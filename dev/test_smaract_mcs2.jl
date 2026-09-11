#=
Bring-up script for the SmarAct SOM-MS-8070 stage on an MCS2 controller.

Run it a block at a time in the REPL rather than all at once - several steps
move the stage. Make sure the stage can travel freely before referencing or
calibrating.

All positions are in microns.
=#

using Revise
using MicroscopeControl
using MicroscopeControl.HardwareImplementations.SmarActMCS2

# --- 1. Check the SDK and find the controller -------------------------------
# `mcs2version` only needs SmarActCTL.dll; an empty device list means the
# controller is not powered on or not connected.
mcs2version()
findmcs2devices()

# --- 2. Connect -------------------------------------------------------------
# Leaving `locator` empty uses the first controller found. Pass one from
# findmcs2devices() when more than one is attached.
stage = MCS2Stage()
initialize(stage)

deviceinfo(stage)

# Which axes have sensors, calibration data and a valid position reference?
hassensor(stage)
iscalibrated(stage)
isreferenced(stage)

# --- 3. Calibrate (once per mechanical setup) -------------------------------
# Only needed if iscalibrated(stage) is false, e.g. after changing positioner
# type. MOVES THE STAGE by up to several mm - do not start near an end stop.
# The result is stored in the controller and survives a power cycle.
#
#   calibrate(stage)

# --- 4. Reference (once per controller power cycle) -------------------------
# The sensors are incremental, so absolute position is unknown until this runs.
# MOVES THE STAGE until it finds the reference mark on each axis.
findreference(stage)

isreferenced(stage)
getposition(stage)

# --- 5. Set up travel limits ------------------------------------------------
# The MCS2 cannot report the mechanical travel of a positioner, so the defaults
# on MCS2Stage are a guess based on the SOM-MS-8070 datasheet (51 mm x, 46 mm y)
# assuming the reference mark sits at mid travel. Confirm the real limits by
# jogging carefully to each end, then write them into the controller so it
# enforces them itself:
#
#   setrangelimits!(stage, :x, (-25_000.0, 25_000.0))
#   setrangelimits!(stage, :y, (-22_500.0, 22_500.0))
getrange(stage)

# --- 6. Move ----------------------------------------------------------------
setvelocity!(stage, 1000.0)        # um/s
setacceleration!(stage, 10_000.0)  # um/s^2

# Non-blocking by default; pass wait=true or call waitformotion to block.
move(stage, 100.0, 100.0; wait=true)
getposition(stage)

moverelative(stage, 10.0, -10.0; wait=true)
getposition(stage)

moveaxis(stage, :x, 0.0; wait=true)

# Define the current position as the origin for this sample
#   zeroposition!(stage)

home(stage; wait=true)             # back to (0, 0)

stopmotion(stage)                  # abort a move, or release the position hold

# --- 7. GUI -----------------------------------------------------------------
# `gui` is ambiguous at the top level because each hardware interface defines
# its own, so call the stage one explicitly.
MicroscopeControl.HardwareInterfaces.StageInterface.gui(stage)

# --- 8. Disconnect ----------------------------------------------------------
shutdown(stage)
