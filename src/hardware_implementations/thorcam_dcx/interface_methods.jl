

function initialize(camera::ThorcamDCXCamera)
    dev_number = zeros(INT, 1)
    success = is_GetNumberOfCameras(dev_number)
    println("number of cameras: ", dev_number[1])
    if dev_number[1] == 0
        @error("No cameras found")
        return
    end
    hcam_ptr = zeros(HCAM, 1)
    success = is_InitCamera(hcam_ptr, C_NULL)
    if success != IS_SUCCESS
        @error("Failed to initialize camera")
        return
    end
    hcam = hcam_ptr[1]
    devInfo = Vector{BOARDINFO}(undef, 1)
    success = is_GetCameraInfo(hcam, devInfo)

    serial = join(filter(x -> x != '\0', map(Char, devInfo[1].SerNo)))
    model = devInfo[1].Type == IS_BOARD_TYPE_UC480_USB_LE
    println("Camera serial number: ", serial)

    sensor_info = Vector{SENSORINFO}(undef, 1)
    success = is_GetSensorInfo(hcam, sensor_info)

    maxWidth = INT(sensor_info[1].nMaxWidth)
    maxHeight = INT(sensor_info[1].nMaxHeight)
    pixelSize = INT(sensor_info[1].wPixelSize)/100 # um

    camera.camera_format = CameraFormat(maxWidth, maxHeight, pixelSize, 1, "CMOS")

    bitsPixel_ptr = zeros(INT, 1)
    colorMode_ptr = zeros(INT, 1)
    success = is_GetColorDepth(hcam, bitsPixel_ptr, colorMode_ptr)

    camera.bits_pixel = bitsPixel_ptr[1]
    camera.bytes_pixel = INT(bitsPixel_ptr[1] / 8)

    success = is_SetColorMode(hcam, IS_CM_RGBA8_PACKED)

    pixel_clock_range = zeros(UINT,3)
    success = is_PixelClock(hcam,IS_PIXELCLOCK_CMD_GET_RANGE,pixel_clock_range,sizeof(pixel_clock_range))
    println("Pixel clock range: ", pixel_clock_range[1], " - ", pixel_clock_range[2])
    # pixelClock = [INT(pixel_clock_range[1]+10)] # for MinFlux Project
    pixelClock = [INT(pixel_clock_range[2]-5)] # for Smart microscope Project
    # pixelClock = [INT(pixel_clock_range[2]-15)] # for Smart microscope Project
    # pixelClock = [INT(pixel_clock_range[1] + (pixel_clock_range[2] - pixel_clock_range[1]) ÷ 2)]  # Middle rangex
    success = is_PixelClock(hcam, IS_PIXELCLOCK_CMD_SET, pixelClock,sizeof(pixelClock))

    framerate = camera.frame_rate
    actual_framerate = zeros(Float64, 1)
    success = is_SetFrameRate(hcam, framerate, actual_framerate)
    camera.frame_rate = actual_framerate[1]

    camera.camera_handle = hcam;
end

function CameraInterface.capture(camera::ThorcamDCXCamera)

    setroi!(camera)
    setexposuretime!(camera)

    ppcImgMem = Ref(Ptr{Cchar}(C_NULL))  # Memory pointer (image buffer)
    pid = Ref(Cint(0))                   # Image ID
    Width = INT(camera.roi.width)
    Height = INT(camera.roi.height)
    success = is_AllocImageMem(camera.camera_handle, Width, Height, camera.bits_pixel, ppcImgMem, pid)
    success = is_SetImageMem(camera.camera_handle, ppcImgMem[], pid[])
    if success != IS_SUCCESS
        @error("Failed to allocate image memory")
        return
    end
    success = is_FreezeVideo(camera.camera_handle, IS_WAIT)
    if success != IS_SUCCESS
        @error("Failed to capture image")
        return
    end
    
    # get data
    camera.pImage_Mem = [ppcImgMem]
    camera.pImage_Id = [pid]
    data = getlastframe(camera)    

    # release memory
    success = is_FreeImageMem(camera.camera_handle, ppcImgMem[], pid[])
    
    return data
end

function CameraInterface.getlastframe(camera::ThorcamDCXCamera)
    Width = INT(camera.roi.width)
    Height = INT(camera.roi.height)

    img_vector = zeros(Cchar, Width * Height * camera.bytes_pixel);
    success = is_CopyImageMem(camera.camera_handle,camera.pImage_Mem[1][], camera.pImage_Id[1][], img_vector)
    if success != IS_SUCCESS
        @error("Failed to copy image memory")
        return
    end

    data = reshape(img_vector, (camera.bytes_pixel,Width, Height));
    data = data[1,:,:]

    return data
end


function CameraInterface.live(camera::ThorcamDCXCamera)
    setroi!(camera)
    setexposuretime!(camera)

    framenum = 1
    ppcImgMem = Vector{Any}(undef, framenum)
    pid = Vector{Any}(undef, framenum)
    Width = INT(camera.roi.width)
    Height = INT(camera.roi.height)

    for i in 1:framenum
        ppcImgMem[i] = Ref(Ptr{Cchar}(C_NULL))  # Memory pointer (image buffer)
        pid[i] = Ref(Cint(0))                   # Image ID
        success = is_AllocImageMem(camera.camera_handle, Width, Height,  camera.bits_pixel, ppcImgMem[i], pid[i])
        success = is_AddToSequence(camera.camera_handle, ppcImgMem[i][], pid[i][])
        if success != IS_SUCCESS
            @error("Failed to allocate image memory")
            return
        end
    end
    camera.pImage_Mem = ppcImgMem
    camera.pImage_Id = pid

    success = is_CaptureVideo(camera.camera_handle, IS_WAIT)
    if success != IS_SUCCESS
        @error("Failed to start live video")
        return
    end
    camera.is_running = 1
