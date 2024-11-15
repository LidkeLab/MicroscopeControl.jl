function okFrontPanel_GetDeviceInfoWithSize(hnd, info, size)
    ccall((:okFrontPanel_GetDeviceInfoWithSize, okFP), ok_ErrorCode, (okFrontPanel_HANDLE, Ptr{okTDeviceInfo}, Cuint), hnd, info, size)
end

function okError_GetMessage(err)
    ccall((:okError_GetMessage, okFP), Ptr{Cchar}, (Ptr{okError},), err)
end

function okError_Free(err)
    ccall((:okError_Free, okFP), Cvoid, (Ptr{okError},), err)
end

# no prototype is found for this function at okFrontPanel.h:622:27, please use with caution
function okFrontPanel_GetAPIVersionMajor()
    ccall((:okFrontPanel_GetAPIVersionMajor, okFP), Cint, ())
end

# no prototype is found for this function at okFrontPanel.h:623:27, please use with caution
function okFrontPanel_GetAPIVersionMinor()
    ccall((:okFrontPanel_GetAPIVersionMinor, okFP), Cint, ())
end

# no prototype is found for this function at okFrontPanel.h:624:27, please use with caution
function okFrontPanel_GetAPIVersionMicro()
    ccall((:okFrontPanel_GetAPIVersionMicro, okFP), Cint, ())
end

# no prototype is found for this function at okFrontPanel.h:626:35, please use with caution
function okFrontPanel_GetAPIVersionString()
    ccall((:okFrontPanel_GetAPIVersionString, okFP), Ptr{Cchar}, ())
end

function okFrontPanel_CheckAPIVersion(major, minor, micro)
    ccall((:okFrontPanel_CheckAPIVersion, okFP), Bool, (Cint, Cint, Cint), major, minor, micro)
end

# no prototype is found for this function at okFrontPanel.h:636:1, please use with caution
function okFrontPanel_TryLoadLib()
    ccall((:okFrontPanel_TryLoadLib, okFP), Bool, ())
end

# no prototype is found for this function at okFrontPanel.h:652:41, please use with caution
function okPLL22393_Construct()
    ccall((:okPLL22393_Construct, okFP), okPLL22393_HANDLE, ())
end

function okPLL22393_Destruct(pll)
    ccall((:okPLL22393_Destruct, okFP), Cvoid, (okPLL22393_HANDLE,), pll)
end

function okPLL22393_SetCrystalLoad(pll, capload)
    ccall((:okPLL22393_SetCrystalLoad, okFP), Bool, (okPLL22393_HANDLE, Cdouble), pll, capload)
end

function okPLL22393_SetReference(pll, freq)
    ccall((:okPLL22393_SetReference, okFP), Cvoid, (okPLL22393_HANDLE, Cdouble), pll, freq)
end

function okPLL22393_GetReference(pll)
    ccall((:okPLL22393_GetReference, okFP), Cdouble, (okPLL22393_HANDLE,), pll)
end

function okPLL22393_SetPLLParameters(pll, n, p, q, enable)
    ccall((:okPLL22393_SetPLLParameters, okFP), Bool, (okPLL22393_HANDLE, Cint, Cint, Cint, Bool), pll, n, p, q, enable)
end

function okPLL22393_SetPLLLF(pll, n, lf)
    ccall((:okPLL22393_SetPLLLF, okFP), Bool, (okPLL22393_HANDLE, Cint, Cint), pll, n, lf)
end

function okPLL22393_SetOutputDivider(pll, n, div)
    ccall((:okPLL22393_SetOutputDivider, okFP), Bool, (okPLL22393_HANDLE, Cint, Cint), pll, n, div)
end

function okPLL22393_SetOutputSource(pll, n, clksrc)
    ccall((:okPLL22393_SetOutputSource, okFP), Bool, (okPLL22393_HANDLE, Cint, ok_ClockSource_22393), pll, n, clksrc)
end

function okPLL22393_SetOutputEnable(pll, n, enable)
    ccall((:okPLL22393_SetOutputEnable, okFP), Cvoid, (okPLL22393_HANDLE, Cint, Bool), pll, n, enable)
end

function okPLL22393_GetPLLP(pll, n)
    ccall((:okPLL22393_GetPLLP, okFP), Cint, (okPLL22393_HANDLE, Cint), pll, n)
end

function okPLL22393_GetPLLQ(pll, n)
    ccall((:okPLL22393_GetPLLQ, okFP), Cint, (okPLL22393_HANDLE, Cint), pll, n)
end

function okPLL22393_GetPLLFrequency(pll, n)
    ccall((:okPLL22393_GetPLLFrequency, okFP), Cdouble, (okPLL22393_HANDLE, Cint), pll, n)
end

function okPLL22393_GetOutputDivider(pll, n)
    ccall((:okPLL22393_GetOutputDivider, okFP), Cint, (okPLL22393_HANDLE, Cint), pll, n)
end

function okPLL22393_GetOutputSource(pll, n)
    ccall((:okPLL22393_GetOutputSource, okFP), ok_ClockSource_22393, (okPLL22393_HANDLE, Cint), pll, n)
end

function okPLL22393_GetOutputFrequency(pll, n)
    ccall((:okPLL22393_GetOutputFrequency, okFP), Cdouble, (okPLL22393_HANDLE, Cint), pll, n)
end

