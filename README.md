# Chairmarks

<!-- [![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://Chairmarks.lilithhafner.com/stable/) -->
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://Chairmarks.lilithhafner.com/dev/)
[![Build Status](https://github.com/LilithHafner/Chairmarks.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/LilithHafner/Chairmarks.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/LilithHafner/Chairmarks.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/LilithHafner/Chairmarks.jl)

Benchmarks with back support. Often hundreds of times faster than BenchmarkTools.jl without compromising on accuracy.

## Precise

Capable of detecting 1% difference in runtime in ideal conditions

```julia
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

```julia
julia> @b sort(rand(100))
1.500 μs (3 allocs: 2.625 KiB)
```

When providing two arguments, the first is setup code and only the runtime of the second is measured

```julia
julia> @b rand(100) sort
1.018 μs (2 allocs: 1.750 KiB)
```

You may use `_` in the later arguments to refer to the output of previous arguments

```julia
julia> @b rand(100) sort(_, by=x -> exp(-x))
5.521 μs (2 allocs: 1.750 KiB)
```

A third argument can run a "teardown" function to integrate testing into the benchmark and ensure that the benchmarked code is behaving correctly

```julia
julia> @b rand(100) sort(_, by=x -> exp(-x)) issorted(_) || error()
ERROR:
Stacktrace:
 [1] error()
[...]

julia> @b rand(100) sort(_, by=x -> exp(-x)) issorted(_, rev=true) || error()
5.358 μs (2 allocs: 1.750 KiB)
```

See the [docstring of `@b`](https://chairmarks.lilithhafner.com/dev/#Chairmarks.@b-Tuple) for more info

## Efficient

|           | Chairmarks.jl | BenchmarkTools.jl | Ratio
|-----------|--------|---------------|--------|
|[TTFX](contrib/ttfx_rm_rf_julia.sh) | 3.4s | 13.4s | 4x
| Load time | 4.2ms | 131ms | 31x
| TTFX excluding precompile time | 43ms | 1118ms | 26x
| minimum runtime | 34μs | 459ms | 13,500x
|Width | Narrow   | Wide     |     2–4x
|Back Support | Almost Always | Sometimes | N/A
