# The Triggerscope driver against a fake serial port.
#
# There is no Triggerscope on any build machine. The driver's serial calls go through five one-line wrappers in
# `triggerscope/helper_functions.jl` (`_new_port`, `_arm_timeouts!`, `_flush_port!`, `_send!`, `_receive!`), and
# `openport` and `closeport` are plain functions of the same module. Defining methods with the same signatures in
# that module replaces them (the seam of `tcube_fake_sdk.jl`), so the constructor, `writecommand`, `readresponse`
# and every command function run unmodified against a recorder, and no test reaches the host's serial layer: the
# fake `_new_port` builds a never-opened `SerialPort` on a NULL port (`sp_get_port_by_name` refuses a made-up name
# on Linux, which failed CI), and libserialport's `sp_free_port` ignores NULL when the finalizer runs.
#
# The fake models the defect the per-command timeout fixes: LibSerialPort's read timeout is a CUMULATIVE budget.
# Each `_receive!` spends `cost_s` of it, and once it is spent the read throws, as LibSerialPort's `Timeout` does.
# `_arm_timeouts!` refills it.
#
# Like the other fakes, the replacements are global and permanent for the process, which is why runtests.jl includes
# this file last; Julia prints a "Method definition ... overwritten" warning for each.

module FakeTriggerscopePort

mutable struct PortState
    budget_s::Float64        # what is left of the read timeout
    cost_s::Float64          # what one reply read spends of it
    events::Vector{Tuple{Symbol,Any}}   # (:new_port | :arm | :flush | :send | :receive | :open | :close, detail)
    fail_send::Bool          # the next `_send!` throws
    send_delay_s::Float64    # a `_send!` yields this long, so another task could interleave
end

const STATE = PortState(0.0, 0.001, Tuple{Symbol,Any}[], false, 0.0)
const STATE_LOCK = ReentrantLock()

function reset!(; cost_s = 0.001, send_delay_s = 0.0)
    lock(STATE_LOCK) do
        STATE.budget_s = 0.0
        STATE.cost_s = cost_s
        empty!(STATE.events)
        STATE.fail_send = false
        STATE.send_delay_s = send_delay_s
    end
    return nothing
end

record!(kind, detail = nothing) = lock(() -> push!(STATE.events, (kind, detail)), STATE_LOCK)
events() = lock(() -> copy(STATE.events), STATE_LOCK)
count_events(kind) = count(e -> e[1] === kind, events())

end # module

const TS_MODULE = MicroscopeControl.HardwareImplementations.Triggerscope

@eval TS_MODULE begin
    function _new_port(portname)
        Main.FakeTriggerscopePort.record!(:new_port, portname)
        return LibSerialPort.SerialPort(Ptr{LibSerialPort.Lib.SPPort}(C_NULL), false, false)
    end
    function _arm_timeouts!(sp, seconds)
        S = Main.FakeTriggerscopePort.STATE
        lock(() -> (S.budget_s = seconds), Main.FakeTriggerscopePort.STATE_LOCK)
        Main.FakeTriggerscopePort.record!(:arm, seconds)
        return nothing
    end
    _flush_port!(sp) = (Main.FakeTriggerscopePort.record!(:flush); nothing)
    function _send!(sp, commandstring)
        S = Main.FakeTriggerscopePort.STATE
        S.fail_send && (S.fail_send = false; error("fake serial write failure"))
        Main.FakeTriggerscopePort.record!(:send, (current_task(), commandstring))
        S.send_delay_s > 0 && sleep(S.send_delay_s)
        return nothing
    end
    function _receive!(sp)
        S = Main.FakeTriggerscopePort.STATE
        spent = lock(Main.FakeTriggerscopePort.STATE_LOCK) do
            S.budget_s < S.cost_s && return false
            S.budget_s -= S.cost_s
            true
        end
        spent || error("fake LibSerialPort Timeout: the read budget is spent")
        Main.FakeTriggerscopePort.record!(:receive, current_task())
        return "OK"
    end
    openport(scope::Triggerscope4) = (Main.FakeTriggerscopePort.record!(:open, scope.portname); nothing)
    closeport(scope::Triggerscope4) = (Main.FakeTriggerscopePort.record!(:close, scope.portname); nothing)
end

