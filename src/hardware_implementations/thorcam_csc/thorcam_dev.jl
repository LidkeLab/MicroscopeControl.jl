function discoveravaliablecameras!(unique_id::Vector{UInt8}, max_length::Cint)
    is_camera_found = @ccall "thorlabs_tsi_camera_sdk.dll".tl_camera_discover_available_cameras(unique_id::Ptr{UInt8}, max_length::Cint)::Cint   #returns zero if successful, test_ID is a pointer to a string containing the ID of the camera, this changes the unique_id
    if is_camera_found != 0
        @error "Camera not found"
    end
    return is_camera_found  
end

function discoveravaliablecameras!(camera::ThorCamCSCCamera, unique_id::Vector{UInt8}, max_length::Cint)
    is_camera_found = @ccall "thorlabs_tsi_camera_sdk.dll".tl_camera_discover_available_cameras(unique_id::Ptr{UInt8}, max_length::Cint)::Cint   #returns zero if successful, test_ID is a pointer to a string containing the ID of the camera
    if is_camera_found != 0
        @error "Camera not found"
    end

    camera.unique_id = unique_id
    camera.max_id_length = max_length

    return is_camera_found
end 

function discoveravaliablecameras!(camera::ThorCamCSCCamera)
    is_camera_found = @ccall "thorlabs_tsi_camera_sdk.dll".tl_camera_discover_available_cameras(camera.unique_id::Ptr{UInt8}, camera.max_id_length::Cint)::Cint   #returns zero if successful, test_ID is a pointer to a string containing the ID of the camera, this changes the unique_id
    if is_camera_found != 0
        @error "Camera not found"
    end
    return is_camera_found  
end

function opencamera(unique_id::Vector{UInt8})
    ref_camera_handle = Ref{Ptr{Cvoid}}() #reference to a pointer to a void pointer
    is_camera_opened = @ccall "thorlabs_tsi_camera_sdk".tl_camera_open_camera(unique_id::Ptr{UInt8}, ref_camera_handle::Ref{Ptr{Cvoid}})::Cint
    handle = ref_camera_handle[]
    if is_camera_opened != 0
        @error "Camera not opened"
    end
    return is_camera_opened, handle
end


function opencamera!(camera::ThorCamCSCCamera, unique_id::Vector{UInt8})
    ref_cam_camera_handle = Ref{Ptr{Cvoid}}(C_NULL) #reference to a pointer to a void pointer
    is_camera_opened = @ccall "thorlabs_tsi_camera_sdk".tl_camera_open_camera(unique_id::Ptr{UInt8}, ref_cam_camera_handle::Ref{Ptr{Cvoid}})::Cint
    camera.camera_handle = ref_cam_camera_handle[]
    
    if is_camera_opened != 0
        @error "Camera not opened"
    end
    return is_camera_opened
end

function opencamera!(camera::ThorCamCSCCamera)  #function without specified ID String
    ref_cam_camera_handle = Ref{Ptr{Cvoid}}(C_NULL) #reference to a pointer to a void pointer
    is_camera_opened = @ccall "thorlabs_tsi_camera_sdk".tl_camera_open_camera(camera.unique_id::Ptr{UInt8}, ref_cam_camera_handle::Ref{Ptr{Cvoid}})::Cint
    camera.camera_handle = ref_cam_camera_handle[] 
    if is_camera_opened != 0
        @error "Camera not opened"
    end
    return is_camera_opened
end

function closecamera(camera::ThorCamCSCCamera)
    is_camera_closed = @ccall "thorlabs_tsi_camera_sdk.dll".tl_camera_close_camera(camera.camera_handle::Ptr{Cvoid})::Cint
    if is_camera_closed != 0
        @error "Camera not closed"
    end
    return is_camera_closed
end


function closecamera(camera_handle::Ptr{Cvoid})
    is_camera_closed = @ccall "thorlabs_tsi_camera_sdk.dll".tl_camera_close_camera(camera_handle::Ptr{Cvoid})::Cint
    if is_camera_closed != 0
        @error "Camera not closed"
    end
    return is_camera_closed
end


