# A fake DCAM SDK for the DCAM4 camera driver.
#
# There is no Hamamatsu DCAM library on any build machine, so the capture paths
# (`getdata`, `stop_and_release!`, the start of `sequence` and `live`) could not
# run here. The seam is the one `tcube_fake_sdk.jl` uses: the DCAM wrappers are
# plain typed functions in the `DCAM4` module, each one a `ccall` into
# `dcamapi.dll`. Defining a method with the identical signature into that module
# replaces it, so the driver's own code runs unmodified against a recorder.
# Only the wrappers the capture tests reach are replaced: the capture, buffer
# and property calls below. `dcamprop_getsize` is replaced too, to return a fixed
# 2 x 2 sensor.
#
# Each replaced wrapper records its name in `FakeDCAM.calls` and returns
# `DCAMERR_SUCCESS` unless the test set a code for it in `FakeDCAM.codes`.
# `FakeDCAM.status` is the capture status `dcamcap_status` reports, and
# `FakeDCAM.on_status` is called on every status read, so a test can change the
# camera in the middle of a poll.
#
# The API and device calls (`dcamapi_init`/`_uninit`, `dcamdev_open`/`_close`) and the wait calls
# (`dcamwait_open`/`_close`/`_abort`/`_event`) are replaced too. `FakeDCAM.api_up` says whether the API is
# initialized; while it is not, and `FakeDCAM.api_down_code` is set, every other recorded call answers that code, as
# a library whose API was uninitialized under a camera would. `dcamwait_event` answers at once (`wait_mode == :ready`) or
# blocks, in Julia, until `dcamwait_abort` reaches it or its timeout passes (`:block`): it sleeps in
# a loop, so a task on the same thread can run, which is what lets a test call `abort` during a wait.
# An abort is not remembered: it reaches a wait only while the wait is inside the event
# (after `entry_delay` seconds), the conservative reading of an SDK that does not say. `in_wait` counts the
# waits inside the event; `dcamcap_stop` and `dcambuf_release` record a violation when one runs while it is above zero.
#
# What this seam does NOT cover:
#
#   * The replacements are global and permanent for the process. That is why
#     runtests.jl includes this file LAST, after every other testset, followed
#     only by the tests that use it (`dcam4_fake_paths.jl`): no other test runs
#     against the fake. No public signature changes.
#   * Code compiled before the include keeps calling the old methods until it
#     re-enters at the latest world age; the tests that use the fake are
#     therefore their own included file, whose top level runs after it.
#   * Including `runtests.jl` into an interactive session leaves it
#     contaminated; the replacements are not undone. `Main.FakeDCAM` assumes
#     inclusion into `Main`.
#   * It says nothing about DLL loading, the `ccall` bodies, or how a real camera
#     answers: all three can be broken while every assertion passes. It is not
#     hardware verification. Julia prints a "Method definition ... overwritten"
#     warning per wrapper as this file is included; they are expected.

"""
    FakeDCAM

Recorder standing in for the Hamamatsu DCAM SDK: the wrappers the driver called,
in order, the code each reports back, and the capture status it reports.
"""
module FakeDCAM

"Wrapper names in the order the driver called them, since the last `reset!`."
const calls = String[]

"Code each wrapper reports; absent means `DCAMERR_SUCCESS`."
const codes = Dict{String,Any}()

"The capture status `dcamcap_status` reports (a `DCAMCAP_STATUS`)."
const status = Ref{Any}(nothing)

"Called with no arguments on every `dcamcap_status`, before it answers."
const on_status = Ref{Function}(() -> nothing)

"The frame count `dcamcap_transferinfo` reports."
const frames_transferred = Ref(0)

"Property values written by `dcamprop_setvalue`, read back by `dcamprop_getvalue` (default 0)."
const values = Dict{Int32,Float64}()

"Whether the API is initialized (`dcamapi_init` and not yet `dcamapi_uninit`)."
const api_up = Ref(false)

"The code every recorded call answers while `api_up` is false; `nothing` leaves the calls alone."
const api_down_code = Ref{Any}(nothing)

"`dcamapi_init` and `dcamapi_uninit` calls, since the last `reset!`."
const inits = Ref(0)
const uninits = Ref(0)

"The device count `dcamapi_init` reports."
const device_count = Ref(1)

"The handles `dcamdev_close` was called with, in order."
const closed = Ptr{Cvoid}[]

"`:ready` (`dcamwait_event` answers at once) or `:block` (it waits for an abort or its timeout)."
const wait_mode = Ref(:ready)

"Seconds `dcamwait_event` spends before it can be aborted (an abort sent meanwhile is lost)."
const entry_delay = Ref(0.0)

"Called with no arguments as `dcamwait_event` leaves, before it answers."
const after_wait = Ref{Function}(() -> nothing)

