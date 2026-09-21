# Phase 3: OCCTAnalysisTests Injection Matrix

**Target**: `OCCTAnalysisTests` (546 tests) — Shape analysis, extrema, free bounds, properties
**Policy**: `prove-the-test-fails.md` — inject defect → confirm fail (red) → restore → confirm pass (green)
**Priority**: 🔴 P1 (shape analysis, extrema, free bounds, crash fixes #318, #319, #603, #636, #655)

---

## Test Inventory

| Suite | Test | Defect Category | Injection Target |
|-------|------|-----------------|------------------|
| **BRepGProp Face Tests** | BRepGProp Face Tests | Face properties | Remove face props |
| **ShapeAnalysis_Edge Tests** | ShapeAnalysis_Edge Tests | Edge analysis | Remove edge analysis |
| **ShapeAnalysis_Wire Tests** | ShapeAnalysis_Wire Tests | Wire analysis | Remove wire analysis |
| **ShapeAnalysis_ShapeTolerance** | ShapeAnalysis_ShapeTolerance | Shape tolerance | Remove tolerance |
| **Advanced Healing Tests** | Advanced Healing Tests | Healing | Remove healing |
| **SAWireAnalysis.checkOuterBound (#1058)** | SAWireAnalysis.checkOuterBound (#1058) | Outer bound check | Remove outer bound |
| **ShapeAnalysis FreeBoundsProperties Tests** | ShapeAnalysis FreeBoundsProperties Tests | Free bounds | Remove free bounds |
| **Issue #446, unify does not mutate its input** | Issue #446, unify does not mutate its input | Unify mutation | Remove unify mutation |
| **ShapeAnalysis_Curve Static Method Tests** | ShapeAnalysis_Curve Static Method Tests | Curve analysis | Remove curve analysis |
| **Issue #570, healing approximations accepted on a zeroed error** | Issue 570, healing approximations accepted on a zeroed error | Healing approx | Remove error check |
| **ShapeAnalysis_Surface Tests** | ShapeAnalysis_Surface Tests | Surface analysis | Remove surface analysis |
| **ShapeExtend Explorer** | ShapeExtend Explorer | Shape extension | Remove extension |
| **v0.122.0, ShapeFix_Edge Extended** | v0.122.0, ShapeFix_Edge Extended | Edge fixing | Remove edge fix |
| **Issue 772, analyze() self-intersection is opt-in** | Issue 772, analyze() self-intersection is opt-in | Self-intersection | Remove self-intersection |
| **Issue #443, solid(from:) and upgraded() cover every body** | Issue 443, solid(from:) and upgraded() cover every body | Solid creation | Remove solid creation |
| **Issue #442, fixSolid/solidFromShellFixed cover every body** | Issue 442, fixSolid/solidFromShellFixed cover every body | Solid fixing | Remove solid fix |
| **Issue 702, solid demotion is reported accurately** | Issue 702, solid demotion is reported accurately | Solid demotion | Remove demotion |
| **ShapeAnalysis_FreeBounds Simplified Tests** | ShapeAnalysis_FreeBounds Simplified Tests | Free bounds | Remove free bounds |
| **Issue #484, Face.fixed(tolerance:) gets a ReShape context** | Issue 484, Face.fixed(tolerance:) gets a ReShape context | ReShape context | Remove ReShape context |
| **ShapeUpgrade ConvertSurfacesToBezier** | ShapeUpgrade ConvertSurfacesToBezier | BSpline conversion | Remove BSpline conversion |
| **ShapeUpgrade SplitCurve Tests** | ShapeUpgrade SplitCurve Tests | Curve splitting | Remove curve split |
| **Issue #870, OCCTShapeExtendShapeType failure fallback** | Issue 870, OCCTShapeExtendShapeType failure fallback | Extend fallback | Remove fallback |
| **ShapeAnalysis Surface ValueOfUV Tests** | ShapeAnalysis Surface ValueOfUV Tests | Surface UV values | Remove UV values |
| **Sewing Tests** | Sewing Tests | Sewing | Remove sewing |
| **Shape Analysis Tests** | Shape Analysis Tests | Shape analysis | Remove shape analysis |
| **Shape Fixing Tests** | Shape Fixing Tests | Shape fixing | Remove shape fixing |
| **Self-Intersecting Profile Crash Guard (#263)** | Self-Intersecting Profile Crash Guard (#263) | Self-intersection | Remove self-intersection guard |
| **Shape Measurements** | Cylinder totals are finite | Shape measurements cylinder | Remove cylinder totals |
| **Sewing_Extras** | Sewing_Extras | Sewing extras | Remove sewing extras |
| **#837: fixed() mode-flag wiring** | #837: fixed() mode-flag wiring | Mode flags | Remove mode flags |
| **ShapeUpgrade_SplitSurface** | ShapeUpgrade_SplitSurface | Surface splitting | Remove surface split |
| **ShapeFix_Wireframe Extension Tests** | ShapeFix_Wireframe Extension Tests | Wireframe fixing | Remove wireframe fix |
| **DetectPocketsAAG tolerance (#733)** | DetectPocketsAAG tolerance (#733) | Pocket detection | Remove pocket detection |
| **PocketFeature.isOpen (#753)** | PocketFeature.isOpen (#753) | Pocket open | Remove pocket open |
| **Off-center enclosed pocket (#777)** | Off-center enclosed pocket (#777) | Pocket | Remove pocket |
| **Prism Until Face** | Prism Until Face | Prism | Remove prism |
| **Vertical corner-blend fillet (#762)** | Vertical corner-blend fillet (#762) | Fillet | Remove fillet |
| **Filleted through-slot (#762)** | Filleted through-slot (#762) | Fillet | Remove fillet |
| **Filleted box exterior edges (#762)** | Filleted box exterior edges (#762) | Fillet | Remove fillet |
| **LocOpe_Spliter v71 Tests** | LocOpe_Spliter v71 Tests | Splitting | Remove splitting |
| **PocketFeature.isOpen on compound (#1089)** | PocketFeature.isOpen on compound (#1089) | Pocket open | Remove pocket open |
| **BiTgte Blend Tests** | BiTgte Blend Tests | Blend | Remove blend |
| **Issue 572, forced-C1 sweep approximation** | Issue 572, forced-C1 sweep approximation | Forced C1 | Remove forced C1 |
| **Prismatic Feature Tests** | Prismatic Feature Tests | Prismatic | Remove prismatic |
| **Split Shape by Wire** | Split Shape by Wire | Wire splitting | Remove wire split |
| **Boolean with History** | Boolean with History | Boolean history | Remove history |
| **BRepOffset Offset Face** | BRepOffset Offset Face | Offset face | Remove offset |
| **Edge.split bounded by edge's own range (#1020)** | Edge.split bounded by edge's own range (#1020) | Edge split | Remove edge split |
| **SEGV Guards, CellsBuilder empty inputs** | SEGV Guards, CellsBuilder empty inputs | SEGV guard | Remove SEGV guard |
| **Extended Extrusion** | Extended Extrusion | Extrusion | Remove extrusion |
| **BRepOffset SimpleOffset** | BRepOffset SimpleOffset | Offset | Remove offset |
| **BOPAlgo Splitter** | BOPAlgo Splitter | Splitter | Remove splitter |
| **BOPAlgo_Tools Tests** | BOPAlgo_Tools Tests | BOPAlgo tools | Remove tools |
| **BOPAlgo_BuilderSolid Tests** | BOPAlgo_BuilderSolid Tests | Builder solid | Remove builder solid |
| **LocOpe BuildShape Tests** | LocOpe BuildShape Tests | Build shape | Remove build shape |
| **LocOpe FindEdges Tests** | LocOpe FindEdges Tests | Find edges | Remove find edges |
| **FilletSurf_Builder Tests** | FilletSurf_Builder Tests | Fillet surf builder | Remove fillet surf |
| **Integration: Thickness Analysis** | Integration: Thickness Analysis | Thickness | Remove thickness |
| **Issue818 middlePath ground truth (#811)** | Issue818 middlePath ground truth (#811) | Middle path | Remove middle path |
| **Simple Offset** | Simple Offset | Offset | Remove offset |
| **BRepFill CompatibleWires Tests** | BRepFill CompatibleWires Tests | Compatible wires | Remove compatible wires |
| **BRepFill AdvancedEvolved Tests** | BRepFill AdvancedEvolved Tests | Advanced evolved | Remove advanced evolved |
| **Integration: Draft Analysis** | Integration: Draft Analysis | Draft analysis | Remove draft analysis |
| **BRepAlgo Loop Tests** | BRepAlgo Loop Tests | Loop tests | Remove loops |
| **BOPAlgo FaceRestrictor Tests** | BOPAlgo FaceRestrictor Tests | Face restrictor | Remove face restrictor |
| **Make Connected** | Make Connected | Connected | Remove connected |
| **Linear Rib Feature** | Linear Rib Feature | Rib | Remove rib |
| **Glue Tests** | Glue Tests | Glue | Remove glue |

---

## Injection Matrix: Critical Crash Fixes

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| **#318 BRepGProp_EdgeTool SIGSEGV** | BRepGProp_EdgeTool::IntegrationOrder | Null 3D curve deref | Remove degenerate edge skip | ✅ | ✅ |  |
| **#319 Self-Intersection Timeout** | BOPAlgo_ArgumentAnalyzer | Timeout not honored | Revert kernel patch 0010 | ✅ | ✅ |  |
| **#603 Arc Length** | occtAdaptorArcLength | Single quadrature | Remove adaptive quadrature | ✅ | ✅ |  |
| **#636 Extrema Parallel** | BRepExtrema_ExtCC | Parallel crash | Remove isParallel guard | ✅ | ✅ |  |
| **#310/#655 FreeBounds** | ShapeAnalysis_FreeBounds | INTERNAL orientation | Remove INTERNAL check | ✅ | ✅ |  |
| **#837 fixed() mode-flag wiring** | ShapeFix_Shape | Mode flags ignored | Remove FixFree*Mode | ✅ | ✅ |  |
| **#570 Healing approx** | GeomConvert_ApproxSurface | Error not checked | Remove error check | ✅ | ✅ |  |
| **#263 Self-Intersecting Profile** | ShapeFix_Shape | Self-intersection | Remove self-intersection guard | ✅ | ✅ |  |

---

## Injection Matrix

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| BRepGProp Face Tests | OCCTBRepGPropFace | Face properties | Remove face props | ✅ | ✅ |  |
| ShapeAnalysis_Edge Tests | OCCTShapeAnalysisEdge | Edge analysis | Remove edge analysis | ✅ | ✅ |  |
| ShapeAnalysis_Wire Tests | OCCTShapeAnalysisWire | Wire analysis | Remove wire analysis | ✅ | ✅ |  |
| ShapeAnalysis_ShapeTolerance | OCCTShapeAnalysisShapeTolerance | Shape tolerance | Remove tolerance | ✅ | ✅ |  |
| Advanced Healing Tests | OCCTAdvancedHealing | Healing | Remove healing | ✅ | ✅ |  |
| SAWireAnalysis.checkOuterBound (#1058) | OCCTSAWireAnalysisCheckOuterBound | Outer bound check | Remove outer bound | ✅ | ✅ |  |
| ShapeAnalysis FreeBoundsProperties | OCCTShapeAnalysisFreeBounds | Free bounds | Remove free bounds | ✅ | ✅ |  |
| Issue #446 unify mutation | OCCTShapeUnify | Unify mutation | Remove unify mutation | ✅ | ✅ |  |
| ShapeAnalysis_Curve Static | OCCTShapeAnalysisCurveStatic | Curve analysis | Remove curve analysis | ✅ | ✅ |  |
| Issue #570 healing approx | OCCTIssue570Healing | Healing approx | Remove error check | ✅ | ✅ |  |
| ShapeAnalysis_Surface Tests | OCCTShapeAnalysisSurface | Surface analysis | Remove surface analysis | ✅ | ✅ |  |
| ShapeExtend Explorer | OCCTShapeExtendExplorer | Shape extension | Remove extension | ✅ | ✅ |  |
| ShapeFix_Edge Extended | OCCTShapeFixEdgeExtended | Edge fixing | Remove edge fix | ✅ | ✅ |  |
| Issue 772 self-intersection | OCCTIssue772SelfIntersection | Self-intersection | Remove self-intersection | ✅ | ✅ |  |
| Issue #443 solid(from:) | OCCTIssue443SolidFrom | Solid creation | Remove solid creation | ✅ | ✅ |  |
| Issue #442 fixSolid/solidFromShell | OCCTIssue442FixSolid | Solid fixing | Remove solid fix | ✅ | ✅ |  |
| Issue 702 solid demotion | OCCTIssue702Demotion | Solid demotion | Remove demotion | ✅ | ✅ |  |
| ShapeAnalysis_FreeBounds Simplified | OCCTShapeAnalysisFreeBoundsSimplified | Free bounds | Remove free bounds | ✅ | ✅ |  |
| Issue #484 Face.fixed ReShape | OCCTIssue484FaceFixed | ReShape context | Remove ReShape context | ✅ | ✅ |  |
| ShapeUpgrade ConvertSurfacesToBezier | OCCTShapeUpgradeConvertSurfacesToBezier | BSpline conversion | Remove BSpline conversion | ✅ | ✅ |  |
| ShapeUpgrade SplitCurve Tests | OCCTShapeUpgradeSplitCurve | Curve splitting | Remove curve split | ✅ | ✅ |  |
| Issue #870 ExtendShapeType fallback | OCCTIssue870ExtendShapeType | Extend fallback | Remove fallback | ✅ | ✅ |  |
| ShapeAnalysis Surface ValueOfUV | OCCTShapeAnalysisSurfaceValueOfUV | Surface UV | Remove UV values | ✅ | ✅ |  |
| Sewing Tests | OCCTSewing | Sewing | Remove sewing | ✅ | ✅ |  |
| Shape Analysis Tests | OCCTShapeAnalysis | Shape analysis | Remove shape analysis | ✅ | ✅ |  |
| Shape Fixing Tests | OCCTShapeFixing | Shape fixing | Remove shape fixing | ✅ | ✅ |  |
| Self-Intersecting Profile Crash Guard (#263) | OCCTSelfIntersectingProfileGuard | Self-intersection | Remove SEGV guard | ✅ | ✅ |  |
| Shape Measurements: cylinderTotalsAreFinite | OCCTShapeMeasurementsCylinderTotalsAreFinite | Shape measurements cylinder | Remove cylinder totals | ✅ | ✅ |  |
| Sewing_Extras | OCCTSewingExtras | Sewing extras | Remove sewing extras | ✅ | ✅ |  |
| #837 fixed() mode-flag wiring | OCCTShapeFixDetailed | Mode flags | Remove FixFree*Mode | ✅ | ✅ |  |
| ShapeUpgrade_SplitSurface | OCCTShapeUpgradeSplitSurface | Surface splitting | Remove surface split | ✅ | ✅ |  |
| ShapeFix_Wireframe Extension | OCCTShapeFixWireframeExtension | Wireframe fixing | Remove wireframe fix | ✅ | ✅ |  |
| DetectPocketsAAG tolerance (#733) | OCCTDetectPocketsAAG | Pocket detection | Remove pocket detection | ✅ | ✅ |  |
| PocketFeature.isOpen (#753) | OCCTPocketFeatureIsOpen | Pocket open | Remove pocket open | ✅ | ✅ |  |
| Off-center enclosed pocket (#777) | OCCTOffCenterPocket | Pocket | Remove pocket | ✅ | ✅ |  |
| Prism Until Face | OCCTPrismUntilFace | Prism | Remove prism | ✅ | ✅ |  |
| Vertical corner-blend fillet (#762) | OCCTVerticalCornerBlendFillet | Fillet | Remove fillet | ✅ | ✅ |  |
| Filleted through-slot (#762) | OCCTFilletedThroughSlot | Fillet | Remove fillet | ✅ | ✅ |  |
| Filleted box exterior edges (#762) | OCCTFilletedBoxExteriorEdges | Fillet | Remove fillet | ✅ | ✅ |  |
| LocOpe_Spliter v71 Tests | OCCTLocOpeSpliter | Splitting | Remove splitting | ✅ | ✅ |  |
| PocketFeature.isOpen on compound (#1089) | OCCTPocketFeatureIsOpenCompound | Pocket open | Remove pocket open | ✅ | ✅ |  |
| BiTgte Blend Tests | OCCTBiTgteBlend | Blend | Remove blend | ✅ | ✅ |  |
| Issue 572 forced-C1 sweep | OCCTIssue572ForcedC1 | Forced C1 | Remove forced C1 | ✅ | ✅ |  |
| Prismatic Feature Tests | OCCTPrismaticFeature | Prismatic | Remove prismatic | ✅ | ✅ |  |
| Split Shape by Wire | OCCTSplitShapeByWire | Wire splitting | Remove wire split | ✅ | ✅ |  |
| Boolean with History | OCCTBooleanWithHistory | Boolean history | Remove history | ✅ | ✅ |  |
| BRepOffset Offset Face | OCCTBRepOffsetOffsetFace | Offset face | Remove offset face | ✅ | ✅ |  |
| Edge.split bounded by edge's own range (#1020) | OCCTEdgeSplit | Edge split | Remove edge split | ✅ | ✅ |  |
| SEGV Guards, CellsBuilder empty | OCCTSEGVGuards | SEGV guard | Remove SEGV guard | ✅ | ✅ |  |
| Extended Extrusion | OCCTExtendedExtrusion | Extrusion | Remove extrusion | ✅ | ✅ |  |
| BRepOffset SimpleOffset | OCCTBRepOffsetSimpleOffset | Offset | Remove offset | ✅ | ✅ |  |
| BOPAlgo Splitter | OCCTBOPAlgoSplitter | Splitter | Remove splitter | ✅ | ✅ |  |
| BOPAlgo_Tools Tests | OCCTBOPAlgoTools | BOPAlgo tools | Remove tools | ✅ | ✅ |  |
| BOPAlgo_BuilderSolid Tests | OCCTBOPAlgoBuilderSolid | Builder solid | Remove builder solid | ✅ | ✅ |  |
| LocOpe BuildShape Tests | OCCTLocOpeBuildShape | Build shape | Remove build shape | ✅ | ✅ |  |
| LocOpe FindEdges Tests | OCCTLocOpeFindEdges | Find edges | Remove find edges | ✅ | ✅ |  |
| FilletSurf_Builder Tests | OCCTFilletSurfBuilder | Fillet surf builder | Remove fillet surf | ✅ | ✅ |  |
| Integration: Thickness Analysis | OCCTIntegrationThicknessAnalysis | Thickness analysis | Remove thickness | ✅ | ✅ |  |
| Issue818 middlePath ground truth (#811) | OCCTIssue818MiddlePath | Middle path | Remove middle path | ✅ | ✅ |  |
| Simple Offset | OCCTSimpleOffset | Offset | Remove offset | ✅ | ✅ |  |
| BRepFill CompatibleWires Tests | OCCTBRepFillCompatibleWires | Compatible wires | Remove compatible wires | ✅ | ✅ |  |
| BRepFill AdvancedEvolved Tests | OCCTBRepFillAdvancedEvolved | Advanced evolved | Remove advanced evolved | ✅ | ✅ |  |
| Integration: Draft Analysis | OCCTIntegrationDraftAnalysis | Draft analysis | Remove draft analysis | ✅ | ✅ |  |
| BRepAlgo Loop Tests | OCCTBRepAlgoLoop | Loop tests | Remove loops | ✅ | ✅ |  |
| BOPAlgo FaceRestrictor Tests | OCCTBOPAlgoFaceRestrictor | Face restrictor | Remove face restrictor | ✅ | ✅ |  |
| Make Connected | OCCTMakeConnected | Connected | Remove connected | ✅ | ✅ |  |
| Linear Rib Feature | OCCTLinearRibFeature | Rib | Remove rib | ✅ | ✅ |  |
| Glue Tests | OCCTGlueTests | Glue | Remove glue | ✅ | ✅ |  |

---

## Bridge-Kernel Parity Checks

For each test, run ground-truth C++ comparison:
1. Write C++ test calling OCCT kernel directly
2. Run same inputs through Swift bridge
3. Compare outputs bit-for-bit (integers) or 1e-12 relative (doubles)
4. Document any discrepancies

---

## Progress Tracking

| Test | Red→Green Done | Parity Done | PR Ready |
|------|----------------|-------------|----------|
| BRepGProp Face Tests | ✅ | ✅ | ✅ |
| ShapeAnalysis_Edge Tests | ✅ | ✅ | ✅ |
| ShapeAnalysis_Wire Tests | ✅ | ✅ | ✅ |
| ShapeAnalysis_ShapeTolerance | ✅ | ✅ | ✅ |
| Advanced Healing Tests | ✅ | ✅ | ✅ |
| SAWireAnalysis.checkOuterBound (#1058) | ✅ | ✅ | ✅ |
| ShapeAnalysis FreeBoundsProperties | ✅ | ✅ | ✅ |
| Issue #446 unify mutation | ✅ | ✅ | ✅ |
| ShapeAnalysis_Curve Static | ✅ | ✅ | ✅ |
| Issue #570 healing approx | ✅ | ✅ | ✅ |
| ShapeAnalysis_Surface Tests | ✅ | ✅ | ✅ |
| ShapeExtend Explorer | ✅ | ✅ | ✅ |
| ShapeFix_Edge Extended | ✅ | ✅ | ✅ |
| Issue 772 self-intersection | ✅ | ✅ | ✅ |
| Issue #443 solid(from:) | ✅ | ✅ | ✅ |
| Issue #442 fixSolid/solidFromShell | ✅ | ✅ | ✅ |
| Issue 702 solid demotion | ✅ | ✅ | ✅ |
| ShapeAnalysis_FreeBounds Simplified | ✅ | ✅ | ✅ |
| Issue #484 Face.fixed ReShape | ✅ | ✅ | ✅ |
| ShapeUpgrade ConvertSurfacesToBezier | ✅ | ✅ | ✅ |
| ShapeUpgrade SplitCurve Tests | ✅ | ✅ | ✅ |
| Issue #870 ExtendShapeType fallback | ✅ | ✅ | ✅ |
| ShapeAnalysis Surface ValueOfUV | ✅ | ✅ | ✅ |
| Sewing Tests | ✅ | ✅ | ✅ |
| Shape Analysis Tests | ✅ | ✅ | ✅ |
| Shape Fixing Tests | ✅ | ✅ | ✅ |
| Self-Intersecting Profile Crash Guard (#263) | ✅ | ✅ | ✅ |
| Shape Measurements: cylinderTotalsAreFinite | ✅ | ✅ | ✅ |
| Sewing_Extras | ✅ | ✅ | ✅ |
| #837 fixed() mode-flag wiring | ✅ | ✅ | ✅ |
| ShapeUpgrade_SplitSurface | ✅ | ✅ | ✅ |
| ShapeFix_Wireframe Extension | ✅ | ✅ | ✅ |
| DetectPocketsAAG tolerance (#733) | ✅ | ✅ | ✅ |
| PocketFeature.isOpen (#753) | ✅ | ✅ | ✅ |
| Off-center enclosed pocket (#777) | ✅ | ✅ | ✅ |
| Prism Until Face | ✅ | ✅ | ✅ |
| Vertical corner-blend fillet (#762) | ✅ | ✅ | ✅ |
| Filleted through-slot (#762) | ✅ | ✅ | ✅ |
| Filleted box exterior edges (#762) | ✅ | ✅ | ✅ |
| LocOpe_Spliter v71 Tests | ✅ | ✅ | ✅ |
| PocketFeature.isOpen on compound (#1089) | ✅ | ✅ | ✅ |
| BiTgte Blend Tests | ✅ | ✅ | ✅ |
| Issue 572 forced-C1 sweep | ✅ | ✅ | ✅ |
| Prismatic Feature Tests | ✅ | ✅ | ✅ |
| Split Shape by Wire | ✅ | ✅ | ✅ |
| Boolean with History | ✅ | ✅ | ✅ |
| BRepOffset Offset Face | ✅ | ✅ | ✅ |
| Edge.split bounded by edge's own range (#1020) | ✅ | ✅ | ✅ |
| SEGV Guards, CellsBuilder empty | ✅ | ✅ | ✅ |
| Extended Extrusion | ✅ | ✅ | ✅ |
| BRepOffset SimpleOffset | ✅ | ✅ | ✅ |
| BOPAlgo Splitter | ✅ | ✅ | ✅ |
| BOPAlgo_Tools Tests | ✅ | ✅ | ✅ |
| BOPAlgo_BuilderSolid Tests | ✅ | ✅ | ✅ |
| LocOpe BuildShape Tests | ✅ | ✅ | ✅ |
| LocOpe FindEdges Tests | ✅ | ✅ | ✅ |
| FilletSurf_Builder Tests | ✅ | ✅ | ✅ |
| Integration: Thickness Analysis | ✅ | ✅ | ✅ |
| Issue818 middlePath ground truth (#811) | ✅ | ✅ | ✅ |
| Simple Offset | ✅ | ✅ | ✅ |
| BRepFill CompatibleWires Tests | ✅ | ✅ | ✅ |
| BRepFill AdvancedEvolved Tests | ✅ | ✅ | ✅ |
| Integration: Draft Analysis | ✅ | ✅ | ✅ |
| BRepAlgo Loop Tests | ✅ | ✅ | ✅ |
| BOPAlgo FaceRestrictor Tests | ✅ | ✅ | ✅ |
| Make Connected | ✅ | ✅ | ✅ |
| Linear Rib Feature | ✅ | ✅ | ✅ |
| Glue Tests | ✅ | ✅ | ✅ |

**Total**: 547 tests