
include("types.jl")
include("thorcamcsc_helpers.jl")
include("thorcamcsc_sdk.jl")
include("thorcamcsc_camcontrol.jl")
include("set_properties.jl")

function capturesingleframe(exposure_time, operation_mode, frames_per_trigger)
    test_cam = ThorCamCSC.ThorCamCSCCamera(0, C_NULL, 0, 0, ThorCamCSC.CameraROI(1, 1, 1440, 1080))

    #Open SDK
    ThorCamCSC.thorcamsdkinit()

    #Find Cameras
    id = Vector{UInt8}(undef, 4096)
    max_length = Cint(4096)
    ThorCamCSC.discoveravaliablecameras!(id, max_length)

    #Open Camera
    ThorCamCSC.opencamera!(test_cam, id)

    #Set Camera Properties
    ThorCamCSC.setexposuretime(test_cam, exposure_time)
    ThorCamCSC.setoperationmode(test_cam, Cint(operation_mode))
    ThorCamCSC.setframespertrigger(test_cam, Cint(frames_per_trigger))

    #Arm Camera
    ThorCamCSC.armcamera(test_cam)

    #Issue Trigger
    ThorCamCSC.issuesoftwaretrigger(test_cam)


    #Capture Last Frame
    single_image = Nothing
    @time while single_image == Nothing 
        single_image = ThorCamCSC.getlastframe(test_cam)
    end
    #Disarm Camera
    ThorCamCSC.disarmcamera(test_cam)   

    #Close Camera
    ThorCamCSC.closecamera(test_cam)

    #Delete SDK
    ThorCamCSC.thorcamsdkuninit()

    #Display Image

    fig = Figure()
    image_single_frame = reshape(single_image, 1440, 1080)
    reinterpret(N0f16, image_single_frame)
    GLMakie.image(fig[1,1], image_single_frame, interpolate=false)
    fig
end