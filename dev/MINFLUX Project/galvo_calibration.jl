# Created by Abbie Gatsch and Martin Zanazzi, Summer 2025
# This code calibrates the galvo system of a microscope using a camera and a Triggerscope4.
# It returns a covariance matrix that can be used to convert pixel positions to voltages for the galvo system, and vice versa.
# It includes a gui that lets you visualize the calibration process in real-time.
# It also plots the relationship between voltage and position in a 2x2 grid of axes and computes the linear fit and R^2 for each axis.
# The entries of the covariance matrix are the slopes of the linear fits.

using Revise
using MicroscopeControl
using MicroscopeControl.HardwareImplementations.Triggerscope
using MicroscopeControl.HardwareImplementations.ThorCamDCx
using MicroscopeControl.HardwareImplementations.ThorCamCSC
using GLMakie, Polynomials
include("./beam_characterization.jl")
include("./dev_helper_funcs.jl")

function position_to_voltage(position::Vector{Int64},calibration_matrix::Matrix{Float64})
    voltages = inv(calibration_matrix) * position
    return round.(voltages, digits = 5)
end

function voltage_to_position(voltage::Vector{Float64}, calibration_matrix::Matrix{Float64})
    position = calibration_matrix * voltage
    return round.(Int, position)
end

function calibrate_galvo(camera, scope::Triggerscope4; step_size::Float64 = 0.01, x_channel = 1, y_channel = 2, frame_margin = 0.1)
    # Dictionary for voltage ranges
    volt_ranges = Dict{Range, Tuple{Float64, Float64}}(
        PLUSMINUS10 => (-10.0, 10.0),
        PLUSMINUS5 => (-5.0, 5.0),
        ZEROTOFIVE => (0.0, 5.0),
        ZEROTOTEN => (0.0, 10.0),
        PLUSMINUS2_5 => (-2.5, 2.5)
    )
    # Assign voltage ranges based on the dacrange of the scope
    x_min_volts = volt_ranges[scope.dacranges[x_channel]][1]
    x_max_volts = volt_ranges[scope.dacranges[x_channel]][2]
    y_min_volts = volt_ranges[scope.dacranges[y_channel]][1]
    y_max_volts = volt_ranges[scope.dacranges[y_channel]][2]

    # Run four calibration loops one for the positive and negative voltages of each channel
    x_pos_positions, x_pos_voltages = calibration_loop(
        camera, scope, x_max_volts, x_min_volts, true; 
        step_size = step_size, channel = x_channel, margin = frame_margin)

    x_neg_positions, x_neg_voltages = calibration_loop(
        camera, scope, x_max_volts, x_min_volts, false; 
        step_size = step_size, channel = x_channel, margin = frame_margin)

    y_pos_positions, y_pos_voltages = calibration_loop(
        camera, scope, y_max_volts, y_min_volts, true; 
        step_size = step_size, channel = y_channel, margin = frame_margin)

    y_neg_positions, y_neg_voltages = calibration_loop(
        camera, scope, y_max_volts, y_min_volts, false; 
        step_size = step_size, channel = y_channel, margin = frame_margin)

    # Combine the positions and voltages for both channels
    # Reverse the negative positions and voltages to maintain order
    x_positions::Vector{Tuple{Float64, Float64}} = vcat(reverse(x_neg_positions), x_pos_positions)
    y_positions::Vector{Tuple{Float64, Float64}} = vcat(reverse(y_neg_positions), y_pos_positions)
    x_voltages::Vector{Float64} = vcat(reverse(x_neg_voltages), x_pos_voltages)
    y_voltages::Vector{Float64} = vcat(reverse(y_neg_voltages), y_pos_voltages)

    # Graph the positions vs voltages and compute the covariance matrix
    coeffs_ax1, coeffs_ax2, coeffs_ax3, coeffs_ax4 = graph_pos_vs_volts(x_positions, y_positions, x_voltages, y_voltages)
    calibration_matrix = [
        coeffs_ax1[2] coeffs_ax3[2];
        coeffs_ax4[2] coeffs_ax2[2]
    ]

    return calibration_matrix
