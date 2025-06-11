using Revise
using MicroscopeControl
using MicroscopeControl.HardwareImplementations.Triggerscope


scope = Triggerscope4()

initialize(scope)

#=
PascalCase: CameraInterface
camelCase: setToZero
snake_case: set_to_zero
=#

arrIndex = false
dacNum1 = 1
dacNum2 = 2
waveform = 1
centerVolt = 2.0
dutyCycle = 50
phase1 = 0
phase2 = 90
trigType = 0
progStep = 0

for i in 1:100
    setdac(scope, 1, 2.0)
    setdac(scope, 2, 2.0)
    setdac(scope, 1, -2.0)
    setdac(scope, 2, -2.0)
end

function armCircle(scope, arrIndex, dacNum1, dacNum2, waveform, centerVolt, dutyCycle, trigType)
    cleartable(scope)
    progwave(scope, arrIndex, dacNum1, waveform, centerVolt, dutyCycle, 0, trigType)
    progwave(scope, arrIndex, dacNum2, waveform, centerVolt, dutyCycle, 90, trigType)
    arm(scope)
    trigmode(scope, CHANGE)
end

armCircle(scope, arrIndex, dacNum1, dacNum2, waveform, centerVolt, dutyCycle, trigType)  

gui(scope)