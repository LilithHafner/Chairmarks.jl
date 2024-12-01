```@meta
CurrentModule = Chairmarks
DocTestSetup = quote
    using Chairmarks
end
DocTestFilters = [r"\d\d?\d?\.\d{3} [μmn]?s( \(.*\))?"]
```

## Precise

Capable of detecting 1% difference in runtime in ideal conditions

!!! warning
    Comparative benchmarking is experimental and may be removed or changed in future versions

```jldoctest
julia> f(n) = sum(rand() for _ in 1:n)
f (generic function with 1 method)

julia> @b f(1000), f(1010)
(1.064 μs, 1.074 μs)

julia> @b f(1000), f(1010)
(1.063 μs, 1.073 μs)

julia> @b f(1000), f(1010)
(1.064 μs, 1.074 μs)
```

## Efficient

|               | Chairmarks     | BenchmarkTools    | Ratio
|---------------|----------------|-------------------|-------|
| TTFX          | 3.4s           | 13.4s             | 4x
| TTFX excluding precompilation | 43ms | 1118ms      | 26x
| Load time     | 4.2ms          | 131ms             | 31x
| minimum runtime | 34μs         | 459ms             | 13,500x
| default runtime | 0.1s         | 5s                | 50x
| proportion of time spent benchmarking | 90%-99% | 13%-65% | 1.5-7x

See [https://github.com/LilithHafner/Chairmarks.jl/blob/main/contrib/ttfx\_rm\_rf\_julia.sh](https://github.com/LilithHafner/Chairmarks.jl/blob/main/contrib/ttfx_rm_rf_julia.sh)
for methodology on the first four entries and
[https://github.com/LilithHafner/Chairmarks.jl/blob/main/contrib/efficiency.jl](https://github.com/LilithHafner/Chairmarks.jl/blob/main/contrib/efficiency.jl)
for the last.

## Concise

Chairmarks uses a concise pipeline syntax to define benchmarks. When providing a single
argument, that argument is automatically wrapped in a function for higher performance and
executed

```jldoctest
julia> @b sort(rand(100))
1.500 μs (3 allocs: 2.625 KiB)
```

When providing two arguments, the first is setup code and only the runtime of the second is
measured

```jldoctest
julia> @b rand(100) sort
1.018 μs (2 allocs: 1.750 KiB)
```

You may use `_` in the later arguments to refer to the output of previous arguments

```jldoctest
julia> @b rand(100) sort(_, by=x -> exp(-x))
5.521 μs (2 allocs: 1.750 KiB)
```

A third argument can run a "teardown" function to integrate testing into the benchmark and
ensure that the benchmarked code is behaving correctly

```jldoctest
julia> @b rand(100) sort(_, by=x -> exp(-x)) issorted(_) || error()
ERROR:
Stacktrace:
  [1] error()
[...]

julia> @b rand(100) sort(_, by=x -> exp(-x)) issorted(_, rev=true) || error()
5.358 μs (2 allocs: 1.750 KiB)
```

The function being benchmarked can be a comma separated list of functions in which case a tuple
of the results is returned

!!! warning
    Comparative benchmarking is experimental and may be removed or changed in future versions

```jldoctest
julia> @b rand(100) sort(_, alg=InsertionSort),sort(_, alg=MergeSort)
(1.245 μs (2 allocs: 928 bytes), 921.875 ns (4 allocs: 1.375 KiB))
```

See [`@be`](@ref) for more info

## Truthful

On versions of Julia prior to 1.8, Chairmarks automatically computes a checksum based on the
results of the provided computations and stores the checksum in Chiarmaks.CHECKSUM. This
makes it impossible for the compiler to elide any part of the computation that has an impact
on its return value.

While the checksums are reasonably fast, one negative side effect of this is that they add a
bit of overhead to the measured runtime, and that overhead can vary depending on the
return value of the function being benchmarked. In versions of Julia 1.8 and later, these
checksums are emulated using the function `Base.donotdelete` which is designed and
documented to ensure that necessary computation is not elided without adding extra overhead.

## Innate qualities

Chairmarks is inherently narrower than BenchmarkTools by construction. It also has more
reliable back support. Back support is a defining feature of chairs while benches are known
to sometimes lack back support.
