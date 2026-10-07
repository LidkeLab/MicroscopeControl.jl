# Electro-optic deflector, through the beam-steering interface.
# Setup, write a voltage, read it back -- in DAQ volts and in crystal volts.

using Revise
using MicroscopeControl
using MicroscopeControl.HardwareImplementations.Triggerscope

# ── Setup: EOD on the NI card, through the HVA200 amplifiers ────────────────
# Wiring (from voltage_supply_beam_char.jl):
#   Dev2/ao0 -> HVA1 -> EOD X crystal
#   Dev2/ao1 -> HVA2 -> EOD Y crystal
# The HVA200 has a gain of 20 and inverts, so 1 V out of the card is -20 V on the crystal.
backend = DAQmxBackend("Dev2/ao0", "Dev2/ao1"; vmin = -10.0, vmax = 10.0)

# Limits are in DAQ volts, because that is what actually gets written.
# 7.5 V in -> 150 V on the crystal.
eod = EOD(backend;
    amplifier_gain = 20.0,
    invert = true,
    xlimits = (-7.5, 7.5),
    ylimits = (-7.5, 7.5),
    unique_id = "test EOD")

initialize(eod)                  # creates and starts one AO task per axis, parks at 0 V

# ── Write, in DAQ volts ─────────────────────────────────────────────────────
setvoltage(eod, 2.0, 0.0)        # 2 V out of the card
getvoltage(eod)                  # (2.0, 0.0)
getcrystalvoltage(eod)           # (-40.0, 0.0) -- the same thing, past the amplifier

# ── Write, in crystal volts ─────────────────────────────────────────────────
setcrystalvoltage(eod, 100.0, 0.0)   # 100 V across the crystal
getvoltage(eod)                      # (-5.0, 0.0) -- what the card is actually putting out
getcrystalvoltage(eod)               # (100.0, 0.0)

crystal_limits(eod)              # the DAQ limits expressed across the crystal, +/-150 V
amplifier_factor(eod)            # -20.0 crystal volts per DAQ volt

zeroaxes(eod)
getvoltage(eod)

# Out of range throws before anything reaches the hardware, and names both voltages:
setcrystalvoltage(eod, 1000.0, 0.0)
getvoltage(eod)                  # unchanged

# ── Angle, once a calibration is measured ───────────────────────────────────
# calibration_basis says which voltage the mrad/V matrix was measured against:
#   :crystal  mrad per volt ACROSS THE CRYSTAL -- what compute_angle_calibration in
#             "MINFLUX Project/angle_defle.jl" produces, since it works from the monitor
#   :daq      mrad per volt OUT OF THE CARD
# Getting this wrong is a silent factor-of-20 error on every angle. Default is :crystal.
eod.calibration = AngleCalibration(mrad_per_volt_x = 0.003, mrad_per_volt_y = 0.003)
eod.calibration_basis            # :crystal

setangle(eod, 0.3, 0.0)          # 0.3 mrad = 100 crystal V = -5 V out of the card
getangle(eod)                    # (0.3, 0.0)
getvoltage(eod)                  # (-5.0, 0.0)
getcrystalvoltage(eod)           # (100.0, 0.0)

shutdown(eod)                    # parks at 0 V, stops and clears the tasks

# ── The same EOD on the Triggerscope ────────────────────────────────────────
# Only the backend differs; every call above is unchanged.
#
# scope = Triggerscope4(portname = "COM5", protocol = MM_PROTOCOL)
# eod = EOD(TriggerscopeBackend(scope; x_channel = 3, y_channel = 4, range = PLUSMINUS10);
#     amplifier_gain = 20.0, invert = true,
#     xlimits = (-7.5, 7.5), ylimits = (-7.5, 7.5), unique_id = "test EOD (Triggerscope)")
# initialize(eod)
# setcrystalvoltage(eod, 100.0, 0.0)
# getcrystalvoltage(eod)
# shutdown(eod)
