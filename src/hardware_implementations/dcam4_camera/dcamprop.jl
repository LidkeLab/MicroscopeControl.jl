# dcamprop stuctures and functions

@enum DCAM_PROP_ATTR::Int begin
    HASRANGE            = -2147483647
    HASSTEP             = 0x40000000
    HASDEFAULT          = 0x20000000
    HASVALUETEXT        = 0x10000000
    HASCHANNEL          = 0x08000000
    AUTOROUNDING        = 0x00800000
    STEPPING_INCONSISTENT = 0x00400000
    DATASTREAM          = 0x00200000
    HASRATIO            = 0x00100000
    VOLATILE            = 0x00080000
    WRITABLE            = 0x00020000
    READABLE            = 0x00010000
    HASVIEW             = 0x00008000
    SYSTEM              = 0x00004000
    ACCESSREADY         = 0x00002000
    ACCESSBUSY          = 0x00001000
    ADVANCED            = 0x00000800
    EFFECTIVE           = 0x00000200
end

mutable struct DCAMPROP_ATTR
    cbSize::Int32
    iProp::Int32
    option::Int32
    iReserved1::Int32
    attribute::Int32
    iGroup::Int32
    iUnit::Int32
    attribute2::Int32
    valuemin::Float64
    valuemax::Float64
    valuestep::Float64
    valuedefault::Float64
    nMaxChannel::Int32
    iReserved3::Int32
    nMaxView::Int32
    iProp_NumberOfElement::Int32
    iProp_ArrayBase::Int32
    iPropStep_Element::Int32
end

function DCAMPROP_ATTR()
    dca = DCAMPROP_ATTR(0, 0, 0, 0, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0)
    dca.cbSize=sizeof(DCAMPROP_ATTR)
    return dca
end

is_effective(attr::DCAMPROP_ATTR) = attr.attribute & Int(EFFECTIVE) != 0
is_writable(attr::DCAMPROP_ATTR) = attr.attribute & Int(WRITABLE) != 0
is_readable(attr::DCAMPROP_ATTR) = attr.attribute & Int(READABLE) != 0
is_volatile(attr::DCAMPROP_ATTR) = attr.attribute & Int(VOLATILE) != 0
is_accessready(attr::DCAMPROP_ATTR) = attr.attribute & Int(ACCESSREADY) != 0
is_accessbusy(attr::DCAMPROP_ATTR) = attr.attribute & Int(ACCESSBUSY) != 0
is_datastream(attr::DCAMPROP_ATTR) = attr.attribute & Int(DATASTREAM) != 0
is_autorounding(attr::DCAMPROP_ATTR) = attr.attribute & Int(AUTOROUNDING) != 0
is_stepping_inconsistent(attr::DCAMPROP_ATTR) = attr.attribute & Int(STEPPING_INCONSISTENT) != 0
is_hasview(attr::DCAMPROP_ATTR) = attr.attribute & Int(HASVIEW) != 0
is_haschannel(attr::DCAMPROP_ATTR) = attr.attribute & Int(HASCHANNEL) != 0
is_hasrange(attr::DCAMPROP_ATTR) = attr.attribute & Int(HASRANGE) != 0
is_hasstep(attr::DCAMPROP_ATTR) = attr.attribute & Int(HASSTEP) != 0
is_hasdefault(attr::DCAMPROP_ATTR) = attr.attribute & Int(HASDEFAULT) != 0
is_hasvaluetext(attr::DCAMPROP_ATTR) = attr.attribute & Int(HASVALUETEXT) != 0
is_hasratio(attr::DCAMPROP_ATTR) = attr.attribute & Int(HASRATIO) != 0
is_system(attr::DCAMPROP_ATTR) = attr.attribute & Int(SYSTEM) != 0
is_advanced(attr::DCAMPROP_ATTR) = attr.attribute & Int(ADVANCED) != 0


"""
options
"""
@enum DCAMPROP_OPTION::Int begin
    DCAMPROP_OPTION_PRIOR = -16777215  # 0xFF000000
    DCAMPROP_OPTION_NEXT = 0x01000000
    DCAMPROP_OPTION_NEAREST = 0x80000000
    DCAMPROP_OPTION_SUPPORT = 0x00000000
    DCAMPROP_OPTION_UPDATED = 0x00000001
    DCAMPROP_OPTION_VOLATILE = 0x00000002
    DCAMPROP_OPTION_ARRAYELEMENT = 0x00000004
    # DCAMPROP_OPTION_NONE = 0x00000000
end

"""
Unit of value
"""
@enum DCAMPROP_UNIT::Int begin
    SECOND = 1
    CELSIUS = 2
    KELVIN = 3
    METERPERSECOND = 4
    PERSECOND = 5
    DEGREE = 6
    MICROMETER = 7
    DCAMPROP_UNIT_NONE = 0
