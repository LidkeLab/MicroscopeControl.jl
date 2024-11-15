
include("dcamerr.jl")
include("dcamapi.jl")
include("dcamdev.jl")
include("dcamprop.jl")
include("dcam_idprop.jl")


function show_properties(iDevice = 0)
    dcamapi_init()
    err, dco = dcamdev_open(iDevice)
    hdcam = dco.hdcam

    err, idprop = dcamprop_getnextid(hdcam, Int32(0), DCAMPROP_OPTION_SUPPORT)
    while (idprop != 0)
        output = string(idprop) * ' '

        err, propname = dcamprop_getname(hdcam, idprop)
        #output *= propname 
        output *= ':' * string(DCAM_IDPROPTR(idprop))
        println(output)

        err, idprop = dcamprop_getnextid(hdcam, idprop, DCAMPROP_OPTION_SUPPORT)
        if is_failed(err)
            display(err)
            println(idprop)
        end

    end

    dcamdev_close(hdcam)
    dcamapi_uninit()
end

dcamapi_uninit()
show_properties()

