"""
IDS Peak Comfort camera implementation.

This module wraps the IDS `ids_peak_comfort_c` API generated in
`constants_ids.jl` and `functions_ids.jl` and exposes the package camera
interface.
"""
module IDSCam

using ...MicroscopeControl.HardwareInterfaces.CameraInterface
using CEnum

import ...MicroscopeControl.HardwareInterfaces.CameraInterface: Camera
import ...MicroscopeControl: export_state, initialize, shutdown

export IDSCamera, gui, initialize, shutdown
export getlastframe, capture, live, sequence, abort, getdata
export setexposuretime!, setroi!, setframerate!

# The 64-bit SDK DLL installed by IDS Peak.  Keeping this here makes the
# generated bindings usable without modifying them.
const IDS = raw"C:\Program Files\IDS\ids_peak\comfort_sdk\api\lib\x86_64\ids_peak_comfort_c.dll"

# Compatibility shims for two C macro spellings retained by the generated
# constants file.
const NULL = C_NULL
UINT64_C(value) = UInt64(value)

include("constants_ids.jl")
include("functions_ids.jl")
include("types.jl")
include("interface_methods.jl")

end
