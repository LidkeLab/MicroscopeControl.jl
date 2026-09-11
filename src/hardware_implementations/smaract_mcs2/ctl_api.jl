#=
Thin Julia wrappers around the SmarActCTL C API (SmarActCTL.dll).

Every wrapper checks the SA_CTL_Result_t return code and throws an `MCS2Error`
carrying the vendor's human readable description. Nothing in this file knows
about `MCS2Stage`; the layers above translate axes to channel indices and
microns to picometres.
=#

"""
    MCS2Error(code, msg, context)

Raised when a SmarActCTL call returns a non-zero result code. `msg` is the
description returned by `SA_CTL_GetResultInfo` and `context` names the call
that failed.
"""
struct MCS2Error <: Exception
    code::UInt32
    msg::String
    context::String
end

function Base.showerror(io::IO, e::MCS2Error)
    print(io, "MCS2 ", e.context, " failed: ", e.msg,
        " (error 0x", string(e.code, base=16, pad=4), ")")
end

"""
    resultinfo(code) -> String

Human readable description of a SmarActCTL result code.
"""
resultinfo(code::Integer) =
    unsafe_string(@ccall ctlpath.SA_CTL_GetResultInfo(UInt32(code)::UInt32)::Cstring)

"""
    checkresult(code, context)

Throw an [`MCS2Error`](@ref) unless `code` is `SA_CTL_ERROR_NONE`.
"""
function checkresult(code::UInt32, context::AbstractString)
    code == SA_CTL_ERROR_NONE || throw(MCS2Error(code, resultinfo(code), context))
    return nothing
end

"""
    libraryversion() -> String

Version of the installed SmarActCTL library. This is the only SDK call that
does not need an open device, so it doubles as a check that the DLL is
reachable.
"""
libraryversion() =
    unsafe_string(@ccall ctlpath.SA_CTL_GetFullVersionString()::Cstring)

"""
    finddevices(options="") -> Vector{String}

Locator strings of all MCS2 controllers the SDK can see. An empty vector means
no controller was found - check that it is powered on and connected.
"""
function finddevices(options::AbstractString="")
    buffer = zeros(UInt8, 4096)
    len = Ref{Csize_t}(length(buffer))
    result = @ccall ctlpath.SA_CTL_FindDevices(
        options::Cstring, buffer::Ptr{UInt8}, len::Ptr{Csize_t})::UInt32
    checkresult(result, "find devices")
    return String[String(strip(l)) for l in split(unsafe_string(pointer(buffer)), '\n') if !isempty(strip(l))]
end

"""
    opendevice(locator; config="") -> UInt32

Open a connection to the controller at `locator` and return its device handle.
"""
function opendevice(locator::AbstractString; config::AbstractString="")
    handle = Ref{UInt32}(0)
    result = @ccall ctlpath.SA_CTL_Open(
        handle::Ptr{UInt32}, locator::Cstring, config::Cstring)::UInt32
    checkresult(result, "open \"$locator\"")
    return handle[]
end

"""
    closedevice(handle)

Close the connection to a controller.
"""
function closedevice(handle::UInt32)
    result = @ccall ctlpath.SA_CTL_Close(handle::UInt32)::UInt32
    checkresult(result, "close device")
end

# --- Property access ---------------------------------------------------------
# `idx` addresses the device (0), a module or a channel depending on the key.

"""
    get_i32(handle, idx, pkey) -> Int32

Read a 32-bit integer property.
"""
function get_i32(handle::UInt32, idx::Integer, pkey::UInt32)
    value = Ref{Int32}(0)
    result = @ccall ctlpath.SA_CTL_GetProperty_i32(
        handle::UInt32, Int8(idx)::Int8, pkey::UInt32,
        value::Ptr{Int32}, C_NULL::Ptr{Csize_t})::UInt32
    checkresult(result, "read property $(keystring(pkey)) at index $idx")
    return value[]
end

