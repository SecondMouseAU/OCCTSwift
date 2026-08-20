# #1008: what `TopoDS::Edge` actually does with a non-edge, and with a null shape

`OCCTMakeWireFromEdges` (`OCCTBridge_Topology.mm`, behind `Shape.wireFromEdges(_:)`) and
`OCCTMakeShell` (behind `Shape.shellFromFaces(_:)`) cast every caller-supplied element with
`TopoDS::Edge` / `TopoDS::Face` and hand the result straight to a builder, with no type test.

The issue was filed on the reading that this is a silent `reinterpret_cast`, because
`TopoDS::Edge`'s guard is a macro and `Standard_TypeMismatch.hxx` gates it on
`#if !defined No_Exception && !defined No_Standard_TypeMismatch`. **Measured, that half is wrong,
and a different half is right.** Both are recorded here rather than only the conclusion, because
the wrong half is the one the next reader will arrive with.

## `No_Exception` is not defined in a bridge translation unit

The macro expands in the **caller's** TU, so whether the guard exists is a property of how
`OCCTBridge` is compiled, not of how the kernel archive was built. OCCT's own CMake defines
`No_Exception` for its Release build (`BUILD_RELEASE_DISABLE_EXCEPTIONS`, default ON), which is why
no precondition inside a kernel `.cxx` is load-bearing here (#487). Nothing defines it for the
bridge: `Package.swift`'s `cxxSettings` carry `OCCT_AVAILABLE` and `OCCT_NO_DEPRECATED` and nothing
else, and the real compile line SwiftPM emits for `OCCTBridge_Topology.mm` is

```
-DDEBUG=1 -DOCCT_AVAILABLE=1 -DOCCT_NO_DEPRECATED -DSWIFT_PACKAGE=1
```

with no `No_Exception` anywhere. No header defines it either. This is #514's finding restated for a
different class: a `gce_*` call compiled inside OCCT has no precondition, a header-inline
construction in a `.mm` does.

## The wrong-typed element is refused twice, on every build

`probe-output.txt` is the default run. `probe-output-no-exception.txt` is the same probe compiled
with `-DNo_Exception`, which is the world the issue describes.

| input | as compiled | with `-DNo_Exception` | with the guard |
|---|---|---|---|
| edge | accepted | accepted | accepted |
| wire, 4 edges | refused, `TopoDS::Edge` | refused, `TopoDS_Builder::Add` | refused |
| face | refused, `TopoDS::Edge` | refused, `TopoDS_Builder::Add` | refused |
| solid | refused, `TopoDS::Edge` | refused, `TopoDS_Builder::Add` | refused |
| vertex | refused, `TopoDS::Edge` | refused, `TopoDS_Builder::Add` | refused |
| compound holding one edge | refused, `TopoDS::Edge` | refused, `TopoDS_Builder::Add` | refused |
| **null shape** | **SIGSEGV** | **SIGSEGV** | refused |

Compiling the type check out does not produce a wrong answer, it produces a refusal one level
further down. `TopoDS_Builder::Add` (`TopoDS_Builder.cxx:96`) tests the component's `ShapeType()`
against a compatibility table and finishes with a bare `throw TopoDS_UnCompatibleShapes(...)`. That
is an unconditional `throw`, not a `*_Raise_if`, so no macro can remove it. The wrong-typed case was
never reachable as a silent reinterpret_cast.

## The null shape is refused by neither, and it is reachable from Swift

`TopoDS::Edge`'s guard reads

```cpp
Standard_TypeMismatch_Raise_if(theShape.IsNull() ? false : theShape.ShapeType() != TopAbs_EDGE,
                               "TopoDS::Edge");
```

so a null shape is passed through deliberately, on every build. `TopoDS_Shape::ShapeType()` is
`myTShape->ShapeType()` (`TopoDS_Shape.hxx:140`) with no null test, so `TopoDS_Builder::Add`'s own
table lookup dereferences a null handle. That is an OS signal, and the `catch (...)` around each of
these functions cannot absorb it.

`Shape.nullified` (`Shape+Topology.swift`, backed by `OCCTShapeNullified`) is a public property that
returns a `Shape` wrapping a null `TopoDS_Shape` by construction. So

```swift
let box = Shape.box(width: 10, height: 10, depth: 10)!
_ = Shape.wireFromEdges([box.nullified!])   // SIGSEGV before the fix
```

is public API to public API, and `swift test --filter Issue1008WireFromEdgesTypeGuard` against the
unfixed bridge dies with `exited with unexpected signal code 11` before any of its six tests
reports.

The same null shape crashes a much wider family that reads `ShapeType()` directly, with no cast
involved, behind `Shape.shapeType`, `Shape.isSolid`, `Shape.typeName` and six more. That is filed
separately as [#1026](https://github.com/SecondMouseAU/OCCTSwift/issues/1026), and
`shapetype_census.py` here is the script that produced its count.

**That count was wrong, and the script is the reason.** It was filed as fifteen bridge functions
across four files. Its guard test was `'IsNull()' not in body`, which accepts an `IsNull()` on any
subject at all, and it had no `--self-test` to catch that; it was additionally blind to a function
declared `extern "C"` on its own line and to a shape read through a local copy or a reference
binding. Corrected and given a fixture battery under #1026, the same criterion reports **29
functions across seven files**, and the whole class #1026 closes is 42. The script's own docstring
carries the correction, the three blindnesses and the removal matrix; `census_matrix.py` beside it
reproduces the matrix.

## The sibling sweep

345 sites across the bridge cast a caller-supplied shape (`<name>->shape`) with one of
`TopoDS::Vertex/Edge/Wire/Face/Shell/Solid/CompSolid/Compound`. **All 345 sit inside a `try`, and
every `catch` in `Sources/OCCTBridge/src/*.mm` is `catch (...)`**, so none of them can leak a
`Standard_TypeMismatch` across the bridge boundary into Swift frames, which would be the #345
`std::terminate` shape. The two fixed here are the two that hand the cast straight to a builder that
reads `ShapeType()` off it.

```bash
python3 Scripts/repro/1008-topods-cast-guard/sweep.py Sources/OCCTBridge/src
python3 Scripts/repro/1008-topods-cast-guard/sweep.py --self-test
```

The sweep's tracker was wrong twice before it was right, in opposite directions, and both versions
reported a clean tree. `sweep.py`'s own docstring carries the removal matrix, including the three
rows that come back green and why none of them is claimed as coverage.

## Build

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/1008-topods-cast-guard/occt_1008_topods_cast.mm -o /tmp/occt_1008
/tmp/occt_1008

# and the same file with the type check compiled out
clang++ ... -DNo_Exception ... -o /tmp/occt_1008_ne
/tmp/occt_1008_ne
```

Each case runs in a forked child, so a crash is reported with its signal rather than ending the
probe. Exit code is the number of crashing cases clamped to 0/1.
