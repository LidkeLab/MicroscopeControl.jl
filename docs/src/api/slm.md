# Spatial light modulators

```@meta
CurrentModule = MicroscopeControl
```

A spatial light modulator is a subtype of `SLM`, which is not an `AbstractInstrument`. `[limitation]` The
interface's display functions (`displayimage`, `displayzernike`, `displayblaze`) do not work on any SLM today;
their docstrings say why. The Meadowlark driver, `MLSLM`, is driven with its own pattern generators and SDK calls,
documented below.

## SLM interface

```@autodocs
Modules = [HardwareInterfaces.SLMInterface]
Order = [:module, :type, :function, :constant, :macro]
Filter = t -> Main.mc_public(t)
```

## Meadowlark SLM

```@autodocs
Modules = [HardwareImplementations.Meadowlark]
Order = [:module, :type, :function, :constant, :macro]
Filter = t -> Main.mc_public(t)
```

## SLM internals

```@autodocs
Modules = [HardwareInterfaces.SLMInterface, HardwareImplementations.Meadowlark]
Filter = t -> Main.mc_internal(t)
```
