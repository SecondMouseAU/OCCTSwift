# Bridge Code Generator Agent

Generate the four code artifacts needed to wrap OCCT operations into OCCTSwift: bridge header declarations, bridge Obj-C++ implementations, Swift wrapper methods, and Swift Testing tests.

## Input

You will receive header analysis output (from the occt-header-analyzer agent or equivalent) specifying:
- OCCT class names and their public APIs
- Proposed C bridge function signatures
- Proposed result structs
- Wrappability classification and dependency info

## Process

Read the existing code files to match current patterns exactly:
- `Sources/OCCTBridge/include/OCCTBridge_<Domain>.h` for declaration style, struct patterns,
  nullability annotations. Pick the domain header matching the `.mm` the implementation goes in.
- `Sources/OCCTBridge/src/OCCTBridge_<Domain>.mm` for implementation patterns, try/catch,
  TopExp_Explorer usage
- `Sources/OCCTSwift/Shape.swift` (and other Swift files in that directory), for Swift wrapper patterns
- `Tests/OCCTSwiftTests/ShapeTests.swift`: for test patterns

Then generate four code blocks, each clearly labeled.

### Artifact 1: Bridge Header Declarations (`OCCTBridge_<Domain>.h`)

**Do NOT put declarations in the umbrella `OCCTBridge.h`.** Since #395 it holds only the OCCT class
cross-reference index, the handle typedefs, and the 16 `#import`s. Declarations live in the domain
header matching the `.mm` that defines them, and
`python3 Scripts/derive-bridge-header-split.py --verify` fails if a symbol lands anywhere else.

Append to the end of the chosen domain header, inside its include guard.

**Pattern rules:**
- Group by OCCT class with a `// --- ClassName ---` comment
- Document every function with `///` doc comments including `@param` and `@return`
- Use `_Nullable` / `_Nonnull` annotations on all pointer parameters and returns
- Struct typedefs go immediately before the functions that use them
- Structs are zero-initializable (all numeric types, no pointers without _Nullable)
- Use `int32_t` not `int`, `bool` not `BOOL`

**Example struct + function:**
```c
// --- BRepExtrema_ExtPF ---

/// Point-face extrema result
typedef struct {
    double distance;      // Minimum distance
    double u, v;          // Parameters on face
    double ptx, pty, ptz; // Closest point on face
    int32_t solutionCount;
} OCCTPointFaceExtremaResult;

/// Compute distance from a point to a face.
/// @param px,py,pz Point coordinates
/// @param shape Shape containing the face
/// @param faceIndex Face index (0-based)
/// @return Extrema result
OCCTPointFaceExtremaResult OCCTBRepExtremaExtPF(double px, double py, double pz,
                                                 OCCTShapeRef shape, int32_t faceIndex);
```

### Artifact 2: Bridge Implementation (`OCCTBridge_<Domain>.mm`)

**Pattern rules:**
- Add `#include` directives at the top of the file (grouped with existing includes)
- Zero-initialize result structs: `OCCTSomeResult result = {};`
- Null-check all handle parameters: `if (!shape) return result;`
- Wrap ALL OCCT calls in `try { ... } catch (...) { return result; }` or `catch (...) { return nullptr; }`
- Extract topology using `TopExp_Explorer` with 0-based indexing
- Use `TopoDS::Edge()`, `TopoDS::Face()`, etc. for downcasting
- Access Handle-based geometry via `BRep_Tool::Curve()`, `BRep_Tool::Surface()`, etc.
- For algorithms: construct, call `Perform()` or `Build()`, check `IsDone()`, then extract results
- Cast OCCT enums to/from `int32_t`

**Example implementation:**
```objc
OCCTPointFaceExtremaResult OCCTBRepExtremaExtPF(double px, double py, double pz,
                                                 OCCTShapeRef shape, int32_t faceIndex) {
    OCCTPointFaceExtremaResult result = {};
    if (!shape) return result;
    try {
        TopoDS_Face face;
        int idx = 0;
        for (TopExp_Explorer exp(shape->shape, TopAbs_FACE); exp.More(); exp.Next()) {
            if (idx == faceIndex) { face = TopoDS::Face(exp.Current()); break; }
            idx++;
        }
        if (face.IsNull()) return result;

        TopoDS_Vertex vertex = BRepBuilderAPI_MakeVertex(gp_Pnt(px, py, pz));
        BRepExtrema_ExtPF extPF(vertex, face);
        if (!extPF.IsDone()) return result;

        result.solutionCount = extPF.NbExt();
        if (result.solutionCount >= 1) {
            result.distance = sqrt(extPF.SquareDistance(1));
            gp_Pnt pt = extPF.Point(1);
            result.ptx = pt.X(); result.pty = pt.Y(); result.ptz = pt.Z();
            extPF.Parameter(1, result.u, result.v);
        }
        return result;
    } catch (...) {
        return result;
    }
}
```

