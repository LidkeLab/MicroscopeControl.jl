include("MCS2Stage_module.jl")

using .MCS2Stage_mod

# Create a stage object — edit these to match your hardware
stage = MCS2Stage(
    stagelabel = "SmarAct MCS2",
    n_channels = 3,                          # change to 1, 2, or 3
    channel_ids = Int32[0, 1, 2],            # which physical channels to use
    velocity_pm_s = fill(Int64(1_000_000_000), 3),   # 1 mm/s
    accel_pm_s2   = fill(Int64(10_000_000_000), 3),  # 10 mm/s²
)

# Connect to the device and configure it
initialize!(stage)

# Open the GUI window
gui(stage)