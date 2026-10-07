# Galvo mirror pair, through the beam-steering interface.
# Setup, write a voltage, read it back.

using Revise
using MicroscopeControl
using MicroscopeControl.HardwareImplementations.Triggerscope

# ── Setup: galvo on Triggerscope DAC 1 (X) and DAC 2 (Y) ────────────────────
scope = Triggerscope4(portname = "COM5", protocol = MM_PROTOCOL)

backend = TriggerscopeBackend(scope; x_channel = 1, y_channel = 2, range = PLUSMINUS10)

# xlimits/ylimits are the voltages the galvo refuses to exceed.
galvo = Galvo(backend; xlimits = (-2.0, 2.0), ylimits = (-2.0, 2.0), unique_id = "test galvo")

initialize(galvo)        # opens the serial port, parks both axes at 0 V

# ── Write ───────────────────────────────────────────────────────────────────
setvoltage(galvo, 0.2, -0.2)

# ── Read ────────────────────────────────────────────────────────────────────
getvoltage(galvo)        # (0.2, -0.2) -- last commanded, not a hardware readback

zeroaxes(galvo)
getvoltage(galvo)        # (0.0, 0.0)

# Out of range throws before anything reaches the hardware; the galvo does not move.
setvoltage(galvo, 5.0, 0.0)
getvoltage(galvo)        # unchanged

# ── Angle, once a calibration is measured ───────────────────────────────────
# The matrix is mrad per volt. Until it is measured it is the identity, so setangle reads
# the same as setvoltage.
galvo.calibration = AngleCalibration(mrad_per_volt_x = 0.45, mrad_per_volt_y = 0.42)

setangle(galvo, 0.5, 0.0)
getangle(galvo)          # (0.5, 0.0)
getvoltage(galvo)        # the volts that produced it

shutdown(galvo)          # parks at 0 V, closes the port

# ── The same galvo on the NI card ───────────────────────────────────────────
# Only the backend differs; every call above is unchanged.
#
# galvo = Galvo(DAQmxBackend("Dev2/ao0", "Dev2/ao1");
#     xlimits = (-2.0, 2.0), ylimits = (-2.0, 2.0), unique_id = "test galvo (NI)")
# initialize(galvo)
# setvoltage(galvo, 0.2, -0.2)
# getvoltage(galvo)
# shutdown(galvo)
