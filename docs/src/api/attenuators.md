# Attenuators

```@meta
CurrentModule = MicroscopeControl
```

An attenuator is a subtype of `Attenuator`: a device whose transmission is set by a drive voltage. The interface
sets and reads the voltage (`setdrivevoltage`, `getdrivevoltage`) or the transmission (`settransmission`,
`gettransmission`), converting between them through a calibration table set with `set_calibration!`. The
`LCC1620` takes its drive voltage from a DAC channel of a `Triggerscope4` (see [Triggerscope](@ref)), which several
attenuators can share.

## Attenuator interface

```@autodocs
Modules = [HardwareInterfaces.AttenuatorInterface]
Order = [:module, :type, :function, :constant, :macro]
Filter = t -> Main.mc_public(t)
```

## Thorlabs LCC1620 liquid crystal attenuator

```@autodocs
Modules = [HardwareImplementations.LCC1620Attenuator]
Order = [:module, :type, :function, :constant, :macro]
Filter = t -> Main.mc_public(t)
```

## Attenuator internals

```@autodocs
Modules = [HardwareInterfaces.AttenuatorInterface, HardwareImplementations.LCC1620Attenuator]
Filter = t -> Main.mc_internal(t)
```
