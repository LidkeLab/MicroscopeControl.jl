function TLI_BuildDeviceList()
    ccall((:TLI_BuildDeviceList, Thorlabs_Tcube_laser), Cshort, ())
end

# no prototype is found for this function at Thorlabs.MotionControl.TCube.LaserDiode.h:201:32, please use with caution
function TLI_GetDeviceListSize()
    ccall((:TLI_GetDeviceListSize, Thorlabs_Tcube_laser), Cshort, ())
end

function TLI_GetDeviceList(stringsReceiver)
    #ccall((:TLI_GetDeviceList, Thorlabs_Tcube_laser), Cshort, (Ptr{Ptr{SAFEARRAY}},), stringsReceiver)
    ccall((:TLI_GetDeviceList, Thorlabs_Tcube_laser), Cshort, (Ptr{Cchar},), stringsReceiver)
end

function TLI_GetDeviceListByType(stringsReceiver, typeID)
    ccall((:TLI_GetDeviceListByType, Thorlabs_Tcube_laser), Cshort, (Ptr{Cchar}, Cint), stringsReceiver, typeID)
end

function TLI_GetDeviceListByTypes(stringsReceiver, typeIDs, length)
    ccall((:TLI_GetDeviceListByTypes, Thorlabs_Tcube_laser), Cshort, (Ptr{Cchar}, Ptr{Cint}, Cint), stringsReceiver, typeIDs, length)
end

function TLI_GetDeviceListExt(receiveBuffer, sizeOfBuffer)
    ccall((:TLI_GetDeviceListExt, Thorlabs_Tcube_laser), Cshort, (Ptr{Cchar}, DWORD), receiveBuffer, sizeOfBuffer)
end

function TLI_GetDeviceListByTypeExt(receiveBuffer, sizeOfBuffer, typeID)
    ccall((:TLI_GetDeviceListByTypeExt, Thorlabs_Tcube_laser), Cshort, (Ptr{Cchar}, DWORD, Cint), receiveBuffer, sizeOfBuffer, typeID)
end

function TLI_GetDeviceListByTypesExt(receiveBuffer, sizeOfBuffer, typeIDs, length)
    ccall((:TLI_GetDeviceListByTypesExt, Thorlabs_Tcube_laser), Cshort, (Ptr{Cchar}, DWORD, Ptr{Cint}, Cint), receiveBuffer, sizeOfBuffer, typeIDs, length)
end

function TLI_GetDeviceInfo(serialNo, info)
    ccall((:TLI_GetDeviceInfo, Thorlabs_Tcube_laser), Cshort, (Ptr{Cchar}, Ptr{TLI_DeviceInfo}), serialNo, info)
end

# no prototype is found for this function at Thorlabs.MotionControl.TCube.LaserDiode.h:313:31, please use with caution
function TLI_InitializeSimulations()
    ccall((:TLI_InitializeSimulations, Thorlabs_Tcube_laser), Cvoid, ())
end

# no prototype is found for this function at Thorlabs.MotionControl.TCube.LaserDiode.h:317:31, please use with caution
function TLI_UninitializeSimulations()
    ccall((:TLI_UninitializeSimulations, Thorlabs_Tcube_laser), Cvoid, ())
end

function LD_Open(serialNo)
    ccall((:LD_Open, Thorlabs_Tcube_laser), Cshort, (Ptr{Cchar},), serialNo)
end

function LD_Close(serialNo)
    ccall((:LD_Close, Thorlabs_Tcube_laser), Cvoid, (Ptr{Cchar},), serialNo)
end

function LD_CheckConnection(serialNo)
    ccall((:LD_CheckConnection, Thorlabs_Tcube_laser), BOOL, (Ptr{Cchar},), serialNo)
end

function LD_Identify(serialNo)
    ccall((:LD_Identify, Thorlabs_Tcube_laser), Cvoid, (Ptr{Cchar},), serialNo)
end

function LD_GetHardwareInfo(serialNo, modelNo, sizeOfModelNo, type, numChannels, notes, sizeOfNotes, firmwareVersion, hardwareVersion, modificationState)
    ccall((:LD_GetHardwareInfo, Thorlabs_Tcube_laser), Cshort, (Ptr{Cchar}, Ptr{Cchar}, DWORD, Ptr{WORD}, Ptr{WORD}, Ptr{Cchar}, DWORD, Ptr{DWORD}, Ptr{WORD}, Ptr{WORD}), serialNo, modelNo, sizeOfModelNo, type, numChannels, notes, sizeOfNotes, firmwareVersion, hardwareVersion, modificationState)
