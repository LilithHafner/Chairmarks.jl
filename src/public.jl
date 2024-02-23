const DOCSTRING_BODY = """
# Positional argument pipeline syntax

The four positional arguments form a pipeline with the return value of each passed as an
argument to the next. Consequently, the first expression in the pipeline must be a nullary
function. If you use a symbol like `rand`, it will be interpreted as a function and called
normally. If you use any other expression, it will be interpreted as the body of a nullary
function. For example in `@bx rand(10)` the function being benchmarked is `() -> rand(10)`.

Later positions in the pipeline must be unary functions. As with the first function, you may
provide either a function, or an expression. However, the rules are slightly different. If
the expression you provide contains an `_` as an rvalue (which would otherwise error), it is
interpreted as a unary function and any such occurrences of `_` are replaced with result
from the previous function in the pipeline. For example, in `@bx rand(10) sort(_, rev=true)`
the setup function is `() -> rand(10)` and the primary function is `x -> sort(x, rev=true)`.
If the expression you provide does not contain an `_` as an rvalue, it is assumed to produce
a function and is called with the result from the previous function in the pipeline. For
example, in `@bx rand(10) sort!∘shuffle!`, the primary function is simply `sort!∘shuffle!`
and receives no preprocessing. `@macroexpand` can help elucidate what is going on in
specific cases.

# Positional argument disambiguation

`setup`, `teardown`, and `init` are optional and are parsed with that precedence giving
these possible forms:

    @bx f
    @bx setup f
    @bx setup f teardown
    @bx init setup f teardown

You may use an underscore `_` to provide other combinations of arguments. For example, you
may provide a `teardown` and no `setup` with

    @bx _ f teardown

# Keyword arguments

Provide keyword arguments using `name=value` syntax similar to how you provide keyword
arguments to ordinary functions. Keyword arguments to control executions are

  - `evals::Integer` How many function evaluations to perform in each sample. Defaults to
    automatic calibration.
  - `samples::Integer` Maximum number of samples to take. Defaults to unlimited and cannot
    be specified without also specifying `evals`. Specifying `samples = 0` will cause `@bx`
    to run the warmup sample only and return that sample.
  - `seconds::Real` Maximum amount of time to spend benchmarking. Defaults to `0.1` seconds
    unless `samples` is specified in which case it defaults to `1` second. Set to `Inf`
    to disable the time limit. Compile time is typically not counted against this limit.
    A reasonable effort is made to respect the time limit, but it is always exceeded by a
    small about (less than 1%) and can be significantly exceeded when benchmarking long
    running functions.

# Evaluation model

At a high level, the implementation of this function looks like this

    x = init()
    results = []
    for sample in 1:samples
        y = setup(x)

        t0 = time()

        z = f(y)
        for _ in 2:evals
            f(y)
        end

        push!(results, time()-t0)

        teardown(z)

    end

So `init` will be called once, `setup` and `teardown` will be called once per sample, and
`f` will be called `evals` times per sample.
"""

"""
    @b [[init] setup] f [teardown] keywords...

Benchmark `f` and return the fastest result

Use `@be` for full results.

$(replace(DOCSTRING_BODY, "@bx" => "@b"))

# Examples

```julia
julia> @b rand(10000) # Benchmark a function
5.833 μs (2 allocs: 78.172 KiB)

julia> @b rand hash # How long does it take to hash a random Float64?
1.757 ns

julia> @b rand(1000) sort issorted(_) || error() # Simultaneously benchmark and test
11.291 μs (3 allocs: 18.062 KiB)

julia> @b rand(1000) sort! issorted(_) || error() # BAD! This repeatedly resorts the same array!
1.309 μs (0.08 allocs: 398.769 bytes)

julia> @b rand(1000) sort! issorted(_) || error() evals=1 # Specify evals=1 to ensure the function is only run once between setup and teardown
10.041 μs (2 allocs: 10.125 KiB)

julia> @b rand(10) _ sort!∘rand! issorted(_) || error() # Or, include randomization in the benchmarked function and only allocate once
120.536 ns

julia> @b (x = 0; for _ in 1:50; x = hash(x); end; x) # We can use arbitrary expressions in any position in the pipeline, not just simple functions.
183.871 ns

julia> @b (x = 0; for _ in 1:5e8; x = hash(x); end; x) # This runs for a long time, so it is only run once (with no warmup)
2.447 s (without a warmup)
```
"""
macro b(args...)
    call = process_args(args)
    :(minimum($(call)))
end

"""
    @be [[init] setup] f [teardown] keywords...

Benchmark `f` and return the results

Use `@b` for abbreviated results.

$(replace(DOCSTRING_BODY, "@bx" => "@be"))

# Examples

```julia
julia> @be rand(10000) # Benchmark a function
Benchmark: 267 samples with 2 evaluations
min    8.500 μs (2 allocs: 78.172 KiB)
median 10.354 μs (2 allocs: 78.172 KiB)
mean   159.639 μs (2 allocs: 78.172 KiB, 0.37% gc time)
max    39.579 ms (2 allocs: 78.172 KiB, 99.93% gc time)

julia> @be rand hash # How long does it take to hash a random Float64?
Benchmark: 4967 samples with 10805 evaluations
min    1.758 ns
median 1.774 ns
mean   1.820 ns
max    5.279 ns

julia> @be rand(1000) sort issorted(_) || error() # Simultaneously benchmark and test
Benchmark: 2689 samples with 2 evaluations
min    9.771 μs (3 allocs: 18.062 KiB)
median 11.562 μs (3 allocs: 18.062 KiB)
mean   14.933 μs (3 allocs: 18.097 KiB, 0.04% gc time)
max    4.916 ms (3 allocs: 20.062 KiB, 99.52% gc time)

julia> @be rand(1000) sort! issorted(_) || error() # BAD! This repeatedly resorts the same array!
Benchmark: 2850 samples with 13 evaluations
min    1.647 μs (0.15 allocs: 797.538 bytes)
median 1.971 μs (0.15 allocs: 797.538 bytes)
mean   2.212 μs (0.15 allocs: 800.745 bytes, 0.03% gc time)
max    262.163 μs (0.15 allocs: 955.077 bytes, 98.95% gc time)

julia> @be rand(1000) sort! issorted(_) || error() evals=1 # Specify evals=1 to ensure the function is only run once between setup and teardown
Benchmark: 6015 samples with 1 evaluation
min    9.666 μs (2 allocs: 10.125 KiB)
median 10.916 μs (2 allocs: 10.125 KiB)
mean   12.330 μs (2 allocs: 10.159 KiB, 0.02% gc time)
max    6.883 ms (2 allocs: 12.125 KiB, 99.56% gc time)

julia> @be rand(10) _ sort!∘rand! issorted(_) || error() # Or, include randomization in the benchmarked function and only allocate once
Benchmark: 3093 samples with 237 evaluations
min    121.308 ns
median 126.055 ns
mean   128.108 ns
max    303.447 ns

julia> @be (x = 0; for _ in 1:50; x = hash(x); end; x) # We can use arbitrary expressions in any position in the pipeline, not just simple functions.
Benchmark: 3387 samples with 144 evaluations
min    183.160 ns
median 184.611 ns
mean   188.869 ns
max    541.667 ns

julia> @be (x = 0; for _ in 1:5e8; x = hash(x); end; x) # This runs for a long time, so it is only run once (with no warmup)
Benchmark: 1 sample with 1 evaluation
       2.488 s (without a warmup)
```
"""
macro be(args...)
    process_args(args)
end


