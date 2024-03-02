```@meta
CurrentModule = Chairmarks
DocTestSetup = quote
    using Chairmarks
end
DocTestFilters = [r"\d\d?\d?\.\d{3} [μmn]?s( \(.*\))?"]
```

# How to use Chairmarks for regression testing

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
