
include("dcamerr.jl")
include("dcamapi.jl")
include("dcamdev.jl")

function show_device_list()
    err, dci = dcamapi_init()

    n = dci.iDeviceCount
    for i in 0:n-1
        err, dco = dcamdev_open(i)
        output = "#$(i): "
        hdcam = dco.hdcam

        err, model = dcamdev_getstring(hdcam, DCAM_IDSTR_MODEL)
        output *= length(model) == 0 ? "No DCAM_IDSTR.MODEL" : "MODEL=$(model)"

        err, cameraid = dcamdev_getstring(hdcam, DCAM_IDSTR_CAMERAID)
        output *= length(cameraid) == 0 ? ", No DCAM_IDSTR.CAMERAID" : ", CAMERAID=$(cameraid)"

        println(output)
        dcamdev_close(hdcam)
    end
    err = dcamapi_uninit()
end

show_device_list();
