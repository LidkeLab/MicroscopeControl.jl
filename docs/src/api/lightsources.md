# Light sources

```@meta
CurrentModule = MicroscopeControl
```

A light source is a subtype of `LightSource` and carries `properties::LightSourceProperties`: the power unit, the
requested power, whether it is on, and the allowed range. `setpower` sets the level, `light_on` and `light_off`
switch it, and [`lights_off`](@ref) calls `light_off` on every light in a set, even after one fails, then reports
every failure in one `LightsOffError` (a light whose switch-off failed may still be on).

A regulated laser diode is a `DiodeLaser`, typed by the quantity its controller holds: `ConstantCurrent` or
`ConstantPhotocurrent`, fixed at construction. It is set with `setcurrent!` (mA), `setoutputpower!` (mW at the
laser output) or `setlevel!` (0 to 1 of the declared range), and read back with `measured_current`,
`measured_photocurrent`, `indicated_output_power` and `loop_status`. `setpower` is deprecated on a `DiodeLaser`: on
a `ConstantCurrent` laser it forwards to `setcurrent!` (the value in mA) after a deprecation warning that Julia shows
only under `--depwarn=yes` (under `--depwarn=error` it throws instead, before forwarding), and on a
`ConstantPhotocurrent` laser it throws. The closed-loop calibration procedure of the TCube driver is in
`src/hardware_implementations/tcube_laser/CALIBRATION.md` in the repository.

A light can take a `modulator::AbstractModulationControl`, which puts its level on an analog input as a voltage;
`NIDAQModulator`, on the [DAQ and FPGA boards](@ref) page, is the DAQ implementation.

## Light source interface

```@autodocs
Modules = [HardwareInterfaces.LightSourceInterface]
Order = [:module, :type, :function, :constant, :macro]
Filter = t -> Main.mc_public(t)
```

## Simulated light

```@autodocs
Modules = [HardwareImplementations.SimulatedLight]
Order = [:module, :type, :function, :constant, :macro]
Filter = t -> Main.mc_public(t)
```

## Simulated laser diode

```@autodocs
Modules = [HardwareImplementations.SimulatedDiodeLaser]
Order = [:module, :type, :function, :constant, :macro]
Filter = t -> Main.mc_public(t)
```

## Thorlabs TLD001 laser diode controller (T-Cube)

```@autodocs
Modules = [HardwareImplementations.TCubeLaserControl]
Order = [:module, :type, :function, :constant, :macro]
Filter = t -> Main.mc_public(t)
```

## CrystaLaser 561 nm

```@autodocs
Modules = [HardwareImplementations.CrystaLaserControl]
Order = [:module, :type, :function, :constant, :macro]
Filter = t -> Main.mc_public(t)
```

## Vortran 488 nm

```@autodocs
Modules = [HardwareImplementations.VortranLaserControl]
Order = [:module, :type, :function, :constant, :macro]
Filter = t -> Main.mc_public(t)
```

## Transmitted light on a DAQ output

```@autodocs
Modules = [HardwareImplementations.TransmissionDaqControl]
Order = [:module, :type, :function, :constant, :macro]
Filter = t -> Main.mc_public(t)
```

## Light source internals

Helpers the interface and the drivers define but do not make public: the diode-loop checks, the modulator helpers
other than the public lifecycle functions (`open_modulator!`, `close_modulator!` and the rest are in the interface
section above), and the Kinesis SDK bindings of the TCube driver.

```@autodocs
Modules = [HardwareInterfaces.LightSourceInterface, HardwareImplementations.SimulatedLight,
           HardwareImplementations.SimulatedDiodeLaser, HardwareImplementations.TCubeLaserControl,
           HardwareImplementations.CrystaLaserControl, HardwareImplementations.VortranLaserControl,
           HardwareImplementations.TransmissionDaqControl]
Filter = t -> Main.mc_internal(t)
```
