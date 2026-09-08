function SA_CTL_GetFullVersionString()
    ccall((:SA_CTL_GetFullVersionString, SmarAct), Ptr{Cchar}, ())
end

function SA_CTL_GetResultInfo(result)
    ccall((:SA_CTL_GetResultInfo, SmarAct), Ptr{Cchar}, (SA_CTL_Result_t,), result)
end

function SA_CTL_GetEventInfo(event)
    ccall((:SA_CTL_GetEventInfo, SmarAct), Ptr{Cchar}, (Ptr{SA_CTL_Event_t},), event)
end

function SA_CTL_Open(dHandle, locator, config)
    ccall((:SA_CTL_Open, SmarAct), SA_CTL_Result_t, (Ptr{SA_CTL_DeviceHandle_t}, Ptr{Cchar}, Ptr{Cchar}), dHandle, locator, config)
end

function SA_CTL_Close(dHandle)
    ccall((:SA_CTL_Close, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t,), dHandle)
end

function SA_CTL_Cancel(dHandle)
    ccall((:SA_CTL_Cancel, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t,), dHandle)
end

function SA_CTL_FindDevices(options, deviceList, deviceListLen)
    ccall((:SA_CTL_FindDevices, SmarAct), SA_CTL_Result_t, (Ptr{Cchar}, Ptr{Cchar}, Ptr{Csize_t}), options, deviceList, deviceListLen)
end

function SA_CTL_GetProperty_i32(dHandle, idx, pkey, value, ioArraySize)
    ccall((:SA_CTL_GetProperty_i32, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t, Int8, SA_CTL_PropertyKey_t, Ptr{Int32}, Ptr{Csize_t}), dHandle, idx, pkey, value, ioArraySize)
end

function SA_CTL_GetPropertyBuffer_i32(dHandle, idx, pkey, value, ioBufferSize)
    ccall((:SA_CTL_GetPropertyBuffer_i32, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t, Int8, SA_CTL_PropertyKey_t, Ptr{Int32}, Ptr{Csize_t}), dHandle, idx, pkey, value, ioBufferSize)
end

function SA_CTL_SetProperty_i32(dHandle, idx, pkey, value)
    ccall((:SA_CTL_SetProperty_i32, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t, Int8, SA_CTL_PropertyKey_t, Int32), dHandle, idx, pkey, value)
end

function SA_CTL_SetPropertyArray_i32(dHandle, idx, pkey, values, arraySize)
    ccall((:SA_CTL_SetPropertyArray_i32, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t, Int8, SA_CTL_PropertyKey_t, Ptr{Int32}, Csize_t), dHandle, idx, pkey, values, arraySize)
end

function SA_CTL_SetPropertyBuffer_i32(dHandle, idx, pkey, values, bufferSize)
    ccall((:SA_CTL_SetPropertyBuffer_i32, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t, Int8, SA_CTL_PropertyKey_t, Ptr{Int32}, Csize_t), dHandle, idx, pkey, values, bufferSize)
end

function SA_CTL_GetProperty_i64(dHandle, idx, pkey, value, ioArraySize)
    ccall((:SA_CTL_GetProperty_i64, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t, Int8, SA_CTL_PropertyKey_t, Ptr{Int64}, Ptr{Csize_t}), dHandle, idx, pkey, value, ioArraySize)
end

function SA_CTL_GetPropertyBuffer_i64(dHandle, idx, pkey, value, ioBufferSize)
    ccall((:SA_CTL_GetPropertyBuffer_i64, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t, Int8, SA_CTL_PropertyKey_t, Ptr{Int64}, Ptr{Csize_t}), dHandle, idx, pkey, value, ioBufferSize)
end

function SA_CTL_SetProperty_i64(dHandle, idx, pkey, value)
    ccall((:SA_CTL_SetProperty_i64, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t, Int8, SA_CTL_PropertyKey_t, Int64), dHandle, idx, pkey, value)
end

function SA_CTL_SetPropertyArray_i64(dHandle, idx, pkey, values, arraySize)
    ccall((:SA_CTL_SetPropertyArray_i64, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t, Int8, SA_CTL_PropertyKey_t, Ptr{Int64}, Csize_t), dHandle, idx, pkey, values, arraySize)
