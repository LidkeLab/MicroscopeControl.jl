# A beam-steering backend that records what it was told to write instead of moving
# hardware, so the voltage/angle/limit/scan logic in the BeamSteerer interface can be run
# with no Triggerscope and no NI card attached. Same seam idea as the fake SDK files for
# the TCube laser and the PI controllers.
#
# Must be included at top level, before the testsets: a struct cannot be defined inside a
# @testset block.

const BeamSteeringInterface = MicroscopeControl.HardwareInterfaces.BeamSteeringInterface

mutable struct RecordingBackend <: SteeringBackend
    writes::Vector{Tuple{Float64,Float64}}
    opened::Int
    closed::Int
end
RecordingBackend() = RecordingBackend(Tuple{Float64,Float64}[], 0, 0)

BeamSteeringInterface.backend_limits(::RecordingBackend) = ((-10.0, 10.0), (-10.0, 10.0))
BeamSteeringInterface.openbackend!(b::RecordingBackend) = (b.opened += 1; nothing)
BeamSteeringInterface.closebackend!(b::RecordingBackend) = (b.closed += 1; nothing)
BeamSteeringInterface.write_voltages!(b::RecordingBackend, vx::Float64, vy::Float64) =
    (push!(b.writes, (vx, vy)); nothing)

# A backend with none of the three contract methods, used to check that the interface
# stubs throw rather than silently returning nothing (CLAUDE.md, "Interface Contract").
struct _BareBackend <: SteeringBackend end
