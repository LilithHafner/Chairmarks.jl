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
        devurl = "dev",
        deploy_url = "chairmarks.lilithhafner.com"),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/LilithHafner/Chairmarks.jl",
    devbranch="main",
    push_preview=true,
)
