# Instruments and saving

```@meta
CurrentModule = MicroscopeControl
```

The types and functions every device shares, the system types for composing devices into an instrument, HDF5
saving of an exported state, and the Claude Code skill installer.

`export_state` returns `(attributes, data, children)`: `attributes` is a `Dict` of settings keyed by name, `data` is
`nothing` or an array, and `children` is a `Dict` whose values are further `(attributes, data, children)` tuples.
Most drivers return `Dict{String,Any}`s, but not all (`NIdaq`'s are narrower), so do not dispatch on the
concrete type. [`save_h5`](@ref) writes that tree as nested HDF5 groups under `Main`; it returns a `Task`, so
`wait` it before reading the file.

## Instruments and systems

```@autodocs
Modules = [MicroscopeControl]
Order = [:module, :type, :function, :constant, :macro]
Filter = t -> Main.mc_public(t) && t !== save_h5 && t !== save_attributes_and_data &&
              t !== install_skills && t !== uninstall_skills && t !== list_skills
```

## Saving to HDF5

```@docs
save_h5
save_attributes_and_data
```

## Claude Code skills

```@docs
install_skills
uninstall_skills
list_skills
```

## Internals

Helpers that are not public: the GUI and HDF5 helpers, the shared-library paths (each can be overridden with an
environment variable, `MICROSCOPECONTROL_LIBDCAM` or `MICROSCOPECONTROL_LIBMADLIB`), and the containers that
re-export the interfaces and drivers.

```@autodocs
Modules = [MicroscopeControl]
Filter = t -> Main.mc_internal(t)
```

```@autodocs
Modules = [MicroscopeControl.Libraries, MicroscopeControl.HardwareInterfaces,
           MicroscopeControl.HardwareImplementations]
```
