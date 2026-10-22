# Light-source modulation: a light with a `modulator` field puts its level on an analogue input through an
# `AbstractModulationControl`, while with `modulator = nothing` every driver runs the code it always did (the rest
# of the suite is that regression test).
#
# The TCube runs on the fake Kinesis SDK of `tcube_fake_sdk.jl`, which models the TLD001's ONE setpoint register
# (a USB write sets it outright, a MOD IN change adds its difference and is lost inside the settle window) and the
# control-source read-back. The MOD IN voltage comes from a test modulator, `FakeModIn`, that turns the level
# into register words at a TRUE scale, which may differ from the `per_volt` it believes. `NIDAQModulator` runs on a
# strict test-local `FakeDAQ <: DAQ`. The Triggerscope serial path has no seam: `TriggerscopeModulator` gets its
# pure parts only. Nothing here commands hardware.
#
# Everything lives in a module so the fixtures (a `FakeDAQ <: DAQ`, test lights) stay out of `Main`, where the
# contract tests walk the interface subtypes.
module LightSourceModulationTests

using Test
using MicroscopeControl

const MC = MicroscopeControl
const LSI = MC.HardwareInterfaces.LightSourceInterface
const TCmod = MC.HardwareImplementations.TCubeLaserControl
const Trig = MC.HardwareImplementations.Triggerscope
const FK = Main.FakeKinesis
const RecordingModulator = MC.RecordingModulator

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

"Silence the driver's prints and logs."
quiet(f) = redirect_stdout(() -> Base.CoreLogging.with_logger(f, Base.CoreLogging.NullLogger()), devnull)

"""
A DAQ that refuses everything the real one would: only "AO" tasks, only with a range named, only a range the card has
(DAQmx -200077 otherwise), a write outside the task's range, a write or delete on a task that is not live.
"""
mutable struct FakeDAQ <: MC.DAQ
    card_range::Tuple{Float64,Float64}
    tasks::Dict{Int,NamedTuple{(:channel, :min, :max),Tuple{String,Float64,Float64}}}
    log::Vector{Tuple}
    next_id::Int
    fail_write::Bool
    fail_delete::Bool
    fail_setup::Bool    # the channel setup fails after the task is allocated
    fail_clear::Bool    # ... and so does clearing it (then `UnreleasedTask`, as NIdaq throws)
end
FakeDAQ(; card_range=(0.0, 5.0)) = FakeDAQ(card_range, Dict{Int,NamedTuple{(:channel, :min, :max),Tuple{String,Float64,Float64}}}(), Tuple[], 0, false, false, false, false)

MC.export_state(d::FakeDAQ) = (Dict{String,Any}("unique_id" => "FakeDAQ"), nothing, Dict{String,Any}())

function MC.createtask(d::FakeDAQ, tasktype::String, channel::String; min_val=nothing, max_val=nothing)
    tasktype == "AO" || error("FakeDAQ: only AO tasks")
    (min_val !== nothing && max_val !== nothing) || error("FakeDAQ: the channel must be created with an explicit range")
    (d.card_range[1] <= min_val && max_val <= d.card_range[2]) || error(
        "FakeDAQ: DAQmx error -200077: the range [$min_val, $max_val] V is not supported by this device")
    d.next_id += 1
    d.tasks[d.next_id] = (channel=channel, min=Float64(min_val), max=Float64(max_val))   # allocated
    push!(d.log, (:create, d.next_id, Float64(min_val), Float64(max_val)))
    if d.fail_setup
        cause = ErrorException("FakeDAQ: channel setup failed")
        d.fail_clear && throw(MC.HardwareInterfaces.DAQInterface.UnreleasedTask(d.next_id, cause))
        delete!(d.tasks, d.next_id)
        push!(d.log, (:delete, d.next_id))
        throw(cause)
    end
    return d.next_id
end

function MC.setvoltage(d::FakeDAQ, t::Int, v::Float64)
    haskey(d.tasks, t) || error("FakeDAQ: write to a task that is not live ($t)")
    d.fail_write && error("FakeDAQ: write refused")
    task = d.tasks[t]
    (task.min <= v <= task.max) || error("FakeDAQ: $v V is outside the task's range [$(task.min), $(task.max)]")
    push!(d.log, (:write, t, v))
    return 1
end

function MC.deletetask(d::FakeDAQ, t::Int)
    haskey(d.tasks, t) || error("FakeDAQ: delete of a task that is not live ($t)")
    d.fail_delete && error("FakeDAQ: delete refused")
    delete!(d.tasks, t)
    push!(d.log, (:delete, t))
    return nothing
end

"""
A modulator for the fake Kinesis controller. It believes `per_volt` (the light's unit per volt) and turns the level into
a voltage; the fake's MOD IN input then sees `v * words_per_volt` register words, the TRUE electrical scale. A level
whose voltage is above `v_max` is refused (`ArgumentError`) before any write. `failure` makes every call throw it,
`fail_nonzero` only a nonzero level, `shutdown_failure` the `shutdown`.
"""
mutable struct FakeModIn <: MC.AbstractModulationControl
    id::String
    per_volt::Float64
    words_per_volt::Float64
    v_max::Float64
    failure::Any
    fail_nonzero::Any
    shutdown_failure::Any
    volts::Vector{Float64}
    times::Vector{Float64}
    attempts::Vector{Float64}
    opened::Int
    closed::Int
end
FakeModIn(; id="mod1", per_volt, words_per_volt, v_max=5.0) =
    FakeModIn(id, per_volt, words_per_volt, v_max, nothing, nothing, nothing, Float64[], Float64[], Float64[], 0, 0)

LSI.output_id(m::FakeModIn) = m.id
function MC.setpower(m::FakeModIn, p::Float64)
    push!(m.attempts, p)
    m.failure === nothing || throw(m.failure)
    (p != 0 && m.fail_nonzero !== nothing) && throw(m.fail_nonzero)
    v = p / m.per_volt
    (isfinite(v) && 0.0 <= v <= m.v_max) || throw(ArgumentError("FakeModIn: $v V is out of reach [0, $(m.v_max)]"))
    push!(m.volts, v)
    push!(m.times, time())
    push!(FK.mod_volts, v)
    push!(FK.calls, "MOD $v")
    FK.apply_ext!(round(Int, v * m.words_per_volt))
    return nothing
end
function MC.initialize(m::FakeModIn)
    m.failure === nothing || throw(m.failure)
    m.opened += 1
    return MC.setpower(m, 0.0)
end
function MC.shutdown(m::FakeModIn)
    m.shutdown_failure === nothing || throw(m.shutdown_failure)
    m.closed += 1
    return MC.setpower(m, 0.0)
end

# Closed loop: 10 V is the photodiode's full scale, tia_range x wa_calibration W: 22.42 mW per volt, 3276.7 words per volt.
# Open loop: 16 mA per volt (a 160 mA limit / 10 V), and the words of 220 mA full scale.
const CP_PER_VOLT = 1e-3 * 224.2 * 1000 / 10
const CP_WORDS_PER_VOLT = 32767 / 10
const CC_PER_VOLT = 16.0
const CC_WORDS_PER_VOLT = 16.0 / 220 * 32767

modin(kind::Symbol; id="mod1", scale=1.0, kw...) = kind === :cp ?
    FakeModIn(; id, per_volt=CP_PER_VOLT * scale, words_per_volt=CP_WORDS_PER_VOLT, kw...) :
    FakeModIn(; id, per_volt=CC_PER_VOLT * scale, words_per_volt=CC_WORDS_PER_VOLT, kw...)

# A level (mA open loop, mW closed loop) and a second one, and the sink that drives the fake from a RecordingModulator.
const LV1 = Dict(:cc => 40.0, :cp => 20.0)
const LV2 = Dict(:cc => 60.0, :cp => 30.0)
words_of(kind::Symbol, p) = round(Int, p * (kind === :cp ? CP_WORDS_PER_VOLT / CP_PER_VOLT : CC_WORDS_PER_VOLT / CC_PER_VOLT))