@testset "Triggerscope (fake serial port)" begin
    TS = TS_MODULE
    Fake = FakeTriggerscopePort
    newscope() = TS.Triggerscope4(portname = "COM_FAKE", compause = 0.0)

    @testset "the constructor never reaches the host's serial layer" begin
        Fake.reset!()
        scope = newscope()
        @test Fake.events() == [(:new_port, "COM_FAKE")]
        @test scope.sp.ref == C_NULL && !isopen(scope.sp)
    end

    @testset "DAC ranges and codes; codes outside 0-65535 throw" begin
        @test TS.dac_range_volts(TS.ZEROTOFIVE) == (0.0, 5.0)
        @test TS.dac_range_volts(TS.ZEROTOTEN) == (0.0, 10.0)
        @test TS.dac_range_volts(TS.PLUSMINUS5) == (-5.0, 5.0)
        @test TS.dac_range_volts(TS.PLUSMINUS10) == (-10.0, 10.0)
        @test TS.dac_range_volts(TS.PLUSMINUS2_5) == (-2.5, 2.5)

        scope = newscope()
        scope.dacranges[1] = TS.ZEROTOFIVE
        scope.dacranges[2] = TS.ZEROTOTEN
        scope.dacranges[3] = TS.PLUSMINUS10      # the constructor's default
        @test TS.volttooutput(scope, 1, 0.0) == 0
        @test TS.volttooutput(scope, 1, 5.0) == 65535
        @test TS.volttooutput(scope, 1, 2.5) == round(Int, 65535 / 2)
        @test TS.volttooutput(scope, 2, 10.0) == 65535
        @test TS.volttooutput(scope, 3, -10.0) == 0
        @test TS.volttooutput(scope, 3, 0.0) == round(Int, 65535 / 2)
        for (dac, v) in ((1, 5.01), (1, -0.01), (2, 10.5), (3, -10.01), (1, NaN), (2, Inf), (3, -Inf), (1, 1e300))
            @test_throws ArgumentError TS.volttooutput(scope, dac, v)
        end
        # a hair past an end still rounds to the end code, as it always did; only a code past 0-65535 is refused
        @test TS.volttooutput(scope, 1, nextfloat(5.0)) == 65535
        @test TS.volttooutput(scope, 1, 5.00003) == 65535          # 65535.39
        @test_throws ArgumentError TS.volttooutput(scope, 1, 5.00004)  # 65535.52 -> 65536
        @test TS.volttooutput(scope, 1, prevfloat(0.0)) == 0
        @test TS.volttooutput(scope, 1, -0.00003) == 0             # -0.39
        @test TS.volttooutput(scope, 3, prevfloat(-10.0)) == 0
        @test TS.volttooutput(scope, 2, nextfloat(10.0)) == 65535
        # every range, both ends and the middle, against the formulas the driver always used
        for (r, f) in ((TS.ZEROTOFIVE, v -> v * 65535 / 5), (TS.ZEROTOTEN, v -> v * 65535 / 10),
                       (TS.PLUSMINUS5, v -> (v + 5) * 65535 / 10), (TS.PLUSMINUS10, v -> (v + 10) * 65535 / 20),
                       (TS.PLUSMINUS2_5, v -> (v + 2.5) * 65535 / 5))
            scope.dacranges[5] = r
            lo, hi = TS.dac_range_volts(r)
            @test all(v -> TS.volttooutput(scope, 5, v) == round(Int, f(v)), range(lo, hi; length = 101))
        end

        # setdac refuses before anything reaches the port
        Fake.reset!()
        @test_throws ArgumentError TS.setdac(scope, 1, 5.5)
        @test isempty(Fake.events())
    end

    @testset "the read timeout is re-armed for every command" begin
        # A 50 ms budget at 1 ms per reply read lasts 50 commands if it is set once (the fake's openport sets
        # nothing, so without a re-arm the very first read fails). 500 commands all pass.
        scope = newscope()
        scope.rwtimeout = 0.05
        scope.dacranges[4] = TS.ZEROTOFIVE
        Fake.reset!(cost_s = 0.001)
        replies = [TS.setdac(scope, 4, 1.0 + 0.001 * k) for k in 1:500]
        @test all(==("OK"), replies)
        @test Fake.count_events(:arm) == 500
        @test Fake.count_events(:send) == 500
        @test Fake.count_events(:receive) == 500
        @test Fake.count_events(:open) == 0          # no port reset
        @test all(e -> e[2] == 0.05, filter(e -> e[1] === :arm, Fake.events()))
    end

    @testset "a failed command resets the port and names it" begin
        scope = newscope()
        Fake.reset!()
        Fake.STATE.fail_send = true
        err = try
            TS.acknowledgetest(scope); nothing
        catch e
            e
        end
        @test err isa ErrorException
        @test occursin("COM_FAKE", err.msg) && occursin("port reset", err.msg)
        @test occursin("fake serial write failure", err.msg)
        @test Fake.count_events(:close) == 1 && Fake.count_events(:open) == 1
        # the scope's lock was released by the throw: the next command goes through
        @test TS.acknowledgetest(scope) == "OK"
    end

    @testset "concurrent commands never interleave a write and its reply" begin
        scope = newscope()
        scope.dacranges[1] = TS.ZEROTOFIVE
        scope.dacranges[2] = TS.ZEROTOFIVE
        Fake.reset!(send_delay_s = 0.001)          # each write yields, so another task would get in between
        n = 40
        t1 = Threads.@spawn for k in 1:n; TS.setdac(scope, 1, 1.0); end
        t2 = Threads.@spawn for k in 1:n; TS.setttl(scope, 3, isodd(k)); end
        @test timedwait(() -> istaskdone(t1) && istaskdone(t2), 30.0) === :ok
        fetch(t1); fetch(t2)
        io = filter(e -> e[1] in (:send, :receive), Fake.events())
        @test length(io) == 4n
        # every send is followed at once by the reply read of the same task
        @test all(1:2:length(io)) do i
            io[i][1] === :send && io[i+1][1] === :receive && io[i][2][1] === io[i+1][2]
        end
    end

    @testset "the lock is held for the whole command, and is reentrant" begin
        scope = newscope()
        Fake.reset!()
        @test scope.lock isa ReentrantLock
        lock(scope.lock)
        t = Threads.@spawn TS.getstatus(scope)
        sleep(0.2)
        @test !istaskdone(t)                        # waits for the holder
        @test Fake.count_events(:send) == 0
        @test TS.runtest(scope) == "OK"             # the holder itself is not blocked
        unlock(scope.lock)
        @test timedwait(() -> istaskdone(t), 10.0) === :ok
        @test fetch(t) == "OK"
    end

    @testset "a range change cannot land between a DAC code's encoding and its write" begin
        # Keith's sequence: one task encodes 5 V on a 0-5 V channel while another sets that channel to 0-10 V. The
        # code must be computed under the lock, against the range the board has when it arrives.
        for cmd in ((s) -> TS.setdac(s, 1, 5.0), (s) -> TS.progdac(s, 7, 1, 5.0))
            scope = newscope()
            scope.dacranges[1] = TS.ZEROTOFIVE
            Fake.reset!()
            lock(scope.lock)
            t = Threads.@spawn cmd(scope)
            sleep(0.2)                                  # t waits for the lock
            @test !istaskdone(t)
            TS.setrange(scope, 1, TS.ZEROTOTEN)         # the holder changes the range
            unlock(scope.lock)
            @test timedwait(() -> istaskdone(t), 10.0) === :ok
            fetch(t)
            sends = [e[2][2] for e in Fake.events() if e[1] === :send]
            @test sends[1] == "RANGE1,2\n"
            @test endswith(sends[2], ",32768\n")        # 5 V on 0-10 V, not 65535 (10 V)
        end

        # setrange's cache update waits for the lock too
        scope = newscope()
        scope.dacranges[1] = TS.ZEROTOFIVE
        Fake.reset!()
        lock(scope.lock)
        t = Threads.@spawn TS.setrange(scope, 1, TS.ZEROTOTEN)
        sleep(0.2)
        @test scope.dacranges[1] == TS.ZEROTOFIVE
        @test TS.volttooutput(scope, 1, 5.0) == 65535   # the holder still encodes against the board's range
        unlock(scope.lock)
        @test timedwait(() -> istaskdone(t), 10.0) === :ok
        @test scope.dacranges[1] == TS.ZEROTOTEN

        # the interface setter: encoding, caches and the write in one transaction
        scope = newscope()
        scope.dacranges[2] = TS.ZEROTOFIVE
        Fake.reset!()
        TS.TrigInterface.setoutputvalue(scope, scope.outputs[1], 2, 2.5)
        @test scope.dacvalues[2] == round(Int, 65535 / 2)
        @test [e[2][2] for e in Fake.events() if e[1] === :send] == ["DAC2,$(round(Int, 65535 / 2))\n"]
    end

    @testset "progttl stores the TTL value after the reply" begin
        scope = newscope()
        Fake.reset!()
        @test TS.progttl(scope, 1, 3, true) == "OK"     # used to throw a MethodError (it wrote the channel count)
        @test scope.ttlvalues[3] == true
        @test scope.ttloutputs == 16
        Fake.STATE.fail_send = true                     # a failed command leaves the value as it was
        @test_throws ErrorException TS.progttl(scope, 1, 4, true)
        @test scope.ttlvalues[4] == false
    end

    @testset "positional construction without the lock still works" begin
        s = newscope()
        fields = [getfield(s, f) for f in fieldnames(TS.Triggerscope4)[1:end-1]]
        s2 = TS.Triggerscope4(fields...)
        @test s2.lock isa ReentrantLock && s2.lock !== s.lock
        @test s2.portname == "COM_FAKE"
    end
end
