using Pkg
Pkg.activate("C:\\Users\\nanol\\.julia\\dev\\MicroscopeControl.jl")
using MicroscopeControl

stage = MCS2Stage(
    stagelabel = "SmarAct MCS2",
    n_channels = 3,
    channel_ids = Int32[0, 1, 2],
)

initialize(stage)

stage.range_x = (-20_000.0, 20_000.0)   # µm, since these fields are in micrometres, software limits only, not hardware limits. The hardware limits are in the device's firmware and cannot be changed from software.
stage.range_y = (-20_000.0, 20_000.0)

MicroscopeControl.HardwareInterfaces.StageInterface.gui(stage)