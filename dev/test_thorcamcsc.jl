using Revise
using MicroscopeControl
using MicroscopeControl.HardwareImplementations.ThorCamCSC

cam = ThorCamCSCCamera()
initialize(cam)

gui(cam)

cam.exposure_time = 10000 # μs
cam.roi.x_start = 100 # index starts at 0, should be multiple of 4
cam.roi.y_start = 200 # index starts at 0, should be multiple of 4
cam.roi.width = 400 # should be multiple of 4
cam.roi.height = 500 # should be multiple of 4

data = capture(cam);

# run the following three lines together
sequence_length = 10
sequence(cam,sequence_length)
data = getdata(cam);

abort(cam)

shutdown(cam)