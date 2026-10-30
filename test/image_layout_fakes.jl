# The drivers' image paths, against replaced SDK calls. Included after `dcam4_fake_paths.jl`, because the DCAM4 part
# needs `dcam4_fake_sdk.jl`; the ThorCam replacements below are likewise global and permanent for the process, and
# nothing else here calls them. Same helpers and the same non-square images as `image_layout.jl`.
@testset "Image layout: driver paths (fake SDK)" begin
    DC = MicroscopeControl.HardwareImplementations.DCAM4
    DCX = MicroscopeControl.HardwareImplementations.ThorCamDCx
    CSC = MicroscopeControl.HardwareImplementations.ThorCamCSC
    CameraInterface = MicroscopeControl.HardwareInterfaces.CameraInterface
    FK = Main.FakeDCAM

    @testset "DCAM4 dcambuf_getframe_err, through the fake properties" begin
        img = layout_image(3, 5)                        # width 5, height 3
        hdcam = Ptr{Cvoid}(UInt(0x100))
        setprops(width, height, rowbytes, type) = begin
            FK.values[Int32(DC.DCAM_IDPROP_IMAGE_WIDTH)] = width
            FK.values[Int32(DC.DCAM_IDPROP_IMAGE_HEIGHT)] = height
            FK.values[Int32(DC.DCAM_IDPROP_IMAGE_ROWBYTES)] = rowbytes
            FK.values[Int32(DC.DCAM_IDPROP_IMAGE_PIXELTYPE)] = Int32(type)
        end
        for stride in (5, 8)      # no padding, then 3 pad pixels (rowbytes = 16) per row
            FK.reset!()
            setprops(5, 3, 2stride, DC.DCAM_PIXELTYPE_MONO16)
            FK.frame[] = layout_rowmajor(img; stride)
            err, data = DC.dcambuf_getframe_err(hdcam, Int32(-1))
            @test err == DC.DCAMERR_SUCCESS
            @test size(data) == (3, 5)
            @test data == img
            @test isempty(FK.violations)
        end

        # The camera's own path: getdata in LIVE mode reads the newest frame through dcambuf_getframe_err
        FK.reset!()
        setprops(5, 3, 16, DC.DCAM_PIXELTYPE_MONO16)
        FK.frame[] = layout_rowmajor(img; stride = 8)
        cam = DC.DCAM4Camera("fake", DC.CameraFormat(1, 1, 1, 1, "SCMOS"), C_NULL, 0.01, 10.0,
            DC.CameraROI(0, 0, 1, 1), DC.LIVE, DC.DCAMPROP_TRIGGER_MODE__NORMAL, 2, DC.DCAMERR_SUCCESS,
            false, 0, zeros(UInt16, 1, 1), NaN, 0)
        @test CameraInterface.getdata(cam) == img

        # 8-bit pixels: rowbytes is the stride in elements
        FK.reset!()
        img8 = UInt8[10y + x for y in 1:2, x in 1:3]
        setprops(3, 2, 5, DC.DCAM_PIXELTYPE_MONO8)
        FK.frame[] = vec(permutedims(hcat(img8, fill(0xff, 2, 2))))
        err, data = DC.dcambuf_getframe_err(hdcam, Int32(0))
        @test data == img8

        # A pixel type the driver does not read
        FK.reset!()
        setprops(3, 2, 6, DC.DCAM_PIXELTYPE_NONE)
        @test_logs (:error, "Unsupported pixel type") begin
            err, data = DC.dcambuf_getframe_err(hdcam, Int32(0))
            @test err == DC.DCAMERR_INVALIDPIXELTYPE && data === nothing
        end

        # A failed copy
        FK.reset!()
        FK.codes["dcambuf_copyframe"] = DC.DCAMERR_NOTREADY
        @test_logs (:error, r"Failed to Copy Frame") match_mode = :any begin
            err, data = DC.dcambuf_getframe_err(hdcam, Int32(0))
            @test err == DC.DCAMERR_NOTREADY && data === nothing
        end
    end

    @testset "DCAM4 dcambuf_copyframe takes a Ptr as well as a Ref" begin
        @test Ptr{DC.DCAMBUF_FRAME} <: Ref{DC.DCAMBUF_FRAME}
        @test hasmethod(DC.dcambuf_copyframe, Tuple{Ptr{Cvoid}, Ptr{DC.DCAMBUF_FRAME}})
        FK.reset!()
        FK.frame[] = UInt16[1, 2, 3, 4]
        buf = zeros(UInt16, 4)
        dcf = DC.DCAMBUF_FRAME()
        dcf.rowbytes = Int32(4); dcf.height = Int32(2); dcf.buf = pointer(buf)
        GC.@preserve dcf buf begin
            err = DC.dcambuf_copyframe(Ptr{Cvoid}(UInt(0x100)), Ptr{DC.DCAMBUF_FRAME}(pointer_from_objref(dcf)))
        end
        @test err == DC.DCAMERR_SUCCESS
        @test buf == UInt16[1, 2, 3, 4]
    end

    @testset "ThorCam DCx getlastframe and getdata" begin
        img = UInt8[10y + x for y in 1:4, x in 1:6]     # roi width 6, height 4
        raw = vec(permutedims(img))                     # row-major, as the SDK copies it
        @eval DCX function is_CopyImageMem(hCam, pcSource, nID, pcDest)
            copyto!(pcDest, $raw)
            return IS_SUCCESS
        end
        cam = DCX.ThorcamDCXCamera()
        cam.roi = CameraROI(0, 0, 6, 4)
        cam.sequence_length = 2
        cam.pImage_Mem = [Ref(Ptr{Cchar}(C_NULL)) for _ in 1:2]
        cam.pImage_Id = [Ref(Cint(0)) for _ in 1:2]
        frame = CameraInterface.getlastframe(cam)
        @test size(frame) == (4, 6)
        @test frame == img
        @eval DCX is_StopLiveVideo(hCam, Wait) = IS_SUCCESS
        @eval DCX is_FreeImageMem(hCam, pcMem, id) = IS_SUCCESS
        stack = CameraInterface.getdata(cam)
        @test size(stack) == (4, 6, 2)
        @test stack[:, :, 1] == img && stack[:, :, 2] == img
    end

    @testset "ThorCam CSC reads the full sensor and crops to the ROI" begin
        # A sensor 8 wide and 6 tall; the camera always delivers all of it.
        csc_camera(roi) = CSC.ThorCamCSCCamera(C_NULL, 40, Cint(1000), UInt8[], Cint(5), CameraFormat(8, 6, 1, 0, "CMOS"),
            Cint(2), Cint(0), Cint(1), Cint(30), roi, 3, CSC.SINGLE_FRAME, CSC.SOFTWARE_TRIGGER,
            Cint(0), Cint(0), 0)
        full = layout_image(6, 8)
        raw = layout_rowmajor(full)
        reads = Ref(0)
        rawref = Ref(raw)
        # The SDK's call is replaced, but not the copy: the SDK's pointer goes through `copy_sensor_frame`
        @eval CSC function getlastframeornothing(camera::ThorCamCSCCamera)
            $reads[] += 1
            r = $rawref[]
            return GC.@preserve r copy_sensor_frame(camera, pointer(r))
        end

        # The copy takes the sensor's pixel count from camera_format, not from roi
        cam = csc_camera(CameraROI(3, 2, 4, 3))
        sdk = copy(raw)                                 # the SDK's buffer: the full sensor, 48 pixels
        copied = GC.@preserve sdk CSC.copy_sensor_frame(cam, pointer(sdk))
        @test length(copied) == 8 * 6
        @test copied == raw
        @test pointer(copied) != pointer(sdk)

        # The default ROI is the full frame
        cam = csc_camera(CameraROI(1, 1, 8, 6))
        @test CSC.frame_size(cam) == (6, 8)
        @test CameraInterface.getlastframe(cam) == full

        # An offset, non-square ROI (x_start = 3, y_start = 2, 4 wide, 3 tall) is exactly that sub-block
        cam = csc_camera(CameraROI(3, 2, 4, 3))
        @test CSC.frame_size(cam) == (3, 4)
        frame = CameraInterface.getlastframe(cam)
        @test size(frame) == (3, 4)
        @test frame == full[2:4, 3:6]
        @test frame[1, 1] == 203                         # row 2, column 3

        # A sequence follows the cropped size
        cam.capture_mode = CSC.SEQUENCE
        stack = CameraInterface.getdata(cam)
        @test size(stack) == (3, 4, 3)
        @test all(stack[:, :, i] == full[2:4, 3:6] for i in 1:3)

        # No frame yet: a zero frame of the ROI's shape
        @eval CSC getlastframeornothing(camera::ThorCamCSCCamera) = Nothing
        @test CameraInterface.getlastframe(cam) == zeros(UInt16, 3, 4)

        # An ROI outside the sensor (past an edge, or empty) throws before anything is read
        @eval CSC function getlastframeornothing(camera::ThorCamCSCCamera)
            $reads[] += 1
            r = $rawref[]
            return GC.@preserve r copy_sensor_frame(camera, pointer(r))
        end
        reads[] = 0
        for roi in (CameraROI(1, 1, 9, 6), CameraROI(1, 1, 8, 7), CameraROI(6, 1, 4, 3), CameraROI(1, 5, 4, 3),
                    CameraROI(0, 1, 4, 3), CameraROI(1, 0, 4, 3), CameraROI(1, 1, 0, 3), CameraROI(1, 1, 4, 0))
            cam = csc_camera(roi)
            @test_throws ArgumentError CSC.validate_roi(cam)
            @test_throws ArgumentError CameraInterface.getlastframe(cam)
        end
        @test reads[] == 0
        err = try CameraInterface.getlastframe(csc_camera(CameraROI(6, 1, 4, 3))) catch e e end
        msg = sprint(showerror, err)
        @test occursin("x_start = 6", msg) && occursin("8 x 6", msg)   # names the ROI and the sensor
    end
end
