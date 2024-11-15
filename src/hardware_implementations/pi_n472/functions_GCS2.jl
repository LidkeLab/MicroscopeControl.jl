function PI_InterfaceSetupDlg(szRegKeyName)
    ccall((:PI_InterfaceSetupDlg, PI_GCS2), Cint, (Ptr{Cchar},), szRegKeyName)
end

function PI_ConnectRS232(nPortNr, iBaudRate)
    ccall((:PI_ConnectRS232, PI_GCS2), Cint, (Cint, Cint), nPortNr, iBaudRate)
end

function PI_TryConnectRS232(port, baudrate)
    ccall((:PI_TryConnectRS232, PI_GCS2), Cint, (Cint, Cint), port, baudrate)
end

function PI_TryConnectUSB(szDescription)
    ccall((:PI_TryConnectUSB, PI_GCS2), Cint, (Ptr{Cchar},), szDescription)
end

function PI_IsConnecting(threadID, bCOnnecting)
    ccall((:PI_IsConnecting, PI_GCS2), BOOL, (Cint, Ptr{BOOL}), threadID, bCOnnecting)
end

function PI_GetControllerID(threadID)
    ccall((:PI_GetControllerID, PI_GCS2), Cint, (Cint,), threadID)
end

function PI_CancelConnect(threadID)
    ccall((:PI_CancelConnect, PI_GCS2), BOOL, (Cint,), threadID)
end

function PI_OpenRS232DaisyChain(iPortNumber, iBaudRate, pNumberOfConnectedDaisyChainDevices, szDeviceIDNs, iBufferSize)
    ccall((:PI_OpenRS232DaisyChain, PI_GCS2), Cint, (Cint, Cint, Ptr{Cint}, Ptr{Cchar}, Cint), iPortNumber, iBaudRate, pNumberOfConnectedDaisyChainDevices, szDeviceIDNs, iBufferSize)
end

function PI_ConnectDaisyChainDevice(iPortId, iDeviceNumber)
    ccall((:PI_ConnectDaisyChainDevice, PI_GCS2), Cint, (Cint, Cint), iPortId, iDeviceNumber)
end

function PI_CloseDaisyChain(iPortId)
    ccall((:PI_CloseDaisyChain, PI_GCS2), Cvoid, (Cint,), iPortId)
end

function PI_ConnectNIgpib(nBoard, nDevAddr)
    ccall((:PI_ConnectNIgpib, PI_GCS2), Cint, (Cint, Cint), nBoard, nDevAddr)
end

function PI_ConnectTCPIP(szHostname, port)
    ccall((:PI_ConnectTCPIP, PI_GCS2), Cint, (Ptr{Cchar}, Cint), szHostname, port)
end

function PI_EnableTCPIPScan(iMask)
    ccall((:PI_EnableTCPIPScan, PI_GCS2), Cint, (Cint,), iMask)
end

function PI_EnumerateTCPIPDevices(szBuffer, iBufferSize, szFilter)
    ccall((:PI_EnumerateTCPIPDevices, PI_GCS2), Cint, (Ptr{Cchar}, Cint, Ptr{Cchar}), szBuffer, iBufferSize, szFilter)
end

function PI_ConnectTCPIPByDescription(szDescription)
    ccall((:PI_ConnectTCPIPByDescription, PI_GCS2), Cint, (Ptr{Cchar},), szDescription)
end

function PI_OpenTCPIPDaisyChain(szHostname, port, pNumberOfConnectedDaisyChainDevices, szDeviceIDNs, iBufferSize)
    ccall((:PI_OpenTCPIPDaisyChain, PI_GCS2), Cint, (Ptr{Cchar}, Cint, Ptr{Cint}, Ptr{Cchar}, Cint), szHostname, port, pNumberOfConnectedDaisyChainDevices, szDeviceIDNs, iBufferSize)
end

function PI_StartDaisyChainScanTCPIP(szHostname, port)
    ccall((:PI_StartDaisyChainScanTCPIP, PI_GCS2), Cint, (Ptr{Cchar}, Cint), szHostname, port)
end

function PI_StartDaisyChainScanRS232(iPortNumber, iBaudRate)
    ccall((:PI_StartDaisyChainScanRS232, PI_GCS2), Cint, (Cint, Cint), iPortNumber, iBaudRate)
end

function PI_StartDaisyChainScanUSB(szDescription)
    ccall((:PI_StartDaisyChainScanUSB, PI_GCS2), Cint, (Ptr{Cchar},), szDescription)
end

function PI_DaisyChainScanning(threadId, scanning, progressPercentage)
    ccall((:PI_DaisyChainScanning, PI_GCS2), Cint, (Cint, Ptr{BOOL}, Ptr{Cdouble}), threadId, scanning, progressPercentage)
end

function PI_GetDaisyChainID(threadId)
    ccall((:PI_GetDaisyChainID, PI_GCS2), Cint, (Cint,), threadId)
end

function PI_GetDevicesInDaisyChain(portId, numberOfDevices, buffer, bufferSize)
    ccall((:PI_GetDevicesInDaisyChain, PI_GCS2), Cint, (Cint, Ptr{Cint}, Ptr{Cchar}, Cint), portId, numberOfDevices, buffer, bufferSize)
end

function PI_StopDaisyChainScan(threadId)
    ccall((:PI_StopDaisyChainScan, PI_GCS2), Cint, (Cint,), threadId)
end

function PI_GetConnectedDaisyChains(daisyChainIds, nrDaisyChainsIds)
    ccall((:PI_GetConnectedDaisyChains, PI_GCS2), Cint, (Ptr{Cint}, Cint), daisyChainIds, nrDaisyChainsIds)
end

# no prototype is found for this function at PI_GCS2_DLL.h:163:18, please use with caution
function PI_GetNrConnectedDaisyChains()
    ccall((:PI_GetNrConnectedDaisyChains, PI_GCS2), Cint, ())
end

# no prototype is found for this function at PI_GCS2_DLL.h:164:19, please use with caution
function PI_CloseAllDaisyChains()
    ccall((:PI_CloseAllDaisyChains, PI_GCS2), Cvoid, ())
end

function PI_EnumerateUSB(szBuffer, iBufferSize, szFilter)
    ccall((:PI_EnumerateUSB, PI_GCS2), Cint, (Ptr{Cchar}, Cint, Ptr{Cchar}), szBuffer, iBufferSize, szFilter)
end

function PI_ConnectUSB(szDescription)
    ccall((:PI_ConnectUSB, PI_GCS2), Cint, (Ptr{Cchar},), szDescription)
end

function PI_ConnectUSBWithBaudRate(szDescription, iBaudRate)
    ccall((:PI_ConnectUSBWithBaudRate, PI_GCS2), Cint, (Ptr{Cchar}, Cint), szDescription, iBaudRate)
end

function PI_OpenUSBDaisyChain(szDescription, pNumberOfConnectedDaisyChainDevices, szDeviceIDNs, iBufferSize)
    ccall((:PI_OpenUSBDaisyChain, PI_GCS2), Cint, (Ptr{Cchar}, Ptr{Cint}, Ptr{Cchar}, Cint), szDescription, pNumberOfConnectedDaisyChainDevices, szDeviceIDNs, iBufferSize)
end

function PI_IsConnected(ID)
    ccall((:PI_IsConnected, PI_GCS2), BOOL, (Cint,), ID)
end

function PI_CloseConnection(ID)
    ccall((:PI_CloseConnection, PI_GCS2), Cvoid, (Cint,), ID)
end

function PI_GetError(ID)
    ccall((:PI_GetError, PI_GCS2), Cint, (Cint,), ID)
end

# no prototype is found for this function at PI_GCS2_DLL.h:187:18, please use with caution
function PI_GetInitError()
    ccall((:PI_GetInitError, PI_GCS2), Cint, ())
end

function PI_SetErrorCheck(ID, bErrorCheck)
    ccall((:PI_SetErrorCheck, PI_GCS2), BOOL, (Cint, BOOL), ID, bErrorCheck)
end

function PI_TranslateError(errNr, szBuffer, iBufferSize)
    ccall((:PI_TranslateError, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cint), errNr, szBuffer, iBufferSize)
end

function PI_SetTimeout(ID, timeoutInMS)
    ccall((:PI_SetTimeout, PI_GCS2), Cint, (Cint, Cint), ID, timeoutInMS)
end

function PI_SetDaisyChainScanMaxDeviceID(maxID)
    ccall((:PI_SetDaisyChainScanMaxDeviceID, PI_GCS2), Cint, (Cint,), maxID)
end

function PI_EnableReconnect(ID, bEnable)
    ccall((:PI_EnableReconnect, PI_GCS2), BOOL, (Cint, BOOL), ID, bEnable)
end

function PI_SetNrTimeoutsBeforeClose(ID, nrTimeoutsBeforeClose)
    ccall((:PI_SetNrTimeoutsBeforeClose, PI_GCS2), Cint, (Cint, Cint), ID, nrTimeoutsBeforeClose)
end

function PI_GetInterfaceDescription(ID, szBuffer, iBufferSize)
    ccall((:PI_GetInterfaceDescription, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cint), ID, szBuffer, iBufferSize)
end

function PI_SetConnectTimeout(timeoutInMS)
    ccall((:PI_SetConnectTimeout, PI_GCS2), Cvoid, (Cint,), timeoutInMS)
end

function PI_EnableBaudRateScan(enableBaudRateScan)
    ccall((:PI_EnableBaudRateScan, PI_GCS2), Cvoid, (BOOL,), enableBaudRateScan)
end

function PI_qERR(ID, pnError)
    ccall((:PI_qERR, PI_GCS2), BOOL, (Cint, Ptr{Cint}), ID, pnError)
end

function PI_qIDN(ID, szBuffer, iBufferSize)
    ccall((:PI_qIDN, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cint), ID, szBuffer, iBufferSize)
end

function PI_INI(ID, szAxes)
    ccall((:PI_INI, PI_GCS2), BOOL, (Cint, Ptr{Cchar}), ID, szAxes)
end

function PI_qHLP(ID, szBuffer, iBufferSize)
    ccall((:PI_qHLP, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cint), ID, szBuffer, iBufferSize)
end

function PI_qHPA(ID, szBuffer, iBufferSize)
    ccall((:PI_qHPA, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cint), ID, szBuffer, iBufferSize)
end

function PI_qHPV(ID, szBuffer, iBufferSize)
    ccall((:PI_qHPV, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cint), ID, szBuffer, iBufferSize)
end

function PI_qCSV(ID, pdCommandSyntaxVersion)
    ccall((:PI_qCSV, PI_GCS2), BOOL, (Cint, Ptr{Cdouble}), ID, pdCommandSyntaxVersion)
end

function PI_qOVF(ID, szAxes, piValueArray)
    ccall((:PI_qOVF, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{BOOL}), ID, szAxes, piValueArray)
end

function PI_RBT(ID)
    ccall((:PI_RBT, PI_GCS2), BOOL, (Cint,), ID)
end

function PI_REP(ID)
    ccall((:PI_REP, PI_GCS2), BOOL, (Cint,), ID)
end

function PI_BDR(ID, iBaudRate)
    ccall((:PI_BDR, PI_GCS2), BOOL, (Cint, Cint), ID, iBaudRate)
end

function PI_qBDR(ID, iBaudRate)
    ccall((:PI_qBDR, PI_GCS2), BOOL, (Cint, Ptr{Cint}), ID, iBaudRate)
end

function PI_DBR(ID, iBaudRate)
    ccall((:PI_DBR, PI_GCS2), BOOL, (Cint, Cint), ID, iBaudRate)
end

function PI_qDBR(ID, iBaudRate)
    ccall((:PI_qDBR, PI_GCS2), BOOL, (Cint, Ptr{Cint}), ID, iBaudRate)
end

function PI_qVER(ID, szBuffer, iBufferSize)
    ccall((:PI_qVER, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cint), ID, szBuffer, iBufferSize)
end

function PI_qSSN(ID, szSerialNumber, iBufferSize)
    ccall((:PI_qSSN, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cint), ID, szSerialNumber, iBufferSize)
end

function PI_CCT(ID, iCommandType)
    ccall((:PI_CCT, PI_GCS2), BOOL, (Cint, Cint), ID, iCommandType)
end

function PI_qCCT(ID, iCommandType)
    ccall((:PI_qCCT, PI_GCS2), BOOL, (Cint, Ptr{Cint}), ID, iCommandType)
end

function PI_qTVI(ID, szBuffer, iBufferSize)
    ccall((:PI_qTVI, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cint), ID, szBuffer, iBufferSize)
end

function PI_IFC(ID, szParameters, szValues)
    ccall((:PI_IFC, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}), ID, szParameters, szValues)
end

function PI_qIFC(ID, szParameters, szBuffer, iBufferSize)
    ccall((:PI_qIFC, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Cint), ID, szParameters, szBuffer, iBufferSize)
