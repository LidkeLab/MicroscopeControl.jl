# DAQ and FPGA boards

```@meta
CurrentModule = MicroscopeControl
```

A DAQ card is a subtype of `DAQ`. Its interface creates a task on a named channel (`createtask`), writes or reads a
voltage through that task (`setvoltage`, `readvoltage`) and deletes it (`deletetask`); `showdevices` and
`showchannels` list what the driver finds. `NIdaq` is the National Instruments driver, through DAQmx.jl, and
`NIDAQModulator` drives a light's analog input from one of its outputs.

The Opal Kelly XEM boards are not `DAQ`s and have no abstract type: `XEM` controls an FPGA board whose exposure
timing is selected through NI DAQ outputs, and `XEM_dac` uses one as a four-channel DAC.

## DAQ interface

```@autodocs
Modules = [HardwareInterfaces.DAQInterface]
Order = [:module, :type, :function, :constant, :macro]
Filter = t -> Main.mc_public(t)
```

## National Instruments DAQ

```@autodocs
Modules = [HardwareImplementations.NIDAQcard]
Order = [:module, :type, :function, :constant, :macro]
Filter = t -> Main.mc_public(t)
```

## Opal Kelly XEM FPGA

```@autodocs
Modules = [HardwareImplementations.OK_XEM]
Order = [:module, :type, :function, :constant, :macro]
Filter = t -> Main.mc_public(t)
```

## Opal Kelly XEM as a DAC

```@autodocs
Modules = [HardwareImplementations.XEM_DAC]
Order = [:module, :type, :function, :constant, :macro]
Filter = t -> Main.mc_public(t)
```

## DAQ internals

```@autodocs
Modules = [HardwareInterfaces.DAQInterface, HardwareImplementations.NIDAQcard, HardwareImplementations.OK_XEM,
           HardwareImplementations.XEM_DAC]
Filter = t -> Main.mc_internal(t)
```
