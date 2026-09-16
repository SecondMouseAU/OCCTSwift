# OCCTMiscTests — Phase 3 Injection Matrix (Epic #766)

**Domain:** Miscellaneous (P3)  
**Total Tests:** 85  
**Branch:** `feat/766-misc-tests`  
**Base:** `v5.0.0-766-execution`  
**Generated:** 2026-09-15

---

## Test Inventory with Defect Injection Plan

Each test below must be verified Red→Green via defect injection per `okf/policies/prove-the-test-fails.md`.

| # | Suite | Test | File | Line | Injected Defect | Expected Failure | Status |
|---|-------|------|------|------|-----------------|------------------|--------|
| 1 | Issue972 2D-to-3D lifting | lift maps a 2D point through the placement's own basis | Issue972LiftingTests.swift | 15 | Return flipped Z axis in placement | Point maps to wrong side | ⬜ |
| 2 | Issue972 2D-to-3D lifting | lift respects a rotated basis | Issue972LiftingTests.swift | 27 | Use identity rotation | Point not rotated correctly | ⬜ |
| 3 | Issue972 2D-to-3D lifting | Flange.normal and Flange.placement.zAxis agree for a non-unit normal | Issue972LiftingTests.swift | 42 | Skip normalization | Vectors don't match | ⬜ |
| 4 | One GROUPED 12-double reader (#1009) | Shape.transformed(matrix:) moves the shape by the GROUPED translation | Issue1009Matrix12GroupedTests.swift | 46 | Swap GROUPED/INTERLEAVED read | Wrong translation applied | ⬜ |
| 5 | One GROUPED 12-double reader (#1009) | A GROUPED matrix agrees with the same transform written INTERLEAVED | Issue1009Matrix12GroupedTests.swift | 64 | Read INTERLEAVED as GROUPED | Matrices disagree | ⬜ |
| 6 | One GROUPED 12-double reader (#1009) | Curve3D.parametricTransformation reads the rotation from the GROUPED slots | Issue1009Matrix12GroupedTests.swift | 92 | Zero rotation in GROUPED | Identity instead of rotation | ⬜ |
| 7 | One GROUPED 12-double reader (#1009) | Document.addComponent(matrix:) places the component at the GROUPED translation | Issue1009Matrix12GroupedTests.swift | 131 | Add offset to translation | Component placed incorrectly | ⬜ |
| 8 | One GROUPED 12-double reader (#1009) | Document.addComponent(matrix:) accepts a reflection and actually reflects | Issue1009Matrix12GroupedTests.swift | 150 | Use identity matrix | No reflection occurs | ⬜ |
| 9 | v0.115.0 - Interpolation Expansion 3D | interpolateWithEndpointTangents | OCCTMiscTests.swift | 20 | Remove endpoint tangent constraint | Wrong curve shape | ⬜ |
| 10 | v0.115.0 - Interpolation Expansion 3D | interpolateWithAllTangents | OCCTMiscTests.swift | 29 | Omit internal tangents | Curve doesn't match tangents | ⬜ |
| 11 | v0.115.0 - Interpolation Expansion 3D | interpolateWithParameters | OCCTMiscTests.swift | 37 | Use uniform parameters | Incorrect parameterization | ⬜ |
| 12 | v0.115.0 - Interpolation Expansion 3D | interpolatePeriodic | OCCTMiscTests.swift | 44 | Break periodicity | Non-periodic result | ⬜ |
| 13 | v0.142 ConstructionContext | Add and retrieve entities by ID | OCCTMiscTests.swift | 58 | Skip entity registration | Lookup returns nil | ⬜ |
| 14 | v0.142 ConstructionContext | Resolve entities against a graph | OCCTMiscTests.swift | 78 | Break graph references | Resolution fails incorrectly | ⬜ |
| 15 | v0.142 ConstructionContext | allBroken detects unregistered references | OCCTMiscTests.swift | 95 | Don't track broken refs | allBroken returns empty | ⬜ |
| 16 | v0.142 ConstructionContext | Remove an entity | OCCTMiscTests.swift | 115 | Don't actually remove | Entity still present | ⬜ |
| 17 | v0.142 ConstructionContext | Remove an axis and a point | OCCTMiscTests.swift | 126 | Skip axis removal | Axis remains in context | ⬜ |
| 18 | v0.142 ConstructionContext | removeAll clears every entity kind | OCCTMiscTests.swift | 140 | Clear only points | Axes/planes remain | ⬜ |
| 19 | v0.142 ConstructionContext | Resolve axis and point entities against a graph | OCCTMiscTests.swift | 157 | Swap axis/point resolution | Wrong entity types returned | ⬜ |
| 20 | v0.142 ConstructionContext | allBroken detects unregistered axis and point references | OCCTMiscTests.swift | 183 | Don't track axis/point refs | Missing broken detections | ⬜ |
| 21 | v0.142 ConstructionContext | Document exposes a lazy construction context | OCCTMiscTests.swift | 203 | Return new context each call | Not lazy, different instances | ⬜ |
| 22 | PR #898 review: ConstructionContext cross-store atomicity | count() never observes a torn cross-store snapshot during removeAll() | OCCTMiscTests.swift | 329 | Remove atomicity | Torn snapshot observed | ⬜ |
| 23 | PR #898 review: ConstructionContext cross-store atomicity | removeAll() stays all-or-nothing under concurrent add() | OCCTMiscTests.swift | 352 | Allow partial removal | Some entities remain | ⬜ |
| 24 | PR #898 review: ConstructionContext cross-store atomicity | removeAll() stays all-or-nothing under concurrent single remove() | OCCTMiscTests.swift | 398 | Allow partial removal | Some entities remain | ⬜ |
| 25 | PR #898 review: ConstructionContext cross-store atomicity | removeAll() immediately followed by count() is empty with no concurrent add() | OCCTMiscTests.swift | 421 | Return stale count | Non-zero count after removeAll | ⬜ |
| 26 | PR #898 review: ConstructionContext cross-store atomicity | allBroken(in:) never observes a torn cross-store snapshot during removeAll() | OCCTMiscTests.swift | 492 | Return torn snapshot | Broken refs in wrong state | ⬜ |
| 27 | PR #898 review: ConstructionContext cross-store atomicity | materialize(in:graph:) never observes a torn cross-store snapshot during removeAll() | OCCTMiscTests.swift | 555 | Return torn snapshot | Materialization corrupted | ⬜ |
| 28 | v0.142 Sketch buildProfile | Profile excludes construction elements | OCCTMiscTests.swift | 631 | Include construction elements | Extra edges in profile | ⬜ |
| 29 | v0.142 Sketch buildProfile | buildProfile returns nil if no profile elements present | OCCTMiscTests.swift | 657 | Return empty wire | Non-nil on empty | ⬜ |
| 30 | v0.142 Sketch buildProfile | buildProfile returns nil when host plane is unresolvable | OCCTMiscTests.swift | 675 | Return wire anyway | Non-nil on bad plane | ⬜ |
| 31 | v0.143 Angle helpers | Angle between two perpendicular edges ≈ π/2 | OCCTMiscTests.swift | 700 | Return π instead of π/2 | Wrong angle computed | ⬜ |
| 32 | v0.143 Angle helpers | Box face pairs parallel-or-perpendicular | OCCTMiscTests.swift | 720 | Swap parallel/perpendicular | Classification inverted | ⬜ |
| 33 | v0.143 Angle helpers | unsignedAngle between parallel vectors == 0 | OCCTMiscTests.swift | 738 | Return π | Non-zero for parallel | ⬜ |
| 34 | v0.143 Angle helpers | unsignedAngle between antiparallel vectors == π | OCCTMiscTests.swift | 749 | Return 0 | Zero for antiparallel | ⬜ |
| 35 | v0.143 Angle helpers | ConstructionAxis angle between resolved axes | OCCTMiscTests.swift | 770 | Use unresolved axes | Angle from wrong axes | ⬜ |
| 36 | v0.143 Angle helpers | ConstructionPlane angle between normals | OCCTMiscTests.swift | 787 | Use plane origins not normals | Wrong angle | ⬜ |
| 37 | #888 Edge.parameterByLinearFraction | parameterByLinearFraction maps 0/0.5/1 to bounds.first/mid/last | OCCTMiscTests.swift | 809 | Return bounds.first for all | All fractions map to start | ⬜ |
| 38 | #888 Edge.parameterByLinearFraction | parameterByLinearFraction clamps out-of-range fractions to [0, 1] | OCCTMiscTests.swift | 841 | Don't clamp | Out of bounds params | ⬜ |
| 39 | #889 Face.uvMidpointSample | uvMidpointSample matches point/normal at manual UV midpoint | OCCTMiscTests.swift | 869 | Return corner sample | Midpoint mismatch | ⬜ |
| 40 | #889 Face.uvMidpointSample | isCoplanar: a face is coplanar with itself | OCCTMiscTests.swift | 891 | Return false for self | Self not coplanar | ⬜ |
| 41 | #889 Face.uvMidpointSample | isCoplanar: parallel but offset faces are not coplanar | OCCTMiscTests.swift | 902 | Return true for offset | Offset faces coplanar | ⬜ |
| 42 | #889 Face.uvMidpointSample | revolutionProperties on cone matches primaryAxis and positive radius | OCCTMiscTests.swift | 921 | Negate radius | Negative radius | ⬜ |
| 43 | v0.143 Multi-leaf createdBy | leafOccurrence picks among split descendants | OCCTMiscTests.swift | 970 | Return seed always | Wrong leaf selected | ⬜ |
| 44 | v0.143 Multi-leaf createdBy | currentForms returns both leaves of a split | OCCTMiscTests.swift | 1000 | Return only seed | Missing split leaves | ⬜ |
| 45 | v0.143 Multi-leaf createdBy | leafOccurrence: nil returns seed without forward-walk | OCCTMiscTests.swift | 1018 | Return first leaf | Wrong entity for nil | ⬜ |
| 46 | v0.143 Multi-leaf createdBy | leafOccurrence out of range fails with occurrenceOutOfRange | OCCTMiscTests.swift | 1040 | Return nil | No error thrown | ⬜ |
| 47 | v0.143 Construction layer persistence | addConstructionShape tags shape with CONSTRUCTION layer | OCCTMiscTests.swift | 1072 | Skip tagging | Shape on wrong layer | ⬜ |
| 48 | v0.143 Construction layer persistence | Materialize all ConstructionContext entities as shapes on CONSTRUCTION layer | OCCTMiscTests.swift | 1088 | Use default layer | Shapes on default layer | ⬜ |
| 49 | v0.143 Construction layer persistence | materialize reports resolve failure for each entity kind | OCCTMiscTests.swift | 1111 | Skip failure reporting | Silent failures | ⬜ |
| 50 | v0.143 Construction layer persistence | materialize reports axisShapeFailed for zero-length axis direction (#880) | OCCTMiscTests.swift | 1153 | Don't check zero length | Invalid shape created | ⬜ |
| 51 | v0.143 Construction layer persistence | materialize reports planeShapeFailed when plane's wire can't be built (#880) | OCCTMiscTests.swift | 1181 | Skip wire validation | Invalid plane shape | ⬜ |
| 52 | v0.143 Construction layer persistence | materializeOne reports add failure instead of bogus success (PR #898 review) | OCCTMiscTests.swift | 1253 | Return success on failure | False positive success | ⬜ |
| 53 | v0.143 Construction layer persistence | materializeOne still reports success for non-negative label ID | OCCTMiscTests.swift | 1287 | Return failure on valid | False negative | ⬜ |
| 54 | v0.143 Construction layer persistence | Fresh Document never inherits dead Document's construction context (#277) | OCCTMiscTests.swift | 1324 | Share context | Leaked context state | ⬜ |
| 55 | v0.145 ISO 5457 paper sizes | A0 landscape dimensions match ISO 5457 | OCCTMiscTests.swift | 1352 | Use A1 dims | Wrong A0 size | ⬜ |
| 56 | v0.145 ISO 5457 paper sizes | A4 portrait is 210 × 297 | OCCTMiscTests.swift | 1358 | Swap width/height | 297 × 210 | ⬜ |
| 57 | v0.145 ISO 5457 paper sizes | Each paper size has half the area of next size up | OCCTMiscTests.swift | 1364 | Use wrong ratio | Area ratio incorrect | ⬜ |
| 58 | v0.145 Sheet rendering | Sheet innerFrame respects ISO 5457 margins | OCCTMiscTests.swift | 1406 | Ignore margins | Frame at edge | ⬜ |
| 59 | v0.145 Sheet rendering | Sheet innerFrame uses A4's distinct ISO 5457 margins, not A0-A3's | OCCTMiscTests.swift | 1418 | Use A0 margins for A4 | Wrong margins | ⬜ |
| 60 | v0.145 Sheet rendering | Sheet render emits border + inner frame polylines onto PDFWriter | OCCTMiscTests.swift | 1459 | Skip frame emission | Missing frame in PDF | ⬜ |
| 61 | v0.145 Sheet rendering | Sheet render emits border + inner frame polylines onto SVGWriter | OCCTMiscTests.swift | 1475 | Skip frame emission | Missing frame in SVG | ⬜ |
| 62 | v0.145 Sheet rendering | Projection symbol renders two circles for both conventions onto PDFWriter | OCCTMiscTests.swift | 1491 | Render one circle | Missing circle | ⬜ |
| 63 | v0.145 Sheet rendering | Projection symbol renders two circles for both conventions onto SVGWriter | OCCTMiscTests.swift | 1502 | Render one circle | Missing circle | ⬜ |
| 64 | v0.145 Sheet rendering | TitleBlock fields are emitted as text onto PDFWriter | OCCTMiscTests.swift | 1513 | Skip text emission | Empty title block | ⬜ |
| 65 | v0.145 Sheet rendering | TitleBlock fields are emitted as text onto SVGWriter | OCCTMiscTests.swift | 1527 | Skip text emission | Empty title block | ⬜ |
| 66 | v0.151 SheetMetal, flange + bend composition | L-bracket: two orthogonal flanges with one bend | OCCTMiscTests.swift | 1552 | Skip bend | Sharp corner | ⬜ |
| 67 | v0.151 SheetMetal, flange + bend composition | U-channel: three flanges, two bends | OCCTMiscTests.swift | 1583 | Skip one bend | Missing bend | ⬜ |
| 68 | v0.151 SheetMetal, flange + bend composition | Flanges-only (no bends) still produces fused solid | OCCTMiscTests.swift | 1620 | Don't fuse | Separate solids | ⬜ |
| 69 | v0.151 SheetMetal, flange + bend composition | Single flange with no bends returns plain extrusion | OCCTMiscTests.swift | 1641 | Add phantom bend | Extra bend geometry | ⬜ |
| 70 | v0.151 SheetMetal, flange + bend composition | Zero thickness is rejected | OCCTMiscTests.swift | 1658 | Accept zero thickness | Invalid solid created | ⬜ |
| 71 | v0.151 SheetMetal, flange + bend composition | Empty flange list is rejected | OCCTMiscTests.swift | 1671 | Accept empty list | Empty result | ⬜ |
| 72 | v0.151 SheetMetal, flange + bend composition | Duplicate flange id is rejected | OCCTMiscTests.swift | 1678 | Accept duplicate | Ambiguous references | ⬜ |
| 73 | v0.151 SheetMetal, flange + bend composition | Bend referencing unknown flange id is rejected | OCCTMiscTests.swift | 1697 | Accept unknown ref | Dangling reference | ⬜ |
| 74 | v0.151 SheetMetal, flange + bend composition | Single-flange volume matches thickness × profile area | OCCTMiscTests.swift | 1713 | Double thickness | Volume 2x expected | ⬜ |
| 75 | v0.151 SheetMetal, flange + bend composition | Fused two-flange volume subtracts overlap | OCCTMiscTests.swift | 1732 | Don't subtract overlap | Volume too large | ⬜ |
| 76 | v0.151 SheetMetal, flange + bend composition | Stepped seam (narrow upright over wider base) succeeds in v0.153 | OCCTMiscTests.swift | 1764 | Fail stepped seam | False failure | ⬜ |
| 77 | v0.151 SheetMetal, flange + bend composition | L-bracket: 80×40 base, 20×30 centred mounting tab | OCCTMiscTests.swift | 1789 | Offset tab incorrectly | Tab not centred | ⬜ |
| 78 | v0.151 SheetMetal, flange + bend composition | Z-bracket: full + stepped seams | OCCTMiscTests.swift | 1814 | Use uniform seams | Wrong seam types | ⬜ |
| 79 | v0.151 SheetMetal, flange + bend composition | U-channel with stepped narrower side flanges | OCCTMiscTests.swift | 1857 | Equal side flanges | Symmetric channel | ⬜ |
| 80 | v0.151 SheetMetal, flange + bend composition | Parallel flanges cannot form a bend | OCCTMiscTests.swift | 1890 | Allow parallel bend | Invalid geometry | ⬜ |
| 81 | Issue #89: convex bends | Z-section with two opposite-direction 90° bends builds cleanly | OCCTMiscTests.swift | 1917 | Use same direction | Self-intersecting | ⬜ |
| 82 | Issue #89: convex bends | Symmetric Z-section (top 30, web 20, bottom 30, R=3) | OCCTMiscTests.swift | 1950 | Asymmetric dims | Wrong profile | ⬜ |
| 83 | Issue #89: convex bends | Offset L with very short web (5mm) and 90° opposite bends | OCCTMiscTests.swift | 1979 | Use long web | Different geometry | ⬜ |
| 84 | Issue #89: convex bends | Channel with flange, mixed concave + convex bends | OCCTMiscTests.swift | 2007 | All same bend type | Missing bend variety | ⬜ |
| 85 | Issue #89: convex bends | Explicit .convex matches auto-detected convex behaviour | OCCTMiscTests.swift | 2044 | Force concave | Mismatch | ⬜ |

---

## Execution Protocol

1. **Run baseline**: `swift test --filter OCCTMiscTests` — all 85 tests must pass
2. **For each test**:
   - Inject the defect (modify bridge or test to simulate failure)
   - Run test — confirm it fails (Red)
   - Restore fix — confirm it passes (Green)
   - Document both results in PR
3. **Final verification**: Full `swift test --filter OCCTMiscTests` clean

---

## Notes

- All tests are in `Tests/OCCTMiscTests/` target (single module)
- Focused compile: `swift build --target OCCTMiscTests` (~3s)
- No OCCT kernel patches required for this domain — all bridge/Swift layer
- Tests cover: lifting, matrix transforms, interpolation, construction context, sketch profiles, angle helpers, edge/face properties, multi-leaf topology, construction layers, ISO 5457, sheet rendering, sheet metal, convex bends