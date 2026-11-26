using MicroscopeControl
using Documenter

DocMeta.setdocmeta!(MicroscopeControl, :DocTestSetup, :(using MicroscopeControl); recursive=true)

# The API pages split each module's docstrings in two. A docstring whose object is public in MicroscopeControl
# (exported, or declared `public`) goes in the device's own section; every other one goes in the page's
# "Internals" section, for driver authors. Documenter evaluates an `@autodocs` block's `Filter` in `Main`, where
# these are defined.
const MC_PUBLIC_OBJECTS = Any[getfield(MicroscopeControl, n) for n in names(MicroscopeControl)
                              if isdefined(MicroscopeControl, n)]
mc_public(obj) = any(o -> o === obj, MC_PUBLIC_OBJECTS)
mc_internal(obj) = !mc_public(obj)

doc = makedocs(;
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
    debug=true,   # return the built document, for the coverage check below
)

# Every docstring of every submodule must be on a page. Documenter's own missing-docstring check compares one
# module's signatures per documented name, so it can miss a docstring of a name documented in several modules
# (`initialize`, `getdata`, ...). This check compares the docstrings the built pages actually contain with every
# docstring the package holds, before anything is deployed.
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
function rendered!(acc, node)
    node.element isa Documenter.DocsNode && foreach(d -> push!(acc, d), node.element.results)
    foreach(child -> rendered!(acc, child), node.children)
    return acc
end
let shown = Base.IdSet{Base.Docs.DocStr}()
    foreach(page -> rendered!(shown, page.mdast), values(doc.blueprint.pages))
    left = ["$mod: $binding $sig" for mod in submodules(MicroscopeControl)
            for (binding, multidoc) in Base.Docs.meta(mod) for (sig, docstr) in multidoc.docs if !(docstr in shown)]
    isempty(left) || error("docstrings on no page of the manual (add their module to an @autodocs block, or " *
                           "name them in a @docs block):\n  " * join(left, "\n  "))
    @info "Coverage check: all $(length(shown)) docstrings on the built pages; none of the package's is missing."
end

deploydocs(;
    repo="github.com/LidkeLab/MicroscopeControl.jl",
    devbranch="main",
)