"Called with no arguments as `dcamwait_event` is entered (a fault can be injected here), and as `dcamwait_close` and `dcamdev_close` start."
const on_wait_enter = Ref{Function}(() -> nothing)
const on_wait_close = Ref{Function}(() -> nothing)
const on_dev_close = Ref{Function}(() -> nothing)

"Makes a `:block` wait return success, as a frame arriving."
const ready_now = Ref(false)

"The mode each `dcamcap_start` was given, in order; `on_start` is called with it."
const start_modes = Int32[]
const on_start = Ref{Function}(m -> nothing)

"The waits inside `dcamwait_event` now; the handles that are open; those that were aborted while inside it."
const in_wait = Ref(0)
const open_waits = Set{Ptr{Cvoid}}()
const active = Set{Ptr{Cvoid}}()
const aborted = Set{Ptr{Cvoid}}()

"Waits that ended by timeout, and `dcamcap_stop`/`dcambuf_release` calls that ran while a wait was in the event."
const timeouts = Ref(0)
const violations = String[]

const next_handle = Ref(0)

function record!(op::AbstractString, default)
    push!(calls, op)
    api_down_code[] !== nothing && !api_up[] && return api_down_code[]
    return get(codes, op, default)
end

"Forget the history and restore the defaults."
function reset!()
    empty!(calls)
    empty!(codes)
    empty!(values)
    status[] = nothing
    on_status[] = () -> nothing
    frames_transferred[] = 0
    api_up[] = false
    api_down_code[] = nothing
    inits[] = 0
    uninits[] = 0
    device_count[] = 1
    empty!(closed)
    wait_mode[] = :ready
    entry_delay[] = 0.0
    after_wait[] = () -> nothing
    on_wait_enter[] = () -> nothing
    on_wait_close[] = () -> nothing
    on_dev_close[] = () -> nothing
    ready_now[] = false
    empty!(start_modes)
    on_start[] = m -> nothing
    in_wait[] = 0
    empty!(open_waits); empty!(active); empty!(aborted)
    timeouts[] = 0
    empty!(violations)
    return nothing
end

"The index of the first call to `op`, or `nothing`."
first_index(op) = findfirst(==(op), calls)
"The index of the last call to `op`, or `nothing`."
last_index(op) = findlast(==(op), calls)

end

