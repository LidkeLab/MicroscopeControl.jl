

mutable struct XEM_dac
    xem::XEM
    
end


function XEM_dac(;
    xem::XEM=XEM())

    return XEM_dac(xem)
    
end

