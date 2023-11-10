using QuickBenchmarkTools
using Documenter

DocMeta.setdocmeta!(QuickBenchmarkTools, :DocTestSetup, :(using QuickBenchmarkTools); recursive=true)

makedocs(;
    modules=[QuickBenchmarkTools],
    authors="Lilith Orion Hafner <lilithhafner@gmail.com> and contributors",
    repo="https://github.com/LilithHafner/QuickBenchmarkTools.jl/blob/{commit}{path}#{line}",
    sitename="QuickBenchmarkTools.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://LilithHafner.github.io/QuickBenchmarkTools.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/LilithHafner/QuickBenchmarkTools.jl",
    devbranch="main",
)