end

function SA_CTL_SetPropertyBuffer_i64(dHandle, idx, pkey, values, bufferSize)
    ccall((:SA_CTL_SetPropertyBuffer_i64, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t, Int8, SA_CTL_PropertyKey_t, Ptr{Int64}, Csize_t), dHandle, idx, pkey, values, bufferSize)
end

function SA_CTL_GetProperty_s(dHandle, idx, pkey, value, ioArraySize)
    ccall((:SA_CTL_GetProperty_s, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t, Int8, SA_CTL_PropertyKey_t, Ptr{Cchar}, Ptr{Csize_t}), dHandle, idx, pkey, value, ioArraySize)
end

function SA_CTL_SetProperty_s(dHandle, idx, pkey, value)
    ccall((:SA_CTL_SetProperty_s, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t, Int8, SA_CTL_PropertyKey_t, Ptr{Cchar}), dHandle, idx, pkey, value)
end

function SA_CTL_RequestReadProperty(dHandle, idx, pkey, rID, tHandle)
    ccall((:SA_CTL_RequestReadProperty, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t, Int8, SA_CTL_PropertyKey_t, Ptr{SA_CTL_RequestID_t}, SA_CTL_TransmitHandle_t), dHandle, idx, pkey, rID, tHandle)
end

function SA_CTL_ReadProperty_i32(dHandle, rID, value, ioArraySize)
    ccall((:SA_CTL_ReadProperty_i32, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t, SA_CTL_RequestID_t, Ptr{Int32}, Ptr{Csize_t}), dHandle, rID, value, ioArraySize)
end

function SA_CTL_ReadProperty_i64(dHandle, rID, value, ioArraySize)
    ccall((:SA_CTL_ReadProperty_i64, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t, SA_CTL_RequestID_t, Ptr{Int64}, Ptr{Csize_t}), dHandle, rID, value, ioArraySize)
end

function SA_CTL_ReadProperty_s(dHandle, rID, value, ioArraySize)
    ccall((:SA_CTL_ReadProperty_s, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t, SA_CTL_RequestID_t, Ptr{Cchar}, Ptr{Csize_t}), dHandle, rID, value, ioArraySize)
end

function SA_CTL_RequestWriteProperty_i32(dHandle, idx, pkey, value, rID, tHandle)
    ccall((:SA_CTL_RequestWriteProperty_i32, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t, Int8, SA_CTL_PropertyKey_t, Int32, Ptr{SA_CTL_RequestID_t}, SA_CTL_TransmitHandle_t), dHandle, idx, pkey, value, rID, tHandle)
end

function SA_CTL_RequestWriteProperty_i64(dHandle, idx, pkey, value, rID, tHandle)
    ccall((:SA_CTL_RequestWriteProperty_i64, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t, Int8, SA_CTL_PropertyKey_t, Int64, Ptr{SA_CTL_RequestID_t}, SA_CTL_TransmitHandle_t), dHandle, idx, pkey, value, rID, tHandle)
end

function SA_CTL_RequestWriteProperty_s(dHandle, idx, pkey, value, rID, tHandle)
    ccall((:SA_CTL_RequestWriteProperty_s, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t, Int8, SA_CTL_PropertyKey_t, Ptr{Cchar}, Ptr{SA_CTL_RequestID_t}, SA_CTL_TransmitHandle_t), dHandle, idx, pkey, value, rID, tHandle)
end

function SA_CTL_RequestWritePropertyArray_i32(dHandle, idx, pkey, values, arraySize, rID, tHandle)
    ccall((:SA_CTL_RequestWritePropertyArray_i32, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t, Int8, SA_CTL_PropertyKey_t, Ptr{Int32}, Csize_t, Ptr{SA_CTL_RequestID_t}, SA_CTL_TransmitHandle_t), dHandle, idx, pkey, values, arraySize, rID, tHandle)
end

function SA_CTL_RequestWritePropertyArray_i64(dHandle, idx, pkey, values, arraySize, rID, tHandle)
    ccall((:SA_CTL_RequestWritePropertyArray_i64, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t, Int8, SA_CTL_PropertyKey_t, Ptr{Int64}, Csize_t, Ptr{SA_CTL_RequestID_t}, SA_CTL_TransmitHandle_t), dHandle, idx, pkey, values, arraySize, rID, tHandle)
