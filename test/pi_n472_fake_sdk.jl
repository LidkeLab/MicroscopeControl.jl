# A fake PI GCS2 library for the N-472 driver.
#
# Replaces the GCS2 wrappers in `functions_GCS2.jl` (each a single `ccall` into
# a Windows DLL that is not on any build machine) with methods that record
# into `Main.FakeGCS2`, so the driver's own `initialize`/`shutdown`/`stopmotion`
# run unmodified and no test can command a rig's controller. Same seam, and
# same caveats, as `tcube_fake_sdk.jl`: the replacements are global and
# permanent for the process, and this file must be included at top level,
# early, into `Main`. See that file for the full list.

"""
    FakeGCS2

Recorder standing in for the PI GCS2 library: what the driver called, in what
order, with which description/axes string, and what each call reports back.
"""
module FakeGCS2

"Operation names in the order the driver called them, since the last `reset!`."
const calls = String[]

"The `szDescription`/`szAxes` argument of the last call per operation, as passed."
const lastarg = Dict{String,Any}()

"Bytes `PI_EnumerateUSB` writes into the caller's buffer."
const enum_bytes = Ref(UInt8[])

"Count `PI_EnumerateUSB` returns."
const enum_count = Ref(1)

"Ids `PI_ConnectUSB` returns, in order; when empty it returns 0."
const connect_ids = Int[]

"Operations that return FALSE."
const failing = Set{String}()

"Ids connected and not yet closed; one id space shared by every object."
const open_ids = Set{Int}()

"Returned by `PI_GetError` and `PI_GetInitError`."
const error_code = Ref(0)

function reset!()
    empty!(calls)
    empty!(lastarg)
    enum_bytes[] = UInt8[codeunits("d1")..., 0x00]
    enum_count[] = 1
    empty!(connect_ids)
    empty!(failing)
    empty!(open_ids)
    error_code[] = 0
    return nothing
end

function record!(op, arg=nothing)
    push!(calls, op)
    arg === nothing || (lastarg[op] = arg)
    return nothing
end

"Record `op` and report FALSE if it is in `failing`, else TRUE."
function status!(op, arg)
    record!(op, arg)
    return op in failing ? Cuint(0) : Cuint(1)
end

end # module FakeGCS2

FakeGCS2.reset!()

@eval MicroscopeControl.HardwareImplementations.PI_N472 begin
    function PI_EnumerateUSB(szBuffer, iBufferSize, szFilter)
        Main.FakeGCS2.record!("PI_EnumerateUSB")
        bytes = Main.FakeGCS2.enum_bytes[]
        n = min(length(bytes), Int(iBufferSize))
        for i in 1:n
            szBuffer[i] = bytes[i]
        end
        return Cint(Main.FakeGCS2.enum_count[])
    end
    function PI_ConnectUSB(szDescription)
        Main.FakeGCS2.record!("PI_ConnectUSB", szDescription)
        ids = Main.FakeGCS2.connect_ids
        id = isempty(ids) ? 0 : popfirst!(ids)
        id >= 0 && push!(Main.FakeGCS2.open_ids, id)
        return Cint(id)
    end
    function PI_IsConnected(ID)
        Main.FakeGCS2.record!("PI_IsConnected")
        return Int(ID) in Main.FakeGCS2.open_ids ? TRUE : FALSE
    end
    function PI_CloseConnection(ID)
        Main.FakeGCS2.record!("PI_CloseConnection")
        delete!(Main.FakeGCS2.open_ids, Int(ID))
        return nothing
    end
    PI_GetError(ID) = (Main.FakeGCS2.record!("PI_GetError"); Cint(Main.FakeGCS2.error_code[]))
    PI_GetInitError() = (Main.FakeGCS2.record!("PI_GetInitError"); Cint(Main.FakeGCS2.error_code[]))
    PI_HLT(ID, szAxes) = Main.FakeGCS2.status!("PI_HLT", szAxes)
    PI_RON(ID, szAxes, pbValueArray) = Main.FakeGCS2.status!("PI_RON", szAxes)
    PI_qRON(ID, szAxes, pbValueArray) = Main.FakeGCS2.status!("PI_qRON", szAxes)
    PI_POS(ID, szAxes, pdValueArray) = Main.FakeGCS2.status!("PI_POS", szAxes)
    PI_SVO(ID, szAxes, pbValueArray) = Main.FakeGCS2.status!("PI_SVO", szAxes)
    PI_qSVO(ID, szAxes, pbValueArray) = Main.FakeGCS2.status!("PI_qSVO", szAxes)
    PI_qTMN(ID, szAxes, pdValueArray) = Main.FakeGCS2.status!("PI_qTMN", szAxes)
    PI_qTMX(ID, szAxes, pdValueArray) = Main.FakeGCS2.status!("PI_qTMX", szAxes)
    PI_VEL(ID, szAxes, pdValueArray) = Main.FakeGCS2.status!("PI_VEL", szAxes)
    PI_qVEL(ID, szAxes, pdValueArray) = Main.FakeGCS2.status!("PI_qVEL", szAxes)
end
