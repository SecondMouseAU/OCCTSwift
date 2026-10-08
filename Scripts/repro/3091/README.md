# 3091: the `gp_Cylinder`, `gp_Sphere` and `gp_Torus` overloads of `GProp_SelGProps` and `GProp_VelGProps`

Evidence for carried patch
[`0057`](../../patches/0057-GProp_SelGProps-GProp_VelGProps-cylinder-sphere-torus-inertia-3091.patch).
`Scripts/repro/3010-cone-inertia/` holds the `gp_Cone` half of the same two functions (patch `0055`),
which this builds on, and `Scripts/repro/2992/` the `dim` half of that.

| file | what it is |
|---|---|
| `probe.cxx` | the probe. Both classes on `gp_Cylinder`, `gp_Sphere` and `gp_Torus`, each compared with a Gauss-Legendre integral written in the file over the surface's own parameter space (24 nodes, a triple integral for the solid). It shares no formula with the kernel. Exits 1 if any check fails |
| `run.sh` | builds the probe twice (the two files recompiled with `0050`, `0051` and `0055` as the control, and the same with `0057` as the variant) and runs each. Exits 1 unless the control fails and the variant passes |
| `transcript.txt` | `run.sh`'s output |

## What it checks

Per case, in an untilted frame at the origin and in a tilted and translated frame: mass, centre of
mass, the matrix of inertia about the centre of mass (`MatrixOfInertia()`) compared entry by entry
with the integral, and `MomentOfInertia` about an oblique axis through (2, -1, 3) from a `loc` there.
Four ranges per shape (a full turn and three partial ones), the surface and the solid: 96 checks.

The control fails 96 of 96 and the variant passes 96 of 96, the largest deviation 1.1e-13. The
probe's first section reproduces the issue's number: the full cylinder surface, `R` = 5, height 10,
reads `314.159` about its axis in the control against `2 pi R^3 H = 7853.98`.

## The torus volume convention

The torus volume over part of the tube has no convention in OCCT. The probe integrates the solid
swept by the segment from the circle through the centres of the tube to the patch, which is what
makes a full range the whole solid torus, `2 pi^2 R r^2`, and matches the other overloads (solid
swept from the axis, or the centre, to the patch). It is the one decision in the patch.

## Reproducing

```bash
Scripts/repro/3091/run.sh        # from the repo root
```

Needs `Libraries/OCCT.xcframework` and `Libraries/occt-src`; `OCCT_SRC` and `OCCT_XC` override the
two paths. `-v` on a probe binary prints the matrices.
