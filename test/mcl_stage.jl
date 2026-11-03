# `MCLStage.initialize` against a fake Madlib.
#
# There is no Madlib library on any build machine. As in `dcam4_fake_sdk.jl`, the wrappers `initialize` reaches
# (`inithandle`, `_mcl_read`, `_mcl_calibration`) are replaced by methods with the identical signature, so the
# driver's own `initialize` runs against a table of axis positions. The replacements are global and permanent for the
# process, which is why runtests.jl includes this file last. It says nothing about the DLL or the real stage.
module FakeMCL
"The position each axis reads, in microns."
const positions = Dict(1 => 10.0, 2 => 20.0, 3 => 30.0)
"The calibrated range each axis reports."
const write_codes = Dict(1 => Cint(0), 2 => Cint(0), 3 => Cint(0))
const ranges = Dict(1 => 100.0, 2 => 100.0, 3 => 50.0)
end

@eval MicroscopeControl.HardwareImplementations.MadCityLabs begin
    function inithandle(stage::MCLStage)
        stage.id = 1
        stage.connectionstatus = true
        return 1
    end
    _mcl_read(axis::Int, id::Int) = Main.FakeMCL.positions[axis]
    _mcl_read_z(id::Int) = Main.FakeMCL.positions[3]
    _mcl_calibration(axis::Int, id::Int) = Main.FakeMCL.ranges[axis]
    _mcl_write(position::Float64, axis::Int, id::Int) = Main.FakeMCL.write_codes[axis]
    _mcl_write_z(position::Float64, id::Int) = Main.FakeMCL.write_codes[3]

end

@testset "MCLStage initialize (fake Madlib)" begin
    stage = MicroscopeControl.HardwareImplementations.MadCityLabs.MCLStage()
    @test (stage.targ_x, stage.targ_y, stage.targ_z) == (0.0, 0.0, 0.0)
    @test MicroscopeControl.initialize(stage) == 1
    # The 3D panel's step buttons move to (targ_x, targ_y, targ_z): the targets start where the stage is, so the
    # first X step leaves Y and Z where they are.
    @test (stage.targ_x, stage.targ_y, stage.targ_z) == (10.0, 20.0, 30.0)
    @test (stage.real_x, stage.real_y, stage.real_z) == (10.0, 20.0, 30.0)
    @test stage.range_z == (0.0, 50.0)
end

@testset "S5: MCL errors never become positions or accepted targets" begin
    MCL = MicroscopeControl.HardwareImplementations.MadCityLabs
    for axis in 1:3
        stage = MCL.MCLStage(real_x=11.0, real_y=22.0, real_z=33.0,
                             targ_x=11.0, targ_y=22.0, targ_z=33.0)
        old = FakeMCL.positions[axis]
        FakeMCL.positions[axis] = -5.0
        @test_throws "MCL_DEV_NOT_READY" MCL.singleread(stage, axis)
        @test (stage.real_x, stage.real_y, stage.real_z) == (11.0, 22.0, 33.0)
        @test_throws "MCL_DEV_NOT_READY" initialize(stage)
        @test (stage.targ_x, stage.targ_y, stage.targ_z) == (11.0, 22.0, 33.0)
        FakeMCL.positions[axis] = old

        accepted_range = getfield(stage, (:range_x, :range_y, :range_z)[axis])
        old = FakeMCL.ranges[axis]
        FakeMCL.ranges[axis] = -8.0
        @test_throws "MCL_INVALID_HANDLE" MCL.getcalibration(stage, axis)
        @test getfield(stage, (:range_x, :range_y, :range_z)[axis]) == accepted_range
        FakeMCL.ranges[axis] = old

        FakeMCL.write_codes[axis] = Cint(-5)
        @test_throws "MCL_DEV_NOT_READY" MCL.singlewrite(stage, axis, 50.0)
        @test (stage.targ_x, stage.targ_y, stage.targ_z) == (11.0, 22.0, 33.0)
        FakeMCL.write_codes[axis] = Cint(0)
        @test MCL.singlewrite(stage, axis, 50.0) == "MCL_SUCCESS"
        @test getfield(stage, (:targ_x, :targ_y, :targ_z)[axis]) == 50.0
    end
    stage = MCL.MCLStage(real_z=12.0, targ_z=13.0)
    FakeMCL.positions[3] = -7.0
    @test_throws "MCL_INVALID_AXIS" MCL.singlereadZ(stage)
    @test stage.real_z == 12.0
    FakeMCL.positions[3] = 30.0
    FakeMCL.write_codes[3] = Cint(-5)
    @test_throws "MCL_DEV_NOT_READY" MCL.singlewriteZ(stage, 20.0)
    @test stage.targ_z == 13.0
    FakeMCL.write_codes[3] = Cint(0)
end
