# Tri-State Return Value Census

This document catalogs all `int32_t` bridge functions that return tri-state values
(-1 = error, 0 = false/no-error, >0 = true/error-code).

## Consolidated Tri-State Decoder (Issue #1077)

The three functions `OCCTCheckFaceStatus`, `OCCTCheckEdgeStatus`, `OCCTCheckVertexStatus`
formerly contained identical tri-state decoder logic. They now share the helper
`occtBRepCheckSubShapeStatus` in `Sources/OCCTBridge/src/OCCTBridge_Healing.mm`.

**Encoding:**
- `-1` = error (null input, analyzer failed, result null, exception)
- `0` = `BRepCheck_NoError` (status list empty)
- `>0` = first `BRepCheck_Status` enum value from the list

---

## Confirmed Tri-State Functions

### Healing / Shape Analysis

| Function | Header | Returns | Notes |
|----------|--------|---------|-------|
| `OCCTWireCheckOuterBound` | `OCCTBridge_Healing.h:1391` | -1/0/1 | -1=error, 0=not outer bound, 1=is outer bound |
| `OCCTCheckFaceStatus` | `OCCTBridge_Healing.h:1470` | -1/0/>0 | Uses shared `occtBRepCheckSubShapeStatus` |
| `OCCTCheckEdgeStatus` | `OCCTBridge_Healing.h:1473` | -1/0/>0 | Uses shared `occtBRepCheckSubShapeStatus` |
| `OCCTCheckVertexStatus` | `OCCTBridge_Healing.h:1476` | -1/0/>0 | Uses shared `occtBRepCheckSubShapeStatus` |

### Modeling / Self-Intersection

| Function | Header | Returns | Notes |
|----------|--------|---------|-------|
| `OCCTShapeSelfIntersectsBounded` | `OCCTBridge_Modeling.h:231` | -1/0/1 | -1=error, 0=clean, 1=self-intersecting (#1088) |
| `OCCTShapeSelfIntersectsDetailed` | `OCCTBridge_Modeling.h:244` | count/-1 | Returns count of issues, -1 on error |
| `OCCTShapeSelfIntersectEstimateCost` | `OCCTBridge_Modeling.h:256` | estimate/-1 | Returns cost estimate, -1 on error |

### Properties / Proximity

| Function | Header | Returns | Notes |
|----------|--------|---------|-------|
| `OCCTShapeProximity` | `OCCTBridge_Properties.h:328` | -1/0/1 | -1=error, 0=clear, 1=proximity detected |

### Shape Analysis / Wire

| Function | Header | Returns | Notes |
|----------|--------|---------|-------|
| `OCCTShapeWireVertexStatus` | `OCCTBridge_Healing.h:814` | -1/0/>0 | Vertex status enum, -1 on error |

### Document / Transactions

| Function | Header | Returns | Notes |
|----------|--------|---------|-------|
| `OCCTDocumentSaveOCAF` | `OCCTBridge_Document.h:1143` | -1/0/1 | -1=error, 0=success, 1=already retrieved |
| `OCCTDocumentSaveOCAFInPlace` | `OCCTBridge_Document.h:1151` | -1/0/1 | Same encoding as SaveOCAF |

### Advanced Modeling / Fillet & Chamfer

| Function | Header | Returns | Notes |
|----------|--------|---------|-------|
| `OCCTFilletBuilderStripeStatus` | `OCCTBridge_Modeling.h:4127` | -1/0/>0 | Stripe status enum, -1 on error |
| `OCCTFilletBuilderFaultyContour` | `OCCTBridge_Modeling.h:4130` | -1/index | Faulty contour index, -1 on error |
| `OCCTMakeEdgeError` | `OCCTBridge_Modeling.h:3703` | error enum | Returns edge construction error code |
| `OCCTWireBuilderError` | `OCCTBridge_Modeling.h:3741` | error enum | Returns wire construction error code |

### BRepGraph Validation

| Function | Header | Returns | Notes |
|----------|--------|---------|-------|
| `OCCTBRepGraphValidateIssueCount` | `OCCTBridge_BRepGraph.h:274` | count/-1 | Count of validation issues, -1 on error |

---

## Functions Returning Counts (Not Tri-State)

These return counts (0 to N) with -1 for error, but are NOT tri-state booleans:

- `OCCTShapeCheckSmallFaces` - returns count of small faces found
- `OCCTCheckShapeDetailed` - returns count of status issues found
- `OCCTShapeSelfIntersectsDetailed` - returns count of self-intersections
- All `*Get*Count`, `*Nb*`, `*Count*` functions

---

## Functions Returning Enums / Indices (Not Tri-State)

These return enum values or indices directly, with -1 for error:

- `OCCTMakeEdgeError` - edge error enum
- `OCCTWireBuilderError` - wire error enum
- `OCCTShapeWireVertexStatus` - vertex status enum

---

## Summary

**True tri-state boolean functions** (-1/0/1 only):
1. `OCCTWireCheckOuterBound`
2. `OCCTShapeSelfIntersectsBounded`
3. `OCCTShapeProximity`
4. `OCCTDocumentSaveOCAF` (0/1 for success/already-retrieved)
5. `OCCTDocumentSaveOCAFInPlace`

**Tri-state with enum payload** (-1/0/>0 where >0 is an enum):
1. `OCCTCheckFaceStatus` → shared helper
2. `OCCTCheckEdgeStatus` → shared helper
3. `OCCTCheckVertexStatus` → shared helper
4. `OCCTShapeWireVertexStatus`

**Count-returning with error sentinel** (-1/0..N):
- `OCCTShapeCheckSmallFaces`
- `OCCTCheckShapeDetailed`
- `OCCTShapeSelfIntersectsDetailed`
- `OCCTShapeSelfIntersectEstimateCost`
- `OCCTBRepGraphValidateIssueCount`

---

## Shared Helper

**`occtBRepCheckSubShapeStatus`** in `Sources/OCCTBridge/src/OCCTBridge_Healing.mm:5816`

Consolidates the identical tri-state decoder previously duplicated in:
- `OCCTCheckFaceStatus`
- `OCCTCheckEdgeStatus`
- `OCCTCheckVertexStatus`

```cpp
inline int32_t occtBRepCheckSubShapeStatus(const TopoDS_Shape& shape,
                                           const TopoDS_Shape& subShape)
{
  try
  {
    BRepCheck_Analyzer analyzer(shape, Standard_True);
    Handle(BRepCheck_Result) res = analyzer.Result(subShape);
    if (res.IsNull())
      return -1;
    const BRepCheck_ListOfStatus& st = res->Status();
    if (st.IsEmpty())
      return 0; // BRepCheck_NoError
    return static_cast<int32_t>(st.First());
  }
  catch (...)
  {
    return -1;
  }
}
```
