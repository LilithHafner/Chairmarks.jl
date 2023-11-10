module QuickBenchmarkTools

using Statistics, Printf

export @b, @be

# Types
struct Sample
    evals              ::Float64
    time               ::Float64
    allocs             ::Float64
    bytes              ::Float64
    gc_fraction        ::Float64
    compile_fraction   ::Float64
    recompile_fraction ::Float64
    warmup             ::Float64
end
Sample(; evals=1, time, allocs=0, bytes=0, gc_fraction=0, compile_fraction=0, recompile_fraction=0, warmup=true) =
    Sample(evals, time, allocs, bytes, gc_fraction, compile_fraction, recompile_fraction, warmup)

struct Benchmark
    data::Vector{Sample}
end

# Input
substitute(f::Symbol, var::Symbol) = f === :_ ? (var, true) : (f, false)
substitute(f, ::Symbol) = f, false
function substitute(ex::Expr, var::Symbol)
    changed = false
    args = similar(ex.args)
    i = firstindex(args)
    if ex.head in (:(=), :->, :function)
        args[i] = ex.args[i]
        i += 1
    end
    for i in i:lastindex(args)
        args[i], c = substitute(ex.args[i], var)
        changed |= c
    end
    changed ? Base.exprarray(ex.head, args) : ex, changed
end

create_first_function(f::Symbol) = f
create_first_function(f) = :(() -> $f)
function create_function(f)
    f === :_ && return identity
    var = gensym()
    new, changed = substitute(f, var)
    changed ? :($var -> $new) : f
end
function process_args(exprs)
    first = true
    in_kw = false
    parameters = Any[]
    args = Any[benchmark, Base.exprarray(:parameters, parameters)]
    for ex in exprs
        if Base.isexpr(ex, :(=))
            in_kw = true
            push!(parameters, Expr(:kw, ex.args...))
        elseif in_kw
            error("Positional argument after keyword argument")
        elseif first
            push!(args, create_first_function(ex))
            first = false
        else
            push!(args, create_function(ex))
        end
    end
    esc(Base.exprarray(:call, args))
end

macro b(args...)
    call = process_args(args)
    :(minimum($(call)))
end
macro be(args...)
    process_args(args)
end

# Benchmarking

function benchmark(init, setup, f, teardown; kw...)
    :init in keys(kw) && throw(ArgumentError("init provided both as a positional argument and as a keyword argument"))
    benchmark(setup, f, teardown; init, kw...)
end
function benchmark(setup, f, teardown; kw...)
    :teardown in keys(kw) && throw(ArgumentError("teardown provided both as a positional argument and as a keyword argument"))
    benchmark(setup, f; teardown, kw...)
end
function benchmark(setup, f; kw...)
    :setup in keys(kw) && throw(ArgumentError("setup provided both as a positional argument and as a keyword argument"))
    benchmark(f; setup, kw...)