end

function PI_IFS(ID, szPassword, szParameters, szValues)
    ccall((:PI_IFS, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}), ID, szPassword, szParameters, szValues)
end

function PI_qIFS(ID, szParameters, szBuffer, iBufferSize)
    ccall((:PI_qIFS, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Cint), ID, szParameters, szBuffer, iBufferSize)
end

function PI_qECO(ID, szSendString, szValues, iBufferSize)
    ccall((:PI_qECO, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Cint), ID, szSendString, szValues, iBufferSize)
end

function PI_MOV(ID, szAxes, pdValueArray)
    ccall((:PI_MOV, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_qMOV(ID, szAxes, pdValueArray)
    ccall((:PI_qMOV, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_MVR(ID, szAxes, pdValueArray)
    ccall((:PI_MVR, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_MVE(ID, szAxes, pdValueArray)
    ccall((:PI_MVE, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_POS(ID, szAxes, pdValueArray)
    ccall((:PI_POS, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_qPOS(ID, szAxes, pdValueArray)
    ccall((:PI_qPOS, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_IsMoving(ID, szAxes, pbValueArray)
    ccall((:PI_IsMoving, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{BOOL}), ID, szAxes, pbValueArray)
end

function PI_HLT(ID, szAxes)
    ccall((:PI_HLT, PI_GCS2), BOOL, (Cint, Ptr{Cchar}), ID, szAxes)
end

function PI_STP(ID)
    ccall((:PI_STP, PI_GCS2), BOOL, (Cint,), ID)
end

function PI_STF(ID)
    ccall((:PI_STF, PI_GCS2), BOOL, (Cint,), ID)
end

function PI_StopAll(ID)
    ccall((:PI_StopAll, PI_GCS2), BOOL, (Cint,), ID)
end

function PI_qONT(ID, szAxes, pbValueArray)
    ccall((:PI_qONT, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{BOOL}), ID, szAxes, pbValueArray)
end

function PI_RTO(ID, szAxes)
    ccall((:PI_RTO, PI_GCS2), BOOL, (Cint, Ptr{Cchar}), ID, szAxes)
end

function PI_qRTO(ID, szAxes, piValueArray)
    ccall((:PI_qRTO, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cint}), ID, szAxes, piValueArray)
end

function PI_ATZ(ID, szAxes, pdLowvoltageArray, pfUseDefaultArray)
    ccall((:PI_ATZ, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}, Ptr{BOOL}), ID, szAxes, pdLowvoltageArray, pfUseDefaultArray)
end

function PI_qATZ(ID, szAxes, piAtzResultArray)
    ccall((:PI_qATZ, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cint}), ID, szAxes, piAtzResultArray)
end

function PI_AOS(ID, szAxes, pdValueArray)
    ccall((:PI_AOS, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_qAOS(ID, szAxes, pdValueArray)
    ccall((:PI_qAOS, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_HasPosChanged(ID, szAxes, pbValueArray)
    ccall((:PI_HasPosChanged, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{BOOL}), ID, szAxes, pbValueArray)
end

function PI_GetErrorStatus(ID, pbIsReferencedArray, pbIsReferencing, pbIsMovingArray, pbIsMotionErrorArray)
    ccall((:PI_GetErrorStatus, PI_GCS2), BOOL, (Cint, Ptr{BOOL}, Ptr{BOOL}, Ptr{BOOL}, Ptr{BOOL}), ID, pbIsReferencedArray, pbIsReferencing, pbIsMovingArray, pbIsMotionErrorArray)
end

function PI_SVA(ID, szAxes, pdValueArray)
    ccall((:PI_SVA, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_qSVA(ID, szAxes, pdValueArray)
    ccall((:PI_qSVA, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_SVR(ID, szAxes, pdValueArray)
    ccall((:PI_SVR, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_DFH(ID, szAxes)
    ccall((:PI_DFH, PI_GCS2), BOOL, (Cint, Ptr{Cchar}), ID, szAxes)
end

function PI_qDFH(ID, szAxes, pdValueArray)
    ccall((:PI_qDFH, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_GOH(ID, szAxes)
    ccall((:PI_GOH, PI_GCS2), BOOL, (Cint, Ptr{Cchar}), ID, szAxes)
end

function PI_qCST(ID, szAxes, szNames, iBufferSize)
    ccall((:PI_qCST, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Cint), ID, szAxes, szNames, iBufferSize)
end

function PI_CST(ID, szAxes, szNames)
    ccall((:PI_CST, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}), ID, szAxes, szNames)
end

function PI_qVST(ID, szBuffer, iBufferSize)
    ccall((:PI_qVST, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cint), ID, szBuffer, iBufferSize)
end

function PI_qPUN(ID, szAxes, szUnit, iBufferSize)
    ccall((:PI_qPUN, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Cint), ID, szAxes, szUnit, iBufferSize)
end

function PI_EAX(ID, szAxes, pbValueArray)
    ccall((:PI_EAX, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{BOOL}), ID, szAxes, pbValueArray)
end

function PI_qEAX(ID, szAxes, pbValueArray)
    ccall((:PI_qEAX, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{BOOL}), ID, szAxes, pbValueArray)
end

function PI_SVO(ID, szAxes, pbValueArray)
    ccall((:PI_SVO, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{BOOL}), ID, szAxes, pbValueArray)
end

function PI_qSVO(ID, szAxes, pbValueArray)
    ccall((:PI_qSVO, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{BOOL}), ID, szAxes, pbValueArray)
end

function PI_SMO(ID, szAxes, piValueArray)
    ccall((:PI_SMO, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cint}), ID, szAxes, piValueArray)
end

function PI_qSMO(ID, szAxes, piValueArray)
    ccall((:PI_qSMO, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cint}), ID, szAxes, piValueArray)
end

function PI_DCO(ID, szAxes, pbValueArray)
    ccall((:PI_DCO, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{BOOL}), ID, szAxes, pbValueArray)
end

function PI_qDCO(ID, szAxes, pbValueArray)
    ccall((:PI_qDCO, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{BOOL}), ID, szAxes, pbValueArray)
end

function PI_BRA(ID, szAxes, pbValueArray)
    ccall((:PI_BRA, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{BOOL}), ID, szAxes, pbValueArray)
end

function PI_qBRA(ID, szAxes, pbValueArray)
    ccall((:PI_qBRA, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{BOOL}), ID, szAxes, pbValueArray)
end

function PI_RON(ID, szAxes, pbValueArray)
    ccall((:PI_RON, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{BOOL}), ID, szAxes, pbValueArray)
end

function PI_qRON(ID, szAxes, pbValueArray)
    ccall((:PI_qRON, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{BOOL}), ID, szAxes, pbValueArray)
end

function PI_VEL(ID, szAxes, pdValueArray)
    ccall((:PI_VEL, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_qVEL(ID, szAxes, pdValueArray)
    ccall((:PI_qVEL, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_JOG(ID, szAxes, pdValueArray)
    ccall((:PI_JOG, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_qJOG(ID, szAxes, pdValueArray)
    ccall((:PI_qJOG, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_qTCV(ID, szAxes, pdValueArray)
    ccall((:PI_qTCV, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_VLS(ID, dSystemVelocity)
    ccall((:PI_VLS, PI_GCS2), BOOL, (Cint, Cdouble), ID, dSystemVelocity)
end

function PI_qVLS(ID, pdSystemVelocity)
    ccall((:PI_qVLS, PI_GCS2), BOOL, (Cint, Ptr{Cdouble}), ID, pdSystemVelocity)
end

function PI_ACC(ID, szAxes, pdValueArray)
    ccall((:PI_ACC, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_qACC(ID, szAxes, pdValueArray)
    ccall((:PI_qACC, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_DEC(ID, szAxes, pdValueArray)
    ccall((:PI_DEC, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_qDEC(ID, szAxes, pdValueArray)
    ccall((:PI_qDEC, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_VCO(ID, szAxes, pbValueArray)
    ccall((:PI_VCO, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{BOOL}), ID, szAxes, pbValueArray)
end

function PI_qVCO(ID, szAxes, pbValueArray)
    ccall((:PI_qVCO, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{BOOL}), ID, szAxes, pbValueArray)
end

function PI_SPA(ID, szItems, iParameterArray, pdValueArray, szStrings)
    ccall((:PI_SPA, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cuint}, Ptr{Cdouble}, Ptr{Cchar}), ID, szItems, iParameterArray, pdValueArray, szStrings)
end

function PI_qSPA(ID, szItems, iParameterArray, pdValueArray, szStrings, iMaxNameSize)
    ccall((:PI_qSPA, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cuint}, Ptr{Cdouble}, Ptr{Cchar}, Cint), ID, szItems, iParameterArray, pdValueArray, szStrings, iMaxNameSize)
end

function PI_SEP(ID, szPassword, szItems, iParameterArray, pdValueArray, szStrings)
    ccall((:PI_SEP, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cuint}, Ptr{Cdouble}, Ptr{Cchar}), ID, szPassword, szItems, iParameterArray, pdValueArray, szStrings)
end

function PI_qSEP(ID, szItems, iParameterArray, pdValueArray, szStrings, iMaxNameSize)
    ccall((:PI_qSEP, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cuint}, Ptr{Cdouble}, Ptr{Cchar}, Cint), ID, szItems, iParameterArray, pdValueArray, szStrings, iMaxNameSize)
end

function PI_WPA(ID, szPassword, szItems, iParameterArray)
    ccall((:PI_WPA, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cuint}), ID, szPassword, szItems, iParameterArray)
end

function PI_DPA(ID, szPassword, szItems, iParameterArray)
    ccall((:PI_DPA, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cuint}), ID, szPassword, szItems, iParameterArray)
end

function PI_TIM(ID, dTimer)
    ccall((:PI_TIM, PI_GCS2), BOOL, (Cint, Cdouble), ID, dTimer)
end

function PI_qTIM(ID, pdTimer)
    ccall((:PI_qTIM, PI_GCS2), BOOL, (Cint, Ptr{Cdouble}), ID, pdTimer)
end

function PI_RPA(ID, szItems, iParameterArray)
    ccall((:PI_RPA, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cuint}), ID, szItems, iParameterArray)
end

function PI_SPA_String(ID, szItems, iParameterArray, szStrings)
    ccall((:PI_SPA_String, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cuint}, Ptr{Cchar}), ID, szItems, iParameterArray, szStrings)
end

function PI_qSPA_String(ID, szItems, iParameterArray, szStrings, iMaxNameSize)
    ccall((:PI_qSPA_String, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cuint}, Ptr{Cchar}, Cint), ID, szItems, iParameterArray, szStrings, iMaxNameSize)
end

function PI_SEP_String(ID, szPassword, szItems, iParameterArray, szStrings)
    ccall((:PI_SEP_String, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cuint}, Ptr{Cchar}), ID, szPassword, szItems, iParameterArray, szStrings)
end

function PI_qSEP_String(ID, szItems, iParameterArray, szStrings, iMaxNameSize)
    ccall((:PI_qSEP_String, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cuint}, Ptr{Cchar}, Cint), ID, szItems, iParameterArray, szStrings, iMaxNameSize)
end

function PI_SPA_int64(ID, szItems, iParameterArray, piValueArray)
    ccall((:PI_SPA_int64, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cuint}, Ptr{__int64}), ID, szItems, iParameterArray, piValueArray)
end

function PI_qSPA_int64(ID, szItems, iParameterArray, piValueArray)
    ccall((:PI_qSPA_int64, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cuint}, Ptr{__int64}), ID, szItems, iParameterArray, piValueArray)
end

function PI_SEP_int64(ID, szPassword, szItems, iParameterArray, piValueArray)
    ccall((:PI_SEP_int64, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cuint}, Ptr{__int64}), ID, szPassword, szItems, iParameterArray, piValueArray)
end

function PI_qSEP_int64(ID, szItems, iParameterArray, piValueArray)
    ccall((:PI_qSEP_int64, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cuint}, Ptr{__int64}), ID, szItems, iParameterArray, piValueArray)
end

function PI_STE(ID, szAxes, dOffsetArray)
    ccall((:PI_STE, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, dOffsetArray)
end

function PI_qSTE(ID, szAxes, pdValueArray)
    ccall((:PI_qSTE, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_IMP(ID, szAxes, pdImpulseSize)
    ccall((:PI_IMP, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdImpulseSize)
end

function PI_IMP_PulseWidth(ID, cAxis, dOffset, iPulseWidth)
    ccall((:PI_IMP_PulseWidth, PI_GCS2), BOOL, (Cint, Cchar, Cdouble, Cint), ID, cAxis, dOffset, iPulseWidth)
end

function PI_qIMP(ID, szAxes, pdValueArray)
    ccall((:PI_qIMP, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_SAI(ID, szOldAxes, szNewAxes)
    ccall((:PI_SAI, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}), ID, szOldAxes, szNewAxes)
end

function PI_qSAI(ID, szAxes, iBufferSize)
    ccall((:PI_qSAI, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cint), ID, szAxes, iBufferSize)
end

function PI_qSAI_ALL(ID, szAxes, iBufferSize)
    ccall((:PI_qSAI_ALL, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cint), ID, szAxes, iBufferSize)
end

function PI_CCL(ID, iComandLevel, szPassWord)
    ccall((:PI_CCL, PI_GCS2), BOOL, (Cint, Cint, Ptr{Cchar}), ID, iComandLevel, szPassWord)
end

function PI_qCCL(ID, piComandLevel)
    ccall((:PI_qCCL, PI_GCS2), BOOL, (Cint, Ptr{Cint}), ID, piComandLevel)
end

function PI_AVG(ID, iAverrageTime)
    ccall((:PI_AVG, PI_GCS2), BOOL, (Cint, Cint), ID, iAverrageTime)
end

function PI_qAVG(ID, iAverrageTime)
    ccall((:PI_qAVG, PI_GCS2), BOOL, (Cint, Ptr{Cint}), ID, iAverrageTime)
end

function PI_qHAR(ID, szAxes, pbValueArray)
    ccall((:PI_qHAR, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{BOOL}), ID, szAxes, pbValueArray)
end

function PI_qLIM(ID, szAxes, pbValueArray)
    ccall((:PI_qLIM, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{BOOL}), ID, szAxes, pbValueArray)
end

function PI_qTRS(ID, szAxes, pbValueArray)
    ccall((:PI_qTRS, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{BOOL}), ID, szAxes, pbValueArray)
end

function PI_FNL(ID, szAxes)
    ccall((:PI_FNL, PI_GCS2), BOOL, (Cint, Ptr{Cchar}), ID, szAxes)
end

function PI_qFPH(ID, szAxes, pdValueArray)
    ccall((:PI_qFPH, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_FPH(ID, szAxes)
    ccall((:PI_FPH, PI_GCS2), BOOL, (Cint, Ptr{Cchar}), ID, szAxes)
end

function PI_FPL(ID, szAxes)
    ccall((:PI_FPL, PI_GCS2), BOOL, (Cint, Ptr{Cchar}), ID, szAxes)
end

function PI_FRF(ID, szAxes)
    ccall((:PI_FRF, PI_GCS2), BOOL, (Cint, Ptr{Cchar}), ID, szAxes)
end

function PI_FED(ID, szAxes, piEdgeArray, piParamArray)
    ccall((:PI_FED, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cint}, Ptr{Cint}), ID, szAxes, piEdgeArray, piParamArray)
end

function PI_qFRF(ID, szAxes, pbValueArray)
    ccall((:PI_qFRF, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{BOOL}), ID, szAxes, pbValueArray)
end

function PI_DIO(ID, piChannelsArray, pbValueArray, iArraySize)
    ccall((:PI_DIO, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{BOOL}, Cint), ID, piChannelsArray, pbValueArray, iArraySize)
end

function PI_qDIO(ID, piChannelsArray, pbValueArray, iArraySize)
    ccall((:PI_qDIO, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{BOOL}, Cint), ID, piChannelsArray, pbValueArray, iArraySize)
end

function PI_qTIO(ID, piInputNr, piOutputNr)
    ccall((:PI_qTIO, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}), ID, piInputNr, piOutputNr)
end

function PI_IsControllerReady(ID, piControllerReady)
    ccall((:PI_IsControllerReady, PI_GCS2), BOOL, (Cint, Ptr{Cint}), ID, piControllerReady)
end

function PI_qSRG(ID, szAxes, iRegisterArray, iValArray)
    ccall((:PI_qSRG, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cint}, Ptr{Cint}), ID, szAxes, iRegisterArray, iValArray)
end

function PI_ATC(ID, piChannels, piValueArray, iArraySize)
    ccall((:PI_ATC, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Cint), ID, piChannels, piValueArray, iArraySize)
end

function PI_qATC(ID, piChannels, piValueArray, iArraySize)
    ccall((:PI_qATC, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Cint), ID, piChannels, piValueArray, iArraySize)
end

function PI_qATS(ID, piChannels, piOptions, piValueArray, iArraySize)
    ccall((:PI_qATS, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Cint), ID, piChannels, piOptions, piValueArray, iArraySize)
end

function PI_SPI(ID, szAxes, pdValueArray)
    ccall((:PI_SPI, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_qSPI(ID, szAxes, pdValueArray)
    ccall((:PI_qSPI, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_SCT(ID, dCycleTime)
    ccall((:PI_SCT, PI_GCS2), BOOL, (Cint, Cdouble), ID, dCycleTime)
end

function PI_qSCT(ID, pdCycleTime)
    ccall((:PI_qSCT, PI_GCS2), BOOL, (Cint, Ptr{Cdouble}), ID, pdCycleTime)
end

function PI_SST(ID, szAxes, pdValueArray)
    ccall((:PI_SST, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_qSST(ID, szAxes, pdValueArray)
    ccall((:PI_qSST, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_qCTV(ID, szAxes, pdValarray)
    ccall((:PI_qCTV, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValarray)
end

function PI_CTV(ID, szAxes, pdValarray)
    ccall((:PI_CTV, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValarray)
end

function PI_CTR(ID, szAxes, pdValarray)
    ccall((:PI_CTR, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValarray)
end

function PI_qCAV(ID, szAxes, pdValarray)
    ccall((:PI_qCAV, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValarray)
end

function PI_qCCV(ID, szAxes, pdValarray)
    ccall((:PI_qCCV, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValarray)
end

function PI_qCMO(ID, szAxes, piValArray)
    ccall((:PI_qCMO, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cint}), ID, szAxes, piValArray)
end

function PI_CMO(ID, szAxes, piValArray)
    ccall((:PI_CMO, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cint}), ID, szAxes, piValArray)
end

function PI_IsRunningMacro(ID, pbRunningMacro)
    ccall((:PI_IsRunningMacro, PI_GCS2), BOOL, (Cint, Ptr{BOOL}), ID, pbRunningMacro)
end

function PI_MAC_BEG(ID, szMacroName)
    ccall((:PI_MAC_BEG, PI_GCS2), BOOL, (Cint, Ptr{Cchar}), ID, szMacroName)
end

function PI_MAC_START(ID, szMacroName)
    ccall((:PI_MAC_START, PI_GCS2), BOOL, (Cint, Ptr{Cchar}), ID, szMacroName)
end

function PI_MAC_NSTART(ID, szMacroName, nrRuns)
    ccall((:PI_MAC_NSTART, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cint), ID, szMacroName, nrRuns)
end

function PI_MAC_START_Args(ID, szMacroName, szArgs)
    ccall((:PI_MAC_START_Args, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}), ID, szMacroName, szArgs)
end

function PI_MAC_NSTART_Args(ID, szMacroName, nrRuns, szArgs)
    ccall((:PI_MAC_NSTART_Args, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cint, Ptr{Cchar}), ID, szMacroName, nrRuns, szArgs)
end

function PI_MAC_END(ID)
    ccall((:PI_MAC_END, PI_GCS2), BOOL, (Cint,), ID)
end

function PI_MAC_DEL(ID, szMacroName)
    ccall((:PI_MAC_DEL, PI_GCS2), BOOL, (Cint, Ptr{Cchar}), ID, szMacroName)
end

function PI_MAC_DEF(ID, szMacroName)
    ccall((:PI_MAC_DEF, PI_GCS2), BOOL, (Cint, Ptr{Cchar}), ID, szMacroName)
end

function PI_MAC_qDEF(ID, szBuffer, iBufferSize)
    ccall((:PI_MAC_qDEF, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cint), ID, szBuffer, iBufferSize)
end

function PI_MAC_qERR(ID, szBuffer, iBufferSize)
    ccall((:PI_MAC_qERR, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cint), ID, szBuffer, iBufferSize)
end

function PI_MAC_qFREE(ID, iFreeSpace)
    ccall((:PI_MAC_qFREE, PI_GCS2), BOOL, (Cint, Ptr{Cint}), ID, iFreeSpace)
end

function PI_qMAC(ID, szMacroName, szBuffer, iBufferSize)
    ccall((:PI_qMAC, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Cint), ID, szMacroName, szBuffer, iBufferSize)
end

function PI_qRMC(ID, szBuffer, iBufferSize)
    ccall((:PI_qRMC, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cint), ID, szBuffer, iBufferSize)
end

function PI_DEL(ID, nMilliSeconds)
    ccall((:PI_DEL, PI_GCS2), BOOL, (Cint, Cint), ID, nMilliSeconds)
end

function PI_WAC(ID, szCondition)
    ccall((:PI_WAC, PI_GCS2), BOOL, (Cint, Ptr{Cchar}), ID, szCondition)
end

function PI_MEX(ID, szCondition)
    ccall((:PI_MEX, PI_GCS2), BOOL, (Cint, Ptr{Cchar}), ID, szCondition)
end

function PI_VAR(ID, szVariable, szValue)
    ccall((:PI_VAR, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}), ID, szVariable, szValue)
end

function PI_qVAR(ID, szVariables, szValues, iBufferSize)
    ccall((:PI_qVAR, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Cint), ID, szVariables, szValues, iBufferSize)
end

function PI_ADD(ID, szVariable, value1, value2)
    ccall((:PI_ADD, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cdouble, Cdouble), ID, szVariable, value1, value2)
end

function PI_CPY(ID, szVariable, szCommand)
    ccall((:PI_CPY, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}), ID, szVariable, szCommand)
end

function PI_GcsCommandset(ID, szCommand)
    ccall((:PI_GcsCommandset, PI_GCS2), BOOL, (Cint, Ptr{Cchar}), ID, szCommand)
end

function PI_GcsGetAnswer(ID, szAnswer, iBufferSize)
    ccall((:PI_GcsGetAnswer, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cint), ID, szAnswer, iBufferSize)
end

function PI_GcsGetAnswerSize(ID, iAnswerSize)
    ccall((:PI_GcsGetAnswerSize, PI_GCS2), BOOL, (Cint, Ptr{Cint}), ID, iAnswerSize)
end

function PI_qTMN(ID, szAxes, pdValueArray)
    ccall((:PI_qTMN, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_qTMX(ID, szAxes, pdValueArray)
    ccall((:PI_qTMX, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_NLM(ID, szAxes, pdValueArray)
    ccall((:PI_NLM, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_qNLM(ID, szAxes, pdValueArray)
    ccall((:PI_qNLM, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_PLM(ID, szAxes, pdValueArray)
    ccall((:PI_PLM, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_qPLM(ID, szAxes, pdValueArray)
    ccall((:PI_qPLM, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_SSL(ID, szAxes, pbValueArray)
    ccall((:PI_SSL, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{BOOL}), ID, szAxes, pbValueArray)
end

function PI_qSSL(ID, szAxes, pbValueArray)
    ccall((:PI_qSSL, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{BOOL}), ID, szAxes, pbValueArray)
end

function PI_qVMO(ID, szAxes, pdValarray, pbMovePossible)
    ccall((:PI_qVMO, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}, Ptr{BOOL}), ID, szAxes, pdValarray, pbMovePossible)
end

function PI_qCMN(ID, szAxes, pdValueArray)
    ccall((:PI_qCMN, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_qCMX(ID, szAxes, pdValueArray)
    ccall((:PI_qCMX, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_IsGeneratorRunning(ID, piWaveGeneratorIds, pbValueArray, iArraySize)
    ccall((:PI_IsGeneratorRunning, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{BOOL}, Cint), ID, piWaveGeneratorIds, pbValueArray, iArraySize)
end

function PI_qTWG(ID, piWaveGenerators)
    ccall((:PI_qTWG, PI_GCS2), BOOL, (Cint, Ptr{Cint}), ID, piWaveGenerators)
end

function PI_WAV_SIN_P(ID, iWaveTableId, iOffsetOfFirstPointInWaveTable, iNumberOfPoints, iAddAppendWave, iCenterPointOfWave, dAmplitudeOfWave, dOffsetOfWave, iSegmentLength)
    ccall((:PI_WAV_SIN_P, PI_GCS2), BOOL, (Cint, Cint, Cint, Cint, Cint, Cint, Cdouble, Cdouble, Cint), ID, iWaveTableId, iOffsetOfFirstPointInWaveTable, iNumberOfPoints, iAddAppendWave, iCenterPointOfWave, dAmplitudeOfWave, dOffsetOfWave, iSegmentLength)
end

function PI_WAV_LIN(ID, iWaveTableId, iOffsetOfFirstPointInWaveTable, iNumberOfPoints, iAddAppendWave, iNumberOfSpeedUpDownPointsInWave, dAmplitudeOfWave, dOffsetOfWave, iSegmentLength)
    ccall((:PI_WAV_LIN, PI_GCS2), BOOL, (Cint, Cint, Cint, Cint, Cint, Cint, Cdouble, Cdouble, Cint), ID, iWaveTableId, iOffsetOfFirstPointInWaveTable, iNumberOfPoints, iAddAppendWave, iNumberOfSpeedUpDownPointsInWave, dAmplitudeOfWave, dOffsetOfWave, iSegmentLength)
end

function PI_WAV_NOISE(ID, iWaveTableId, iAddAppendWave, dAmplitudeOfWave, dOffsetOfWave, iSegmentLength)
    ccall((:PI_WAV_NOISE, PI_GCS2), BOOL, (Cint, Cint, Cint, Cdouble, Cdouble, Cint), ID, iWaveTableId, iAddAppendWave, dAmplitudeOfWave, dOffsetOfWave, iSegmentLength)
end

function PI_WAV_SWEEP(ID, iWaveTableId, iAddAppendWave, iStarFequencytValueInPoints, iStopFrequencyValueInPoints, nLengthOfWave, dAmplitudeOfWave, dOffsetOfWave)
    ccall((:PI_WAV_SWEEP, PI_GCS2), BOOL, (Cint, Cint, Cint, Cuint, Cuint, Cuint, Cdouble, Cdouble), ID, iWaveTableId, iAddAppendWave, iStarFequencytValueInPoints, iStopFrequencyValueInPoints, nLengthOfWave, dAmplitudeOfWave, dOffsetOfWave)
end

function PI_WAV_RAMP(ID, iWaveTableId, iOffsetOfFirstPointInWaveTable, iNumberOfPoints, iAddAppendWave, iCenterPointOfWave, iNumberOfSpeedUpDownPointsInWave, dAmplitudeOfWave, dOffsetOfWave, iSegmentLength)
    ccall((:PI_WAV_RAMP, PI_GCS2), BOOL, (Cint, Cint, Cint, Cint, Cint, Cint, Cint, Cdouble, Cdouble, Cint), ID, iWaveTableId, iOffsetOfFirstPointInWaveTable, iNumberOfPoints, iAddAppendWave, iCenterPointOfWave, iNumberOfSpeedUpDownPointsInWave, dAmplitudeOfWave, dOffsetOfWave, iSegmentLength)
end

function PI_WAV_PNT(ID, iWaveTableId, iOffsetOfFirstPointInWaveTable, iNumberOfPoints, iAddAppendWave, pdWavePoints)
    ccall((:PI_WAV_PNT, PI_GCS2), BOOL, (Cint, Cint, Cint, Cint, Cint, Ptr{Cdouble}), ID, iWaveTableId, iOffsetOfFirstPointInWaveTable, iNumberOfPoints, iAddAppendWave, pdWavePoints)
end

function PI_qWAV(ID, piWaveTableIdsArray, piParamereIdsArray, pdValueArray, iArraySize)
    ccall((:PI_qWAV, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Ptr{Cdouble}, Cint), ID, piWaveTableIdsArray, piParamereIdsArray, pdValueArray, iArraySize)
end

function PI_WGO(ID, piWaveGeneratorIdsArray, iStartModArray, iArraySize)
    ccall((:PI_WGO, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Cint), ID, piWaveGeneratorIdsArray, iStartModArray, iArraySize)
end

function PI_qWGO(ID, piWaveGeneratorIdsArray, piValueArray, iArraySize)
    ccall((:PI_qWGO, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Cint), ID, piWaveGeneratorIdsArray, piValueArray, iArraySize)
end

function PI_WGC(ID, piWaveGeneratorIdsArray, piNumberOfCyclesArray, iArraySize)
    ccall((:PI_WGC, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Cint), ID, piWaveGeneratorIdsArray, piNumberOfCyclesArray, iArraySize)
end

function PI_qWGC(ID, piWaveGeneratorIdsArray, piValueArray, iArraySize)
    ccall((:PI_qWGC, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Cint), ID, piWaveGeneratorIdsArray, piValueArray, iArraySize)
end

function PI_qWGI(ID, piWaveGeneratorIdsArray, piValueArray, iArraySize)
    ccall((:PI_qWGI, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Cint), ID, piWaveGeneratorIdsArray, piValueArray, iArraySize)
end

function PI_qWGN(ID, piWaveGeneratorIdsArray, piValueArray, iArraySize)
    ccall((:PI_qWGN, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Cint), ID, piWaveGeneratorIdsArray, piValueArray, iArraySize)
end

function PI_qWGS(ID, iWaveGeneratorId, szItem, buffer, bufferSize)
    ccall((:PI_qWGS, PI_GCS2), BOOL, (Cint, Cint, Ptr{Cchar}, Ptr{Cchar}, Cint), ID, iWaveGeneratorId, szItem, buffer, bufferSize)
end

function PI_WSL(ID, piWaveGeneratorIdsArray, piWaveTableIdsArray, iArraySize)
    ccall((:PI_WSL, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Cint), ID, piWaveGeneratorIdsArray, piWaveTableIdsArray, iArraySize)
end

function PI_qWSL(ID, piWaveGeneratorIdsArray, piWaveTableIdsArray, iArraySize)
    ccall((:PI_qWSL, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Cint), ID, piWaveGeneratorIdsArray, piWaveTableIdsArray, iArraySize)
end

function PI_DTC(ID, piDdlTableIdsArray, iArraySize)
    ccall((:PI_DTC, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Cint), ID, piDdlTableIdsArray, iArraySize)
end

function PI_qDTL(ID, piDdlTableIdsArray, piValueArray, iArraySize)
    ccall((:PI_qDTL, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Cint), ID, piDdlTableIdsArray, piValueArray, iArraySize)
end

function PI_WCL(ID, piWaveTableIdsArray, iArraySize)
    ccall((:PI_WCL, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Cint), ID, piWaveTableIdsArray, iArraySize)
end

function PI_qTLT(ID, piNumberOfDdlTables)
    ccall((:PI_qTLT, PI_GCS2), BOOL, (Cint, Ptr{Cint}), ID, piNumberOfDdlTables)
end

function PI_qGWD_SYNC(ID, iWaveTableId, iOffsetOfFirstPointInWaveTable, iNumberOfValues, pdValueArray)
    ccall((:PI_qGWD_SYNC, PI_GCS2), BOOL, (Cint, Cint, Cint, Cint, Ptr{Cdouble}), ID, iWaveTableId, iOffsetOfFirstPointInWaveTable, iNumberOfValues, pdValueArray)
end

function PI_qGWD(ID, iWaveTableIdsArray, iNumberOfWaveTables, iOffset, nrValues, pdValarray, szGcsArrayHeader, iGcsArrayHeaderMaxSize)
    ccall((:PI_qGWD, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Cint, Cint, Cint, Ptr{Ptr{Cdouble}}, Ptr{Cchar}, Cint), ID, iWaveTableIdsArray, iNumberOfWaveTables, iOffset, nrValues, pdValarray, szGcsArrayHeader, iGcsArrayHeaderMaxSize)
end

function PI_WOS(ID, iWaveTableIdsArray, pdValueArray, iArraySize)
    ccall((:PI_WOS, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cdouble}, Cint), ID, iWaveTableIdsArray, pdValueArray, iArraySize)
end

function PI_qWOS(ID, iWaveTableIdsArray, pdValueArray, iArraySize)
    ccall((:PI_qWOS, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cdouble}, Cint), ID, iWaveTableIdsArray, pdValueArray, iArraySize)
end

function PI_WTR(ID, piWaveGeneratorIdsArray, piTableRateArray, piInterpolationTypeArray, iArraySize)
    ccall((:PI_WTR, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Cint), ID, piWaveGeneratorIdsArray, piTableRateArray, piInterpolationTypeArray, iArraySize)
end

function PI_qWTR(ID, piWaveGeneratorIdsArray, piTableRateArray, piInterpolationTypeArray, iArraySize)
    ccall((:PI_qWTR, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Cint), ID, piWaveGeneratorIdsArray, piTableRateArray, piInterpolationTypeArray, iArraySize)
end

function PI_DDL(ID, iDdlTableId, iOffsetOfFirstPointInDdlTable, iNumberOfValues, pdValueArray)
    ccall((:PI_DDL, PI_GCS2), BOOL, (Cint, Cint, Cint, Cint, Ptr{Cdouble}), ID, iDdlTableId, iOffsetOfFirstPointInDdlTable, iNumberOfValues, pdValueArray)
end

function PI_qDDL_SYNC(ID, iDdlTableId, iOffsetOfFirstPointInDdlTable, iNumberOfValues, pdValueArray)
    ccall((:PI_qDDL_SYNC, PI_GCS2), BOOL, (Cint, Cint, Cint, Cint, Ptr{Cdouble}), ID, iDdlTableId, iOffsetOfFirstPointInDdlTable, iNumberOfValues, pdValueArray)
end

function PI_qDDL(ID, iDdlTableIdsArray, iNumberOfDdlTables, iOffset, nrValues, pdValarray, szGcsArrayHeader, iGcsArrayHeaderMaxSize)
    ccall((:PI_qDDL, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Cint, Cint, Cint, Ptr{Ptr{Cdouble}}, Ptr{Cchar}, Cint), ID, iDdlTableIdsArray, iNumberOfDdlTables, iOffset, nrValues, pdValarray, szGcsArrayHeader, iGcsArrayHeaderMaxSize)
end

function PI_DPO(ID, szAxes)
    ccall((:PI_DPO, PI_GCS2), BOOL, (Cint, Ptr{Cchar}), ID, szAxes)
end

function PI_qWMS(ID, piWaveTableIds, iWaveTableMaximumSize, iArraySize)
    ccall((:PI_qWMS, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Cint), ID, piWaveTableIds, iWaveTableMaximumSize, iArraySize)
end

function PI_TWE(ID, piWaveTableIdsArray, piWaveTableStartIndexArray, piWaveTableEndIndexArray, iArraySize)
    ccall((:PI_TWE, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Cint), ID, piWaveTableIdsArray, piWaveTableStartIndexArray, piWaveTableEndIndexArray, iArraySize)
end

function PI_qTWE(ID, piWaveTableIdsArray, piWaveTableStartIndexArray, piWaveTableEndIndexArray, iArraySize)
    ccall((:PI_qTWE, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Cint), ID, piWaveTableIdsArray, piWaveTableStartIndexArray, piWaveTableEndIndexArray, iArraySize)
end

function PI_TWC(ID)
    ccall((:PI_TWC, PI_GCS2), BOOL, (Cint,), ID)
end

function PI_TWS(ID, piTriggerChannelIdsArray, piPointNumberArray, piSwitchArray, iArraySize)
    ccall((:PI_TWS, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Cint), ID, piTriggerChannelIdsArray, piPointNumberArray, piSwitchArray, iArraySize)
end

function PI_qTWS(ID, iTriggerChannelIdsArray, iNumberOfTriggerChannels, iOffset, nrValues, pdValarray, szGcsArrayHeader, iGcsArrayHeaderMaxSize)
    ccall((:PI_qTWS, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Cint, Cint, Cint, Ptr{Ptr{Cdouble}}, Ptr{Cchar}, Cint), ID, iTriggerChannelIdsArray, iNumberOfTriggerChannels, iOffset, nrValues, pdValarray, szGcsArrayHeader, iGcsArrayHeaderMaxSize)
end

function PI_CTO(ID, piTriggerOutputIds, piTriggerParameterArray, pdValueArray, iArraySize)
    ccall((:PI_CTO, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Ptr{Cdouble}, Cint), ID, piTriggerOutputIds, piTriggerParameterArray, pdValueArray, iArraySize)
end

function PI_CTOString(ID, piTriggerOutputIds, piTriggerParameterArray, szValueArray, iArraySize)
    ccall((:PI_CTOString, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Ptr{Cchar}, Cint), ID, piTriggerOutputIds, piTriggerParameterArray, szValueArray, iArraySize)
end

function PI_qCTO(ID, piTriggerOutputIds, piTriggerParameterArray, pdValueArray, iArraySize)
    ccall((:PI_qCTO, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Ptr{Cdouble}, Cint), ID, piTriggerOutputIds, piTriggerParameterArray, pdValueArray, iArraySize)
end

function PI_qCTOString(ID, piTriggerOutputIds, piTriggerParameterArray, szValueArray, iArraySize, iBufferSize)
    ccall((:PI_qCTOString, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Ptr{Cchar}, Cint, Cint), ID, piTriggerOutputIds, piTriggerParameterArray, szValueArray, iArraySize, iBufferSize)
end

function PI_TRO(ID, piTriggerOutputIds, pbTriggerState, iArraySize)
    ccall((:PI_TRO, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{BOOL}, Cint), ID, piTriggerOutputIds, pbTriggerState, iArraySize)
end

function PI_qTRO(ID, piTriggerOutputIds, pbTriggerState, iArraySize)
    ccall((:PI_qTRO, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{BOOL}, Cint), ID, piTriggerOutputIds, pbTriggerState, iArraySize)
end

function PI_TRI(ID, piTriggerInputIds, pbTriggerState, iArraySize)
    ccall((:PI_TRI, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{BOOL}, Cint), ID, piTriggerInputIds, pbTriggerState, iArraySize)
end

function PI_qTRI(ID, piTriggerInputIds, pbTriggerState, iArraySize)
    ccall((:PI_qTRI, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{BOOL}, Cint), ID, piTriggerInputIds, pbTriggerState, iArraySize)
end

function PI_CTI(ID, piTriggerInputIds, piTriggerParameterArray, szValueArray, iArraySize)
    ccall((:PI_CTI, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Ptr{Cchar}, Cint), ID, piTriggerInputIds, piTriggerParameterArray, szValueArray, iArraySize)
end

function PI_qCTI(ID, piTriggerInputIds, piTriggerParameterArray, szValueArray, iArraySize, iBufferSize)
    ccall((:PI_qCTI, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Ptr{Cchar}, Cint, Cint), ID, piTriggerInputIds, piTriggerParameterArray, szValueArray, iArraySize, iBufferSize)
end

function PI_qHDR(ID, szBuffer, iBufferSize)
    ccall((:PI_qHDR, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cint), ID, szBuffer, iBufferSize)
end

function PI_qTNR(ID, piNumberOfRecordCannels)
    ccall((:PI_qTNR, PI_GCS2), BOOL, (Cint, Ptr{Cint}), ID, piNumberOfRecordCannels)
end

function PI_DRC(ID, piRecordTableIdsArray, szRecordSourceIds, piRecordOptionArray)
    ccall((:PI_DRC, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cchar}, Ptr{Cint}), ID, piRecordTableIdsArray, szRecordSourceIds, piRecordOptionArray)
end

function PI_qDRC(ID, piRecordTableIdsArray, szRecordSourceIds, piRecordOptionArray, iRecordSourceIdsBufferSize, iRecordOptionArraySize)
    ccall((:PI_qDRC, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cchar}, Ptr{Cint}, Cint, Cint), ID, piRecordTableIdsArray, szRecordSourceIds, piRecordOptionArray, iRecordSourceIdsBufferSize, iRecordOptionArraySize)
end

function PI_qDRR_SYNC(ID, iRecordTablelId, iOffsetOfFirstPointInRecordTable, iNumberOfValues, pdValueArray)
    ccall((:PI_qDRR_SYNC, PI_GCS2), BOOL, (Cint, Cint, Cint, Cint, Ptr{Cdouble}), ID, iRecordTablelId, iOffsetOfFirstPointInRecordTable, iNumberOfValues, pdValueArray)
end

function PI_qDRR(ID, piRecTableIdIdsArray, iNumberOfRecTables, iOffsetOfFirstPointInRecordTable, iNumberOfValues, pdValueArray, szGcsArrayHeader, iGcsArrayHeaderMaxSize)
    ccall((:PI_qDRR, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Cint, Cint, Cint, Ptr{Ptr{Cdouble}}, Ptr{Cchar}, Cint), ID, piRecTableIdIdsArray, iNumberOfRecTables, iOffsetOfFirstPointInRecordTable, iNumberOfValues, pdValueArray, szGcsArrayHeader, iGcsArrayHeaderMaxSize)
end

function PI_DRT(ID, piRecordChannelIdsArray, piTriggerSourceArray, szValues, iArraySize)
    ccall((:PI_DRT, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Ptr{Cchar}, Cint), ID, piRecordChannelIdsArray, piTriggerSourceArray, szValues, iArraySize)
end

function PI_qDRT(ID, piRecordChannelIdsArray, piTriggerSourceArray, szValues, iArraySize, iValueBufferLength)
    ccall((:PI_qDRT, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Ptr{Cchar}, Cint, Cint), ID, piRecordChannelIdsArray, piTriggerSourceArray, szValues, iArraySize, iValueBufferLength)
end

function PI_RTR(ID, piReportTableRate)
    ccall((:PI_RTR, PI_GCS2), BOOL, (Cint, Cint), ID, piReportTableRate)
end

function PI_qRTR(ID, piReportTableRate)
    ccall((:PI_qRTR, PI_GCS2), BOOL, (Cint, Ptr{Cint}), ID, piReportTableRate)
end

function PI_WGR(ID)
    ccall((:PI_WGR, PI_GCS2), BOOL, (Cint,), ID)
end

function PI_qDRL(ID, piRecordChannelIdsArray, piNuberOfRecordedValuesArray, iArraySize)
    ccall((:PI_qDRL, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Cint), ID, piRecordChannelIdsArray, piNuberOfRecordedValuesArray, iArraySize)
end

function PI_WFR(ID, szAxis, iMode, dAmplitude, dLowFrequency, dHighFrequency, iNumberOfFrequencies)
    ccall((:PI_WFR, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cint, Cdouble, Cdouble, Cdouble, Cint), ID, szAxis, iMode, dAmplitude, dLowFrequency, dHighFrequency, iNumberOfFrequencies)
end

function PI_qWFR(ID, szAxis, iMode, pbValueArray, szGcsArrayHeader, iGcsArrayHeaderMaxSize)
    ccall((:PI_qWFR, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cint, Ptr{Ptr{Cdouble}}, Ptr{Cchar}, Cint), ID, szAxis, iMode, pbValueArray, szGcsArrayHeader, iGcsArrayHeaderMaxSize)
end

function PI_VMA(ID, piPiezoChannelsArray, pdValueArray, iArraySize)
    ccall((:PI_VMA, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cdouble}, Cint), ID, piPiezoChannelsArray, pdValueArray, iArraySize)
end

function PI_qVMA(ID, piPiezoChannelsArray, pdValueArray, iArraySize)
    ccall((:PI_qVMA, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cdouble}, Cint), ID, piPiezoChannelsArray, pdValueArray, iArraySize)
end

function PI_VMI(ID, piPiezoChannelsArray, pdValueArray, iArraySize)
    ccall((:PI_VMI, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cdouble}, Cint), ID, piPiezoChannelsArray, pdValueArray, iArraySize)
end

function PI_qVMI(ID, piPiezoChannelsArray, pdValueArray, iArraySize)
    ccall((:PI_qVMI, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cdouble}, Cint), ID, piPiezoChannelsArray, pdValueArray, iArraySize)
end

function PI_VOL(ID, piPiezoChannelsArray, pdValueArray, iArraySize)
    ccall((:PI_VOL, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cdouble}, Cint), ID, piPiezoChannelsArray, pdValueArray, iArraySize)
end

function PI_qVOL(ID, piPiezoChannelsArray, pdValueArray, iArraySize)
    ccall((:PI_qVOL, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cdouble}, Cint), ID, piPiezoChannelsArray, pdValueArray, iArraySize)
end

function PI_qTPC(ID, piNumberOfPiezoChannels)
    ccall((:PI_qTPC, PI_GCS2), BOOL, (Cint, Ptr{Cint}), ID, piNumberOfPiezoChannels)
end

function PI_ONL(ID, iPiezoCannels, piValueArray, iArraySize)
    ccall((:PI_ONL, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Cint), ID, iPiezoCannels, piValueArray, iArraySize)
end

function PI_qONL(ID, iPiezoCannels, piValueArray, iArraySize)
    ccall((:PI_qONL, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Cint), ID, iPiezoCannels, piValueArray, iArraySize)
end

function PI_qTAD(ID, piSensorsChannelsArray, piValueArray, iArraySize)
    ccall((:PI_qTAD, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Cint), ID, piSensorsChannelsArray, piValueArray, iArraySize)
end

function PI_qTNS(ID, piSensorsChannelsArray, pdValueArray, iArraySize)
    ccall((:PI_qTNS, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cdouble}, Cint), ID, piSensorsChannelsArray, pdValueArray, iArraySize)
end

function PI_TSP(ID, piSensorsChannelsArray, pdValueArray, iArraySize)
    ccall((:PI_TSP, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cdouble}, Cint), ID, piSensorsChannelsArray, pdValueArray, iArraySize)
end

function PI_qTSP(ID, piSensorsChannelsArray, pdValueArray, iArraySize)
    ccall((:PI_qTSP, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cdouble}, Cint), ID, piSensorsChannelsArray, pdValueArray, iArraySize)
end

function PI_SCN(ID, piSensorsChannelsArray, piValueArray, iArraySize)
    ccall((:PI_SCN, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Cint), ID, piSensorsChannelsArray, piValueArray, iArraySize)
end

function PI_qSCN(ID, piSensorsChannelsArray, piValueArray, iArraySize)
    ccall((:PI_qSCN, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Cint), ID, piSensorsChannelsArray, piValueArray, iArraySize)
end

function PI_qTSC(ID, piNumberOfSensorChannels)
    ccall((:PI_qTSC, PI_GCS2), BOOL, (Cint, Ptr{Cint}), ID, piNumberOfSensorChannels)
end

function PI_APG(ID, piPIEZOWALKChannelsArray, iArraySize)
    ccall((:PI_APG, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Cint), ID, piPIEZOWALKChannelsArray, iArraySize)
end

function PI_qAPG(ID, piPIEZOWALKChannelsArray, piValueArray, iArraySize)
    ccall((:PI_qAPG, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Cint), ID, piPIEZOWALKChannelsArray, piValueArray, iArraySize)
end

function PI_OAC(ID, piPIEZOWALKChannelsArray, pdValueArray, iArraySize)
    ccall((:PI_OAC, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cdouble}, Cint), ID, piPIEZOWALKChannelsArray, pdValueArray, iArraySize)
end

function PI_qOAC(ID, piPIEZOWALKChannelsArray, pdValueArray, iArraySize)
    ccall((:PI_qOAC, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cdouble}, Cint), ID, piPIEZOWALKChannelsArray, pdValueArray, iArraySize)
end

function PI_OAD(ID, piPIEZOWALKChannelsArray, pdValueArray, iArraySize)
    ccall((:PI_OAD, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cdouble}, Cint), ID, piPIEZOWALKChannelsArray, pdValueArray, iArraySize)
end

function PI_qOAD(ID, piPIEZOWALKChannelsArray, pdValueArray, iArraySize)
    ccall((:PI_qOAD, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cdouble}, Cint), ID, piPIEZOWALKChannelsArray, pdValueArray, iArraySize)
end

function PI_ODC(ID, piPIEZOWALKChannelsArray, pdValueArray, iArraySize)
    ccall((:PI_ODC, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cdouble}, Cint), ID, piPIEZOWALKChannelsArray, pdValueArray, iArraySize)
end

function PI_qODC(ID, piPIEZOWALKChannelsArray, pdValueArray, iArraySize)
    ccall((:PI_qODC, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cdouble}, Cint), ID, piPIEZOWALKChannelsArray, pdValueArray, iArraySize)
end

function PI_OCD(ID, piPIEZOWALKChannelsArray, pdValueArray, iArraySize)
    ccall((:PI_OCD, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cdouble}, Cint), ID, piPIEZOWALKChannelsArray, pdValueArray, iArraySize)
end

function PI_qOCD(ID, piPIEZOWALKChannelsArray, pdValueArray, iArraySize)
    ccall((:PI_qOCD, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cdouble}, Cint), ID, piPIEZOWALKChannelsArray, pdValueArray, iArraySize)
end

function PI_OSM(ID, piPIEZOWALKChannelsArray, piValueArray, iArraySize)
    ccall((:PI_OSM, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Cint), ID, piPIEZOWALKChannelsArray, piValueArray, iArraySize)
end

function PI_qOSM(ID, piPIEZOWALKChannelsArray, piValueArray, iArraySize)
    ccall((:PI_qOSM, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Cint), ID, piPIEZOWALKChannelsArray, piValueArray, iArraySize)
end

function PI_OSMf(ID, piPIEZOWALKChannelsArray, pdValueArray, iArraySize)
    ccall((:PI_OSMf, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cdouble}, Cint), ID, piPIEZOWALKChannelsArray, pdValueArray, iArraySize)
end

function PI_qOSMf(ID, piPIEZOWALKChannelsArray, pdValueArray, iArraySize)
    ccall((:PI_qOSMf, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cdouble}, Cint), ID, piPIEZOWALKChannelsArray, pdValueArray, iArraySize)
end

function PI_OSMstringIDs(ID, szAxisOrChannelIds, pdValueArray)
    ccall((:PI_OSMstringIDs, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxisOrChannelIds, pdValueArray)
end

function PI_qOSMstringIDs(ID, szAxisOrChannelIds, pdValueArray)
    ccall((:PI_qOSMstringIDs, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxisOrChannelIds, pdValueArray)
end

function PI_OVL(ID, piPIEZOWALKChannelsArray, pdValueArray, iArraySize)
    ccall((:PI_OVL, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cdouble}, Cint), ID, piPIEZOWALKChannelsArray, pdValueArray, iArraySize)
end

function PI_qOVL(ID, piPIEZOWALKChannelsArray, pdValueArray, iArraySize)
    ccall((:PI_qOVL, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cdouble}, Cint), ID, piPIEZOWALKChannelsArray, pdValueArray, iArraySize)
end

function PI_qOSN(ID, piPIEZOWALKChannelsArray, piValueArray, iArraySize)
    ccall((:PI_qOSN, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Cint), ID, piPIEZOWALKChannelsArray, piValueArray, iArraySize)
end

function PI_qOSNstringIDs(ID, szAxisOrChannelIds, piValueArray)
    ccall((:PI_qOSNstringIDs, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cint}), ID, szAxisOrChannelIds, piValueArray)
end

function PI_SSA(ID, piPIEZOWALKChannelsArray, pdValueArray, iArraySize)
    ccall((:PI_SSA, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cdouble}, Cint), ID, piPIEZOWALKChannelsArray, pdValueArray, iArraySize)
end

function PI_qSSA(ID, piPIEZOWALKChannelsArray, pdValueArray, iArraySize)
    ccall((:PI_qSSA, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cdouble}, Cint), ID, piPIEZOWALKChannelsArray, pdValueArray, iArraySize)
end

function PI_RNP(ID, piPIEZOWALKChannelsArray, pdValueArray, iArraySize)
    ccall((:PI_RNP, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cdouble}, Cint), ID, piPIEZOWALKChannelsArray, pdValueArray, iArraySize)
end

function PI_PGS(ID, piPIEZOWALKChannelsArray, iArraySize)
    ccall((:PI_PGS, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Cint), ID, piPIEZOWALKChannelsArray, iArraySize)
end

function PI_qTAC(ID, pnNrChannels)
    ccall((:PI_qTAC, PI_GCS2), BOOL, (Cint, Ptr{Cint}), ID, pnNrChannels)
end

function PI_qTAV(ID, piChannelsArray, pdValueArray, iArraySize)
    ccall((:PI_qTAV, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cdouble}, Cint), ID, piChannelsArray, pdValueArray, iArraySize)
end

function PI_OMA(ID, szAxes, pdValueArray)
    ccall((:PI_OMA, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_qOMA(ID, szAxes, pdValueArray)
    ccall((:PI_qOMA, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_OMR(ID, szAxes, pdValueArray)
    ccall((:PI_OMR, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_qJAS(ID, iJoystickIDsArray, iAxesIDsArray, pdValueArray, iArraySize)
    ccall((:PI_qJAS, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Ptr{Cdouble}, Cint), ID, iJoystickIDsArray, iAxesIDsArray, pdValueArray, iArraySize)
end

function PI_JAX(ID, iJoystickID, iAxesID, szAxesBuffer)
    ccall((:PI_JAX, PI_GCS2), BOOL, (Cint, Cint, Cint, Ptr{Cchar}), ID, iJoystickID, iAxesID, szAxesBuffer)
end

function PI_qJAX(ID, iJoystickIDsArray, iAxesIDsArray, iArraySize, szAxesBuffer, iBufferSize)
    ccall((:PI_qJAX, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Cint, Ptr{Cchar}, Cint), ID, iJoystickIDsArray, iAxesIDsArray, iArraySize, szAxesBuffer, iBufferSize)
end

function PI_qJBS(ID, iJoystickIDsArray, iButtonIDsArray, pbValueArray, iArraySize)
    ccall((:PI_qJBS, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Ptr{BOOL}, Cint), ID, iJoystickIDsArray, iButtonIDsArray, pbValueArray, iArraySize)
end

function PI_JDT(ID, iJoystickIDsArray, iAxisIDsArray, piValueArray, iArraySize)
    ccall((:PI_JDT, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Cint), ID, iJoystickIDsArray, iAxisIDsArray, piValueArray, iArraySize)
end

function PI_JLT(ID, iJoystickID, iAxisID, iStartAdress, pdValueArray, iArraySize)
    ccall((:PI_JLT, PI_GCS2), BOOL, (Cint, Cint, Cint, Cint, Ptr{Cdouble}, Cint), ID, iJoystickID, iAxisID, iStartAdress, pdValueArray, iArraySize)
end

function PI_qJLT(ID, iJoystickIDsArray, iAxisIDsArray, iNumberOfTables, iOffsetOfFirstPointInTable, iNumberOfValues, pdValueArray, szGcsArrayHeader, iGcsArrayHeaderMaxSize)
    ccall((:PI_qJLT, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Cint, Cint, Cint, Ptr{Ptr{Cdouble}}, Ptr{Cchar}, Cint), ID, iJoystickIDsArray, iAxisIDsArray, iNumberOfTables, iOffsetOfFirstPointInTable, iNumberOfValues, pdValueArray, szGcsArrayHeader, iGcsArrayHeaderMaxSize)
end

function PI_JON(ID, iJoystickIDsArray, pbValueArray, iArraySize)
    ccall((:PI_JON, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{BOOL}, Cint), ID, iJoystickIDsArray, pbValueArray, iArraySize)
end

function PI_qJON(ID, iJoystickIDsArray, pbValueArray, iArraySize)
    ccall((:PI_qJON, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{BOOL}, Cint), ID, iJoystickIDsArray, pbValueArray, iArraySize)
end

function PI_AAP(ID, szAxis1, dLength1, szAxis2, dLength2, dAlignStep, iNrRepeatedPositions, iAnalogInput)
    ccall((:PI_AAP, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cdouble, Ptr{Cchar}, Cdouble, Cdouble, Cint, Cint), ID, szAxis1, dLength1, szAxis2, dLength2, dAlignStep, iNrRepeatedPositions, iAnalogInput)
end

function PI_FIO(ID, szAxis1, dLength1, szAxis2, dLength2, dThreshold, dLinearStep, dAngleScan, iAnalogInput)
    ccall((:PI_FIO, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cdouble, Ptr{Cchar}, Cdouble, Cdouble, Cdouble, Cdouble, Cint), ID, szAxis1, dLength1, szAxis2, dLength2, dThreshold, dLinearStep, dAngleScan, iAnalogInput)
end

function PI_FLM(ID, szAxis, dLength, dThreshold, iAnalogInput, iDirection)
    ccall((:PI_FLM, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cdouble, Cdouble, Cint, Cint), ID, szAxis, dLength, dThreshold, iAnalogInput, iDirection)
end

function PI_FLS(ID, szAxis, dLength, dThreshold, iAnalogInput, iDirection)
    ccall((:PI_FLS, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cdouble, Cdouble, Cint, Cint), ID, szAxis, dLength, dThreshold, iAnalogInput, iDirection)
end

function PI_FSA(ID, szAxis1, dLength1, szAxis2, dLength2, dThreshold, dDistance, dAlignStep, iAnalogInput)
    ccall((:PI_FSA, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cdouble, Ptr{Cchar}, Cdouble, Cdouble, Cdouble, Cdouble, Cint), ID, szAxis1, dLength1, szAxis2, dLength2, dThreshold, dDistance, dAlignStep, iAnalogInput)
end

function PI_FSC(ID, szAxis1, dLength1, szAxis2, dLength2, dThreshold, dDistance, iAnalogInput)
    ccall((:PI_FSC, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cdouble, Ptr{Cchar}, Cdouble, Cdouble, Cdouble, Cint), ID, szAxis1, dLength1, szAxis2, dLength2, dThreshold, dDistance, iAnalogInput)
end

function PI_FSM(ID, szAxis1, dLength1, szAxis2, dLength2, dThreshold, dDistance, iAnalogInput)
    ccall((:PI_FSM, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cdouble, Ptr{Cchar}, Cdouble, Cdouble, Cdouble, Cint), ID, szAxis1, dLength1, szAxis2, dLength2, dThreshold, dDistance, iAnalogInput)
end

function PI_qFSS(ID, piResult)
    ccall((:PI_qFSS, PI_GCS2), BOOL, (Cint, Ptr{Cint}), ID, piResult)
end

function PI_FGC(ID, szProcessIds, pdScanAxisCenterValueArray, pdStepAxisCenterValueArray)
    ccall((:PI_FGC, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}, Ptr{Cdouble}), ID, szProcessIds, pdScanAxisCenterValueArray, pdStepAxisCenterValueArray)
end

function PI_qFGC(ID, szProcessIds, pdScanAxisCenterValueArray, pdStepAxisCenterValueArray)
    ccall((:PI_qFGC, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}, Ptr{Cdouble}), ID, szProcessIds, pdScanAxisCenterValueArray, pdStepAxisCenterValueArray)
end

function PI_FRC(ID, szProcessIdBase, szProcessIdsCoupled)
    ccall((:PI_FRC, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}), ID, szProcessIdBase, szProcessIdsCoupled)
end

function PI_qFRC(ID, szProcessIdsBase, szBuffer, iBufferSize)
    ccall((:PI_qFRC, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Cint), ID, szProcessIdsBase, szBuffer, iBufferSize)
end

function PI_qTCI(ID, piFastAlignmentInputIdsArray, pdCalculatedInputValueArray, iArraySize)
    ccall((:PI_qTCI, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cdouble}, Cint), ID, piFastAlignmentInputIdsArray, pdCalculatedInputValueArray, iArraySize)
end

function PI_SIC(ID, iFastAlignmentInputId, iCalcType, pdParameters, iNumberOfParameters)
    ccall((:PI_SIC, PI_GCS2), BOOL, (Cint, Cint, Cint, Ptr{Cdouble}, Cint), ID, iFastAlignmentInputId, iCalcType, pdParameters, iNumberOfParameters)
end

function PI_qSIC(ID, piFastAlignmentInputIdsArray, iNumberOfInputIds, szBuffer, iBufferSize)
    ccall((:PI_qSIC, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Cint, Ptr{Cchar}, Cint), ID, piFastAlignmentInputIdsArray, iNumberOfInputIds, szBuffer, iBufferSize)
end

function PI_FDR(ID, szScanRoutineName, szScanAxis, dScanAxisRange, szStepAxis, dStepAxisRange, szParameters)
    ccall((:PI_FDR, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Cdouble, Ptr{Cchar}, Cdouble, Ptr{Cchar}), ID, szScanRoutineName, szScanAxis, dScanAxisRange, szStepAxis, dStepAxisRange, szParameters)
end

function PI_FDG(ID, szScanRoutineName, szScanAxis, szStepAxis, szParameters)
    ccall((:PI_FDG, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}), ID, szScanRoutineName, szScanAxis, szStepAxis, szParameters)
end

function PI_FRS(ID, szScanRoutineNames)
    ccall((:PI_FRS, PI_GCS2), BOOL, (Cint, Ptr{Cchar}), ID, szScanRoutineNames)
end

function PI_FRP(ID, szScanRoutineNames, piOptionsArray)
    ccall((:PI_FRP, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cint}), ID, szScanRoutineNames, piOptionsArray)
end

function PI_qFRP(ID, szScanRoutineNames, piOptionsArray)
    ccall((:PI_qFRP, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cint}), ID, szScanRoutineNames, piOptionsArray)
end

function PI_qFRR(ID, szScanRoutineNames, iResultId, szResult, iBufferSize)
    ccall((:PI_qFRR, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cint, Ptr{Cchar}, Cint), ID, szScanRoutineNames, iResultId, szResult, iBufferSize)
end

function PI_qFRRArray(ID, szScanRoutineNames, iResultIds, szResult, iBufferSize)
    ccall((:PI_qFRRArray, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cint}, Ptr{Cchar}, Cint), ID, szScanRoutineNames, iResultIds, szResult, iBufferSize)
end

function PI_qFRH(ID, szBuffer, iBufferSize)
    ccall((:PI_qFRH, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cint), ID, szBuffer, iBufferSize)
end

function PI_SGA(ID, piAnalogChannelIds, piGainValues, iArraySize)
    ccall((:PI_SGA, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Cint), ID, piAnalogChannelIds, piGainValues, iArraySize)
end

function PI_qSGA(ID, piAnalogChannelIds, piGainValues, iArraySize)
    ccall((:PI_qSGA, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Cint), ID, piAnalogChannelIds, piGainValues, iArraySize)
end

function PI_NAV(ID, piAnalogChannelIds, piNrReadingsValues, iArraySize)
    ccall((:PI_NAV, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Cint), ID, piAnalogChannelIds, piNrReadingsValues, iArraySize)
end

function PI_qNAV(ID, piAnalogChannelIds, piNrReadingsValues, iArraySize)
    ccall((:PI_qNAV, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Cint), ID, piAnalogChannelIds, piNrReadingsValues, iArraySize)
end

function PI_GetDynamicMoveBufferSize(ID, iSize)
    ccall((:PI_GetDynamicMoveBufferSize, PI_GCS2), BOOL, (Cint, Ptr{Cint}), ID, iSize)
end

function PI_qCOV(ID, piChannelsArray, pdValueArray, iArraySize)
    ccall((:PI_qCOV, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cdouble}, Cint), ID, piChannelsArray, pdValueArray, iArraySize)
end

function PI_MOD(ID, szItems, iModeArray, szValues)
    ccall((:PI_MOD, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cuint}, Ptr{Cchar}), ID, szItems, iModeArray, szValues)
end

function PI_qMOD(ID, szItems, iModeArray, szValues, iMaxValuesSize)
    ccall((:PI_qMOD, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cuint}, Ptr{Cchar}, Cint), ID, szItems, iModeArray, szValues, iMaxValuesSize)
end

function PI_qDIA(ID, iIDArray, szValues, iBufferSize, iArraySize)
    ccall((:PI_qDIA, PI_GCS2), BOOL, (Cint, Ptr{Cuint}, Ptr{Cchar}, Cint, Cint), ID, iIDArray, szValues, iBufferSize, iArraySize)
end

function PI_qHDI(ID, szBuffer, iBufferSize)
    ccall((:PI_qHDI, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cint), ID, szBuffer, iBufferSize)
end

function PI_qHIS(ID, szBuffer, iBufferSize)
    ccall((:PI_qHIS, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cint), ID, szBuffer, iBufferSize)
end

function PI_HIS(ID, iDeviceIDsArray, iItemIDsArray, iPropertyIDArray, szValues, iArraySize)
    ccall((:PI_HIS, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Ptr{Cchar}, Cint), ID, iDeviceIDsArray, iItemIDsArray, iPropertyIDArray, szValues, iArraySize)
end

function PI_qHIE(ID, iDeviceIDsArray, iAxesIDsArray, pdValueArray, iArraySize)
    ccall((:PI_qHIE, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Ptr{Cdouble}, Cint), ID, iDeviceIDsArray, iAxesIDsArray, pdValueArray, iArraySize)
end

function PI_qHIB(ID, iDeviceIDsArray, iButtonIDsArray, pbValueArray, iArraySize)
    ccall((:PI_qHIB, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Cint), ID, iDeviceIDsArray, iButtonIDsArray, pbValueArray, iArraySize)
end

function PI_HIL(ID, iDeviceIDsArray, iLED_IDsArray, pnValueArray, iArraySize)
    ccall((:PI_HIL, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Cint), ID, iDeviceIDsArray, iLED_IDsArray, pnValueArray, iArraySize)
end

function PI_qHIL(ID, iDeviceIDsArray, iLED_IDsArray, pnValueArray, iArraySize)
    ccall((:PI_qHIL, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Cint), ID, iDeviceIDsArray, iLED_IDsArray, pnValueArray, iArraySize)
end

function PI_HIN(ID, szAxes, pbValueArray)
    ccall((:PI_HIN, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{BOOL}), ID, szAxes, pbValueArray)
end

function PI_qHIN(ID, szAxes, pbValueArray)
    ccall((:PI_qHIN, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{BOOL}), ID, szAxes, pbValueArray)
end

function PI_HIA(ID, szAxes, iFunctionArray, iDeviceIDsArray, iAxesIDsArray)
    ccall((:PI_HIA, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}), ID, szAxes, iFunctionArray, iDeviceIDsArray, iAxesIDsArray)
end

function PI_qHIA(ID, szAxes, iFunctionArray, iDeviceIDsArray, iAxesIDsArray)
    ccall((:PI_qHIA, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}), ID, szAxes, iFunctionArray, iDeviceIDsArray, iAxesIDsArray)
end

function PI_HDT(ID, iDeviceIDsArray, iAxisIDsArray, piValueArray, iArraySize)
    ccall((:PI_HDT, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Cint), ID, iDeviceIDsArray, iAxisIDsArray, piValueArray, iArraySize)
end

function PI_qHDT(ID, iDeviceIDsArray, iAxisIDsArray, piValueArray, iArraySize)
    ccall((:PI_qHDT, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Cint), ID, iDeviceIDsArray, iAxisIDsArray, piValueArray, iArraySize)
end

function PI_HIT(ID, piTableIdsArray, piPointNumberArray, pdValueArray, iArraySize)
    ccall((:PI_HIT, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Ptr{Cdouble}, Cint), ID, piTableIdsArray, piPointNumberArray, pdValueArray, iArraySize)
end

function PI_qHIT(ID, piTableIdsArray, iNumberOfTables, iOffsetOfFirstPointInTable, iNumberOfValues, pdValueArray, szGcsArrayHeader, iGcsArrayHeaderMaxSize)
    ccall((:PI_qHIT, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Cint, Cint, Cint, Ptr{Ptr{Cdouble}}, Ptr{Cchar}, Cint), ID, piTableIdsArray, iNumberOfTables, iOffsetOfFirstPointInTable, iNumberOfValues, pdValueArray, szGcsArrayHeader, iGcsArrayHeaderMaxSize)
end

function PI_qMAN(ID, szCommand, szBuffer, iBufferSize)
    ccall((:PI_qMAN, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Cint), ID, szCommand, szBuffer, iBufferSize)
end

function PI_KSF(ID, szNameOfCoordSystem)
    ccall((:PI_KSF, PI_GCS2), BOOL, (Cint, Ptr{Cchar}), ID, szNameOfCoordSystem)
end

function PI_KEN(ID, szNameOfCoordSystem)
    ccall((:PI_KEN, PI_GCS2), BOOL, (Cint, Ptr{Cchar}), ID, szNameOfCoordSystem)
end

function PI_KRM(ID, szNameOfCoordSystem)
    ccall((:PI_KRM, PI_GCS2), BOOL, (Cint, Ptr{Cchar}), ID, szNameOfCoordSystem)
end

function PI_KLF(ID, szNameOfCoordSystem)
    ccall((:PI_KLF, PI_GCS2), BOOL, (Cint, Ptr{Cchar}), ID, szNameOfCoordSystem)
end

function PI_KSD(ID, szNameOfCoordSystem, szAxes, pdValueArray)
    ccall((:PI_KSD, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cdouble}), ID, szNameOfCoordSystem, szAxes, pdValueArray)
end

function PI_KST(ID, szNameOfCoordSystem, szAxes, pdValueArray)
    ccall((:PI_KST, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cdouble}), ID, szNameOfCoordSystem, szAxes, pdValueArray)
end

function PI_KSW(ID, szNameOfCoordSystem, szAxes, pdValueArray)
    ccall((:PI_KSW, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cdouble}), ID, szNameOfCoordSystem, szAxes, pdValueArray)
end

function PI_KLD(ID, szNameOfCoordSystem, szAxes, pdValueArray)
    ccall((:PI_KLD, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cdouble}), ID, szNameOfCoordSystem, szAxes, pdValueArray)
end

function PI_KSB(ID, szNameOfCoordSystem, szAxes, pdValueArray)
    ccall((:PI_KSB, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cdouble}), ID, szNameOfCoordSystem, szAxes, pdValueArray)
end

function PI_MRT(ID, szAxes, pdValueArray)
    ccall((:PI_MRT, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_MRW(ID, szAxes, pdValueArray)
    ccall((:PI_MRW, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, szAxes, pdValueArray)
end

function PI_qKLT(ID, szStartCoordSystem, szEndCoordSystem, buffer, bufsize)
    ccall((:PI_qKLT, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Cint), ID, szStartCoordSystem, szEndCoordSystem, buffer, bufsize)
end

function PI_qKEN(ID, szNamesOfCoordSystems, buffer, bufsize)
    ccall((:PI_qKEN, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Cint), ID, szNamesOfCoordSystems, buffer, bufsize)
end

function PI_qKET(ID, szTypes, buffer, bufsize)
    ccall((:PI_qKET, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Cint), ID, szTypes, buffer, bufsize)
end

function PI_qKLS(ID, szNameOfCoordSystem, szItem1, szItem2, buffer, bufsize)
    ccall((:PI_qKLS, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Cint), ID, szNameOfCoordSystem, szItem1, szItem2, buffer, bufsize)
end

function PI_KLN(ID, szNameOfChild, szNameOfParent)
    ccall((:PI_KLN, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}), ID, szNameOfChild, szNameOfParent)
end

function PI_qKLN(ID, szNamesOfCoordSystems, buffer, bufsize)
    ccall((:PI_qKLN, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Cint), ID, szNamesOfCoordSystems, buffer, bufsize)
end

function PI_qTRA(ID, szAxes, pdComponents, pdValueArray)
    ccall((:PI_qTRA, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}, Ptr{Cdouble}), ID, szAxes, pdComponents, pdValueArray)
end

function PI_qKLC(ID, szNameOfCoordSystem1, szNameOfCoordSystem2, szItem1, szItem2, buffer, bufsize)
    ccall((:PI_qKLC, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Cint), ID, szNameOfCoordSystem1, szNameOfCoordSystem2, szItem1, szItem2, buffer, bufsize)
end

function PI_KCP(ID, szSource, szDestination)
    ccall((:PI_KCP, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}), ID, szSource, szDestination)
end

function PI_TGA(ID, piTrajectoriesArray, pdValarray, iArraySize)
    ccall((:PI_TGA, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cdouble}, Cint), ID, piTrajectoriesArray, pdValarray, iArraySize)
end

function PI_TGC(ID, piTrajectoriesArray, iArraySize)
    ccall((:PI_TGC, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Cint), ID, piTrajectoriesArray, iArraySize)
end

function PI_TGF(ID, piTrajectoriesArray, iArraySize)
    ccall((:PI_TGF, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Cint), ID, piTrajectoriesArray, iArraySize)
end

function PI_TGS(ID, piTrajectoriesArray, iArraySize)
    ccall((:PI_TGS, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Cint), ID, piTrajectoriesArray, iArraySize)
end

function PI_qTGL(ID, piTrajectoriesArray, iTrajectorySizesArray, iArraySize)
    ccall((:PI_qTGL, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Cint), ID, piTrajectoriesArray, iTrajectorySizesArray, iArraySize)
end

function PI_TGT(ID, iTrajectoryTiming)
    ccall((:PI_TGT, PI_GCS2), BOOL, (Cint, Cint), ID, iTrajectoryTiming)
end

function PI_qTGT(ID, iTrajectoryTiming)
    ccall((:PI_qTGT, PI_GCS2), BOOL, (Cint, Ptr{Cint}), ID, iTrajectoryTiming)
end

function PI_FSF(ID, szAxis, forceValue1, positionOffset, useForceValue2, forceValue2)
    ccall((:PI_FSF, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cdouble, Cdouble, BOOL, Cdouble), ID, szAxis, forceValue1, positionOffset, useForceValue2, forceValue2)
end

function PI_qFSF(ID, szAxes, pForceValue1Array, pPositionOffsetArray, pForceValue2Array)
    ccall((:PI_qFSF, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}), ID, szAxes, pForceValue1Array, pPositionOffsetArray, pForceValue2Array)
end

function PI_qFSR(ID, szAxes, pbValueArray)
    ccall((:PI_qFSR, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{BOOL}), ID, szAxes, pbValueArray)
end

function PI_GetSupportedParameters(ID, piParameterIdArray, piCommandLevelArray, piMemoryLocationArray, piDataTypeArray, piNumberOfItems, iiBufferSize, szParameterName, iMaxParameterNameSize)
    ccall((:PI_GetSupportedParameters, PI_GCS2), BOOL, (Cint, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Cint, Ptr{Cchar}, Cint), ID, piParameterIdArray, piCommandLevelArray, piMemoryLocationArray, piDataTypeArray, piNumberOfItems, iiBufferSize, szParameterName, iMaxParameterNameSize)
end

function PI_GetSupportedControllers(szBuffer, iBufferSize)
    ccall((:PI_GetSupportedControllers, PI_GCS2), BOOL, (Ptr{Cchar}, Cint), szBuffer, iBufferSize)
end

function PI_GetAsyncBufferIndex(ID)
    ccall((:PI_GetAsyncBufferIndex, PI_GCS2), Cint, (Cint,), ID)
end

function PI_GetAsyncBuffer(ID, pdValueArray)
    ccall((:PI_GetAsyncBuffer, PI_GCS2), BOOL, (Cint, Ptr{Ptr{Cdouble}}), ID, pdValueArray)
end

function PI_AddStage(ID, szAxes)
    ccall((:PI_AddStage, PI_GCS2), BOOL, (Cint, Ptr{Cchar}), ID, szAxes)
end

function PI_RemoveStage(ID, szStageName)
    ccall((:PI_RemoveStage, PI_GCS2), BOOL, (Cint, Ptr{Cchar}), ID, szStageName)
end

function PI_OpenUserStagesEditDialog(ID)
    ccall((:PI_OpenUserStagesEditDialog, PI_GCS2), BOOL, (Cint,), ID)
end

function PI_OpenPiStagesEditDialog(ID)
    ccall((:PI_OpenPiStagesEditDialog, PI_GCS2), BOOL, (Cint,), ID)
end

function PI_WriteConfigurationFromDatabaseToController(ID, szFilter, szConfigurationName, szWarnings, warningsBufferSize)
    ccall((:PI_WriteConfigurationFromDatabaseToController, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Cint), ID, szFilter, szConfigurationName, szWarnings, warningsBufferSize)
end

function PI_WriteConfigurationFromDatabaseToControllerAndSave(ID, szFilter, szConfigurationName, szWarnings, warningsBufferSize)
    ccall((:PI_WriteConfigurationFromDatabaseToControllerAndSave, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Cint), ID, szFilter, szConfigurationName, szWarnings, warningsBufferSize)
end

function PI_ReadConfigurationFromControllerToDatabase(ID, szFilter, szConfigurationName, szWarnings, warningsBufferSize)
    ccall((:PI_ReadConfigurationFromControllerToDatabase, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Cint), ID, szFilter, szConfigurationName, szWarnings, warningsBufferSize)
end

function PI_GetAvailableControllerConfigurationsFromDatabase(ID, szConfigurationNames, configurationNamesBufferSize)
    ccall((:PI_GetAvailableControllerConfigurationsFromDatabase, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cint), ID, szConfigurationNames, configurationNamesBufferSize)
end

function PI_GetAvailableControllerConfigurationsFromDatabaseByType(ID, szConfigurationNames, configurationNamesBufferSize, configurationType)
    ccall((:PI_GetAvailableControllerConfigurationsFromDatabaseByType, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cint, Cuint), ID, szConfigurationNames, configurationNamesBufferSize, configurationType)
end

function PI_IsAvailable(ID)
    ccall((:PI_IsAvailable, PI_GCS2), BOOL, (Cint,), ID)
end

function PI_GetDllVersionInformation(ID, dllVersionsInformationBuffer, bufferSize)
    ccall((:PI_GetDllVersionInformation, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cint), ID, dllVersionsInformationBuffer, bufferSize)
end

function PI_GetPIStages3VersionInformation(ID, piStages3VersionsInformationBuffer, bufferSize)
    ccall((:PI_GetPIStages3VersionInformation, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cint), ID, piStages3VersionsInformationBuffer, bufferSize)
end

function PI_POL(ID, szAxes, iValueArray)
    ccall((:PI_POL, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cint}), ID, szAxes, iValueArray)
end

function PI_STD(ID, tableType, tableID, data)
    ccall((:PI_STD, PI_GCS2), BOOL, (Cint, Cint, Cint, Ptr{Cchar}), ID, tableType, tableID, data)
end

function PI_RTD(ID, tableType, tableID, name)
    ccall((:PI_RTD, PI_GCS2), BOOL, (Cint, Cint, Cint, Ptr{Cchar}), ID, tableType, tableID, name)
end

function PI_qRTD(ID, tableType, tableID, infoID, buffer, bufsize)
    ccall((:PI_qRTD, PI_GCS2), BOOL, (Cint, Cint, Cint, Cint, Ptr{Cchar}, Cint), ID, tableType, tableID, infoID, buffer, bufsize)
end

function PI_qLST(ID, buffer, bufsize)
    ccall((:PI_qLST, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cint), ID, buffer, bufsize)
end

function PI_DLT(ID, name)
    ccall((:PI_DLT, PI_GCS2), BOOL, (Cint, Ptr{Cchar}), ID, name)
end

function PI_REC_START(ID, recorderIds)
    ccall((:PI_REC_START, PI_GCS2), BOOL, (Cint, Ptr{Cchar}), ID, recorderIds)
end

function PI_REC_STOP(ID, recorderIds)
    ccall((:PI_REC_STOP, PI_GCS2), BOOL, (Cint, Ptr{Cchar}), ID, recorderIds)
end

function PI_REC_RATE(ID, recorderId, rate)
    ccall((:PI_REC_RATE, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cint), ID, recorderId, rate)
end

function PI_qREC_RATE(ID, recorderIds, rateValues)
    ccall((:PI_qREC_RATE, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cint}), ID, recorderIds, rateValues)
end

function PI_REC_TRACE(ID, recorderId, traceId, containerUnitId, functionUnitId, parameterId)
    ccall((:PI_REC_TRACE, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cint, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}), ID, recorderId, traceId, containerUnitId, functionUnitId, parameterId)
end

function PI_REC_TRG(ID, recorderId, triggerMode, triggerOption1, triggerOption2)
    ccall((:PI_REC_TRG, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}), ID, recorderId, triggerMode, triggerOption1, triggerOption2)
end

function PI_qREC_NUM(ID, recorderIds, numDataValues)
    ccall((:PI_qREC_NUM, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cint}), ID, recorderIds, numDataValues)
end

function PI_qREC_STATE(ID, recorderIds, statesBuffer, statesBufferSize)
    ccall((:PI_qREC_STATE, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Cint), ID, recorderIds, statesBuffer, statesBufferSize)
end

function PI_qREC_TRG(ID, recorderIds, triggerConfigurationBuffer, triggerConfigurationBufferSize)
    ccall((:PI_qREC_TRG, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Cint), ID, recorderIds, triggerConfigurationBuffer, triggerConfigurationBufferSize)
end

function PI_qREC_TRACE(ID, recorderId, traceIndex, traceConfigurationBuffer, traceConfigurationBufferSize)
    ccall((:PI_qREC_TRACE, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cint, Ptr{Cchar}, Cint), ID, recorderId, traceIndex, traceConfigurationBuffer, traceConfigurationBufferSize)
end

function PI_qREC_DAT(ID, recorderId, dataFormat, offset, numberOfValue, traceIndices, numberOfTraceIndices, dataValues, gcsArrayHeaderBuffer, gcsArrayHeaderBufferSize)
    ccall((:PI_qREC_DAT, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Cint, Cint, Ptr{Cint}, Cint, Ptr{Ptr{Cdouble}}, Ptr{Cchar}, Cint), ID, recorderId, dataFormat, offset, numberOfValue, traceIndices, numberOfTraceIndices, dataValues, gcsArrayHeaderBuffer, gcsArrayHeaderBufferSize)
end

function PI_UCL(ID, userCommandLevel, password)
    ccall((:PI_UCL, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}), ID, userCommandLevel, password)
