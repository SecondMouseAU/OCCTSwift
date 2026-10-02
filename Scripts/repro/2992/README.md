# 2992: both `gp_Cone` overloads of `GProp_SelGProps` and `GProp_VelGProps`

Evidence for carried patches
[`0050`](../../patches/0050-GProp_SelGProps-cone-lateral-area-drops-cos-semiangle-2992.patch) and
[`0051`](../../patches/0051-GProp_VelGProps-cone-volume-is-the-frustum-2992.patch).
`Scripts/repro/766-gpropcylcone/` holds the original finding; this directory holds the
re-derivation and the before/after measurement of the fix.

| file | what it is |
|---|---|
| `derivation-check.py` | the closed forms, re-derived and evaluated against the kernel's own expressions in exact arithmetic. Pure Python, no OCCT, runs in a second |
| `probe.cxx` | the kernel probe: both classes on `gp_Cone(gp::XOY(), pi/6, 5)` over `u in [0, 2 pi]`, `v in [0, 10]`, plus the cylinder and three near-cylinder cones |
| `override-link-transcript.txt` | `probe.cxx` run twice, with the unpatched and then the patched translation units override-linked ahead of the pinned `libOCCT-macos.a` |
| `slice-compile-transcript.txt` | `GProp_SelGProps.cxx`, `GProp_VelGProps.cxx` and `Geom_BezierSurface.cxx` compiled on `macos-arm64`, `ios-arm64` and `ios-arm64-simulator` against each slice's own headers, with the patched `Geom_BezierSurface.hxx` first on the include path for `0052` |

## The two arbiters, and why they are the arbiters

Neither class has a caller anywhere in `Libraries/occt-src`:

```bash
grep -rn 'GProp_SelGProps\|GProp_VelGProps' --include=*.cxx --include=*.hxx Libraries/occt-src/src
```

returns only their own definitions. Per
[`okf/policies/follow-occt-callers.md`](../../../okf/policies/follow-occt-callers.md) there is no
call site whose use of the result could settle what the result means, so the "when OCCT does not
answer" branch applies and the arbiters are:

1. **the closed form**, derived from `gp_Cone`'s own parametrisation
   `P(u, v) = Loc + (R + v sin a)(cos u X + sin u Y) + v cos a Z`; and
2. **the cylinder limit**, because a cone of vanishing semi-angle is the cylinder that the same two
   classes both answer exactly, and `gp_Cone` refuses `semiAngle = 0` so the limit is approached
   rather than taken.

Both are in `derivation-check.py` and both are measured in `override-link-transcript.txt`.

## Reproducing

```bash
python3 Scripts/repro/2992/derivation-check.py

XC=Libraries/OCCT.xcframework/macos-arm64
clang++ -std=c++17 -O2 -I"$XC/Headers" -c Scripts/repro/2992/probe.cxx -o /tmp/probe.o
clang++ -std=c++17 -O2 -I"$XC/Headers" -c Libraries/occt-src/src/ModelingData/TKGeomBase/GProp/GProp_SelGProps.cxx -o /tmp/sel.o
clang++ -std=c++17 -O2 -I"$XC/Headers" -c Libraries/occt-src/src/ModelingData/TKGeomBase/GProp/GProp_VelGProps.cxx -o /tmp/vel.o
clang++ -std=c++17 -O2 /tmp/sel.o /tmp/vel.o /tmp/probe.o \
  -L"$XC" -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ -o /tmp/run && /tmp/run
```

Run that with `Libraries/occt-src` unpatched for the "before" column and with `0050`/`0051`
applied for the "after" column. The unpatched override-linked run is byte-identical to the archive
alone, which is how the pinned asset is known to carry no fix of its own here.

## Result

| quantity | before | after | closed form |
|---|---|---|---|
| cone lateral area | `408.10485695269909` | `471.23889803846896` | `471.23889803846896` |
| cone frustum volume | `2040.524284763495` | `1587.0744437049409` | `1587.0744437049404` |
| area centre of mass | `(0, 0, 4.81125224325)` | identical | unchanged by either patch |

Cylinder limit, against the cylinder's own `314.15926535897933` and `785.39816339744823`:

| semiAngle | area before | area after | volume before | volume after |
|---|---|---|---|---|
| `1e-3` | `314.47326733528` | `314.47342457198` | `3.14473214923` | `786.96961317468` |
| `1e-6` | `314.15957951809` | `314.15957951824` | `0.00314159580` | `785.39973419443` |
| `1e-9` | `314.15926567314` | `314.15926567314` | `0.00000314159` | `785.39816496824` |

The area converged before and after, because its defect is a factor of `cos a` which goes to 1.
The volume converged on **zero** before and on the cylinder after. The residuals at `1e-9` are the
closed-form first-order terms, `pi h^2 sin a` and `pi R h^2 sin a`, not error.

## The inertia terms are a separate, unfixed defect

Found while re-deriving the two above, measured, and deliberately out of scope for both patches.
`GProp_SelGProps`' `Dm(3, 3)` is `cos a sin a` times the second moment about the axis
(`12753.276779771842` against `29452.43112740431`), `IZ2` is wrong in a third way, and
`GProp_VelGProps`' `IR2` integrates a four-term quartic over 4 where the volume moment is a
five-term quartic over 20. `derivation-check.py` prints the `Dm(3, 3)` comparison. Nothing in the
bridge reads any of it. Filed as
[#3010](https://github.com/SecondMouseAU/OCCTSwift/issues/3010).
