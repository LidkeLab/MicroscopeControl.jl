

"""
    XEM_dac(; xem=XEM()) -> XEM_dac

Four-channel DAC (DAC8814 per the source comment; output range -10 to 10 V) on an Opal Kelly FPGA board,
set through FrontPanel wire-in endpoints. The one field, `xem`, is the [`XEM`](@ref) that carries the
connection; the keyword constructor wraps the given `XEM` (default `XEM()`) and opens nothing. The board
is opened and configured with `initialize(dac.xem)` (set `dac.xem.bitfile` first); there is no `initialize`
or `shutdown` method for `XEM_dac` itself. Channels A to D are wire-in endpoints 1 to 4 and
[`start`](@ref) and [`stop`](@ref) write endpoint 5.
"""
mutable struct XEM_dac
    xem::XEM
    
end


function XEM_dac(;
    xem::XEM=XEM())

    return XEM_dac(xem)
    
end