end

function PI_qUCL(ID, userCommandLevel, bufSize)
    ccall((:PI_qUCL, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cint), ID, userCommandLevel, bufSize)
end

function PI_qIPR(ID, szBuffer, iBufferSize)
    ccall((:PI_qIPR, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cint), ID, szBuffer, iBufferSize)
end

function PI_qUSG(ID, usg, bufSize)
    ccall((:PI_qUSG, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cint), ID, usg, bufSize)
end

function PI_qUSG_CMD(ID, chapter, usg, bufSize)
    ccall((:PI_qUSG_CMD, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Cint), ID, chapter, usg, bufSize)
end

function PI_qUSG_SYS(ID, chapter, usg, bufSize)
    ccall((:PI_qUSG_SYS, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Cint), ID, chapter, usg, bufSize)
end

function PI_qUSG_PAM(ID, chapter, usg, bufSize)
    ccall((:PI_qUSG_PAM, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Cint), ID, chapter, usg, bufSize)
end

function PI_qUSG_HW(ID, chapter, usg, bufSize)
    ccall((:PI_qUSG_HW, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Cint), ID, chapter, usg, bufSize)
end

function PI_qUSG_PROP(ID, chapter, usg, bufSize)
    ccall((:PI_qUSG_PROP, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Cint), ID, chapter, usg, bufSize)
