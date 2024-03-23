using Chairmarks
using Documenter

import Pkg
Pkg.rm("DocumenterVitepress")
Pkg.add(url="https://github.com/LilithHafner/DocumenterVitepress.jl", rev="lh/redirect-slash")

using DocumenterVitepress

DocMeta.setdocmeta!(Chairmarks, :DocTestSetup, :(using Chairmarks); recursive=true)

makedocs(;
    authors="Lilith Orion Hafner <lilithhafner@gmail.com> and contributors",
    repo=Remotes.GitHub("LilithHafner", "Chairmarks.jl"),
    sitename="Chairmarks.jl",
    format=DocumenterVitepress.MarkdownVitepress(
        repo = "https://github.com/LilithHafner/Chairmarks.jl",
        devbranch = "main",
        devurl = "dev",
        deploy_url = "chairmarks.lilithhafner.com",
        redirect_trailing_slash = true,
    ),
    pages=[
        "Home" => "index.md",
        "Why use Chairmarks?" => "why.md",
        "Tutorial" => "tutorial.md",
        "How To" => [
            "migrate from BenchmarkTools" => "migration.md",
            "install Chairmarks ergonomically" => "autoload.md",
            "perform automated regression testing on a package" => "regressions.md",
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
