```@meta
CurrentModule = Chairmarks
DocTestSetup = quote
    using Chairmarks
end
DocTestFilters = [r"\d\d?\d?\.\d{3} [μmn]?s( \(.*\))?"]
```

# Chairmarks

[Chairmarks.jl](https://github.com/LilithHafner/Chairmarks.jl) provides benchmarks with back support. Often hundreds of times faster than BenchmarkTools.jl without compromising on accuracy.

## Precise

Capable of detecting 1% difference in runtime in ideal conditions

```jldoctest
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

## Concise

Chairmarks uses a concise pipeline syntax to define benchmarks. When providing a single argument, that argument is automatically wrapped in a function for higher performance and executed

```jldoctest
julia> @b sort(rand(100))
1.500 μs (3 allocs: 2.625 KiB)
```

When providing two arguments, the first is setup code and only the runtime of the second is measured

```jldoctest
julia> @b rand(100) sort
1.018 μs (2 allocs: 1.750 KiB)
```

You may use `_` in the later arguments to refer to the output of previous arguments

```jldoctest
julia> @b rand(100) sort(_, by=x -> exp(-x))
5.521 μs (2 allocs: 1.750 KiB)
```

A third argument can run a "teardown" function to integrate testing into the benchmark and ensure that the benchmarked code is behaving correctly

```jldoctest
julia> @b rand(100) sort(_, by=x -> exp(-x)) issorted(_) || error()
ERROR:
Stacktrace:
 [1] error()
[...]

julia> @b rand(100) sort(_, by=x -> exp(-x)) issorted(_, rev=true) || error()
5.358 μs (2 allocs: 1.750 KiB)
```

See [`@b`](@ref) for more info

## Truthful

Charimarks.jl automatically computes a checksum based on the results of the provided
computations, and returns that checksum to the user along with benchmark results. This makes
it impossible for the compiler to elide any part of the computation that has an impact on
its return value.

While the checksums are fast, one negative side effect of this is that they add a bit of
overhead to the measured runtime, and that overhead can vary depending on the function being
benchmarked. These checksums are performed by computing a map over the returned values and a
reduction over those mapped values. You can disable this by overwriting the map with
something trivial. For example, `map=Returns(nothing)`, possibly in combination with a
custom teardown function that verifies computation results. Be aware that as the compiler
improves, it may become better at eliding benchmarks whose results are not saved.

```jldoctest; filters=r"\d\d?\d?\.\d{3} [μmn]?s( \(.*\))?|0 ns|<0.001 ns"
julia> @b 1
0.713 ns

julia> @b 1.0
1.135 ns

julia> @b 1.0 map=Returns(nothing)
0 ns
```

## Efficient

|           | Chairmarks.jl | BenchmarkTools.jl | Ratio
|-----------|--------|---------------|--------|
|[TTFX](https://github.com/LilithHafner/Chairmarks.jl/blob/main/contrib/ttfx_rm_rf_julia.sh) | 3.4s | 13.4s | 4x
| Load time | 4.2ms | 131ms | 31x
| TTFX excluding precompile time | 43ms | 1118ms | 26x
| minimum runtime | 34μs | 459ms | 13,500x
|Width | Narrow   | Wide     |     2–4x
|Back Support | Almost Always | Sometimes | N/A

## [Installation / Integrating Chairmarks into your workflow](@id Installation)

### For interactive use

There are several ways to use Chairmarks in your interactive sessions, ordered from simplest
to install first to most streamlined user experience last.

1. Add Chairmarks to your default environment with `import Pkg; Pkg.activate(); Pkg.add("Chairmarks")`.
Chairmarks has no non-stdlib dependencies, and precompiles in less than one second, so this
should not have any adverse impacts on your environments nor slow load times nor package
instillation times.

2. Add Chairmarks to your default environment and put `isinteractive() && using Chairmarks`
in your startup.jl file. This will make Chairmarks available in all your REPL sessions
while still requiring and explicit load in scripts and packages. This will slow down
launching a new Julia session by a few milliseconds (for comparison, this is about 20x
faster than loading `Revise` in your startup.jl file).

3. **Recommended** Add Chairmarks to your default environment and put the following script in your
startup.jl file to automatically load it when you type `@b` or `@be` in the REPL.

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

### For regression testing

Use [`RegressionTests.jl`](https://github.com/LilithHafner/RegressionTests.jl)! Make a file
`bench/runbenchmarks.jl` with the following content:

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

See the [RegressionTests.jl documentation](https://github.com/LilithHafner/RegressionTests.jl)
for more information.


```@index
```

```@autodocs
Modules = [Chairmarks]
```
