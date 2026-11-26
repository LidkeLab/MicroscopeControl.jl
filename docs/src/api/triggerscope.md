# Triggerscope

```@meta
CurrentModule = MicroscopeControl
```

`Triggerscope4` drives an Advanced Research Consulting Triggerscope 4 over a serial port: analog DAC outputs, each
with a selectable voltage range, and TTL outputs (16 of each by default), set directly (`setdac`, `setttl`) or
programmed as a triggered sequence (the `prog*` functions, then `arm`). `[limitation]` Parts of sequence
programming do not work today: `progttl` throws after sending its command and `progarray` cannot complete; their
docstrings say why. Its abstract type, `TRIG`, describes channel groups for
the shared control panel and is not an `AbstractInstrument`. An `LCC1620` attenuator takes its drive voltage from
one of its DAC channels.

## Trigger controller interface

```@autodocs
Modules = [HardwareInterfaces.TrigInterface]
Order = [:module, :type, :function, :constant, :macro]
Filter = t -> Main.mc_public(t)
```

## Triggerscope 4

```@autodocs
Modules = [HardwareImplementations.Triggerscope]
Order = [:module, :type, :function, :constant, :macro]
Filter = t -> Main.mc_public(t)
```

## Triggerscope internals

The channel functions the control panel calls, the serial helpers of the driver, and `reset`, a user command that
lands here because it extends `Base.reset` rather than a MicroscopeControl name.

```@autodocs
Modules = [HardwareInterfaces.TrigInterface, HardwareImplementations.Triggerscope]
Filter = t -> Main.mc_internal(t)
```