end

function SA_CTL_WaitForWrite(dHandle, rID)
    ccall((:SA_CTL_WaitForWrite, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t, SA_CTL_RequestID_t), dHandle, rID)
end

function SA_CTL_CancelRequest(dHandle, rID)
    ccall((:SA_CTL_CancelRequest, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t, SA_CTL_RequestID_t), dHandle, rID)
end

function SA_CTL_CreateOutputBuffer(dHandle, tHandle)
    ccall((:SA_CTL_CreateOutputBuffer, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t, Ptr{SA_CTL_TransmitHandle_t}), dHandle, tHandle)
end

function SA_CTL_FlushOutputBuffer(dHandle, tHandle)
    ccall((:SA_CTL_FlushOutputBuffer, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t, SA_CTL_TransmitHandle_t), dHandle, tHandle)
end

function SA_CTL_CancelOutputBuffer(dHandle, tHandle)
    ccall((:SA_CTL_CancelOutputBuffer, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t, SA_CTL_TransmitHandle_t), dHandle, tHandle)
end

function SA_CTL_OpenCommandGroup(dHandle, tHandle, triggerMode)
    ccall((:SA_CTL_OpenCommandGroup, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t, Ptr{SA_CTL_TransmitHandle_t}, UInt32), dHandle, tHandle, triggerMode)
end

function SA_CTL_CloseCommandGroup(dHandle, tHandle)
    ccall((:SA_CTL_CloseCommandGroup, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t, SA_CTL_TransmitHandle_t), dHandle, tHandle)
end

function SA_CTL_CancelCommandGroup(dHandle, tHandle)
    ccall((:SA_CTL_CancelCommandGroup, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t, SA_CTL_TransmitHandle_t), dHandle, tHandle)
end

function SA_CTL_WaitForEvent(dHandle, event, timeout)
    ccall((:SA_CTL_WaitForEvent, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t, Ptr{SA_CTL_Event_t}, UInt32), dHandle, event, timeout)
end

function SA_CTL_Calibrate(dHandle, idx, tHandle)
    ccall((:SA_CTL_Calibrate, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t, Int8, SA_CTL_TransmitHandle_t), dHandle, idx, tHandle)
end

function SA_CTL_Reference(dHandle, idx, tHandle)
    ccall((:SA_CTL_Reference, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t, Int8, SA_CTL_TransmitHandle_t), dHandle, idx, tHandle)
end

function SA_CTL_Move(dHandle, idx, moveValue, tHandle)
    ccall((:SA_CTL_Move, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t, Int8, Int64, SA_CTL_TransmitHandle_t), dHandle, idx, moveValue, tHandle)
end

function SA_CTL_Stop(dHandle, idx, tHandle)
    ccall((:SA_CTL_Stop, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t, Int8, SA_CTL_TransmitHandle_t), dHandle, idx, tHandle)
end

function SA_CTL_StopExt(dHandle, idx, stopOptions, tHandle)
    ccall((:SA_CTL_StopExt, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t, Int8, UInt32, SA_CTL_TransmitHandle_t), dHandle, idx, stopOptions, tHandle)
end

function SA_CTL_OpenStream(dHandle, sHandle, triggerMode)
    ccall((:SA_CTL_OpenStream, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t, Ptr{SA_CTL_StreamHandle_t}, UInt32), dHandle, sHandle, triggerMode)
end

function SA_CTL_StreamFrame(dHandle, sHandle, frameData, frameSize)
    ccall((:SA_CTL_StreamFrame, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t, SA_CTL_StreamHandle_t, Ptr{UInt8}, UInt32), dHandle, sHandle, frameData, frameSize)
end

function SA_CTL_CloseStream(dHandle, sHandle)
    ccall((:SA_CTL_CloseStream, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t, SA_CTL_StreamHandle_t), dHandle, sHandle)
end

function SA_CTL_AbortStream(dHandle, sHandle)
    ccall((:SA_CTL_AbortStream, SmarAct), SA_CTL_Result_t, (SA_CTL_DeviceHandle_t, SA_CTL_StreamHandle_t), dHandle, sHandle)
end

