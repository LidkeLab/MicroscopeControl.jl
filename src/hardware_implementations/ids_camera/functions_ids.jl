# no prototype is found for this function at ids_peak_comfort_c.h:1362:17, please use with caution
function peak_Library_Init()
    ccall((:peak_Library_Init, IDS), peak_status, ())
end

# no prototype is found for this function at ids_peak_comfort_c.h:1381:17, please use with caution
function peak_Library_Exit()
    ccall((:peak_Library_Exit, IDS), peak_status, ())
end

function peak_Library_GetVersion(majorVersion, minorVersion, subminorVersion, patchVersion)
    ccall((:peak_Library_GetVersion, IDS), peak_status, (Ptr{UInt32}, Ptr{UInt32}, Ptr{UInt32}, Ptr{UInt32}), majorVersion, minorVersion, subminorVersion, patchVersion)
end

function peak_Library_GetLastError(lastErrorCode, lastErrorMessage, lastErrorMessageSize)
    ccall((:peak_Library_GetLastError, IDS), peak_status, (Ptr{peak_status}, Ptr{Cchar}, Ptr{Csize_t}), lastErrorCode, lastErrorMessage, lastErrorMessageSize)
end

function peak_Library_InterfaceTechnology_IsSupported(interfaceTech)
    ccall((:peak_Library_InterfaceTechnology_IsSupported, IDS), peak_bool, (peak_interface_technology,), interfaceTech)
end

function peak_Reconnect_Enable(interfaceTech, enabled)
    ccall((:peak_Reconnect_Enable, IDS), peak_status, (peak_interface_technology, peak_bool), interfaceTech, enabled)
end

function peak_Reconnect_IsEnabled(interfaceTech)
    ccall((:peak_Reconnect_IsEnabled, IDS), peak_bool, (peak_interface_technology,), interfaceTech)
end

function peak_Reconnect_GetAccessStatus(interfaceTech)
    ccall((:peak_Reconnect_GetAccessStatus, IDS), peak_access_status, (peak_interface_technology,), interfaceTech)
end

function peak_CameraList_Update(cameraCount)
    ccall((:peak_CameraList_Update, IDS), peak_status, (Ptr{Csize_t},), cameraCount)
end

function peak_CameraList_Get(cameraList, cameraCount)
    ccall((:peak_CameraList_Get, IDS), peak_status, (Ptr{peak_camera_descriptor}, Ptr{Csize_t}), cameraList, cameraCount)
end

function peak_Camera_ID_FromHandle(hCam)
    ccall((:peak_Camera_ID_FromHandle, IDS), peak_camera_id, (peak_camera_handle,), hCam)
end

function peak_Camera_ID_FromSerialNumber(serialNumber)
    ccall((:peak_Camera_ID_FromSerialNumber, IDS), peak_camera_id, (Ptr{Cchar},), serialNumber)
end

function peak_Camera_ID_FromUserDefinedName(userDefinedName)
    ccall((:peak_Camera_ID_FromUserDefinedName, IDS), peak_camera_id, (Ptr{Cchar},), userDefinedName)
end

function peak_Camera_ID_FromMAC(macAddress)
    ccall((:peak_Camera_ID_FromMAC, IDS), peak_camera_id, (peak_mac_address,), macAddress)
end

function peak_Camera_GetAccessStatus(cameraID)
    ccall((:peak_Camera_GetAccessStatus, IDS), peak_access_status, (peak_camera_id,), cameraID)
end

function peak_Camera_GetDescriptor(cameraID, cameraDescriptor)
    ccall((:peak_Camera_GetDescriptor, IDS), peak_status, (peak_camera_id, Ptr{peak_camera_descriptor}), cameraID, cameraDescriptor)
end

function peak_Camera_Open(cameraID, hCam)
    ccall((:peak_Camera_Open, IDS), peak_status, (peak_camera_id, Ptr{peak_camera_handle}), cameraID, hCam)
end

function peak_Camera_OpenFirstAvailable(hCam)
    ccall((:peak_Camera_OpenFirstAvailable, IDS), peak_status, (Ptr{peak_camera_handle},), hCam)
end

function peak_Camera_Close(hCam)
    ccall((:peak_Camera_Close, IDS), peak_status, (peak_camera_handle,), hCam)
end

function peak_Camera_ResetToDefaultSettings(hCam)
    ccall((:peak_Camera_ResetToDefaultSettings, IDS), peak_status, (peak_camera_handle,), hCam)
end

function peak_Camera_UserDefinedName_Set(hCam, userDefinedName)
    ccall((:peak_Camera_UserDefinedName_Set, IDS), peak_status, (peak_camera_handle, Ptr{Cchar}), hCam, userDefinedName)
end

function peak_Camera_UserDefinedName_Get(hCam, userDefinedName, userDefinedNameSize)
    ccall((:peak_Camera_UserDefinedName_Get, IDS), peak_status, (peak_camera_handle, Ptr{Cchar}, Ptr{Csize_t}), hCam, userDefinedName, userDefinedNameSize)
end

function peak_Camera_IsConnected(hCam)
    ccall((:peak_Camera_IsConnected, IDS), peak_bool, (peak_camera_handle,), hCam)
end

function peak_Camera_Reboot(hCam)
    ccall((:peak_Camera_Reboot, IDS), peak_status, (peak_camera_handle,), hCam)
end

function peak_EthernetConfig_GetAccessStatus(cameraID)
    ccall((:peak_EthernetConfig_GetAccessStatus, IDS), peak_access_status, (peak_camera_id,), cameraID)
end

function peak_EthernetConfig_GetInfo(cameraID, ethernetInfo)
    ccall((:peak_EthernetConfig_GetInfo, IDS), peak_status, (peak_camera_id, Ptr{peak_ethernet_info}), cameraID, ethernetInfo)
end

function peak_EthernetConfig_DHCP_GetAccessStatus(cameraID)
    ccall((:peak_EthernetConfig_DHCP_GetAccessStatus, IDS), peak_access_status, (peak_camera_id,), cameraID)
end

function peak_EthernetConfig_DHCP_Enable(cameraID, enabled)
    ccall((:peak_EthernetConfig_DHCP_Enable, IDS), peak_status, (peak_camera_id, peak_bool), cameraID, enabled)
end

function peak_EthernetConfig_DHCP_IsEnabled(cameraID)
    ccall((:peak_EthernetConfig_DHCP_IsEnabled, IDS), peak_bool, (peak_camera_id,), cameraID)
end

function peak_EthernetConfig_PersistentIP_GetAccessStatus(cameraID)
    ccall((:peak_EthernetConfig_PersistentIP_GetAccessStatus, IDS), peak_access_status, (peak_camera_id,), cameraID)
end

function peak_EthernetConfig_PersistentIP_Set(cameraID, persistentIP)
    ccall((:peak_EthernetConfig_PersistentIP_Set, IDS), peak_status, (peak_camera_id, peak_ip_config), cameraID, persistentIP)
end

function peak_EthernetConfig_PersistentIP_Get(cameraID, persistentIP)
    ccall((:peak_EthernetConfig_PersistentIP_Get, IDS), peak_status, (peak_camera_id, Ptr{peak_ip_config}), cameraID, persistentIP)
end

function peak_Acquisition_Start(hCam, numberOfFrames)
    ccall((:peak_Acquisition_Start, IDS), peak_status, (peak_camera_handle, UInt32), hCam, numberOfFrames)
end

function peak_Acquisition_Stop(hCam)
    ccall((:peak_Acquisition_Stop, IDS), peak_status, (peak_camera_handle,), hCam)
end

function peak_Acquisition_IsStarted(hCam)
    ccall((:peak_Acquisition_IsStarted, IDS), peak_bool, (peak_camera_handle,), hCam)
end

function peak_Acquisition_WaitForFrame(hCam, timeout_ms, hFrame)
    ccall((:peak_Acquisition_WaitForFrame, IDS), peak_status, (peak_camera_handle, UInt32, Ptr{peak_frame_handle}), hCam, timeout_ms, hFrame)
end

function peak_Acquisition_GetInfo(hCam, acquisitionInfo)
    ccall((:peak_Acquisition_GetInfo, IDS), peak_status, (peak_camera_handle, Ptr{peak_acquisition_info}), hCam, acquisitionInfo)
end

function peak_Acquisition_Buffer_GetRequiredSize(hCam, requiredBufferSize)
    ccall((:peak_Acquisition_Buffer_GetRequiredSize, IDS), peak_status, (peak_camera_handle, Ptr{Csize_t}), hCam, requiredBufferSize)
end

function peak_Acquisition_Buffer_GetRequiredCount(hCam, requiredBufferCount)
    ccall((:peak_Acquisition_Buffer_GetRequiredCount, IDS), peak_status, (peak_camera_handle, Ptr{Csize_t}), hCam, requiredBufferCount)
end

function peak_Acquisition_Buffer_Announce(hCam, memoryAddress, memorySize, userContext)
    ccall((:peak_Acquisition_Buffer_Announce, IDS), peak_status, (peak_camera_handle, Ptr{UInt8}, Csize_t, Ptr{Cvoid}), hCam, memoryAddress, memorySize, userContext)
end

function peak_Acquisition_Buffer_Revoke(hCam, memoryAddress)
    ccall((:peak_Acquisition_Buffer_Revoke, IDS), peak_status, (peak_camera_handle, Ptr{UInt8}), hCam, memoryAddress)
end

function peak_Acquisition_Buffer_RevokeAll(hCam)
    ccall((:peak_Acquisition_Buffer_RevokeAll, IDS), peak_status, (peak_camera_handle,), hCam)
end

