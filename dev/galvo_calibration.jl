using Revise
using MicroscopeControl
using MicroscopeControl.HardwareImplementations.Triggerscope
using MicroscopeControl.HardwareImplementations.ThorCamDCx
using GLMakie
include("./beam_characterization.jl")

# overall goal: make a thing that tracks the slope of the Voltage vs positiion graph so that a covariance matrix can be made
# steps to do that goal
# 1. make a function that tracks the position of the beam and the voltage of the galvo
# 2. make a function that calculates the slope of the voltage vs position graph
# 3. make a function that calculates the covariance matrix from the slopes
# 4. make a function that uses the covariance matrix to calculate the position of the beam given a voltage

function galvo_position_predictor()

end

function make_covariance_matrix()

end

function calibrate_galvo(camera::ThorcamDCXCamera, scope::Triggerscope4; step_size::Float64 = 0.005, x_channel = 1, y_channel = 2)
    volt_ranges = Dict{Range, Tuple{Float64, Float64}}(
        PLUSMINUS10 => (-10.0, 10.0),
        PLUSMINUS5 => (-5.0, 5.0),
        ZEROTOFIVE => (0.0, 5.0),
        ZEROTOTEN => (0.0, 10.0),
        PLUSMINUS2_5 => (-2.5, 2.5)
    )
    x_min_volts = volt_ranges[scope.dacranges[x_channel]][1]
    x_max_volts = volt_ranges[scope.dacranges[x_channel]][2]
    y_min_volts = volt_ranges[scope.dacranges[y_channel]][1]
    y_max_volts = volt_ranges[scope.dacranges[y_channel]][2]

    x_pos_positions, x_pos_voltages = calibration_loop(
        camera, scope, x_max_volts, x_min_volts, true; 
        step_size = step_size, channel = x_channel)

    x_neg_positions, x_neg_voltages = calibration_loop(
        camera, scope, x_max_volts, x_min_volts, false; 
        step_size = step_size, channel = x_channel)

    y_pos_positions, y_pos_voltages = calibration_loop(
        camera, scope, y_max_volts, y_min_volts, true; 
        step_size = step_size, channel = y_channel)

    y_neg_positions, y_neg_voltages = calibration_loop(
        camera, scope, y_max_volts, y_min_volts, false; 
        step_size = step_size, channel = y_channel)

    x_positions::Vector{Tuple{Float64, Float64}} = vcat(reverse(x_neg_positions), x_pos_positions)
    y_positions::Vector{Tuple{Float64, Float64}} = vcat(reverse(y_neg_positions), y_pos_positions)
    x_voltages::Vector{Float64} = vcat(reverse(x_neg_voltages), x_pos_voltages)
    y_voltages::Vector{Float64} = vcat(reverse(y_neg_voltages), y_pos_voltages)

    return x_positions, y_positions, x_voltages, y_voltages
end

function calibration_loop(
    camera::ThorcamDCXCamera, 
    scope::Triggerscope4, 
    max_voltage::Float64, 
    min_voltage::Float64,
    positive::Bool; 
    step_size::Float64 = 0.01, 
    channel = 1, 
)
    frame_size = size(getlastframe(camera))
    positions = []
    voltages = []
    voltage_counter = 0.0
    margin = 0.05
    go = true

    while go == true && (positive ? voltage_counter <= max_voltage : voltage_counter >= min_voltage)
        setdac(scope, channel, voltage_counter)
        new_frame = getlastframe(camera)
        new_cx, new_cy = find_center(new_frame)

        push!(positions, (new_cx, new_cy))
        push!(voltages, round(voltage_counter, digits = 4))

        positive ? voltage_counter += step_size : voltage_counter -= step_size

        if new_cx < frame_size[1] * margin || new_cx > frame_size[1] * (1 - margin) ||
        new_cy < frame_size[2] * margin || new_cy > frame_size[2] * (1 - margin)
            go = false
        end
    end
    setdac(scope, channel, 0.0)  # Reset channel galvo to 0 volts
    return positions, voltages
end

function scope_setup(scope::Triggerscope4; compause::Float64 = 0.1, range::Range = PLUSMINUS10)
    clearall(scope)
    scope.compause = compause
    setrange(scope, 1, range)
    setrange(scope, 2, range)
    setdac(scope, 1, 0.0)
    setdac(scope, 2, 0.0)
end

function graph_pos_vs_volts(
    x_positions::Vector{Tuple{Float64, Float64}}, 
    y_positions::Vector{Tuple{Float64, Float64}}, 
    x_voltages::Vector{Float64}, 
    y_voltages::Vector{Float64}
)
    fig = Figure(size = (800, 600), title = "Position vs Voltage")
    ax1 = Axis(fig[1, 1], title = "X Position vs X Voltage")
    ax2 = Axis(fig[2, 2], title = "Y Position vs Y Voltage")
    ax3 = Axis(fig[1, 2], title = "X Position vs Y Voltage")
    ax4 = Axis(fig[2, 1], title = "Y Position vs X Voltage")

    scatter!(ax1, x_voltages, [pos[1] for pos in x_positions], color=:blue, markersize=5)
    scatter!(ax2, y_voltages, [pos[2] for pos in y_positions], color=:red, markersize=5)
    scatter!(ax3, y_voltages, [pos[1] for pos in y_positions], color=:green, markersize=5)
    scatter!(ax4, x_voltages, [pos[2] for pos in x_positions], color=:purple, markersize=5)

    ax1.xlabel = " X Voltage (V)"
    ax1.ylabel = "X Position (pixels)"
    ax2.xlabel = " Y Voltage (V)"
    ax2.ylabel = "Y Position (pixels)"
    ax3.xlabel = "Y Voltage (V)"
    ax3.ylabel = "X Position (pixels)"
    ax4.xlabel = "X Voltage (V)"
    ax4.ylabel = "Y Position (pixels)"

    display(fig)
end

# GUI for Galvo Calibration
function galvo_calibration_gui(camera::ThorcamDCXCamera, scope::Triggerscope4; framerate::Float64 = 15.0, exposure_time::Float64 = 0.01)
    # initalize triggerscope 
    initialize(scope)
    sleep(2)  # Allow time for instruments to initialize
    scope_setup(scope; compause=0.07)

    # initalize camera
    initialize(camera)    
    camera.exposure_time = exposure_time
    live(camera)
    initial_frame = getlastframe(camera)
    start = time()

    # initalize figure and axis
    fig = Figure(size = (1000, 750), title = "Galvo Calibration")
    ax = Axis(fig[1, 1], title = "Live Camera Feed"; aspect = DataAspect())

    frame_obs = Observable(initial_frame)
    duration = Observable(0.0)
    center_x = Observable(0.0)
    center_y = Observable(0.0)

    heatmap!(ax, frame_obs, colormap = :inferno)
    scatter!(ax, center_x, center_y, color=:teal, markersize=10)

    display(fig)
    window_closer(fig, () -> shutdown(camera), () -> shutdown(scope))

    @async begin 
        while camera.is_running == 1
            frame = getlastframe(camera)
            if frame !== nothing
                frame_obs[] = frame
                duration[] = round(time() - start, digits = 2)
                center_x[], center_y[] = find_center(frame)
                ax.title = "Live Camera Feed - Time: $(duration[]) seconds"
            end
            sleep(1 / framerate)
        end
    end
end

camera1 = ThorcamDCXCamera()
scope = Triggerscope4()
galvo_calibration_gui(camera1, scope)
x_positions, y_positions, x_voltages, y_voltages = calibrate_galvo(camera1, scope)
graph_pos_vs_volts(x_positions, y_positions, x_voltages, y_voltages)
