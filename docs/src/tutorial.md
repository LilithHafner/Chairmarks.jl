```@meta
CurrentModule = Chairmarks
DocTestSetup = quote
    using Chairmarks
end
DocTestFilters = [r"\d\d?\d?\.\d{3} [μmn]?s( \(.*\))?"]
```

# Tutorial

Welcome! This tutorial assumes very little prior knowledge and walks you through how to
become a proficient user of Chairmarks.jl. If you are already an experienced user of
BenchmarkTools, you may want to read about
[how to transition from BenchmarkTools to Chairmarks](@ref migration) instead.

If you don't have Julia already, download it from
[julialang.org/downloads](https://julialang.org/downloads/).

Now, launch a Julia REPL by typing `julia` at the command line.

To install Chairmarks, type `]` to enter the package manager, and then type

```julia-repl
(@v1.xx) pkg> add Chairmarks
```

This will install Chairmarks into your default environment. Unlike most packages, installing
Chairmarks into your default environment _is_ recommended because it is a very lightweight
package and a development tool.

Now, you can use Chairmarks by typing `using Chairmarks` in the REPL. Press backspace to
exit the package manager and return to the REPL and run

```jldoctest
julia> using Chairmarks

julia> @b rand(100)
95.500 ns (2 allocs: 928 bytes)
```

Congratulations! This is your first result from Chairmarks. Let's look a little closer at
the invocation and results. `@b` is a macro exported from Chairmarks. It takes the
expression `rand(100)` and runs it a bunch of times, measuring how long it takes to run.

The result, `95.500 ns (2 allocs: 928 bytes)` tells us that the expression takes 95.5
nanoseconds to run and allocates 928 bytes of memory spread across two distinct allocation
events. The exact results you get will likely differ based on your hardware and the Julia
version you are using. These results from Julia 1.11.

By default, Chairmarks reports the _fastest_ runtime of the expression. This is typically
the best choice for reducing noise in microbenchmarks as things like garbage collection and
other background tasks can cause inconsistent slowdowns but but speedups. If you want to
get the full results, use the `@be` macro. (`@be` is longer than `@b` and gives a longer
output)

```jldoctest
julia> @be rand(100)
Benchmark: 19442 samples with 25 evaluations
min    95.000 ns (2 allocs: 928 bytes)
median 103.320 ns (2 allocs: 928 bytes)
mean   140.096 ns (2 allocs: 928 bytes, 0.36% gc time)
max    19.748 μs (2 allocs: 928 bytes, 96.95% gc time)
```

This invocation runs the same experiment as `@b`, but reports more results. It ran 19442
samples, each of which involved recording some performance counters, running `rand(100)` 25
times, and then recording the performance counters again and computing the difference. The
reported runtimes and allocations are those differences divided by the number of
evaluations. We can see here that the runtime of `rand(100)` is pretty stable. 50% of the
time it ranges between 95 and 103.3 nanoseconds. However, the maximum time is two orders
of magnitude slower than the mean time. This is because the maximum time includes a garbage
collection event that took 96.95% of the time[^1].

Sometimes, we wish to measure the runtime of a function that requires some data to operate
on, but don't want to measure the runtime of the function that generates the data. For
example, we may want to compare how long it takes to hash an array of numbers, but we don't
want to include the time it takes to generate the input in our measurements. We can do this
using Chairmarks' pipeline syntax:

```jldoctest
julia> @b rand(100) hash
166.665 ns
```

The first argument is called once per sample, and the second argument is called once per
evaluation, each time passed the result of the first argument. We can also use the special
`_` variable to refer to the output of the previous step. Here, we compare two different
implementations of the norm of a vector

```jldoctest
julia> @b rand(100) sqrt(sum(_ .* _))
37.628 ns (2 allocs: 928 bytes)

julia> @b rand(100) sqrt(sum(x->x^2, _))
11.053 ns
```

The _ refers to the array whose norm is to be computed. Both implementations are quite fast.
These measurements are on a 3.5 GHz CPU so it appears that the first implementation takes
about one clock cycle per element, with a bit of overhead. The second, on the other hand,
appears to be running much faster than that, likely because it is making use of SIMD
instructions.

[^1]: note that the samples are compared element wise, so the max field reports the maximum
    runtime and the maximum proportion of runtime spent in garbage collection (gc). Thus it
    is possible that the trial which had a 19.748 μs runtime was not the same trial that
    spent 96.95% of its time in garbage collection. This is in order to make the results
    more consistent. If half the trials spend 10% of their time in gc amd runtime varies
    based on other factors, it would be unfortunate to report maximum gc time as either 10%
    or 0% at random depending on whether the longest running trial happened to trigger gc.