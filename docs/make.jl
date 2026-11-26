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

# Documenter's own missing-docstring check misses a docstring left off the site when its name is documented in
# several modules (`initialize`, `getdata`, ...): it compares one module's signatures per name. The pages put every
# docstring of a module on the site once that module is in an `@autodocs` `Modules` list (each list pairs a
# `mc_public` block with a `mc_internal` one, or takes the module unfiltered), so check that every submodule is.
function submodules(m::Module, acc=Set{Module}([m]))
    for n in names(m; all=true)
        isdefined(m, n) || continue
        v = getfield(m, n)
        if v isa Module && v !== m && parentmodule(v) === m && !(v in acc)
            push!(acc, v)
            submodules(v, acc)
        end
    end
    return acc
end
function listed_modules()
    listed = Set{Module}()
    for file in readdir(joinpath(@__DIR__, "src", "api"); join=true)
        endswith(file, ".md") || continue
        for m in eachmatch(r"Modules = \[(.*?)\]"s, read(file, String)), name in split(m.captures[1], ',')
            push!(listed, Core.eval(MicroscopeControl, Meta.parse(strip(name))))
        end
    end
    return listed
end
let unlisted = setdiff(submodules(MicroscopeControl), listed_modules())
    isempty(unlisted) || error("modules on no API page (add each to a page's @autodocs Modules list): " *
                               join(string.(unlisted), ", "))
end

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
