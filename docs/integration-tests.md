# OCCTSwift Integration & Stress Tests

Comprehensive test plan for validating the full OCCTSwift wrapper (3333 operations).

These tests go beyond unit tests — they exercise realistic multi-step workflows, stress edge cases, and verify end-to-end fidelity. They are implemented across the OCCTSwift ecosystem:

- **OCCTSwift** (`Tests/OCCTIntegrationTests/`) — Swift Testing framework
- **OCCTSwiftScripts** — standalone script variants for longer-running stress tests
- **OCCTSwiftViewport** — visual demos that exercise the same workflows with rendering

## 1. Design Workflows

### 1.1 Mounting Bracket

A classic parametric design that chains 7 distinct modeling operations, validating at each step.

```
box → union(wall) → fillet(corner) → drill(x4) → chamfer(holes) → shell → validate
```

**Operations exercised:** BRepPrimAPI (box, cylinder), BRepAlgoAPI_Fuse, BRepFilletAPI_MakeFillet, BRepAlgoAPI_Cut, BRepFilletAPI_MakeChamfer, BRepOffsetAPI_MakeThickSolid

**Checks at each step:**
- `isValid` remains true
- Volume changes monotonically (union increases, drill/shell decreases)
- Face count changes as expected
- Final: volume > 0, correct topology, STEP round-trip preserves measurements

### 1.2 Involute Gear

Exercises curve construction, extrusion, circular patterns, and boolean composition.

```
involute curve → tooth wire → extrude → circularPattern(x20) → union(hub) → drill(bore)
```

**Operations exercised:** Curve3D.interpolate, Wire.wireFromEdges, Shape.extrude, Shape.circularPattern, BRepAlgoAPI_Fuse, BRepAlgoAPI_Cut

**Checks:** 20 teeth in pattern, rotational symmetry, volume consistency, manifold mesh

### 1.3 OCCT Bottle (Reference Tutorial)

The canonical OCCT tutorial adapted to Swift. Exercises nearly every fundamental operation.

```
profile wire → mirror → face → revolve → fillet(all) → shell → thread(helix+loft) → STEP round-trip
```

**Operations exercised:** Wire construction, mirror, face creation, revolve, fillet, shell (MakeThickSolid), ThruSections loft, boolean union, STEP I/O

### 1.4 Assembly Interference Check

Validates measurement and spatial queries between positioned parts.

```
shaft + housing → translate → intersects?(clearance) → distance → interference volume
```

**Operations exercised:** Shape.cylinder, Shape.translated, Shape.intersects, Shape.distance, BRepAlgoAPI_Common, volume measurement

### 1.5 Fluent Chain Composition

Tests that operations compose correctly — one operation's output is valid input for the next.

```
box → fillet → drill → boss → chamfer → shell → isValid at every step
```

**Checks:** `isValid` true at all 6 intermediate stages, volume changes in expected direction

## 2. CAM Workflows

### 2.1 Pocket Clearing (Parallel Offset)

Simulates 2.5D pocket milling toolpath generation.

```
box with pocket → extract pocket face → offset wire inward repeatedly → collect passes
```

**Operations exercised:** BRepOffsetAPI_MakeOffset (wire offset), face extraction, wire analysis

**Checks:** Each offset wire is valid and closed, wires eventually collapse to nil, total area converges

### 2.2 Z-Level Slicing for Roughing

Simulates roughing pass generation by slicing at multiple Z heights.

```
hemisphere → slice at 25 Z-levels → verify wire count/size → offset each slice
```

**Operations exercised:** BRepAlgoAPI_Section, wire queries, wire offset

**Checks:** Wire bounding box shrinks toward pole, consistent wire count per level, area follows expected curve

### 2.3 Hole Detection for Drilling

Automatically identifies circular features for drill cycle generation.

```
plate with 5 drilled holes → section at Z → find circular edges → extract centers/radii
```

**Operations exercised:** Shape.drilled, Shape.sectionWiresAtZ, edge type queries, wire analysis

**Checks:** Detected hole count matches drilled count, centers within tolerance, radii match

### 2.4 Surface Milling Scallop Analysis

Analyzes curvature to determine adaptive stepover for 3D surface milling.

```
BSpline surface → sample curvature grid → compute scallop height → identify steep regions
```

**Operations exercised:** Surface.bspline, Surface.gaussianCurvature, Surface.principalCurvatures, iso-curve extraction

### 2.5 Profile Contouring

Generates contour toolpaths by offsetting section wires.

```
complex part → section at Z → offset outward by tool radius → verify no self-intersection
```

## 3. Esoteric/Advanced Workflows

### 3.1 Draft Analysis for Mold Design

Classifies faces by draft angle relative to a pull direction.

```
part → iterate faces → compute normal at centroid → angle vs pull direction → classify
```

**Checks:** Faces with sufficient draft (>3 deg), insufficient draft, undercuts (negative)

