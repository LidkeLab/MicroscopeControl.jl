
"""
Function to move PI Stage to a specific position
"""
function move(stage::PIStage, x::Float64, y::Float64)
    @ccall gcs2path.PI_MOV(stage.id::Cint, "1 2"::Ptr{UInt8}, [Cdouble(x),Cdouble(y)]::Ptr{Cdouble})::Cint
    stage.targ_x = x
    stage.targ_y = y
    @info "Stage moving to position: " * string(x) * ", " * string(y)
end

"""
Function to move PI Stage, and wait for completion
"""
function moveandwait(stage::PIStage, x::Float64, y::Float64)
    @ccall gcs2path.PI_MOV(stage.id::Cint, "1 2"::Ptr{UInt8}, [Cdouble(x),Cdouble(y)]::Ptr{Cdouble})::Cint
    stage.targ_x = x
    stage.targ_y = y
    ismoving(stage)
    while stage.ismoving[1] == 1 || stage.ismoving[2] == 1
        ismoving(stage)
    end
end


"""
Function to move PI Stage X axis to a specific position
"""
function movex(stage::PIStage, x::Float64)
    @ccall gcs2path.PI_MOV(stage.id::Cint, "1"::Ptr{UInt8}, [Cdouble(x)]::Ptr{Cdouble})::Cint
    stage.targ_x = x
end

"""
Function to move PI Stage Y axis to a specific position
"""
function movey(stage::PIStage, y::Float64)
    @ccall gcs2path.PI_MOV(stage.id::Cint, "2"::Ptr{UInt8}, [Cdouble(y)]::Ptr{Cdouble})::Cint
    stage.targ_y = y
end

"""
Function call to smoothly stop motion of the PI Stage
"""
function stopmotion(stage::PIStage)
    isstopped = @ccall gcs2path.PI_HLT(stage.id::Cint, "1 2"::Ptr{UInt8})::Cint
    if isstopped == 1
        @info "Motion successfully stopped"
    else
        @error "Motion unsucessfully stopped"
    end
end

"""
Function call to immediately stop the PI Stage
"""
function immediatestop(stage::PIStage)
    isstopped = @ccall gcs2path.PI_STP(stage.id::Cint)::Cint
    if isstopped == 1
        @info "Motion successfully stopped"
    else
        @error "Motion unsucessfully stopped"
    end
end