props() = LightSourceProperties("mW", 0.0, false, 1.0, 70.0)
cc(; kw...) = TCubeLaser("00000000"; mode=ConstantCurrent(), max_current=160.0, kw...)
cp(; kw...) = TCubeLaser("00000000"; mode=ConstantPhotocurrent(), wa_calibration=224.2, tia_range=1e-3,
                         tec_stabilised=missing, properties=props(), max_current=160.0,
                         lock_check_s=0.1, ramp_step_s=0.0, kw...)
tcube(kind::Symbol; kw...) = kind === :cp ? cp(; kw...) : cc(; kw...)
setlvl!(l, kind::Symbol, p::Float64) = kind === :cp ? setoutputpower!(l, p) : setcurrent!(l, p)
requested(l, kind::Symbol) = kind === :cp ? l.pd.output_power_requested : l.drive_current

"A fresh controller and an initialized TCube of `kind` (`:cc` open loop, `:cp` closed loop); `calls` is left as initialize made it."
function ready(kind::Symbol; modulator=modin(kind), settle=0.0, strict=true, kw...)
    FK.reset!()
    FK.strict_handle[] = strict   # a call on a closed handle raises, as the DLL does
    FK.require_zero_mod[] = modulator !== nothing   # every USB setpoint at 0 V, or it is recorded in FK.violations
    empty!(LSI.MODULATOR_OUTPUTS)
    kind === :cp && (FK.limit_follows_pot[] = true)
    TCmod.MOD_SETTLE_S[] = settle
    l = tcube(kind; modulator, kw...)
    quiet(() -> initialize(l))
    return l
end

idx(op) = findfirst(==(op), FK.calls)
lastidx(op) = findlast(==(op), FK.calls)
modwrites() = [i for (i, c) in enumerate(FK.calls) if startswith(c, "MOD ")]

struct StubDAQ <: MC.DAQ end
struct NoField <: MC.LightSource end

# The deprecated `setupIO` and `set_modvoltage` still run `NIdaq` discovery after they warn. Replace the two discovery
# methods so nothing in this suite can reach DAQmx through them (same seam as `tcube_fake_sdk.jl`): one device, no
# channels, so `setupIO` stops with an error before it could make a task. The replacements are permanent for the process.
@eval MC.HardwareImplementations.NIDAQcard begin
    DAQInterface.showdevices(daq::NIdaq) = ["FakeDev1"]
    DAQInterface.showchannels(daq::NIdaq, channeltype::String, device::String) = String[]
end

# Lights that break the convention, one way each, for `modulation_violations` to find.
mutable struct BadLight <: MC.LightSource
    unique_id::String
    properties::LightSourceProperties
    modulator::Union{Nothing,MC.AbstractModulationControl}
    flavor::Symbol   # :ignores, :writes_while_off, :no_zero_first, :no_darken, :swallows
end
BadLight(flavor::Symbol; modulator=RecordingModulator()) = BadLight("BadLight", LightSourceProperties("mW", 0.0, false, 0.0, 100.0), modulator, flavor)
function MC.setpower(l::BadLight, p::Float64)
    l.flavor === :ignores && return (l.properties.power = p)
    if l.flavor === :writes_while_off || l.properties.is_on
        try
            MC.setpower(l.modulator, p)
        catch e
            e isa ArgumentError && rethrow()
            l.flavor === :no_darken && rethrow()
            l.flavor === :swallows && return nothing
            MC.setpower(l.modulator, 0.0)
            l.properties.is_on = false
            rethrow()
        end
    end
    l.properties.power = p
end
function MC.light_on(l::BadLight)
    if l.flavor !== :ignores
        l.flavor === :no_zero_first || MC.setpower(l.modulator, 0.0)
        l.properties.is_on = true
        MC.setpower(l.modulator, l.properties.power)
        return nothing
    end
    l.properties.is_on = true
end
function MC.light_off(l::BadLight)
    l.flavor === :ignores || LSI.zero_modulator!(l)
    l.properties.is_on = false
end

# ---------------------------------------------------------------------------

