# The Meadowlark `Create_SDK` binding, checked without the DLL.
#
# No build machine has the Blink SDK, and calling it is never safe in a test. What broke was the binding's
# argument types (a 4-byte `0::Cuint` where the header declares `char*`), so the test reads the types out of the
# wrapper's own lowered `foreigncall`, which is exactly what is handed to the C call.

@testset "Meadowlark Create_SDK binding (no DLL)" begin
    ML = MicroscopeControl.HardwareImplementations.Meadowlark
    calls = Expr[]
    for ci in Base.code_lowered(ML._create_sdk)
        for st in ci.code
            st isa Expr && st.head === :foreigncall && push!(calls, st)
        end
    end
    @test length(calls) == 1
    fc = only(calls)
    name = fc.args[1]
    @test occursin("Create_SDK", string(name))
    argtypes = collect(fc.args[3])
    # the vendor header: (unsigned int, unsigned int*, int*, int, int, int, int, char*)
    @test length(argtypes) == 8
    @test argtypes[1] == Cuint
    @test argtypes[2] in (Ref{Cuint}, Ptr{Cuint})      # unsigned int*
    @test argtypes[3] in (Ref{Cint}, Ptr{Cint})        # int*
    @test all(==(Cint), argtypes[4:7])
    @test argtypes[8] == Ptr{Cchar}                    # a pointer, 8 bytes on x64, not a 4-byte integer
    @test fc.args[2] == Cvoid

    # initializesdk keeps its zero-argument form and takes the vendor parameters by keyword
    m = only(methods(ML.initializesdk))
    @test m.nargs == 1
    kws = Base.kwarg_decl(m)
    @test Set(kws) == Set([:bit_depth, :is_nematic_type, :ram_write_enable, :use_gpu, :max_transient_frames,
                           :regional_lut])
end
