# Image layout

The lab's one convention for camera images, simulated images and every array that stands for an image is lab
decision 0040 (`conventions/image-layout.md` in the admiral repository). MicroscopeControl restates it here, in the
docstrings of the functions that take or return an image, and in `CLAUDE.md`.

## The rule

- **An image is an array, shown the way the array prints.** The first dimension is y (rows, increasing downward),
  the second is x (columns, increasing rightward), then frame: a stack is `(ny, nx, nframes)` and a camera map
  (offset, variance, gain, QE) is `(ny, nx)`. `[1, 1]` is the top-left pixel, so `data[row, col] == data[y, x]`.
- **The only transposes are at a device boundary.**
  - *Camera in:* an SDK delivers a row-major (C-order) buffer, and the driver converts it once, immediately, with
    `CameraInterface.rowmajor_to_yx(buf, width, height; stride)`. Every driver (`DCAM4Camera`, `ThorcamDCXCamera`,
    `ThorCamCSCCamera`) calls it, and `SimCamera` builds `(roi.height, roi.width)` arrays directly. `stride` is
    the SDK's row length in elements; it exceeds `width` when the camera pads its rows, and the padding is dropped.
  - *Display out:* Makie's `image` and `heatmap` put the first index on the horizontal axis, so a display shows
    `permutedims` of the array on a `yreversed` axis:

    ```julia
    image(permutedims(frame); axis=(yreversed=true,))
    heatmap(permutedims(frame); axis=(yreversed=true,))
    ```

  - *Devices out* that need another order (an SLM pattern, for example) convert at the call into the device.

  Nothing else transposes, permutes or reverses an image array.
- **Files store the array as it is.** `save_h5` writes the Julia array without permuting. In Julia and MATLAB terms
  the dataset on disk is `(y, x, frame)`; C-order tools (h5py, h5dump) list the same dimensions reversed. Every image
  dataset (any `data` of two or more dimensions) carries
  `dimension_order = "y,x"` or `"y,x,frame"` and
  `dimension_order_convention = "column-major (Julia/MATLAB); C-order tools list it reversed"`, plus the older
  `dimension_labels` and `memory_layout`.
- **Tests use non-square images with known content**, so a swapped axis fails.

## Files written before this convention

Between 2026-01-29 and the release carrying this change, `save_h5` wrote `dimension_order = "HW"` or `"HWN"`. The
data was already `(y, x[, frame])`, unpermuted, so only the attribute's spelling differs. MicroscopeControl has no
reader of its own; a reader elsewhere should keep accepting `"HW"` and `"HWN"` as `"y,x"` and `"y,x,frame"`.

Files written by MicroscopeControl before 2026-01-29 hold `[x, y]` and carry no `dimension_order`; their reader
recognizes the missing attribute and converts data and maps together, once, at load.

## Functions

```@docs
MicroscopeControl.HardwareInterfaces.CameraInterface.rowmajor_to_yx
```
