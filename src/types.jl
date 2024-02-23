"""
    Sample

A struct representing a single sample of a benchmark. The fields are internal and subject to
change.
"""
struct Sample
    """
        evals

    The number of times the benchmark was evaluated for this sample.

        t0 = time()
        for i in 1:evals
            f()
        end
        sample_time = t0-time()
    """
    evals              ::Float64

    "The average time taken to run the sample, in seconds per evaluation."
    time               ::Float64

    "The average number of allocations made per evaluation (not the number of bytes allocated)"
    allocs             ::Float64

    "The average number of bytes allocated per evaluation (not the number of allocations)"
    bytes              ::Float64

    "The fraction of time spent in garbage collection (0.0 to 1.0)"
    gc_fraction        ::Float64

    "The fraction of time spent compiling (0.0 to 1.0)"
    compile_fraction   ::Float64

    "The fraction of compile time which was, itself, recompilation (0.0 to 1.0)"
    recompile_fraction ::Float64

    "Whether this sample had a warmup run before it (1.0 = yes. 0.0 = no)."
    warmup             ::Float64

    "The value returned by the accumulator"
    value              ::Float64
end
Sample(; evals=1, time, allocs=0, bytes=0, gc_fraction=0, compile_fraction=0, recompile_fraction=0, warmup=true, value=0) =
    Sample(evals, time, allocs, bytes, gc_fraction, compile_fraction, recompile_fraction, warmup, value)

struct Benchmark
    data::Vector{Sample}
end
