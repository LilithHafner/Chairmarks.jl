"""
    Runnable(f) <: Function

Calling `run(Runnable(f); kwargs...)` will run `f()`.
Calling `BenchmarkTools.tune!(::Runnable; kwargs)` will return `nothing`
Calling `(r::Runnable)()` will run `f()`.

This type exists to allow functions to be passed both to tools that expect functions and
to tools built to support BenchmarkTools.jl.

!!! warning
    This type is experimental. Notably, it may be removed in future versions of Chairmarks
    or moved to a different package.
"""
struct Runnable{F} <: Function
    f::F
end
Base.run(r::Runnable; kwargs...) = r.f()
(r::Runnable)() = r.f()

"""
    @benchmarkable args...

Like `()->@be args...`, but compatible with tools built to support BenchmarkTools.jl.

!!! warning
    This macro is experimental. Notably, it may be removed in future versions of Chairmarks
    or moved to a different package.
"""
macro benchmarkable(args...)
    :(Runnable(()->@be $(args...)))
end
