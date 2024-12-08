# Chairmarks

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://Chairmarks.lilithhafner.com/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://Chairmarks.lilithhafner.com/dev/)
[![Build Status](https://github.com/LilithHafner/Chairmarks.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/LilithHafner/Chairmarks.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/LilithHafner/Chairmarks.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/LilithHafner/Chairmarks.jl)
[![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

Chairmarks measures performance [hundreds of times faster](https://Chairmarks.lilithhafner.com/stable/why#efficient)
than BenchmarkTools [without compromising on accuracy](https://Chairmarks.lilithhafner.com/stable/why#precise).

Installation

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

julia> @b rand(100,100) inv,_^2,sum # Is it be faster to invert, square, or sum a matrix? [THIS USAGE IS EXPERIMENTAL]
(92.917 μs (9 allocs: 129.203 KiB), 27.166 μs (3 allocs: 78.203 KiB), 1.083 μs)
```

[Tutorial](https://Chairmarks.lilithhafner.com/stable/tutorial)

[Why Chairmarks?](https://Chairmarks.lilithhafner.com/stable/why)

[API Reference](https://Chairmarks.lilithhafner.com/stable/reference)
