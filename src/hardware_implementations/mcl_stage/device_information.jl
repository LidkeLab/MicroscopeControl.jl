function isdeviceattached(stage::MCLStage)
    #Waits max 500 miliseconds
    isattached = @ccall madlibpath.MCL_DeviceAttached(Cint(500)::Cint, stage.id::Cint)::Cint

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
    @ccall madlibpath.MCL_PrintDeviceInfo(stage.id::Cint)::Cvoid
    return nothing
end

function getserialnumber(stage::MCLStage)
    serialnumber = @ccall madlibpath.MCL_GetSerialNumber(stage.id::Cint)::Cint
    return serialnumber
end

function getcommandedposition(stage::MCLStage)
    x_commanded = Ref{Cdouble}(0.0)
    y_commanded = Ref{Cdouble}(0.0)
    z_commanded = Ref{Cdouble}(0.0)

    @ccall madlibpath.MCL_GetCommandedPosition(x_commanded::Ptr{Cdouble}, y_commanded::Ptr{Cdouble}, z_commanded::Ptr{Cdouble}, stage.id::Cint)::Cvoid
    return x_commanded[], y_commanded[], z_commanded[]  #Could change target to this?
end

function getcalibration(stage::MCLStage, axis::Int) #This returns the maximum value of each axis
    if axis == 1
        calibration = @ccall madlibpath.MCL_GetCalibration(Cint(1)::Cint, stage.id::Cint)::Cdouble
        stage.range_x = (0.0, calibration)
    elseif axis == 2
        calibration = @ccall madlibpath.MCL_GetCalibration(Cint(2)::Cint, stage.id::Cint)::Cdouble
        stage.range_y = (0.0, calibration)
    elseif axis == 3
        calibration = @ccall madlibpath.MCL_GetCalibration(Cint(3)::Cint, stage.id::Cint)::Cdouble
        stage.range_z = (0.0, calibration)
    else
        @error "Invalid axis"
        return false
    end
end
