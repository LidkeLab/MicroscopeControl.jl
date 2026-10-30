"""
    rowmajor_to_yx(buf::AbstractVector, width::Integer, height::Integer; stride::Integer = width)

Convert a camera SDK's row-major (C-order) frame buffer to the lab image layout: a `(height, width)` array with
`[y, x]` indexing and `[1, 1]` at the top left. See `docs/src/conventions.md` and lab decision 0040
(`conventions/image-layout.md` in the admiral repository).

An SDK hands back `height` rows of `stride` elements each, the first `width` of which are pixels. `stride` is the
row length in elements, `rowbytes` divided by the bytes per pixel; it exceeds `width` when the camera pads its
rows, and the padding is dropped. This is the one place a driver transposes a camera image: every driver calls it
once, on the buffer the SDK filled, and nothing downstream permutes the result.

```julia
rowmajor_to_yx(UInt16[11, 12, 13, 21, 22, 23], 3, 2)   # [11 12 13; 21 22 23], size (2, 3)
```
"""
function rowmajor_to_yx(buf::AbstractVector, width::Integer, height::Integer; stride::Integer = width)
    stride >= width ||
        throw(ArgumentError("stride ($stride) is less than width ($width)"))
    length(buf) >= stride * height ||
        throw(ArgumentError("buffer of $(length(buf)) elements is too short for $height rows of stride $stride"))
    rows = reshape(view(buf, 1:stride*height), Int(stride), Int(height))   # [x, y], padding included
    return permutedims(view(rows, 1:Int(width), :))
end
