# Abbie Gatsch and Martin Zanazzi, Summer 2025
# moves the laser to each position
# takes the intensity value of the frame for each position 
# returns an array of intensity values
# math to find out where the laser should go next

# If there are any weird errors, especially involving libserialport, unplugging and plugging in the camera and/or triggerscope is a good start

using Revise
using MicroscopeControl
using MicroscopeControl.HardwareImplementations.Triggerscope
using MicroscopeControl.HardwareImplementations.ThorCamDCx
using GLMakie
include("./galvo_calibration.jl")
include("./dev_helper_funcs.jl")
include("./beam_characterization.jl")

function find_scan_pattern(r::Int, x_start::Int, y_start::Int)
    pos1 = (x_start, y_start)
    pos2 = (x_start + r, y_start)
    pos3 = (x_start + round(Int, (r * -0.5)), y_start + round(Int, (r * sqrt(3) / 2)))
    pos4 = (x_start + round(Int, (r * -0.5)), y_start + round(Int, (r * -sqrt(3) / 2)))
    return (pos1, pos2, pos3, pos4)
end

# Moves the galvo to each position and returns the intensity values
function galvo_scan_pattern(positions::NTuple{4, Tuple{Int, Int}}, scope::Triggerscope4, camera, calibration_matrix::Matrix{Float64}; r = 40)
    intensity::Vector{Float64} = []
    x, y = positions[1]
    getroisize(camera)
    mask = zeros(Float64, camera.roi.width, camera.roi.height)
    mask[(x-r:x+r), (y-r:y+r)] .= 1

    for pos in positions
        volts = position_to_voltage(collect(pos) .- camera.roi.width ÷ 2, calibration_matrix)
        setdac(scope, 1, volts[1])
        setdac(scope, 2, volts[2])

        sleep(1 / camera.frame_rate)
        frame = getlastframe(camera)'
        frame .*= mask
        sum_intensity = sum(frame)
        push!(intensity, sum_intensity)
    end
    return intensity
end

function estimate_position(intensity::Vector{Float64}, positions::NTuple{4, Tuple{Int, Int}})
    numerator = zeros(Float64, 2)
    for i in 1:4
        weight = 1 / (intensity[i] .^ 6)
        pos_vec = collect(positions[i])
        numerator .+= weight .* pos_vec
    end
    denominator = sum(1 / (intensity[i] .^ 6) for i in 1:4)
    if denominator == 0
        return nothing
    end
    return round.(numerator ./ denominator)
end

# Simulates MINFLUX tracking by masking the frame of the camera with a frame of 0s and 1s, with the only 1s being a specified radius away from the mouse to simulate a bead.
# The smaller the screen size, the faster the frame rate, leading to significantly quicker tracking. This program uses the beam characterization camera.
function simulation(
    scope::Triggerscope4, 
    camera, 
    calibration_matrix::Matrix{Float64}; 
    bead_size = 5, 
    screen_size = 200
    )
    # Set the camera to the best and fastest settings 
    initialize(camera)
    center_x = camera.camera_format.x_pixels ÷ 2
    center_y = camera.camera_format.y_pixels ÷ 2
    # A smaller roi allows for a faster frame rate
    camera.roi = CameraROI(center_y - (screen_size ÷ 2), center_x - (screen_size ÷ 2), screen_size, screen_size)
    camera.exposure_time = 0.01
    camera.frame_rate = 200.0 # sets to highest number possible once setroi!() is called
    setroi!(camera)
    
    fig, ax, frame = live_camera_display(camera)
    frame_width, frame_height = size(frame[])

    track_mouse = false
    cursor_text = Observable("Mouse: (0, 0)")
    text!(ax, cursor_text, position = (0, 0), fontsize = 16, color = :white)
    

    mouse_pos = Observable(zeros(Float64, frame_width, frame_height))
    intensity = Observable(zeros(Float64, frame_width, frame_height))
    last_x = Observable(0)
    last_y = Observable(0)
    x = 0; y = 0

    predicted_x = lift(last_x) do x
        return x + (screen_size ÷ 2)
    end

    predicted_y = lift(last_y) do y
        return y + (screen_size ÷ 2)
    end

    scatter!(ax, predicted_x, predicted_y, markersize = 10, color = :teal)

    on(events(fig).mousebutton) do event
        # toggles the mouse tracking on left click
        if event.button == Mouse.left && event.action == Mouse.press
            track_mouse ? track_mouse = false : track_mouse = true
        end
    end

    on(events(fig).mouseposition) do mp
        plot_pos = mouseposition(ax.scene)
        x, y = round(Int, plot_pos[1]), round(Int, plot_pos[2])

        if 1 + bead_size <= x <= frame_width - bead_size && 1 + bead_size <= y <= frame_height - bead_size
            cursor_text[] = "Mouse: ($x, $y) \n Tracking $(track_mouse ? "enabled" : "disabled" )"
            mouse_pos[] = zeros(Float64, frame_width, frame_height)
            mouse_pos[][(x-bead_size:x+bead_size), (y-bead_size:y+bead_size)] .= 1
            intensity[] .= frame[] .* mouse_pos[]
        end
    end

    @async begin 
        while Bool(camera.is_running) == 1
            if track_mouse && 1 <= x <= frame_width && 1 <= y <= frame_height
                try
                    positions = find_scan_pattern(7, last_x[], last_y[])
                    intensities::Vector{Float64} = []    
                    for pos in positions
                        volts = position_to_voltage(collect(pos), calibration_matrix)
                        setdac(scope, 1, volts[1])
                        setdac(scope, 2, volts[2])
                        sleep(1.75 / camera.frame_rate)
                        intensity[] .= frame[] .* mouse_pos[]
                        sum_intensity = sum(intensity[])
                        push!(intensities, sum_intensity)
                    end
                    println("Intensities: ", intensities)
                    last_x[], last_y[] = round.(Int, estimate_position(intensities, positions))
                    volts = position_to_voltage([last_x[], last_y[]], calibration_matrix)
                    println("Estimated position: ($(last_x[]), $(last_y[]))")
                    setdac(scope, 1, volts[1])
                    setdac(scope, 2, volts[2])
                catch e
                    @warn "Error estimating position: $e"
                    setrange(scope, 1, PLUSMINUS10)
                    sleep(0.2)
                    setrange(scope, 2, PLUSMINUS10)
                end
            end
            sleep(0.01) # Yeild time
        end
    end
