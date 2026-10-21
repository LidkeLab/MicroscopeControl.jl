# `MCLStage.initialize` against a fake Madlib.
#
# There is no Madlib library on any build machine. As in `dcam4_fake_sdk.jl`, the wrappers `initialize` reaches
# (`inithandle`, `singleread`, `getcalibration`) are replaced by methods with the identical signature, so the
# driver's own `initialize` runs against a table of axis positions. The replacements are global and permanent for the
# process, which is why runtests.jl includes this file last. It says nothing about the DLL or the real stage.
module FakeMCL
"The position each axis reads, in microns."
const positions = Dict(1 => 10.0, 2 => 20.0, 3 => 30.0)
"The calibrated range each axis reports."
const ranges = Dict(1 => 100.0, 2 => 100.0, 3 => 50.0)
end

@eval MicroscopeControl.HardwareImplementations.MadCityLabs begin
    function inithandle(stage::MCLStage)
        stage.id = 1
        stage.connectionstatus = true
        return 1
    end
    function singleread(stage::MCLStage, axis::Int)
        position = Main.FakeMCL.positions[axis]
        axis == 1 && (stage.real_x = position)
        axis == 2 && (stage.real_y = position)
        axis == 3 && (stage.real_z = position)
        return position
    end
    function getcalibration(stage::MCLStage, axis::Int)
        top = Main.FakeMCL.ranges[axis]
        axis == 1 && (stage.range_x = (0.0, top))
        axis == 2 && (stage.range_y = (0.0, top))
        axis == 3 && (stage.range_z = (0.0, top))
        return top
    end
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
