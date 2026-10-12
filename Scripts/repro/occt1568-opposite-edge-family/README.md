# Opposite-edge fillet family (OCCT#1568, OCCT#1177): the IR series and its evidence

Investigation and candidate only. Nothing is posted upstream and no PR is open. Read `review/index.md` first.

- `upstream/0001..0005-*.patch`: the series against upstream `IR` (`23d68aeb9`), `git format-patch` output. The branch is
  `integration/ir-fillet-1568` in the OCCT checkout `upstream/occt` (worktree `/Users/elb/Projects/worktrees/occt-ir-fillet-1568`).
- `review/`: images, decision figures Q1 to Q6, the model of #1568, the 715-case batteries, `validate.tsv`, and `drafts/`
  (the PR description, the FreeCAD#25289 comment, the Discussion note).
- Probes, all raw OCCT, one process per case (an uncatchable SIGSEGV is the original defect):
  `fprobe.cxx` (box fillets), `brepfillet.cxx` (DRAW-numbered edges of a BREP), `meshdump.cxx` (render input),
  `battery.py`, `sweep.py`, `validate.py`, `oracle.py`, `fuzz.py`, `render.py`, `render_model.py`, `render_alternatives.py`.
- Build against a CMake build of IR (Release, shared): compile a probe with `-I<build>/include/opencascade`, link
  `-L<build>/mac64/clang/lib -lTKernel -lTKMath -lTKG2d -lTKG3d -lTKGeomBase -lTKBRep -lTKGeomAlgo -lTKTopAlgo -lTKPrim
  -lTKBO -lTKBool -lTKShHealing -lTKFillet -lTKMesh -lTKOffset`. To compare two states of TKFillet, copy
  `libTKFillet*.dylib` into a directory per state and run with `DYLD_LIBRARY_PATH` pointing at it. Against the released
  kernel: `-I Libraries/OCCT.xcframework/macos-arm64/Headers -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++`.
- The pinned kernel (8.0.1 plus carried patches) refuses everything the series builds. Its candidates are 0054 and 0059
  (on main) and 0060 (branch `fix/fillet-pivot-edges`); the IR commits that repair IR's own regression (2 and 5) do not apply
  to it. No new patch number.
