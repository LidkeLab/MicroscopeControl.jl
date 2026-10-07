using MicroscopeControl
using Documenter

DocMeta.setdocmeta!(MicroscopeControl, :DocTestSetup, :(using MicroscopeControl); recursive=true)

makedocs(;
    modules=[MicroscopeControl],
    authors="klidke@unm.edu",
    sitename="MicroscopeControl.jl",
    format=Documenter.HTML(;
        canonical="https://LidkeLab.github.io/MicroscopeControl.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
    # Not every docstring is in the manual yet; report that as a warning
    # instead of aborting the build.
    warnonly=[:missing_docs],
)

deploydocs(;
    repo="github.com/LidkeLab/MicroscopeControl.jl",
    devbranch="main",
)
