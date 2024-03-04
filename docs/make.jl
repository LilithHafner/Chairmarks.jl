using Chairmarks
using Documenter

DocMeta.setdocmeta!(Chairmarks, :DocTestSetup, :(using Chairmarks); recursive=true)

makedocs(;
    authors="Lilith Orion Hafner <lilithhafner@gmail.com> and contributors",
    repo=Remotes.GitHub("LilithHafner", "Chairmarks.jl"),
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
        "Tutorial" => "tutorial.md",
        "How To" => [
            "...migrate from BenchmarkTools" => "migration.md",
            "...install Chairmarks ergonomically" => "autoload.md",
            "...perform automated regression testing on a package" => "regressions.md",
        ],
        "Reference" => "reference.md",
        "Explanations" => "explanations.md",
    ],
    linkcheck=true,
)

deploydocs(;
    repo="github.com/LilithHafner/Chairmarks.jl",
    devbranch="main",
    push_preview=true,
)
