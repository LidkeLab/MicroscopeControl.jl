
@enum DCAMERR begin
    # status error
    DCAMERR_BUSY = -2147483391  # 0x80000101, API cannot process in busy state.
    DCAMERR_NOTREADY = -2147483389  # 0x80000103, API requires ready state.
    DCAMERR_NOTSTABLE = -2147483388  # 0x80000104, API requires stable or unstable state.
    DCAMERR_UNSTABLE = -2147483387  # 0x80000105, API does not support in unstable state.
    DCAMERR_NOTBUSY = -2147483385  # 0x80000107, API requires busy state.
    DCAMERR_EXCLUDED = -2147483376  # 0x80000110, some resource is exclusive and already used
    DCAMERR_COOLINGTROUBLE = -2147482878  # 0x80000302, something happens near cooler
    DCAMERR_NOTRIGGER = -2147482877  # 0x80000303, no trigger when necessary. Some camera supports this error.
    DCAMERR_TEMPERATURE_TROUBLE = -2147482876  # 0x80000304, camera warns its temperature
    DCAMERR_TOOFREQUENTTRIGGER = -2147482875  # 0x80000305, input too frequent trigger. Some camera supports this error.
    # wait error
    DCAMERR_ABORT = -2147483390  # 0x80000102, abort process
    DCAMERR_TIMEOUT = -2147483386  # 0x80000106, timeout
    DCAMERR_LOSTFRAME = -2147482879  # 0x80000301, frame data is lost
    DCAMERR_MISSINGFRAME_TROUBLE = -2147479802  # 0x80000f06, frame is lost but reason is low lever driver's bug
    DCAMERR_INVALIDIMAGE = -2147482847  # 0x80000321, hpk format data is invalid data
    # initialization error
    DCAMERR_NORESOURCE = -2147483135  # 0x80000201, not enough resource except memory
    DCAMERR_NOMEMORY = -2147483133  # 0x80000203, not enough memory
    DCAMERR_NOMODULE = -2147483132  # 0x80000204, no sub module
    DCAMERR_NODRIVER = -2147483131  # 0x80000205, no driver
    DCAMERR_NOCAMERA = -2147483130  # 0x80000206, no camera
    DCAMERR_NOGRABBER = -2147483129  # 0x80000207, no grabber
    DCAMERR_NOCOMBINATION = -2147483128  # 0x80000208, no combination on registry
    DCAMERR_FAILOPEN = -2147479551  # 0x80001001, DEPRECATED
    DCAMERR_FRAMEGRABBER_NEEDS_FIRMWAREUPDATE = -2147479550  # 0x80001002, need to update frame grabber firmware to use the camera
    DCAMERR_INVALIDMODULE = -2147483119  # 0x80000211, dcam_init() found invalid module
    DCAMERR_INVALIDCOMMPORT = -2147483118  # 0x80000212, invalid serial port
    DCAMERR_FAILOPENBUS = -2130702335  # 0x81001001, the bus or driver are not available```julia
    DCAMERR_FAILOPENCAMERA = -2113925119  # 0x82001001, camera report error during opening
    DCAMERR_DEVICEPROBLEM = -2113925118  # 0x82001002, initialization failed(for maico)
    # calling error
    DCAMERR_INVALIDCAMERA = -2147481594  # 0x80000806, invalid camera
    DCAMERR_INVALIDHANDLE = -2147481593  # 0x80000807, invalid camera handle
    DCAMERR_INVALIDPARAM = -2147481592  # 0x80000808, invalid parameter
    DCAMERR_INVALIDVALUE = -2147481567  # 0x80000821, invalid property value
    DCAMERR_OUTOFRANGE = -2147481566  # 0x80000822, value is out of range
    DCAMERR_NOTWRITABLE = -2147481565  # 0x80000823, the property is not writable
    DCAMERR_NOTREADABLE = -2147481564  # 0x80000824, the property is not readable
    DCAMERR_INVALIDPROPERTYID = -2147481563  # 0x80000825, the property id is invalid
    DCAMERR_NEWAPIREQUIRED = -2147481562  # 0x80000826, old API cannot present the value because only new API need to be used
    DCAMERR_WRONGHANDSHAKE = -2147481561  # 0x80000827, this error happens DCAM get error code from camera unexpectedly
    DCAMERR_NOPROPERTY = -2147481560  # 0x80000828, there is no altenative or influence id, or no more property id
    DCAMERR_INVALIDCHANNEL = -2147481559  # 0x80000829, the property id specifies channel but channel is invalid
    DCAMERR_INVALIDVIEW = -2147481558  # 0x8000082a, the property id specifies channel but channel is invalid
    DCAMERR_INVALIDSUBARRAY = -2147481557  # 0x8000082b, the combination of subarray values are invalid. e.g. DCAM_IDPROP_SUBARRAYHPOS + DCAM_IDPROP_SUBARRAYHSIZE is greater than the number of horizontal pixel of sensor.
    DCAMERR_ACCESSDENY = -2147481556  # 0x8000082c, the property cannot access during this DCAM STATUS
    DCAMERR_NOVALUETEXT = -2147481555  # 0x8000082d, the property does not have value text
    DCAMERR_WRONGPROPERTYVALUE = -2147481554  # 0x8000082e, at least one property value is wrong
    DCAMERR_DISHARMONY = -2147481552  # 0x80000830, the paired camera does not have same parameter
    DCAMERR_FRAMEBUNDLESHOULDBEOFF = -2147481550  # 0x80000832, framebundle mode should be OFF under current property settings
    DCAMERR_INVALIDFRAMEINDEX = -2147481549  # 0x80000833, the frame index is invalid
    DCAMERR_INVALIDSESSIONINDEX = -2147481548  # 0x80000834, the session index is invalid
    DCAMERR_NOCORRECTIONDATA = -2147481544  # 0x80000838, not take the dark and shading correction data yet.
    DCAMERR_CHANNELDEPENDENTVALUE = -2147481543  # 0x80000839, each channel has own property value so can't return overall property value.
    DCAMERR_VIEWDEPENDENTVALUE = -2147481542  # 0x8000083a, each view has own property value so can't return overall property value.
    DCAMERR_NODEVICEBUFFER = -2147481541  # 0x8000083b, the frame count is larger than device momory size on using device memory.
    DCAMERR_REQUIREDSNAP = -2147481540  # 0x8000083c, the capture mode is sequence on using device memory.
    DCAMERR_LESSSYSTEMMEMORY = -2147481537  # 0x8000083f, the sysmte memory size is too small. PC doesn't have enough memory or is limited memory by 32bit OS.
    DCAMERR_NOTSUPPORT = -2147479805  # 0x80000f03, camera does not support the function or property with current settings
    # camera or bus trouble
    DCAMERR_FAILREADCAMERA = -2097147902  # 0x83001002, failed to read data from camera
    DCAMERR_FAILWRITECAMERA = -2097147901  # 0x83001003, failed to write data to the camera
    DCAMERR_CONFLICTCOMMPORT = -2097147900  # 0x83001004, conflict the com port name user set
    DCAMERR_OPTICS_UNPLUGGED = -2097147899  # 0x83001005, Optics part is unplugged so please check it.
    DCAMERR_FAILCALIBRATION = -2097147898  # 0x83001006, fail calibration
    DCAMERR_MISMATCH_CONFIGURATION = -2097147887  # 0x83001011, mismatch between camera output(connection) and frame grabber specs
    # 0x84000100 - 0x840001FF, DCAMERR_INVALIDMEMBER_x
    DCAMERR_INVALIDMEMBER_3 = -2080374525  # 0x84000103, 3th member variable is invalid value
    DCAMERR_INVALIDMEMBER_5 = -2080374523  # 0x84000105, 5th member variable is invalid value
    DCAMERR_INVALIDMEMBER_7 = -2080374521  # 0x84000107, 7th member variable is invalid value
    DCAMERR_INVALIDMEMBER_8 = -2080374520  # 0x84000108, 7th member variable is invalid value
    DCAMERR_INVALIDMEMBER_9 = -2080374519  # 0x84000109, 9th member variable is invalid value
    DCAMERR_FAILEDOPENRECFILE = -2080370687  # 0x84001001, DCAMREC failed to open the file
    DCAMERR_INVALIDRECHANDLE = -2080370686  # 0x84001002, DCAMREC is invalid handle
    DCAMERR_FAILEDWRITEDATA = -2080370685  # 0x84001003, DCAMREC failed to write the data
    DCAMERR_FAILEDREADDATA = -2080370684  # 0x84001004, DCAMREC failed to read the data
    DCAMERR_NOWRECORDING = -2080370683  # 0x84001005, DCAMREC is recording data now
    DCAMERR_WRITEFULL = -2080370682  # 0x84001006, DCAMREC writes full frame of the session
    DCAMERR_ALREADYOCCUPIED = -2080370681  # 0x84001007, DCAMREC handle is already occupied by other HDCAM
    DCAMERR_TOOLARGEUSERDATASIZE = -2080370680  # 0x84001008, DCAMREC is set the large value to user data size
    DCAMERR_INVALIDWAITHANDLE = -2080366591  # 0x84002001, DCAMWAIT is invalid handle
    DCAMERR_NEWRUNTIMEREQUIRED = -2080366590  # 0x84002002, DCAM Module Version is older than the version that the camera requests
    DCAMERR_VERSIONMISMATCH = -2080366589  # 0x84002003, Camre returns the error on setting parameter to limit version
    DCAMERR_RUNAS_FACTORYMODE = -2080366588  # 0x84002004, Camera is running as a factory mode
    DCAMERR_IMAGE_UNKNOWNSIGNATURE = -2080362495  # 0x84003001, sigunature of image header is unknown or corrupted
    DCAMERR_IMAGE_NEWRUNTIMEREQUIRED = -2080362494  # 0x84003002, version of image header is newer than version that used DCAM supports
    DCAMERR_IMAGE_ERRORSTATUSEXIST = -2080362493  # 0x84003003, image header stands error status
    DCAMERR_IMAGE_HEADERCORRUPTED = -2080358396  # 0x84004004, image header value is strange
    DCAMERR_IMAGE_BROKENCONTENT = -2080358395  # 0x84004005, image content is corrupted
    # calling error for DCAM-API 2.1.3
    DCAMERR_UNKNOWNMSGID = -2147481599  # 0x80000801, unknown message id
    DCAMERR_UNKNOWNSTRID = -2147481598  # 0x80000802, unknown string id
    DCAMERR_UNKNOWNPARAMID = -2147481597  # 0x80000803, unkown parameter id
    DCAMERR_UNKNOWNBITSTYPE = -2147481596  # 0x80000804, unknown bitmap bits type
    DCAMERR_UNKNOWNDATATYPE = -2147481595  # 0x80000805, unknown frame data type
    # internal error
    DCAMERR_NONE = 0  # 0, no error, nothing to have done
    DCAMERR_INSTALLATIONINPROGRESS = -2147479808  # 0x80000f00, installation progress
    DCAMERR_UNREACH = -2147479807  # 0x80000f01, internal error
    DCAMERR_UNLOADED = -2147479804  # 0x80000f04, calling after process terminated
    DCAMERR_THRUADAPTER = -2147479803  # 0x80000f05
    DCAMERR_NOCONNECTION = -2147479801  # 0x80000f07, HDCAM lost connection to camera
    DCAMERR_NOTIMPLEMENT = -2147479806  # 0x80000f02, not yet implementation
    DCAMERR_DELAYEDFRAME = -2147479799  # 0x80000f09, the frame waiting re-load from hardware buffer with SNAPSHOT of DEVICEBUFFER MODE
    DCAMERR_DEVICEINITIALIZING = -1342177279  # 0xb0000001
    DCAMERR_APIINIT_INITOPTIONBYTES = -1543438333  # 0xa4010003, DCAMAPI_INIT::initoptionbytes is invalid
    DCAMERR_APIINIT_INITOPTION = -1543438332  # 0xa4010004, DCAMAPI_INIT::initoption is invalid
    DCAMERR_INITOPTION_COLLISION_BASE = -1543389184  # 0xa401C000
    DCAMERR_INITOPTION_COLLISION_MAX = -1543372801  # 0xa401FFFF
    # Between DCAMERR_INITOPTION_COLLISION_BASE and DCAMERR_INITOPTION_COLLISION_MAX means there is collision with initoption in DCAMAPI_INIT.
    # The value "(error code) - DCAMERR_INITOPTION_COLLISION_BASE" indicates the index which second INITOPTION group happens.
    DCAMERR_MISSPROP_TRIGGERSOURCE = -535822064  # 0xE0100110, the trigger mode is internal or syncreadout on using device memory.
    # success
    DCAMERR_SUCCESS = 1  # 1, no error, general success code, app should check the value is positive

    DCAMERR_ALREADYINITIALIZED = -520093695  # 0xE1000001
    DCAMERR_ALREADYOPENED = -520093694  # 0xE1000002
    DCAMERR_INVALIDPIXELTYPE = -520093440  # 0xE1000100

    DCAMERR_SUCCESS_PROP_GETATTR = 88  # dcamprop_getattr() returns this value at SUCCESS
end

# Function to check if the error code indicates a failure
function is_failed(err::DCAMERR)
    return Int(err) < 0
end

# Function to check if the error code indicates a timeout
function is_timeout(err::DCAMERR)
    return err == DCAMERR_TIMEOUT
end
