# #3326: BRepGProp_Vinert by plane, 0 versus 500

The #2660 v5 transcript's `vinertPlaneZ=0` was real for the kernel it ran on and is wrong for the
pinned one. The cause is carried patch 0043 (#2827), pinned from `v4.0.0-kernel.3`.

Vanilla V8_0_1 `BRepGProp_Gauss::convert` kept the computed mass only under
`std::abs(theInertia.Mass) >= EPS_DIM && theIsByPoint`, so every by-plane call fell into the else
branch that sets the mass and the centre of mass to 0 (`Scripts/patches/0043-*.patch`). The
main-checkout `Libraries/OCCT.xcframework` the v5 agent used is dated 22 Sep (v4.0.0-kernel.1) and
lacks 0043. `transcript.txt` shows the same probe on that build and on kernel.2 (both 0), and on
kernel.6 (500, with the closed form and the sum equal to the volume).

Correction: the "kernel finding" in PR #2660 ("returned 0 for every face of the cube and for a whole
sphere against z = -10, where the analytic value is not 0") was a true observation of an unpatched
kernel, not a defect in the pinned one. Nothing needs patching. Main's by-plane tests in
`Tests/OCCTAnalysisTests/BRepGProp/BRepGPropVinertTests.swift` (#2827, #2873) already assert the
per-face sum equals the volume for three planes, the first-moment identity, and the planar closed
form, and they fail with "this kernel lacks patch 0043" against an older asset, so no test is added.
