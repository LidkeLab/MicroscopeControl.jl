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

function printdeviceinfo(stage::MCLStage)
    @ccall libmadlib.MCL_PrintDeviceInfo(stage.id::Cint)::Cvoid
    return nothing
end

function getserialnumber(stage::MCLStage)
    serialnumber = @ccall libmadlib.MCL_GetSerialNumber(stage.id::Cint)::Cint
    return serialnumber
end

function getcommandedposition(stage::MCLStage)
    x_commanded = Ref{Cdouble}(0.0)
    y_commanded = Ref{Cdouble}(0.0)
    z_commanded = Ref{Cdouble}(0.0)

    @ccall libmadlib.MCL_GetCommandedPosition(x_commanded::Ptr{Cdouble}, y_commanded::Ptr{Cdouble}, z_commanded::Ptr{Cdouble}, stage.id::Cint)::Cvoid
    return x_commanded[], y_commanded[], z_commanded[]  #Could change target to this?
end

_mcl_calibration(axis::Int, id::Int) = @ccall libmadlib.MCL_GetCalibration(axis::Cint, id::Cint)::Cdouble

function getcalibration(stage::MCLStage, axis::Int) # Maximum value of each axis
    if !(axis in 1:3)
        @error "Invalid axis"
        return false
    end
    calibration = checked_mcl_value(_mcl_calibration(axis, stage.id), "calibration axis $axis")
    return setfield!(stage, (:range_x, :range_y, :range_z)[axis], (0.0, calibration))
end
