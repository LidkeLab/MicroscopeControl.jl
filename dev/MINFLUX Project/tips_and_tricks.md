# Tips and Tricks for Operating the MINFLUX System
### Written by Martin Zanazzi and Abigail Gatsch
As of Summer 2025 the microscope is in a state of development where it can be tricky to operate. Here is what we've learned in our summer of building and operating it.

## Set up
To turn on the microscope
1. Turn on the following equipment
    - The galvos
    - The laser key, its fan, and its "enable" button
    - The objective positioners if they are off
2. Start the Julia REPL and precompile MicroscopeControl.jl and neccesary dependencies
3. Define the triggerscope and camera
    ```julia
    camera1 = ThorCamCSCCamera()
    camera2 = ThorcamDCXCamera()
    scope = Triggerscope4(compause = 2e-4)
    ```
    The compause is an important attribute of the triggerscope as it determines how quickly it can receive commands. Decreasing the compause increases the chance that the triggerscope resets because the serial port did not wait long enough for a hardware response.

    Additionally, the ThorCamCSCCamera object must be reassigned to its variable after everytime the camera shutsdown. If you forget, it can result in a string of "frame not collected" errors. 
4. Zero the galvos by running the following commands in Julia
    ```julia
    initialize(scope)
    clearall(scope)
    setrange(scope, 1, PLUSMINUS10)
    setrange(scope, 2, PLUSMINUS10)
    setdac(scope, 1, 0.0)
    setdac(scope, 2, 0.0)
    ```
    Attempting to zero the scope in any other way could result in undefined behaviour. Additionally, **many functions complete this step for you, and will throw errors if used after the scope was initialized.** To avoid this fate, simply shut down your scope if you were using it before calling the function by calling `shutdown(scope)` 

5. Check the beam quality in `beam_characterization.jl` by running beam_characterization(camera2) after placing the removeable mirror in the optical path.

6. Calibrate the galvos using the lines of code commented at the bottom of `galvo_calibration` if there is no saved matrix available. Two key words arguments of note are `margin` and `step_size`. Margin dictates how far along the screen the center dot will go before continuing to the next loop, and step_size determines how large each galvo voltage step will be.

7. Run `test_track(scope, camera1, saved_calibration_matrix_CSC_1)` from `MINFLUX_TEST` in order to run the tracking program.

## Common Tech issues
#### **Problem:** Camera whiteout 
**Solution:** Unplug and re-plug in the camera. It will do this often. 

#### **Problem:** `ERROR: libserialport returned SP_ERR_FAIL - Host OS reported a failure.` 

**Solution:** Unplug and re-plug in the triggerscope. 
NOTE: This has caused windows to crash at least four times, but usually it is fine

#### **Problem:** Galvos make very strange noise after programming them

**Solution:** Usually they are pretty noisy, but if they are really screaming it check to see if the function generator is on. Additionally, it could be that too many lines were programmed onto the triggerscope. It can only handle up to 50 lines. If you write more than that, the other lines will be ignored, but no errors will occur. If you write more than 255, the triggerscope will have some sort of error, the galvos power will need to be cut, and the triggerscope will need to be unplugged and re-plugged in in order for it to function normally. 