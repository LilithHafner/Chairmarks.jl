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

!!! Warning "This is not part of the API"
    The things listed on this page are true (or should be fixed) but are not guarantees.
    They may change in future 1.x releases.

## Why the name "Chairmarks.jl"?

The obvious and formulaic choice, [Benchmarks.jl](https://github.com/johnmyleswhite/Benchmarks.jl),
was taken. This package is very similar to Benchmarks.jl and BenchmarkTools.jl, but has a
significantly different implementation and a distinct API. When differentiating multiple
similar things, I prefer distinctive names over synonyms or different parts of speech. The
difference between the names should, if possible, reflect the difference in the concepts,
and if that's not possible, it should be clear that the difference between the names does
not reflect the difference between concepts. This rules out most names like "Benchmarker",
"Benchmarking", "BenchmarkSystem", etc. I could have chosen "EfficientBenchmarks.jl", but
that is pretty pretentious and also would become misleading of "BenchmarkTools.jl" becomes
more efficient in the future.

Ultimately, I decided to follow Julia's
[package naming conventions](https://docs.julialang.org/en/v1.12-dev/tutorials/creating-packages/#Package-naming-guidelines)
and heed teh advice that

> A less systematic name may suit a package that implements one of several possible approaches to its domain.

## How is this faster than BenchmarkTools?

A few reasons
- Chairmarks doesn't run garbage collection between each sample by default
- Chairmarks has faster and more efficient auto-tuning
- Chairmarks runs its arguments as functions in the scope that the benchmark was invoked
  from, rather than `eval`ing them at global scope. This makes it possible to get
  significant performance speedups for fast benchmarks by putting the benchmarking itself
  into a function. It also avoids leaking memory on repeated invocations of a benchmark,
  which is unavoidable with BenchmarkTools.jl's design.
  ([discourse](https://discourse.julialang.org/t/memory-leak-with-benchmarktools/31282),
  [github](https://github.com/JuliaCI/BenchmarkTools.jl/issues/339))
- Because Charimarks does not use toplevel eval, it can run arbitrarily quickly, as limited
  by a user's noise tolerance. Consequently, I spend time tuning the auto-tuning algorithm
  for low benchmarking runtime budgets in addition to long runtimes so its precision doesn't
  degrade too much at low runtimes.
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

## How does tuning work?

First of all, what is "tuning" for? It's for tuning the number of evaluations per sample.
We want the total runtime of a sample to be 30μs, which makes the noise of instrumentation
itself (clock precision, the time to takes to record performance counters, etc.) negligible.
If the user specifies `evals` manually, then there is nothing to tune, so we do a single
warmup and then jump straight to the benchmark. In the benchmark, we run samples until the
time budget or sample budget is exhausted.

If `evals` is not provided and `seconds` is (by default we have `seconds=0.1`), then we
target spending 5% of the time budget on calibration. We have a multi-phase approach where
we start by running the function just once, use that to decide the order of the bnechmark
and how much additional calibration is needed. See
https://github.com/LilithHafner/Chairmarks.jl/blob/main/src/benchmarking.jl for details.
