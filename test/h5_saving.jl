@testset "S6/S7: cached driver exports and HDF5 round trips (no SDK)" begin
    ML = MicroscopeControl.HardwareImplementations.Meadowlark
    CSC = MicroscopeControl.HardwareImplementations.ThorCamCSC
    DC = MicroscopeControl.HardwareImplementations.DCAM4
    slm = MLSLM(width=4, height=3, pixelsize=2.0, wavelength=0.5,
        pupil=ML.Pupil(1, 2, 3, 4), phase=fill(1.0, 3, 4), offset=fill(2.0, 3, 4),
        sequence=ML.Sequence(phase=fill(3.0, 3, 4, 2), offset=fill(4.0, 3, 4, 2)))
    # Positional construction bypasses SDK initialization; the keyword camera constructors open hardware.
    cam = CSC.ThorCamCSCCamera(C_NULL, 3_000_000, Cint(1000), UInt8[0x31], Cint(5),
        CameraFormat(8, 6, 1, 0, "CMOS"), Cint(2), Cint(0), Cint(1), Cint(30),
        CameraROI(3, 2, 4, 3), 3, CSC.SEQUENCE, CSC.SOFTWARE_TRIGGER, Cint(9), Cint(7), 0)
    dcam = DC.DCAM4Camera("fake", CameraFormat(8, 6, 1, 1, "SCMOS"), C_NULL, 0.01, 10.0,
        CameraROI(2, 1, 4, 3), DC.SINGLE_FRAME, DC.DCAMPROP_TRIGGER_MODE__NORMAL, 2,
        DC.DCAMERR_SUCCESS, false, 0, zeros(UInt16, 3, 4), NaN, 0)

    a, data, children = export_state(slm)
    @test a["width"] == 4 && a["height"] == 3
    @test a["pixelsize"] == 2.0 && a["wavelength"] == 0.5
    @test (a["pupil_x_center"], a["pupil_y_center"], a["pupil_x_radius"], a["pupil_y_radius"]) == (1, 2, 3, 4)
    @test a["bit_depth"] == 12 && a["n_boards_found"] == 0 && a["constructed_ok"] == 1
    @test a["is_nematic_type"] == a["ram_write_enable"] == a["use_gpu"] == 1
    @test a["max_transient_frames"] == 10
    @test all(v -> v isa Number, values(a))
    @test data === nothing
    @test isempty(children)

    a, data, children = export_state(cam)
    @test a["unique_id"] == cam.unique_id && a["unique_id"] !== cam.unique_id
    @test a["camera_format_x_pixels"] == 8 && a["camera_format_y_pixels"] == 6
    @test a["roi_origin"] == 1
    @test (a["roi_x"], a["roi_y"], a["roi_width"], a["roi_height"]) == (3, 2, 4, 3)
    @test a["exposure_time"] == 3_000_000 && a["exposure_time_unit"] == "us"
    @test a["poll_timeout_ms"] == 1000
    @test a["capture_mode"] == Int(CSC.SEQUENCE) && a["trigger_mode"] == Int(CSC.SOFTWARE_TRIGGER)
    @test a["sequence_length"] == 3 && a["last_error"] == 9
    @test a["is_running"] == 0 && a["camera_state"] == 7
    @test data === nothing && isempty(children)

    a = export_state(dcam)[1]
    @test a["roi_origin"] == 0
    @test (a["roi_x"], a["roi_y"], a["roi_width"], a["roi_height"]) == (2, 1, 4, 3)

    mktempdir() do dir
        for (name, device) in (("slm", slm), ("csc", cam), ("dcam", dcam))
            path = joinpath(dir, name * ".h5")
            state = export_state(device)
            wait(save_h5(path, state))
            HDF5.h5open(path) do file
                group = file["Main"]
                @test isempty(keys(group)) # attributes only: no data or child groups
                @test Set(keys(HDF5.attrs(group))) == Set(keys(state[1]))
                for (key, value) in state[1]
                    @test HDF5.read_attribute(group, key) == value
                end
            end
        end
    end
end
