using Pkg
Pkg.activate("C:\\Users\\krai\\.julia\\dev\\MicroscopeControl.jl")
using MicroscopeControl

stage = MCS2Stage(
    stagelabel = "SmarAct MCS2",
    n_channels = 3,
    channel_ids = Int32[0, 1, 2],
)

# initialize(stage)   # this is the step that would need real hardware — skip/comment out for now

MicroscopeControl.HardwareInterfaces.StageInterface.gui(stage)