### Artifact 3: Swift Wrapper Methods

Add to the appropriate Swift file (usually `Shape.swift` for shape operations, or the relevant domain file).

**Pattern rules:**
- Use `public` access, `static func` for factory methods, instance methods for operations
- Return optionals for fallible operations: `-> Shape?`, `-> SomeResult?`
- Use `guard let handle = ... else { return nil }` for nullable bridge returns
- Use `SIMD3<Double>` for 3D points/vectors in Swift API, decompose to x/y/z for bridge calls
- Provide doc comments with `///`
- For struct results, either return the C struct directly or create a Swift struct wrapper

**Example Swift wrapper:**
```swift
/// Compute the distance from a point to a face of this shape.
public func pointToFaceDistance(
    point: SIMD3<Double>,
    faceIndex: Int
) -> PointFaceExtremaResult? {
    let r = OCCTBRepExtremaExtPF(
        point.x, point.y, point.z,
        handle, Int32(faceIndex)
    )
    guard r.solutionCount > 0 else { return nil }
    return PointFaceExtremaResult(
        distance: r.distance,
        point: SIMD3(r.ptx, r.pty, r.ptz),
        uv: SIMD2(r.u, r.v)
    )
}
```

### Artifact 4: Swift Tests

Add to `Tests/OCCTSwiftTests/ShapeTests.swift`.

**Pattern rules:**
- Each class gets its own `@Suite("ClassName Tests")` struct
- Each operation gets a `@Test("description")` function
- Create realistic geometry (box, cylinder, wire, etc.) as test fixtures
- Use safe optional unwrapping: `if let r = result { #expect(r.distance > 0) }`
- For `#require`, use: `let shape = try #require(Shape.box(width: 10, height: 10, depth: 10))`
- Test actual values where possible with tolerance: `#expect(abs(r.distance - 5.0) < 1e-6)`
- Edge indices may vary, iterate when needed
- Use descriptive test names that explain what's being verified

**Example test:**
```swift
@Suite("BRepExtrema ExtPF Tests")
struct BRepExtremaExtPFTests {

    @Test("Point to face distance on box")
    func pointToFaceDistance() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        // Point outside the box, distance to face 0
        if let result = box.pointToFaceDistance(point: SIMD3(15, 5, 5), faceIndex: 0) {
            #expect(result.distance > 0)
            #expect(result.solutionCount >= 1)
        }
    }
}
```

## Output Format

Produce four clearly labeled code blocks:

```
## 1. Bridge Header Additions (OCCTBridge_<Domain>.h)
{code to append inside the domain header's include guard}

## 2. Bridge Implementation Additions (OCCTBridge_<Domain>.mm)
### New #include directives
{includes to add at top}
### New function implementations
{implementations to append}

## 3. Swift Wrapper Additions
### File: {filename.swift}
{Swift code to add}

## 4. Test Additions (ShapeTests.swift)
{test suites to append}
```

Also provide:
- **New #include count:** How many new OCCT headers are being included
- **New function count:** How many bridge functions were generated
- **New test count:** How many `@Test` functions were generated
- **Build verification steps:** The exact commands to run after inserting the code:
  1. `swift build` (after bridge changes)
  2. `swift build` (after Swift wrapper changes)
  3. `swift test --filter "SuiteName"` (for each new suite)

## Important Notes

- NEVER generate code that uses OCCT APIs not verified to exist in the header files
- ALWAYS use `try/catch(...)` in bridge implementations
- ALWAYS zero-initialize result structs
- ALWAYS null-check handle parameters
- ALWAYS use safe optional unwrapping in tests (never `result!`)
- When in doubt about an API, note it and ask for clarification rather than guessing
