# All vendor operations capture/sequence can reach are replaced, including the raw pending-frame call.
module FakeCSC
const raw = UInt16[100y + x for y in 1:6 for x in 1:8]
const polls = Ref(0)
const missing = Ref(0)
const sdk_error = Ref(Cint(0))
const exposure_error = Ref(Cint(0))
const exposures = Int64[]
const timeouts = Cint[]
end
@eval MicroscopeControl.HardwareImplementations.ThorCamCSC begin
    function _sdk_pending_frame(handle, image, count, metadata, metadata_size)
        F = Main.FakeCSC
        F.polls[] += 1
        image[] = F.polls[] == F.missing[] ? C_NULL : pointer(F.raw)
        return F.sdk_error[]
    end
    function _sdk_set_exposure(handle::Ptr{Cvoid}, value::Clonglong)
        push!(Main.FakeCSC.exposures, value)
        return Main.FakeCSC.exposure_error[]
    end
    function _sdk_set_poll_timeout(handle::Ptr{Cvoid}, value::Cint)
        push!(Main.FakeCSC.timeouts, value)
        return Cint(0)
    end
    setoperationmode(camera::ThorCamCSCCamera) = Cint(0)
    setframespertrigger(camera::ThorCamCSCCamera) = Cint(0)
    setframespertrigger!(camera::ThorCamCSCCamera, value::Cint) = Cint(0)
    armcamera(camera::ThorCamCSCCamera) = Cint(0)
    issuesoftwaretrigger(camera::ThorCamCSCCamera) = Cint(0)
end

@testset "M5/S6/S7: CSC missing frames, exposure, and export (p5)" begin
    CSC = MicroscopeControl.HardwareImplementations.ThorCamCSC
    CI = MicroscopeControl.HardwareInterfaces.CameraInterface
    F = Main.FakeCSC
    # Positional construction bypasses SDK initialization; the public keyword constructor opens hardware.
    cam = CSC.ThorCamCSCCamera(C_NULL, 40, Cint(1000), UInt8[0x31], Cint(5), CameraFormat(8, 6, 1, 0, "CMOS"),
        Cint(2), Cint(0), Cint(1), Cint(30), CameraROI(3, 2, 4, 3), 3, CSC.SEQUENCE,
        CSC.SOFTWARE_TRIGGER, Cint(0), Cint(0), 0)
    for missing in 1:3
        F.polls[] = 0; F.missing[] = missing
        @test_throws "sequence frame $missing of 3" getdata(cam)
        @test F.polls[] == missing
        @test cam.last_error == CSC.FRAME_POLL_TIMEOUT
    end
    F.polls[] = 0; F.missing[] = 1
    @test getlastframe(cam) == zeros(UInt16, 3, 4)
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
    a, data, children = export_state(cam)
    @test a["roi_origin"] == 1
    @test a["roi_x"] == 3 && a["roi_height"] == 3
    @test a["exposure_time"] == 3_000_000 && a["exposure_time_unit"] == "us"
    @test data === nothing && isempty(children)
    mktempdir() do dir
        path = joinpath(dir, "csc.h5")
        wait(save_h5(path, export_state(cam)))
        HDF5.h5open(path) do file
            @test HDF5.read_attribute(file["Main"], "roi_origin") == 1
            @test HDF5.read_attribute(file["Main"], "exposure_time") == 3_000_000
        end
    end
end
