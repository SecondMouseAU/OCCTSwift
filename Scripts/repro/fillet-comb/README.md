# Fillet and chamfer comb (branch fix/fillet-comb-chamfer, no PR)

Read `review/index.md` first: the one-page failure classes, the decisions waiting for the maintainer, and the chamfer parity set.

- `cprobe.cxx`, `build-probe.sh`: the raw-OCCT probe (one process per case); `swap-members.sh`: compile changed kernel units into a COPY of the macOS slice.
- `comb_oracle.py`: independent reference volumes (wedge unions, sphere corners, Pappus rims); `calibrate()` checks it against closed forms.
- `sweep.py`, `summarize.py`, `order_check.py`: the 1828-case sweep, the ranked class table, the edge-order check. `results/` holds the CSVs.
- `swift-harness/`, `crosscheck.py`: the same cases through the public API and the #3200 guard.
- `chamfer_cases.py`, `render_chamfer.py`: the 42 chamfer parity cases, the pivot and half-space references, the review images.
- Patch 0063 (candidate, #3300): `Scripts/patches/0063-*.patch`. Reading of a distance past its face: `-DBRepFilletAPI_CHAMFER_RUNOUT=0|1|2`.
  The GTests added to `BRepFilletAPI_MakeChamfer_Test.cxx` in the patch were not built (no OCCT GTest build here); the same cases
  were run through `cprobe` and fail on kernel.6, pass with 0063.