end

function PI_qLOG(ID, startIndex, errorLog, bufSize)
    ccall((:PI_qLOG, PI_GCS2), BOOL, (Cint, Cint, Ptr{Cchar}, Cint), ID, startIndex, errorLog, bufSize)
end

function PI_SPV_Int32(ID, memType, containerUnit, functionUnit, parameter, value)
    ccall((:PI_SPV_Int32, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, INT32), ID, memType, containerUnit, functionUnit, parameter, value)
end

function PI_SPV_UInt32(ID, memType, containerUnit, functionUnit, parameter, value)
    ccall((:PI_SPV_UInt32, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, UINT32), ID, memType, containerUnit, functionUnit, parameter, value)
end

function PI_SPV_Int64(ID, memType, containerUnit, functionUnit, parameter, value)
    ccall((:PI_SPV_Int64, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, INT64), ID, memType, containerUnit, functionUnit, parameter, value)
end

function PI_SPV_UInt64(ID, memType, containerUnit, functionUnit, parameter, value)
    ccall((:PI_SPV_UInt64, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, UINT64), ID, memType, containerUnit, functionUnit, parameter, value)
end

function PI_SPV_Double(ID, memType, containerUnit, functionUnit, parameter, value)
    ccall((:PI_SPV_Double, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Cdouble), ID, memType, containerUnit, functionUnit, parameter, value)