function okPLL22393_IsOutputEnabled(pll, n)
    ccall((:okPLL22393_IsOutputEnabled, okFP), Bool, (okPLL22393_HANDLE, Cint), pll, n)
end

function okPLL22393_IsPLLEnabled(pll, n)
    ccall((:okPLL22393_IsPLLEnabled, okFP), Bool, (okPLL22393_HANDLE, Cint), pll, n)
end

# no prototype is found for this function at okFrontPanel.h:677:41, please use with caution
function okPLL22150_Construct()
    ccall((:okPLL22150_Construct, okFP), okPLL22150_HANDLE, ())
end

function okPLL22150_Destruct(pll)
    ccall((:okPLL22150_Destruct, okFP), Cvoid, (okPLL22150_HANDLE,), pll)
end

function okPLL22150_SetCrystalLoad(pll, capload)
    ccall((:okPLL22150_SetCrystalLoad, okFP), Cvoid, (okPLL22150_HANDLE, Cdouble), pll, capload)
end

function okPLL22150_SetReference(pll, freq, extosc)
    ccall((:okPLL22150_SetReference, okFP), Cvoid, (okPLL22150_HANDLE, Cdouble, Bool), pll, freq, extosc)
end

function okPLL22150_GetReference(pll)
    ccall((:okPLL22150_GetReference, okFP), Cdouble, (okPLL22150_HANDLE,), pll)
end

function okPLL22150_SetVCOParameters(pll, p, q)
    ccall((:okPLL22150_SetVCOParameters, okFP), Bool, (okPLL22150_HANDLE, Cint, Cint), pll, p, q)
end

function okPLL22150_GetVCOP(pll)
    ccall((:okPLL22150_GetVCOP, okFP), Cint, (okPLL22150_HANDLE,), pll)
end

function okPLL22150_GetVCOQ(pll)
    ccall((:okPLL22150_GetVCOQ, okFP), Cint, (okPLL22150_HANDLE,), pll)
end

function okPLL22150_GetVCOFrequency(pll)
    ccall((:okPLL22150_GetVCOFrequency, okFP), Cdouble, (okPLL22150_HANDLE,), pll)
end

function okPLL22150_SetDiv1(pll, divsrc, n)
    ccall((:okPLL22150_SetDiv1, okFP), Cvoid, (okPLL22150_HANDLE, ok_DividerSource, Cint), pll, divsrc, n)
end

function okPLL22150_SetDiv2(pll, divsrc, n)
    ccall((:okPLL22150_SetDiv2, okFP), Cvoid, (okPLL22150_HANDLE, ok_DividerSource, Cint), pll, divsrc, n)
end

function okPLL22150_GetDiv1Source(pll)
    ccall((:okPLL22150_GetDiv1Source, okFP), ok_DividerSource, (okPLL22150_HANDLE,), pll)
end

function okPLL22150_GetDiv2Source(pll)
    ccall((:okPLL22150_GetDiv2Source, okFP), ok_DividerSource, (okPLL22150_HANDLE,), pll)
end

function okPLL22150_GetDiv1Divider(pll)
    ccall((:okPLL22150_GetDiv1Divider, okFP), Cint, (okPLL22150_HANDLE,), pll)
end

function okPLL22150_GetDiv2Divider(pll)
    ccall((:okPLL22150_GetDiv2Divider, okFP), Cint, (okPLL22150_HANDLE,), pll)
end

function okPLL22150_SetOutputSource(pll, output, clksrc)
    ccall((:okPLL22150_SetOutputSource, okFP), Cvoid, (okPLL22150_HANDLE, Cint, ok_ClockSource_22150), pll, output, clksrc)
end

function okPLL22150_SetOutputEnable(pll, output, enable)
    ccall((:okPLL22150_SetOutputEnable, okFP), Cvoid, (okPLL22150_HANDLE, Cint, Bool), pll, output, enable)
end

function okPLL22150_GetOutputSource(pll, output)
    ccall((:okPLL22150_GetOutputSource, okFP), ok_ClockSource_22150, (okPLL22150_HANDLE, Cint), pll, output)
end

function okPLL22150_GetOutputFrequency(pll, output)
    ccall((:okPLL22150_GetOutputFrequency, okFP), Cdouble, (okPLL22150_HANDLE, Cint), pll, output)
end

function okPLL22150_IsOutputEnabled(pll, output)
    ccall((:okPLL22150_IsOutputEnabled, okFP), Bool, (okPLL22150_HANDLE, Cint), pll, output)
end

# no prototype is found for this function at okFrontPanel.h:707:46, please use with caution
function okDeviceSensors_Construct()
    ccall((:okDeviceSensors_Construct, okFP), okDeviceSensors_HANDLE, ())
end

function okDeviceSensors_Destruct(hnd)
    ccall((:okDeviceSensors_Destruct, okFP), Cvoid, (okDeviceSensors_HANDLE,), hnd)
end

function okDeviceSensors_GetSensorCount(hnd)
    ccall((:okDeviceSensors_GetSensorCount, okFP), Cint, (okDeviceSensors_HANDLE,), hnd)
end

function okDeviceSensors_GetSensor(hnd, n)
    ccall((:okDeviceSensors_GetSensor, okFP), okTDeviceSensor, (okDeviceSensors_HANDLE, Cint), hnd, n)
end

# no prototype is found for this function at okFrontPanel.h:715:51, please use with caution
function okDeviceSettingNames_Construct()
    ccall((:okDeviceSettingNames_Construct, okFP), okDeviceSettingNames_HANDLE, ())
