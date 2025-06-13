using Revise
using MicroscopeControl
using MicroscopeControl.HardwareImplementations.Triggerscope

scope4 = Triggerscope4()
initialize(scope4)

#=
PascalCase: CameraInterface
camelCase: setToZero
snake_case: set_to_zero
=#

arrIndex = false
dacNum1 = 1
dacNum2 = 2
waveform = 1
centerVolt = 5.0
dutyCycle = 50
phase1 = 0
phase2 = 90
trigType = 0
progStep = 0

setdac(scope4, 1, 0.0)
setdac(scope4, 2, 0.0)

for i in 1:10
    setdac(scope4, 1, 0.0)
    setdac(scope4, 2, 0.0) 
    setdac(scope4, 1, 3.0) 
    setdac(scope4, 2, 3.0)
end



function armCircle(scope4, arrIndex, dacNum1, dacNum2, waveform, centerVolt, dutyCycle, trigType)
    progwave(scope4, arrIndex, dacNum1, waveform, centerVolt, dutyCycle, 0, trigType)
    progwave(scope4, arrIndex, dacNum2, waveform, centerVolt, dutyCycle, 90, trigType)
    timecycles(scope4, 2)
    trigmode(scope4, CHANGE)
    arm(scope4)
end

#armCircle(scope4, arrIndex, dacNum1, dacNum2, waveform, centerVolt, dutyCycle, trigType)  

gui(scope4)


progwave(scope4, arrIndex, dacNum1, waveform, centerVolt, dutyCycle, 0, trigType)
progwave(scope4, arrIndex, dacNum2, waveform, centerVolt, dutyCycle, 90, trigType)
timecycles(scope4, 10000)
trigmode(scope4, CHANGE)
arm(scope4)


clearall(scope4)
line_number = 1  # Start at line 1
for i in 1:75
    progdac(scope4, line_number, 1, 0.0)
    line_number += 1
    progdac(scope4, line_number, 2, 0.0)
    line_number += 1
    progdac(scope4, line_number, 1, 3.0)
    line_number += 1
    progdac(scope4, line_number, 2, 4.0)
    line_number += 1
    println("Line number: $line_number")
end

trigmode(scope4, CHANGE)
arm(scope4)