end

function PI_SPV_String(ID, memType, containerUnit, functionUnit, parameter, value)
    ccall((:PI_SPV_String, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}), ID, memType, containerUnit, functionUnit, parameter, value)
end

function PI_qSPV(ID, memType, containerUnit, functionUnit, parameter, answer, bufSize)
    ccall((:PI_qSPV, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Cint), ID, memType, containerUnit, functionUnit, parameter, answer, bufSize)
end

function PI_qSPV_Int32(ID, memType, containerUnit, functionUnit, parameter, value)
    ccall((:PI_qSPV_Int32, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Ptr{INT32}), ID, memType, containerUnit, functionUnit, parameter, value)
end

function PI_qSPV_UInt32(ID, memType, containerUnit, functionUnit, parameter, value)
    ccall((:PI_qSPV_UInt32, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Ptr{UINT32}), ID, memType, containerUnit, functionUnit, parameter, value)
end

function PI_qSPV_Int64(ID, memType, containerUnit, functionUnit, parameter, value)
    ccall((:PI_qSPV_Int64, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Ptr{INT64}), ID, memType, containerUnit, functionUnit, parameter, value)
end

function PI_qSPV_UInt64(ID, memType, containerUnit, functionUnit, parameter, value)
    ccall((:PI_qSPV_UInt64, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Ptr{UINT64}), ID, memType, containerUnit, functionUnit, parameter, value)