end
maybecall(f::Nothing, x) = x
maybecall(f, x) = (f(x...),)
function benchmark(f; init=nothing, setup=nothing, teardown=nothing, evals=nothing, samples=nothing, seconds=samples === nothing ? .1 : 1)
    samples !== nothing && evals === nothing && throw(ArgumentError("Sorry, we don't support specifying samples but not evals"))
    samples === seconds === nothing && throw(ArgumentError("Must specify either samples or seconds"))
    evals === nothing || evals > 0 || throw(ArgumentError("evals must be positive"))
    samples === nothing || samples >= 0 || throw(ArgumentError("samples must be non-negative"))
    seconds === nothing || seconds >= 0 || throw(ArgumentError("seconds must be non-negative"))

    args1 = maybecall(init, ())

    function bench(evals, warmup=true)
        args2 = maybecall(setup, args1)
        sample, t, args3 = _benchmark(f, args2, evals, warmup)
        maybecall(teardown, (args3,))
        sample, t
    end

    warmup, start_time = bench(1, false)

    (samples == 0 || seconds == 0) && return Benchmark([warmup])

    new_evals = if evals === nothing
        @assert evals === samples === nothing && seconds !== nothing

        ns = 1e9seconds

        if warmup.time > 2ns && warmup.compile_fraction < .5
            # The estimated runtime in the warmup already exceeds the time budget.
            # Return the warmup result (which is marked as not having a warmup).
            return Benchmark([warmup])
        end

        calibration1, time = bench(1)

        # We should be spending about 5% of runtime on calibration.
        # If we spent less than 1% then recalibrate with more evals.
        calibration2 = nothing
        if calibration1.time < .01ns
            calibration2, time = bench(floor(Int, .05ns/(calibration1.time+1)))
        end

        # We need samples that take at least 30 nanoseconds for any reasonable measurements
        # and sample times above 30 microseconds are excessive. But we must always respect
        # the user's requested time limit, even if it is below 30 nanoseconds.
        target_sample_time = target_sample_time = if seconds < 3e-8
            seconds
        elseif seconds > 3e-2
            3e-5
        else
            exp(evalpoly(log(seconds), (-10.85931838387908, -0.25381312421338964, -0.03619120682527099)))
            # exp(evalpoly(log(seconds), (-log(30e-9)^2/4log(1000),1+(2log(30e-9)/4log(1000)),-1/4log(1000))))
        end

        max(1, floor(Int, 1e9target_sample_time/(something(calibration2, calibration1).time+1)))
    else
        evals
    end

    data = Vector{Sample}(undef, samples === nothing ? 64 : samples)
    samples === nothing && resize!(data, 1)

    # Save calibration runs as data if they match the calibrate evals
    if evals === nothing && calibration1.evals == new_evals
        data[1] = calibration1
    elseif evals === nothing && calibration2 !== nothing && calibration2.evals == new_evals # Can't match both
        data[1] = calibration2
    else
        data[1], time = bench(new_evals)
    end

    i = 1
    stop_time = seconds === nothing ? nothing : round(UInt64, start_time + 1e9seconds)
    while (seconds === nothing || time < stop_time) && (samples === nothing || i < samples)
        sample, time = bench(new_evals)
        samples === nothing ? push!(data, sample) : (data[i += 1] = sample)
    end

    Benchmark(data)
end
_div(a, b) = a == b == 0 ? zero(a/b) : a/b
struct Secretb45188098f2cd177828f6d91bb0b10ec end
function _benchmark(f::F, args::A, evals::Int, warmup::Bool) where {F, A}
    gcstats = Base.gc_num()
    Base.cumulative_compile_timing(true)
    ctime, time0, time1, res = try
        res = Secretb45188098f2cd177828f6d91bb0b10ec()
        ctime = Base.cumulative_compile_time_ns()
        time0 = time_ns()
        for _ in 1:evals
            res = f(args...)
        end
        time1 = time_ns()
        ctime = Base.cumulative_compile_time_ns() .- ctime

        @assert !(res isa Secretb45188098f2cd177828f6d91bb0b10ec)
        ctime, time0, time1, res
    finally
        Base.cumulative_compile_timing(false)
    end
    rtime = time1 - time0
    gcdiff = Base.GC_Diff(Base.gc_num(), gcstats)
    Sample(evals, rtime/evals, Base.gc_alloc_count(gcdiff)/evals, gcdiff.allocd/evals, _div(gcdiff.total_time,rtime), _div(ctime[1],rtime), _div(ctime[2],ctime[1]), warmup), time1, res
end

# Statistics
function elementwise(f, b::Benchmark)
    Sample.((f(getproperty(s, p) for s in b.data) for p in fieldnames(Sample))...)
end
Base.minimum(b::Benchmark) = elementwise(minimum, b)
Statistics.median(b::Benchmark) = elementwise(median, b)
Statistics.mean(b::Benchmark) = elementwise(mean, b)
Base.maximum(b::Benchmark) = elementwise(maximum, b)


# Output
function print_rounded(io, x, digits)
    1 ≤ digits ≤ 20 || throw(ArgumentError("digits must be between 1 and 20"))
    if x == 0
        print(io, '0')
    elseif 0 < x < 1/10^digits
        print(io, "<0.", '0'^(digits-1), "1")
    else
        print(io, Base.Ryu.writefixed(x, digits))
    end
end
function print_time(io, ns::Float64)
    ns < 1e3 && return (print_rounded(io, ns, 3); print(io, " ns"))
    ns < 1e6 && return @printf io "%.3f μs" ns/1e3
    ns < 1e9 && return @printf io "%.3f ms" ns/1e6
    @printf io "%.3f s" ns/1e9
end
function print_allocs(io, allocs, bytes)
    if isinteger(allocs)
        @printf io "%d" allocs
    else
        print_rounded(io, allocs, 2)
    end
    print(io, " allocs: ")
    if bytes < 2^10
        if isinteger(bytes)
            @printf io "%d" bytes
        else
            print_rounded(io, bytes, 3)
        end
        print(io, " bytes")
        return
    end
    bytes < 2^20 && return @printf io "%.3f KiB" bytes/2^10
    bytes < 2^30 && return @printf io "%.3f MiB" bytes/2^20
    bytes < Int64(2)^40 && return @printf io "%.3f GiB" bytes/2^30
    bytes < Int64(2)^50 && return @printf io "%.3f TiB" bytes/Int64(2)^40
    @printf io "%.3f PiB" bytes/Int64(2)^50
