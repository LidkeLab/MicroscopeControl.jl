# Light sources

```@meta
CurrentModule = MicroscopeControl
```

A light source is a subtype of `LightSource` and carries `properties::LightSourceProperties`: the power unit, the
requested power, whether it is on, and the allowed range. `setpower` sets the level, `light_on` and `light_off`
switch it, and [`lights_off`](@ref) switches off a set of lights, attempting every one even after a failure.

A regulated laser diode is a `DiodeLaser`, typed by the quantity its controller holds: `ConstantCurrent` or
`ConstantPhotocurrent`, fixed at construction. It is set with `setcurrent!` (mA), `setoutputpower!` (mW at the
laser output) or `setlevel!` (0 to 1 of the declared range), and read back with `measured_current`,
`measured_photocurrent`, `indicated_output_power` and `loop_status`; `setpower` throws on a `DiodeLaser`. The
closed-loop calibration of the TCube driver is described in
[`CALIBRATION.md`](https://github.com/LidkeLab/MicroscopeControl.jl/blob/main/src/hardware_implementations/tcube_laser/CALIBRATION.md).

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

Helpers the interface and the drivers define but do not export: the modulator lifecycle, the diode-loop checks,
and the Kinesis SDK bindings of the TCube driver.

```@autodocs
Modules = [HardwareInterfaces.LightSourceInterface, HardwareImplementations.SimulatedLight,
           HardwareImplementations.SimulatedDiodeLaser, HardwareImplementations.TCubeLaserControl,
           HardwareImplementations.CrystaLaserControl, HardwareImplementations.VortranLaserControl,
           HardwareImplementations.TransmissionDaqControl]
Filter = t -> Main.mc_internal(t)
```
