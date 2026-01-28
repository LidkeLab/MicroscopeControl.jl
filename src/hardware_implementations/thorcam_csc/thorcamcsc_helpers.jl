function show_error()
    error_msg = @ccall "thorlabs_tsi_camera_sdk.dll".tl_camera_get_last_error()::Ptr{UInt8}

    message = Vector{UInt8}(undef, 128)
    for i in 1:128
        message[i] = unsafe_load(error_msg, i)
    end
    
    message = reinterpret(UInt8, message)
    str = String(message)
    println(str)
end
