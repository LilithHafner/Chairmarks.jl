using Chairmarks
using Documenter
using DocumenterVitepress

DocMeta.setdocmeta!(Chairmarks, :DocTestSetup, :(using Chairmarks); recursive=true)

makedocs(;
    modules=[Chairmarks],
    authors="Lilith Orion Hafner <lilithhafner@gmail.com> and contributors",
    repo="https://github.com/LilithHafner/Chairmarks.jl/blob/{commit}{path}#{line}",
    sitename="Chairmarks.jl",
    format=DocumenterVitepress.MarkdownVitepress(
        repo = "https://github.com/LilithHafner/Chairmarks.jl",
        devbranch = "main",
        devurl = "dev"
    ),
    pages=[
        "Home" => "index.md",
    ],
    build = joinpath(@__DIR__, "build") # TODO: remove this line once https://github.com/LuxDL/DocumenterVitepress.jl/pull/32 is released
)

deploydocs(;
    repo="github.com/LilithHafner/Chairmarks.jl",
    devbranch="main",
    push_preview=true,
)
