# Cameras

```@meta
CurrentModule = MicroscopeControl
```

A camera is a subtype of `Camera`. Exposure time and region of interest live in the camera's `exposure_time` and
`roi::CameraROI` fields; a driver's setters (`setexposuretime!`, `setroi!`, `settriggermode!`) push them to the
hardware. Every frame is a `(height, width)` array indexed `[y, x]`, and a sequence is `(height, width, frames)`
(see [Image layout](@ref)).

The acquisition calls are `capture` (one frame), `live` (a continuous view read with `getlastframe`), `sequence`
(a fixed number of frames read with `getdata`) and `abort`. Their blocking behavior, timeouts and return values
differ between drivers; each driver's docstrings below state its own.

## Camera interface

```@autodocs
Modules = [HardwareInterfaces.CameraInterface]
Order = [:module, :type, :function, :constant, :macro]
Filter = t -> Main.mc_public(t)
```

## Simulated camera

```@autodocs
Modules = [HardwareImplementations.SimulatedCamera]
Order = [:module, :type, :function, :constant, :macro]
Filter = t -> Main.mc_public(t)
```

## Hamamatsu cameras (DCAM-API)

```@autodocs
Modules = [HardwareImplementations.DCAM4]
Order = [:module, :type, :function, :constant, :macro]
Filter = t -> Main.mc_public(t)
```

## Thorlabs scientific cameras (CS series)

```@autodocs
Modules = [HardwareImplementations.ThorCamCSC]
Order = [:module, :type, :function, :constant, :macro]
Filter = t -> Main.mc_public(t)
```

## Thorlabs DCx cameras (uc480)

```@autodocs
Modules = [HardwareImplementations.ThorCamDCx]
Order = [:module, :type, :function, :constant, :macro]
Filter = t -> Main.mc_public(t)
```

## Camera internals

Helpers the interface and the drivers define but do not export: the shared GUI loop, the row-major conversion
every driver calls, and each driver's SDK bindings.

```@autodocs
Modules = [HardwareInterfaces.CameraInterface, HardwareImplementations.SimulatedCamera,
           HardwareImplementations.DCAM4, HardwareImplementations.ThorCamCSC, HardwareImplementations.ThorCamDCx]
Filter = t -> Main.mc_internal(t)
```
