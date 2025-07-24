using Revise


err1 = @ccall "thorlabs_tsi_camera_sdk.dll".tl_camera_open_sdk()::Cint #Returns zero if successful

id = Vector{UInt8}(undef, 4096)
max_length = Cint(4096)
is_camera_found = @ccall "thorlabs_tsi_camera_sdk.dll".tl_camera_discover_available_cameras(id::Ptr{UInt8}, max_length::Cint)::Cint   #returns zero if successful, test_ID is a pointer to a string containing the ID of the camera, this changes the unique_id

ref_cam_camera_handle = Ref{Ptr{Cvoid}}(C_NULL) #reference to a pointer to a void pointer
is_camera_opened = @ccall "thorlabs_tsi_camera_sdk".tl_camera_open_camera(id::Ptr{UInt8}, ref_cam_camera_handle::Ref{Ptr{Cvoid}})::Cint
camera_handle = ref_cam_camera_handle[]

# get camera properties
exposure_time = [Clonglong(2)]
err1 = @ccall "thorlabs_tsi_camera_sdk".tl_camera_get_exposure_time(camera_handle::Ptr{Cvoid}, exposure_time::Ptr{Clonglong})::Cint
println("Exposure time: ", exposure_time[1] / 1000, " ms")

frame_rate = [Float64(2)]
err1 = @ccall "thorlabs_tsi_camera_sdk".tl_camera_get_frame_rate_control_value(camera_handle::Ptr{Cvoid}, frame_rate::Ptr{Float64})::Cint
println("Frame rate: ", frame_rate[1], " fps")


gain = [Cint(2)]
err1 = @ccall "thorlabs_tsi_camera_sdk".tl_camera_get_gain(camera_handle::Ptr{Cvoid}, gain::Ptr{Cint})::Cint
println("Gain: ", gain[1]/10, " dB")


operation_mode = [Cint(2)]
err1 = @ccall "thorlabs_tsi_camera_sdk".tl_camera_get_operation_mode(camera_handle::Ptr{Cvoid}, operation_mode::Ptr{Cint})::Cint
println("Operation mode: ", operation_mode[1])

image_height = [Cint(2)]
err1 = @ccall "thorlabs_tsi_camera_sdk".tl_camera_get_image_height(camera_handle::Ptr{Cvoid}, image_height::Ptr{Cint})::Cint
println("Image height: ", image_height[1])

image_width = [Cint(2)]
err1 = @ccall "thorlabs_tsi_camera_sdk".tl_camera_get_image_width(camera_handle::Ptr{Cvoid}, image_width::Ptr{Cint})::Cint
println("Image width: ", image_width[1])

sensor_height = [Cint(2)]
err1 = @ccall "thorlabs_tsi_camera_sdk".tl_camera_get_sensor_height(camera_handle::Ptr{Cvoid}, sensor_height::Ptr{Cint})::Cint
println("Sensor height: ", sensor_height[1])

sensor_width = [Cint(2)]
err1 = @ccall "thorlabs_tsi_camera_sdk".tl_camera_get_sensor_width(camera_handle::Ptr{Cvoid}, sensor_width::Ptr{Cint})::Cint
println("Sensor width: ", sensor_width[1])

x_start = [Cint(2)]
y_start = [Cint(2)]
x_end = [Cint(2)]
y_end = [Cint(2)]
err1 = @ccall "thorlabs_tsi_camera_sdk".tl_camera_get_roi(camera_handle::Ptr{Cvoid}, x_start::Ptr{Cint}, y_start::Ptr{Cint}, x_end::Ptr{Cint}, y_end::Ptr{Cint})::Cint
println("ROI: (", x_start[1], ", ", y_start[1], ") to (", x_end[1], ", ", y_end[1], ")")

is_enabled = [Cint(2)]
err1 = @ccall "thorlabs_tsi_camera_sdk".tl_camera_get_is_frame_rate_control_enabled(camera_handle::Ptr{Cvoid}, is_enabled::Ptr{Cint})::Cint
println("Is frame rate control enabled: ", is_enabled[1])



# Set the camera properties

enable = Cint(1)
err1 = @ccall "thorlabs_tsi_camera_sdk".tl_camera_set_is_frame_rate_control_enabled(camera_handle::Ptr{Cvoid}, enable::Cint)::Cint

frame_rate = Float64(30)
err1 = @ccall "thorlabs_tsi_camera_sdk".tl_camera_set_frame_rate_control_value(camera_handle::Ptr{Cvoid}, frame_rate::Float64)::Cint

width = 400
height = 400
x_start = Cint(100)
y_start = Cint(200)
x_end = Cint(width+x_start-1)
y_end = Cint(height+y_start-1)
err1 = @ccall "thorlabs_tsi_camera_sdk".tl_camera_set_roi(camera_handle::Ptr{Cvoid}, x_start::Cint, y_start::Cint, x_end::Cint, y_end::Cint)::Cint