end

function okDeviceSettingNames_Destruct(hnd)
    ccall((:okDeviceSettingNames_Destruct, okFP), Cvoid, (okDeviceSettingNames_HANDLE,), hnd)
end

function okDeviceSettingNames_GetCount(hnd)
    ccall((:okDeviceSettingNames_GetCount, okFP), Cint, (okDeviceSettingNames_HANDLE,), hnd)
end

function okDeviceSettingNames_Get(hnd, n)
    ccall((:okDeviceSettingNames_Get, okFP), Ptr{Cchar}, (okDeviceSettingNames_HANDLE, Cint), hnd, n)
end

# no prototype is found for this function at okFrontPanel.h:723:47, please use with caution
function okDeviceSettings_Construct()
    ccall((:okDeviceSettings_Construct, okFP), okDeviceSettings_HANDLE, ())
end

function okDeviceSettings_Destruct(hnd)
    ccall((:okDeviceSettings_Destruct, okFP), Cvoid, (okDeviceSettings_HANDLE,), hnd)
end

function okDeviceSettings_GetString(hnd, key, length, buf)
    ccall((:okDeviceSettings_GetString, okFP), ok_ErrorCode, (okDeviceSettings_HANDLE, Ptr{Cchar}, Cint, Ptr{Cchar}), hnd, key, length, buf)
end

function okDeviceSettings_SetString(hnd, key, buf)
    ccall((:okDeviceSettings_SetString, okFP), ok_ErrorCode, (okDeviceSettings_HANDLE, Ptr{Cchar}, Ptr{Cchar}), hnd, key, buf)
end

function okDeviceSettings_GetInt(hnd, key, value)
    ccall((:okDeviceSettings_GetInt, okFP), ok_ErrorCode, (okDeviceSettings_HANDLE, Ptr{Cchar}, Ptr{UINT32}), hnd, key, value)
end

function okDeviceSettings_SetInt(hnd, key, value)
    ccall((:okDeviceSettings_SetInt, okFP), ok_ErrorCode, (okDeviceSettings_HANDLE, Ptr{Cchar}, UINT32), hnd, key, value)
end

function okDeviceSettings_Delete(hnd, key)
    ccall((:okDeviceSettings_Delete, okFP), ok_ErrorCode, (okDeviceSettings_HANDLE, Ptr{Cchar}), hnd, key)
end

function okDeviceSettings_Save(hnd)
    ccall((:okDeviceSettings_Save, okFP), ok_ErrorCode, (okDeviceSettings_HANDLE,), hnd)
end

function okDeviceSettings_List(hnd, names)
    ccall((:okDeviceSettings_List, okFP), ok_ErrorCode, (okDeviceSettings_HANDLE, okDeviceSettingNames_HANDLE), hnd, names)
end

function okBuffer_Construct(size)
    ccall((:okBuffer_Construct, okFP), okBuffer_HANDLE, (Cuint,), size)
end

function okBuffer_FromData(ptr, size)
    ccall((:okBuffer_FromData, okFP), okBuffer_HANDLE, (Ptr{Cvoid}, Cuint), ptr, size)
end

function okBuffer_Copy(hnd)
    ccall((:okBuffer_Copy, okFP), okBuffer_HANDLE, (okBuffer_HANDLE,), hnd)
end

function okBuffer_Destruct(hnd)
    ccall((:okBuffer_Destruct, okFP), Cvoid, (okBuffer_HANDLE,), hnd)
end

function okBuffer_IsEmpty(hnd)
    ccall((:okBuffer_IsEmpty, okFP), okBool, (okBuffer_HANDLE,), hnd)
end

function okBuffer_GetSize(hnd)
    ccall((:okBuffer_GetSize, okFP), Cuint, (okBuffer_HANDLE,), hnd)
end

function okBuffer_GetData(hnd)
    ccall((:okBuffer_GetData, okFP), Ptr{Cuchar}, (okBuffer_HANDLE,), hnd)
end

function okScriptValue_Copy(h)
    ccall((:okScriptValue_Copy, okFP), okScriptValue_HANDLE, (okScriptValue_HANDLE,), h)
end

function okScriptValue_NewString(s)
    ccall((:okScriptValue_NewString, okFP), okScriptValue_HANDLE, (Ptr{Cchar},), s)
end

function okScriptValue_NewBool(b)
    ccall((:okScriptValue_NewBool, okFP), okScriptValue_HANDLE, (okBool,), b)
end

function okScriptValue_NewInt(n)
    ccall((:okScriptValue_NewInt, okFP), okScriptValue_HANDLE, (Cint,), n)
end

function okScriptValue_NewBuffer(buf)
    ccall((:okScriptValue_NewBuffer, okFP), okScriptValue_HANDLE, (okBuffer_HANDLE,), buf)
end

function okScriptValue_GetAsString(h, ps)
    ccall((:okScriptValue_GetAsString, okFP), okBool, (okScriptValue_HANDLE, Ptr{Ptr{Cchar}}), h, ps)
end

function okScriptValue_GetAsBool(h, pb)
    ccall((:okScriptValue_GetAsBool, okFP), okBool, (okScriptValue_HANDLE, Ptr{okBool}), h, pb)
end

function okScriptValue_GetAsInt(h, pn)
    ccall((:okScriptValue_GetAsInt, okFP), okBool, (okScriptValue_HANDLE, Ptr{Cint}), h, pn)
