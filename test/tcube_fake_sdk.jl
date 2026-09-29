# A fake Kinesis SDK for the TCube laser driver.
#
# There is no Thorlabs TCube on any build machine, which is why the safety
# logic was factored into `check_current`, `effective_max_current` and
# `record_controller_limit!` in the first place. But testing those helpers is
# not testing `initialize`: the defect this driver was fixed for lived in
# `initialize`'s own body (it assigned the controller's limit straight over the
# caller's `max_current`), and a review restored exactly that assignment with
# the helpers left intact and watched every assertion still pass.
#
# The seam used here is the one the driver already has. The Kinesis wrappers in
# `functions_Tlaser.jl` are plain Julia functions with untyped arguments living
# in the `TCubeLaserControl` module, each a single `ccall` into a Windows DLL.
# Defining a method with the same signature into that module replaces them, so
# the driver's own `initialize`/`setpower`/`shutdown` run unmodified against a
# recorder instead of a controller. Nothing in `src/` changes for the sake of
# the test, and the calls being replaced could never have succeeded here: the
# DLL they load does not exist on this machine.
#
# What this seam does NOT cover, established by review rather than assumed:
#
#   * The replacements are global and permanent for the process. Every
#     later testset -- contract, GUI, skills -- runs against them. That is the
#     intent (there is no real controller to reach) and no current test depends
#     on the original wrapper bodies: the contract tests inspect public
#     interface dispatch, the GUI tests drive simulated devices and
#     `RecordingLight`, and the skills tests inspect public methods and
#     generated documentation. None of those signatures change here.
#   * The include must stay at top level and stay early. Replacement bumps the
#     world age, and an ordinary function -- even one already compiled -- picks
#     up the fake when it is next called from the new world. A *task* created
#     before the replacement does not: it keeps the old methods for its
#     lifetime. So an earlier include that spawns a task, or that runs TCube
#     code immediately, would silently bypass the fake.
#   * Including `runtests.jl` into an interactive session leaves that session
#     contaminated: the replacements are not undone. `Main.FakeKinesis` also
#     assumes inclusion into `Main`.
#   * The recorder does not validate serial numbers, and these calls bypass the
#     DLL on Windows too. So nothing here says anything about DLL loading, the
#     binding bodies, or how a real controller answers -- all three can be
#     broken while every assertion below passes. That is the right scope for a
#     unit test, but it is not hardware verification. If hardware integration
#     tests are ever added, this fake-backed group needs its own subprocess.
#   * Julia prints a "Method definition ... overwritten" warning per wrapper as
#     this file is included. They are expected.

#
# Since 0.2.5 the fake also carries the small amount of controller STATE the
# closed-loop path reads back -- status bits, the setpoint, the max-current
# potentiometer, the W/A factor, the two readings -- because that path verifies
# each of its writes, and a recorder that only returned 0 could not tell a
# verified write from an unverified one. Each piece of state can be made to
# misbehave (a pot that does not take, a mode bit that does not set, a
# setpoint that reads back wrong) so that every refusal has a test.

"""
    FakeKinesis

Recorder standing in for the Thorlabs Kinesis SDK: what the driver called, in
what order, what it sent, what each call reports back, and the little state a
TLD001 would hold between calls.
"""
module FakeKinesis

"Operation names in the order the driver called them, since the last `reset!`."
const calls = String[]

"Status each operation reports; absent means `0`, i.e. success."
const status = Dict{String,Int}()

"""
Operations that raise instead of returning a status, and the message they
raise with.

A status code is not the only way a Kinesis call can fail, and for `LD_Close`
it is not a way at all: the binding returns `void`, so the only failure it can
express is a thrown exception. Without this, `initialize`'s cleanup handler --
the `try`/`catch` around `LD_Close` that exists precisely so a failing close
cannot replace the error that stopped initialization -- had no way to be
exercised, and deleting it failed nothing.
"""
const throws = Dict{String,String}()

"Every setpoint that reached `LD_SetLaserSetPoint`."
const setpoints = UInt16[]

