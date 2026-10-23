using Revise
using MicroscopeControl
using MicroscopeControl.HardwareImplementations.IDSCam

# IDS Peak Comfort camera smoke test.  The camera must be connected and
# available with read/write access in IDS Peak Cockpit before running this.
cam = IDSCamera()
initialize(cam)

# The generic camera GUI is inherited through `CameraInterface.gui`.
# Close its control window before allowing this script to call `shutdown(cam)`.
gui(cam)

#try
    # Settings use seconds and pixels, matching the package camera interface.
    cam.exposure_time = 0.01
    setexposuretime!(cam)

    # Single-frame acquisition.
    single_frame = capture(cam)
    @assert size(single_frame) == (cam.roi.height, cam.roi.width)

    # Continuous acquisition; `getlastframe` copies and releases the SDK frame.


    live(cam)
    live_frame = getlastframe(cam)
    @assert size(live_frame) == size(single_frame)
    abort(cam)

    # Finite sequence acquisition.
    cam.sequence_length = 10
    sequence(cam)
    sequence_data = getdata(cam)
    @assert size(sequence_data) == (cam.roi.height, cam.roi.width, cam.sequence_length)

    
#finally
    # Close the device and leave the global IDS library in a clean state.
    shutdown(cam)
#end
