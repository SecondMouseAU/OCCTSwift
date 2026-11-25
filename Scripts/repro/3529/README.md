# OCCTSwift#3529 ground truth: a STEP file that starts with a UTF-8 byte order mark

`Document.load(from:)` throws on a STEP file whose first three bytes are `EF BB BF`. The kernel prints
`ERR StepFile : Undefined Parsing: Line 2: Incorrect syntax: unexpected QUID, expecting STEP`, and
the same file without the three bytes loads.

`occt_3529_step_bom.mm` writes a 10 x 20 x 30 box, writes a copy with the mark in front, and reads
both with `STEPControl_Reader` and `STEPCAFControl_Reader`. `probe-output.txt` is its output on the
pinned kernel (OCCT V8_0_2 plus the carried patches, `macos-arm64`).

## Compile and run

```bash
XC=Libraries/OCCT.xcframework      # or .build/artifacts/<package>/OCCT/OCCT.xcframework
clang++ -std=c++17 -ObjC++ -w -I"$XC/macos-arm64/Headers" -L"$XC/macos-arm64" -lOCCT-macos \
  -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/3529/occt_3529_step_bom.mm -o /tmp/occt_3529
/tmp/occt_3529
```

## What it shows

| read | `STEPControl_Reader` | `STEPCAFControl_Reader` |
|---|---|---|
| `ReadFile`, no mark (control) | `RetDone`, 1 root, volume 6000 | `RetDone`, transfer ok, 1 free shape |
| `ReadFile`, with the mark | `RetFail` | `RetFail` |
| `ReadStream`, mark skipped | `RetDone`, 1 root, volume 6000 | `RetDone`, transfer ok, 1 free shape |
| `ReadStream`, mark NOT skipped | `RetFail` | `RetFail` |

The last row is the one that says why: the stream path is not what changes the answer, the three
skipped bytes are. A `ReadStream` that starts at the mark fails exactly as `ReadFile` does.

## What OCCT offers, and what the bridge does with it

`ReadFile` opens the file with `OSD_FileSystem::DefaultFileSystem()->OpenIStream(name, in | binary)`
and scans the stream (`StepSelect_WorkLibrary.cxx:63` into `StepFile_Read.cxx:77-89`, scan at
`:105-108`). `ReadStream(name, stream)` is the same read with the stream given by the caller
(`StepSelect_WorkLibrary.cxx:78`), and both readers have it. The scanner is a flex/bison grammar
that starts at `ISO-10303-21;` and has no rule for a mark.

So the bridge opens the file the way `ReadFile` does, reads the first three bytes, and hands the
stream to `ReadStream` positioned after them when they are `EF BB BF`. Any other file goes through
`ReadFile` unchanged: the check is three bytes of a second open, and nothing that loaded before reads
differently. The decision lives in one function, `occtStepReadFile` in `OCCTBridge_Internal.h`, and
all fifteen STEP readers in `OCCTBridge_IO_StepFormat.mm` and `OCCTBridge_Document_DocumentLifecycle.mm`
go through it: `OCCTImportSTEP`, `OCCTImportSTEPRobust`, `OCCTImportSTEPWithUnit`,
`OCCTImportSTEPRoot` and `OCCTImportSTEPWithDiagnostics` and their `Progress` forms,
`OCCTSTEPReaderNbRoots`, `OCCTSTEPReaderNbShapes`, `OCCTStepTidyOptimize`, and the four document
loaders (`OCCTDocumentLoadSTEP`, `OCCTDocumentLoadSTEPProgress`, `OCCTDocumentLoadSTEPWithModes`,
`OCCTDocumentLoadSTEPWithModesProgress`). So `Document.load`, `Document.loadSTEP` in each spelling,
`Shape.load` and `Shape.loadSTEP` all read a marked file.

Only a UTF-8 mark is skipped, and only one. OCCT does not read UTF-16 or UTF-32 STEP, so a UTF-16
mark stays refused, and a second mark is as much a syntax error as the first was.
