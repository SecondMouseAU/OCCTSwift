//
//  OCCTBridge.h
//  OCCTSwift
//
//  Objective-C++ bridge to OpenCASCADE Technology
//

#ifndef OCCTBridge_h
#define OCCTBridge_h

// Suppress nullability-completeness warnings. This header mixes annotated and
// unannotated pointer declarations across ~17K lines. Full annotation would
// require changing thousands of lines and altering the Swift import surface.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnullability-completeness"

#import <Foundation/Foundation.h>

// MARK: - Continuity vocabularies
//
// Continuity crosses this boundary as a plain integer, and there are exactly three request
// vocabularies it can be speaking, plus one it is reported back in. Every declaration below that
// takes or returns one names which (#490/#495); the decoders live in one place,
// OCCTBridge_Internal.h, so a value cannot mean different things in different functions the way
// it did before #490 (see #433 for the bug that shipped from exactly that).
//
//   Surface continuity — geometric constraint order handed to a plate solver.
//     0=G0, 1=G1, 2=G2. Swift: `SurfaceContinuity`. Saturates at 2.
//
//   Parametric continuity — "make every piece at least Cn".
//     0=C0, 1=C1, 2=C2, 3=C3, and anything above asks for CN, the top of the same ladder.
//     Swift: `ParametricContinuity`. Not every consumer accepts the strict end: the
//     GeomConvert/Geom2dConvert Approx* family and ShapeCustom_BSplineRestriction fail the call
//     above C2, while the Split*Continuity and PointsToBSpline families take the whole range.
//
//   Analysis order — a GeomAbs_Shape class named by its own ordinal.
//     0=C0, 1=G1, 2=C1, 3=G2, 4=C2. What the LocalAnalysis_* junction analysers are asked to
//     check. Saturates at 4: those classes implement no predicate above C2/G2. It selects the
//     analysis, it is not just a ceiling — each order computes only its own branch (C0; C0+G1;
//     C0+C1; C0+G1+G2; C0+C1+C2), so a class the order does not cover is never measured and its
//     predicate answers true from an uninitialised member. occtAnalysisMeasuredMask names the
//     covered set and the *Flags functions report it. #495.
//
//   Measured class — a GeomAbs_Shape ordinal reported back as a *result*, 0=C0, 1=G1, 2=C1,
//     3=G2, 4=C2, 5=C3, 6=CN. Swift: `ContinuityClass`. The full seven-value form, unlike the
//     analysis order above, which shares the numbering but stops at 4. Spoken by
//     OCCTCurve3D/2D/SurfaceGetContinuity (#485) and OCCTBRepLibContinuityOfFaces.
//
// MARK: - OCCT Class Cross-Reference Index
//
// Maps OCCT C++ classes to their OCCTBridge function names.
// Use this to find the bridge function for any OCCT class you know.
// Generated from OCCTBridge.mm #include directives.
//
// --- HLRAppli ---
// HLRAppli_ReflectLines               → OCCTHLRReflectLines*
//
// --- Intrv ---
// Intrv_Interval                      → OCCTIntrvInterval*
// Intrv_Intervals                     → OCCTIntrvIntervals*
//
// --- TopCnx ---
// TopCnx_EdgeFaceTransition           → OCCTTopCnxEdgeFaceTransition*
//
// --- Adaptor2d/3d ---
// Adaptor2d_Curve2d                   → OCCTApproxCurve2d
// Adaptor3d_Curve                     → OCCTShapePlateCurves, OCCTShapePlateMixed
// Adaptor3d_IsoCurve                  → OCCTAdaptor3dIsoCurveEval
//
// --- Approx ---
// Approx_Curve2d                      → OCCTApproxCurve2d
// Approx_Curve3d                      → OCCTEdgeApproxCurve
// Approx_CurveOnSurface               → OCCTApproxCurveOnSurface
// Approx_CurvilinearParameter         → OCCTApproxCurvilinearParameter
//
// --- BOPAlgo ---
// BOPAlgo_ArgumentAnalyzer            → OCCTBOPAlgoAnalyzeArguments
// BOPAlgo_BuilderFace                 → OCCTBOPAlgoBuilderFace
// BOPAlgo_BuilderSolid                → OCCTBOPAlgoBuilderSolid
// BOPAlgo_CellsBuilder                → OCCTCellsBuilder* (the incremental builder; OCCTBOPAlgoSplit
//                                       drives BOPAlgo_Splitter, two entries down)
// BOPAlgo_CheckerSI                   → OCCTShapeSelfIntersects
// BOPAlgo_MakeConnected               → OCCTShapeMakeConnected
// BOPAlgo_MakePeriodic                → OCCTShapeMakePeriodic, OCCTShapeRepeat
// BOPAlgo_MakerVolume                 → OCCTShapeMakeVolume
// BOPAlgo_RemoveFeatures              → OCCTShapeDefeature, OCCTShapeRemoveFeatures,
//                                       OCCTShapeHistoryFromDefeature, OCCTShapeRemoveSmallFaces
//                                       (via BRepAlgoAPI_Defeaturing, a forwarder to it;
//                                       #536 deleted the direct wrap that duplicated them)
// BOPAlgo_Section                     → OCCTBOPAlgoSection
// BOPAlgo_ShellSplitter               → OCCTBOPAlgoShellSplitter
// BOPAlgo_Splitter                    → OCCTBOPAlgoSplit
// BOPAlgo_Tools                       → OCCTBOPAlgoEdgesToWires, OCCTBOPAlgoWiresToFaces
//
// --- BOPTools ---
// BOPTools_AlgoTools                  → OCCTBOPToolsIsOpenShell
// BOPTools_AlgoTools3D                → OCCTBOPToolsNormalOnEdge, OCCTBOPToolsPointInFace, OCCTBOPToolsIsEmptyShape
//
// --- BRepAlgoAPI ---
// BRepAlgoAPI_Check                   → OCCTShapeBooleanCheck
// BRepAlgoAPI_Common                  → OCCTShapeIntersect
// BRepAlgoAPI_Cut                     → OCCTShapeSubtract, OCCTShapeDrillHole
// BRepAlgoAPI_Defeaturing             → OCCTShapeRemoveFeatures, OCCTShapeDefeature,
//                                       OCCTShapeHistoryFromDefeature, OCCTShapeRemoveSmallFaces
// BRepAlgoAPI_Fuse                    → OCCTShapeUnion
// BRepAlgoAPI_Section                 → OCCTShapeSection, OCCTShapeSliceAtZ, OCCTSectionBuilder*
// BRepAlgoAPI_Splitter                → OCCTShapeSplit
//
// --- BRepBuilderAPI ---
// BRepBuilderAPI_Copy                 → OCCTShapeCopy
// BRepBuilderAPI_FastSewing           → OCCTShapeFastSewn
// BRepBuilderAPI_FindPlane            → OCCTShapeFindPlane
// BRepBuilderAPI_GTransform           → OCCTShapeNonUniformScale
// BRepBuilderAPI_MakeEdge             → OCCTWireCreate*, OCCTMakeEdgeFrom*, OCCTMakeEdgeOnSurface*
// BRepBuilderAPI_MakeEdge2d           → OCCTMakeEdge2d*
// BRepBuilderAPI_MakeFace             → OCCTMakeFace*, OCCTShapeCreateFace*
// BRepBuilderAPI_MakePolygon          → OCCTWireCreateFastPolygon
// BRepBuilderAPI_MakeShapeOnMesh      → OCCTShapeFromMesh
// BRepBuilderAPI_MakeShell            → OCCTShapeCreateShellFromSurface
// BRepBuilderAPI_MakeSolid            → OCCTShapeCreateSolidFromShell
// BRepBuilderAPI_MakeVertex           → OCCTShapeCreateVertex
// BRepBuilderAPI_MakeWire             → OCCTWireCreate*
// BRepBuilderAPI_NurbsConvert         → OCCTShapeConvertToNURBS
// BRepBuilderAPI_Sewing               → OCCTShapeSew
// BRepBuilderAPI_Transform            → OCCTShapeTranslate, OCCTShapeRotate, OCCTShapeScale, OCCTShapeMirror
//
// --- BRepCheck ---
// BRepCheck_Analyzer                  → OCCTShapeIsValid, OCCTShapeAnalyze, OCCTCheckShape*,
//                                       OCCTBRepCheckSubShapeValid
// BRepCheck_Edge/Face/Shell/Solid     → OCCTCheckFace, OCCTCheckSolid
//
// --- BRepExtrema ---
// BRepExtrema_DistShapeShape          → OCCTShapeDistance, OCCTShapeIntersects
// BRepExtrema_ExtCC                   → OCCTBRepExtremaExtCC
// BRepExtrema_ExtCF                   → OCCTBRepExtremaExtCF
// BRepExtrema_ExtFF                   → OCCTBRepExtremaExtFF
// BRepExtrema_ExtPC                   → OCCTBRepExtremaExtPC (for its extrema COUNT only since
//                                       #580; the distance/parameter/point come from
//                                       occtNearestPointOnCurveRange, because extrema exclude the
//                                       edge's ends and the one in range can be a maximum)
// BRepExtrema_ExtPF                   → OCCTBRepExtremaExtPF
// BRepExtrema_Poly                    → OCCTShapePolyhedralDistance
//
// --- BRepFeat ---
// BRepFeat_Builder                    → OCCTBRepFeatBuilderFuse, OCCTBRepFeatBuilderCut
// BRepFeat_Gluer                      → OCCTBRepFeatGluer
// BRepFeat_MakeCylindricalHole        → OCCTBRepFeatCylindricalHole*
// BRepFeat_MakeDPrism                 → OCCTShapeDraftPrism*
// BRepFeat_MakeLinearForm             → OCCTShapeAddLinearRib
// BRepFeat_MakePipe                   → OCCTShapePipeFeature*
// BRepFeat_MakePrism                  → OCCTShapePrismUntilFace
// BRepFeat_MakeRevol                  → OCCTShapeRevolFeature*
// BRepFeat_MakeRevolutionForm         → OCCTShapeAddRevolutionForm
// BRepFeat_SplitShape                 → OCCTBRepFeatSplitShape*
//
// --- BRepFill ---
// BRepFill_CompatibleWires            → OCCTBRepFillCompatibleWires
// BRepFill_Draft                      → OCCTBRepFillDraft
// BRepFill_Generator                  → OCCTBRepFillGenerator
// BRepFill_OffsetWire                 → OCCTBRepFillOffsetWire, OCCTBRepFillOffsetAncestors*
//                                       (OCCTWireOffset drives BRepOffsetAPI_MakeOffset, not this)
// BRepFill_Pipe                       → OCCTBRepFillPipe
// BRepFill_PipeShell                  → OCCTPipeShell* (the incremental builder — what
//                                       BRepOffsetAPI_MakePipeShell forwards to; #503)
//
// --- BRepFilletAPI ---
// BRepFilletAPI_MakeChamfer           → OCCTShapeChamfer*
// BRepFilletAPI_MakeFillet            → OCCTShapeFillet*, OCCTShapeBlendEdges, OCCTShapeFuseAndBlend, OCCTShapeCutAndBlend, OCCTFilletBuilder*
// BRepFilletAPI_MakeFillet2d          → OCCTFace2DFillet, OCCTFace2DChamfer
//
// --- BRepGProp ---
// BRepGProp                           → OCCTShapeGetVolume, OCCTShapeGetSurfaceArea,
//                                       OCCTEdgeGetLength, OCCTFaceGetArea, OCCTShapeAnalyze
//                                       (OCCTShapeGetCenterOfMass does NOT use BRepGProp — it
//                                       returns the bounding-box centre via BRepBndLib; #605)
// BRepGProp_Face                      → OCCTBRepGPropFace*, OCCTFaceGetNaturalBounds, OCCTFaceEvaluateNormalAtUV
// BRepGProp_MeshCinert                → OCCTMeshCinert*
// BRepGProp_MeshProps                 → OCCTMeshProps*
//
// --- BRepIntCurveSurface ---
// BRepIntCurveSurface_Inter           → OCCTCurveSurfaceInter*
//
// --- BRepLib ---
// BRepLib_MakeEdge                    → OCCTBRepLibMakeEdge*
// BRepLib_MakeFace                    → OCCTBRepLibMakeFace*
// BRepLib_MakeShell                   → OCCTBRepLibMakeShellFromPlane
// BRepLib_MakeSolid                   → OCCTShapeMakeSolidFromShell
// BRepLib_ValidateEdge                → OCCTValidateEdge
//
// --- BRepMesh ---
// BRepMesh_Deflection                 → OCCTComputeAbsoluteDeflection, OCCTDeflectionIsConsistent
// BRepMesh_IncrementalMesh            → OCCTShapeCreateMesh*
// BRepMesh_ShapeTool                  → OCCTMeshShapeTool*
//
// --- BRepOffset ---
// BRepOffset_Analyse                  → OCCTAnalyse*, OCCTShapeAnalyzeEdgeConcavity,
//                                       OCCTShapeCountEdgeConcavity (OCCTEdgeGetConvexity is a
//                                       DIFFERENT edge-convexity classifier, ChFi3d::DefineConnectType,
//                                       not this class; see the ChFi3d entry below, #723)
// BRepOffset_MakeOffset               → OCCTShapeOffsetPerFace
// BRepOffset_MakeSimpleOffset         → OCCTShapeSimpleOffset
// BRepOffset_Offset                   → OCCTBRepOffsetOffsetFace
// BRepOffset_SimpleOffset             → OCCTBRepOffsetSimpleOffset
//
// --- BRepOffsetAPI ---
// BRepOffsetAPI_DraftAngle            → OCCTShapeDraft
// BRepOffsetAPI_MakeDraft             → OCCTShapeMakeDraft
// BRepOffsetAPI_MakeEvolved           → OCCTShapeCreateEvolved, OCCTShapeCreateEvolvedAdvanced
// BRepOffsetAPI_MakeFilling           → OCCTShapeFill* (Shape.fill), OCCTFilling*
//                                       (FillingSurface) — one implementation, #434
// BRepOffsetAPI_MakeOffset            → OCCTWireOffset, OCCTWireMultiOffset, OCCTOffsetWireOnPlane,
//                                       OCCTOffsetFace
// BRepOffsetAPI_MakeOffsetShape       → OCCTShapeOffset, OCCTShapeOffsetByJoin
// BRepOffsetAPI_MakePipe              → OCCTShapeCreatePipeSweep (OCCTShapePipeFeature* is
//                                       BRepFeat_MakePipe)
// BRepOffsetAPI_MakePipeShell         → OCCTShapeCreatePipeShellMultiSection (every
//                                       Add() sweep, one profile or many),
//                                       OCCTShapeCreatePipeShellWithLaw (SetLaw). #503
//                                       (the OCCTPipeShell* incremental builder drives
//                                       BRepFill_PipeShell directly — see that entry)
// BRepOffsetAPI_MakeThickSolid        → OCCTShapeShell*, OCCTShapeMakeThickSolid, OCCTThickSolidWithOptions,
//                                       OCCTShapeHistoryFromShell
// BRepOffsetAPI_ThruSections          → OCCTShapeCreateLoft*, OCCTThruSections*
//
// --- BRepPrimAPI ---
// BRepPrimAPI_MakeBox                 → OCCTShapeCreateBox*
// BRepPrimAPI_MakeCone                → OCCTShapeCreateCone
// BRepPrimAPI_MakeCylinder            → OCCTShapeCreateCylinder*, OCCTShapeDrillHole
// BRepPrimAPI_MakeHalfSpace           → OCCTShapeCreateHalfSpace
// BRepPrimAPI_MakePrism               → OCCTShapeCreateExtrusion
// BRepPrimAPI_MakeRevol               → OCCTShapeCreateRevolution*
// BRepPrimAPI_MakeSphere              → OCCTShapeCreateSphere
// BRepPrimAPI_MakeTorus               → OCCTShapeCreateTorus
// BRepPrimAPI_MakeWedge               → OCCTShapeCreateWedge
//
// --- BRepTools ---
// BRepTools_Modifier                  → OCCTBRepToolsModifierNurbsConvert, OCCTBRepOffsetSimpleOffset, OCCTShapeCopyModification, OCCTShapeTrsfModification, OCCTShapeGTrsfModification, OCCTShapeDraftModification
// BRepTools_ReShape                   → OCCTShapeReplaceSubShape*
// BRepTools_Substitution              → OCCTBRepToolsSubstitute, OCCTShapeSubstitute, OCCTSubstitutionIsCopied
// BRepTools_WireExplorer              → OCCTWireExplorer*
//
// --- ChFi2d ---
// ChFi2d_AnaFilletAlgo                → OCCTChFi2dAnaFillet
// ChFi2d_Builder                      → OCCTChFi2dAdd*, OCCTChFi2dModify*, OCCTChFi2dRemove*
// ChFi2d_ChamferAPI                   → OCCTChFi2dChamferEdges
// ChFi2d_FilletAlgo                   → OCCTChFi2dFilletAlgo
// ChFi2d_FilletAPI                    → OCCTChFi2dFilletEdges
//
// --- ChFi3d ---
// ChFi3d                               → OCCTEdgeGetConvexity (ChFi3d::DefineConnectType, the same
//                                       static facade the 3D fillet/chamfer builder itself calls
//                                       to classify an edge; not the ChFi3d_Builder that actually
//                                       builds the fillet, which BRepFilletAPI_MakeFillet reaches
//                                       instead and is not wrapped directly here, #723)
//
// --- FilletSurf ---
// FilletSurf_Builder                  → OCCTFilletSurfBuild, OCCTFilletSurfError
//
// --- Contap ---
// Contap_ContAna                      → OCCTContapSphereDir, OCCTContapCylinderDir, OCCTContapSphereEye
// Contap_Contour                      → OCCTContapContour*
//
// --- CPnts ---
// CPnts_UniformDeflection             → OCCTCPntsUniformDeflection*
//
// --- GC ---
// GC_MakeArcOfCircle                  → OCCTCurve3DCreateArcOfCircle, OCCTWireCreateArcThroughPoints
// GC_MakeCircle                       → OCCTGCMakeCircle*
// GC_MakeEllipse                      → OCCTGCMakeEllipse3Points
// GC_MakeHyperbola                    → OCCTGCMakeHyperbola3Points
// GC_MakeMirror                       → OCCTShapeMirrorAboutAxis, OCCTShapeMirrorAboutPoint
// GC_MakeScale                        → OCCTShapeScaleAboutPoint
// GC_MakeSegment                      → OCCTCurve3DCreateSegment
// GC_MakeTranslation                  → OCCTShapeTranslateByPoints
//
// --- GC 2D ---
// GC_MakeCircle2d                     → OCCTCurve2DMakeCircle*
// GC_MakeEllipse2d                    → OCCTCurve2DMakeEllipse*
// GC_MakeHyperbola2d                  → OCCTCurve2DMakeHyperbola*
// GC_MakeLine2d                       → OCCTCurve2DMakeLine*
// GC_MakeParabola2d                   → OCCTCurve2DMakeParabola*
//
// --- GCPnts ---
// GCPnts_AbscissaPoint                → OCCTCurve3DGetLength*, OCCTCurve3DParameterAtLength,
//                                       OCCTCurve2DGetLength*, OCCTCurve2DParameterAtLength,
//                                       OCCTEdgeArcLength*, OCCTEdgeParameterAt*, OCCTWireGetLength
//                                       (three further spellings were deleted by #506/#549; their
//                                       tombstones sit at the old declaration sites. None of the
//                                       seven names the class any more: since #603 they all reach
//                                       it through the shared helpers, so grep those, not the
//                                       class. Three sites construct it: occtArcQuadrature's
//                                       single-span branch, occtArcWalkToLength's final piece,
//                                       and occtAdaptorParameterAtLength's fallback solver)
// CPnts_AbscissaPoint                 → the same functions, as occtArcQuadrature's per-span integrator on composite curves (#603)
// GCPnts_QuasiUniformAbscissa         → OCCTCurve3DQuasiUniformAbscissa, OCCTGCPntsQuasiUniform
// GCPnts_QuasiUniformDeflection       → OCCTCurve3DQuasiUniformDeflection
// GCPnts_TangentialDeflection         → OCCTGCPntsTangentialDeflection*, OCCTCurve3DDrawAdaptive, OCCTCurve2DDrawAdaptive
// GCPnts_UniformAbscissa              → OCCTUniformAbscissaBy*, OCCTCurve3DDrawUniform, OCCTCurve2DDrawUniform, OCCTCompCurveSampleUniform, OCCTEdgeCurveSampleUniform
// GCPnts_UniformDeflection            → OCCTCurve3DDrawDeflection, OCCTCurve2DDrawDeflection
//
// --- GccAna ---
// GccAna_Circ2d2TanOn                 → OCCTGccAnaCirc2d2TanOn*
// GccAna_Circ2d2TanRad                → OCCTGccAnaCirc2d2TanRad*
// GccAna_Circ2dTanCen                 → OCCTGccAnaCirc2dTanCen*
// GccAna_Circ2dTanOnRad               → OCCTGccAnaCirc2dTanOnRad*
// GccAna_Lin2dBisec                   → OCCTGccAnaLin2dBisec
// GccAna_Lin2dTanObl                  → OCCTGccAnaLin2dTanOblPt
// GccAna_Lin2dTanPar                  → OCCTGccAnaLin2dTanPar*
// GccAna_Lin2dTanPer                  → OCCTGccAnaLin2dTanPer*
// GccAna_Circ2d3Tan                   → OCCTGccAnaCirc2d3Tan* (v0.68.0)
// GccAna_Pnt2dBisec                   → OCCTGccAnaPnt2dBisec
//
// --- Geom ---
// Geom_BSplineCurve                   → OCCTCurve3D*, OCCTSurface*
// Geom_BSplineSurface                 → OCCTSurface*
// Geom_BezierCurve                    → OCCTCurve3DBezier*, OCCTCurve3DCreateBezier
// Geom_BezierSurface                  → OCCTSurface*
// Geom_Circle                         → OCCTCurve3DCircle*, OCCTCurve3DCreateCircle, OCCTGceMakeCircFrom*
// Geom_ConicalSurface                 → OCCTSurfaceCone*
// Geom_CylindricalSurface             → OCCTSurfaceCylinder*
// Geom_Ellipse                        → OCCTCurve3DEllipse*
// Geom_Hyperbola                      → OCCTCurve3DHyperbola*
// Geom_Line                           → OCCTCurve3DLine*, OCCTCurve3DCreateLine, OCCTGceMakeLinFrom2Points
// Geom_OffsetSurface                  → OCCTSurfaceOffset, OCCTSurfaceOffsetValue, OCCTSurfaceSetOffsetValue, OCCTSurfaceOffsetBasis (v0.99.0)
// Geom_Parabola                       → OCCTCurve3DParabola*
// Geom_Plane                          → OCCTSurfacePlane*
// Geom_SphericalSurface               → OCCTSurfaceSphere*, OCCTSurfaceCreateSphere
// Geom_SurfaceOfLinearExtrusion       → OCCTSurfaceCreateExtrusion, OCCTFaceGetPrimaryAxis
// Geom_SurfaceOfRevolution            → OCCTSurfaceRevolution*, OCCTSurfaceCreateRevolution, OCCTShapeRevolutionAxes
// Geom_ToroidalSurface                → OCCTSurfaceTorus*, OCCTSurfaceCreateTorus
// Geom_TrimmedCurve                   → OCCTCurve3DTrim
//
// --- Geom2d ---
// Geom2d_AxisPlacement                → OCCTAxisPlacement2D*
// Geom2d_BSplineCurve                 → OCCTCurve2D*
// Geom2d_BezierCurve                  → OCCTCurve2DBezier*, OCCTCurve2DCreateBezier
// Geom2d_CartesianPoint               → OCCTPoint2D*
// Geom2d_Circle                       → OCCTCurve2DCircle*, OCCTCurve2DCreateCircle, OCCTCurve2DCreateArcOfCircle,
//                                       OCCTGceMakeCirc2d*
// Geom2d_Ellipse                      → OCCTCurve2DEllipse*
// Geom2d_Hyperbola                    → OCCTCurve2DHyperbola*, OCCTCurve2DCreateHyperbola,
//                                       OCCTCurve2DCreateArcOfHyperbola, OCCTGceMakeHypr2d
// Geom2d_Line                         → OCCTCurve2DLine*, OCCTCurve2DCreateLine, OCCTCurve2DSegmentFromPoints,
//                                       OCCTGceMakeLin2d*
// Geom2d_OffsetCurve                  → OCCTCurve2DOffset
// Geom2d_Parabola                     → OCCTCurve2DParabola*, OCCTCurve2DCreateParabola,
//                                       OCCTCurve2DCreateArcOfParabola, OCCTGceMakeParab2d
// Geom2d_Transformation               → OCCTTransform2D*
// Geom2d_TrimmedCurve                 → OCCTCurve2DTrim
//                                       (Geom2d_Direction and Geom2d_VectorWithMagnitude are not
//                                       wrapped — OCCTDirection2D*/OCCTVector2D* are gp_Dir2d/
//                                       gp_Vec2d arithmetic; see docs/occtswift-wrapping-gaps.md)
//
// --- Geom2dAPI ---
// Geom2dAPI_ExtremaCurveCurve         → OCCTCurve2DMinDistance, OCCTCurve2DAllExtrema
// Geom2dAPI_InterCurveCurve           → OCCTCurve2DIntersect, OCCTCurve2DSelfIntersect
// Geom2dAPI_Interpolate               → OCCTCurve2DInterpolate*
// Geom2dAPI_PointsToBSpline           → OCCTCurve2DFitPoints, OCCTCurve2DApproximate2D,
//                                        OCCTPoints2DToBSplineWithParams
// Geom2dAPI_ProjectPointOnCurve       → OCCTCurve2DProjectPoint, OCCTCurve2DProjectPointAll,
//                                       OCCTCurve2DProjectPoint2D, OCCTPoint2DDistanceToCurve,
//                                       OCCTCurve2DNearestParameter
//                                       (all but OCCTCurve2DProjectPointAll only as one of the two
//                                       candidate sources occtNearestPointOnCurve2dRange takes a
//                                       minimum over, the other being the curve's own two ends;
//                                       there is no 2D ShapeAnalysis_Curve to be the third, see
//                                       #615. OCCTCurve2DProjectPointAll wants the extrema
//                                       themselves and constructs its own)
//
// --- Geom2dGcc ---
// Geom2dGcc_Circ2d2TanOn              → OCCTGeom2dGccCirc2d2TanOn*
// Geom2dGcc_Circ2d2TanRad             → OCCTGccCircle2d2TanRad, OCCTGccCircle2dTanPtRad, OCCTGccCircle2d2PtRad
// Geom2dGcc_Circ2dTanCen              → OCCTGccCircle2dTanCen
// Geom2dGcc_Circ2dTanOnRad            → OCCTGeom2dGccCirc2dTanOnRad*
// Geom2dGcc_Lin2d2Tan                 → OCCTGccLine2d2Tan, OCCTGccLine2dTanPt
// Geom2dGcc_Lin2dTanObl               → OCCTGeom2dGccLin2dTanObl*
//
// --- Geom2dHatch ---
// Geom2dHatch_Hatcher                 → OCCTCurve2DHatch
//
// --- GeomAPI ---
// GeomAPI_ExtremaCurveCurve           → OCCTCurve3DMinDistanceToCurve, OCCTCurve3DExtrema
// GeomAPI_ExtremaCurveSurface         → OCCTCurve3DDistanceToSurface
// GeomAPI_ExtremaSurfaceSurface       → OCCTSurfaceExtrema
// GeomAPI_IntCS                       → OCCTCurve3DIntersectSurface
// GeomAPI_IntSS                       → OCCTSurfaceSurfaceIntersect
// GeomAPI_PointsToBSpline             → OCCTCurve3DFitPoints, OCCTPointsToBSplineWithParams,
//                                        OCCTPointsToBSplineWithParameters, OCCTWireCreateBSpline,
//                                        OCCTBSplineApproxInterp* (that family keeps the C ABI of
//                                        Approx_BSplineApproxInterp, removed in OCCT 8.0.0p1, and
//                                        is backed by this class; see its section for the no-ops)
// GeomAPI_PointsToBSplineSurface      → OCCTPointsToSurfaceBSpline, OCCTSurfaceNLPlateG0,
//                                        OCCTSurfaceNLPlateG1, OCCTSurfaceNLPlateG2,
//                                        OCCTSurfaceNLPlateG3, OCCTSurfaceNLPlateIncrementalG0
//                                        (NOT OCCTSurfacePlateThrough; see GeomPlate)
// GeomAPI_ProjectPointOnCurve         → OCCTCurve3DNearestParameter, OCCTExtremaLocateOnCurve,
//                                       OCCTExtremaPointCurve, OCCTProjOnCurve*,
//                                       OCCTEdgeProjectPoint, OCCTCurve3DProjectPoint,
//                                       OCCTBRepExtremaExtPC
//                                       (all but OCCTExtremaPointCurve and OCCTProjOnCurve* only as
//                                       one of the three candidate sources
//                                       occtNearestPointOnCurveRange takes a minimum over; see
//                                       ShapeAnalysis_Curve for the second, the curve's own two
//                                       ends for the third, and #539 for why neither class answers
//                                       correctly on its own. OCCTExtremaLocateOnCurve reaches it
//                                       only through its full-range fallback -- its primary local
//                                       window search is a bare GeomAPI extremum by design, #615)
// GeomAPI_ProjectPointOnSurf          → OCCTSurfaceProjectPoint, OCCTFaceProject*
//
// --- GeomConvert ---
// GeomConvert                         → OCCTCurve3DToBSpline, OCCTCurve3DBSplineToBeziers, OCCTCurve3DSplitAtContinuity,
//                                       OCCTSurfaceToBSpline, OCCTSurfaceToBezierPatches
// GeomConvert_BSplineCurveKnotSplitting → OCCTCurve3DBSplineKnotSplits (the sole wrapper; #562)
// GeomConvert_BSplineSurfaceKnotSplitting → OCCTSurfaceKnotSplitting (the sole wrapper since #562
//                                       deleted the second family that wrapped it)
// GeomConvert_CompCurveToBSplineCurve → OCCTCurve3DJoinCurves, OCCTCurve3DJoinToBSpline,
//                                       OCCTCurve3DConcatenateG1, OCCTConcatenateCurves3D
// GeomConvert_CurveToAnaCurve         → OCCTGeomConvertCurveToAnalytical, OCCTGeomConvertIsLinear
// GeomConvert_SurfToAnaSurf           → OCCTGeomConvertSurfToAnalytical*, OCCTGeomConvertIsCanonical
//
// --- Geom2dConvert ---
// #562: this section did not exist, which is half of why Geom2dConvert_BSplineCurveKnotSplitting
// could be wrapped twice without anything noticing. Census is by call site in OCCTBridge_Geom2d.mm.
// Geom2dConvert                       → OCCTCurve2DToBSpline, OCCTCurve2DSplitAtContinuity,
//                                       OCCTCurve2DJoinToBSpline
// Geom2dConvert_ApproxArcsSegments    → OCCTGeom2dConvertApproxArcsSegments, OCCTCurve2DToArcsAndSegments
// Geom2dConvert_ApproxCurve           → OCCTCurve2DApproximate
// Geom2dConvert_BSplineCurveKnotSplitting → OCCTCurve2DSplitAtDiscontinuities (the sole wrapper
//                                       since #562 deleted the second family that wrapped it)
// Geom2dConvert_BSplineCurveToBezierCurve → OCCTCurve2DBSplineToBeziers
// Geom2dConvert_CompCurveToBSplineCurve → OCCTConcatenateCurves2D, OCCTCurve2DJoinToBSpline
//
// --- Convert ---
// Convert_CompBezierCurvesToBSplineCurve   → OCCTConvertCompBezierToBSpline (v0.99.0)
// Convert_CompBezierCurves2dToBSplineCurve2d → OCCTConvertCompBezier2dToBSpline2d (v0.99.0)
//
// --- GeomFill ---
// GeomFill_BSplineCurves              → OCCTSurfaceFillBSpline2Curves, OCCTSurfaceFillBSpline4Curves
// GeomFill_BezierCurves               → OCCTSurfaceBezierFill*
// GeomFill_ConstrainedFilling         → OCCTGeomFillConstrained
// GeomFill_Coons                      → OCCTGeomFillCoonsPoles
// GeomFill_CoonsAlgPatch              → OCCTGeomFillCoonsAlgPatchEval
// GeomFill_CorrectedFrenet            → OCCTGeomFillCorrectedFrenet
// GeomFill_Curved                     → OCCTGeomFillCurvedPoles
// GeomFill_DiscreteTrihedron          → OCCTGeomFillDiscreteTrihedron
// GeomFill_ConstantBiNormal           → OCCTGeomFillConstantBiNormalTrihedron (v0.68.0)
// GeomFill_Darboux                    → OCCTGeomFillDarbouxTrihedron (v0.68.0)
// GeomFill_DraftTrihedron             → OCCTGeomFillDraftTrihedron
// GeomFill_EvolvedSection             → OCCTGeomFillEvolvedSectionInfo
// GeomFill_Fixed                      → OCCTGeomFillFixedTrihedron (v0.68.0)
// GeomFill_Frenet                     → OCCTGeomFillFrenetTrihedron (v0.68.0)
// GeomFill_NSections                  → OCCTGeomFillNSections (v0.68.0)
// GeomFill_Generator                  → OCCTGeomFillGenerator (v0.69.0)
// GeomFill_DegeneratedBound           → OCCTGeomFillDegeneratedBoundValue,
//                                       OCCTGeomFillDegeneratedBoundIsDegenerated (v0.69.0)
// GeomFill_BoundWithSurf              → OCCTGeomFillBoundWithSurfEvaluate (v0.69.0)
// GeomFill_Pipe                       → OCCTSurfaceCreatePipe, OCCTSurfaceCreatePipeWithSection
// GeomFill_SimpleBound                → OCCTGeomFillConstrained, OCCTGeomFillCoonsAlgPatchEval
// GeomFill_Sweep                      → OCCTGeomFillSweep
//
// --- GeomInt ---
// GeomInt_IntSS                       → OCCTGeomIntSS*
//
// --- GeomLProp ---
// GeomLProp_CLProps                   → OCCTGeomLPropCLProps, OCCTCurve3DGetCurvature, OCCTCurve3DGetTangent,
//                                       OCCTCurve3DGetNormal, OCCTCurve3DGetCenterOfCurvature,
//                                       OCCTCurve3DLocal*, OCCTEdgeGetCurvature3D, OCCTEdgeGetTangent3D,
//                                       OCCTEdgeGetNormal3D, OCCTEdgeGetCenterOfCurvature3D
// GeomLProp_SLProps                   → OCCTGeomLPropSLProps, OCCTFaceGetNormalAtUV, OCCTFaceGetGaussianCurvature,
//                                       OCCTFaceGetMeanCurvature, OCCTFaceGetPrincipalCurvatures,
//                                       OCCTSurfaceGetNormal, OCCTSurfaceGetPrincipalCurvatures,
//                                       OCCTSurfaceLocalCurvatures, OCCTSurfaceLocalCurvatureDirections
//
// --- GeomPlate ---
// GeomPlate_BuildPlateSurface         → OCCTShapePlate*, OCCTGeomPlateSurface, OCCTSurfacePlateThrough
// GeomPlate_BuildAveragePlane         → OCCTGeomPlateBuildAveragePlane (v0.69.0)
// GeomPlate_MakeApprox                → OCCTShapePlate*, OCCTGeomPlateSurface, OCCTSurfacePlateThrough
//
// --- IntAna2d ---
// IntAna2d_AnaIntersection            → OCCTIntAna2d*
//
// --- IntCurvesFace ---
// IntCurvesFace_Intersector           → OCCTIntersectLineFace
// IntCurvesFace_ShapeIntersector      → OCCTIntCurvesFaceShapeIntersect*, OCCTShapeRaycast
//
// --- IntTools ---
// IntTools_BeanFaceIntersector        → OCCTIntToolsBeanFaceIntersect
// IntTools_EdgeEdge                   → OCCTIntToolsEdgeEdge
// IntTools_EdgeFace                   → OCCTIntToolsEdgeFace
// IntTools_FaceFace                   → OCCTIntToolsFaceFace
// IntTools_FClass2d                   → OCCTIntToolsFClass2d*
//
// --- Law ---
// Law_BSpFunc                         → OCCTLawCreateBSpline, OCCTLawInterpolate
// Law_BSpline                         → OCCTLawCreateBSpline, OCCTLawInterpolate, OCCTLawBSplineKnotSplit*
// Law_Constant                        → OCCTLawCreateConstant
// Law_Interpol                        → OCCTLawCreateInterpolate
// Law_Interpolate                     → OCCTLawInterpolate (a different class from Law_Interpol,
//                                       one letter apart, driven by a different bridge function)
// Law_Linear                          → OCCTLawCreateLinear
// Law_S                               → OCCTLawCreateS
// Law_BSplineKnotSplitting            → OCCTLawBSplineKnotSplitting (v0.68.0)
// Law_Composite                       → OCCTLawComposite (v0.68.0)
//
// --- Intf ---
// Intf_InterferencePolygon2d          → OCCTIntfInterferencePolygon2d (v0.68.0)
//
// --- LocOpe ---
// LocOpe_BuildShape                   → OCCTLocOpeBuildShape
// LocOpe_CSIntersector                → OCCTLocOpeCSIntersectLine
// LocOpe_DPrism                       → OCCTLocOpeDPrism
// LocOpe_FindEdges                    → OCCTLocOpeFindEdges
// LocOpe_FindEdgesInFace              → OCCTLocOpeFindEdgesInFace
// LocOpe_Gluer                        → OCCTLocOpeGlue
// LocOpe_LinearForm                   → OCCTLocOpeLinearForm
// LocOpe_Pipe                         → OCCTLocOpePipe
// LocOpe_Prism                        → OCCTLocOpePrism
// LocOpe_Revol                        → OCCTLocOpeRevol
// LocOpe_RevolutionForm               → OCCTLocOpeRevolutionForm
// LocOpe_SplitDrafts                  → OCCTLocOpeSplitDrafts
// LocOpe_SplitShape                   → OCCTLocOpeSplitShape*
// LocOpe_Spliter                      → OCCTLocOpeSplitByWire*
// LocOpe_WiresOnShape                 → OCCTLocOpeBuildWires, OCCTLocOpeSplitByWire*
//
// --- LProp ---
// LProp_CurAndInf                     → OCCTLPropAnalyticCurInf (which fills a LProp_CurAndInf from
//                                       an inline scan — LProp_AnalyticCurInf itself is not wrapped)
//
// --- NLPlate ---
// NLPlate_NLPlate                     → OCCTSurfaceNLPlate*
// NLPlate_HPG0G2Constraint            → OCCTSurfaceNLPlateG2
// NLPlate_HPG0G3Constraint            → OCCTSurfaceNLPlateG3
//
// --- OSD ---
// OSD_Environment                     → OCCTEnvironment*
// OSD_Path                            → OCCTOSDPath* (the only path-parsing family; #499 deleted
//                                       the TDocStd_PathParser one that duplicated it)
//
// --- Plate ---
// Plate_Plate                         → OCCTPlate*
// Plate_PinpointConstraint            → OCCTPlateLoadPinpoint
// Plate_GtoCConstraint                → OCCTPlateLoadGtoC
//
// --- ProjLib ---
// ProjLib_ComputeApprox               → OCCTProjLibComputeApprox
// ProjLib_ComputeApproxOnPolarSurface → OCCTProjLibComputeApproxOnPolarSurface
//
// --- ShapeAnalysis ---
// ShapeAnalysis_Curve                 → OCCTCurve3DProjectPoint, OCCTCurve3DValidateRange,
//                                       OCCTCurve3DGetSamplePoints3D, OCCTCurve3DIsClosedWithPreci,
//                                       OCCTCurve3DIsPeriodicSA, OCCTEdgeProjectPoint,
//                                       OCCTBRepExtremaExtPC
//                                       (the three projection entry points reach ::Project through
//                                       occtNearestPointOnCurveRange, which does not trust its
//                                       answer alone; see GeomAPI_ProjectPointOnCurve)
// ShapeAnalysis_FreeBounds            → OCCTShapeFreeBounds, OCCTShapeFreeBoundsClosedCount,
//                                       OCCTShapeFreeBoundsClosed, OCCTShapeFreeBoundsOpen
// ShapeAnalysis_FreeBoundsProperties  → OCCTFreeBoundsProps* (one family since #504; the stateless
//                                       OCCTFreeBounds* family was a second wrapping of the same
//                                       class and is gone)
// ShapeAnalysis_Surface               → OCCTSurfaceProjectPointUV*, OCCTSurfaceProjectDegenerated,
//                                       OCCTSurfaceValueOfUV, OCCTSurfaceNextValueOfUV, OCCTSurfaceUVFromIso,
//                                       OCCTSurfaceSingularity*, OCCTSurfaceHasSingularities,
//                                       OCCTSurfaceNbSingularities, OCCTSurfaceIsDegenerated,
//                                       OCCTSurfaceIsUClosedSA, OCCTSurfaceIsVClosedSA
// ShapeAnalysis_TransferParametersProj → OCCTShapeAnalysisTransferParam*
// ShapeAnalysis_Wire                  → OCCTWireAnalyze, OCCTWireAnalyzer*,
//                                       OCCTWireCheck* (including OCCTWireCheckOuterBound),
//                                       OCCTWireEdgeCount, OCCTWireMinDistance*, OCCTWireMaxDistance*,
//                                       OCCTShapeAnalyze
// ShapeAnalysis_WireOrder             → OCCTWireOrderAnalyze, OCCTWireOrderAnalyzeWire
//
// --- ShapeBuild ---
// ShapeBuild_Edge                     → OCCTShapeBuildEdge*
// ShapeBuild_Vertex                   → OCCTShapeBuildVertex*
//
// --- ShapeConstruct ---
// ShapeConstruct_MakeTriangulation    → OCCTShapeConstructTriangulation*
//
// --- ShapeCustom ---
// ShapeCustom_BSplineRestriction      → OCCTShapeBSplineRestriction*
// ShapeCustom_Curve2d                 → OCCTCurve2DIsLinear, OCCTCurve2DConvertToLine, OCCTCurve2DSimplifyBSpline
// ShapeCustom_DirectModification      → OCCTShapeCustomDirectModification
// ShapeCustom_Surface                 → OCCTSurfaceConvertToAnalytical, OCCTSurfaceConvertToPeriodic, OCCTSurfaceConversionGap
// ShapeCustom_SweptToElementary       → OCCTShapeSweptToElementary
// ShapeCustom_TrsfModification        → OCCTShapeCustomTrsfModificationScale
//
// --- ShapeExtend ---
// ShapeExtend_Explorer                → OCCTShapeExtendSortedCompound, OCCTShapeExtendShapeType
//
// --- ShapeFix ---
// ShapeFix_Edge                       → OCCTShapeFixEdge*
// ShapeFix_Face                       → OCCTFaceFix, OCCTFaceFixer*, OCCTShapeCreateFaceFromSurfaceWire, OCCTShapeCreateFaceFromSurfaceWireWithHoles
// ShapeFix_FaceConnect                → OCCTShapeFixFaceConnect
// ShapeFix_FixSmallFace               → OCCTShapeFixSmallFaces
// ShapeFix_FixSmallSolid              → OCCTShapeFixRemoveSmallSolids, OCCTShapeFixMergeSmallSolids
// ShapeFix_Shape                      → OCCTShapeFixDetailed, OCCTShapeFixer*, OCCTShapeHeal*, OCCTShapeSimplify,
//                                       OCCTShapeUpgrade, OCCTImportSTEPRobust*, OCCTImportSTEPWithDiagnostics,
//                                       OCCTImportIGESRobust*, OCCTImportSTLRobust
// ShapeFix_ShapeTolerance             → OCCTShapeFixLimitTolerance, OCCTShapeFixSetTolerance,
//                                       OCCTShapeFixTolerance, OCCTShapeLimitMaxTolerance
// ShapeFix_SplitCommonVertex          → OCCTShapeFixSplitCommonVertex
// ShapeFix_Wire                       → OCCTWireFix, OCCTWireFixer* (OCCTShapeFixWire* is the two
//                                       entries below: ShapeFix_WireVertex and ShapeFix_Wireframe)
// ShapeFix_WireVertex                 → OCCTShapeFixWireVertex
// ShapeFix_Wireframe                  → OCCTShapeFixWireframe, OCCTShapeFixWireGaps, OCCTShapeFixSmallEdges (v0.99.0)
//
// --- ShapeUpgrade ---
// ShapeUpgrade_ConvertCurve3dToBezier → OCCTShapeUpgradeConvertCurves3dToBezier
//                                       (via ShapeUpgrade_ShapeConvertToBezier, the shape-level
//                                       driver that owns it; no direct wrap)
// ShapeUpgrade_ConvertSurfaceToBezierBasis → OCCTShapeUpgradeConvertSurfaceToBezier
//                                       (via ShapeUpgrade_ShapeConvertToBezier, as above)
// ShapeUpgrade_FixSmallBezierCurves   → OCCTShapeUpgradeFixSmallBezierCurves
// ShapeUpgrade_FixSmallCurves         → OCCTShapeUpgradeFixSmallCurves
// ShapeUpgrade_ShapeConvertToBezier   → OCCTShapeConvertToBezier,
//                                       OCCTShapeUpgradeConvertCurves3dToBezier,
//                                       OCCTShapeUpgradeConvertSurfaceToBezier
// ShapeUpgrade_ShapeDivideClosed      → OCCTShapeUpgradeDivideClosed
// ShapeUpgrade_ShapeDivideContinuity  → OCCTShapeDivide (#438 folded a second, narrower entry
//                                       point into this one; see OCCTBridge_Healing.mm)
// ShapeUpgrade_UnifySameDomain        → OCCTShapeUnifySameDomain, OCCTShapeSimplify, OCCTUnifySameDomainCreate
//
// --- STEP/IGES/OBJ/PLY/STL ---
// STEPControl_Reader/Writer           → OCCTExportSTEP, OCCTImportSTEP*
// IGESControl_Reader/Writer           → OCCTExportIGES, OCCTImportIGES*
// RWObj_CafReader/Writer              → OCCTDocumentLoadOBJ*, OCCTDocumentWriteOBJ,
//                                       OCCTImportOBJ, OCCTExportOBJ
// RWPly_CafWriter                     → OCCTDocumentWritePLY, OCCTExportPLY, OCCTExportPLYWithOptions
// StlAPI_Reader/Writer                → OCCTImportSTL, OCCTExportSTL
//
// --- TDF/OCAF ---
// TDF_Label                           → OCCTDocumentLabel*
// TDF_Reference                       → OCCTDocumentLabelSetReference, OCCTDocumentLabelGetReference
// TDF_CopyLabel                       → OCCTDocumentCopyLabel
// TDocStd_Document                    → OCCTDocument*
//
// --- TDataStd ---
// TDataStd_Integer/Real/AsciiString   → OCCTDocumentSetIntegerAttr, OCCTDocumentGetIntegerAttr,
//                                       OCCTDocumentSetRealAttr, OCCTDocumentGetRealAttr,
//                                       OCCTDocumentSetAsciiStringAttr,
//                                       OCCTDocumentGetAsciiStringAttr
// TDataStd_Comment                    → OCCTDocumentSetCommentAttr, OCCTDocumentGetCommentAttr
// TDataStd_IntegerArray/RealArray     → OCCTDocumentInitIntegerArray,
//                                       OCCTDocumentSetIntegerArrayValue,
//                                       OCCTDocumentGetIntegerArrayValue,
//                                       OCCTDocumentGetIntegerArrayBounds,
//                                       OCCTDocumentInitRealArray, OCCTDocumentSetRealArrayValue,
//                                       OCCTDocumentGetRealArrayValue,
//                                       OCCTDocumentGetRealArrayBounds
// TDataStd_TreeNode                   → OCCTDocumentSetTreeNode, OCCTDocumentAppendTreeChild,
//                                       OCCTDocumentTreeNode*, OCCTChildNodeIteratorCount
// TDataStd_NamedData                  → OCCTDocumentNamedData*
// TDataStd_IntPackedMap               → OCCTIntPackedMap*
// TDataStd_NoteBook                   → OCCTNoteBook*
// TDataStd_UAttribute                 → OCCTUAttribute*
// TDataStd_ChildNodeIterator          → OCCTChildNodeIteratorCount
//
// --- TopTrans ---
// TopTrans_CurveTransition            → OCCTTopTransCurveTransition* (v0.68.0)
// TopTrans_SurfaceTransition          → OCCTTopTransSurfaceTransition* (v0.67.0)
//
// --- TNaming ---
// TNaming_Builder                     → OCCTDocumentNamingRecord, OCCTDocumentSetShapeAttr
// TNaming_CopyShape                   → OCCTShapeDeepCopy
// TNaming_Iterator                    → OCCTDocumentNamingHistoryCount, OCCTDocumentNamingGetHistoryEntry,
//                                       OCCTDocumentNamingGetOldShape, OCCTDocumentNamingGetNewShape
// TNaming_NamedShape                  → OCCTNamingGet*, OCCTNamingIsEmpty, OCCTNamingGetVersion/SetVersion
// TNaming_NewShapeIterator            → OCCTDocumentNamingTraceForward
// TNaming_OldShapeIterator            → OCCTDocumentNamingTraceBackward
// TNaming_SameShapeIterator           → OCCTNamingSameShapeCount, OCCTNamingSameShapeLabels
// TNaming_Selector                    → OCCTDocumentNamingSelect*, OCCTDocumentNamingResolve*
// TNaming_Tool                        → OCCTNamingOriginalShape, OCCTNamingHasLabel, OCCTNamingFindLabel,
//                                       OCCTNamingValidUntil, OCCTDocumentNamingGetCurrentShape,
//                                       OCCTDocumentNamingGetShape, OCCTDocumentNamingResolve
//
// --- XCAFDoc ---
// XCAFDoc_AssemblyGraph               → OCCTAssemblyGraph*
// XCAFDoc_AssemblyItemId              → OCCTAssemblyItemId*
// XCAFDoc_ClippingPlaneTool           → OCCTDocumentClipPlaneTool*
// XCAFDoc_Color                       → OCCTDocumentSetColorAttr, OCCTDocumentSetColorRGBAAttr,
//                                       OCCTDocumentSetColorNOCAttr, OCCTDocumentGetColorAttr,
//                                       OCCTDocumentGetColorRGBAAttr, OCCTDocumentGetColorAlphaAttr,
//                                       OCCTDocumentGetColorNOCAttr
// XCAFDoc_ColorTool                   → OCCTDocumentColorTool*, OCCTDocumentSetLabelColor,
//                                       OCCTDocumentGetLabelColor, OCCTDocumentSetShapeColor,
//                                       OCCTDocumentGetShapeColor, OCCTDocumentIsShapeColorSet,
//                                       OCCTDocumentSetLabelVisibility, OCCTDocumentGetLabelVisibility
// XCAFDoc_Editor                      → OCCTDocumentEditorExpand, OCCTDocumentEditorRescaleGeometry
// XCAFDoc_GraphNode                   → OCCTDocumentGraphNode*
// XCAFDoc_LayerTool                   → OCCTDocumentSetLayer*, OCCTDocumentGetLayer*, OCCTDocumentGetLabelLayers,
//                                       OCCTDocumentFindLayer, OCCTDocumentIsLayerSet
// XCAFDoc_Location                    → OCCTDocumentSetLocation, OCCTDocumentGetLocationTranslation,
//                                       OCCTDocumentHasLocation
// XCAFDoc_Material                    → OCCTDocumentSetMaterialAttr, OCCTDocumentGetMaterialAttr*,
//                                       OCCTDocumentHasMaterialAttr
// XCAFDoc_NoteBalloon                 → OCCTDocumentSetNoteBalloon
// XCAFDoc_NoteBinData                 → OCCTDocumentSetNoteBinData, OCCTDocumentGetNoteBinDataSize
// XCAFDoc_NoteComment                 → OCCTDocumentSetNoteComment, OCCTDocumentGetNoteCommentText,
//                                       OCCTDocumentGetNoteUserName
// XCAFDoc_NotesTool                   → OCCTDocumentNotesTool*
// XCAFDoc_ShapeMapTool                → OCCTDocumentShapeMapTool*
// XCAFDoc_ShapeTool                   → OCCTDocumentShapeTool*, and the assembly surface it backs:
//                                       OCCTDocumentAddShape, OCCTDocumentNewShape,
//                                       OCCTDocumentRemoveShape, OCCTDocumentFindShape,
//                                       OCCTDocumentSearchShape, OCCTDocumentGetShape*,
//                                       OCCTDocumentAddComponent*, OCCTDocumentRemoveComponent,
//                                       OCCTDocumentGetComponent*, OCCTDocumentGetFreeShape*,
//                                       OCCTDocumentGetRoot*, OCCTDocumentGetChild*,
//                                       OCCTDocumentGetSubShape*, OCCTDocumentGetReferredLabelId,
//                                       OCCTDocumentIsAssembly, OCCTDocumentIsComponent,
//                                       OCCTDocumentIsCompound, OCCTDocumentIsReference,
//                                       OCCTDocumentIsSubShape, OCCTDocumentIsTopLevel,
//                                       OCCTDocumentExpandShape, OCCTDocumentUpdateAssemblies,
//                                       OCCTDocumentExplorer*, and every OBJ/PLY/glTF/STEP
//                                       import/export (OCCTImportOBJ, OCCTImportGLTF,
//                                       OCCTExportOBJ, OCCTExportPLY*, OCCTExportGLTF,
//                                       OCCTDocumentLoad*, OCCTDocumentWrite*)
// XCAFDoc_VisMaterialCommon           → OCCTVisMaterialCommon*
// XCAFDoc_VisMaterialPBR              → OCCTVisMaterialPBR*
//
// --- XCAFNoteObjects ---
// XCAFNoteObjects_NoteObject          → OCCTNoteObject*
//
// --- XCAFPrs ---
// XCAFPrs_Style                       → OCCTXCAFPrsStyle*
//
// --- XCAFView ---
// XCAFView_Object                     → OCCTViewObject*
//
// --- gp (core geometry) ---
// gp_Pnt/gp_Vec/gp_Dir               → (used throughout all bridge functions)
// gp_Ax1/gp_Ax2/gp_Ax3               → (used throughout all bridge functions)
// gp_Trsf/gp_Trsf2d                  → OCCTShapeTranslate/Rotate/Scale/Mirror, OCCTPoint2D*
// gp_Pnt2d/gp_Vec2d/gp_Dir2d         → OCCTCurve2D*, OCCTPoint2D*, OCCTVector2D*, OCCTDirection2D*
//

