# Thorlabs compact scientific camera

module ThorCamCSC

using ...MicroscopeControl.HardwareInterfaces.CameraInterface

import ...MicroscopeControl: export_state, initialize, shutdown

export ThorCamCSC, gui #, shutdown
export getlastframe, capture, live, sequence, abort, getdata
export set_exposuretime, set_triggermode, set_roi

# include statements




end