end

function CameraInterface.sequence(camera::ThorcamDCXCamera, nframes::Real)
    setroi!(camera)
    setexposuretime!(camera)
    camera.sequence_length = nframes
    framenum = INT(nframes)
    ppcImgMem = Vector{Any}(undef, framenum)
    pid = Vector{Any}(undef, framenum)
    Width = INT(camera.roi.width)
    Height = INT(camera.roi.height)

    for i in 1:framenum
        ppcImgMem[i] = Ref(Ptr{Cchar}(C_NULL))  # Memory pointer (image buffer)
        pid[i] = Ref(Cint(0))                   # Image ID
        success = is_AllocImageMem(camera.camera_handle, Width, Height,  camera.bits_pixel, ppcImgMem[i], pid[i])
        success = is_AddToSequence(camera.camera_handle, ppcImgMem[i][], pid[i][])
        if success != IS_SUCCESS
            @error("Failed to allocate image memory")
            return
        end
    end
    camera.pImage_Mem = ppcImgMem
    camera.pImage_Id = pid

    success = is_CaptureVideo(camera.camera_handle, IS_WAIT)
    if success != IS_SUCCESS
        @error("Failed to start sequence")
        return
    end
    camera.is_running = 1

    FrameCount = is_CameraStatus(camera.camera_handle, IS_SEQUENCE_CNT,IS_GET_STATUS)
    frameInterval = 1 / camera.frame_rate
    @async begin
        println("Starting sequence")
        while INT(FrameCount) < INT(nframes)
            sleep(frameInterval)
            FrameCount = is_CameraStatus(camera.camera_handle, IS_SEQUENCE_CNT,IS_GET_STATUS)
        end
        success = is_StopLiveVideo(camera.camera_handle, IS_WAIT)
        println("Sequence finished")
    end

end

function CameraInterface.sequence(camera::ThorcamDCXCamera)
    return CameraInterface.sequence(camera, camera.sequence_length)
end


function CameraInterface.getdata(camera::ThorcamDCXCamera)
    Width = camera.roi.width
    Height = camera.roi.height
    data = zeros(UInt8, Width, Height, camera.sequence_length)
    for i in 1:camera.sequence_length
        img_vector = zeros(Cchar, Width * Height * camera.bytes_pixel)
        success = is_CopyImageMem(camera.camera_handle, camera.pImage_Mem[i][], camera.pImage_Id[i][], img_vector)
        img = reshape(img_vector, (camera.bytes_pixel, Width, Height))
        data[:,:,i] = img[1,:,:]
    end

    # release Memory
    abort(camera)

    return data
end

function CameraInterface.abort(camera::ThorcamDCXCamera)
    success = is_StopLiveVideo(camera.camera_handle, IS_WAIT)
    for i in eachindex(camera.pImage_Mem)
        success = is_FreeImageMem(camera.camera_handle, camera.pImage_Mem[i][], camera.pImage_Id[i][])
    end
    camera.is_running = 0
end


function shutdown(camera::ThorcamDCXCamera)
    success = is_ExitCamera(camera.camera_handle)
    camera.is_running = 0
end

function setexposuretime!(camera::ThorcamDCXCamera)

    param = [camera.exposure_time*1e3]
    success = is_Exposure(camera.camera_handle, IS_EXPOSURE_CMD_SET_EXPOSURE, param ,UINT(8))
    param = Vector{Float64}(undef, 1)
    success = is_Exposure(camera.camera_handle, IS_EXPOSURE_CMD_GET_EXPOSURE, param ,UINT(8))
    camera.exposure_time = param[1]/1e3

end


function setroi!(camera::ThorcamDCXCamera)
    ROI = IS_RECT()
    ROI.s32X = INT(camera.roi.x_start)
    ROI.s32Y = INT(camera.roi.y_start)
    ROI.s32Width = INT(camera.roi.width)
    ROI.s32Height = INT(camera.roi.height)
    success = is_AOI(camera.camera_handle, IS_AOI_IMAGE_SET_AOI, Ref(ROI), sizeof(ROI))
    if success != IS_SUCCESS
        @error("Failed to set ROI")
        return
    end

    ROI =  IS_RECT()
    success = is_AOI(camera.camera_handle,IS_AOI_IMAGE_GET_AOI,Ref(ROI),sizeof(ROI))
    camera.roi.x_start = ROI.s32X
    camera.roi.y_start = ROI.s32Y
    camera.roi.width = ROI.s32Width
    camera.roi.height = ROI.s32Height

    framerate = camera.frame_rate
    actual_framerate = zeros(Float64, 1)
    success = is_SetFrameRate(camera.camera_handle, framerate, actual_framerate)
    camera.frame_rate = actual_framerate[1]

end

function export_state(camera::ThorcamDCXCamera)
    attributes = Dict(
        "unique_id" => camera.unique_id,
        "camera_format_x_pixels" => camera.camera_format.x_pixels,
        "camera_format_y_pixels" => camera.camera_format.y_pixels,
        "camera_format_pixelsize" => camera.camera_format.pixelsize,
        "camera_format_gain" => camera.camera_format.gain,
        "exposure_time" => camera.exposure_time,
        "frame_rate" => camera.frame_rate,
        "roi_x" => camera.roi.x_start,
        "roi_y" => camera.roi.y_start,
        "roi_width" => camera.roi.width,
        "roi_height" => camera.roi.height,
        "sequence_length" => camera.sequence_length,
        "is_running" => camera.is_running,
        "bits_pixel" => camera.bits_pixel,
        "bytes_pixel" => camera.bytes_pixel,
    )
    data = nothing
    children = Dict()
    return attributes, data, children
end