end

function okScriptValue_GetAsBuffer(h, pbuf)
    ccall((:okScriptValue_GetAsBuffer, okFP), okBool, (okScriptValue_HANDLE, Ptr{okBuffer_HANDLE}), h, pbuf)
end

function okScriptValue_Destruct(h)
    ccall((:okScriptValue_Destruct, okFP), Cvoid, (okScriptValue_HANDLE,), h)
end

# no prototype is found for this function at okFrontPanel.h:770:45, please use with caution
function okScriptValues_Construct()
    ccall((:okScriptValues_Construct, okFP), okScriptValues_HANDLE, ())
end

function okScriptValues_Copy(h)
    ccall((:okScriptValues_Copy, okFP), okScriptValues_HANDLE, (okScriptValues_HANDLE,), h)
end

function okScriptValues_Destruct(hnd)
    ccall((:okScriptValues_Destruct, okFP), Cvoid, (okScriptValues_HANDLE,), hnd)
end

function okScriptValues_Clear(hnd)
    ccall((:okScriptValues_Clear, okFP), Cvoid, (okScriptValues_HANDLE,), hnd)
end

function okScriptValues_Add(hnd, arg)
    ccall((:okScriptValues_Add, okFP), Cvoid, (okScriptValues_HANDLE, okScriptValue_HANDLE), hnd, arg)
end

function okScriptValues_GetCount(hnd)
    ccall((:okScriptValues_GetCount, okFP), Cint, (okScriptValues_HANDLE,), hnd)
end

function okScriptValues_Get(hnd, n)
    ccall((:okScriptValues_Get, okFP), okScriptValue_HANDLE, (okScriptValues_HANDLE, Cint), hnd, n)
end

# no prototype is found for this function at okFrontPanel.h:783:43, please use with caution
function okFrontPanel_Construct()
    ccall((:okFrontPanel_Construct, okFP), okFrontPanel_HANDLE, ())
end

function okFrontPanel_Destruct(hnd)
    ccall((:okFrontPanel_Destruct, okFP), Cvoid, (okFrontPanel_HANDLE,), hnd)
end

function okFrontPanel_GetErrorString(ec, buf, length)
    ccall((:okFrontPanel_GetErrorString, okFP), Cint, (Cint, Ptr{Cchar}, Cint), ec, buf, length)
end

function okFrontPanel_GetLastErrorMessage(hnd)
    ccall((:okFrontPanel_GetLastErrorMessage, okFP), Ptr{Cchar}, (okFrontPanel_HANDLE,), hnd)
end

function okFrontPanel_AddCustomDevice(matchInfo, devInfo)
    ccall((:okFrontPanel_AddCustomDevice, okFP), ok_ErrorCode, (Ptr{okTDeviceMatchInfo}, Ptr{okTDeviceInfo}), matchInfo, devInfo)
end

function okFrontPanel_RemoveCustomDevice(productID)
    ccall((:okFrontPanel_RemoveCustomDevice, okFP), ok_ErrorCode, (Cint,), productID)
end

function okFrontPanel_WriteI2C(hnd, addr, length, data)
    ccall((:okFrontPanel_WriteI2C, okFP), ok_ErrorCode, (okFrontPanel_HANDLE, Cint, Cint, Ptr{Cuchar}), hnd, addr, length, data)
end

function okFrontPanel_ReadI2C(hnd, addr, length, data)
    ccall((:okFrontPanel_ReadI2C, okFP), ok_ErrorCode, (okFrontPanel_HANDLE, Cint, Cint, Ptr{Cuchar}), hnd, addr, length, data)
end

function okFrontPanel_FlashEraseSector(hnd, address)
    ccall((:okFrontPanel_FlashEraseSector, okFP), ok_ErrorCode, (okFrontPanel_HANDLE, UINT32), hnd, address)
end

function okFrontPanel_FlashWrite(hnd, address, length, buf)
    ccall((:okFrontPanel_FlashWrite, okFP), ok_ErrorCode, (okFrontPanel_HANDLE, UINT32, UINT32, Ptr{UINT8}), hnd, address, length, buf)
end

function okFrontPanel_FlashRead(hnd, address, length, buf)
    ccall((:okFrontPanel_FlashRead, okFP), ok_ErrorCode, (okFrontPanel_HANDLE, UINT32, UINT32, Ptr{UINT8}), hnd, address, length, buf)
end

function okFrontPanel_GetFPGAResetProfile(hnd, method, profile)
    ccall((:okFrontPanel_GetFPGAResetProfile, okFP), ok_ErrorCode, (okFrontPanel_HANDLE, ok_FPGAConfigurationMethod, Ptr{okTFPGAResetProfile}), hnd, method, profile)
end

function okFrontPanel_GetFPGAResetProfileWithSize(hnd, method, profile, size)
    ccall((:okFrontPanel_GetFPGAResetProfileWithSize, okFP), ok_ErrorCode, (okFrontPanel_HANDLE, ok_FPGAConfigurationMethod, Ptr{okTFPGAResetProfile}, Cuint), hnd, method, profile, size)
end

function okFrontPanel_SetFPGAResetProfile(hnd, method, profile)
    ccall((:okFrontPanel_SetFPGAResetProfile, okFP), ok_ErrorCode, (okFrontPanel_HANDLE, ok_FPGAConfigurationMethod, Ptr{okTFPGAResetProfile}), hnd, method, profile)
