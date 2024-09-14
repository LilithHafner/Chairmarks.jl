# Formal API

The formal API of Chairmarks is defined by the docstrings of public symbols. Any behavior
promised by these docstrings should typically remain in all future non-breaking releases.
Specific display behavior is not part of the API.

However, as a package designed primarily for interactive usage, Chairmarks follows _soft
semantic versioning_. A technically breaking change may be released with a non-breaking
version number if the change is not expected to cause significant disruptions.

- [`Chairmarks.Sample`](@ref)
- [`Chairmarks.Benchmark`](@ref)
- [`@b`](@ref)
- [`@be`](@ref)
- [`Chairmarks.DEFAULTS`](@ref)

```@docs
Chairmarks.Sample
Chairmarks.Benchmark
@b
@be
Chairmarks.DEFAULTS
```