#ifdef __cplusplus
extern "C" {
#endif


// MARK: - Thread Safety Lock
void OCCTSerialLockAcquire(void);
void OCCTSerialLockRelease(void);

// MARK: - Opaque Handle Types

typedef struct OCCTShape* OCCTShapeRef;
typedef struct OCCTWire* OCCTWireRef;
typedef struct OCCTMesh* OCCTMeshRef;
typedef struct OCCTFace* OCCTFaceRef;

// --- Bulk edge discretisation (handle-based) — issue #275 ---

/// An immutable set of discretised edge polylines, computed in one pass.
typedef struct OCCTEdgePolylines* OCCTEdgePolylinesRef;

// MARK: - Edge Access (Issue #14)

typedef struct OCCTEdge* OCCTEdgeRef;

// MARK: - XDE/XCAF Document Support (v0.6.0)

/// Opaque handle for XDE document
typedef struct OCCTDocument* OCCTDocumentRef;

// MARK: - 2D Drawing / HLR Projection (v0.6.0)

/// Opaque handle for 2D drawing (HLR projection result)
typedef struct OCCTDrawing* OCCTDrawingRef;

// MARK: - Camera (Metal Visualization)

typedef struct OCCTCamera* OCCTCameraRef;

// MARK: - Selector (Metal Visualization)

typedef struct OCCTSelector* OCCTSelectorRef;

// MARK: - Drawer-Aware Mesh Extraction

typedef struct OCCTDrawer* OCCTDrawerRef;

// MARK: - Clip Plane (Metal Visualization)

typedef struct OCCTClipPlane* OCCTClipPlaneRef;

// MARK: - Z-Layer Settings (Metal Visualization)

typedef struct OCCTZLayerSettings* OCCTZLayerSettingsRef;

// MARK: - 2D Curve (Geom2d) — v0.16.0

typedef struct OCCTCurve2D* OCCTCurve2DRef;

// MARK: - Curve3D: 3D Parametric Curves (v0.19.0)

typedef struct OCCTCurve3D* OCCTCurve3DRef;

// MARK: - CompCurve adaptor: treat a multi-edge wire as one arc-length curve (#211, BRepAdaptor_CompCurve)

typedef struct OCCTCompCurve* OCCTCompCurveRef;

// EdgeCurve adaptor: a single edge as an arc-length curve (BRepAdaptor_Curve). #211/#212
typedef struct OCCTEdgeCurve* OCCTEdgeCurveRef;

// MARK: - Surface: Parametric Surfaces (v0.20.0)

typedef struct OCCTSurface* OCCTSurfaceRef;

// MARK: - Law Functions (v0.21.0)

typedef struct OCCTLawFunction* OCCTLawFunctionRef;

// MARK: - BRepMAT2d: Medial Axis Transform (v0.24.0)

/// Opaque handle for a computed medial axis of a planar face.
typedef struct OCCTMedialAxis* OCCTMedialAxisRef;

// ============================================================
// MARK: - AIS Annotations & Measurements (v0.26.0)
// ============================================================

/// Opaque handle to a dimension measurement (length, radius, angle, or diameter).
typedef struct OCCTDimension* OCCTDimensionRef;

/// Opaque handle to a positioned text label.
typedef struct OCCTTextLabel* OCCTTextLabelRef;

/// Opaque handle to a point cloud.
typedef struct OCCTPointCloud* OCCTPointCloudRef;

// MARK: - KD-Tree Spatial Queries (v0.28.0)

/// Opaque handle to a KD-tree for 3D point queries.
typedef struct OCCTKDTree* OCCTKDTreeRef;

// MARK: - Boolean with Full Per-Input History (issue #165)

/// Opaque handle to a boolean operation that retains its builder so
/// per-input-subshape history (Modified / Generated / IsDeleted) can be
/// queried after the operation completes. Free with OCCTBooleanHistoryRelease.
typedef struct OCCTBooleanHistory* OCCTBooleanHistoryRef;

/// Opaque handle to BRepTools_History.
typedef void* _Nullable OCCTHistoryRef;

// MARK: - v0.45.0: BRepOffsetAPI_MakeFilling, BRepExtrema_SelfIntersection, BRepGProp_Face, ShapeAnalysis_WireOrder

/// N-side surface filling: create a face from boundary edges and optional point constraints.
/// Call OCCTFillingCreate, add edges/points, then Build, get face, and Release. Backs
/// FillingSurface; shares its BRepOffsetAPI_MakeFilling implementation with OCCTShapeFill*
/// (Shape.fill) as of #434 — see the continuity note on OCCTFillingParams above.
typedef struct OCCTFilling* OCCTFillingRef;

// MARK: - Contap — Contour Analysis (v0.61.0)

/// Opaque handle for contour analysis result
typedef struct OCCTContourResult* OCCTContourResultRef;

// MARK: - BOPAlgo — CellsBuilder (v0.61.0)

/// Opaque handle for CellsBuilder
typedef struct OCCTCellsBuilder* OCCTCellsBuilderRef;

// --- GeomInt_IntSS ---
// Surface-surface intersection returning 3D curves
// Returns count of intersection curves; curves stored internally
typedef void* OCCTGeomIntSSRef;

// --- Contap_Contour ---
// Contour lines on a face with direction or eye point
typedef void* OCCTContapContourRef;

// MARK: - v0.66.0: Full TkG2d Toolkit Coverage

// Forward declarations
typedef struct OCCTTransform2D* OCCTTransform2DRef;

// --- Point2D (Geom2d_CartesianPoint) ---

/// Opaque handle for 2D geometric point
typedef struct OCCTPoint2D* OCCTPoint2DRef;

// --- AxisPlacement2D (Geom2d_AxisPlacement) ---

/// Opaque handle for 2D axis placement
typedef struct OCCTAxisPlacement2D* OCCTAxisPlacement2DRef;

// --- Plate_Plate solver ---

/// Opaque handle for Plate_Plate solver
typedef void* OCCTPlateRef;

// --- Intrv_Interval ---

/// Opaque handle for an interval with tolerances
typedef struct OCCTIntrvInterval* OCCTIntrvIntervalRef;

// --- Intrv_Intervals ---

/// Opaque handle for a sorted sequence of non-overlapping intervals
typedef struct OCCTIntrvIntervals* OCCTIntrvIntervalsRef;

// MARK: - BRepIntCurveSurface_Inter (Ray/Curve–Shape Intersection)

/// Opaque handle for BRepIntCurveSurface_Inter iterator.
typedef struct OCCTCurveSurfaceInter* OCCTCurveSurfaceInterRef;

// MARK: - Geom_CartesianPoint (3D Geometric Point)

typedef struct OCCTGeomPoint3D* OCCTGeomPoint3DRef;

// MARK: - Geom_Direction (3D Unit Vector)

typedef struct OCCTGeomDirection* OCCTGeomDirectionRef;

// MARK: - Geom_VectorWithMagnitude (3D Vector)

typedef struct OCCTGeomVector3D* OCCTGeomVector3DRef;

// MARK: - Geom_Axis1Placement (3D Axis)

typedef struct OCCTAxis1Placement* OCCTAxis1PlacementRef;

// MARK: - Geom_Axis2Placement (3D Coordinate System)

typedef struct OCCTAxis2Placement* OCCTAxis2PlacementRef;

// MARK: - Poly_Polygon2D

typedef struct Poly_Polygon2DOpaque* OCCTPolyPolygon2DRef;

// MARK: - Poly_Triangulation (v0.160.0)

typedef struct Poly_TriangulationOpaque* OCCTPolyTriangulationRef;

// MARK: - Poly_Polygon3D

typedef struct Poly_Polygon3DOpaque* OCCTPolyPolygon3DRef;

// MARK: - Poly_PolygonOnTriangulation

typedef struct Poly_PolygonOnTriangulationOpaque* OCCTPolyPolygonOnTriRef;

// MARK: - v0.79.0: Poly_CoherentTriangulation, BRepFill_Evolved/OffsetAncestors/NSections,
//                   BRepExtrema_DistanceSS, BRepGProp_VinertGK, GeomFill_Profiler/Stretch/
//                   LocationDraft/GuideTrihedronAC/GuideTrihedronPlan/SectionPlacement/AppSurf,
//                   ShapeFix_ComposeShell

// --- Poly_CoherentTriangulation ---
typedef void* OCCTCoherentTriangulationRef;

// --- BRepFill_OffsetAncestors ---
typedef void* OCCTOffsetAncestorsRef;

// --- GeomFill_Profiler ---
typedef void* OCCTGeomFillProfilerRef;

// --- GeomFill_LocationDraft ---
typedef void* OCCTLocationDraftRef;

// --- GeomFill_GuideTrihedronAC ---
typedef void* OCCTGuideTrihedronACRef;

// --- GeomFill_GuideTrihedronPlan ---
typedef void* OCCTGuideTrihedronPlanRef;

// --- BRepFill_NSections ---
typedef void* OCCTNSectionsRef;

typedef struct {
    double squareDistance;
    double x1, y1, z1;  // Point on curve 1
    double param1;
    double x2, y2, z2;  // Point on curve 2
    double param2;
} OCCTExtremaPointPair;

// --- Image_AlienPixMap ---

/// Opaque handle to Image_AlienPixMap
typedef void *_Nullable OCCTImageRef;

// --- XCAFDoc_AssemblyGraph ---

/// Opaque handle to assembly graph
typedef void *_Nullable OCCTAssemblyGraphRef;

// --- XCAFView_Object ---

/// Opaque handle to XCAFView_Object
typedef void *_Nullable OCCTViewObjectRef;

// --- XCAFNoteObjects_NoteObject ---

/// Opaque handle to XCAFNoteObjects_NoteObject
typedef void *_Nullable OCCTNoteObjectRef;

// --- TObj_Application ---

/// Opaque handle for TObj_Application
typedef void* OCCTTObjAppRef;

// --- Message_Messenger ---

/// Opaque handle for Message_Messenger
typedef void* OCCTMessengerRef;

// --- Message_Report ---

/// Opaque handle for Message_Report
typedef void* OCCTReportRef;

// --- TDF_IDFilter ---

/// Opaque handle for TDF_IDFilter
typedef void* OCCTIDFilterRef;

// MARK: - Geom_Transformation

/// Opaque handle for Geom_Transformation
typedef void* OCCTGeomTransformRef;

// MARK: - gp_Quaternion (v0.91.0)

/// Opaque quaternion reference.
typedef struct OCCTQuaternion* OCCTQuaternionRef;

// MARK: - OSD_Timer (v0.91.0)

/// Opaque timer reference.
typedef struct OCCTTimer* OCCTTimerRef;

// MARK: - Bnd_OBB — Oriented Bounding Box (v0.92.0)

/// Opaque OBB reference.
typedef struct OCCTOBB* OCCTOBBRef;

// MARK: - Bnd_Range — 1D Range (v0.92.0)

/// Opaque range reference.
typedef struct OCCTRange* OCCTRangeRef;

// MARK: - math_Matrix (v0.94.0)

typedef struct OCCTMathMatrix* OCCTMathMatrixRef;

// MARK: - BRepAlgo_Image (v0.96.0)

typedef struct OCCTBRepAlgoImage* OCCTBRepAlgoImageRef;

// MARK: - Bnd_BoundSortBox (v0.97.0)

typedef struct OCCTBoundSortBox* OCCTBoundSortBoxRef;

// MARK: - OSD_File (v0.99.0)

/// Opaque reference to an OSD_File object.
typedef struct OCCTOSDFile* OCCTOSDFileRef;

// --- APIHeaderSection_MakeHeader ---

/// Opaque type for STEP file header
typedef struct OCCTStepHeader* OCCTStepHeaderRef;

// --- Resource_Manager ---

typedef struct OCCTResourceManager* OCCTResourceManagerRef;

// MARK: - OSD_PerfMeter (v0.104.0)

typedef struct OCCTPerfMeter* OCCTPerfMeterRef;

// MARK: - Bnd_Sphere (v0.103.0)

/// Create a bounding sphere. Returns opaque ref.
typedef struct OCCTBndSphere* OCCTBndSphereRef;

// MARK: - BRepTools_ReShape (v0.105.0)

typedef struct OCCTReShape* OCCTReShapeRef;

// MARK: - BRepFill_PipeShell (v0.105.0)

typedef struct OCCTPipeShell* OCCTPipeShellRef;

// MARK: - Sewing (v0.107.0)

/// Opaque sewing builder handle.
typedef struct OCCTSewing* OCCTSewingRef;

// MARK: - Hatch_Hatcher (v0.107.0)

/// Opaque hatcher handle.
typedef struct OCCTHatcher* OCCTHatcherRef;
/// 3D elementary extrema result
typedef struct {
    double squareDistance;
    double x1, y1, z1;  ///< Point on first element
    double x2, y2, z2;  ///< Point on second element
} OCCTExtremaElResult;

// MARK: - BRepAlgo_NormalProjection (v0.109.0)

typedef struct OCCTNormalProjection* OCCTNormalProjectionRef;

// MARK: - OSD_SharedLibrary (v0.109.0)

typedef struct OCCTSharedLib* OCCTSharedLibRef;

// MARK: - v0.112.0: RWMesh iterators, Intf_Tool, BRepAlgo_AsDes, BiTgte_CurveOnEdge, Shape extras, Extrema

// --- RWMesh_FaceIterator ---

/// Opaque handle for face mesh iterator.
typedef struct OCCTMeshFaceIter* OCCTMeshFaceIterRef;

// --- RWMesh_VertexIterator ---

/// Opaque handle for vertex mesh iterator.
typedef struct OCCTMeshVertexIter* OCCTMeshVertexIterRef;

// --- Intf_Tool ---

/// Opaque handle for Intf_Tool line-box clipping.
typedef struct OCCTIntfTool* OCCTIntfToolRef;

// --- BRepAlgo_AsDes ---

/// Opaque handle for BRepAlgo_AsDes ascendant-descendant tracker.
typedef struct OCCTAsDes* OCCTAsDesRef;

// --- BiTgte_CurveOnEdge ---

/// Opaque handle for BiTgte_CurveOnEdge.
typedef struct OCCTBiTgteCurveOnEdge* OCCTBiTgteCurveOnEdgeRef;

// --- GeomAPI_ProjectPointOnCurve (multi-result) ---

typedef struct OCCTProjOnCurve* OCCTProjOnCurveRef;

// --- GeomAPI_ProjectPointOnSurf (multi-result) ---

typedef struct OCCTProjOnSurf* OCCTProjOnSurfRef;

// --- BRepExtrema_DistShapeShape (full results) ---

typedef struct OCCTDistSS* OCCTDistSSRef;

// --- ShapeFix_Wire individual fixes ---

typedef struct OCCTWireFixer* OCCTWireFixerRef;

// --- ShapeFix_Face individual fixes ---

typedef struct OCCTFaceFixer* OCCTFaceFixerRef;

// --- GeomAPI_IntCS full results ---

typedef struct OCCTIntCS* OCCTIntCSRef;

// --- ShapeAnalysis_FreeBoundsProperties ---
//
// The one wrapping of this class since #504, which removed the stateless OCCTFreeBounds* family
// declared in the v0.49.0 block. Every index below is 0-based and range-checked here.
//
// A free bound is a boundary contour of the shape: a chain of edges each used by exactly one
// face, closed into a loop where it can be. Contours that close are "closed" bounds, the rest
// "open". Note that the sewing-based search backing this class closes essentially
// everything it finds, so the open sequence is usually empty (#504).

typedef struct OCCTFreeBoundsProps* OCCTFreeBoundsPropsRef;

// --- BRepBuilderAPI_MakeWire (incremental) ---

typedef struct OCCTWireBuilder* OCCTWireBuilderRef;

// OCCTDefeatureWithTolerance was declared here. BRepAlgoAPI_Defeaturing has no fuzzy tolerance to
// set — Build() forwards neither the value nor anything else from BOPAlgo_Options to the algorithm
// that does the work — so it was OCCTShapeDefeature under another name. #497
// --- BRepOffsetAPI_ThruSections builder ---

typedef void* OCCTThruSectionsRef;

// --- ShapeFix_Shape builder ---

typedef void* OCCTShapeFixerRef;

// --- FilletBuilder (BRepFilletAPI_MakeFillet) ---

typedef struct OCCTFilletBuilder* OCCTFilletBuilderRef;

// --- ChamferBuilder (BRepFilletAPI_MakeChamfer) ---

typedef struct OCCTChamferBuilder* OCCTChamferBuilderRef;

// --- WireAnalyzer (ShapeAnalysis_Wire) (v0.124.0) ---

typedef struct OCCTWireAnalyzer* OCCTWireAnalyzerRef;

// --- UnifySameDomain builder ---

typedef void* OCCTUnifySameDomainRef;

// --- SectionBuilder (BRepAlgoAPI_Section) ---

typedef struct OCCTSectionBuilder* OCCTSectionBuilderRef;

// MARK: - v0.131.0: Approx_BSplineApproxInterp, GeomEval TBezier/AHTBezier, GeomAdaptor_TransformedCurve

// --- Approx_BSplineApproxInterp (reimplemented on GeomAPI_PointsToBSpline) ---
//
// OCCT 8.0.0p1 removed Approx_BSplineApproxInterp. The C ABI below is preserved unchanged,
// but every function in this section is now served by GeomAPI_PointsToBSpline, which is
// where the cross-reference index at the top of this header lists the family, and where a
// behaviour change to that class has to be propagated. Implementation and the reasoning
// behind each mapping: OCCTBridge_Curve3D.mm, "Approx_BSplineApproxInterp" section.
//
// Differences the preserved ABI cannot express, kept so callers compile and run unchanged:
//   * nbControlPts and continuousIfClosed are ADVISORY: GeomAPI_PointsToBSpline picks the
//     pole count it needs to meet the tolerance within [DegMin, DegMax].
//   * InterpolatePoint, SetAlpha, SetMinPivot, SetClosedTol and SetKnotTol are NO-OPS;
//     GeomAPI_PointsToBSpline exposes no equivalent control. Flagged per function below.
//   * SetConvergenceTol and SetProjectionTol both drive the one 3D fit tolerance.
//   * PerformOptimal is identical to Perform; maxIter is ignored.
//   * MaxError is measured by projecting the input points back onto the fitted curve.

/// Opaque ref to the B-spline approximation solver (backed by GeomAPI_PointsToBSpline).
typedef struct OCCTBSplineApproxInterp* OCCTBSplineApproxInterpRef;

// MARK: - BRepGraph (Topology Graph)

/// Opaque handle to a BRepGraph instance.
typedef struct OCCTBRepGraph* OCCTBRepGraphRef;

// MARK: - Per-Domain Bridge Headers
//
// Declarations live in the 15 files below (#395); this umbrella assembles them.
// Handle typedefs and the two shared Extrema result types above are needed by more
// than one domain header (or by every one of them), so they stay here, ahead of
// the imports.

#import "OCCTBridge_AIS.h"
#import "OCCTBridge_BRepGraph.h"
#import "OCCTBridge_Curve3D.h"
#import "OCCTBridge_Document.h"
#import "OCCTBridge_Geom2d.h"
#import "OCCTBridge_Healing.h"
#import "OCCTBridge_IO.h"
#import "OCCTBridge_Mesh.h"
#import "OCCTBridge_Modeling.h"
#import "OCCTBridge_ProjLib_NLPlate.h"
#import "OCCTBridge_Properties.h"
#import "OCCTBridge_Spatial.h"
#import "OCCTBridge_Surface.h"
#import "OCCTBridge_Topology.h"
#import "OCCTBridge_Visualization.h"

#ifdef __cplusplus
}
#endif

#pragma clang diagnostic pop

#endif /* OCCTBridge_h */
