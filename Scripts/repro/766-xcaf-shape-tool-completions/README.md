# `XCAFDoc_ShapeTool` completion methods, ground truth

What the nine `XCAFDoc_ShapeTool` entry points behind `Document.shapeTool*` return for the input
`Tests/OCCTXCAFTests/ShapeToolCompletionsTests.swift` uses: a 10x10x10 box centred on the origin,
added to a fresh `MDTV-XCAF` document with `AddShape(shape, makeAssembly = true)`, which is what
`Document.addShape` does by default.

`probe.mm` calls the kernel directly, with no bridge and no Swift in the path. `transcript.txt` is
its output.

## Build and run

```bash
XC=Libraries/OCCT.xcframework/macos-arm64      # or .build/artifacts/<pkg>/OCCT/OCCT.xcframework/macos-arm64
clang++ -std=c++17 -ObjC++ -w \
  -I"$XC/Headers" -L"$XC" -lOCCT-macos \
  -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/766-xcaf-shape-tool-completions/probe.mm -o /tmp/occt_probe_766
/tmp/occt_probe_766 | diff - Scripts/repro/766-xcaf-shape-tool-completions/transcript.txt
```

Reproduced byte-identically on 2026-09-28 against the pinned `v4.0.0-kernel.2` asset that SwiftPM
resolves, which is the kernel CI tests against. All nine `XCAFDoc_ShapeTool` symbols the probe
calls resolve in `libOCCT-macos.a`.

## What it measures

```
IsFree=true IsSimpleShape=true IsComponent=false IsCompound=false IsSubShape=false IsExternRef=false
GetUsers=0 NbComponents=0
ComputeShapes returned; IsFree still=true
```

Six values are `false` or `0`, and that is the point of recording them here rather than trusting
the test suite. Every one of these bridge functions in `OCCTBridge_Modeling_Misc.mm` answers `false`
or `0` on a label it cannot resolve, so a test asserting one of those six proves nothing on its own
about the kernel: it is satisfied by a label that does not exist. The suite's fixture therefore
proves the label exists and holds the box, through `OCCTDocumentFindShape`, before asserting any of
them.

`ComputeShapes` returns `void`, and the bridge wrapper returns `void`, so the only observable is the
document state after the call. The third line is that observable, and it is what the suite asserts.

## Provenance

The probe and this transcript come from PR #2486, which is otherwise rejected: its nine
kernel-parity rows certified nine tests that could not fail, and one round of review resolved a
genuine bridge-versus-kernel mismatch by deleting the kernel's extra measurement rather than
reconciling it (commit `aed802ca`). The evidence here stands on its own; the certification did not.
#2794 records what that cost and what to reject in review next time.

Review on PR #2800 trimmed the probe: two unused `TCollection_*` includes, an unused `TDF_Tool.hxx`,
an unused `TDF_LabelSequence comps` local and a `tagLabel` helper nothing called. None of them reach
the measurement, and the trimmed probe reproduces `transcript.txt` byte-identically against the same
pinned `v4.0.0-kernel.2` asset. So it is #2486's probe minus dead code, not #2486's file byte for
byte; the three lines it prints are unchanged.
