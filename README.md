# Chairmarks

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://Chairmarks.lilithhafner.com/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://Chairmarks.lilithhafner.com/dev/)
[![Build Status](https://github.com/LilithHafner/Chairmarks.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/LilithHafner/Chairmarks.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/LilithHafner/Chairmarks.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/LilithHafner/Chairmarks.jl)

Chairmarks measures performance [hundreds of times faster](https://Chairmarks.lilithhafner.com/stable/why/#Efficient)
than BenchmarkTools [without compromising on accuracy](https://Chairmarks.lilithhafner.com/stable/why/#Precise).

Instalation

```julia
julia> import Pkg; Pkg.add("Chairmarks")
```

Usage

```julia
julia> using Chairmarks

julia> @b rand(1000) # How long does it take to generate a random array of length 1000?
720.214 ns (3 allocs: 7.875 KiB)

julia> @b rand(1000) hash # How long does it take to hash that array?
1.689 μs

julia> @b rand(1000) _.*5 # How long does it take to multiply it by 5 element wise?
172.970 ns (3 allocs: 7.875 KiB)
```

[Why Chairmarks?](https://Chairmarks.lilithhafner.com/stable/why)

[Tutorial](https://Chairmarks.lilithhafner.com/stable/tutorial)

[API Reference](https://Chairmarks.lilithhafner.com/stable/reference)
