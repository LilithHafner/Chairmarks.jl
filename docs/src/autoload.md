```@meta
CurrentModule = Chairmarks
DocTestSetup = quote
    using Chairmarks
end
DocTestFilters = [r"\d\d?\d?\.\d{3} [μmn]?s( \(.*\))?"]
```

# [How to integrate Chairmarks into your workflow](@id installation)

There are several ways to use Chairmarks in your interactive sessions, ordered from simplest
to install first to most streamlined user experience last.

1. Add Chairmarks to your default environment with `import Pkg; Pkg.activate(); Pkg.add("Chairmarks")`.
   Chairmarks has no non-stdlib dependencies, and precompiles in less than one second, so
   this should not have any adverse impacts on your environments nor slow load times nor
   package instillation times.

2. Add Chairmarks to your default environment and put `isinteractive() && using Chairmarks`
   in your startup.jl file. This will make Chairmarks available in all your REPL sessions
   while still requiring an explicit load in scripts and packages. This will slow down
   launching a new Julia session by a few milliseconds (for comparison, this is about 20x
   faster than loading `Revise` in your startup.jl file).

3. [**Recommended**] Add Chairmarks and [BasicAutoloads](https://github.com/LilithHafner/BasicAutoloads.jl)
   to your default environment and put the following script in your startup.jl file to
   automatically load it when you type `@b` or `@be` in the REPL:

```julia
if isinteractive()
    import BasicAutoloads
    BasicAutoloads.register_autoloads([
        ["@b", "@be"] => :(using Chairmarks),
    ])
end
```
