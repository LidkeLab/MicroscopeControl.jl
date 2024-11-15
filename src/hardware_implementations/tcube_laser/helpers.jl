# This code is useful when trying to find 

const Thorlabs_Tcube_laser = "C:\\Program Files\\Thorlabs\\Kinesis\\Thorlabs.MotionControl.TCube.LaserDiode.dll"
include("constants_Tlaser.jl")
include("functions_Tlaser.jl")

TLI_BuildDeviceList()
TLI_GetDeviceListSize()

buffersize = 128 # just a guess of a large number that we hyposize is larger than the actual size of the string
devstring = zeros(UInt8, buffersize) # create a buffer to store the device list
TLI_GetDeviceList(devstring) # get the device list
devstring = filter(x -> x != 0x00, devstring) # remove the null characters from the string
@info "Laser: " * String(devstring) # print the device list

serialstring = zeros(UInt8, buffersize) # create a buffer to store the serial number
TLI_GetDeviceListByTypeExt(serialstring,buffersize,64) # get the serial number

serialNo = unsafe_string(pointer(serialstring)) # convert the serial number to a string
serialNo = serialNo[1:8] # extract the serial number from the string (i.e., remove the extra comma)
@info "Serial number: " * serialNo #here, * is used to concatenate the strings

serialNo = "64849775"
LD_Open(serialNo)
LD_SetOpenLoopMode(serialNo)
LD_EnableOutput(serialNo)
global current2::Float64 = 80 # [mA]
current_identifier::UInt16 = UInt16(round(current2/220.0*32767.0))
LD_SetLaserSetPoint(serialNo, current_identifier)
LD_DisableOutput(serialNo)
LD_Close(serialNo)


LD_RequestReadings(serialNo)
Float64(LD_GetLaserDiodeCurrentReading(serialNo))/32767.0*220.0
out = Float64(LD_GetLaserDiodeMaxCurrentLimit(serialNo))/32767.0*220.0
max_setpoint = 32767.0
max_setcurrent = 220.0
max_current = Float64(out)/max_setpoint*max_setcurrent



LD_SetClosedLoopMode(serialNo)

calibFactor = 224.2
LD_SetWACalibFactor(serialNo, calibFactor)

Float64(LD_GetPhotoCurrentReading(serialNo))/calibFactor

LD_GetWACalibFactor(serialNo)


WperA = 224.2
TIARange = 1.0


laser_power = 70.0


LD_SetLaserSetPoint(serialNo, UInt16(round(50.0*32767.0/WperA/TIARange)))



### Data for expected power vs actual power in mW; no statistical measurements used
# 0.0, less than 0.001 mW
# 10.0, 9.31 mW
# 20.0, 19.11
# 30.0, 29.11
# 40.0, 39.06
# 50.0, 48.97
# 60.0, 59.22
# 70.0, 69.65
# 80.0, 79.5