end

function okFrontPanel_SetFPGAResetProfileWithSize(hnd, method, profile, size)
    ccall((:okFrontPanel_SetFPGAResetProfileWithSize, okFP), ok_ErrorCode, (okFrontPanel_HANDLE, ok_FPGAConfigurationMethod, Ptr{okTFPGAResetProfile}, Cuint), hnd, method, profile, size)
end

function okFrontPanel_ReadRegister(hnd, addr, data)
    ccall((:okFrontPanel_ReadRegister, okFP), ok_ErrorCode, (okFrontPanel_HANDLE, UINT32, Ptr{UINT32}), hnd, addr, data)
end

function okFrontPanel_ReadRegisters(hnd, num, regs)
    ccall((:okFrontPanel_ReadRegisters, okFP), ok_ErrorCode, (okFrontPanel_HANDLE, Cuint, Ptr{okTRegisterEntry}), hnd, num, regs)
end

function okFrontPanel_WriteRegister(hnd, addr, data)
    ccall((:okFrontPanel_WriteRegister, okFP), ok_ErrorCode, (okFrontPanel_HANDLE, UINT32, UINT32), hnd, addr, data)
end

function okFrontPanel_WriteRegisters(hnd, num, regs)
    ccall((:okFrontPanel_WriteRegisters, okFP), ok_ErrorCode, (okFrontPanel_HANDLE, Cuint, Ptr{okTRegisterEntry}), hnd, num, regs)
end

function okFrontPanel_GetHostInterfaceWidth(hnd)
    ccall((:okFrontPanel_GetHostInterfaceWidth, okFP), Cint, (okFrontPanel_HANDLE,), hnd)
end

function okFrontPanel_IsHighSpeed(hnd)
    ccall((:okFrontPanel_IsHighSpeed, okFP), Bool, (okFrontPanel_HANDLE,), hnd)
end

function okFrontPanel_GetBoardModel(hnd)
    ccall((:okFrontPanel_GetBoardModel, okFP), ok_BoardModel, (okFrontPanel_HANDLE,), hnd)
end

function okFrontPanel_FindUSBDeviceModel(usbVID, usbPID)
    ccall((:okFrontPanel_FindUSBDeviceModel, okFP), ok_BoardModel, (Cuint, Cuint), usbVID, usbPID)
end

function okFrontPanel_GetBoardModelString(hnd, m, buf)
    ccall((:okFrontPanel_GetBoardModelString, okFP), Cvoid, (okFrontPanel_HANDLE, ok_BoardModel, Ptr{Cchar}), hnd, m, buf)
end

function okFrontPanel_GetDeviceCount(hnd)
    ccall((:okFrontPanel_GetDeviceCount, okFP), Cint, (okFrontPanel_HANDLE,), hnd)
end

function okFrontPanel_GetDeviceListModel(hnd, num)
    ccall((:okFrontPanel_GetDeviceListModel, okFP), ok_BoardModel, (okFrontPanel_HANDLE, Cint), hnd, num)
end

function okFrontPanel_GetDeviceListSerial(hnd, num, buf)
    ccall((:okFrontPanel_GetDeviceListSerial, okFP), Cvoid, (okFrontPanel_HANDLE, Cint, Ptr{Cchar}), hnd, num, buf)
end

function okFrontPanel_OpenBySerial(hnd, serial)
    ccall((:okFrontPanel_OpenBySerial, okFP), ok_ErrorCode, (okFrontPanel_HANDLE, Ptr{Cchar}), hnd, serial)
end

function okFrontPanel_IsOpen(hnd)
    ccall((:okFrontPanel_IsOpen, okFP), Bool, (okFrontPanel_HANDLE,), hnd)
end

function okFrontPanel_IsRemote(hnd)
    ccall((:okFrontPanel_IsRemote, okFP), Bool, (okFrontPanel_HANDLE,), hnd)
end

function okFrontPanel_EnableAsynchronousTransfers(hnd, enable)
    ccall((:okFrontPanel_EnableAsynchronousTransfers, okFP), Cvoid, (okFrontPanel_HANDLE, Bool), hnd, enable)
end

function okFrontPanel_SetBTPipePollingInterval(hnd, interval)
    ccall((:okFrontPanel_SetBTPipePollingInterval, okFP), ok_ErrorCode, (okFrontPanel_HANDLE, Cint), hnd, interval)
end

function okFrontPanel_SetTimeout(hnd, timeout)
    ccall((:okFrontPanel_SetTimeout, okFP), Cvoid, (okFrontPanel_HANDLE, Cint), hnd, timeout)
end

function okFrontPanel_GetDeviceMajorVersion(hnd)
    ccall((:okFrontPanel_GetDeviceMajorVersion, okFP), Cint, (okFrontPanel_HANDLE,), hnd)
end

function okFrontPanel_GetDeviceMinorVersion(hnd)
    ccall((:okFrontPanel_GetDeviceMinorVersion, okFP), Cint, (okFrontPanel_HANDLE,), hnd)
end

function okFrontPanel_ResetFPGA(hnd)
    ccall((:okFrontPanel_ResetFPGA, okFP), ok_ErrorCode, (okFrontPanel_HANDLE,), hnd)
end

function okFrontPanel_Close(hnd)
    ccall((:okFrontPanel_Close, okFP), Cvoid, (okFrontPanel_HANDLE,), hnd)
end

