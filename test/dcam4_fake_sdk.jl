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

record!(op::AbstractString, default) = (push!(calls, op); get(codes, op, default))

"Forget the history and restore the defaults."
function reset!()
    empty!(calls)
    empty!(codes)
    empty!(values)
    status[] = nothing
    on_status[] = () -> nothing
    frames_transferred[] = 0
    return nothing
end

"The index of the first call to `op`, or `nothing`."
first_index(op) = findfirst(==(op), calls)
"The index of the last call to `op`, or `nothing`."
last_index(op) = findlast(==(op), calls)

end

@eval MicroscopeControl.HardwareImplementations.DCAM4 begin
    dcamcap_start(hdcam::Ptr{Cvoid}, mode::Int32) = Main.FakeDCAM.record!("dcamcap_start", DCAMERR_SUCCESS)
    dcamcap_stop(hdcam::Ptr{Cvoid}) = Main.FakeDCAM.record!("dcamcap_stop", DCAMERR_SUCCESS)
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
    dcambuf_release(hdcam::Ptr{Cvoid}) = Main.FakeDCAM.record!("dcambuf_release", DCAMERR_SUCCESS)
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
end
