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
# several modules (`initialize`, `getdata`, ...): it compares one module's signatures per name. So before building,
# select docstrings the way Documenter's `@autodocs` and `@docs` blocks do, from every page in docs/src, and fail if
# any docstring of any submodule lands on no page. `@autodocs` evaluates `Modules`, `Order`, `Public` and `Private`
# in the page's `CurrentModule` and `Filter` in `Main`; `@docs` takes every docstring of each binding it names.
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
assignments(body) = [ex for ex in Meta.parseall(body).args if ex isa Expr && ex.head === :(=)]
function docs_left_off()
    autodocs = []                   # (modules, order, public, private, filter) per @autodocs block
    named = Set{Docs.Binding}()     # bindings named in @docs blocks
    for (root, _, files) in walkdir(joinpath(@__DIR__, "src")), file in files
        endswith(file, ".md") || continue
        text = replace(read(joinpath(root, file), String), r"<!--.*?-->"s => "")
        meta = match(r"^```@meta\s*\n(.*?)^```"ms, text)
        curmod = Main
        if meta !== nothing
            for ex in assignments(meta.captures[1])
                ex.args[1] === :CurrentModule && (curmod = Core.eval(Main, ex.args[2]))
            end
        end
        for block in eachmatch(r"^```@autodocs\s*\n(.*?)^```"ms, text)
            f = Dict{Symbol,Any}()
            for ex in assignments(block.captures[1])
                f[ex.args[1]] = Core.eval(ex.args[1] === :Filter ? Main : curmod, ex.args[2])
            end
            push!(autodocs, (f[:Modules], get(f, :Order, [:module, :constant, :type, :function, :macro]),
                             get(f, :Public, true), get(f, :Private, true), get(f, :Filter, _ -> true)))
        end
        for block in eachmatch(r"^```@docs\s*\n(.*?)^```"ms, text), line in split(block.captures[1], '\n')
            isempty(strip(line)) || push!(named, Documenter.DocSystem.binding(curmod, Meta.parse(line)))
        end
    end
    left = String[]
    for mod in submodules(MicroscopeControl), (binding, multidoc) in Documenter.DocSystem.getmeta(mod)
        binding in named && continue
        ispublic = Documenter.DocSystem.APIStatus(mod, binding.var).ispublic
        category = Documenter.DocSystem.category(binding)
        object = Core.eval(binding.mod, binding.var)
        shown = any(autodocs) do (modules, order, public, private, filter)
            mod in modules && category in order && (ispublic ? public : private) &&
                Base.invokelatest(filter, object)
        end
        shown || push!(left, "$mod: $binding ($(length(multidoc.docs)) docstring(s))")
    end
    return left
end
let left = docs_left_off()
    isempty(left) || error("docstrings on no page of the manual (add their module to an @autodocs block, or " *
                           "name them in a @docs block):\n  " * join(left, "\n  "))
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