end

# This is the function that moves an individual galvo through a range of voltages while tracking the position of the beam.
function calibration_loop(
    camera, 
    scope::Triggerscope4, 
    max_voltage::Float64, # Set in the triggerscope
    min_voltage::Float64, # Set in the triggerscope
    positive::Bool; # Whether the calibration is for positive or negative voltages
    step_size::Float64 = 0.001, # Step size for voltage increments
    channel = 1, # DAC channel on triggerscope to use
    margin = 0.1 # Margin of the frame size to stop the calibration loop
)
    frame_size = size(getlastframe(camera)')
    positions = []
    voltages = [] # create an array that is the same size as positions for graphing
    voltage_counter = 0.0 # keeps track of current voltage
    go = true

    # step in increments of step_size until voltage_counter reaches max_voltage or min_voltage or frame edge is reached
    while go == true && (positive ? voltage_counter <= max_voltage : voltage_counter >= min_voltage)
        setdac(scope, channel, voltage_counter)
        new_frame = getlastframe(camera)'
        new_cx, new_cy = find_center(new_frame)

        # push the positions and voltages to the arrays
        push!(positions, (new_cx, new_cy))
        push!(voltages, round(voltage_counter, digits = 4))

        # Increment or decrement the voltage counter based on the positive flag
        positive ? voltage_counter += step_size : voltage_counter -= step_size

        # Sets go to false if the new center is outside the margin of the frame size
        if new_cx < frame_size[1] * margin || new_cx > frame_size[1] * (1 - margin) ||
        new_cy < frame_size[2] * margin || new_cy > frame_size[2] * (1 - margin)
            go = false
        end
    end
    setdac(scope, channel, 0.0)  # Reset channel galvo to 0 volts
    return positions, voltages
end

# Function to set up the triggerscope to ensure the zero point is consistent
# The zero point of the DAC ports will be different if clearall is called after setting the ranges.
# Compause is the time between setting the DAC and reading the response from scope.
# Shorter compause leads to faster response, but increases the risk of errors or crashes.
function scope_setup(scope::Triggerscope4; compause::Float64 = 0.1, range::Range = PLUSMINUS10)
    clearall(scope)
    scope.compause = compause
    setrange(scope, 1, range)
    setrange(scope, 2, range)
    setdac(scope, 1, 0.0)
    setdac(scope, 2, 0.0)
end

# Plots the positions vs voltages in a 2x2 grid of axes in the same layout as the covariance matrix.
# Also plots the linear fits and desplays the R^2 values.
function graph_pos_vs_volts(
    x_volt_positions::Vector{Tuple{Float64, Float64}}, 
    y_volt_positions::Vector{Tuple{Float64, Float64}}, 
    x_voltages::Vector{Float64}, 
    y_voltages::Vector{Float64}
)
    # Create figure and axes
    fig2 = Figure(size = (800, 600), title = "Position vs Voltage")
    ax1 = Axis(fig2[1, 1], title = "X Position vs X Voltage")
    ax2 = Axis(fig2[2, 2], title = "Y Position vs Y Voltage")
    ax3 = Axis(fig2[1, 2], title = "X Position vs Y Voltage")
    ax4 = Axis(fig2[2, 1], title = "Y Position vs X Voltage")

    # Scatter plots for actual positions vs voltages
    scatter!(ax1, x_voltages, [pos[1] for pos in x_volt_positions], color=:lightblue, markersize=4)
    scatter!(ax2, y_voltages, [pos[2] for pos in y_volt_positions], color=:salmon, markersize=4)
    scatter!(ax3, y_voltages, [pos[1] for pos in y_volt_positions], color=:lightgreen, markersize=4)
    scatter!(ax4, x_voltages, [pos[2] for pos in x_volt_positions], color=:orchid, markersize=4)

    # Calculate linear fits and R^2 values for each axis
    fit_ax1, r2_ax1, coeffs_ax1 = linear_fit(x_volt_positions, x_voltages, true)
    fit_ax2, r2_ax2, coeffs_ax2 = linear_fit(y_volt_positions, y_voltages, false)
    fit_ax3, r2_ax3, coeffs_ax3 = linear_fit(y_volt_positions, y_voltages, true)
    fit_ax4, r2_ax4, coeffs_ax4 = linear_fit(x_volt_positions, x_voltages, false)

    # Plot linear fits
    lines!(ax1, x_voltages, fit_ax1, color=:blue, linewidth=2)
    lines!(ax2, y_voltages, fit_ax2, color=:red, linewidth=2)
    lines!(ax3, y_voltages, fit_ax3, color=:green, linewidth=2)
    lines!(ax4, x_voltages, fit_ax4, color=:purple, linewidth=2)

    # Label axis and display R^2 values
    ax1.xlabel = " X Voltage (V), R² = $(round(r2_ax1, digits=5))"
    ax1.ylabel = "X Position (pixels)"
    ax2.xlabel = " Y Voltage (V), R² = $(round(r2_ax2, digits=5))"
    ax2.ylabel = "Y Position (pixels)"
    ax3.xlabel = "Y Voltage (V), R² = $(round(r2_ax3, digits=5))"
    ax3.ylabel = "X Position (pixels)"
    ax4.xlabel = "X Voltage (V), R² = $(round(r2_ax4, digits=5))"
    ax4.ylabel = "Y Position (pixels)"

    # Separate window for displaying the figure
    display(GLMakie.Screen(), fig2)

    # Returns the coefficients of the linear fits for each axis
    # These coefficients are used to create the covariance matrix
    return coeffs_ax1, coeffs_ax2, coeffs_ax3, coeffs_ax4
end

# Calculates linear fit and R^2 values
function linear_fit(volt_positions::Vector{Tuple{Float64, Float64}}, voltages::Vector{Float64}, x_pos::Bool)
    # x_pos is a boolean that determines whether the x position is used for the fit (true) or y position (false)
    x = [voltage for voltage in voltages]
    y = x_pos ? [pos[1] for pos in volt_positions] : [pos[2] for pos in volt_positions]
    p = fit(x, y, 1)  # Linear fit
    fit_coeffs = coeffs(p)
    # y_fit is the array of y values for the linear fit
    y_fit = fit_coeffs[1] .+ fit_coeffs[2] .* x  # y = mx + b
    # Compute R^2
    ss_res = sum((y .- y_fit).^2)
    ss_tot = sum((y .- mean(y)).^2)
    r2 = 1 - ss_res / ss_tot
    return y_fit, r2, fit_coeffs
end



# GUI for Galvo Calibration
function galvo_calibration_gui(camera, scope::Triggerscope4; frame_rate::Float64 = 80.0, exposure_time = 10000, gain = Int32(480))
    # initalize triggerscope 
    initialize(scope)
    sleep(2)  # Allow time for instruments to initialize
    scope_setup(scope; compause=0.07)

    fig, ax, frame_obs = live_camera_display(camera, frame_rate = frame_rate, exposure_time = exposure_time, gain = gain)
   
    center_x = Observable(0.0)
    center_y = Observable(0.0)

    # Create scatter for center point
    scatter!(ax, center_x, center_y, color=:teal, markersize=10)

    # Async loop to update center with live camera feed
    @async begin 
        while Bool(camera.is_running) == 1
            center_x[], center_y[] = find_center(frame_obs[])
            sleep(1 / frame_rate)
        end
    end
end

# To run:
# Close each camera gui before running the next one.
# camera = ThorCamCSCCamera()
# scope = Triggerscope4()
# galvo_calibration_gui(camera, scope)
# calibration_matrix = calibrate_galvo(camera, scope, frame_margin = 0.25)
# saved_calibration_matrix_CSC = [1017.56 24.7616; 6.11555 746.693]
