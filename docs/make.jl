using Chairmarks
using Documenter

DocMeta.setdocmeta!(Chairmarks, :DocTestSetup, :(using Chairmarks); recursive=true)

makedocs(;
    modules=[Chairmarks],
    authors="Lilith Orion Hafner <lilithhafner@gmail.com> and contributors",
    repo="https://github.com/LilithHafner/Chairmarks.jl/blob/{commit}{path}#{line}",
    sitename="Chairmarks.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://Chairmarks.lilithhafner.com",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Why use Chairmarks?" => "why.md",
        "How To" => [
            "...migrate from BenchmarkTools" => "migration.md",
            "...install Charimarks ergonomically" => "autoload.md",
            "...perform automated regression testing on a package" => "regressions.md",
        ],
        "Reference" => "reference.md",
    ],
)

deploydocs(;
    repo="github.com/LilithHafner/Chairmarks.jl",
    devbranch="main",
    push_preview=true,
)
