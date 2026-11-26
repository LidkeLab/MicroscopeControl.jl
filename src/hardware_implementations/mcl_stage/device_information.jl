"""
    isdeviceattached(stage::MCLStage) -> Bool

Ask the Madlib library whether the Nano-Drive with handle `stage.id` is attached (`MCL_DeviceAttached`, waiting
up to 500 ms), set `stage.connectionstatus` to the answer, log it, and return it. It does not throw when the
device is absent. It uses the handle already in `stage.id`, so call it after `initialize`.
"""
function isdeviceattached(stage::MCLStage)
    #Waits max 500 miliseconds
    isattached = @ccall libmadlib.MCL_DeviceAttached(Cint(500)::Cint, stage.id::Cint)::Cint

    if isattached == 1
        @info "Device Attached"
        stage.connectionstatus = true
    else
        @error "Device Not Attached"
        stage.connectionstatus = false
    end

    return stage.connectionstatus
end

"""
    printdeviceinfo(stage::MCLStage) -> nothing

Have the Madlib library print the device information of handle `stage.id` (`MCL_PrintDeviceInfo`). The text
is written by the library, not returned to Julia, so it may not appear in a Julia session's output.
"""
function printdeviceinfo(stage::MCLStage)
    @ccall libmadlib.MCL_PrintDeviceInfo(stage.id::Cint)::Cvoid
    return nothing
end

"""
    getserialnumber(stage::MCLStage) -> Int32

Return the serial number of the Nano-Drive with handle `stage.id` (`MCL_GetSerialNumber`) as the library
reports it. The value is not checked, so a library error code comes back as a number, not a throw.
"""
function getserialnumber(stage::MCLStage)
    serialnumber = @ccall libmadlib.MCL_GetSerialNumber(stage.id::Cint)::Cint
    return serialnumber
end

"""
    getcommandedposition(stage::MCLStage) -> (x, y, z)

Return the position last commanded to the controller (`MCL_GetCommandedPosition`) as three `Float64`s, in
the stage's units (micrometers per [`MCLStage`](@ref)). Unlike `getposition`, it asks for the commanded
position rather than a measured one, and it does not update `real_x`, `real_y`, `real_z` or the targets.
The call's status is not checked.
"""
function getcommandedposition(stage::MCLStage)
    x_commanded = Ref{Cdouble}(0.0)
    y_commanded = Ref{Cdouble}(0.0)
    z_commanded = Ref{Cdouble}(0.0)

    @ccall libmadlib.MCL_GetCommandedPosition(x_commanded::Ptr{Cdouble}, y_commanded::Ptr{Cdouble}, z_commanded::Ptr{Cdouble}, stage.id::Cint)::Cvoid
    return x_commanded[], y_commanded[], z_commanded[]  #Could change target to this?
end

_mcl_calibration(axis::Int, id::Int) = @ccall libmadlib.MCL_GetCalibration(axis::Cint, id::Cint)::Cdouble

"""
    getcalibration(stage::MCLStage, axis::Int) -> Tuple{Float64,Float64} or false

Read the calibration (maximum travel) of axis `axis` (1 = X, 2 = Y, 3 = Z) with `MCL_GetCalibration`, store
`(0.0, calibration)` in `stage.range_x`, `range_y` or `range_z`, and return that tuple. An axis outside 1 to 3
logs an error and returns `false`. A negative integer library result throws an `ErrorException` naming the
Madlib error when the code is a known one ("unknown error" otherwise); a non-finite result throws one saying the
value is invalid.
"""
function getcalibration(stage::MCLStage, axis::Int) # Maximum value of each axis
    if !(axis in 1:3)
        @error "Invalid axis"
        return false
    end
    calibration = checked_mcl_value(_mcl_calibration(axis, stage.id), "calibration axis $axis")
    return setfield!(stage, (:range_x, :range_y, :range_z)[axis], (0.0, calibration))
end