end

function LD_GetHardwareInfoBlock(serialNo, hardwareInfo)
    ccall((:LD_GetHardwareInfoBlock, Thorlabs_Tcube_laser), Cshort, (Ptr{Cchar}, Ptr{TLI_HardwareInformation}), serialNo, hardwareInfo)
end

function LD_GetFirmwareVersion(serialNo)
    ccall((:LD_GetFirmwareVersion, Thorlabs_Tcube_laser), DWORD, (Ptr{Cchar},), serialNo)
end

function LD_GetSoftwareVersion(serialNo)
    ccall((:LD_GetSoftwareVersion, Thorlabs_Tcube_laser), DWORD, (Ptr{Cchar},), serialNo)
end

function LD_LoadSettings(serialNo)
    ccall((:LD_LoadSettings, Thorlabs_Tcube_laser), BOOL, (Ptr{Cchar},), serialNo)
end

function LD_LoadNamedSettings(serialNo, settingsName)
    ccall((:LD_LoadNamedSettings, Thorlabs_Tcube_laser), BOOL, (Ptr{Cchar}, Ptr{Cchar}), serialNo, settingsName)
end

function LD_PersistSettings(serialNo)
    ccall((:LD_PersistSettings, Thorlabs_Tcube_laser), BOOL, (Ptr{Cchar},), serialNo)
end

function LD_Disable(serialNo)
    ccall((:LD_Disable, Thorlabs_Tcube_laser), Cshort, (Ptr{Cchar},), serialNo)
end

function LD_Enable(serialNo)
    ccall((:LD_Enable, Thorlabs_Tcube_laser), Cshort, (Ptr{Cchar},), serialNo)
end

function LD_ClearMessageQueue(serialNo)
    ccall((:LD_ClearMessageQueue, Thorlabs_Tcube_laser), Cvoid, (Ptr{Cchar},), serialNo)
end

function LD_RegisterMessageCallback(serialNo, functionPointer)
    ccall((:LD_RegisterMessageCallback, Thorlabs_Tcube_laser), Cvoid, (Ptr{Cchar}, Ptr{Cvoid}), serialNo, functionPointer)
end

function LD_MessageQueueSize(serialNo)
    ccall((:LD_MessageQueueSize, Thorlabs_Tcube_laser), Cint, (Ptr{Cchar},), serialNo)
end

function LD_GetNextMessage(serialNo, messageType, messageID, messageData)
    ccall((:LD_GetNextMessage, Thorlabs_Tcube_laser), BOOL, (Ptr{Cchar}, Ptr{WORD}, Ptr{WORD}, Ptr{DWORD}), serialNo, messageType, messageID, messageData)
end

function LD_WaitForMessage(serialNo, messageType, messageID, messageData)
    ccall((:LD_WaitForMessage, Thorlabs_Tcube_laser), BOOL, (Ptr{Cchar}, Ptr{WORD}, Ptr{WORD}, Ptr{DWORD}), serialNo, messageType, messageID, messageData)
end

function LD_SetOpenLoopMode(serialNo)
    ccall((:LD_SetOpenLoopMode, Thorlabs_Tcube_laser), Cshort, (Ptr{Cchar},), serialNo)
end

function LD_SetClosedLoopMode(serialNo)
    ccall((:LD_SetClosedLoopMode, Thorlabs_Tcube_laser), Cshort, (Ptr{Cchar},), serialNo)
end

function LD_EnableMaxCurrentAdjust(serialNo, enableAdjust, enableDiode)
    ccall((:LD_EnableMaxCurrentAdjust, Thorlabs_Tcube_laser), Cshort, (Ptr{Cchar}, BOOL, BOOL), serialNo, enableAdjust, enableDiode)
end

function LD_RequestMaxCurrentDigPot(serialNo)
    ccall((:LD_RequestMaxCurrentDigPot, Thorlabs_Tcube_laser), Cshort, (Ptr{Cchar},), serialNo)
end

