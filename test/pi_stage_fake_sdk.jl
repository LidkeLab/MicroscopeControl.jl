# A fake PI GCS2 library for the PIStage driver.
#
# Replaces the wrappers in `pi_stage/gcs2.jl` (each a single `@ccall` into a
# Windows DLL that is not on any build machine) with methods that record into
# `Main.FakePIStage`, so the driver's own `initialize`/`shutdown` run unmodified
# and no test can command a rig's controller. Same seam, and same caveats, as
# `tcube_fake_sdk.jl`: the replacements are global and permanent for the
# process, and this file must be included at top level, early, into `Main`.
# A wrapper the tests do not need throws, so no test can reach a DLL.

"""
    FakePIStage

Recorder standing in for the PI GCS2 library: what the driver called, in what
order, and what each call reports back. Failures are per call: `fail!(op)`
makes it return FALSE, `throw!(op)` makes it throw.
"""
module FakePIStage

"Operation names in the order the driver called them, since the last `reset!`."
const calls = String[]

"Bytes `PI_EnumerateUSB` writes into the caller's buffer."
const enum_bytes = Ref(UInt8[])

"Count `PI_EnumerateUSB` returns."
const enum_count = Ref(1)

"Ids `PI_ConnectUSB` returns, in order; when empty it returns 0."
const connect_ids = Int[]

"Ids connected and not yet closed."
const open_ids = Set{Int}()

"Operations that return FALSE."
const failing = Set{String}()

"Operations that throw."
const throwing = Set{String}()

"When true, `PI_CloseConnection` leaves the id open: a close that fails."
const close_leaves_open = Ref(false)

"`PI_IsControllerReady` answers not ready for this many polls."
const not_ready_polls = Ref(0)

"`PI_qFRF` answers unreferenced for this many polls."
const unreferenced_polls = Ref(0)

"Called with no arguments inside `PI_FRF`, so a test can observe driver state there."
const frf_hook = Ref{Any}(nothing)

"Returned by `PI_GetError`."
const error_code = Ref(0)

"`PI_IsMoving` answers moving on both axes for this many polls."
const moving_polls = Ref(0)

const ready_polls = Ref(0)
const moving_count = Ref(0)
const referenced_polls = Ref(0)

function reset!()
    empty!(calls)
    enum_bytes[] = UInt8[codeunits("d1")..., 0x00]
    enum_count[] = 1
    empty!(connect_ids)
    empty!(open_ids)
    empty!(failing)
    empty!(throwing)
    close_leaves_open[] = false
    not_ready_polls[] = 0
    unreferenced_polls[] = 0
    frf_hook[] = nothing
    error_code[] = 0
    ready_polls[] = 0
    referenced_polls[] = 0
    moving_polls[] = 0
    moving_count[] = 0
    return nothing
end

fail!(op) = push!(failing, op)
throw!(op) = push!(throwing, op)

"Record `op`, throw if it is in `throwing`."
function record!(op)
    push!(calls, op)
    op in throwing && error("FakePIStage: $op threw")
    return nothing
end

"Record `op` and report FALSE if it is in `failing`, else TRUE."
function status!(op)
    record!(op)
    return op in failing ? Cint(0) : Cint(1)
end

unmodelled(op) = error("FakePIStage: $op is not modelled")

end # module FakePIStage

FakePIStage.reset!()

@eval MicroscopeControl.HardwareImplementations.PI begin
    function PI_EnumerateUSB(buffer, bufsize, filter)
        Main.FakePIStage.record!("PI_EnumerateUSB")
        bytes = Main.FakePIStage.enum_bytes[]
        for i in 1:min(length(bytes), Int(bufsize))
            buffer[i] = bytes[i]
        end
        return Cint(Main.FakePIStage.enum_count[])
    end
    function PI_ConnectUSB(description)
        Main.FakePIStage.record!("PI_ConnectUSB")
        ids = Main.FakePIStage.connect_ids
        id = isempty(ids) ? 0 : popfirst!(ids)
        id >= 0 && push!(Main.FakePIStage.open_ids, id)
        return Cint(id)
    end
    function PI_IsConnected(ID)
        Main.FakePIStage.record!("PI_IsConnected")
        return Int(ID) in Main.FakePIStage.open_ids ? Cint(1) : Cint(0)
    end
    function PI_CloseConnection(ID)
        Main.FakePIStage.record!("PI_CloseConnection")
        Main.FakePIStage.close_leaves_open[] || delete!(Main.FakePIStage.open_ids, Int(ID))
        return nothing
    end
    PI_GetError(ID) = (Main.FakePIStage.record!("PI_GetError"); Cint(Main.FakePIStage.error_code[]))
    function PI_IsControllerReady(ID, piControllerReady)
        st = Main.FakePIStage.status!("PI_IsControllerReady")
        Main.FakePIStage.ready_polls[] += 1
        piControllerReady[] = Main.FakePIStage.ready_polls[] > Main.FakePIStage.not_ready_polls[] ? Cint(1) : Cint(0)
        return st
    end
    function PI_FRF(ID, axes)
        hook = Main.FakePIStage.frf_hook[]
        hook === nothing || hook()
        return Main.FakePIStage.status!("PI_FRF")
    end
    function PI_qFRF(ID, axes, referenced)
        st = Main.FakePIStage.status!("PI_qFRF")
        Main.FakePIStage.referenced_polls[] += 1
        done = Main.FakePIStage.referenced_polls[] > Main.FakePIStage.unreferenced_polls[]
        referenced[1] = referenced[2] = done ? Cint(1) : Cint(0)
        return st
    end
    PI_SVO(ID, axes, values) = Main.FakePIStage.status!("PI_SVO")
    PI_VEL(ID, axes, values) = Main.FakePIStage.status!("PI_VEL")
    function PI_qVEL(ID, axes, values)
        st = Main.FakePIStage.status!("PI_qVEL")
        st == 1 && (values[1] = values[2] = 1.0)
        return st
    end
    function PI_IsMoving(ID, axes, values)
        st = Main.FakePIStage.status!("PI_IsMoving")
        Main.FakePIStage.moving_count[] += 1
        moving = Main.FakePIStage.moving_count[] <= Main.FakePIStage.moving_polls[]
        st == 1 && (values[1] = values[2] = moving ? 1 : 0)
        return st
    end
    function PI_qTMN(ID, axes, values)
        st = Main.FakePIStage.status!("PI_qTMN")
        st == 1 && (values[1] = values[2] = 0.0)
        return st
    end
    function PI_qTMX(ID, axes, values)
        st = Main.FakePIStage.status!("PI_qTMX")
        st == 1 && (values[1] = values[2] = 25.0)
        return st
    end
    function PI_qPOS(ID, axes, values)
        st = Main.FakePIStage.status!("PI_qPOS")
        for i in eachindex(values)
            values[i] = 12.5
        end
        return st
    end
    PI_MOV(ID, axes, values) = Main.FakePIStage.unmodelled("PI_MOV")
    PI_HLT(ID, axes) = Main.FakePIStage.unmodelled("PI_HLT")
    PI_STP(ID) = Main.FakePIStage.unmodelled("PI_STP")
end
