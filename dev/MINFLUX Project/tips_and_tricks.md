# Tips and Tricks for Operating the MINFLUX System
#### Written by Martin Zanazzi and Abigail Gatsch
As of July 2025 the microscope is in a state of development where it can be tricky to operate. Here is what we've learned in our summer of building and operating it.

## Set up
To turn on the microscope
1. Turn on the following equipment
    - The galvos
    - The laser key, its fan, and its "enable" button
    - The objective positioners if they are off
2. Start the Julia REPL and precompile MicroscopeControl.jl and necessary dependencies
3. Define the triggerscope and camera
    ```julia
    camera1 = ThorCamCSCCamera()
    camera2 = ThorcamDCXCamera()
    scope = Triggerscope4(compause = 2e-4)
    ```
    The compause is an important attribute of the triggerscope as it determines how quickly it can receive commands. Decreasing the compause increases the chance that the triggerscope resets because the serial port did not wait long enough for a hardware response. It can, however, make object tracking significantly more responsive.

    Additionally, each time the camera is shutdown, the ThorCamCSCCamera object must be reassigned to its variable before use. If you forget, it could result in a string of "frame not collected" errors. 
4. Zero the galvos by running the following commands in Julia
    ```julia
    initialize(scope)
    clearall(scope)
    setrange(scope, 1, PLUSMINUS10)
    setrange(scope, 2, PLUSMINUS10)
    setdac(scope, 1, 0.0)
    setdac(scope, 2, 0.0)
    ```
    Attempting to zero the scope in any other way could result in undefined behavior. Additionally, **many functions complete this step for you, and will throw errors if used after the scope was initialized.** To avoid this fate, simply shut down your scope if you were using it before calling the function by calling `shutdown(scope)` 

5. Check the beam quality in `beam_characterization.jl` by running beam_characterization(camera2) after placing the removable mirror in the optical path. Move the phase plate and mess with the aperture until the donut looks nice.

6. Calibrate the galvos using the lines of code commented out at the bottom of `galvo_calibration` if there is no saved matrix available. Two key words arguments of note are `margin` and `step_size`. Margin dictates how close to the edge of the screen the center dot will go before continuing to the next loop, and step_size determines how large each galvo voltage step will be. A smaller step size may result in a more accurate calibration matrix. When running `galvo_calibration` on a high density sample, the donut might get so distorted at the edges that the center tracking code can no longer do its job. In that case, increase the margin size. You'll still get a useable calibration matrix.

7. Run `test_track(scope, camera1, saved_calibration_matrix_CSC_1)` from `MINFLUX_TEST` in order to run the tracking program. In order to actually track a bead, the donut needs to have a good extinction ratio and be roughly symmetrical across all axes. You also need to center the donut around a bead so that no fluorescence is seen on camera before anything else. Try to find one that is isolated from others. Toggle tracking, and move the stage slowly. The teal dot should follow your movements as long as they aren't sudden.

8. Before leaving, just turn off the hardware and close GLMakie windows that utilize the camera. Make sure the objective is nice and clean.

#### Other Notes

There is still a lot of room for improvement for the tracking code. At the moment, the speed of the tracking pattern is limited by the frame rate of the camera. That's why we've cropped the region of interest so aggressively. You can change the region of interest with the screen_size parameter for `test_track`. 

There are a couple parameters for this code that we did not have the foresight to make variables in `test_track`. Most notably, the first argument in `find_scan_pattern` is the pattern radius in pixels. Messing around with this can significantly change the effectiveness of the code. As a rule of thumb, you never want the particle to go outside the donut's rim of max intensity at any point in the scan pattern. This will cause the donut to run away from the particle instead of track it.

You might notice the liberal use of `'`, particularly with `getlastframe(camera)'`. This is because we were told to standardize the coordinate system of camera pixels. The code for `getlastframe(camera)` has the first transposition, which should make the aspect ratio horizontal directly out of the function. However, GLMakie's `scatter!` and `heatmap!` seem to transpose data internally before plotting, which is why we assign frame to the transpose of `getlastframe(camera)`, making the final aspect ratio horizonal again. Honestly, we might have just made it more confusing.

Make sure to comment the running code at the bottom of each file out when you are done with it. There's a good chance other files include the code.

The 3D printed stage is not exactly level. Moving the stage a lot can cause the sample to drift in and out of focus.

The shape of the donut gets very distorted after going through the objective at large aperture diameters. We don't know why this happens. It could be that the collimated light out of the first 50 mm lens is no longer gaussian after passing through the aperture. At some point that should probably be switched out for a shorter lens because a larger aperture is more ideal for this microscope.

The two removable optical elements are the beam calibration mirror and the widefield lens. The beam calibration mirror sends the laser to the DCX camera. We haven't gotten the microscope to work well without the widefield lens in place (which is the configuration in which it is supposed to track objects), mostly because of alignment and donut quality issues. It is supposed to let the microscope switch between finding something to track and actually tracking it. This might be succeeded by a raster scan in the future.

For our purposes it was useful to have a high-density sample for beam characterization after the objective and a low-density sample for test tracking. Our high density sample consisted of 200 nm beads at 1 : 10^4 concentration, although we didn't actually make this sample and suspect the actual concentration is higher. Our low-density sample consisted of 200 nm bead at 1 : 5 * 10^5 concentration. They can still be found in the wet lab fridge as of early August.

Gain is pretty important for the current cameras. If it's too low you won't see anything. It is nearly maxed out by default in the running code, but you can change it if you'd like. The default exposure times also vary between cameras, so you'll likely have to adjust laser power while switching between the sample and the DCX camera.

The ThorCamCSC camera has a tendency to crash Julia. Sometimes this is because of a problem in the code, but often it is a random crash that will sort itself out after resetting, restarting, and unplugging everything. If the problem persists, it's likely an SDK issue. Further investigation may be needed. 

There are several triggerscope functions that do not work. This is not a problem with the Julia code but rather the triggerscope itself, or perhaps its documentation. `progwave` and `progdelay` are two that we have found. 

The objective positioner has a range of motion limited at the bottom by the large mirror and at the top by the stage. Make sure you have enough clearance before moving the objective. The functions can be found in mcl_micro_positioner and mcl_stage.

## Common Tech issues
#### **Problem:** Camera whiteout or `SDK not initialized`
**Solution:** Unplug and re-plug in the camera. It will do this often. 

#### **Problem:** `ERROR: libserialport returned SP_ERR_FAIL - Host OS reported a failure.` 

**Solution:** Unplug and re-plug in the triggerscope. If that doesn't work, flip the switch on the triggerscope next to the plugs back and forth.
NOTE: Unplugging has caused windows to crash at least four times, but usually it is fine.

#### **Problem:** Galvos make very strange noise after programming them

**Solution:** Usually they are pretty noisy, but if they are really screaming it check to see if the function generator is on. Additionally, it could be that too many lines were programmed onto the triggerscope. It can only handle up to 50 lines. If you write more than that, the other lines will be ignored, but no errors will occur. If you write more than 255, the triggerscope will have some sort of error, the galvos power will need to be cut, and the triggerscope will need to be unplugged and re-plugged in in order for it to function normally. Running a program above around 1500 Hz has been risky in our experience, but thankfully we haven't broken anything in our time here. 