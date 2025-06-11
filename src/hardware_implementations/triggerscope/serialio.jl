#These functions will communicate with the board
function openport(scope::Triggerscope4)
    #open the serial port
    scope.sp = LibSerialPort.open(scope.portname, scope.baudrate)   #opens the serial port
    #set the read and write timeouts
    set_read_timeout(scope.sp, scope.rwtimeout)                     #Sets timeout for failed read operations
    set_write_timeout(scope.sp, scope.rwtimeout)                    #Sets timeout for failed write operations
end

function writecommand(scope::Triggerscope4, command::String)
    write(scope.sp, command)                                        #writes the command to the serial port
    sleep(scope.comtimeout)                                         #automatic pause after sending a command, optional
end

function readresponse(scope::Triggerscope4)
    return readline(scope.sp)                                       #Right now this only reads one line of the response, some commands may return multiple lines
end