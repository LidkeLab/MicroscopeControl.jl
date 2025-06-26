using Revise
using MicroscopeControl
using MicroscopeControl.HardwareImplementations.Triggerscope
using MicroscopeControl.HardwareImplementations.ThorCamDCx
import MicroscopeControl.HardwareImplementations.ThorCamDCx: gui as camera_gui
using MicroscopeControl.HardwareImplementations.NIDAQcard

using LibSerialPort


camera = ThorcamDCXCamera()
initialize(camera)
camera_gui(camera)
shutdown(camera)

data = capture(camera)

scope4.sp.ref

scope4 = Triggerscope4()
initialize(scope4)
setrange(scope4, 1, PLUSMINUS10)

shutdown(scope4)

setdac(scope4, 1, 0.0)
setdac(scope4, 2, 0.0)
program_para_eq(9.0, π/25, 0.0, 2π, 200, x, y)
clearall(scope4)
arm(scope4)

for i in 1:20
    setdac(scope4, 1, -1.0)
    setdac(scope4, 2, -2.0) 
    setdac(scope4, 1, 1.0) 
    setdac(scope4, 2, 2.0)
end

function program_square(side_length::Float64, num_cycles::Int)
    clearall(scope4)
    progdac(scope4, 1, 1, -(side_length))
    progdac(scope4, 1, 2, -(side_length))
    progdac(scope4, 2, 1, side_length)
    progdac(scope4, 2, 2, -(side_length))
    progdac(scope4, 3, 1, side_length)
    progdac(scope4, 3, 2, side_length)
    progdac(scope4, 4, 1, -(side_length))
    progdac(scope4, 4, 2, side_length)
    timecycles(scope4, num_cycles)
    trigmode(scope4, CHANGE)
end

program_square(9.0, 1000)
arm(scope4)


function program_circle(radius::Float64, step_size::Float64, num_cycles::Int)
    line_number = 1
    clearall(scope4)
    for θ in 0:step_size:2π
    progdac(scope4, line_number, 1, radius * sin(θ))
    progdac(scope4, line_number, 2, radius * cos(θ))
    line_number += 1
    end
    timecycles(scope4, num_cycles)
    trigmode(scope4, CHANGE)
    setdac(scope4, 1, 0.0)
    setdac(scope4, 2, 0.0)
end

program_circle(10.0, π/24, 200)
arm(scope4)
clearall(scope4)




function program_heart(scale::Float64, num_cycles::Int)
    clearall(scope4)
    setdac(scope4, 1, 0.0)
    setdac(scope4, 2, 0.0)
    line_number = 1
    
    # Heart parametric equations
    # x = 16*sin^3(t)
    # y = 13*cos(t) - 5*cos(2t) - 2*cos(3t) - cos(4t)
    
    step_size = π/24  # Higher resolution for smooth heart shape
    
    for t in 0:step_size:2π
        # Calculate heart coordinates
        x = 16 * sin(t)^3
        y = 13*cos(t) - 5*cos(2*t) - 2*cos(3*t) - cos(4*t)
        
        # Scale to desired voltage range and flip y-axis for proper orientation
        voltage_x = scale * x / 16  # Normalize and scale
        voltage_y = scale * y / 16  # Flip y-axis, normalize and scale
        
        # Program the DAC values
        progdac(scope4, line_number, 1, voltage_x)
        progdac(scope4, line_number, 2, voltage_y)
        line_number += 1
    end
    
    timecycles(scope4, num_cycles)
    trigmode(scope4, CHANGE)
end

program_heart(9.0, 500) # 10.0 scale makes a spade!
arm(scope4)


function program_para_eq(scale::Float64, step_size::Float64, low_range::Float64, high_range::Float64, num_cycles::Int, x_eq::Function, y_eq::Function)
    clearall(scope4)
    setdac(scope4, 1, 0.0)
    setdac(scope4, 2, 0.0)
    line_number = 1

    for t in low_range:step_size:high_range
       
        x = x_eq(t)
        y = y_eq(t)
        
        # Scale to desired voltage range and flip y-axis for proper orientation
        voltage_x = scale * x  # Normalize and scale
        voltage_y = scale * y  # Flip y-axis, normalize and scale
        
        # Program the DAC values
        progdac(scope4, line_number, 1, voltage_x)
        progdac(scope4, line_number, 2, voltage_y)
        line_number += 1
    end
    
    timecycles(scope4, num_cycles)
    trigmode(scope4, CHANGE)
end

function x(t)
    return sin(3t + π/4)
end

function y(t)
    return sin(4t)
end

function with_reset(func::Function, args...)
    try
        func(args...)
    catch e
        @error "$e Resetting port"
        closeport(scope4)
        openport(scope4)
    end
end

shutdown(scope4)




#= This is for controlling the arduino but it doesn't work yet

daq = NIdaq() # the type of daq is NIdaq

NIDAQcard.gui(daq)


devs = NIDAQcard.showdevices(daq)
channelsAO = NIDAQcard.showchannels(daq,"AO",devs[1])

t = NIDAQcard.createtask(daq,"AO",channelsAO[1]) # the type of t is Task
NIDAQcard.setvoltage(daq,t, 0.0) # the maximum voltage is 5.0 V.
NIDAQcard.deletetask(daq,t)

=#