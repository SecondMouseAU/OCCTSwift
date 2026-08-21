# #1030: the two datum readers that do not go through the shared lookup

`Scripts/repro/1022-datum-point-from-plane-array/` measures the kernel defect: `XCAFDoc_Datum::GetObject`
builds the datum point's X out of the annotation plane's array, so a datum carrying a point with no
plane location dereferences a null handle. This directory measures the **bridge** side of #1030,
specifically the part the issue did not know about.

## Two GD&T tables, not one

The issue scoped the guard to `occtDocumentDatumObjectAt`, the lookup seven bridge functions share.
That helper reads the tool this bridge attaches to `Main()` itself:

```objc
XCAFDoc_DimTolTool::Set(doc->doc->Main())     // the tool attribute lands on 0:1
```

Two other bridge functions reach `GetObject` without passing through it, and they read a **different
table**, the one `XCAFDoc_DocumentTool` owns and every importer writes:

| Bridge function | Swift surface | Reaches `GetObject` via |
|---|---|---|
| `OCCTDocumentDimTolToleranceCount` | `Document.dimTolToolToleranceCount` | `XCAFDimTolObjects_Tool::GetGeomTolerances` |
| `OCCTDocumentEditorRescaleGeometry` | `Document.rescaleGeometry(labelId:scaleFactor:forceIfNotRoot:)` | `XCAFDoc_Editor::RescaleGeometry` |

Both build their tool with `XCAFDoc_DocumentTool::DimTolTool(...)`
(`XCAFDimTolObjects_Tool.cxx:37`, `XCAFDoc_Editor.cxx:839`), which resolves to `0:1:4`.

The probe prints both facts in one line each. Its datum lands at `0:1:4:2`, and
`OCCTDocumentGetDatumCount`, which reads the `Main()` table, answers **0** for that same document.
So the two tables do not see each other, and a datum written by any other XCAF application is
invisible to `Document.datums` while still being read by these two functions. That divergence is a
separate defect from the crash and is filed on its own; this directory only records that the guard
has to cover both tables.

## Files

| File | What it is |
|---|---|
| `occt_1030_tool_table.mm` | The probe. Three sections selected by argv, because two of them take the process down when the guard is absent. |
| `run.sh` | Compiles it against the real bridge objects from `.build/` and runs each section in its own process. |
| `unguarded.txt` | Transcript with both tool-table guards deleted. |
| `guarded.txt` | Transcript as the tree stands. |

The probe calls the real bridge functions rather than reimplementing them: `run.sh` links
`occt_1030_tool_table.mm` against every `.o` in `.build/arm64-apple-macosx/debug/OCCTBridge.build/src`,
so it measures whatever `swift build` last produced. Run `OCCTSWIFT_LOCAL=1 swift build` first.

## Why this is not a Swift test

`Tests/OCCTXCAFTests/Issue1030DatumLookupGuardTests.swift` covers the shared lookup, because the
crashing shape is authorable there through `AssemblyNode.findChild(tag:create:)` plus
`initRealArray(lower:upper:)`. It cannot cover these two: putting a datum in the `XCAFDoc_DocumentTool`
table needs an `XCAFDoc_Datum` attribute, and attaching one is not on the bridge's label surface.
Hence a C++ probe, following `Scripts/repro/643-geomtools-null-write/`'s precedent of override-linking
the real bridge functions rather than asserting from a reimplementation.

## Measured

Both sections crash with the guards removed and are refused with them in place. The control is
byte-identical either way, which is what separates "the guard works" from "the guard refuses
everything".

| Section | Unguarded | Guarded |
|---|---|---|
| A, tolerance count, point and no plane | `Segmentation fault: 11`, exit 139 | `returned 0`, exit 0 |
| B, rescale geometry, point and no plane | `Segmentation fault: 11`, exit 139 | `returned 0`, exit 0 |
| C, control, plane and point | count `1`, rescale `1`, exit 0 | count `1`, rescale `1`, exit 0 |

Each function returns the value it already returns on failure, rather than a new sentinel: `0` for
the count and `false` for the rescale, matching #726.

## Retirement

The guard exists only because `Scripts/patches/0029-*` is in no built kernel. Retire it with the
release commit that pins a kernel carrying `0029`; `CLAUDE.md`'s #1022 entry carries that
obligation, and neither this probe nor the Swift suite can signal it, since both assert the refusal
and so pass either way.
