```@meta
CurrentModule = Chairmarks
DocTestSetup = quote
    using Chairmarks
end
DocTestFilters = [r"\d\d?\d?\.\d{3} [μmn]?s( \(.*\))?"]
```

# Chairmarks

[Chairmarks.jl](https://github.com/LilithHafner/Chairmarks.jl) provides benchmarks with back support. Often hundreds of times faster than BenchmarkTools.jl without compromising on accuracy.

## Precise

Capable of detecting 1% difference in runtime in ideal conditions

```jldoctest
julia> f(n) = sum(rand() for _ in 1:n)
f (generic function with 1 method)

julia> @b f(1000)
1.074 μs

julia> @b f(1000)
1.075 μs

julia> @b f(1000)
1.076 μs

julia> @b f(1010)
1.086 μs

julia> @b f(1010)
1.087 μs

julia> @b f(1010)
1.087 μs
```

## Concise

Chairmarks uses a concise pipeline syntax to define benchmarks. When providing a single argument, that argument is automatically wrapped in a function for higher performance and executed

```jldoctest
julia> @b sort(rand(100))
1.500 μs (3 allocs: 2.625 KiB)
```

When providing two arguments, the first is setup code and only the runtime of the second is measured

```jldoctest
julia> @b rand(100) sort
1.018 μs (2 allocs: 1.750 KiB)
```

You may use `_` in the later arguments to refer to the output of previous arguments

```jldoctest
julia> @b rand(100) sort(_, by=x -> exp(-x))
5.521 μs (2 allocs: 1.750 KiB)
```

A third argument can run a "teardown" function to integrate testing into the benchmark and ensure that the benchmarked code is behaving correctly

```jldoctest
julia> @b rand(100) sort(_, by=x -> exp(-x)) issorted(_) || error()
ERROR:
Stacktrace:
 [1] error()
[...]

julia> @b rand(100) sort(_, by=x -> exp(-x)) issorted(_, rev=true) || error()
5.358 μs (2 allocs: 1.750 KiB)
```

See [`@b`](@ref) for more info

## Efficient

|           | Chairmarks.jl | BenchmarkTools.jl | Ratio
|-----------|--------|---------------|--------|
|[TTFX](https://github.com/LilithHafner/Chairmarks.jl/blob/main/contrib/ttfx_rm_rf_julia.sh) | 3.4s | 13.4s | 4x
| Load time | 4.2ms | 131ms | 31x
| TTFX excluding precompile time | 43ms | 1118ms | 26x
| minimum runtime | 34μs | 459ms | 13,500x
|Width | Narrow   | Wide     |     2–4x
|Back Support | Almost Always | Sometimes | N/A


```@index
```

```@autodocs
Modules = [Chairmarks]
```
