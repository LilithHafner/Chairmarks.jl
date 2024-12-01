```@meta
CurrentModule = Chairmarks
DocTestSetup = quote
    using Chairmarks
end
DocTestFilters = [r"\d\d?\d?\.\d{3} [μmn]?s( \(.*\))?"]
```

# Explanation of design decisions

This page of the documentation is not targeted at teaching folks how to use this package.
Instead, it is designed to offer insight into how the the internals work, why I made certain
design decisions. That said, it certainly won't hurt your user experience to read this!

!!! warning "This is not part of the API"
    The things listed on this page are true (or should be fixed) but are not guarantees.
    They may change in future 1.x releases.

## Why the name "Chairmarks.jl"?

The obvious and formulaic choice, [Benchmarks.jl](https://github.com/johnmyleswhite/Benchmarks.jl),
was taken. This package is very similar to Benchmarks.jl and BenchmarkTools.jl, but has a
significantly different implementation and a distinct API. When differentiating multiple
similar things, I prefer distinctive names over synonyms or different parts of speech. The
difference between the names should, if possible, reflect the difference in the concepts. If
that's not possible, it should be clear that the difference between the names does not
reflect the difference between concepts. This rules out most names like "Benchmarker.jl",
"Benchmarking.jl", "BenchmarkSystem.jl", etc. I could have chosen "EfficientBenchmarks.jl",
but that is pretty pretentious and also would become misleading if "BenchmarkTools.jl"
becomes more efficient in the future.

Ultimately, I decided to follow Julia's
[package naming conventions](https://pkgdocs.julialang.org/v1/creating-packages/#Package-naming-guidelines)
and heed the advice that

> A less systematic name may suit a package that implements one of several possible approaches to its domain.

## How is this faster than BenchmarkTools?

A few reasons
- Chairmarks doesn't run garbage collection at the start of every benchmark by default
- Chairmarks has faster and more efficient auto-tuning
- Chairmarks runs its arguments as functions in the scope that the benchmark was invoked
  from, rather than `eval`ing them at global scope. This makes it possible to get
  significant performance speedups for fast benchmarks by putting the benchmarking itself
  into a function. It also avoids leaking memory on repeated invocations of a benchmark,
  which is unavoidable with BenchmarkTools.jl's design.
  ([discourse](https://discourse.julialang.org/t/memory-leak-with-benchmarktools/31282),
  [github](https://github.com/JuliaCI/BenchmarkTools.jl/issues/339))
- Because Charimarks does not use toplevel eval, it can run arbitrarily quickly, as limited
  by a user's noise tolerance. Consequently, the auto-tuning algorithm is tuned for low
  runtime budgets in addition to high budgets so its precision doesn't degrade too much at
  low runtime budgets.
- Chairmarks tries very hard not to discard data. For example, if your function takes longer
  to evaluate then the runtime budget, Chairmarks will simply report the warmup runtime
  (with a disclaimer that there was no warmup). This makes Chairmarks a viable complete
  substitute for the trivial `@time` macro and friends. `@b sleep(10)` takes 10.05 seconds
  (just like `@time sleep(10)`), whereas `@benchmark sleep(10)` takes 30.6 seconds despite
  only reporting one sample.

## Is this as stable/reliable as BenchmarkTools?

When comparing `@b` to `@btime` with `seconds=.5` or more, yes: result stability should be
comparable. Any deficiency in precision or reliability compared to BenchmarkTools is a
problem and should be reported. When `seconds` is less than about `0.5`, BenchmarkTools
stops respecting the requested runtime budget and so it could very well perform much more
precisely than Chairmarks (it's hard to compete with a 500ms benchmark when you only have
1ms). In practice, however, Chairmarks stays pretty reliable even for fairly low runtimes.

When comparing different implementations of the same function, `@b rand f,g` can be more reliable
than `judge(minimum(@benchmark(f(x) setup=(x=rand()))), minimum(@benchmark(g(x) setup=(x=rand())))`
because the former randomly interleaves calls to `f` and `g` in the same context and scope
with the same inputs while the latter runs all evaluations of `f` before all evaluations of
`g` and—typically less importantly—uses different random inputs.

!!! warning
    Comparative benchmarking is experimental and may be removed or changed in future versions

## How does tuning work?

First of all, what is "tuning" for? It's for tuning the number of evaluations per sample.
We want the total runtime of a sample to be 30μs, which makes the noise of instrumentation
itself (clock precision, the time to takes to record performance counters, etc.) negligible.
If the user specifies `evals` manually, then there is nothing to tune, so we do a single
warmup and then jump straight to the benchmark. In the benchmark, we run samples until the
time budget or sample budget is exhausted.

If `evals` is not provided and `seconds` is (by default we have `seconds=0.1`), then we
target spending 5% of the time budget on calibration. We have a multi-phase approach where
we start by running the function just once, use that to decide the order of the benchmark
and how much additional calibration is needed. See
[https://github.com/LilithHafner/Chairmarks.jl/blob/main/src/benchmarking.jl](https://github.com/LilithHafner/Chairmarks.jl/blob/main/src/benchmarking.jl)
for details.

## Why Chairmarks uses soft semantic versioning

We prioritize human experience (both user and developer) over formal guarantees. Where
formal guarantees improve the experience of folks using this package, we will try to make
and adhere to them. Under both soft and traditional semantic versioning, the
version number is primarily used to communicate to users whether a release is breaking. If
Chairmarks had an infinite number of users, all of whom respected the formal API by only
depending on formally documented behavior, then soft semantic versioning would be equivalent
to traditional semantic versioning. However, as the user base differs from that theoretical
ideal, so too does the most effective way of communicating which releases are breaking. For
example, if version 1.1.0 documents that "the default runtime is 0.1 seconds" and a new
version allows users to control this with a global variable, then that change does break the
guarantee that the default runtime is 0.1 seconds. However, it still makes sense to release
as 1.2.0 rather than 2.0.0 because it is less disruptive to users to have that technical
breakage than to have to review the changelog for breakage and decide whether to update
their compatibility statements or not.

# Departures from BenchmarkTools

When there are conflicts between compatibility/alignment with `BenchmarkTools` and
producing the best experience I can for folks who are not coming for BenchmarkTools or using
BenchmarkTools simultaneously, I put much more weight on the latter. One reason for this is
folks who want something like BenchmarkTools should use BenchmarkTools. It's a great package
that is reliable, mature, and has been stable for a long time. A diversity of design choices
lets users pick packages based on their own preferences. Another reason for this is that I
aim to work toward the best long term benchmarking solution possible (perhaps in some years
there will come a time where another package makes both BenchmarkTools.jl and Chairmarks.jl
obsolete). To this end, carrying forward design choices I disagree with is not beneficial.
All that said, I do _not_ want to break compatibility or change style just to stand out.
Almost all of BenchmarkTools' design decisions are solid and worth copying. Things like
automatic tuning, the ability to bypass that automatic tuning, a split evals/samples
structure, the ability to run untimed setup code before each sample, and many more mundane
details we take for granted were once clever design decisions made in BenchmarkTools or its
predecessors.

Below, I'll list some specific design departures and why I made them

## Macro names

Chairmarks uses the abbreviated macros `@b` and `@be`. Descriptive names are almost always
better than terse one-letter names. However I maintain that macros defined in packages and
designed to be typed repeatedly at the REPL are one of the few exceptions to this "almost
always". At the REPL, these macros are often typed once and never read. In this case,
concision does matter and readability does not. When naming these macros I anticipated that
REPL usage would be much more common than usage in packages or reused scripts. However, if
and as this changes it may be worth adding longer names for them and possibly restricting
the shorter names to interactive use only.

## Return style

`@be`, like `BenchmarkTools.@benchmark`, returns a `Benchmark` object. `@b`, unlike
`BenchmarkTools.@btime` returns a composite sample formed by computing the minimum statistic
over the benchmark, rather than returning the expression result and printing runtime
statistics. The reason I originally considered making this decision is that typed
`@btime sort!(x) setup=(x=rand(1000)) evals=1` into the REPL and seen the whole screen fill
with random numbers too many times. Let's also consider the etymology of `@time` to justify
this decision further. `@time` is a lovely macro that can be placed around an arbitrary
long-running chunk of code or expression to report its runtime to stdout. `@time` is the
print statement of profiling. `@btime` and `@b` can very much _not_ fill that role for three
major reasons: first, most long-running code has side effects, and those macros run the code
repeatedly, which could break things that rely on their side effects; second, `@btime`, and
to a lesser extent `@b`, take ages to run; and third, only applying to `@btime`, `@btime`
runs its body in global scope, not the scope of the caller. `@btime` and `@b` are not
noninvasive tools to measure runtime of a portion of an algorithm, they are top-level macros
to measure the runtime of an expression or function call. Their primary result is the
runtime statistics of expression under benchmarking and the conventional way to report the
primary result of a macro of function call to the calling context is with a return value.
Consequently `@b` returns an aggregated benchmark result rather than following the pattern
of `@btime`.

If you are writing a script that computes some values and want to display those values to
the user, you generally have to call display. Chairmarks in not an exception. If it were
possible, I would consider special-casing `@show @b blah`.

## Display format

Chairmarks's display format is differs slightly from BenchmarkTools' display format. The
indentation differences are to make sure Chairmarks is internally consistent and the choice
of information displayed differs because Chairmarks has more types of information to display
than BenchmarkTools.

`@btime` displays with a leading space while `@b` does not. No Julia objects that I know of
`display`s with a leading space on the first line. `Sample` (returned by `@b`) is no
different. See [above](#return-style) for why `@b` returns a `Sample` instead of displaying
in the style of `@time`.

BenchmarkTools.jl's short display mode (`@btime`) displays runtime and allocations.
Chairmark's short display mode (displaying a sample, or simply `@b` at the REPL) follows
`Base.@time` instead and captures a wide variety of information, displaying only nonzero
values. Here's a selection of the diversity of information Charimarks makes available to
users, paired with how BenchmarkTools treats the same expressions:

```julia
julia> @b 1+1
1.132 ns

julia> @btime 1+1;
  1.125 ns (0 allocations: 0 bytes)

julia> @b rand(10)
48.890 ns (1 allocs: 144 bytes)

julia> @btime rand(10);
  46.812 ns (1 allocation: 144 bytes)

julia> @b rand(10_000_000)
11.321 ms (2 allocs: 76.294 MiB, 17.34% gc time)

julia> @btime rand(10_000_000);
  9.028 ms (2 allocations: 76.29 MiB)

julia> @b @eval begin f(x) = x+1; f(1) end
1.237 ms (632 allocs: 41.438 KiB, 70.73% compile time)

julia> @btime @eval begin f(x) = x+1; f(1) end;
  1.421 ms (625 allocations: 41.27 KiB)

julia> @b sleep(1)
1.002 s (4 allocs: 112 bytes, without a warmup)

julia> @btime sleep(1)
  1.002 s (4 allocations: 112 bytes)
```

It would be a loss restrict ourselves to only runtime and allocations, it would be
distracting to include "0% compilation time" in outputs which have zero compile time, and it
would be inconsistent to make some fields (e.g. allocation count and amount) always display
while others are only displayed when non-zero. Sparse display is the compromise I've chosen
to get the best of both worlds.
