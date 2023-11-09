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
end
Sample(; evals=1, time, allocs=0, bytes=0, gc_fraction=0, compile_fraction=0, recompile_fraction=0) =
    Sample(evals, time, allocs, bytes, gc_fraction, compile_fraction, recompile_fraction)

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
function benchmark(f, args...; evals=nothing, samples=nothing, seconds=samples === nothing ? .1 : nothing)
    samples !== nothing && evals === nothing && throw(ArgumentError("Sorry, we don't support specifying samples but not evals"))
    samples === seconds === nothing && throw(ArgumentError("Must specify either samples or seconds"))

    s = _benchmark(f, args, 1)
    s.time > 5e9 && return [t]

    s = _benchmark(f, args, 1)
    evals = max(1, floor(Int, 63_245sqrt(seconds)/(s.time+1)))
    samples = ceil(Int, min(50000seconds, 1e9seconds/(s.time+1)/evals))

    if samples > 1
        # Retune if very fast and tuning is cheap
        s = _benchmark(f, args, evals)
        evals = max(1, floor(Int, 63_245sqrt(seconds)/(s.time+1)))
        samples = ceil(Int, min(50000seconds, 1e9seconds/(s.time+1)/evals))
    end

    data = Vector{Sample}(undef, samples)
    data[1] = evals == s.evals ? s : _benchmark(f, args, evals)
    for i in 2:samples
        data[i] = _benchmark(f, args, evals)
    end
    Benchmark(data)
end
_div(a, b) = a == b == 0 ? zero(a/b) : a/b
function _benchmark(f::F, args::A, evals::Int) where {F, A}
    gcstats = Base.gc_num()
    Base.cumulative_compile_timing(true)
    ctime, rtime = try
        ctime = Base.cumulative_compile_time_ns()
        rtime = time_ns()
        for _ in 1:evals
            f(args...)
        end
        rtime = time_ns() - rtime
        ctime = Base.cumulative_compile_time_ns() .- ctime
        ctime, rtime
    finally
        Base.cumulative_compile_timing(false)
    end
    gcdiff = Base.GC_Diff(Base.gc_num(), gcstats)

    Sample(evals, rtime/evals, Base.gc_alloc_count(gcdiff)/evals, gcdiff.allocd/evals, _div(gcdiff.total_time,rtime), _div(ctime[1],rtime), _div(ctime[2],ctime[1]))
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