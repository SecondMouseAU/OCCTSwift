# #1392: a fixture BRepCheck_Solid flags

`OCCTCheckSolid` was implemented, declared and documented, and had no Swift caller, so nothing could
reach it. Wrapping it needed a solid that `BRepCheck_Solid` specifically rejects, as opposed to one
whose faces or edges are broken and which the existing `Shape.checkResult` path already catches.

`probe.mm` builds five candidates against the pinned kernel and prints, for each, the
`BRepCheck_Solid` status list and what `BRepCheck_Analyzer` says about the same shape.

```
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/1392-check-solid/probe.mm -o /tmp/occt_1392 && /tmp/occt_1392
```

Measured, OCCT 8.0.1 plus the carried patches:

| fixture | `BRepCheck_Solid` | `Analyzer::IsValid` |
|---|---|---|
| valid box | `NoError` | 1 |
| same shell added twice | `InvalidImbricationOfShells`, `EnclosedRegion` | 0 |
| single reversed shell | `NoError` | 1 |
| two disjoint shells in one solid | `EnclosedRegion`, `SubshapeNotInShape` | 0 |
| **small box fully inside a large one, both shells forward** | **`EnclosedRegion`** | 0 |

The last row is the fixture the test uses: one status, no ambiguity, and every face, edge, wire and
shell in it is individually valid, so it isolates the solid-level check.

Two results worth keeping rather than discarding:

- **A reversed shell is not an error.** `BRepCheck_Solid` returns `NoError` for a solid whose only
  shell is reversed, so "orientation is wrong" is not a way to build an invalid solid here.
- **Two disjoint lumps in one solid raise `SubshapeNotInShape` as well**, which reads as a
  structural complaint rather than the geometric one being tested, which is why it was not used.

The probe also answers the issue's second question. `BRepCheck_Analyzer::IsValid` is false for
every flagged fixture, but the status sits on the SOLID result, and `OCCTCheckShape` walked only
`TopAbs_FACE` and `TopAbs_EDGE`, so `errorCount` stayed 0 while `isValid` was false. That is fixed
in the same PR by walking `TopAbs_SHELL` and `TopAbs_SOLID` too.