function LD_GetMaxCurrentDigPot(serialNo)
    ccall((:LD_GetMaxCurrentDigPot, Thorlabs_Tcube_laser), WORD, (Ptr{Cchar},), serialNo)
end

function LD_SetMaxCurrentDigPot(serialNo, maxCurrent)
    ccall((:LD_SetMaxCurrentDigPot, Thorlabs_Tcube_laser), Cshort, (Ptr{Cchar}, WORD), serialNo, maxCurrent)
end

function LD_FindTIAGain(serialNo)
    ccall((:LD_FindTIAGain, Thorlabs_Tcube_laser), Cshort, (Ptr{Cchar},), serialNo)
end

function LD_EnableTIAGainAdjust(serialNo, enable)
    ccall((:LD_EnableTIAGainAdjust, Thorlabs_Tcube_laser), Cshort, (Ptr{Cchar}, BOOL), serialNo, enable)
end

function LD_DisableOutput(serialNo)
    ccall((:LD_DisableOutput, Thorlabs_Tcube_laser), Cshort, (Ptr{Cchar},), serialNo)
end

function LD_EnableOutput(serialNo)
    ccall((:LD_EnableOutput, Thorlabs_Tcube_laser), Cshort, (Ptr{Cchar},), serialNo)
end

function LD_RequestControlSource(serialNo)
    ccall((:LD_RequestControlSource, Thorlabs_Tcube_laser), Cshort, (Ptr{Cchar},), serialNo)
end

function LD_GetControlSource(serialNo)
    ccall((:LD_GetControlSource, Thorlabs_Tcube_laser), LD_InputSourceFlags, (Ptr{Cchar},), serialNo)
end

function LD_SetControlSource(serialNo, source)
    ccall((:LD_SetControlSource, Thorlabs_Tcube_laser), Cshort, (Ptr{Cchar}, LD_InputSourceFlags), serialNo, source)
end

function LD_GetInterlockState(serialNo)
    ccall((:LD_GetInterlockState, Thorlabs_Tcube_laser), BYTE, (Ptr{Cchar},), serialNo)
end

function LD_RequestDisplay(serialNo)
    ccall((:LD_RequestDisplay, Thorlabs_Tcube_laser), Cshort, (Ptr{Cchar},), serialNo)
end

function LD_GetDisplayUnits(serialNo)
    ccall((:LD_GetDisplayUnits, Thorlabs_Tcube_laser), LD_DisplayUnits, (Ptr{Cchar},), serialNo)
end

function LD_SetDisplayUnits(serialNo, units)
    ccall((:LD_SetDisplayUnits, Thorlabs_Tcube_laser), Cshort, (Ptr{Cchar}, LD_DisplayUnits), serialNo, units)
end

function LD_GetLEDBrightness(serialNo)
    ccall((:LD_GetLEDBrightness, Thorlabs_Tcube_laser), WORD, (Ptr{Cchar},), serialNo)
end

function LD_SetLEDBrightness(serialNo, brightness)
    ccall((:LD_SetLEDBrightness, Thorlabs_Tcube_laser), Cshort, (Ptr{Cchar}, Cshort), serialNo, brightness)
end

function LD_RequestLaserSetPoint(serialNo)
    ccall((:LD_RequestLaserSetPoint, Thorlabs_Tcube_laser), Cshort, (Ptr{Cchar},), serialNo)
end

function LD_GetLaserSetPoint(serialNo)
    ccall((:LD_GetLaserSetPoint, Thorlabs_Tcube_laser), WORD, (Ptr{Cchar},), serialNo)
end

function LD_SetLaserSetPoint(serialNo, laserDiodeCurrent)
    ccall((:LD_SetLaserSetPoint, Thorlabs_Tcube_laser), Cshort, (Ptr{Cchar}, WORD), serialNo, laserDiodeCurrent)
end

function LD_RequestStatus(serialNo)
    ccall((:LD_RequestStatus, Thorlabs_Tcube_laser), Cshort, (Ptr{Cchar},), serialNo)
end

function LD_RequestReadings(serialNo)
    ccall((:LD_RequestReadings, Thorlabs_Tcube_laser), Cshort, (Ptr{Cchar},), serialNo)
end

function LD_RequestStatusBits(serialNo)
    ccall((:LD_RequestStatusBits, Thorlabs_Tcube_laser), Cshort, (Ptr{Cchar},), serialNo)
