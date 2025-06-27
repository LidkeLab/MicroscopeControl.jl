# This file contains wrappers for the movement and encoder C functions for the MicroDrive1

"""
    md1_move_profile_microsteps(positioner::MclZPositioner)


# Arguments
    - `positioner::MCLZPositioner`: the positioner or stage

# Returns 
    - 
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
    md1_move_profile(positioner::MclZPositioner)


# Arguments
    - `positioner::MCLZPositioner`: the positioner or stage

# Returns 
    - 
"""
function md1_move_profile(positioner::MclZPositioner)
    #This function is already defined as 'move' in interface_methods.jl
end

"""
    md1_single_step(positioner::MclZPositioner)


# Arguments
    - `positioner::MCLZPositioner`: the positioner or stage

# Returns 
    - 
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


# Arguments
    - `positioner::MCLZPositioner`: the positioner or stage

# Returns 
    - 
"""
function md1_reset_encoder(positioner::MclZPositioner)
    status = Vector{Cuchar}(undef, 1)  # allocate memory for status byte
    call = @ccall madlibpath.MCL_MD1ResetEncoder(
        status::Ptr{Cuchar},  # status parameter
        positioner.handle::Cint  # handle parameter
    )::Cint
    return HardwareReturn[call], status[1]
end

"""
    md1_read_encoder(positioner::MclZPositioner)


# Arguments
    - `positioner::MCLZPositioner`: the positioner or stage

# Returns 
    - 
"""
function md1_read_encoder(positioner::MclZPositioner)
    position = Vector{Cdouble}(undef, 1)  # allocate memory for position
    call = @ccall madlibpath.MCL_MD1ReadEncoder(
        position::Ptr{Cdouble},  # position parameter
        positioner.handle::Cint  # handle parameter
    )::Cint
    return HardwareReturn[call], position[1]  # return the actual position value
end

"""
    md1_current_microstep_pos(positioner::MclZPositioner)


# Arguments
    - `positioner::MCLZPositioner`: the positioner or stage

# Returns 
    - 
"""
function md1_current_microstep_pos(positioner::MclZPositioner)
    microsteps = Vector{Cint}(undef, 1)  # allocate memory for microstep count
    call = @ccall madlibpath.MCL_MD1CurrentMicroStepPosition(
        microsteps::Ptr{Cint},  # microSteps parameter
        positioner.handle::Cint  # handle parameter
    )::Cint
    return HardwareReturn[call], microsteps[1]
end