end

@enum DCAM_PROP_TYPE::Int begin
    DCAM_PROP_TYPE_NONE = 0x00000000
    DCAM_PROP_TYPE_MODE = 0x00000001
    DCAM_PROP_TYPE_LONG = 0x00000002
    DCAM_PROP_TYPE_REAL = 0x00000003
    DCAM_PROP_TYPE_MASK = 0x0000000F
end

mutable struct DCAMPROP_VALUETEXT
    cbSize::Int32
    iProp::Int32
    value::Float64
    text::Ptr{Cchar}
    textbytes::Int32
end



function DCAMPROP_VALUETEXT()
    d = DCAMPROP_VALUETEXT(0, 0, 0.0, C_NULL, 0)
    d.cbSize = sizeof(d)
    return d
end

mutable struct Prop_Info
    name::String
    type::String
    unit::String
    range::Vector{Float64}
    writable::Int32
    readable::Int32
    options
end

function Prop_Info()
    prop = Prop_Info("", "", "", [0.0, 0.0, 0.0], 0, 0, [])
    return prop
end

function alloctext(d::DCAMPROP_VALUETEXT, maxlen::Int)
    textbuf = Vector{Cchar}(undef, maxlen)
    d.text = pointer(textbuf)
    d.textbytes = sizeof(textbuf)
    return d, textbuf  # return both `d` and `textbuf` to prevent garbage collection
end

function dcamprop_getattr(hdcam::Ptr{Cvoid}, iProp::Int32)
    dca = DCAMPROP_ATTR()
    dca.iProp = iProp
    ptr_dca = Ref(dca)
    err = @ccall "dcamapi.dll".dcamprop_getattr(hdcam::Ptr{Cvoid},ptr_dca::Ref{DCAMPROP_ATTR})::DCAMERR
    return err, dca
end

function dcamprop_getattr(hdcam::Ptr{Cvoid}, idprop::DCAM_IDPROP)
    return dcamprop_getattr(hdcam, Int32(idprop))
end

function dcamprop_getvalue(hdcam::Ptr{Cvoid},iProp::Int32)
    pValue = Ref{Float64}(0.0)
    err = @ccall "dcamapi.dll".dcamprop_getvalue(hdcam::Ptr{Cvoid}, iProp::Int32, pValue::Ref{Float64})::DCAMERR
    if is_failed(err)
        @error "DCAM Failed to get Value"
    end
    return err, pValue[]
end

function dcamprop_getvalue(hdcam::Ptr{Cvoid},idprop::DCAM_IDPROP)
    return dcamprop_getvalue(hdcam,Int32(idprop))
end


function dcamprop_setvalue(hdcam::Ptr{Cvoid}, iProp::Int32, fValue::Float64)
    err = @ccall "dcamapi.dll".dcamprop_setvalue(hdcam::Ptr{Cvoid}, iProp::Int32, fValue::Float64)::DCAMERR
    if is_failed(err)
        @error "DCAM Failed to set value of $(fValue) for: $(DCAM_IDPROP(iProp))"
        display(err)
    end
    return err
end

function dcamprop_setvalue(hdcam::Ptr{Cvoid}, idprop::DCAM_IDPROP, fValue::Float64)
    return dcamprop_setvalue(hdcam, Int32(idprop), fValue)
end 

function dcamprop_setgetvalue(hdcam::Ptr{Cvoid}, iProp::Int32)
    pValue = Ref{Float64}(0.0)
    option - 0
    err = @ccall "dcamapi.dll".dcamprop_setgetvalue(hdcam::Ptr{Cvoid}, iProp::Int32, pValue::Ref{Float64}, option::Int32)::DCAMERR
    if is_failed(err)
        @error "DCAM Failed to set/get value"
    end
    return err, pValue[]
end

"""
Option to request the kind of value. This parameter can be one of following values;
DCAMPROP_OPTION_NONE	return value is the actual set value for the device when host software calls dcamprop_setvalue()
DCAMPROP_OPTION_PRIOR	return value is the prior value
DCAMPROP_OPTION_NEXT	return value is the next value
"""
function dcamprop_queryvalue(hdcam::Ptr{Cvoid}, iProp::Int32, option::Int32)
    pValue = Ref{Float64}(0.0)
    err = @ccall "dcamapi.dll".dcamprop_queryvalue(hdcam::Ptr{Cvoid}, iProp::Int32, pValue::Ref{Float64}, option::Int32)::DCAMERR
    if is_failed(err)
        @error "DCAM Failed to query value"
    end
    return err, pValue[]
end

