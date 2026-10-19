# Emergency/manual: open the cube, zero, disable, restore nothing else.
include("lib.jl")
ser = isempty(ARGS) ? SERIAL : ARGS[1]
ld_build(); sleep(0.2)
c = ccall((:LD_Open, DLL), Cshort, (Cstring,), ser); println("LD_Open($ser) -> $c")
ccall((:LD_StartPolling, DLL), Bool, (Cstring, Cint), ser, 50); sleep(0.3)
ccall((:LD_SetLaserSetPoint, DLL), Cshort, (Cstring, Cushort), ser, 0x0000); sleep(0.05)
println("disable -> ", ccall((:LD_DisableOutput, DLL), Cshort, (Cstring,), ser))
for _ in 1:2; ccall((:LD_RequestStatusBits, DLL), Cshort, (Cstring,), ser); sleep(0.1); end
println("status 0x", string(ccall((:LD_GetStatusBits, DLL), Cuint, (Cstring,), ser); base=16))
ccall((:LD_StopPolling, DLL), Cvoid, (Cstring,), ser); ccall((:LD_Close, DLL), Cvoid, (Cstring,), ser)