function okFrontPanel_GetSerialNumber(hnd, buf)
    ccall((:okFrontPanel_GetSerialNumber, okFP), Cvoid, (okFrontPanel_HANDLE, Ptr{Cchar}), hnd, buf)
end

function okFrontPanel_GetDeviceSensors(hnd, settings)
    ccall((:okFrontPanel_GetDeviceSensors, okFP), ok_ErrorCode, (okFrontPanel_HANDLE, okDeviceSensors_HANDLE), hnd, settings)
end

function okFrontPanel_GetDeviceSettings(hnd, settings)
    ccall((:okFrontPanel_GetDeviceSettings, okFP), ok_ErrorCode, (okFrontPanel_HANDLE, okDeviceSettings_HANDLE), hnd, settings)
end

function okFrontPanel_GetDeviceID(hnd, buf)
    ccall((:okFrontPanel_GetDeviceID, okFP), Cvoid, (okFrontPanel_HANDLE, Ptr{Cchar}), hnd, buf)
end

function okFrontPanel_SetDeviceID(hnd, strID)
    ccall((:okFrontPanel_SetDeviceID, okFP), Cvoid, (okFrontPanel_HANDLE, Ptr{Cchar}), hnd, strID)
end

function okFrontPanel_ClearFPGAConfiguration(hnd)
    ccall((:okFrontPanel_ClearFPGAConfiguration, okFP), ok_ErrorCode, (okFrontPanel_HANDLE,), hnd)
end

function okFrontPanel_ConfigureFPGA(hnd, strFilename)
    ccall((:okFrontPanel_ConfigureFPGA, okFP), ok_ErrorCode, (okFrontPanel_HANDLE, Ptr{Cchar}), hnd, strFilename)
end

function okFrontPanel_ConfigureFPGAWithReset(hnd, strFilename, reset)
    ccall((:okFrontPanel_ConfigureFPGAWithReset, okFP), ok_ErrorCode, (okFrontPanel_HANDLE, Ptr{Cchar}, Ptr{okTFPGAResetProfile}), hnd, strFilename, reset)
end

function okFrontPanel_ConfigureFPGAFromMemory(hnd, data, length)
    ccall((:okFrontPanel_ConfigureFPGAFromMemory, okFP), ok_ErrorCode, (okFrontPanel_HANDLE, Ptr{Cuchar}, Culong), hnd, data, length)
end

function okFrontPanel_ConfigureFPGAFromMemoryWithProgress(hnd, data, length, callback, arg)
    ccall((:okFrontPanel_ConfigureFPGAFromMemoryWithProgress, okFP), ok_ErrorCode, (okFrontPanel_HANDLE, Ptr{Cuchar}, Culong, okTProgressCallback, Ptr{Cvoid}), hnd, data, length, callback, arg)
end

function okFrontPanel_ConfigureFPGAFromMemoryWithReset(hnd, data, length, reset)
    ccall((:okFrontPanel_ConfigureFPGAFromMemoryWithReset, okFP), ok_ErrorCode, (okFrontPanel_HANDLE, Ptr{Cuchar}, Culong, Ptr{okTFPGAResetProfile}), hnd, data, length, reset)
end

function okFrontPanel_ConfigureFPGAFromFlash(hnd, configIndex)
    ccall((:okFrontPanel_ConfigureFPGAFromFlash, okFP), ok_ErrorCode, (okFrontPanel_HANDLE, Culong), hnd, configIndex)
end

function okFrontPanel_GetPLL22150Configuration(hnd, pll)
    ccall((:okFrontPanel_GetPLL22150Configuration, okFP), ok_ErrorCode, (okFrontPanel_HANDLE, okPLL22150_HANDLE), hnd, pll)
end

function okFrontPanel_SetPLL22150Configuration(hnd, pll)
    ccall((:okFrontPanel_SetPLL22150Configuration, okFP), ok_ErrorCode, (okFrontPanel_HANDLE, okPLL22150_HANDLE), hnd, pll)
end

function okFrontPanel_GetEepromPLL22150Configuration(hnd, pll)
    ccall((:okFrontPanel_GetEepromPLL22150Configuration, okFP), ok_ErrorCode, (okFrontPanel_HANDLE, okPLL22150_HANDLE), hnd, pll)
end

function okFrontPanel_SetEepromPLL22150Configuration(hnd, pll)
    ccall((:okFrontPanel_SetEepromPLL22150Configuration, okFP), ok_ErrorCode, (okFrontPanel_HANDLE, okPLL22150_HANDLE), hnd, pll)
end

function okFrontPanel_GetPLL22393Configuration(hnd, pll)
    ccall((:okFrontPanel_GetPLL22393Configuration, okFP), ok_ErrorCode, (okFrontPanel_HANDLE, okPLL22393_HANDLE), hnd, pll)
end

function okFrontPanel_SetPLL22393Configuration(hnd, pll)
    ccall((:okFrontPanel_SetPLL22393Configuration, okFP), ok_ErrorCode, (okFrontPanel_HANDLE, okPLL22393_HANDLE), hnd, pll)
end

function okFrontPanel_GetEepromPLL22393Configuration(hnd, pll)
    ccall((:okFrontPanel_GetEepromPLL22393Configuration, okFP), ok_ErrorCode, (okFrontPanel_HANDLE, okPLL22393_HANDLE), hnd, pll)
end

