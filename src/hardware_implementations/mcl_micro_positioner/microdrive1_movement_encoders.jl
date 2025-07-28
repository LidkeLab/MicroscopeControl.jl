# This file contains wrappers for the movement and encoder C functions for the MicroDrive1

"""
    md1_move_profile_microsteps(positioner::MclZPositioner, microsteps::Int64)
Moves the positioner the specified number of microsteps.

# Arguments
    - `positioner::MCLZPositioner`: the positioner or stage
    - `microsteps::Int64`: The number of microsteps to move

# Returns 
    - "MCL_SUCCESS" or relevant error code
"""
function md1_move_profile_microsteps(positioner::MclZPositioner, microsteps::Int64)
    @info "Moving MicroDrive1 with $microsteps microsteps."
    call = @ccall madlibpath.MCL_MD1MoveProfile_MicroSteps(
        positioner.velocity::Cdouble,
        microsteps::Cint,
        positioner.handle::Cint
    )::Cint
    return HardwareReturn[call]
end

"""
    md1_move_profile(positioner::MclZPositioner, targ_z::Float64)
moves the positioner to the specified location. 

# Arguments
    - `positioner::MCLZPositioner`: the positioner or stage
    - `targ_z::Float64`: the target position

# Returns 
    - "MCL_SUCCESS" or relevant error code
"""
function md1_move_profile(positioner::MclZPositioner, targ_z::Float64)
    @info "This function is already defined as 'move' in interface_methods.jl"
    return move(positioner, targ_z)
end

"""
    md1_single_step(positioner::MclZPositioner, direction::Int64)
Moves the positioner a single step forwards or backwards

# Arguments
    - `positioner::MCLZPositioner`: the positioner or stage
    - `direction::Int64`: The direction: 1 for forwards, -1 for reverse

# Returns 
    - "MCL_SUCCESS" or relevant error code
"""
function md1_single_step(positioner::MclZPositioner, direction::Int64)
    call = @ccall madlibpath.MCL_MD1SingleStep(
        direction::Cint, # direction: 1 for forward, -1 for reverse
        positioner.handle::Cint
    )::Cint
    return HardwareReturn[call]
end

"""
    md1_reset_encoder(positioner::MclZPositioner)
Makes the current position of the positioner the zero point

# Arguments
    - `positioner::MCLZPositioner`: the positioner or stage

# Returns
    - `Status::UInt8`
        - Bit4: Success/Failure
        - Bit3: Forward Limit Switch
        - Bit2: Reverse Limit Switch
    - "MCL_SUCCESS" or relevant error code
    
"""
function md1_reset_encoder(positioner::MclZPositioner)
    status = Ref{Cuchar}()  # allocate memory for status byte
    call = @ccall madlibpath.MCL_MD1ResetEncoder(
        status::Ref{Cuchar},  # status parameter
        positioner.handle::Cint  # handle parameter
    )::Cint
    return status[], HardwareReturn[call]
end

"""
    md1_read_encoder(positioner::MclZPositioner)
Reads the postion of the positioner from the encoder

# Arguments
    - `positioner::MCLZPositioner`: the positioner or stage

# Returns 
    - `Position::Float64`: the position read from the encoder
    - "MCL_SUCCESS" or relevant error code
"""
function md1_read_encoder(positioner::MclZPositioner)
    position = Ref{Cdouble}()
    call = @ccall madlibpath.MCL_MD1ReadEncoder(
        position::Ref{Cdouble},  # position parameter
        positioner.handle::Cint  # handle parameter
    )::Cint
    return position[], HardwareReturn[call]   # return the actual position value
end

"""
    md1_current_microstep_pos(positioner::MclZPositioner)
Reads the number of microsteps taken since the beginning of the program

# Arguments
    - `positioner::MCLZPositioner`: the positioner or stage

# Returns 
    - `microsteps::Int32`: The number of microsteps taken
    - "MCL_SUCCESS" or relevant error code
"""
function md1_current_microstep_pos(positioner::MclZPositioner)
    microsteps = Ref{Cint}()
    call = @ccall madlibpath.MCL_MD1CurrentMicroStepPosition(
        microsteps::Ref{Cint},  # microSteps parameter
        positioner.handle::Cint  # handle parameter
    )::Cint
    return microsteps[], HardwareReturn[call]
end