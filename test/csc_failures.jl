# All vendor operations capture/sequence can reach are replaced, including the raw pending-frame call.
module FakeCSC
const raw = UInt16[100y + x for y in 1:6 for x in 1:8]
const polls = Ref(0)
const missing = Ref(0)
const sdk_error = Ref(Cint(0))
const exposure_error = Ref(Cint(0))
const timeout_error = Ref(Cint(0))
const exposures = Int64[]
const timeouts = Cint[]
end
@eval MicroscopeControl.HardwareImplementations.ThorCamCSC begin
    function _sdk_pending_frame(handle, image, count, metadata, metadata_size)
        F = Main.FakeCSC
        F.polls[] += 1
        # SDK success with a null image after the polling wait is the documented timeout result.
        if F.polls[] == F.missing[]
            sleep((isempty(F.timeouts) ? 5 : F.timeouts[end]) / 1000)
            image[] = C_NULL
        else
            image[] = pointer(F.raw)
        end
        return F.sdk_error[]
    end
    function _sdk_set_exposure(handle::Ptr{Cvoid}, value::Clonglong)
        push!(Main.FakeCSC.exposures, value)
        return Main.FakeCSC.exposure_error[]
    end
    function _sdk_set_poll_timeout(handle::Ptr{Cvoid}, value::Cint)
        push!(Main.FakeCSC.timeouts, value)
        return Main.FakeCSC.timeout_error[]
    end
    thorcamsdkinit() = Cint(0)
    discoveravaliablecameras!(id::Vector{UInt8}, max_length::Cint) = Cint(0)
    opencamera(id::Vector{UInt8}) = (Cint(0), Ptr{Cvoid}(C_NULL))
    setoperationmode(camera::ThorCamCSCCamera) = Cint(0)
    setframespertrigger(camera::ThorCamCSCCamera) = Cint(0)
    setframespertrigger!(camera::ThorCamCSCCamera, value::Cint) = Cint(0)
    armcamera(camera::ThorCamCSCCamera) = Cint(0)
    issuesoftwaretrigger(camera::ThorCamCSCCamera) = Cint(0)
end

@testset "M5: CSC missing frames and exposure" begin
    CSC = MicroscopeControl.HardwareImplementations.ThorCamCSC
    CI = MicroscopeControl.HardwareInterfaces.CameraInterface
    F = Main.FakeCSC
    # Constructor SDK operations are replaced above. Omit poll_timeout to test automatic timeouts.
    cam = CSC.ThorCamCSCCamera(camera_format=CameraFormat(8, 6, 1, 0, "CMOS"),
        roi=CameraROI(3, 2, 4, 3), sequence_length=3, capture_mode=CSC.SEQUENCE)
    @test CSC.ThorCamCSCCamera(exposure_time=Int64(3_000_000)).poll_timeout == 7000
    for missing in 1:3
        F.polls[] = 0; F.missing[] = missing
        @test_throws "sequence frame $missing of 3" getdata(cam)
        @test F.polls[] == missing
        @test cam.last_error == CSC.FRAME_POLL_TIMEOUT
    end
    F.polls[] = 0; F.missing[] = 1
    @test getlastframe(cam) === nothing
    @test cam.last_error == CSC.FRAME_POLL_TIMEOUT
    F.polls[] = 0
    @test_throws "capture frame" capture(cam)
    @test cam.last_error == CSC.FRAME_POLL_TIMEOUT
    F.missing[] = 0
    @test capture(cam) == [100y + x for y in 2:4, x in 3:6]
    @test cam.last_error == 0
    cam.capture_mode = CSC.SEQUENCE
    @test size(getdata(cam)) == (3, 4, 3)
    F.sdk_error[] = Cint(7)
    @test_logs (:error, "Frame not collected") @test_throws "frame 1 of 3" getdata(cam)
    @test cam.last_error == 7
    F.sdk_error[] = Cint(0)

    F.exposure_error[] = Cint(9)
    before = (cam.exposure_time, cam.poll_timeout)
    @test_throws "set exposure" setexposuretime!(cam, Int64(2_000_000))
    @test (cam.exposure_time, cam.poll_timeout) == before
    @test cam.last_error == 9
    F.exposure_error[] = Cint(0)
    @test setexposuretime!(cam, Int64(2_000_000)) == 0
    @test cam.exposure_time == 2_000_000
    @test cam.poll_timeout == 5000
    @test F.timeouts[end] == 5000
    @test CSC.exposure_poll_timeout(40) == 1001
    @test CSC.exposure_poll_timeout(typemax(Int64)) == typemax(Cint)
    @test_throws ArgumentError CSC.exposure_poll_timeout(-1)
    cam.exposure_time = 3_000_000
    capture(cam)
    @test F.timeouts[end] == 7000
