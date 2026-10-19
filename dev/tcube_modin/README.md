# TLD001 MOD IN experiments (2026-10-19)

Raw Kinesis + DAQmx.jl scripts, deliberately not the MicroscopeControl driver (the driver adds the
modulation level to every USB write, so a test through it measures the driver). Laser under test:
TCube 64865766 (new 642 nm). MOD IN on Dev2/ao1 (USB-6008, 0-5 V, software-timed); external PD on
Dev2/ai0-ai4 (differential). Rig values are in `lib.jl` constants for this one-off bench run only.

- `lib.jl`: raw calls, safety (caps, current trip, `with_session` always ends 0 V / setpoint 0 / output off /
  control source and loop mode restored; `LD_PersistSettings` is not bound).
- Runs: `inventory`, `li_curve`, `ao_probe`, `range_check`, `tia_gain`, `ai_scan`, `xpd_cal`, `modscale`,
  `registers` (runs 1, 3, 4), `settle` (run 2), `speed`. Offline: `settle_windows`, `speed_traces`, `report`.
- `repl/`: the wrappers that ran them in the workspace's persistent REPL, from `dev/output/repl/`
  (their relative paths assume that location). Results: `dev/output/tcube-modin/` (gitignored) and the NAS,
  `T:\projects\smart-microscope\data\tcube_power\modin\2026-10-19\` (report.html there).

Environment: `julia --project=dev/tcube_modin` (DAQmx.jl dev'd from `~/.julia/dev/DAQmx.jl`, HDF5).
