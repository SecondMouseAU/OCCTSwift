# Audit OCCT Wrapping Coverage

Scan the OCCT headers in the xcframework against the functions already declared across the bridge
headers (`Sources/OCCTBridge/include/OCCTBridge*.h`) and produce a categorized gap report showing what remains to be wrapped.

## Instructions

1. **Collect all OCCT header filenames** from `Libraries/OCCT.xcframework/macos-arm64/Headers/*.hxx`. Group them by module prefix (e.g., `BRepPrimAPI_`, `GeomFill_`, `ShapeFix_`, `GCPnts_`, etc.).

2. **Collect all currently wrapped classes** by scanning `Sources/OCCTBridge/include/OCCTBridge*.h`
   (since #395 the declarations are spread across 15 domain headers; the umbrella `OCCTBridge.h`
   keeps the class cross-reference index but only 2 function declarations)` for OCCT class names referenced in comments and function names. Also scan `Sources/OCCTBridge/src/OCCTBridge.mm` `#include` directives to get the definitive list of OCCT classes already used.

3. **Classify each unwrapped header** into one of these tiers:

   **Tier 1. High Priority (commonly used in CAD/CAM):**
   - `BRepPrimAPI_*`, `BRepAlgoAPI_*`, `BRepFilletAPI_*`, `BRepOffsetAPI_*` (shape creation/modification)
   - `BRepBuilderAPI_*` (topology construction)
   - `BRepExtrema_*` (distance/measurement)
   - `BRepTools_*`, `BRepLib_*` (utility operations)
   - `ShapeFix_*`, `ShapeAnalysis_*`, `ShapeUpgrade_*`, `ShapeCustom_*` (healing/analysis)
   - `GC_*`, `GCE2d_*` (geometry construction)
   - `GeomAPI_*`, `Geom2dAPI_*` (geometry algorithms)
   - `GCPnts_*` (curve discretization)
   - `GeomConvert_*`, `Geom2dConvert_*` (geometry conversion)

   **Tier 2. Medium Priority (useful but less common):**
   - `GeomFill_*` (surface filling)
   - `LocOpe_*` (local operations)
   - `BRepCheck_*` (validation)
   - `BRepMesh_*` (meshing)
   - `GeomLProp_*`, `BRepLProp_*` (local properties)
   - `Approx_*`, `AppDef_*`, `AppParCurves_*` (approximation)

   **Tier 3. Low Priority (internal/specialized):**
   - `NCollection_*`, `TCollection_*` (containers, internal OCCT use)
   - `Standard_*` (runtime, internal)
   - `IntCurve*`, `IntPatch*`, `IntSurf*` (intersection internals)
   - `math_*` (linear algebra internals)
   - Data exchange (`IGESData_*`, `StepData_*`, `XSControl_*`)

   **Skip. Not wrappable:**
   - `.lxx` files (inline implementations)
   - `*_0.hxx` (deprecated OCCT stubs)
   - Pure enum/typedef headers with no classes
   - Abstract base classes that require C++ subclassing

4. **Filter out non-class headers.** Only include headers that define concrete, instantiable classes with public constructors or static factory methods. Skip:
   - Pure template instantiations (`NCollection_Sequence`, `NCollection_Array1`, etc.)
   - Enum-only headers
   - Internal implementation headers

5. **Produce the gap report** in this format:

   ```
   ## OCCT Wrapping Audit Report

   **Current coverage:** {N} wrapped classes out of ~{M} wrappable classes ({percent}%)

   ### Tier 1. High Priority ({count} unwrapped)
   | Module | Class | Key Operations | Complexity |
   |--------|-------|----------------|------------|
   | BRepBuilderAPI | MakePolygon | Add points to polygon wire | Low |
   | ... | ... | ... | ... |

   ### Tier 2. Medium Priority ({count} unwrapped)
   ...

   ### Tier 3. Low Priority ({count} unwrapped)
   ...

   ### Recommended Next Release (v0.XX.0)
   Pick ~100 operations from Tier 1 and Tier 2, prioritizing:
   1. Classes that complete partially-wrapped modules
   2. Commonly needed operations with simple APIs
   3. Classes that don't require complex type hierarchies
   ```

6. **Complexity estimation** per class:
   - **Low**: Simple constructor + result, few parameters, no special types
   - **Medium**: Multiple constructors, struct results, requires topology extraction
   - **High**: Requires Handle<> hierarchies, abstract base classes, iterators, or Law/Section types

7. For the "Recommended Next Release" section, propose a concrete list of ~100 operations that would make a good release. Group them by module for clarity. Prioritize breadth over depth, cover many classes with a few operations each rather than exhaustively wrapping one class.

## Output
Print the full gap report to the conversation. Do NOT write it to a file unless asked.
