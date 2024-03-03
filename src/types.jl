"""
    struct Sample
        evals              ::Float64 # The number of times the benchmark was evaluated for this sample.
        time               ::Float64 # The average time taken to run the sample, in seconds per evaluation.
        allocs             ::Float64 # The average number of allocations made per evaluation
        bytes              ::Float64 # The average number of bytes allocated per evaluation
        gc_fraction        ::Float64 # The fraction of time spent in garbage collection (0.0 to 1.0)
        compile_fraction   ::Float64 # The fraction of time spent compiling (0.0 to 1.0)
        recompile_fraction ::Float64 # The fraction of compile time which was, itself, recompilation (0.0 to 1.0)
        warmup             ::Float64 # Whether this sample had a warmup run before it (1.0 = yes. 0.0 = no).
        checksum           ::Float64 # The checksum value returned by the accumulator
        ...more fields may be added...
    end

A struct representing a single sample of a benchmark.

[`@b`](@ref) returns a composite sample formed by taking the field-wise minimum of the
measured samples. More fields may be added in the future as more information becomes
available.
"""
struct Sample
    "The number of times the benchmark was evaluated for this sample."
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
    "The checksum value returned by the accumulator"
    checksum           ::Float64
end
Sample(; evals=1, time, allocs=0, bytes=0, gc_fraction=0, compile_fraction=0, recompile_fraction=0, warmup=true, checksum=0) =
    Sample(evals, time, allocs, bytes, gc_fraction, compile_fraction, recompile_fraction, warmup, checksum)

"""
    struct Benchmark
        data::Vector{Sample}
        ...more fields may be added...
    end

A struct representing a complete benchmark result.

[`@be`](@ref) returns a `Benchmark` object.

More fields may be added in the future to represent non sample specific information.
"""
struct Benchmark
    data::Vector{Sample}
end
