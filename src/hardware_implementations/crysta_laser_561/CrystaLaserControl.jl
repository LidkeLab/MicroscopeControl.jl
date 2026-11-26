"""
    CrystaLaserControl

A Module for controlling a laser through a NIDAQ card.
"""
module CrystaLaserControl

using ...MicroscopeControl.HardwareInterfaces.DAQInterface: DAQ

using ...MicroscopeControl.HardwareInterfaces.LightSourceInterface
using ...MicroscopeControl.HardwareImplementations.NIDAQcard

import ...MicroscopeControl: export_state, initialize, shutdown
import ...MicroscopeControl.HardwareInterfaces.LightSourceInterface: gui as laser_561_gui
import ...MicroscopeControl.HardwareImplementations.NIDAQcard: gui as nidaq_gui

export CrystaLaser, laser_561_gui, nidaq_gui, light_on, light_off, setpower #, initialize

"""
    laser_561_gui(light::LightSource) -> GLMakie.Screen

The same function as `gui`, under the name this module exports for its light. For a `CrystaLaser` it opens
a panel in the light's own power unit and range and returns its `GLMakie.Screen`; opening the panel issues no
command. Closing the panel does not switch the light off. Needs a display (GLMakie).
"""
laser_561_gui

"""
    nidaq_gui(device)

Another name for `gui`, the one function every device's control panel is a method of.
`CrystaLaserControl`, `VortranLaserControl` and `TransmissionDaqControl` each export it next to their light type,
so `nidaq_gui(card)` on an `NIdaq` opens the DAQ card's panel and `nidaq_gui(light)` opens the light's. Needs a
display (GLMakie).
"""
nidaq_gui

include("types.jl")
include("interface_methods.jl")

end