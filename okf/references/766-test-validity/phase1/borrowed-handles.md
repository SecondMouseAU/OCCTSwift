# Phase 1: Borrowed Handles Injection Matrix

**Script**: `Scripts/check-borrowed-handles.py` — Detects Swift value types (struct/enum) that store `OCCT*Ref` without a `deinit` to release it

**Policy**: `prove-the-test-fails.md` — For each test: inject defect → confirm fail (red) → restore → confirm pass (green) → report both

---

## Background

From #965: 19 `*Properties` views across Curve2D.swift (7), Curve3D.swift (5), Surface.swift (7) stored `fileprivate let handle: OCCT*Ref`. Accessing `edge.curve3D?.circleProperties.radius` caused SIGSEGV (use-after-free).

The fix: conform each view to `NativeHandleView` which stores the OWNER and reads the handle through it.

---

## Test Coverage for Borrowed Handles

The gate script scans `Sources/OCCTSwift/*.swift` for structs/enums storing `OCCT*Ref` directly.

### Current State (from check-borrowed-handles.py ALLOWED table)
- ALLOWED table is **empty** — no value type should store a raw handle
- Any finding is a regression of #965 fix

### Swift Types to Verify (from CLAUDE.md and codebase)

| Type | File | NativeHandleView? | Test Coverage |
|------|------|-------------------|---------------|
| `CircleProperties` | Curve2D.swift | ✅ | Curve2DTests |
| `EllipseProperties` | Curve2D.swift | ✅ | Curve2DTests |
| `HyperbolaProperties` | Curve2D.swift | ✅ | Curve2DTests |
| `ParabolaProperties` | Curve2D.swift | ✅ | Curve2DTests |
| `LineProperties` | Curve2D.swift | ✅ | Curve2DTests |
| `BSplineCurve2DProperties` | Curve2D.swift | ✅ | Curve2DTests |
| `BezierCurve2DProperties` | Curve2D.swift | ✅ | Curve2DTests |
| `CircleProperties` | Curve3D.swift | ✅ | Curve3DTests |
| `EllipseProperties` | Curve3D.swift | ✅ | Curve3DTests |
| `HyperbolaProperties` | Curve3D.swift | ✅ | Curve3DTests |
| `ParabolaProperties` | Curve3D.swift | ✅ | Curve3DTests |
| `BSplineCurve3DProperties` | Curve3D.swift | ✅ | Curve3DTests |
| `BezierCurve3DProperties` | Curve3D.swift | ✅ | Curve3DTests |
| `SphereProperties` | Surface.swift | ✅ | SurfaceTests |
| `CylindricalSurfaceProperties` | Surface.swift | ✅ | SurfaceTests |
| `ConicalSurfaceProperties` | Surface.swift | ✅ | SurfaceTests |
| `ToroidalSurfaceProperties` | Surface.swift | ✅ | SurfaceTests |
| `PlaneProperties` | Surface.swift | ✅ | SurfaceTests |
| `BSplineSurfaceProperties` | Surface.swift | ✅ | SurfaceTests |
| `BezierSurfaceProperties` | Surface.swift | ✅ | SurfaceTests |

---

## Injection Procedure per Test

For each test that accesses a `*Properties` view:

```bash
# 1. Locate the struct/enum definition in Sources/OCCTSwift/*.swift
# 2. Create injection by REVERTING the fix:
#    - Change: `let owner: Curve3D` + `var handle: OCCTCurve3DRef { owner.handle }`
#    - To: `fileprivate let handle: OCCTCurve3DRef` (original #965 defect)
# 3. Run focused test: swift test --filter <TestStructName>
# 4. Confirm FAIL (red) - should SIGSEGV or read wrong memory
# 5. Restore NativeHandleView conformance
# 6. Confirm PASS (green)
# 7. Record in matrix below
```

---

## Injection Matrix

| Test Target | Suite | Test | Properties Type | Defect Injected | Red? | Green? | Notes |
|-------------|-------|------|-----------------|-----------------|------|--------|-------|
| OCCTCurveTests | Circle property extraction | Cylindrical face exposes revolutionProperties with correct radius | CircleProperties (Curve3D) | Revert to `fileprivate let handle` |  |  | |
| OCCTCurveTests | BSplineCurve3DProperties | (find relevant) | BSplineCurve3DProperties | Revert to raw handle |  |  | |
| OCCTCurveTests | BezierCurve3DProperties | (find relevant) | BezierCurve3DProperties | Revert to raw handle |  |  | |
| OCCTGeom2dTests | CircleProperties (Curve2D) | (find relevant) | CircleProperties (Curve2D) | Revert to raw handle |  |  | |
| OCCTGeom2dTests | EllipseProperties | (find relevant) | EllipseProperties | Revert to raw handle |  |  | |
| OCCTGeom2dTests | HyperbolaProperties | (find relevant) | HyperbolaProperties | Revert to raw handle |  |  | |
| OCCTGeom2dTests | ParabolaProperties | (find relevant) | ParabolaProperties | Revert to raw handle |  |  | |
| OCCTSurfaceTests | SphereProperties | (find relevant) | SphereProperties | Revert to raw handle |  |  | |
| OCCTSurfaceTests | CylindricalSurfaceProperties | (find relevant) | CylindricalSurfaceProperties | Revert to raw handle |  |  | |
| OCCTSurfaceTests | PlaneProperties | (find relevant) | PlaneProperties | Revert to raw handle |  |  | |

---

## Gate Script Self-Test Removal Matrix

From `check-borrowed-handles.py --self-test`:

| Self-Test Case | Mechanism Isolated | Expected Findings Before | Expected Findings After Removal | Red? |
|----------------|-------------------|-------------------------|--------------------------------|------|
| struct storing bare handle | #965 defect itself | 1 (CircleProperties.handle) | 0 (if guard removed) |  |
| struct storing optional handle | `?` suffix handling | 1 (Thing.handle) | 0 |  |
| struct with computed handle | stored/computed split | 0 | 0 (still 0) |  |
| computed handle brace next line | `_opens_a_body_next` | 0 | 0 |  |
| CLASS storing handle | value/reference split | 0 | 0 |  |
| LOCAL handle in method | func-scope frame | 0 | 0 |  |
| struct storing OWNER | fix shape (NativeHandleView) | 0 | 0 |  |
| struct NESTED in class | nesting | 1 (PlaneProperties.handle) | 0 |  |
| STATIC stored handle on struct | static modifier | 1 (Cache.handle) | 0 |  |
| handle in comment only | comment stripping | 0 | 0 |  |
| unbalanced brace in line comment | line-comment stripping | 1 | 0 |  |
| unbalanced brace in block comment | single-line block comment | 1 | 0 |  |
| multi-line block comment with braces | in_block tracking (#680) | 1 | 0 |  |
| ENUM storing static handle | enums as value types | 1 (Registry.handle) | 0 |  |
| non-handle properties only | clean-tree control | 0 | 0 |  |

Run: `python3 Scripts/check-borrowed-handles.py --self-test`

For each case: remove the corresponding guard in `scan_lines()` → run self-test → confirm case count drops → restore.

---

## Next Steps

1. Map each `*Properties` test to its test suite (using inventory.json)
2. For each, create injection by reverting to raw handle storage
3. Run test → confirm SIGSEGV/red → restore → confirm green
4. Document in matrix above
5. Run gate script `--self-test` with each guard removal