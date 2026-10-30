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

# A recorder that can be told to fail the way real hardware does: the Y write after the X
# write has gone out, or the park at shutdown. Releasing still counts as `closed`, which is
# what a real backend does when its park fails.
mutable struct FailingBackend <: SteeringBackend
    writes::Vector{Tuple{Symbol,Float64}}
    fail_y::Bool
    fail_park::Bool
    closed::Int
end
FailingBackend() = FailingBackend(Tuple{Symbol,Float64}[], false, false, 0)

BeamSteeringInterface.backend_limits(::FailingBackend) = ((-10.0, 10.0), (-10.0, 10.0))
BeamSteeringInterface.openbackend!(::FailingBackend) = nothing
function BeamSteeringInterface.write_voltages!(b::FailingBackend, vx::Float64, vy::Float64)
    push!(b.writes, (:x, vx))
    b.fail_y && error("fake Y write failure")
    push!(b.writes, (:y, vy))
    return nothing
end
function BeamSteeringInterface.closebackend!(b::FailingBackend)
    b.closed += 1
    b.fail_park && error("fake park failure")
    return nothing
end

# A recorder on a 0.25 V grid over ±10 V, standing in for a DAC: its limits snap inward.
struct QuantizedBackend <: SteeringBackend end
BeamSteeringInterface.backend_limits(::QuantizedBackend) = ((-10.0, 10.0), (-10.0, 10.0))
BeamSteeringInterface.snap_limits(::QuantizedBackend, lims::Tuple{Float64,Float64}) =
    (ceil(lims[1] / 0.25) * 0.25, floor(lims[2] / 0.25) * 0.25)
BeamSteeringInterface.openbackend!(::QuantizedBackend) = nothing
BeamSteeringInterface.closebackend!(::QuantizedBackend) = nothing
BeamSteeringInterface.write_voltages!(::QuantizedBackend, ::Float64, ::Float64) = nothing

# A backend with none of the three contract methods, used to check that the interface
# stubs throw rather than silently returning nothing (CLAUDE.md, "Interface Contract").
struct _BareBackend <: SteeringBackend end
