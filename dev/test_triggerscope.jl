# Triggerscope as a beam-steering backend.
# Setup, write a voltage, read it back -- for a galvo and an EOD on the same board.

using Revise
using MicroscopeControl
using MicroscopeControl.HardwareImplementations.Triggerscope

scope = Triggerscope4(portname = "COM5", protocol = MM_PROTOCOL)

# ── Ranges and step size (no hardware needed) ───────────────────────────────
# The DAC is 16 bit over the selected range, so the finest step it can address is
# range_span / 65535. A narrower range gives finer steps for free.
rangelimits(PLUSMINUS10)                                            # (-10.0, 10.0)
rangelimits(PLUSMINUS2_5)                                           # (-2.5, 2.5)

min_voltage_step(TriggerscopeBackend(scope; range = PLUSMINUS10))   # ~305 uV
min_voltage_step(TriggerscopeBackend(scope; range = PLUSMINUS2_5))  # ~76 uV

# ── One device on its own board ─────────────────────────────────────────────
# owns_device defaults to true: initialize(galvo) opens the serial port and
# shutdown(galvo) closes it.
galvo = Galvo(TriggerscopeBackend(scope; x_channel = 1, y_channel = 2, range = PLUSMINUS10);
    xlimits = (-2.0, 2.0), ylimits = (-2.0, 2.0), unique_id = "galvo (Triggerscope)")

initialize(galvo)
setvoltage(galvo, 0.2, -0.2)
getvoltage(galvo)
shutdown(galvo)

# ── Two devices sharing one board ───────────────────────────────────────────
# Pass owns_device = false to both and open the port yourself, otherwise whichever
# device you shut down first closes the port out from under the other.
scope = Triggerscope4(portname = "COM5", protocol = MM_PROTOCOL)

galvo = Galvo(TriggerscopeBackend(scope; x_channel = 1, y_channel = 2,
        range = PLUSMINUS10, owns_device = false);
    xlimits = (-2.0, 2.0), ylimits = (-2.0, 2.0), unique_id = "galvo (shared)")

eod = EOD(TriggerscopeBackend(scope; x_channel = 3, y_channel = 4,
        range = PLUSMINUS10, owns_device = false);
    amplifier_gain = 20.0, invert = true,
    xlimits = (-7.5, 7.5), ylimits = (-7.5, 7.5), unique_id = "EOD (shared)")

initialize(scope)        # you own the port now, not the devices
initialize(galvo)
initialize(eod)

# Write
setvoltage(galvo, 0.2, -0.2)
setcrystalvoltage(eod, 100.0, 0.0)

# Read
getvoltage(galvo)
getvoltage(eod)
getcrystalvoltage(eod)

shutdown(galvo)
shutdown(eod)
shutdown(scope)          # the port closes here, after both devices are parked

# ── Raw DAC access, for comparison ──────────────────────────────────────────
# The backend uses these underneath. Driving them directly bypasses the devices' limit
# checks and their record of where they are, so prefer the device calls above.
#
# initialize(scope)
# setrange(scope, 1, PLUSMINUS10)
# setdac(scope, 1, 0.2)
# shutdown(scope)
