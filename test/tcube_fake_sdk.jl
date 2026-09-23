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
#   * The eleven replacements are global and permanent for the process. Every
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

"""
    FakeKinesis

Recorder standing in for the Thorlabs Kinesis SDK: what the driver called, in
what order, what it sent, and what each call reports back.
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

"Forget the recorded history and restore the default responses."
function reset!(; limit_raw::Integer=23830)
    empty!(calls)
    empty!(status)
    empty!(setpoints)
    empty!(throws)
    diode_limit_raw[] = limit_raw
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

end

@eval MicroscopeControl.HardwareImplementations.TCubeLaserControl begin
    TLI_BuildDeviceList() = Main.FakeKinesis.record!("TLI_BuildDeviceList")
    TLI_GetDeviceListSize() = (Main.FakeKinesis.record!("TLI_GetDeviceListSize"); 1)
    LD_Open(serialNo) = Main.FakeKinesis.record!("LD_Open")
    LD_Close(serialNo) = (Main.FakeKinesis.record!("LD_Close"); nothing)
    LD_SetOpenLoopMode(serialNo) = Main.FakeKinesis.record!("LD_SetOpenLoopMode")
    LD_RequestReadings(serialNo) = Main.FakeKinesis.record!("LD_RequestReadings")
    LD_EnableOutput(serialNo) = Main.FakeKinesis.record!("LD_EnableOutput")
    LD_DisableOutput(serialNo) = Main.FakeKinesis.record!("LD_DisableOutput")
    function LD_SetLaserSetPoint(serialNo, laserDiodeCurrent)
        push!(Main.FakeKinesis.setpoints, laserDiodeCurrent)
        return Main.FakeKinesis.record!("LD_SetLaserSetPoint")
    end
    function LD_GetLaserDiodeMaxCurrentLimit(serialNo)
        Main.FakeKinesis.record!("LD_GetLaserDiodeMaxCurrentLimit")
        return Main.FakeKinesis.diode_limit_raw[]
    end
    function LD_GetLaserDiodeCurrentReading(serialNo)
        Main.FakeKinesis.record!("LD_GetLaserDiodeCurrentReading")
        return Main.FakeKinesis.diode_limit_raw[]
    end
end
