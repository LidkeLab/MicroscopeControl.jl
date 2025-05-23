function loadlut()  #TODO: Input LUT path
    #This works, now must load the LUT
    lut_path = "C:\\Program Files\\Meadowlark Optics\\Blink OverDrive Plus\\LUT Files\\1024x1024_linearVoltage.LUT"
    loaded_lut = @ccall "C:\\Program Files\\Meadowlark Optics\\Blink OverDrive Plus\\SDK\\Blink_C_wrapper.dll".Load_LUT_file(1::Cuint, lut_path::Ptr{UInt8})::Cint

end

function writesingleimage(slm::MLSLM)
    single_image = slm.phase .* 255 #Converting 0 to 1 to scaled values between 0 and 255
    single_image = round.(Int, single_image) #Converting to integers
    single_image = convert(Array{UInt8}, single_image)

    board_number = 1
    wait_for_trigger::Cuint = 0
    flip_immediate::Cuint = 0
    output_pulse_image_flip::Cuint = 0
    output_pulse_image_refresh::Cuint = 0
    trigger_timout_ms::Cuint = 5000
    image_size::Cint = slm.height * slm.width

    #=
    single_image = reshape(single_image, 1, image_size)
    new_image = zeros(UInt8, image_size)    #Issues with Column vs Row major order
    new_image[:] .= single_image[1, :]
    =#
    new_image = reshape(single_image, image_size)
    @ccall "C:\\Program Files\\Meadowlark Optics\\Blink OverDrive Plus\\SDK\\Blink_C_wrapper.dll".Write_image(board_number::Cuint, 
        new_image::Ptr{Cint}, image_size::Cint, wait_for_trigger::Cuint, flip_immediate::Cuint, output_pulse_image_flip::Cuint, 
        output_pulse_image_refresh::Cuint, trigger_timout_ms::Cuint)::Cint
    
end

function writesequence(slm::MLSLM)
    @error "Not implemented"
end

function selectsequenceimage(slm::MLSLM)
    @error "Not implemented"
end