### 3.2 UV Surface Analysis (Approximate Unwrapping)

Validates surface parameterization by integrating the metric tensor.

```
cylinder surface → trim → sample UV grid → compute metric tensor → integrate area → compare to face.area()
```

**Checks:** Integrated area matches face.area() within 1%, Gaussian curvature = 0 for cylinder (developable)

### 3.3 Geodesic Path Approximation

Tests surface evaluation convergence on a sphere.

```
sphere → pick two UV points → subdivide UV path → evaluate 3D → measure length → compare to great circle
```

**Checks:** Path length converges to analytical great circle distance as N increases

### 3.4 OBB Tightness

Validates oriented bounding box is tighter than axis-aligned.

```
lofted shape → compute AABB → compute OBB → verify OBB_volume <= AABB_volume → rotate → verify OBB invariant
```

### 3.5 Thickness Analysis via Ray Casting

Computes wall thickness map by ray casting from each face.

```
shelled box → for each face: cast ray along normal → find opposite wall → compute thickness
```

**Checks:** Minimum thickness matches shell parameter, identify thin-wall regions

## 4. Stress Tests

### 4.1 Boolean Chain (100 Subtractions)

```
box → subtract 100 random spheres sequentially → validate every 10th step
```

**Checks:** Volume decreases monotonically, isValid at checkpoints, compare sequential vs compound subtraction performance

### 4.2 Precision Extremes

```
micro: 1um cube → fillet 0.1um
macro: 1km cube → drill 1m hole
mixed: 1m box → 0.001mm hole
tolerance: shared-edge boxes offset by 1e-8
```

**Checks:** isValid, volume correctness, boolean success/failure boundaries

### 4.3 Degenerate Geometry Resilience

```
zero-thickness shell → should return nil
self-intersecting wire → face creation fails gracefully
oversized fillet → returns nil
```

**Checks:** No crashes, graceful nil returns, healing can improve

### 4.4 Format Round-Trip Fidelity

```
complex part → measure (volume, area, CoM, edges, faces)
→ export STEP → reimport → compare
→ export BREP → reimport → compare (should be exact)
→ export IGES → reimport → compare
```

**Checks:** Volume within 0.1%, area within 0.1%, face/edge counts equal, CoM within 1e-6

### 4.5 Memory Stress

```
10K iterations: create box → compute volume → release
1K iterations: create → fillet → drill → measure → release
100 iterations: create → STEP export → reimport → release
```

**Checks:** No crashes, no memory growth, final iteration matches first

### 4.6 Concurrent Shape Operations

```
8 concurrent tasks: each creates box → fillet → drill → measure
```

**Checks:** All 8 results identical, no crashes (monitors known NCollection SEGV)

## 5. Regression Tests

### 5.1 Golden Shape Baselines

One canonical shape per category with all measurements stored. Any change flags a regression.

### 5.2 Cross-Section Regression

```
cylinder with through-holes → section at 50 Z-levels → verify wire count + area consistency
```

### 5.3 Tolerance Cascade

```
shared-edge boxes → shift by increasing offsets (1e-8 to 1e-3)
→ boolean at each offset → validate → heal
```

## Running the Tests

```bash
# Integration tests (in OCCTSwift)
swift test --filter "IntegrationTests"

# Stress tests (in OCCTSwiftScripts)
cd ../OCCTSwiftScripts
swift run StressTests

# Visual workflow demos (in OCCTSwiftViewport)
cd ../OCCTSwiftViewport
swift run OCCTSwiftMetalDemo --test-all-demos
```

## Status

| Test | Status | Notes |
|------|--------|-------|
|------|--------|-------|
| 1.1 Mounting Bracket | PASS | |
| 1.2 Involute Gear | PASS | |
| 1.3 OCCT Bottle | PASS | |
| 1.4 Assembly Interference | PASS | |
| 1.5 Fluent Chain | PASS | |
| 2.1 Pocket Clearing | PASS | |
| 2.2 Z-Level Slicing | PASS | |
| 2.3 Hole Detection | PASS | |
| 2.4 Scallop Analysis | PASS | |
| 2.5 Profile Contouring | PASS | |
| 3.1 Draft Analysis | PASS | |
| 3.2 UV Unwrapping | PASS | |
| 3.3 Geodesic Path | PASS | |
| 3.4 OBB Tightness | PASS | |
| 3.5 Thickness Analysis | PASS | |
| 4.1 Boolean Chain | PASS | |
| 4.2 Precision Extremes | PASS | |
| 4.3 Degenerate Resilience | PASS | |
| 4.4 Format Round-Trip | PASS | |
| 4.5 Memory Stress | PASS | |
| 4.6 Concurrent Ops | PASS | Known OCCT #1179 SEGV |
| 5.1 Golden Baselines | PASS | |
| 5.2 Cross-Section | PASS | |
| 5.3 Tolerance Cascade | PASS | |