function okFrontPanel_SetEepromPLL22393Configuration(hnd, pll)
    ccall((:okFrontPanel_SetEepromPLL22393Configuration, okFP), ok_ErrorCode, (okFrontPanel_HANDLE, okPLL22393_HANDLE), hnd, pll)
end

function okFrontPanel_LoadDefaultPLLConfiguration(hnd)
    ccall((:okFrontPanel_LoadDefaultPLLConfiguration, okFP), ok_ErrorCode, (okFrontPanel_HANDLE,), hnd)
end

function okFrontPanel_IsFrontPanelEnabled(hnd)
    ccall((:okFrontPanel_IsFrontPanelEnabled, okFP), Bool, (okFrontPanel_HANDLE,), hnd)
end

function okFrontPanel_IsFrontPanel3Supported(hnd)
    ccall((:okFrontPanel_IsFrontPanel3Supported, okFP), Bool, (okFrontPanel_HANDLE,), hnd)
end

function okFrontPanel_UpdateWireIns(hnd)
    ccall((:okFrontPanel_UpdateWireIns, okFP), ok_ErrorCode, (okFrontPanel_HANDLE,), hnd)
end

function okFrontPanel_GetWireInValue(hnd, epAddr, val)
    ccall((:okFrontPanel_GetWireInValue, okFP), ok_ErrorCode, (okFrontPanel_HANDLE, Cint, Ptr{UINT32}), hnd, epAddr, val)
end

function okFrontPanel_SetWireInValue(hnd, ep, val, mask)
    ccall((:okFrontPanel_SetWireInValue, okFP), ok_ErrorCode, (okFrontPanel_HANDLE, Cint, Culong, Culong), hnd, ep, val, mask)
end

function okFrontPanel_UpdateWireOuts(hnd)
    ccall((:okFrontPanel_UpdateWireOuts, okFP), ok_ErrorCode, (okFrontPanel_HANDLE,), hnd)
end

function okFrontPanel_GetWireOutValue(hnd, epAddr)
    ccall((:okFrontPanel_GetWireOutValue, okFP), Culong, (okFrontPanel_HANDLE, Cint), hnd, epAddr)
end

function okFrontPanel_ActivateTriggerIn(hnd, epAddr, bit)
    ccall((:okFrontPanel_ActivateTriggerIn, okFP), ok_ErrorCode, (okFrontPanel_HANDLE, Cint, Cint), hnd, epAddr, bit)
end

function okFrontPanel_UpdateTriggerOuts(hnd)
    ccall((:okFrontPanel_UpdateTriggerOuts, okFP), ok_ErrorCode, (okFrontPanel_HANDLE,), hnd)
end

function okFrontPanel_IsTriggered(hnd, epAddr, mask)
    ccall((:okFrontPanel_IsTriggered, okFP), Bool, (okFrontPanel_HANDLE, Cint, Culong), hnd, epAddr, mask)
end

function okFrontPanel_GetTriggerOutVector(hnd, epAddr)
    ccall((:okFrontPanel_GetTriggerOutVector, okFP), UINT32, (okFrontPanel_HANDLE, Cint), hnd, epAddr)
end

function okFrontPanel_GetLastTransferLength(hnd)
    ccall((:okFrontPanel_GetLastTransferLength, okFP), Clong, (okFrontPanel_HANDLE,), hnd)
end

function okFrontPanel_WriteToPipeIn(hnd, epAddr, length, data)
    ccall((:okFrontPanel_WriteToPipeIn, okFP), Clong, (okFrontPanel_HANDLE, Cint, Clong, Ptr{Cuchar}), hnd, epAddr, length, data)
end

function okFrontPanel_ReadFromPipeOut(hnd, epAddr, length, data)
    ccall((:okFrontPanel_ReadFromPipeOut, okFP), Clong, (okFrontPanel_HANDLE, Cint, Clong, Ptr{Cuchar}), hnd, epAddr, length, data)
end

function okFrontPanel_WriteToBlockPipeIn(hnd, epAddr, blockSize, length, data)
    ccall((:okFrontPanel_WriteToBlockPipeIn, okFP), Clong, (okFrontPanel_HANDLE, Cint, Cint, Clong, Ptr{Cuchar}), hnd, epAddr, blockSize, length, data)
end

function okFrontPanel_ReadFromBlockPipeOut(hnd, epAddr, blockSize, length, data)
    ccall((:okFrontPanel_ReadFromBlockPipeOut, okFP), Clong, (okFrontPanel_HANDLE, Cint, Cint, Clong, Ptr{Cuchar}), hnd, epAddr, blockSize, length, data)
end

function okScriptEngine_ConstructLua(fp)
    ccall((:okScriptEngine_ConstructLua, okFP), okScriptEngine_HANDLE, (okFrontPanel_HANDLE,), fp)
end

function okScriptEngine_Destruct(hnd)
    ccall((:okScriptEngine_Destruct, okFP), Cvoid, (okScriptEngine_HANDLE,), hnd)
end

function okScriptEngine_LoadScript(hnd, name, code, err)
    ccall((:okScriptEngine_LoadScript, okFP), Bool, (okScriptEngine_HANDLE, Ptr{Cchar}, Ptr{Cchar}, Ptr{Ptr{okError}}), hnd, name, code, err)
end

function okScriptEngine_LoadFile(hnd, path, err)
    ccall((:okScriptEngine_LoadFile, okFP), Bool, (okScriptEngine_HANDLE, Ptr{Cchar}, Ptr{Ptr{okError}}), hnd, path, err)
