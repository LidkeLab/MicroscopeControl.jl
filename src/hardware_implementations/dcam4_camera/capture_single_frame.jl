using GLMakie

include("dcamerr.jl")
include("dcam_idprop.jl")
include("dcamapi.jl")
include("dcamdev.jl")
include("dcamprop.jl")
include("dcamwait.jl")
include("dcambuf.jl")
include("dcamcap.jl")


function capture_single_frame(; timeout_milisec::Int32=Int32(1000))
    err, dci = dcamapi_init()
    if is_failed(err)
        dcamapi_uninit()
        return err
    end

    err, dco = dcamdev_open(0)
    if is_failed(err)
        dcamapi_uninit()
        return err
    end
    hdcam = dco.hdcam

    err, status = dcamcap_status(hdcam)

    err = dcambuf_alloc(hdcam, Int32(1))
    if is_failed(err)
        dcamapi_uninit()
        return err
    end

    err = dcamcap_start(hdcam, Int32(DCAMCAP_START_SNAP))
    if is_failed(err)
        dcamapi_uninit()
        return err
    end

    err, hwait = dcamwait_open(hdcam)
    if is_failed(err)
        display(err)
        dcamapi_uninit()
        return err
    end
    display(hwait)

    err, event = dcamwait_event(hwait, Int32(DCAMWAIT_CAPEVENT_FRAMEREADY), timeout_milisec)
    if is_timeout(err)
        display(err)
        dcamapi_uninit()
        return err
    elseif is_failed(err)
        display(err)
        dcamapi_uninit()
        return err
    end

    err, data = dcambuf_getlastframe(hdcam)

    dcambuf_release(hdcam)
    err = dcamdev_close(hdcam)
    dcamapi_uninit()
    return data
end

dcamapi_uninit()
data = capture_single_frame()

# Create second window with heatmap
window2 = GLMakie.Screen()
data_fig = Figure()

# Create an Axis in the data window
ax = Axis(data_fig[1, 1], aspect = DataAspect())

# Generate initial heatmap data
heatmap_data = Float32.(data)

# Create an Observable for the heatmap data
heatmap_data_observable = Observable(heatmap_data)

# Create a heatmap with the initial data
hm = heatmap!(ax, heatmap_data_observable)

# Display the data window
display(window2, data_fig)



