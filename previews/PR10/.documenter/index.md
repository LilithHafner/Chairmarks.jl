


# Chairmarks {#Chairmarks}

[Chairmarks.jl](https://github.com/LilithHafner/Chairmarks.jl) provides benchmarks with back support. Often hundreds of times faster than BenchmarkTools.jl without compromising on accuracy.

## Precise {#Precise}

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


## Concise {#Concise}

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


See [`@b`](/index#Chairmarks.@b-Tuple) for more info

## Truthful {#Truthful}

Charimarks.jl automatically computes a checksum based on the results of the provided computations, and returns that checksum to the user along with benchmark results. This makes it impossible for the compiler to elide any part of the computation that has an impact on its return value.

While the checksums are fast, one negative side effect of this is that they add a bit of overhead to the measured runtime, and that overhead can vary depending on the function being benchmarked. These checksums are performed by computing a map over the returned values and a reduction over those mapped values. You can disable this by passing the `checksum=false` keyword argument, possibly in combination with a custom teardown function that verifies computation results. Be aware that as the compiler improves, it may become better at eliding benchmarks whose results are not saved.

```julia
julia> @b 1
0.713 ns

julia> @b 1.0
1.135 ns

julia> @b 1.0 checksum=false
0 ns
```


You may experiment with custom reductions using the internal _map and _reduction keyword arguments. The default maps and reductions (`Chairmarks.default_map`and`Chairmarks.default_reduction`) are internal and subject to change and/or removal in future.

## Efficient {#Efficient}

|                                                                                             | Chairmarks.jl | BenchmarkTools.jl |   Ratio |
| -------------------------------------------------------------------------------------------:| -------------:| -----------------:| -------:|
| [TTFX](https://github.com/LilithHafner/Chairmarks.jl/blob/main/contrib/ttfx_rm_rf_julia.sh) |          3.4s |             13.4s |      4x |
|                                                                                   Load time |         4.2ms |             131ms |     31x |
|                                                              TTFX excluding precompile time |          43ms |            1118ms |     26x |
|                                                                             minimum runtime |          34μs |             459ms | 13,500x |
|                                                                                       Width |        Narrow |              Wide |    2–4x |
|                                                                                Back Support | Almost Always |         Sometimes |     N/A |


## Installation / Integrating Chairmarks into your workflow {#Installation}

### For interactive use {#For-interactive-use}

There are several ways to use Chairmarks in your interactive sessions, ordered from simplest to install first to most streamlined user experience last.
1. Add Chairmarks to your default environment with `import Pkg; Pkg.activate(); Pkg.add("Chairmarks")`. Chairmarks has no non-stdlib dependencies, and precompiles in less than one second, so this should not have any adverse impacts on your environments nor slow load times nor package instillation times.
  
1. Add Chairmarks to your default environment and put `isinteractive() && using Chairmarks` in your startup.jl file. This will make Chairmarks available in all your REPL sessions while still requiring and explicit load in scripts and packages. This will slow down launching a new Julia session by a few milliseconds (for comparison, this is about 20x faster than loading `Revise` in your startup.jl file).
  
1. [**Recommended**] Add Chairmarks to your default environment and put the following script in your startup.jl file to automatically load it when you type `@b` or `@be` in the REPL:
  

```julia
if isinteractive() && (local REPL = get(Base.loaded_modules, Base.PkgId(Base.UUID("3fa0cd96-eef1-5676-8a61-b3b8758bbffb"), "REPL"), nothing); REPL !== nothing)
    # https://github.com/fredrikekre/.dotfiles/blob/65b96f492da775702c05dd2fd460055f0706457b/.julia/config/startup.jl
    # Automatically load tooling on demand. These packages should be stdlibs or part of the default environment.
    # - Chairmarks.jl when encountering @b or @be
    # - add more as desired...
    local tooling = [
        ["@b", "@be"] => :Chairmarks,
        # add more here...
    ]

    local tooling_dict = Dict(Symbol(k) => v for (ks, v) in tooling for k in ks)
    function load_tools(ast)
        if ast isa Expr
            if ast.head === :macrocall
                pkg = get(tooling_dict, ast.args[1], nothing)
                if pkg !== nothing && !isdefined(Main, pkg)
                    @info "Loading $pkg ..."
                    try
                        Core.eval(Main, :(using $pkg))
                    catch err
                        @info "Failed to automatically load $pkg" exception=err
                    end
                end
            end
            foreach(load_tools, ast.args)
        end
        ast
    end

    pushfirst!(REPL.repl_ast_transforms, load_tools)
end
```


### For regression testing {#For-regression-testing}

Use [`RegressionTests.jl`](https://github.com/LilithHafner/RegressionTests.jl)! Make a file `bench/runbenchmarks.jl` with the following content:

```julia
using Chairmarks, RegressionTests
using MyPackage

@track @be MyPackage.compute_thing(1)
@track @be MyPackage.compute_thing(1000)
```


And add the following to your `test/runtests.jl`:

```julia
using RegressionTests

@testset "Regression tests" begin
    RegressionTests.test(skip_unsupported_platforms=true)
end
```


See the [RegressionTests.jl documentation](https://github.com/LilithHafner/RegressionTests.jl) for more information.
- [`Chairmarks.Sample`](#Chairmarks.Sample)
- [`Chairmarks.@b`](#Chairmarks.@b-Tuple)
- [`Chairmarks.@be`](#Chairmarks.@be-Tuple)

<div style='border-width:1px; border-style:solid; border-color:black; padding: 1em; border-radius: 25px;'>
<a id='Chairmarks.Sample' href='#Chairmarks.Sample'>#</a>&nbsp;<b><u>Chairmarks.Sample</u></b> &mdash; <i>Type</i>.




```julia
Sample
```


A struct representing a single sample of a benchmark. The fields are internal and subject to change.


[source](https://github.com/LilithHafner/Chairmarks.jl/blob/708e056c366cf799f6d547ba2807b1a0c9c13d35/src/types.jl#L1-L6)

</div>
<br>
<div style='border-width:1px; border-style:solid; border-color:black; padding: 1em; border-radius: 25px;'>
<a id='Chairmarks.@b-Tuple' href='#Chairmarks.@b-Tuple'>#</a>&nbsp;<b><u>Chairmarks.@b</u></b> &mdash; <i>Macro</i>.




```julia
@b [[init] setup] f [teardown] keywords...
```


Benchmark `f` and return the fastest result

Use `@be` for full results.

**Positional argument pipeline syntax**

The four positional arguments form a pipeline with the return value of each passed as an argument to the next. Consequently, the first expression in the pipeline must be a nullary function. If you use a symbol like `rand`, it will be interpreted as a function and called normally. If you use any other expression, it will be interpreted as the body of a nullary function. For example in `@b rand(10)` the function being benchmarked is `() -> rand(10)`.

Later positions in the pipeline must be unary functions. As with the first function, you may provide either a function, or an expression. However, the rules are slightly different. If the expression you provide contains an `_` as an rvalue (which would otherwise error), it is interpreted as a unary function and any such occurrences of `_` are replaced with result from the previous function in the pipeline. For example, in `@b rand(10) sort(_, rev=true)` the setup function is `() -> rand(10)` and the primary function is `x -> sort(x, rev=true)`. If the expression you provide does not contain an `_` as an rvalue, it is assumed to produce a function and is called with the result from the previous function in the pipeline. For example, in `@b rand(10) sort!∘shuffle!`, the primary function is simply `sort!∘shuffle!` and receives no preprocessing. `@macroexpand` can help elucidate what is going on in specific cases.

**Positional argument disambiguation**

`setup`, `teardown`, and `init` are optional and are parsed with that precedence giving these possible forms:

```
@b f
@b setup f
@b setup f teardown
@b init setup f teardown
```


You may use an underscore `_` to provide other combinations of arguments. For example, you may provide a `teardown` and no `setup` with

```
@b _ f teardown
```


**Keyword arguments**

Provide keyword arguments using `name=value` syntax similar to how you provide keyword arguments to ordinary functions. Keyword arguments to control executions are
- `evals::Integer` How many function evaluations to perform in each sample. Defaults to automatic calibration.
  
- `samples::Integer` Maximum number of samples to take. Defaults to unlimited and cannot be specified without also specifying `evals`. Specifying `samples = 0` will cause `@b` to run the warmup sample only and return that sample.
  
- `seconds::Real` Maximum amount of time to spend benchmarking. Defaults to `0.1` seconds unless `samples` is specified in which case it defaults to `1` second. Set to `Inf` to disable the time limit. Compile time is typically not counted against this limit. A reasonable effort is made to respect the time limit, but it is always exceeded by a small about (less than 1%) and can be significantly exceeded when benchmarking long running functions.
  

**Evaluation model**

At a high level, the implementation of this function looks like this

```
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
```


So `init` will be called once, `setup` and `teardown` will be called once per sample, and `f` will be called `evals` times per sample.

**Examples**

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



[source](https://github.com/LilithHafner/Chairmarks.jl/blob/708e056c366cf799f6d547ba2807b1a0c9c13d35/src/public.jl#L80-L116)

</div>
<br>
<div style='border-width:1px; border-style:solid; border-color:black; padding: 1em; border-radius: 25px;'>
<a id='Chairmarks.@be-Tuple' href='#Chairmarks.@be-Tuple'>#</a>&nbsp;<b><u>Chairmarks.@be</u></b> &mdash; <i>Macro</i>.




```julia
@be [[init] setup] f [teardown] keywords...
```


Benchmark `f` and return the results

Use `@b` for abbreviated results.

**Positional argument pipeline syntax**

The four positional arguments form a pipeline with the return value of each passed as an argument to the next. Consequently, the first expression in the pipeline must be a nullary function. If you use a symbol like `rand`, it will be interpreted as a function and called normally. If you use any other expression, it will be interpreted as the body of a nullary function. For example in `@be rand(10)` the function being benchmarked is `() -> rand(10)`.

Later positions in the pipeline must be unary functions. As with the first function, you may provide either a function, or an expression. However, the rules are slightly different. If the expression you provide contains an `_` as an rvalue (which would otherwise error), it is interpreted as a unary function and any such occurrences of `_` are replaced with result from the previous function in the pipeline. For example, in `@be rand(10) sort(_, rev=true)` the setup function is `() -> rand(10)` and the primary function is `x -> sort(x, rev=true)`. If the expression you provide does not contain an `_` as an rvalue, it is assumed to produce a function and is called with the result from the previous function in the pipeline. For example, in `@be rand(10) sort!∘shuffle!`, the primary function is simply `sort!∘shuffle!` and receives no preprocessing. `@macroexpand` can help elucidate what is going on in specific cases.

**Positional argument disambiguation**

`setup`, `teardown`, and `init` are optional and are parsed with that precedence giving these possible forms:

```
@be f
@be setup f
@be setup f teardown
@be init setup f teardown
```


You may use an underscore `_` to provide other combinations of arguments. For example, you may provide a `teardown` and no `setup` with

```
@be _ f teardown
```


**Keyword arguments**

Provide keyword arguments using `name=value` syntax similar to how you provide keyword arguments to ordinary functions. Keyword arguments to control executions are
- `evals::Integer` How many function evaluations to perform in each sample. Defaults to automatic calibration.
  
- `samples::Integer` Maximum number of samples to take. Defaults to unlimited and cannot be specified without also specifying `evals`. Specifying `samples = 0` will cause `@be` to run the warmup sample only and return that sample.
  
- `seconds::Real` Maximum amount of time to spend benchmarking. Defaults to `0.1` seconds unless `samples` is specified in which case it defaults to `1` second. Set to `Inf` to disable the time limit. Compile time is typically not counted against this limit. A reasonable effort is made to respect the time limit, but it is always exceeded by a small about (less than 1%) and can be significantly exceeded when benchmarking long running functions.
  

**Evaluation model**

At a high level, the implementation of this function looks like this

```
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
```


So `init` will be called once, `setup` and `teardown` will be called once per sample, and `f` will be called `evals` times per sample.

**Examples**

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



[source](https://github.com/LilithHafner/Chairmarks.jl/blob/708e056c366cf799f6d547ba2807b1a0c9c13d35/src/public.jl#L122-L187)

</div>
<br>

## Migrating from BenchmarkTools.jl {#Migrating-from-BenchmarkTools.jl}

Chairmarks.jl has a similar samples/evals model to BenchmarkTools. It preserves the keyword arguments `samples`, `evals`, and `seconds`. Unlike BenchmarkTools.jl, the `seconds` argument is honored even as it drops down to the order of 30μs (`@b @b hash(rand()) seconds=.00003`). While accuracy does decay as the total number of evaluations and samples decreases, it remains quite reasonable (e.g. I see a noise of about 30% when benchmarking `@b hash(rand()) seconds=.00003`). This makes it much more reasonable to perform meta-analysis such as computing the time it takes to hash a thousand different lengthed arrays with `[@b hash(rand(n)) seconds=.001 for n in 1:1000]`.

Both BenchmarkTools.jl and Chairmarks.jl use an evaluation model structured like this:

```julia
init()
samples = []
for _ in 1:samples
    setup()
    t0 = time()
    for _ in 1:evals
        f()
    end
    t1 = time()
    push!(samples, t1 - t0)
    teardown()
end
return samples
```


In BenchmarkTools, you specify `f` and `setup` with the invocation `@benchmark f setup=(setup)`. In Chairmarks, you specify `f` and `setup` with the invocation `@be setup f`. In BenchmarkTools, `setup` and `f` communicate via shared local variables in code generated by BenchmarkTools.jl. In Chairmarks, the function `f` is passed the return value of the function `setup` as an argument. Chairmarks also lets you specify `teardown`, which is not possible with BenchmarkTools, and an `init` which can be emulated with interpolation using BenchmarkTools.

Here are some examples of corresponding invocations in BenchmarkTools.jl and Chairmarks.jl:

|                                                                          BenchmarkTools.jl |                                                  Charimarks |
| ------------------------------------------------------------------------------------------:| -----------------------------------------------------------:|
|                                                                           `@btime rand();` |                                                 `@b rand()` |
|                                             `@btime sort!(x) setup=(x=rand(100)) evals=1;` |                                `@b rand(100) sort! evals=1` |
|                                   `@btime sort!(x, rev=true) setup=(x=rand(100)) evals=1;` |                   `@b rand(100) sort!(_, rev=true) evals=1` |
|                       `@btime issorted(sort!(x)) \|\| error() setup=(x=rand(100)) evals=1` |       `@b rand(100) sort! issorted(_) \|\| error() evals=1` |
| `let X = rand(100); @btime issorted(sort!($X)) \|\| error() setup=(rand!($X)) evals=1 end` | `@b rand(100) rand! sort! issorted(_) \|\| error() evals=1` |


For automated regression tests, [RegressionTests.jl](https://github.com/LilithHafner/RegressionTests.jl) is a work in progress replacement for the `BenchmarkGroup` and `@benchmarkable` system. Because Chairmarks is efficiently and stably autotuned and RegressionTests.jl is inherently robust to noise, there is no need for parameter caching.

### Toplevel API {#Toplevel-API}

Chairmarks always returns the benchmark result, while BenchmarkTools mirrors the more diverse base API.

|        BenchmarkTools |       Chairmarks |         Base |
| ---------------------:| ----------------:| ------------:|
| minimum(@benchmark _) |               @b |          N/A |
|            @benchmark |              @be |          N/A |
|             @belapsed |      (@b _).time |     @elapsed |
|                @btime | display(@b _); _ |        @time |
|                   N/A |    (@b _).allocs | @allocations |
|           @ballocated |     (@b _).bytes |   @allocated |


Chairmarks may provide `@belapsed`, `@btime`, `@ballocated`, and `@ballocations` in the future.

### Fields {#Fields}

Benchmark results have the following fields:

| Chairmarks           | BenchmarkTools    | Description            | |–––––––––––|––––––- ––-|––––––––––––| | x.time               | x.time_1e9        | Runtime in seconds     | | x.time/1e9           | x.time            | Runtime in nanoseconds | | x.allocs             | x.allocs          | Number of allocations  | | x.bytes              | x.memory          | Number of bytes allocated across all allocations | | x.gc_fraction        | x.gctime / x.time | Fraction of time spent in garbage collection | | x.gc_time_x.time     | x.gctime          | Time spent in garbage collection | | x.compile_fraction   | N/A               | Fraction of time spent compiling | | x.recompile_fraction | N/A               | Fraction of time spent compiling which was on recompilation | | x.warmup             | true              | weather or not the sample had a warmup run before it | | x.checksum           | N/A               | a checksum computed from the return values of the benchmarked code | | x.evals              | x.params.evals    | the number of evaluations in the sample |

Note that these fields are likely to change in Chairmarks 1.0.

### Nonconstant globals and interpolation {#Nonconstant-globals-and-interpolation}

The arguments to Chairmarks.jl are lowered to functions, not quoted expressions. Consequently, there is no need to interpolate variables and interpolation is therefore not supported. Like BenchmarkTools.jl, benchmarks that includes access to nonconstant globals will receive a performance overhead for that access. Two possible ways to avoid this are to make the global constant, and to include it in the setup or initiaization phase. For example,

```julia
julia> x = 6 # nonconstant global
6

julia> @b rand(x) # slow
39.616 ns (1.02 allocs: 112.630 bytes)

julia> @b x rand # fast
18.939 ns (1 allocs: 112 bytes)

julia> const X = x
6

julia> @b rand(X) # fast
18.860 ns (1 allocs: 112 bytes)
```

