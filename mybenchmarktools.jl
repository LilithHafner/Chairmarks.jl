using Statistics, Printf

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
function process_kw(kw)
    all(Base.Fix2(Base.isexpr, :(=)), kw) || error("Invalid syntax")
    (Expr(:parameters, (Expr(:kw, x.args...) for x in kw)...),)
end
macro b(x, kw...)
    Base.isexpr(x, :call) || error("Can only benchmark function calls")
    Expr(:call, :benchmark, process_kw(kw)..., x.args...)
end

# Benchmarking
function benchmark(f, args...; evals=nothing, samples=nothing, seconds=samples === nothing ? .1 : 1)
    samples !== nothing && evals === nothing && throw(ArgumentError("Sorry, we don't support specifying samples but not evals"))
    samples === seconds === nothing && throw(ArgumentError("Must specify either samples or seconds"))
    evals === nothing || evals > 0 || throw(ArgumentError("evals must be positive"))
    samples === nothing || samples >= 0 || throw(ArgumentError("samples must be non-negative"))
    seconds === nothing || seconds >= 0 || throw(ArgumentError("seconds must be non-negative"))

    warmup, start_time = _benchmark(f, args, 1, false)

    (samples == 0 || seconds == 0) && return Benchmark([warmup])

    if evals === nothing
        @assert evals === samples === nothing && seconds !== nothing

        ns = 1e9seconds

        if warmup.time > 2ns && warmup.compile_fraction < .5
            # The estimated runtime in the warmup already exceeds the time budget.
            # Return the warmup result (which is marked as not having a warmup).
            return Benchmark([warmup])
        end

        calibration1, time = _benchmark(f, args, 1)

        # We should be spending about 5% of runtime on calibration.
        # If we spent less than 1% then recalibrate with more evals.
        calibration2 = nothing
        if calibration1.time < .01ns
            calibration2, time = _benchmark(f, args, floor(Int, .05ns/(calibration1.time+1)))
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

        evals = max(1, floor(Int, 1e9target_sample_time/(something(calibration2, calibration1).time+1)))
    end

    data = Vector{Sample}(undef, samples === nothing ? 64 : samples)
    samples === nothing && resize!(data, 1)

    # Save calibration runs as data if they match the calibrate evals
    if calibration1.evals == evals
        data[1] = calibration1
    elseif calibration2 !== nothing && calibration2.evals == evals # Can't match both
        data[1] = calibration2
    else
        data[1], time = _benchmark(f, args, evals)
    end

    i = 1
    stop_time = seconds === nothing ? nothing : round(UInt64, start_time + 1e9seconds)
    while (seconds === nothing || time < stop_time) && (samples === nothing || i < samples)
        sample, time = _benchmark(f, args, evals)
        samples === nothing ? push!(data, sample) : (data[i += 1] = sample)
    end

    Benchmark(data)
end
_div(a, b) = a == b == 0 ? zero(a/b) : a/b
function _benchmark(f::F, args::A, evals::Int, warmup::Bool=true) where {F, A}
    gcstats = Base.gc_num()
    Base.cumulative_compile_timing(true)
    ctime, time0, time1 = try
        ctime = Base.cumulative_compile_time_ns()
        time0 = time_ns()
        for _ in 1:evals
            f(args...)
        end
        time1 = time_ns()
        ctime = Base.cumulative_compile_time_ns() .- ctime
        ctime, time0, time1
    finally
        Base.cumulative_compile_timing(false)
    end
    rtime = time1 - time0
    gcdiff = Base.GC_Diff(Base.gc_num(), gcstats)
    Sample(evals, rtime/evals, Base.gc_alloc_count(gcdiff)/evals, gcdiff.allocd/evals, _div(gcdiff.total_time,rtime), _div(ctime[1],rtime), _div(ctime[2],ctime[1]), warmup), time1
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
        for s in sd
            print(io, "       ")
            show(io, m, s)
            println(io)
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

g(seconds) = if seconds < 3e-8
    seconds
elseif seconds > 3e-2
    3e-5
else
    # exp(evalpoly(log(seconds), (-10.85931838387908, -0.25381312421338964, -0.03619120682527099)))

    exp(evalpoly(log(seconds), (
        -log(30e-9)^2/4log(1000),
        1+(2log(30e-9)/4log(1000)),
        -1/4log(1000)
    )))
end


h(seconds) = if seconds < 3e-8
    seconds
elseif seconds > 3e-8+2(3e-5-3e-8)
    3e-5
else
    # exp(evalpoly(log(seconds), (-10.85931838387908, -0.25381312421338964, -0.03619120682527099)))

    evalpoly(seconds, (
        3e-8 + 3e-8^2/4(3e-5-3e-8) - 3e-8 * (1 + 3e-8/2(3e-5-3e-8)),
        1 + 3e-8/2(3e-5-3e-8),
        -1/4(3e-5-3e-8)
    ))
    # exp(evalpoly(log(seconds), (
    #     -log(30e-9)^2/4log(1000),
    #     1+(2log(30e-9)/4log(1000)),
    #     -1/4log(1000)
    # )))
end
