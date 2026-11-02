# The two single-line lights share every write-and-record operation.
initialize(light::DaqTrLight) = NIDAQcard._single_line_off!(light)
shutdown(light::DaqTrLight) = NIDAQcard._single_line_off!(light)
LightSourceInterface.setpower(light::DaqTrLight, voltage::Float64) = NIDAQcard._single_line_setpower!(light, voltage)
LightSourceInterface.light_on(light::DaqTrLight) = NIDAQcard._single_line_on!(light)
LightSourceInterface.light_off(light::DaqTrLight) = NIDAQcard._single_line_off!(light)
LightSourceInterface._power_settings(light::DaqTrLight) = NIDAQcard._voltage_panel_settings(light)
export_state(light::DaqTrLight) = NIDAQcard._voltage_light_state(light)
