using Revise
using CEnum
using CairoMakie
include("constants_uc480.jl")
include("functions_uc480.jl")

const uc480 = "C:\\Windows\\System32\\uc480_64.dll"


dev_number = zeros(INT,1)
success = is_GetNumberOfCameras(dev_number)

#dev_list = Vector{UC480_CAMERA_LIST}(undef, dev_number[1])

#success = is_GetCameraList(dev_list)



#serial = join(filter(x -> x != '\0', map(Char, dev_list[1].uci[1].SerNo)))

#model = join(filter(x -> x != '\0', map(Char, dev_list[1].uci[1].Model)))

#camId = dev_list[1].uci[1].dwCameraID
#devId = Int(dev_list[1].uci[1].dwDeviceID)

hcam_ptr = zeros(HCAM,1)
#hcam_ptr[1] = camId
success = is_InitCamera(hcam_ptr, C_NULL)
hcam = hcam_ptr[1]

devInfo = Vector{BOARDINFO}(undef, 1)
success = is_GetCameraInfo(hcam, devInfo)

serial = join(filter(x -> x != '\0', map(Char, devInfo[1].SerNo)))
model = devInfo[1].Type == IS_BOARD_TYPE_UC480_USB_LE


sensor_info = Vector{SENSORINFO}(undef, 1)
success=is_GetSensorInfo(hcam, sensor_info)

maxWidth = INT(sensor_info[1].nMaxWidth)
maxHeight = INT(sensor_info[1].nMaxHeight)
pixelSize = INT(sensor_info[1].wPixelSize) # nm

bitsPixel_ptr = zeros(INT, 1)
colorMode_ptr = zeros(INT, 1)
success = is_GetColorDepth(hcam, bitsPixel_ptr, colorMode_ptr)

bitspixel = bitsPixel_ptr[1]
bytespixel = INT(bitspixel / 8)


success = is_SetColorMode(hcam, IS_CM_RGBA8_PACKED)


param = Vector{UINT}(undef, 1)
success = is_Exposure(hcam, IS_EXPOSURE_CMD_GET_CAPS, param ,UINT(4))
param[1] & IS_EXPOSURE_CAP_EXPOSURE

param = Vector{Float64}(undef, 1)
success = is_Exposure(hcam, IS_EXPOSURE_CMD_GET_EXPOSURE, param ,UINT(8))
exposure = param[1]

param = Vector{Float64}(undef, 1)
success = is_Exposure(hcam, IS_EXPOSURE_CMD_GET_EXPOSURE_RANGE_MIN, param ,UINT(8))
min_exposure = param[1]

param = Vector{Float64}(undef, 1)
success = is_Exposure(hcam, IS_EXPOSURE_CMD_GET_EXPOSURE_RANGE_MAX, param ,UINT(8))
max_exposure = param[1]

param = [1.0]
success = is_Exposure(hcam, IS_EXPOSURE_CMD_SET_EXPOSURE, param ,UINT(8))

ROI =  IS_RECT()
success = is_AOI(hcam,IS_AOI_IMAGE_GET_AOI,Ref(ROI),sizeof(ROI))
ROI.s32X
ROI.s32Y
ROI.s32Width
ROI.s32Height


ROI = IS_RECT()
ROI.s32X = INT(100)
ROI.s32Y = INT(200)
ROI.s32Width = INT(200)
ROI.s32Height = INT(220)
success = is_AOI(hcam, IS_AOI_IMAGE_SET_AOI, Ref(ROI), sizeof(ROI))


timeout = INT(4000)
maxpixelclock = zeros(INT, 1)
maxframerate = zeros(Float64, 1)
success = is_SetOptimalCameraTiming(hcam,IS_BEST_PCLK_RUN_ONCE, timeout, maxpixelclock, maxframerate)

framerate = 20
actual_framerate = zeros(Float64, 1)
success = is_SetFrameRate(hcam, framerate, actual_framerate)


pixel_clock_range = zeros(UINT,3)
success = is_PixelClock(hcam,IS_PIXELCLOCK_CMD_GET_RANGE,pixel_clock_range,sizeof(pixel_clock_range))

pixelClock = [INT(35)]
success = is_PixelClock(hcam, IS_PIXELCLOCK_CMD_SET, pixelClock,sizeof(pixelClock))

# start capture
ppcImgMem = Ref(Ptr{Cchar}(C_NULL))  # Memory pointer (image buffer)
pid = Ref(Cint(0))                   # Image ID
Width = ROI.s32Width
Height = ROI.s32Height
success = is_AllocImageMem(hcam, Width, Height, bitspixel, ppcImgMem, pid)

success = is_SetImageMem(hcam, ppcImgMem[], pid[])


success = is_FreezeVideo(hcam, IS_WAIT)


img_vector = zeros(Cchar, Width * Height * bytespixel);
success = is_CopyImageMem(hcam,ppcImgMem[], pid[], img_vector)

#numlines = INT(1)
#success = is_CopyImageMemLines(hcam,ppcImgMem[], pid[], numlines, img_vector)


img = reshape(img_vector, (bytespixel,Width, Height));

success = is_FreeImageMem(hcam, ppcImgMem[], pid[])


# start live
framenum = 10
ppcImgMem = Vector{Any}(undef, framenum)
pid = Vector{Any}(undef, framenum)

for i in 1:framenum
    ppcImgMem[i] = Ref(Ptr{Cchar}(C_NULL))  # Memory pointer (image buffer)
    pid[i] = Ref(Cint(0))                   # Image ID
    success = is_AllocImageMem(hcam, maxWidth, maxHeight, bitspixel, ppcImgMem[i], pid[i])
    success = is_AddToSequence(hcam, ppcImgMem[i][], pid[i][])
end



#success = is_SetImageMem(hcam, ppcImgMem[], pid[])

success = is_CaptureVideo(hcam, IS_WAIT)

capStatusTnfo = Vector{UC480_CAPTURE_STATUS_INFO}(undef, 1)
success = is_CaptureStatus(hcam,IS_CAPTURE_STATUS_INFO_CMD_GET,capStatusTnfo,sizeof(capStatusTnfo))


capStatusTnfo[1].adwCapStatusCnt_Detail[INT(IS_CAP_STATUS_API_CONVERSION_FAILED)]

FrameCount = is_CameraStatus(hcam, IS_SEQUENCE_CNT,IS_GET_STATUS)

success = is_StopLiveVideo(hcam, IS_WAIT)


# get last frame
img_vector = zeros(Cchar, maxWidth * maxHeight * bytespixel);
success = is_CopyImageMem(hcam,ppcImgMem[end][], pid[end][], img_vector)
img = reshape(img_vector, (bytespixel,maxWidth, maxHeight));



for i in 1:framenum
    success = is_FreeImageMem(hcam, ppcImgMem[i][], pid[i][])
end





success = is_ExitCamera(hcam)