end

@testset "r7b: CSC explicit and automatic poll timeouts" begin
    CSC = MicroscopeControl.HardwareImplementations.ThorCamCSC
    F = Main.FakeCSC
    F.missing[] = 0
    F.sdk_error[] = F.exposure_error[] = F.timeout_error[] = Cint(0)
    camera(; kw...) = CSC.ThorCamCSCCamera(; camera_format=CameraFormat(8, 6, 1, 0, "CMOS"),
        roi=CameraROI(3, 2, 4, 3), kw...)

    # Both are valid explicit SDK timeouts, including one equal to the initial automatic value.
    for timeout in (Cint(9000), Cint(1001))
        cam = camera(poll_timeout=timeout)
        for start in (capture, c -> sequence(c, 2), live)
            start(cam)
            @test cam.poll_timeout == timeout
            @test F.timeouts[end] == timeout
        end
        setexposuretime!(cam, Int64(2_000_000))
        @test cam.poll_timeout == timeout
        @test F.timeouts[end] == timeout
    end

    cam = camera()
    CSC.setpolltimeout!(cam, Cint(9000))
    capture(cam)
    @test cam.poll_timeout == 9000
    @test F.timeouts[end] == 9000
    setexposuretime!(cam, Int64(3_000_000))
    @test cam.poll_timeout == 9000

    # Direct assignment is an existing public usage, even if it matches the initial default.
    for timeout in (Cint(9000), Cint(1001))
        assigned = camera()
        assigned.poll_timeout = timeout
        for start in (capture, c -> sequence(c, 2), live)
            start(assigned)
            @test assigned.poll_timeout == timeout
            @test F.timeouts[end] == timeout
        end
        setexposuretime!(assigned, Int64(3_000_000))
        @test assigned.poll_timeout == timeout
        @test F.timeouts[end] == timeout
    end

    # Preserve the original positional constructor: its supplied timeout is explicit too.
    positional = CSC.ThorCamCSCCamera(C_NULL, 40, Cint(9000), UInt8[0x31], Cint(5),
        CameraFormat(8, 6, 1, 0, "CMOS"), Cint(2), Cint(0), Cint(1), Cint(30),
        CameraROI(3, 2, 4, 3), 3, CSC.SINGLE_FRAME, CSC.SOFTWARE_TRIGGER, Cint(0), Cint(0), 0)
    capture(positional)
    @test positional.poll_timeout == 9000

    automatic = camera()
    for (exposure, timeout) in ((40, 1001), (1_000_000, 3000), (3_000_000, 7000))
        automatic.exposure_time = exposure
        capture(automatic)
        @test automatic.poll_timeout == timeout
        @test F.timeouts[end] == timeout
    end
end

@testset "r7b: refused CSC timeout writes preserve the cache" begin
    CSC = MicroscopeControl.HardwareImplementations.ThorCamCSC
    F = Main.FakeCSC
    cam = CSC.ThorCamCSCCamera()
    before = cam.poll_timeout
    F.timeout_error[] = Cint(1) # Nonzero SDK failure, rather than an impossible timeout value.
    @test_throws "set poll timeout" setexposuretime!(cam, Int64(2_000_000))
    @test cam.exposure_time == 2_000_000 # The preceding exposure write succeeded.
    @test cam.poll_timeout == before
    @test cam.last_error == 1
    @test_throws "set poll timeout" CSC.setpolltimeout!(cam, Cint(9000))
    @test cam.poll_timeout == before
    F.timeout_error[] = Cint(0)
    CSC.setexposuretime(cam)
    @test cam.poll_timeout == 5000 # A refused explicit write did not switch away from automatic.
    CSC.setpolltimeout!(cam, Cint(9000))
    F.timeout_error[] = Cint(1)
    @test_throws "set poll timeout" CSC.setpolltimeout!(cam, Cint(8000))
    @test cam.poll_timeout == 9000
    F.timeout_error[] = Cint(0)
    capture(cam)
    @test cam.poll_timeout == 9000
end
