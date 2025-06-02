


# Chairmarks {#Chairmarks}

[Chairmarks](https://github.com/LilithHafner/Chairmarks.jl) measures performance [hundreds of times faster](/why#Efficient) than BenchmarkTools [without compromising on accuracy](/why#Precise).

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

