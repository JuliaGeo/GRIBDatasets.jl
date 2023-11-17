using GRIBDatasets
using Documenter


setup = quote 
    using GRIBDatasets
    const GDS = GRIBDatasets
    example_file = joinpath(dirname(pathof(GRIBDatasets)), "..", "test", "sample-data", "era5-levels-members.grib")
    end
DocMeta.setdocmeta!(GRIBDatasets, :DocTestSetup, setup; recursive=true)

makedocs(;
    modules=[GRIBDatasets],
    authors="tcarion <tristan.carion@gmail.com> and contributors",
    repo="https://github.com/tcarion/GRIBDatasets.jl/blob/{commit}{path}#{line}",
    sitename="GRIBDatasets.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://tcarion.github.io/GRIBDatasets.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Internals" => Any[
            # "internals.md",
            "FileIndex" => "file_index.md"
        ],
    ],
)

deploydocs(;
    repo="github.com/tcarion/GRIBDatasets.jl",
    devbranch="main",
)