@eval MicroscopeControl.HardwareImplementations.DCAM4 begin
    function dcamcap_start(hdcam::Ptr{Cvoid}, mode::Int32)
        push!(Main.FakeDCAM.start_modes, mode)
        Main.FakeDCAM.on_start[](mode)
        return Main.FakeDCAM.record!("dcamcap_start", DCAMERR_SUCCESS)
    end
    function dcamcap_stop(hdcam::Ptr{Cvoid})
        Main.FakeDCAM.in_wait[] > 0 && push!(Main.FakeDCAM.violations, "dcamcap_stop")
        return Main.FakeDCAM.record!("dcamcap_stop", DCAMERR_SUCCESS)
    end
    function dcamcap_status(hdcam::Ptr{Cvoid})
        err = Main.FakeDCAM.record!("dcamcap_status", DCAMERR_SUCCESS)
        Main.FakeDCAM.on_status[]()
        st = Main.FakeDCAM.status[]
        return err, st === nothing ? DCAMCAP_STATUS_STABLE : st
    end
    function dcamcap_transferinfo(hdcam::Ptr{Cvoid})
        err = Main.FakeDCAM.record!("dcamcap_transferinfo", DCAMERR_SUCCESS)
        info = DCAMCAP_TRANSFERINFO()
        info.nFrameCount = Main.FakeDCAM.frames_transferred[]
        return err, info
    end
    dcambuf_alloc(hdcam::Ptr{Cvoid}, framecount::Int32) = Main.FakeDCAM.record!("dcambuf_alloc", DCAMERR_SUCCESS)
    function dcambuf_release(hdcam::Ptr{Cvoid})
        Main.FakeDCAM.in_wait[] > 0 && push!(Main.FakeDCAM.violations, "dcambuf_release")
        return Main.FakeDCAM.record!("dcambuf_release", DCAMERR_SUCCESS)
    end
    function dcambuf_getframe_err(hdcam::Ptr{Cvoid}, iFrame::Int32)
        err = Main.FakeDCAM.record!("dcambuf_getframe_err", DCAMERR_SUCCESS)
        return err, is_failed(err) ? nothing : zeros(UInt16, 2, 2)
    end
    dcamprop_getsize(hdcam::Ptr{Cvoid}) = (2, 2)
    function dcamprop_getattr(hdcam::Ptr{Cvoid}, iProp::Int32)
        dca = DCAMPROP_ATTR()
        dca.attribute = Int32(-1)   # every attribute bit: writable, with a range
        return Main.FakeDCAM.record!("dcamprop_getattr", DCAMERR_SUCCESS), dca
    end
    function dcamprop_setvalue(hdcam::Ptr{Cvoid}, iProp::Int32, fValue::Float64)
        Main.FakeDCAM.values[iProp] = fValue
        return Main.FakeDCAM.record!("dcamprop_setvalue", DCAMERR_SUCCESS)
    end
    dcamprop_getvalue(hdcam::Ptr{Cvoid}, iProp::Int32) =
        (Main.FakeDCAM.record!("dcamprop_getvalue", DCAMERR_SUCCESS), get(Main.FakeDCAM.values, iProp, 0.0))

    function dcamapi_init()
        FK = Main.FakeDCAM
        push!(FK.calls, "dcamapi_init")
        FK.inits[] += 1
        dci = DCAMAPI_INIT()
        dci.iDeviceCount = FK.device_count[]
        err = get(FK.codes, "dcamapi_init", DCAMERR_SUCCESS)
        FK.api_up[] = !is_failed(err)
        return err, dci
    end
    function dcamapi_uninit()
        FK = Main.FakeDCAM
        push!(FK.calls, "dcamapi_uninit")
        FK.uninits[] += 1
        FK.api_up[] = false
        return get(FK.codes, "dcamapi_uninit", DCAMERR_SUCCESS)
    end
    function dcamdev_open(i::Int)
        err = Main.FakeDCAM.record!("dcamdev_open", DCAMERR_SUCCESS)
        dco = DCAMDEV_OPEN()
        dco.index = Int32(i)
        dco.hdcam = is_failed(err) ? C_NULL : Ptr{Cvoid}(UInt(0x100 * (i + 1)))
        return err, dco
    end
    function dcamdev_close(hdcam::Ptr{Cvoid})
        FK = Main.FakeDCAM
        isempty(FK.open_waits) || push!(FK.violations, "dcamdev_close with a wait handle open")
        push!(FK.closed, hdcam)
        err = FK.record!("dcamdev_close", DCAMERR_SUCCESS)
        FK.on_dev_close[]()
        push!(FK.calls, "dcamdev_close_end")
        return err
    end
    dcamdev_getstring(hdcam::Ptr{Cvoid}, strid::DCAM_IDSTR) =
        (Main.FakeDCAM.record!("dcamdev_getstring", DCAMERR_SUCCESS), "FAKE")

    function dcamwait_open(hdcam::Ptr{Cvoid})
        FK = Main.FakeDCAM
        err = FK.record!("dcamwait_open", DCAMERR_SUCCESS)
        is_failed(err) && return err, C_NULL
        FK.next_handle[] += 1
        hwait = Ptr{Cvoid}(UInt(0x10000 + 16 * FK.next_handle[]))
        push!(FK.open_waits, hwait)
        return err, hwait
    end
    function dcamwait_close(hwait::Ptr{Cvoid})
        FK = Main.FakeDCAM
        FK.on_wait_close[]()
        delete!(FK.open_waits, hwait)
        return FK.record!("dcamwait_close", DCAMERR_SUCCESS)
    end
    function dcamwait_abort(hwait::Ptr{Cvoid})
        FK = Main.FakeDCAM
        hwait in FK.active && push!(FK.aborted, hwait)  # not remembered by a wait that is not inside the event
        return FK.record!("dcamwait_abort", DCAMERR_SUCCESS)
    end
    function dcamwait_event(hwait::Ptr{Cvoid}, eventmask::Int32, timeout_millisec::Int32)
        FK = Main.FakeDCAM
        err = FK.record!("dcamwait_event", DCAMERR_SUCCESS)
        FK.in_wait[] += 1
        try
            FK.on_wait_enter[]()
            if is_failed(err)
                # answered by the call itself
            elseif FK.wait_mode[] == :block
                FK.entry_delay[] > 0 && sleep(FK.entry_delay[])
                push!(FK.active, hwait)
                deadline = time() + timeout_millisec / 1000
                err = DCAMERR_TIMEOUT
                while time() < deadline
                    if hwait in FK.aborted
                        err = DCAMERR_ABORT
                        break
                    end
                    if FK.ready_now[]
                        err = DCAMERR_SUCCESS
                        break
                    end
                    sleep(0.002)
                end
                err == DCAMERR_TIMEOUT && (FK.timeouts[] += 1)
                delete!(FK.active, hwait)
                delete!(FK.aborted, hwait)
            end
            FK.after_wait[]()
        finally
            FK.in_wait[] -= 1
        end
        push!(FK.calls, "dcamwait_event_end")
        return err, eventmask
    end
end
