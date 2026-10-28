const BLINK_DLL = "C:\\Program Files\\Meadowlark Optics\\Blink OverDrive Plus\\SDK\\Blink_C_wrapper.dll"

# The vendor header (Blink_C_wrapper.h) declares
#
#     void Create_SDK(unsigned int SLM_bit_depth, unsigned int* n_boards_found, int* constructed_ok,
#                     int is_nematic_type, int RAM_write_enable, int use_GPU_if_available,
#                     int max_transient_frames, char* static_regional_lut_file);
#
# The last argument is a POINTER. It used to be passed as `0::Cuint`, a 4-byte integer; on Windows x64 the eighth
# argument goes on the stack, the SDK reads 8 bytes there, gets 4 bytes of garbage above the zero and dereferences a
# wild pointer. The process then dies with no Julia traceback (seen on a rig, 2026-09). A NULL `Ptr{Cchar}` means "no
# regional LUT", as the vendor's examples pass it.
_create_sdk(bit_depth, n_boards_found, constructed_ok, is_nematic_type, ram_write_enable, use_gpu,
            max_transient_frames, regional_lut) =
    @ccall BLINK_DLL.Create_SDK(bit_depth::Cuint, n_boards_found::Ref{Cuint}, constructed_ok::Ref{Cint},
        is_nematic_type::Cint, ram_write_enable::Cint, use_gpu::Cint, max_transient_frames::Cint,
        regional_lut::Ptr{Cchar})::Cvoid

"""
    initializesdk(; bit_depth = 12, is_nematic_type = 1, ram_write_enable = 1, use_gpu = 1,
                  max_transient_frames = 10, regional_lut = nothing) -> (; n_boards_found, constructed_ok)

Open the Blink SDK (`Create_SDK`). `regional_lut` is the path of a static regional LUT file, or `nothing` for none
(a NULL pointer). Prints the board count and the constructor's flag, as before, and returns them.

Call it once per process: a second `Create_SDK` without `closesdk()` in between crashes the process, and so does a
`Create_SDK` on a board another process (or a crashed session) still holds, which needs a power cycle of the SLM
controller.
"""
function initializesdk(; bit_depth::Integer = 12, is_nematic_type::Integer = 1, ram_write_enable::Integer = 1,
                       use_gpu::Integer = 1, max_transient_frames::Integer = 10,
                       regional_lut::Union{Nothing,AbstractString} = nothing)
    n_boards_found = Ref{Cuint}(0)
    constructed_ok = Ref{Cint}(0)
    if regional_lut === nothing
        _create_sdk(Cuint(bit_depth), n_boards_found, constructed_ok, Cint(is_nematic_type), Cint(ram_write_enable),
                    Cint(use_gpu), Cint(max_transient_frames), Ptr{Cchar}(C_NULL))
    else
        path = String(regional_lut)
        GC.@preserve path _create_sdk(Cuint(bit_depth), n_boards_found, constructed_ok, Cint(is_nematic_type),
            Cint(ram_write_enable), Cint(use_gpu), Cint(max_transient_frames), Base.unsafe_convert(Ptr{Cchar}, path))
    end

    println(n_boards_found[])
    println(constructed_ok[])
    return (; n_boards_found = Int(n_boards_found[]), constructed_ok = constructed_ok[] != 0)
end

function closesdk()
    # Close the SLM
    @ccall BLINK_DLL.Delete_SDK()::Cvoid
end