end

function test_track(
    scope::Triggerscope4, 
    camera::ThorCamCSCCamera,
    positioner::MclZPositioner,
    calibration_matrix::Matrix{Float64}; 
    screen_size::Int = 400,
    r::Int = 40
)
    initialize(scope)
    clearall(scope)
    setrange(scope, 1, PLUSMINUS10)
    setrange(scope, 2, PLUSMINUS10)
    setdac(scope, 1, 0.0)
    setdac(scope, 2, 0.0)

    center_y = camera.camera_format.x_pixels ÷ 2
    center_x = camera.camera_format.y_pixels ÷ 2
    println("Camera format: $(camera.camera_format.x_pixels) x $(camera.camera_format.y_pixels)")
    # A smaller roi allows for a faster frame rate
    camera.roi = CameraROI(center_y - (screen_size ÷ 2), center_x - (screen_size ÷ 2), screen_size, screen_size)

    frame_rate = 150.0
    fig, ax, frame = live_camera_display(camera, gain = Int32(450), frame_rate = frame_rate, exposure_time = 10000, roi = camera.roi)
    make_objective_gui!(positioner, fig)

    info_box = GridLayout(fig[2, 1], tellwidth=false, tellheight=false)

    Label(info_box[1, 1], text="Enable Tracking:")
    tracking_tog = Toggle(info_box[1, 2], active=false)
    moving_indicator = Label(info_box[1, 3], text="Not Moving")

    rowsize!(fig.layout, 1, Relative(0.9))
    rowsize!(fig.layout, 2, Relative(0.1))
    colsize!(fig.layout, 1, Relative(0.7))
    colsize!(fig.layout, 2, Relative(0.3))

    last_x = Observable{Int}(screen_size ÷ 2)
    last_y = Observable{Int}(screen_size ÷ 2)
    mask = Observable{Matrix{Float64}}(zeros(Float64, screen_size, screen_size))

    scatter!(ax, last_x, last_y, markersize = 20, color = :teal)

    @async begin
        while Bool(camera.is_running) == 1
            if tracking_tog.active[]
                try
                    positions = find_scan_pattern(12, last_x[], last_y[])
                    intensities = galvo_scan_pattern(positions, scope, camera, calibration_matrix, r = r)
                    new_pos = estimate_position(intensities, positions)
                    
                    if new_pos[1] != last_x[] && new_pos[2] != last_y[]
                        moving_indicator.text = "moving in x and y"
                    elseif new_pos[1] != last_x[]
                        moving_indicator.text = "moving in x"
                    elseif new_pos[2] != last_y[]
                        moving_indicator.text = "moving in y"
                    else
                        moving_indicator.text = "not moving :("
                    end

                    last_x[] = new_pos[1]
                    last_y[] = new_pos[2]

                    volts = position_to_voltage([last_x[] - screen_size ÷ 2, last_y[] - screen_size ÷ 2], calibration_matrix)
                    println("Estimated position: ($(last_x[]), $(last_y[]))")
                    setdac(scope, 1, volts[1])
                    setdac(scope, 2, volts[2])
                catch e
                    @warn "Error estimating position: $e"
                    setrange(scope, 1, PLUSMINUS10)
                    sleep(0.2)
                    setrange(scope, 2, PLUSMINUS10)
                end
            end
            sleep(1 / frame_rate)
        end
    end
end

# for real use with microscope
camera1 = ThorCamCSCCamera()
scope = Triggerscope4(compause = 2e-4)
positioner = MclZPositioner()
saved_calibration_matrix_CSC_1 = [1017.56 24.7616; 6.11555 746.693]
test_track(scope, camera1, positioner, saved_calibration_matrix_CSC_1)

shutdown(scope)
shutdown(positioner)

# a simulated MINFLUX tracker using the characterization camera
# camera = ThorcamDCXCamera()
# simulation(scope, camera, calibration_matrix)