end

function PI_qSPV_Double(ID, memType, containerUnit, functionUnit, parameter, value)
    ccall((:PI_qSPV_Double, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cdouble}), ID, memType, containerUnit, functionUnit, parameter, value)
end

function PI_qSPV_String(ID, memType, containerUnit, functionUnit, parameter, value, bufSize)
    ccall((:PI_qSPV_String, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Cint), ID, memType, containerUnit, functionUnit, parameter, value, bufSize)
end

function PI_CPA(ID, sourceMemType, targetMemType, containerUnit, functionUnit, parameter)
    ccall((:PI_CPA, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}), ID, sourceMemType, targetMemType, containerUnit, functionUnit, parameter)
end

function PI_qSTV(ID, containerUnit, statusArray)
    ccall((:PI_qSTV, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cuint}), ID, containerUnit, statusArray)
end

function PI_SAM(ID, axisContainerUnit, axisOperationMode)
    ccall((:PI_SAM, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Cuint), ID, axisContainerUnit, axisOperationMode)
end

function PI_qSAM(ID, axisContainerUnit, axesOperationModesArray)
    ccall((:PI_qSAM, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cuint}), ID, axisContainerUnit, axesOperationModesArray)
end

function PI_RES(ID, axisContainerUnit)
    ccall((:PI_RES, PI_GCS2), BOOL, (Cint, Ptr{Cchar}), ID, axisContainerUnit)
end

function PI_SMV(ID, axisContainerUnitsArray, numberOfStepsArray)
    ccall((:PI_SMV, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, axisContainerUnitsArray, numberOfStepsArray)
end

function PI_qSMV(ID, axisContainerUnit, commandedSteps)
    ccall((:PI_qSMV, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, axisContainerUnit, commandedSteps)
end

function PI_qSMR(ID, axisContainerUnit, remainingSteps)
    ccall((:PI_qSMR, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, axisContainerUnit, remainingSteps)
end

function PI_OCV(ID, axisContainerUnitsArray, controlValueArray)
    ccall((:PI_OCV, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, axisContainerUnitsArray, controlValueArray)
end

function PI_qOCV(ID, axisContainerUnit, controlValueArray)
    ccall((:PI_qOCV, PI_GCS2), BOOL, (Cint, Ptr{Cchar}, Ptr{Cdouble}), ID, axisContainerUnit, controlValueArray)
end

