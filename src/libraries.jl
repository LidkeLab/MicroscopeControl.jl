"""
Platform-dependent shared-library names.

Each library is a global assigned in `__init__`, so the value is resolved
at load time on the running machine rather than baked in during
precompilation. `@ccall libdcam.f(...)` then works on any platform.

Override any path with the matching environment variable, e.g.
`MICROSCOPECONTROL_LIBDCAM=/opt/hamamatsu/lib/libdcamapi.so`.

Verified 2026-10-05: `libdcam` against DCAM-API Lite v26.6.7175 on Ubuntu 26.04
(capture confirmed) and on Windows (resolves to `dcamapi.dll`); `libmadlib`
against Madlib 2.0.1 on both. The env-var override exists so a wrong guess
costs nothing.
"""
module Libraries

export libdcam, libmadlib

global libdcam::String = ""
global libmadlib::String = ""

_pick(key, win, linux) = get(ENV, "MICROSCOPECONTROL_" * uppercase(key),
    Sys.iswindows() ? win :
    Sys.islinux()   ? linux :
    "")

function __init__()
    global libdcam = _pick("libdcam",
        "dcamapi.dll", "libdcamapi.so")
    global libmadlib = _pick("libmadlib",
        raw"C:\Program Files\Mad City Labs\NanoDrive\Madlib.dll",
        "libmadlib.so")
end

"""
    isavailable(lib::AbstractString) -> Bool

Whether `lib` can actually be opened on this machine. Lets a device
constructor fail with a clear message instead of a raw dlopen error
from inside a `@ccall`.
"""
function isavailable(lib::AbstractString)
    isempty(lib) && return false
    try
        h = Base.Libc.Libdl.dlopen(lib)
        Base.Libc.Libdl.dlclose(h)
        true
    catch
        false
    end
end

end # module
