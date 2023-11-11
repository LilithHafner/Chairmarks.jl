using Tablemarks
using Documenter

DocMeta.setdocmeta!(Tablemarks, :DocTestSetup, :(using Tablemarks); recursive=true)

makedocs(;
    modules=[Tablemarks],
    authors="Lilith Orion Hafner <lilithhafner@gmail.com> and contributors",
    repo="https://github.com/LilithHafner/Tablemarks.jl/blob/{commit}{path}#{line}",
    sitename="Tablemarks.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://tablemarks.lilithhafner.com",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/LilithHafner/Tablemarks.jl",
    devbranch="main",
)
