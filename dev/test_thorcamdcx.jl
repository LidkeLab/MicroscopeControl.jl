using Revise
using MicroscopeControl

# Test the saving function of Red Laser
using MicroscopeControl.HardwareImplementations.ThorCamDCx

cam = ThorcamDCXCamera()
initialize(cam)

gui(cam)

cam.exposure_time = 0.01 # s
cam.roi.x_start = 100
cam.roi.y_start = 100
cam.roi.width = 200
cam.roi.height = 300

data = capture(cam);


cam.sequence_length = 10
sequence(cam)
data = getdata(cam);

abort(cam)

shutdown(cam)
