# The two single-line lights share every write-and-record operation.
initialize(light::CrystaLaser) = NIDAQcard._single_line_off!(light)
shutdown(light::CrystaLaser) = NIDAQcard._single_line_off!(light)
LightSourceInterface.setpower(light::CrystaLaser, voltage::Float64) = NIDAQcard._single_line_setpower!(light, voltage)
LightSourceInterface.light_on(light::CrystaLaser) = NIDAQcard._single_line_on!(light)
LightSourceInterface.light_off(light::CrystaLaser) = NIDAQcard._single_line_off!(light)
LightSourceInterface._power_settings(light::CrystaLaser) = NIDAQcard._voltage_panel_settings(light)
export_state(light::CrystaLaser) = NIDAQcard._voltage_light_state(light)