"""
Raw reading returned by `LD_GetLaserDiodeMaxCurrentLimit`. The default is
`floor(160 / 220 * 32767)`, i.e. a controller limit of 160 mA under the
driver's default scale.
"""
const diode_limit_raw = Ref{Int}(23830)

"Raw limit values the next `LD_GetLaserDiodeMaxCurrentLimit` reads return, first in first out, before `diode_limit_raw` applies again."
const limit_raw_queue = Int[]

"Raw diode-current reading; `nothing` returns `diode_limit_raw`, as before 0.2.5."
const current_raw = Ref{Union{Nothing,Int}}(nothing)

"Raw photocurrent reading (`LD_GetPhotoCurrentReading`)."
const photocurrent_raw = Ref{Int}(0)

const KEY, CLOSED, INTERLOCK, ENABLED = 0x00000002, 0x00000004, 0x00000008, 0x00000001
const TIA_1mA, TIA_10mA, PSU_OK = 0x00000040, 0x00000080, 0x00001000
const TIA_OVER, TIA_UNDER = 0x00002000, 0x00004000

"The status word: key, interlock, PSU OK and the 1 mA range by default."
const bits = Ref{UInt32}(KEY | INTERLOCK | PSU_OK | TIA_1mA)

"Whether `LD_SetClosedLoopMode` actually sets the closed-loop bit."
const closed_loop_takes = Ref(true)

"The setpoint the controller holds, and an override for what it reads back."
const setpoint_held = Ref{UInt16}(0)
const setpoint_readback = Ref{Union{Nothing,UInt16}}(nothing)

"""
The rig's TLD001 IGNORES a setpoint sent while its output is off, and with the
output off `LD_GetLaserSetPoint` returns a stale word (65530 on the rig) that
has nothing to do with what was sent. Measured 2026-09-28; the fake does the
same, so a driver that sends setpoints with the output off fails here as it did
on the rig.
"""
const STALE_SETPOINT = UInt16(65530)

"The max-current potentiometer position, whether a set takes, and every set."
const digpot = Ref{Int}(204)
const digpot_takes = Ref(true)
const digpot_sets = Int[]

"""
When `true`, the diode current limit follows the potentiometer on the scale
measured on the 642 nm rig's TLD001 (position 204 -> 160.74 mA, 194 -> 152.43
mA, about 0.831 mA per step) instead of returning `diode_limit_raw`. The
closed-loop tests turn it on; the open-loop ones rely on a fixed limit.
"""
const limit_follows_pot = Ref(false)
limit_mA_for(pos) = 160.74 + (pos - 204) * 0.831

"Every `(enableAdjust, enableDiode)` pair sent to `LD_EnableMaxCurrentAdjust`."
const adjust_calls = Tuple{Any,Any}[]

"The W/A factor the controller holds, and an override for what it reads back."
const wa = Ref{Float32}(0f0)
const wa_readback = Ref{Union{Nothing,Float32}}(nothing)

"What `LD_StartPolling` returns: a success FLAG."
const polling_ok = Ref(true)

"""
0.2.4's names for the same controller state, kept so its tests
(`tcube_output_order.jl`) run unchanged: `stored` IS `setpoint_held`, and
`output_on[]` reads the `ENABLED` status bit.
"""
const stored = setpoint_held
struct OutputOn end
Base.getindex(::OutputOn) = bits[] & ENABLED != 0
const output_on = OutputOn()

"The stored setpoint at each successful `LD_EnableOutput`, i.e. what it ran on."
const enable_log = Int[]

"Forget the recorded history and restore the default responses."
function reset!(; limit_raw::Integer=23830, stored::Integer=0)
    empty!(calls)
    empty!(status)
    empty!(setpoints)
    empty!(throws)
    empty!(enable_log)
    diode_limit_raw[] = limit_raw
    empty!(limit_raw_queue)
    current_raw[] = nothing
    photocurrent_raw[] = 0
    bits[] = KEY | INTERLOCK | PSU_OK | TIA_1mA
    closed_loop_takes[] = true
    setpoint_held[] = stored
    setpoint_readback[] = nothing
    digpot[] = 204
    limit_follows_pot[] = false
    digpot_takes[] = true
    empty!(digpot_sets)
    empty!(adjust_calls)
    wa[] = 0f0
    wa_readback[] = nothing
    polling_ok[] = true
    return nothing
