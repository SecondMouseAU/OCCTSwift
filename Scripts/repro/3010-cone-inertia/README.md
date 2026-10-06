# 3010: the `gp_Cone` matrix of inertia of `GProp_SelGProps` and `GProp_VelGProps`

Evidence for carried patch
[`0055`](../../patches/0055-GProp_SelGProps-GProp_VelGProps-cone-matrix-of-inertia-3010.patch).
`Scripts/repro/2992/` holds the `dim` half of the same two functions (patches `0050` and `0051`),
which this builds on.

| file | what it is |
|---|---|
| `probe.cxx` | the probe. Both classes on `gp_Cone`, `gp_Cylinder` and `gp_Sphere`, each compared with a Gauss-Legendre integral written in the file over the surface's own parameter space (24 nodes, a triple integral for the solid). It shares no formula with the kernel. Exits 1 if any cone check fails |
| `run.sh` | builds the probe three ways (the archive alone, the two files recompiled with `0050` and `0051` as the control, and the same with `0055` as the variant) and runs each. Exits 1 unless the control fails and the variant passes |
| `transcript.txt` | `run.sh`'s output |

## What it checks

Per case, in an untilted frame at the origin and in a tilted and translated frame: mass, centre of
mass, the matrix of inertia about the centre of mass (`MatrixOfInertia()`) compared entry by entry
with the integral, and `MomentOfInertia` about an oblique axis through (2, -1, 3) from a `loc` there,
which exercises the `loc` handling. 16 cone cases give 64 checks.

The control fails 64 of 64 and the variant passes 64 of 64, the largest deviation 7.9e-14. The probe's
first section reproduces the issue's number: `Dm(3, 3)` of the surface at `a` = pi/6, `R` = 5,
`v` in [0, 10] reads `12753.276779771842` in the control against an integral of
`29452.431127404328`, a ratio of `0.43301270189221902`, which is `cos(pi/6) sin(pi/6)`. The
issue's closed form and the integral agree.

## What it does not fix

`gp_Cylinder` and `gp_Sphere` fail the same probe, 16 of 16, and are not touched by `0055`. The
probe prints them in their own section so the failure is on the record. For the cylinder
surface `Dm(3, 3)` is `Alpha2 - Alpha1` where the second moment about the axis has an `R^2` in it.

## Reproducing

```bash
Scripts/repro/3010-cone-inertia/run.sh        # from the repo root
```

Needs `Libraries/OCCT.xcframework` and `Libraries/occt-src`; `OCCT_SRC` and `OCCT_XC` override the
two paths. `-v` on a probe binary prints the matrices.
