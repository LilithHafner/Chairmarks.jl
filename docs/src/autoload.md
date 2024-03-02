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
   while still requiring and explicit load in scripts and packages. This will slow down
   launching a new Julia session by a few milliseconds (for comparison, this is about 20x
   faster than loading `Revise` in your startup.jl file).

3. [**Recommended**] Add Chairmarks to your default environment and put the following script in your
   startup.jl file to automatically load it when you type `@b` or `@be` in the REPL:

```julia
if isinteractive() && (local REPL = get(Base.loaded_modules, Base.PkgId(Base.UUID("3fa0cd96-eef1-5676-8a61-b3b8758bbffb"), "REPL"), nothing); REPL !== nothing)
    # https://github.com/fredrikekre/.dotfiles/blob/65b96f492da775702c05dd2fd460055f0706457b/.julia/config/startup.jl
    # Automatically load tooling on demand. These packages should be stdlibs or part of the default environment.
    # - Chairmarks when encountering @b or @be
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