end
function Base.show(io::IO, ::MIME"text/plain", s::Sample)
    print_time(io, s.time)
    open = false
    if s.allocs != 0 || s.bytes != 0
        print(io, open ? ", " : " (")
        print_allocs(io, s.allocs, s.bytes)
        open = true
    end
    if s.gc_fraction !== 0.0
        print(io, open ? ", " : " (")
        print_rounded(io, s.gc_fraction * 100, 2)
        print(io, "% gc time")
        open = true
    end
    if s.compile_fraction !== 0.0 || s.recompile_fraction !== 0.0
        print(io, open ? ", " : " (")
        print_rounded(io, s.compile_fraction * 100, 2)
        print(io, "% compile time")
        if s.recompile_fraction != 0
            print(io, " ")
            print_rounded(io, s.recompile_fraction * 100, 2)
            print(io, "% of which was recompilation")
        end
        open = true
    end
    if s.warmup !== 1.0
        print(io, open ? ", " : " (")
        if s.warmup === 0.0
            print(io, "without a warmup")
        else
            print_rounded(io, s.warmup * 100, 1)
            print(io, "% warmed up")
        end
        open = true
    end
    if open
        print(io, ')')
    end
end
function print_maybe_int(io, prefix, x)
    print(io, prefix)
    isinteger(x) ? print(io, Integer(x)) : print(io, x)
end
function print_maybe_int(io, prefix, x, suffix)
    print_maybe_int(io, prefix, x)
    print(io, suffix)
end
function Base.show(io::IO, s::Sample)
    print(io, "Sample(")
    s.evals !== 1.0 && print_maybe_int(io, "evals=", s.evals, ", ")
    print_maybe_int(io, "time=", s.time)
    s.allocs !== 0.0 && print_maybe_int(io, ", allocs=", s.allocs)
    s.bytes !== 0.0 && print_maybe_int(io, ", bytes=", s.bytes)
    s.gc_fraction !== 0.0 && print(io, ", gc_fraction=", s.gc_fraction)
    s.compile_fraction !== 0.0 && print(io, ", compile_fraction=", s.compile_fraction)
    s.recompile_fraction !== 0.0 && print(io, ", recompile_fraction=", s.recompile_fraction)
    s.warmup !== 1.0 && print_maybe_int(io, ", warmup=", s.warmup)
    print(io, ')')
end

function Base.show(io::IO, b::Benchmark)
    println(io, "Benchmark([")
    for s in b.data
        println(io, "  ", s)
    end
    print(io, "])")
end
function Base.show(io::IO, m::MIME"text/plain", b::Benchmark)
    samples = length(b.data)
    print(io, "Benchmark: $samples sample")
    samples == 1 || print(io, "s")
    print(io, " with ")
    if allequal(getproperty.(b.data, :evals))
        evals = first(b.data).evals
        print_maybe_int(io, "", first(b.data).evals, " evaluation")
        evals == 1 || print(io, "s")
        println()
    else
        println("variable evaluations")
    end
    if samples ≤ 4
        sd = sort(b.data, by=s -> s.time)
        for (i, s) in enumerate(sd)
            print(io, "       ")
            show(io, m, s)
            i == length(sd) || println(io)
        end
    else
        print("min    ")
        show(io, m, minimum(b))
        println(io)
        print("median ")
        show(io, m, median(b))
        println(io)
        print("mean   ")
        show(io, m, mean(b))
        println(io)
        print("max    ")
        show(io, m, maximum(b))
    end
end

# precompilation
precompile(benchmark, (Function,))
precompile(benchmark, (Function,Function))
precompile(benchmark, (Function,Function,Function))
precompile(Base.show, (Base.IOContext{Base.TTY}, MIME"text/plain", Benchmark))
precompile(minimum, (Benchmark,))
precompile(process_args, (Tuple{Expr},))
precompile(process_args, (Tuple{Expr, Expr},))
precompile(process_args, (Tuple{Expr, Symbol},))
precompile(process_args, (Tuple{Expr, Expr, Expr},))
precompile(process_args, (Tuple{Expr, Symbol, Expr},))

end