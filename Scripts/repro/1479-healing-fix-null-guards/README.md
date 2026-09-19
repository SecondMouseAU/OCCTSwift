# #1479: `OCCTShapeFixComposeShell` / `OCCTShapeFixEdgeConnect` null guards

Both defects are uncatchable-crash gaps (an OS signal, not a C++ exception, so the surrounding
`catch (...)` cannot stop either): the crash therefore can't be reproduced inside `swift test`
itself. This directory holds the standalone before/after validation instead, following this
project's established pattern for guard fixes whose defect is a SIGSEGV rather than a value.

`repro_1479.mm` reproduces both functions' pre-fix and post-fix bodies verbatim (see the file's own
top-of-file comment for why it reimplements rather than override-links) and takes a mode argument
selecting which body/input pair to run, so each pairing is one process, one exit code.

## Compile

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/1479-healing-fix-null-guards/repro_1479.mm -o /tmp/repro_1479
```

## Run

```bash
for m in composeshell-buggy composeshell-fixed edgeconnect-buggy edgeconnect-fixed; do
  /tmp/repro_1479 "$m"; echo "$m -> exit $?"
done
```

## Measured result (macOS arm64, pinned `V8_0_1` + carried patches, 2026-09-02)

| mode                 | input                                          | result                          |
|-----------------------|-------------------------------------------------|----------------------------------|
| `composeshell-buggy`  | non-null wrapper, nullified `TopoDS_Shape`       | **SIGSEGV, exit 139**            |
| `composeshell-fixed`  | same input, `occtShapeIsPresent`-equivalent guard| clean exit 0, returns `nullptr`  |
| `edgeconnect-buggy`   | genuinely-null `OCCTShapeRef` pointer            | **SIGSEGV, exit 139**            |
| `edgeconnect-fixed`   | same input, `if (!shape) return nullptr;`        | clean exit 0, returns `nullptr`  |

Confirms both crashes reproduce on the pinned kernel exactly as the issue describes, and that the
one-line guards added in `OCCTBridge_Healing_Fix.mm` close both without a kernel change.