function dcamprop_getnextid(hdcam::Ptr{Cvoid}, idprop::Int32, option::DCAMPROP_OPTION)
    pProp = Ref(idprop)
    err = @ccall "dcamapi.dll".dcamprop_getnextid(hdcam::Ptr{Cvoid}, pProp::Ref{Int32}, option::Int32)::DCAMERR
    if is_failed(err)
        @error "DCAM Failed to get next ID"
        pProp[] = 0
    end
    return err, pProp[]
end

function dcamprop_getname(hdcam::Ptr{Cvoid}, iProp::Int32)
    textbytes = 256
    text = Vector{Cchar}(undef, textbytes)
    err = @ccall "dcamapi.dll".dcamprop_getname(hdcam::Ptr{Cvoid}, iProp::Int32, text::Ptr{Cchar}, textbytes::Int32)::DCAMERR
    if is_failed(err)
        @error "DCAM Failed to get name"
    end

    # Convert the null-terminated Cchar array to a Julia String
    str = unsafe_string(pointer(text))

    # Find the first null character
    null_char_pos = findfirst(==(Cchar(0)), text)

    # If a null character was found, truncate the string
    if null_char_pos !== nothing
        str = str[1:null_char_pos-1]
    end

    return err, str
end




function dcamprop_getvaluetext(hdcam::Ptr{Cvoid}, param::DCAMPROP_VALUETEXT)
    ptr_param = Ref(param)
    err = @ccall "dcamapi.dll".dcamprop_getvaluetext(hdcam::Ptr{Cvoid}, ptr_param::Ref{DCAMPROP_VALUETEXT})::DCAMERR
    if is_failed(err)
        @error "DCAM Failed to get value text"
        return err, ""
    end
    str = unsafe_string(param.text)
    return err, str
end

function dcamprop_getsize(hdcam::Ptr{Cvoid})
    err, width = dcamprop_getvalue(hdcam, Int32(DCAM_IDPROP_IMAGE_WIDTH))
    if is_failed(err)
        @error "DCAM Failed to get width"
    end

    err, height = dcamprop_getvalue(hdcam, Int32(DCAM_IDPROP_IMAGE_HEIGHT))
    if is_failed(err)
        @error "DCAM Failed to get height"
    end

    return Int(width), Int(height)
end

function dcam_get_prop_options!(hdcam::Ptr{Cvoid}, prop::Prop_Info,idprop::Int32)
    options = fill("",Int(prop.range[2]))
    d = DCAMPROP_VALUETEXT()
    d.iProp = idprop
    d, textbuf = alloctext(d, 256)
    for i in Int(prop.range[1]):Int(prop.range[2])
        d.value = i
        err, text = dcamprop_getvaluetext(hdcam,d)
        options[i] = text
    end
    prop.options = options
    return nothing
end

function dcam_get_propinfo(hdcam::Ptr{Cvoid},idprop::Int32)
    prop = Prop_Info()
    err, name = dcamprop_getname(hdcam, idprop)
    prop.name = name
    err, attr = dcamprop_getattr(hdcam, idprop)
    dcam_get_propinfo!(attr, prop)
    if prop.type == "Mode"
        dcam_get_prop_options!(hdcam, prop, idprop)
    end
    return prop
end

function dcam_get_propinfo!(attr::DCAMPROP_ATTR, prop::Prop_Info)

    prop.readable = is_readable(attr)
    prop.writable = is_writable(attr)

    if attr.iUnit == Int(SECOND)
        prop.unit = "Second"
    elseif attr.iUnit == Int(CELSIUS)
        prop.unit = "Celsius"
    elseif attr.iUnit == Int(KELVIN)
        prop.unit = "Kelvin"
    elseif attr.iUnit == Int(METERPERSECOND)
        prop.unit = "Meter per second"
    elseif attr.iUnit == Int(PERSECOND)
        prop.unit = "Per second"
    elseif attr.iUnit == Int(DEGREE)
        prop.unit = "Degree"
    elseif attr.iUnit == Int(MICROMETER)
        prop.unit = "Micrometer"
    else
        prop.unit = "None"
    end

    if attr.attribute & Int(DCAM_PROP_TYPE_MASK) == Int(DCAM_PROP_TYPE_MODE)
        prop.type = "Mode"
    elseif attr.attribute & Int(DCAM_PROP_TYPE_MASK) == Int(DCAM_PROP_TYPE_LONG)
        prop.type = "Long"
    elseif attr.attribute & Int(DCAM_PROP_TYPE_MASK) == Int(DCAM_PROP_TYPE_REAL)
        prop.type = "Real"
    else
        prop.type = "None"
    end


    if is_hasrange(attr)
        prop.range[1] = attr.valuemin
        prop.range[2] = attr.valuemax
    else
        prop.range[1] = 1.0
        prop.range[2] = 2.0
    end

    if is_hasstep(attr)
        prop.range[3] = attr.valuestep
    else
        prop.range[3] = -1.0
    end

    return nothing

end