"""
    set_i32(handle, idx, pkey, value)

Write a 32-bit integer property.
"""
function set_i32(handle::UInt32, idx::Integer, pkey::UInt32, value::Integer)
    result = @ccall ctlpath.SA_CTL_SetProperty_i32(
        handle::UInt32, Int8(idx)::Int8, pkey::UInt32, Int32(value)::Int32)::UInt32
    checkresult(result, "write property $(keystring(pkey)) at index $idx")
end

"""
    get_i64(handle, idx, pkey) -> Int64

Read a 64-bit integer property (positions, velocities and limits).
"""
function get_i64(handle::UInt32, idx::Integer, pkey::UInt32)
    value = Ref{Int64}(0)
    result = @ccall ctlpath.SA_CTL_GetProperty_i64(
        handle::UInt32, Int8(idx)::Int8, pkey::UInt32,
        value::Ptr{Int64}, C_NULL::Ptr{Csize_t})::UInt32
    checkresult(result, "read property $(keystring(pkey)) at index $idx")
    return value[]
end

"""
    set_i64(handle, idx, pkey, value)

Write a 64-bit integer property.
"""
function set_i64(handle::UInt32, idx::Integer, pkey::UInt32, value::Integer)
    result = @ccall ctlpath.SA_CTL_SetProperty_i64(
        handle::UInt32, Int8(idx)::Int8, pkey::UInt32, Int64(value)::Int64)::UInt32
    checkresult(result, "write property $(keystring(pkey)) at index $idx")
end

"""
    get_str(handle, idx, pkey; buffersize=128) -> String

Read a string property such as the device name or positioner type name.
"""
function get_str(handle::UInt32, idx::Integer, pkey::UInt32; buffersize::Integer=128)
    buffer = zeros(UInt8, buffersize)
    len = Ref{Csize_t}(buffersize)
    result = @ccall ctlpath.SA_CTL_GetProperty_s(
        handle::UInt32, Int8(idx)::Int8, pkey::UInt32,
        buffer::Ptr{UInt8}, len::Ptr{Csize_t})::UInt32
    checkresult(result, "read property $(keystring(pkey)) at index $idx")
    return unsafe_string(pointer(buffer))
end

keystring(pkey::UInt32) = "0x" * string(pkey, base=16, pad=8)

# --- Motion commands ---------------------------------------------------------
# All four are non-blocking: they return as soon as the command is queued.

"""
    movecommand(handle, channel, value)

Issue `SA_CTL_Move` on `channel`. `value` is interpreted according to the
channel's current move mode (a position in pm for closed-loop modes, a step
count for open-loop step mode).
"""
function movecommand(handle::UInt32, channel::Integer, value::Integer)
    result = @ccall ctlpath.SA_CTL_Move(
        handle::UInt32, Int8(channel)::Int8, Int64(value)::Int64, UInt32(0)::UInt32)::UInt32
    checkresult(result, "move channel $channel")
end

"""
    stopcommand(handle, channel)

Abort any ongoing movement on `channel` and release the position hold.
"""
function stopcommand(handle::UInt32, channel::Integer)
    result = @ccall ctlpath.SA_CTL_Stop(
        handle::UInt32, Int8(channel)::Int8, UInt32(0)::UInt32)::UInt32
    checkresult(result, "stop channel $channel")
end

"""
    referencecommand(handle, channel)

Start the referencing sequence on `channel`. **This moves the positioner.**
"""
function referencecommand(handle::UInt32, channel::Integer)
    result = @ccall ctlpath.SA_CTL_Reference(
        handle::UInt32, Int8(channel)::Int8, UInt32(0)::UInt32)::UInt32
    checkresult(result, "reference channel $channel")
end

"""
    calibratecommand(handle, channel)

Start the calibration sequence on `channel`. **This moves the positioner**, by
up to several mm, so it must not be started close to an end stop.
"""
function calibratecommand(handle::UInt32, channel::Integer)
    result = @ccall ctlpath.SA_CTL_Calibrate(
        handle::UInt32, Int8(channel)::Int8, UInt32(0)::UInt32)::UInt32
    checkresult(result, "calibrate channel $channel")
end
