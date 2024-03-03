```@meta
CurrentModule = Chairmarks
DocTestSetup = quote
    using Chairmarks
end
DocTestFilters = [r"\d\d?\d?\.\d{3}( [μmn]?s|\d* seconds)( \(.*\))?|Benchmark: \d+ samples with \d+ evaluations"]
```

# Tutorial

Welcome! This tutorial assumes very little prior knowledge and walks you through how to
become a competent user of Chairmarks. If you are already an experienced user of
BenchmarkTools, you may want to read about
[how to migrate from BenchmarkTools to Chairmarks](@ref migration) instead.

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

Chairmarks reports results in seconds (s), milliseconds (ms), microseconds (μs), or
nanoseconds (ns) depending on the magnitude of the runtime. Each of these units is 1000
times smaller than the last according to the standard
[SI unit system](https://en.wikipedia.org/wiki/Metric_prefix).

By default, Chairmarks reports the _fastest_ runtime of the expression. This is typically
the best choice for reducing noise in microbenchmarks as things like garbage collection and
other background tasks can cause inconsistent slowdowns but not speedups. If you want to
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
collection event that took 96.95% of the time.[^1]

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

## Common pitfalls

When benchmarking a function which mutates its arguments, be aware that the same input is
passed to the function each evaluation in a sample. This can cause problems if the function
does not expect to repeatedly operate on the same input.

```jldoctest
julia> @b rand(100) sort!
129.573 ns (0.02 allocs: 11.317 bytes)
```

We can see immediately that something suspicious is going on here: the reported number of
allocations (which we expect to be an integer) is a floating point number. This is because
each sample, the array is sorted once, which involves allocating a scratchspace, and then
that same array is re-sorted repeatedly. It turns out `sort!` operates very quickly and
does not allocate at all when it is passed a sorted array. To benchmark this more
accurately, we may specify the number of evaluations

```jldoctest
julia> @b rand(100) sort! evals=1
1.208 μs (2 allocs: 928 bytes)
```

or copy the input before sorting it

```jldoctest
julia> @b rand(100) sort!(copy(_))
1.250 μs (4 allocs: 1.812 KiB)
```

copy the input into a pre-allocated array

```jldoctest
julia> @b (x = rand(100); (x, copy(x))) sort!(copyto!(_[1], _[2]))
675.926 ns (2 allocs: 928 bytes)
```

or re-generate the input each evaluation

```jldoctest
julia> @b sort!(rand(100))
1.405 μs (4 allocs: 1.812 KiB)
```

Notice that each of these invocations produces a different output. Setting `evals` to 1 can
cause strange effects whenever the runtime of the expression is less than about 30 μs both
due to the overhead of starting and stopping the timers and due to the imprecision of timer
results on most machines. Any form of pre-processing included in the primary function will
be included in the reported runtime, so each of the latter options also introduce artifacts.

In general, it is important to use the same methodology when comparing two different
functions. Chairmarks is optimized to produce reliable results for answering questions of
the form "which of these two implementations of the same specification is faster", more so
than providing absolute measurements of the runtime of fast-running functions.

That said, for functions which take more than about 30 μs to run, Chairmarks can reliably
provide accurate absolute timings. In general, the faster the runtime of the expression
being measured, the more strange behavior and artifacts you will see, and the more careful
you have to be.

```jldoctest
julia> f() = sum(rand(100_000))
f (generic function with 1 method)

julia> @b f()
67.167 μs (3 allocs: 781.312 KiB)

julia> @b f() evals=1
67.334 μs (3 allocs: 781.312 KiB)

julia> @b for _ in 1:3 f() end
201.917 μs (9 allocs: 2.289 MiB)

julia> 201.917/67.167
3.0061935176500363

julia> 201.917/67.334
2.998737636261027
```

Longer runtimes and macrobenchmarks are much more trustworthy than microbenchmarks, though
microbenchmarks are often a great tool for identifying performance bottlenecks and
optimizing macrobenchmarks.

## Running many benchmarks

It's pretty straightforward to benchmark a whole parameter sweep to check performance
figures. Just invoke `@b` or `@be` repeatedly. For example, if you want to know how
allocation times vary with input size, you could run this list comprehension which runs
`@b fill(0, n)` for each power of 4 from 4 to 4^10:

```jldoctest
julia> [@b fill(0, n) for n in 4 .^ (1:10)]
10-element Vector{Chairmarks.Sample}:
 9.752 ns (2 allocs: 96 bytes)
 11.040 ns (2 allocs: 192 bytes)
 27.859 ns (2 allocs: 576 bytes)
 128.009 ns (3 allocs: 2.062 KiB)
 122.513 ns (3 allocs: 8.062 KiB)
 346.962 ns (3 allocs: 32.062 KiB)
 1.055 μs (3 allocs: 128.062 KiB)
 3.597 μs (3 allocs: 512.062 KiB)
 11.417 μs (3 allocs: 2.000 MiB)
 88.084 μs (3 allocs: 8.000 MiB)
```

The default runtime of a benchmark is 0.1 seconds, so this invocation should take just over
1 second to run. Let's verify:

```jldoctest
julia> @time [@b fill(0, n) for n in 4 .^ (1:10)];
  1.038502 seconds (27.16 M allocations: 22.065 GiB, 27.03% gc time, 3.59% compilation time)
```

If we want a wider parameter sweep, we can use the `seconds` parameter to configure how
long benchmarking will take. However, once we start setting seconds to a value below `0.1`,
the benchmarking itself becomes performance sensitive and, from
[the performance tips](https://docs.julialang.org/en/v1/manual/performance-tips/#Performance-critical-code-should-be-inside-a-function),
performance critical code should be inside a function. So we should put the call to `@b` or
`@be` into a function.

```julia-repl
julia> f(n, t) = @b fill(0, n) seconds=t
f (generic function with 1 method)

julia> @time f.(1:1000, .001)
  1.089171 seconds (20.88 M allocations: 18.901 GiB, 19.87% gc time, 1.81% compilation time)
1000-element Vector{Chairmarks.Sample}:
 10.286 ns (2 allocs: 64 bytes)
 10.628 ns (2 allocs: 80 bytes)
 10.607 ns (2 allocs: 80 bytes)
 10.723 ns (2 allocs: 96 bytes)
 ⋮
 129.294 ns (3 allocs: 7.875 KiB)
 129.294 ns (3 allocs: 7.875 KiB)
 129.471 ns (3 allocs: 7.875 KiB)
 130.570 ns (3 allocs: 7.875 KiB)
```

Setting the `seconds` parameter too low can cause benchmarks to be noisy. It's good practice
to run a benchmark at least a couple of times no matter what the configuration is to make
sure it's reasonably stable.

## Advanced usage

It is possible to manually specify the number of evaluations, samples, and/or seconds to run
benchmarking for. It is also possible to pass a teardown function or an initialization
function that runs only once. See the docstring of [`@be`](@ref) for more information on
these additional arguments.

[^1]: note that the samples are aggregated element wise, so the max field reports the maximum
    runtime and the maximum proportion of runtime spent in garbage collection (gc). Thus it
    is possible that the trial which had a 19.748 μs runtime was not the same trial that
    spent 96.95% of its time in garbage collection. This is in order to make the results
    more consistent. If half the trials spend 10% of their time in gc amd runtime varies
    based on other factors, it would be unfortunate to report maximum gc time as either 10%
    or 0% at random depending on whether the longest running trial happened to trigger gc.
