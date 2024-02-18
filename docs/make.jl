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
    ],
    doctestfilters=[
        # If a line is talking about time, that can't be counted on at all
        # e.g. "median 10.354 μs (2 allocs: 78.172 KiB)"
        # the very existence of the line may also change if nubmer of samples is low
        r".*\d\.\d\d\d [nμm]?s.*",
        # Numbers are volatile e.g. "Benchmark: 267 samples with 2 evaluations"
        r"\d+",
    ]
)

deploydocs(;
    repo="github.com/LilithHafner/Chairmarks.jl",
    devbranch="main",
)