end

"""
Record a call, then either raise what `throw!` asked for or return the status
`fail!` asked for (`0` = success). The call is recorded either way: a call that
throws still happened, and the order assertions need to see it.
"""
function record!(op::AbstractString)
    push!(calls, op)
    haskey(throws, op) && error(throws[op])
    return get(status, op, 0)
end

"Make `op` report a Thorlabs error code from now on."
fail!(op::AbstractString, code::Integer=1) = (status[op] = code; nothing)

"Make `op` raise an `ErrorException` from now on, rather than report a code."
throw!(op::AbstractString, msg::AbstractString="fake Kinesis failure in $op") = (throws[op] = msg; nothing)

"Set or clear status bits."
setbits!(mask; on::Bool=true) = (bits[] = on ? (bits[] | UInt32(mask)) : (bits[] & ~UInt32(mask)); nothing)

end

@eval MicroscopeControl.HardwareImplementations.TCubeLaserControl begin
    TLI_BuildDeviceList() = Main.FakeKinesis.record!("TLI_BuildDeviceList")
    TLI_GetDeviceListSize() = (Main.FakeKinesis.record!("TLI_GetDeviceListSize"); 1)
    LD_Open(serialNo) = Main.FakeKinesis.record!("LD_Open")
    LD_Close(serialNo) = (Main.FakeKinesis.record!("LD_Close"); nothing)
    function LD_SetOpenLoopMode(serialNo)
        s = Main.FakeKinesis.record!("LD_SetOpenLoopMode")
        s == 0 && Main.FakeKinesis.setbits!(Main.FakeKinesis.CLOSED; on=false)
        return s
    end
    function LD_SetClosedLoopMode(serialNo)
        s = Main.FakeKinesis.record!("LD_SetClosedLoopMode")
        (s == 0 && Main.FakeKinesis.closed_loop_takes[]) && Main.FakeKinesis.setbits!(Main.FakeKinesis.CLOSED)
        return s
    end
    LD_RequestReadings(serialNo) = Main.FakeKinesis.record!("LD_RequestReadings")
    LD_RequestLaserDiodeMaxCurrentLimit(serialNo) =
        Main.FakeKinesis.record!("LD_RequestLaserDiodeMaxCurrentLimit")
    function LD_EnableOutput(serialNo)
        s = Main.FakeKinesis.record!("LD_EnableOutput")
        if s == 0
            Main.FakeKinesis.setbits!(Main.FakeKinesis.ENABLED)
            push!(Main.FakeKinesis.enable_log, Int(Main.FakeKinesis.setpoint_held[]))
        end
        return s
    end
    function LD_DisableOutput(serialNo)
        s = Main.FakeKinesis.record!("LD_DisableOutput")
        s == 0 && Main.FakeKinesis.setbits!(Main.FakeKinesis.ENABLED; on=false)
        return s
    end
    function LD_SetLaserSetPoint(serialNo, laserDiodeCurrent)
        push!(Main.FakeKinesis.setpoints, laserDiodeCurrent)
        s = Main.FakeKinesis.record!("LD_SetLaserSetPoint")
        on = Main.FakeKinesis.bits[] & Main.FakeKinesis.ENABLED != 0
        (s == 0 && on) && (Main.FakeKinesis.setpoint_held[] = laserDiodeCurrent) # ignored with the output off
        return s
    end
    LD_RequestLaserSetPoint(serialNo) = Main.FakeKinesis.record!("LD_RequestLaserSetPoint")
    function LD_GetLaserSetPoint(serialNo)
        Main.FakeKinesis.record!("LD_GetLaserSetPoint")
        Main.FakeKinesis.setpoint_readback[] === nothing || return Main.FakeKinesis.setpoint_readback[]
        on = Main.FakeKinesis.bits[] & Main.FakeKinesis.ENABLED != 0
        return on ? Main.FakeKinesis.setpoint_held[] : Main.FakeKinesis.STALE_SETPOINT
    end
    function LD_GetLaserDiodeMaxCurrentLimit(serialNo)
        Main.FakeKinesis.record!("LD_GetLaserDiodeMaxCurrentLimit")
        isempty(Main.FakeKinesis.limit_raw_queue) || return popfirst!(Main.FakeKinesis.limit_raw_queue)
        Main.FakeKinesis.limit_follows_pot[] || return Main.FakeKinesis.diode_limit_raw[]
        return floor(Int, Main.FakeKinesis.limit_mA_for(Main.FakeKinesis.digpot[]) / 220 * 32767)
    end
    function LD_GetLaserDiodeCurrentReading(serialNo)
        Main.FakeKinesis.record!("LD_GetLaserDiodeCurrentReading")
        return something(Main.FakeKinesis.current_raw[], Main.FakeKinesis.diode_limit_raw[])
    end
    function LD_GetPhotoCurrentReading(serialNo)
        Main.FakeKinesis.record!("LD_GetPhotoCurrentReading")
        return Main.FakeKinesis.photocurrent_raw[]
    end
    LD_RequestStatusBits(serialNo) = Main.FakeKinesis.record!("LD_RequestStatusBits")
    function LD_GetStatusBits(serialNo)
        Main.FakeKinesis.record!("LD_GetStatusBits")
        return Main.FakeKinesis.bits[]
    end
    function LD_EnableMaxCurrentAdjust(serialNo, enableAdjust, enableDiode)
        push!(Main.FakeKinesis.adjust_calls, (enableAdjust, enableDiode))
        return Main.FakeKinesis.record!("LD_EnableMaxCurrentAdjust")
    end
    function LD_SetMaxCurrentDigPot(serialNo, maxCurrent)
        push!(Main.FakeKinesis.digpot_sets, Int(maxCurrent))
        s = Main.FakeKinesis.record!("LD_SetMaxCurrentDigPot")
        (s == 0 && Main.FakeKinesis.digpot_takes[]) && (Main.FakeKinesis.digpot[] = Int(maxCurrent))
        return s
    end
    LD_RequestMaxCurrentDigPot(serialNo) = Main.FakeKinesis.record!("LD_RequestMaxCurrentDigPot")
    function LD_GetMaxCurrentDigPot(serialNo)
        Main.FakeKinesis.record!("LD_GetMaxCurrentDigPot")
        return UInt16(Main.FakeKinesis.digpot[])
    end
    function LD_SetWACalibFactor(serialNo, calibFactor)
        s = Main.FakeKinesis.record!("LD_SetWACalibFactor")
        s == 0 && (Main.FakeKinesis.wa[] = Float32(calibFactor))
        return s
    end
    LD_RequestWACalibFactor(serialNo) = Main.FakeKinesis.record!("LD_RequestWACalibFactor")
    function LD_GetWACalibFactor(serialNo)
        Main.FakeKinesis.record!("LD_GetWACalibFactor")
        return something(Main.FakeKinesis.wa_readback[], Main.FakeKinesis.wa[])
    end
    function LD_StartPolling(serialNo, milliseconds)
        Main.FakeKinesis.record!("LD_StartPolling")
        return Main.FakeKinesis.polling_ok[]
    end
    LD_StopPolling(serialNo) = (Main.FakeKinesis.record!("LD_StopPolling"); nothing)
end

# The driver waits between a Kinesis request and the read of its answer; the
# fake answers immediately, so the suite does not need to wait.
MicroscopeControl.HardwareImplementations.TCubeLaserControl.REQUEST_WAIT_S[] = 0.0
MicroscopeControl.HardwareImplementations.TCubeLaserControl.CLAMP_WAIT_S[] = 0.0
MicroscopeControl.HardwareImplementations.TCubeLaserControl.SETPOINT_CONFIRM_TIMEOUT_S[] = 0.05
