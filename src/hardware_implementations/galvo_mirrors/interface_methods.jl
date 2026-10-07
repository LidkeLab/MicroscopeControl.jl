# A galvo needs no behaviour of its own: the generic BeamSteerer methods in
# BeamSteeringInterface (initialize, shutdown, export_state, setvoltage, setangle,
# gridscan, ...) already do everything, because Galvo supplies the fields they expect.
#
# The one thing worth saying is what the two axes mean on the hardware, which the
# backend knows and the device does not — so `show` reports it.

function Base.show(io::IO, galvo::Galvo)
    vx, vy = getvoltage(galvo)
    state = galvo.isopen ? "open" : "closed"
    print(io, "Galvo(\"", galvo.unique_id, "\", ", state,
        ", ", round(vx, digits=4), " V / ", round(vy, digits=4), " V",
        ", backend ", typeof(galvo.backend), ")")
end
