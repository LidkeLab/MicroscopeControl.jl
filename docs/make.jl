using MicroscopeControl
using Documenter

DocMeta.setdocmeta!(MicroscopeControl, :DocTestSetup, :(using MicroscopeControl); recursive=true)

# The API pages split each module's docstrings in two. A docstring whose object is public in MicroscopeControl
# (exported, or declared `public`) goes in the device's own section; every other one goes in the page's
# "Internals" section, for driver authors. The pages call these through `Main.`, because their `@autodocs` blocks
# evaluate `Filter` in `CurrentModule = MicroscopeControl`.
const MC_PUBLIC_OBJECTS = Any[getfield(MicroscopeControl, n) for n in names(MicroscopeControl)
                              if isdefined(MicroscopeControl, n)]
mc_public(obj) = any(o -> o === obj, MC_PUBLIC_OBJECTS)
mc_internal(obj) = !mc_public(obj)

makedocs(;
    modules=[MicroscopeControl],
    authors="klidke@unm.edu",
    sitename="MicroscopeControl.jl",
    format=Documenter.HTML(;
        canonical="https://LidkeLab.github.io/MicroscopeControl.jl",
        edit_link="main",
        assets=String[],
        size_threshold_warn=400 * 1024,
        size_threshold=800 * 1024,
    ),
    pages=[
        "Home" => "index.md",
        "Quick start" => "quickstart.md",
        "Image layout" => "conventions.md",
        "API reference" => [
            "Instruments and saving" => "api/instrument.md",
            "Cameras" => "api/cameras.md",
            "Stages" => "api/stages.md",
            "Light sources" => "api/lightsources.md",
            "DAQ and FPGA boards" => "api/daq.md",
            "Attenuators" => "api/attenuators.md",
            "Spatial light modulators" => "api/slm.md",
            "Triggerscope" => "api/triggerscope.md",
            "Index" => "api/index.md",
        ],
    ],
)

deploydocs(;
    repo="github.com/LidkeLab/MicroscopeControl.jl",
    devbranch="main",
)
