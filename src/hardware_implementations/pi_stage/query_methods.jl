

"""
Function to update the position of the PI Stage
"""
function getposition(stage::PIStage)
    position = Vector{Cdouble}(undef, 2)
    @ccall gcs2path.PI_qPOS(stage.id::Cint, "1 2"::Ptr{UInt8}, position::Ptr{Cdouble})::Cint

    @info "Stage position: " * string(position[1]) * ", " * string(position[2])
    stage.real_x = position[1]
    stage.real_y = position[2]
end

"""
Function to update the x position of the PI Stage
"""
function getxposition(stage::PIStage)
    xposition = Cdouble(0.0)
    @ccall gcs2path.PI_qPOS(stage.id::Cint, "1"::Ptr{UInt8}, [xposition]::Ptr{Cdouble})::Cint
    stage.real_x = xposition
end

"""
Function to update the y position of the PI Stage
"""
function getyposition(stage::PIStage)
    yposition = Cdouble(0.0)
    @ccall gcs2path.PI_qPOS(stage.id::Cint, "2"::Ptr{UInt8}, [yposition]::Ptr{Cdouble})::Cint
    stage.real_y = yposition
end

"""
BOOL PI_IsMoving (int ID, const char* szAxes, BOOL* pbValueArray)

Function to check if the PI Stage is moving, both the x and y axis are checked
"""
function ismoving(stage::PIStage)
    ismoving = Vector{UInt32}(undef, 2)
    @ccall gcs2path.PI_IsMoving(stage.id::Cint, "1 2"::Ptr{UInt8}, ismoving::Ptr{UInt32})::Cint
    stage.ismoving = (Bool(ismoving[1]), Bool(ismoving[2]))
end

function getrange(stage::PIStage)
    findmin(stage)
    findmax(stage)
end

"""

"""
function findmin(stage::PIStage)
    minpositions = Vector{Cdouble}(undef, 2)
    @ccall gcs2path.PI_qTMN(stage.id::Cint, "1 2"::Ptr{UInt8}, minpositions::Ptr{Cdouble})::Cint
    stage.range_x = (minpositions[1], stage.range_x[2])
    stage.range_y = (minpositions[2], stage.range_y[2])
end

"""

"""
function findmax(stage::PIStage)
    maxpositions = Vector{Cdouble}(undef, 2)
    @ccall gcs2path.PI_qTMX(stage.id::Cint, "1 2"::Ptr{UInt8}, maxpositions::Ptr{Cdouble})::Cint
    stage.range_x = (stage.range_x[1], maxpositions[1])
    stage.range_y = (stage.range_y[1], maxpositions[2])
end