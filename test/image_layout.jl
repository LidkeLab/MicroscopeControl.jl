# The lab image layout (decision 0040): an image is `[y, x]`, a stack `(ny, nx, nframes)`, `[1, 1]` at the top
# left. Every array here is non-square, and its value encodes its own row and column, so a swapped or transposed
# axis fails. `image_layout_fakes.jl` runs the driver paths that need a replaced SDK.

# Pixel value 100*row + col, in the `[y, x]` layout the drivers must produce.
layout_image(ny, nx) = [UInt16(100 * y + x) for y in 1:ny, x in 1:nx]

# What an SDK writes for that image: `ny` rows of `stride` elements, row-major, pad elements marked 0xffff.
function layout_rowmajor(img; stride = size(img, 2))
    ny, nx = size(img)
    buf = fill(0xffff, stride * ny)
    for y in 1:ny, x in 1:nx
        buf[(y - 1) * stride + x] = img[y, x]
    end
    return buf
end

@testset "Image layout" begin
    CameraInterface = MicroscopeControl.HardwareInterfaces.CameraInterface
    rowmajor_to_yx = CameraInterface.rowmajor_to_yx

    @testset "rowmajor_to_yx" begin
        img = layout_image(3, 5)
        @test rowmajor_to_yx(UInt16[11, 12, 13, 21, 22, 23], 3, 2) == [11 12 13; 21 22 23]

        out = rowmajor_to_yx(layout_rowmajor(img), 5, 3)
        @test size(out) == (3, 5)
        @test out == img
        @test out[2, 4] == 204               # row 2, column 4

        # Padded rows: the stride exceeds the width, and the padding is dropped.
        padded = rowmajor_to_yx(layout_rowmajor(img; stride = 8), 5, 3; stride = 8)
        @test size(padded) == (3, 5)
        @test padded == img
        @test !any(==(0xffff), padded)

        # A tall image as well, and an 8-bit buffer.
        tall = layout_image(7, 2)
        @test rowmajor_to_yx(layout_rowmajor(tall), 2, 7) == tall
        @test rowmajor_to_yx(UInt8[1, 2, 3, 4, 5, 6], 3, 2) == UInt8[1 2 3; 4 5 6]

        # A buffer longer than the frame is read from the front.
        @test rowmajor_to_yx([layout_rowmajor(img); UInt16[9, 9]], 5, 3) == img

        @test_throws ArgumentError rowmajor_to_yx(UInt16[1, 2, 3], 2, 2)
        @test_throws ArgumentError rowmajor_to_yx(UInt16[1, 2, 3, 4], 3, 1; stride = 2)
    end

    @testset "SimCamera shape is (height, width[, N])" begin
        cam = SimCamera(exposure_time = 0.01)
        cam.roi = CameraROI(1, 1, 64, 32)          # width 64, height 32
        capture(cam)
        @test size(getdata(cam)) == (32, 64)
        @test size(getlastframe(cam)) == (32, 64)
        cam.sequence_length = 3
        sequence(cam)
        @test size(getdata(cam)) == (32, 64, 3)
        abort(cam)
        live(cam)
        @test size(getdata(cam)) == (32, 64)
        abort(cam)
    end

    @testset "save_h5 writes the array as it is, with the convention's attributes" begin
        mktempdir() do dir
            for (data, order) in ((rand(UInt16, 6, 10), "y,x"), (rand(UInt16, 6, 10, 4), "y,x,frame"))
                path = joinpath(dir, "layout$(ndims(data)).h5")
                wait(save_h5(path, (Dict{String,Any}(), data, Dict{String,Any}())))
                HDF5.h5open(path, "r") do h5
                    dset = h5["Main/data"]
                    @test read(dset) == data
                    @test size(dset) == size(data)
                    @test HDF5.read_attribute(dset, "dimension_order") == order
                    @test HDF5.read_attribute(dset, "dimension_order_convention") ==
                        "column-major (Julia/MATLAB); C-order tools list it reversed"
                    @test HDF5.read_attribute(dset, "memory_layout") == "column_major_julia"
                    @test HDF5.read_attribute(dset, "dimension_labels") ==
                        (ndims(data) == 2 ? ["height", "width"] : ["height", "width", "frames"])
                end
            end
        end
    end
end