end

function LD_GetPhotoCurrentReading(serialNo)
    ccall((:LD_GetPhotoCurrentReading, Thorlabs_Tcube_laser), WORD, (Ptr{Cchar},), serialNo)
end

function LD_GetVoltageReading(serialNo)
    ccall((:LD_GetVoltageReading, Thorlabs_Tcube_laser), WORD, (Ptr{Cchar},), serialNo)
end

function LD_GetLaserDiodeCurrentReading(serialNo)
    ccall((:LD_GetLaserDiodeCurrentReading, Thorlabs_Tcube_laser), WORD, (Ptr{Cchar},), serialNo)
end

function LD_RequestLaserDiodeMaxCurrentLimit(serialNo)
    ccall((:LD_RequestLaserDiodeMaxCurrentLimit, Thorlabs_Tcube_laser), Cshort, (Ptr{Cchar},), serialNo)
end

function LD_GetLaserDiodeMaxCurrentLimit(serialNo)
    ccall((:LD_GetLaserDiodeMaxCurrentLimit, Thorlabs_Tcube_laser), WORD, (Ptr{Cchar},), serialNo)
end

function LD_RequestWACalibFactor(serialNo)
    ccall((:LD_RequestWACalibFactor, Thorlabs_Tcube_laser), Cshort, (Ptr{Cchar},), serialNo)
end

function LD_GetWACalibFactor(serialNo)
    ccall((:LD_GetWACalibFactor, Thorlabs_Tcube_laser), Cfloat, (Ptr{Cchar},), serialNo)
end

function LD_SetWACalibFactor(serialNo, calibFactor)
    ccall((:LD_SetWACalibFactor, Thorlabs_Tcube_laser), Cshort, (Ptr{Cchar}, Cfloat), serialNo, calibFactor)
end

function LD_RequestLaserPolarity(serialNo)
    ccall((:LD_RequestLaserPolarity, Thorlabs_Tcube_laser), Cshort, (Ptr{Cchar},), serialNo)
end

function LD_GetLaserPolarity(serialNo)
    ccall((:LD_GetLaserPolarity, Thorlabs_Tcube_laser), LD_POLARITY, (Ptr{Cchar},), serialNo)
end

function LD_SetLaserPolarity(serialNo, polarity)
    ccall((:LD_SetLaserPolarity, Thorlabs_Tcube_laser), Cshort, (Ptr{Cchar}, LD_POLARITY), serialNo, polarity)
end

function LD_GetStatusBits(serialNo)
    ccall((:LD_GetStatusBits, Thorlabs_Tcube_laser), DWORD, (Ptr{Cchar},), serialNo)
end

function LD_StartPolling(serialNo, milliseconds)
    ccall((:LD_StartPolling, Thorlabs_Tcube_laser), BOOL, (Ptr{Cchar}, Cint), serialNo, milliseconds)
end

function LD_PollingDuration(serialNo)
    ccall((:LD_PollingDuration, Thorlabs_Tcube_laser), Clong, (Ptr{Cchar},), serialNo)
end

function LD_StopPolling(serialNo)
    ccall((:LD_StopPolling, Thorlabs_Tcube_laser), Cvoid, (Ptr{Cchar},), serialNo)
end

function LD_TimeSinceLastMsgReceived(serialNo, arg2)
    ccall((:LD_TimeSinceLastMsgReceived, Thorlabs_Tcube_laser), BOOL, (Ptr{Cchar}, __int64), serialNo, arg2)
end

function LD_EnableLastMsgTimer(serialNo, enable, lastMsgTimeout)
    ccall((:LD_EnableLastMsgTimer, Thorlabs_Tcube_laser), Cvoid, (Ptr{Cchar}, BOOL, __int32), serialNo, enable, lastMsgTimeout)
end

function LD_HasLastMsgTimerOverrun(serialNo)
    ccall((:LD_HasLastMsgTimerOverrun, Thorlabs_Tcube_laser), BOOL, (Ptr{Cchar},), serialNo)
end

function LD_RequestSettings(serialNo)
    ccall((:LD_RequestSettings, Thorlabs_Tcube_laser), Cshort, (Ptr{Cchar},), serialNo)
end