@testset "LightSource modulation" begin

    @testset "types and defaults" begin
        @test isabstracttype(MC.AbstractModulationControl)
        @test !(MC.AbstractModulationControl <: MC.AbstractInstrument)
        # Public, not exported.
        for name in (:output_id, :open_modulator!, :close_modulator!, :RecordingModulator, :modulation_violations)
            @test isdefined(MC, name) && Base.ispublic(MC, name) && !Base.isexported(MC, name)
        end
        @test :AbstractModulationControl in names(MC)
        rec = RecordingModulator(id="x")
        # The export_state fallback: the type and the output id.
        a, d, c = MC.export_state(rec)
        @test a["output_id"] == "x" && a["modulator_type"] == "RecordingModulator" && d === nothing && isempty(c)
    end

    @testset "claim and lifecycle (RecordingModulator on SimLight)" begin
        empty!(LSI.MODULATOR_OUTPUTS)
        r1, r2 = RecordingModulator(id="out"), RecordingModulator(id="out")
        l1, l2 = SimLight(modulator=r1), SimLight(modulator=r2)
        initialize(l1)
        @test r1.opened == 1 && r1.writes == [0.0] && !l1.properties.is_on
        # A second light object on the same output is refused; a re-initialize of the holder is not.
        @test_throws r"already driving" initialize(l2)
        @test r2.opened == 0 && LSI.MODULATOR_OUTPUTS["out"] === l1
        initialize(l1)
        @test r1.opened == 2
        # A failed shutdown keeps the claim for a retry; the next shutdown releases it.
        r1.failure = ErrorException("DAQ gone")
        @test_throws "DAQ gone" quiet(() -> shutdown(l1))
        @test_throws r"already driving" initialize(l2)
        r1.failure = nothing
        shutdown(l1)
        @test r1.closed == 1 && isempty(LSI.MODULATOR_OUTPUTS)
        initialize(l2)
        @test r2.opened == 1
        shutdown(l2)
        # An initialize that throws releases the claim.
        r3 = RecordingModulator(id="out")
        r3.failure = ErrorException("no output")
        l3 = SimLight(modulator=r3)
        @test_throws "no output" initialize(l3)
        @test isempty(LSI.MODULATOR_OUTPUTS)
        # A light that never opened has nothing to close.
        @test shutdown(SimLight(modulator=RecordingModulator(id="never"))) === nothing
        @test isempty(LSI.MODULATOR_OUTPUTS)
    end

    @testset "NIDAQModulator on a strict FakeDAQ" begin
        mk(daq; kw...) = NIDAQModulator(; channel="Dev1/ao1", v_range=(0.0, 5.0), per_volt=22.42, daq, kw...)
        daq = FakeDAQ()
        m = mk(daq)
        @test MC.output_id(m) == "NIDAQ Dev1/ao1"
        @test isempty(daq.log) && isempty(daq.tasks)            # construction is pure
        @test_throws "before initialize" MC.setpower(m, 1.0)
        initialize(m)
        @test daq.log == [(:create, 1, 0.0, 5.0), (:write, 1, 0.0)]   # one task with v_range, 0 V at open
        MC.setpower(m, 22.42)
        MC.setpower(m, 0.0)
        @test daq.log[end-1:end] == [(:write, 1, 1.0), (:write, 1, 0.0)]
        n = length(daq.log)
        for p in (120.0, -1.0, NaN, Inf)                         # out of reach: ArgumentError before any write
            @test_throws ArgumentError MC.setpower(m, p)
        end
        @test length(daq.log) == n
        initialize(m)                                            # one task for life
        @test count(e -> e[1] == :create, daq.log) == 1 && length(daq.tasks) == 1
        shutdown(m)
        @test daq.log[end-1:end] == [(:write, 1, 0.0), (:delete, 1)] && isempty(daq.tasks)
        @test_throws "before initialize" MC.setpower(m, 1.0)
        @test shutdown(m) === nothing

        # A failed initialize deletes the task it made.
        daq = FakeDAQ(); daq.fail_write = true
        m = mk(daq)
        @test_throws "write refused" initialize(m)
        @test isempty(daq.tasks) && count(e -> e[1] == :create, daq.log) == count(e -> e[1] == :delete, daq.log) == 1
        # A card without the range (P6): DAQmx refuses, nothing is left behind.
        daq = FakeDAQ(card_range=(0.0, 5.0))
        m = NIDAQModulator(; channel="Dev1/ao1", v_range=(0.0, 10.0), per_volt=22.42, daq)
        @test_throws r"-200077" initialize(m)
        @test isempty(daq.tasks)
        # A delete that fails keeps the task for the next shutdown.
        daq = FakeDAQ(); m = mk(daq); initialize(m); daq.fail_delete = true
        @test_throws "delete refused" shutdown(m)
        @test length(daq.tasks) == 1
        daq.fail_delete = false
        shutdown(m)
        @test isempty(daq.tasks)

        # A shutdown whose 0 V write fails keeps the task and the claim, and the next shutdown zeroes again before the delete.
        empty!(LSI.MODULATOR_OUTPUTS)
        daq = FakeDAQ(); m = mk(daq); light = SimLight(modulator=m)
        initialize(light)
        daq.fail_write = true
        @test_throws "write refused" quiet(() -> shutdown(light))
        @test length(daq.tasks) == 1 && m.task !== nothing && LSI.MODULATOR_OUTPUTS[MC.output_id(m)] === light
        daq.fail_write = false
        n = length(daq.log)
        shutdown(light)
        @test daq.log[end-1:end] == [(:write, 1, 0.0), (:delete, 1)] && isempty(daq.tasks) && isempty(LSI.MODULATOR_OUTPUTS)

        # createtask that allocates a task and then fails its channel setup: nothing leaks ...
        empty!(LSI.MODULATOR_OUTPUTS)
        daq = FakeDAQ(); daq.fail_setup = true
        m = mk(daq); light = SimLight(modulator=m)
        @test_throws "channel setup failed" initialize(light)
        @test isempty(daq.tasks) && m.task === nothing && isempty(LSI.MODULATOR_OUTPUTS)
        # ... and when clearing it fails too, the allocated task is kept (and so is the claim) until shutdown deletes it.
        daq = FakeDAQ(); daq.fail_setup = true; daq.fail_clear = true
        m = mk(daq); light = SimLight(modulator=m)
        @test_throws "channel setup failed" quiet(() -> initialize(light))
        @test length(daq.tasks) == 1 && m.task !== nothing && !m.configured && LSI.MODULATOR_OUTPUTS[MC.output_id(m)] === light
        @test_throws r"already driving" initialize(SimLight(modulator=mk(daq)))
        daq.fail_setup = false; daq.fail_clear = false
        quiet(() -> shutdown(light))                             # no channel was ever added: nothing to zero, only the delete
        @test isempty(daq.tasks) && m.task === nothing && isempty(LSI.MODULATOR_OUTPUTS) && !any(e -> e[1] == :write, daq.log)

        # A failed re-initialize (the 0 V write fails) keeps the live task AND the claim; shutdown then releases both.
        empty!(LSI.MODULATOR_OUTPUTS)
        daq = FakeDAQ(); m = mk(daq); light = SimLight(modulator=m)
        initialize(light)
        daq.fail_write = true
        @test_throws "write refused" quiet(() -> initialize(light))
        @test length(daq.tasks) == 1 && LSI.MODULATOR_OUTPUTS[MC.output_id(m)] === light && MC.HardwareInterfaces.LightSourceInterface.holds_resources(m)
        daq.fail_write = false
        shutdown(light)
        @test isempty(daq.tasks) && isempty(LSI.MODULATOR_OUTPUTS)
        # A first initialize whose write AND delete both fail keeps the handle and the claim, so shutdown can delete it.
        empty!(LSI.MODULATOR_OUTPUTS)
        daq = FakeDAQ(); daq.fail_write = true; daq.fail_delete = true
        m = mk(daq); light = SimLight(modulator=m)
        @test_throws "write refused" quiet(() -> initialize(light))
        @test length(daq.tasks) == 1 && m.task !== nothing && LSI.MODULATOR_OUTPUTS[MC.output_id(m)] === light
        @test_throws r"already driving" initialize(SimLight(modulator=mk(daq)))          # nobody else may take the output
        daq.fail_write = false; daq.fail_delete = false
        shutdown(light)
        @test isempty(daq.tasks) && m.task === nothing && isempty(LSI.MODULATOR_OUTPUTS)
        # ... and a modulator that holds nothing releases the claim of a failed initialize, as before.
        empty!(LSI.MODULATOR_OUTPUTS)
        daq = FakeDAQ(card_range=(0.0, 5.0)); m = NIDAQModulator(; channel="Dev1/ao1", v_range=(0.0, 10.0), per_volt=22.42, daq)
        @test_throws r"-200077" initialize(SimLight(modulator=m))
        @test isempty(LSI.MODULATOR_OUTPUTS) && isempty(daq.tasks)

        # A bipolar output still refuses a negative level, before any write.
        daq = FakeDAQ(card_range=(-5.0, 5.0))
        mb = NIDAQModulator(; channel="Dev1/ao1", v_range=(-5.0, 5.0), per_volt=22.42, daq)
        initialize(mb)
        n = length(daq.log)
        for p in (-1.0, -22.42, -Inf, NaN)
            @test_throws ArgumentError MC.setpower(mb, p)
        end
        @test length(daq.log) == n
        MC.setpower(mb, 22.42); @test daq.log[end] == (:write, 1, 1.0)
        shutdown(mb)

        # Construction.
        @test_throws UndefKeywordError NIDAQModulator(; channel="Dev1/ao1", v_range=(0.0, 5.0), daq=FakeDAQ())
        for bad in (0.0, -1.0, NaN, Inf)
            @test_throws ArgumentError mk(FakeDAQ(); per_volt=bad)
        end
        @test_throws ArgumentError NIDAQModulator(; channel="Dev1/ao1", v_range=(1.0, 5.0), per_volt=1.0)   # 0 V must be reachable
        @test_throws ArgumentError NIDAQModulator(; channel="Dev1/ao1", v_range=(5.0, 0.0), per_volt=1.0)
        @test_throws ArgumentError NIDAQModulator(; channel="", v_range=(0.0, 5.0), per_volt=1.0)
        @test NIDAQModulator(; channel="Dev1/ao1", v_range=(0.0, 5.0), per_volt=1.0).daq isa NIdaq   # the default DAQ

        # On a light: the light opens and closes it.
        empty!(LSI.MODULATOR_OUTPUTS)
        daq = FakeDAQ(); light = SimLight(modulator=mk(daq))
        initialize(light)
        @test length(daq.tasks) == 1
        light_on(light); setpower(light, 22.42)
        @test daq.log[end] == (:write, 1, 1.0)
        shutdown(light)
        @test isempty(daq.tasks) && daq.log[end] == (:delete, 1)
        a, _, c = MC.export_state(m)
        @test a["output_id"] == "NIDAQ Dev1/ao1" && a["per_volt"] == 22.42 && haskey(c, "daq")
    end

    @testset "createtask keywords" begin
        @test_throws "not implemented" MC.createtask(StubDAQ(), "AO", "Dev1/ao0")
        @test_throws "not implemented" MC.createtask(StubDAQ(), "AO", "Dev1/ao0"; min_val=0.0, max_val=5.0)
        # NIdaq: a half-given or non-voltage range is refused before DAQmx is reached.
        daq = NIdaq()
        @test_throws ArgumentError MC.createtask(daq, "AO", "Dev1/ao0"; min_val=0.0)
        @test_throws ArgumentError MC.createtask(daq, "AO", "Dev1/ao0"; max_val=5.0)
        @test_throws ArgumentError MC.createtask(daq, "DO", "Dev1/port0/line0"; min_val=0.0, max_val=5.0)
    end

    # A `Triggerscope4` holds an unopened `SerialPort`, which libserialport only builds for a port the machine has.
    # `COM3` is the driver's default; the others are device nodes that exist on a Linux box without a Triggerscope.
    function a_scope()
        for port in ("COM3", "/dev/ttyS0", "/dev/tty")
            try
                return Triggerscope4(; portname=port)
            catch
            end
        end
        return nothing
    end
    scope = a_scope()
    scope === nothing && @warn "no serial port name libserialport accepts on this machine; the TriggerscopeModulator tests are skipped"
    scope === nothing || @testset "TriggerscopeModulator: pure parts" begin
        @test scope.lock isa ReentrantLock
        @test Trig.dac_range_volts(ZEROTOFIVE) == (0.0, 5.0)
        @test Trig.dac_range_volts(ZEROTOTEN) == (0.0, 10.0)
        @test Trig.dac_range_volts(PLUSMINUS5) == (-5.0, 5.0)
        @test Trig.dac_range_volts(PLUSMINUS10) == (-10.0, 10.0)
        @test Trig.dac_range_volts(PLUSMINUS2_5) == (-2.5, 2.5)
        m = TriggerscopeModulator(; scope, dac=3, range=ZEROTOFIVE, per_volt=22.42)
        @test MC.output_id(m) == "Triggerscope $(scope.portname) DAC 3" == quiet(() -> Trig.dac_output(scope, 3)).output_id
        # Construction.
        @test_throws UndefKeywordError TriggerscopeModulator(; scope, dac=3, per_volt=22.42)    # range is required
        @test_throws UndefKeywordError TriggerscopeModulator(; scope, dac=3, range=ZEROTOFIVE)  # so is per_volt
        @test_throws ArgumentError TriggerscopeModulator(; scope, dac=0, range=ZEROTOFIVE, per_volt=1.0)
        @test_throws ArgumentError TriggerscopeModulator(; scope, dac=scope.dacoutputs + 1, range=ZEROTOFIVE, per_volt=1.0)
        for bad in (0.0, -1.0, NaN)
            @test_throws ArgumentError TriggerscopeModulator(; scope, dac=3, range=ZEROTOFIVE, per_volt=bad)
        end
        # The arithmetic and the reach, in the range's own span.
        @test Trig.volts(m, 22.42) ≈ 1.0
        @test Trig.volts(m, 0.0) == 0.0
        @test Trig.volts(m, 5 * 22.42) ≈ 5.0
        for p in (-1.0, 5 * 22.42 + 1, NaN, Inf)
            @test_throws ArgumentError Trig.volts(m, p)
        end
        for rng in (PLUSMINUS5, PLUSMINUS10, PLUSMINUS2_5)                  # bipolar: a negative level is still refused
            mbip = TriggerscopeModulator(; scope, dac=7, range=rng, per_volt=1.0)
            @test_throws ArgumentError Trig.volts(mbip, -0.5)
            @test_throws ArgumentError MC.setpower(mbip, -0.5)
            @test Trig.volts(mbip, 0.5) == 0.5
        end
        m10 = TriggerscopeModulator(; scope, dac=4, range=ZEROTOTEN, per_volt=15.0)
        @test Trig.volts(m10, 150.0) ≈ 10.0
        @test_throws ArgumentError Trig.volts(m10, 151.0)
        # ... and what the DAC would be sent for it.
        scope.dacranges[3] = ZEROTOFIVE
        @test Trig.volttooutput(scope, 3, 1.0) == round(Int, 65535 / 5)
        # setpower refuses before touching the serial port: out of reach (ArgumentError), not opened, range moved.
        @test_throws ArgumentError MC.setpower(m, 1e9)
        @test_throws "before initialize" MC.setpower(m, 1.0)
        m.is_open = true
        scope.dacranges[3] = PLUSMINUS10
        @test_throws r"not ZEROTOFIVE" MC.setpower(m, 1.0)
        m.is_open = false
        # The compause warning, from the pure check initialize runs first.
        scope.compause = 0.1
        @test_logs (:warn, r"compause = 0.1") Trig.check_compause(m)
        scope.compause = 0.0
        @test_logs Trig.check_compause(m)
        # The range check, the encoding and the cache run under the scope's lock: with another task holding it,
        # nothing changes and nothing is sent. (The waiting task is interrupted before it can reach the serial port.)
        before = scope.dacranges[5]
        lock(scope.lock)
        waiter = @async try Trig.setrange(scope, 5, before == ZEROTOTEN ? ZEROTOFIVE : ZEROTOTEN) catch e; e end
        sleep(0.1)
        @test scope.dacranges[5] == before                    # the cache is updated under the lock, not before it
        schedule(waiter, InterruptException(); error=true)
        @test fetch(waiter) isa InterruptException
        m6 = TriggerscopeModulator(; scope, dac=6, range=ZEROTOFIVE, per_volt=22.42)
        m6.is_open = true                                      # the scope's range for DAC 6 is not ZEROTOFIVE: setpower would refuse
        waiter = @async try MC.setpower(m6, 1.0) catch e; e end
        sleep(0.1)
        @test !istaskdone(waiter)                             # ... but only after it holds the lock
        schedule(waiter, InterruptException(); error=true)
        @test fetch(waiter) isa InterruptException
        unlock(scope.lock)
        # The serial transaction replaced by a recorder (`COMMAND_SEAM`): no port is touched. A RANGE command that fails leaves the
        # device's range ambiguous, so the cache is not changed and the DAC refuses writes (a requested 0 V would else be encoded
        # for the wrong range) until a RANGE succeeds.
        sc = a_scope(); sc.compause = 0.0
        sent = String[]; failing = Ref(false)
        Trig.COMMAND_SEAM[] = (scope_, cmd) -> (push!(sent, cmd); failing[] && startswith(cmd, "RANGE") ? error("serial gone") : "OK")
        try
            Trig.setrange(sc, 8, ZEROTOFIVE)
            @test sc.dacranges[8] == ZEROTOFIVE && sent == ["RANGE8,1\n"] && !(8 in sc.range_unknown)
            failing[] = true
            @test_throws "serial gone" Trig.setrange(sc, 8, PLUSMINUS10)
            @test sc.dacranges[8] == ZEROTOFIVE && 8 in sc.range_unknown            # not trusted, not changed
            n = length(sent)
            @test_throws "range is unknown" Trig.setdac(sc, 8, 0.0)
            @test length(sent) == n                                                  # nothing was sent for it
            failing[] = false
            Trig.setrange(sc, 8, ZEROTOFIVE)
            @test !(8 in sc.range_unknown)
            Trig.setdac(sc, 8, 0.0)
            @test sent[end] == "DAC8,0\n"
            # A modulator through the same seam: its lifecycle, its writes, and its claim across a failed re-initialize.
            empty!(LSI.MODULATOR_OUTPUTS)
            tm = TriggerscopeModulator(; scope=sc, dac=9, range=ZEROTOFIVE, per_volt=22.42)
            light = SimLight(modulator=tm)
            empty!(sent)
            initialize(light)
            @test sent == ["RANGE9,1\n", "DAC9,0\n"] && tm.is_open && MC.HardwareInterfaces.LightSourceInterface.holds_resources(tm)
            light_on(light); setpower(light, 22.42)
            @test sent[end] == "DAC9,13107\n"
            failing[] = true
            @test_throws "serial gone" quiet(() -> initialize(light))                # a failed re-initialize ...
            @test tm.is_open && LSI.MODULATOR_OUTPUTS[MC.output_id(tm)] === light     # ... keeps its claim
            @test 9 in sc.range_unknown
            failing[] = false
            shutdown(light)                                                          # re-sets the range, then zeroes
            @test sent[end-1:end] == ["RANGE9,1\n", "DAC9,0\n"] && !tm.is_open && isempty(LSI.MODULATOR_OUTPUTS)
        finally
            Trig.COMMAND_SEAM[] = nothing
        end
        # The positional constructor from before the lock field (19 arguments) still builds a scope, with its own lock.
        fields = fieldnames(Triggerscope4)[1:19]
        scope2 = Triggerscope4(getfield.(Ref(scope), fields)...)
        @test scope2.lock isa ReentrantLock && scope2.lock !== scope.lock && scope2.portname == scope.portname
        a, d, c = MC.export_state(m)
        @test a["output_id"] == MC.output_id(m) && a["dac"] == 3 && a["range"] == "ZEROTOFIVE" && a["per_volt"] == 22.42
        @test shutdown(m) === nothing   # not open: no serial write
    end

    @testset "SimLight and SimDiodeLaser with a modulator" begin
        # SimLight: the plain-setpower reference.
        empty!(LSI.MODULATOR_OUTPUTS)
        rec = RecordingModulator(id="sl")
        l = SimLight(modulator=rec)
        initialize(l)
        @test !l.properties.is_on && rec.writes == [0.0]
        setpower(l, 2.0)                                   # off: recorded, not written
        @test l.properties.power == 2.0 && rec.writes == [0.0]
        light_on(l)
        @test l.properties.is_on && rec.writes == [0.0, 0.0, 2.0]
        setpower(l, 3.0)
        @test rec.writes[end] == 3.0
        rec.reach = 5.0
        @test_throws ArgumentError setpower(l, 9.0)       # out of reach: changes nothing
        @test l.properties.power == 3.0 && l.properties.is_on && rec.writes[end] == 3.0
        rec.failure = ErrorException("DAQ gone")
        @test_throws "DAQ gone" quiet(() -> setpower(l, 4.0))   # any other throw darkens
        @test !l.properties.is_on && l.properties.power == 3.0 && rec.attempts[end] == 0.0
        @test_throws "DAQ gone" quiet(() -> light_on(l))   # and a light_on throw enables nothing
        @test !l.properties.is_on
        rec.failure = nothing
        light_on(l); rec.failure = ErrorException("DAQ gone")
        quiet(() -> light_off(l))                          # light_off logs and switches off
        @test !l.properties.is_on
        rec.failure = nothing
        shutdown(l)
        @test rec.closed == 1 && isempty(LSI.MODULATOR_OUTPUTS) && rec.writes[end] == 0.0
        # Without a modulator: unchanged (on after initialize, no claim).
        plain = SimLight(); initialize(plain)
        @test plain.properties.is_on && isempty(LSI.MODULATOR_OUTPUTS)

        # SimLight keeps its converting two-argument constructor.
        sl = SimLight(SubString("a simlight", 3, 10), LightSourceProperties("mW", 0.0, false, 0.0, 100.0))
        @test sl.unique_id == "simlight" && sl.unique_id isa String && sl.modulator === nothing

        # A recorded level the modulator then refuses: light_on has enabled, so every throw darkens.
        empty!(LSI.MODULATOR_OUTPUTS)
        rec = RecordingModulator(id="ref1", reach=5.0)
        l = SimLight(modulator=rec); initialize(l)
        setpower(l, 9.0)                                   # off: recorded
        @test_throws ArgumentError light_on(l)
        @test !l.properties.is_on && rec.attempts[end] == 0.0
        rec2 = RecordingModulator(id="ref2", reach=10.0)
        sim = SimDiodeLaser(modulator=rec2); initialize(sim)
        setcurrent!(sim, 40.0)
        @test_throws ArgumentError light_on(sim)
        @test !sim.properties.is_on && !sim.output_enabled && sim.setpoint == 0.0

        # An interrupted activation sleep darkens: the whole tail after the enable is protected.
        empty!(LSI.MODULATOR_OUTPUTS)
        rec = RecordingModulator(id="settle")
        sim = SimDiodeLaser(modulator=rec, settle_s=0.4); initialize(sim)
        quiet(() -> setcurrent!(sim, 40.0))
        t = @async try light_on(sim) catch e; e end
        sleep(0.1)                                         # inside _settle, after the enable
        @test sim.properties.is_on && sim.output_enabled
        schedule(t, InterruptException(); error=true)
        @test fetch(t) isa InterruptException
        @test !sim.properties.is_on && !sim.output_enabled && sim.setpoint == 0.0 && rec.attempts[end] == 0.0
        n = length(rec.writes)
        quiet(() -> setcurrent!(sim, 30.0))                 # a later setter does not drive the modulator
        @test length(rec.writes) == n

        # An interrupted 0 V write still switches off first.
        for mk in (() -> SimLight(modulator=RecordingModulator(id="int1")), () -> SimDiodeLaser(modulator=RecordingModulator(id="int2")))
            empty!(LSI.MODULATOR_OUTPUTS)
            l = mk(); initialize(l); light_on(l)
            l.modulator.failure = InterruptException()
            @test_throws InterruptException quiet(() -> light_off(l))
            @test !l.properties.is_on
            l.modulator.failure = nothing; light_on(l)
            l.modulator.failure = InterruptException()
            @test_throws InterruptException quiet(() -> shutdown(l))
            @test !l.properties.is_on
        end

        # SimDiodeLaser, open loop: the same convention; the model follows the level the modulator was given.
        for mode in (:cc, :cp)
            empty!(LSI.MODULATOR_OUTPUTS)
            rec = RecordingModulator(id="sd-$mode")
            sim = mode === :cc ? SimDiodeLaser(; mode=ConstantCurrent(), modulator=rec) :
                  SimDiodeLaser(; mode=ConstantPhotocurrent(), max_current=160.0, wa_calibration=224.2, tia_range=1e-3,
                                tec_stabilised=missing, properties=props(), modulator=rec)
            initialize(sim)
            @test rec.opened == 1 && rec.writes == [0.0] && !sim.properties.is_on
            setlvl!(sim, mode, LV1[mode])                  # off: recorded, nothing written, still dark
            @test rec.writes == [0.0] && requested(sim, mode) == LV1[mode] && sim.setpoint == 0.0
            light_on(sim)
            @test rec.writes == [0.0, 0.0, LV1[mode]] && sim.properties.is_on && sim.setpoint > 0
            before = (requested(sim, mode), sim.setpoint)
            setlvl!(sim, mode, LV2[mode])
            @test rec.writes[end] == LV2[mode] && sim.setpoint > before[2]
            rec.reach = LV2[mode]
            @test_throws ArgumentError setlvl!(sim, mode, LV2[mode] + 1.0)
            @test rec.writes[end] == LV2[mode] && sim.properties.is_on
            rec.failure = ErrorException("DAQ gone")
            @test_throws "DAQ gone" quiet(() -> setlvl!(sim, mode, LV1[mode]))
            @test !sim.properties.is_on && !sim.output_enabled && sim.setpoint == 0.0 && rec.attempts[end] == 0.0
            @test requested(sim, mode) == LV2[mode]       # the failed request is not recorded
            rec.failure = nothing
            light_off(sim)
            @test rec.writes[end] == 0.0
            shutdown(sim)
            @test rec.closed == 1 && isempty(LSI.MODULATOR_OUTPUTS)
            @test haskey(MC.export_state(sim)[3], "modulator") == true
        end
        # ... and with none, the exported children and the setpoint are as they were.
        plain = SimDiodeLaser(); initialize(plain); setcurrent!(plain, 20.0)
        @test plain.setpoint == 20.0 && isempty(MC.export_state(plain)[3])
    end

    for kind in (:cc, :cp)
    @testset "TCube with a modulator, $(kind === :cc ? "open loop" : "closed loop")" begin
        lv, lv2 = LV1[kind], LV2[kind]

        @testset "initialize: modulator at 0 V, source 3 set while off, never enabled" begin
            l = ready(kind)
            m = l.modulator
            @test m.opened == 1 && m.volts == [0.0] && haskey(LSI.MODULATOR_OUTPUTS, "mod1")
            @test FK.source[] == 3 && l.source_before == 5                   # the fake starts at 5
            @test "LD_EnableOutput" ∉ FK.calls && !FK.enabled() && !l.properties.is_on
            @test idx("MOD 0.0") < idx("LD_SetControlSource")
            @test all(e -> e[1] == 0 && e[2] == 0, FK.setpoint_log)
            # Kept across a re-initialize: the first source found is the one restored (a 3 would read back as 1).
            quiet(() -> initialize(l))
            @test l.source_before == 5 && FK.source[] == 3 && m.opened == 2
            quiet(() -> shutdown(l))
            @test FK.source[] == 5 && l.source_before === nothing && m.closed == 1 && isempty(LSI.MODULATOR_OUTPUTS)
            quiet(() -> initialize(l))                                       # a new cycle records again
            @test l.source_before == 5
            quiet(() -> shutdown(l))
            # A failed step releases the modulator and the claim, and closes the handle.
            l = ready(kind)
            FK.throw!("LD_SetControlSource")
            @test_throws "fake Kinesis failure" quiet(() -> initialize(l))
            @test "LD_Close" in FK.calls && isempty(LSI.MODULATOR_OUTPUTS) && l.modulator.closed == 1
        end

        @testset "untouched with modulator = nothing" begin
            l = ready(kind; modulator=nothing)
            quiet(() -> (setlvl!(l, kind, lv); light_on(l); setlvl!(l, kind, lv2); light_off(l); light_on(l); shutdown(l)))
            @test FK.source[] == 5 && isempty(FK.mod_volts)
            @test "LD_SetControlSource" ∉ FK.calls && "LD_RequestControlSource" ∉ FK.calls && "LD_GetControlSource" ∉ FK.calls
            @test isempty(LSI.MODULATOR_OUTPUTS) && !any(c -> startswith(c, "MOD"), FK.calls)
        end

        @testset "setters while off write nothing" begin
            l = ready(kind); m = l.modulator
            empty!(FK.calls); n = length(m.attempts)
            quiet(() -> (setlvl!(l, kind, lv); setlvl!(l, kind, lv2); setlevel!(l, 0.5)))
            @test isempty(FK.calls) && length(m.attempts) == n          # no USB call, no modulator write
            @test requested(l, kind) ≈ (kind === :cp ? 1.0 + 0.5 * 69.0 : 0.0 + 0.5 * TCmod.effective_max_current(l))
            @test_throws ArgumentError setlvl!(l, kind, kind === :cp ? 80.0 : 200.0)   # validated as always
            @test isempty(FK.calls) && length(m.attempts) == n
        end

        @testset "light_on: the order of the steps, the wait, the confirm" begin
            l = ready(kind; settle=0.15); m = l.modulator
            quiet(() -> setlvl!(l, kind, lv))
            empty!(FK.calls); empty!(FK.setpoints)
            elapsed = @elapsed quiet(() -> light_on(l))
            ops = [c for c in FK.calls if c in ("LD_EnableOutput", "LD_SetLaserSetPoint", "LD_DisableOutput") || startswith(c, "MOD ")]
            @test ops[1:3] == ["MOD 0.0", "LD_EnableOutput", "LD_SetLaserSetPoint"]
            @test startswith(ops[4], "MOD ") && ops[4] != "MOD 0.0" && length(ops) == 4
            @test lastidx("LD_GetLaserSetPoint") > modwrites()[2]       # the confirm reads after the level is on
            @test FK.setpoints == [0x0000]                                # the only USB setpoint is the zero
            @test m.times[end] - FK.last_write_t[] >= 0.15 - 1e-3        # the wait between the zero and the level
            @test elapsed >= 0.15
            @test l.properties.is_on && FK.enabled()
            @test abs(FK.held_total() - words_of(kind, lv)) <= 2
            # A second light_on while on reruns all of it.
            empty!(FK.calls)
            quiet(() -> light_on(l))
            @test length(modwrites()) == 2 && FK.calls[modwrites()[1]] == "MOD 0.0" && l.properties.is_on
            empty!(FK.calls)
            quiet(() -> light_off(l))
            @test !FK.enabled() && m.volts[end] == 0.0 && FK.ext_words[] == 0
            @test idx("MOD 0.0") < idx("LD_SetLaserSetPoint") < idx("LD_DisableOutput")   # 0 V, then USB 0 and the disable
            TCmod.MOD_SETTLE_S[] = 0.0
        end

        @testset "level setters while on: one modulator write, no USB call" begin
            l = ready(kind); m = l.modulator
            quiet(() -> (setlvl!(l, kind, lv); light_on(l)))
            empty!(FK.calls)
            quiet(() -> setlvl!(l, kind, lv2))
            @test length(FK.calls) == 1 && startswith(FK.calls[1], "MOD ")
            @test abs(FK.held_total() - words_of(kind, lv2)) <= 2
            @test requested(l, kind) == lv2
            quiet(() -> setlevel!(l, 0.25))
            @test length(FK.calls) == 2 && all(c -> startswith(c, "MOD "), FK.calls)
            quiet(() -> light_off(l))
        end

        @testset "every USB setpoint is 0 or the reference, at 0 V" begin
            ref = kind === :cp ? (; ref_current_mA=90.0, ref_photocurrent_A=FK.pd_word_at(90.0) / 32767 * 1e-3) : (;)
            l = ready(kind; ref...)
            quiet() do
                setlvl!(l, kind, lv)
                light_on(l)
                setlvl!(l, kind, lv2)
                light_on(l)
                light_off(l)
                setlvl!(l, kind, lv)
                light_on(l)
                initialize(l)          # re-initialize while lit: 0 V first, then the zero
                light_on(l)
                shutdown(l)
            end
            refcode = kind === :cp ? Int(TCmod.setpoint_code(l, 90.0)) : 0
            @test !isempty(FK.setpoint_log)
            @test all(e -> e[2] == 0 && e[1] in (0, refcode), FK.setpoint_log)
            kind === :cp && @test count(e -> e[1] == refcode, FK.setpoint_log) == 2   # the check ran, once per initialize
        end

        @testset "the confirm refuses, ending off at 0 V" begin
            function refused(l; during=nothing)
                task = during === nothing ? nothing : @async(during())
                quiet() do
                    @test_throws r"setpoint register|superseded" light_on(l)
                end
                task === nothing || wait(task)
                @test !l.properties.is_on && !FK.enabled() && FK.ext_words[] == 0
                @test l.modulator.volts[end] == 0.0 && "LD_DisableOutput" in FK.calls
            end
            # (a) the controller loses a MOD IN change made within its window; MOD_SETTLE_S is shorter than the window.
            l = ready(kind); quiet(() -> setlvl!(l, kind, lv))
            FK.settle_s[] = 0.3
            refused(l)
            #     ... and with MOD_SETTLE_S above the window it lands.
            TCmod.MOD_SETTLE_S[] = 0.35
            quiet(() -> light_on(l))
            @test l.properties.is_on && abs(FK.held_total() - words_of(kind, lv)) <= 2
            quiet(() -> light_off(l))
            # (b) a per_volt the manual's 3.2x too high.
            l = ready(kind; modulator=modin(kind; scale=3.2)); quiet(() -> setlvl!(l, kind, lv))
            refused(l)
            #     ... and one too low (cp: 2.85 V is within reach; cc: 8 V is not, and light_on refuses all the same).
            if kind === :cp
                l = ready(kind; modulator=modin(kind; scale=1 / 3.2)); quiet(() -> setlvl!(l, kind, lv))
                refused(l)
            end
            # (d) a light_off during the wait supersedes the activation (it writes nothing more) and the light is off.
            l = ready(kind; settle=0.4); quiet(() -> setlvl!(l, kind, lv))
            refused(l; during=() -> (sleep(0.15); light_off(l)))
            TCmod.MOD_SETTLE_S[] = 0.0
        end

        @testset "an ArgumentError keeps the old level; a transport throw ends off" begin
            l = ready(kind); m = l.modulator
            quiet(() -> (setlvl!(l, kind, lv); light_on(l)))
            m.v_max = kind === :cp ? 1.0 : 3.0                          # reaches lv, not lv2
            words = FK.held_total(); nw = length(m.volts)
            @test_throws ArgumentError quiet(() -> setlvl!(l, kind, lv2))
            @test requested(l, kind) == lv && l.properties.is_on && FK.enabled()
            @test FK.held_total() == words && length(m.volts) == nw && m.volts[end] > 0   # no write, no 0
            @test_throws ArgumentError quiet(() -> setlvl!(l, kind, kind === :cp ? 80.0 : 200.0))   # the driver's own check
            @test requested(l, kind) == lv && l.properties.is_on
            # A transport failure: level 0 is tried, the light is off, the error reaches the caller, the request is not recorded.
            m.failure = ErrorException("DAQ gone")
            empty!(FK.calls)
            @test_throws "DAQ gone" quiet(() -> setlvl!(l, kind, lv2 - 10.0))
            @test m.attempts[end] == 0.0 && !l.properties.is_on && !FK.enabled() && "LD_DisableOutput" in FK.calls
            @test requested(l, kind) == lv
            # light_off with a failing modulator: logged, and the output is still disabled.
            m.failure = nothing; quiet(() -> light_on(l)); m.failure = ErrorException("DAQ gone")
            @test quiet(() -> light_off(l)) === nothing
            @test !l.properties.is_on && !FK.enabled()
            # light_on with a failing modulator enables nothing.
            empty!(FK.calls)
            @test_throws "DAQ gone" quiet(() -> light_on(l))
            @test "LD_EnableOutput" ∉ FK.calls && !l.properties.is_on && !FK.enabled()
            # A failure of the level itself (not of the 0 V before the enable): off again, 0 tried.
            m.failure = nothing; m.fail_nonzero = ErrorException("level refused")
            empty!(FK.calls)
            @test_throws "level refused" quiet(() -> light_on(l))
            @test "LD_EnableOutput" in FK.calls && "LD_DisableOutput" in FK.calls && !l.properties.is_on && !FK.enabled()
            @test m.attempts[end] == 0.0 && FK.ext_words[] == 0
            # An out-of-reach request at light_on is an ArgumentError, with the light dark.
            m.fail_nonzero = nothing; m.v_max = 0.5
            @test_throws ArgumentError quiet(() -> light_on(l))
            @test !l.properties.is_on && !FK.enabled() && FK.ext_words[] == 0
        end

        @testset "shutdown: 0 V, disable, source restored, claim released" begin
            l = ready(kind); m = l.modulator
            quiet(() -> (setlvl!(l, kind, lv); light_on(l)))
            empty!(FK.calls)
            quiet(() -> shutdown(l))
            @test idx("MOD 0.0") < idx("LD_DisableOutput") < idx("LD_SetControlSource") < idx("LD_Close")
            @test FK.source[] == 5 && m.closed == 1 && isempty(LSI.MODULATOR_OUTPUTS) && !FK.enabled()
        end

        @testset "the claim: a second light is refused; a failed shutdown(mc) keeps it" begin
            l1 = ready(kind; strict=false)                               # one fake handle serves both serials
            l2 = tcube(kind; modulator=modin(kind))                      # same output id
            @test_throws r"already driving" quiet(() -> initialize(l2))
            @test "LD_Close" in FK.calls && FK.source[] == 3              # l2's handle closed; l1's source untouched
            m1 = l1.modulator
            m1.shutdown_failure = ErrorException("DAQ gone")
            @test_throws "DAQ gone" quiet(() -> shutdown(l1))
            @test FK.source[] == 5                                        # the source was restored, the handle closed
            @test_throws r"already driving" quiet(() -> initialize(l2))
            m1.shutdown_failure = nothing
            quiet(() -> shutdown(l1))                                     # the retry
            @test m1.closed == 1 && isempty(LSI.MODULATOR_OUTPUTS)
            quiet(() -> initialize(l2))
            @test haskey(LSI.MODULATOR_OUTPUTS, "mod1")
            quiet(() -> shutdown(l2))
        end

        @testset "a level change during the wait is applied by the activation (Codex's case)" begin
            # No request when light_on starts (code 0). A setter inside the controller's loss window used to write MOD IN
            # (absorbed), and the confirm then passed on the old zero. Now an arming light only records; the
            # activation applies the CURRENT request after the wait, outside the window.
            l = ready(kind; settle=0.4); m = l.modulator
            FK.settle_s[] = 0.3
            task = @async (sleep(0.1); setlvl!(l, kind, lv))
            quiet(() -> light_on(l))
            wait(task)
            @test l.properties.is_on && !l.arming && FK.enabled()
            @test abs(FK.held_total() - words_of(kind, lv)) <= 2 && requested(l, kind) == lv
            quiet(() -> setlvl!(l, kind, lv2))                                  # and the next request lands right
            @test abs(FK.held_total() - words_of(kind, lv2)) <= 2
            @test isempty(FK.violations)
            quiet(() -> light_off(l))
            TCmod.MOD_SETTLE_S[] = 0.0
        end

        @testset "a superseded activation writes nothing more" begin
            l = ready(kind; settle=0.3); m = l.modulator
            quiet(() -> setlvl!(l, kind, lv))
            err = Ref{Any}(nothing)
            n_after_off = Ref(0)
            off = @async (sleep(0.1); light_off(l))
            act = @async try light_on(l) catch e; e end
            quiet() do
                wait(off)
                n_after_off[] = length(FK.calls)
                err[] = fetch(act)
            end
            @test occursin("superseded", sprint(showerror, err[]))
            @test length(FK.calls) == n_after_off[]                            # it touched neither MOD IN nor the controller
            @test !l.properties.is_on && !FK.enabled() && FK.ext_words[] == 0 && isempty(FK.violations)
            TCmod.MOD_SETTLE_S[] = 0.0
        end

        @testset "concurrency: an intruder lands at each critical point" begin
            # Another task's setter, light_off, initialize or light_on lands in the middle of an activation: in the
            # preflight, between the enable and USB 0, during the sleep, and between the MOD write and its read-back.
            # Joins are bounded, so a deadlock fails the test instead of hanging it.
            intruders = ("setter" => l -> setlvl!(l, kind, lv2), "light_off" => l -> light_off(l),
                         "initialize" => l -> initialize(l), "light_on" => l -> light_on(l))
            preflight_op = kind === :cp ? "LD_RequestStatusBits" : "LD_RequestLaserDiodeMaxCurrentLimit"
            points = ("preflight" => (preflight_op, 1), "enable to USB 0" => ("LD_SetLaserSetPoint", 1),
                      "sleep" => (nothing, 0), "write to read-back" => ("LD_GetLaserSetPoint", 2))
            function settled(l)
                if l.properties.is_on
                    tol = max(30, ceil(Int, 0.03 * words_of(kind, requested(l, kind))))
                    return FK.enabled() && !l.arming && abs(FK.held_total() - words_of(kind, requested(l, kind))) <= tol
                end
                return !FK.enabled() && FK.ext_words[] == 0 && !l.arming
            end
            for (pname, (op, nth)) in points, (iname, intruder) in intruders
                l = ready(kind; settle=0.3)
                quiet(() -> setlvl!(l, kind, lv))
                tasks = Task[]
                run_intruder() = (try intruder(l) catch e; e end)
                if op === nothing
                    push!(tasks, @async (sleep(0.1); run_intruder()))
                else
                    FK.hook!(op, get(FK.op_counts, op, 0) + nth, () -> (push!(tasks, @async run_intruder()); yield()))
                end
                actres = Ref{Any}(nothing)
                quiet() do
                    actres[] = try light_on(l) catch e; e end
                    # bounded join: a deadlock fails here
                    @test timedwait(() -> all(istaskdone, tasks), 20.0) === :ok
                end
                @test !isempty(tasks)
                for t in tasks
                    istaskdone(t) && @test !(fetch(t) isa Exception)
                end
                @test actres[] === nothing || occursin("superseded", sprint(showerror, actres[]))
                @test isempty(FK.violations)
                @test settled(l)
                iname == "setter" && @test requested(l, kind) == lv2 && l.properties.is_on &&
                                           abs(FK.held_total() - words_of(kind, lv2)) <= max(30, ceil(Int, 0.03 * words_of(kind, lv2)))
                # Whatever happened, the next activation delivers the current request.
                TCmod.MOD_SETTLE_S[] = 0.0
                quiet(() -> light_on(l))
                @test settled(l) && l.properties.is_on && isempty(FK.violations)
                quiet(() -> light_off(l))
            end
            TCmod.MOD_SETTLE_S[] = 0.0
        end

        @testset "a failed disable stays pending and is retried by shutdown" begin
            l = ready(kind)
            quiet(() -> (setlvl!(l, kind, lv); light_on(l)))
            FK.fail!("LD_DisableOutput")
            @test_throws "LD_DisableOutput" quiet(() -> light_off(l))
            @test l.properties.is_on && l.disable_pending && FK.enabled()      # recorded off only after a successful disable
            @test_throws "LD_DisableOutput" quiet(() -> shutdown(l))
            @test !FK.opened[] && l.disable_pending && l.properties.is_on && FK.enabled()
            @test isempty(FK.violations)                                        # (the USB zero was skipped or at 0 V throughout)
            delete!(FK.status, "LD_DisableOutput")
            empty!(FK.calls)
            quiet(() -> shutdown(l))                                            # reopens deliberately for the disable
            @test FK.calls[1] == "LD_Open" && "LD_DisableOutput" in FK.calls && FK.calls[end] == "LD_Close"
            @test !l.disable_pending && !l.properties.is_on && !FK.enabled() && !FK.opened[] && isempty(LSI.MODULATOR_OUTPUTS)
        end

        @testset "a failed 0 V write skips the USB setpoint and still disables" begin
            l = ready(kind); m = l.modulator
            quiet(() -> (setlvl!(l, kind, lv); light_on(l)))
            m.failure = ErrorException("DAQ gone")
            quiet(() -> light_off(l))
            @test !FK.enabled() && !l.properties.is_on && isempty(FK.violations)
            m.failure = nothing
            quiet(() -> light_on(l))
            m.failure = ErrorException("DAQ gone")
            @test_throws "DAQ gone" quiet(() -> setlvl!(l, kind, lv2))
            @test !FK.enabled() && isempty(FK.violations)
        end

        @testset "an interrupted write still switches off, then the interrupt passes on" begin
            l = ready(kind); m = l.modulator
            quiet(() -> (setlvl!(l, kind, lv); light_on(l)))
            m.failure = InterruptException()
            @test_throws InterruptException quiet(() -> light_off(l))
            @test !FK.enabled() && !l.properties.is_on
            m.failure = nothing
            quiet(() -> light_on(l))
            m.failure = InterruptException()
            @test_throws InterruptException quiet(() -> setlvl!(l, kind, lv2))   # a setter: 0 tried, off, rethrown
            @test !FK.enabled() && !l.properties.is_on && m.attempts[end] == 0.0
            m.failure = InterruptException()
            empty!(FK.calls)
            @test_throws InterruptException quiet(() -> light_on(l))              # level 0 before the enable
            @test "LD_EnableOutput" ∉ FK.calls && !FK.enabled()
            m.failure = nothing; m.fail_nonzero = InterruptException()
            @test_throws InterruptException quiet(() -> light_on(l))              # the level itself, after the enable
            @test !FK.enabled() && !l.properties.is_on && FK.ext_words[] == 0
            m.fail_nonzero = nothing
            quiet(() -> light_on(l))
            m.failure = InterruptException()
            @test_throws InterruptException quiet(() -> shutdown(l))
            @test !FK.enabled() && !FK.opened[]                                   # disabled and the handle closed first
        end

        @testset "a failed preflight on a second light_on leaves 0 V and no USB write at a level" begin
            l = ready(kind); m = l.modulator
            quiet(() -> (setlvl!(l, kind, lv); light_on(l)))
            @test FK.ext_words[] != 0
            kind === :cc ? (FK.diode_limit_raw[] = 32767) : FK.setbits!(FK.CLOSED; on=false)   # the clamp / mode check refuses
            empty!(FK.setpoint_log)
            @test_throws r"refused" quiet(() -> light_on(l))
            @test !FK.enabled() && !l.properties.is_on
            @test FK.ext_words[] == 0 && m.volts[end] == 0.0
            @test !isempty(FK.setpoint_log) && all(e -> e[1] == 0 && e[2] == 0, FK.setpoint_log)   # every USB write at 0 V
        end

        @testset "shutdown retried after the handle closed touches no closed handle" begin
            l = ready(kind); m = l.modulator
            m.shutdown_failure = ErrorException("DAQ gone")
            @test_throws "DAQ gone" quiet(() -> shutdown(l))
            @test !FK.opened[] && !l.connected && FK.source[] == 5
            empty!(FK.calls)
            m.shutdown_failure = nothing
            quiet(() -> shutdown(l))                                            # the strict fake raises on any LD_ call now
            @test m.closed == 1 && isempty(LSI.MODULATOR_OUTPUTS) && !any(c -> startswith(c, "LD_"), FK.calls)
            # A source restore still pending reopens the handle for that one command, then closes it.
            l = ready(kind)
            FK.throw!("LD_SetControlSource")
            @test_throws "fake Kinesis failure" quiet(() -> shutdown(l))
            @test !FK.opened[] && l.source_before == 5 && FK.source[] == 3
            delete!(FK.throws, "LD_SetControlSource")
            empty!(FK.calls)
            quiet(() -> shutdown(l))
            @test FK.source[] == 5 && l.source_before === nothing && !FK.opened[]
            @test FK.calls[1] == "LD_Open" && FK.calls[end] == "LD_Close" && "LD_SetControlSource" in FK.calls
            @test isempty(LSI.MODULATOR_OUTPUTS)
        end

        @testset "export_state carries the modulator as a child" begin
            l = ready(kind)
            a, d, c = MC.export_state(l)
            @test haskey(c, "daq") && c["modulator"][1]["output_id"] == "mod1"
            @test !haskey(MC.export_state(ready(kind; modulator=nothing))[3], "modulator")
        end
    end
    end

    @testset "modulation_violations" begin
        function sinked(kind)
            RecordingModulator(id="rec-$kind", sink=p -> FK.apply_ext!(words_of(kind, p)))
        end
        for kind in (:cc, :cp)
            l = ready(kind; modulator=sinked(kind))
            viol = quiet(() -> MC.modulation_violations(l; set! = x -> setlvl!(x, kind, LV1[kind]), expect = LV1[kind]))
            @test viol == String[]
            @test !l.properties.is_on
        end
        for (name, mk) in (
            "SimLight" => () -> (l = SimLight(modulator=RecordingModulator(id="v1")); (l, x -> setpower(x, 2.0), 2.0)),
            "SimDiodeLaser current" => () -> (l = SimDiodeLaser(modulator=RecordingModulator(id="v2")); (l, x -> setcurrent!(x, 20.0), 20.0)),
            "SimDiodeLaser power" => () -> (l = SimDiodeLaser(; mode=ConstantPhotocurrent(), max_current=160.0, wa_calibration=224.2,
                tia_range=1e-3, tec_stabilised=missing, properties=props(), modulator=RecordingModulator(id="v3"));
                (l, x -> setoutputpower!(x, 20.0), 20.0)),
        )
            empty!(LSI.MODULATOR_OUTPUTS)
            l, set!, expect = mk()
            initialize(l)
            @test (name => quiet(() -> MC.modulation_violations(l; set!, expect))) == (name => String[])
        end

        # A light that breaks the convention is found, each in its own way.
        function violations(flavor)
            empty!(LSI.MODULATOR_OUTPUTS)
            l = BadLight(flavor)
            quiet(() -> MC.modulation_violations(l; set! = x -> MC.setpower(x, 2.0), expect = 2.0))
        end
        @test any(v -> occursin("wrote nothing", v), violations(:ignores))
        @test any(v -> occursin("while the light was off reached the output", v), violations(:writes_while_off))
        @test any(v -> occursin("not level 0", v), violations(:no_zero_first))
        @test any(v -> occursin("still on", v), violations(:no_darken))
        @test any(v -> occursin("did not reach the caller", v), violations(:swallows))
        # Missing pieces are reported, not thrown.
        @test MC.modulation_violations(NoField(); set! = identity, expect = 1.0) == ["NoField has no `modulator` field"]
        @test any(v -> occursin("RecordingModulator", v),
                  MC.modulation_violations(BadLight(:ignores; modulator=nothing); set! = identity, expect = 1.0))
    end

    @testset "setupIO and set_modvoltage are deprecated, naming the modulator" begin
        # Discovery is replaced above (one device, no channels), so setupIO stops before it could make a task, and
        # `task_mod` stays 0, so set_modvoltage has no task to write to: neither can reach DAQmx.
        l = cc()
        @test MC.showdevices(l.daq) == ["FakeDev1"]
        err = nothing
        @test_deprecated r"NIDAQModulator" (err = try TCmod.setupIO(l); nothing catch e; e end)
        @test err isa ErrorException && occursin("2nd DAQ device", err.msg)
        l2 = cc(daq_device="FakeDev1")
        err = nothing
        @test_deprecated r"NIDAQModulator" (err = try TCmod.setupIO(l2); nothing catch e; e end)
        @test err isa ErrorException && occursin("AO channel", err.msg)
        err = nothing
        @test_deprecated r"NIDAQModulator" (err = try TCmod.set_modvoltage(l, 1.0); nothing catch e; e end)
        @test err isa ErrorException && occursin("not implemented", err.msg)
        @test l.task_mod == 0 && l2.task_mod == 0
    end

    FK.reset!()
    TCmod.MOD_SETTLE_S[] = 0.0
    empty!(LSI.MODULATOR_OUTPUTS)
end

end # module
