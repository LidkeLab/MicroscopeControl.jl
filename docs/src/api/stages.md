# Stages

```@meta
CurrentModule = MicroscopeControl
```

A stage is a subtype of `Stage`. `move` commands a position, `getposition` reads it, `getrange` reports the travel
of each axis, and `stopmotion` halts a move where the driver implements it (`MCLStage`'s only logs an error). The
number of axes, the position units and whether `move` waits for the stage to arrive differ between drivers; each
driver's docstrings below state its own. A stage's `export_state` records `position_fresh::Bool`: on a hardware
stage, true when the export read every axis from the hardware; on a simulated stage, always true.

## Stage interface

```@autodocs
Modules = [HardwareInterfaces.StageInterface]
Order = [:module, :type, :function, :constant, :macro]
Filter = t -> Main.mc_public(t)
```

## Simulated stages

```@autodocs
Modules = [HardwareImplementations.SimulatedStage]
Order = [:module, :type, :function, :constant, :macro]
Filter = t -> Main.mc_public(t)
```

## Mad City Labs Nano-Drive

```@autodocs
Modules = [HardwareImplementations.MadCityLabs]
Order = [:module, :type, :function, :constant, :macro]
Filter = t -> Main.mc_public(t)
```

## PI C-867 (GCS2)

```@autodocs
Modules = [HardwareImplementations.PI]
Order = [:module, :type, :function, :constant, :macro]
Filter = t -> Main.mc_public(t)
```

## PI N-472

```@autodocs
Modules = [HardwareImplementations.PI_N472]
Order = [:module, :type, :function, :constant, :macro]
Filter = t -> Main.mc_public(t)
```

## SmarAct MCS2

```@autodocs
Modules = [HardwareImplementations.MCS2Stage_mod]
Order = [:module, :type, :function, :constant, :macro]
Filter = t -> Main.mc_public(t)
```

## Stage internals

Helpers the interface and the drivers define but do not export, including each driver's SDK bindings.

```@autodocs
Modules = [HardwareInterfaces.StageInterface, HardwareImplementations.SimulatedStage,
           HardwareImplementations.MadCityLabs, HardwareImplementations.PI, HardwareImplementations.PI_N472,
           HardwareImplementations.MCS2Stage_mod]
Filter = t -> Main.mc_internal(t)
```
