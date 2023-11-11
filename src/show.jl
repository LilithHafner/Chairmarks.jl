function print_rounded(@nospecialize(io::IO), x::Float64, digits::Int)
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
    @nospecialize
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
    if bytes < 1<<10
        if isinteger(bytes)
            @printf io "%d" bytes
        else
            print_rounded(io, bytes, 3)
        end
        print(io, " bytes")
        return
    end
    for (i, c) in enumerate("KMGTP")
        bytes < UInt64(1)<<(10*(i+1)) && return @printf io "%.3f %siB" bytes/(UInt64(1)<<10i) c
    end
end
function Base.show(io::IO, ::MIME"text/plain", s::Sample)
    @nospecialize
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
