using GLMakie
using ImageCore

include("dcamerr.jl")
include("dcam_idprop.jl")
include("dcamapi.jl")
include("dcamdev.jl")
include("dcamprop.jl")
include("dcamwait.jl")
include("dcambuf.jl")
include("dcamcap.jl")

function collect_sequence(nframes::Int=100; timeout_milisec::Int32=Int32(1000))

    fps = 60

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

    im_width, im_height = dcamprop_getsize(hdcam)
    err, exposure_time = dcamprop_getvalue(hdcam, DCAM_IDPROPTR_EXPOSURETIME)

    println("expsoure time: ", exposure_time)


    err = dcambuf_alloc(hdcam, Int32(nframes))
    if is_failed(err)
        dcamapi_uninit()
        return err
    end

    #Setup display
    img = Observable(rand(Gray{N0f8}, im_height, im_width))
    imgplot = image(@lift(rotr90($img)),
        axis=(aspect=DataAspect(),),
        figure=(figure_padding=0, resolution=size(img[]) ./ 2))
    # Create an Observable for the text
    text_data = Observable("Initial Text")
    neon_green = RGB(0.2, 1, 0.2)

    # Add the Observable text to the plot
    text!(imgplot.axis, text_data, position=(im_width / 10, im_height * 9/10), color = neon_green, textsize = 50)

    hidedecorations!(imgplot.axis)
    display(imgplot)

    err = dcamcap_start(hdcam, Int32(DCAMCAP_START_SNAP))
    if is_failed(err)
        dcamapi_uninit()
        return err
    end

    err, hwait = dcamwait_open(hdcam)
    if is_failed(err)
        dcamapi_uninit()
        return err
    end

    err, status = dcamcap_status(hdcam)

    while status == DCAMCAP_STATUS_BUSY
        err, event = dcamwait_event(hwait, Int32(DCAMWAIT_CAPEVENT_FRAMEREADY), timeout_milisec)
        if is_timeout(err)
            display(event)
            dcamapi_uninit()
            return err
        end

        framedata = dcambuf_getlastframe(hdcam)
        max_val = maximum(framedata)
        min_val = minimum(framedata)
        img[] = Gray{N0f8}.(framedata .* (1 / max_val))
        text_data[] = "[$min_val $max_val]"
        sleep(1 / fps)

        err, status = dcamcap_status(hdcam)
        if is_failed(err)
            dcamapi_uninit()
            return err
        end
    end

    #get all data
    data = zeros(UInt16, im_height, im_width, nframes)
    for i in 1:nframes
        data[:, :, i] = dcambuf_getframe(hdcam, Int32(i - 1))
    end

    dcambuf_release(hdcam)
    err = dcamdev_close(hdcam)
    dcamapi_uninit()
    return data
end

dcamapi_uninit()
data = collect_sequence(100);
println("done")
size(data)


