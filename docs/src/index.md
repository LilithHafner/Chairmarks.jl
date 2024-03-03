```@meta
CurrentModule = Chairmarks
DocTestSetup = quote
    using Chairmarks
end
DocTestFilters = [r"\d\d?\d?\.\d{3} [μmn]?s( \(.*\))?"]
```

# Chairmarks

[Chairmarks](https://github.com/LilithHafner/Chairmarks.jl) measures performance hundreds
of times faster than BenchmarkTools without compromising on accuracy.

Installation

```julia-repl
julia> import Pkg; Pkg.add("Chairmarks")
```

Usage

```jldoctest
julia> using Chairmarks

julia> @b rand(1000) # How long does it take to generate a random array of length 1000?
720.214 ns (3 allocs: 7.875 KiB)

julia> @b rand(1000) hash # How long does it take to hash that array?
1.689 μs

julia> @b rand(1000) _.*5 # How long does it take to multiply it by 5 element wise?
172.970 ns (3 allocs: 7.875 KiB)
```
