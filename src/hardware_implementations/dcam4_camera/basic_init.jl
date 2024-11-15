
include("dcamerr.jl")
include("dcamapi.jl")


err, dci = dcamapi_init()
display(dci)
dci.iDeviceCount

err = dcamapi_uninit()





