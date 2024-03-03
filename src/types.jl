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
        samples::Vector{Sample}
        ...more fields may be added...
    end

A struct representing a complete benchmark result; returned from [`@be`](@ref).

More fields may be added in the future to represent non sample specific information.

The functions `minimum` and `maximum` are defined field wise on `Benchmark` objects and
return [`Sample`](@ref)s. On Julia 1.9 and above, the functions `Statistics.median`,
`Statistics.mean`, and `Statistics.quantile` are also defined field wise on `Benchmark`
objects and return `Sample`s.

```jldoctest; filter = [r"\\d\\d?\\d?\\.\\d{3} [μmn]?s( \\(.*\\))?"=>s"RES", r"\\d+ (sample|evaluation)s?"=>s"### \\1"]
julia> @be eval(:(for _ in 1:10; sqrt(rand()); end))
Benchmark: 15 samples with 1 evaluation
min    4.307 ms (3608 allocs: 173.453 KiB, 92.21% compile time)
median 4.778 ms (3608 allocs: 173.453 KiB, 94.65% compile time)
mean   6.494 ms (3608 allocs: 173.453 KiB, 94.15% compile time)
max    12.021 ms (3608 allocs: 173.453 KiB, 95.03% compile time)

julia> minimum(ans)
4.307 ms (3608 allocs: 173.453 KiB, 92.21% compile time)
```
"""
struct Benchmark
    samples::Vector{Sample}
end