end

function okScriptEngine_PrependToScriptPath(hnd, dir)
    ccall((:okScriptEngine_PrependToScriptPath, okFP), Cvoid, (okScriptEngine_HANDLE, Ptr{Cchar}), hnd, dir)
end

function okScriptEngine_RunScriptFunction(hnd, name, retval, args, err)
    ccall((:okScriptEngine_RunScriptFunction, okFP), Bool, (okScriptEngine_HANDLE, Ptr{Cchar}, Ptr{okScriptValues_HANDLE}, okScriptValues_HANDLE, Ptr{Ptr{okError}}), hnd, name, retval, args, err)
end

function okScriptEngine_RunScriptFunctionAsync(hnd, callback, data, name, args, err)
    ccall((:okScriptEngine_RunScriptFunctionAsync, okFP), Bool, (okScriptEngine_HANDLE, okScriptEngineAsyncCallback, Ptr{Cvoid}, Ptr{Cchar}, okScriptValues_HANDLE, Ptr{Ptr{okError}}), hnd, callback, data, name, args, err)
end

function okFrontPanelManager_Construct(self, realm)
    ccall((:okFrontPanelManager_Construct, okFP), okCFrontPanelManager_HANDLE, (okFrontPanelManager_HANDLE, Ptr{Cchar}), self, realm)
end

function okFrontPanelManager_ConstructWithCallbacks(self, realm, onAdded, onRemoved)
    ccall((:okFrontPanelManager_ConstructWithCallbacks, okFP), okCFrontPanelManager_HANDLE, (okFrontPanelManager_HANDLE, Ptr{Cchar}, okFrontPanelManager_OnDeviceCallback_t, okFrontPanelManager_OnDeviceCallback_t), self, realm, onAdded, onRemoved)
end

function okFrontPanelManager_Destruct(hnd)
    ccall((:okFrontPanelManager_Destruct, okFP), Cvoid, (okCFrontPanelManager_HANDLE,), hnd)
end

function okFrontPanelManager_StartMonitoring(hnd)
    ccall((:okFrontPanelManager_StartMonitoring, okFP), ok_ErrorCode, (okCFrontPanelManager_HANDLE,), hnd)
end

function okFrontPanelManager_StartMonitoringWithCBInfo(hnd, cbInfo)
    ccall((:okFrontPanelManager_StartMonitoringWithCBInfo, okFP), ok_ErrorCode, (okCFrontPanelManager_HANDLE, Ptr{okTCallbackInfo}), hnd, cbInfo)
end

function okFrontPanelManager_StopMonitoring(hnd)
    ccall((:okFrontPanelManager_StopMonitoring, okFP), ok_ErrorCode, (okCFrontPanelManager_HANDLE,), hnd)
end

function okFrontPanelManager_EnterMonitorLoop(hnd, cbInfo)
    ccall((:okFrontPanelManager_EnterMonitorLoop, okFP), Cint, (okCFrontPanelManager_HANDLE, Ptr{okTCallbackInfo}), hnd, cbInfo)
end

function okFrontPanelManager_EnterMonitorLoopWithTimeout(hnd, cbInfo, millisecondsTimeout)
    ccall((:okFrontPanelManager_EnterMonitorLoopWithTimeout, okFP), Cint, (okCFrontPanelManager_HANDLE, Ptr{okTCallbackInfo}, Cint), hnd, cbInfo, millisecondsTimeout)
end

function okFrontPanelManager_ExitMonitorLoop(hnd, exitCode)
    ccall((:okFrontPanelManager_ExitMonitorLoop, okFP), Cvoid, (okCFrontPanelManager_HANDLE, Cint), hnd, exitCode)
end

function okFrontPanelManager_Open(hnd, serial)
    ccall((:okFrontPanelManager_Open, okFP), okFrontPanel_HANDLE, (okCFrontPanelManager_HANDLE, Ptr{Cchar}), hnd, serial)
end

function okFrontPanelManager_EmulateTestDeviceConnection(serial, connect)
    ccall((:okFrontPanelManager_EmulateTestDeviceConnection, okFP), ok_ErrorCode, (Ptr{Cchar}, Bool), serial, connect)
end

function okFrontPanelDevices_Construct(realm, err)
    ccall((:okFrontPanelDevices_Construct, okFP), okCFrontPanelDevices_HANDLE, (Ptr{Cchar}, Ptr{Ptr{okError}}), realm, err)
end

function okFrontPanelDevices_Destruct(hnd)
    ccall((:okFrontPanelDevices_Destruct, okFP), Cvoid, (okCFrontPanelDevices_HANDLE,), hnd)
end

function okFrontPanelDevices_GetCount(hnd)
    ccall((:okFrontPanelDevices_GetCount, okFP), Cint, (okCFrontPanelDevices_HANDLE,), hnd)
end

function okFrontPanelDevices_GetSerial(hnd, num, buf)
    ccall((:okFrontPanelDevices_GetSerial, okFP), Cvoid, (okCFrontPanelDevices_HANDLE, Cint, Ptr{Cchar}), hnd, num, buf)
end

function okFrontPanelDevices_Open(hnd, serial)
    ccall((:okFrontPanelDevices_Open, okFP), okFrontPanel_HANDLE, (okCFrontPanelDevices_HANDLE, Ptr{Cchar}), hnd, serial)
end

