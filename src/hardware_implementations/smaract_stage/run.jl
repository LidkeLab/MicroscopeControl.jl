using Pkg
Pkg.activate("C:\\Users\\nanol\\Documents\\GitHub\\MicroscopeControl.jl")
using MicroscopeControl

stage = MCS2Stage(
    stagelabel = "SmarAct MCS2",
    n_channels = 3,
    channel_ids = Int32[0, 1, 2],
)

initialize(stage)

MicroscopeControl.HardwareInterfaces.StageInterface.gui(stage)