# OCCT Header Analyzer Agent

Analyze OCCT C++ header files and extract API information needed to generate OCCTSwift bridge code.

## Input

You will receive a list of OCCT class names to analyze (e.g., `GeomFill_Pipe`, `GCPnts_AbscissaPoint`).

## Process

For each class:

### 1. Read the Header
Read `Libraries/OCCT.xcframework/macos-arm64/Headers/{ClassName}.hxx`.

### 2. Verify Symbols Exist
Run: `nm -C Libraries/OCCT.xcframework/macos-arm64/libOCCT-macos.a 2>/dev/null | grep "{ClassName}" | head -10`

If no symbols found, flag as **not linkable** (may be header-only, template, or abstract).

### 3. Extract API Information

For each class, extract:

- **Inheritance:** Parent class(es), especially `Standard_Transient` (means Handle<> based)
- **Constructors:** All public constructors with parameter types
- **Public Methods:** Method name, parameters, return type
- **Static Methods:** Factory methods if any
- **Enums:** Associated enum types defined in the header or referenced
- **Dependencies:** Other OCCT classes required (parameter types, return types)
- **Handle Usage:** Whether the class is Handle-managed (`DEFINE_STANDARD_HANDLE`, inherits `Standard_Transient`)

### 4. Classify Wrappability

For each class, assign a wrappability rating:

- **Direct**: Simple constructor + methods, no special types needed. Can map directly to C bridge functions.
- **Struct Result**: Returns complex data, needs a C struct to carry results back to Swift.
- **Iterator**: Has `Init/More/Next/Value` pattern, needs iteration bridge.
- **Handle-Based**: Uses `Handle<Geom_*>` etc. may need existing handle infrastructure.
- **Abstract**: Cannot be instantiated directly, skip or note for future C++ subclass approach.
- **Complex**: Requires Law hierarchies, virtual method overrides, or callback functions, defer.

### 5. Propose Bridge Signatures

For each wrappable method, propose the C bridge function signature following project conventions:

**Naming rules:**
- Prefix with handle type: `OCCTShape`, `OCCTWire`, `OCCTFace`, `OCCTEdge`, `OCCTCurve3D`, `OCCTSurface`, `OCCTMesh`
- For new domains, use `OCCT{Domain}` (e.g., `OCCTGeomFillPipe`)
- Function names describe the operation: `OCCTShapeCreateBox`, `OCCTBRepExtremaExtCC`

**Parameter mapping:**
- `gp_Pnt` → `double x, double y, double z`
- `gp_Vec` / `gp_Dir` → `double dx, double dy, double dz`
- `gp_Ax1` → `double ox, double oy, double oz, double dx, double dy, double dz`
- `gp_Ax2` → `double ox, double oy, double oz, double dx, double dy, double dz` (origin + Z direction)
- `TopoDS_Shape` → `OCCTShapeRef`
- `TopoDS_Wire` → `OCCTWireRef`
- `TopoDS_Face` → `OCCTFaceRef`
- `TopoDS_Edge` → `OCCTShapeRef` (edges stored as shapes)
- `Handle(Geom_Curve)` → `OCCTCurve3DRef`
- `Handle(Geom_Surface)` → `OCCTSurfaceRef`
- `Standard_Real` / `double` → `double`
- `Standard_Integer` / `int` → `int32_t`
- `Standard_Boolean` → `bool`
- Enums → `int32_t` (cast in bridge)

**Return mapping:**
- Single value → direct return
- Multiple values → C struct (typedef'd, zero-initialized in implementation)
- New shape → `OCCTShapeRef _Nullable`
- Success/failure → `bool` or nullable return

**Result structs:**
```c
typedef struct {
    // fields with descriptive names
    bool success;  // or use _Nullable return instead
} OCCTSomeResult;
```

### 6. Flag Issues

Note any of these:
- Methods that throw exceptions (need `try/catch(...)` wrapping)
- Methods returning iterators or collections (need special handling)
- Methods requiring `Handle<>` types not yet in the bridge
- `StdFail_NotDone` risks (algorithm classes that may fail)
- Abstract classes or pure virtual methods
- Dependencies on unwrapped classes

## Output Format

For each class, produce:

```
## {ClassName}
- **Header:** {path}
- **Wrappability:** Direct | Struct Result | Iterator | Handle-Based | Abstract | Complex
- **Inherits:** {parent}
- **Handle-managed:** Yes/No
- **Dependencies:** {list of OCCT classes needed}

### Constructors
- `ClassName(params)` → `OCCTBridgeFunction(mapped_params)`

### Methods to Wrap
| C++ Method | Proposed Bridge Function | Return Type | Notes |
|------------|------------------------|-------------|-------|
| `Result()` | `OCCTClassNameResult(ref)` | `OCCTSomeResult` | try/catch needed |

### Proposed Structs
```c
typedef struct { ... } OCCTSomeResult;
```

### Issues / Warnings
- {any flags from step 6}
```

Produce this analysis for ALL requested classes, then summarize with a count of how many are directly wrappable vs. deferred.