function peak_Acquisition_BufferHandling_Mode_GetAccessStatus(hCam)
    ccall((:peak_Acquisition_BufferHandling_Mode_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_Acquisition_BufferHandling_Mode_GetList(hCam, bufferHandlingModeList, bufferHandlingModesCount)
    ccall((:peak_Acquisition_BufferHandling_Mode_GetList, IDS), peak_status, (peak_camera_handle, Ptr{peak_buffer_handling_mode}, Ptr{Csize_t}), hCam, bufferHandlingModeList, bufferHandlingModesCount)
end

function peak_Acquisition_BufferHandling_Mode_Set(hCam, mode)
    ccall((:peak_Acquisition_BufferHandling_Mode_Set, IDS), peak_status, (peak_camera_handle, peak_buffer_handling_mode), hCam, mode)
end

function peak_Acquisition_BufferHandling_Mode_Get(hCam, mode)
    ccall((:peak_Acquisition_BufferHandling_Mode_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_buffer_handling_mode}), hCam, mode)
end

function peak_Acquisition_LossHandling_Mode_GetAccessStatus(hCam)
    ccall((:peak_Acquisition_LossHandling_Mode_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_Acquisition_LossHandling_Mode_GetList(hCam, lossHandlingModeList, lossHandlingModesCount)
    ccall((:peak_Acquisition_LossHandling_Mode_GetList, IDS), peak_status, (peak_camera_handle, Ptr{peak_loss_handling_mode}, Ptr{Csize_t}), hCam, lossHandlingModeList, lossHandlingModesCount)
end

function peak_Acquisition_LossHandling_Mode_Set(hCam, mode)
    ccall((:peak_Acquisition_LossHandling_Mode_Set, IDS), peak_status, (peak_camera_handle, peak_loss_handling_mode), hCam, mode)
end

function peak_Acquisition_LossHandling_Mode_Get(hCam, mode)
    ccall((:peak_Acquisition_LossHandling_Mode_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_loss_handling_mode}), hCam, mode)
end

function peak_Acquisition_LossHandling_Extent_GetAccessStatus(hCam)
    ccall((:peak_Acquisition_LossHandling_Extent_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_Acquisition_LossHandling_Extent_GetRange(hCam, minExtent, maxExtent, incExtent)
    ccall((:peak_Acquisition_LossHandling_Extent_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{Int64}, Ptr{Int64}, Ptr{Int64}), hCam, minExtent, maxExtent, incExtent)
end

function peak_Acquisition_LossHandling_Extent_Set(hCam, extent)
    ccall((:peak_Acquisition_LossHandling_Extent_Set, IDS), peak_status, (peak_camera_handle, Int64), hCam, extent)
end

function peak_Acquisition_LossHandling_Extent_Get(hCam, extent)
    ccall((:peak_Acquisition_LossHandling_Extent_Get, IDS), peak_status, (peak_camera_handle, Ptr{Int64}), hCam, extent)
end

function peak_Acquisition_LossHandling_FrameAbortTimeout_GetAccessStatus(hCam)
    ccall((:peak_Acquisition_LossHandling_FrameAbortTimeout_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_Acquisition_LossHandling_FrameAbortTimeout_GetRange(hCam, minTimeout, maxTimeout, incTimeout)
    ccall((:peak_Acquisition_LossHandling_FrameAbortTimeout_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{Int64}, Ptr{Int64}, Ptr{Int64}), hCam, minTimeout, maxTimeout, incTimeout)
end

function peak_Acquisition_LossHandling_FrameAbortTimeout_Set(hCam, timeout)
    ccall((:peak_Acquisition_LossHandling_FrameAbortTimeout_Set, IDS), peak_status, (peak_camera_handle, Int64), hCam, timeout)
end

function peak_Acquisition_LossHandling_FrameAbortTimeout_Get(hCam, timeout)
    ccall((:peak_Acquisition_LossHandling_FrameAbortTimeout_Get, IDS), peak_status, (peak_camera_handle, Ptr{Int64}), hCam, timeout)
end

function peak_Acquisition_LossHandling_ResendRequestTimeout_GetAccessStatus(hCam)
    ccall((:peak_Acquisition_LossHandling_ResendRequestTimeout_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_Acquisition_LossHandling_ResendRequestTimeout_GetRange(hCam, minTimeout, maxTimeout, incTimeout)
    ccall((:peak_Acquisition_LossHandling_ResendRequestTimeout_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{Int64}, Ptr{Int64}, Ptr{Int64}), hCam, minTimeout, maxTimeout, incTimeout)
end

function peak_Acquisition_LossHandling_ResendRequestTimeout_Set(hCam, timeout)
    ccall((:peak_Acquisition_LossHandling_ResendRequestTimeout_Set, IDS), peak_status, (peak_camera_handle, Int64), hCam, timeout)
end

function peak_Acquisition_LossHandling_ResendRequestTimeout_Get(hCam, timeout)
    ccall((:peak_Acquisition_LossHandling_ResendRequestTimeout_Get, IDS), peak_status, (peak_camera_handle, Ptr{Int64}), hCam, timeout)
end

function peak_PixelFormat_GetInfo(pixelFormat, pixelFormatInfo)
    ccall((:peak_PixelFormat_GetInfo, IDS), peak_status, (peak_pixel_format, Ptr{peak_pixel_format_info}), pixelFormat, pixelFormatInfo)
end

function peak_Frame_Release(hCam, hFrame)
    ccall((:peak_Frame_Release, IDS), peak_status, (peak_camera_handle, peak_frame_handle), hCam, hFrame)
end

function peak_Frame_GetInfo(hFrame, frameInfo)
    ccall((:peak_Frame_GetInfo, IDS), peak_status, (peak_frame_handle, Ptr{peak_frame_info}), hFrame, frameInfo)
end

function peak_Frame_Type_Get(hFrame, frameType)
    ccall((:peak_Frame_Type_Get, IDS), peak_status, (peak_frame_handle, Ptr{peak_frame_type}), hFrame, frameType)
end

function peak_Frame_Buffer_Get(hFrame, buffer)
    ccall((:peak_Frame_Buffer_Get, IDS), peak_status, (peak_frame_handle, Ptr{peak_buffer}), hFrame, buffer)
end

function peak_Frame_ID_Get(hFrame, frameID)
    ccall((:peak_Frame_ID_Get, IDS), peak_status, (peak_frame_handle, Ptr{UInt64}), hFrame, frameID)
end

function peak_Frame_Timestamp_Get(hFrame, timestamp_ns)
    ccall((:peak_Frame_Timestamp_Get, IDS), peak_status, (peak_frame_handle, Ptr{UInt64}), hFrame, timestamp_ns)
end

function peak_Frame_ROI_Get(hFrame, roi)
    ccall((:peak_Frame_ROI_Get, IDS), peak_status, (peak_frame_handle, Ptr{peak_roi}), hFrame, roi)
end

function peak_Frame_PixelFormat_Get(hFrame, pixelFormat)
    ccall((:peak_Frame_PixelFormat_Get, IDS), peak_status, (peak_frame_handle, Ptr{peak_pixel_format}), hFrame, pixelFormat)
end

function peak_Frame_IsComplete(hFrame)
    ccall((:peak_Frame_IsComplete, IDS), peak_bool, (peak_frame_handle,), hFrame)
end

function peak_Frame_BytesExpected_Get(hFrame, bytesExpected)
    ccall((:peak_Frame_BytesExpected_Get, IDS), peak_status, (peak_frame_handle, Ptr{Csize_t}), hFrame, bytesExpected)
end

function peak_Frame_BytesWritten_Get(hFrame, bytesWritten)
    ccall((:peak_Frame_BytesWritten_Get, IDS), peak_status, (peak_frame_handle, Ptr{Csize_t}), hFrame, bytesWritten)
end

function peak_Frame_ProcessingTime_Get(hFrame, processingTime_ms)
    ccall((:peak_Frame_ProcessingTime_Get, IDS), peak_status, (peak_frame_handle, Ptr{UInt32}), hFrame, processingTime_ms)
end

function peak_Frame_Save(hFrame, fileName)
    ccall((:peak_Frame_Save, IDS), peak_status, (peak_frame_handle, Ptr{Cchar}), hFrame, fileName)
end

function peak_Frame_HasChunks(hFrame)
    ccall((:peak_Frame_HasChunks, IDS), peak_bool, (peak_frame_handle,), hFrame)
end

function peak_CameraSettings_ParameterSet_GetAccessStatus(hCam, parameterSet)
    ccall((:peak_CameraSettings_ParameterSet_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle, peak_parameter_set), hCam, parameterSet)
end

function peak_CameraSettings_ParameterSet_GetList(hCam, parameterSetList, parameterSetCount)
    ccall((:peak_CameraSettings_ParameterSet_GetList, IDS), peak_status, (peak_camera_handle, Ptr{peak_parameter_set}, Ptr{Csize_t}), hCam, parameterSetList, parameterSetCount)
end

function peak_CameraSettings_ParameterSet_Store(hCam, parameterSet)
    ccall((:peak_CameraSettings_ParameterSet_Store, IDS), peak_status, (peak_camera_handle, peak_parameter_set), hCam, parameterSet)
end

function peak_CameraSettings_ParameterSet_Apply(hCam, parameterSet)
    ccall((:peak_CameraSettings_ParameterSet_Apply, IDS), peak_status, (peak_camera_handle, peak_parameter_set), hCam, parameterSet)
end

function peak_CameraSettings_ParameterSet_Startup_GetAccessStatus(hCam)
    ccall((:peak_CameraSettings_ParameterSet_Startup_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_CameraSettings_ParameterSet_Startup_Set(hCam, parameterSet)
    ccall((:peak_CameraSettings_ParameterSet_Startup_Set, IDS), peak_status, (peak_camera_handle, peak_parameter_set), hCam, parameterSet)
end

function peak_CameraSettings_ParameterSet_Startup_Get(hCam, parameterSet)
    ccall((:peak_CameraSettings_ParameterSet_Startup_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_parameter_set}), hCam, parameterSet)
end

function peak_CameraSettings_DiskFile_GetAccessStatus(hCam)
    ccall((:peak_CameraSettings_DiskFile_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_CameraSettings_DiskFile_Store(hCam, file)
    ccall((:peak_CameraSettings_DiskFile_Store, IDS), peak_status, (peak_camera_handle, Ptr{Cchar}), hCam, file)
end

function peak_CameraSettings_DiskFile_Apply(hCam, file)
    ccall((:peak_CameraSettings_DiskFile_Apply, IDS), peak_status, (peak_camera_handle, Ptr{Cchar}), hCam, file)
end

function peak_FrameRate_GetAccessStatus(hCam)
    ccall((:peak_FrameRate_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_FrameRate_GetRange(hCam, minFrameRate_fps, maxFrameRate_fps, incFrameRate_fps)
    ccall((:peak_FrameRate_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}), hCam, minFrameRate_fps, maxFrameRate_fps, incFrameRate_fps)
end

function peak_FrameRate_Set(hCam, frameRate_fps)
    ccall((:peak_FrameRate_Set, IDS), peak_status, (peak_camera_handle, Cdouble), hCam, frameRate_fps)
end

function peak_FrameRate_Get(hCam, frameRate_fps)
    ccall((:peak_FrameRate_Get, IDS), peak_status, (peak_camera_handle, Ptr{Cdouble}), hCam, frameRate_fps)
end

function peak_ExposureTime_GetAccessStatus(hCam)
    ccall((:peak_ExposureTime_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_ExposureTime_GetRange(hCam, minExposureTime_us, maxExposureTime_us, incExposureTime_us)
    ccall((:peak_ExposureTime_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}), hCam, minExposureTime_us, maxExposureTime_us, incExposureTime_us)
end

function peak_ExposureTime_Set(hCam, exposureTime_us)
    ccall((:peak_ExposureTime_Set, IDS), peak_status, (peak_camera_handle, Cdouble), hCam, exposureTime_us)
end

function peak_ExposureTime_Get(hCam, exposureTime_us)
    ccall((:peak_ExposureTime_Get, IDS), peak_status, (peak_camera_handle, Ptr{Cdouble}), hCam, exposureTime_us)
end

function peak_ShutterMode_GetAccessStatus(hCam)
    ccall((:peak_ShutterMode_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_ShutterMode_GetList(hCam, shutterModeList, shutterModeCount)
    ccall((:peak_ShutterMode_GetList, IDS), peak_status, (peak_camera_handle, Ptr{peak_shutter_mode}, Ptr{Csize_t}), hCam, shutterModeList, shutterModeCount)
end

function peak_ShutterMode_Set(hCam, shutterMode)
    ccall((:peak_ShutterMode_Set, IDS), peak_status, (peak_camera_handle, peak_shutter_mode), hCam, shutterMode)
end

function peak_ShutterMode_Get(hCam, shutterMode)
    ccall((:peak_ShutterMode_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_shutter_mode}), hCam, shutterMode)
end

function peak_PixelClock_GetAccessStatus(hCam)
    ccall((:peak_PixelClock_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_PixelClock_HasRange(hCam)
    ccall((:peak_PixelClock_HasRange, IDS), peak_bool, (peak_camera_handle,), hCam)
end

function peak_PixelClock_GetRange(hCam, minPixelClock_MHz, maxPixelClock_MHz, incPixelClock_MHz)
    ccall((:peak_PixelClock_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}), hCam, minPixelClock_MHz, maxPixelClock_MHz, incPixelClock_MHz)
end

function peak_PixelClock_GetList(hCam, pixelClockList, pixelClockCount)
    ccall((:peak_PixelClock_GetList, IDS), peak_status, (peak_camera_handle, Ptr{Cdouble}, Ptr{Csize_t}), hCam, pixelClockList, pixelClockCount)
end

function peak_PixelClock_Set(hCam, pixelClock_MHz)
    ccall((:peak_PixelClock_Set, IDS), peak_status, (peak_camera_handle, Cdouble), hCam, pixelClock_MHz)
end

function peak_PixelClock_Get(hCam, pixelClock_MHz)
    ccall((:peak_PixelClock_Get, IDS), peak_status, (peak_camera_handle, Ptr{Cdouble}), hCam, pixelClock_MHz)
end

function peak_IOChannel_GetAccessStatus(hCam, ioChannel)
    ccall((:peak_IOChannel_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle, peak_io_channel), hCam, ioChannel)
end

function peak_IOChannel_GetList(hCam, ioChannelList, ioChannelCount)
    ccall((:peak_IOChannel_GetList, IDS), peak_status, (peak_camera_handle, Ptr{peak_io_channel}, Ptr{Csize_t}), hCam, ioChannelList, ioChannelCount)
end

function peak_IOChannel_GetListForDirection(hCam, direction, ioChannelList, ioChannelCount)
    ccall((:peak_IOChannel_GetListForDirection, IDS), peak_status, (peak_camera_handle, peak_io_direction, Ptr{peak_io_channel}, Ptr{Csize_t}), hCam, direction, ioChannelList, ioChannelCount)
end

function peak_IOChannel_Direction_GetAccessStatus(hCam, ioChannel)
    ccall((:peak_IOChannel_Direction_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle, peak_io_channel), hCam, ioChannel)
end

function peak_IOChannel_Direction_Get(hCam, ioChannel, direction)
    ccall((:peak_IOChannel_Direction_Get, IDS), peak_status, (peak_camera_handle, peak_io_channel, Ptr{peak_io_direction}), hCam, ioChannel, direction)
end

function peak_IOChannel_Type_GetAccessStatus(hCam, ioChannel)
    ccall((:peak_IOChannel_Type_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle, peak_io_channel), hCam, ioChannel)
end

function peak_IOChannel_Type_Get(hCam, ioChannel, type)
    ccall((:peak_IOChannel_Type_Get, IDS), peak_status, (peak_camera_handle, peak_io_channel, Ptr{peak_io_type}), hCam, ioChannel, type)
end

function peak_IOChannel_Level_GetAccessStatus(hCam, ioChannel)
    ccall((:peak_IOChannel_Level_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle, peak_io_channel), hCam, ioChannel)
end

function peak_IOChannel_Level_IsHigh(hCam, ioChannel)
    ccall((:peak_IOChannel_Level_IsHigh, IDS), peak_bool, (peak_camera_handle, peak_io_channel), hCam, ioChannel)
end

function peak_IOChannel_Level_SetHigh(hCam, ioChannel, high)
    ccall((:peak_IOChannel_Level_SetHigh, IDS), peak_status, (peak_camera_handle, peak_io_channel, peak_bool), hCam, ioChannel, high)
end

function peak_IOChannel_Inverter_GetAccessStatus(hCam, ioChannel)
    ccall((:peak_IOChannel_Inverter_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle, peak_io_channel), hCam, ioChannel)
end

function peak_IOChannel_Inverter_Enable(hCam, ioChannel, enabled)
    ccall((:peak_IOChannel_Inverter_Enable, IDS), peak_status, (peak_camera_handle, peak_io_channel, peak_bool), hCam, ioChannel, enabled)
end

function peak_IOChannel_Inverter_IsEnabled(hCam, ioChannel)
    ccall((:peak_IOChannel_Inverter_IsEnabled, IDS), peak_bool, (peak_camera_handle, peak_io_channel), hCam, ioChannel)
end

function peak_IOChannel_NoiseFilter_GetAccessStatus(hCam, ioChannel)
    ccall((:peak_IOChannel_NoiseFilter_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle, peak_io_channel), hCam, ioChannel)
end

function peak_IOChannel_NoiseFilter_Enable(hCam, ioChannel, enabled)
    ccall((:peak_IOChannel_NoiseFilter_Enable, IDS), peak_status, (peak_camera_handle, peak_io_channel, peak_bool), hCam, ioChannel, enabled)
end

function peak_IOChannel_NoiseFilter_IsEnabled(hCam, ioChannel)
    ccall((:peak_IOChannel_NoiseFilter_IsEnabled, IDS), peak_bool, (peak_camera_handle, peak_io_channel), hCam, ioChannel)
end

function peak_IOChannel_NoiseFilter_Duration_GetRange(hCam, ioChannel, minNoiseFilterDuration_us, maxNoiseFilterDuration_us, incNoiseFilterDuration_us)
    ccall((:peak_IOChannel_NoiseFilter_Duration_GetRange, IDS), peak_status, (peak_camera_handle, peak_io_channel, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}), hCam, ioChannel, minNoiseFilterDuration_us, maxNoiseFilterDuration_us, incNoiseFilterDuration_us)
end

function peak_IOChannel_NoiseFilter_Duration_Set(hCam, ioChannel, noiseFilterDuration_us)
    ccall((:peak_IOChannel_NoiseFilter_Duration_Set, IDS), peak_status, (peak_camera_handle, peak_io_channel, Cdouble), hCam, ioChannel, noiseFilterDuration_us)
end

function peak_IOChannel_NoiseFilter_Duration_Get(hCam, ioChannel, noiseFilterDuration_us)
    ccall((:peak_IOChannel_NoiseFilter_Duration_Get, IDS), peak_status, (peak_camera_handle, peak_io_channel, Ptr{Cdouble}), hCam, ioChannel, noiseFilterDuration_us)
end

function peak_Trigger_GetAccessStatus(hCam)
    ccall((:peak_Trigger_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_Trigger_Enable(hCam, enabled)
    ccall((:peak_Trigger_Enable, IDS), peak_status, (peak_camera_handle, peak_bool), hCam, enabled)
end

function peak_Trigger_IsEnabled(hCam)
    ccall((:peak_Trigger_IsEnabled, IDS), peak_bool, (peak_camera_handle,), hCam)
end

function peak_Trigger_IsExecutable(hCam)
    ccall((:peak_Trigger_IsExecutable, IDS), peak_bool, (peak_camera_handle,), hCam)
end

function peak_Trigger_Execute(hCam)
    ccall((:peak_Trigger_Execute, IDS), peak_status, (peak_camera_handle,), hCam)
end

function peak_Trigger_Mode_GetAccessStatus(hCam, triggerMode)
    ccall((:peak_Trigger_Mode_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle, peak_trigger_mode), hCam, triggerMode)
end

function peak_Trigger_Mode_Set(hCam, triggerMode)
    ccall((:peak_Trigger_Mode_Set, IDS), peak_status, (peak_camera_handle, peak_trigger_mode), hCam, triggerMode)
end

function peak_Trigger_Mode_Get(hCam, triggerMode)
    ccall((:peak_Trigger_Mode_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_trigger_mode}), hCam, triggerMode)
end

function peak_Trigger_Mode_Config_Get(hCam, triggerMode)
    ccall((:peak_Trigger_Mode_Config_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_trigger_mode}), hCam, triggerMode)
end

function peak_Trigger_Edge_GetAccessStatus(hCam)
    ccall((:peak_Trigger_Edge_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_Trigger_Edge_GetList(hCam, triggerEdgeList, triggerEdgeCount)
    ccall((:peak_Trigger_Edge_GetList, IDS), peak_status, (peak_camera_handle, Ptr{peak_trigger_edge}, Ptr{Csize_t}), hCam, triggerEdgeList, triggerEdgeCount)
end

function peak_Trigger_Edge_Set(hCam, triggerEdge)
    ccall((:peak_Trigger_Edge_Set, IDS), peak_status, (peak_camera_handle, peak_trigger_edge), hCam, triggerEdge)
end

function peak_Trigger_Edge_Get(hCam, triggerEdge)
    ccall((:peak_Trigger_Edge_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_trigger_edge}), hCam, triggerEdge)
end

function peak_Trigger_Delay_GetAccessStatus(hCam)
    ccall((:peak_Trigger_Delay_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_Trigger_Delay_GetRange(hCam, minTriggerDelay_us, maxTriggerDelay_us, incTriggerDelay_us)
    ccall((:peak_Trigger_Delay_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}), hCam, minTriggerDelay_us, maxTriggerDelay_us, incTriggerDelay_us)
end

function peak_Trigger_Delay_Set(hCam, triggerDelay_us)
    ccall((:peak_Trigger_Delay_Set, IDS), peak_status, (peak_camera_handle, Cdouble), hCam, triggerDelay_us)
end

function peak_Trigger_Delay_Get(hCam, triggerDelay_us)
    ccall((:peak_Trigger_Delay_Get, IDS), peak_status, (peak_camera_handle, Ptr{Cdouble}), hCam, triggerDelay_us)
end

function peak_Trigger_Divider_GetAccessStatus(hCam)
    ccall((:peak_Trigger_Divider_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_Trigger_Divider_GetRange(hCam, minTriggerDivider, maxTriggerDivider, incTriggerDivider)
    ccall((:peak_Trigger_Divider_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{UInt32}, Ptr{UInt32}, Ptr{UInt32}), hCam, minTriggerDivider, maxTriggerDivider, incTriggerDivider)
end

function peak_Trigger_Divider_Set(hCam, triggerDivider)
    ccall((:peak_Trigger_Divider_Set, IDS), peak_status, (peak_camera_handle, UInt32), hCam, triggerDivider)
end

function peak_Trigger_Divider_Get(hCam, triggerDivider)
    ccall((:peak_Trigger_Divider_Get, IDS), peak_status, (peak_camera_handle, Ptr{UInt32}), hCam, triggerDivider)
end

function peak_Trigger_Burst_GetAccessStatus(hCam)
    ccall((:peak_Trigger_Burst_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_Trigger_Burst_GetRange(hCam, minTriggerBurst, maxTriggerBurst, incTriggerBurst)
    ccall((:peak_Trigger_Burst_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{UInt32}, Ptr{UInt32}, Ptr{UInt32}), hCam, minTriggerBurst, maxTriggerBurst, incTriggerBurst)
end

function peak_Trigger_Burst_Set(hCam, triggerBurst)
    ccall((:peak_Trigger_Burst_Set, IDS), peak_status, (peak_camera_handle, UInt32), hCam, triggerBurst)
end

function peak_Trigger_Burst_Get(hCam, triggerBurst)
    ccall((:peak_Trigger_Burst_Get, IDS), peak_status, (peak_camera_handle, Ptr{UInt32}), hCam, triggerBurst)
end

function peak_Flash_GetAccessStatus(hCam)
    ccall((:peak_Flash_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_Flash_Enable(hCam, enabled)
    ccall((:peak_Flash_Enable, IDS), peak_status, (peak_camera_handle, peak_bool), hCam, enabled)
end

function peak_Flash_IsEnabled(hCam)
    ccall((:peak_Flash_IsEnabled, IDS), peak_bool, (peak_camera_handle,), hCam)
end

function peak_Flash_Mode_GetAccessStatus(hCam, flashMode)
    ccall((:peak_Flash_Mode_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle, peak_flash_mode), hCam, flashMode)
end

function peak_Flash_Mode_Set(hCam, flashMode)
    ccall((:peak_Flash_Mode_Set, IDS), peak_status, (peak_camera_handle, peak_flash_mode), hCam, flashMode)
end

function peak_Flash_Mode_Get(hCam, flashMode)
    ccall((:peak_Flash_Mode_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_flash_mode}), hCam, flashMode)
end

function peak_Flash_Mode_Config_Get(hCam, flashMode)
    ccall((:peak_Flash_Mode_Config_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_flash_mode}), hCam, flashMode)
end

function peak_Flash_StartDelay_GetAccessStatus(hCam)
    ccall((:peak_Flash_StartDelay_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_Flash_StartDelay_GetRange(hCam, minFlashStartDelay_us, maxFlashStartDelay_us, incFlashStartDelay_us)
    ccall((:peak_Flash_StartDelay_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}), hCam, minFlashStartDelay_us, maxFlashStartDelay_us, incFlashStartDelay_us)
end

function peak_Flash_StartDelay_Set(hCam, flashStartDelay_us)
    ccall((:peak_Flash_StartDelay_Set, IDS), peak_status, (peak_camera_handle, Cdouble), hCam, flashStartDelay_us)
end

function peak_Flash_StartDelay_Get(hCam, flashStartDelay_us)
    ccall((:peak_Flash_StartDelay_Get, IDS), peak_status, (peak_camera_handle, Ptr{Cdouble}), hCam, flashStartDelay_us)
end

function peak_Flash_EndDelay_GetAccessStatus(hCam)
    ccall((:peak_Flash_EndDelay_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_Flash_EndDelay_GetRange(hCam, minFlashEndDelay_us, maxFlashEndDelay_us, incFlashEndDelay_us)
    ccall((:peak_Flash_EndDelay_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}), hCam, minFlashEndDelay_us, maxFlashEndDelay_us, incFlashEndDelay_us)
end

function peak_Flash_EndDelay_Set(hCam, flashEndDelay_us)
    ccall((:peak_Flash_EndDelay_Set, IDS), peak_status, (peak_camera_handle, Cdouble), hCam, flashEndDelay_us)
end

function peak_Flash_EndDelay_Get(hCam, flashEndDelay_us)
    ccall((:peak_Flash_EndDelay_Get, IDS), peak_status, (peak_camera_handle, Ptr{Cdouble}), hCam, flashEndDelay_us)
end

function peak_Flash_Duration_GetAccessStatus(hCam)
    ccall((:peak_Flash_Duration_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_Flash_Duration_GetRange(hCam, minFlashDuration_us, maxFlashDuration_us, incFlashDuration_us)
    ccall((:peak_Flash_Duration_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}), hCam, minFlashDuration_us, maxFlashDuration_us, incFlashDuration_us)
end

function peak_Flash_Duration_Set(hCam, flashDuration_us)
    ccall((:peak_Flash_Duration_Set, IDS), peak_status, (peak_camera_handle, Cdouble), hCam, flashDuration_us)
end

function peak_Flash_Duration_Get(hCam, flashDuration_us)
    ccall((:peak_Flash_Duration_Get, IDS), peak_status, (peak_camera_handle, Ptr{Cdouble}), hCam, flashDuration_us)
end

function peak_Focus_GetAccessStatus(hCam)
    ccall((:peak_Focus_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_Focus_GetRange(hCam, minFocus, maxFocus, incFocus)
    ccall((:peak_Focus_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{UInt32}, Ptr{UInt32}, Ptr{UInt32}), hCam, minFocus, maxFocus, incFocus)
end

function peak_Focus_Set(hCam, focus)
    ccall((:peak_Focus_Set, IDS), peak_status, (peak_camera_handle, UInt32), hCam, focus)
end

function peak_Focus_Get(hCam, focus)
    ccall((:peak_Focus_Get, IDS), peak_status, (peak_camera_handle, Ptr{UInt32}), hCam, focus)
end

function peak_PixelFormat_GetAccessStatus(hCam)
    ccall((:peak_PixelFormat_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_PixelFormat_GetList(hCam, pixelFormatList, pixelFormatCount)
    ccall((:peak_PixelFormat_GetList, IDS), peak_status, (peak_camera_handle, Ptr{peak_pixel_format}, Ptr{Csize_t}), hCam, pixelFormatList, pixelFormatCount)
end

function peak_PixelFormat_Set(hCam, pixelFormat)
    ccall((:peak_PixelFormat_Set, IDS), peak_status, (peak_camera_handle, peak_pixel_format), hCam, pixelFormat)
end

function peak_PixelFormat_Get(hCam, pixelFormat)
    ccall((:peak_PixelFormat_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_pixel_format}), hCam, pixelFormat)
end

function peak_Gain_GetAccessStatus(hCam, gainType, gainChannel)
    ccall((:peak_Gain_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle, peak_gain_type, peak_gain_channel), hCam, gainType, gainChannel)
end

function peak_Gain_GetChannelList(hCam, gainType, gainChannelList, gainChannelCount)
    ccall((:peak_Gain_GetChannelList, IDS), peak_status, (peak_camera_handle, peak_gain_type, Ptr{peak_gain_channel}, Ptr{Csize_t}), hCam, gainType, gainChannelList, gainChannelCount)
end

function peak_Gain_GetRange(hCam, gainType, gainChannel, minGain, maxGain, incGain)
    ccall((:peak_Gain_GetRange, IDS), peak_status, (peak_camera_handle, peak_gain_type, peak_gain_channel, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}), hCam, gainType, gainChannel, minGain, maxGain, incGain)
end

function peak_Gain_Set(hCam, gainType, gainChannel, gain)
    ccall((:peak_Gain_Set, IDS), peak_status, (peak_camera_handle, peak_gain_type, peak_gain_channel, Cdouble), hCam, gainType, gainChannel, gain)
end

function peak_Gain_Get(hCam, gainType, gainChannel, gain)
    ccall((:peak_Gain_Get, IDS), peak_status, (peak_camera_handle, peak_gain_type, peak_gain_channel, Ptr{Cdouble}), hCam, gainType, gainChannel, gain)
end

function peak_Gamma_GetAccessStatus(hCam)
    ccall((:peak_Gamma_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_Gamma_GetRange(hCam, minGamma, maxGamma, incGamma)
    ccall((:peak_Gamma_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}), hCam, minGamma, maxGamma, incGamma)
end

function peak_Gamma_Set(hCam, gamma)
    ccall((:peak_Gamma_Set, IDS), peak_status, (peak_camera_handle, Cdouble), hCam, gamma)
end

function peak_Gamma_Get(hCam, gamma)
    ccall((:peak_Gamma_Get, IDS), peak_status, (peak_camera_handle, Ptr{Cdouble}), hCam, gamma)
end

function peak_ColorCorrection_GetAccessStatus(hCam)
    ccall((:peak_ColorCorrection_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_ColorCorrection_Mode_GetList(hCam, colorCorrectionModeList, colorCorrectionModeCount)
    ccall((:peak_ColorCorrection_Mode_GetList, IDS), peak_status, (peak_camera_handle, Ptr{peak_color_correction_mode}, Ptr{Csize_t}), hCam, colorCorrectionModeList, colorCorrectionModeCount)
end

function peak_ColorCorrection_Mode_Set(hCam, colorCorrectionMode)
    ccall((:peak_ColorCorrection_Mode_Set, IDS), peak_status, (peak_camera_handle, peak_color_correction_mode), hCam, colorCorrectionMode)
end

function peak_ColorCorrection_Mode_Get(hCam, colorCorrectionMode)
    ccall((:peak_ColorCorrection_Mode_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_color_correction_mode}), hCam, colorCorrectionMode)
end

function peak_ColorCorrection_Matrix_GetAccessStatus(hCam)
    ccall((:peak_ColorCorrection_Matrix_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_ColorCorrection_Matrix_GetRange(hCam, minMatrixElementValue, maxMatrixElementValue, incMatrixElementValue)
    ccall((:peak_ColorCorrection_Matrix_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}), hCam, minMatrixElementValue, maxMatrixElementValue, incMatrixElementValue)
end

function peak_ColorCorrection_Matrix_Set(hCam, colorCorrectionMatrix)
    ccall((:peak_ColorCorrection_Matrix_Set, IDS), peak_status, (peak_camera_handle, peak_matrix), hCam, colorCorrectionMatrix)
end

function peak_ColorCorrection_Matrix_Get(hCam, colorCorrectionMatrix)
    ccall((:peak_ColorCorrection_Matrix_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_matrix}), hCam, colorCorrectionMatrix)
end

function peak_ColorCorrection_Enable(hCam, enabled)
    ccall((:peak_ColorCorrection_Enable, IDS), peak_status, (peak_camera_handle, peak_bool), hCam, enabled)
end

function peak_ColorCorrection_IsEnabled(hCam)
    ccall((:peak_ColorCorrection_IsEnabled, IDS), peak_bool, (peak_camera_handle,), hCam)
end

function peak_AutoBrightness_GetAccessStatus(hCam)
    ccall((:peak_AutoBrightness_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_AutoBrightness_Target_GetAccessStatus(hCam)
    ccall((:peak_AutoBrightness_Target_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_AutoBrightness_Target_GetRange(hCam, minAutoBrightnessTarget, maxAutoBrightnessTarget, incAutoBrightnessTarget)
    ccall((:peak_AutoBrightness_Target_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{UInt32}, Ptr{UInt32}, Ptr{UInt32}), hCam, minAutoBrightnessTarget, maxAutoBrightnessTarget, incAutoBrightnessTarget)
end

function peak_AutoBrightness_Target_Set(hCam, autoBrightnessTarget)
    ccall((:peak_AutoBrightness_Target_Set, IDS), peak_status, (peak_camera_handle, UInt32), hCam, autoBrightnessTarget)
end

function peak_AutoBrightness_Target_Get(hCam, autoBrightnessTarget)
    ccall((:peak_AutoBrightness_Target_Get, IDS), peak_status, (peak_camera_handle, Ptr{UInt32}), hCam, autoBrightnessTarget)
end

function peak_AutoBrightness_TargetTolerance_GetAccessStatus(hCam)
    ccall((:peak_AutoBrightness_TargetTolerance_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_AutoBrightness_TargetTolerance_GetRange(hCam, minAutoBrightnessTargetTolerance, maxAutoBrightnessTargetTolerance, incAutoBrightnessTargetTolerance)
    ccall((:peak_AutoBrightness_TargetTolerance_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{UInt32}, Ptr{UInt32}, Ptr{UInt32}), hCam, minAutoBrightnessTargetTolerance, maxAutoBrightnessTargetTolerance, incAutoBrightnessTargetTolerance)
end

function peak_AutoBrightness_TargetTolerance_Set(hCam, autoBrightnessTargetTolerance)
    ccall((:peak_AutoBrightness_TargetTolerance_Set, IDS), peak_status, (peak_camera_handle, UInt32), hCam, autoBrightnessTargetTolerance)
end

function peak_AutoBrightness_TargetTolerance_Get(hCam, autoBrightnessTargetTolerance)
    ccall((:peak_AutoBrightness_TargetTolerance_Get, IDS), peak_status, (peak_camera_handle, Ptr{UInt32}), hCam, autoBrightnessTargetTolerance)
end

function peak_AutoBrightness_TargetPercentile_GetAccessStatus(hCam)
    ccall((:peak_AutoBrightness_TargetPercentile_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_AutoBrightness_TargetPercentile_GetRange(hCam, minAutoBrightnessTargetPercentile, maxAutoBrightnessTargetPercentile, incAutoBrightnessTargetPercentile)
    ccall((:peak_AutoBrightness_TargetPercentile_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}), hCam, minAutoBrightnessTargetPercentile, maxAutoBrightnessTargetPercentile, incAutoBrightnessTargetPercentile)
end

function peak_AutoBrightness_TargetPercentile_Set(hCam, autoBrightnessTargetPercentile)
    ccall((:peak_AutoBrightness_TargetPercentile_Set, IDS), peak_status, (peak_camera_handle, Cdouble), hCam, autoBrightnessTargetPercentile)
end

function peak_AutoBrightness_TargetPercentile_Get(hCam, autoBrightnessTargetPercentile)
    ccall((:peak_AutoBrightness_TargetPercentile_Get, IDS), peak_status, (peak_camera_handle, Ptr{Cdouble}), hCam, autoBrightnessTargetPercentile)
end

function peak_AutoBrightness_ROI_GetAccessStatus(hCam)
    ccall((:peak_AutoBrightness_ROI_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_AutoBrightness_ROI_Mode_Set(hCam, autoBrightnessROIMode)
    ccall((:peak_AutoBrightness_ROI_Mode_Set, IDS), peak_status, (peak_camera_handle, peak_auto_feature_roi_mode), hCam, autoBrightnessROIMode)
end

function peak_AutoBrightness_ROI_Mode_Get(hCam, autoBrightnessROIMode)
    ccall((:peak_AutoBrightness_ROI_Mode_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_auto_feature_roi_mode}), hCam, autoBrightnessROIMode)
end

function peak_AutoBrightness_ROI_Offset_GetRange(hCam, minAutoBrightnessROIOffset, maxAutoBrightnessROIOffset, incAutoBrightnessROIOffset)
    ccall((:peak_AutoBrightness_ROI_Offset_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{peak_position}, Ptr{peak_position}, Ptr{peak_position}), hCam, minAutoBrightnessROIOffset, maxAutoBrightnessROIOffset, incAutoBrightnessROIOffset)
end

function peak_AutoBrightness_ROI_Size_GetRange(hCam, minAutoBrightnessROISize, maxAutoBrightnessROISize, incAutoBrightnessROISize)
    ccall((:peak_AutoBrightness_ROI_Size_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{peak_size}, Ptr{peak_size}, Ptr{peak_size}), hCam, minAutoBrightnessROISize, maxAutoBrightnessROISize, incAutoBrightnessROISize)
end

function peak_AutoBrightness_ROI_Set(hCam, autoBrightnessROI)
    ccall((:peak_AutoBrightness_ROI_Set, IDS), peak_status, (peak_camera_handle, peak_roi), hCam, autoBrightnessROI)
end

function peak_AutoBrightness_ROI_Get(hCam, autoBrightnessROI)
    ccall((:peak_AutoBrightness_ROI_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_roi}), hCam, autoBrightnessROI)
end

function peak_AutoBrightness_Exposure_GetAccessStatus(hCam)
    ccall((:peak_AutoBrightness_Exposure_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_AutoBrightness_Exposure_Mode_GetList(hCam, modeList, modeListSize)
    ccall((:peak_AutoBrightness_Exposure_Mode_GetList, IDS), peak_status, (peak_camera_handle, Ptr{peak_auto_feature_mode}, Ptr{Csize_t}), hCam, modeList, modeListSize)
end

function peak_AutoBrightness_Exposure_Mode_Set(hCam, autoExposureMode)
    ccall((:peak_AutoBrightness_Exposure_Mode_Set, IDS), peak_status, (peak_camera_handle, peak_auto_feature_mode), hCam, autoExposureMode)
end

function peak_AutoBrightness_Exposure_Mode_Get(hCam, autoExposureMode)
    ccall((:peak_AutoBrightness_Exposure_Mode_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_auto_feature_mode}), hCam, autoExposureMode)
end

function peak_AutoBrightness_Gain_GetAccessStatus(hCam)
    ccall((:peak_AutoBrightness_Gain_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_AutoBrightness_Gain_Mode_GetList(hCam, modeList, modeListSize)
    ccall((:peak_AutoBrightness_Gain_Mode_GetList, IDS), peak_status, (peak_camera_handle, Ptr{peak_auto_feature_mode}, Ptr{Csize_t}), hCam, modeList, modeListSize)
end

function peak_AutoBrightness_Gain_Mode_Set(hCam, autoGainMode)
    ccall((:peak_AutoBrightness_Gain_Mode_Set, IDS), peak_status, (peak_camera_handle, peak_auto_feature_mode), hCam, autoGainMode)
end

function peak_AutoBrightness_Gain_Mode_Get(hCam, autoGainMode)
    ccall((:peak_AutoBrightness_Gain_Mode_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_auto_feature_mode}), hCam, autoGainMode)
end

function peak_AutoWhiteBalance_GetAccessStatus(hCam)
    ccall((:peak_AutoWhiteBalance_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_AutoWhiteBalance_ROI_GetAccessStatus(hCam)
    ccall((:peak_AutoWhiteBalance_ROI_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_AutoWhiteBalance_ROI_Mode_Set(hCam, autoWhiteBalanceROIMode)
    ccall((:peak_AutoWhiteBalance_ROI_Mode_Set, IDS), peak_status, (peak_camera_handle, peak_auto_feature_roi_mode), hCam, autoWhiteBalanceROIMode)
end

function peak_AutoWhiteBalance_ROI_Mode_Get(hCam, autoWhiteBalanceROIMode)
    ccall((:peak_AutoWhiteBalance_ROI_Mode_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_auto_feature_roi_mode}), hCam, autoWhiteBalanceROIMode)
end

function peak_AutoWhiteBalance_ROI_Offset_GetRange(hCam, minAutoWhiteBalanceROIOffset, maxAutoWhiteBalanceROIOffset, incAutoWhiteBalanceROIOffset)
    ccall((:peak_AutoWhiteBalance_ROI_Offset_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{peak_position}, Ptr{peak_position}, Ptr{peak_position}), hCam, minAutoWhiteBalanceROIOffset, maxAutoWhiteBalanceROIOffset, incAutoWhiteBalanceROIOffset)
end

function peak_AutoWhiteBalance_ROI_Size_GetRange(hCam, minAutoWhiteBalanceROISize, maxAutoWhiteBalanceROISize, incAutoWhiteBalanceROISize)
    ccall((:peak_AutoWhiteBalance_ROI_Size_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{peak_size}, Ptr{peak_size}, Ptr{peak_size}), hCam, minAutoWhiteBalanceROISize, maxAutoWhiteBalanceROISize, incAutoWhiteBalanceROISize)
end

function peak_AutoWhiteBalance_ROI_Set(hCam, autoWhiteBalanceROI)
    ccall((:peak_AutoWhiteBalance_ROI_Set, IDS), peak_status, (peak_camera_handle, peak_roi), hCam, autoWhiteBalanceROI)
end

function peak_AutoWhiteBalance_ROI_Get(hCam, autoWhiteBalanceROI)
    ccall((:peak_AutoWhiteBalance_ROI_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_roi}), hCam, autoWhiteBalanceROI)
end

function peak_AutoWhiteBalance_Mode_Set(hCam, autoWhiteBalanceMode)
    ccall((:peak_AutoWhiteBalance_Mode_Set, IDS), peak_status, (peak_camera_handle, peak_auto_feature_mode), hCam, autoWhiteBalanceMode)
end

function peak_AutoWhiteBalance_Mode_Get(hCam, autoWhiteBalanceMode)
    ccall((:peak_AutoWhiteBalance_Mode_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_auto_feature_mode}), hCam, autoWhiteBalanceMode)
end

function peak_AutoWhiteBalance_Mode_GetList(hCam, modeList, modeListSize)
    ccall((:peak_AutoWhiteBalance_Mode_GetList, IDS), peak_status, (peak_camera_handle, Ptr{peak_auto_feature_mode}, Ptr{Csize_t}), hCam, modeList, modeListSize)
end

function peak_ROI_GetAccessStatus(hCam)
    ccall((:peak_ROI_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_ROI_Offset_GetRange(hCam, minROIOffset, maxROIOffset, incROIOffset)
    ccall((:peak_ROI_Offset_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{peak_position}, Ptr{peak_position}, Ptr{peak_position}), hCam, minROIOffset, maxROIOffset, incROIOffset)
end

function peak_ROI_Offset_GetAccessStatus(hCam)
    ccall((:peak_ROI_Offset_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_ROI_Offset_Set(hCam, position)
    ccall((:peak_ROI_Offset_Set, IDS), peak_status, (peak_camera_handle, peak_position), hCam, position)
end

function peak_ROI_Offset_Get(hCam, position)
    ccall((:peak_ROI_Offset_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_position}), hCam, position)
end

function peak_ROI_Size_GetRange(hCam, minROISize, maxROISize, incROISize)
    ccall((:peak_ROI_Size_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{peak_size}, Ptr{peak_size}, Ptr{peak_size}), hCam, minROISize, maxROISize, incROISize)
end

function peak_ROI_Size_GetAccessStatus(hCam)
    ccall((:peak_ROI_Size_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_ROI_Size_Set(hCam, size)
    ccall((:peak_ROI_Size_Set, IDS), peak_status, (peak_camera_handle, peak_size), hCam, size)
end

function peak_ROI_Size_Get(hCam, size)
    ccall((:peak_ROI_Size_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_size}), hCam, size)
end

function peak_ROI_Set(hCam, roi)
    ccall((:peak_ROI_Set, IDS), peak_status, (peak_camera_handle, peak_roi), hCam, roi)
end

function peak_ROI_Get(hCam, roi)
    ccall((:peak_ROI_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_roi}), hCam, roi)
end

function peak_Binning_GetAccessStatus(hCam)
    ccall((:peak_Binning_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_Binning_FactorX_GetList(hCam, binningFactorXList, binningFactorXCount)
    ccall((:peak_Binning_FactorX_GetList, IDS), peak_status, (peak_camera_handle, Ptr{UInt32}, Ptr{Csize_t}), hCam, binningFactorXList, binningFactorXCount)
end

function peak_Binning_FactorY_GetList(hCam, binningFactorYList, binningFactorYCount)
    ccall((:peak_Binning_FactorY_GetList, IDS), peak_status, (peak_camera_handle, Ptr{UInt32}, Ptr{Csize_t}), hCam, binningFactorYList, binningFactorYCount)
end

function peak_Binning_Set(hCam, binningFactorX, binningFactorY)
    ccall((:peak_Binning_Set, IDS), peak_status, (peak_camera_handle, UInt32, UInt32), hCam, binningFactorX, binningFactorY)
end

function peak_Binning_Get(hCam, binningFactorX, binningFactorY)
    ccall((:peak_Binning_Get, IDS), peak_status, (peak_camera_handle, Ptr{UInt32}, Ptr{UInt32}), hCam, binningFactorX, binningFactorY)
end

function peak_BinningManual_GetAccessStatus(hCam, subsamplingEngine)
    ccall((:peak_BinningManual_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle, peak_subsampling_engine), hCam, subsamplingEngine)
end

function peak_BinningManual_FactorX_GetList(hCam, subsamplingEngine, binningFactorXList, binningFactorXCount)
    ccall((:peak_BinningManual_FactorX_GetList, IDS), peak_status, (peak_camera_handle, peak_subsampling_engine, Ptr{UInt32}, Ptr{Csize_t}), hCam, subsamplingEngine, binningFactorXList, binningFactorXCount)
end

function peak_BinningManual_FactorY_GetList(hCam, subsamplingEngine, binningFactorYList, binningFactorYCount)
    ccall((:peak_BinningManual_FactorY_GetList, IDS), peak_status, (peak_camera_handle, peak_subsampling_engine, Ptr{UInt32}, Ptr{Csize_t}), hCam, subsamplingEngine, binningFactorYList, binningFactorYCount)
end

function peak_BinningManual_Set(hCam, subsamplingEngine, binningFactorX, binningFactorY)
    ccall((:peak_BinningManual_Set, IDS), peak_status, (peak_camera_handle, peak_subsampling_engine, UInt32, UInt32), hCam, subsamplingEngine, binningFactorX, binningFactorY)
end

function peak_BinningManual_Get(hCam, subsamplingEngine, binningFactorX, binningFactorY)
    ccall((:peak_BinningManual_Get, IDS), peak_status, (peak_camera_handle, peak_subsampling_engine, Ptr{UInt32}, Ptr{UInt32}), hCam, subsamplingEngine, binningFactorX, binningFactorY)
end

function peak_Decimation_GetAccessStatus(hCam)
    ccall((:peak_Decimation_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_Decimation_FactorX_GetList(hCam, decimationFactorXList, decimationFactorXCount)
    ccall((:peak_Decimation_FactorX_GetList, IDS), peak_status, (peak_camera_handle, Ptr{UInt32}, Ptr{Csize_t}), hCam, decimationFactorXList, decimationFactorXCount)
end

function peak_Decimation_FactorY_GetList(hCam, decimationFactorYList, decimationFactorYCount)
    ccall((:peak_Decimation_FactorY_GetList, IDS), peak_status, (peak_camera_handle, Ptr{UInt32}, Ptr{Csize_t}), hCam, decimationFactorYList, decimationFactorYCount)
end

function peak_Decimation_Set(hCam, decimationFactorX, decimationFactorY)
    ccall((:peak_Decimation_Set, IDS), peak_status, (peak_camera_handle, UInt32, UInt32), hCam, decimationFactorX, decimationFactorY)
end

function peak_Decimation_Get(hCam, decimationFactorX, decimationFactorY)
    ccall((:peak_Decimation_Get, IDS), peak_status, (peak_camera_handle, Ptr{UInt32}, Ptr{UInt32}), hCam, decimationFactorX, decimationFactorY)
end

function peak_DecimationManual_GetAccessStatus(hCam, subsamplingEngine)
    ccall((:peak_DecimationManual_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle, peak_subsampling_engine), hCam, subsamplingEngine)
end

function peak_DecimationManual_FactorX_GetList(hCam, subsamplingEngine, decimationFactorXList, decimationFactorXCount)
    ccall((:peak_DecimationManual_FactorX_GetList, IDS), peak_status, (peak_camera_handle, peak_subsampling_engine, Ptr{UInt32}, Ptr{Csize_t}), hCam, subsamplingEngine, decimationFactorXList, decimationFactorXCount)
end

function peak_DecimationManual_FactorY_GetList(hCam, subsamplingEngine, decimationFactorYList, decimationFactorYCount)
    ccall((:peak_DecimationManual_FactorY_GetList, IDS), peak_status, (peak_camera_handle, peak_subsampling_engine, Ptr{UInt32}, Ptr{Csize_t}), hCam, subsamplingEngine, decimationFactorYList, decimationFactorYCount)
end

function peak_DecimationManual_Set(hCam, subsamplingEngine, decimationFactorX, decimationFactorY)
    ccall((:peak_DecimationManual_Set, IDS), peak_status, (peak_camera_handle, peak_subsampling_engine, UInt32, UInt32), hCam, subsamplingEngine, decimationFactorX, decimationFactorY)
end

function peak_DecimationManual_Get(hCam, subsamplingEngine, decimationFactorX, decimationFactorY)
    ccall((:peak_DecimationManual_Get, IDS), peak_status, (peak_camera_handle, peak_subsampling_engine, Ptr{UInt32}, Ptr{UInt32}), hCam, subsamplingEngine, decimationFactorX, decimationFactorY)
end

function peak_Scaling_GetAccessStatus(hCam)
    ccall((:peak_Scaling_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_Scaling_FactorX_GetRange(hCam, minScalingFactorX, maxScalingFactorX, incScalingFactorX)
    ccall((:peak_Scaling_FactorX_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}), hCam, minScalingFactorX, maxScalingFactorX, incScalingFactorX)
end

function peak_Scaling_FactorY_GetRange(hCam, minScalingFactorY, maxScalingFactorY, incScalingFactorY)
    ccall((:peak_Scaling_FactorY_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}), hCam, minScalingFactorY, maxScalingFactorY, incScalingFactorY)
end

function peak_Scaling_Set(hCam, scalingFactorX, scalingFactorY)
    ccall((:peak_Scaling_Set, IDS), peak_status, (peak_camera_handle, Cdouble, Cdouble), hCam, scalingFactorX, scalingFactorY)
end

function peak_Scaling_Get(hCam, scalingFactorX, scalingFactorY)
    ccall((:peak_Scaling_Get, IDS), peak_status, (peak_camera_handle, Ptr{Cdouble}, Ptr{Cdouble}), hCam, scalingFactorX, scalingFactorY)
end

function peak_Mirror_LeftRight_GetAccessStatus(hCam)
    ccall((:peak_Mirror_LeftRight_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_Mirror_LeftRight_Enable(hCam, enabled)
    ccall((:peak_Mirror_LeftRight_Enable, IDS), peak_status, (peak_camera_handle, peak_bool), hCam, enabled)
end

function peak_Mirror_LeftRight_IsEnabled(hCam)
    ccall((:peak_Mirror_LeftRight_IsEnabled, IDS), peak_bool, (peak_camera_handle,), hCam)
end

function peak_Mirror_UpDown_GetAccessStatus(hCam)
    ccall((:peak_Mirror_UpDown_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_Mirror_UpDown_Enable(hCam, enabled)
    ccall((:peak_Mirror_UpDown_Enable, IDS), peak_status, (peak_camera_handle, peak_bool), hCam, enabled)
end

function peak_Mirror_UpDown_IsEnabled(hCam)
    ccall((:peak_Mirror_UpDown_IsEnabled, IDS), peak_bool, (peak_camera_handle,), hCam)
end

function peak_CameraMemory_Area_GetAccessStatus(hCam, cameraMemoryArea)
    ccall((:peak_CameraMemory_Area_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle, peak_camera_memory_area), hCam, cameraMemoryArea)
end

function peak_CameraMemory_Area_GetList(hCam, cameraMemoryAreaList, cameraMemoryAreaCount)
    ccall((:peak_CameraMemory_Area_GetList, IDS), peak_status, (peak_camera_handle, Ptr{peak_camera_memory_area}, Ptr{Csize_t}), hCam, cameraMemoryAreaList, cameraMemoryAreaCount)
end

function peak_CameraMemory_Area_Size_Get(hCam, cameraMemoryArea, cameraMemoryAreaSize)
    ccall((:peak_CameraMemory_Area_Size_Get, IDS), peak_status, (peak_camera_handle, peak_camera_memory_area, Ptr{Csize_t}), hCam, cameraMemoryArea, cameraMemoryAreaSize)
end

function peak_CameraMemory_Area_Data_Clear(hCam, cameraMemoryArea)
    ccall((:peak_CameraMemory_Area_Data_Clear, IDS), peak_status, (peak_camera_handle, peak_camera_memory_area), hCam, cameraMemoryArea)
end

function peak_CameraMemory_Area_Data_Write(hCam, cameraMemoryArea, data, dataSize)
    ccall((:peak_CameraMemory_Area_Data_Write, IDS), peak_status, (peak_camera_handle, peak_camera_memory_area, Ptr{UInt8}, Csize_t), hCam, cameraMemoryArea, data, dataSize)
end

function peak_CameraMemory_Area_Data_Read(hCam, cameraMemoryArea, data, dataSize)
    ccall((:peak_CameraMemory_Area_Data_Read, IDS), peak_status, (peak_camera_handle, peak_camera_memory_area, Ptr{UInt8}, Csize_t), hCam, cameraMemoryArea, data, dataSize)
end

function peak_GFA_EnableWriteAccess(hCam, enabled)
    ccall((:peak_GFA_EnableWriteAccess, IDS), peak_status, (peak_camera_handle, peak_bool), hCam, enabled)
end

function peak_GFA_IsWriteAccessEnabled(hCam)
    ccall((:peak_GFA_IsWriteAccessEnabled, IDS), peak_bool, (peak_camera_handle,), hCam)
end

function peak_GFA_Feature_GetAccessStatus(hCam, _module, featureName)
    ccall((:peak_GFA_Feature_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle, peak_gfa_module, Ptr{Cchar}), hCam, _module, featureName)
end

function peak_GFA_Float_HasRange(hCam, _module, floatFeatureName)
    ccall((:peak_GFA_Float_HasRange, IDS), peak_bool, (peak_camera_handle, peak_gfa_module, Ptr{Cchar}), hCam, _module, floatFeatureName)
end

function peak_GFA_Float_GetRange(hCam, _module, floatFeatureName, minFloatValue, maxFloatValue, incFloatValue)
    ccall((:peak_GFA_Float_GetRange, IDS), peak_status, (peak_camera_handle, peak_gfa_module, Ptr{Cchar}, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}), hCam, _module, floatFeatureName, minFloatValue, maxFloatValue, incFloatValue)
end

function peak_GFA_Float_GetList(hCam, _module, floatFeatureName, floatList, floatCount)
    ccall((:peak_GFA_Float_GetList, IDS), peak_status, (peak_camera_handle, peak_gfa_module, Ptr{Cchar}, Ptr{Cdouble}, Ptr{Csize_t}), hCam, _module, floatFeatureName, floatList, floatCount)
end

function peak_GFA_Float_Set(hCam, _module, floatFeatureName, floatValue)
    ccall((:peak_GFA_Float_Set, IDS), peak_status, (peak_camera_handle, peak_gfa_module, Ptr{Cchar}, Cdouble), hCam, _module, floatFeatureName, floatValue)
end

function peak_GFA_Float_Get(hCam, _module, floatFeatureName, floatValue)
    ccall((:peak_GFA_Float_Get, IDS), peak_status, (peak_camera_handle, peak_gfa_module, Ptr{Cchar}, Ptr{Cdouble}), hCam, _module, floatFeatureName, floatValue)
end

function peak_GFA_Integer_HasRange(hCam, _module, integerFeatureName)
    ccall((:peak_GFA_Integer_HasRange, IDS), peak_bool, (peak_camera_handle, peak_gfa_module, Ptr{Cchar}), hCam, _module, integerFeatureName)
end

function peak_GFA_Integer_GetRange(hCam, _module, integerFeatureName, minIntegerValue, maxIntegerValue, incIntegerValue)
    ccall((:peak_GFA_Integer_GetRange, IDS), peak_status, (peak_camera_handle, peak_gfa_module, Ptr{Cchar}, Ptr{Int64}, Ptr{Int64}, Ptr{Int64}), hCam, _module, integerFeatureName, minIntegerValue, maxIntegerValue, incIntegerValue)
end

function peak_GFA_Integer_GetList(hCam, _module, integerFeatureName, integerList, integerCount)
    ccall((:peak_GFA_Integer_GetList, IDS), peak_status, (peak_camera_handle, peak_gfa_module, Ptr{Cchar}, Ptr{Int64}, Ptr{Csize_t}), hCam, _module, integerFeatureName, integerList, integerCount)
end

function peak_GFA_Integer_Set(hCam, _module, integerFeatureName, integerValue)
    ccall((:peak_GFA_Integer_Set, IDS), peak_status, (peak_camera_handle, peak_gfa_module, Ptr{Cchar}, Int64), hCam, _module, integerFeatureName, integerValue)
end

function peak_GFA_Integer_Get(hCam, _module, integerFeatureName, integerValue)
    ccall((:peak_GFA_Integer_Get, IDS), peak_status, (peak_camera_handle, peak_gfa_module, Ptr{Cchar}, Ptr{Int64}), hCam, _module, integerFeatureName, integerValue)
end

function peak_GFA_Boolean_Set(hCam, _module, booleanFeatureName, booleanValue)
    ccall((:peak_GFA_Boolean_Set, IDS), peak_status, (peak_camera_handle, peak_gfa_module, Ptr{Cchar}, peak_bool), hCam, _module, booleanFeatureName, booleanValue)
end

function peak_GFA_Boolean_Get(hCam, _module, booleanFeatureName, booleanValue)
    ccall((:peak_GFA_Boolean_Get, IDS), peak_status, (peak_camera_handle, peak_gfa_module, Ptr{Cchar}, Ptr{peak_bool}), hCam, _module, booleanFeatureName, booleanValue)
end

function peak_GFA_String_Set(hCam, _module, stringFeatureName, stringValue)
    ccall((:peak_GFA_String_Set, IDS), peak_status, (peak_camera_handle, peak_gfa_module, Ptr{Cchar}, Ptr{Cchar}), hCam, _module, stringFeatureName, stringValue)
end

function peak_GFA_String_Get(hCam, _module, stringFeatureName, stringValue, stringValueSize)
    ccall((:peak_GFA_String_Get, IDS), peak_status, (peak_camera_handle, peak_gfa_module, Ptr{Cchar}, Ptr{Cchar}, Ptr{Csize_t}), hCam, _module, stringFeatureName, stringValue, stringValueSize)
end

function peak_GFA_Command_Execute(hCam, _module, commandFeatureName)
    ccall((:peak_GFA_Command_Execute, IDS), peak_status, (peak_camera_handle, peak_gfa_module, Ptr{Cchar}), hCam, _module, commandFeatureName)
end

function peak_GFA_Command_WaitForDone(hCam, _module, commandFeatureName, timeout_ms)
    ccall((:peak_GFA_Command_WaitForDone, IDS), peak_status, (peak_camera_handle, peak_gfa_module, Ptr{Cchar}, UInt32), hCam, _module, commandFeatureName, timeout_ms)
end

function peak_GFA_Enumeration_GetList(hCam, _module, enumerationFeatureName, enumerationEntryList, enumerationEntryCount)
    ccall((:peak_GFA_Enumeration_GetList, IDS), peak_status, (peak_camera_handle, peak_gfa_module, Ptr{Cchar}, Ptr{peak_gfa_enumeration_entry}, Ptr{Csize_t}), hCam, _module, enumerationFeatureName, enumerationEntryList, enumerationEntryCount)
end

function peak_GFA_EnumerationEntry_GetAccessStatus(hCam, _module, enumerationFeatureName, enumerationEntry)
    ccall((:peak_GFA_EnumerationEntry_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle, peak_gfa_module, Ptr{Cchar}, Ptr{peak_gfa_enumeration_entry}), hCam, _module, enumerationFeatureName, enumerationEntry)
end

function peak_GFA_EnumerationEntry_GetAccessStatusBySymbolicValue(hCam, _module, enumerationFeatureName, enumerationEntrySymbolicValue)
    ccall((:peak_GFA_EnumerationEntry_GetAccessStatusBySymbolicValue, IDS), peak_access_status, (peak_camera_handle, peak_gfa_module, Ptr{Cchar}, Ptr{Cchar}), hCam, _module, enumerationFeatureName, enumerationEntrySymbolicValue)
end

function peak_GFA_EnumerationEntry_GetAccessStatusByIntegerValue(hCam, _module, enumerationFeatureName, enumerationEntryIntegerValue)
    ccall((:peak_GFA_EnumerationEntry_GetAccessStatusByIntegerValue, IDS), peak_access_status, (peak_camera_handle, peak_gfa_module, Ptr{Cchar}, Int64), hCam, _module, enumerationFeatureName, enumerationEntryIntegerValue)
end

function peak_GFA_Enumeration_Set(hCam, _module, enumerationFeatureName, enumerationEntry)
    ccall((:peak_GFA_Enumeration_Set, IDS), peak_status, (peak_camera_handle, peak_gfa_module, Ptr{Cchar}, Ptr{peak_gfa_enumeration_entry}), hCam, _module, enumerationFeatureName, enumerationEntry)
end

function peak_GFA_Enumeration_SetBySymbolicValue(hCam, _module, enumerationFeatureName, enumerationEntrySymbolicValue)
    ccall((:peak_GFA_Enumeration_SetBySymbolicValue, IDS), peak_status, (peak_camera_handle, peak_gfa_module, Ptr{Cchar}, Ptr{Cchar}), hCam, _module, enumerationFeatureName, enumerationEntrySymbolicValue)
end

function peak_GFA_Enumeration_SetByIntegerValue(hCam, _module, enumerationFeatureName, enumerationEntryIntegerValue)
    ccall((:peak_GFA_Enumeration_SetByIntegerValue, IDS), peak_status, (peak_camera_handle, peak_gfa_module, Ptr{Cchar}, Int64), hCam, _module, enumerationFeatureName, enumerationEntryIntegerValue)
end

function peak_GFA_Enumeration_Get(hCam, _module, enumerationFeatureName, enumerationEntry)
    ccall((:peak_GFA_Enumeration_Get, IDS), peak_status, (peak_camera_handle, peak_gfa_module, Ptr{Cchar}, Ptr{peak_gfa_enumeration_entry}), hCam, _module, enumerationFeatureName, enumerationEntry)
end

function peak_GFA_Register_Set(hCam, _module, registerFeatureName, registerValue, registerValueSize)
    ccall((:peak_GFA_Register_Set, IDS), peak_status, (peak_camera_handle, peak_gfa_module, Ptr{Cchar}, Ptr{UInt8}, Csize_t), hCam, _module, registerFeatureName, registerValue, registerValueSize)
end

function peak_GFA_Register_Get(hCam, _module, registerFeatureName, registerValue, registerValueSize)
    ccall((:peak_GFA_Register_Get, IDS), peak_status, (peak_camera_handle, peak_gfa_module, Ptr{Cchar}, Ptr{UInt8}, Ptr{Csize_t}), hCam, _module, registerFeatureName, registerValue, registerValueSize)
end

function peak_GFA_Data_Write(hCam, _module, address, data, dataSize)
    ccall((:peak_GFA_Data_Write, IDS), peak_status, (peak_camera_handle, peak_gfa_module, UInt64, Ptr{UInt8}, Csize_t), hCam, _module, address, data, dataSize)
end

function peak_GFA_Data_Read(hCam, _module, address, data, dataSize)
    ccall((:peak_GFA_Data_Read, IDS), peak_status, (peak_camera_handle, peak_gfa_module, UInt64, Ptr{UInt8}, Csize_t), hCam, _module, address, data, dataSize)
end

function peak_IPL_PixelFormat_GetList(hCam, inputPixelFormat, outputPixelFormatList, outputPixelFormatCount)
    ccall((:peak_IPL_PixelFormat_GetList, IDS), peak_status, (peak_camera_handle, peak_pixel_format, Ptr{peak_pixel_format}, Ptr{Csize_t}), hCam, inputPixelFormat, outputPixelFormatList, outputPixelFormatCount)
end

function peak_IPL_PixelFormat_Set(hCam, pixelFormat)
    ccall((:peak_IPL_PixelFormat_Set, IDS), peak_status, (peak_camera_handle, peak_pixel_format), hCam, pixelFormat)
end

function peak_IPL_PixelFormat_Get(hCam, pixelFormat)
    ccall((:peak_IPL_PixelFormat_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_pixel_format}), hCam, pixelFormat)
end

function peak_IPL_Gain_GetRange(hCam, gainChannel, minGain, maxGain, incGain)
    ccall((:peak_IPL_Gain_GetRange, IDS), peak_status, (peak_camera_handle, peak_gain_channel, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}), hCam, gainChannel, minGain, maxGain, incGain)
end

function peak_IPL_Gain_Set(hCam, gainChannel, gain)
    ccall((:peak_IPL_Gain_Set, IDS), peak_status, (peak_camera_handle, peak_gain_channel, Cdouble), hCam, gainChannel, gain)
end

function peak_IPL_Gain_Get(hCam, gainChannel, gain)
    ccall((:peak_IPL_Gain_Get, IDS), peak_status, (peak_camera_handle, peak_gain_channel, Ptr{Cdouble}), hCam, gainChannel, gain)
end

function peak_IPL_Gamma_GetRange(hCam, minGamma, maxGamma, incGamma)
    ccall((:peak_IPL_Gamma_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}), hCam, minGamma, maxGamma, incGamma)
end

function peak_IPL_Gamma_Set(hCam, gamma)
    ccall((:peak_IPL_Gamma_Set, IDS), peak_status, (peak_camera_handle, Cdouble), hCam, gamma)
end

function peak_IPL_Gamma_Get(hCam, gamma)
    ccall((:peak_IPL_Gamma_Get, IDS), peak_status, (peak_camera_handle, Ptr{Cdouble}), hCam, gamma)
end

function peak_IPL_ColorCorrection_Matrix_Set(hCam, colorCorrectionMatrix)
    ccall((:peak_IPL_ColorCorrection_Matrix_Set, IDS), peak_status, (peak_camera_handle, peak_matrix), hCam, colorCorrectionMatrix)
end

function peak_IPL_ColorCorrection_Matrix_Get(hCam, colorCorrectionMatrix)
    ccall((:peak_IPL_ColorCorrection_Matrix_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_matrix}), hCam, colorCorrectionMatrix)
end

function peak_IPL_ColorCorrection_Saturation_Get(hCam, saturation)
    ccall((:peak_IPL_ColorCorrection_Saturation_Get, IDS), peak_status, (peak_camera_handle, Ptr{Cdouble}), hCam, saturation)
end

function peak_IPL_ColorCorrection_Saturation_Set(hCam, saturation)
    ccall((:peak_IPL_ColorCorrection_Saturation_Set, IDS), peak_status, (peak_camera_handle, Cdouble), hCam, saturation)
end

function peak_IPL_ColorCorrection_Saturation_GetRange(hCam, minSaturation, maxSaturation, incSaturation)
    ccall((:peak_IPL_ColorCorrection_Saturation_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}), hCam, minSaturation, maxSaturation, incSaturation)
end

function peak_IPL_ColorCorrection_ChromaticAdaption_ColorSpace_Get(hCam, colorSpace)
    ccall((:peak_IPL_ColorCorrection_ChromaticAdaption_ColorSpace_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_chromatic_adaption_color_space}), hCam, colorSpace)
end

function peak_IPL_ColorCorrection_ChromaticAdaption_ColorSpace_Set(hCam, colorSpace)
    ccall((:peak_IPL_ColorCorrection_ChromaticAdaption_ColorSpace_Set, IDS), peak_status, (peak_camera_handle, peak_chromatic_adaption_color_space), hCam, colorSpace)
end

function peak_IPL_ColorCorrection_ChromaticAdaption_Algorithm_Get(hCam, algorithm)
    ccall((:peak_IPL_ColorCorrection_ChromaticAdaption_Algorithm_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_chromatic_adaption_algorithm}), hCam, algorithm)
end

function peak_IPL_ColorCorrection_ChromaticAdaption_Algorithm_Set(hCam, algorithm)
    ccall((:peak_IPL_ColorCorrection_ChromaticAdaption_Algorithm_Set, IDS), peak_status, (peak_camera_handle, peak_chromatic_adaption_algorithm), hCam, algorithm)
end

function peak_IPL_ColorCorrection_ChromaticAdaption_ColorTemperature_Get(hCam, colorTemperature)
    ccall((:peak_IPL_ColorCorrection_ChromaticAdaption_ColorTemperature_Get, IDS), peak_status, (peak_camera_handle, Ptr{UInt32}), hCam, colorTemperature)
end

function peak_IPL_ColorCorrection_ChromaticAdaption_ColorTemperature_Set(hCam, colorTemperature)
    ccall((:peak_IPL_ColorCorrection_ChromaticAdaption_ColorTemperature_Set, IDS), peak_status, (peak_camera_handle, UInt32), hCam, colorTemperature)
end

function peak_IPL_ColorCorrection_ChromaticAdaption_ColorTemperature_GetRange(hCam, minColorTemperature, maxColorTemperature, incColorTemperature)
    ccall((:peak_IPL_ColorCorrection_ChromaticAdaption_ColorTemperature_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{UInt32}, Ptr{UInt32}, Ptr{UInt32}), hCam, minColorTemperature, maxColorTemperature, incColorTemperature)
end

function peak_IPL_ColorCorrection_ChromaticAdaption_Enable(hCam, enable)
    ccall((:peak_IPL_ColorCorrection_ChromaticAdaption_Enable, IDS), peak_status, (peak_camera_handle, peak_bool), hCam, enable)
end

function peak_IPL_ColorCorrection_ChromaticAdaption_IsEnabled(hCam)
    ccall((:peak_IPL_ColorCorrection_ChromaticAdaption_IsEnabled, IDS), peak_bool, (peak_camera_handle,), hCam)
end

function peak_IPL_ColorCorrection_Enable(hCam, enabled)
    ccall((:peak_IPL_ColorCorrection_Enable, IDS), peak_status, (peak_camera_handle, peak_bool), hCam, enabled)
end

function peak_IPL_ColorCorrection_IsEnabled(hCam)
    ccall((:peak_IPL_ColorCorrection_IsEnabled, IDS), peak_bool, (peak_camera_handle,), hCam)
end

function peak_IPL_AutoBrightness_Target_GetRange(hCam, minAutoBrightnessTarget, maxAutoBrightnessTarget, incAutoBrightnessTarget)
    ccall((:peak_IPL_AutoBrightness_Target_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{UInt32}, Ptr{UInt32}, Ptr{UInt32}), hCam, minAutoBrightnessTarget, maxAutoBrightnessTarget, incAutoBrightnessTarget)
end

function peak_IPL_AutoBrightness_Target_Set(hCam, autoBrightnessTarget)
    ccall((:peak_IPL_AutoBrightness_Target_Set, IDS), peak_status, (peak_camera_handle, UInt32), hCam, autoBrightnessTarget)
end

function peak_IPL_AutoBrightness_Target_Get(hCam, autoBrightnessTarget)
    ccall((:peak_IPL_AutoBrightness_Target_Get, IDS), peak_status, (peak_camera_handle, Ptr{UInt32}), hCam, autoBrightnessTarget)
end

function peak_IPL_AutoBrightness_TargetTolerance_GetRange(hCam, minAutoBrightnessTargetTolerance, maxAutoBrightnessTargetTolerance, incAutoBrightnessTargetTolerance)
    ccall((:peak_IPL_AutoBrightness_TargetTolerance_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{UInt32}, Ptr{UInt32}, Ptr{UInt32}), hCam, minAutoBrightnessTargetTolerance, maxAutoBrightnessTargetTolerance, incAutoBrightnessTargetTolerance)
end

function peak_IPL_AutoBrightness_TargetTolerance_Set(hCam, autoBrightnessTargetTolerance)
    ccall((:peak_IPL_AutoBrightness_TargetTolerance_Set, IDS), peak_status, (peak_camera_handle, UInt32), hCam, autoBrightnessTargetTolerance)
end

function peak_IPL_AutoBrightness_TargetTolerance_Get(hCam, autoBrightnessTargetTolerance)
    ccall((:peak_IPL_AutoBrightness_TargetTolerance_Get, IDS), peak_status, (peak_camera_handle, Ptr{UInt32}), hCam, autoBrightnessTargetTolerance)
end

function peak_IPL_AutoBrightness_TargetPercentile_GetRange(hCam, minAutoBrightnessTargetPercentile, maxAutoBrightnessTargetPercentile, incAutoBrightnessTargetPercentile)
    ccall((:peak_IPL_AutoBrightness_TargetPercentile_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}), hCam, minAutoBrightnessTargetPercentile, maxAutoBrightnessTargetPercentile, incAutoBrightnessTargetPercentile)
end

function peak_IPL_AutoBrightness_TargetPercentile_Set(hCam, autoBrightnessTargetPercentile)
    ccall((:peak_IPL_AutoBrightness_TargetPercentile_Set, IDS), peak_status, (peak_camera_handle, Cdouble), hCam, autoBrightnessTargetPercentile)
end

function peak_IPL_AutoBrightness_TargetPercentile_Get(hCam, autoBrightnessTargetPercentile)
    ccall((:peak_IPL_AutoBrightness_TargetPercentile_Get, IDS), peak_status, (peak_camera_handle, Ptr{Cdouble}), hCam, autoBrightnessTargetPercentile)
end

function peak_IPL_AutoBrightness_ROI_Mode_Set(hCam, autoBrightnessROIMode)
    ccall((:peak_IPL_AutoBrightness_ROI_Mode_Set, IDS), peak_status, (peak_camera_handle, peak_auto_feature_roi_mode), hCam, autoBrightnessROIMode)
end

function peak_IPL_AutoBrightness_ROI_Mode_Get(hCam, autoBrightnessROIMode)
    ccall((:peak_IPL_AutoBrightness_ROI_Mode_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_auto_feature_roi_mode}), hCam, autoBrightnessROIMode)
end

function peak_IPL_AutoBrightness_ROI_Offset_GetRange(hCam, minAutoBrightnessROIOffset, maxAutoBrightnessROIOffset, incAutoBrightnessROIOffset)
    ccall((:peak_IPL_AutoBrightness_ROI_Offset_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{peak_position}, Ptr{peak_position}, Ptr{peak_position}), hCam, minAutoBrightnessROIOffset, maxAutoBrightnessROIOffset, incAutoBrightnessROIOffset)
end

function peak_IPL_AutoBrightness_ROI_Size_GetRange(hCam, minAutoBrightnessROISize, maxAutoBrightnessROISize, incAutoBrightnessROISize)
    ccall((:peak_IPL_AutoBrightness_ROI_Size_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{peak_size}, Ptr{peak_size}, Ptr{peak_size}), hCam, minAutoBrightnessROISize, maxAutoBrightnessROISize, incAutoBrightnessROISize)
end

function peak_IPL_AutoBrightness_ROI_Set(hCam, autoBrightnessROI)
    ccall((:peak_IPL_AutoBrightness_ROI_Set, IDS), peak_status, (peak_camera_handle, peak_roi), hCam, autoBrightnessROI)
end

function peak_IPL_AutoBrightness_ROI_Get(hCam, autoBrightnessROI)
    ccall((:peak_IPL_AutoBrightness_ROI_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_roi}), hCam, autoBrightnessROI)
end

function peak_IPL_AutoBrightness_Exposure_Mode_Set(hCam, autoExposureMode)
    ccall((:peak_IPL_AutoBrightness_Exposure_Mode_Set, IDS), peak_status, (peak_camera_handle, peak_auto_feature_mode), hCam, autoExposureMode)
end

function peak_IPL_AutoBrightness_Exposure_Mode_Get(hCam, autoExposureMode)
    ccall((:peak_IPL_AutoBrightness_Exposure_Mode_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_auto_feature_mode}), hCam, autoExposureMode)
end

function peak_IPL_AutoBrightness_ExposureLimit_Get(hCam, exposureLimit)
    ccall((:peak_IPL_AutoBrightness_ExposureLimit_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_double_limit}), hCam, exposureLimit)
end

function peak_IPL_AutoBrightness_ExposureLimit_GetRange(hCam, exposureLimit)
    ccall((:peak_IPL_AutoBrightness_ExposureLimit_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{peak_double_limit}), hCam, exposureLimit)
end

function peak_IPL_AutoBrightness_ExposureLimit_Set(hCam, exposureLimit)
    ccall((:peak_IPL_AutoBrightness_ExposureLimit_Set, IDS), peak_status, (peak_camera_handle, peak_double_limit), hCam, exposureLimit)
end

function peak_IPL_AutoBrightness_Gain_Mode_Set(hCam, autoGainMode)
    ccall((:peak_IPL_AutoBrightness_Gain_Mode_Set, IDS), peak_status, (peak_camera_handle, peak_auto_feature_mode), hCam, autoGainMode)
end

function peak_IPL_AutoBrightness_Gain_Mode_Get(hCam, autoGainMode)
    ccall((:peak_IPL_AutoBrightness_Gain_Mode_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_auto_feature_mode}), hCam, autoGainMode)
end

function peak_IPL_AutoBrightness_GainAnalog_Mode_Set(hCam, autoGainMode)
    ccall((:peak_IPL_AutoBrightness_GainAnalog_Mode_Set, IDS), peak_status, (peak_camera_handle, peak_auto_feature_mode), hCam, autoGainMode)
end

function peak_IPL_AutoBrightness_GainAnalog_Mode_Get(hCam, autoGainMode)
    ccall((:peak_IPL_AutoBrightness_GainAnalog_Mode_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_auto_feature_mode}), hCam, autoGainMode)
end

function peak_IPL_AutoBrightness_GainDigital_Mode_Set(hCam, autoGainMode)
    ccall((:peak_IPL_AutoBrightness_GainDigital_Mode_Set, IDS), peak_status, (peak_camera_handle, peak_auto_feature_mode), hCam, autoGainMode)
end

function peak_IPL_AutoBrightness_GainDigital_Mode_Get(hCam, autoGainMode)
    ccall((:peak_IPL_AutoBrightness_GainDigital_Mode_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_auto_feature_mode}), hCam, autoGainMode)
end

function peak_IPL_AutoBrightness_GainCombined_Mode_Set(hCam, autoGainMode)
    ccall((:peak_IPL_AutoBrightness_GainCombined_Mode_Set, IDS), peak_status, (peak_camera_handle, peak_auto_feature_mode), hCam, autoGainMode)
end

function peak_IPL_AutoBrightness_GainCombined_Mode_Get(hCam, autoGainMode)
    ccall((:peak_IPL_AutoBrightness_GainCombined_Mode_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_auto_feature_mode}), hCam, autoGainMode)
end

function peak_IPL_AutoBrightness_GainHost_Mode_Set(hCam, autoGainMode)
    ccall((:peak_IPL_AutoBrightness_GainHost_Mode_Set, IDS), peak_status, (peak_camera_handle, peak_auto_feature_mode), hCam, autoGainMode)
end

function peak_IPL_AutoBrightness_GainHost_Mode_Get(hCam, autoGainMode)
    ccall((:peak_IPL_AutoBrightness_GainHost_Mode_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_auto_feature_mode}), hCam, autoGainMode)
end

function peak_IPL_AutoBrightness_Algorithm_Set(hCam, algorithm)
    ccall((:peak_IPL_AutoBrightness_Algorithm_Set, IDS), peak_status, (peak_camera_handle, peak_auto_feature_brightness_algorithm), hCam, algorithm)
end

function peak_IPL_AutoBrightness_Algorithm_Get(hCam, algorithm)
    ccall((:peak_IPL_AutoBrightness_Algorithm_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_auto_feature_brightness_algorithm}), hCam, algorithm)
end

function peak_IPL_AutoBrightness_AverageLast_Get(hCam, lastAverage)
    ccall((:peak_IPL_AutoBrightness_AverageLast_Get, IDS), peak_status, (peak_camera_handle, Ptr{UInt32}), hCam, lastAverage)
end

function peak_IPL_AutoBrightness_GainLimit_Set(hCam, gainLimit)
    ccall((:peak_IPL_AutoBrightness_GainLimit_Set, IDS), peak_status, (peak_camera_handle, peak_double_limit), hCam, gainLimit)
end

function peak_IPL_AutoBrightness_GainLimit_Get(hCam, gainLimit)
    ccall((:peak_IPL_AutoBrightness_GainLimit_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_double_limit}), hCam, gainLimit)
end

function peak_IPL_AutoBrightness_GainLimit_GetRange(hCam, gainLimit)
    ccall((:peak_IPL_AutoBrightness_GainLimit_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{peak_double_limit}), hCam, gainLimit)
end

function peak_IPL_AutoBrightness_GainAnalogLimit_Set(hCam, gainLimit)
    ccall((:peak_IPL_AutoBrightness_GainAnalogLimit_Set, IDS), peak_status, (peak_camera_handle, peak_double_limit), hCam, gainLimit)
end

function peak_IPL_AutoBrightness_GainAnalogLimit_Get(hCam, gainLimit)
    ccall((:peak_IPL_AutoBrightness_GainAnalogLimit_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_double_limit}), hCam, gainLimit)
end

function peak_IPL_AutoBrightness_GainAnalogLimit_GetRange(hCam, gainLimit)
    ccall((:peak_IPL_AutoBrightness_GainAnalogLimit_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{peak_double_limit}), hCam, gainLimit)
end

function peak_IPL_AutoBrightness_GainDigitalLimit_Set(hCam, gainLimit)
    ccall((:peak_IPL_AutoBrightness_GainDigitalLimit_Set, IDS), peak_status, (peak_camera_handle, peak_double_limit), hCam, gainLimit)
end

function peak_IPL_AutoBrightness_GainDigitalLimit_Get(hCam, gainLimit)
    ccall((:peak_IPL_AutoBrightness_GainDigitalLimit_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_double_limit}), hCam, gainLimit)
end

function peak_IPL_AutoBrightness_GainDigitalLimit_GetRange(hCam, gainLimit)
    ccall((:peak_IPL_AutoBrightness_GainDigitalLimit_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{peak_double_limit}), hCam, gainLimit)
end

function peak_IPL_AutoBrightness_GainCombinedLimit_Set(hCam, gainLimit)
    ccall((:peak_IPL_AutoBrightness_GainCombinedLimit_Set, IDS), peak_status, (peak_camera_handle, peak_double_limit), hCam, gainLimit)
end

function peak_IPL_AutoBrightness_GainCombinedLimit_Get(hCam, gainLimit)
    ccall((:peak_IPL_AutoBrightness_GainCombinedLimit_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_double_limit}), hCam, gainLimit)
end

function peak_IPL_AutoBrightness_GainCombinedLimit_GetRange(hCam, gainLimit)
    ccall((:peak_IPL_AutoBrightness_GainCombinedLimit_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{peak_double_limit}), hCam, gainLimit)
end

function peak_IPL_AutoBrightness_GainHostLimit_Set(hCam, gainLimit)
    ccall((:peak_IPL_AutoBrightness_GainHostLimit_Set, IDS), peak_status, (peak_camera_handle, peak_double_limit), hCam, gainLimit)
end

function peak_IPL_AutoBrightness_GainHostLimit_Get(hCam, gainLimit)
    ccall((:peak_IPL_AutoBrightness_GainHostLimit_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_double_limit}), hCam, gainLimit)
end

function peak_IPL_AutoBrightness_GainHostLimit_GetRange(hCam, gainLimit)
    ccall((:peak_IPL_AutoBrightness_GainHostLimit_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{peak_double_limit}), hCam, gainLimit)
end

function peak_IPL_AutoBrightness_SkipFrames_Set(hCam, skipFrames)
    ccall((:peak_IPL_AutoBrightness_SkipFrames_Set, IDS), peak_status, (peak_camera_handle, UInt32), hCam, skipFrames)
end

function peak_IPL_AutoBrightness_SkipFrames_Get(hCam, skipFrames)
    ccall((:peak_IPL_AutoBrightness_SkipFrames_Get, IDS), peak_status, (peak_camera_handle, Ptr{UInt32}), hCam, skipFrames)
end

function peak_IPL_AutoBrightness_SkipFrames_GetRange(hCam, skipFramesMin, skipFramesMax, skipFramesInc)
    ccall((:peak_IPL_AutoBrightness_SkipFrames_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{UInt32}, Ptr{UInt32}, Ptr{UInt32}), hCam, skipFramesMin, skipFramesMax, skipFramesInc)
end

function peak_IPL_AutoWhiteBalance_ROI_Mode_Set(hCam, autoWhiteBalanceROIMode)
    ccall((:peak_IPL_AutoWhiteBalance_ROI_Mode_Set, IDS), peak_status, (peak_camera_handle, peak_auto_feature_roi_mode), hCam, autoWhiteBalanceROIMode)
end

function peak_IPL_AutoWhiteBalance_ROI_Mode_Get(hCam, autoWhiteBalanceROIMode)
    ccall((:peak_IPL_AutoWhiteBalance_ROI_Mode_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_auto_feature_roi_mode}), hCam, autoWhiteBalanceROIMode)
end

function peak_IPL_AutoWhiteBalance_ROI_Offset_GetRange(hCam, minAutoWhiteBalanceROIOffset, maxAutoWhiteBalanceROIOffset, incAutoWhiteBalanceROIOffset)
    ccall((:peak_IPL_AutoWhiteBalance_ROI_Offset_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{peak_position}, Ptr{peak_position}, Ptr{peak_position}), hCam, minAutoWhiteBalanceROIOffset, maxAutoWhiteBalanceROIOffset, incAutoWhiteBalanceROIOffset)
end

function peak_IPL_AutoWhiteBalance_ROI_Size_GetRange(hCam, minAutoWhiteBalanceROISize, maxAutoWhiteBalanceROISize, incAutoWhiteBalanceROISize)
    ccall((:peak_IPL_AutoWhiteBalance_ROI_Size_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{peak_size}, Ptr{peak_size}, Ptr{peak_size}), hCam, minAutoWhiteBalanceROISize, maxAutoWhiteBalanceROISize, incAutoWhiteBalanceROISize)
end

function peak_IPL_AutoWhiteBalance_ROI_Set(hCam, autoWhiteBalanceROI)
    ccall((:peak_IPL_AutoWhiteBalance_ROI_Set, IDS), peak_status, (peak_camera_handle, peak_roi), hCam, autoWhiteBalanceROI)
end

function peak_IPL_AutoWhiteBalance_ROI_Get(hCam, autoWhiteBalanceROI)
    ccall((:peak_IPL_AutoWhiteBalance_ROI_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_roi}), hCam, autoWhiteBalanceROI)
end

function peak_IPL_AutoWhiteBalance_Mode_Set(hCam, autoWhiteBalanceMode)
    ccall((:peak_IPL_AutoWhiteBalance_Mode_Set, IDS), peak_status, (peak_camera_handle, peak_auto_feature_mode), hCam, autoWhiteBalanceMode)
end

function peak_IPL_AutoWhiteBalance_Mode_Get(hCam, autoWhiteBalanceMode)
    ccall((:peak_IPL_AutoWhiteBalance_Mode_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_auto_feature_mode}), hCam, autoWhiteBalanceMode)
end

function peak_IPL_AutoWhiteBalance_SkipFrames_Set(hCam, skipFrames)
    ccall((:peak_IPL_AutoWhiteBalance_SkipFrames_Set, IDS), peak_status, (peak_camera_handle, UInt32), hCam, skipFrames)
end

function peak_IPL_AutoWhiteBalance_SkipFrames_Get(hCam, skipFrames)
    ccall((:peak_IPL_AutoWhiteBalance_SkipFrames_Get, IDS), peak_status, (peak_camera_handle, Ptr{UInt32}), hCam, skipFrames)
end

function peak_IPL_AutoWhiteBalance_SkipFrames_GetRange(hCam, skipFramesMin, skipFramesMax, skipFramesInc)
    ccall((:peak_IPL_AutoWhiteBalance_SkipFrames_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{UInt32}, Ptr{UInt32}, Ptr{UInt32}), hCam, skipFramesMin, skipFramesMax, skipFramesInc)
end

function peak_IPL_AutoFocus_GetAccessStatus(hCam)
    ccall((:peak_IPL_AutoFocus_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_IPL_AutoFocus_ROI_Set(hCam, autoFocusROIList, autoFocusROICount)
    ccall((:peak_IPL_AutoFocus_ROI_Set, IDS), peak_status, (peak_camera_handle, Ptr{peak_focus_roi}, Csize_t), hCam, autoFocusROIList, autoFocusROICount)
end

function peak_IPL_AutoFocus_ROI_Get(hCam, autoFocusROIList, autoFocusROICount)
    ccall((:peak_IPL_AutoFocus_ROI_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_focus_roi}, Ptr{Csize_t}), hCam, autoFocusROIList, autoFocusROICount)
end

function peak_IPL_AutoFocus_Mode_Set(hCam, autoFocusMode)
    ccall((:peak_IPL_AutoFocus_Mode_Set, IDS), peak_status, (peak_camera_handle, peak_auto_feature_mode), hCam, autoFocusMode)
end

function peak_IPL_AutoFocus_Mode_Get(hCam, autoFocusMode)
    ccall((:peak_IPL_AutoFocus_Mode_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_auto_feature_mode}), hCam, autoFocusMode)
end

function peak_IPL_AutoFocus_SearchAlgorithm_Set(hCam, searchAlgorithm)
    ccall((:peak_IPL_AutoFocus_SearchAlgorithm_Set, IDS), peak_status, (peak_camera_handle, peak_auto_focus_search_algorithm), hCam, searchAlgorithm)
end

function peak_IPL_AutoFocus_SearchAlgorithm_Get(hCam, searchAlgorithm)
    ccall((:peak_IPL_AutoFocus_SearchAlgorithm_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_auto_focus_search_algorithm}), hCam, searchAlgorithm)
end

function peak_IPL_AutoFocus_SharpnessAlgorithm_Set(hCam, sharpnessAlgorithm)
    ccall((:peak_IPL_AutoFocus_SharpnessAlgorithm_Set, IDS), peak_status, (peak_camera_handle, peak_sharpness_algorithm), hCam, sharpnessAlgorithm)
end

function peak_IPL_AutoFocus_SharpnessAlgorithm_Get(hCam, sharpnessAlgorithm)
    ccall((:peak_IPL_AutoFocus_SharpnessAlgorithm_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_sharpness_algorithm}), hCam, sharpnessAlgorithm)
end

function peak_IPL_AutoFocus_Range_Set(hCam, rangeBegin, rangeEnd)
    ccall((:peak_IPL_AutoFocus_Range_Set, IDS), peak_status, (peak_camera_handle, UInt32, UInt32), hCam, rangeBegin, rangeEnd)
end

function peak_IPL_AutoFocus_Range_Get(hCam, rangeBegin, rangeEnd)
    ccall((:peak_IPL_AutoFocus_Range_Get, IDS), peak_status, (peak_camera_handle, Ptr{UInt32}, Ptr{UInt32}), hCam, rangeBegin, rangeEnd)
end

function peak_IPL_AutoFocus_Hysteresis_Set(hCam, hysteresis)
    ccall((:peak_IPL_AutoFocus_Hysteresis_Set, IDS), peak_status, (peak_camera_handle, UInt8), hCam, hysteresis)
end

function peak_IPL_AutoFocus_Hysteresis_Get(hCam, hysteresis)
    ccall((:peak_IPL_AutoFocus_Hysteresis_Get, IDS), peak_status, (peak_camera_handle, Ptr{UInt8}), hCam, hysteresis)
end

function peak_IPL_AutoFocus_Hysteresis_GetRange(hCam, minHysteresis, maxHysteresis, incHysteresis)
    ccall((:peak_IPL_AutoFocus_Hysteresis_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{UInt8}, Ptr{UInt8}, Ptr{UInt8}), hCam, minHysteresis, maxHysteresis, incHysteresis)
end

function peak_IPL_HotpixelCorrection_Sensitivity_Set(hCam, hotpixelCorrectionSensitivity)
    ccall((:peak_IPL_HotpixelCorrection_Sensitivity_Set, IDS), peak_status, (peak_camera_handle, peak_hotpixel_correction_sensitivity), hCam, hotpixelCorrectionSensitivity)
end

function peak_IPL_HotpixelCorrection_Sensitivity_Get(hCam, hotpixelCorrectionSensitivity)
    ccall((:peak_IPL_HotpixelCorrection_Sensitivity_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_hotpixel_correction_sensitivity}), hCam, hotpixelCorrectionSensitivity)
end

function peak_IPL_HotpixelCorrection_GetList(hCam, hotpixelList, hotpixelCount)
    ccall((:peak_IPL_HotpixelCorrection_GetList, IDS), peak_status, (peak_camera_handle, Ptr{peak_position}, Ptr{Csize_t}), hCam, hotpixelList, hotpixelCount)
end

function peak_IPL_HotpixelCorrection_SetList(hCam, hotpixelList, hotpixelCount)
    ccall((:peak_IPL_HotpixelCorrection_SetList, IDS), peak_status, (peak_camera_handle, Ptr{peak_position}, Csize_t), hCam, hotpixelList, hotpixelCount)
end

function peak_IPL_HotpixelCorrection_ResetList(hCam)
    ccall((:peak_IPL_HotpixelCorrection_ResetList, IDS), peak_status, (peak_camera_handle,), hCam)
end

function peak_IPL_HotpixelCorrection_Enable(hCam, enabled)
    ccall((:peak_IPL_HotpixelCorrection_Enable, IDS), peak_status, (peak_camera_handle, peak_bool), hCam, enabled)
end

function peak_IPL_HotpixelCorrection_IsEnabled(hCam)
    ccall((:peak_IPL_HotpixelCorrection_IsEnabled, IDS), peak_bool, (peak_camera_handle,), hCam)
end

function peak_IPL_Mirror_UpDown_Enable(hCam, enabled)
    ccall((:peak_IPL_Mirror_UpDown_Enable, IDS), peak_status, (peak_camera_handle, peak_bool), hCam, enabled)
end

function peak_IPL_Mirror_UpDown_IsEnabled(hCam)
    ccall((:peak_IPL_Mirror_UpDown_IsEnabled, IDS), peak_bool, (peak_camera_handle,), hCam)
end

function peak_IPL_Mirror_LeftRight_Enable(hCam, enabled)
    ccall((:peak_IPL_Mirror_LeftRight_Enable, IDS), peak_status, (peak_camera_handle, peak_bool), hCam, enabled)
end

function peak_IPL_Mirror_LeftRight_IsEnabled(hCam)
    ccall((:peak_IPL_Mirror_LeftRight_IsEnabled, IDS), peak_bool, (peak_camera_handle,), hCam)
end

function peak_IPL_ProcessFrame(hCam, hFrame, hResultFrame)
    ccall((:peak_IPL_ProcessFrame, IDS), peak_status, (peak_camera_handle, peak_frame_handle, Ptr{peak_frame_handle}), hCam, hFrame, hResultFrame)
end

function peak_IPL_ProcessFrameInplace(hCam, hFrame)
    ccall((:peak_IPL_ProcessFrameInplace, IDS), peak_status, (peak_camera_handle, peak_frame_handle), hCam, hFrame)
end

function peak_IPL_ReadImage(hCam, path, hFrame)
    ccall((:peak_IPL_ReadImage, IDS), peak_status, (peak_camera_handle, Ptr{Cchar}, Ptr{peak_frame_handle}), hCam, path, hFrame)
end

function peak_IPL_EdgeEnhancement_Enable(hCam, enable)
    ccall((:peak_IPL_EdgeEnhancement_Enable, IDS), peak_status, (peak_camera_handle, peak_bool), hCam, enable)
end

function peak_IPL_EdgeEnhancement_IsEnabled(hCam)
    ccall((:peak_IPL_EdgeEnhancement_IsEnabled, IDS), peak_bool, (peak_camera_handle,), hCam)
end

function peak_IPL_EdgeEnhancement_Factor_Set(hCam, factor)
    ccall((:peak_IPL_EdgeEnhancement_Factor_Set, IDS), peak_status, (peak_camera_handle, UInt32), hCam, factor)
end

function peak_IPL_EdgeEnhancement_Factor_Get(hCam, factor)
    ccall((:peak_IPL_EdgeEnhancement_Factor_Get, IDS), peak_status, (peak_camera_handle, Ptr{UInt32}), hCam, factor)
end

function peak_IPL_EdgeEnhancement_Factor_GetDefault(hCam, defaultFactor)
    ccall((:peak_IPL_EdgeEnhancement_Factor_GetDefault, IDS), peak_status, (peak_camera_handle, Ptr{UInt32}), hCam, defaultFactor)
end

function peak_IPL_EdgeEnhancement_Factor_GetRange(hCam, minFactor, maxFactor, incFactor)
    ccall((:peak_IPL_EdgeEnhancement_Factor_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{UInt32}, Ptr{UInt32}, Ptr{UInt32}), hCam, minFactor, maxFactor, incFactor)
end

function peak_IPL_Sharpness_Measure(hFrame, roi, sharpnessAlgorithm, calculatedValue)
    ccall((:peak_IPL_Sharpness_Measure, IDS), peak_status, (peak_frame_handle, peak_roi, peak_sharpness_algorithm, Ptr{Cdouble}), hFrame, roi, sharpnessAlgorithm, calculatedValue)
end

function peak_IPL_Sharpness_GetList(sharpnessAlgorithm, pixelFormatList, pixelFormatSize)
    ccall((:peak_IPL_Sharpness_GetList, IDS), peak_status, (peak_sharpness_algorithm, Ptr{peak_pixel_format}, Ptr{Csize_t}), sharpnessAlgorithm, pixelFormatList, pixelFormatSize)
end

function peak_IPL_Rotation_Angle_Set(hCam, rotationAngle)
    ccall((:peak_IPL_Rotation_Angle_Set, IDS), peak_status, (peak_camera_handle, Int32), hCam, rotationAngle)
end

function peak_IPL_Rotation_Angle_Get(hCam, rotationAngle)
    ccall((:peak_IPL_Rotation_Angle_Get, IDS), peak_status, (peak_camera_handle, Ptr{Int32}), hCam, rotationAngle)
end

function peak_IPL_Histogram_ProcessFrame(hFrame, hHistogram)
    ccall((:peak_IPL_Histogram_ProcessFrame, IDS), peak_status, (peak_frame_handle, Ptr{peak_histogram_handle}), hFrame, hHistogram)
end

function peak_IPL_Histogram_Release(hHistogram)
    ccall((:peak_IPL_Histogram_Release, IDS), peak_status, (peak_histogram_handle,), hHistogram)
end

function peak_IPL_Histogram_Channel_GetCount(hHistogram, numChannels)
    ccall((:peak_IPL_Histogram_Channel_GetCount, IDS), peak_status, (peak_histogram_handle, Ptr{Csize_t}), hHistogram, numChannels)
end

function peak_IPL_Histogram_Channel_GetInfo(hHistogram, channel, channelInfo)
    ccall((:peak_IPL_Histogram_Channel_GetInfo, IDS), peak_status, (peak_histogram_handle, Csize_t, Ptr{peak_histogram_channel_info}), hHistogram, channel, channelInfo)
end

function peak_IPL_Histogram_Channel_GetBinArray(hHistogram, channel, binArray, binArraySize)
    ccall((:peak_IPL_Histogram_Channel_GetBinArray, IDS), peak_status, (peak_histogram_handle, Csize_t, Ptr{UInt64}, Ptr{Csize_t}), hHistogram, channel, binArray, binArraySize)
end

function peak_VideoWriter_Open(hVideo, fileName, container, encoder)
    ccall((:peak_VideoWriter_Open, IDS), peak_status, (Ptr{peak_video_handle}, Ptr{Cchar}, peak_video_container, peak_video_encoder), hVideo, fileName, container, encoder)
end

function peak_VideoWriter_Close(hVideo)
    ccall((:peak_VideoWriter_Close, IDS), peak_status, (peak_video_handle,), hVideo)
end

function peak_VideoWriter_AddFrame(hVideo, hFrame)
    ccall((:peak_VideoWriter_AddFrame, IDS), peak_status, (peak_video_handle, peak_frame_handle), hVideo, hFrame)
end

function peak_VideoWriter_Container_GetEncoderList(container, encoderList, encoderCount)
    ccall((:peak_VideoWriter_Container_GetEncoderList, IDS), peak_status, (peak_video_container, Ptr{peak_video_encoder}, Ptr{Csize_t}), container, encoderList, encoderCount)
end

function peak_VideoWriter_Encoder_GetPixelFormatList(encoder, pixelFormatList, pixelFormatCount)
    ccall((:peak_VideoWriter_Encoder_GetPixelFormatList, IDS), peak_status, (peak_video_encoder, Ptr{peak_pixel_format}, Ptr{Csize_t}), encoder, pixelFormatList, pixelFormatCount)
end

function peak_VideoWriter_Encoder_GetContainerList(encoder, containerList, containerCount)
    ccall((:peak_VideoWriter_Encoder_GetContainerList, IDS), peak_status, (peak_video_encoder, Ptr{peak_video_container}, Ptr{Csize_t}), encoder, containerList, containerCount)
end

function peak_VideoWriter_GetInfo(hVideo, videoInfo)
    ccall((:peak_VideoWriter_GetInfo, IDS), peak_status, (peak_video_handle, Ptr{peak_video_info}), hVideo, videoInfo)
end

function peak_VideoWriter_Container_Option_Set(hVideo, containerOption, value, count)
    ccall((:peak_VideoWriter_Container_Option_Set, IDS), peak_status, (peak_video_handle, peak_video_container_option, Ptr{Cvoid}, Csize_t), hVideo, containerOption, value, count)
end

function peak_VideoWriter_Container_Option_Get(hVideo, containerOption, value, count, outCount)
    ccall((:peak_VideoWriter_Container_Option_Get, IDS), peak_status, (peak_video_handle, peak_video_container_option, Ptr{Cvoid}, Csize_t, Ptr{Csize_t}), hVideo, containerOption, value, count, outCount)
end

function peak_VideoWriter_Encoder_Option_Set(hVideo, encoderOption, value, count)
    ccall((:peak_VideoWriter_Encoder_Option_Set, IDS), peak_status, (peak_video_handle, peak_video_encoder_option, Ptr{Cvoid}, Csize_t), hVideo, encoderOption, value, count)
end

function peak_VideoWriter_Encoder_Option_Get(hVideo, encoderOption, value, count, outCount)
    ccall((:peak_VideoWriter_Encoder_Option_Get, IDS), peak_status, (peak_video_handle, peak_video_encoder_option, Ptr{Cvoid}, Csize_t, Ptr{Csize_t}), hVideo, encoderOption, value, count, outCount)
end

function peak_VideoWriter_WaitUntilQueueEmpty(hVideo, timeout_ms)
    ccall((:peak_VideoWriter_WaitUntilQueueEmpty, IDS), peak_status, (peak_video_handle, Int32), hVideo, timeout_ms)
end

function peak_Inference_CNN_Open(path, hInference)
    ccall((:peak_Inference_CNN_Open, IDS), peak_status, (Ptr{Cchar}, Ptr{peak_inference_handle}), path, hInference)
end

function peak_Inference_CNN_Close(hInference)
    ccall((:peak_Inference_CNN_Close, IDS), peak_status, (peak_inference_handle,), hInference)
end

function peak_Inference_CNN_ProcessFrame(hInference, hFrame, hInferenceHandle)
    ccall((:peak_Inference_CNN_ProcessFrame, IDS), peak_status, (peak_inference_handle, peak_frame_handle, Ptr{peak_inference_result_handle}), hInference, hFrame, hInferenceHandle)
end

function peak_Inference_CNN_Info_Get(hInference, info)
    ccall((:peak_Inference_CNN_Info_Get, IDS), peak_status, (peak_inference_handle, Ptr{peak_inference_info}), hInference, info)
end

function peak_Inference_Result_Get(hInferenceHandle, result)
    ccall((:peak_Inference_Result_Get, IDS), peak_status, (peak_inference_result_handle, Ptr{peak_inference_result_data}), hInferenceHandle, result)
end

function peak_Inference_Result_Release(hInferenceHandle)
    ccall((:peak_Inference_Result_Release, IDS), peak_status, (peak_inference_result_handle,), hInferenceHandle)
end

function peak_Inference_Result_Classification_GetList(hInferenceHandle, resultList, resultCount)
    ccall((:peak_Inference_Result_Classification_GetList, IDS), peak_status, (peak_inference_result_handle, Ptr{peak_inference_result_classification}, Ptr{Csize_t}), hInferenceHandle, resultList, resultCount)
end

function peak_Inference_Result_Detection_GetList(hInferenceHandle, resultList, resultCount)
    ccall((:peak_Inference_Result_Detection_GetList, IDS), peak_status, (peak_inference_result_handle, Ptr{peak_inference_result_detection}, Ptr{Csize_t}), hInferenceHandle, resultList, resultCount)
end

function peak_Inference_Statistics_Get(hInference, statistics)
    ccall((:peak_Inference_Statistics_Get, IDS), peak_status, (peak_inference_handle, Ptr{peak_inference_statistics}), hInference, statistics)
end

function peak_Inference_Statistics_Reset(hInference)
    ccall((:peak_Inference_Statistics_Reset, IDS), peak_status, (peak_inference_handle,), hInference)
end

function peak_Inference_ConfidenceThreshold_Get(hInference, threshold)
    ccall((:peak_Inference_ConfidenceThreshold_Get, IDS), peak_status, (peak_inference_handle, Ptr{UInt32}), hInference, threshold)
end

function peak_Inference_ConfidenceThreshold_GetRange(hInference, minThreshold, maxThreshold, incThreshold)
    ccall((:peak_Inference_ConfidenceThreshold_GetRange, IDS), peak_status, (peak_inference_handle, Ptr{UInt32}, Ptr{UInt32}, Ptr{UInt32}), hInference, minThreshold, maxThreshold, incThreshold)
end

function peak_Inference_ConfidenceThreshold_Set(hInference, threshold)
    ccall((:peak_Inference_ConfidenceThreshold_Set, IDS), peak_status, (peak_inference_handle, UInt32), hInference, threshold)
end

function peak_MessageQueue_Create(hMessageQueue)
    ccall((:peak_MessageQueue_Create, IDS), peak_status, (Ptr{peak_message_queue_handle},), hMessageQueue)
end

function peak_MessageQueue_Destroy(hMessageQueue)
    ccall((:peak_MessageQueue_Destroy, IDS), peak_status, (peak_message_queue_handle,), hMessageQueue)
end

function peak_MessageQueue_EnableMessage(hMessageQueue, hCam, messageType)
    ccall((:peak_MessageQueue_EnableMessage, IDS), peak_status, (peak_message_queue_handle, peak_camera_handle, peak_message_type), hMessageQueue, hCam, messageType)
end

function peak_MessageQueue_DisableMessage(hMessageQueue, hCam, messageType)
    ccall((:peak_MessageQueue_DisableMessage, IDS), peak_status, (peak_message_queue_handle, peak_camera_handle, peak_message_type), hMessageQueue, hCam, messageType)
end

function peak_MessageQueue_EnableMessageList(hMessageQueue, hCam, messageTypesArray, messageTypesArraySize)
    ccall((:peak_MessageQueue_EnableMessageList, IDS), peak_status, (peak_message_queue_handle, peak_camera_handle, Ptr{peak_message_type}, Csize_t), hMessageQueue, hCam, messageTypesArray, messageTypesArraySize)
end

function peak_MessageQueue_DisableMessageList(hMessageQueue, hCam, messageTypesArray, messageTypesArraySize)
    ccall((:peak_MessageQueue_DisableMessageList, IDS), peak_status, (peak_message_queue_handle, peak_camera_handle, Ptr{peak_message_type}, Csize_t), hMessageQueue, hCam, messageTypesArray, messageTypesArraySize)
end

function peak_MessageQueue_EnabledMessages_GetList(hMessageQueue, messageTypesArray, messageTypesArraySize)
    ccall((:peak_MessageQueue_EnabledMessages_GetList, IDS), peak_status, (peak_message_queue_handle, Ptr{peak_message_type}, Ptr{Csize_t}), hMessageQueue, messageTypesArray, messageTypesArraySize)
end

function peak_MessageQueue_SetMode(hMessageQueue, queueMode)
    ccall((:peak_MessageQueue_SetMode, IDS), peak_status, (peak_message_queue_handle, peak_message_queue_mode), hMessageQueue, queueMode)
end

function peak_MessageQueue_GetMode(hMessageQueue, queueMode)
    ccall((:peak_MessageQueue_GetMode, IDS), peak_status, (peak_message_queue_handle, Ptr{peak_message_queue_mode}), hMessageQueue, queueMode)
end

function peak_MessageQueue_Start(hMessageQueue)
    ccall((:peak_MessageQueue_Start, IDS), peak_status, (peak_message_queue_handle,), hMessageQueue)
end

function peak_MessageQueue_Stop(hMessageQueue)
    ccall((:peak_MessageQueue_Stop, IDS), peak_status, (peak_message_queue_handle,), hMessageQueue)
end

function peak_MessageQueue_IsStarted(hMessageQueue)
    ccall((:peak_MessageQueue_IsStarted, IDS), peak_bool, (peak_message_queue_handle,), hMessageQueue)
end

function peak_MessageQueue_WaitForMessage(hMessageQueue, timeout_ms, hMessage)
    ccall((:peak_MessageQueue_WaitForMessage, IDS), peak_status, (peak_message_queue_handle, UInt32, Ptr{peak_message_handle}), hMessageQueue, timeout_ms, hMessage)
end

function peak_MessageQueue_Flush(hMessageQueue)
    ccall((:peak_MessageQueue_Flush, IDS), peak_status, (peak_message_queue_handle,), hMessageQueue)
end

function peak_MessageQueue_IsMessageSupported(hMessageQueue, hCam, messageType)
    ccall((:peak_MessageQueue_IsMessageSupported, IDS), peak_bool, (peak_message_queue_handle, peak_camera_handle, peak_message_type), hMessageQueue, hCam, messageType)
end

function peak_MessageQueue_Statistics_Get(hMessageQueue, messageQueueInfo)
    ccall((:peak_MessageQueue_Statistics_Get, IDS), peak_status, (peak_message_queue_handle, Ptr{peak_message_queue_statistics_info}), hMessageQueue, messageQueueInfo)
end

function peak_MessageQueue_Statistics_Reset(hMessageQueue)
    ccall((:peak_MessageQueue_Statistics_Reset, IDS), peak_status, (peak_message_queue_handle,), hMessageQueue)
end

function peak_MessageQueue_MaxQueueSize_Set(hMessageQueue, messageQueueMaxSize)
    ccall((:peak_MessageQueue_MaxQueueSize_Set, IDS), peak_status, (peak_message_queue_handle, Csize_t), hMessageQueue, messageQueueMaxSize)
end

function peak_MessageQueue_MaxQueueSize_Get(hMessageQueue, messageQueueMaxSize)
    ccall((:peak_MessageQueue_MaxQueueSize_Get, IDS), peak_status, (peak_message_queue_handle, Ptr{Csize_t}), hMessageQueue, messageQueueMaxSize)
end

function peak_Message_Release(hMessage)
    ccall((:peak_Message_Release, IDS), peak_status, (peak_message_handle,), hMessage)
end

function peak_Message_GetInfo(hMessage, messageInfo)
    ccall((:peak_Message_GetInfo, IDS), peak_status, (peak_message_handle, Ptr{peak_message_info}), hMessage, messageInfo)
end

function peak_Message_Type_Get(hMessage, messageType)
    ccall((:peak_Message_Type_Get, IDS), peak_status, (peak_message_handle, Ptr{peak_message_type}), hMessage, messageType)
end

function peak_Message_CameraHandle_Get(hMessage, hCam)
    ccall((:peak_Message_CameraHandle_Get, IDS), peak_status, (peak_message_handle, Ptr{peak_camera_handle}), hMessage, hCam)
end

function peak_Message_ID_Get(hMessage, messageID)
    ccall((:peak_Message_ID_Get, IDS), peak_status, (peak_message_handle, Ptr{UInt64}), hMessage, messageID)
end

function peak_Message_HostTimestamp_Get(hMessage, hostTimestamp_ns)
    ccall((:peak_Message_HostTimestamp_Get, IDS), peak_status, (peak_message_handle, Ptr{UInt64}), hMessage, hostTimestamp_ns)
end

function peak_Message_Data_Type_Get(hMessage, messageType)
    ccall((:peak_Message_Data_Type_Get, IDS), peak_status, (peak_message_handle, Ptr{peak_message_data_type}), hMessage, messageType)
end

function peak_Message_Data_RemoteDevice_Get(hMessage, message)
    ccall((:peak_Message_Data_RemoteDevice_Get, IDS), peak_status, (peak_message_handle, Ptr{peak_message_data_remote_device}), hMessage, message)
end

function peak_Message_Data_RemoteDeviceError_Get(hMessage, message)
    ccall((:peak_Message_Data_RemoteDeviceError_Get, IDS), peak_status, (peak_message_handle, Ptr{peak_message_data_remote_device_error}), hMessage, message)
end

function peak_Message_Data_RemoteDeviceDropped_Get(hMessage, message)
    ccall((:peak_Message_Data_RemoteDeviceDropped_Get, IDS), peak_status, (peak_message_handle, Ptr{peak_message_data_remote_device_dropped}), hMessage, message)
end

function peak_Message_Data_RemoteDeviceFrame_Get(hMessage, message)
    ccall((:peak_Message_Data_RemoteDeviceFrame_Get, IDS), peak_status, (peak_message_handle, Ptr{peak_message_data_remote_device_frame}), hMessage, message)
end

function peak_Message_Data_RemoteDeviceTemperature_Get(hMessage, message)
    ccall((:peak_Message_Data_RemoteDeviceTemperature_Get, IDS), peak_status, (peak_message_handle, Ptr{peak_message_data_remote_device_temperature}), hMessage, message)
end

function peak_Message_Data_AutoFocusData_Get(hMessage, message)
    ccall((:peak_Message_Data_AutoFocusData_Get, IDS), peak_status, (peak_message_handle, Ptr{peak_message_data_autofocus}), hMessage, message)
end

function peak_Message_Data_DeviceFound_Get(hMessage, message)
    ccall((:peak_Message_Data_DeviceFound_Get, IDS), peak_status, (peak_message_handle, Ptr{peak_message_data_device_found}), hMessage, message)
end

function peak_Message_Data_DeviceLost_Get(hMessage, message)
    ccall((:peak_Message_Data_DeviceLost_Get, IDS), peak_status, (peak_message_handle, Ptr{peak_message_data_device_lost}), hMessage, message)
end

function peak_Message_Data_DeviceReconnected_Get(hMessage, message)
    ccall((:peak_Message_Data_DeviceReconnected_Get, IDS), peak_status, (peak_message_handle, Ptr{peak_message_data_device_reconnected}), hMessage, message)
end

function peak_Message_Data_DeviceDisconnected_Get(hMessage, message)
    ccall((:peak_Message_Data_DeviceDisconnected_Get, IDS), peak_status, (peak_message_handle, Ptr{peak_message_data_device_disconnected}), hMessage, message)
end

function peak_Message_Data_FirmwareUpdate_Get(hMessage, message)
    ccall((:peak_Message_Data_FirmwareUpdate_Get, IDS), peak_status, (peak_message_handle, Ptr{peak_message_data_firmware_update}), hMessage, message)
end

function peak_I2C_Create(hCam, hI2C)
    ccall((:peak_I2C_Create, IDS), peak_status, (peak_camera_handle, Ptr{peak_i2c_handle}), hCam, hI2C)
end

function peak_I2C_Destroy(hI2C)
    ccall((:peak_I2C_Destroy, IDS), peak_status, (peak_i2c_handle,), hI2C)
end

function peak_I2C_GetAccessStatus(hI2C)
    ccall((:peak_I2C_GetAccessStatus, IDS), peak_access_status, (peak_i2c_handle,), hI2C)
end

function peak_I2C_Mode_GetList(hI2C, modeList, modeListSize)
    ccall((:peak_I2C_Mode_GetList, IDS), peak_status, (peak_i2c_handle, Ptr{peak_i2c_mode}, Ptr{Csize_t}), hI2C, modeList, modeListSize)
end

function peak_I2C_Mode_Set(hI2C, mode)
    ccall((:peak_I2C_Mode_Set, IDS), peak_status, (peak_i2c_handle, peak_i2c_mode), hI2C, mode)
end

function peak_I2C_Mode_Get(hI2C, mode)
    ccall((:peak_I2C_Mode_Get, IDS), peak_status, (peak_i2c_handle, Ptr{peak_i2c_mode}), hI2C, mode)
end

function peak_I2C_DeviceAddress_GetRange(hI2C, minAddress, maxAddress)
    ccall((:peak_I2C_DeviceAddress_GetRange, IDS), peak_status, (peak_i2c_handle, Ptr{UInt32}, Ptr{UInt32}), hI2C, minAddress, maxAddress)
end

function peak_I2C_DeviceAddress_Set(hI2C, address)
    ccall((:peak_I2C_DeviceAddress_Set, IDS), peak_status, (peak_i2c_handle, UInt32), hI2C, address)
end

function peak_I2C_DeviceAddress_Get(hI2C, address)
    ccall((:peak_I2C_DeviceAddress_Get, IDS), peak_status, (peak_i2c_handle, Ptr{UInt32}), hI2C, address)
end

function peak_I2C_RegisterAddress_Length_GetList(hI2C, i2cLengthList, i2cLengthCount)
    ccall((:peak_I2C_RegisterAddress_Length_GetList, IDS), peak_status, (peak_i2c_handle, Ptr{peak_i2c_register_address_length}, Ptr{Csize_t}), hI2C, i2cLengthList, i2cLengthCount)
end

function peak_I2C_RegisterAddress_Length_Set(hI2C, length)
    ccall((:peak_I2C_RegisterAddress_Length_Set, IDS), peak_status, (peak_i2c_handle, peak_i2c_register_address_length), hI2C, length)
end

function peak_I2C_RegisterAddress_Length_Get(hI2C, length)
    ccall((:peak_I2C_RegisterAddress_Length_Get, IDS), peak_status, (peak_i2c_handle, Ptr{peak_i2c_register_address_length}), hI2C, length)
end

function peak_I2C_RegisterAddress_Endianness_Set(hI2C, endianness)
    ccall((:peak_I2C_RegisterAddress_Endianness_Set, IDS), peak_status, (peak_i2c_handle, peak_endianness), hI2C, endianness)
end

function peak_I2C_RegisterAddress_Endianness_Get(hI2C, endianness)
    ccall((:peak_I2C_RegisterAddress_Endianness_Get, IDS), peak_status, (peak_i2c_handle, Ptr{peak_endianness}), hI2C, endianness)
end

function peak_I2C_RegisterAddress_Set(hI2C, address)
    ccall((:peak_I2C_RegisterAddress_Set, IDS), peak_status, (peak_i2c_handle, UInt32), hI2C, address)
end

function peak_I2C_RegisterAddress_Get(hI2C, address)
    ccall((:peak_I2C_RegisterAddress_Get, IDS), peak_status, (peak_i2c_handle, Ptr{UInt32}), hI2C, address)
end

function peak_I2C_AckPolling_Enable(hI2C, enabled)
    ccall((:peak_I2C_AckPolling_Enable, IDS), peak_status, (peak_i2c_handle, peak_bool), hI2C, enabled)
end

function peak_I2C_AckPolling_IsEnabled(hI2C)
    ccall((:peak_I2C_AckPolling_IsEnabled, IDS), peak_bool, (peak_i2c_handle,), hI2C)
end

function peak_I2C_AckPolling_Timeout_GetAccessStatus(hI2C)
    ccall((:peak_I2C_AckPolling_Timeout_GetAccessStatus, IDS), peak_access_status, (peak_i2c_handle,), hI2C)
end

function peak_I2C_AckPolling_Timeout_GetRange(hI2C, minTimeout_ms, maxTimeout_ms, incTimeout_ms)
    ccall((:peak_I2C_AckPolling_Timeout_GetRange, IDS), peak_status, (peak_i2c_handle, Ptr{UInt32}, Ptr{UInt32}, Ptr{UInt32}), hI2C, minTimeout_ms, maxTimeout_ms, incTimeout_ms)
end

function peak_I2C_AckPolling_Timeout_Set(hI2C, timeout_ms)
    ccall((:peak_I2C_AckPolling_Timeout_Set, IDS), peak_status, (peak_i2c_handle, UInt32), hI2C, timeout_ms)
end

function peak_I2C_AckPolling_Timeout_Get(hI2C, timeout_ms)
    ccall((:peak_I2C_AckPolling_Timeout_Get, IDS), peak_status, (peak_i2c_handle, Ptr{UInt32}), hI2C, timeout_ms)
end

function peak_I2C_Data_Write(hI2C, data, dataSize)
    ccall((:peak_I2C_Data_Write, IDS), peak_status, (peak_i2c_handle, Ptr{UInt8}, Csize_t), hI2C, data, dataSize)
end

function peak_I2C_Data_Read(hI2C, maxDataSize, data, dataSize)
    ccall((:peak_I2C_Data_Read, IDS), peak_status, (peak_i2c_handle, Csize_t, Ptr{UInt8}, Ptr{Csize_t}), hI2C, maxDataSize, data, dataSize)
end

function peak_I2C_Data_MaxSize_Get(hI2C, maxDataSize)
    ccall((:peak_I2C_Data_MaxSize_Get, IDS), peak_status, (peak_i2c_handle, Ptr{Csize_t}), hI2C, maxDataSize)
end

function peak_I2C_OperationStatus_Get(hI2C, operationStatus)
    ccall((:peak_I2C_OperationStatus_Get, IDS), peak_status, (peak_i2c_handle, Ptr{peak_i2c_operation_status}), hI2C, operationStatus)
end

function peak_IPL_ImageWriter_Create(hImageWriter)
    ccall((:peak_IPL_ImageWriter_Create, IDS), peak_status, (Ptr{peak_imagewriter_handle},), hImageWriter)
end

function peak_IPL_ImageWriter_Destroy(hImageWriter)
    ccall((:peak_IPL_ImageWriter_Destroy, IDS), peak_status, (peak_imagewriter_handle,), hImageWriter)
end

function peak_IPL_ImageWriter_Save(hImageWriter, hFrame, fileName)
    ccall((:peak_IPL_ImageWriter_Save, IDS), peak_status, (peak_imagewriter_handle, peak_frame_handle, Ptr{Cchar}), hImageWriter, hFrame, fileName)
end

function peak_IPL_ImageWriter_Format_Set(hImageWriter, imageFormat)
    ccall((:peak_IPL_ImageWriter_Format_Set, IDS), peak_status, (peak_imagewriter_handle, peak_imagefile_format), hImageWriter, imageFormat)
end

function peak_IPL_ImageWriter_Format_Get(hImageWriter, imageFormat)
    ccall((:peak_IPL_ImageWriter_Format_Get, IDS), peak_status, (peak_imagewriter_handle, Ptr{peak_imagefile_format}), hImageWriter, imageFormat)
end

function peak_IPL_ImageWriter_Compression_Set(hImageWriter, compression)
    ccall((:peak_IPL_ImageWriter_Compression_Set, IDS), peak_status, (peak_imagewriter_handle, UInt32), hImageWriter, compression)
end

function peak_IPL_ImageWriter_Compression_Get(hImageWriter, compression)
    ccall((:peak_IPL_ImageWriter_Compression_Get, IDS), peak_status, (peak_imagewriter_handle, Ptr{UInt32}), hImageWriter, compression)
end

function peak_IPL_Binning_FactorX_GetList(hCam, binningFactorXList, binningFactorXCount)
    ccall((:peak_IPL_Binning_FactorX_GetList, IDS), peak_status, (peak_camera_handle, Ptr{UInt32}, Ptr{Csize_t}), hCam, binningFactorXList, binningFactorXCount)
end

function peak_IPL_Binning_FactorY_GetList(hCam, binningFactorYList, binningFactorYCount)
    ccall((:peak_IPL_Binning_FactorY_GetList, IDS), peak_status, (peak_camera_handle, Ptr{UInt32}, Ptr{Csize_t}), hCam, binningFactorYList, binningFactorYCount)
end

function peak_IPL_Binning_Set(hCam, binningFactorX, binningFactorY)
    ccall((:peak_IPL_Binning_Set, IDS), peak_status, (peak_camera_handle, UInt32, UInt32), hCam, binningFactorX, binningFactorY)
end

function peak_IPL_Binning_Get(hCam, binningFactorX, binningFactorY)
    ccall((:peak_IPL_Binning_Get, IDS), peak_status, (peak_camera_handle, Ptr{UInt32}, Ptr{UInt32}), hCam, binningFactorX, binningFactorY)
end

function peak_IPL_Decimation_FactorX_GetList(hCam, decimationFactorXList, decimationFactorXCount)
    ccall((:peak_IPL_Decimation_FactorX_GetList, IDS), peak_status, (peak_camera_handle, Ptr{UInt32}, Ptr{Csize_t}), hCam, decimationFactorXList, decimationFactorXCount)
end

function peak_IPL_Decimation_FactorY_GetList(hCam, decimationFactorYList, decimationFactorYCount)
    ccall((:peak_IPL_Decimation_FactorY_GetList, IDS), peak_status, (peak_camera_handle, Ptr{UInt32}, Ptr{Csize_t}), hCam, decimationFactorYList, decimationFactorYCount)
end

function peak_IPL_Decimation_Set(hCam, decimationFactorX, decimationFactorY)
    ccall((:peak_IPL_Decimation_Set, IDS), peak_status, (peak_camera_handle, UInt32, UInt32), hCam, decimationFactorX, decimationFactorY)
end

function peak_IPL_Decimation_Get(hCam, decimationFactorX, decimationFactorY)
    ccall((:peak_IPL_Decimation_Get, IDS), peak_status, (peak_camera_handle, Ptr{UInt32}, Ptr{UInt32}), hCam, decimationFactorX, decimationFactorY)
end

function peak_FirmwareUpdate_CompatibleCameraList_Get(gufFileName, cameraList, cameraCount)
    ccall((:peak_FirmwareUpdate_CompatibleCameraList_Get, IDS), peak_status, (Ptr{Cchar}, Ptr{peak_camera_descriptor}, Ptr{Csize_t}), gufFileName, cameraList, cameraCount)
end

function peak_FirmwareUpdate_Execute(cameraID, gufFileName)
    ccall((:peak_FirmwareUpdate_Execute, IDS), peak_status, (peak_camera_id, Ptr{Cchar}), cameraID, gufFileName)
end

function peak_TestPattern_GetAccessStatus(hCam)
    ccall((:peak_TestPattern_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_TestPattern_Set(hCam, pattern)
    ccall((:peak_TestPattern_Set, IDS), peak_status, (peak_camera_handle, peak_test_pattern), hCam, pattern)
end

function peak_TestPattern_Get(hCam, pattern)
    ccall((:peak_TestPattern_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_test_pattern}), hCam, pattern)
end

function peak_TestPattern_GetList(hCam, testPatternList, testPatternCount)
    ccall((:peak_TestPattern_GetList, IDS), peak_status, (peak_camera_handle, Ptr{peak_test_pattern}, Ptr{Csize_t}), hCam, testPatternList, testPatternCount)
end

function peak_LED_GetAccessStatus(hCam)
    ccall((:peak_LED_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_LED_Target_GetList(hCam, targetList, targetCount)
    ccall((:peak_LED_Target_GetList, IDS), peak_status, (peak_camera_handle, Ptr{peak_led_target}, Ptr{Csize_t}), hCam, targetList, targetCount)
end

function peak_LED_Mode_GetList(hCam, target, modeList, ledModeCount)
    ccall((:peak_LED_Mode_GetList, IDS), peak_status, (peak_camera_handle, peak_led_target, Ptr{peak_led_mode}, Ptr{Csize_t}), hCam, target, modeList, ledModeCount)
end

function peak_LED_Set(hCam, target, mode)
    ccall((:peak_LED_Set, IDS), peak_status, (peak_camera_handle, peak_led_target, peak_led_mode), hCam, target, mode)
end

function peak_LED_Get(hCam, target, mode)
    ccall((:peak_LED_Get, IDS), peak_status, (peak_camera_handle, peak_led_target, Ptr{peak_led_mode}), hCam, target, mode)
end

function peak_BlackLevel_Auto_GetAccessStatus(hCam)
    ccall((:peak_BlackLevel_Auto_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_BlackLevel_Auto_Enable(hCam, enable)
    ccall((:peak_BlackLevel_Auto_Enable, IDS), peak_status, (peak_camera_handle, peak_bool), hCam, enable)
end

function peak_BlackLevel_Auto_IsEnabled(hCam)
    ccall((:peak_BlackLevel_Auto_IsEnabled, IDS), peak_bool, (peak_camera_handle,), hCam)
end

function peak_BlackLevel_Offset_GetAccessStatus(hCam)
    ccall((:peak_BlackLevel_Offset_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_BlackLevel_Offset_Set(hCam, offset)
    ccall((:peak_BlackLevel_Offset_Set, IDS), peak_status, (peak_camera_handle, Cdouble), hCam, offset)
end

function peak_BlackLevel_Offset_Get(hCam, offset)
    ccall((:peak_BlackLevel_Offset_Get, IDS), peak_status, (peak_camera_handle, Ptr{Cdouble}), hCam, offset)
end

function peak_BlackLevel_Offset_GetRange(hCam, min, max, inc)
    ccall((:peak_BlackLevel_Offset_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}), hCam, min, max, inc)
end

function peak_Bandwidth_LinkSpeed_GetAccessStatus(hCam)
    ccall((:peak_Bandwidth_LinkSpeed_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_Bandwidth_LinkSpeed_Get(hCam, linkSpeed_Bps)
    ccall((:peak_Bandwidth_LinkSpeed_Get, IDS), peak_status, (peak_camera_handle, Ptr{Int64}), hCam, linkSpeed_Bps)
end

function peak_Bandwidth_ThroughputLimit_GetAccessStatus(hCam)
    ccall((:peak_Bandwidth_ThroughputLimit_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_Bandwidth_ThroughputLimit_GetRange(hCam, minThroughputLimit_Bps, maxThroughputLimit_Bps, incThroughputLimit_Bps)
    ccall((:peak_Bandwidth_ThroughputLimit_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{Int64}, Ptr{Int64}, Ptr{Int64}), hCam, minThroughputLimit_Bps, maxThroughputLimit_Bps, incThroughputLimit_Bps)
end

function peak_Bandwidth_ThroughputLimit_Set(hCam, throughputLimit_Bps)
    ccall((:peak_Bandwidth_ThroughputLimit_Set, IDS), peak_status, (peak_camera_handle, Int64), hCam, throughputLimit_Bps)
end

function peak_Bandwidth_ThroughputLimit_Get(hCam, throughputLimit_Bps)
    ccall((:peak_Bandwidth_ThroughputLimit_Get, IDS), peak_status, (peak_camera_handle, Ptr{Int64}), hCam, throughputLimit_Bps)
end

function peak_Bandwidth_ThroughputFrameRateLimit_GetAccessStatus(hCam)
    ccall((:peak_Bandwidth_ThroughputFrameRateLimit_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_Bandwidth_ThroughputFrameRateLimit_Get(hCam, throughputFrameRateLimit_fps)
    ccall((:peak_Bandwidth_ThroughputFrameRateLimit_Get, IDS), peak_status, (peak_camera_handle, Ptr{Cdouble}), hCam, throughputFrameRateLimit_fps)
end

function peak_Bandwidth_ThroughputCalculated_GetAccessStatus(hCam)
    ccall((:peak_Bandwidth_ThroughputCalculated_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_Bandwidth_ThroughputCalculated_Get(hCam, throughputCalculated_Bps)
    ccall((:peak_Bandwidth_ThroughputCalculated_Get, IDS), peak_status, (peak_camera_handle, Ptr{Int64}), hCam, throughputCalculated_Bps)
end

function peak_IPO_GetAccessStatus(interfaceTech)
    ccall((:peak_IPO_GetAccessStatus, IDS), peak_access_status, (peak_interface_technology,), interfaceTech)
end

function peak_IPO_IsEnabled(interfaceTech)
    ccall((:peak_IPO_IsEnabled, IDS), peak_bool, (peak_interface_technology,), interfaceTech)
end

function peak_IPO_Enable(interfaceTech, enabled)
    ccall((:peak_IPO_Enable, IDS), peak_status, (peak_interface_technology, peak_bool), interfaceTech, enabled)
end

function peak_IPL_DigitalBlack_GetRange(hCam, minDigitalBlack, maxDigitalBlack)
    ccall((:peak_IPL_DigitalBlack_GetRange, IDS), peak_status, (peak_camera_handle, Ptr{Cdouble}, Ptr{Cdouble}), hCam, minDigitalBlack, maxDigitalBlack)
end

function peak_IPL_DigitalBlack_Set(hCam, digitalBlack)
    ccall((:peak_IPL_DigitalBlack_Set, IDS), peak_status, (peak_camera_handle, Cdouble), hCam, digitalBlack)
end

function peak_IPL_DigitalBlack_Get(hCam, digitalBlack)
    ccall((:peak_IPL_DigitalBlack_Get, IDS), peak_status, (peak_camera_handle, Ptr{Cdouble}), hCam, digitalBlack)
end

function peak_IPL_LUT_Enable(hCam, enabled)
    ccall((:peak_IPL_LUT_Enable, IDS), peak_status, (peak_camera_handle, peak_bool), hCam, enabled)
end

function peak_IPL_LUT_IsEnabled(hCam)
    ccall((:peak_IPL_LUT_IsEnabled, IDS), peak_bool, (peak_camera_handle,), hCam)
end

function peak_IPL_LUT_Preset_Set(hCam, selector, preset)
    ccall((:peak_IPL_LUT_Preset_Set, IDS), peak_status, (peak_camera_handle, peak_lut_selector, peak_lut_preset), hCam, selector, preset)
end

function peak_IPL_LUT_Value_Set(hCam, selector, channel, index, value)
    ccall((:peak_IPL_LUT_Value_Set, IDS), peak_status, (peak_camera_handle, peak_lut_selector, peak_lut_channel, UInt32, UInt32), hCam, selector, channel, index, value)
end

function peak_IPL_LUT_Value_Get(hCam, selector, channel, index, value)
    ccall((:peak_IPL_LUT_Value_Get, IDS), peak_status, (peak_camera_handle, peak_lut_selector, peak_lut_channel, UInt32, Ptr{UInt32}), hCam, selector, channel, index, value)
end

function peak_IPL_LUT_ValueList_Set(hCam, selector, channel, values, size)
    ccall((:peak_IPL_LUT_ValueList_Set, IDS), peak_status, (peak_camera_handle, peak_lut_selector, peak_lut_channel, Ptr{UInt32}, Csize_t), hCam, selector, channel, values, size)
end

function peak_IPL_LUT_ValueList_Get(hCam, selector, channel, values, size)
    ccall((:peak_IPL_LUT_ValueList_Get, IDS), peak_status, (peak_camera_handle, peak_lut_selector, peak_lut_channel, Ptr{UInt32}, Ptr{Csize_t}), hCam, selector, channel, values, size)
end

function peak_Chunks_GetAccessStatus(hCam)
    ccall((:peak_Chunks_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle,), hCam)
end

function peak_Chunks_Enable(hCam, enabled)
    ccall((:peak_Chunks_Enable, IDS), peak_status, (peak_camera_handle, peak_bool), hCam, enabled)
end

function peak_Chunks_IsEnabled(hCam)
    ccall((:peak_Chunks_IsEnabled, IDS), peak_bool, (peak_camera_handle,), hCam)
end

function peak_Chunks_AutoUpdate_Enable(hCam, enabled)
    ccall((:peak_Chunks_AutoUpdate_Enable, IDS), peak_status, (peak_camera_handle, peak_bool), hCam, enabled)
end

function peak_Chunks_AutoUpdate_IsEnabled(hCam)
    ccall((:peak_Chunks_AutoUpdate_IsEnabled, IDS), peak_bool, (peak_camera_handle,), hCam)
end

function peak_Chunks_Update(hCam, hFrame)
    ccall((:peak_Chunks_Update, IDS), peak_status, (peak_camera_handle, peak_frame_handle), hCam, hFrame)
end

function peak_Chunks_Type_GetAccessStatus(hCam, type)
    ccall((:peak_Chunks_Type_GetAccessStatus, IDS), peak_access_status, (peak_camera_handle, peak_chunks_type), hCam, type)
end

function peak_Chunks_Type_Enable(hCam, type, enabled)
    ccall((:peak_Chunks_Type_Enable, IDS), peak_status, (peak_camera_handle, peak_chunks_type, peak_bool), hCam, type, enabled)
end

function peak_Chunks_Type_IsEnabled(hCam, type)
    ccall((:peak_Chunks_Type_IsEnabled, IDS), peak_bool, (peak_camera_handle, peak_chunks_type), hCam, type)
end

function peak_Chunks_Type_Supported_GetList(hCam, chunksTypesSupported, chunksTypesSize)
    ccall((:peak_Chunks_Type_Supported_GetList, IDS), peak_status, (peak_camera_handle, Ptr{peak_chunks_type}, Ptr{Csize_t}), hCam, chunksTypesSupported, chunksTypesSize)
end

function peak_Chunks_FrameInfo_Get(hCam, data)
    ccall((:peak_Chunks_FrameInfo_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_chunks_frame_info}), hCam, data)
end

function peak_Chunks_Exposure_Get(hCam, data)
    ccall((:peak_Chunks_Exposure_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_chunks_exposure}), hCam, data)
end

function peak_Chunks_Gain_Get(hCam, data)
    ccall((:peak_Chunks_Gain_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_chunks_gain}), hCam, data)
end

function peak_Chunks_Sequencer_Get(hCam, data)
    ccall((:peak_Chunks_Sequencer_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_chunks_sequencer}), hCam, data)
end

function peak_Chunks_Timestamp_Get(hCam, data)
    ccall((:peak_Chunks_Timestamp_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_chunks_timestamp}), hCam, data)
end

function peak_Chunks_ExposureTrigger_Get(hCam, data)
    ccall((:peak_Chunks_ExposureTrigger_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_chunks_exposure_trigger}), hCam, data)
end

function peak_Chunks_UsableROI_Get(hCam, data)
    ccall((:peak_Chunks_UsableROI_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_chunks_usable_roi}), hCam, data)
end

function peak_Chunks_LineStatus_Get(hCam, data)
    ccall((:peak_Chunks_LineStatus_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_chunks_line_status}), hCam, data)
end

function peak_Chunks_AutoFeature_Get(hCam, data)
    ccall((:peak_Chunks_AutoFeature_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_chunks_autofeature}), hCam, data)
end

function peak_Chunks_PTPStatus_Get(hCam, data)
    ccall((:peak_Chunks_PTPStatus_Get, IDS), peak_status, (peak_camera_handle, Ptr{peak_chunks_ptp_status}), hCam, data)
end

