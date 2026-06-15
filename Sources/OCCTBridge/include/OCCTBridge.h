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
// BOPAlgo_CellsBuilder                → OCCTBOPAlgoSplit
// BOPAlgo_CheckerSI                   → OCCTShapeSelfIntersects
// BOPAlgo_MakeConnected               → OCCTShapeMakeConnected
// BOPAlgo_MakePeriodic                → OCCTShapeMakePeriodic, OCCTShapeRepeat
// BOPAlgo_MakerVolume                 → OCCTShapeMakeVolume
// BOPAlgo_RemoveFeatures              → OCCTBOPAlgoRemoveFeatures
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
// BRepAlgoAPI_Cut                     → OCCTShapeSubtract
// BRepAlgoAPI_Defeaturing             → OCCTShapeRemoveFeatures
// BRepAlgoAPI_Fuse                    → OCCTShapeUnion
// BRepAlgoAPI_Section                 → OCCTShapeSection, OCCTShapeSliceAtZ, OCCTSectionBuilder*
// BRepAlgoAPI_Splitter                → OCCTShapeSplit
//
// --- BRepBuilderAPI ---
// BRepBuilderAPI_Copy                 → OCCTShapeCopy
// BRepBuilderAPI_FastSewing           → OCCTShapeFastSewn
// BRepBuilderAPI_FindPlane            → OCCTShapeFindPlane
// BRepBuilderAPI_GTransform           → OCCTShapeNonUniformScale
// BRepBuilderAPI_MakeEdge             → OCCTWireCreate*, OCCTBRepLibEdge*
// BRepBuilderAPI_MakeEdge2d           → OCCTMakeEdge2d*
// BRepBuilderAPI_MakeFace             → OCCTShapeCreate*, OCCTFaceFill*
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
// BRepCheck_Analyzer                  → OCCTShapeIsValid, OCCTShapeAnalyze, OCCTCheckShape*
// BRepCheck_Edge/Face/Shell/Solid     → OCCTCheckFace, OCCTCheckSolid, OCCTBRepCheckSubShapeValid
//
// --- BRepExtrema ---
// BRepExtrema_DistShapeShape          → OCCTShapeDistance, OCCTShapeIntersects
// BRepExtrema_ExtCC                   → OCCTBRepExtremaExtCC
// BRepExtrema_ExtCF                   → OCCTBRepExtremaExtCF
// BRepExtrema_ExtFF                   → OCCTBRepExtremaExtFF
// BRepExtrema_ExtPC                   → OCCTBRepExtremaExtPC
// BRepExtrema_ExtPF                   → OCCTBRepExtremaExtPF
// BRepExtrema_Poly                    → OCCTShapePolyhedralDistance
//
// --- BRepFeat ---
// BRepFeat_Builder                    → OCCTBRepFeatFuse, OCCTBRepFeatCut
// BRepFeat_Gluer                      → OCCTBRepFeatGluer
// BRepFeat_MakeCylindricalHole        → OCCTBRepFeatCylindricalHole*
// BRepFeat_MakeDPrism                 → OCCTShapeDraftPrism*
// BRepFeat_MakeLinearForm             → OCCTShapeLinearRib
// BRepFeat_MakePipe                   → OCCTShapePipeFeature*
// BRepFeat_MakePrism                  → OCCTShapePrism, OCCTShapeSemiInfiniteExtrusion
// BRepFeat_MakeRevol                  → OCCTShapeRevolFeature*
// BRepFeat_MakeRevolutionForm         → OCCTShapeRevolutionForm
// BRepFeat_SplitShape                 → OCCTBRepFeatSplitShape*
//
// --- BRepFill ---
// BRepFill_CompatibleWires            → OCCTShapeCompatibleWires
// BRepFill_Draft                      → OCCTShapeDraftFromWire
// BRepFill_Filling                    → OCCTFillingSurface*
// BRepFill_Generator                  → OCCTShapeRuledShell
// BRepFill_OffsetWire                 → OCCTWireOffset
// BRepFill_Pipe                       → OCCTShapePipeSweep
//
// --- BRepFilletAPI ---
// BRepFilletAPI_MakeChamfer           → OCCTShapeChamfer*
// BRepFilletAPI_MakeFillet            → OCCTShapeFillet*
// BRepFilletAPI_MakeFillet2d          → OCCTShapeFillet2D*, OCCTShapeChamfer2D*
//
// --- BRepGProp ---
// BRepGProp                           → OCCTShapeVolume, OCCTShapeSurfaceArea, OCCTShapeGetCenterOfMass
// BRepGProp_Face                      → OCCTFaceGProp*
// BRepGProp_MeshCinert                → OCCTMeshCinert*
// BRepGProp_MeshProps                 → OCCTMeshProps*
//
// --- BRepIntCurveSurface ---
// BRepIntCurveSurface_Inter           → OCCTCurveSurfaceInter*
//
// --- BRepLib ---
// BRepLib_MakeEdge                    → OCCTBRepLibEdge*
// BRepLib_MakeFace                    → OCCTBRepLibFace*
// BRepLib_MakeShell                   → OCCTBRepLibShell*
// BRepLib_MakeSolid                   → OCCTBRepLibSolidFromShell
// BRepLib_ValidateEdge                → OCCTValidateEdge
//
// --- BRepMesh ---
// BRepMesh_Deflection                 → OCCTDeflectionCompute, OCCTDeflectionIsConsistent
// BRepMesh_IncrementalMesh            → OCCTShapeCreateMesh*
// BRepMesh_ShapeTool                  → OCCTMeshShapeTool*
//
// --- BRepOffset ---
// BRepOffset_Analyse                  → OCCTEdgeGetConvexity
// BRepOffset_Offset                   → OCCTBRepOffsetFace
// BRepOffset_SimpleOffset             → OCCTShapeSimpleOffset
//
// --- BRepOffsetAPI ---
// BRepOffsetAPI_DraftAngle            → OCCTShapeDraft
// BRepOffsetAPI_MakeDraft             → OCCTShapeMakeDraft
// BRepOffsetAPI_MakeEvolved           → OCCTShapeEvolved*
// BRepOffsetAPI_MakeFilling           → OCCTFillingSurface*
// BRepOffsetAPI_MakeOffset            → OCCTShapeOffset*
// BRepOffsetAPI_MakePipe              → OCCTShapePipe*
// BRepOffsetAPI_MakePipeShell         → OCCTShapePipeShell*
// BRepOffsetAPI_MakeThickSolid        → OCCTShapeShell, OCCTShapeHollowed
// BRepOffsetAPI_ThruSections          → OCCTShapeLoft*
//
// --- BRepPrimAPI ---
// BRepPrimAPI_MakeBox                 → OCCTShapeCreateBox*
// BRepPrimAPI_MakeCone                → OCCTShapeCreateCone
// BRepPrimAPI_MakeCylinder            → OCCTShapeCreateCylinder*
// BRepPrimAPI_MakeHalfSpace           → OCCTShapeCreateHalfSpace
// BRepPrimAPI_MakePrism               → OCCTShapeCreateExtrusion
// BRepPrimAPI_MakeRevol               → OCCTShapeCreateRevolve
// BRepPrimAPI_MakeSphere              → OCCTShapeCreateSphere
// BRepPrimAPI_MakeTorus               → OCCTShapeCreateTorus
// BRepPrimAPI_MakeWedge               → OCCTShapeCreateWedge
//
// --- BRepTools ---
// BRepTools_Modifier                  → OCCTShapeNurbsConvertViaModifier, OCCTShapeSimpleOffset
// BRepTools_ReShape                   → OCCTShapeReplaceSubShape*
// BRepTools_Substitution              → OCCTShapeSubstituted
// BRepTools_WireExplorer              → OCCTWireGetOrderedEdge*
//
// --- ChFi2d ---
// ChFi2d_AnaFilletAlgo               → OCCTShapeAnaFillet*
// ChFi2d_Builder                      → OCCTChFi2dAdd*, OCCTChFi2dModify*, OCCTChFi2dRemove*
// ChFi2d_ChamferAPI                   → OCCTChFi2dChamferEdges
// ChFi2d_FilletAlgo                   → OCCTShapeFilletAlgo*
// ChFi2d_FilletAPI                    → OCCTChFi2dFilletEdges
//
// --- FilletSurf ---
// FilletSurf_Builder                  → OCCTFilletSurfBuild, OCCTFilletSurfError
//
// --- Contap ---
// Contap_ContAna                      → OCCTContapSphereDir, OCCTContapCylinderDir, OCCTContapSphereEye
// Contap_Contour                      → OCCTContapContour*
//
// --- GC ---
// GC_MakeArcOfCircle                  → OCCTWireCreateArc, OCCTWireCreateArc3Points
// GC_MakeCircle                       → OCCTWireCreateCircle
// GC_MakeEllipse                      → OCCTGCMakeEllipse3Points
// GC_MakeHyperbola                    → OCCTGCMakeHyperbola3Points
// GC_MakeMirror                       → OCCTGCMakeMirror*
// GC_MakeScale                        → OCCTGCMakeScale
// GC_MakeSegment                      → OCCTWireCreateLine
// GC_MakeTranslation                  → OCCTGCMakeTranslation
//
// --- GC 2D ---
// GC_MakeLine2d                       → OCCTGCE2dMakeLine* (bridge symbols retain GCE2d historical name)
//
// --- GCPnts ---
// GCPnts_AbscissaPoint                → OCCTCurve2DParameterAtLength
// GCPnts_QuasiUniformAbscissa         → OCCTCurve3DQuasiUniformParams
// GCPnts_QuasiUniformDeflection       → OCCTCurve3DQuasiUniformDeflection
// GCPnts_UniformAbscissa              → OCCTCPntsUniformDeflection*
// GCPnts_UniformDeflection            → OCCTCPntsUniformDeflection*
//
// --- GccAna ---
// GccAna_Circ2d2TanOn                 → OCCTGccAnaCirc2d2TanOn*
// GccAna_Circ2d2TanRad                → OCCTGccAnaCirc2d2TanRad*
// GccAna_Circ2dTanCen                 → OCCTGccAnaCirc2dTanCen*
// GccAna_Circ2dTanOnRad               → OCCTGccAnaCirc2dTanOnRad*
// GccAna_Lin2dBisec                   → OCCTGccAnaBisecLL, OCCTGccAnaBisecPP
// GccAna_Lin2dTanObl                  → OCCTGccAnaLinOblique*
// GccAna_Lin2dTanPar                  → OCCTGccAnaLinParallel*
// GccAna_Lin2dTanPer                  → OCCTGccAnaLinPerpendicular*
// GccAna_Circ2d3Tan                   → OCCTGccAnaCirc2d3Tan* (v0.68.0)
// GccAna_Pnt2dBisec                   → OCCTGccAnaBisecPP
//
// --- Geom ---
// Geom_BSplineCurve                   → OCCTCurve3D*, OCCTSurface*
// Geom_BSplineSurface                 → OCCTSurface*
// Geom_BezierCurve                    → OCCTCurve3DBezier
// Geom_BezierSurface                  → OCCTSurface*
// Geom_Circle                         → OCCTCurve3DCircle, OCCTCurve3DArc*
// Geom_ConicalSurface                 → OCCTSurfaceCone*
// Geom_CylindricalSurface             → OCCTSurfaceCylinder*
// Geom_Ellipse                        → OCCTCurve3DEllipse*
// Geom_Hyperbola                      → OCCTCurve3DHyperbola*
// Geom_Line                           → OCCTCurve3DLine, OCCTCurve3DSegment
// Geom_OffsetSurface                  → OCCTSurfaceOffset, OCCTSurfaceOffsetValue, OCCTSurfaceSetOffsetValue, OCCTSurfaceOffsetBasis (v0.99.0)
// Geom_Parabola                       → OCCTCurve3DParabola*
// Geom_Plane                          → OCCTSurfacePlane*
// Geom_SphericalSurface               → OCCTSurfaceSphere
// Geom_SurfaceOfLinearExtrusion       → OCCTSurfaceExtrusion
// Geom_SurfaceOfRevolution            → OCCTSurfaceRevolution
// Geom_ToroidalSurface                → OCCTSurfaceTorus
// Geom_TrimmedCurve                   → OCCTCurve3DTrim
//
// --- Geom2d ---
// Geom2d_AxisPlacement                → OCCTAxisPlacement2D*
// Geom2d_BSplineCurve                 → OCCTCurve2D*
// Geom2d_BezierCurve                  → OCCTCurve2DBezier
// Geom2d_CartesianPoint               → OCCTPoint2D*
// Geom2d_Circle                       → OCCTCurve2DCircle, OCCTCurve2DArc*
// Geom2d_Direction                    → OCCTDirection2D*
// Geom2d_Ellipse                      → OCCTCurve2DEllipse*
// Geom2d_Hyperbola                    → OCCTCurve2DHyperbola
// Geom2d_Line                         → OCCTCurve2DLine, OCCTCurve2DSegment
// Geom2d_OffsetCurve                  → OCCTCurve2DOffset
// Geom2d_Parabola                     → OCCTCurve2DParabola
// Geom2d_Transformation               → OCCTTransform2D*
// Geom2d_TrimmedCurve                 → OCCTCurve2DTrim
// Geom2d_VectorWithMagnitude          → OCCTVector2D*
//
// --- Geom2dAPI ---
// Geom2dAPI_ExtremaCurveCurve         → OCCTCurve2DExtrema, OCCTCurve2DCurvatureExtrema
// Geom2dAPI_InterCurveCurve           → OCCTCurve2DIntersect, OCCTCurve2DSelfIntersect
// Geom2dAPI_Interpolate               → OCCTCurve2DInterpolate*
// Geom2dAPI_ProjectPointOnCurve       → OCCTPoint2DDistanceToCurve, OCCTCurve2DProjectPoint2D
//
// --- Geom2dGcc ---
// Geom2dGcc_Circ2d2TanOn              → OCCTGeom2dGccCirc2d2TanOn*
// Geom2dGcc_Circ2d2TanRad             → OCCTGeom2dGccCirc2d2TanRad*
// Geom2dGcc_Circ2dTanCen              → OCCTGeom2dGccCirc2dTanCen*
// Geom2dGcc_Circ2dTanOnRad            → OCCTGeom2dGccCirc2dTanOnRad*
// Geom2dGcc_Lin2d2Tan                 → OCCTGeom2dGccLin2d2Tan*
// Geom2dGcc_Lin2dTanObl               → OCCTGeom2dGccLin2dTanObl*
//
// --- Geom2dHatch ---
// Geom2dHatch_Hatcher                 → OCCTHatchGenerate
//
// --- GeomAPI ---
// GeomAPI_ExtremaCurveCurve           → OCCTCurve3DMinDistance, OCCTCurve3DExtrema
// GeomAPI_ExtremaCurveSurface         → OCCTCurve3DDistanceToSurface
// GeomAPI_ExtremaSurfaceSurface       → OCCTSurfaceExtrema
// GeomAPI_IntCS                       → OCCTCurve3DIntersectSurface
// GeomAPI_IntSS                       → OCCTSurfaceSurfaceIntersect
// GeomAPI_PointsToBSpline             → OCCTCurve3DFit
// GeomAPI_PointsToBSplineSurface      → OCCTSurfacePlateThrough, OCCTSurfaceNLPlateG0
// GeomAPI_ProjectPointOnCurve         → OCCTCurve3DProjectPoint
// GeomAPI_ProjectPointOnSurf          → OCCTSurfaceProjectPoint, OCCTFaceProject*
//
// --- GeomConvert ---
// GeomConvert                         → OCCTCurve3DToBSpline, OCCTCurve3DToBezierSegments
// GeomConvert_CompCurveToBSplineCurve → OCCTCurve3DJoined
//
// --- Convert ---
// Convert_CompBezierCurvesToBSplineCurve   → OCCTConvertCompBezierToBSpline (v0.99.0)
// Convert_CompBezierCurves2dToBSplineCurve2d → OCCTConvertCompBezier2dToBSpline2d (v0.99.0)
//
// --- GeomFill ---
// GeomFill_BSplineCurves              → OCCTSurfaceBSplineFill*
// GeomFill_BezierCurves               → OCCTSurfaceBezierFill*
// GeomFill_ConstrainedFilling         → OCCTShapeConstrainedFill
// GeomFill_Coons                      → OCCTGeomFillCoons
// GeomFill_CoonsAlgPatch              → OCCTGeomFillCoonsAlgPatch
// GeomFill_CorrectedFrenet            → OCCTGeomFillCorrectedFrenet
// GeomFill_Curved                     → OCCTGeomFillCurved
// GeomFill_DiscreteTrihedron          → OCCTGeomFillDiscreteTrihedron
// GeomFill_ConstantBiNormal           → OCCTGeomFillConstantBiNormalTrihedron (v0.68.0)
// GeomFill_Darboux                    → OCCTGeomFillDarbouxTrihedron (v0.68.0)
// GeomFill_DraftTrihedron             → OCCTGeomFillDraftTrihedron
// GeomFill_EvolvedSection             → OCCTGeomFillEvolvedSection
// GeomFill_Fixed                      → OCCTGeomFillFixedTrihedron (v0.68.0)
// GeomFill_Frenet                     → OCCTGeomFillFrenetTrihedron (v0.68.0)
// GeomFill_NSections                  → OCCTGeomFillNSections (v0.68.0)
// GeomFill_Generator                  → OCCTGeomFillGenerator (v0.69.0)
// GeomFill_DegeneratedBound           → OCCTGeomFillDegeneratedBound (v0.69.0)
// GeomFill_BoundWithSurf              → OCCTGeomFillBoundWithSurf (v0.69.0)
// GeomFill_Pipe                       → OCCTSurfacePipe*
// GeomFill_SimpleBound                → OCCTShapeConstrainedFill
// GeomFill_Sweep                      → OCCTGeomFillSweep
//
// --- GeomInt ---
// GeomInt_IntSS                       → OCCTGeomIntSS*
//
// --- GeomLProp ---
// GeomLProp_CLProps                   → OCCTGeomLPropCurve
// GeomLProp_SLProps                   → OCCTGeomLPropSurface
//
// --- GeomPlate ---
// GeomPlate_BuildPlateSurface         → OCCTShapePlate*, OCCTGeomPlateSurface
// GeomPlate_BuildAveragePlane         → OCCTGeomPlateBuildAveragePlane (v0.69.0)
// GeomPlate_MakeApprox                → OCCTShapePlate*, OCCTGeomPlateSurface
//
// --- IntAna2d ---
// IntAna2d_AnaIntersection            → OCCTIntAna2d*
//
// --- IntCurvesFace ---
// IntCurvesFace_Intersector           → OCCTIntCurvesFaceIntersect
// IntCurvesFace_ShapeIntersector      → OCCTRayIntersect*
//
// --- IntTools ---
// IntTools_BeanFaceIntersector        → OCCTIntToolsBeanFaceIntersect
// IntTools_EdgeEdge                   → OCCTIntToolsEdgeEdge
// IntTools_EdgeFace                   → OCCTIntToolsEdgeFace
// IntTools_FaceFace                   → OCCTIntToolsFaceFace
// IntTools_FClass2d                   → OCCTIntToolsFClass2d*
//
// --- Law ---
// Law_BSpFunc                         → OCCTLawBSpline
// Law_BSpline                         → OCCTLawBSpline
// Law_Constant                        → OCCTLawConstant
// Law_Interpol                        → OCCTLawInterpolate
// Law_Linear                          → OCCTLawLinear
// Law_S                               → OCCTLawSCurve
// Law_BSplineKnotSplitting            → OCCTLawBSplineKnotSplitting (v0.68.0)
// Law_Composite                       → OCCTLawComposite (v0.68.0)
//
// --- Intf ---
// Intf_InterferencePolygon2d          → OCCTIntfInterferencePolygon2d (v0.68.0)
//
// --- LocOpe ---
// LocOpe_BuildShape                   → OCCTLocOpeBuildShape
// LocOpe_CSIntersector                → OCCTLocOpeCSIntersect
// LocOpe_DPrism                       → OCCTLocOpeDPrism
// LocOpe_FindEdges                    → OCCTLocOpeCommonEdges
// LocOpe_FindEdgesInFace              → OCCTLocOpeEdgesInFace
// LocOpe_Gluer                        → OCCTLocOpeGlue
// LocOpe_LinearForm                   → OCCTShapeLocalLinearForm
// LocOpe_Pipe                         → OCCTLocOpePipe
// LocOpe_Prism                        → OCCTLocOpePrism
// LocOpe_Revol                        → OCCTLocOpeRevol
// LocOpe_RevolutionForm               → OCCTShapeLocalRevolutionForm
// LocOpe_SplitDrafts                  → OCCTLocOpeSplitDrafts
// LocOpe_SplitShape                   → OCCTLocOpeSplitShape*
// LocOpe_Spliter                      → OCCTLocOpeSpliter*
// LocOpe_WiresOnShape                 → OCCTLocOpeWiresOnShape*
//
// --- LProp ---
// LProp_AnalyticCurInf                → OCCTLPropAnalyticCurInf
//
// --- NLPlate ---
// NLPlate_NLPlate                     → OCCTSurfaceNLPlateG0, OCCTSurfaceNLPlateG1, OCCTNLPlate*
// NLPlate_HPG0G2Constraint            → OCCTNLPlateG0G2
// NLPlate_HPG0G3Constraint            → OCCTNLPlateG0G3
//
// --- Plate ---
// Plate_Plate                         → OCCTPlate*
// Plate_PinpointConstraint            → OCCTPlateLoadPinpoint
// Plate_GtoCConstraint                → OCCTPlateLoadGtoC
//
// --- ProjLib ---
// ProjLib_ComputeApprox               → OCCTProjLibProjectOntoSurface
// ProjLib_ComputeApproxOnPolarSurface → OCCTProjLibProjectOntoPolarSurface
//
// --- ShapeAnalysis ---
// ShapeAnalysis_Curve                 → OCCTCurveRangeValid*, OCCTCurveSamplePoints, OCCTCurveProjectPoint
// ShapeAnalysis_FreeBoundsProperties  → OCCTShapeFreeBoundsAnalysis*
// ShapeAnalysis_Surface               → OCCTSurfaceUVProject*
// ShapeAnalysis_TransferParametersProj → OCCTShapeAnalysisTransferParam*
// ShapeAnalysis_WireOrder             → OCCTWireAnalyze
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
// ShapeCustom_DirectModification      → OCCTShapeDirectModification
// ShapeCustom_Surface                 → OCCTSurfaceConvertToAnalytical, OCCTSurfaceConvertToPeriodic, OCCTSurfaceConversionGap
// ShapeCustom_SweptToElementary       → OCCTShapeSweptToElementary
// ShapeCustom_TrsfModification        → OCCTShapeTrsfModificationScale
//
// --- ShapeExtend ---
// ShapeExtend_Explorer                → OCCTShapeExtendSorted*, OCCTShapeExtendPredominant*
//
// --- ShapeFix ---
// ShapeFix_Edge                       → OCCTShapeFixEdge*
// ShapeFix_Face                       → OCCTShapeFixFace
// ShapeFix_FaceConnect                → OCCTShapeFixConnect*
// ShapeFix_FixSmallFace               → OCCTShapeFixSmallFaces
// ShapeFix_FixSmallSolid              → OCCTShapeFixSmallSolid*
// ShapeFix_Shape                      → OCCTShapeFix, OCCTShapeFixed*
// ShapeFix_ShapeTolerance             → OCCTShapeLimitTolerance, OCCTShapeSetTolerance
// ShapeFix_Shell                      → OCCTShapeFixShell
// ShapeFix_SplitCommonVertex          → OCCTShapeFixSplitCommonVertex
// ShapeFix_Wire                       → OCCTShapeFixWire*
// ShapeFix_WireVertex                 → OCCTShapeFixWireVertices
// ShapeFix_Wireframe                  → OCCTShapeFixWireframe, OCCTShapeFixWireGaps, OCCTShapeFixSmallEdges (v0.99.0)
//
// --- ShapeUpgrade ---
// ShapeUpgrade_ConvertCurve3dToBezier → OCCTShapeUpgradeConvertCurves3dToBezier
// ShapeUpgrade_ConvertSurfaceToBezierBasis → OCCTShapeUpgradeConvertSurfaceToBezier
// ShapeUpgrade_FixSmallBezierCurves   → OCCTShapeUpgradeFixSmallBezierCurves
// ShapeUpgrade_FixSmallCurves         → OCCTShapeUpgradeFixSmallCurves
// ShapeUpgrade_ShapeConvertToBezier   → OCCTShapeUpgradeConvertCurves3dToBezier
// ShapeUpgrade_ShapeDivideClosed      → OCCTShapeDividedClosedEdges
// ShapeUpgrade_ShapeDivideContinuity  → OCCTShapeDividedByContinuity
// ShapeUpgrade_UnifySameDomain        → OCCTShapeUnified
//
// --- STEP/IGES/OBJ/PLY/STL ---
// STEPControl_Reader/Writer           → OCCTExportSTEP, OCCTImportSTEP*
// IGESControl_Reader/Writer           → OCCTExportIGES, OCCTImportIGES*
// RWObj_CafReader/Writer              → OCCTDocumentImportOBJ, OCCTDocumentExportOBJ
// RWPly_CafWriter                     → OCCTDocumentExportPLY
// StlAPI_Reader/Writer                → OCCTImportSTL, OCCTExportSTL
//
// --- TDF/OCAF ---
// TDF_Label                           → OCCTDocumentLabel*
// TDF_Reference                       → OCCTLabelSetReference
// TDF_CopyLabel                       → OCCTLabelCopy
// TDocStd_Document                    → OCCTDocument*
//
// --- TDataStd ---
// TDataStd_Integer/Real/AsciiString   → OCCTLabel{Set,Get}Integer/Real/AsciiString
// TDataStd_Comment                    → OCCTLabelSetComment
// TDataStd_IntegerArray/RealArray     → OCCTLabel*Array*
// TDataStd_NamedData                  → OCCTLabelNamedData*
// TDataStd_TreeNode                   → OCCTLabelSetTreeNode*
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
// TNaming_Builder                     → OCCTNamingBuilder*
// TNaming_CopyShape                   → OCCTShapeDeepCopy
// TNaming_Iterator                    → OCCTNamingIterateEntries
// TNaming_NamedShape                  → OCCTNamingGet*, OCCTNamingIsEmpty, OCCTNamingGetVersion/SetVersion
// TNaming_NewShapeIterator            → OCCTNamingNewShapeHistory
// TNaming_OldShapeIterator            → OCCTNamingOldShapeHistory
// TNaming_SameShapeIterator           → OCCTNamingSameShapeTags
// TNaming_Selector                    → OCCTDocumentNamingSelect*, OCCTDocumentNamingResolve*
// TNaming_Tool                        → OCCTNamingCurrentShape, OCCTNamingGetStoredShape, OCCTNamingOriginalShape, OCCTNamingHasLabel, OCCTNamingFindLabelTag, OCCTNamingValidUntil
//
// --- XCAFDoc ---
// XCAFDoc_AssemblyGraph               → OCCTAssemblyGraph*
// XCAFDoc_AssemblyItemId              → OCCTAssemblyItemId*
// XCAFDoc_ClippingPlaneTool           → OCCTDocumentClipPlaneTool*
// XCAFDoc_Color                       → OCCTDocumentSet/GetColorAttr*
// XCAFDoc_ColorTool                   → OCCTXCAFShape*Color*
// XCAFDoc_Editor                      → OCCTXCAFEditorExpand, OCCTXCAFRescaleGeometry
// XCAFDoc_GraphNode                   → OCCTDocumentGraphNode*
// XCAFDoc_LayerTool                   → OCCTXCAFSet/Get/FindLayer*
// XCAFDoc_Location                    → OCCTDocumentSet/GetLocation*
// XCAFDoc_Material                    → OCCTDocumentSet/GetMaterialAttr*
// XCAFDoc_NoteBalloon                 → OCCTDocumentSetNoteBalloon
// XCAFDoc_NoteBinData                 → OCCTDocumentSet/GetNoteBinData*
// XCAFDoc_NoteComment                 → OCCTDocumentSet/GetNoteComment*
// XCAFDoc_NotesTool                   → OCCTDocumentNotesTool*
// XCAFDoc_ShapeMapTool                → OCCTDocumentShapeMapTool*
// XCAFDoc_ShapeTool                   → OCCTXCAFShape*
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
// gp_Pnt2d/gp_Vec2d/gp_Dir2d         → OCCTCurve2D*, OCCTPoint2D*, OCCTVector2D*
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

// MARK: - Shape Creation (Primitives)

OCCTShapeRef OCCTShapeCreateBox(double width, double height, double depth);
OCCTShapeRef OCCTShapeCreateBoxAt(double x, double y, double z, double width, double height, double depth);
OCCTShapeRef _Nullable OCCTShapeCreateBoxOriented(
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double width, double height, double depth);
OCCTShapeRef OCCTShapeCreateCylinder(double radius, double height);
OCCTShapeRef OCCTShapeCreateCylinderAt(double cx, double cy, double bottomZ, double radius, double height);
/// Create a cylinder at an arbitrary origin along an arbitrary direction.
OCCTShapeRef _Nullable OCCTShapeCreateCylinderOriented(
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double radius, double height);
OCCTShapeRef _Nullable OCCTShapeCreateCylinderPartial(double radius, double height, double angle);
OCCTShapeRef OCCTShapeCreateToolSweep(double radius, double height, double x1, double y1, double z1, double x2, double y2, double z2);
OCCTShapeRef OCCTShapeCreateSphere(double radius);
OCCTShapeRef _Nullable OCCTShapeCreateSphereAtCenter(double cx, double cy, double cz, double radius);
OCCTShapeRef _Nullable OCCTShapeCreateSphereOriented(
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double radius);
OCCTShapeRef _Nullable OCCTShapeCreateSpherePartial(double radius, double angle);
OCCTShapeRef _Nullable OCCTShapeCreateSphereOrientedPartial(
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double radius, double angle);
OCCTShapeRef _Nullable OCCTShapeCreateSphereOrientedSegment(
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double radius, double angle1, double angle2);
OCCTShapeRef OCCTShapeCreateCone(double bottomRadius, double topRadius, double height);
OCCTShapeRef _Nullable OCCTShapeCreateConeOriented(
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double bottomRadius, double topRadius, double height);
OCCTShapeRef _Nullable OCCTShapeCreateConeOrientedPartial(
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double bottomRadius, double topRadius, double height, double angle);
OCCTShapeRef OCCTShapeCreateTorus(double majorRadius, double minorRadius);
OCCTShapeRef _Nullable OCCTShapeCreateTorusOriented(
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double majorRadius, double minorRadius);
OCCTShapeRef _Nullable OCCTShapeCreateTorusOrientedPartial(
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double majorRadius, double minorRadius, double angle);
OCCTShapeRef _Nullable OCCTShapeCreateTorusOrientedSegment(
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double majorRadius, double minorRadius, double angle1, double angle2);
OCCTShapeRef _Nullable OCCTShapeCreateCylinderOrientedPartial(
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double radius, double height, double angle);

// MARK: - Shape Creation (Sweeps)

OCCTShapeRef OCCTShapeCreatePipeSweep(OCCTWireRef profile, OCCTWireRef path);
OCCTShapeRef OCCTShapeCreateExtrusion(OCCTWireRef profile, double dx, double dy, double dz, double length);
/// Extrude a shape along a direction to infinity (or semi-infinite).
OCCTShapeRef _Nullable OCCTShapeCreateExtrusionInfinite(OCCTShapeRef _Nonnull shape,
    double dirX, double dirY, double dirZ, bool infinite);
/// Extrude a shape by a vector (general shape, not just wire).
OCCTShapeRef _Nullable OCCTShapeCreateExtrusionShape(OCCTShapeRef _Nonnull shape,
    double dx, double dy, double dz);
OCCTShapeRef OCCTShapeCreateRevolution(OCCTWireRef profile, double axisX, double axisY, double axisZ, double dirX, double dirY, double dirZ, double angle);
/// Revolve a shape (not just wire) around an axis by a full 360 degrees.
OCCTShapeRef _Nullable OCCTShapeCreateRevolutionFull(OCCTShapeRef _Nonnull shape,
    double axisX, double axisY, double axisZ,
    double dirX, double dirY, double dirZ);
/// Revolve a shape (not just wire) around an axis by a partial angle.
OCCTShapeRef _Nullable OCCTShapeCreateRevolutionPartial(OCCTShapeRef _Nonnull shape,
    double axisX, double axisY, double axisZ,
    double dirX, double dirY, double dirZ,
    double angle);
OCCTShapeRef OCCTShapeCreateLoft(const OCCTWireRef* profiles, int32_t count, bool solid);

// MARK: - Boolean Operations

OCCTShapeRef OCCTShapeUnion(OCCTShapeRef shape1, OCCTShapeRef shape2);
OCCTShapeRef OCCTShapeSubtract(OCCTShapeRef shape1, OCCTShapeRef shape2);
OCCTShapeRef OCCTShapeIntersect(OCCTShapeRef shape1, OCCTShapeRef shape2);

// Boolean ops with robustness levers: fuzzyValue (tolerance-based fuzzy boolean;
// <= 0 keeps OCCT's default), glue (0 = off, 1 = BOPAlgo_GlueShift, 2 = BOPAlgo_GlueFull;
// glue helps when arguments share coincident faces). #202
// timeoutSeconds bounds the build via a wall-clock UserBreak watchdog; <= 0 means no
// bound. On timeout (or failure) the op returns NULL instead of hanging. #206
OCCTShapeRef OCCTShapeUnionEx(OCCTShapeRef shape1, OCCTShapeRef shape2, double fuzzyValue, int32_t glue, double timeoutSeconds);
OCCTShapeRef OCCTShapeSubtractEx(OCCTShapeRef shape1, OCCTShapeRef shape2, double fuzzyValue, int32_t glue, double timeoutSeconds);
OCCTShapeRef OCCTShapeIntersectEx(OCCTShapeRef shape1, OCCTShapeRef shape2, double fuzzyValue, int32_t glue, double timeoutSeconds);

// Self-interference check (BOPAlgo_ArgumentAnalyzer), watchdog-bounded by timeoutSeconds
// (<= 0 = unbounded). Detects the self-intersection that BRepCheck misses and that hangs
// booleans (#206/#208). Returns 1 = self-intersects, 0 = clean, -1 = indeterminate.
// (Distinct from the older unbounded bool OCCTShapeSelfIntersects via BOPAlgo_CheckerSI.)
int32_t OCCTShapeSelfIntersectsBounded(OCCTShapeRef shape, double timeoutSeconds);

// MARK: - Modifications

OCCTShapeRef OCCTShapeFillet(OCCTShapeRef shape, double radius);
OCCTShapeRef OCCTShapeChamfer(OCCTShapeRef shape, double distance);
OCCTShapeRef OCCTShapeShell(OCCTShapeRef shape, double thickness);
OCCTShapeRef OCCTShapeOffset(OCCTShapeRef shape, double distance);

// MARK: - Transformations

OCCTShapeRef OCCTShapeTranslate(OCCTShapeRef shape, double dx, double dy, double dz);
OCCTShapeRef OCCTShapeRotate(OCCTShapeRef shape, double axisX, double axisY, double axisZ, double angle);
OCCTShapeRef OCCTShapeScale(OCCTShapeRef shape, double factor);
OCCTShapeRef OCCTShapeMirror(OCCTShapeRef shape, double originX, double originY, double originZ, double normalX, double normalY, double normalZ);

// MARK: - Compound

OCCTShapeRef OCCTShapeCreateCompound(const OCCTShapeRef* shapes, int32_t count);

// MARK: - Validation

bool OCCTShapeIsValid(OCCTShapeRef shape);
OCCTShapeRef OCCTShapeHeal(OCCTShapeRef shape);

// MARK: - Measurement & Analysis (v0.7.0)

/// Mass properties result structure
typedef struct {
    double volume;           // Cubic units
    double surfaceArea;      // Square units
    double mass;             // With density applied
    double centerX, centerY, centerZ;  // Center of mass
    double ixx, ixy, ixz;    // Inertia tensor row 1
    double iyx, iyy, iyz;    // Inertia tensor row 2
    double izx, izy, izz;    // Inertia tensor row 3
    bool isValid;
} OCCTShapeProperties;

/// Get full mass properties of a shape
/// @param shape The shape to analyze
/// @param density Density for mass calculation (use 1.0 for volume-only calculations)
/// @return Properties structure with isValid indicating success
OCCTShapeProperties OCCTShapeGetProperties(OCCTShapeRef shape, double density);

/// Get volume of a shape (convenience function)
/// @param shape The shape to measure
/// @return Volume in cubic units, or -1.0 on error
double OCCTShapeGetVolume(OCCTShapeRef shape);

/// Get surface area of a shape (convenience function)
/// @param shape The shape to measure
/// @return Surface area in square units, or -1.0 on error
double OCCTShapeGetSurfaceArea(OCCTShapeRef shape);

/// Get center of mass of a shape (convenience function)
/// @param shape The shape to analyze
/// @param outX, outY, outZ Output: center of mass coordinates
/// @return true on success, false on error
bool OCCTShapeGetCenterOfMass(OCCTShapeRef shape, double* outX, double* outY, double* outZ);

/// Distance measurement result structure
typedef struct {
    double distance;         // Minimum distance between shapes
    double p1x, p1y, p1z;    // Closest point on shape1
    double p2x, p2y, p2z;    // Closest point on shape2
    int32_t solutionCount;   // Number of solutions found
    bool isValid;
} OCCTDistanceResult;

/// Compute minimum distance between two shapes
/// @param shape1 First shape
/// @param shape2 Second shape
/// @param deflection Deflection tolerance for curved geometry (use 1e-6 for default)
/// @return Distance result with isValid indicating success
OCCTDistanceResult OCCTShapeDistance(OCCTShapeRef shape1, OCCTShapeRef shape2, double deflection);

/// Check if two shapes intersect (overlap in space)
/// @param shape1 First shape
/// @param shape2 Second shape
/// @param tolerance Tolerance for intersection test
/// @return true if shapes intersect or touch, false otherwise
bool OCCTShapeIntersects(OCCTShapeRef shape1, OCCTShapeRef shape2, double tolerance);

/// Get total number of vertices in a shape
int32_t OCCTShapeGetVertexCount(OCCTShapeRef shape);

/// Get vertex coordinates at index
/// @param shape The shape containing vertices
/// @param index Vertex index (0-based)
/// @param outX, outY, outZ Output: vertex coordinates
/// @return true on success, false if index out of bounds
bool OCCTShapeGetVertexAt(OCCTShapeRef shape, int32_t index, double* outX, double* outY, double* outZ);

/// Get all vertices as an array
/// @param shape The shape containing vertices
/// @param outVertices Output array for vertices [x,y,z,...] (caller allocates vertexCount*3 doubles)
/// @return Number of vertices written
int32_t OCCTShapeGetVertices(OCCTShapeRef shape, double* outVertices);

// MARK: - Meshing

OCCTMeshRef OCCTShapeCreateMesh(OCCTShapeRef shape, double linearDeflection, double angularDeflection);

/// Enhanced mesh parameters for fine control over tessellation
typedef struct {
    double deflection;           // Linear deflection for boundary edges
    double angle;                // Angular deflection for boundary edges (radians)
    double deflectionInterior;   // Linear deflection for face interior (0 = same as deflection)
    double angleInterior;        // Angular deflection for face interior (0 = same as angle)
    double minSize;              // Minimum element size (0 = no minimum)
    bool relative;               // Use relative deflection (proportion of edge size)
    bool inParallel;             // Enable multi-threaded meshing
    bool internalVertices;       // Generate vertices inside faces
    bool controlSurfaceDeflection; // Validate surface approximation quality
    bool adjustMinSize;          // Auto-adjust minSize based on edge size
} OCCTMeshParameters;

/// Create mesh with enhanced parameters
OCCTMeshRef OCCTShapeCreateMeshWithParams(OCCTShapeRef shape, OCCTMeshParameters params);

/// Get default mesh parameters
OCCTMeshParameters OCCTMeshParametersDefault(void);

/// Construct a Mesh directly from raw triangulation arrays.
///
/// `vertices` is `vertexCount` packed (x, y, z) triplets (so `vertexCount * 3` floats).
/// `normals`, if non-NULL, is the same shape and must match `vertexCount`. Pass NULL
/// to have per-vertex normals computed from triangle face-normals (smooth shading).
/// `indices` is `indexCount` UInt32 indices forming `indexCount / 3` triangles; each
/// index must be < `vertexCount`.
///
/// Returns NULL if any input is invalid (empty, mismatched normal count,
/// `indexCount` not divisible by 3, or any index out of range), or on
/// allocation failure. Caller releases the result via `OCCTMeshRelease`.
OCCTMeshRef OCCTMeshCreateFromArrays(
    const float* vertices,
    uint32_t vertexCount,
    const float* normals,
    const uint32_t* indices,
    uint32_t indexCount
);

// MARK: - Edge Discretization

/// Ensure all edges in a shape have explicit 3D curves.
/// Call before allEdgePolylines on lofted/swept shapes where edges may only have pcurves.
/// Safe to call multiple times — only builds missing curves.
void OCCTShapeBuildCurves3d(OCCTShapeRef shape);

/// Get discretized edge as polyline points
/// @param shape The shape containing edges
/// @param edgeIndex Index of the edge (0-based)
/// @param deflection Linear deflection for discretization
/// @param outPoints Output array for points [x,y,z,...] (caller allocates)
/// @param maxPoints Maximum points to return
/// @return Number of points written, or -1 on error
int32_t OCCTShapeGetEdgePolyline(OCCTShapeRef shape, int32_t edgeIndex, double deflection, double* outPoints, int32_t maxPoints);

// MARK: - Triangle Access

/// Triangle data with face reference
typedef struct {
    uint32_t v1, v2, v3;    // Vertex indices
    int32_t faceIndex;       // Source B-Rep face index (-1 if unknown)
    float nx, ny, nz;        // Triangle normal
} OCCTTriangle;

/// Get triangles with face association and normals
/// @param mesh The mesh to query
/// @param outTriangles Output array (caller allocates with triangleCount elements)
/// @return Number of triangles written
int32_t OCCTMeshGetTrianglesWithFaces(OCCTMeshRef mesh, OCCTTriangle* outTriangles);

// MARK: - Mesh to Shape Conversion

/// Convert a mesh (triangulation) to a B-Rep shape (compound of faces)
/// @param mesh The mesh to convert
/// @return Shape containing triangulated faces, or NULL on failure
OCCTShapeRef OCCTMeshToShape(OCCTMeshRef mesh);

/// Convert a mesh to a B-Rep shape with a caller-supplied sewing (vertex-weld) tolerance.
/// The weld tolerance must scale with the mesh's coordinate magnitude — too small for a
/// large-coordinate mesh leaves the shell open. @param weldTolerance edge-merge tolerance
/// (model units); pass 1e-6 to reproduce the default behaviour of OCCTMeshToShape.
/// @return Shape containing triangulated faces, or NULL on failure
OCCTShapeRef OCCTMeshToShapeWithTolerance(OCCTMeshRef mesh, double weldTolerance);

// MARK: - Mesh Booleans (via B-Rep roundtrip)

/// Perform boolean union on two meshes
/// @param mesh1 First mesh
/// @param mesh2 Second mesh
/// @param deflection Deflection for re-meshing result
/// @return Result mesh, or NULL on failure
OCCTMeshRef OCCTMeshUnion(OCCTMeshRef mesh1, OCCTMeshRef mesh2, double deflection);

/// Perform boolean subtraction on two meshes (mesh1 - mesh2)
OCCTMeshRef OCCTMeshSubtract(OCCTMeshRef mesh1, OCCTMeshRef mesh2, double deflection);

/// Perform boolean intersection on two meshes
OCCTMeshRef OCCTMeshIntersect(OCCTMeshRef mesh1, OCCTMeshRef mesh2, double deflection);

// MARK: - Shape Conversion

OCCTShapeRef OCCTShapeFromWire(OCCTWireRef wireRef);
OCCTShapeRef OCCTShapeFromFace(OCCTFaceRef faceRef);

/// Construct a Face reference from a Shape that wraps a TopoDS_Face.
/// Returns NULL if the shape is null or its topology type is not TopAbs_FACE.
/// Caller owns the returned reference and must release it.
OCCTFaceRef OCCTFaceFromShape(OCCTShapeRef shape);

/// Construct a Wire reference from a Shape that wraps a TopoDS_Wire.
/// Returns NULL if the shape is null or its topology type is not TopAbs_WIRE.
/// Caller owns the returned reference and must release it.
OCCTWireRef OCCTWireFromShape(OCCTShapeRef shape);

// MARK: - Memory Management

void OCCTShapeRelease(OCCTShapeRef shape);
void OCCTWireRelease(OCCTWireRef wire);
void OCCTMeshRelease(OCCTMeshRef mesh);

// MARK: - Wire Creation (2D Profiles)

OCCTWireRef OCCTWireCreateRectangle(double width, double height);
OCCTWireRef OCCTWireCreateCircle(double radius);
OCCTWireRef OCCTWireCreateCircleEx(double radius,
    double ox, double oy, double oz,
    double nx, double ny, double nz);
OCCTWireRef OCCTWireCreatePolygon(const double* points, int32_t pointCount, bool closed);
OCCTWireRef OCCTWireCreateFromPoints3D(const double* points, int32_t pointCount, bool closed);

// MARK: - Wire Creation (3D Paths)

OCCTWireRef OCCTWireCreateLine(double x1, double y1, double z1, double x2, double y2, double z2);
OCCTWireRef OCCTWireCreateArc(double centerX, double centerY, double centerZ, double radius, double startAngle, double endAngle, double normalX, double normalY, double normalZ);
/// Build an arc-wire from three points (start, midpoint on the arc, end).
/// Avoids the gp_Ax2 X-direction ambiguity that the angle-based arc API has.
/// Returns NULL if the three points are collinear or the arc cannot be built.
OCCTWireRef OCCTWireCreateArcThroughPoints(double sx, double sy, double sz,
                                            double mx, double my, double mz,
                                            double ex, double ey, double ez);
OCCTWireRef OCCTWireCreateBSpline(const double* controlPoints, int32_t pointCount);
OCCTWireRef OCCTWireJoin(const OCCTWireRef* wires, int32_t count);

// MARK: - NURBS Curve Creation

/// Create a NURBS curve with full control over all parameters
/// @param poles Control points as [x,y,z] triplets (count = poleCount * 3)
/// @param poleCount Number of control points
/// @param weights Weight for each control point (count = poleCount, NULL for uniform weights)
/// @param knots Knot values (count = knotCount)
/// @param knotCount Number of distinct knot values
/// @param multiplicities Multiplicity of each knot (count = knotCount, NULL for all 1s)
/// @param degree Curve degree (1=linear, 2=quadratic, 3=cubic, etc.)
OCCTWireRef OCCTWireCreateNURBS(
    const double* poles,
    int32_t poleCount,
    const double* weights,
    const double* knots,
    int32_t knotCount,
    const int32_t* multiplicities,
    int32_t degree
);

/// Create a NURBS curve with uniform knots (clamped, uniform parameterization)
/// @param poles Control points as [x,y,z] triplets (count = poleCount * 3)
/// @param poleCount Number of control points
/// @param weights Weight for each control point (NULL for uniform weights = non-rational B-spline)
/// @param degree Curve degree (1=linear, 2=quadratic, 3=cubic)
OCCTWireRef OCCTWireCreateNURBSUniform(
    const double* poles,
    int32_t poleCount,
    const double* weights,
    int32_t degree
);

/// Create a clamped cubic B-spline through given control points (non-rational)
/// @param poles Control points as [x,y,z] triplets
/// @param poleCount Number of control points (minimum 4 for cubic)
OCCTWireRef OCCTWireCreateCubicBSpline(const double* poles, int32_t poleCount);

// MARK: - Mesh Access

int32_t OCCTMeshGetVertexCount(OCCTMeshRef mesh);
int32_t OCCTMeshGetTriangleCount(OCCTMeshRef mesh);
void OCCTMeshGetVertices(OCCTMeshRef mesh, float* outVertices);
void OCCTMeshGetNormals(OCCTMeshRef mesh, float* outNormals);
void OCCTMeshGetIndices(OCCTMeshRef mesh, uint32_t* outIndices);

// MARK: - Export

bool OCCTExportSTL(OCCTShapeRef shape, const char* path, double deflection);
bool OCCTExportSTLWithMode(OCCTShapeRef shape, const char* path, double deflection, bool ascii);
bool OCCTExportSTEP(OCCTShapeRef shape, const char* path);
bool OCCTExportSTEPWithName(OCCTShapeRef shape, const char* path, const char* name);

// MARK: - Import

OCCTShapeRef OCCTImportSTEP(const char* path);

// MARK: - Import progress + cancellation (v0.168.0, issue #98)
//
// Wrapper for OCCT's Message_ProgressIndicator. Pass a non-NULL OCCTImportProgress
// struct to the *Progress entry points to receive progress callbacks during
// STEP/IGES TransferRoots and to request cooperative cancellation.
//
// Lifetime: the OCCTImportProgress* must remain valid for the duration of the
// import call. The bridge does not retain it. userData is passed back unchanged.
//
// Cancellation: if shouldCancel returns true, OCCT stops at the next polling
// boundary. The *Progress entry points return NULL and set *outCancelled=true.
// If the import otherwise fails, NULL is returned and *outCancelled stays false.

typedef struct OCCTImportProgress {
    /// Called as the importer advances. fraction is 0.0...1.0; step is a
    /// human-readable name of the current sub-task (may be NULL or empty).
    void (* _Nullable onProgress)(double fraction, const char* _Nullable step, void* _Nullable userData);

    /// Return true to cooperatively cancel the in-flight import.
    bool (* _Nullable shouldCancel)(void* _Nullable userData);

    /// Opaque pointer passed back to onProgress and shouldCancel.
    void* _Nullable userData;
} OCCTImportProgress;

OCCTShapeRef _Nullable OCCTImportSTEPProgress(const char* _Nonnull path,
                                                const OCCTImportProgress* _Nullable ctx,
                                                bool* _Nullable outCancelled);

OCCTShapeRef _Nullable OCCTImportSTEPRobustProgress(const char* _Nonnull path,
                                                      const OCCTImportProgress* _Nullable ctx,
                                                      bool* _Nullable outCancelled);

OCCTShapeRef _Nullable OCCTImportSTEPWithUnitProgress(const char* _Nonnull path, double unitInMeters,
                                                       const OCCTImportProgress* _Nullable ctx,
                                                       bool* _Nullable outCancelled);

OCCTShapeRef _Nullable OCCTImportIGESProgress(const char* _Nonnull path,
                                                const OCCTImportProgress* _Nullable ctx,
                                                bool* _Nullable outCancelled);

OCCTShapeRef _Nullable OCCTImportIGESRobustProgress(const char* _Nonnull path,
                                                      const OCCTImportProgress* _Nullable ctx,
                                                      bool* _Nullable outCancelled);

// MARK: - Mesh + export progress (v0.169.0, follow-up to issue #98)
//
// Same OCCTImportProgress channel, different operations. The struct name is
// kept for ABI compatibility; the OperationProgress / ExportProgress / MeshProgress
// Swift typealiases live in the OCCTSwift module.

/// Run BRepMesh_IncrementalMesh on a shape with optional progress + cancellation.
/// Returns the meshed shape (same handle, mutated in place; new OCCTShape wrapping the
/// same TopoDS_Shape) on success, or nullptr on failure / cancellation. Sets
/// *outCancelled=true on cancellation.
OCCTShapeRef _Nullable OCCTShapeIncrementalMeshProgress(OCCTShapeRef _Nonnull shape,
                                                          double linearDeflection,
                                                          double angularDeflection,
                                                          const OCCTImportProgress* _Nullable ctx,
                                                          bool* _Nullable outCancelled);

/// Export a shape to STEP with optional progress + cancellation.
bool OCCTExportSTEPProgress(OCCTShapeRef _Nonnull shape, const char* _Nonnull path,
                             const OCCTImportProgress* _Nullable ctx,
                             bool* _Nullable outCancelled);

/// Export a shape to STEP with explicit model type + progress.
bool OCCTExportSTEPWithModeProgress(OCCTShapeRef _Nonnull shape, const char* _Nonnull path,
                                      int32_t modelType,
                                      const OCCTImportProgress* _Nullable ctx,
                                      bool* _Nullable outCancelled);

/// Export a shape to IGES with optional progress + cancellation.
bool OCCTExportIGESProgress(OCCTShapeRef _Nonnull shape, const char* _Nonnull path,
                             const OCCTImportProgress* _Nullable ctx,
                             bool* _Nullable outCancelled);

// Document progress entry points are declared further down (after OCCTDocumentRef typedef).

// MARK: - Robust STEP Import

/// Import result structure with diagnostics
typedef struct {
    OCCTShapeRef shape;
    int originalType;   // TopAbs_ShapeEnum: 0=Compound, 1=CompSolid, 2=Solid, 3=Shell, 4=Face, etc.
    int resultType;     // Type after processing
    bool sewingApplied;
    bool solidCreated;
    bool healingApplied;
} OCCTSTEPImportResult;

/// Import STEP file with robust handling: sewing, solid creation, and shape healing
OCCTShapeRef OCCTImportSTEPRobust(const char* path);

/// Import STEP file with diagnostic information
OCCTSTEPImportResult OCCTImportSTEPWithDiagnostics(const char* path);

/// Get shape type (TopAbs_ShapeEnum value)
int OCCTShapeGetType(OCCTShapeRef shape);

/// Check if shape is a valid closed solid
bool OCCTShapeIsValidSolid(OCCTShapeRef shape);

// MARK: - Bounds

void OCCTShapeGetBounds(OCCTShapeRef shape, double* minX, double* minY, double* minZ, double* maxX, double* maxY, double* maxZ);

// MARK: - Slicing

OCCTShapeRef OCCTShapeSliceAtZ(OCCTShapeRef shape, double z);
int32_t OCCTShapeGetEdgeCount(OCCTShapeRef shape);
int32_t OCCTShapeGetEdgePoints(OCCTShapeRef shape, int32_t edgeIndex, double* outPoints, int32_t maxPoints);
int32_t OCCTShapeGetContourPoints(OCCTShapeRef shape, double* outPoints, int32_t maxPoints);

// MARK: - CAM Operations

/// Offset a planar wire by a distance (positive = outward, negative = inward)
/// @param wire The wire to offset (must be planar)
/// @param distance Offset distance (positive = outward, negative = inward)
/// @param joinType Join type: 0 = arc (round corners), 1 = intersection (sharp corners)
/// @return Offset wire, or NULL on failure
OCCTWireRef OCCTWireOffset(OCCTWireRef wire, double distance, int32_t joinType);

/// Get closed wires from a shape section at Z level
/// @param shape The shape to section
/// @param z The Z level to section at
/// @param tolerance Tolerance for connecting edges into wires (use 1e-6 for default)
/// @param outCount Output: number of wires returned
/// @return Array of wire references, or NULL on failure. Caller must free with OCCTFreeWireArray.
OCCTWireRef* OCCTShapeSectionWiresAtZ(OCCTShapeRef shape, double z, double tolerance, int32_t* outCount);

/// Free an array of wires returned by OCCTShapeSectionWiresAtZ (frees wires AND array)
/// @param wires Array of wire references
/// @param count Number of wires in the array
void OCCTFreeWireArray(OCCTWireRef* wires, int32_t count);

/// Free only the array container, not the wires - use when Swift takes ownership of wire handles
/// @param wires Array of wire references
void OCCTFreeWireArrayOnly(OCCTWireRef* wires);

// MARK: - Face Analysis (for solid-based CAM)

/// Get all faces from a shape
/// @param shape The shape to extract faces from
/// @param outCount Output: number of faces returned
/// @return Array of face references, or NULL on failure. Caller must free with OCCTFreeFaceArray.
OCCTFaceRef* OCCTShapeGetFaces(OCCTShapeRef shape, int32_t* outCount);

/// Free an array of faces (frees faces AND array)
/// @param faces Array of face references
/// @param count Number of faces in the array
void OCCTFreeFaceArray(OCCTFaceRef* faces, int32_t count);

/// Free only the face array container, not the faces - use when Swift takes ownership
/// @param faces Array of face references
void OCCTFreeFaceArrayOnly(OCCTFaceRef* faces);

/// Release a single face
void OCCTFaceRelease(OCCTFaceRef face);

/// Get the normal vector at the center of a face
/// @param face The face to get normal from
/// @param outNx, outNy, outNz Output: normal vector components
/// @return true if successful, false if normal could not be computed
bool OCCTFaceGetNormal(OCCTFaceRef face, double* outNx, double* outNy, double* outNz);

/// Get the outer wire (boundary) of a face
/// @param face The face to get outer wire from
/// @return Wire reference, or NULL on failure. Caller must release with OCCTWireRelease.
OCCTWireRef OCCTFaceGetOuterWire(OCCTFaceRef face);

/// Get the bounding box of a face
/// @param face The face to get bounds from
void OCCTFaceGetBounds(OCCTFaceRef face, double* minX, double* minY, double* minZ, double* maxX, double* maxY, double* maxZ);

/// Check if a face is planar (flat)
/// @param face The face to check
/// @return true if the face is planar
bool OCCTFaceIsPlanar(OCCTFaceRef face);

/// Get the Z level of a horizontal planar face
/// @param face The face to get Z from
/// @param outZ Output: Z coordinate of the face plane
/// @return true if face is horizontal and Z was computed, false otherwise
bool OCCTFaceGetZLevel(OCCTFaceRef face, double* outZ);

/// Get horizontal faces from a shape (faces with normals pointing up or down)
/// @param shape The shape to search
/// @param tolerance Angle tolerance in radians (e.g., 0.01 for ~0.5 degrees)
/// @param outCount Output: number of faces returned
/// @return Array of face references for horizontal faces only
OCCTFaceRef* OCCTShapeGetHorizontalFaces(OCCTShapeRef shape, double tolerance, int32_t* outCount);

/// Get upward-facing horizontal faces (potential pocket floors)
/// @param shape The shape to search
/// @param tolerance Angle tolerance in radians
/// @param outCount Output: number of faces returned
/// @return Array of face references for upward-facing horizontal faces
OCCTFaceRef* OCCTShapeGetUpwardFaces(OCCTShapeRef shape, double tolerance, int32_t* outCount);

// MARK: - Ray Casting & Selection (Issues #12, #13, #14)

/// Ray hit result structure
typedef struct {
    double point[3];        // 3D intersection point
    double normal[3];       // Surface normal at hit
    int32_t faceIndex;      // Index of hit face
    double distance;        // Distance from ray origin
    double uv[2];           // UV parameters on surface
} OCCTRayHit;

/// Cast ray against shape and return all intersections
/// @param shape The shape to test against
/// @param originX, originY, originZ Ray origin
/// @param dirX, dirY, dirZ Ray direction (will be normalized)
/// @param tolerance Intersection tolerance
/// @param outHits Output array for hits (caller allocates)
/// @param maxHits Maximum number of hits to return
/// @return Number of hits found, or -1 on error
int32_t OCCTShapeRaycast(
    OCCTShapeRef shape,
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double tolerance,
    OCCTRayHit* outHits,
    int32_t maxHits
);

/// Get total number of faces in a shape
int32_t OCCTShapeGetFaceCount(OCCTShapeRef shape);

/// Get face by index (0-based)
/// @param shape The shape containing faces
/// @param index Face index (0-based)
/// @return Face reference, or NULL if index out of bounds
OCCTFaceRef OCCTShapeGetFaceAtIndex(OCCTShapeRef shape, int32_t index);

// MARK: - Edge Access (Issue #14)

typedef struct OCCTEdge* OCCTEdgeRef;

/// Get total number of edges in a shape
int32_t OCCTShapeGetTotalEdgeCount(OCCTShapeRef shape);

/// Get edge by index (0-based)
/// @param shape The shape containing edges
/// @param index Edge index (0-based)
/// @return Edge reference, or NULL if index out of bounds. Caller must release.
OCCTEdgeRef OCCTShapeGetEdgeAtIndex(OCCTShapeRef shape, int32_t index);

/// Release an edge reference
void OCCTEdgeRelease(OCCTEdgeRef edge);

/// Convert an edge to a shape
OCCTShapeRef OCCTShapeFromEdge(OCCTEdgeRef edgeRef);

/// Construct an Edge reference from a Shape that wraps a TopoDS_Edge.
/// Returns NULL if the shape is null or its topology type is not TopAbs_EDGE.
/// Caller owns the returned reference and must release it.
OCCTEdgeRef OCCTEdgeFromShape(OCCTShapeRef shape);

/// Get edge length
double OCCTEdgeGetLength(OCCTEdgeRef edge);

/// Get edge bounding box
void OCCTEdgeGetBounds(OCCTEdgeRef edge, double* minX, double* minY, double* minZ, double* maxX, double* maxY, double* maxZ);

/// Get points along edge curve
/// @param edge The edge to sample
/// @param count Number of points to generate
/// @param outPoints Output array [x,y,z,...] (caller allocates count*3 doubles)
/// @return Actual number of points written
int32_t OCCTEdgeGetPoints(OCCTEdgeRef edge, int32_t count, double* outPoints);

/// Check if edge is a line
bool OCCTEdgeIsLine(OCCTEdgeRef edge);

/// Check if edge is a circle/arc
bool OCCTEdgeIsCircle(OCCTEdgeRef edge);

/// Get start and end vertices of edge
void OCCTEdgeGetEndpoints(OCCTEdgeRef edge, double* startX, double* startY, double* startZ, double* endX, double* endY, double* endZ);


// MARK: - Attributed Adjacency Graph (AAG) Support

/// Edge convexity type for AAG
typedef enum {
    OCCTEdgeConvexityConcave = -1,  // Interior angle > 180° (pocket-like)
    OCCTEdgeConvexitySmooth = 0,    // Tangent faces (180°)
    OCCTEdgeConvexityConvex = 1     // Interior angle < 180° (fillet-like)
} OCCTEdgeConvexity;

/// Get the two faces adjacent to an edge within a shape
/// @param shape The shape containing the edge and faces
/// @param edge The edge to query
/// @param outFace1 Output: first adjacent face (caller must release)
/// @param outFace2 Output: second adjacent face (caller must release), may be NULL for boundary edges
/// @return Number of adjacent faces (0, 1, or 2)
int32_t OCCTEdgeGetAdjacentFaces(OCCTShapeRef shape, OCCTEdgeRef edge, OCCTFaceRef* outFace1, OCCTFaceRef* outFace2);

/// Determine the convexity of an edge between two faces
/// @param shape The shape containing the geometry
/// @param edge The shared edge
/// @param face1 First adjacent face
/// @param face2 Second adjacent face
/// @return Convexity type (concave, smooth, or convex)
OCCTEdgeConvexity OCCTEdgeGetConvexity(OCCTShapeRef shape, OCCTEdgeRef edge, OCCTFaceRef face1, OCCTFaceRef face2);

/// Get all edges shared between two faces
/// @param shape The shape containing the faces
/// @param face1 First face
/// @param face2 Second face  
/// @param outEdges Output array for shared edges (caller allocates)
/// @param maxEdges Maximum number of edges to return
/// @return Number of shared edges found
int32_t OCCTFaceGetSharedEdges(OCCTShapeRef shape, OCCTFaceRef face1, OCCTFaceRef face2, OCCTEdgeRef* outEdges, int32_t maxEdges);

/// Check if two faces are adjacent (share at least one edge)
bool OCCTFacesAreAdjacent(OCCTShapeRef shape, OCCTFaceRef face1, OCCTFaceRef face2);

/// Get the dihedral angle between two adjacent faces at their shared edge
/// @param edge The shared edge
/// @param face1 First face
/// @param face2 Second face
/// @param parameter Parameter along edge (0.0 to 1.0) where to measure angle
/// @return Dihedral angle in radians (0 to 2*PI), or -1 on error
double OCCTEdgeGetDihedralAngle(OCCTEdgeRef edge, OCCTFaceRef face1, OCCTFaceRef face2, double parameter);


// MARK: - XDE/XCAF Document Support (v0.6.0)

/// Opaque handle for XDE document
typedef struct OCCTDocument* OCCTDocumentRef;

OCCTDocumentRef _Nullable OCCTDocumentLoadSTEPProgress(const char* _Nonnull path,
                                                         const OCCTImportProgress* _Nullable ctx,
                                                         bool* _Nullable outCancelled);

OCCTDocumentRef _Nullable OCCTDocumentLoadSTEPWithModesProgress(const char* _Nonnull path,
                                                                  bool colorMode, bool nameMode, bool layerMode,
                                                                  bool propsMode, bool gdtMode, bool matMode,
                                                                  const OCCTImportProgress* _Nullable ctx,
                                                                  bool* _Nullable outCancelled);

/// Write a Document to STEP with optional progress + cancellation.
bool OCCTDocumentWriteSTEPProgress(OCCTDocumentRef _Nonnull doc, const char* _Nonnull path,
                                     const OCCTImportProgress* _Nullable ctx,
                                     bool* _Nullable outCancelled);

/// Create a new empty XDE document
OCCTDocumentRef OCCTDocumentCreate(void);

/// Load STEP file into XDE document with assembly structure, names, colors, materials
/// @param path Path to STEP file
/// @return Document reference, or NULL on failure
OCCTDocumentRef OCCTDocumentLoadSTEP(const char* path);

/// Write document to STEP file (preserves assembly structure, colors, materials)
/// @param doc Document to write
/// @param path Output file path
/// @return true on success
bool OCCTDocumentWriteSTEP(OCCTDocumentRef doc, const char* path);

/// Release document and all internal resources
void OCCTDocumentRelease(OCCTDocumentRef doc);

// MARK: - XDE Assembly Traversal

/// Get number of root (top-level/free) shapes in document
int32_t OCCTDocumentGetRootCount(OCCTDocumentRef doc);

/// Get label ID for root shape at index
/// @param doc Document
/// @param index Root index (0-based)
/// @return Label ID, or -1 if index out of bounds
int64_t OCCTDocumentGetRootLabelId(OCCTDocumentRef doc, int32_t index);

/// Get name for a label
/// @param doc Document
/// @param labelId Label identifier
/// @return Name string (caller must free with OCCTStringFree), or NULL if no name
const char* OCCTDocumentGetLabelName(OCCTDocumentRef doc, int64_t labelId);

/// Check if label represents an assembly (has components)
bool OCCTDocumentIsAssembly(OCCTDocumentRef doc, int64_t labelId);

/// Check if label is a reference (instance of another shape)
bool OCCTDocumentIsReference(OCCTDocumentRef doc, int64_t labelId);

/// Get number of child components for an assembly label
int32_t OCCTDocumentGetChildCount(OCCTDocumentRef doc, int64_t labelId);

/// Get child label ID at index
/// @param doc Document
/// @param parentLabelId Parent assembly label
/// @param index Child index (0-based)
/// @return Child label ID, or -1 if index out of bounds
int64_t OCCTDocumentGetChildLabelId(OCCTDocumentRef doc, int64_t parentLabelId, int32_t index);

/// Get the referred shape label for a reference
/// @param doc Document
/// @param refLabelId Reference label ID
/// @return Referred label ID, or -1 if not a reference
int64_t OCCTDocumentGetReferredLabelId(OCCTDocumentRef doc, int64_t refLabelId);

/// Get shape for a label (without location transform applied)
/// @param doc Document
/// @param labelId Label identifier
/// @return Shape reference (caller must release), or NULL on failure
OCCTShapeRef OCCTDocumentGetShape(OCCTDocumentRef doc, int64_t labelId);

/// Get shape with location transform applied
/// @param doc Document
/// @param labelId Label identifier
/// @return Shape reference with transform applied (caller must release), or NULL on failure
OCCTShapeRef OCCTDocumentGetShapeWithLocation(OCCTDocumentRef doc, int64_t labelId);

// MARK: - XDE Transforms

/// Get location transform as 4x4 matrix (column-major, suitable for simd_float4x4)
/// @param doc Document
/// @param labelId Label identifier
/// @param outMatrix16 Output array for 16 floats (column-major 4x4 matrix)
void OCCTDocumentGetLocation(OCCTDocumentRef doc, int64_t labelId, float* outMatrix16);

// MARK: - XDE Colors

/// Color type (matches XCAFDoc_ColorType)
typedef enum {
    OCCTColorTypeGeneric = 0,   // Generic color
    OCCTColorTypeSurface = 1,   // Surface color (overrides generic)
    OCCTColorTypeCurve = 2      // Curve color (overrides generic)
} OCCTColorType;

/// RGBA color with set flag
typedef struct {
    double r, g, b, a;
    bool isSet;
} OCCTColor;

/// Get color for a label
/// @param doc Document
/// @param labelId Label identifier
/// @param colorType Type of color to retrieve
/// @return Color structure (check isSet to see if color was assigned)
OCCTColor OCCTDocumentGetLabelColor(OCCTDocumentRef doc, int64_t labelId, OCCTColorType colorType);

/// Set color for a label
/// @param doc Document
/// @param labelId Label identifier
/// @param colorType Type of color to set
/// @param r, g, b RGB values (0.0-1.0)
void OCCTDocumentSetLabelColor(OCCTDocumentRef doc, int64_t labelId, OCCTColorType colorType, double r, double g, double b);

// MARK: - XDE Materials (PBR)

/// PBR Material properties
typedef struct {
    OCCTColor baseColor;
    double metallic;        // 0.0-1.0
    double roughness;       // 0.0-1.0
    OCCTColor emissive;
    double transparency;    // 0.0-1.0
    bool isSet;
} OCCTMaterial;

/// Get PBR material for a label
/// @param doc Document
/// @param labelId Label identifier
/// @return Material structure (check isSet to see if material was assigned)
OCCTMaterial OCCTDocumentGetLabelMaterial(OCCTDocumentRef doc, int64_t labelId);

/// Set PBR material for a label
/// @param doc Document
/// @param labelId Label identifier
/// @param material Material properties to set
void OCCTDocumentSetLabelMaterial(OCCTDocumentRef doc, int64_t labelId, OCCTMaterial material);

// MARK: - XDE Utility

/// Free a string returned by OCCTDocumentGetLabelName
void OCCTStringFree(const char* str);

// MARK: - 2D Drawing / HLR Projection (v0.6.0)

/// Opaque handle for 2D drawing (HLR projection result)
typedef struct OCCTDrawing* OCCTDrawingRef;

/// Projection type
typedef enum {
    OCCTProjectionOrthographic = 0,
    OCCTProjectionPerspective = 1
} OCCTProjectionType;

/// Edge visibility type
typedef enum {
    OCCTEdgeTypeVisible = 0,
    OCCTEdgeTypeHidden = 1,
    OCCTEdgeTypeOutline = 2
} OCCTEdgeType;

/// Create 2D projection using Hidden Line Removal (HLR)
/// @param shape Shape to project
/// @param dirX, dirY, dirZ View direction (will be normalized)
/// @param projectionType Orthographic or perspective projection
/// @return Drawing reference, or NULL on failure
OCCTDrawingRef OCCTDrawingCreate(OCCTShapeRef shape, double dirX, double dirY, double dirZ, OCCTProjectionType projectionType);

/// Release drawing resources
void OCCTDrawingRelease(OCCTDrawingRef drawing);

/// Get projected edges by visibility type as a compound shape
/// @param drawing Drawing to query
/// @param edgeType Type of edges to retrieve
/// @return Shape containing 2D edges (caller must release), or NULL if no edges
OCCTShapeRef OCCTDrawingGetEdges(OCCTDrawingRef drawing, OCCTEdgeType edgeType);


// MARK: - Advanced Modeling (v0.8.0)

/// Fillet specific edges with uniform radius
/// @param shape The shape to fillet
/// @param edgeIndices Array of edge indices (0-based)
/// @param edgeCount Number of edges to fillet
/// @param radius Fillet radius
/// @return Filleted shape, or NULL on failure
OCCTShapeRef OCCTShapeFilletEdges(OCCTShapeRef shape, const int32_t* edgeIndices,
                                   int32_t edgeCount, double radius);

/// Fillet specific edges with linear radius interpolation
/// @param shape The shape to fillet
/// @param edgeIndices Array of edge indices (0-based)
/// @param edgeCount Number of edges to fillet
/// @param startRadius Radius at start of each edge
/// @param endRadius Radius at end of each edge
/// @return Filleted shape, or NULL on failure
OCCTShapeRef OCCTShapeFilletEdgesLinear(OCCTShapeRef shape, const int32_t* edgeIndices,
                                         int32_t edgeCount, double startRadius, double endRadius);

/// Add draft angle to faces for mold release
/// @param shape The shape to draft
/// @param faceIndices Array of face indices (0-based)
/// @param faceCount Number of faces to draft
/// @param dirX, dirY, dirZ Pull direction (typically vertical)
/// @param angle Draft angle in radians
/// @param planeX, planeY, planeZ Point on neutral plane
/// @param planeNx, planeNy, planeNz Normal of neutral plane
/// @return Drafted shape, or NULL on failure
OCCTShapeRef OCCTShapeDraft(OCCTShapeRef shape, const int32_t* faceIndices, int32_t faceCount,
                            double dirX, double dirY, double dirZ, double angle,
                            double planeX, double planeY, double planeZ,
                            double planeNx, double planeNy, double planeNz);

/// Remove features (faces) from shape using defeaturing
/// @param shape The shape to modify
/// @param faceIndices Array of face indices to remove (0-based)
/// @param faceCount Number of faces to remove
/// @return Shape with features removed, or NULL on failure
OCCTShapeRef OCCTShapeRemoveFeatures(OCCTShapeRef shape, const int32_t* faceIndices, int32_t faceCount);

/// Pipe sweep mode for advanced sweeps
typedef enum {
    OCCTPipeModeFrenet = 0,           // Standard Frenet trihedron
    OCCTPipeModeCorrectedFrenet = 1,  // Corrected for singularities
    OCCTPipeModeFixedBinormal = 2,    // Fixed binormal direction
    OCCTPipeModeAuxiliary = 3         // Guided by auxiliary curve
} OCCTPipeMode;

/// Create pipe shell with sweep mode
/// @param spine Path wire for sweep
/// @param profile Profile wire to sweep
/// @param mode Sweep mode (Frenet, corrected Frenet, etc.)
/// @param solid If true, create solid; if false, create shell
/// @return Swept shape, or NULL on failure
OCCTShapeRef OCCTShapeCreatePipeShell(OCCTWireRef spine, OCCTWireRef profile,
                                       OCCTPipeMode mode, bool solid);

/// Create pipe shell with fixed binormal direction
/// @param spine Path wire for sweep
/// @param profile Profile wire to sweep
/// @param bnX, bnY, bnZ Fixed binormal direction
/// @param solid If true, create solid; if false, create shell
/// @return Swept shape, or NULL on failure
OCCTShapeRef OCCTShapeCreatePipeShellWithBinormal(OCCTWireRef spine, OCCTWireRef profile,
                                                   double bnX, double bnY, double bnZ, bool solid);

/// Create pipe shell guided by auxiliary spine
/// @param spine Main path wire
/// @param profile Profile wire to sweep
/// @param auxSpine Auxiliary spine for twist control
/// @param solid If true, create solid; if false, create shell
/// @return Swept shape, or NULL on failure
OCCTShapeRef OCCTShapeCreatePipeShellWithAuxSpine(OCCTWireRef spine, OCCTWireRef profile,
                                                   OCCTWireRef auxSpine, bool solid);

/// Create a variable-section pipe shell from several profiles (issue #180).
/// Adds each profile (positioned in 3D along the spine) to a single
/// BRepOffsetAPI_MakePipeShell, producing a smooth swept solid/shell that
/// interpolates between sections. Supports every orientation mode:
///   - OCCTPipeModeFixedBinormal uses (bnX, bnY, bnZ)
///   - OCCTPipeModeAuxiliary uses auxSpine (must be non-NULL for that mode)
/// @param spine Path wire for sweep
/// @param profiles Array of profile wires (length profileCount, all non-NULL)
/// @param profileCount Number of profiles (>= 1)
/// @param mode Sweep mode controlling profile orientation
/// @param bnX, bnY, bnZ Fixed binormal (used only for OCCTPipeModeFixedBinormal)
/// @param auxSpine Auxiliary spine (used only for OCCTPipeModeAuxiliary; else NULL)
/// @param withContact If true, move each profile to touch the spine before sweeping
/// @param withCorrection If true, rotate the profile to stay orthogonal to the spine
/// @param solid If true, create solid; if false, create shell
/// @return Swept shape, or NULL on failure
OCCTShapeRef OCCTShapeCreatePipeShellMultiSection(OCCTWireRef spine,
                                                  const OCCTWireRef* profiles, int32_t profileCount,
                                                  OCCTPipeMode mode,
                                                  double bnX, double bnY, double bnZ,
                                                  OCCTWireRef auxSpine,
                                                  bool withContact, bool withCorrection,
                                                  bool solid);

/// Build one thread-start cutter as a SMOOTH analytic helicoid solid (issue #187).
/// Each of the 4 ISO-68 V-profile corners traces a BSpline helix; the cutter is the
/// solid bounded by ruled faces (BRepFill::Face) between consecutive corner-helices plus
/// two V end caps, sewn. O(1) faces (no faceting), in-envelope, vs the MakePipeShell sweep
/// which bulges with the helix lead. The axis frame is given by (origin, axis-unit,
/// radial0-unit, with tangential0 = axis x radial0 computed internally).
/// @param ox,oy,oz Axis origin (a point on the thread axis)
/// @param ax,ay,az Thread axis direction (unit)
/// @param rx,ry,rz radial0 (unit, perpendicular to the axis)
/// @param pitch Axial advance per turn; turns Number of turns
/// @param apexSign -1 external (apex inward) / +1 internal (apex outward into the wall)
/// @param helixRadius Thread pitch-line radius (nominal/2)
/// @param cutDepth, rootHalf, crestHalf, bleed ISO-68 V-form dimensions
/// @param phase Angular start offset (radians; multi-start); handed -1 left-handed / +1 right
/// @param nSections BSpline interpolation samples per corner helix
/// @return The cutter solid, or NULL on failure
OCCTShapeRef OCCTShapeBuildThreadCutter(double ox, double oy, double oz,
                                        double ax, double ay, double az,
                                        double rx, double ry, double rz,
                                        double pitch, double turns, double apexSign,
                                        double helixRadius, double cutDepth,
                                        double rootHalf, double crestHalf, double bleed,
                                        double phase, double handed, int32_t nSections);


// MARK: - Surfaces & Curves (v0.9.0)

/// Curve analysis result structure
typedef struct {
    double length;
    bool isClosed;
    bool isPeriodic;
    double startX, startY, startZ;
    double endX, endY, endZ;
    bool isValid;
} OCCTCurveInfo;

/// Curve point with derivatives
typedef struct {
    double posX, posY, posZ;      // Position
    double tanX, tanY, tanZ;      // Tangent vector
    double curvature;              // Curvature magnitude
    double normX, normY, normZ;   // Principal normal (if curvature > 0)
    bool hasNormal;
    bool isValid;
} OCCTCurvePoint;

/// Get comprehensive curve information for a wire
/// @param wire The wire to analyze
/// @return Curve information structure with isValid indicating success
OCCTCurveInfo OCCTWireGetCurveInfo(OCCTWireRef wire);

/// Get the length of a wire
/// @param wire The wire to measure
/// @return Length in linear units, or -1.0 on error
double OCCTWireGetLength(OCCTWireRef wire);

/// Get point on wire at normalized parameter (0.0 to 1.0)
/// @param wire The wire to sample
/// @param param Parameter value from 0.0 (start) to 1.0 (end)
/// @param x, y, z Output: point coordinates
/// @return true on success, false on error
bool OCCTWireGetPointAt(OCCTWireRef wire, double param, double* x, double* y, double* z);

/// Get tangent vector at normalized parameter
/// @param wire The wire to sample
/// @param param Parameter value from 0.0 to 1.0
/// @param tx, ty, tz Output: tangent vector components (normalized)
/// @return true on success, false on error
bool OCCTWireGetTangentAt(OCCTWireRef wire, double param, double* tx, double* ty, double* tz);

/// Get curvature at normalized parameter
/// @param wire The wire to sample
/// @param param Parameter value from 0.0 to 1.0
/// @return Curvature value (1/radius), or -1.0 on error
double OCCTWireGetCurvatureAt(OCCTWireRef wire, double param);

/// Get full curve point with position, tangent, and curvature
/// @param wire The wire to sample
/// @param param Parameter value from 0.0 to 1.0
/// @return Curve point structure with isValid indicating success
OCCTCurvePoint OCCTWireGetCurvePointAt(OCCTWireRef wire, double param);

/// Offset wire in 3D space along a direction
/// @param wire The wire to offset
/// @param distance Offset distance
/// @param dirX, dirY, dirZ Direction vector for offset
/// @return Offset wire, or NULL on failure
OCCTWireRef OCCTWireOffset3D(OCCTWireRef wire, double distance, double dirX, double dirY, double dirZ);

/// Create B-spline surface from a grid of control points
/// @param poles Control points as [x,y,z,...] in row-major order (uCount * vCount * 3 doubles)
/// @param uCount Number of control points in U direction
/// @param vCount Number of control points in V direction
/// @param uDegree Degree in U direction (typically 3)
/// @param vDegree Degree in V direction (typically 3)
/// @return Face shape from B-spline surface, or NULL on failure
OCCTShapeRef OCCTShapeCreateBSplineSurface(const double* poles, int32_t uCount, int32_t vCount,
                                            int32_t uDegree, int32_t vDegree);

/// Create ruled surface between two wires
/// @param wire1 First boundary wire
/// @param wire2 Second boundary wire
/// @return Face shape from ruled surface, or NULL on failure
OCCTShapeRef OCCTShapeCreateRuled(OCCTWireRef wire1, OCCTWireRef wire2);

/// Create shell (hollow solid) with specific faces left open
/// @param shape The solid to shell
/// @param thickness Shell wall thickness (positive = inward, negative = outward)
/// @param openFaceIndices Array of face indices to leave open (0-based)
/// @param faceCount Number of faces to leave open
/// @return Shelled shape, or NULL on failure
OCCTShapeRef OCCTShapeShellWithOpenFaces(OCCTShapeRef shape, double thickness,
                                          const int32_t* openFaceIndices, int32_t faceCount);


// MARK: - IGES Import/Export (v0.10.0)

/// Import IGES file
/// @param path Path to IGES file
/// @return Shape reference, or NULL on failure
OCCTShapeRef OCCTImportIGES(const char* path);

/// Import IGES file with automatic repair (sewing, healing)
/// @param path Path to IGES file
/// @return Shape reference with healing applied, or NULL on failure
OCCTShapeRef OCCTImportIGESRobust(const char* path);

/// Export shape to IGES file
/// @param shape The shape to export
/// @param path Output file path
/// @return true on success
bool OCCTExportIGES(OCCTShapeRef shape, const char* path);


// MARK: - BREP Native Format (v0.10.0)

/// Import OCCT native BREP file
/// @param path Path to BREP file
/// @return Shape reference, or NULL on failure
OCCTShapeRef OCCTImportBREP(const char* path);

/// Export shape to OCCT native BREP file
/// @param shape The shape to export
/// @param path Output file path
/// @return true on success
bool OCCTExportBREP(OCCTShapeRef shape, const char* path);

/// Export shape to BREP file with options for triangulation
/// @param shape The shape to export
/// @param path Output file path
/// @param withTriangles Include triangulation data
/// @param withNormals Include normal data (only if withTriangles is true)
/// @return true on success
bool OCCTExportBREPWithTriangles(OCCTShapeRef shape, const char* path, bool withTriangles, bool withNormals);


// MARK: - Geometry Construction (v0.11.0)

/// Create a planar face from a closed wire
/// @param wire Closed wire defining the face boundary
/// @param planar If true, require the wire to be planar; if false, attempt to create face anyway
/// @return Face shape, or NULL on failure
OCCTShapeRef OCCTShapeCreateFaceFromWire(OCCTWireRef wire, bool planar);

/// Create a face with holes from an outer wire and inner wires
/// @param outer Outer boundary wire (closed)
/// @param holes Array of inner boundary wires (holes)
/// @param holeCount Number of holes
/// @return Face shape with holes, or NULL on failure
OCCTShapeRef OCCTShapeCreateFaceWithHoles(OCCTWireRef outer, const OCCTWireRef* holes, int32_t holeCount);

/// Create a solid from a closed shell
/// @param shell Shell shape (must be closed)
/// @return Solid shape, or NULL on failure
OCCTShapeRef OCCTShapeCreateSolidFromShell(OCCTShapeRef shell);

/// Sew multiple faces/shapes into a shell or solid
/// @param shapes Array of shapes to sew
/// @param count Number of shapes
/// @param tolerance Sewing tolerance (use 1e-6 for default)
/// @return Sewn shape (shell or solid), or NULL on failure
OCCTShapeRef OCCTShapeSew(const OCCTShapeRef* shapes, int32_t count, double tolerance);

/// Sew two shapes together
/// @param shape1 First shape
/// @param shape2 Second shape
/// @param tolerance Sewing tolerance
/// @return Sewn shape, or NULL on failure
OCCTShapeRef OCCTShapeSewTwo(OCCTShapeRef shape1, OCCTShapeRef shape2, double tolerance);

/// Create a smooth curve interpolating through given points
/// @param points Points as [x,y,z,...] triplets (count * 3 doubles)
/// @param count Number of points (minimum 2)
/// @param closed If true, create a closed (periodic) curve
/// @param tolerance Interpolation tolerance (use 1e-6 for default)
/// @return Wire representing the interpolated curve, or NULL on failure
OCCTWireRef OCCTWireInterpolate(const double* points, int32_t count, bool closed, double tolerance);

/// Create a curve interpolating through points with specified end tangents
/// @param points Points as [x,y,z,...] triplets (count * 3 doubles)
/// @param count Number of points (minimum 2)
/// @param startTanX, startTanY, startTanZ Tangent vector at start point
/// @param endTanX, endTanY, endTanZ Tangent vector at end point
/// @param tolerance Interpolation tolerance
/// @return Wire with specified end tangents, or NULL on failure
OCCTWireRef OCCTWireInterpolateWithTangents(const double* points, int32_t count,
                                             double startTanX, double startTanY, double startTanZ,
                                             double endTanX, double endTanY, double endTanZ,
                                             double tolerance);


// MARK: - Feature-Based Modeling (v0.12.0)

/// Add a prismatic boss to a shape by extruding a profile
/// @param shape The base shape to modify
/// @param profile Wire profile to extrude (must be on a face of shape)
/// @param dirX, dirY, dirZ Extrusion direction
/// @param height Extrusion height
/// @param fuse If true, fuse with base shape; if false, cut from base shape
/// @return Modified shape with boss/pocket, or NULL on failure
OCCTShapeRef OCCTShapePrism(OCCTShapeRef shape, OCCTWireRef profile,
                            double dirX, double dirY, double dirZ,
                            double height, bool fuse);

/// Drill a cylindrical hole into a shape
/// @param shape The shape to drill
/// @param posX, posY, posZ Position of hole center on surface
/// @param dirX, dirY, dirZ Drill direction (into the shape)
/// @param radius Hole radius
/// @param depth Hole depth (0 for through-hole)
/// @return Shape with hole, or NULL on failure
OCCTShapeRef OCCTShapeDrillHole(OCCTShapeRef shape,
                                 double posX, double posY, double posZ,
                                 double dirX, double dirY, double dirZ,
                                 double radius, double depth);

/// Split a shape using a cutting tool (wire, face, or shape)
/// @param shape The shape to split
/// @param tool The cutting tool
/// @param outCount Output: number of resulting shapes
/// @return Array of split shapes (caller must free with OCCTFreeShapeArray), or NULL on failure
OCCTShapeRef* OCCTShapeSplit(OCCTShapeRef shape, OCCTShapeRef tool, int32_t* outCount);

/// Split a shape by a plane
/// @param shape The shape to split
/// @param planeX, planeY, planeZ Point on the cutting plane
/// @param normalX, normalY, normalZ Normal vector of the cutting plane
/// @param outCount Output: number of resulting shapes
/// @return Array of split shapes (caller must free with OCCTFreeShapeArray), or NULL on failure
OCCTShapeRef* OCCTShapeSplitByPlane(OCCTShapeRef shape,
                                     double planeX, double planeY, double planeZ,
                                     double normalX, double normalY, double normalZ,
                                     int32_t* outCount);

/// Free an array of shapes returned by split operations
/// @param shapes Array of shape references
/// @param count Number of shapes in the array
void OCCTFreeShapeArray(OCCTShapeRef* shapes, int32_t count);

/// Free only the shape array container, not the shapes themselves
/// @param shapes Array of shape references
void OCCTFreeShapeArrayOnly(OCCTShapeRef* shapes);

/// Glue two shapes together at coincident faces
/// @param shape1 First shape
/// @param shape2 Second shape (must have faces coincident with shape1)
/// @param tolerance Tolerance for face matching
/// @return Glued shape, or NULL on failure
OCCTShapeRef OCCTShapeGlue(OCCTShapeRef shape1, OCCTShapeRef shape2, double tolerance);

/// Create an evolved shape (profile swept along spine with rotation)
/// @param spine The spine wire
/// @param profile The profile wire to sweep
/// @return Evolved shape, or NULL on failure
OCCTShapeRef OCCTShapeCreateEvolved(OCCTWireRef spine, OCCTWireRef profile);

/// Create a linear pattern of a shape
/// @param shape The shape to pattern
/// @param dirX, dirY, dirZ Direction of the pattern
/// @param spacing Distance between copies
/// @param count Number of copies (including original)
/// @return Compound of patterned shapes, or NULL on failure
OCCTShapeRef OCCTShapeLinearPattern(OCCTShapeRef shape,
                                     double dirX, double dirY, double dirZ,
                                     double spacing, int32_t count);

/// Create a circular pattern of a shape
/// @param shape The shape to pattern
/// @param axisX, axisY, axisZ Point on the rotation axis
/// @param axisDirX, axisDirY, axisDirZ Direction of the rotation axis
/// @param count Number of copies (including original)
/// @param angle Total angle to span (radians), 0 for full circle
/// @return Compound of patterned shapes, or NULL on failure
OCCTShapeRef OCCTShapeCircularPattern(OCCTShapeRef shape,
                                       double axisX, double axisY, double axisZ,
                                       double axisDirX, double axisDirY, double axisDirZ,
                                       int32_t count, double angle);

// MARK: - Shape Healing & Analysis (v0.13.0)

/// Shape analysis result structure
typedef struct {
    int32_t smallEdgeCount;        // Number of edges smaller than tolerance
    int32_t smallFaceCount;        // Number of faces smaller than tolerance
    int32_t gapCount;              // Number of gaps between edges/faces
    int32_t selfIntersectionCount; // Number of self-intersections
    int32_t freeEdgeCount;         // Number of free (unconnected) edges
    int32_t freeFaceCount;         // Number of free faces (shell not closed)
    bool hasInvalidTopology;       // Whether topology is invalid
    bool isValid;                  // Whether analysis succeeded
} OCCTShapeAnalysisResult;

/// Analyze a shape for problems
/// @param shape The shape to analyze
/// @param tolerance Tolerance for small feature detection
/// @return Analysis result with problem counts
OCCTShapeAnalysisResult OCCTShapeAnalyze(OCCTShapeRef shape, double tolerance);

/// Fix a wire (close gaps, remove degenerate edges, reorder)
/// @param wire The wire to fix
/// @param tolerance Tolerance for fixing operations
/// @return Fixed wire, or NULL on failure
OCCTWireRef OCCTWireFix(OCCTWireRef wire, double tolerance);

/// Fix a face (wire orientation, missing seams, surface parameters)
/// @param face The face to fix
/// @param tolerance Tolerance for fixing operations
/// @return Fixed face as a shape, or NULL on failure
OCCTShapeRef OCCTFaceFix(OCCTFaceRef face, double tolerance);

/// Fix a shape with detailed control
/// @param shape The shape to fix
/// @param tolerance Tolerance for fixing operations
/// @param fixSolid Whether to fix solid orientation
/// @param fixShell Whether to fix shell closure
/// @param fixFace Whether to fix face issues
/// @param fixWire Whether to fix wire issues
/// @return Fixed shape, or NULL on failure
OCCTShapeRef OCCTShapeFixDetailed(OCCTShapeRef shape, double tolerance,
                                   bool fixSolid, bool fixShell,
                                   bool fixFace, bool fixWire);

/// Unify faces and edges lying on the same geometry
/// @param shape The shape to simplify
/// @param unifyEdges Whether to unify edges on same curve
/// @param unifyFaces Whether to unify faces on same surface
/// @param concatBSplines Whether to concatenate adjacent B-splines
/// @return Unified shape, or NULL on failure
OCCTShapeRef OCCTShapeUnifySameDomain(OCCTShapeRef shape,
                                       bool unifyEdges, bool unifyFaces,
                                       bool concatBSplines);

/// Remove internal wires (holes) smaller than area threshold
/// @param shape The shape to clean
/// @param minArea Minimum area threshold for holes
/// @return Cleaned shape, or NULL on failure
OCCTShapeRef OCCTShapeRemoveSmallFaces(OCCTShapeRef shape, double minArea);

/// Simplify shape by removing small features
/// @param shape The shape to simplify
/// @param tolerance Size threshold for small features
/// @return Simplified shape, or NULL on failure
OCCTShapeRef OCCTShapeSimplify(OCCTShapeRef shape, double tolerance);

// MARK: - Camera (Metal Visualization)

typedef struct OCCTCamera* OCCTCameraRef;

OCCTCameraRef OCCTCameraCreate(void);
void          OCCTCameraDestroy(OCCTCameraRef cam);

void OCCTCameraSetEye(OCCTCameraRef cam, double x, double y, double z);
void OCCTCameraGetEye(OCCTCameraRef cam, double* x, double* y, double* z);
void OCCTCameraSetCenter(OCCTCameraRef cam, double x, double y, double z);
void OCCTCameraGetCenter(OCCTCameraRef cam, double* x, double* y, double* z);
void OCCTCameraSetUp(OCCTCameraRef cam, double x, double y, double z);
void OCCTCameraGetUp(OCCTCameraRef cam, double* x, double* y, double* z);

void OCCTCameraSetProjectionType(OCCTCameraRef cam, int type);
int  OCCTCameraGetProjectionType(OCCTCameraRef cam);
void OCCTCameraSetFOV(OCCTCameraRef cam, double degrees);
double OCCTCameraGetFOV(OCCTCameraRef cam);
void OCCTCameraSetScale(OCCTCameraRef cam, double scale);
double OCCTCameraGetScale(OCCTCameraRef cam);
void OCCTCameraSetZRange(OCCTCameraRef cam, double zNear, double zFar);
void OCCTCameraGetZRange(OCCTCameraRef cam, double* zNear, double* zFar);
void OCCTCameraSetAspect(OCCTCameraRef cam, double aspect);
double OCCTCameraGetAspect(OCCTCameraRef cam);

void OCCTCameraGetProjectionMatrix(OCCTCameraRef cam, float* out16);
void OCCTCameraGetViewMatrix(OCCTCameraRef cam, float* out16);

void OCCTCameraProject(OCCTCameraRef cam, double wX, double wY, double wZ,
                       double* sX, double* sY, double* sZ);
void OCCTCameraUnproject(OCCTCameraRef cam, double sX, double sY, double sZ,
                         double* wX, double* wY, double* wZ);

void OCCTCameraFitBBox(OCCTCameraRef cam, double xMin, double yMin, double zMin,
                       double xMax, double yMax, double zMax);

// MARK: - Presentation Mesh (Metal Visualization)

typedef struct {
    float* vertices;
    int32_t vertexCount;
    int32_t* indices;
    int32_t triangleCount;
} OCCTShadedMeshData;

typedef struct {
    float* vertices;
    int32_t vertexCount;
    int32_t* segmentStarts;
    int32_t segmentCount;
} OCCTEdgeMeshData;

bool OCCTShapeGetShadedMesh(OCCTShapeRef shape, double deflection, OCCTShadedMeshData* out);
void OCCTShadedMeshDataFree(OCCTShadedMeshData* data);

bool OCCTShapeGetEdgeMesh(OCCTShapeRef shape, double deflection, OCCTEdgeMeshData* out);
void OCCTEdgeMeshDataFree(OCCTEdgeMeshData* data);

// MARK: - Selector (Metal Visualization)

typedef struct OCCTSelector* OCCTSelectorRef;

typedef struct {
    int32_t shapeId;
    double depth;
    double pointX, pointY, pointZ;
    int32_t subShapeType;   // TopAbs_ShapeEnum: 7=VERTEX, 6=EDGE, 5=WIRE, 4=FACE, 8=SHAPE
    int32_t subShapeIndex;  // 1-based index of sub-shape within parent, 0 if whole shape
} OCCTPickResult;

OCCTSelectorRef OCCTSelectorCreate(void);
void            OCCTSelectorDestroy(OCCTSelectorRef sel);

bool OCCTSelectorAddShape(OCCTSelectorRef sel, OCCTShapeRef shape, int32_t shapeId);
bool OCCTSelectorRemoveShape(OCCTSelectorRef sel, int32_t shapeId);
void OCCTSelectorClear(OCCTSelectorRef sel);

/// Activate a selection mode for a shape (0=shape, 1=vertex, 2=edge, 3=wire, 4=face).
/// Mode 0 is activated automatically when adding a shape.
void OCCTSelectorActivateMode(OCCTSelectorRef sel, int32_t shapeId, int32_t mode);

/// Deactivate a selection mode for a shape. Pass -1 to deactivate all modes.
void OCCTSelectorDeactivateMode(OCCTSelectorRef sel, int32_t shapeId, int32_t mode);

/// Check if a selection mode is active for a shape.
bool OCCTSelectorIsModeActive(OCCTSelectorRef sel, int32_t shapeId, int32_t mode);

/// Set pixel tolerance for picking near edges/vertices (default 2).
void OCCTSelectorSetPixelTolerance(OCCTSelectorRef sel, int32_t tolerance);
int32_t OCCTSelectorGetPixelTolerance(OCCTSelectorRef sel);

int32_t OCCTSelectorPick(OCCTSelectorRef sel, OCCTCameraRef cam,
                         double viewW, double viewH,
                         double pixelX, double pixelY,
                         OCCTPickResult* out, int32_t maxResults);

int32_t OCCTSelectorPickRect(OCCTSelectorRef sel, OCCTCameraRef cam,
                             double viewW, double viewH,
                             double xMin, double yMin, double xMax, double yMax,
                             OCCTPickResult* out, int32_t maxResults);

/// Polyline (lasso) pick: select shapes within a closed polygon defined by 2D pixel points.
/// polyXY is an array of x,y pairs (length = pointCount * 2).
int32_t OCCTSelectorPickPoly(OCCTSelectorRef sel, OCCTCameraRef cam,
                             double viewW, double viewH,
                             const double* polyXY, int32_t pointCount,
                             OCCTPickResult* out, int32_t maxResults);

// MARK: - Drawer-Aware Mesh Extraction

typedef struct OCCTDrawer* OCCTDrawerRef;

/// Extract shaded mesh using a DisplayDrawer for tessellation control.
bool OCCTShapeGetShadedMeshWithDrawer(OCCTShapeRef shape, OCCTDrawerRef drawer, OCCTShadedMeshData* out);
bool OCCTShapeGetEdgeMeshWithDrawer(OCCTShapeRef shape, OCCTDrawerRef drawer, OCCTEdgeMeshData* out);

// MARK: - Display Drawer (Metal Visualization)

OCCTDrawerRef OCCTDrawerCreate(void);
void OCCTDrawerDestroy(OCCTDrawerRef drawer);

/// Chordal deviation coefficient (relative to bounding box). Default ~0.001.
void OCCTDrawerSetDeviationCoefficient(OCCTDrawerRef drawer, double coeff);
double OCCTDrawerGetDeviationCoefficient(OCCTDrawerRef drawer);

/// Angular deviation in radians. Default 20 degrees (M_PI/9).
void OCCTDrawerSetDeviationAngle(OCCTDrawerRef drawer, double angle);
double OCCTDrawerGetDeviationAngle(OCCTDrawerRef drawer);

/// Maximal chordal deviation (absolute). Applies when type of deflection is absolute.
void OCCTDrawerSetMaximalChordialDeviation(OCCTDrawerRef drawer, double deviation);
double OCCTDrawerGetMaximalChordialDeviation(OCCTDrawerRef drawer);

/// Type of deflection: 0=relative (default), 1=absolute.
void OCCTDrawerSetTypeOfDeflection(OCCTDrawerRef drawer, int32_t type);
int32_t OCCTDrawerGetTypeOfDeflection(OCCTDrawerRef drawer);

/// Auto-triangulation on/off. Default true.
void OCCTDrawerSetAutoTriangulation(OCCTDrawerRef drawer, bool on);
bool OCCTDrawerGetAutoTriangulation(OCCTDrawerRef drawer);

/// Number of iso-parameter lines (U and V). Default 1.
void OCCTDrawerSetIsoOnTriangulation(OCCTDrawerRef drawer, bool on);
bool OCCTDrawerGetIsoOnTriangulation(OCCTDrawerRef drawer);

/// Discretisation (number of points for curves). Default 30.
void OCCTDrawerSetDiscretisation(OCCTDrawerRef drawer, int32_t value);
int32_t OCCTDrawerGetDiscretisation(OCCTDrawerRef drawer);

/// Face boundary display on/off. Default false.
void OCCTDrawerSetFaceBoundaryDraw(OCCTDrawerRef drawer, bool on);
bool OCCTDrawerGetFaceBoundaryDraw(OCCTDrawerRef drawer);

/// Wire frame display on/off. Default true.
void OCCTDrawerSetWireDraw(OCCTDrawerRef drawer, bool on);
bool OCCTDrawerGetWireDraw(OCCTDrawerRef drawer);

// MARK: - Clip Plane (Metal Visualization)

typedef struct OCCTClipPlane* OCCTClipPlaneRef;

/// Create a clip plane from an equation Ax + By + Cz + D = 0
OCCTClipPlaneRef OCCTClipPlaneCreate(double a, double b, double c, double d);
void OCCTClipPlaneDestroy(OCCTClipPlaneRef plane);

void OCCTClipPlaneSetEquation(OCCTClipPlaneRef plane, double a, double b, double c, double d);
void OCCTClipPlaneGetEquation(OCCTClipPlaneRef plane, double* a, double* b, double* c, double* d);

/// Get the reversed equation (for back-face clipping)
void OCCTClipPlaneGetReversedEquation(OCCTClipPlaneRef plane, double* a, double* b, double* c, double* d);

void OCCTClipPlaneSetOn(OCCTClipPlaneRef plane, bool on);
bool OCCTClipPlaneIsOn(OCCTClipPlaneRef plane);

void OCCTClipPlaneSetCapping(OCCTClipPlaneRef plane, bool on);
bool OCCTClipPlaneIsCapping(OCCTClipPlaneRef plane);

void OCCTClipPlaneSetCappingColor(OCCTClipPlaneRef plane, double r, double g, double b);
void OCCTClipPlaneGetCappingColor(OCCTClipPlaneRef plane, double* r, double* g, double* b);

/// Set capping hatch style (see Aspect_HatchStyle values)
void OCCTClipPlaneSetCappingHatch(OCCTClipPlaneRef plane, int32_t style);
int32_t OCCTClipPlaneGetCappingHatch(OCCTClipPlaneRef plane);
void OCCTClipPlaneSetCappingHatchOn(OCCTClipPlaneRef plane, bool on);
bool OCCTClipPlaneIsCappingHatchOn(OCCTClipPlaneRef plane);

/// Probe a point against the clip plane chain. Returns: 0=Out, 1=In, 2=On
int32_t OCCTClipPlaneProbePoint(OCCTClipPlaneRef plane, double x, double y, double z);

/// Probe an axis-aligned bounding box against the clip plane chain. Returns: 0=Out, 1=In, 2=On
int32_t OCCTClipPlaneProbeBox(OCCTClipPlaneRef plane,
                               double xMin, double yMin, double zMin,
                               double xMax, double yMax, double zMax);

/// Chain another plane for logical AND clipping (conjunction)
void OCCTClipPlaneSetChainNext(OCCTClipPlaneRef plane, OCCTClipPlaneRef next);
/// Get the number of planes in the forward chain (including this one)
int32_t OCCTClipPlaneChainLength(OCCTClipPlaneRef plane);

// MARK: - Z-Layer Settings (Metal Visualization)

typedef struct OCCTZLayerSettings* OCCTZLayerSettingsRef;

OCCTZLayerSettingsRef OCCTZLayerSettingsCreate(void);
void OCCTZLayerSettingsDestroy(OCCTZLayerSettingsRef settings);

void OCCTZLayerSettingsSetName(OCCTZLayerSettingsRef settings, const char* name);

void OCCTZLayerSettingsSetDepthTest(OCCTZLayerSettingsRef settings, bool on);
bool OCCTZLayerSettingsGetDepthTest(OCCTZLayerSettingsRef settings);
void OCCTZLayerSettingsSetDepthWrite(OCCTZLayerSettingsRef settings, bool on);
bool OCCTZLayerSettingsGetDepthWrite(OCCTZLayerSettingsRef settings);
void OCCTZLayerSettingsSetClearDepth(OCCTZLayerSettingsRef settings, bool on);
bool OCCTZLayerSettingsGetClearDepth(OCCTZLayerSettingsRef settings);

/// Set polygon offset: mode (0=Off,1=Fill,2=Line,4=Point,7=All), factor, units
void OCCTZLayerSettingsSetPolygonOffset(OCCTZLayerSettingsRef settings, int32_t mode, float factor, float units);
void OCCTZLayerSettingsGetPolygonOffset(OCCTZLayerSettingsRef settings, int32_t* mode, float* factor, float* units);

/// Convenience: set minimal positive depth offset (factor=1, units=1)
void OCCTZLayerSettingsSetDepthOffsetPositive(OCCTZLayerSettingsRef settings);
/// Convenience: set minimal negative depth offset (factor=1, units=-1)
void OCCTZLayerSettingsSetDepthOffsetNegative(OCCTZLayerSettingsRef settings);

void OCCTZLayerSettingsSetImmediate(OCCTZLayerSettingsRef settings, bool on);
bool OCCTZLayerSettingsGetImmediate(OCCTZLayerSettingsRef settings);
void OCCTZLayerSettingsSetRaytracable(OCCTZLayerSettingsRef settings, bool on);
bool OCCTZLayerSettingsGetRaytracable(OCCTZLayerSettingsRef settings);

void OCCTZLayerSettingsSetEnvironmentTexture(OCCTZLayerSettingsRef settings, bool on);
bool OCCTZLayerSettingsGetEnvironmentTexture(OCCTZLayerSettingsRef settings);

void OCCTZLayerSettingsSetRenderInDepthPrepass(OCCTZLayerSettingsRef settings, bool on);
bool OCCTZLayerSettingsGetRenderInDepthPrepass(OCCTZLayerSettingsRef settings);

/// Set culling distance (set to negative or zero to disable)
void OCCTZLayerSettingsSetCullingDistance(OCCTZLayerSettingsRef settings, double distance);
double OCCTZLayerSettingsGetCullingDistance(OCCTZLayerSettingsRef settings);

/// Set culling size (set to negative or zero to disable)
void OCCTZLayerSettingsSetCullingSize(OCCTZLayerSettingsRef settings, double size);
double OCCTZLayerSettingsGetCullingSize(OCCTZLayerSettingsRef settings);

/// Set layer origin (for coordinate precision in large scenes)
void OCCTZLayerSettingsSetOrigin(OCCTZLayerSettingsRef settings, double x, double y, double z);
void OCCTZLayerSettingsGetOrigin(OCCTZLayerSettingsRef settings, double* x, double* y, double* z);

// MARK: - Advanced Blends & Surface Filling (v0.14.0)

/// Apply variable radius fillet to a specific edge
/// @param shape The shape to fillet
/// @param edgeIndex Index of the edge to fillet
/// @param radii Array of radius values along the edge
/// @param params Array of parameter values (0-1) where radii apply
/// @param count Number of radius/parameter pairs
/// @return Filleted shape, or NULL on failure
OCCTShapeRef OCCTShapeFilletVariable(OCCTShapeRef shape, int32_t edgeIndex,
                                      const double* radii, const double* params, int32_t count);

/// Apply 2D fillet to a wire at a specific vertex
/// @param wire The wire to fillet
/// @param vertexIndex Index of the vertex to fillet
/// @param radius Fillet radius
/// @return Filleted wire, or NULL on failure
OCCTWireRef OCCTWireFillet2D(OCCTWireRef wire, int32_t vertexIndex, double radius);

/// Apply 2D fillet to all vertices of a wire
/// @param wire The wire to fillet
/// @param radius Fillet radius for all corners
/// @return Filleted wire, or NULL on failure
OCCTWireRef OCCTWireFilletAll2D(OCCTWireRef wire, double radius);

/// Apply 2D chamfer to a wire at a specific vertex
/// @param wire The wire to chamfer
/// @param vertexIndex Index of the vertex to chamfer
/// @param dist1 First chamfer distance
/// @param dist2 Second chamfer distance
/// @return Chamfered wire, or NULL on failure
OCCTWireRef OCCTWireChamfer2D(OCCTWireRef wire, int32_t vertexIndex, double dist1, double dist2);

/// Apply 2D chamfer to all vertices of a wire
/// @param wire The wire to chamfer
/// @param distance Chamfer distance for all corners
/// @return Chamfered wire, or NULL on failure
OCCTWireRef OCCTWireChamferAll2D(OCCTWireRef wire, double distance);

/// Blend multiple edges with individual radii
/// @param shape The shape to blend
/// @param edgeIndices Array of edge indices
/// @param radii Array of radii (one per edge)
/// @param count Number of edges
/// @return Blended shape, or NULL on failure
OCCTShapeRef OCCTShapeBlendEdges(OCCTShapeRef shape,
                                  const int32_t* edgeIndices, const double* radii, int32_t count);

/// Parameters for surface filling operation
typedef struct {
    int32_t continuity;   // 0=GeomAbs_C0, 1=GeomAbs_G1, 2=GeomAbs_G2
    double tolerance;     // Surface tolerance
    int32_t maxDegree;    // Maximum surface degree (default 8)
    int32_t maxSegments;  // Maximum segments (default 9)
} OCCTFillingParams;

/// Fill an N-sided boundary with a surface
/// @param boundaries Array of boundary wires
/// @param wireCount Number of boundary wires
/// @param params Filling parameters
/// @return Filled face, or NULL on failure
OCCTShapeRef OCCTShapeFill(const OCCTWireRef* boundaries, int32_t wireCount,
                            OCCTFillingParams params);

/// Create a surface constrained to pass through points
/// @param points Array of points [x,y,z triplets]
/// @param pointCount Number of points
/// @param tolerance Surface tolerance
/// @return Surface face, or NULL on failure
OCCTShapeRef OCCTShapePlatePoints(const double* points, int32_t pointCount, double tolerance);

/// Create a surface constrained by curves
/// @param curves Array of constraint curves
/// @param curveCount Number of curves
/// @param continuity Desired continuity (0=C0, 1=G1, 2=G2)
/// @param tolerance Surface tolerance
/// @return Surface face, or NULL on failure
OCCTShapeRef OCCTShapePlateCurves(const OCCTWireRef* curves, int32_t curveCount,
                                   int32_t continuity, double tolerance);


// MARK: - 2D Curve (Geom2d) — v0.16.0

typedef struct OCCTCurve2D* OCCTCurve2DRef;

void OCCTCurve2DRelease(OCCTCurve2DRef curve);

// Properties
void   OCCTCurve2DGetDomain(OCCTCurve2DRef curve, double* first, double* last);
bool   OCCTCurve2DIsClosed(OCCTCurve2DRef curve);
bool   OCCTCurve2DIsPeriodic(OCCTCurve2DRef curve);
double OCCTCurve2DGetPeriod(OCCTCurve2DRef curve);

// Evaluation
void OCCTCurve2DGetPoint(OCCTCurve2DRef curve, double u, double* x, double* y);
void OCCTCurve2DD1(OCCTCurve2DRef curve, double u,
                   double* px, double* py, double* vx, double* vy);
void OCCTCurve2DD2(OCCTCurve2DRef curve, double u,
                   double* px, double* py,
                   double* v1x, double* v1y, double* v2x, double* v2y);

// Primitives
OCCTCurve2DRef OCCTCurve2DCreateLine(double px, double py, double dx, double dy);
OCCTCurve2DRef OCCTCurve2DCreateSegment(double p1x, double p1y, double p2x, double p2y);
OCCTCurve2DRef OCCTCurve2DCreateCircle(double cx, double cy, double radius);
OCCTCurve2DRef OCCTCurve2DCreateArcOfCircle(double cx, double cy, double radius,
                                            double startAngle, double endAngle);
OCCTCurve2DRef OCCTCurve2DCreateArcThrough(double p1x, double p1y,
                                           double p2x, double p2y,
                                           double p3x, double p3y);
OCCTCurve2DRef OCCTCurve2DCreateEllipse(double cx, double cy,
                                        double majorR, double minorR, double rotation);
OCCTCurve2DRef OCCTCurve2DCreateArcOfEllipse(double cx, double cy,
                                             double majorR, double minorR,
                                             double rotation,
                                             double startAngle, double endAngle);
OCCTCurve2DRef OCCTCurve2DCreateParabola(double fx, double fy,
                                         double dx, double dy, double focal);
OCCTCurve2DRef OCCTCurve2DCreateHyperbola(double cx, double cy,
                                          double majorR, double minorR,
                                          double rotation);

// Draw (discretization for Metal)
int32_t OCCTCurve2DDrawAdaptive(OCCTCurve2DRef curve, double angularDefl, double chordalDefl,
                                double* outXY, int32_t maxPoints);
int32_t OCCTCurve2DDrawUniform(OCCTCurve2DRef curve, int32_t pointCount, double* outXY);
int32_t OCCTCurve2DDrawDeflection(OCCTCurve2DRef curve, double deflection,
                                  double* outXY, int32_t maxPoints);

// BSpline & Bezier
OCCTCurve2DRef OCCTCurve2DCreateBSpline(const double* poles, int32_t poleCount,
                                        const double* weights,
                                        const double* knots, int32_t knotCount,
                                        const int32_t* multiplicities, int32_t degree);
OCCTCurve2DRef OCCTCurve2DCreateBezier(const double* poles, int32_t poleCount,
                                       const double* weights);

// Interpolation & Fitting
OCCTCurve2DRef OCCTCurve2DInterpolate(const double* points, int32_t count,
                                      bool closed, double tolerance);
OCCTCurve2DRef OCCTCurve2DInterpolateWithTangents(const double* points, int32_t count,
                                                  double stx, double sty,
                                                  double etx, double ety,
                                                  double tolerance);
OCCTCurve2DRef OCCTCurve2DFitPoints(const double* points, int32_t count,
                                    int32_t minDeg, int32_t maxDeg, double tolerance);

// BSpline queries
int32_t OCCTCurve2DGetPoleCount(OCCTCurve2DRef curve);
int32_t OCCTCurve2DGetPoles(OCCTCurve2DRef curve, double* outXY);
int32_t OCCTCurve2DGetDegree(OCCTCurve2DRef curve);

// Operations
OCCTCurve2DRef OCCTCurve2DTrim(OCCTCurve2DRef curve, double u1, double u2);
OCCTCurve2DRef OCCTCurve2DOffset(OCCTCurve2DRef curve, double distance);
OCCTCurve2DRef OCCTCurve2DReversed(OCCTCurve2DRef curve);
OCCTCurve2DRef OCCTCurve2DTranslate(OCCTCurve2DRef curve, double dx, double dy);
OCCTCurve2DRef OCCTCurve2DRotate(OCCTCurve2DRef curve, double cx, double cy, double angle);
OCCTCurve2DRef OCCTCurve2DScale(OCCTCurve2DRef curve, double cx, double cy, double factor);
OCCTCurve2DRef OCCTCurve2DMirrorAxis(OCCTCurve2DRef curve, double px, double py,
                                     double dx, double dy);
OCCTCurve2DRef OCCTCurve2DMirrorPoint(OCCTCurve2DRef curve, double px, double py);
double OCCTCurve2DGetLength(OCCTCurve2DRef curve);
double OCCTCurve2DGetLengthBetween(OCCTCurve2DRef curve, double u1, double u2);

// Intersection
typedef struct {
    double x, y, u1, u2;
} OCCTCurve2DIntersection;

int32_t OCCTCurve2DIntersect(OCCTCurve2DRef c1, OCCTCurve2DRef c2, double tolerance,
                             OCCTCurve2DIntersection* out, int32_t max);
int32_t OCCTCurve2DSelfIntersect(OCCTCurve2DRef curve, double tolerance,
                                 OCCTCurve2DIntersection* out, int32_t max);

// Projection
typedef struct {
    double x, y, parameter, distance;
} OCCTCurve2DProjection;

OCCTCurve2DProjection OCCTCurve2DProjectPoint(OCCTCurve2DRef curve, double px, double py);
int32_t OCCTCurve2DProjectPointAll(OCCTCurve2DRef curve, double px, double py,
                                   OCCTCurve2DProjection* out, int32_t max);

// Extrema
typedef struct {
    double p1x, p1y, p2x, p2y, u1, u2, distance;
} OCCTCurve2DExtrema;

OCCTCurve2DExtrema OCCTCurve2DMinDistance(OCCTCurve2DRef c1, OCCTCurve2DRef c2);
int32_t OCCTCurve2DAllExtrema(OCCTCurve2DRef c1, OCCTCurve2DRef c2,
                              OCCTCurve2DExtrema* out, int32_t max);

// Conversion
OCCTCurve2DRef OCCTCurve2DToBSpline(OCCTCurve2DRef curve, double tolerance);
int32_t OCCTCurve2DBSplineToBeziers(OCCTCurve2DRef curve, OCCTCurve2DRef* out, int32_t max);
void OCCTCurve2DFreeArray(OCCTCurve2DRef* curves, int32_t count);
OCCTCurve2DRef OCCTCurve2DJoinToBSpline(const OCCTCurve2DRef* curves, int32_t count,
                                        double tolerance);

// Local Properties (Geom2dLProp)
double OCCTCurve2DGetCurvature(OCCTCurve2DRef curve, double u);
bool   OCCTCurve2DGetNormal(OCCTCurve2DRef curve, double u, double* nx, double* ny);
bool   OCCTCurve2DGetTangentDir(OCCTCurve2DRef curve, double u, double* tx, double* ty);
bool   OCCTCurve2DGetCenterOfCurvature(OCCTCurve2DRef curve, double u, double* cx, double* cy);

/// Curve inflection/curvature result type: 0=Inflection, 1=MinCurvature, 2=MaxCurvature
typedef struct {
    double parameter;
    int32_t type;
} OCCTCurve2DCurvePoint;

int32_t OCCTCurve2DGetInflectionPoints(OCCTCurve2DRef curve, double* outParams, int32_t max);
int32_t OCCTCurve2DGetCurvatureExtrema(OCCTCurve2DRef curve, OCCTCurve2DCurvePoint* out, int32_t max);
int32_t OCCTCurve2DGetAllSpecialPoints(OCCTCurve2DRef curve, OCCTCurve2DCurvePoint* out, int32_t max);

// Bounding Box
bool OCCTCurve2DGetBoundingBox(OCCTCurve2DRef curve, double* xMin, double* yMin,
                               double* xMax, double* yMax);

// Additional Arc Types
OCCTCurve2DRef OCCTCurve2DCreateArcOfHyperbola(double cx, double cy,
                                               double majorR, double minorR,
                                               double rotation,
                                               double startAngle, double endAngle);
OCCTCurve2DRef OCCTCurve2DCreateArcOfParabola(double fx, double fy,
                                              double dx, double dy, double focal,
                                              double startParam, double endParam);

// Conversion Extras
OCCTCurve2DRef OCCTCurve2DApproximate(OCCTCurve2DRef curve, double tolerance,
                                      int32_t continuity, int32_t maxSegments, int32_t maxDegree);
int32_t OCCTCurve2DSplitAtDiscontinuities(OCCTCurve2DRef curve, int32_t continuity,
                                          int32_t* outKnotIndices, int32_t max);
int32_t OCCTCurve2DToArcsAndSegments(OCCTCurve2DRef curve, double tolerance,
                                     double angleTol, OCCTCurve2DRef* out, int32_t max);

// Issue #37 — parameter at arc length
/// Returns the curve parameter at the given arc-length distance from fromParam.
/// Pass the curve's FirstParameter() as fromParam to measure from the start.
/// Returns -DBL_MAX on failure.
double OCCTCurve2DParameterAtLength(OCCTCurve2DRef curve, double arcLength, double fromParam);

// Issue #38 — interpolate with interior tangent constraints
/// Interpolate through points with per-point tangent constraints.
/// tangents: flat array of (tx, ty) pairs, one per point.
/// tangentFlags: one bool per point; true means the tangent at that index is constrained.
/// Returns NULL on failure.
OCCTCurve2DRef OCCTCurve2DInterpolateWithInteriorTangents(
    const double* points, int32_t count,
    const double* tangents, const bool* tangentFlags,
    bool closed, double tolerance);

// Issue #39 — lift a 2D curve onto a 3D plane to produce a Wire
/// Creates a 3D wire by embedding the 2D curve into a gp_Pln.
/// The plane is defined by its origin (ox,oy,oz), normal (nx,ny,nz) and x-axis (xx,xy,xz).
/// Returns NULL on failure.
OCCTWireRef OCCTWireFromCurve2DOnPlane(OCCTCurve2DRef curve,
                                       double ox, double oy, double oz,
                                       double nx, double ny, double nz,
                                       double xx, double xy, double xz);

// Gcc Constraint Solver — Qualifier enum
typedef enum {
    OCCTGccQualUnqualified = 0,
    OCCTGccQualEnclosing   = 1,
    OCCTGccQualEnclosed    = 2,
    OCCTGccQualOutside     = 3
} OCCTGccQualifier;

/// Circle tangent solution result
typedef struct {
    double cx, cy, radius;
    int32_t qualifier;
} OCCTGccCircleSolution;

/// Line tangent solution result
typedef struct {
    double px, py, dx, dy;
    int32_t qualifier;
} OCCTGccLineSolution;

// Gcc Circle Construction
int32_t OCCTGccCircle2d3Tan(OCCTCurve2DRef c1, int32_t q1,
                            OCCTCurve2DRef c2, int32_t q2,
                            OCCTCurve2DRef c3, int32_t q3,
                            double tolerance,
                            OCCTGccCircleSolution* out, int32_t max);
int32_t OCCTGccCircle2d2TanPt(OCCTCurve2DRef c1, int32_t q1,
                              OCCTCurve2DRef c2, int32_t q2,
                              double px, double py,
                              double tolerance,
                              OCCTGccCircleSolution* out, int32_t max);
int32_t OCCTGccCircle2dTanCen(OCCTCurve2DRef curve, int32_t qualifier,
                              double cx, double cy, double tolerance,
                              OCCTGccCircleSolution* out, int32_t max);
int32_t OCCTGccCircle2d2TanRad(OCCTCurve2DRef c1, int32_t q1,
                               OCCTCurve2DRef c2, int32_t q2,
                               double radius, double tolerance,
                               OCCTGccCircleSolution* out, int32_t max);
int32_t OCCTGccCircle2dTanPtRad(OCCTCurve2DRef curve, int32_t qualifier,
                                double px, double py,
                                double radius, double tolerance,
                                OCCTGccCircleSolution* out, int32_t max);
int32_t OCCTGccCircle2d2PtRad(double p1x, double p1y, double p2x, double p2y,
                              double radius, double tolerance,
                              OCCTGccCircleSolution* out, int32_t max);
int32_t OCCTGccCircle2d3Pt(double p1x, double p1y, double p2x, double p2y,
                           double p3x, double p3y, double tolerance,
                           OCCTGccCircleSolution* out, int32_t max);

// Gcc Line Construction
int32_t OCCTGccLine2d2Tan(OCCTCurve2DRef c1, int32_t q1,
                          OCCTCurve2DRef c2, int32_t q2,
                          double tolerance,
                          OCCTGccLineSolution* out, int32_t max);
int32_t OCCTGccLine2dTanPt(OCCTCurve2DRef curve, int32_t qualifier,
                           double px, double py, double tolerance,
                           OCCTGccLineSolution* out, int32_t max);

// Hatching
int32_t OCCTCurve2DHatch(const OCCTCurve2DRef* boundaries, int32_t boundaryCount,
                         double originX, double originY,
                         double dirX, double dirY,
                         double spacing, double tolerance,
                         double* outXY, int32_t maxPoints);

// Bisector
OCCTCurve2DRef OCCTCurve2DBisectorCC(OCCTCurve2DRef c1, OCCTCurve2DRef c2,
                                     double originX, double originY, bool side);
OCCTCurve2DRef OCCTCurve2DBisectorPC(double px, double py, OCCTCurve2DRef curve,
                                     double originX, double originY, bool side);


// MARK: - STL Import (v0.17.0)

/// Import an STL file as a shape (sews faces into a shell/solid)
OCCTShapeRef OCCTImportSTL(const char* path);

/// Import an STL file with robust healing (sew + solid creation + heal)
OCCTShapeRef OCCTImportSTLRobust(const char* path, double sewingTolerance);


// MARK: - OBJ Import/Export (v0.17.0)

/// Import an OBJ file as a shape
OCCTShapeRef OCCTImportOBJ(const char* path);

/// Export a shape to OBJ format
bool OCCTExportOBJ(OCCTShapeRef shape, const char* path, double deflection);


// MARK: - PLY Export (v0.17.0)

/// Export a shape to PLY format (Stanford Polygon Format)
bool OCCTExportPLY(OCCTShapeRef shape, const char* path, double deflection);


// MARK: - Advanced Healing (v0.17.0)

/// Divide a shape at continuity discontinuities
/// @param shape Shape to divide
/// @param continuity Target continuity (0=C0, 1=C1, 2=C2, 3=C3)
/// @return Divided shape, or NULL on failure
OCCTShapeRef OCCTShapeDivide(OCCTShapeRef shape, int32_t continuity);

/// Convert geometry to direct faces (canonical surfaces)
OCCTShapeRef OCCTShapeDirectFaces(OCCTShapeRef shape);

/// Scale shape geometry
OCCTShapeRef OCCTShapeScaleGeometry(OCCTShapeRef shape, double factor);

/// Convert BSpline surfaces to their closest analytical form
/// (planes, cylinders, cones, spheres, tori)
OCCTShapeRef OCCTShapeBSplineRestriction(OCCTShapeRef shape,
                                          double surfaceTol, double curveTol,
                                          int32_t maxDegree, int32_t maxSegments);

/// Convert swept surfaces to elementary (canonical) surfaces
OCCTShapeRef OCCTShapeSweptToElementary(OCCTShapeRef shape);

/// Convert surfaces of revolution to elementary surfaces
OCCTShapeRef OCCTShapeRevolutionToElementary(OCCTShapeRef shape);

/// Convert all surfaces to BSpline
OCCTShapeRef OCCTShapeConvertToBSpline(OCCTShapeRef shape);

/// Sew a single shape (reconnect disconnected faces)
OCCTShapeRef OCCTShapeSewSingle(OCCTShapeRef shape, double tolerance);

/// Upgrade shape: sew + make solid + heal (pipeline)
OCCTShapeRef OCCTShapeUpgrade(OCCTShapeRef shape, double tolerance);


// MARK: - Point Classification (v0.17.0)

/// Classification result: 0=IN, 1=OUT, 2=ON, 3=UNKNOWN
typedef int32_t OCCTTopAbsState;

/// Classify a point relative to a solid
OCCTTopAbsState OCCTClassifyPointInSolid(OCCTShapeRef solid,
                                          double px, double py, double pz,
                                          double tolerance);

/// Classify a point relative to a face (using 3D point)
OCCTTopAbsState OCCTClassifyPointOnFace(OCCTFaceRef face,
                                         double px, double py, double pz,
                                         double tolerance);

/// Classify a point relative to a face (using UV parameters)
OCCTTopAbsState OCCTClassifyPointOnFaceUV(OCCTFaceRef face,
                                           double u, double v,
                                           double tolerance);


// MARK: - Face Surface Properties (v0.18.0)

/// Get UV parameter bounds of a face
bool OCCTFaceGetUVBounds(OCCTFaceRef face,
                         double* uMin, double* uMax,
                         double* vMin, double* vMax);

/// Evaluate surface point at UV parameters
bool OCCTFaceEvaluateAtUV(OCCTFaceRef face, double u, double v,
                          double* px, double* py, double* pz);

/// Get surface normal at UV parameters
bool OCCTFaceGetNormalAtUV(OCCTFaceRef face, double u, double v,
                           double* nx, double* ny, double* nz);

/// Get Gaussian curvature at UV parameters
bool OCCTFaceGetGaussianCurvature(OCCTFaceRef face, double u, double v,
                                   double* curvature);

/// Get mean curvature at UV parameters
bool OCCTFaceGetMeanCurvature(OCCTFaceRef face, double u, double v,
                               double* curvature);

/// Get principal curvatures and directions at UV parameters
bool OCCTFaceGetPrincipalCurvatures(OCCTFaceRef face, double u, double v,
                                     double* k1, double* k2,
                                     double* d1x, double* d1y, double* d1z,
                                     double* d2x, double* d2y, double* d2z);

/// Get surface type: 0=Plane, 1=Cylinder, 2=Cone, 3=Sphere, 4=Torus,
///   5=BezierSurface, 6=BSplineSurface, 7=SurfaceOfRevolution,
///   8=SurfaceOfExtrusion, 9=OffsetSurface, 10=Other
int32_t OCCTFaceGetSurfaceType(OCCTFaceRef face);

/// Get surface area of a single face
double OCCTFaceGetArea(OCCTFaceRef face, double tolerance);

/// Get the primary axis of a face's underlying surface if cylindrical/conical/spherical/
/// toroidal/surface-of-revolution/surface-of-extrusion. Returns false for non-axial surfaces. v0.137.
/// outKind: 0=none, 1=cylinder, 2=cone, 3=sphere, 4=torus, 5=revolution, 6=extrusion.
bool OCCTFaceGetPrimaryAxis(OCCTFaceRef _Nonnull face,
                             double* _Nonnull ox, double* _Nonnull oy, double* _Nonnull oz,
                             double* _Nonnull dx, double* _Nonnull dy, double* _Nonnull dz,
                             int32_t* _Nonnull outKind);


// MARK: - Edge 3D Curve Properties (v0.18.0)

/// Get parameter bounds of an edge's curve
bool OCCTEdgeGetParameterBounds(OCCTEdgeRef edge, double* first, double* last);

/// Get 3D curvature at parameter on edge curve
bool OCCTEdgeGetCurvature3D(OCCTEdgeRef edge, double param, double* curvature);

/// Get tangent direction at parameter on edge curve
bool OCCTEdgeGetTangent3D(OCCTEdgeRef edge, double param,
                           double* tx, double* ty, double* tz);

/// Get principal normal at parameter on edge curve
bool OCCTEdgeGetNormal3D(OCCTEdgeRef edge, double param,
                          double* nx, double* ny, double* nz);

/// Get center of curvature at parameter on edge curve
bool OCCTEdgeGetCenterOfCurvature3D(OCCTEdgeRef edge, double param,
                                     double* cx, double* cy, double* cz);

/// Get torsion at parameter on edge curve
bool OCCTEdgeGetTorsion(OCCTEdgeRef edge, double param, double* torsion);

/// Get point at parameter (uses actual curve parameterization)
bool OCCTEdgeGetPointAtParam(OCCTEdgeRef edge, double param,
                              double* px, double* py, double* pz);

/// Get curve type: 0=Line, 1=Circle, 2=Ellipse, 3=Hyperbola, 4=Parabola,
///   5=BezierCurve, 6=BSplineCurve, 7=OffsetCurve, 8=Other
int32_t OCCTEdgeGetCurveType(OCCTEdgeRef edge);


// MARK: - Point Projection (v0.18.0)

/// Projection result for point-on-surface
typedef struct {
    double px, py, pz;   // closest 3D point
    double u, v;          // UV parameters
    double distance;      // distance from original point
    bool isValid;
} OCCTSurfaceProjectionResult;

/// Project point onto face (closest point)
OCCTSurfaceProjectionResult OCCTFaceProjectPoint(OCCTFaceRef face,
                                                  double px, double py, double pz);

/// Get all projection results (multiple solutions)
int32_t OCCTFaceProjectPointAll(OCCTFaceRef face,
                                 double px, double py, double pz,
                                 OCCTSurfaceProjectionResult* results,
                                 int32_t maxResults);

/// Projection result for point-on-curve
typedef struct {
    double px, py, pz;   // closest 3D point on curve
    double parameter;     // curve parameter
    double distance;      // distance from original point
    bool isValid;
} OCCTCurveProjectionResult;

/// Project point onto edge curve (closest point)
OCCTCurveProjectionResult OCCTEdgeProjectPoint(OCCTEdgeRef edge,
                                                double px, double py, double pz);


// MARK: - Shape Proximity (v0.18.0)

/// Face proximity pair result
typedef struct {
    int32_t face1Index;
    int32_t face2Index;
} OCCTFaceProximityPair;

/// Detect face pairs between two shapes that are within tolerance
int32_t OCCTShapeProximity(OCCTShapeRef shape1, OCCTShapeRef shape2,
                            double tolerance,
                            OCCTFaceProximityPair* outPairs,
                            int32_t maxPairs,
                            double deflection);

/// Check if a shape self-intersects
bool OCCTShapeSelfIntersects(OCCTShapeRef shape);


// MARK: - Surface Intersection (v0.18.0)

/// Intersect two faces and return intersection curves as edges
OCCTShapeRef OCCTFaceIntersect(OCCTFaceRef face1, OCCTFaceRef face2,
                                double tolerance);


// MARK: - Curve3D: 3D Parametric Curves (v0.19.0)

typedef struct OCCTCurve3D* OCCTCurve3DRef;

void OCCTCurve3DRelease(OCCTCurve3DRef curve);

/// Get the 3D curve underlying an edge as a standalone Curve3D handle.
/// Returns nil if the edge has no 3D curve representation.
/// Ensures the 3D curve is built via BRepLib::BuildCurves3d for edges that
/// may only carry a pcurve (lofted / swept shapes). v0.147.
OCCTCurve3DRef _Nullable OCCTEdgeGetCurve3D(OCCTEdgeRef _Nonnull edge);

// Properties
void   OCCTCurve3DGetDomain(OCCTCurve3DRef curve, double* first, double* last);
bool   OCCTCurve3DIsClosed(OCCTCurve3DRef curve);
bool   OCCTCurve3DIsPeriodic(OCCTCurve3DRef curve);
double OCCTCurve3DGetPeriod(OCCTCurve3DRef curve);

// Evaluation
void OCCTCurve3DGetPoint(OCCTCurve3DRef curve, double u,
                         double* x, double* y, double* z);
void OCCTCurve3DD1(OCCTCurve3DRef curve, double u,
                   double* px, double* py, double* pz,
                   double* vx, double* vy, double* vz);
void OCCTCurve3DD2(OCCTCurve3DRef curve, double u,
                   double* px, double* py, double* pz,
                   double* v1x, double* v1y, double* v1z,
                   double* v2x, double* v2y, double* v2z);

// Primitive Curves
OCCTCurve3DRef OCCTCurve3DCreateLine(double px, double py, double pz,
                                      double dx, double dy, double dz);
OCCTCurve3DRef OCCTCurve3DCreateSegment(double p1x, double p1y, double p1z,
                                         double p2x, double p2y, double p2z);
OCCTCurve3DRef OCCTCurve3DCreateCircle(double cx, double cy, double cz,
                                        double nx, double ny, double nz,
                                        double radius);
OCCTCurve3DRef OCCTCurve3DCreateArcOfCircle(double p1x, double p1y, double p1z,
                                             double p2x, double p2y, double p2z,
                                             double p3x, double p3y, double p3z);
OCCTCurve3DRef OCCTCurve3DCreateArc3Points(double p1x, double p1y, double p1z,
                                            double pmx, double pmy, double pmz,
                                            double p2x, double p2y, double p2z);
OCCTCurve3DRef OCCTCurve3DCreateEllipse(double cx, double cy, double cz,
                                         double nx, double ny, double nz,
                                         double majorR, double minorR);
OCCTCurve3DRef OCCTCurve3DCreateParabola(double cx, double cy, double cz,
                                          double nx, double ny, double nz,
                                          double focal);
OCCTCurve3DRef OCCTCurve3DCreateHyperbola(double cx, double cy, double cz,
                                           double nx, double ny, double nz,
                                           double majorR, double minorR);

// BSpline / Bezier / Interpolation
OCCTCurve3DRef OCCTCurve3DCreateBSpline(const double* poles, int32_t poleCount,
                                         const double* weights,
                                         const double* knots, int32_t knotCount,
                                         const int32_t* multiplicities, int32_t degree);
OCCTCurve3DRef OCCTCurve3DCreateBezier(const double* poles, int32_t poleCount,
                                        const double* weights);
OCCTCurve3DRef OCCTCurve3DInterpolate(const double* points, int32_t count,
                                       bool closed, double tolerance);
OCCTCurve3DRef OCCTCurve3DInterpolateWithTangents(const double* points, int32_t count,
                                                   double stx, double sty, double stz,
                                                   double etx, double ety, double etz,
                                                   double tolerance);
OCCTCurve3DRef OCCTCurve3DFitPoints(const double* points, int32_t count,
                                     int32_t minDeg, int32_t maxDeg, double tolerance);

// BSpline queries
int32_t OCCTCurve3DGetPoleCount(OCCTCurve3DRef curve);
int32_t OCCTCurve3DGetPoles(OCCTCurve3DRef curve, double* outXYZ);
int32_t OCCTCurve3DGetDegree(OCCTCurve3DRef curve);

// Operations
OCCTCurve3DRef OCCTCurve3DTrim(OCCTCurve3DRef curve, double u1, double u2);
OCCTCurve3DRef OCCTCurve3DReversed(OCCTCurve3DRef curve);
OCCTCurve3DRef OCCTCurve3DTranslate(OCCTCurve3DRef curve, double dx, double dy, double dz);
OCCTCurve3DRef OCCTCurve3DRotate(OCCTCurve3DRef curve,
                                  double axisOx, double axisOy, double axisOz,
                                  double axisDx, double axisDy, double axisDz,
                                  double angle);
OCCTCurve3DRef OCCTCurve3DScale(OCCTCurve3DRef curve,
                                 double cx, double cy, double cz, double factor);
OCCTCurve3DRef OCCTCurve3DMirrorPoint(OCCTCurve3DRef curve,
                                       double px, double py, double pz);
OCCTCurve3DRef OCCTCurve3DMirrorAxis(OCCTCurve3DRef curve,
                                      double px, double py, double pz,
                                      double dx, double dy, double dz);
OCCTCurve3DRef OCCTCurve3DMirrorPlane(OCCTCurve3DRef curve,
                                       double px, double py, double pz,
                                       double nx, double ny, double nz);
double OCCTCurve3DGetLength(OCCTCurve3DRef curve);
double OCCTCurve3DGetLengthBetween(OCCTCurve3DRef curve, double u1, double u2);

// Conversion (GeomConvert)
OCCTCurve3DRef OCCTCurve3DToBSpline(OCCTCurve3DRef curve);
int32_t OCCTCurve3DBSplineToBeziers(OCCTCurve3DRef curve,
                                     OCCTCurve3DRef* out, int32_t max);
void OCCTCurve3DFreeArray(OCCTCurve3DRef* curves, int32_t count);
OCCTCurve3DRef OCCTCurve3DJoinToBSpline(const OCCTCurve3DRef* curves, int32_t count,
                                         double tolerance);
OCCTCurve3DRef OCCTCurve3DApproximate(OCCTCurve3DRef curve, double tolerance,
                                       int32_t continuity, int32_t maxSegments,
                                       int32_t maxDegree);

// Draw Methods (discretization for Metal)
int32_t OCCTCurve3DDrawAdaptive(OCCTCurve3DRef curve,
                                 double angularDefl, double chordalDefl,
                                 double* outXYZ, int32_t maxPoints);
int32_t OCCTCurve3DDrawUniform(OCCTCurve3DRef curve,
                                int32_t pointCount, double* outXYZ);
int32_t OCCTCurve3DDrawDeflection(OCCTCurve3DRef curve, double deflection,
                                   double* outXYZ, int32_t maxPoints);

// Local Properties
double OCCTCurve3DGetCurvature(OCCTCurve3DRef curve, double u);
bool   OCCTCurve3DGetTangent(OCCTCurve3DRef curve, double u,
                              double* tx, double* ty, double* tz);
bool   OCCTCurve3DGetNormal(OCCTCurve3DRef curve, double u,
                             double* nx, double* ny, double* nz);
bool   OCCTCurve3DGetCenterOfCurvature(OCCTCurve3DRef curve, double u,
                                        double* cx, double* cy, double* cz);
double OCCTCurve3DGetTorsion(OCCTCurve3DRef curve, double u);

// Bounding Box
bool OCCTCurve3DGetBoundingBox(OCCTCurve3DRef curve,
                                double* xMin, double* yMin, double* zMin,
                                double* xMax, double* yMax, double* zMax);


// MARK: - Surface: Parametric Surfaces (v0.20.0)

typedef struct OCCTSurface* OCCTSurfaceRef;

void OCCTSurfaceRelease(OCCTSurfaceRef surface);

// Properties
void   OCCTSurfaceGetDomain(OCCTSurfaceRef surface,
                             double* uMin, double* uMax,
                             double* vMin, double* vMax);
bool   OCCTSurfaceIsUClosed(OCCTSurfaceRef surface);
bool   OCCTSurfaceIsVClosed(OCCTSurfaceRef surface);
bool   OCCTSurfaceIsUPeriodic(OCCTSurfaceRef surface);
bool   OCCTSurfaceIsVPeriodic(OCCTSurfaceRef surface);
double OCCTSurfaceGetUPeriod(OCCTSurfaceRef surface);
double OCCTSurfaceGetVPeriod(OCCTSurfaceRef surface);

// Evaluation
void OCCTSurfaceGetPoint(OCCTSurfaceRef surface, double u, double v,
                          double* x, double* y, double* z);
void OCCTSurfaceD1(OCCTSurfaceRef surface, double u, double v,
                    double* px, double* py, double* pz,
                    double* dux, double* duy, double* duz,
                    double* dvx, double* dvy, double* dvz);
void OCCTSurfaceD2(OCCTSurfaceRef surface, double u, double v,
                    double* px, double* py, double* pz,
                    double* d1ux, double* d1uy, double* d1uz,
                    double* d1vx, double* d1vy, double* d1vz,
                    double* d2ux, double* d2uy, double* d2uz,
                    double* d2vx, double* d2vy, double* d2vz,
                    double* d2uvx, double* d2uvy, double* d2uvz);
bool OCCTSurfaceGetNormal(OCCTSurfaceRef surface, double u, double v,
                           double* nx, double* ny, double* nz);

// Analytic Surfaces
OCCTSurfaceRef OCCTSurfaceCreatePlane(double px, double py, double pz,
                                       double nx, double ny, double nz);
OCCTSurfaceRef OCCTSurfaceCreateCylinder(double px, double py, double pz,
                                          double dx, double dy, double dz,
                                          double radius);
OCCTSurfaceRef OCCTSurfaceCreateCone(double px, double py, double pz,
                                      double dx, double dy, double dz,
                                      double radius, double semiAngle);
OCCTSurfaceRef OCCTSurfaceCreateSphere(double cx, double cy, double cz,
                                        double radius);
OCCTSurfaceRef OCCTSurfaceCreateTorus(double px, double py, double pz,
                                       double dx, double dy, double dz,
                                       double majorRadius, double minorRadius);

// Swept Surfaces
OCCTSurfaceRef OCCTSurfaceCreateExtrusion(OCCTCurve3DRef profile,
                                           double dx, double dy, double dz);
OCCTSurfaceRef OCCTSurfaceCreateRevolution(OCCTCurve3DRef meridian,
                                            double px, double py, double pz,
                                            double dx, double dy, double dz);

// Freeform Surfaces
OCCTSurfaceRef OCCTSurfaceCreateBezier(const double* poles,
                                        int32_t uCount, int32_t vCount,
                                        const double* weights);
OCCTSurfaceRef OCCTSurfaceCreateBSpline(const double* poles,
                                         int32_t uPoleCount, int32_t vPoleCount,
                                         const double* weights,
                                         const double* uKnots, int32_t uKnotCount,
                                         const double* vKnots, int32_t vKnotCount,
                                         const int32_t* uMults, const int32_t* vMults,
                                         int32_t uDegree, int32_t vDegree);

// Operations
OCCTSurfaceRef OCCTSurfaceTrim(OCCTSurfaceRef surface,
                                double u1, double u2, double v1, double v2);
OCCTSurfaceRef OCCTSurfaceOffset(OCCTSurfaceRef surface, double distance);
OCCTSurfaceRef OCCTSurfaceTranslate(OCCTSurfaceRef surface,
                                     double dx, double dy, double dz);
OCCTSurfaceRef OCCTSurfaceRotate(OCCTSurfaceRef surface,
                                  double axOx, double axOy, double axOz,
                                  double axDx, double axDy, double axDz,
                                  double angle);
OCCTSurfaceRef OCCTSurfaceScale(OCCTSurfaceRef surface,
                                 double cx, double cy, double cz, double factor);
OCCTSurfaceRef OCCTSurfaceMirrorPlane(OCCTSurfaceRef surface,
                                       double px, double py, double pz,
                                       double nx, double ny, double nz);

// Conversion
OCCTSurfaceRef OCCTSurfaceToBSpline(OCCTSurfaceRef surface);
OCCTSurfaceRef OCCTSurfaceApproximate(OCCTSurfaceRef surface, double tolerance,
                                       int32_t continuity, int32_t maxSegments,
                                       int32_t maxDegree);

// Iso Curves (returns Curve3D)
OCCTCurve3DRef OCCTSurfaceUIso(OCCTSurfaceRef surface, double u);
OCCTCurve3DRef OCCTSurfaceVIso(OCCTSurfaceRef surface, double v);

// Pipe Surface (GeomFill_Pipe)
OCCTSurfaceRef OCCTSurfaceCreatePipe(OCCTCurve3DRef path, double radius);
OCCTSurfaceRef OCCTSurfaceCreatePipeWithSection(OCCTCurve3DRef path,
                                                 OCCTCurve3DRef section);

// Draw Methods (discretization for Metal)
/// Draw iso-parameter grid lines: uCount U-iso lines + vCount V-iso lines
/// Returns total point count. outXYZ[pointIndex*3..+3] for coordinates.
/// outLineLengths[lineIndex] = number of points in that line.
int32_t OCCTSurfaceDrawGrid(OCCTSurfaceRef surface,
                             int32_t uCount, int32_t vCount,
                             int32_t pointsPerLine,
                             double* outXYZ, int32_t maxPoints,
                             int32_t* outLineLengths, int32_t maxLines);

/// Sample a uniform grid of points for mesh triangulation
/// Returns total point count (uCount * vCount)
int32_t OCCTSurfaceDrawMesh(OCCTSurfaceRef surface,
                             int32_t uCount, int32_t vCount,
                             double* outXYZ);

// Local Properties (GeomLProp_SLProps)
double OCCTSurfaceGetGaussianCurvature(OCCTSurfaceRef surface, double u, double v);
double OCCTSurfaceGetMeanCurvature(OCCTSurfaceRef surface, double u, double v);
bool   OCCTSurfaceGetPrincipalCurvatures(OCCTSurfaceRef surface, double u, double v,
                                          double* kMin, double* kMax,
                                          double* d1x, double* d1y, double* d1z,
                                          double* d2x, double* d2y, double* d2z);

// Bounding Box
bool OCCTSurfaceGetBoundingBox(OCCTSurfaceRef surface,
                                double* xMin, double* yMin, double* zMin,
                                double* xMax, double* yMax, double* zMax);

// BSpline Queries
int32_t OCCTSurfaceGetUPoleCount(OCCTSurfaceRef surface);
int32_t OCCTSurfaceGetVPoleCount(OCCTSurfaceRef surface);
int32_t OCCTSurfaceGetPoles(OCCTSurfaceRef surface, double* outXYZ);
int32_t OCCTSurfaceGetUDegree(OCCTSurfaceRef surface);
int32_t OCCTSurfaceGetVDegree(OCCTSurfaceRef surface);


// MARK: - Law Functions (v0.21.0)

typedef struct OCCTLawFunction* OCCTLawFunctionRef;

void OCCTLawFunctionRelease(OCCTLawFunctionRef law);

/// Evaluate law value at parameter
double OCCTLawFunctionValue(OCCTLawFunctionRef law, double param);

/// Get law parameter bounds
void OCCTLawFunctionBounds(OCCTLawFunctionRef law, double* first, double* last);

/// Create a constant law: value is constant over [first, last]
OCCTLawFunctionRef OCCTLawCreateConstant(double value, double first, double last);

/// Create a linear law: linearly interpolates from (first, startVal) to (last, endVal)
OCCTLawFunctionRef OCCTLawCreateLinear(double first, double startVal,
                                        double last, double endVal);

/// Create an S-curve law: smooth sigmoid between (first, startVal) and (last, endVal)
OCCTLawFunctionRef OCCTLawCreateS(double first, double startVal,
                                   double last, double endVal);

/// Create an interpolated law from (parameter, value) pairs
/// points is array of [param0, val0, param1, val1, ...]
OCCTLawFunctionRef OCCTLawCreateInterpolate(const double* paramValues,
                                             int32_t count, bool periodic);

/// Create a BSpline law
OCCTLawFunctionRef OCCTLawCreateBSpline(const double* poles, int32_t poleCount,
                                         const double* knots, int32_t knotCount,
                                         const int32_t* multiplicities,
                                         int32_t degree);

/// Create pipe shell with law-based scaling along spine
/// profile: wire cross-section, spine: wire path, law: scaling evolution
OCCTShapeRef OCCTShapeCreatePipeShellWithLaw(OCCTWireRef spine,
                                              OCCTWireRef profile,
                                              OCCTLawFunctionRef law,
                                              bool solid);

// MARK: - XDE GD&T / Dimension Tolerance (v0.21.0)

/// Get count of dimension labels in document
int32_t OCCTDocumentGetDimensionCount(OCCTDocumentRef doc);

/// Get count of geometric tolerance labels in document
int32_t OCCTDocumentGetGeomToleranceCount(OCCTDocumentRef doc);

/// Get count of datum labels in document
int32_t OCCTDocumentGetDatumCount(OCCTDocumentRef doc);

/// Dimension info result
typedef struct {
    int32_t type;         // XCAFDimTolObjects_DimensionType enum
    double value;         // primary value
    double lowerTol;      // lower tolerance
    double upperTol;      // upper tolerance
    bool isValid;
} OCCTDimensionInfo;

/// Get dimension info at index
OCCTDimensionInfo OCCTDocumentGetDimensionInfo(OCCTDocumentRef doc, int32_t index);

/// Geometric tolerance info result
typedef struct {
    int32_t type;         // XCAFDimTolObjects_GeomToleranceType enum
    double value;         // tolerance value
    bool isValid;
} OCCTGeomToleranceInfo;

/// Get geometric tolerance info at index
OCCTGeomToleranceInfo OCCTDocumentGetGeomToleranceInfo(OCCTDocumentRef doc, int32_t index);

/// Datum info result
typedef struct {
    char name[64];        // datum identifier (A, B, C, etc.)
    bool isValid;
} OCCTDatumInfo;

/// Get datum info at index
OCCTDatumInfo OCCTDocumentGetDatumInfo(OCCTDocumentRef doc, int32_t index);

// MARK: - GD&T Write Path (v0.140)

/// Create a dimension attribute on the document and attach it to a shape label.
/// type: XCAFDimTolObjects_DimensionType enum
/// value: primary measured value
/// Returns -1 on failure, else the index of the new dimension (usable with
/// OCCTDocumentGetDimensionInfo).
int32_t OCCTDocumentCreateDimension(OCCTDocumentRef _Nonnull doc,
                                     int64_t shapeLabelId,
                                     int32_t type,
                                     double value);

/// Create a geometric tolerance attribute on the document and attach it to a shape.
/// type: XCAFDimTolObjects_GeomToleranceType enum
/// Returns -1 on failure, else the index of the new tolerance.
int32_t OCCTDocumentCreateGeomTolerance(OCCTDocumentRef _Nonnull doc,
                                         int64_t shapeLabelId,
                                         int32_t type,
                                         double value);

/// Create a datum attribute on the document with the given identifier.
/// Returns -1 on failure, else the index of the new datum.
int32_t OCCTDocumentCreateDatum(OCCTDocumentRef _Nonnull doc,
                                 const char* _Nonnull name);

/// Set tolerance bounds (lower + upper, relative to the primary value) on an
/// existing dimension. Returns true on success.
bool OCCTDocumentSetDimensionTolerance(OCCTDocumentRef _Nonnull doc,
                                        int32_t dimensionIndex,
                                        double lowerTol, double upperTol);


// MARK: - NLPlate: Advanced Plate Surfaces (v0.23.0)

/// Constraint order for advanced plate surface construction
typedef enum {
    OCCTPlateConstraintG0 = 0,  // Position only
    OCCTPlateConstraintG1 = 1,  // Position + tangent
    OCCTPlateConstraintG2 = 2   // Position + tangent + curvature
} OCCTPlateConstraintOrder;

/// Create a plate surface through points with specified constraint orders.
/// points: flat array of (x,y,z). orders: G0/G1/G2 per point.
/// Returns a BSpline face approximation.
OCCTShapeRef OCCTShapePlatePointsAdvanced(const double* points, int32_t pointCount,
                                           const int32_t* orders, int32_t degree,
                                           int32_t nbPtsOnCur, int32_t nbIter,
                                           double tolerance);

/// Create a plate surface with mixed point and curve constraints.
OCCTShapeRef OCCTShapePlateMixed(const double* points, const int32_t* pointOrders,
                                  int32_t pointCount,
                                  const OCCTWireRef* curves, const int32_t* curveOrders,
                                  int32_t curveCount,
                                  int32_t degree, double tolerance);

/// Create a plate surface (as parametric Surface) through points.
/// Uses GeomPlate_BuildPlateSurface + GeomPlate_MakeApprox.
OCCTSurfaceRef OCCTSurfacePlateThrough(const double* points, int32_t pointCount,
                                        int32_t degree, double tolerance);

/// Deform a surface to pass through constraint points (NLPlate G0).
/// constraints: flat array of (u, v, targetX, targetY, targetZ) per point.
OCCTSurfaceRef OCCTSurfaceNLPlateG0(OCCTSurfaceRef initialSurface,
                                     const double* constraints, int32_t constraintCount,
                                     int32_t maxIter, double tolerance);

/// Deform a surface with position + tangent constraints (NLPlate G0+G1).
/// constraints: flat (u, v, targetX, targetY, targetZ, d1uX, d1uY, d1uZ, d1vX, d1vY, d1vZ) per point.
OCCTSurfaceRef OCCTSurfaceNLPlateG1(OCCTSurfaceRef initialSurface,
                                     const double* constraints, int32_t constraintCount,
                                     int32_t maxIter, double tolerance);


// MARK: - ProjLib: Curve Projection onto Surfaces (v0.22.0)

/// Project a 3D curve onto a surface, returning a 2D (UV) curve.
/// Uses GeomProjLib::Curve2d. Returns NULL on failure.
OCCTCurve2DRef OCCTSurfaceProjectCurve2D(OCCTSurfaceRef surface,
                                          OCCTCurve3DRef curve,
                                          double tolerance);

/// Project a 3D curve onto a surface using composite projection (multiple segments).
/// Returns the number of 2D curve segments written to outCurves (up to maxCurves).
/// Uses ProjLib_CompProjectedCurve.
int32_t OCCTSurfaceProjectCurveSegments(OCCTSurfaceRef surface,
                                         OCCTCurve3DRef curve,
                                         double tolerance,
                                         OCCTCurve2DRef* outCurves,
                                         int32_t maxCurves);

/// Project a 3D curve onto a surface, returning the result as a 3D curve.
/// Uses GeomProjLib::Project. Returns NULL on failure.
OCCTCurve3DRef OCCTSurfaceProjectCurve3D(OCCTSurfaceRef surface,
                                          OCCTCurve3DRef curve);

/// Project a 3D curve onto a plane along a direction, returning a 3D curve.
/// Uses GeomProjLib::ProjectOnPlane.
/// (oX,oY,oZ) = plane origin, (nX,nY,nZ) = plane normal, (dX,dY,dZ) = projection direction.
OCCTCurve3DRef OCCTCurve3DProjectOnPlane(OCCTCurve3DRef curve,
                                          double oX, double oY, double oZ,
                                          double nX, double nY, double nZ,
                                          double dX, double dY, double dZ);

/// Project a point onto a parametric surface (closest point).
/// Returns true on success, writing UV parameters and distance.
/// Uses GeomAPI_ProjectPointOnSurf.
bool OCCTSurfaceProjectPoint(OCCTSurfaceRef surface,
                              double px, double py, double pz,
                              double* u, double* v, double* distance);


// MARK: - BRepMAT2d: Medial Axis Transform (v0.24.0)

/// Opaque handle for a computed medial axis of a planar face.
typedef struct OCCTMedialAxis* OCCTMedialAxisRef;

/// Node in the medial axis graph: position (x,y) and distance to boundary.
typedef struct {
    int32_t index;
    double x;
    double y;
    double distance;  // inscribed circle radius at this node
    bool isPending;   // true if node has only one linked arc (endpoint)
    bool isOnBoundary;
} OCCTMedialAxisNode;

/// Arc in the medial axis graph: connects two nodes, separates two boundary elements.
typedef struct {
    int32_t index;
    int32_t geomIndex;
    int32_t firstNodeIndex;
    int32_t secondNodeIndex;
    int32_t firstEltIndex;
    int32_t secondEltIndex;
} OCCTMedialAxisArc;

/// Compute the medial axis of a planar face.
/// The shape must contain at least one face; the first face is used.
/// Returns NULL on failure.
OCCTMedialAxisRef OCCTMedialAxisCompute(OCCTShapeRef shape, double tolerance);

/// Release a medial axis computation.
void OCCTMedialAxisRelease(OCCTMedialAxisRef ma);

/// Get the number of arcs (bisector curves) in the medial axis graph.
int32_t OCCTMedialAxisGetArcCount(OCCTMedialAxisRef ma);

/// Get the number of nodes (arc endpoints) in the medial axis graph.
int32_t OCCTMedialAxisGetNodeCount(OCCTMedialAxisRef ma);

/// Get information about a node by index (1-based).
/// Returns true on success.
bool OCCTMedialAxisGetNode(OCCTMedialAxisRef ma, int32_t index, OCCTMedialAxisNode* outNode);

/// Get information about an arc by index (1-based).
/// Returns true on success.
bool OCCTMedialAxisGetArc(OCCTMedialAxisRef ma, int32_t index, OCCTMedialAxisArc* outArc);

/// Sample points along a bisector arc. Returns the number of points written.
/// Points are written as (x,y) pairs into outXY (so outXY needs 2*maxPoints capacity).
/// index is 1-based.
int32_t OCCTMedialAxisDrawArc(OCCTMedialAxisRef ma, int32_t arcIndex,
                               double* outXY, int32_t maxPoints);

/// Sample all bisector arcs. Returns total number of points written.
/// outXY receives (x,y) pairs. lineStarts receives the starting index in outXY
/// for each arc. maxLines should be >= arc count.
int32_t OCCTMedialAxisDrawAll(OCCTMedialAxisRef ma,
                               double* outXY, int32_t maxPoints,
                               int32_t* lineStarts, int32_t* lineLengths, int32_t maxLines);

/// Get the inscribed circle distance (radius) at a point along an arc.
/// arcIndex is 1-based, t is in [0,1] where 0=firstNode, 1=secondNode.
double OCCTMedialAxisDistanceOnArc(OCCTMedialAxisRef ma, int32_t arcIndex, double t);

/// Get the minimum distance (half-thickness) across the entire medial axis.
/// Returns the smallest inscribed circle radius found at any node.
double OCCTMedialAxisMinThickness(OCCTMedialAxisRef ma);

/// Get the number of boundary elements (input edges) in the medial axis.
int32_t OCCTMedialAxisGetBasicEltCount(OCCTMedialAxisRef ma);


// MARK: - TNaming: Topological Naming History (v0.25.0)

/// Evolution type for TNaming history records.
typedef enum {
    OCCTNamingPrimitive  = 0,  ///< New entity created (old=NULL, new=shape)
    OCCTNamingGenerated  = 1,  ///< Entity generated from another (old=generator, new=result)
    OCCTNamingModify     = 2,  ///< Entity modified (old=before, new=after)
    OCCTNamingDelete     = 3,  ///< Entity deleted (old=shape, new=NULL)
    OCCTNamingSelected   = 4   ///< Named selection (old=context, new=selected)
} OCCTNamingEvolution;

/// A single entry in the naming history of a label.
typedef struct {
    OCCTNamingEvolution evolution;
    bool hasOldShape;
    bool hasNewShape;
    bool isModification;
} OCCTNamingHistoryEntry;

/// Create a new child label under the given parent label.
/// Pass parentLabelId = -1 to create under the document root.
/// Returns the new label's ID, or -1 on failure.
int64_t OCCTDocumentCreateLabel(OCCTDocumentRef doc, int64_t parentLabelId);

/// Record a naming evolution on a label.
/// For PRIMITIVE: oldShape=NULL, newShape=the created shape.
/// For GENERATED: oldShape=generator, newShape=generated result.
/// For MODIFY: oldShape=before, newShape=after.
/// For DELETE: oldShape=deleted shape, newShape=NULL.
/// For SELECTED: oldShape=context, newShape=selected shape.
/// Returns true on success.
bool OCCTDocumentNamingRecord(OCCTDocumentRef doc, int64_t labelId,
                               OCCTNamingEvolution evolution,
                               OCCTShapeRef oldShape, OCCTShapeRef newShape);

/// Get the current (most recent) shape stored on a label via TNaming.
/// Uses TNaming_Tool::CurrentShape. Returns NULL if no naming exists.
OCCTShapeRef OCCTDocumentNamingGetCurrentShape(OCCTDocumentRef doc, int64_t labelId);

/// Get the shape stored in the NamedShape attribute on a label.
/// Uses TNaming_Tool::GetShape. Returns NULL if no naming exists.
OCCTShapeRef OCCTDocumentNamingGetShape(OCCTDocumentRef doc, int64_t labelId);

/// Get the number of history entries (old/new pairs) on a label.
int32_t OCCTDocumentNamingHistoryCount(OCCTDocumentRef doc, int64_t labelId);

/// Get a specific history entry by index (0-based).
/// Returns true on success.
bool OCCTDocumentNamingGetHistoryEntry(OCCTDocumentRef doc, int64_t labelId,
                                        int32_t index, OCCTNamingHistoryEntry* outEntry);

/// Get the old shape from a specific history entry (0-based index).
/// Returns NULL if the entry has no old shape.
OCCTShapeRef OCCTDocumentNamingGetOldShape(OCCTDocumentRef doc, int64_t labelId, int32_t index);

/// Get the new shape from a specific history entry (0-based index).
/// Returns NULL if the entry has no new shape.
OCCTShapeRef OCCTDocumentNamingGetNewShape(OCCTDocumentRef doc, int64_t labelId, int32_t index);

/// Trace forward: find all shapes generated/modified from the given shape.
/// Uses TNaming_NewShapeIterator. accessLabelId provides the label scope.
/// Returns the number of shapes written to outShapes (up to maxCount).
/// Caller must release each returned shape.
int32_t OCCTDocumentNamingTraceForward(OCCTDocumentRef doc, int64_t accessLabelId,
                                        OCCTShapeRef shape,
                                        OCCTShapeRef* outShapes, int32_t maxCount);

/// Trace backward: find all shapes that generated/preceded the given shape.
/// Uses TNaming_OldShapeIterator. accessLabelId provides the label scope.
/// Returns the number of shapes written to outShapes (up to maxCount).
/// Caller must release each returned shape.
int32_t OCCTDocumentNamingTraceBackward(OCCTDocumentRef doc, int64_t accessLabelId,
                                         OCCTShapeRef shape,
                                         OCCTShapeRef* outShapes, int32_t maxCount);

/// Select a shape for persistent naming.
/// Creates a TNaming_Selector on the label and selects the shape within context.
/// Returns true on success.
bool OCCTDocumentNamingSelect(OCCTDocumentRef doc, int64_t labelId,
                               OCCTShapeRef selection, OCCTShapeRef context);

/// Resolve a previously selected shape after modifications.
/// Uses TNaming_Selector::Solve to update the selection.
/// Returns the resolved shape, or NULL on failure.
OCCTShapeRef OCCTDocumentNamingResolve(OCCTDocumentRef doc, int64_t labelId);

/// Get the evolution type of the NamedShape attribute on a label.
/// Returns -1 if no NamedShape exists on the label.
int32_t OCCTDocumentNamingGetEvolution(OCCTDocumentRef doc, int64_t labelId);


// ============================================================
// MARK: - AIS Annotations & Measurements (v0.26.0)
// ============================================================

/// Opaque handle to a dimension measurement (length, radius, angle, or diameter).
typedef struct OCCTDimension* OCCTDimensionRef;

/// Opaque handle to a positioned text label.
typedef struct OCCTTextLabel* OCCTTextLabelRef;

/// Opaque handle to a point cloud.
typedef struct OCCTPointCloud* OCCTPointCloudRef;

/// Kind of dimension measurement.
typedef enum {
    OCCTDimensionKindLength   = 0,
    OCCTDimensionKindRadius   = 1,
    OCCTDimensionKindAngle    = 2,
    OCCTDimensionKindDiameter = 3
} OCCTDimensionKind;

/// Geometry extracted from a dimension for Metal rendering.
typedef struct {
    double firstPoint[3];     ///< First attachment point (on geometry)
    double secondPoint[3];    ///< Second attachment point (on geometry)
    double centerPoint[3];    ///< Angle vertex; or circle center for radius/diameter
    double textPosition[3];   ///< Suggested text placement position
    double circleNormal[3];   ///< Circle axis for radius/diameter dimensions
    double circleRadius;      ///< Circle radius for radius/diameter dimensions
    double value;             ///< Measured value (distance in model units, angle in radians)
    int32_t kind;             ///< OCCTDimensionKind
    bool isValid;             ///< Whether the geometry is valid
} OCCTDimensionGeometry;

/// Info extracted from a text label.
typedef struct {
    double position[3];
    double height;
    char text[256];
} OCCTTextLabelInfo;

// --- Dimension creation ---

/// Create a length dimension between two 3D points.
OCCTDimensionRef OCCTDimensionCreateLengthFromPoints(
    double p1x, double p1y, double p1z,
    double p2x, double p2y, double p2z);

/// Create a length dimension measuring a linear edge.
OCCTDimensionRef OCCTDimensionCreateLengthFromEdge(OCCTShapeRef edge);

/// Create a length dimension between two parallel faces.
OCCTDimensionRef OCCTDimensionCreateLengthFromFaces(
    OCCTShapeRef face1, OCCTShapeRef face2);

/// Create a radius dimension from a shape with circular geometry.
OCCTDimensionRef OCCTDimensionCreateRadiusFromShape(OCCTShapeRef shape);

/// Create an angle dimension between two edges.
OCCTDimensionRef OCCTDimensionCreateAngleFromEdges(
    OCCTShapeRef edge1, OCCTShapeRef edge2);

/// Create an angle dimension from three points (first, vertex, second).
OCCTDimensionRef OCCTDimensionCreateAngleFromPoints(
    double p1x, double p1y, double p1z,
    double cx, double cy, double cz,
    double p2x, double p2y, double p2z);

/// Create an angle dimension between two planar faces.
OCCTDimensionRef OCCTDimensionCreateAngleFromFaces(
    OCCTShapeRef face1, OCCTShapeRef face2);

/// Create a diameter dimension from a shape with circular geometry.
OCCTDimensionRef OCCTDimensionCreateDiameterFromShape(OCCTShapeRef shape);

// --- Dimension common functions ---

/// Release a dimension handle.
void OCCTDimensionRelease(OCCTDimensionRef dim);

/// Get the measured (or custom) value of a dimension.
double OCCTDimensionGetValue(OCCTDimensionRef dim);

/// Get the full dimension geometry for rendering.
bool OCCTDimensionGetGeometry(OCCTDimensionRef dim, OCCTDimensionGeometry* outGeometry);

/// Override the dimension value with a custom number.
void OCCTDimensionSetCustomValue(OCCTDimensionRef dim, double value);

/// Check if the dimension geometry is valid.
bool OCCTDimensionIsValid(OCCTDimensionRef dim);

/// Get the kind of this dimension.
int32_t OCCTDimensionGetKind(OCCTDimensionRef dim);

// --- Text Label ---

/// Create a text label at a 3D position.
OCCTTextLabelRef OCCTTextLabelCreate(const char* text,
                                      double x, double y, double z);

/// Release a text label handle.
void OCCTTextLabelRelease(OCCTTextLabelRef label);

/// Set the label text.
void OCCTTextLabelSetText(OCCTTextLabelRef label, const char* text);

/// Set the label position.
void OCCTTextLabelSetPosition(OCCTTextLabelRef label,
                               double x, double y, double z);

/// Set the label text height.
void OCCTTextLabelSetHeight(OCCTTextLabelRef label, double height);

/// Get label info (text, position, height).
bool OCCTTextLabelGetInfo(OCCTTextLabelRef label, OCCTTextLabelInfo* outInfo);

// --- Point Cloud ---

/// Create a point cloud from xyz coordinate triples.
/// @param coords Array of [x0,y0,z0, x1,y1,z1, ...] (3 * count doubles)
/// @param count Number of points
OCCTPointCloudRef OCCTPointCloudCreate(const double* coords, int32_t count);

/// Create a colored point cloud.
/// @param coords Array of xyz triples (3 * count doubles)
/// @param colors Array of rgb triples (3 * count floats, each in [0,1])
/// @param count Number of points
OCCTPointCloudRef OCCTPointCloudCreateColored(const double* coords,
                                               const float* colors,
                                               int32_t count);

/// Release a point cloud handle.
void OCCTPointCloudRelease(OCCTPointCloudRef cloud);

/// Get the number of points in the cloud.
int32_t OCCTPointCloudGetCount(OCCTPointCloudRef cloud);

/// Get the axis-aligned bounding box.
/// Returns true on success, fills minXYZ[3] and maxXYZ[3].
bool OCCTPointCloudGetBounds(OCCTPointCloudRef cloud,
                              double* outMinXYZ, double* outMaxXYZ);

/// Copy point coordinates into the output buffer.
/// @param outCoords Buffer for xyz triples (must hold at least 3 * count doubles)
/// @param maxCount Maximum number of points to copy
/// @return Number of points copied
int32_t OCCTPointCloudGetPoints(OCCTPointCloudRef cloud,
                                 double* outCoords, int32_t maxCount);

/// Copy point colors into the output buffer.
/// @param outColors Buffer for rgb triples (must hold at least 3 * count floats)
/// @param maxCount Maximum number of colors to copy
/// @return Number of colors copied (0 if uncolored)
int32_t OCCTPointCloudGetColors(OCCTPointCloudRef cloud,
                                 float* outColors, int32_t maxCount);


// MARK: - Helix Curves (v0.28.0)

/// Create a helical wire (constant radius).
/// @param originX/Y/Z Helix axis origin
/// @param axisX/Y/Z Helix axis direction
/// @param radius Helix radius
/// @param pitch Distance between consecutive turns
/// @param turns Number of turns
/// @param clockwise true for clockwise, false for counter-clockwise
OCCTWireRef OCCTWireCreateHelix(double originX, double originY, double originZ,
                                 double axisX, double axisY, double axisZ,
                                 double radius, double pitch, double turns,
                                 bool clockwise);

/// Create a tapered (conical) helical wire.
/// @param startRadius Radius at the start
/// @param endRadius Radius at the end
OCCTWireRef OCCTWireCreateHelixTapered(double originX, double originY, double originZ,
                                        double axisX, double axisY, double axisZ,
                                        double startRadius, double endRadius,
                                        double pitch, double turns,
                                        bool clockwise);

// MARK: - KD-Tree Spatial Queries (v0.28.0)

/// Opaque handle to a KD-tree for 3D point queries.
typedef struct OCCTKDTree* OCCTKDTreeRef;

/// Build a KD-tree from 3D points.
/// @param coords Flat array of xyz coordinates (3 * count doubles)
/// @param count Number of points
OCCTKDTreeRef OCCTKDTreeBuild(const double* coords, int32_t count);

/// Release a KD-tree.
void OCCTKDTreeRelease(OCCTKDTreeRef tree);

/// Find the nearest point in the tree to a query point.
/// @param outDistance If non-null, receives the distance (not squared)
/// @return 0-based index of the nearest point, or -1 on error
int32_t OCCTKDTreeNearestPoint(OCCTKDTreeRef tree,
                                double qx, double qy, double qz,
                                double* outDistance);

/// Find the K nearest points.
/// @param outIndices Buffer for 0-based indices (must hold at least k entries)
/// @param outSqDistances Buffer for squared distances (may be null)
/// @param k Number of neighbors to find
/// @return Number of points found
int32_t OCCTKDTreeKNearest(OCCTKDTreeRef tree,
                            double qx, double qy, double qz,
                            int32_t k,
                            int32_t* outIndices,
                            double* outSqDistances);

/// Find all points within a sphere of given radius.
/// @param outIndices Buffer for 0-based indices
/// @param maxResults Maximum number of results
/// @return Number of points found
int32_t OCCTKDTreeRangeSearch(OCCTKDTreeRef tree,
                               double qx, double qy, double qz,
                               double radius,
                               int32_t* outIndices, int32_t maxResults);

/// Find all points within an axis-aligned bounding box.
int32_t OCCTKDTreeBoxSearch(OCCTKDTreeRef tree,
                             double minX, double minY, double minZ,
                             double maxX, double maxY, double maxZ,
                             int32_t* outIndices, int32_t maxResults);

// MARK: - STEP Optimization (v0.28.0)

/// Optimize a STEP file by merging duplicate entities.
/// Reads a STEP file, deduplicates geometric entities, and writes the result.
/// @param inputPath Path to input STEP file
/// @param outputPath Path to output STEP file
/// @return true on success
bool OCCTStepTidyOptimize(const char* inputPath, const char* outputPath);

// MARK: - Batch Curve2D Evaluation (v0.28.0)

/// Evaluate a 2D curve at multiple parameter values (batch).
/// @param curve The curve to evaluate
/// @param params Array of parameter values
/// @param paramCount Number of parameters
/// @param outXY Output buffer for xy pairs (must hold 2 * paramCount doubles)
/// @return Number of points evaluated
int32_t OCCTCurve2DEvaluateGrid(OCCTCurve2DRef curve,
                                 const double* params, int32_t paramCount,
                                 double* outXY);

/// Evaluate a 2D curve and its first derivative at multiple parameters (batch).
/// @param outXY Output buffer for point xy pairs (2 * paramCount doubles)
/// @param outDXDY Output buffer for derivative xy pairs (2 * paramCount doubles)
/// @return Number of points evaluated
int32_t OCCTCurve2DEvaluateGridD1(OCCTCurve2DRef curve,
                                   const double* params, int32_t paramCount,
                                   double* outXY, double* outDXDY);


// MARK: - Wedge Primitive (v0.29.0)

/// Create a wedge (tapered box) primitive.
/// @param dx, dy, dz Full dimensions in X, Y, Z
/// @param ltx X dimension at the top (0 for a full taper to a ridge)
/// @return Wedge shape, or NULL on failure
OCCTShapeRef OCCTShapeCreateWedge(double dx, double dy, double dz, double ltx);

/// Create a wedge primitive with min/max control on the top face.
/// @param dx, dy, dz Full dimensions in X, Y, Z
/// @param xmin, zmin, xmax, zmax Bounds of the top face within the base
/// @return Wedge shape, or NULL on failure
OCCTShapeRef OCCTShapeCreateWedgeAdvanced(double dx, double dy, double dz,
                                           double xmin, double zmin, double xmax, double zmax);
OCCTShapeRef _Nullable OCCTShapeCreateWedgeOriented(
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double dx, double dy, double dz, double ltx);


// MARK: - NURBS Conversion (v0.29.0)

/// Convert all geometry in a shape to NURBS representation.
/// @param shape The shape to convert
/// @return NURBS shape, or NULL on failure
OCCTShapeRef OCCTShapeConvertToNURBS(OCCTShapeRef shape);


// MARK: - Fast Sewing (v0.29.0)

/// Sew faces using the fast sewing algorithm (less robust but faster).
/// @param shape The shape to sew
/// @param tolerance Sewing tolerance
/// @return Sewn shape, or NULL on failure
OCCTShapeRef OCCTShapeFastSewn(OCCTShapeRef shape, double tolerance);


// MARK: - Normal Projection (v0.29.0)

/// Project a wire or edge normally onto a surface shape.
/// @param wireOrEdge Wire or edge to project
/// @param surface Surface shape to project onto
/// @param tol3d 3D tolerance
/// @param tol2d 2D tolerance
/// @param maxDegree Maximum degree of resulting curve
/// @param maxSeg Maximum segments of resulting curve
/// @return Projected shape, or NULL on failure
OCCTShapeRef OCCTShapeNormalProjection(OCCTShapeRef wireOrEdge, OCCTShapeRef surface,
                                        double tol3d, double tol2d, int maxDegree, int maxSeg);


// MARK: - Batch Curve3D Evaluation (v0.29.0)

/// Evaluate a 3D curve at multiple parameter values (batch).
/// @param curve The curve to evaluate
/// @param params Array of parameter values
/// @param paramCount Number of parameters
/// @param outXYZ Output buffer for xyz triples (must hold 3 * paramCount doubles)
/// @return Number of points evaluated
int32_t OCCTCurve3DEvaluateGrid(OCCTCurve3DRef curve, const double* params, int32_t paramCount,
                                 double* outXYZ);

/// Evaluate a 3D curve and its first derivative at multiple parameters (batch).
/// @param outXYZ Output buffer for point xyz triples (3 * paramCount doubles)
/// @param outDXDYDZ Output buffer for derivative xyz triples (3 * paramCount doubles)
/// @return Number of points evaluated
int32_t OCCTCurve3DEvaluateGridD1(OCCTCurve3DRef curve, const double* params, int32_t paramCount,
                                   double* outXYZ, double* outDXDYDZ);


// MARK: - Batch Surface Evaluation (v0.29.0)

/// Evaluate a surface at a grid of UV parameter values (batch).
/// Output is row-major (u varies fastest): outXYZ[(iv * uCount + iu) * 3 + {0,1,2}].
/// @param surface The surface to evaluate
/// @param uParams Array of U parameter values
/// @param uCount Number of U parameters
/// @param vParams Array of V parameter values
/// @param vCount Number of V parameters
/// @param outXYZ Output buffer for xyz triples (must hold 3 * uCount * vCount doubles)
/// @return Number of points evaluated (uCount * vCount on success)
int32_t OCCTSurfaceEvaluateGrid(OCCTSurfaceRef surface,
                                 const double* uParams, int32_t uCount,
                                 const double* vParams, int32_t vCount,
                                 double* outXYZ);


// MARK: - Wire Explorer (v0.29.0)

/// Get the number of edges in a wire by ordered traversal.
/// @param wire The wire to explore
/// @return Number of edges
int32_t OCCTWireExplorerEdgeCount(OCCTWireRef wire);

/// Get a discretized edge from a wire by ordered traversal index.
/// @param wire The wire to explore
/// @param index 0-based edge index
/// @param outPoints Output buffer for xyz triples [x,y,z,...]
/// @param maxPoints Maximum number of points to output
/// @param outPointCount Output: actual number of points written
/// @return true on success
bool OCCTWireExplorerGetEdge(OCCTWireRef wire, int32_t index,
                              double* outPoints, int32_t maxPoints, int32_t* outPointCount);

/// Get the number of discretized points for an edge in a wire.
/// @param wire The wire to explore
/// @param index 0-based edge index
/// @return Number of points, or 0 on failure
int32_t OCCTWireExplorerGetEdgePointCount(OCCTWireRef wire, int32_t index);


// MARK: - Half-Space (v0.29.0)

/// Create a half-space solid from a face and a reference point.
/// The half-space is the solid containing the reference point.
/// @param faceShape Shape containing a face (first face is used)
/// @param refX, refY, refZ Reference point in the desired half-space
/// @return Half-space solid, or NULL on failure
OCCTShapeRef OCCTShapeCreateHalfSpace(OCCTShapeRef faceShape, double refX, double refY, double refZ);


// MARK: - Polynomial Solvers (v0.29.0)

/// Result of a polynomial root finding operation.
typedef struct {
    int32_t count;
    double roots[4];
} OCCTPolynomialRoots;

/// Solve a quadratic equation: a*x^2 + b*x + c = 0
OCCTPolynomialRoots OCCTSolveQuadratic(double a, double b, double c);

/// Solve a cubic equation: a*x^3 + b*x^2 + c*x + d = 0
OCCTPolynomialRoots OCCTSolveCubic(double a, double b, double c, double d);

/// Solve a quartic equation: a*x^4 + b*x^3 + c*x^2 + d*x + e = 0
OCCTPolynomialRoots OCCTSolveQuartic(double a, double b, double c, double d, double e);


// MARK: - Sub-Shape Replacement (v0.29.0)

/// Replace a sub-shape within a shape.
/// @param shape The parent shape
/// @param oldSub Sub-shape to replace
/// @param newSub Replacement sub-shape
/// @return Modified shape, or NULL on failure
OCCTShapeRef OCCTShapeReplaceSubShape(OCCTShapeRef shape, OCCTShapeRef oldSub, OCCTShapeRef newSub);

/// Remove a sub-shape from a shape.
/// @param shape The parent shape
/// @param subToRemove Sub-shape to remove
/// @return Modified shape, or NULL on failure
OCCTShapeRef OCCTShapeRemoveSubShape(OCCTShapeRef shape, OCCTShapeRef subToRemove);


// MARK: - Periodic Shapes (v0.29.0)

/// Make a shape periodic in one or more directions.
/// @param shape The shape to make periodic
/// @param xPeriodic, yPeriodic, zPeriodic Enable periodicity in each direction
/// @param xPeriod, yPeriod, zPeriod Period value in each direction
/// @return Periodic shape, or NULL on failure
OCCTShapeRef OCCTShapeMakePeriodic(OCCTShapeRef shape,
                                    bool xPeriodic, double xPeriod,
                                    bool yPeriodic, double yPeriod,
                                    bool zPeriodic, double zPeriod);

/// Repeat a periodic shape in one or more directions.
/// @param shape The base shape (should be made periodic first)
/// @param xPeriodic, yPeriodic, zPeriodic Enable repetition in each direction
/// @param xPeriod, yPeriod, zPeriod Period value for repetition
/// @param xTimes, yTimes, zTimes Number of repetitions in each direction
/// @return Repeated shape, or NULL on failure
OCCTShapeRef OCCTShapeRepeat(OCCTShapeRef shape,
                              bool xPeriodic, double xPeriod,
                              bool yPeriodic, double yPeriod,
                              bool zPeriodic, double zPeriod,
                              int32_t xTimes, int32_t yTimes, int32_t zTimes);


// MARK: - Hatch Patterns (v0.29.0)

/// Generate hatch line segments within a 2D polygon boundary.
/// @param boundaryXY Flat array of (x,y) pairs defining the boundary polygon
/// @param boundaryCount Number of boundary points
/// @param dirX, dirY Hatch line direction
/// @param spacing Distance between hatch lines
/// @param offset Offset of the first hatch line from origin
/// @param outSegments Output buffer: pairs of (x1,y1,x2,y2) per segment (4 doubles each)
/// @param maxSegments Maximum number of output segments
/// @return Number of segments written
int32_t OCCTHatchLines(const double* boundaryXY, int32_t boundaryCount,
                        double dirX, double dirY, double spacing, double offset,
                        double* outSegments, int32_t maxSegments);


// MARK: - Draft from Shape (v0.29.0)

/// Create a draft shell by sweeping a shape along a direction with taper angle.
/// @param shape Wire or edge to draft from
/// @param dirX, dirY, dirZ Draft direction
/// @param angle Taper angle in radians
/// @param lengthMax Maximum draft length
/// @return Draft shell shape, or NULL on failure
OCCTShapeRef OCCTShapeMakeDraft(OCCTShapeRef shape, double dirX, double dirY, double dirZ,
                                 double angle, double lengthMax);


// MARK: - Curve Planarity Check (v0.29.0)

/// Check if a 3D curve is planar.
/// @param curve The curve to check
/// @param tolerance Planarity tolerance
/// @param outNX, outNY, outNZ Output: normal of the plane (if planar)
/// @return true if the curve is planar
bool OCCTCurve3DIsPlanar(OCCTCurve3DRef curve, double tolerance,
                          double* outNX, double* outNY, double* outNZ);


// MARK: - Revolution Feature (v0.29.0)

// NOTE: BRepFeat_MakeRevol is complex (requires sketch face identification).
// This function is omitted because identifying the correct sketch face from the
// profile shape is highly context-dependent and error-prone in a generic C bridge.
// Users should instead use OCCTShapeCreateRevolution (sweep-based) for revolution solids,
// or BRepAlgoAPI_Fuse/Cut for adding/subtracting revolved material.


// MARK: - Non-Uniform Transform (v0.30.0)

/// Apply non-uniform scaling to a shape using BRepBuilderAPI_GTransform.
/// @param shape The shape to scale
/// @param sx Scale factor in X direction
/// @param sy Scale factor in Y direction
/// @param sz Scale factor in Z direction
/// @return Scaled shape, or NULL on failure
OCCTShapeRef OCCTShapeNonUniformScale(OCCTShapeRef shape, double sx, double sy, double sz);


// MARK: - Make Shell (v0.30.0)

/// Create a shell from a surface using BRepBuilderAPI_MakeShell.
/// @param surface The surface to convert to a shell
/// @return Shell shape, or NULL on failure
OCCTShapeRef OCCTShapeCreateShellFromSurface(OCCTSurfaceRef surface);


// MARK: - Make Vertex (v0.30.0)

/// Create a vertex at a point using BRepBuilderAPI_MakeVertex.
/// @param x X coordinate
/// @param y Y coordinate
/// @param z Z coordinate
/// @return Vertex shape, or NULL on failure
OCCTShapeRef OCCTShapeCreateVertex(double x, double y, double z);


// MARK: - Simple Offset (v0.30.0)

/// Create a simple offset of a shape using BRepOffset_MakeSimpleOffset.
/// @param shape The shape to offset
/// @param offsetValue Offset distance (positive = outward)
/// @return Offset shape, or NULL on failure
OCCTShapeRef OCCTShapeSimpleOffset(OCCTShapeRef shape, double offsetValue);


// MARK: - Middle Path (v0.30.0)

/// Compute the middle path between two sub-shapes using BRepOffsetAPI_MiddlePath.
/// @param shape The main shape (typically a solid or shell)
/// @param startShape Start sub-shape (wire or edge on the shape)
/// @param endShape End sub-shape (wire or edge on the shape)
/// @return Middle path wire, or NULL on failure
OCCTShapeRef OCCTShapeMiddlePath(OCCTShapeRef shape, OCCTShapeRef startShape, OCCTShapeRef endShape);


// MARK: - Fuse Edges (v0.30.0)

/// Fuse connected edges sharing the same geometry using BRepLib_FuseEdges.
/// @param shape The shape containing edges to fuse
/// @return Shape with fused edges, or NULL on failure
OCCTShapeRef OCCTShapeFuseEdges(OCCTShapeRef shape);


// MARK: - Maker Volume (v0.30.0)

/// Create a solid volume from a set of shapes using BOPAlgo_MakerVolume.
/// @param shapes Array of shape references
/// @param count Number of shapes
/// @return Volume solid, or NULL on failure
OCCTShapeRef OCCTShapeMakeVolume(OCCTShapeRef* shapes, int32_t count);


// MARK: - Make Connected (v0.30.0)

/// Make a set of shapes connected using BOPAlgo_MakeConnected.
/// @param shapes Array of shape references
/// @param count Number of shapes
/// @return Connected shape, or NULL on failure
OCCTShapeRef OCCTShapeMakeConnected(OCCTShapeRef* shapes, int32_t count);


// MARK: - Curve-Curve Extrema (v0.30.0)

/// Result structure for curve-curve extrema computation.
typedef struct {
    double distance;    ///< Distance between closest points
    double point1[3];   ///< Closest point on curve 1 (x, y, z)
    double point2[3];   ///< Closest point on curve 2 (x, y, z)
    double param1;      ///< Parameter on curve 1
    double param2;      ///< Parameter on curve 2
} OCCTCurveExtrema;

/// Compute the minimum distance between two 3D curves.
/// @param c1 First curve
/// @param c2 Second curve
/// @return Minimum distance, or -1.0 on failure
double OCCTCurve3DMinDistanceToCurve(OCCTCurve3DRef c1, OCCTCurve3DRef c2);

/// Compute all extrema (closest/farthest point pairs) between two 3D curves.
/// @param c1 First curve
/// @param c2 Second curve
/// @param outExtrema Output buffer for extrema results
/// @param maxCount Maximum number of results to write
/// @return Number of extrema found, or 0 on failure
int32_t OCCTCurve3DExtrema(OCCTCurve3DRef c1, OCCTCurve3DRef c2, OCCTCurveExtrema* outExtrema, int32_t maxCount);


// MARK: - Curve-Surface Intersection (v0.30.0)

/// Result structure for curve-surface intersection.
typedef struct {
    double point[3];    ///< Intersection point (x, y, z)
    double paramCurve;  ///< W parameter on the curve
    double paramU;      ///< U parameter on the surface
    double paramV;      ///< V parameter on the surface
} OCCTCurveSurfaceIntersection;

/// Compute intersection points between a 3D curve and a surface.
/// @param curve The 3D curve
/// @param surface The surface
/// @param outHits Output buffer for intersection results
/// @param maxHits Maximum number of results to write
/// @return Number of intersections found, or 0 on failure
int32_t OCCTCurve3DIntersectSurface(OCCTCurve3DRef curve, OCCTSurfaceRef surface,
                                     OCCTCurveSurfaceIntersection* outHits, int32_t maxHits);


// MARK: - Surface-Surface Intersection (v0.30.0)

/// Compute intersection curves between two surfaces.
/// @param s1 First surface
/// @param s2 Second surface
/// @param tolerance Intersection tolerance
/// @param outCurves Output buffer for intersection curve references
/// @param maxCurves Maximum number of curves to write
/// @return Number of intersection curves found, or 0 on failure
int32_t OCCTSurfaceIntersect(OCCTSurfaceRef s1, OCCTSurfaceRef s2, double tolerance,
                              OCCTCurve3DRef* outCurves, int32_t maxCurves);


// MARK: - Curve-Surface Distance (v0.30.0)

/// Compute the minimum distance between a 3D curve and a surface.
/// @param curve The 3D curve
/// @param surface The surface
/// @return Minimum distance, or -1.0 on failure
double OCCTCurve3DDistanceToSurface(OCCTCurve3DRef curve, OCCTSurfaceRef surface);


// MARK: - Curve to Analytical (v0.30.0)

/// Convert a curve to its analytical (canonical) form if possible.
/// @param curve The input curve
/// @param tolerance Conversion tolerance
/// @return Analytical curve, or NULL if conversion is not possible
OCCTCurve3DRef OCCTCurve3DToAnalytical(OCCTCurve3DRef curve, double tolerance);


// MARK: - Surface to Analytical (v0.30.0)

/// Convert a surface to its analytical (canonical) form if possible.
/// @param surface The input surface
/// @param tolerance Conversion tolerance
/// @return Analytical surface, or NULL if conversion is not possible
OCCTSurfaceRef OCCTSurfaceToAnalytical(OCCTSurfaceRef surface, double tolerance);


// MARK: - Shape Contents (v0.30.0)

/// Structure containing counts of topological entities in a shape.
typedef struct {
    int32_t nbSolids;      ///< Number of solids
    int32_t nbShells;      ///< Number of shells
    int32_t nbFaces;       ///< Number of faces
    int32_t nbWires;       ///< Number of wires
    int32_t nbEdges;       ///< Number of edges
    int32_t nbVertices;    ///< Number of vertices
    int32_t nbFreeEdges;   ///< Number of free (unattached) edges
    int32_t nbFreeWires;   ///< Number of free (unattached) wires
    int32_t nbFreeFaces;   ///< Number of free (unattached) faces
} OCCTShapeContents;

/// Analyze shape contents and return counts of topological entities.
/// @param shape The shape to analyze
/// @return Structure with entity counts (all zeros on failure)
OCCTShapeContents OCCTShapeGetContents(OCCTShapeRef shape);


// MARK: - Canonical Recognition (v0.30.0)

/// Structure describing a recognized canonical geometric form.
typedef struct {
    int32_t type;       ///< 0=unknown, 1=plane, 2=cylinder, 3=cone, 4=sphere, 5=line, 6=circle, 7=ellipse
    double origin[3];   ///< Origin point (x, y, z)
    double direction[3];///< Direction or normal (x, y, z)
    double radius;      ///< Primary radius (for cylinder/cone/sphere/circle)
    double radius2;     ///< Secondary radius (for cone/ellipse)
    double gap;         ///< Approximation gap
} OCCTCanonicalForm;

/// Attempt to recognize a shape as a canonical geometric form.
/// @param shape The shape to recognize (face, edge, etc.)
/// @param tolerance Recognition tolerance
/// @return Recognized form (type=0 if unrecognized)
OCCTCanonicalForm OCCTShapeRecognizeCanonical(OCCTShapeRef shape, double tolerance);


// MARK: - Edge Analysis (v0.30.0)

/// Check if an edge has a 3D curve representation.
/// @param edge The edge shape
/// @return true if the edge has a 3D curve
bool OCCTEdgeHasCurve3D(OCCTShapeRef edge);

/// Check if an edge is closed (start == end) in 3D.
/// @param edge The edge shape
/// @return true if the edge is closed
bool OCCTEdgeIsClosed3D(OCCTShapeRef edge);

/// Check if an edge is a seam edge on a face.
/// @param edge The edge shape
/// @param face The face shape
/// @return true if the edge is a seam edge on the face
bool OCCTEdgeIsSeam(OCCTShapeRef edge, OCCTShapeRef face);


// MARK: - Find Surface (v0.30.0)

/// Find a surface that approximates a shape (wire, set of edges, etc.).
/// @param shape The shape to find a surface for
/// @param tolerance Approximation tolerance
/// @return Surface reference, or NULL if not found
OCCTSurfaceRef OCCTShapeFindSurface(OCCTShapeRef shape, double tolerance);


// MARK: - Contiguous Edges (v0.30.0)

/// Find contiguous edge pairs in a shape.
/// @param shape The shape to analyze
/// @param tolerance Contiguity tolerance
/// @return Number of contiguous edge pairs found, or 0 on failure
int32_t OCCTShapeFindContiguousEdges(OCCTShapeRef shape, double tolerance);


// MARK: - Shape Fix Wireframe (v0.30.0)

/// Fix wireframe issues (small edges, wire gaps) in a shape.
/// @param shape The shape to fix
/// @param tolerance Precision for fixing
/// @return Fixed shape, or NULL on failure
OCCTShapeRef OCCTShapeFixWireframe(OCCTShapeRef shape, double tolerance);


// MARK: - Remove Internal Wires (v0.30.0)

/// Remove internal wires (holes) below a minimum area from a shape.
/// @param shape The shape to process
/// @param minArea Minimum area threshold; wires enclosing less area are removed
/// @return Shape with internal wires removed, or NULL on failure
OCCTShapeRef OCCTShapeRemoveInternalWires(OCCTShapeRef shape, double minArea);


// MARK: - Document Length Unit (v0.30.0)

/// Get the length unit information from an XDE document.
/// @param doc The document to query
/// @param unitScale Output: the scale factor relative to mm (e.g. 1.0 for mm, 10.0 for cm)
/// @param unitName Output: buffer for unit name string
/// @param maxNameLen Maximum length of the unitName buffer
/// @return true if length unit information was found
bool OCCTDocumentGetLengthUnit(OCCTDocumentRef doc, double* unitScale, char* unitName, int32_t maxNameLen);


// MARK: - Quasi-Uniform Curve Sampling (v0.31.0)

/// Sample curve parameters using quasi-uniform abscissa distribution.
/// @param curve The curve to sample
/// @param nbPoints Desired number of sample points
/// @param outParams Output array for parameter values (must hold nbPoints doubles)
/// @return Actual number of parameters written, or 0 on failure
int32_t OCCTCurve3DQuasiUniformAbscissa(OCCTCurve3DRef curve, int32_t nbPoints, double* outParams);


// MARK: - Quasi-Uniform Deflection Sampling (v0.31.0)

/// Sample curve points using quasi-uniform deflection distribution.
/// @param curve The curve to sample
/// @param deflection Maximum deflection tolerance
/// @param outXYZ Output array for point coordinates (x,y,z triples; must hold maxPoints*3 doubles)
/// @param maxPoints Maximum number of points to return
/// @return Actual number of points written, or 0 on failure
int32_t OCCTCurve3DQuasiUniformDeflection(OCCTCurve3DRef curve, double deflection, double* outXYZ, int32_t maxPoints);


// MARK: - Bezier Surface Fill (v0.31.0)

/// Create a Bezier surface by filling 4 Bezier boundary curves.
/// @param c1, c2, c3, c4 The four boundary curves (must be Bezier curves)
/// @param fillStyle Filling style: 0=stretch, 1=coons, 2=curved
/// @return Surface reference, or NULL on failure
OCCTSurfaceRef OCCTSurfaceBezierFill4(OCCTCurve3DRef c1, OCCTCurve3DRef c2,
                                        OCCTCurve3DRef c3, OCCTCurve3DRef c4,
                                        int32_t fillStyle);

/// Create a Bezier surface by filling 2 Bezier boundary curves.
/// @param c1, c2 The two boundary curves (must be Bezier curves)
/// @param fillStyle Filling style: 0=stretch, 1=coons, 2=curved
/// @return Surface reference, or NULL on failure
OCCTSurfaceRef OCCTSurfaceBezierFill2(OCCTCurve3DRef c1, OCCTCurve3DRef c2,
                                        int32_t fillStyle);


// MARK: - Quilt Faces (v0.31.0)

/// Quilt multiple shapes (faces/shells) together into a single shell.
/// @param shapes Array of shape references to quilt
/// @param count Number of shapes in the array
/// @return Resulting shell shape, or NULL on failure
OCCTShapeRef OCCTShapeQuilt(OCCTShapeRef* shapes, int32_t count);


// MARK: - Fix Small Faces (v0.31.0)

/// Fix small faces in a shape by removing or merging them.
/// @param shape The shape to fix
/// @param tolerance Precision tolerance for identifying small faces
/// @return Fixed shape, or NULL on failure
OCCTShapeRef OCCTShapeFixSmallFaces(OCCTShapeRef shape, double tolerance);


// MARK: - Remove Locations (v0.31.0)

/// Remove all locations (transformations) from a shape, baking them into geometry.
/// @param shape The shape to process
/// @return Shape with locations removed, or NULL on failure
OCCTShapeRef OCCTShapeRemoveLocations(OCCTShapeRef shape);


// MARK: - Revolution from Curve (v0.31.0)

/// Create a solid of revolution from a meridian curve.
/// @param meridian The curve to revolve (meridian profile)
/// @param axOX, axOY, axOZ Origin of the revolution axis
/// @param axDX, axDY, axDZ Direction of the revolution axis
/// @param angle Revolution angle in radians (use 2*pi for full revolution)
/// @return Revolved shape, or NULL on failure
OCCTShapeRef OCCTShapeCreateRevolutionFromCurve(OCCTCurve3DRef meridian,
                                                 double axOX, double axOY, double axOZ,
                                                 double axDX, double axDY, double axDZ,
                                                 double angle);


// MARK: - Document Layers (v0.31.0)

/// Get the number of layers in a document.
/// @param doc The document to query
/// @return Number of layers, or 0 on failure
int32_t OCCTDocumentGetLayerCount(OCCTDocumentRef doc);

/// Get the name of a layer by index.
/// @param doc The document to query
/// @param index Zero-based layer index
/// @param outName Output buffer for the layer name
/// @param maxLen Maximum length of the output buffer
/// @return true if the layer name was retrieved successfully
bool OCCTDocumentGetLayerName(OCCTDocumentRef doc, int32_t index, char* outName, int32_t maxLen);


// MARK: - Document Materials (v0.31.0)

/// Material info structure returned by OCCTDocumentGetMaterialInfo.
typedef struct {
    char name[128];
    char description[256];
    double density;
} OCCTMaterialInfo;

/// Get the number of materials in a document.
/// @param doc The document to query
/// @return Number of materials, or 0 on failure
int32_t OCCTDocumentGetMaterialCount(OCCTDocumentRef doc);

/// Get material information by index.
/// @param doc The document to query
/// @param index Zero-based material index
/// @param outInfo Output material info structure
/// @return true if the material info was retrieved successfully
bool OCCTDocumentGetMaterialInfo(OCCTDocumentRef doc, int32_t index, OCCTMaterialInfo* outInfo);


// MARK: - Linear Rib Feature (v0.31.0)

/// Add a linear rib feature to a shape.
/// @param shape The base shape to add the rib to
/// @param profile The wire profile of the rib
/// @param dirX, dirY, dirZ Direction of the rib extrusion
/// @param dir1X, dir1Y, dir1Z Secondary direction (draft direction)
/// @param fuse true to fuse (add material), false to cut (remove material)
/// @return Shape with rib added, or NULL on failure
OCCTShapeRef OCCTShapeAddLinearRib(OCCTShapeRef shape, OCCTWireRef profile,
                                    double dirX, double dirY, double dirZ,
                                    double dir1X, double dir1Y, double dir1Z,
                                    bool fuse);


// MARK: - Asymmetric Chamfer (v0.32.0)

/// Chamfer specific edges with two different distances (asymmetric).
/// @param shape The shape to chamfer
/// @param edgeIndices Array of 0-based edge indices
/// @param faceIndices Array of 0-based face indices (one per edge, identifies reference face)
/// @param dist1 Array of first distances (measured on the reference face)
/// @param dist2 Array of second distances (measured on the other face)
/// @param count Number of edges to chamfer
/// @return Chamfered shape, or NULL on failure
OCCTShapeRef OCCTShapeChamferTwoDistances(OCCTShapeRef shape,
                                           const int32_t* edgeIndices,
                                           const int32_t* faceIndices,
                                           const double* dist1,
                                           const double* dist2,
                                           int32_t count);

/// Chamfer specific edges with distance + angle.
/// @param shape The shape to chamfer
/// @param edgeIndices Array of 0-based edge indices
/// @param faceIndices Array of 0-based face indices (one per edge, identifies reference face)
/// @param distances Array of distances (measured on the reference face)
/// @param anglesDeg Array of angles in degrees (must be between 0 and 90, exclusive)
/// @param count Number of edges to chamfer
/// @return Chamfered shape, or NULL on failure
OCCTShapeRef OCCTShapeChamferDistAngle(OCCTShapeRef shape,
                                        const int32_t* edgeIndices,
                                        const int32_t* faceIndices,
                                        const double* distances,
                                        const double* anglesDeg,
                                        int32_t count);


// MARK: - Loft Improvements (v0.32.0)

/// Create a lofted shape with ruled/smooth control and optional vertex endpoints.
/// @param profiles Array of wire profiles
/// @param profileCount Number of wire profiles
/// @param solid Whether to create a solid (true) or shell (false)
/// @param ruled Whether to use ruled surfaces (true) or smooth B-spline (false)
/// @param firstVertexX,Y,Z If not NaN, use as starting vertex (cone tip)
/// @param lastVertexX,Y,Z If not NaN, use as ending vertex (cone tip)
/// @return Lofted shape, or NULL on failure
OCCTShapeRef OCCTShapeCreateLoftAdvanced(const OCCTWireRef* profiles, int32_t profileCount,
                                          bool solid, bool ruled,
                                          double firstVertexX, double firstVertexY, double firstVertexZ,
                                          double lastVertexX, double lastVertexY, double lastVertexZ);


// MARK: - Offset with Join Type (v0.32.0)

/// Offset shape using the proper PerformByJoin algorithm.
/// @param shape The shape to offset
/// @param distance Offset distance (positive = outward, negative = inward)
/// @param tolerance Coincidence tolerance (typically 1e-7)
/// @param joinType Join type: 0=Arc (rounded gaps), 1=Tangent, 2=Intersection (sharp)
/// @param removeInternalEdges Whether to remove internal edges from result
/// @return Offset shape, or NULL on failure
OCCTShapeRef OCCTShapeOffsetByJoin(OCCTShapeRef shape, double distance,
                                    double tolerance, int32_t joinType,
                                    bool removeInternalEdges);


// MARK: - Revolution Form Feature (v0.32.0)

/// Add a revolution form (revolved rib/groove) to a shape.
/// @param shape The base shape
/// @param profile The wire profile of the rib
/// @param axOX,axOY,axOZ Origin of revolution axis
/// @param axDX,axDY,axDZ Direction of revolution axis
/// @param height1 Height on one side
/// @param height2 Height on the other side
/// @param fuse true for rib, false for groove
/// @return Shape with revolution form, or NULL on failure
OCCTShapeRef OCCTShapeAddRevolutionForm(OCCTShapeRef shape, OCCTWireRef profile,
                                         double axOX, double axOY, double axOZ,
                                         double axDX, double axDY, double axDZ,
                                         double height1, double height2,
                                         bool fuse);


// MARK: - Draft Prism Feature (v0.32.0)

/// Add a draft prism (tapered extrusion) to a shape, extruded to a given height.
/// @param shape The base shape
/// @param profileFace 0-based face index on shape to use as sketch/profile face
/// @param profile Wire profile to extrude
/// @param angleDeg Draft angle in degrees
/// @param height Extrusion height
/// @param fuse true to add material, false to cut
/// @return Shape with draft prism, or NULL on failure
OCCTShapeRef OCCTShapeDraftPrism(OCCTShapeRef shape, int32_t profileFace,
                                  OCCTWireRef profile, double angleDeg,
                                  double height, bool fuse);

/// Add a draft prism, extruded through the entire shape.
OCCTShapeRef OCCTShapeDraftPrismThruAll(OCCTShapeRef shape, int32_t profileFace,
                                         OCCTWireRef profile, double angleDeg,
                                         bool fuse);


// MARK: - Revolution Feature (v0.32.0)

/// Add a revolved feature (boss/pocket) to a shape, revolving to a given angle.
/// @param shape The base shape
/// @param profileFace 0-based face index on shape to use as sketch face
/// @param profile Wire profile to revolve
/// @param axOX,axOY,axOZ Origin of revolution axis
/// @param axDX,axDY,axDZ Direction of revolution axis
/// @param angleDeg Rotation angle in degrees
/// @param fuse true to add material, false to cut
/// @return Shape with revolved feature, or NULL on failure
OCCTShapeRef OCCTShapeRevolFeature(OCCTShapeRef shape, int32_t profileFace,
                                    OCCTWireRef profile,
                                    double axOX, double axOY, double axOZ,
                                    double axDX, double axDY, double axDZ,
                                    double angleDeg, bool fuse);

/// Add a revolved feature, revolving through 360 degrees.
OCCTShapeRef OCCTShapeRevolFeatureThruAll(OCCTShapeRef shape, int32_t profileFace,
                                           OCCTWireRef profile,
                                           double axOX, double axOY, double axOZ,
                                           double axDX, double axDY, double axDZ,
                                           bool fuse);


// MARK: - Evolved Shape Advanced (v0.33.0)

/// Create an evolved shape with full parameter control.
/// @param spine The spine shape (wire or face)
/// @param profile The profile wire
/// @param joinType Join type: 0=Arc, 1=Tangent, 2=Intersection
/// @param axeProf true if profile is in global coords, false for local
/// @param solid true to produce a solid
/// @param volume true for volume mode (remove self-intersections via BOPAlgo)
/// @param tolerance Tolerance for evolved shape creation
/// @return Evolved shape, or NULL on failure
OCCTShapeRef OCCTShapeCreateEvolvedAdvanced(OCCTShapeRef spine, OCCTWireRef profile,
                                             int32_t joinType, bool axeProf,
                                             bool solid, bool volume,
                                             double tolerance);


// MARK: - Pipe Shell with Transition Mode (v0.33.0)

/// Create a pipe shell with transition mode control.
/// @param spine The spine wire
/// @param profile The profile wire
/// @param mode Sweep mode: 0=Frenet, 1=CorrectedFrenet
/// @param transitionMode Transition: 0=Transformed, 1=RightCorner, 2=RoundCorner
/// @param solid true to produce a solid
/// @return Pipe shape, or NULL on failure
OCCTShapeRef OCCTShapeCreatePipeShellWithTransition(OCCTWireRef spine, OCCTWireRef profile,
                                                     int32_t mode, int32_t transitionMode,
                                                     bool solid);


// MARK: - Face from Surface with UV Bounds (v0.33.0)

/// Create a face from a surface with specific UV parameter bounds.
/// @param surface The surface to create a face from
/// @param uMin Minimum U parameter
/// @param uMax Maximum U parameter
/// @param vMin Minimum V parameter
/// @param vMax Maximum V parameter
/// @param tolerance Tolerance for face creation
/// @return Face shape, or NULL on failure
OCCTShapeRef OCCTShapeCreateFaceFromSurface(OCCTSurfaceRef surface,
                                             double uMin, double uMax,
                                             double vMin, double vMax,
                                             double tolerance);


// MARK: - Edges to Faces (v0.33.0)

/// Reconstruct faces from a compound of loose edges.
/// @param compound Shape containing edges
/// @param isOnlyPlane true to only create planar faces
/// @return Compound of faces, or NULL on failure
OCCTShapeRef OCCTShapeEdgesToFaces(OCCTShapeRef compound, bool isOnlyPlane);


// MARK: - Shape-to-Shape Section (v0.34.0)

/// Compute the intersection curves/edges between two shapes.
/// @param shape1 First shape
/// @param shape2 Second shape
/// @return Shape containing intersection edges/wires, or NULL on failure
OCCTShapeRef OCCTShapeSection(OCCTShapeRef shape1, OCCTShapeRef shape2);


// MARK: - Boolean Pre-Validation (v0.34.0)

/// Check whether shapes are valid for boolean operations.
/// @param shape1 First shape (argument)
/// @param shape2 Second shape (tool), may be NULL for self-check
/// @return true if shapes are valid for booleans
bool OCCTShapeBooleanCheck(OCCTShapeRef shape1, OCCTShapeRef shape2);


// MARK: - Split Shape by Wire (v0.34.0)

/// Split faces of a shape by imprinting a wire onto a face.
/// @param shape The shape to modify
/// @param wire The wire to imprint
/// @param faceIndex 0-based index of the face to split
/// @return Modified shape with split faces, or NULL on failure
OCCTShapeRef OCCTShapeSplitByWire(OCCTShapeRef shape, OCCTWireRef wire, int32_t faceIndex);


// MARK: - Split Shape by Angle (v0.34.0)

/// Split surfaces that span more than a specified angle.
/// Useful for export to systems that cannot handle full 360° surfaces.
/// @param shape The shape to split
/// @param maxAngleDegrees Maximum angle in degrees (e.g. 90 = quarter-turns)
/// @return Shape with split surfaces, or NULL on failure
OCCTShapeRef OCCTShapeSplitByAngle(OCCTShapeRef shape, double maxAngleDegrees);


// MARK: - Drop Small Edges (v0.34.0)

/// Remove degenerate/tiny edges from a shape.
/// @param shape The shape to clean
/// @param tolerance Tolerance for identifying small edges
/// @return Shape with small edges removed, or NULL on failure
OCCTShapeRef OCCTShapeDropSmallEdges(OCCTShapeRef shape, double tolerance);


// MARK: - Multi-Tool Boolean Fuse (v0.34.0)

/// Fuse multiple shapes simultaneously (more robust than sequential pairwise union).
/// @param shapes Array of shape references
/// @param count Number of shapes
/// @return Fused shape, or NULL on failure
OCCTShapeRef OCCTShapeFuseMulti(const OCCTShapeRef* shapes, int32_t count);


// MARK: - Multi-Offset Wire (v0.35.0)

/// Generate multiple parallel offset wires from a face boundary.
/// @param face A planar face whose outer wire defines the offset contour
/// @param offsets Array of offset distances (positive = outward, negative = inward)
/// @param count Number of offset distances
/// @param joinType Join type: 0=Arc, 1=Tangent, 2=Intersection
/// @param outWires Output array of wire refs (caller must release each)
/// @param maxWires Maximum number of output wires
/// @return Number of wires actually produced
int32_t OCCTWireMultiOffset(OCCTShapeRef face, const double* offsets, int32_t count,
                             int32_t joinType, OCCTWireRef* outWires, int32_t maxWires);


// MARK: - Surface-Surface Intersection (v0.35.0)

/// Compute intersection curves between two parametric surfaces.
/// @param surface1 First surface
/// @param surface2 Second surface
/// @param tolerance Tolerance
/// @param outCurves Output array of Curve3D refs (caller must release each)
/// @param maxCurves Maximum number of output curves
/// @return Number of intersection curves found
int32_t OCCTSurfaceSurfaceIntersect(OCCTSurfaceRef surface1, OCCTSurfaceRef surface2,
                                     double tolerance,
                                     OCCTCurve3DRef* outCurves, int32_t maxCurves);


// MARK: - Curve-Surface Intersection (v0.35.0)

/// Intersection result point for curve-surface intersection.
typedef struct {
    double x, y, z;    // 3D intersection point
    double u, v;       // Surface parameters at intersection
    double w;          // Curve parameter at intersection
} OCCTCurveSurfacePoint;

/// Compute intersection points between a curve and a surface.
/// @param curve The curve
/// @param surface The surface
/// @param outPoints Output array of intersection points
/// @param maxPoints Maximum number of output points
/// @return Number of intersection points found
int32_t OCCTCurveSurfaceIntersect(OCCTCurve3DRef curve, OCCTSurfaceRef surface,
                                   OCCTCurveSurfacePoint* outPoints, int32_t maxPoints);


// MARK: - Cylindrical Projection (v0.35.0)

/// Project a wire onto a shape along a direction (cylindrical projection).
/// @param wire Wire/edge to project
/// @param shape Target shape to project onto
/// @param dirX, dirY, dirZ Projection direction
/// @return Compound of projected wires, or NULL on failure
OCCTShapeRef OCCTShapeProjectWire(OCCTShapeRef wire, OCCTShapeRef shape,
                                   double dirX, double dirY, double dirZ);


// MARK: - Same Parameter (v0.35.0)

/// Enforce same-parameter consistency on a shape.
/// Ensures 3D and 2D curve representations are consistent.
/// @param shape The shape to fix
/// @param tolerance Tolerance for same-parameter check
/// @return Fixed shape, or NULL on failure
OCCTShapeRef OCCTShapeSameParameter(OCCTShapeRef shape, double tolerance);


// MARK: - Conical Projection (v0.36.0)

/// Project a wire onto a shape from a point (conical projection).
/// @param wire Wire/edge to project
/// @param shape Target shape to project onto
/// @param eyeX, eyeY, eyeZ Point of projection (eye/viewpoint)
/// @return Compound of projected wires, or NULL on failure
OCCTShapeRef OCCTShapeProjectWireConical(OCCTShapeRef wire, OCCTShapeRef shape,
                                          double eyeX, double eyeY, double eyeZ);


// MARK: - Encode Regularity (v0.36.0)

/// Mark smooth (G1) edges as "regular" so downstream algorithms can skip them.
/// @param shape The shape to process
/// @param toleranceAngleDegrees Angular tolerance for smoothness (degrees)
/// @return Shape with regularity encoded, or NULL on failure
OCCTShapeRef OCCTShapeEncodeRegularity(OCCTShapeRef shape, double toleranceAngleDegrees);


// MARK: - Update Tolerances (v0.36.0)

/// Recalculate and update geometric tolerances on a shape.
/// @param shape The shape to update
/// @param verifyFaceTolerance Whether to verify and correct face tolerances
/// @return Shape with updated tolerances, or NULL on failure
OCCTShapeRef OCCTShapeUpdateTolerances(OCCTShapeRef shape, bool verifyFaceTolerance);


// MARK: - Shape Divide by Number (v0.36.0)

/// Split faces of a shape into a specified number of patches in U and V.
/// @param shape The shape to divide
/// @param nbU Number of segments in U direction
/// @param nbV Number of segments in V direction
/// @return Shape with divided faces, or NULL on failure
OCCTShapeRef OCCTShapeDivideByNumber(OCCTShapeRef shape, int32_t nbU, int32_t nbV);


// MARK: - Surface to Bezier Patches (v0.36.0)

/// Convert a BSpline surface to an array of Bezier surface patches.
/// @param surface The BSpline surface
/// @param outPatches Output array of surface refs (caller must release each)
/// @param maxPatches Maximum number of output patches
/// @return Number of Bezier patches produced
int32_t OCCTSurfaceToBezierPatches(OCCTSurfaceRef surface,
                                    OCCTSurfaceRef* outPatches, int32_t maxPatches);


// MARK: - Boolean with Modified Shapes (v0.36.0)

/// Perform a boolean fuse and return modified shapes from shape1.
/// @param shape1 First shape (argument)
/// @param shape2 Second shape (tool)
/// @param outModified Output array for shapes in result that are modifications of shape1 faces
/// @param maxModified Maximum number of output shapes
/// @return Number of modified shapes found, or -1 on failure
int32_t OCCTShapeFuseWithHistory(OCCTShapeRef shape1, OCCTShapeRef shape2,
                                  OCCTShapeRef* outModified, int32_t maxModified);


// MARK: - Boolean with Full Per-Input History (issue #165)

/// Opaque handle to a boolean operation that retains its builder so
/// per-input-subshape history (Modified / Generated / IsDeleted) can be
/// queried after the operation completes. Free with OCCTBooleanHistoryRelease.
typedef struct OCCTBooleanHistory* OCCTBooleanHistoryRef;

/// Boolean union (s1 ∪ s2) with retained history.
/// @param outResult If non-null, set to the result shape on success (caller owns; free with OCCTShapeRelease).
/// @return History handle on success, NULL on failure.
OCCTBooleanHistoryRef _Nullable OCCTBooleanUnionWithHistory(OCCTShapeRef _Nonnull shape1,
                                                              OCCTShapeRef _Nonnull shape2,
                                                              OCCTShapeRef _Nullable * _Nullable outResult);

/// Boolean subtract (s1 \ s2) with retained history.
OCCTBooleanHistoryRef _Nullable OCCTBooleanSubtractWithHistory(OCCTShapeRef _Nonnull shape1,
                                                                 OCCTShapeRef _Nonnull shape2,
                                                                 OCCTShapeRef _Nullable * _Nullable outResult);

/// Boolean intersect (s1 ∩ s2) with retained history.
OCCTBooleanHistoryRef _Nullable OCCTBooleanIntersectWithHistory(OCCTShapeRef _Nonnull shape1,
                                                                  OCCTShapeRef _Nonnull shape2,
                                                                  OCCTShapeRef _Nullable * _Nullable outResult);

/// Split shape1 by shape2 (BRepAlgoAPI_Splitter). Result is a compound; use
/// OCCTShapeCompoundChildren to extract the pieces.
OCCTBooleanHistoryRef _Nullable OCCTBooleanSplitWithHistory(OCCTShapeRef _Nonnull shape1,
                                                              OCCTShapeRef _Nonnull shape2,
                                                              OCCTShapeRef _Nullable * _Nullable outResult);

/// Modified output sub-shapes for an input sub-shape. Returns count, fills outRefs (if non-null) up to maxCount.
/// Caller takes ownership of each OCCTShapeRef written.
int32_t OCCTBooleanHistoryModified(OCCTBooleanHistoryRef _Nonnull history,
                                     OCCTShapeRef _Nonnull inputSubShape,
                                     OCCTShapeRef _Nullable * _Nullable outRefs, int32_t maxCount);

/// Generated output sub-shapes for an input sub-shape (e.g. fillet faces generated FROM an edge).
int32_t OCCTBooleanHistoryGenerated(OCCTBooleanHistoryRef _Nonnull history,
                                      OCCTShapeRef _Nonnull inputSubShape,
                                      OCCTShapeRef _Nullable * _Nullable outRefs, int32_t maxCount);

/// True if the input sub-shape was deleted with no replacement.
bool OCCTBooleanHistoryIsDeleted(OCCTBooleanHistoryRef _Nonnull history,
                                   OCCTShapeRef _Nonnull inputSubShape);

void OCCTBooleanHistoryRelease(OCCTBooleanHistoryRef _Nonnull history);

/// Top-level children of a compound shape (TopoDS_Iterator). Returns count,
/// fills outRefs (if non-null) up to maxCount. Used to extract pieces from
/// BRepAlgoAPI_Splitter results. Caller takes ownership of each OCCTShapeRef.
int32_t OCCTShapeCompoundChildren(OCCTShapeRef _Nonnull compound,
                                    OCCTShapeRef _Nullable * _Nullable outRefs, int32_t maxCount);


// MARK: - Tier 2 modification ops with full per-input history (issue #165)

/// Uniform-radius fillet on the given edges, with retained history.
OCCTBooleanHistoryRef _Nullable OCCTShapeHistoryFromFilletEdges(OCCTShapeRef _Nonnull shape,
                                                                  const int32_t* _Nonnull edgeIndices,
                                                                  int32_t count,
                                                                  double radius,
                                                                  OCCTShapeRef _Nullable * _Nullable outResult);

/// Variable-radius fillet on a single edge (start radius linearly varies to end radius
/// along the edge's parameter range), with retained history.
OCCTBooleanHistoryRef _Nullable OCCTShapeHistoryFromFilletEdgeVariable(OCCTShapeRef _Nonnull shape,
                                                                         int32_t edgeIndex,
                                                                         double startRadius, double endRadius,
                                                                         OCCTShapeRef _Nullable * _Nullable outResult);

/// Uniform chamfer on the given edges, with retained history.
OCCTBooleanHistoryRef _Nullable OCCTShapeHistoryFromChamferEdges(OCCTShapeRef _Nonnull shape,
                                                                   const int32_t* _Nonnull edgeIndices,
                                                                   int32_t count,
                                                                   double distance,
                                                                   OCCTShapeRef _Nullable * _Nullable outResult);

/// Shell / thick-solid: remove given faces and offset inward by `thickness`, with retained history.
OCCTBooleanHistoryRef _Nullable OCCTShapeHistoryFromShell(OCCTShapeRef _Nonnull shape,
                                                            const int32_t* _Nonnull faceIndices,
                                                            int32_t faceCount,
                                                            double thickness, double tolerance,
                                                            OCCTShapeRef _Nullable * _Nullable outResult);

/// Defeature: remove given faces by smoothing surrounding topology, with retained history.
OCCTBooleanHistoryRef _Nullable OCCTShapeHistoryFromDefeature(OCCTShapeRef _Nonnull shape,
                                                                const int32_t* _Nonnull faceIndices,
                                                                int32_t faceCount,
                                                                OCCTShapeRef _Nullable * _Nullable outResult);


// MARK: - Thick Solid / Hollowing (v0.37.0)

/// Create a hollowed (thick) solid by removing faces and offsetting inward.
/// @param shape The solid to hollow
/// @param faceIndices 0-based indices of faces to remove (openings)
/// @param faceCount Number of faces to remove
/// @param offset Wall thickness (positive = inward)
/// @param tolerance Tolerance
/// @param joinType Join type: 0=Arc, 1=Tangent, 2=Intersection
/// @return Hollowed solid, or NULL on failure
OCCTShapeRef OCCTShapeMakeThickSolid(OCCTShapeRef shape, const int32_t* faceIndices,
                                      int32_t faceCount, double offset, double tolerance,
                                      int32_t joinType);


// MARK: - Wire Analysis (v0.37.0)

/// Result of wire topology analysis.
typedef struct {
    bool isClosed;
    bool hasSmallEdges;
    bool hasGaps3d;
    bool hasSelfIntersection;
    bool isOrdered;
    double minDistance3d;
    double maxDistance3d;
    int32_t edgeCount;
} OCCTWireAnalysisResult;

/// Analyze wire topology for potential issues.
/// @param wire The wire to analyze
/// @param tolerance Analysis tolerance
/// @param result Output analysis result
/// @return true if analysis completed
bool OCCTWireAnalyze(OCCTWireRef wire, double tolerance, OCCTWireAnalysisResult* result);


// MARK: - Surface Singularity Analysis (v0.37.0)

/// Check if a surface has singularities (poles/degenerate points).
/// @param surface The surface to check
/// @param tolerance Precision for singularity detection
/// @return Number of singularities found (0 = none)
int32_t OCCTSurfaceSingularityCount(OCCTSurfaceRef surface, double tolerance);

/// Check if a surface is degenerated at a given point.
/// @param surface The surface
/// @param x, y, z The 3D point to check
/// @param tolerance Precision
/// @return true if the point is at a degenerate region
bool OCCTSurfaceIsDegenerated(OCCTSurfaceRef surface, double x, double y, double z, double tolerance);


// MARK: - Shell from Surface (v0.37.0)

/// Create a shell from a parametric surface with UV bounds.
/// @param surface The surface
/// @param uMin, uMax, vMin, vMax UV parameter bounds
/// @return Shell shape, or NULL on failure
OCCTShapeRef OCCTShapeMakeShell(OCCTSurfaceRef surface,
                                 double uMin, double uMax,
                                 double vMin, double vMax);


// MARK: - Multi-Tool Boolean Common (v0.37.0)

/// Compute the common (intersection) of multiple shapes simultaneously.
/// @param shapes Array of shape references
/// @param count Number of shapes (must be >= 2)
/// @return Common shape (intersection of all), or NULL on failure
OCCTShapeRef OCCTShapeCommonMulti(const OCCTShapeRef* shapes, int32_t count);


// MARK: - Oriented Bounding Box (v0.38.0)

/// Oriented bounding box result
typedef struct {
    double centerX, centerY, centerZ;     // center point
    double xDirX, xDirY, xDirZ;          // X-axis direction
    double yDirX, yDirY, yDirZ;          // Y-axis direction
    double zDirX, zDirY, zDirZ;          // Z-axis direction
    double halfX, halfY, halfZ;           // half-dimensions along each axis
} OCCTOrientedBoundingBox;

/// Compute an oriented bounding box for a shape.
/// @param shape The shape to bound
/// @param optimal If true, compute tighter (but slower) OBB
/// @param result Output OBB structure
/// @return true on success
bool OCCTShapeOrientedBoundingBox(OCCTShapeRef shape, bool optimal, OCCTOrientedBoundingBox* result);

/// Get the volume of the oriented bounding box.
/// @param result Pointer to an OBB structure
/// @return Volume (8 * halfX * halfY * halfZ)
double OCCTOrientedBoundingBoxVolume(const OCCTOrientedBoundingBox* result);

/// Get the 8 corner points of the oriented bounding box.
/// @param result Pointer to an OBB structure
/// @param outCorners Output array of 24 doubles (8 corners * 3 coordinates)
void OCCTOrientedBoundingBoxCorners(const OCCTOrientedBoundingBox* result, double* outCorners);


// MARK: - Deep Shape Copy (v0.38.0)

/// Create a deep copy of a shape (independent geometry).
/// @param shape The shape to copy
/// @param copyGeom If true, copy geometry (otherwise share it)
/// @param copyMesh If true, also copy mesh data
/// @return New independent shape, or NULL on failure
OCCTShapeRef OCCTShapeCopy(OCCTShapeRef shape, bool copyGeom, bool copyMesh);


// MARK: - Sub-Shape Extraction (v0.38.0)

/// Get the number of solid sub-shapes in a shape.
int32_t OCCTShapeGetSolidCount(OCCTShapeRef shape);

/// Get solid sub-shapes from a shape.
/// @param shape The shape to explore
/// @param outSolids Output array for solid shape references
/// @param maxCount Maximum number of solids to return
/// @return Number of solids actually returned
int32_t OCCTShapeGetSolids(OCCTShapeRef shape, OCCTShapeRef* outSolids, int32_t maxCount);

/// Get the number of shell sub-shapes in a shape.
int32_t OCCTShapeGetShellCount(OCCTShapeRef shape);

/// Get shell sub-shapes from a shape.
/// @param shape The shape to explore
/// @param outShells Output array for shell shape references
/// @param maxCount Maximum number of shells to return
/// @return Number of shells actually returned
int32_t OCCTShapeGetShells(OCCTShapeRef shape, OCCTShapeRef* outShells, int32_t maxCount);

/// Get the number of wire sub-shapes in a shape.
int32_t OCCTShapeGetWireCount(OCCTShapeRef shape);

/// Get wire sub-shapes from a shape.
/// @param shape The shape to explore
/// @param outWires Output array for wire shape references (wrapped as OCCTShapeRef)
/// @param maxCount Maximum number of wires to return
/// @return Number of wires actually returned
int32_t OCCTShapeGetWires(OCCTShapeRef shape, OCCTShapeRef* outWires, int32_t maxCount);


// MARK: - Fuse and Blend (v0.38.0)

/// Fuse two shapes and fillet the intersection edges with the given radius.
/// @param shape1 First shape
/// @param shape2 Second shape
/// @param radius Fillet radius for intersection edges
/// @return Fused and filleted shape, or NULL on failure
OCCTShapeRef OCCTShapeFuseAndBlend(OCCTShapeRef shape1, OCCTShapeRef shape2, double radius);

/// Cut shape2 from shape1 and fillet the intersection edges with the given radius.
/// @param shape1 Base shape
/// @param shape2 Tool shape to cut
/// @param radius Fillet radius for intersection edges
/// @return Cut and filleted shape, or NULL on failure
OCCTShapeRef OCCTShapeCutAndBlend(OCCTShapeRef shape1, OCCTShapeRef shape2, double radius);


// MARK: - Multi-Edge Evolving Fillet (v0.38.0)

/// Parameter-radius pair for evolving fillets.
typedef struct {
    double parameter;
    double radius;
} OCCTFilletRadiusPoint;

/// Apply evolving-radius fillets to multiple edges simultaneously.
/// @param shape The shape
/// @param edgeIndices Array of 1-based edge indices
/// @param edgeCount Number of edges
/// @param radiusPoints Array of parameter-radius pairs per edge (flattened: edge0[rp0,rp1,...], edge1[rp0,...], ...)
/// @param pointCounts Array of how many radius points per edge
/// @return Filleted shape, or NULL on failure
OCCTShapeRef OCCTShapeFilletEvolving(OCCTShapeRef shape,
                                      const int32_t* edgeIndices, int32_t edgeCount,
                                      const OCCTFilletRadiusPoint* radiusPoints,
                                      const int32_t* pointCounts);


// MARK: - Per-Face Variable Offset (v0.38.0)

/// Offset a shape with per-face variable distances.
/// @param shape The shape to offset
/// @param defaultOffset Default offset distance for all faces
/// @param faceIndices Array of 1-based face indices with custom offsets
/// @param faceOffsets Array of offset values for those faces
/// @param faceCount Number of custom face offsets
/// @param tolerance Offset tolerance
/// @param joinType Join type (0=Arc, 1=Tangent, 2=Intersection)
/// @return Offset shape, or NULL on failure
OCCTShapeRef OCCTShapeOffsetPerFace(OCCTShapeRef shape, double defaultOffset,
                                     const int32_t* faceIndices, const double* faceOffsets,
                                     int32_t faceCount, double tolerance, int32_t joinType);


// MARK: - v0.39.0: Poly HLR, Free Bounds, Pipe Feature, Semi-Infinite Extrusion

/// Create a fast polygon-based HLR (hidden-line removal) drawing.
/// Uses the triangulation mesh rather than exact geometry — much faster but approximate.
/// The shape must have a triangulation (mesh); if not, it will be meshed at the given deflection.
/// @param shape The shape to project
/// @param dirX,dirY,dirZ View direction vector
/// @param projectionType 0=orthographic (perspective not yet supported for poly)
/// @param deflection Mesh deflection for triangulation (smaller = more accurate, default 0.01)
/// @return Drawing reference, or NULL on failure
OCCTDrawingRef OCCTDrawingCreatePoly(OCCTShapeRef shape,
                                      double dirX, double dirY, double dirZ,
                                      int32_t projectionType, double deflection);

/// Compute free boundary wires on a shape (open edges not shared by two faces).
/// Returns a compound of wire shapes representing the free boundaries.
/// @param shape The shape to analyze
/// @param sewingTolerance Tolerance for grouping free edges into wires
/// @param outClosedCount Number of closed free boundary wires (output)
/// @param outOpenCount Number of open free boundary wires (output)
/// @return Compound of free boundary wires, or NULL if none found
OCCTShapeRef OCCTShapeFreeBounds(OCCTShapeRef shape, double sewingTolerance,
                                  int32_t* outClosedCount, int32_t* outOpenCount);

/// Fix free boundary wires by closing gaps.
/// @param shape The shape whose free boundaries to fix
/// @param sewingTolerance Tolerance for sewing free edges
/// @param closingTolerance Maximum distance to close a gap
/// @param outFixedCount Number of wires that were fixed (output)
/// @return Fixed shape, or NULL on failure
OCCTShapeRef OCCTShapeFixFreeBounds(OCCTShapeRef shape, double sewingTolerance,
                                     double closingTolerance, int32_t* outFixedCount);

/// Create a pipe feature (protrusion or depression) by sweeping a profile along a spine.
/// The profile is swept along the spine wire and fused/cut with the base shape.
/// @param shape Base solid shape
/// @param profileFaceIndex Index (0-based) of the profile face to sweep
/// @param sketchFaceIndex Index (0-based) of the face on the base solid where the profile sits
/// @param spine Wire defining the sweep path
/// @param fuse 1 to add material (boss), 0 to remove (pocket)
/// @return Modified shape, or NULL on failure
OCCTShapeRef OCCTShapePipeFeature(OCCTShapeRef shape, int32_t profileFaceIndex,
                                   int32_t sketchFaceIndex, OCCTWireRef spine,
                                   int32_t fuse);

/// Create a pipe feature from a standalone profile shape swept along a spine.
/// @param baseShape Base solid shape
/// @param profileShape Profile shape (face or wire) to sweep
/// @param sketchFaceIndex Index (0-based) of the face on base where profile sits
/// @param spine Wire defining the sweep path
/// @param fuse 1 to add material (boss), 0 to remove (pocket)
/// @return Modified shape, or NULL on failure
OCCTShapeRef OCCTShapePipeFeatureFromProfile(OCCTShapeRef baseShape, OCCTShapeRef profileShape,
                                              int32_t sketchFaceIndex, OCCTWireRef spine,
                                              int32_t fuse);

/// Create a semi-infinite extrusion of a shape in a direction.
/// The shape is extruded infinitely in the given direction from its original position.
/// @param profile The profile shape (face, wire, or edge) to extrude
/// @param dirX,dirY,dirZ Direction of extrusion
/// @param semiInfinite If true, extrude in one direction only; if false, both directions (infinite)
/// @return Extruded shape, or NULL on failure
OCCTShapeRef OCCTShapeExtrudeSemiInfinite(OCCTShapeRef profile,
                                           double dirX, double dirY, double dirZ,
                                           bool semiInfinite);

/// Prism feature: extrude a profile until it reaches a target face.
/// Uses BRepFeat_MakePrism which is smarter than simple extrusion+boolean.
/// @param baseShape Base solid shape
/// @param profileShape Profile face to extrude
/// @param sketchFaceIndex Face on base where profile sits (0-based)
/// @param dirX,dirY,dirZ Extrusion direction
/// @param fuse 1=add material, 0=remove material
/// @param untilFaceIndex Face index (0-based) on base where extrusion stops (-1 for thru-all)
/// @return Modified shape, or NULL on failure
OCCTShapeRef OCCTShapePrismUntilFace(OCCTShapeRef baseShape, OCCTShapeRef profileShape,
                                      int32_t sketchFaceIndex,
                                      double dirX, double dirY, double dirZ,
                                      int32_t fuse, int32_t untilFaceIndex);

// MARK: - v0.40.0: Mass Properties, Geometry Conversion, Distance Analysis

/// Inertia properties result structure
typedef struct {
    double volume;
    double centerX, centerY, centerZ;
    /// Row-major 3x3 inertia matrix (Ixx, Ixy, Ixz, Iyx, Iyy, Iyz, Izx, Izy, Izz)
    double inertia[9];
    /// Principal moments of inertia
    double principalIx, principalIy, principalIz;
    /// Principal axes (3x3, row-major: axisX, axisY, axisZ)
    double principalAxes[9];
    bool hasSymmetryAxis;
    bool hasSymmetryPoint;
} OCCTInertiaProperties;

/// Compute volume-based inertia properties (volume, center of mass, inertia matrix)
bool OCCTShapeInertiaProperties(OCCTShapeRef shape, OCCTInertiaProperties* outProps);

/// Compute surface-area-based inertia properties
bool OCCTShapeSurfaceInertiaProperties(OCCTShapeRef shape, OCCTInertiaProperties* outProps);

// MARK: - Shape Axis Extraction (v0.137)

/// Axis record emitted by OCCTShapeRevolutionAxes / OCCTShapeSymmetryAxes.
/// kind: 1=cylinder, 2=cone, 3=sphere, 4=torus, 5=revolution, 6=extrusion, 7=symmetry
typedef struct {
    double originX, originY, originZ;
    double directionX, directionY, directionZ;
    double extentMin;       // along direction from origin (-inf as -DBL_MAX)
    double extentMax;       // +inf as DBL_MAX
    bool   hasExtent;
    int32_t kind;
} OCCTShapeAxis;

/// Collect revolution axes from all cylindrical/conical/toroidal/revolved faces in a shape.
/// Axes are deduplicated by origin+direction within the given tolerance. Returns count,
/// writes up to maxAxes entries into outAxes. Returns -1 on failure.
int32_t OCCTShapeRevolutionAxes(OCCTShapeRef _Nonnull shape,
                                 double tolerance,
                                 OCCTShapeAxis* _Nonnull outAxes,
                                 int32_t maxAxes);

/// Detect symmetry axes from principal moments of inertia — when two moments are nearly
/// equal (within fractionalTolerance of the larger), the third is a symmetry axis.
/// Returns count (0 for none, 1 for rotational symmetry, 3 for spherical symmetry).
int32_t OCCTShapeSymmetryAxes(OCCTShapeRef _Nonnull shape,
                               double fractionalTolerance,
                               OCCTShapeAxis* _Nonnull outAxes,
                               int32_t maxAxes);

/// Distance solution entry
typedef struct {
    double point1X, point1Y, point1Z;
    double point2X, point2Y, point2Z;
    double distance;
} OCCTDistanceSolution;

/// Compute all distance solutions between two shapes
/// @param outSolutions Pre-allocated array for results
/// @param maxSolutions Maximum number of solutions to return
/// @return Number of solutions found, -1 on failure
int32_t OCCTShapeAllDistanceSolutions(OCCTShapeRef shape1, OCCTShapeRef shape2,
                                       OCCTDistanceSolution* outSolutions, int32_t maxSolutions);

/// Check if one shape is fully inside another (inner solution)
/// @return 1 if inner, 0 if not inner, -1 on failure
int32_t OCCTShapeIsInnerDistance(OCCTShapeRef shape1, OCCTShapeRef shape2);

/// Distance solution detail: support type and parametric location.
/// supportType: 0=Vertex, 1=OnEdge, 2=InFace
typedef struct {
    int32_t supportType1;
    int32_t supportType2;
    double paramEdge1;   // parameter on edge (if supportType1 == 1)
    double paramEdge2;   // parameter on edge (if supportType2 == 1)
    double paramFaceU1;  // U parameter on face (if supportType1 == 2)
    double paramFaceV1;  // V parameter on face (if supportType1 == 2)
    double paramFaceU2;  // U parameter on face (if supportType2 == 2)
    double paramFaceV2;  // V parameter on face (if supportType2 == 2)
} OCCTDistanceSolutionDetail;

/// Get detailed parametric info for a distance solution.
/// @param solutionIndex 0-based solution index
/// @return true on success
bool OCCTShapeDistanceSolutionDetail(OCCTShapeRef _Nonnull shape1, OCCTShapeRef _Nonnull shape2,
    int32_t solutionIndex, OCCTDistanceSolutionDetail* _Nonnull outDetail);

/// Decompose a BSpline surface into Bezier patches
/// @param surface BSpline surface reference
/// @param outPatches Pre-allocated array of surface refs for output patches
/// @param maxPatches Maximum patches to return
/// @param outNbUPatches Number of patches in U direction
/// @param outNbVPatches Number of patches in V direction
/// @return Total number of patches, or -1 on failure
int32_t OCCTSurfaceBSplineToBezierPatches(OCCTSurfaceRef surface,
                                           OCCTSurfaceRef* outPatches, int32_t maxPatches,
                                           int32_t* outNbUPatches, int32_t* outNbVPatches);

/// Find continuity break parameters in a BSpline curve
/// @param curve3D BSpline curve reference
/// @param continuityOrder Minimum continuity to require (0=C0, 1=C1, 2=C2)
/// @param outParams Pre-allocated array for break parameters
/// @param maxParams Maximum number of parameters to return
/// @return Number of break parameters found, or -1 on failure
int32_t OCCTCurve3DBSplineKnotSplits(OCCTCurve3DRef curve3D, int32_t continuityOrder,
                                       double* outParams, int32_t maxParams);

/// Find the underlying geometric surface of a shape (wire, edge set) with options
/// @param shape Shape whose edges define a surface
/// @param tolerance Tolerance for surface detection
/// @param onlyPlane If true, only look for planar surfaces
/// @param outFound Set to true if a surface was found
/// @return Surface reference, or NULL if not found
OCCTSurfaceRef OCCTShapeFindSurfaceEx(OCCTShapeRef shape, double tolerance,
                                       bool onlyPlane, bool* outFound);

// MARK: - v0.41.0: Shape Surgery, Plane Detection, Geometry Conversion

/// Remove sub-shapes from a shape using BRepTools_ReShape
/// @param shape Base shape
/// @param subShapes Array of sub-shape handles to remove
/// @param count Number of sub-shapes to remove
/// @return Modified shape, or NULL on failure
OCCTShapeRef OCCTShapeRemoveSubShapes(OCCTShapeRef shape, OCCTShapeRef* subShapes, int32_t count);

/// Replace sub-shapes in a shape using BRepTools_ReShape
/// @param shape Base shape
/// @param oldShapes Array of old sub-shapes
/// @param newShapes Array of new sub-shapes (must match oldShapes count)
/// @param count Number of replacements
/// @return Modified shape, or NULL on failure
OCCTShapeRef OCCTShapeReplaceSubShapes(OCCTShapeRef shape,
                                        OCCTShapeRef* oldShapes, OCCTShapeRef* newShapes,
                                        int32_t count);

/// Find if a shape's edges lie in a plane
/// @param shape Shape to analyze
/// @param tolerance Tolerance for planarity check
/// @param outNormalX/Y/Z Plane normal (set if found)
/// @param outOriginX/Y/Z Plane origin (set if found)
/// @return true if a plane was found
bool OCCTShapeFindPlane(OCCTShapeRef shape, double tolerance,
                         double* outNormalX, double* outNormalY, double* outNormalZ,
                         double* outOriginX, double* outOriginY, double* outOriginZ);

/// Split closed (periodic) edges in a shape
/// @param shape Shape containing closed edges
/// @param nbSplitPoints Number of split points per closed edge (default 1)
/// @return Modified shape, or NULL on failure
OCCTShapeRef OCCTShapeDivideClosedEdges(OCCTShapeRef shape, int32_t nbSplitPoints);

/// Convert all surfaces in a shape to BSpline form
/// @param shape Shape to convert
/// @param extrusion Convert extrusion surfaces
/// @param revolution Convert revolution surfaces
/// @param offset Convert offset surfaces
/// @param plane Convert planar surfaces
/// @return Converted shape, or NULL on failure
OCCTShapeRef OCCTShapeCustomConvertToBSpline(OCCTShapeRef shape,
                                              bool extrusion, bool revolution,
                                              bool offset, bool plane);

/// Convert surfaces in a shape to revolution form
/// @param shape Shape to convert
/// @return Converted shape, or NULL on failure
OCCTShapeRef OCCTShapeCustomConvertToRevolution(OCCTShapeRef shape);

/// Build restricted faces from a surface and wire boundaries
/// @param faceShape Face providing the underlying surface
/// @param wires Array of wire handles for boundaries
/// @param wireCount Number of wires
/// @param outFaces Pre-allocated array for result faces
/// @param maxFaces Maximum faces to return
/// @return Number of faces created, or -1 on failure
int32_t OCCTShapeFaceRestrict(OCCTShapeRef faceShape,
                               OCCTWireRef* wires, int32_t wireCount,
                               OCCTShapeRef* outFaces, int32_t maxFaces);

// MARK: - v0.42.0: Solid Construction, Fast Polygon, 2D Fillet, Point Cloud Analysis

/// Create a solid from one or more shell shapes
/// @param shells Array of shell shapes (first is outer, rest are cavities)
/// @param count Number of shells
/// @return Solid shape, or NULL on failure
OCCTShapeRef OCCTSolidFromShells(OCCTShapeRef* shells, int32_t count);

/// Create a polygon wire from 3D points (fast, rectilinear edges)
/// @param coords Flat array of x,y,z coordinates
/// @param pointCount Number of points
/// @param closed Whether to close the polygon
/// @return Wire handle, or NULL on failure
OCCTWireRef OCCTWireCreateFastPolygon(const double* coords, int32_t pointCount, bool closed);

/// Add a 2D fillet to a planar face at specified vertex indices
/// @param shape Face shape to fillet
/// @param vertexIndices Array of 0-based vertex indices
/// @param radii Array of fillet radii (one per vertex)
/// @param count Number of fillets to add
/// @return Filleted face shape, or NULL on failure
OCCTShapeRef OCCTFace2DFillet(OCCTShapeRef shape, const int32_t* vertexIndices,
                               const double* radii, int32_t count);

/// Add a 2D chamfer to a planar face between adjacent edges
/// @param shape Face shape to chamfer
/// @param edge1Indices Array of first edge indices (0-based)
/// @param edge2Indices Array of second edge indices (0-based)
/// @param distances Array of chamfer distances
/// @param count Number of chamfers to add
/// @return Chamfered face shape, or NULL on failure
OCCTShapeRef OCCTFace2DChamfer(OCCTShapeRef shape,
                                const int32_t* edge1Indices, const int32_t* edge2Indices,
                                const double* distances, int32_t count);

/// Point cloud geometry analysis result
typedef struct {
    int32_t type; // 0=point, 1=linear, 2=planar, 3=space
    double pointX, pointY, pointZ;        // Mean/centroid point
    double dirX, dirY, dirZ;              // Line direction (if linear)
    double normalX, normalY, normalZ;     // Plane normal (if planar)
} OCCTPointCloudGeometry;

/// Analyze a point cloud to determine if points are coincident, collinear, coplanar, or 3D
/// @param coords Flat array of x,y,z coordinates
/// @param pointCount Number of points
/// @param tolerance Tolerance for degeneracy detection
/// @param outResult Result structure
/// @return true on success
bool OCCTAnalyzePointCloud(const double* coords, int32_t pointCount,
                            double tolerance, OCCTPointCloudGeometry* outResult);

// MARK: - Sub-Shape Extraction (fixes #36)

/// Count sub-shapes of a given topological type
/// @param shape The parent shape
/// @param type TopAbs_ShapeEnum value (0=COMPOUND..7=VERTEX)
/// @return Number of sub-shapes of that type
int32_t OCCTShapeGetSubShapeCount(OCCTShapeRef shape, int32_t type);

/// Get a sub-shape by type and 0-based index
/// @param shape The parent shape
/// @param type TopAbs_ShapeEnum value
/// @param index 0-based index
/// @return Sub-shape as OCCTShapeRef, or NULL if out of range
OCCTShapeRef OCCTShapeGetSubShapeByTypeIndex(OCCTShapeRef shape, int32_t type, int32_t index);

// MARK: - v0.43.0: Face Subdivision, Small Face Detection, BSpline Fill, Location Purge

/// Subdivide faces of a shape whose area exceeds a maximum threshold
/// @param shape Input shape
/// @param maxArea Maximum face area (faces larger than this get split)
/// @return Subdivided shape, or NULL on failure
OCCTShapeRef OCCTShapeDivideByArea(OCCTShapeRef shape, double maxArea);

/// Subdivide faces into a target number of parts per face
/// @param shape Input shape
/// @param nbParts Target number of parts per face
/// @return Subdivided shape, or NULL on failure
OCCTShapeRef OCCTShapeDivideByParts(OCCTShapeRef shape, int32_t nbParts);

/// Small face analysis result for a single face
typedef struct {
    bool isSpotFace;      // Face collapsed to a point
    bool isStripFace;     // Face has negligible width
    bool isTwisted;       // Face is twisted
    double spotX, spotY, spotZ;   // Spot face location (if isSpotFace)
} OCCTSmallFaceResult;

/// Check a shape's faces for small/degenerate conditions
/// @param shape Shape to analyze
/// @param tolerance Analysis tolerance
/// @param outResults Array to receive per-face results
/// @param maxResults Maximum number of results
/// @return Number of degenerate faces found (results written to outResults)
int32_t OCCTShapeCheckSmallFaces(OCCTShapeRef shape, double tolerance,
                                  OCCTSmallFaceResult* outResults, int32_t maxResults);

/// Create a BSpline surface from 2 boundary curves (Stretch/Coons/Curved fill)
/// @param curve1 First boundary curve (OCCTCurve3DRef)
/// @param curve2 Second boundary curve
/// @param fillStyle 0=Stretch, 1=Coons, 2=Curved
/// @return Surface handle, or NULL on failure
OCCTSurfaceRef OCCTSurfaceFillBSpline2Curves(OCCTCurve3DRef curve1, OCCTCurve3DRef curve2,
                                               int32_t fillStyle);

/// Create a BSpline surface from 4 boundary curves
/// @param c1,c2,c3,c4 Boundary curves in order
/// @param fillStyle 0=Stretch, 1=Coons, 2=Curved
/// @return Surface handle, or NULL on failure
OCCTSurfaceRef OCCTSurfaceFillBSpline4Curves(OCCTCurve3DRef c1, OCCTCurve3DRef c2,
                                               OCCTCurve3DRef c3, OCCTCurve3DRef c4,
                                               int32_t fillStyle);

/// Purge problematic location datums from a shape
/// Removes negative-scale and non-unit-scale transforms from sub-shapes
/// @param shape Input shape
/// @return Purged shape, or NULL if nothing to purge
OCCTShapeRef OCCTShapePurgeLocations(OCCTShapeRef shape);

// MARK: - v0.44.0: Surface Extrema, Curve-on-Surface Check, Ellipse Arc, Edge Connect, Bezier Convert

/// Surface-to-surface extrema result
typedef struct {
    double distance;
    double p1X, p1Y, p1Z;  // Nearest point on surface 1
    double p2X, p2Y, p2Z;  // Nearest point on surface 2
    double u1, v1, u2, v2;  // UV parameters on each surface
} OCCTSurfaceExtremaResult;

/// Compute min distance between two surfaces
/// @param s1, s2 Surface handles
/// @param u1Min..v2Max UV bounds for each surface
/// @param outResult Result structure for the minimum distance
/// @return Number of extrema found, or 0 on failure
int32_t OCCTSurfaceExtrema(OCCTSurfaceRef s1, OCCTSurfaceRef s2,
                            double u1Min, double u1Max, double v1Min, double v1Max,
                            double u2Min, double u2Max, double v2Min, double v2Max,
                            OCCTSurfaceExtremaResult* outResult);

/// Check edge-on-surface consistency (max deviation between 3D curve and pcurve)
/// @param shape Shape containing edges and faces
/// @param outMaxDist Maximum distance found across all edge-face pairs
/// @param outMaxParam Parameter at maximum distance
/// @return true if check completed successfully
bool OCCTShapeCheckCurveOnSurface(OCCTShapeRef shape, double* outMaxDist, double* outMaxParam);

/// Create a 3D elliptical arc from angles
/// @param centerX..centerZ Center of the ellipse
/// @param normalX..normalZ Normal direction of the ellipse plane
/// @param majorRadius Major radius
/// @param minorRadius Minor radius
/// @param angle1, angle2 Start and end angles (radians)
/// @param sense true=counterclockwise
/// @return Curve3D handle, or NULL on failure
OCCTCurve3DRef OCCTCurve3DArcOfEllipse(double centerX, double centerY, double centerZ,
                                         double normalX, double normalY, double normalZ,
                                         double majorRadius, double minorRadius,
                                         double angle1, double angle2, bool sense);

/// Create a 3D elliptical arc between two points on the ellipse
/// @return Curve3D handle, or NULL on failure
OCCTCurve3DRef OCCTCurve3DArcOfEllipsePoints(double centerX, double centerY, double centerZ,
                                               double normalX, double normalY, double normalZ,
                                               double majorRadius, double minorRadius,
                                               double p1X, double p1Y, double p1Z,
                                               double p2X, double p2Y, double p2Z, bool sense);

/// Connect edges by merging shared vertices in a shape
/// @param shape Shape to process
/// @return Shape with connected edges, or NULL on failure
OCCTShapeRef OCCTShapeConnectEdges(OCCTShapeRef shape);

/// Convert all curves and surfaces in a shape to Bezier representations
/// @param shape Input shape
/// @return Converted shape, or NULL on failure
OCCTShapeRef OCCTShapeConvertToBezier(OCCTShapeRef shape);

// MARK: - v0.45.0: BRepFill_Filling, BRepExtrema_SelfIntersection, BRepGProp_Face, ShapeAnalysis_WireOrder

/// N-side surface filling: create a face from boundary edges and optional point constraints.
/// Call OCCTFillingCreate, add edges/points, then Build, get face, and Release.
typedef struct OCCTFilling* OCCTFillingRef;

/// Create a filling surface builder with specified degree and number of points.
/// @param degree Target polynomial degree (default 3)
/// @param nbPtsOnCur Number of discretization points on each constraint curve (default 15)
/// @param maxDegree Maximum polynomial degree (default 8)
/// @param maxSegments Maximum number of segments (default 9)
/// @param tolerance3d 3D tolerance (default 1e-4)
/// @return Filling handle
OCCTFillingRef OCCTFillingCreate(int32_t degree, int32_t nbPtsOnCur, int32_t maxDegree,
                                  int32_t maxSegments, double tolerance3d);

/// Release a filling surface builder.
void OCCTFillingRelease(OCCTFillingRef filling);

/// Add a boundary edge constraint.
/// @param filling Filling handle
/// @param edge Edge to add as constraint
/// @param continuity Continuity order: 0=C0, 1=C1, 2=C2
/// @return true if edge was added
bool OCCTFillingAddEdge(OCCTFillingRef filling, OCCTEdgeRef edge, int32_t continuity);

/// Add a free boundary edge constraint (not required to be connected to other edges).
/// @param filling Filling handle
/// @param edge Edge to add
/// @param continuity Continuity order: 0=C0, 1=C1, 2=C2
/// @return true if edge was added
bool OCCTFillingAddFreeEdge(OCCTFillingRef filling, OCCTEdgeRef edge, int32_t continuity);

/// Add a point constraint that the filling surface must pass through.
/// @param filling Filling handle
/// @param x, y, z Point coordinates
/// @return true if point was added
bool OCCTFillingAddPoint(OCCTFillingRef filling, double x, double y, double z);

/// Build the filling surface.
/// @param filling Filling handle
/// @return true if build succeeded
bool OCCTFillingBuild(OCCTFillingRef filling);

/// Check if the filling surface was built successfully.
/// @param filling Filling handle
/// @return true if done
bool OCCTFillingIsDone(OCCTFillingRef filling);

/// Get the resulting face from a successful build.
/// @param filling Filling handle
/// @return Face shape, or NULL if not built
OCCTShapeRef OCCTFillingGetFace(OCCTFillingRef filling);

/// Get the G0 (positional) error of the filling surface.
/// @param filling Filling handle
/// @return G0 error value, or -1 on error
double OCCTFillingG0Error(OCCTFillingRef filling);

/// Get the G1 (tangent) error of the filling surface.
/// @param filling Filling handle
/// @return G1 error value, or -1 on error
double OCCTFillingG1Error(OCCTFillingRef filling);

/// Get the G2 (curvature) error of the filling surface.
/// @param filling Filling handle
/// @return G2 error value, or -1 on error
double OCCTFillingG2Error(OCCTFillingRef filling);

// --- BRepExtrema_SelfIntersection ---

/// Result of self-intersection check
typedef struct {
    int32_t overlapCount;    ///< Number of overlapping triangle pairs
    bool isDone;             ///< Whether the check completed
} OCCTSelfIntersectionResult;

/// Check a shape for self-intersection using BVH-accelerated triangle mesh overlap.
/// The shape should be meshed first (will be auto-meshed if not).
/// @param shape Shape to check
/// @param tolerance Tolerance for detecting intersections
/// @param meshDeflection Mesh deflection for auto-meshing (default 0.5)
/// @return Self-intersection result
OCCTSelfIntersectionResult OCCTShapeSelfIntersection(OCCTShapeRef shape, double tolerance,
                                                      double meshDeflection);

// --- BRepGProp_Face ---

/// Get the natural bounds of a face using BRepGProp_Face.
/// Unlike OCCTFaceGetUVBounds (BRepTools::UVBounds), this uses BRepGProp_Face::Bounds
/// which accounts for face orientation and provides parametric integration bounds.
/// @param face Face to query
/// @param uMin, uMax, vMin, vMax Output UV bounds
/// @return true on success
bool OCCTFaceGetNaturalBounds(OCCTFaceRef face, double* uMin, double* uMax,
                               double* vMin, double* vMax);

/// Evaluate a face at UV using BRepGProp_Face::Normal, returning point and unnormalized normal.
/// Unlike OCCTFaceGetNormalAtUV which normalizes, this returns the raw cross product of
/// partial derivatives (dS/du x dS/dv), whose magnitude equals the local area element.
/// @param face Face to evaluate
/// @param u, v UV parameters
/// @param px, py, pz Output 3D point coordinates
/// @param nx, ny, nz Output surface normal (unnormalized, magnitude = area element)
/// @return true on success
bool OCCTFaceEvaluateNormalAtUV(OCCTFaceRef face, double u, double v,
                                 double* px, double* py, double* pz,
                                 double* nx, double* ny, double* nz);

// --- ShapeAnalysis_WireOrder ---

/// Wire ordering result entry
typedef struct {
    int32_t originalIndex;  ///< Original edge index (1-based, negative if reversed)
} OCCTWireOrderEntry;

/// Result of wire ordering analysis
typedef struct {
    int32_t status;         ///< 0=closed, 1=open, 2=gaps, -1=failed
    int32_t nbEdges;        ///< Number of edges in the order
} OCCTWireOrderResult;

/// Analyze the ordering of edges to form connected chains.
/// Edges are specified by their start/end 3D points.
/// @param starts Array of start points (x,y,z triples)
/// @param ends Array of end points (x,y,z triples)
/// @param nbEdges Number of edges
/// @param tolerance Connection tolerance
/// @param outOrder Output array for ordered edge indices (must hold nbEdges entries)
/// @return Wire order result (status and count)
OCCTWireOrderResult OCCTWireOrderAnalyze(const double* starts, const double* ends,
                                          int32_t nbEdges, double tolerance,
                                          OCCTWireOrderEntry* outOrder);

/// Analyze the ordering of edges from a wire shape.
/// @param wire Wire to analyze
/// @param tolerance Connection tolerance
/// @param outOrder Output array for ordered edge indices (must hold enough entries)
/// @param maxEntries Maximum entries in outOrder
/// @return Wire order result
OCCTWireOrderResult OCCTWireOrderAnalyzeWire(OCCTWireRef wire, double tolerance,
                                              OCCTWireOrderEntry* outOrder, int32_t maxEntries);

// MARK: - v0.46.0: BRepOffset_Analyse, Approx_Curve3d, LocOpe_Prism, Volume Inertia

// --- BRepOffset_Analyse: Edge convexity classification ---

/// Edge concavity type from BRepOffset_Analyse
typedef enum {
    OCCTConcavityConvex = 0,
    OCCTConcavityConcave = 1,
    OCCTConcavityTangent = 2
} OCCTConcavityType;

/// Result for a single edge classification
typedef struct {
    OCCTConcavityType type;
} OCCTEdgeConcavity;

/// Analyze edge convexity/concavity in a shape.
/// @param shape Shape to analyze
/// @param angle Threshold angle for tangent classification (radians)
/// @param outEdgeTypes Output array of edge concavity types (must hold shapeEdgeCount entries)
/// @param maxEntries Maximum entries in output array
/// @return Number of edges classified, or -1 on error
int32_t OCCTShapeAnalyzeEdgeConcavity(OCCTShapeRef shape, double angle,
                                       OCCTEdgeConcavity* outEdgeTypes, int32_t maxEntries);

/// Count edges of a specific concavity type in a shape.
/// @param shape Shape to analyze
/// @param angle Threshold angle for tangent classification
/// @param type Concavity type to count (0=convex, 1=concave, 2=tangent)
/// @return Number of edges of that type, or -1 on error
int32_t OCCTShapeCountEdgeConcavity(OCCTShapeRef shape, double angle, int32_t type);

// --- Approx_Curve3d: Curve approximation to BSpline ---

/// Approximate an edge's curve as a BSpline curve.
/// @param edge Edge whose curve to approximate
/// @param tolerance Approximation tolerance
/// @param maxSegments Maximum number of BSpline segments
/// @param maxDegree Maximum BSpline degree
/// @return New Curve3D handle (BSpline), or NULL on failure
OCCTCurve3DRef OCCTEdgeApproxCurve(OCCTEdgeRef edge, double tolerance,
                                     int32_t maxSegments, int32_t maxDegree);

/// Get the approximation error of the last edge curve approximation.
/// @param edge Edge whose curve was approximated
/// @param tolerance Approximation tolerance
/// @param maxSegments Maximum number of BSpline segments
/// @param maxDegree Maximum BSpline degree
/// @param outMaxError Output: maximum approximation error
/// @param outDegree Output: BSpline degree
/// @param outNbPoles Output: number of BSpline poles (control points)
/// @return true if approximation succeeded
bool OCCTEdgeApproxCurveInfo(OCCTEdgeRef edge, double tolerance,
                              int32_t maxSegments, int32_t maxDegree,
                              double* outMaxError, int32_t* outDegree, int32_t* outNbPoles);

// --- LocOpe_Prism: Local prism with shape tracking ---

/// Create a local prism (extrusion) from a face along a direction vector.
/// Tracks generated shapes for each input sub-shape.
/// @param face Face to extrude
/// @param dx, dy, dz Direction vector
/// @return Shape result, or NULL on failure
OCCTShapeRef OCCTLocOpePrism(OCCTShapeRef face, double dx, double dy, double dz);

/// Create a local prism with a secondary translation vector.
/// @param face Face to extrude
/// @param dx, dy, dz Primary direction vector
/// @param tx, ty, tz Secondary translation vector
/// @return Shape result, or NULL on failure
OCCTShapeRef OCCTLocOpePrismWithTranslation(OCCTShapeRef face,
                                             double dx, double dy, double dz,
                                             double tx, double ty, double tz);

// --- Volume Inertia Properties ---

/// Result of volume inertia analysis
typedef struct {
    double volume;             ///< Volume (mass)
    double centerX, centerY, centerZ;  ///< Center of mass

    /// Matrix of inertia (3x3, row-major, about center of mass)
    double inertia[9];

    /// Principal moments of inertia
    double principalMoment1, principalMoment2, principalMoment3;

    /// Principal axes of inertia (3 unit vectors)
    double axis1X, axis1Y, axis1Z;
    double axis2X, axis2Y, axis2Z;
    double axis3X, axis3Y, axis3Z;

    /// Gyration radii
    double gyrationRadius1, gyrationRadius2, gyrationRadius3;
} OCCTVolumeInertiaResult;

/// Compute volume inertia properties of a shape.
/// Returns volume, center of mass, inertia tensor, principal moments/axes.
/// @param shape Shape to analyze
/// @param result Output inertia result
/// @return true on success
bool OCCTShapeVolumeInertia(OCCTShapeRef shape, OCCTVolumeInertiaResult* result);

/// Surface inertia result (for area properties)
typedef struct {
    double area;
    double centerX, centerY, centerZ;
    double inertia[9];
    double principalMoment1, principalMoment2, principalMoment3;
} OCCTSurfaceInertiaResult;

/// Compute surface (area) inertia properties of a shape.
/// @param shape Shape to analyze
/// @param result Output inertia result
/// @return true on success
bool OCCTShapeSurfaceInertia(OCCTShapeRef shape, OCCTSurfaceInertiaResult* result);

// MARK: - v0.47.0: LocOpe_Revol, LocOpe_DPrism, GeomFill_ConstrainedFilling, BRepCheck

// --- LocOpe_Revol: Local revolution with shape tracking ---

/// Create a revolved shape from a profile face around an axis.
/// Uses default constructor + Perform pattern.
/// @param profile Face to revolve
/// @param axisOriginX,Y,Z Origin point of rotation axis
/// @param axisDirX,Y,Z Direction of rotation axis
/// @param angle Rotation angle in radians
/// @return Revolved shape, or NULL on failure
OCCTShapeRef OCCTLocOpeRevol(OCCTShapeRef profile,
                              double axisOriginX, double axisOriginY, double axisOriginZ,
                              double axisDirX, double axisDirY, double axisDirZ,
                              double angle);

/// Create a revolved shape with angular offset for positioning.
/// @param profile Face to revolve
/// @param axisOriginX,Y,Z Origin of rotation axis
/// @param axisDirX,Y,Z Direction of rotation axis
/// @param angle Rotation angle in radians
/// @param angledec Angular offset in radians
/// @return Revolved shape, or NULL on failure
OCCTShapeRef OCCTLocOpeRevolWithOffset(OCCTShapeRef profile,
                                        double axisOriginX, double axisOriginY, double axisOriginZ,
                                        double axisDirX, double axisDirY, double axisDirZ,
                                        double angle, double angledec);

// --- LocOpe_DPrism: Draft prism (tapered extrusion) ---

/// Create a draft prism with two heights and a draft angle.
/// @param spineFace Face defining the prism spine
/// @param height1 First height
/// @param height2 Second height
/// @param angle Draft angle in radians
/// @return Draft prism shape, or NULL on failure
OCCTShapeRef OCCTLocOpeDPrism(OCCTFaceRef spineFace,
                               double height1, double height2, double angle);

/// Create a draft prism with single height and draft angle.
/// @param spineFace Face defining the prism spine
/// @param height Height
/// @param angle Draft angle in radians
/// @return Draft prism shape, or NULL on failure
OCCTShapeRef OCCTLocOpeDPrismSingleHeight(OCCTFaceRef spineFace,
                                            double height, double angle);

// --- GeomFill_ConstrainedFilling: BSpline surface from boundary curves ---

/// Result of constrained filling
typedef struct {
    bool isValid;
    int32_t uDegree;
    int32_t vDegree;
    int32_t uPoles;
    int32_t vPoles;
} OCCTConstrainedFillingInfo;

/// Create a BSpline surface by filling a region bounded by 3 or 4 curves.
/// Curves are specified as edges; the function extracts their geometric curves.
/// @param edge1,edge2,edge3 Three boundary edges (required)
/// @param edge4 Fourth boundary edge (optional, pass NULL for 3-sided fill)
/// @param maxDeg Maximum degree of the resulting surface
/// @param maxSeg Maximum number of segments
/// @return Face built on the filled surface, or NULL on failure
OCCTShapeRef OCCTGeomFillConstrained(OCCTEdgeRef edge1, OCCTEdgeRef edge2,
                                      OCCTEdgeRef edge3, OCCTEdgeRef edge4,
                                      int32_t maxDeg, int32_t maxSeg);

/// Get information about a constrained filling result surface.
/// @param face Face from constrained filling
/// @param info Output info struct
/// @return true on success
bool OCCTGeomFillConstrainedInfo(OCCTShapeRef face, OCCTConstrainedFillingInfo* info);

// --- BRepCheck: Shape validity checking ---

/// Shape validity status codes (maps to BRepCheck_Status)
typedef enum {
    OCCTCheckNoError = 0,
    OCCTCheckInvalidPointOnCurve = 1,
    OCCTCheckInvalidPointOnCurveOnSurface = 2,
    OCCTCheckInvalidPointOnSurface = 3,
    OCCTCheckNo3DCurve = 4,
    OCCTCheckMultiple3DCurve = 5,
    OCCTCheckInvalid3DCurve = 6,
    OCCTCheckNoCurveOnSurface = 7,
    OCCTCheckInvalidCurveOnSurface = 8,
    OCCTCheckInvalidCurveOnClosedSurface = 9,
    OCCTCheckInvalidSameRangeFlag = 10,
    OCCTCheckInvalidSameParameterFlag = 11,
    OCCTCheckInvalidDegeneratedFlag = 12,
    OCCTCheckFreeEdge = 13,
    OCCTCheckInvalidMultiConnexity = 14,
    OCCTCheckInvalidRange = 15,
    OCCTCheckEmptyWire = 16,
    OCCTCheckRedundantEdge = 17,
    OCCTCheckSelfIntersectingWire = 18,
    OCCTCheckNoSurface = 19,
    OCCTCheckInvalidWire = 20,
    OCCTCheckRedundantWire = 21,
    OCCTCheckIntersectingWires = 22,
    OCCTCheckInvalidImbricationOfWires = 23,
    OCCTCheckEmptyShell = 24,
    OCCTCheckRedundantFace = 25,
    OCCTCheckInvalidImbricationOfShells = 26,
    OCCTCheckUnorientableShape = 27,
    OCCTCheckNotClosed = 28,
    OCCTCheckNotConnected = 29,
    OCCTCheckSubshapeNotInShape = 30,
    OCCTCheckBadOrientation = 31,
    OCCTCheckBadOrientationOfSubshape = 32,
    OCCTCheckInvalidPolygonOnTriangulation = 33,
    OCCTCheckInvalidToleranceValue = 34,
    OCCTCheckEnclosedRegion = 35,
    OCCTCheckCheckFail = 36
} OCCTCheckStatus;

/// Result of shape validity check
typedef struct {
    bool isValid;           ///< True if no errors found
    int32_t errorCount;     ///< Number of errors
    OCCTCheckStatus firstError;  ///< First error code (if any)
} OCCTShapeCheckResult;

/// Check validity of a face.
/// @param face Face to check
/// @return Check result
OCCTShapeCheckResult OCCTCheckFace(OCCTFaceRef face);

/// Check validity of a solid.
/// @param shape Solid shape to check
/// @return Check result
OCCTShapeCheckResult OCCTCheckSolid(OCCTShapeRef shape);

/// Check overall validity of any shape (comprehensive check).
/// Uses BRepCheck_Analyzer for full topology + geometry validation.
/// @param shape Shape to check
/// @return Check result
OCCTShapeCheckResult OCCTCheckShape(OCCTShapeRef shape);

/// Get detailed check status codes for a shape.
/// @param shape Shape to analyze
/// @param outStatuses Output array of status codes
/// @param maxStatuses Max entries in output
/// @return Number of status entries written
int32_t OCCTCheckShapeDetailed(OCCTShapeRef shape, OCCTCheckStatus* outStatuses, int32_t maxStatuses);

// MARK: - v0.48.0: Comprehensive Local Operations, Validation, Fixing, Extrema

// --- LocOpe_Pipe ---

/// Perform a pipe sweep of a profile along a wire spine with shape tracking.
/// @param shape Profile shape (face) to sweep
/// @param spineWire Wire shape to use as spine
/// @return Result swept shape, or NULL on failure
OCCTShapeRef _Nullable OCCTLocOpePipe(OCCTShapeRef shape, OCCTShapeRef spineWire);

// --- LocOpe_LinearForm ---

/// Perform a linear form (translation sweep) with shape tracking.
/// @param shape Base shape (face) to sweep
/// @param dx,dy,dz Direction vector
/// @param p1x,p1y,p1z Start point
/// @param p2x,p2y,p2z End point
/// @return Result shape, or NULL on failure
OCCTShapeRef _Nullable OCCTLocOpeLinearForm(OCCTShapeRef shape,
                                             double dx, double dy, double dz,
                                             double p1x, double p1y, double p1z,
                                             double p2x, double p2y, double p2z);

// --- LocOpe_RevolutionForm ---

/// Perform a revolution form with shape tracking.
/// @param shape Base shape (face) to revolve
/// @param axisOriginX,Y,Z Axis origin
/// @param axisDirX,Y,Z Axis direction
/// @param angle Revolution angle in radians
/// @return Result shape, or NULL on failure
OCCTShapeRef _Nullable OCCTLocOpeRevolutionForm(OCCTShapeRef shape,
                                                 double axisOriginX, double axisOriginY, double axisOriginZ,
                                                 double axisDirX, double axisDirY, double axisDirZ,
                                                 double angle);

// --- LocOpe_SplitShape ---

/// Split a shape by adding a wire on a face. Returns the modified shape.
/// @param shape Shape to split
/// @param faceIndex Index of the face to split (0-based)
/// @param wire Wire to split the face with
/// @return Modified shape, or NULL on failure
OCCTShapeRef _Nullable OCCTLocOpeSplitShapeByWire(OCCTShapeRef shape, int32_t faceIndex, OCCTShapeRef wire);

/// Split a shape by adding a vertex on an edge. Returns the modified shape.
/// @param shape Shape to split
/// @param edgeIndex Index of the edge to split (0-based)
/// @param parameter Parameter along the edge [0,1]
/// @return Modified shape, or NULL on failure
OCCTShapeRef _Nullable OCCTLocOpeSplitShapeByVertex(OCCTShapeRef shape, int32_t edgeIndex, double parameter);

// --- LocOpe_SplitDrafts ---

/// Split a face with draft angles on both sides of a wire.
/// @param shape Shape containing the face
/// @param faceIndex Index of the face to split
/// @param wire Wire defining the split
/// @param dirX,dirY,dirZ Extraction direction
/// @param planeOriginX,Y,Z Neutral plane origin
/// @param planeNormalX,Y,Z Neutral plane normal
/// @param angle Draft angle in radians
/// @return Modified shape, or NULL on failure
OCCTShapeRef _Nullable OCCTLocOpeSplitDrafts(OCCTShapeRef shape, int32_t faceIndex, OCCTShapeRef wire,
                                              double dirX, double dirY, double dirZ,
                                              double planeOriginX, double planeOriginY, double planeOriginZ,
                                              double planeNormalX, double planeNormalY, double planeNormalZ,
                                              double angle);

// --- LocOpe_FindEdges ---

/// Find common edges between two shapes.
/// @param shape1 First shape
/// @param shape2 Second shape
/// @param outEdges Output buffer for edge shapes
/// @param maxEdges Max edges to return
/// @return Number of common edges found
int32_t OCCTLocOpeFindEdges(OCCTShapeRef shape1, OCCTShapeRef shape2,
                            OCCTShapeRef _Nullable * _Nonnull outEdges, int32_t maxEdges);

// --- LocOpe_FindEdgesInFace ---

/// Find edges of a shape that lie in a specific face.
/// @param shape Shape whose edges to check
/// @param faceIndex Face index to check against
/// @param outEdges Output buffer for edge shapes
/// @param maxEdges Max edges to return
/// @return Number of edges found in the face
int32_t OCCTLocOpeFindEdgesInFace(OCCTShapeRef shape, int32_t faceIndex,
                                   OCCTShapeRef _Nullable * _Nonnull outEdges, int32_t maxEdges);

// --- LocOpe_CSIntersector ---

/// Result of a curve-shape intersection point
typedef struct {
    double px, py, pz;    // Intersection point
    double parameter;     // Parameter on curve
    double uOnFace;       // U parameter on face
    double vOnFace;       // V parameter on face
    int32_t orientation;  // TopAbs_Orientation value
} OCCTCSIntersectionPoint;

/// Intersect a line with a shape.
/// @param shape Shape to intersect
/// @param lineOriginX,Y,Z Line origin
/// @param lineDirX,Y,Z Line direction
/// @param outPoints Output buffer for intersection points
/// @param maxPoints Max points to return
/// @return Number of intersection points found
int32_t OCCTLocOpeCSIntersectLine(OCCTShapeRef shape,
                                   double lineOriginX, double lineOriginY, double lineOriginZ,
                                   double lineDirX, double lineDirY, double lineDirZ,
                                   OCCTCSIntersectionPoint* outPoints, int32_t maxPoints);

// --- BRepCheck_Analyzer ---

/// Perform comprehensive shape validity analysis.
/// @param shape Shape to analyze
/// @param geometryChecks Whether to include geometry checks
/// @return true if shape is valid
bool OCCTBRepCheckAnalyzerIsValid(OCCTShapeRef shape, bool geometryChecks);

/// Check if a specific sub-shape is valid within its parent shape context.
/// @param parentShape Parent shape for context
/// @param subShapeType TopAbs_ShapeEnum type to check (0=COMPOUND, 1=COMPSOLID, 2=SOLID, 3=SHELL, 4=FACE, 5=WIRE, 6=EDGE, 7=VERTEX)
/// @param subShapeIndex 0-based index of sub-shape of that type
/// @return true if the sub-shape is valid
bool OCCTBRepCheckSubShapeValid(OCCTShapeRef parentShape, int32_t subShapeType, int32_t subShapeIndex);

// --- BRepCheck_Edge / Wire / Shell / Vertex ---

/// Check validity of an edge by index.
/// @param shape Parent shape
/// @param edgeIndex 0-based edge index
/// @return Check result
OCCTShapeCheckResult OCCTCheckEdge(OCCTShapeRef shape, int32_t edgeIndex);

/// Check validity of a wire by index.
/// @param shape Parent shape
/// @param wireIndex 0-based wire index
/// @return Check result
OCCTShapeCheckResult OCCTCheckWire(OCCTShapeRef shape, int32_t wireIndex);

/// Check validity of a shell by index.
/// @param shape Parent shape
/// @param shellIndex 0-based shell index
/// @return Check result
OCCTShapeCheckResult OCCTCheckShell(OCCTShapeRef shape, int32_t shellIndex);

/// Check validity of a vertex by index.
/// @param shape Parent shape
/// @param vertexIndex 0-based vertex index
/// @return Check result
OCCTShapeCheckResult OCCTCheckVertex(OCCTShapeRef shape, int32_t vertexIndex);

// --- ShapeFix_ShapeTolerance ---

/// Limit all tolerances in a shape to a given range.
/// @param shape Shape to modify
/// @param minTolerance Minimum tolerance
/// @param maxTolerance Maximum tolerance
/// @return true if any tolerance was changed
bool OCCTShapeFixLimitTolerance(OCCTShapeRef shape, double minTolerance, double maxTolerance);

/// Set all tolerances in a shape to a specific value.
/// @param shape Shape to modify
/// @param tolerance Tolerance value to set
void OCCTShapeFixSetTolerance(OCCTShapeRef shape, double tolerance);

// --- ShapeFix_SplitCommonVertex ---

/// Split vertices that are shared between edges in incompatible ways.
/// @param shape Shape to fix
/// @return Fixed shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeFixSplitCommonVertex(OCCTShapeRef shape);

// --- ShapeFix_FaceConnect ---

/// Connect adjacent faces in a shell.
/// @param shape Shell shape to fix
/// @param tolerance Connection tolerance
/// @return Fixed shell shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeFixFaceConnect(OCCTShapeRef shape, double tolerance);

// --- ShapeFix_Edge ---

/// Fix same-parameter inconsistencies on all edges in a shape.
/// @param shape Shape to fix
/// @param tolerance Tolerance for fixing (0 = default)
/// @return Number of edges fixed
int32_t OCCTShapeFixEdgeSameParameter(OCCTShapeRef shape, double tolerance);

/// Fix vertex tolerance issues on all edges in a shape.
/// @param shape Shape to fix
/// @return Number of edges fixed
int32_t OCCTShapeFixEdgeVertexTolerance(OCCTShapeRef shape);

// --- ShapeFix_WireVertex ---

/// Fix vertex issues in all wires of a shape.
/// @param shape Shape to fix
/// @param precision Precision for fixing
/// @return Number of fixes applied
int32_t OCCTShapeFixWireVertex(OCCTShapeRef shape, double precision);

// --- BRepExtrema_ExtCC ---

/// Edge-edge extrema result
typedef struct {
    double distance;      // Minimum distance
    double paramOnE1;     // Parameter on first edge
    double paramOnE2;     // Parameter on second edge
    double pt1x, pt1y, pt1z;  // Closest point on edge 1
    double pt2x, pt2y, pt2z;  // Closest point on edge 2
    bool isParallel;      // Whether edges are parallel
    int32_t solutionCount; // Number of extrema
} OCCTEdgeEdgeExtremaResult;

/// Compute distance extrema between two edges.
/// @param shape1 Shape containing first edge
/// @param edgeIndex1 Index of first edge (0-based)
/// @param shape2 Shape containing second edge
/// @param edgeIndex2 Index of second edge (0-based)
/// @return Extrema result
OCCTEdgeEdgeExtremaResult OCCTBRepExtremaExtCC(OCCTShapeRef shape1, int32_t edgeIndex1,
                                                OCCTShapeRef shape2, int32_t edgeIndex2);

/// Compute distance extrema between two standalone edges (from wire shapes).
/// @param edge1 First edge shape
/// @param edge2 Second edge shape
/// @return Extrema result
OCCTEdgeEdgeExtremaResult OCCTBRepExtremaExtCCEdges(OCCTShapeRef edge1, OCCTShapeRef edge2);

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

// --- BRepExtrema_ExtFF ---

/// Face-face extrema result
typedef struct {
    double distance;
    double u1, v1;        // Parameters on face 1
    double u2, v2;        // Parameters on face 2
    double pt1x, pt1y, pt1z;
    double pt2x, pt2y, pt2z;
    int32_t solutionCount;
} OCCTFaceFaceExtremaResult;

/// Compute distance extrema between two faces.
/// @param shape1 Shape containing first face
/// @param faceIndex1 First face index (0-based)
/// @param shape2 Shape containing second face
/// @param faceIndex2 Second face index (0-based)
/// @return Extrema result
OCCTFaceFaceExtremaResult OCCTBRepExtremaExtFF(OCCTShapeRef shape1, int32_t faceIndex1,
                                                OCCTShapeRef shape2, int32_t faceIndex2);

// --- ShapeUpgrade_ShapeDivideClosed ---

/// Divide closed faces in a shape.
/// @param shape Shape to process
/// @param nbSplitPoints Number of split points per closed face
/// @return Divided shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeUpgradeDivideClosed(OCCTShapeRef shape, int32_t nbSplitPoints);

// --- ShapeUpgrade_ShapeDivideContinuity ---

/// Divide a shape at continuity breaks.
/// @param shape Shape to process
/// @param boundaryCriterion Minimum continuity level (0=C0, 1=C1, 2=C2, 3=C3, 4=CN, 5=G1, 6=G2)
/// @param tolerance Tolerance for continuity check
/// @return Divided shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeUpgradeDivideContinuity(OCCTShapeRef shape, int32_t boundaryCriterion, double tolerance);

// MARK: - v0.49.0: BRepExtrema_ExtPC, ExtCF, FreeBounds, ShapeCustom, ShapeFix, Surface/Curve expansion

// --- BRepExtrema_ExtPC ---

/// Point-edge extrema result
typedef struct {
    double distance;           // Minimum distance
    double parameter;          // Parameter on edge at closest point
    double ptx, pty, ptz;     // Closest point on edge
    int32_t solutionCount;    // Number of extrema found
} OCCTPointEdgeExtremaResult;

/// Compute distance from a point to an edge.
/// @param px,py,pz Point coordinates
/// @param shape Shape containing the edge
/// @param edgeIndex Edge index (0-based)
/// @return Extrema result (minimum distance solution)
OCCTPointEdgeExtremaResult OCCTBRepExtremaExtPC(double px, double py, double pz,
                                                 OCCTShapeRef shape, int32_t edgeIndex);

// --- BRepExtrema_ExtCF ---

/// Edge-face (curve-face) extrema result
typedef struct {
    double distance;
    double paramOnEdge;
    double uOnFace, vOnFace;
    double edgePtx, edgePty, edgePtz;
    double facePtx, facePty, facePtz;
    int32_t solutionCount;
    bool isParallel;
} OCCTEdgeFaceExtremaResult;

/// Compute distance extrema between an edge and a face.
/// @param shape1 Shape containing the edge
/// @param edgeIndex Edge index (0-based)
/// @param shape2 Shape containing the face
/// @param faceIndex Face index (0-based)
/// @return Extrema result (minimum distance solution)
OCCTEdgeFaceExtremaResult OCCTBRepExtremaExtCF(OCCTShapeRef shape1, int32_t edgeIndex,
                                                OCCTShapeRef shape2, int32_t faceIndex);

// --- GeomConvert_CompCurveToBSplineCurve ---

/// Join multiple curves into a single BSpline curve.
/// @param curves Array of curve handles to join (in order)
/// @param count Number of curves
/// @param tolerance Tolerance for joining (gap between endpoints)
/// @return Joined BSpline curve, or NULL on failure
OCCTCurve3DRef _Nullable OCCTCurve3DJoinCurves(const OCCTCurve3DRef* curves, int32_t count, double tolerance);

// --- ShapeFix_FixSmallSolid ---

/// Remove small solids from a shape based on volume threshold.
/// @param shape Shape containing solids
/// @param volumeThreshold Volume below which solids are removed
/// @return Shape with small solids removed, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeFixRemoveSmallSolids(OCCTShapeRef shape, double volumeThreshold);

/// Merge small solids into adjacent larger solids.
/// @param shape Shape containing solids
/// @param widthFactorThreshold Width factor below which solids are merged
/// @return Shape with small solids merged, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeFixMergeSmallSolids(OCCTShapeRef shape, double widthFactorThreshold);

// --- ShapeCustom ---

/// Redress indirect (left-handed) surfaces to direct (right-handed).
/// @param shape Shape to process
/// @return Shape with all surfaces made direct, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeCustomDirectFaces(OCCTShapeRef shape);

/// Simplify BSpline surfaces and curves by restricting degree and segment count.
/// @param shape Shape to process
/// @param tol3d 3D tolerance
/// @param tol2d 2D tolerance
/// @param maxDegree Maximum BSpline degree
/// @param maxSegments Maximum number of BSpline segments
/// @param continuity3d 3D continuity (0=C0, 1=C1, 2=C2)
/// @param continuity2d 2D continuity (0=C0, 1=C1, 2=C2)
/// @param degreePriority If true, prioritize degree reduction over segment count
/// @param rational If true, allow rational BSplines
/// @return Simplified shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeCustomBSplineRestriction(OCCTShapeRef shape,
    double tol3d, double tol2d, int32_t maxDegree, int32_t maxSegments,
    int32_t continuity3d, int32_t continuity2d, bool degreePriority, bool rational);

// --- ShapeAnalysis_FreeBoundsProperties ---

/// Free bounds analysis result (summary)
typedef struct {
    int32_t totalFreeBounds;
    int32_t closedFreeBounds;
    int32_t openFreeBounds;
} OCCTFreeBoundsResult;

/// Analyze free bounds of a shape.
/// @param shape Shape to analyze
/// @param tolerance Sewing tolerance for finding free bounds
/// @return Analysis result with bound counts
OCCTFreeBoundsResult OCCTFreeBoundsAnalyze(OCCTShapeRef shape, double tolerance);

/// Individual free bound properties
typedef struct {
    double area;
    double perimeter;
    double ratio;       // Area / (perimeter * perimeter)
    double width;       // Average width
    int32_t notchCount;
} OCCTFreeBoundInfo;

/// Get properties of a closed free bound.
/// @param shape Shape previously analyzed
/// @param tolerance Same tolerance used in analysis
/// @param index 0-based index of the closed free bound
/// @return Properties of the specified closed free bound
OCCTFreeBoundInfo OCCTFreeBoundsGetClosedBoundInfo(OCCTShapeRef shape, double tolerance, int32_t index);

/// Get properties of an open free bound.
/// @param shape Shape previously analyzed
/// @param tolerance Same tolerance used in analysis
/// @param index 0-based index of the open free bound
/// @return Properties of the specified open free bound
OCCTFreeBoundInfo OCCTFreeBoundsGetOpenBoundInfo(OCCTShapeRef shape, double tolerance, int32_t index);

/// Get the wire of a closed free bound as a shape.
/// @param shape Shape previously analyzed
/// @param tolerance Same tolerance used in analysis
/// @param index 0-based index of the closed free bound
/// @return Wire shape, or NULL on failure
OCCTShapeRef _Nullable OCCTFreeBoundsGetClosedBoundWire(OCCTShapeRef shape, double tolerance, int32_t index);

/// Get the wire of an open free bound as a shape.
/// @param shape Shape previously analyzed
/// @param tolerance Same tolerance used in analysis
/// @param index 0-based index of the open free bound
/// @return Wire shape, or NULL on failure
OCCTShapeRef _Nullable OCCTFreeBoundsGetOpenBoundWire(OCCTShapeRef shape, double tolerance, int32_t index);

// --- ShapeAnalysis_Surface expansion ---

/// Surface UV projection result
typedef struct {
    double u, v;   // Projected UV parameters
    double gap;    // Distance between 3D point and surface at (u,v)
} OCCTSurfaceUVResult;

/// Project a 3D point onto a surface to find UV parameters.
/// @param surface Surface to project onto
/// @param px,py,pz 3D point to project
/// @param precision Projection precision
/// @return UV coordinates and gap distance
OCCTSurfaceUVResult OCCTSurfaceValueOfUV(OCCTSurfaceRef surface,
    double px, double py, double pz, double precision);

/// Project a 3D point onto a surface using a previous UV as starting hint.
/// More efficient than ValueOfUV for iterative projections along a path.
/// @param surface Surface to project onto
/// @param prevU,prevV Previous UV hint
/// @param px,py,pz 3D point to project
/// @param precision Projection precision
/// @return UV coordinates and gap distance
OCCTSurfaceUVResult OCCTSurfaceNextValueOfUV(OCCTSurfaceRef surface,
    double prevU, double prevV, double px, double py, double pz, double precision);

// --- ShapeAnalysis_Curve expansion ---

/// Curve point projection result
typedef struct {
    double distance;            // Distance from original point to projection
    double parameter;           // Parameter on curve at closest point
    double projX, projY, projZ; // Projected point coordinates
} OCCTCurveProjectResult;

/// Project a point onto a 3D curve.
/// @param curve Curve to project onto
/// @param px,py,pz Point to project
/// @param precision Projection precision
/// @return Projection result with distance, parameter, and projected point
OCCTCurveProjectResult OCCTCurve3DProjectPoint(OCCTCurve3DRef curve,
    double px, double py, double pz, double precision);

/// Curve range validation result
typedef struct {
    double first;       // Validated first parameter
    double last;        // Validated last parameter
    bool wasAdjusted;   // True if the range was adjusted
} OCCTCurveValidateRangeResult;

/// Validate and optionally adjust a curve parameter range.
/// @param curve Curve to validate against
/// @param first Desired first parameter
/// @param last Desired last parameter
/// @param precision Tolerance for validation
/// @return Validated range (adjusted if necessary)
OCCTCurveValidateRangeResult OCCTCurve3DValidateRange(OCCTCurve3DRef curve,
    double first, double last, double precision);

/// Get sample points along a 3D curve.
/// @param curve Curve to sample
/// @param first Start parameter
/// @param last End parameter
/// @param outXYZ Output buffer (must hold maxPoints * 3 doubles)
/// @param maxPoints Maximum number of points to return
/// @return Actual number of points written to outXYZ
int32_t OCCTCurve3DGetSamplePoints3D(OCCTCurve3DRef curve, double first, double last,
    double* outXYZ, int32_t maxPoints);

// MARK: - v0.50.0: GC_Make* geometry construction, BRepExtrema_Poly, BRepTools_History,
// GeomConvert knot splitting + CompBezier, ShapeAnalysis WireVertex + NearestPlane,
// ShapeCustom Curve/Surface, ShapeUpgrade SplitCurve3d/SplitSurfaceContinuity

/// Create an arc of hyperbola between two parameter values.
/// @param majorRadius Major radius (a) of the hyperbola
/// @param minorRadius Minor radius (b) of the hyperbola
/// @param axisX,axisY,axisZ Center of the hyperbola
/// @param dirX,dirY,dirZ Normal direction of the plane
/// @param alpha1 Start parameter
/// @param alpha2 End parameter
/// @param sense Direction of parameterization (true = natural)
/// @return Trimmed curve handle, or NULL on failure
OCCTCurve3DRef _Nullable OCCTCurve3DArcOfHyperbola(
    double majorRadius, double minorRadius,
    double axisX, double axisY, double axisZ,
    double dirX, double dirY, double dirZ,
    double alpha1, double alpha2, bool sense);

/// Create an arc of parabola between two parameter values.
/// @param focalDistance Focal distance of the parabola
/// @param axisX,axisY,axisZ Center of the parabola
/// @param dirX,dirY,dirZ Normal direction of the plane
/// @param alpha1 Start parameter
/// @param alpha2 End parameter
/// @param sense Direction of parameterization (true = natural)
/// @return Trimmed curve handle, or NULL on failure
OCCTCurve3DRef _Nullable OCCTCurve3DArcOfParabola(
    double focalDistance,
    double axisX, double axisY, double axisZ,
    double dirX, double dirY, double dirZ,
    double alpha1, double alpha2, bool sense);

/// Create a conical surface from axis, semi-angle, and base radius.
/// @param semiAngle Half-angle of the cone in radians (must be in (0, PI/2))
/// @param radius Base radius of the cone
/// @return Surface handle, or NULL on failure
OCCTSurfaceRef _Nullable OCCTSurfaceConicalFromAxis(
    double axisX, double axisY, double axisZ,
    double dirX, double dirY, double dirZ,
    double semiAngle, double radius);

/// Create a conical surface from two points and two radii.
/// @param r1 Radius at p1, r2 Radius at p2
/// @return Surface handle, or NULL on failure
OCCTSurfaceRef _Nullable OCCTSurfaceConicalFromPointsRadii(
    double p1x, double p1y, double p1z,
    double p2x, double p2y, double p2z,
    double r1, double r2);

/// Create a cylindrical surface from axis and radius.
OCCTSurfaceRef _Nullable OCCTSurfaceCylindricalFromAxis(
    double axisX, double axisY, double axisZ,
    double dirX, double dirY, double dirZ,
    double radius);

/// Create a cylindrical surface from 3 points.
OCCTSurfaceRef _Nullable OCCTSurfaceCylindricalFromPoints(
    double p1x, double p1y, double p1z,
    double p2x, double p2y, double p2z,
    double p3x, double p3y, double p3z);

/// Create a plane surface from 3 points.
OCCTSurfaceRef _Nullable OCCTSurfacePlaneFromPoints(
    double p1x, double p1y, double p1z,
    double p2x, double p2y, double p2z,
    double p3x, double p3y, double p3z);

/// Create a plane surface from a point and normal direction.
OCCTSurfaceRef _Nullable OCCTSurfacePlaneFromPointNormal(
    double px, double py, double pz,
    double nx, double ny, double nz);

/// Create a trimmed conical surface from two endpoints and two radii.
/// @return Rectangular trimmed surface handle, or NULL on failure
OCCTSurfaceRef _Nullable OCCTSurfaceTrimmedCone(
    double p1x, double p1y, double p1z,
    double p2x, double p2y, double p2z,
    double r1, double r2);

/// Create a trimmed cylindrical surface from axis, radius, and height.
OCCTSurfaceRef _Nullable OCCTSurfaceTrimmedCylinder(
    double axisX, double axisY, double axisZ,
    double dirX, double dirY, double dirZ,
    double radius, double height);

/// Result of polyhedral distance computation.
typedef struct {
    double distance;    // Polyhedral distance between shapes
    double p1x, p1y, p1z;  // Closest point on shape 1
    double p2x, p2y, p2z;  // Closest point on shape 2
    bool success;       // True if computation succeeded
} OCCTPolyDistanceResult;

/// Compute fast polyhedral (approximate) distance between two shapes.
/// Shapes must be meshed beforehand (BRepMesh_IncrementalMesh).
OCCTPolyDistanceResult OCCTShapePolyhedralDistance(OCCTShapeRef shape1, OCCTShapeRef shape2);

/// Opaque handle to BRepTools_History.
typedef void* _Nullable OCCTHistoryRef;

/// Create an empty shape modification history.
OCCTHistoryRef OCCTHistoryCreate(void);

/// Record that a shape was modified into a new shape.
void OCCTHistoryAddModified(OCCTHistoryRef history, OCCTShapeRef initial, OCCTShapeRef modified);

/// Record that a shape generated a new shape.
void OCCTHistoryAddGenerated(OCCTHistoryRef history, OCCTShapeRef initial, OCCTShapeRef generated);

/// Record that a shape was removed.
void OCCTHistoryRemove(OCCTHistoryRef history, OCCTShapeRef shape);

/// Check if a shape was removed.
bool OCCTHistoryIsRemoved(OCCTHistoryRef history, OCCTShapeRef shape);

/// Query flags for history state.
bool OCCTHistoryHasModified(OCCTHistoryRef history);
bool OCCTHistoryHasGenerated(OCCTHistoryRef history);
bool OCCTHistoryHasRemoved(OCCTHistoryRef history);

/// Get the number of shapes that the initial shape was modified to.
int32_t OCCTHistoryModifiedCount(OCCTHistoryRef history, OCCTShapeRef initial);

/// Get the number of shapes that the initial shape generated.
int32_t OCCTHistoryGeneratedCount(OCCTHistoryRef history, OCCTShapeRef initial);

/// Destroy a history object.
void OCCTHistoryDestroy(OCCTHistoryRef history);

/// Result of BSpline surface knot splitting analysis.
typedef struct {
    int32_t nbUSplits;  // Number of U split indices
    int32_t nbVSplits;  // Number of V split indices
} OCCTSurfaceKnotSplitResult;

/// Analyze BSpline surface knot splitting at a given continuity level.
/// @param surface BSpline surface to analyze
/// @param uContinuity Desired U continuity (0=C0, 1=C1, 2=C2)
/// @param vContinuity Desired V continuity (0=C0, 1=C1, 2=C2)
OCCTSurfaceKnotSplitResult OCCTSurfaceKnotSplitting(OCCTSurfaceRef surface,
    int32_t uContinuity, int32_t vContinuity);

/// Join an array of Bezier surface patches into a single BSpline surface.
/// @param patches Array of surface handles (row-major, nRows x nCols)
/// @param nRows Number of rows in the patch grid
/// @param nCols Number of columns in the patch grid
/// @return BSpline surface handle, or NULL on failure
OCCTSurfaceRef _Nullable OCCTSurfaceJoinBezierPatches(
    const OCCTSurfaceRef _Nullable * _Nonnull patches,
    int32_t nRows, int32_t nCols);

/// Result of wire vertex analysis.
typedef struct {
    int32_t nbEdges;    // Number of edges analyzed
    bool isDone;        // True if analysis completed
} OCCTWireVertexResult;

/// Analyze wire vertex connections.
/// @param wire Wire to analyze
/// @param precision Tolerance for vertex analysis
OCCTWireVertexResult OCCTShapeWireVertexAnalysis(OCCTShapeRef wire, double precision);

/// Get the status of a specific vertex in a wire vertex analysis.
/// @param wire Wire that was analyzed
/// @param precision Same precision used in analysis
/// @param vertexIndex 0-based vertex index
/// @return Status code: 0=SameVertex, 1=SameCoords, 2=Close, 3=End, 4=Start, 5=Inters, -1=Disjoined
int32_t OCCTShapeWireVertexStatus(OCCTShapeRef wire, double precision, int32_t vertexIndex);

/// Result of nearest plane fitting.
typedef struct {
    double normalX, normalY, normalZ;  // Plane normal direction
    double originX, originY, originZ;  // Point on the plane
    double maxDeviation;  // Maximum distance from points to plane
    bool success;
} OCCTNearestPlaneResult;

/// Fit the nearest plane to a set of 3D points.
/// @param points Array of point coordinates (x,y,z triples)
/// @param nPoints Number of points
OCCTNearestPlaneResult OCCTShapeNearestPlane(const double* points, int32_t nPoints);

/// Result of surface analytical conversion.
typedef struct {
    OCCTSurfaceRef _Nullable surface;  // Recognized analytical surface, or NULL
    double gap;  // Maximum deviation from original
} OCCTSurfaceAnalyticalResult;

/// Try to recognize an analytical surface (plane, cylinder, etc.) from a BSpline.
/// @param surface Input BSpline surface
/// @param tolerance Recognition tolerance
OCCTSurfaceAnalyticalResult OCCTSurfaceConvertToAnalytical(OCCTSurfaceRef surface, double tolerance);

/// Convert a closed BSpline curve to periodic form.
/// @param curve Closed BSpline curve
/// @return Periodic curve, or NULL if conversion fails
OCCTCurve3DRef _Nullable OCCTCurve3DConvertToPeriodic(OCCTCurve3DRef curve);

/// Split a 3D curve at a specified parameter value.
/// @param curve Curve to split
/// @param splitParam Parameter at which to split
/// @param outCurve1 First segment (before split point)
/// @param outCurve2 Second segment (after split point)
/// @return True if split succeeded
bool OCCTCurve3DSplitAt(OCCTCurve3DRef curve, double splitParam,
    OCCTCurve3DRef _Nullable * _Nonnull outCurve1,
    OCCTCurve3DRef _Nullable * _Nonnull outCurve2);

/// Result of surface continuity splitting.
typedef struct {
    bool wasSplit;      // True if the surface was actually split
    bool isOk;          // True if no split was needed (already meets criterion)
    int32_t nUSplits;   // Number of U split values
    int32_t nVSplits;   // Number of V split values
} OCCTSurfaceContinuitySplitResult;

/// Split a BSpline surface at continuity breaks.
/// @param surface BSpline surface to split
/// @param criterion Continuity level: 0=C0, 1=C1, 2=C2, 3=C3
/// @param tolerance Tolerance for continuity checking
OCCTSurfaceContinuitySplitResult OCCTSurfaceSplitByContinuity(OCCTSurfaceRef surface,
    int32_t criterion, double tolerance);

// MARK: - v0.51.0: BRepLib makers, GC geometry, GCE2d, ChFi2d_AnaFilletAlgo

// --- BRepLib_MakePolygon ---

/// Create a polygonal wire from an array of 3D points.
/// @param coords Array of point coordinates (x,y,z triples), length = nPoints * 3
/// @param nPoints Number of points (must be >= 2)
/// @param close If true, close the polygon
/// @return Wire shape, or NULL on failure
OCCTWireRef _Nullable OCCTWireMakePolygonFromPoints(const double* coords, int32_t nPoints, bool close);

// --- BRepLib_MakeWire ---

/// Create a wire from an array of edge shapes.
/// @param edges Array of edge shapes
/// @param count Number of edges
/// @return Wire, or NULL on failure
OCCTWireRef _Nullable OCCTWireMakeWireFromEdges(const OCCTShapeRef _Nonnull * _Nonnull edges, int32_t count);

/// Create a wire from an array of OCCTEdgeRef objects.
/// @param edges Array of edge refs
/// @param count Number of edges
/// @return Wire, or NULL on failure
OCCTWireRef _Nullable OCCTWireMakeWireFromEdgeRefs(const OCCTEdgeRef _Nonnull * _Nonnull edges, int32_t count);

// --- BRepLib_MakeSolid ---

/// Create a solid from a shell shape.
/// @param shell Shape containing a shell
/// @return Solid shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeMakeSolidFromShell(OCCTShapeRef shell);

// --- GC_MakeEllipse ---

/// Create a 3D ellipse curve from axis position and radii.
/// @param cx,cy,cz Center point
/// @param dx,dy,dz Normal direction (Z axis of the ellipse plane)
/// @param majorRadius Major radius
/// @param minorRadius Minor radius
/// @return Ellipse curve, or NULL on failure
OCCTCurve3DRef _Nullable OCCTCurve3DMakeEllipse(double cx, double cy, double cz,
    double dx, double dy, double dz, double majorRadius, double minorRadius);

/// Create a 3D ellipse curve from three points.
/// @param s1x,s1y,s1z End of major axis
/// @param s2x,s2y,s2z Point defining minor axis
/// @param centerX,centerY,centerZ Center point
/// @return Ellipse curve, or NULL on failure
OCCTCurve3DRef _Nullable OCCTCurve3DMakeEllipseThreePoints(
    double s1x, double s1y, double s1z,
    double s2x, double s2y, double s2z,
    double centerX, double centerY, double centerZ);

// --- GC_MakeHyperbola ---

/// Create a 3D hyperbola curve from axis position and radii.
/// @param cx,cy,cz Center point
/// @param dx,dy,dz Normal direction
/// @param majorRadius Major radius
/// @param minorRadius Minor radius
/// @return Hyperbola curve, or NULL on failure
OCCTCurve3DRef _Nullable OCCTCurve3DMakeHyperbola(double cx, double cy, double cz,
    double dx, double dy, double dz, double majorRadius, double minorRadius);

/// Create a 3D hyperbola curve from three points.
/// @param s1x,s1y,s1z End of major axis
/// @param s2x,s2y,s2z Point defining minor axis
/// @param centerX,centerY,centerZ Center point
/// @return Hyperbola curve, or NULL on failure
OCCTCurve3DRef _Nullable OCCTCurve3DMakeHyperbolaThreePoints(
    double s1x, double s1y, double s1z,
    double s2x, double s2y, double s2z,
    double centerX, double centerY, double centerZ);

// --- GC_MakeMirror ---

/// Mirror a shape about a point (point symmetry).
/// @param shape Shape to mirror
/// @param px,py,pz Mirror point
/// @return Mirrored shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeMirrorAboutPoint(OCCTShapeRef shape,
    double px, double py, double pz);

/// Mirror a shape about an axis line.
/// @param shape Shape to mirror
/// @param ox,oy,oz Point on axis
/// @param dx,dy,dz Axis direction
/// @return Mirrored shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeMirrorAboutAxis(OCCTShapeRef shape,
    double ox, double oy, double oz, double dx, double dy, double dz);

// --- GC_MakeScale ---

/// Scale a shape about a specific point.
/// @param shape Shape to scale
/// @param px,py,pz Center of scaling
/// @param factor Scale factor
/// @return Scaled shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeScaleAboutPoint(OCCTShapeRef shape,
    double px, double py, double pz, double factor);

// --- GC_MakeTranslation ---

/// Translate a shape by the vector from point1 to point2.
/// @param shape Shape to translate
/// @param p1x,p1y,p1z Start point
/// @param p2x,p2y,p2z End point
/// @return Translated shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeTranslateByPoints(OCCTShapeRef shape,
    double p1x, double p1y, double p1z, double p2x, double p2y, double p2z);

// --- GC_MakeLine2d ---

/// Create a 2D infinite line through two points.
/// @param p1x,p1y First point
/// @param p2x,p2y Second point
/// @return 2D line curve, or NULL if points coincide
OCCTCurve2DRef _Nullable OCCTCurve2DMakeLineThroughPoints(double p1x, double p1y,
    double p2x, double p2y);

/// Create a 2D line parallel to another at a given distance.
/// @param px,py Point on reference line
/// @param dx,dy Direction of reference line
/// @param distance Signed distance to offset
/// @return 2D line curve, or NULL on failure
OCCTCurve2DRef _Nullable OCCTCurve2DMakeLineParallel(double px, double py,
    double dx, double dy, double distance);

// --- ChFi2d_AnaFilletAlgo ---

/// Result of a 2D analytical fillet operation.
typedef struct {
    OCCTShapeRef _Nullable fillet;   // The fillet arc edge
    OCCTShapeRef _Nullable edge1;    // Trimmed first edge
    OCCTShapeRef _Nullable edge2;    // Trimmed second edge
    bool success;
} OCCTAnaFilletResult;

/// Compute a 2D analytical fillet between two edges (segments/arcs).
/// @param edge1 First edge shape
/// @param edge2 Second edge shape
/// @param planeOx,planeOy,planeOz Point on the plane
/// @param planeNx,planeNy,planeNz Plane normal direction
/// @param radius Fillet radius
/// @return Fillet result with fillet arc and trimmed edges
OCCTAnaFilletResult OCCTChFi2dAnaFillet(OCCTShapeRef edge1, OCCTShapeRef edge2,
    double planeOx, double planeOy, double planeOz,
    double planeNx, double planeNy, double planeNz,
    double radius);

// MARK: - v0.52.0: BRepFill, LocOpe, Healing Utilities, 2D Curve Tools

// --- BRepFill_Generator ---

/// Create a ruled shell by lofting between multiple wire sections.
/// @param wires Array of wire handles
/// @param count Number of wires
/// @return Shell shape, or NULL on failure
OCCTShapeRef _Nullable OCCTBRepFillGenerator(const OCCTWireRef _Nonnull * _Nonnull wires, int32_t count);

// --- BRepFill_AdvancedEvolved ---

/// Create an evolved solid from a spine wire and profile wire.
/// @param spine Wire defining the sweep path
/// @param profile Wire defining the cross-section
/// @param tolerance Geometric tolerance (default 1e-3)
/// @param solidReq Whether to produce a solid (vs shell)
/// @return Evolved shape, or NULL on failure
OCCTShapeRef _Nullable OCCTBRepFillAdvancedEvolved(OCCTWireRef spine, OCCTWireRef profile,
    double tolerance, bool solidReq);

// --- BRepFill_OffsetWire ---

/// Offset a planar wire on its face.
/// @param faceRef Face containing the wire
/// @param offset Signed offset distance (positive = outward, negative = inward)
/// @return Offset wire shape, or NULL on failure
OCCTShapeRef _Nullable OCCTBRepFillOffsetWire(OCCTFaceRef faceRef, double offset);

// --- BRepFill_Draft ---

/// Create a draft surface from a wire along a direction with a taper angle.
/// @param wire Wire defining the base profile
/// @param dirX,dirY,dirZ Draft direction
/// @param angle Taper angle in radians
/// @param length Draft length
/// @return Draft shape, or NULL on failure
OCCTShapeRef _Nullable OCCTBRepFillDraft(OCCTWireRef wire,
    double dirX, double dirY, double dirZ, double angle, double length);

// --- BRepFill_Pipe ---

/// Result of a pipe sweep operation.
typedef struct {
    OCCTShapeRef _Nullable shape;  // The swept pipe shape
    double errorOnSurface;         // Surface approximation error
} OCCTBRepFillPipeResult;

/// Create a pipe sweep of a profile along a spine.
/// @param spine Wire defining the sweep path
/// @param profile Wire defining the cross-section
/// @return Pipe result with shape and error metric
OCCTBRepFillPipeResult OCCTBRepFillPipe(OCCTWireRef spine, OCCTWireRef profile);

// --- BRepFill_CompatibleWires ---

/// Make wires compatible for lofting (same number of edges, aligned).
/// @param wires Array of wire handles
/// @param count Number of wires
/// @param outWires Output array for compatible wires (must be pre-allocated to count)
/// @return Number of compatible wires produced, or 0 on failure
int32_t OCCTBRepFillCompatibleWires(const OCCTWireRef _Nonnull * _Nonnull wires, int32_t count,
    OCCTWireRef _Nullable * _Nonnull outWires);

// --- ChFi2d_FilletAlgo ---

/// Result of a 2D iterative fillet operation.
typedef struct {
    OCCTShapeRef _Nullable fillet;  // The fillet arc edge
    OCCTShapeRef _Nullable edge1;   // Trimmed first edge
    OCCTShapeRef _Nullable edge2;   // Trimmed second edge
    int32_t resultCount;            // Number of fillet solutions found
    bool success;
} OCCTChFi2dFilletResult;

/// Compute a 2D iterative fillet between two edges in a plane.
/// @param edge1 First edge shape
/// @param edge2 Second edge shape
/// @param planeOx,planeOy,planeOz Point on the working plane
/// @param planeNx,planeNy,planeNz Plane normal direction
/// @param radius Fillet radius
/// @return Fillet result with fillet edge and trimmed input edges
OCCTChFi2dFilletResult OCCTChFi2dFilletAlgo(OCCTShapeRef edge1, OCCTShapeRef edge2,
    double planeOx, double planeOy, double planeOz,
    double planeNx, double planeNy, double planeNz,
    double radius);

// --- BRepTools_Substitution ---

/// Substitute a sub-shape within a parent shape.
/// @param parentShape The shape to modify
/// @param oldSubShape The sub-shape to replace
/// @param newSubShape The replacement sub-shape
/// @return Modified shape, or NULL on failure
OCCTShapeRef _Nullable OCCTBRepToolsSubstitute(OCCTShapeRef parentShape,
    OCCTShapeRef oldSubShape, OCCTShapeRef newSubShape);

// --- ShapeUpgrade_ShellSewing ---

/// Sew disconnected shells in a shape.
/// @param shape Shape containing shells to sew
/// @param tolerance Sewing tolerance
/// @return Sewn shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeUpgradeShellSewing(OCCTShapeRef shape, double tolerance);

// --- ShapeCustom_Curve2d ---

/// Check if a 2D curve's control points are collinear (i.e., nearly linear).
/// @param curve2D The 2D curve to check
/// @param tolerance Maximum deviation to consider as linear
/// @param deviation Output: actual maximum deviation from line
/// @return true if the curve is linear within tolerance
bool OCCTCurve2DIsLinear(OCCTCurve2DRef curve2D, double tolerance, double* deviation);

/// Convert a nearly-linear 2D curve to a Geom2d_Line.
/// @param curve2D The 2D curve to convert
/// @param first First parameter
/// @param last Last parameter
/// @param tolerance Maximum deviation tolerance
/// @param newFirst Output: new first parameter on line
/// @param newLast Output: new last parameter on line
/// @param deviation Output: actual deviation
/// @return Converted 2D line curve, or NULL if not linear
OCCTCurve2DRef _Nullable OCCTCurve2DConvertToLine(OCCTCurve2DRef curve2D,
    double first, double last, double tolerance,
    double* newFirst, double* newLast, double* deviation);

/// Simplify a 2D BSpline curve by removing unnecessary knots.
/// @param curve2D The 2D BSpline curve to simplify
/// @param tolerance Simplification tolerance
/// @return true if the curve was simplified
bool OCCTCurve2DSimplifyBSpline(OCCTCurve2DRef curve2D, double tolerance);

// --- ShapeFix_SplitTool ---

/// Split an edge at a parameter value.
/// @param edge The edge to split
/// @param param Parameter value at which to split
/// @param vertexX,vertexY,vertexZ Position of split vertex
/// @param outEdge1 Output: first half of split edge
/// @param outEdge2 Output: second half of split edge
/// @return true if split succeeded
bool OCCTShapeFixSplitEdge(OCCTEdgeRef edge, double param,
    double vertexX, double vertexY, double vertexZ,
    OCCTEdgeRef _Nullable * _Nonnull outEdge1,
    OCCTEdgeRef _Nullable * _Nonnull outEdge2);

// --- LocOpe_BuildShape ---

/// Build a shape from a list of faces.
/// @param shape Shape containing faces
/// @return Built shape, or NULL on failure
OCCTShapeRef _Nullable OCCTLocOpeBuildShape(OCCTShapeRef shape);

// --- Approx_Curve2d ---

/// Approximate a 2D curve as a BSpline.
/// @param curve2D The 2D curve to approximate
/// @param first First parameter
/// @param last Last parameter
/// @param tolU Tolerance in U
/// @param tolV Tolerance in V
/// @param maxDegree Maximum BSpline degree
/// @param maxSegments Maximum number of segments
/// @return Approximated 2D BSpline curve, or NULL on failure
OCCTCurve2DRef _Nullable OCCTApproxCurve2d(OCCTCurve2DRef curve2D,
    double first, double last, double tolU, double tolV,
    int32_t maxDegree, int32_t maxSegments);

// ============================================================================
// MARK: - v0.53.0: 2D Geometry Completions
// ============================================================================

// --- GccAna Bisectors ---

/// Bisector result type
typedef enum {
    OCCTBisecTypeLine = 0,
    OCCTBisecTypeCircle = 1,
    OCCTBisecTypeEllipse = 2,
    OCCTBisecTypeHyperbola = 3,
    OCCTBisecTypeParabola = 4,
    OCCTBisecTypePoint = 5
} OCCTBisecType;

/// Bisector solution (stores the type and curve if applicable)
typedef struct {
    OCCTBisecType type;
    /// For line: (px, py) is a point on it, (dx, dy) is its direction
    /// For circle: (px, py) is center, radius is radius
    /// For point: (px, py) is the point, others are 0
    /// For conics: (px, py) is focus/center, radius is semi-axis
    double px, py, dx, dy, radius;
} OCCTBisecSolution;

/// Perpendicular bisector between two points.
/// @return true if a solution exists
bool OCCTGccAnaPnt2dBisec(double p1x, double p1y, double p2x, double p2y,
                          double* outPx, double* outPy, double* outDx, double* outDy);

/// Angle bisectors between two lines.
/// @param l1px, l1py, l1dx, l1dy First line (point + direction)
/// @param l2px, l2py, l2dx, l2dy Second line (point + direction)
/// @param out Output array for line solutions
/// @param max Max solutions to return
/// @return Number of solutions
int32_t OCCTGccAnaLin2dBisec(double l1px, double l1py, double l1dx, double l1dy,
                             double l2px, double l2py, double l2dx, double l2dy,
                             OCCTGccLineSolution* out, int32_t max);

/// Bisector between a line and a point (returns a parabola as GccInt_Bisec).
/// @return Bisector type, with properties stored in solution
bool OCCTGccAnaLinPnt2dBisec(double lpx, double lpy, double ldx, double ldy,
                             double px, double py,
                             OCCTBisecSolution* out);

/// Bisectors between two circles.
/// @return Number of solutions
int32_t OCCTGccAnaCirc2dBisec(double c1x, double c1y, double c1r,
                              double c2x, double c2y, double c2r,
                              OCCTBisecSolution* out, int32_t max);

/// Bisectors between a circle and a line.
/// @return Number of solutions
int32_t OCCTGccAnaCircLin2dBisec(double cx, double cy, double cr,
                                 double lpx, double lpy, double ldx, double ldy,
                                 OCCTBisecSolution* out, int32_t max);

/// Bisectors between a circle and a point.
/// @return Number of solutions
int32_t OCCTGccAnaCircPnt2dBisec(double cx, double cy, double cr,
                                 double px, double py,
                                 OCCTBisecSolution* out, int32_t max);

// --- GccAna Line Solvers ---

/// Line through a point parallel to a reference line.
/// @return Number of solutions
int32_t OCCTGccAnaLin2dTanParPt(double px, double py,
                                double lpx, double lpy, double ldx, double ldy,
                                OCCTGccLineSolution* out, int32_t max);

/// Line tangent to a circle, parallel to a reference line.
/// @return Number of solutions
int32_t OCCTGccAnaLin2dTanParCirc(double cx, double cy, double cr, int32_t qualifier,
                                  double lpx, double lpy, double ldx, double ldy,
                                  OCCTGccLineSolution* out, int32_t max);

/// Line through a point perpendicular to a reference line.
/// @return Number of solutions
int32_t OCCTGccAnaLin2dTanPerPtLin(double px, double py,
                                   double lpx, double lpy, double ldx, double ldy,
                                   OCCTGccLineSolution* out, int32_t max);

/// Line tangent to a circle, perpendicular to a reference line.
/// @return Number of solutions
int32_t OCCTGccAnaLin2dTanPerCircLin(double cx, double cy, double cr, int32_t qualifier,
                                     double lpx, double lpy, double ldx, double ldy,
                                     OCCTGccLineSolution* out, int32_t max);

/// Line through a point at an angle to a reference line.
/// @return Number of solutions
int32_t OCCTGccAnaLin2dTanOblPt(double px, double py,
                                double lpx, double lpy, double ldx, double ldy,
                                double angle,
                                OCCTGccLineSolution* out, int32_t max);

/// Line tangent to a curve at an angle to a reference line (Geom2dGcc version).
/// @return Number of solutions
int32_t OCCTGeom2dGccLin2dTanObl(OCCTCurve2DRef curve, int32_t qualifier,
                                 double lpx, double lpy, double ldx, double ldy,
                                 double tolerance, double angle,
                                 OCCTGccLineSolution* out, int32_t max);

// --- GccAna Circle Solvers ---

/// Circle tangent to 2 lines, center on a line.
/// @return Number of solutions
int32_t OCCTGccAnaCirc2d2TanOnLinLin(double l1px, double l1py, double l1dx, double l1dy, int32_t q1,
                                     double l2px, double l2py, double l2dx, double l2dy, int32_t q2,
                                     double onPx, double onPy, double onDx, double onDy,
                                     double tolerance,
                                     OCCTGccCircleSolution* out, int32_t max);

/// Circle tangent to line, center on line, given radius.
/// @return Number of solutions
int32_t OCCTGccAnaCirc2dTanOnRadLin(double lpx, double lpy, double ldx, double ldy, int32_t qualifier,
                                    double onPx, double onPy, double onDx, double onDy,
                                    double radius, double tolerance,
                                    OCCTGccCircleSolution* out, int32_t max);

// --- Geom2dGcc Circle Solvers ---

/// Circle tangent to 2 curves, center on curve (Geom2dGcc).
/// @return Number of solutions
int32_t OCCTGeom2dGccCirc2d2TanOn(OCCTCurve2DRef c1, int32_t q1,
                                  OCCTCurve2DRef c2, int32_t q2,
                                  OCCTCurve2DRef onCurve,
                                  double tolerance,
                                  double initParam1, double initParam2, double initParamOn,
                                  OCCTGccCircleSolution* out, int32_t max);

/// Circle tangent to curve, center on curve, given radius (Geom2dGcc).
/// @return Number of solutions
int32_t OCCTGeom2dGccCirc2dTanOnRad(OCCTCurve2DRef curve, int32_t qualifier,
                                    OCCTCurve2DRef onCurve,
                                    double radius, double tolerance,
                                    OCCTGccCircleSolution* out, int32_t max);

// --- IntAna2d_AnaIntersection ---

/// 2D intersection point result
typedef struct {
    double x, y;        ///< Intersection point
    double param1;      ///< Parameter on first curve
    double param2;      ///< Parameter on second curve
} OCCTIntAna2dPoint;

/// Intersect two 2D lines.
/// @return Number of intersection points
int32_t OCCTIntAna2dLinLin(double l1px, double l1py, double l1dx, double l1dy,
                           double l2px, double l2py, double l2dx, double l2dy,
                           OCCTIntAna2dPoint* out, int32_t max);

/// Intersect a 2D line and circle.
/// @return Number of intersection points
int32_t OCCTIntAna2dLinCirc(double lpx, double lpy, double ldx, double ldy,
                            double cx, double cy, double cr,
                            OCCTIntAna2dPoint* out, int32_t max);

/// Intersect two 2D circles.
/// @return Number of intersection points
int32_t OCCTIntAna2dCircCirc(double c1x, double c1y, double c1r,
                             double c2x, double c2y, double c2r,
                             OCCTIntAna2dPoint* out, int32_t max);

// --- Extrema 2D ---

/// 2D extrema result point
typedef struct {
    double squareDistance;
    double param1;       ///< Parameter on first curve
    double param2;       ///< Parameter on second curve
    double p1x, p1y;    ///< Point on first curve
    double p2x, p2y;    ///< Point on second curve
} OCCTExtrema2dResult;

/// Distance between two 2D lines (checks parallel).
/// @param outIsParallel Set to true if lines are parallel
/// @return Number of extrema (-1 on error)
int32_t OCCTExtremaExtElC2dLinLin(double l1px, double l1py, double l1dx, double l1dy,
                                  double l2px, double l2py, double l2dx, double l2dy,
                                  double tolerance,
                                  bool* outIsParallel,
                                  OCCTExtrema2dResult* out, int32_t max);

/// Distance between a 2D line and circle.
/// @return Number of extrema
int32_t OCCTExtremaExtElC2dLinCirc(double lpx, double lpy, double ldx, double ldy,
                                   double cx, double cy, double cr,
                                   double tolerance,
                                   OCCTExtrema2dResult* out, int32_t max);

/// Closest point(s) on a 2D circle to a point.
/// @return Number of extrema
int32_t OCCTExtremaExtPElC2dCirc(double px, double py,
                                 double cx, double cy, double cr,
                                 double tolerance,
                                 OCCTExtrema2dResult* out, int32_t max);

/// Closest point(s) on a 2D line to a point.
/// @return Number of extrema
int32_t OCCTExtremaExtPElC2dLin(double px, double py,
                                double lpx, double lpy, double ldx, double ldy,
                                double tolerance,
                                OCCTExtrema2dResult* out, int32_t max);

/// Distance between two 2D curves (Extrema_ExtCC2d).
/// @return Number of extrema
int32_t OCCTExtremaExtCC2d(OCCTCurve2DRef c1, double first1, double last1,
                           OCCTCurve2DRef c2, double first2, double last2,
                           OCCTExtrema2dResult* out, int32_t max);

// --- Geom2dLProp_NumericCurInf2d ---

/// Curvature inflection/extremum point result
typedef struct {
    double parameter;
    int32_t type;   ///< 0 = curvature minimum, 1 = curvature maximum, 2 = inflection
} OCCTCurInfPoint;

/// Find curvature extrema on a 2D curve.
/// @return Number of extrema found
int32_t OCCTGeom2dLPropCurExt(OCCTCurve2DRef curve,
                              OCCTCurInfPoint* out, int32_t max);

/// Find inflection points on a 2D curve.
/// @return Number of inflection points found
int32_t OCCTGeom2dLPropCurInf(OCCTCurve2DRef curve,
                              OCCTCurInfPoint* out, int32_t max);

// --- Bisector_BisecAna ---

/// Compute analytical bisector between two 2D curves.
/// @return A 2D curve representing the bisector, or NULL on failure
OCCTCurve2DRef _Nullable OCCTBisectorBisecAnaCurveCurve(
    OCCTCurve2DRef curve1, OCCTCurve2DRef curve2,
    double px, double py,
    double v1x, double v1y, double v2x, double v2y,
    double sense, double tolerance);

/// Compute analytical bisector between a 2D curve and a point.
/// @return A 2D curve representing the bisector, or NULL on failure
OCCTCurve2DRef _Nullable OCCTBisectorBisecAnaCurvePoint(
    OCCTCurve2DRef curve,
    double ptx, double pty,
    double px, double py,
    double v1x, double v1y, double v2x, double v2y,
    double sense, double tolerance);

/// Compute analytical bisector between two points.
/// @return A 2D curve (line) representing the bisector, or NULL on failure
OCCTCurve2DRef _Nullable OCCTBisectorBisecAnaPointPoint(
    double pt1x, double pt1y,
    double pt2x, double pt2y,
    double px, double py,
    double v1x, double v1y, double v2x, double v2y,
    double sense, double tolerance);

// MARK: - TDF Label Properties (v0.54.0)

/// Get the tag of a label.
/// @return Tag integer, or -1 if label is invalid
int32_t OCCTDocumentLabelTag(OCCTDocumentRef doc, int64_t labelId);

/// Get the depth of a label in the tree.
/// @return Depth (root=0, main=1, etc.), or -1 if invalid
int32_t OCCTDocumentLabelDepth(OCCTDocumentRef doc, int64_t labelId);

/// Check if a label is null.
bool OCCTDocumentLabelIsNull(OCCTDocumentRef doc, int64_t labelId);

/// Check if a label is the root label (0:).
bool OCCTDocumentLabelIsRoot(OCCTDocumentRef doc, int64_t labelId);

/// Get the father (parent) label of a label.
/// @return Parent labelId, or -1 if root or invalid
int64_t OCCTDocumentLabelFather(OCCTDocumentRef doc, int64_t labelId);

/// Get the root label of a label's data framework.
/// @return Root labelId
int64_t OCCTDocumentLabelRoot(OCCTDocumentRef doc, int64_t labelId);

/// Check if a label has any attributes.
bool OCCTDocumentLabelHasAttribute(OCCTDocumentRef doc, int64_t labelId);

/// Get the number of attributes on a label.
int32_t OCCTDocumentLabelNbAttributes(OCCTDocumentRef doc, int64_t labelId);

/// Check if a label has any child labels.
bool OCCTDocumentLabelHasChild(OCCTDocumentRef doc, int64_t labelId);

/// Get the number of direct child labels.
int32_t OCCTDocumentLabelNbChildren(OCCTDocumentRef doc, int64_t labelId);

/// Find or create a child label by tag.
/// @param tag The tag to find
/// @param create If true, create the child if it doesn't exist
/// @return Child labelId, or -1 if not found and create is false
int64_t OCCTDocumentLabelFindChild(OCCTDocumentRef doc, int64_t labelId, int32_t tag, bool create);

/// Remove all attributes from a label.
/// @param clearChildren If true, also clears attributes from child labels
void OCCTDocumentLabelForgetAllAttributes(OCCTDocumentRef doc, int64_t labelId, bool clearChildren);

/// Get all descendant labels using TDF_ChildIterator.
/// @param allLevels If true, iterate all descendants; if false, direct children only
/// @param outLabelIds Output array of labelIds
/// @param maxCount Maximum number of labels to return
/// @return Number of labels found
int32_t OCCTDocumentGetDescendantLabels(OCCTDocumentRef doc, int64_t labelId,
                                         bool allLevels,
                                         int64_t* outLabelIds, int32_t maxCount);

// MARK: - TDF Label Name (v0.54.0)

/// Set the name (TDataStd_Name) on a label.
/// @param name The name string to set
/// @return true on success
bool OCCTDocumentSetLabelName(OCCTDocumentRef doc, int64_t labelId, const char* name);

// MARK: - TDF Reference (v0.54.0)

/// Set a TDF_Reference attribute on a label, pointing to another label.
/// @param labelId The label to set the reference on
/// @param targetLabelId The label being referenced
/// @return true on success
bool OCCTDocumentLabelSetReference(OCCTDocumentRef doc, int64_t labelId, int64_t targetLabelId);

/// Get the referenced label from a TDF_Reference attribute.
/// @return Referenced labelId, or -1 if no reference attribute
int64_t OCCTDocumentLabelGetReference(OCCTDocumentRef doc, int64_t labelId);

// MARK: - TDF CopyLabel (v0.54.0)

/// Copy a label and its attributes to a destination label.
/// @param sourceLabelId Source label to copy from
/// @param destLabelId Destination label to copy to
/// @return true if copy succeeded
bool OCCTDocumentCopyLabel(OCCTDocumentRef doc, int64_t sourceLabelId, int64_t destLabelId);

// MARK: - Document Main Label (v0.54.0)

/// Get the main label (0:1) of the document.
/// @return Main labelId
int64_t OCCTDocumentGetMainLabel(OCCTDocumentRef doc);

// MARK: - Document Transactions (v0.54.0)

/// Open a new transaction (command) on the document.
void OCCTDocumentOpenTransaction(OCCTDocumentRef doc);

/// Commit the current transaction.
/// @return true if committed successfully
bool OCCTDocumentCommitTransaction(OCCTDocumentRef doc);

/// Abort the current transaction, undoing all changes since OpenTransaction.
void OCCTDocumentAbortTransaction(OCCTDocumentRef doc);

/// Check if a transaction is currently open.
bool OCCTDocumentHasOpenTransaction(OCCTDocumentRef doc);

// MARK: - Document Undo/Redo (v0.54.0)

/// Set the maximum number of undo steps.
void OCCTDocumentSetUndoLimit(OCCTDocumentRef doc, int32_t limit);

/// Get the maximum number of undo steps.
int32_t OCCTDocumentGetUndoLimit(OCCTDocumentRef doc);

/// Perform undo.
/// @return true if undo was performed
bool OCCTDocumentUndo(OCCTDocumentRef doc);

/// Perform redo.
/// @return true if redo was performed
bool OCCTDocumentRedo(OCCTDocumentRef doc);

/// Get the number of available undo steps.
int32_t OCCTDocumentGetAvailableUndos(OCCTDocumentRef doc);

/// Get the number of available redo steps.
int32_t OCCTDocumentGetAvailableRedos(OCCTDocumentRef doc);

// MARK: - Document Modified Labels (v0.54.0)

/// Mark a label as modified.
void OCCTDocumentSetModified(OCCTDocumentRef doc, int64_t labelId);

/// Clear all modification marks.
void OCCTDocumentClearModified(OCCTDocumentRef doc);

/// Check if a label is marked as modified (via TDocStd_Modified on root).
/// Note: This uses TDocStd_Document::GetModified(), not TDocStd_Modified attribute directly.
bool OCCTDocumentIsLabelModified(OCCTDocumentRef doc, int64_t labelId);

// MARK: - TDataStd Scalar Attributes (v0.55.0)

/// Set an integer attribute (TDataStd_Integer) on a label.
bool OCCTDocumentSetIntegerAttr(OCCTDocumentRef doc, int64_t labelId, int32_t value);

/// Get the integer attribute from a label.
bool OCCTDocumentGetIntegerAttr(OCCTDocumentRef doc, int64_t labelId, int32_t* outValue);

/// Set a real attribute (TDataStd_Real) on a label.
bool OCCTDocumentSetRealAttr(OCCTDocumentRef doc, int64_t labelId, double value);

/// Get the real attribute from a label.
bool OCCTDocumentGetRealAttr(OCCTDocumentRef doc, int64_t labelId, double* outValue);

/// Set an ASCII string attribute (TDataStd_AsciiString) on a label.
bool OCCTDocumentSetAsciiStringAttr(OCCTDocumentRef doc, int64_t labelId, const char* value);

/// Get the ASCII string attribute from a label. Caller must free with OCCTStringFree.
const char* OCCTDocumentGetAsciiStringAttr(OCCTDocumentRef doc, int64_t labelId);

/// Set a comment attribute (TDataStd_Comment) on a label.
bool OCCTDocumentSetCommentAttr(OCCTDocumentRef doc, int64_t labelId, const char* value);

/// Get the comment attribute from a label. Caller must free with OCCTStringFree.
const char* OCCTDocumentGetCommentAttr(OCCTDocumentRef doc, int64_t labelId);

// MARK: - TDataStd Integer Array (v0.55.0)

/// Initialize an integer array attribute on a label.
bool OCCTDocumentInitIntegerArray(OCCTDocumentRef doc, int64_t labelId, int32_t lower, int32_t upper);

/// Set a value in an integer array attribute.
bool OCCTDocumentSetIntegerArrayValue(OCCTDocumentRef doc, int64_t labelId, int32_t index, int32_t value);

/// Get a value from an integer array attribute.
bool OCCTDocumentGetIntegerArrayValue(OCCTDocumentRef doc, int64_t labelId, int32_t index, int32_t* outValue);

/// Get the bounds of an integer array attribute.
bool OCCTDocumentGetIntegerArrayBounds(OCCTDocumentRef doc, int64_t labelId, int32_t* outLower, int32_t* outUpper);

// MARK: - TDataStd Real Array (v0.55.0)

/// Initialize a real array attribute on a label.
bool OCCTDocumentInitRealArray(OCCTDocumentRef doc, int64_t labelId, int32_t lower, int32_t upper);

/// Set a value in a real array attribute.
bool OCCTDocumentSetRealArrayValue(OCCTDocumentRef doc, int64_t labelId, int32_t index, double value);

/// Get a value from a real array attribute.
bool OCCTDocumentGetRealArrayValue(OCCTDocumentRef doc, int64_t labelId, int32_t index, double* outValue);

/// Get the bounds of a real array attribute.
bool OCCTDocumentGetRealArrayBounds(OCCTDocumentRef doc, int64_t labelId, int32_t* outLower, int32_t* outUpper);

// MARK: - TDataStd TreeNode (v0.55.0)

/// Set a tree node attribute (TDataStd_TreeNode) on a label.
bool OCCTDocumentSetTreeNode(OCCTDocumentRef doc, int64_t labelId);

/// Append a child tree node under a parent tree node.
bool OCCTDocumentAppendTreeChild(OCCTDocumentRef doc, int64_t parentLabelId, int64_t childLabelId);

/// Get the father (parent) of a tree node.
int64_t OCCTDocumentTreeNodeFather(OCCTDocumentRef doc, int64_t labelId);

/// Get the first child of a tree node.
int64_t OCCTDocumentTreeNodeFirst(OCCTDocumentRef doc, int64_t labelId);

/// Get the next sibling of a tree node.
int64_t OCCTDocumentTreeNodeNext(OCCTDocumentRef doc, int64_t labelId);

/// Check if a tree node has a father.
bool OCCTDocumentTreeNodeHasFather(OCCTDocumentRef doc, int64_t labelId);

/// Get the depth of a tree node (root=0).
int32_t OCCTDocumentTreeNodeDepth(OCCTDocumentRef doc, int64_t labelId);

/// Get the number of children of a tree node.
int32_t OCCTDocumentTreeNodeNbChildren(OCCTDocumentRef doc, int64_t labelId);

// MARK: - TDataStd NamedData (v0.55.0)

/// Set an integer value in a NamedData attribute.
bool OCCTDocumentNamedDataSetInteger(OCCTDocumentRef doc, int64_t labelId, const char* name, int32_t value);

/// Get an integer value from a NamedData attribute.
bool OCCTDocumentNamedDataGetInteger(OCCTDocumentRef doc, int64_t labelId, const char* name, int32_t* outValue);

/// Check if a named integer exists in a NamedData attribute.
bool OCCTDocumentNamedDataHasInteger(OCCTDocumentRef doc, int64_t labelId, const char* name);

/// Set a real value in a NamedData attribute.
bool OCCTDocumentNamedDataSetReal(OCCTDocumentRef doc, int64_t labelId, const char* name, double value);

/// Get a real value from a NamedData attribute.
bool OCCTDocumentNamedDataGetReal(OCCTDocumentRef doc, int64_t labelId, const char* name, double* outValue);

/// Check if a named real exists in a NamedData attribute.
bool OCCTDocumentNamedDataHasReal(OCCTDocumentRef doc, int64_t labelId, const char* name);

/// Set a string value in a NamedData attribute.
bool OCCTDocumentNamedDataSetString(OCCTDocumentRef doc, int64_t labelId, const char* name, const char* value);

/// Get a string value from a NamedData attribute. Caller must free with OCCTStringFree.
const char* OCCTDocumentNamedDataGetString(OCCTDocumentRef doc, int64_t labelId, const char* name);

/// Check if a named string exists in a NamedData attribute.
bool OCCTDocumentNamedDataHasString(OCCTDocumentRef doc, int64_t labelId, const char* name);

// MARK: - TDataXtd Shape Attribute (v0.56.0)

/// Set a shape attribute on a label (stores shape via TNaming).
bool OCCTDocumentSetShapeAttr(OCCTDocumentRef doc, int64_t labelId, OCCTShapeRef shape);

/// Get the shape stored in a TDataXtd_Shape attribute on a label.
OCCTShapeRef OCCTDocumentGetShapeAttr(OCCTDocumentRef doc, int64_t labelId);

/// Check if a label has a TDataXtd_Shape attribute.
bool OCCTDocumentHasShapeAttr(OCCTDocumentRef doc, int64_t labelId);

// MARK: - TDataXtd Position Attribute (v0.56.0)

/// Set a position (3D point) attribute on a label.
bool OCCTDocumentSetPositionAttr(OCCTDocumentRef doc, int64_t labelId, double x, double y, double z);

/// Get the position attribute from a label.
bool OCCTDocumentGetPositionAttr(OCCTDocumentRef doc, int64_t labelId, double* outX, double* outY, double* outZ);

/// Check if a label has a TDataXtd_Position attribute.
bool OCCTDocumentHasPositionAttr(OCCTDocumentRef doc, int64_t labelId);

// MARK: - TDataXtd Geometry Attribute (v0.56.0)

/// Set a geometry type attribute on a label. Type values:
/// 0=ANY_GEOM, 1=POINT, 2=LINE, 3=CIRCLE, 4=ELLIPSE, 5=SPLINE, 6=PLANE, 7=CYLINDER
bool OCCTDocumentSetGeometryAttr(OCCTDocumentRef doc, int64_t labelId, int32_t geometryType);

/// Get the geometry type from a label. Returns -1 if not found.
int32_t OCCTDocumentGetGeometryType(OCCTDocumentRef doc, int64_t labelId);

/// Check if a label has a TDataXtd_Geometry attribute.
bool OCCTDocumentHasGeometryAttr(OCCTDocumentRef doc, int64_t labelId);

// MARK: - TDataXtd Triangulation Attribute (v0.56.0)

/// Set a triangulation attribute on a label by meshing a shape.
bool OCCTDocumentSetTriangulationFromShape(OCCTDocumentRef doc, int64_t labelId, OCCTShapeRef shape, double deflection);

/// Get the number of nodes in a triangulation attribute.
int32_t OCCTDocumentTriangulationNbNodes(OCCTDocumentRef doc, int64_t labelId);

/// Get the number of triangles in a triangulation attribute.
int32_t OCCTDocumentTriangulationNbTriangles(OCCTDocumentRef doc, int64_t labelId);

/// Get the deflection of a triangulation attribute.
double OCCTDocumentTriangulationDeflection(OCCTDocumentRef doc, int64_t labelId);

// MARK: - TDataXtd Point/Axis/Plane Attributes (v0.56.0)

/// Set a point attribute on a label.
bool OCCTDocumentSetPointAttr(OCCTDocumentRef doc, int64_t labelId, double x, double y, double z);

/// Set an axis attribute on a label (origin + direction).
bool OCCTDocumentSetAxisAttr(OCCTDocumentRef doc, int64_t labelId, double ox, double oy, double oz, double dx, double dy, double dz);

/// Set a plane attribute on a label (origin + normal).
bool OCCTDocumentSetPlaneAttr(OCCTDocumentRef doc, int64_t labelId, double ox, double oy, double oz, double nx, double ny, double nz);

// MARK: - TFunction Logbook (v0.56.0)

/// Create a TFunction_Logbook attribute on a label.
bool OCCTDocumentSetLogbook(OCCTDocumentRef doc, int64_t labelId);

/// Mark a label as touched in the logbook.
bool OCCTDocumentLogbookSetTouched(OCCTDocumentRef doc, int64_t logbookLabelId, int64_t targetLabelId);

/// Mark a label as impacted in the logbook.
bool OCCTDocumentLogbookSetImpacted(OCCTDocumentRef doc, int64_t logbookLabelId, int64_t targetLabelId);

/// Check if a label is modified (touched) in the logbook.
bool OCCTDocumentLogbookIsModified(OCCTDocumentRef doc, int64_t logbookLabelId, int64_t targetLabelId);

/// Clear the logbook.
bool OCCTDocumentLogbookClear(OCCTDocumentRef doc, int64_t logbookLabelId);

/// Check if the logbook is empty.
bool OCCTDocumentLogbookIsEmpty(OCCTDocumentRef doc, int64_t logbookLabelId);

// MARK: - TFunction GraphNode (v0.56.0)

/// Create a TFunction_GraphNode attribute on a label.
bool OCCTDocumentSetGraphNode(OCCTDocumentRef doc, int64_t labelId);

/// Add a previous dependency to a graph node (by tag ID).
bool OCCTDocumentGraphNodeAddPrevious(OCCTDocumentRef doc, int64_t labelId, int32_t prevTag);

/// Add a next dependency to a graph node (by tag ID).
bool OCCTDocumentGraphNodeAddNext(OCCTDocumentRef doc, int64_t labelId, int32_t nextTag);

/// Set the execution status of a graph node.
/// 0=WrongDefinition, 1=NotExecuted, 2=Executing, 3=Succeeded, 4=Failed
bool OCCTDocumentGraphNodeSetStatus(OCCTDocumentRef doc, int64_t labelId, int32_t status);

/// Get the execution status of a graph node. Returns -1 if not found.
int32_t OCCTDocumentGraphNodeGetStatus(OCCTDocumentRef doc, int64_t labelId);

/// Remove all previous dependencies from a graph node.
bool OCCTDocumentGraphNodeRemoveAllPrevious(OCCTDocumentRef doc, int64_t labelId);

/// Remove all next dependencies from a graph node.
bool OCCTDocumentGraphNodeRemoveAllNext(OCCTDocumentRef doc, int64_t labelId);

// MARK: - TFunction Function Attribute (v0.56.0)

/// Create a TFunction_Function attribute on a label.
bool OCCTDocumentSetFunctionAttr(OCCTDocumentRef doc, int64_t labelId);

/// Check if a function attribute has failed.
bool OCCTDocumentFunctionIsFailed(OCCTDocumentRef doc, int64_t labelId);

/// Get the failure mode of a function attribute. Returns -1 if not found.
int32_t OCCTDocumentFunctionGetFailure(OCCTDocumentRef doc, int64_t labelId);

/// Set the failure mode of a function attribute.
bool OCCTDocumentFunctionSetFailure(OCCTDocumentRef doc, int64_t labelId, int32_t mode);

// MARK: - TNaming CopyShape (v0.56.0)

/// Deep copy a shape (creates independent copy with new topology).
OCCTShapeRef OCCTShapeDeepCopy(OCCTShapeRef shape);

// MARK: - OCAF Persistence — Format Registration (v0.57.0)

/// Register binary OCAF format drivers (BinOcaf).
void OCCTDocumentDefineFormatBin(OCCTDocumentRef doc);

/// Register lite binary OCAF format drivers (BinLOcaf).
void OCCTDocumentDefineFormatBinL(OCCTDocumentRef doc);

/// Register XML OCAF format drivers (XmlOcaf).
void OCCTDocumentDefineFormatXml(OCCTDocumentRef doc);

/// Register lite XML OCAF format drivers (XmlLOcaf).
void OCCTDocumentDefineFormatXmlL(OCCTDocumentRef doc);

/// Register binary XCAF format drivers (BinXCAF).
void OCCTDocumentDefineFormatBinXCAF(OCCTDocumentRef doc);

/// Register XML XCAF format drivers (XmlXCAF).
void OCCTDocumentDefineFormatXmlXCAF(OCCTDocumentRef doc);

// MARK: - OCAF Persistence — Save/Load (v0.57.0)

/// Save OCAF document to file. Returns PCDM_StoreStatus (0=OK).
/// Format is determined by the document's storage format.
int32_t OCCTDocumentSaveOCAF(OCCTDocumentRef doc, const char* path);

/// Load OCAF document from file. Returns a new document ref, or NULL on failure.
/// The outStatus receives PCDM_ReaderStatus (0=OK).
OCCTDocumentRef OCCTDocumentLoadOCAF(const char* path, int32_t* outStatus);

/// Save current OCAF document in-place (to previously saved path).
/// Returns PCDM_StoreStatus (0=OK), or -1 if not previously saved.
int32_t OCCTDocumentSaveOCAFInPlace(OCCTDocumentRef doc);

// MARK: - OCAF Document Metadata (v0.57.0)

/// Check if the document has been saved.
bool OCCTDocumentIsSaved(OCCTDocumentRef doc);

/// Get the storage format of the document. Caller must free with OCCTStringFree.
const char* OCCTDocumentGetStorageFormat(OCCTDocumentRef doc);

/// Change the storage format of the document.
bool OCCTDocumentSetStorageFormat(OCCTDocumentRef doc, const char* format);

/// Get the number of documents in the application.
int32_t OCCTDocumentNbDocuments(OCCTDocumentRef doc);

/// Get the list of available reading formats. Returns count.
/// Each format string is written to outFormats (up to maxFormats). Caller must free strings with OCCTStringFree.
int32_t OCCTDocumentReadingFormats(OCCTDocumentRef doc, const char** outFormats, int32_t maxFormats);

/// Get the list of available writing formats. Returns count.
int32_t OCCTDocumentWritingFormats(OCCTDocumentRef doc, const char** outFormats, int32_t maxFormats);

/// Create a new OCAF document with a specific format. Returns a new document ref.
/// Supported formats: "BinOcaf", "XmlOcaf", "BinLOcaf", "XmlLOcaf", "BinXCAF", "XmlXCAF".
OCCTDocumentRef OCCTDocumentCreateWithFormat(const char* format);

// MARK: - STEP Full Coverage — STEPControl_Writer (v0.58.0)

/// Export shape to STEP with specific model type.
/// modelType: 0=AsIs, 1=ManifoldSolidBrep, 2=BrepWithVoids, 3=FacetedBrep,
///            5=ShellBasedSurfaceModel, 6=GeometricCurveSet
bool OCCTExportSTEPWithMode(OCCTShapeRef shape, const char* path, int32_t modelType);

/// Export shape to STEP with model type and tolerance.
bool OCCTExportSTEPWithModeAndTolerance(OCCTShapeRef shape, const char* path,
                                         int32_t modelType, double tolerance);

/// Export shape to STEP and clean duplicate entities before writing.
bool OCCTExportSTEPCleanDuplicates(OCCTShapeRef shape, const char* path, int32_t modelType);

// MARK: - STEP Full Coverage — STEPControl_Reader (v0.58.0)

/// Read a STEP file and return the number of transferable roots.
int32_t OCCTSTEPReaderNbRoots(const char* path);

/// Import a specific root from a STEP file (1-based index).
OCCTShapeRef OCCTImportSTEPRoot(const char* path, int32_t rootIndex);

/// Import a STEP file with a specific system length unit (in meters, e.g. 0.001 for mm).
OCCTShapeRef OCCTImportSTEPWithUnit(const char* path, double unitInMeters);

/// Read a STEP file and return the number of shapes after full transfer.
int32_t OCCTSTEPReaderNbShapes(const char* path);

// MARK: - STEP Full Coverage — STEPCAFControl Modes (v0.58.0)

/// Load STEP file into XDE document with individual mode control.
/// All mode flags: true=enabled, false=disabled.
OCCTDocumentRef OCCTDocumentLoadSTEPWithModes(const char* path,
    bool colorMode, bool nameMode, bool layerMode,
    bool propsMode, bool gdtMode, bool matMode);

/// Write XDE document to STEP with model type and individual mode control.
/// modelType: 0=AsIs, 1=ManifoldSolidBrep, etc.
bool OCCTDocumentWriteSTEPWithModes(OCCTDocumentRef doc, const char* path,
    int32_t modelType, bool colorMode, bool nameMode, bool layerMode,
    bool dimTolMode, bool materialMode);

// MARK: - IGES Full Coverage — Reader (v0.59.0)

/// Read an IGES file and return the number of transferable roots.
int32_t OCCTIGESReaderNbRoots(const char* path);

/// Import a specific root from an IGES file (1-based index).
OCCTShapeRef OCCTImportIGESRoot(const char* path, int32_t rootIndex);

/// Read an IGES file and return the number of shapes after full transfer.
int32_t OCCTIGESReaderNbShapes(const char* path);

/// Import only visible entities from an IGES file.
OCCTShapeRef OCCTImportIGESVisible(const char* path);

// MARK: - IGES Full Coverage — Writer (v0.59.0)

/// Export shape to IGES with specific unit. unit: "MM", "IN", "M", "FT", etc.
bool OCCTExportIGESWithUnit(OCCTShapeRef shape, const char* path, const char* unit);

/// Export shape to IGES in BRep mode (vs default Faces mode).
bool OCCTExportIGESBRepMode(OCCTShapeRef shape, const char* path);

/// Export multiple shapes to a single IGES file.
bool OCCTExportIGESMultiShape(const OCCTShapeRef* shapes, int32_t count, const char* path);

// MARK: - OBJ Document I/O (v0.59.0)

/// Load an OBJ file into an XDE document (preserves materials, names).
OCCTDocumentRef OCCTDocumentLoadOBJ(const char* path);

/// Load an OBJ file into an XDE document with options.
/// singlePrecision: true for float, false for double vertex coords.
/// systemLengthUnit: length unit in meters (e.g. 0.001 for mm). 0 = default.
OCCTDocumentRef OCCTDocumentLoadOBJWithOptions(const char* path,
    bool singlePrecision, double systemLengthUnit);

/// Write an XDE document to OBJ format.
/// deflection: mesh deflection for tessellation. 0 = skip re-meshing.
bool OCCTDocumentWriteOBJ(OCCTDocumentRef doc, const char* path, double deflection);

// MARK: - PLY Export Expansion (v0.59.0)

/// Export an XDE document to PLY format with options.
bool OCCTDocumentWritePLY(OCCTDocumentRef doc, const char* path, double deflection,
    bool normals, bool colors, bool texCoords);

/// Export a shape to PLY format with normals/colors/texCoords options.
bool OCCTExportPLYWithOptions(OCCTShapeRef shape, const char* path, double deflection,
    bool normals, bool colors, bool texCoords);

// MARK: - RWMesh Coordinate System (v0.59.0)

/// Coordinate system enum values:
/// -1=Undefined, 0=posYfwd_posZup (Blender/Zup), 1=negZfwd_posYup (glTF/Yup)

/// Load an OBJ file into an XDE document with coordinate system conversion.
/// inputCS and outputCS: -1=Undefined, 0=Zup/Blender, 1=Yup/glTF
OCCTDocumentRef OCCTDocumentLoadOBJWithCS(const char* path,
    int32_t inputCS, int32_t outputCS, double inputLengthUnit, double outputLengthUnit);

// MARK: - XDE ShapeTool Expansion (v0.60.0)

/// Get total number of shapes in the document (all levels).
int32_t OCCTDocumentGetShapeCount(OCCTDocumentRef doc);

/// Get label ID for a shape at index (from GetShapes sequence).
int64_t OCCTDocumentGetShapeLabelId(OCCTDocumentRef doc, int32_t index);

/// Get total number of free (top-level) shapes.
int32_t OCCTDocumentGetFreeShapeCount(OCCTDocumentRef doc);

/// Get label ID for a free shape at index.
int64_t OCCTDocumentGetFreeShapeLabelId(OCCTDocumentRef doc, int32_t index);

/// Check if a label is top-level.
bool OCCTDocumentIsTopLevel(OCCTDocumentRef doc, int64_t labelId);

/// Check if a label is a component (instance inside an assembly).
bool OCCTDocumentIsComponent(OCCTDocumentRef doc, int64_t labelId);

/// Check if a label represents a compound shape.
bool OCCTDocumentIsCompound(OCCTDocumentRef doc, int64_t labelId);

/// Check if a label represents a sub-shape of a top-level shape.
bool OCCTDocumentIsSubShape(OCCTDocumentRef doc, int64_t labelId);

/// Find label ID for a given shape in the document.
/// @return Label ID, or -1 if not found
int64_t OCCTDocumentFindShape(OCCTDocumentRef doc, OCCTShapeRef shape);

/// Search for a shape in the document (including sub-shapes).
/// @return Label ID, or -1 if not found
int64_t OCCTDocumentSearchShape(OCCTDocumentRef doc, OCCTShapeRef shape);

/// Get number of sub-shapes for a label.
int32_t OCCTDocumentGetSubShapeCount(OCCTDocumentRef doc, int64_t labelId);

/// Get sub-shape label ID at index.
int64_t OCCTDocumentGetSubShapeLabelId(OCCTDocumentRef doc, int64_t labelId, int32_t index);

/// Add a shape to the document.
/// @param makeAssembly If true, compound shapes become assemblies
/// @return Label ID of the added shape
int64_t OCCTDocumentAddShape(OCCTDocumentRef doc, OCCTShapeRef shape, bool makeAssembly);

/// Create a new empty shape label.
int64_t OCCTDocumentNewShape(OCCTDocumentRef doc);

/// Remove a shape from the document.
bool OCCTDocumentRemoveShape(OCCTDocumentRef doc, int64_t labelId);

/// Add a component to an assembly with transform.
/// @param assemblyLabelId Assembly to add to
/// @param shapeLabelId Shape to add as component
/// @param tx, ty, tz Translation
/// @return Label ID of the new component, or -1 on failure
int64_t OCCTDocumentAddComponent(OCCTDocumentRef doc, int64_t assemblyLabelId,
    int64_t shapeLabelId, double tx, double ty, double tz);

// Add a component with a FULL rigid placement from a 12-element row-major matrix
// [r00 r01 r02 r10 r11 r12 r20 r21 r22 tx ty tz]. Returns -1 if the matrix is not a proper rigid
// transform (e.g. a reflection — gp_Trsf can't represent it; the caller should bake a mirrored
// product instead). Issue #174.
int64_t OCCTDocumentAddComponentMatrix(OCCTDocumentRef doc, int64_t assemblyLabelId,
    int64_t shapeLabelId, const double* _Nonnull matrix12);

/// Remove a component from an assembly.
void OCCTDocumentRemoveComponent(OCCTDocumentRef doc, int64_t componentLabelId);

/// Get number of components in an assembly.
int32_t OCCTDocumentGetComponentCount(OCCTDocumentRef doc, int64_t assemblyLabelId);

/// Get component label ID at index.
int64_t OCCTDocumentGetComponentLabelId(OCCTDocumentRef doc, int64_t assemblyLabelId, int32_t index);

/// Get the referred (original) shape label for a component.
/// @return Referred label ID, or -1 if not a reference
int64_t OCCTDocumentGetComponentReferredLabelId(OCCTDocumentRef doc, int64_t componentLabelId);

/// Get number of labels that use (reference) a given shape.
int32_t OCCTDocumentGetShapeUserCount(OCCTDocumentRef doc, int64_t shapeLabelId);

/// Update all assemblies (recompute compounds from components).
void OCCTDocumentUpdateAssemblies(OCCTDocumentRef doc);

/// Expand a compound shape into an assembly (ShapeTool::Expand).
bool OCCTDocumentExpandShape(OCCTDocumentRef doc, int64_t labelId);

// MARK: - XDE ColorTool by Shape (v0.60.0)

/// Set color on a shape (not by label).
/// @param colorType 0=generic, 1=surface, 2=curve
void OCCTDocumentSetShapeColor(OCCTDocumentRef doc, OCCTShapeRef shape,
    int32_t colorType, double r, double g, double b);

/// Get color for a shape (not by label).
/// @return OCCTColor with isSet=true if color was found
OCCTColor OCCTDocumentGetShapeColor(OCCTDocumentRef doc, OCCTShapeRef shape, int32_t colorType);

/// Check if color is set on a shape.
bool OCCTDocumentIsShapeColorSet(OCCTDocumentRef doc, OCCTShapeRef shape, int32_t colorType);

/// Set visibility for a label.
void OCCTDocumentSetLabelVisibility(OCCTDocumentRef doc, int64_t labelId, bool visible);

/// Get visibility for a label.
bool OCCTDocumentGetLabelVisibility(OCCTDocumentRef doc, int64_t labelId);

// MARK: - XDE Area / Volume / Centroid (v0.60.0)

/// Set area attribute on a label.
void OCCTDocumentSetArea(OCCTDocumentRef doc, int64_t labelId, double area);

/// Get area attribute from a label. Returns -1 if not set.
double OCCTDocumentGetArea(OCCTDocumentRef doc, int64_t labelId);

/// Set volume attribute on a label.
void OCCTDocumentSetVolume(OCCTDocumentRef doc, int64_t labelId, double volume);

/// Get volume attribute from a label. Returns -1 if not set.
double OCCTDocumentGetVolume(OCCTDocumentRef doc, int64_t labelId);

/// Set centroid attribute on a label.
void OCCTDocumentSetCentroid(OCCTDocumentRef doc, int64_t labelId, double x, double y, double z);

/// Get centroid attribute from a label. Returns false if not set.
bool OCCTDocumentGetCentroid(OCCTDocumentRef doc, int64_t labelId, double* outX, double* outY, double* outZ);

// MARK: - XDE LayerTool Expansion (v0.60.0)

/// Set a named layer on a label.
void OCCTDocumentSetLayer(OCCTDocumentRef doc, int64_t labelId, const char* layerName);

/// Check if a specific layer is set on a label.
bool OCCTDocumentIsLayerSet(OCCTDocumentRef doc, int64_t labelId, const char* layerName);

/// Get layers on a label. Returns count. Fills outNames (caller-allocated array of buffers).
/// Each buffer must be at least maxLen chars.
int32_t OCCTDocumentGetLabelLayers(OCCTDocumentRef doc, int64_t labelId,
    char** outNames, int32_t maxNames, int32_t maxLen);

/// Find a layer label by name. Returns label ID or -1 if not found.
int64_t OCCTDocumentFindLayer(OCCTDocumentRef doc, const char* layerName);

/// Set visibility for a layer label.
void OCCTDocumentSetLayerVisibility(OCCTDocumentRef doc, int64_t layerLabelId, bool visible);

/// Get visibility for a layer label.
bool OCCTDocumentGetLayerVisibility(OCCTDocumentRef doc, int64_t layerLabelId);

// MARK: - XDE Editor (v0.60.0)

/// Expand a compound shape label into an assembly using XCAFDoc_Editor::Expand.
/// @param recursively If true, expand recursively
/// @return true if expanded successfully
bool OCCTDocumentEditorExpand(OCCTDocumentRef doc, int64_t labelId, bool recursively);

/// Rescale geometry on a label.
/// @param labelId Label to rescale
/// @param scaleFactor Scale factor
/// @param forceIfNotRoot Force rescale even if label is not root
/// @return true on success
bool OCCTDocumentEditorRescaleGeometry(OCCTDocumentRef doc, int64_t labelId,
    double scaleFactor, bool forceIfNotRoot);

// MARK: - Contap — Contour Analysis (v0.61.0)

/// Opaque handle for contour analysis result
typedef struct OCCTContourResult* OCCTContourResultRef;

/// Contour type enum: 0=Line, 1=Circle, 2=Walking, 3=Restriction
/// Compute analytical contours on a sphere with a view direction.
/// @return Number of contours, or -1 on failure. If circle, outCx/Cy/Cz/Cr are filled.
int32_t OCCTContapSphereDir(double cx, double cy, double cz, double radius,
    double dirX, double dirY, double dirZ,
    int32_t* outType, double* outData);

/// Compute analytical contours on a cylinder with a view direction.
int32_t OCCTContapCylinderDir(double px, double py, double pz,
    double axX, double axY, double axZ, double radius,
    double dirX, double dirY, double dirZ,
    int32_t* outType, double* outData);

/// Compute analytical contours on a sphere with an eye point (perspective).
int32_t OCCTContapSphereEye(double cx, double cy, double cz, double radius,
    double eyeX, double eyeY, double eyeZ,
    int32_t* outType, double* outData);

// MARK: - IntCurvesFace — Curve-Face Intersection (v0.61.0)

/// Intersect a line with a face. Returns number of intersection points.
/// outPoints must have space for maxPts * 3 doubles (x,y,z triples).
/// outParams must have space for maxPts doubles (w parameter on line).
int32_t OCCTIntersectLineFace(OCCTShapeRef face,
    double origX, double origY, double origZ,
    double dirX, double dirY, double dirZ,
    double pInf, double pSup,
    double* outPoints, double* outParams, int32_t maxPts);

// MARK: - BOPAlgo — Splitter (v0.61.0)

/// Split shapes by tools. Returns the result shape.
/// @param objects Array of object shapes
/// @param objCount Number of objects
/// @param tools Array of tool shapes
/// @param toolCount Number of tools
/// @return Result shape, or NULL on failure
OCCTShapeRef OCCTBOPAlgoSplit(const OCCTShapeRef* objects, int32_t objCount,
    const OCCTShapeRef* tools, int32_t toolCount);

// MARK: - BOPAlgo — CellsBuilder (v0.61.0)

/// Opaque handle for CellsBuilder
typedef struct OCCTCellsBuilder* OCCTCellsBuilderRef;

/// Create a CellsBuilder, add arguments, and perform splitting.
/// @param shapes Array of input shapes
/// @param count Number of shapes
/// @return CellsBuilder handle, or NULL on failure
OCCTCellsBuilderRef OCCTCellsBuilderCreate(const OCCTShapeRef* shapes, int32_t count);

/// Release a CellsBuilder.
void OCCTCellsBuilderRelease(OCCTCellsBuilderRef builder);

/// Add all split parts to result with a material ID.
void OCCTCellsBuilderAddAllToResult(OCCTCellsBuilderRef builder, int32_t material);

/// Remove all parts from result.
void OCCTCellsBuilderRemoveAllFromResult(OCCTCellsBuilderRef builder);

/// Remove internal boundaries between cells with the same material.
void OCCTCellsBuilderRemoveInternalBoundaries(OCCTCellsBuilderRef builder);

/// Get the current result shape.
OCCTShapeRef OCCTCellsBuilderGetResult(OCCTCellsBuilderRef builder);

// MARK: - BOPAlgo — ArgumentAnalyzer (v0.61.0)

/// Analyze two shapes for Boolean operation validity.
/// @param shape1 First shape (object)
/// @param shape2 Second shape (tool)
/// @param operation 0=FUSE, 1=COMMON, 2=CUT, 3=CUT21, 4=SECTION
/// @return true if shapes are valid for the operation (no faults found)
bool OCCTBOPAlgoAnalyzeArguments(OCCTShapeRef shape1, OCCTShapeRef shape2, int32_t operation);

// MARK: - BRepAdaptor_Curve2d (v0.61.0)

/// Get 2D curve parameters for an edge on a face.
/// @param edge Edge shape
/// @param face Face shape
/// @param outFirst Output first parameter
/// @param outLast Output last parameter
/// @return true if PCurve exists
bool OCCTEdgePCurveParams(OCCTShapeRef edge, OCCTShapeRef face,
    double* outFirst, double* outLast);

/// Evaluate 2D curve point for an edge on a face at parameter t.
/// @return true if successful
bool OCCTEdgePCurveValue(OCCTShapeRef edge, OCCTShapeRef face, double t,
    double* outU, double* outV);

// MARK: - BRepMesh_Deflection (v0.61.0)

/// Compute absolute deflection from relative deflection and max shape size.
double OCCTComputeAbsoluteDeflection(OCCTShapeRef shape, double relativeDeflection, double maxShapeSize);

/// Check if a current deflection is consistent with a required deflection.
bool OCCTDeflectionIsConsistent(double current, double required, bool allowDecrease, double ratio);

// MARK: - Approx_CurveOnSurface (v0.61.0)

/// Approximate a 2D curve on a surface as a 3D BSpline curve.
/// Uses the edge's PCurve on the face.
/// @param edge Edge with PCurve
/// @param face Face with surface
/// @param tolerance Approximation tolerance
/// @param maxSegments Maximum BSpline segments
/// @param maxDegree Maximum BSpline degree
/// @return Approximated 3D shape (edge), or NULL on failure
OCCTShapeRef OCCTApproxCurveOnSurface(OCCTShapeRef edge, OCCTShapeRef face,
    double tolerance, int32_t maxSegments, int32_t maxDegree);

// MARK: - BRepBuilderAPI_MakeShapeOnMesh (v0.61.0)

/// Build a shape from a triangulation mesh.
/// @param points Array of point coordinates (x,y,z triples), length = nodeCount*3
/// @param nodeCount Number of nodes
/// @param triangles Array of triangle indices (i,j,k triples, 1-based), length = triCount*3
/// @param triCount Number of triangles
/// @return Shape, or NULL on failure
OCCTShapeRef OCCTShapeFromMesh(const double* points, int32_t nodeCount,
    const int32_t* triangles, int32_t triCount);

// MARK: - GeomPlate_Surface (v0.61.0)

/// Build a plate surface through point constraints and return as a BSpline face.
/// @param points Array of point coordinates (x,y,z triples), length = ptCount*3
/// @param ptCount Number of points
/// @param tolerance Approximation tolerance
/// @param maxDegree Maximum BSpline degree
/// @param maxSegments Maximum BSpline segments
/// @return Face shape with plate surface, or NULL on failure
OCCTShapeRef OCCTGeomPlateSurface(const double* points, int32_t ptCount,
    double tolerance, int32_t maxDegree, int32_t maxSegments);

// MARK: - v0.62.0: BRepLib, LocOpe completion, ShapeUpgrade/ShapeCustom, CPnts, IntCurvesFace

// --- BRepLib_MakeEdge ---

/// Create an edge from a line segment between two parameters.
OCCTShapeRef _Nullable OCCTBRepLibMakeEdgeFromLine(
    double ox, double oy, double oz,
    double dx, double dy, double dz,
    double p1, double p2);

/// Create an edge from two 3D points.
OCCTShapeRef _Nullable OCCTBRepLibMakeEdgeFromPoints(
    double x1, double y1, double z1,
    double x2, double y2, double z2);

/// Create an edge from a circle arc between two parameters.
OCCTShapeRef _Nullable OCCTBRepLibMakeEdgeFromCircle(
    double cx, double cy, double cz,
    double dx, double dy, double dz,
    double radius, double p1, double p2);

// --- BRepLib_MakeFace ---

/// Create a face from a plane surface with UV bounds.
OCCTShapeRef _Nullable OCCTBRepLibMakeFaceFromPlane(
    double ox, double oy, double oz,
    double nx, double ny, double nz,
    double uMin, double uMax, double vMin, double vMax, double tolerance);

/// Create a face from a cylindrical surface with UV bounds.
OCCTShapeRef _Nullable OCCTBRepLibMakeFaceFromCylinder(
    double ox, double oy, double oz,
    double dx, double dy, double dz,
    double radius,
    double uMin, double uMax, double vMin, double vMax, double tolerance);

// --- BRepLib_MakeShell ---

/// Create a shell from a plane surface with UV bounds.
OCCTShapeRef _Nullable OCCTBRepLibMakeShellFromPlane(
    double ox, double oy, double oz,
    double nx, double ny, double nz,
    double uMin, double uMax, double vMin, double vMax);

// --- BRepLib_ToolTriangulatedShape ---

/// Compute normals on the triangulation of a shape's faces.
/// The shape must be meshed first.
/// @return true if normals were computed on at least one face
bool OCCTBRepLibComputeNormals(OCCTShapeRef shape);

// --- BRepLib_PointCloudShape ---

/// Generate a point cloud from a meshed shape by triangulation.
/// @param shape The meshed shape
/// @param outPoints Output array of (x,y,z) triples — caller must free with free()
/// @param outNormals Output array of (nx,ny,nz) triples — caller must free with free()
/// @param outCount Number of points generated
/// @return true on success
bool OCCTBRepLibPointCloudByTriangulation(OCCTShapeRef shape,
    double* _Nullable * _Nonnull outPoints,
    double* _Nullable * _Nonnull outNormals,
    int32_t* outCount);

/// Generate a point cloud from a meshed shape by density.
/// @param shape The meshed shape
/// @param density Points per unit area
/// @param outPoints Output array of (x,y,z) triples — caller must free with free()
/// @param outNormals Output array of (nx,ny,nz) triples — caller must free with free()
/// @param outCount Number of points generated
/// @return true on success
bool OCCTBRepLibPointCloudByDensity(OCCTShapeRef shape, double density,
    double* _Nullable * _Nonnull outPoints,
    double* _Nullable * _Nonnull outNormals,
    int32_t* outCount);

// --- BRepBuilderAPI_MakeEdge2d ---

/// Create a 2D edge from two 2D points.
OCCTShapeRef _Nullable OCCTMakeEdge2dFromPoints(double x1, double y1, double x2, double y2);

/// Create a 2D edge from a 2D circle arc.
OCCTShapeRef _Nullable OCCTMakeEdge2dFromCircle(
    double cx, double cy, double dx, double dy,
    double radius, double p1, double p2);

/// Create a 2D edge from a 2D line with parameters.
OCCTShapeRef _Nullable OCCTMakeEdge2dFromLine(
    double ox, double oy, double dx, double dy,
    double p1, double p2);

// --- BRepTools_Modifier + NurbsConvertModification ---

/// Apply NURBS conversion to a shape via BRepTools_Modifier.
/// This is a more flexible alternative to BRepBuilderAPI_NurbsConvert.
OCCTShapeRef _Nullable OCCTBRepToolsModifierNurbsConvert(OCCTShapeRef shape);

// --- ShapeCustom_DirectModification ---

/// Apply ShapeCustom_DirectModification to orient face normals outward.
OCCTShapeRef _Nullable OCCTShapeCustomDirectModification(OCCTShapeRef shape);

// --- ShapeCustom_TrsfModification ---

/// Apply a transformation as a shape modification with correct tolerance scaling.
/// @param shape Input shape
/// @param sx Scale X (uniform scaling: sx=sy=sz)
/// @param sy Scale Y
/// @param sz Scale Z
OCCTShapeRef _Nullable OCCTShapeCustomTrsfModificationScale(OCCTShapeRef shape, double scaleFactor);

// --- LocOpe_BuildWires ---

/// Build wires from loose edges of a shape.
/// @param shape The shape whose edges to build into wires
/// @param faceIndex 1-based face index to get edges from (0 = all edges)
/// @param outWires Output array of wire shapes — caller must release each
/// @param outCount Number of wires built
/// @return true on success
bool OCCTLocOpeBuildWires(OCCTShapeRef shape, int32_t faceIndex,
    OCCTShapeRef _Nullable * _Nullable * _Nonnull outWires,
    int32_t* outCount);

// --- LocOpe_WiresOnShape + LocOpe_Spliter ---

/// Split a shape by projecting a wire onto a face and splitting along it.
/// @param shape The shape to split
/// @param wire The splitting wire
/// @param faceIndex 1-based index of the face to split
/// @return The split shape, or NULL on failure
OCCTShapeRef _Nullable OCCTLocOpeSplitByWireOnFace(OCCTShapeRef shape,
    OCCTShapeRef wire, int32_t faceIndex);

// --- LocOpe_CurveShapeIntersector ---

/// Intersect a line with a shape and return intersection parameters.
/// @param shape The shape to intersect
/// @param ox,oy,oz Origin of the line
/// @param dx,dy,dz Direction of the line
/// @param outParams Output array of parameter values — caller must free with free()
/// @param outCount Number of intersection points
/// @return true if intersections found
bool OCCTLocOpeCurveShapeIntersectLine(OCCTShapeRef shape,
    double ox, double oy, double oz,
    double dx, double dy, double dz,
    double* _Nullable * _Nonnull outParams,
    int32_t* outCount);

// --- ShapeUpgrade_ClosedFaceDivide ---

/// Divide closed faces (e.g., full cylinders) into multiple faces.
/// @param shape The shape containing closed faces
/// @param nbSplitPoints Number of splitting lines (result = nbSplitPoints+1 faces per closed face)
/// @return The modified shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeUpgradeClosedFaceDivide(OCCTShapeRef shape, int32_t nbSplitPoints);

// --- ShapeUpgrade_SplitSurfaceAngle ---

/// Split surfaces of revolution so each segment covers no more than maxAngle degrees.
/// @param shape The shape to process
/// @param maxAngleDegrees Maximum angle per segment in degrees
/// @return The modified shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeUpgradeSplitSurfaceAngle(OCCTShapeRef shape, double maxAngleDegrees);

// --- ShapeUpgrade_SplitSurfaceArea ---

/// Split faces into approximately nbParts equal-area parts.
/// @param shape The shape to process
/// @param nbParts Target number of parts per face
/// @return The modified shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeUpgradeSplitSurfaceArea(OCCTShapeRef shape, int32_t nbParts);

// --- CPnts_UniformDeflection ---

/// Discretize an edge curve by uniform deflection.
/// @param shape Edge shape to discretize
/// @param deflection Maximum chordal deflection
/// @param outParams Output array of parameter values — caller must free with free()
/// @param outPoints Output array of (x,y,z) triples — caller must free with free()
/// @param outCount Number of points generated
/// @return true on success
bool OCCTCPntsUniformDeflection(OCCTShapeRef shape, double deflection,
    double* _Nullable * _Nonnull outParams,
    double* _Nullable * _Nonnull outPoints,
    int32_t* outCount);

/// Discretize an edge curve by uniform deflection within a parameter range.
bool OCCTCPntsUniformDeflectionRange(OCCTShapeRef shape, double deflection,
    double u1, double u2,
    double* _Nullable * _Nonnull outParams,
    double* _Nullable * _Nonnull outPoints,
    int32_t* outCount);

// --- IntCurvesFace_ShapeIntersector ---

/// Intersect a ray with all faces of a shape.
/// @param shape The shape to intersect
/// @param ox,oy,oz Ray origin
/// @param dx,dy,dz Ray direction
/// @param outPoints Output array of (x,y,z) triples — caller must free with free()
/// @param outParams Output array of parameter values along ray — caller must free with free()
/// @param outCount Number of intersection points
/// @return true if intersections found
bool OCCTIntCurvesFaceShapeIntersect(OCCTShapeRef shape,
    double ox, double oy, double oz,
    double dx, double dy, double dz,
    double* _Nullable * _Nonnull outPoints,
    double* _Nullable * _Nonnull outParams,
    int32_t* outCount);

/// Find the nearest intersection of a ray with a shape.
/// @return true if an intersection was found, with the point in outX/Y/Z and parameter in outParam
bool OCCTIntCurvesFaceShapeIntersectNearest(OCCTShapeRef shape,
    double ox, double oy, double oz,
    double dx, double dy, double dz,
    double* outX, double* outY, double* outZ,
    double* outParam);

// MARK: - v0.63.0: GeomLProp, BRepOffset_SimpleOffset, Approx_CurvilinearParameter,
// GeomInt_IntSS, Contap_Contour, BRepFeat_Builder, GeomFill trihedrons/filling/sweep

// --- GeomLProp_CLProps ---
// Curve local properties at a parameter
typedef struct {
    double px, py, pz;       // point
    double tx, ty, tz;       // tangent direction (0 if undefined)
    double nx, ny, nz;       // normal direction (0 if undefined)
    double cx, cy, cz;       // center of curvature (0 if undefined)
    double curvature;        // curvature value
    bool tangentDefined;
} OCCTCurveLocalProps;

OCCTCurveLocalProps OCCTGeomLPropCLProps(OCCTShapeRef edgeShape, double param);

// --- GeomLProp_SLProps ---
// Surface local properties at (U,V) on a face
typedef struct {
    double px, py, pz;           // point
    double nx, ny, nz;           // normal (0 if undefined)
    double tuX, tuY, tuZ;        // tangent U direction (0 if undefined)
    double tvX, tvY, tvZ;        // tangent V direction (0 if undefined)
    double maxCurvature;
    double minCurvature;
    double meanCurvature;
    double gaussianCurvature;
    bool normalDefined;
    bool curvatureDefined;
    bool isUmbilic;
} OCCTSurfaceLocalProps;

OCCTSurfaceLocalProps OCCTGeomLPropSLProps(OCCTShapeRef faceShape, double u, double v);

// --- BRepOffset_SimpleOffset ---
OCCTShapeRef _Nullable OCCTBRepOffsetSimpleOffset(OCCTShapeRef shape, double offset, double tolerance);

// --- Approx_CurvilinearParameter ---
// Reparameterize an edge curve by arc length → BSpline
OCCTShapeRef _Nullable OCCTApproxCurvilinearParameter(OCCTShapeRef edgeShape,
    double tolerance, int maxDegree, int maxSegments);

// --- GeomInt_IntSS ---
// Surface-surface intersection returning 3D curves
// Returns count of intersection curves; curves stored internally
typedef void* OCCTGeomIntSSRef;
OCCTGeomIntSSRef _Nullable OCCTGeomIntSSCreate(OCCTShapeRef face1, OCCTShapeRef face2, double tolerance);
int OCCTGeomIntSSLineCount(OCCTGeomIntSSRef ref);
OCCTShapeRef _Nullable OCCTGeomIntSSLine(OCCTGeomIntSSRef ref, int index);
int OCCTGeomIntSSPointCount(OCCTGeomIntSSRef ref);
void OCCTGeomIntSSPoint(OCCTGeomIntSSRef ref, int index, double* x, double* y, double* z);
void OCCTGeomIntSSRelease(OCCTGeomIntSSRef ref);

// --- Contap_Contour ---
// Contour lines on a face with direction or eye point
typedef void* OCCTContapContourRef;
OCCTContapContourRef _Nullable OCCTContapContourDirection(OCCTShapeRef faceShape,
    double dx, double dy, double dz);
OCCTContapContourRef _Nullable OCCTContapContourEye(OCCTShapeRef faceShape,
    double ex, double ey, double ez);
int OCCTContapContourLineCount(OCCTContapContourRef ref);
int OCCTContapContourLinePointCount(OCCTContapContourRef ref, int lineIndex);
void OCCTContapContourLinePoint(OCCTContapContourRef ref, int lineIndex, int pointIndex,
    double* x, double* y, double* z);
int OCCTContapContourLineType(OCCTContapContourRef ref, int lineIndex);
void OCCTContapContourRelease(OCCTContapContourRef ref);

// --- BRepFeat_Builder ---
// Feature-based boolean with part selection
OCCTShapeRef _Nullable OCCTBRepFeatBuilderFuse(OCCTShapeRef shape, OCCTShapeRef tool);
OCCTShapeRef _Nullable OCCTBRepFeatBuilderCut(OCCTShapeRef shape, OCCTShapeRef tool);

// --- GeomFill Trihedron Laws ---
// Evaluate trihedron frame (tangent, normal, binormal) on an edge at parameter
typedef struct {
    double tx, ty, tz;  // tangent
    double nx, ny, nz;  // normal
    double bx, by, bz;  // binormal
} OCCTTrihedronFrame;

OCCTTrihedronFrame OCCTGeomFillDraftTrihedron(OCCTShapeRef edgeShape, double param,
    double biNormalX, double biNormalY, double biNormalZ, double angle);
OCCTTrihedronFrame OCCTGeomFillDiscreteTrihedron(OCCTShapeRef edgeShape, double param);
OCCTTrihedronFrame OCCTGeomFillCorrectedFrenet(OCCTShapeRef edgeShape, double param);

// --- GeomFill_Coons / GeomFill_Curved ---
// Fill from 4 boundary point arrays; returns computed pole grid
// pointsPerSide: how many points define each boundary
// boundary arrays are flat [x,y,z, x,y,z, ...]
// outPoints: flat output [x,y,z, ...], maxPoints: max poles to write
// outNbU, outNbV: pole grid dimensions
// Returns: number of poles written
int OCCTGeomFillCoonsPoles(
    const double* b1, const double* b2, const double* b3, const double* b4,
    int pointsPerSide, double* outPoints, int maxPoints,
    int* outNbU, int* outNbV);
int OCCTGeomFillCurvedPoles(
    const double* b1, const double* b2, const double* b3, const double* b4,
    int pointsPerSide, double* outPoints, int maxPoints,
    int* outNbU, int* outNbV);

// --- GeomFill_CoonsAlgPatch ---
// Evaluate Coons algorithmic patch from 4 boundary curves (edges)
void OCCTGeomFillCoonsAlgPatchEval(
    OCCTShapeRef edge1, OCCTShapeRef edge2, OCCTShapeRef edge3, OCCTShapeRef edge4,
    int evalU, int evalV, double* outPoints);

// --- GeomFill_Sweep ---
// Sweep a section curve along a path curve with corrected Frenet frame
// Returns the swept surface as a face
OCCTShapeRef _Nullable OCCTGeomFillSweep(OCCTShapeRef pathEdge, OCCTShapeRef sectionEdge);

// --- GeomFill_EvolvedSection ---
// Query section shape info from evolved section (curve + law)
typedef struct {
    int nbPoles;
    int nbKnots;
    int degree;
    bool isRational;
} OCCTEvolvedSectionInfo;

OCCTEvolvedSectionInfo OCCTGeomFillEvolvedSectionInfo(OCCTShapeRef edgeShape);

// MARK: - v0.64.0: ProjLib, BRepOffset_Offset, Adaptor3d_IsoCurve,
// ShapeAnalysis_TransferParametersProj

// --- ProjLib_ComputeApprox ---
// Project a 3D curve (edge) onto a surface (face) → 2D BSpline curve edge
OCCTShapeRef _Nullable OCCTProjLibComputeApprox(OCCTShapeRef edgeShape, OCCTShapeRef faceShape,
    double tolerance);

// --- ProjLib_ComputeApproxOnPolarSurface ---
// Project curve onto polar surface (sphere, torus, etc.)
OCCTShapeRef _Nullable OCCTProjLibComputeApproxOnPolarSurface(OCCTShapeRef edgeShape,
    OCCTShapeRef faceShape, double tolerance);

// --- BRepOffset_Offset ---
// Offset a face by a distance
OCCTShapeRef _Nullable OCCTBRepOffsetOffsetFace(OCCTShapeRef faceShape, double offset);

// --- Adaptor3d_IsoCurve ---
// Extract U-iso or V-iso curve from a face at given parameter
// isoType: 0 = IsoU, 1 = IsoV
// evalCount: number of evaluation points
// outPoints: flat [x,y,z,...] array of size evalCount*3
void OCCTAdaptor3dIsoCurveEval(OCCTShapeRef faceShape, int isoType, double param,
    int evalCount, double* outPoints);

// Extract iso-curve as an edge shape
OCCTShapeRef _Nullable OCCTAdaptor3dIsoCurveEdge(OCCTShapeRef faceShape, int isoType,
    double param, double p1, double p2);

// --- ShapeAnalysis_TransferParametersProj ---
// Transfer a parameter from edge 3D curve to face 2D representation
double OCCTShapeAnalysisTransferParam(OCCTShapeRef edgeShape, OCCTShapeRef faceShape,
    double param, bool toFace);

// MARK: - v0.65.0: Shape Processing Completions + Boolean Completions

// --- BOPAlgo_RemoveFeatures ---
/// Remove features (faces) from a solid shape.
/// @param shape Input solid shape
/// @param facesToRemove Array of face shapes to remove
/// @param faceCount Number of faces to remove
/// @return Result shape with features removed, or NULL on failure
OCCTShapeRef _Nullable OCCTBOPAlgoRemoveFeatures(OCCTShapeRef shape,
    const OCCTShapeRef _Nonnull * _Nonnull facesToRemove, int32_t faceCount);

// --- BOPAlgo_Section ---
/// Compute section (intersection curves/vertices) between shapes.
/// @param objects Array of object shapes
/// @param objCount Number of objects
/// @param tools Array of tool shapes
/// @param toolCount Number of tools
/// @return Result compound of edges/vertices, or NULL on failure
OCCTShapeRef _Nullable OCCTBOPAlgoSection(const OCCTShapeRef _Nonnull * _Nonnull objects, int32_t objCount,
    const OCCTShapeRef _Nonnull * _Nonnull tools, int32_t toolCount);

// --- ShapeBuild_Edge ---
/// Copy an edge, optionally sharing PCurves.
OCCTShapeRef _Nullable OCCTShapeBuildEdgeCopy(OCCTShapeRef edgeShape, bool sharePCurves);

/// Copy an edge replacing its vertices.
OCCTShapeRef _Nullable OCCTShapeBuildEdgeCopyReplaceVertices(OCCTShapeRef edgeShape,
    OCCTShapeRef vertex1Shape, OCCTShapeRef vertex2Shape);

/// Set the 3D parameter range on an edge.
void OCCTShapeBuildEdgeSetRange3d(OCCTShapeRef edgeShape, double first, double last);

/// Rebuild the 3D curve of an edge from its PCurves.
/// @return true if successful
bool OCCTShapeBuildEdgeBuildCurve3d(OCCTShapeRef edgeShape);

/// Remove the 3D curve from an edge.
void OCCTShapeBuildEdgeRemoveCurve3d(OCCTShapeRef edgeShape);

/// Copy parameter ranges from one edge to another.
void OCCTShapeBuildEdgeCopyRanges(OCCTShapeRef toEdge, OCCTShapeRef fromEdge);

/// Copy PCurves from one edge to another.
void OCCTShapeBuildEdgeCopyPCurves(OCCTShapeRef toEdge, OCCTShapeRef fromEdge);

/// Remove a PCurve from an edge for a given face.
void OCCTShapeBuildEdgeRemovePCurve(OCCTShapeRef edgeShape, OCCTShapeRef faceShape);

/// Reassign a PCurve from one face to another.
/// @return true if successful
bool OCCTShapeBuildEdgeReassignPCurve(OCCTShapeRef edgeShape, OCCTShapeRef oldFaceShape,
    OCCTShapeRef newFaceShape);

// --- ShapeBuild_Vertex ---
/// Combine two vertices into one at the average position.
/// @param tolFactor Tolerance factor (default 1.0001)
OCCTShapeRef _Nullable OCCTShapeBuildVertexCombine(OCCTShapeRef v1Shape, OCCTShapeRef v2Shape,
    double tolFactor);

/// Combine two points into a vertex.
OCCTShapeRef _Nullable OCCTShapeBuildVertexCombineFromPoints(
    double x1, double y1, double z1, double tol1,
    double x2, double y2, double z2, double tol2,
    double tolFactor);

// --- ShapeExtend_Explorer ---
/// Filter a compound shape, extracting only sub-shapes of the specified type.
/// @param shapeType TopAbs_ShapeEnum value (0=COMPOUND..7=SHAPE)
/// @param explore If true, explore sub-compounds recursively
/// @return Compound containing only shapes of the specified type, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeExtendSortedCompound(OCCTShapeRef shape, int32_t shapeType,
    bool explore);

/// Get the predominant shape type in a compound.
/// @param compound If true, look inside compounds
/// @return TopAbs_ShapeEnum value
int32_t OCCTShapeExtendShapeType(OCCTShapeRef shape, bool compound);

// --- ShapeUpgrade_FaceDivide ---
/// Divide a face using surface segmentation.
/// Uses ShapeUpgrade_FaceDivide with surface segment mode.
/// @param faceShape Input face shape
/// @return Divided shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeUpgradeFaceDivide(OCCTShapeRef faceShape);

// --- ShapeUpgrade_WireDivide ---
/// Divide a wire on a face.
/// @param wireShape Input wire shape
/// @param faceShape Face the wire lies on
/// @return Divided wire as shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeUpgradeWireDivideOnFace(OCCTShapeRef wireShape, OCCTShapeRef faceShape);

// --- ShapeUpgrade_EdgeDivide ---
/// Analyze an edge for potential division on a face.
/// @param edgeShape Input edge shape
/// @param faceShape Face context
/// @param outHasCurve2d Output: whether edge has 2D curve on face
/// @param outHasCurve3d Output: whether edge has 3D curve
/// @return true if computation succeeded
bool OCCTShapeUpgradeEdgeDivideCompute(OCCTShapeRef edgeShape, OCCTShapeRef faceShape,
    bool* outHasCurve2d, bool* outHasCurve3d);

// --- ShapeUpgrade_ClosedEdgeDivide ---
/// Analyze a closed (seam) edge for division on a face.
/// @return true if the edge is closed and can be divided
bool OCCTShapeUpgradeClosedEdgeDivideCompute(OCCTShapeRef edgeShape, OCCTShapeRef faceShape);

// --- ShapeUpgrade_FixSmallCurves ---
/// Fix small curves in a shape by removing degenerate edges.
/// @param shape Input shape
/// @param tolerance Tolerance for small curve detection
/// @return Fixed shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeUpgradeFixSmallCurves(OCCTShapeRef shape, double tolerance);

// --- ShapeUpgrade_FixSmallBezierCurves ---
/// Fix small Bezier curves in a shape.
/// @param shape Input shape
/// @param tolerance Tolerance for small curve detection
/// @return Fixed shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeUpgradeFixSmallBezierCurves(OCCTShapeRef shape, double tolerance);

// --- ShapeUpgrade_ConvertCurve3dToBezier ---
/// Convert 3D curves in a shape to Bezier representation.
/// @param shape Input shape
/// @param lineMode Convert lines to Bezier
/// @param circleMode Convert circles to Bezier
/// @param conicMode Convert conics to Bezier
/// @return Shape with Bezier curves, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeUpgradeConvertCurves3dToBezier(OCCTShapeRef shape,
    bool lineMode, bool circleMode, bool conicMode);

// --- ShapeUpgrade_ConvertSurfaceToBezierBasis ---
/// Convert surfaces in a shape to Bezier patches.
/// @param shape Input shape
/// @param planeMode Convert planes
/// @param revolutionMode Convert surfaces of revolution
/// @param extrusionMode Convert extrusion surfaces
/// @param bsplineMode Convert BSpline surfaces
/// @return Shape with Bezier surfaces, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeUpgradeConvertSurfaceToBezier(OCCTShapeRef shape,
    bool planeMode, bool revolutionMode, bool extrusionMode, bool bsplineMode);

// MARK: - v0.66.0: Full TkG2d Toolkit Coverage

// Forward declarations
typedef struct OCCTTransform2D* OCCTTransform2DRef;

// --- Point2D (Geom2d_CartesianPoint) ---

/// Opaque handle for 2D geometric point
typedef struct OCCTPoint2D* OCCTPoint2DRef;

/// Create a 2D point at (x, y)
OCCTPoint2DRef _Nullable OCCTPoint2DCreate(double x, double y);
/// Release a 2D point
void OCCTPoint2DRelease(OCCTPoint2DRef _Nonnull ref);
/// Get X coordinate
double OCCTPoint2DGetX(OCCTPoint2DRef _Nonnull ref);
/// Get Y coordinate
double OCCTPoint2DGetY(OCCTPoint2DRef _Nonnull ref);
/// Set coordinates
void OCCTPoint2DSetCoords(OCCTPoint2DRef _Nonnull ref, double x, double y);
/// Distance to another point
double OCCTPoint2DDistance(OCCTPoint2DRef _Nonnull ref, OCCTPoint2DRef _Nonnull other);
/// Square distance to another point
double OCCTPoint2DSquareDistance(OCCTPoint2DRef _Nonnull ref, OCCTPoint2DRef _Nonnull other);
/// Translate by (dx, dy), returns new point
OCCTPoint2DRef _Nullable OCCTPoint2DTranslated(OCCTPoint2DRef _Nonnull ref, double dx, double dy);
/// Rotate around center by angle (radians), returns new point
OCCTPoint2DRef _Nullable OCCTPoint2DRotated(OCCTPoint2DRef _Nonnull ref,
    double cx, double cy, double angle);
/// Scale from center by factor, returns new point
OCCTPoint2DRef _Nullable OCCTPoint2DScaled(OCCTPoint2DRef _Nonnull ref,
    double cx, double cy, double factor);
/// Mirror across a point, returns new point
OCCTPoint2DRef _Nullable OCCTPoint2DMirroredPoint(OCCTPoint2DRef _Nonnull ref,
    double px, double py);
/// Mirror across an axis (origin + direction), returns new point
OCCTPoint2DRef _Nullable OCCTPoint2DMirroredAxis(OCCTPoint2DRef _Nonnull ref,
    double ox, double oy, double dx, double dy);
/// Distance from point to curve
double OCCTPoint2DDistanceToCurve(OCCTPoint2DRef _Nonnull ref, OCCTCurve2DRef _Nonnull curve);
/// Apply a Transform2D to a point, returns new point
OCCTPoint2DRef _Nullable OCCTPoint2DTransformed(OCCTPoint2DRef _Nonnull ref,
    OCCTTransform2DRef _Nonnull trsf);

// --- Transform2D (Geom2d_Transformation) ---

/// Create identity transform
OCCTTransform2DRef _Nullable OCCTTransform2DCreateIdentity(void);
/// Release a transform
void OCCTTransform2DRelease(OCCTTransform2DRef _Nonnull ref);
/// Create translation transform
OCCTTransform2DRef _Nullable OCCTTransform2DCreateTranslation(double dx, double dy);
/// Create rotation transform around center by angle
OCCTTransform2DRef _Nullable OCCTTransform2DCreateRotation(double cx, double cy, double angle);
/// Create scale transform from center by factor
OCCTTransform2DRef _Nullable OCCTTransform2DCreateScale(double cx, double cy, double factor);
/// Create mirror about a point
OCCTTransform2DRef _Nullable OCCTTransform2DCreateMirrorPoint(double px, double py);
/// Create mirror about an axis (origin + direction)
OCCTTransform2DRef _Nullable OCCTTransform2DCreateMirrorAxis(double ox, double oy,
    double dx, double dy);
/// Inverted transform
OCCTTransform2DRef _Nullable OCCTTransform2DInverted(OCCTTransform2DRef _Nonnull ref);
/// Composed (multiplied) transforms: this * other
OCCTTransform2DRef _Nullable OCCTTransform2DComposed(OCCTTransform2DRef _Nonnull ref,
    OCCTTransform2DRef _Nonnull other);
/// Powered transform: this^n
OCCTTransform2DRef _Nullable OCCTTransform2DPowered(OCCTTransform2DRef _Nonnull ref, int32_t n);
/// Apply transform to a point (returns transformed coordinates)
void OCCTTransform2DApply(OCCTTransform2DRef _Nonnull ref, double* _Nonnull x, double* _Nonnull y);
/// Get scale factor
double OCCTTransform2DScaleFactor(OCCTTransform2DRef _Nonnull ref);
/// Is the transform negative (reflection)?
bool OCCTTransform2DIsNegative(OCCTTransform2DRef _Nonnull ref);
/// Get 2x3 matrix values [a11, a12, a13, a21, a22, a23]
void OCCTTransform2DGetValues(OCCTTransform2DRef _Nonnull ref,
    double* _Nonnull a11, double* _Nonnull a12, double* _Nonnull a13,
    double* _Nonnull a21, double* _Nonnull a22, double* _Nonnull a23);
/// Apply transform to a Curve2D, returns new curve
OCCTCurve2DRef _Nullable OCCTTransform2DApplyToCurve(OCCTTransform2DRef _Nonnull ref,
    OCCTCurve2DRef _Nonnull curve);

// --- AxisPlacement2D (Geom2d_AxisPlacement) ---

/// Opaque handle for 2D axis placement
typedef struct OCCTAxisPlacement2D* OCCTAxisPlacement2DRef;

/// Create a 2D axis placement from origin and direction
OCCTAxisPlacement2DRef _Nullable OCCTAxisPlacement2DCreate(double ox, double oy,
    double dx, double dy);
/// Release
void OCCTAxisPlacement2DRelease(OCCTAxisPlacement2DRef _Nonnull ref);
/// Get origin
void OCCTAxisPlacement2DGetOrigin(OCCTAxisPlacement2DRef _Nonnull ref,
    double* _Nonnull x, double* _Nonnull y);
/// Get direction
void OCCTAxisPlacement2DGetDirection(OCCTAxisPlacement2DRef _Nonnull ref,
    double* _Nonnull x, double* _Nonnull y);
/// Reversed axis
OCCTAxisPlacement2DRef _Nullable OCCTAxisPlacement2DReversed(OCCTAxisPlacement2DRef _Nonnull ref);
/// Angle between two axes
double OCCTAxisPlacement2DAngle(OCCTAxisPlacement2DRef _Nonnull ref,
    OCCTAxisPlacement2DRef _Nonnull other);

// --- Vector2D (Geom2d_VectorWithMagnitude) ---

/// Signed angle between two 2D vectors (radians, -PI to PI)
double OCCTVector2DAngle(double ax, double ay, double bx, double by);
/// Cross product of two 2D vectors (scalar)
double OCCTVector2DCross(double ax, double ay, double bx, double by);
/// Dot product of two 2D vectors
double OCCTVector2DDot(double ax, double ay, double bx, double by);
/// Magnitude of a 2D vector
double OCCTVector2DMagnitude(double x, double y);
/// Normalize a 2D vector (returns via pointers)
void OCCTVector2DNormalize(double* _Nonnull x, double* _Nonnull y);

// --- Direction2D (Geom2d_Direction) ---

/// Create a normalized direction from components (returns via pointers)
void OCCTDirection2DNormalize(double* _Nonnull x, double* _Nonnull y);
/// Signed angle between two directions
double OCCTDirection2DAngle(double ax, double ay, double bx, double by);
/// Cross product of two directions
double OCCTDirection2DCross(double ax, double ay, double bx, double by);

// --- LProp_AnalyticCurInf ---

/// Compute curvature special points for analytic curve types.
/// @param curveType GeomAbs_CurveType: 0=Line, 1=Circle, 2=Ellipse, 3=Hyperbola, 4=Parabola
/// @param first First parameter
/// @param last Last parameter
/// @param outParams Output array of parameters at special points
/// @param outTypes Output array of types (0=Inflection, 1=MinCur, 2=MaxCur)
/// @param maxResults Maximum number of results to return
/// @return Number of special points found
int32_t OCCTLPropAnalyticCurInf(int32_t curveType, double first, double last,
    double* _Nonnull outParams, int32_t* _Nonnull outTypes, int32_t maxResults);

// --- Curve2D ↔ Point2D integration ---

/// Create a Point2D from a Curve2D at parameter t
OCCTPoint2DRef _Nullable OCCTCurve2DPointAt(OCCTCurve2DRef _Nonnull curve, double t);

/// Create a line segment Curve2D between two Point2Ds
OCCTCurve2DRef _Nullable OCCTCurve2DSegmentFromPoints(OCCTPoint2DRef _Nonnull p1,
    OCCTPoint2DRef _Nonnull p2);

/// Project a Point2D onto a Curve2D, returns parameter at closest point
/// @param outDistance Output: minimum distance
/// @return parameter on curve, or 0 on failure
double OCCTCurve2DProjectPoint2D(OCCTCurve2DRef _Nonnull curve, OCCTPoint2DRef _Nonnull point,
    double* _Nonnull outDistance);

// MARK: - v0.67.0: TKGeomAlgo Part 1 — FairCurve, LocalAnalysis, TopTrans

// --- FairCurve_Batten ---

/// Create a fair curve (batten) between two 2D points.
/// @param height Height of deformation (must be > 0)
/// @param slope Slope value (0 = uniform section)
/// @return Curve2D result after computation, or NULL on failure
OCCTCurve2DRef _Nullable OCCTFairCurveBatten(double p1x, double p1y, double p2x, double p2y,
    double height, double slope, double angle1, double angle2,
    int32_t constraintOrder1, int32_t constraintOrder2, bool freeSliding,
    int32_t* _Nonnull outCode);

/// Create a minimal variation fair curve between two 2D points.
/// @param physicalRatio Physical ratio (0-1, balance between curvature and jerk energy)
/// @param curvature1 Desired curvature at P1 (only used if constraintOrder >= 2)
/// @param curvature2 Desired curvature at P2 (only used if constraintOrder >= 2)
/// @return Curve2D result after computation, or NULL on failure
OCCTCurve2DRef _Nullable OCCTFairCurveMinimalVariation(double p1x, double p1y, double p2x, double p2y,
    double height, double slope, double angle1, double angle2,
    int32_t constraintOrder1, int32_t constraintOrder2, bool freeSliding,
    double physicalRatio, double curvature1, double curvature2,
    int32_t* _Nonnull outCode);

// --- LocalAnalysis_CurveContinuity ---

/// Analyze local continuity between two 3D curves at given parameters.
/// Uses BSpline curves extracted from edges via Curve3D handles.
/// @param curve1 First curve
/// @param u1 Parameter on first curve
/// @param curve2 Second curve
/// @param u2 Parameter on second curve
/// @param order Requested analysis order: 0=C0, 1=G1, 2=C1, 3=G2, 4=C2
/// @param outStatus Output: continuity status (0=C0, 1=G1, 2=C1, 3=G2, 4=C2)
/// @param outC0Value Output: C0 distance
/// @param outG1Angle Output: G1 angle (radians)
/// @param outC1Angle Output: C1 angle
/// @param outC1Ratio Output: C1 ratio
/// @param outC2Angle Output: C2 angle
/// @param outC2Ratio Output: C2 ratio
/// @param outG2Angle Output: G2 angle
/// @param outG2CurvatureVariation Output: G2 curvature variation
/// @return true if analysis succeeded
bool OCCTLocalAnalysisCurveContinuity(OCCTCurve3DRef _Nonnull curve1, double u1,
    OCCTCurve3DRef _Nonnull curve2, double u2, int32_t order,
    int32_t* _Nonnull outStatus,
    double* _Nonnull outC0Value, double* _Nonnull outG1Angle,
    double* _Nonnull outC1Angle, double* _Nonnull outC1Ratio,
    double* _Nonnull outC2Angle, double* _Nonnull outC2Ratio,
    double* _Nonnull outG2Angle, double* _Nonnull outG2CurvatureVariation);

/// Check boolean continuity flags for curve continuity analysis.
/// @return Bitmask: bit 0=IsC0, bit 1=IsG1, bit 2=IsC1, bit 3=IsG2, bit 4=IsC2
int32_t OCCTLocalAnalysisCurveContinuityFlags(OCCTCurve3DRef _Nonnull curve1, double u1,
    OCCTCurve3DRef _Nonnull curve2, double u2, int32_t order);

// --- LocalAnalysis_SurfaceContinuity ---

/// Analyze local continuity between two surfaces at given UV parameters.
/// @param surface1 First surface
/// @param u1 U parameter on first surface
/// @param v1 V parameter on first surface
/// @param surface2 Second surface
/// @param u2 U parameter on second surface
/// @param v2 V parameter on second surface
/// @param order Requested analysis order: 0=C0, 1=G1, 2=C1, 3=G2, 4=C2
/// @param outStatus Output: continuity status
/// @param outC0Value Output: C0 distance
/// @param outG1Angle Output: G1 angle
/// @param outC1UAngle Output: C1 U angle
/// @param outC1VAngle Output: C1 V angle
/// @return true if analysis succeeded
bool OCCTLocalAnalysisSurfaceContinuity(OCCTSurfaceRef _Nonnull surface1, double u1, double v1,
    OCCTSurfaceRef _Nonnull surface2, double u2, double v2, int32_t order,
    int32_t* _Nonnull outStatus,
    double* _Nonnull outC0Value, double* _Nonnull outG1Angle,
    double* _Nonnull outC1UAngle, double* _Nonnull outC1VAngle);

/// Check boolean continuity flags for surface continuity analysis.
/// @return Bitmask: bit 0=IsC0, bit 1=IsG1, bit 2=IsC1, bit 3=IsG2, bit 4=IsC2
int32_t OCCTLocalAnalysisSurfaceContinuityFlags(OCCTSurfaceRef _Nonnull surface1, double u1, double v1,
    OCCTSurfaceRef _Nonnull surface2, double u2, double v2, int32_t order);

// --- TopTrans_SurfaceTransition ---

/// Compute surface transition states for a boundary crossing.
/// @param tgtX/Y/Z Tangent direction of the boundary
/// @param normX/Y/Z Normal of the reference surface
/// @param surfNormX/Y/Z Normal of the crossing surface
/// @param tolerance Tolerance for angle comparison
/// @param surfOrientation Orientation of the crossing surface (0=FORWARD, 1=REVERSED)
/// @param boundOrientation Orientation of the boundary (0=FORWARD, 1=REVERSED)
/// @param outStateBefore Output: state before crossing (0=IN, 1=OUT, 2=ON, 3=UNKNOWN)
/// @param outStateAfter Output: state after crossing (0=IN, 1=OUT, 2=ON, 3=UNKNOWN)
void OCCTTopTransSurfaceTransition(
    double tgtX, double tgtY, double tgtZ,
    double normX, double normY, double normZ,
    double surfNormX, double surfNormY, double surfNormZ,
    double tolerance,
    int32_t surfOrientation, int32_t boundOrientation,
    int32_t* _Nonnull outStateBefore, int32_t* _Nonnull outStateAfter);

/// Compute surface transition with curvature information.
void OCCTTopTransSurfaceTransitionCurvature(
    double tgtX, double tgtY, double tgtZ,
    double normX, double normY, double normZ,
    double maxDX, double maxDY, double maxDZ,
    double minDX, double minDY, double minDZ,
    double maxCurv, double minCurv,
    double surfNormX, double surfNormY, double surfNormZ,
    double surfMaxDX, double surfMaxDY, double surfMaxDZ,
    double surfMinDX, double surfMinDY, double surfMinDZ,
    double surfMaxCurv, double surfMinCurv,
    double tolerance,
    int32_t surfOrientation, int32_t boundOrientation,
    int32_t* _Nonnull outStateBefore, int32_t* _Nonnull outStateAfter);

// MARK: - v0.68.0: TKGeomAlgo Part 2 — CurveTransition, Trihedrons, NSections, Law, GccAna, Intf

// --- TopTrans_CurveTransition ---
/// Compute curve transition states at a boundary crossing (simple, no curvature).
void OCCTTopTransCurveTransition(
    double tgtX, double tgtY, double tgtZ,
    double tangX, double tangY, double tangZ,
    double normX, double normY, double normZ,
    double curvature, double tolerance,
    int32_t surfOrientation, int32_t boundOrientation,
    int32_t* _Nonnull outStateBefore, int32_t* _Nonnull outStateAfter);

/// Compute curve transition states with curvature on the boundary curve.
void OCCTTopTransCurveTransitionWithCurvature(
    double tgtX, double tgtY, double tgtZ,
    double curveNormX, double curveNormY, double curveNormZ,
    double curveCurv,
    double tangX, double tangY, double tangZ,
    double normX, double normY, double normZ,
    double surfCurv, double tolerance,
    int32_t surfOrientation, int32_t boundOrientation,
    int32_t* _Nonnull outStateBefore, int32_t* _Nonnull outStateAfter);

// --- GeomFill Trihedrons ---
/// Evaluate Darboux trihedron on a surface-curve (edge on face).
OCCTTrihedronFrame OCCTGeomFillDarbouxTrihedron(OCCTShapeRef _Nonnull edgeShape, OCCTShapeRef _Nonnull faceShape, double param);

/// Evaluate Fixed trihedron (constant tangent and normal).
OCCTTrihedronFrame OCCTGeomFillFixedTrihedron(
    double tangentX, double tangentY, double tangentZ,
    double normalX, double normalY, double normalZ, double param);

/// Evaluate Frenet trihedron on a curve.
OCCTTrihedronFrame OCCTGeomFillFrenetTrihedron(OCCTShapeRef _Nonnull edgeShape, double param);

/// Evaluate ConstantBiNormal trihedron on a curve.
OCCTTrihedronFrame OCCTGeomFillConstantBiNormalTrihedron(OCCTShapeRef _Nonnull edgeShape, double param,
    double biNormalX, double biNormalY, double biNormalZ);

// --- GeomFill_NSections ---
/// Create a BSpline surface by lofting through N section curves.
/// @param curveRefs Array of Curve3D handles (section curves)
/// @param params Array of parameter values for each section (0..1)
/// @param count Number of sections
/// @return Surface handle, or NULL on failure
OCCTSurfaceRef _Nullable OCCTGeomFillNSections(
    const OCCTCurve3DRef _Nonnull * _Nonnull curveRefs,
    const double* _Nonnull params, int32_t count);

/// Query section shape info from N-sections surface creation.
/// Returns section pole count, knot count, and degree.
void OCCTGeomFillNSectionsInfo(
    const OCCTCurve3DRef _Nonnull * _Nonnull curveRefs,
    const double* _Nonnull params, int32_t count,
    int32_t* _Nonnull outNbPoles, int32_t* _Nonnull outNbKnots, int32_t* _Nonnull outDegree);

// --- Law_BSplineKnotSplitting ---
/// Find knot indices where a BSpline law drops below given continuity.
/// @param law BSpline law function handle
/// @param continuityOrder Continuity level to check (0=C0, 1=C1, 2=C2)
/// @param outIndices Output array of split knot indices
/// @param maxIndices Maximum number of indices to write
/// @return Number of split knot indices written
int32_t OCCTLawBSplineKnotSplitting(OCCTLawFunctionRef _Nonnull law,
    int32_t continuityOrder,
    int32_t* _Nonnull outIndices, int32_t maxIndices);

// --- Law_Composite ---
/// Create a composite law from multiple sub-laws stitched together.
/// @param lawRefs Array of law function handles
/// @param count Number of sub-laws
/// @param first Start of parametric range
/// @param last End of parametric range
/// @return Composite law handle
OCCTLawFunctionRef _Nullable OCCTLawComposite(const OCCTLawFunctionRef _Nonnull * _Nonnull lawRefs,
    int32_t count, double first, double last);

// --- GccAna_Circ2d3Tan ---

/// Result struct for GccAna_Circ2d3Tan solutions.
typedef struct {
    double centerX, centerY;
    double radius;
} OCCTCircle2DSolution;

/// Find circles tangent to / through 3 points.
int32_t OCCTGccAnaCirc2d3TanPoints(double p1x, double p1y, double p2x, double p2y,
    double p3x, double p3y, double tolerance,
    OCCTCircle2DSolution* _Nonnull outSolutions, int32_t maxSolutions);

/// Find circles tangent to 3 lines.
int32_t OCCTGccAnaCirc2d3TanLines(
    double l1px, double l1py, double l1dx, double l1dy,
    double l2px, double l2py, double l2dx, double l2dy,
    double l3px, double l3py, double l3dx, double l3dy,
    double tolerance,
    OCCTCircle2DSolution* _Nonnull outSolutions, int32_t maxSolutions);

/// Find circles tangent to 3 circles.
int32_t OCCTGccAnaCirc2d3TanCircles(
    double c1x, double c1y, double c1r,
    double c2x, double c2y, double c2r,
    double c3x, double c3y, double c3r,
    double tolerance,
    OCCTCircle2DSolution* _Nonnull outSolutions, int32_t maxSolutions);

/// Find circles tangent to 2 circles through 1 point.
int32_t OCCTGccAnaCirc2d2CirclesPoint(
    double c1x, double c1y, double c1r,
    double c2x, double c2y, double c2r,
    double px, double py, double tolerance,
    OCCTCircle2DSolution* _Nonnull outSolutions, int32_t maxSolutions);

/// Find circles tangent to 1 circle through 2 points.
int32_t OCCTGccAnaCirc2dCircle2Points(
    double cx, double cy, double cr,
    double p1x, double p1y, double p2x, double p2y, double tolerance,
    OCCTCircle2DSolution* _Nonnull outSolutions, int32_t maxSolutions);

/// Find circles tangent to 2 lines through 1 point.
int32_t OCCTGccAnaCirc2d2LinesPoint(
    double l1px, double l1py, double l1dx, double l1dy,
    double l2px, double l2py, double l2dx, double l2dy,
    double px, double py, double tolerance,
    OCCTCircle2DSolution* _Nonnull outSolutions, int32_t maxSolutions);

// --- Intf_InterferencePolygon2d ---

/// Intersection point result for polygon interference.
typedef struct {
    double x, y;
} OCCTIntfPoint2D;

/// Compute interference (intersection) between two 2D polylines.
/// @param poly1 Flat array of (x,y) pairs for first polyline
/// @param count1 Number of points in first polyline
/// @param poly2 Flat array of (x,y) pairs for second polyline
/// @param count2 Number of points in second polyline
/// @param outPoints Output array of intersection points
/// @param maxPoints Maximum intersection points to write
/// @return Number of intersection points found
int32_t OCCTIntfInterferencePolygon2d(
    const double* _Nonnull poly1, int32_t count1,
    const double* _Nonnull poly2, int32_t count2,
    OCCTIntfPoint2D* _Nonnull outPoints, int32_t maxPoints);

/// Compute self-interference of a 2D polyline.
int32_t OCCTIntfSelfInterferencePolygon2d(
    const double* _Nonnull poly, int32_t count,
    OCCTIntfPoint2D* _Nonnull outPoints, int32_t maxPoints);

// MARK: - v0.69.0: NLPlate G2/G3, Plate_Plate, GeomPlate_BuildAveragePlane, GeomFill_Generator/Bound

// --- NLPlate G0+G2 constraint ---

/// Deform a surface with position + tangent + curvature constraints (NLPlate G0+G2).
/// constraints: flat array per point of (u, v, targetX, targetY, targetZ,
///   d1uX,d1uY,d1uZ, d1vX,d1vY,d1vZ,
///   d2uuX,d2uuY,d2uuZ, d2uvX,d2uvY,d2uvZ, d2vvX,d2vvY,d2vvZ) = 20 doubles each.
OCCTSurfaceRef _Nullable OCCTSurfaceNLPlateG2(OCCTSurfaceRef _Nonnull initialSurface,
    const double* _Nonnull constraints, int32_t constraintCount,
    int32_t maxIter, double tolerance);

/// Deform a surface with G0+G1+G2+G3 constraints.
/// constraints: flat array per point of 32 doubles each:
///   (u, v, targetX,Y,Z, d1uX,Y,Z, d1vX,Y,Z, d2uuX,Y,Z, d2uvX,Y,Z, d2vvX,Y,Z,
///    d3uuuX,Y,Z, d3uuvX,Y,Z, d3uvvX,Y,Z, d3vvvX,Y,Z)
OCCTSurfaceRef _Nullable OCCTSurfaceNLPlateG3(OCCTSurfaceRef _Nonnull initialSurface,
    const double* _Nonnull constraints, int32_t constraintCount,
    int32_t maxIter, double tolerance);

/// NLPlate with IncrementalSolve strategy (for challenging constraint sets).
/// Same constraint format as OCCTSurfaceNLPlateG0.
OCCTSurfaceRef _Nullable OCCTSurfaceNLPlateIncrementalG0(OCCTSurfaceRef _Nonnull initialSurface,
    const double* _Nonnull constraints, int32_t constraintCount,
    int32_t maxOrder, int32_t initConstraintOrder, int32_t nbIncrements);

/// Evaluate derivative of NLPlate solution at a UV point.
/// Deforms initial surface, solves, and returns derivative (iu,iv) at UV.
/// Returns false if solve fails. Writes result to outX/Y/Z.
bool OCCTSurfaceNLPlateEvaluateDerivative(OCCTSurfaceRef _Nonnull initialSurface,
    const double* _Nonnull constraints, int32_t constraintCount,
    double u, double v, int32_t iu, int32_t iv,
    double* _Nonnull outX, double* _Nonnull outY, double* _Nonnull outZ);

// --- Plate_Plate solver ---

/// Opaque handle for Plate_Plate solver
typedef void* OCCTPlateRef;

/// Create a Plate_Plate solver.
OCCTPlateRef OCCTPlateCreate(void);

/// Release a Plate_Plate solver.
void OCCTPlateRelease(OCCTPlateRef plate);

/// Load a pinpoint constraint into the plate solver.
/// @param iu, iv Derivative orders (0 for position, 1+ for derivatives)
void OCCTPlateLoadPinpoint(OCCTPlateRef plate,
    double u, double v, double x, double y, double z,
    int32_t iu, int32_t iv);

/// Load a G-to-C constraint (G1 level: source D1 → target D1).
/// d1s/d1t: flat (duX,duY,duZ, dvX,dvY,dvZ) = 6 doubles each.
void OCCTPlateLoadGtoC(OCCTPlateRef plate,
    double u, double v,
    const double* _Nonnull d1s, const double* _Nonnull d1t);

/// Solve the plate.
/// @param order Solution polynomial order (default 4)
/// @param anisotropy Anisotropy parameter (default 1.0)
/// @return true if solve succeeded
bool OCCTPlateSolve(OCCTPlateRef plate, int32_t order, double anisotropy);

/// Check if plate solve succeeded.
bool OCCTPlateIsDone(OCCTPlateRef plate);

/// Evaluate the plate at a UV point. Returns (x,y,z).
void OCCTPlateEvaluate(OCCTPlateRef plate,
    double u, double v,
    double* _Nonnull outX, double* _Nonnull outY, double* _Nonnull outZ);

/// Evaluate derivative at a UV point.
void OCCTPlateEvaluateDerivative(OCCTPlateRef plate,
    double u, double v, int32_t iu, int32_t iv,
    double* _Nonnull outX, double* _Nonnull outY, double* _Nonnull outZ);

/// Get UV bounding box of constraints.
void OCCTPlateUVBox(OCCTPlateRef plate,
    double* _Nonnull umin, double* _Nonnull umax,
    double* _Nonnull vmin, double* _Nonnull vmax);

/// Get continuity order of the plate solution.
int32_t OCCTPlateContinuity(OCCTPlateRef plate);

// --- GeomPlate_BuildAveragePlane ---

/// Result struct for average plane computation.
typedef struct {
    bool isPlane;
    bool isLine;
    double normalX, normalY, normalZ;     // plane normal (if isPlane)
    double originX, originY, originZ;     // plane origin (if isPlane)
    double umin, umax, vmin, vmax;        // min-max box on plane
    double lineOriginX, lineOriginY, lineOriginZ;  // line origin (if isLine)
    double lineDirX, lineDirY, lineDirZ;  // line direction (if isLine)
} OCCTAveragePlaneResult;

/// Compute average plane (or line) through a set of 3D points.
/// @param points Flat array of (x,y,z) triples
/// @param pointCount Number of points
/// @param nbBoundPoints Number of boundary points (for plane orientation)
/// @param tolerance Tolerance
/// @return Average plane result
OCCTAveragePlaneResult OCCTGeomPlateBuildAveragePlane(
    const double* _Nonnull points, int32_t pointCount,
    int32_t nbBoundPoints, double tolerance);

/// Get G0/G1/G2 errors from a GeomPlate build.
/// Uses same point-based plate surface construction as OCCTGeomPlateSurface.
/// @return false if construction fails
bool OCCTGeomPlateErrors(const double* _Nonnull points, int32_t ptCount,
    double tolerance, int32_t maxDegree, int32_t maxSegments,
    double* _Nonnull g0Error, double* _Nonnull g1Error, double* _Nonnull g2Error);

// --- GeomFill_Generator ---

/// Generate a ruled/lofted surface from a sequence of section curves.
/// Uses GeomFill_Generator (linear interpolation in V direction).
/// @param curves Array of curve handles
/// @param curveCount Number of curves
/// @param tolerance Parametric tolerance
/// @return BSpline surface, or NULL on failure
OCCTSurfaceRef _Nullable OCCTGeomFillGenerator(
    const OCCTCurve3DRef _Nonnull * _Nonnull curves, int32_t curveCount,
    double tolerance);

// --- GeomFill_DegeneratedBound ---

/// Result struct for GeomFill boundary evaluation.
typedef struct {
    double x, y, z;
} OCCTBoundaryPoint;

/// Create a degenerated boundary (single point) and evaluate at parameter.
/// @return The degenerated point value
OCCTBoundaryPoint OCCTGeomFillDegeneratedBoundValue(
    double px, double py, double pz,
    double first, double last, double param);

/// Check if a degenerated boundary is degenerated (always true).
bool OCCTGeomFillDegeneratedBoundIsDegenerated(
    double px, double py, double pz, double first, double last);

// --- GeomFill_BoundWithSurf ---

/// Evaluate a boundary-with-surface at a parameter.
/// The boundary is defined by a 2D curve on a surface.
/// @param surface The surface
/// @param curve2d The 2D curve on the surface (Curve2D handle)
/// @param first, last Parameter range of the 2D curve
/// @param param Parameter to evaluate at
/// @param outX/Y/Z Output point coordinates
/// @param outNX/NY/NZ Output surface normal at that point
/// @return true if evaluation succeeded
bool OCCTGeomFillBoundWithSurfEvaluate(
    OCCTSurfaceRef _Nonnull surface,
    OCCTCurve2DRef _Nonnull curve2d,
    double first, double last, double param,
    double* _Nonnull outX, double* _Nonnull outY, double* _Nonnull outZ,
    double* _Nonnull outNX, double* _Nonnull outNY, double* _Nonnull outNZ);

// MARK: - IntTools (v0.70.0)

/// Result of an edge-edge or edge-face intersection common part.
typedef struct {
    int32_t type;         // 0 = vertex, 1 = edge (TopAbs_VERTEX=7, TopAbs_EDGE=6 mapped to 0/1)
    double param1First;   // First parameter on edge 1
    double param1Last;    // Last parameter on edge 1 (same as first for vertex)
    double param2First;   // First parameter on edge 2
    double param2Last;    // Last parameter on edge 2 (same as first for vertex)
    double pointX, pointY, pointZ; // Bounding point (for vertex intersections)
} OCCTCommonPart;

/// Intersect two edges. Returns array of common parts.
/// @param edge1, edge2 Input edges
/// @param outParts Pointer to receive allocated array (caller must free)
/// @param outCount Number of common parts found
/// @return true if intersection succeeded (IsDone)
bool OCCTIntToolsEdgeEdge(OCCTShapeRef _Nonnull edge1, OCCTShapeRef _Nonnull edge2,
    OCCTCommonPart* _Nullable * _Nonnull outParts, int32_t* _Nonnull outCount);

/// Intersect an edge with a face. Returns array of common parts.
/// @param edge Input edge
/// @param face Input face
/// @param outParts Pointer to receive allocated array (caller must free)
/// @param outCount Number of common parts found
/// @return true if intersection succeeded
bool OCCTIntToolsEdgeFace(OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull face,
    OCCTCommonPart* _Nullable * _Nonnull outParts, int32_t* _Nonnull outCount);

/// Result of a face-face intersection curve.
typedef struct {
    double startX, startY, startZ;
    double endX, endY, endZ;
    bool hasStart;
    bool hasEnd;
} OCCTFaceFaceCurve;

/// Result of a face-face intersection point.
typedef struct {
    double x1, y1, z1; // Point on face 1
    double x2, y2, z2; // Point on face 2
} OCCTFaceFacePoint;

/// Intersect two faces. Returns intersection curves and points.
/// @param face1, face2 Input faces
/// @param tolerance Approximation tolerance
/// @param outCurves Pointer to receive allocated curve array (caller must free)
/// @param outCurveCount Number of intersection curves
/// @param outPoints Pointer to receive allocated point array (caller must free)
/// @param outPointCount Number of intersection points
/// @param outTangent Whether the faces are tangent
/// @return true if intersection succeeded
bool OCCTIntToolsFaceFace(OCCTShapeRef _Nonnull face1, OCCTShapeRef _Nonnull face2,
    double tolerance,
    OCCTFaceFaceCurve* _Nullable * _Nonnull outCurves, int32_t* _Nonnull outCurveCount,
    OCCTFaceFacePoint* _Nullable * _Nonnull outPoints, int32_t* _Nonnull outPointCount,
    bool* _Nonnull outTangent);

/// Classify a 2D point with respect to a face's boundary.
/// @param face Input face
/// @param u, v 2D point coordinates in face parameter space
/// @param tolerance Classification tolerance
/// @return 0=IN, 1=ON, 2=OUT, 3=UNKNOWN
int32_t OCCTIntToolsFClass2dPerform(OCCTShapeRef _Nonnull face, double u, double v, double tolerance);

/// Check if a face represents a hole (inner wire orientation).
/// @param face Input face
/// @param tolerance Classification tolerance
/// @return true if the face is a hole
bool OCCTIntToolsFClass2dIsHole(OCCTShapeRef _Nonnull face, double tolerance);

// MARK: - BOPAlgo Builder (v0.70.0)

/// Build faces from edges on a base face.
/// @param baseFace The face that provides the surface
/// @param edges Array of edge shapes to build faces from
/// @param edgeCount Number of edges
/// @param outFaces Pointer to receive allocated array of face shapes (caller must free each + array)
/// @param outFaceCount Number of result faces
/// @return true if succeeded
bool OCCTBOPAlgoBuilderFace(OCCTShapeRef _Nonnull baseFace,
    const OCCTShapeRef _Nonnull * _Nonnull edges, int32_t edgeCount,
    OCCTShapeRef _Nullable * _Nullable * _Nonnull outFaces, int32_t* _Nonnull outFaceCount);

/// Build solids from faces.
/// @param faces Array of face shapes
/// @param faceCount Number of faces
/// @param outSolids Pointer to receive allocated array of solid shapes (caller must free each + array)
/// @param outSolidCount Number of result solids
/// @return true if succeeded
bool OCCTBOPAlgoBuilderSolid(const OCCTShapeRef _Nonnull * _Nonnull faces, int32_t faceCount,
    OCCTShapeRef _Nullable * _Nullable * _Nonnull outSolids, int32_t* _Nonnull outSolidCount);

/// Split a shell into connected components.
/// @param shell Input shell shape
/// @param outShells Pointer to receive allocated array of shell shapes (caller must free each + array)
/// @param outShellCount Number of result shells
/// @return true if succeeded
bool OCCTBOPAlgoShellSplitter(OCCTShapeRef _Nonnull shell,
    OCCTShapeRef _Nullable * _Nullable * _Nonnull outShells, int32_t* _Nonnull outShellCount);

/// Convert a set of edges into wires.
/// @param edges Compound of edges
/// @param tolerance Tolerance for connecting edges
/// @return Result compound of wires, or NULL on failure
OCCTShapeRef _Nullable OCCTBOPAlgoEdgesToWires(OCCTShapeRef _Nonnull edges, double tolerance);

/// Convert a set of wires into faces.
/// @param wires Compound of wires
/// @param tolerance Tolerance for face building
/// @return Result compound of faces, or NULL on failure
OCCTShapeRef _Nullable OCCTBOPAlgoWiresToFaces(OCCTShapeRef _Nonnull wires, double tolerance);

// MARK: - BOPTools (v0.70.0)

/// Get the normal to a face at an edge.
/// @param edge Edge on the face
/// @param face Face containing the edge
/// @param outNX/NY/NZ Output normal direction
/// @return true if succeeded
bool OCCTBOPToolsNormalOnEdge(OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull face,
    double* _Nonnull outNX, double* _Nonnull outNY, double* _Nonnull outNZ);

/// Find a point strictly inside a face.
/// @param face Input face
/// @param outX/Y/Z Output 3D point
/// @return true if a point was found
bool OCCTBOPToolsPointInFace(OCCTShapeRef _Nonnull face,
    double* _Nonnull outX, double* _Nonnull outY, double* _Nonnull outZ);

/// Check if a shape is empty (has no sub-shapes).
bool OCCTBOPToolsIsEmptyShape(OCCTShapeRef _Nonnull shape);

/// Check if a shell is open (not all edges are shared by two faces).
bool OCCTBOPToolsIsOpenShell(OCCTShapeRef _Nonnull shell);

// MARK: - IntTools_BeanFaceIntersector (v0.71.0)

/// Result range from bean-face intersection.
typedef struct {
    double first;
    double last;
} OCCTParameterRange;

/// Intersect an edge curve with a face surface to find coincident ranges.
/// @param edge The edge
/// @param face The face
/// @param outRanges Pointer to receive allocated array of ranges (caller must free)
/// @param outCount Number of ranges found
/// @param outMinSquareDist Minimum square distance between edge and face
/// @return true if intersection succeeded
bool OCCTIntToolsBeanFaceIntersect(OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull face,
    OCCTParameterRange* _Nullable * _Nonnull outRanges, int32_t* _Nonnull outCount,
    double* _Nonnull outMinSquareDist);

// MARK: - BOPAlgo_WireSplitter (v0.71.0)

/// Build a wire from a list of edges (static utility).
/// @param edges Array of edge shapes
/// @param edgeCount Number of edges
/// @return Result wire as shape, or NULL on failure
OCCTShapeRef _Nullable OCCTBOPAlgoMakeWire(const OCCTShapeRef _Nonnull * _Nonnull edges, int32_t edgeCount);

// MARK: - BRepFeat_SplitShape (v0.71.0)

/// Split a shape by adding an edge to a face.
/// @param shape Input shape to split
/// @param edge Edge to add as split line
/// @param face Face on which to add the edge
/// @return Result shape, or NULL on failure
OCCTShapeRef _Nullable OCCTBRepFeatSplitShapeEdge(OCCTShapeRef _Nonnull shape,
    OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull face);

/// Split a shape by adding a wire to a face.
/// @param shape Input shape to split
/// @param wire Wire to add as split line
/// @param face Face on which to add the wire
/// @return Result shape, or NULL on failure
OCCTShapeRef _Nullable OCCTBRepFeatSplitShapeWire(OCCTShapeRef _Nonnull shape,
    OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nonnull face);

/// Split a shape by adding edges/wires to faces, with left/right face outputs.
/// @param shape Input shape to split
/// @param edgesOnFaces Array of (edge, face) pairs — alternating edge, face shapes
/// @param pairCount Number of (edge, face) pairs (array has 2*pairCount elements)
/// @param outLeft Pointer to receive allocated array of left-side face shapes (caller must free each + array)
/// @param outLeftCount Number of left faces
/// @param outRight Pointer to receive allocated array of right-side face shapes (caller must free each + array)
/// @param outRightCount Number of right faces
/// @return Result shape, or NULL on failure
OCCTShapeRef _Nullable OCCTBRepFeatSplitShapeWithSides(OCCTShapeRef _Nonnull shape,
    const OCCTShapeRef _Nonnull * _Nonnull edgesOnFaces, int32_t pairCount,
    OCCTShapeRef _Nullable * _Nullable * _Nonnull outLeft, int32_t* _Nonnull outLeftCount,
    OCCTShapeRef _Nullable * _Nullable * _Nonnull outRight, int32_t* _Nonnull outRightCount);

// MARK: - BRepFeat_MakeCylindricalHole (v0.71.0)

/// Drill a through cylindrical hole in a shape.
/// @param shape Input solid shape
/// @param axisOriginX/Y/Z Axis origin
/// @param axisDirX/Y/Z Axis direction
/// @param radius Hole radius
/// @return Result shape with hole, or NULL on failure
OCCTShapeRef _Nullable OCCTBRepFeatCylindricalHole(OCCTShapeRef _Nonnull shape,
    double axisOriginX, double axisOriginY, double axisOriginZ,
    double axisDirX, double axisDirY, double axisDirZ,
    double radius);

/// Drill a blind cylindrical hole in a shape.
/// @param shape Input solid shape
/// @param axisOriginX/Y/Z Axis origin
/// @param axisDirX/Y/Z Axis direction
/// @param radius Hole radius
/// @param depth Hole depth
/// @return Result shape with hole, or NULL on failure
OCCTShapeRef _Nullable OCCTBRepFeatCylindricalHoleBlind(OCCTShapeRef _Nonnull shape,
    double axisOriginX, double axisOriginY, double axisOriginZ,
    double axisDirX, double axisDirY, double axisDirZ,
    double radius, double depth);

/// Drill a cylindrical hole through to the next face.
/// @return Result shape, or NULL on failure
OCCTShapeRef _Nullable OCCTBRepFeatCylindricalHoleThruNext(OCCTShapeRef _Nonnull shape,
    double axisOriginX, double axisOriginY, double axisOriginZ,
    double axisDirX, double axisDirY, double axisDirZ,
    double radius);

/// Get the status of the last cylindrical hole operation.
/// @return 0 = NoError, 1 = InvalidPlacement, 2 = HoleTooLong
int32_t OCCTBRepFeatCylindricalHoleStatus(OCCTShapeRef _Nonnull shape,
    double axisOriginX, double axisOriginY, double axisOriginZ,
    double axisDirX, double axisDirY, double axisDirZ,
    double radius);

// MARK: - BRepFeat_Gluer (v0.71.0)

/// Glue two shapes together by binding matching faces.
/// @param baseShape The base shape
/// @param gluedShape The shape to glue onto the base
/// @param baseFaces Array of base shape faces to bind
/// @param gluedFaces Array of glued shape faces to bind (same count)
/// @param faceCount Number of face pairs
/// @return Result glued shape, or NULL on failure
OCCTShapeRef _Nullable OCCTBRepFeatGluer(OCCTShapeRef _Nonnull baseShape,
    OCCTShapeRef _Nonnull gluedShape,
    const OCCTShapeRef _Nonnull * _Nonnull baseFaces,
    const OCCTShapeRef _Nonnull * _Nonnull gluedFaces,
    int32_t faceCount);

// MARK: - LocOpe_WiresOnShape + LocOpe_Spliter (v0.71.0)

/// Split a shape by projecting wires onto faces using LocOpe_WiresOnShape + LocOpe_Spliter.
/// @param shape Input shape
/// @param wiresOnFaces Array of (wire, face) pairs — alternating wire, face shapes
/// @param pairCount Number of (wire, face) pairs
/// @param outDirectLeft Pointer to receive allocated array of directly-left face shapes
/// @param outDirectLeftCount Number of directly-left faces
/// @return Result shape, or NULL on failure
OCCTShapeRef _Nullable OCCTLocOpeSplitByWires(OCCTShapeRef _Nonnull shape,
    const OCCTShapeRef _Nonnull * _Nonnull wiresOnFaces, int32_t pairCount,
    OCCTShapeRef _Nullable * _Nullable * _Nonnull outDirectLeft, int32_t* _Nonnull outDirectLeftCount);

/// Bind all edges of wires to shape faces automatically, then split.
/// @param shape Input shape
/// @param wires Array of wire shapes to project onto shape
/// @param wireCount Number of wires
/// @return Result shape, or NULL on failure
OCCTShapeRef _Nullable OCCTLocOpeSplitByWiresAuto(OCCTShapeRef _Nonnull shape,
    const OCCTShapeRef _Nonnull * _Nonnull wires, int32_t wireCount);

// MARK: - LocOpe_Gluer (v0.72.0)

/// Glue two shapes by binding matching faces and edges using LocOpe_Gluer.
/// @param baseShape Base shape
/// @param gluedShape Shape to glue onto base
/// @param baseFaces Base shape faces to bind (parallel array with gluedFaces)
/// @param gluedFaces Glued shape faces to bind
/// @param faceCount Number of face pairs
/// @param baseEdges Base shape edges to bind (parallel array with gluedEdges), may be NULL
/// @param gluedEdges Glued shape edges to bind, may be NULL
/// @param edgeCount Number of edge pairs
/// @return Result shape, or NULL on failure
OCCTShapeRef _Nullable OCCTLocOpeGlue(OCCTShapeRef _Nonnull baseShape,
    OCCTShapeRef _Nonnull gluedShape,
    const OCCTShapeRef _Nonnull * _Nonnull baseFaces,
    const OCCTShapeRef _Nonnull * _Nonnull gluedFaces,
    int32_t faceCount,
    const OCCTShapeRef _Nullable * _Nullable baseEdges,
    const OCCTShapeRef _Nullable * _Nullable gluedEdges,
    int32_t edgeCount);

// MARK: - ChFi2d_Builder (v0.72.0)

/// Add a 2D fillet at a vertex on a planar face.
/// @param face Planar face shape
/// @param vertexIndex 0-based vertex index
/// @param radius Fillet radius
/// @return Result face with fillet, or NULL on failure
OCCTShapeRef _Nullable OCCTChFi2dAddFillet(OCCTShapeRef _Nonnull face,
    int32_t vertexIndex, double radius);

/// Add a 2D chamfer between two edges on a planar face (two distances).
/// @param face Planar face shape
/// @param edge1Index 0-based index of first edge
/// @param edge2Index 0-based index of second edge
/// @param d1 Distance on first edge
/// @param d2 Distance on second edge
/// @return Result face with chamfer, or NULL on failure
OCCTShapeRef _Nullable OCCTChFi2dAddChamfer(OCCTShapeRef _Nonnull face,
    int32_t edge1Index, int32_t edge2Index, double d1, double d2);

/// Add a 2D chamfer at a vertex on a planar face (distance + angle).
/// @param face Planar face shape
/// @param edgeIndex 0-based edge index
/// @param vertexIndex 0-based vertex index on that edge
/// @param distance Distance on edge
/// @param angle Chamfer angle in radians
/// @return Result face with chamfer, or NULL on failure
OCCTShapeRef _Nullable OCCTChFi2dAddChamferAngle(OCCTShapeRef _Nonnull face,
    int32_t edgeIndex, int32_t vertexIndex, double distance, double angle);

/// Modify an existing fillet radius on a face using ChFi2d_Builder.
/// @param originalFace The original face before any fillet was added
/// @param modifiedFace The face with existing fillet
/// @param filletEdgeIndex 0-based index of the fillet edge in modified face
/// @param newRadius New fillet radius
/// @return Result face with modified fillet, or NULL on failure
OCCTShapeRef _Nullable OCCTChFi2dModifyFillet(OCCTShapeRef _Nonnull originalFace,
    OCCTShapeRef _Nonnull modifiedFace, int32_t filletEdgeIndex, double newRadius);

/// Remove a fillet from a face using ChFi2d_Builder.
/// @param originalFace The original face before fillet was added
/// @param modifiedFace The face with existing fillet
/// @param filletEdgeIndex 0-based index of the fillet edge in modified face
/// @return Result face with fillet removed, or NULL on failure
OCCTShapeRef _Nullable OCCTChFi2dRemoveFillet(OCCTShapeRef _Nonnull originalFace,
    OCCTShapeRef _Nonnull modifiedFace, int32_t filletEdgeIndex);

/// Remove a chamfer from a face using ChFi2d_Builder.
/// @param originalFace The original face before chamfer was added
/// @param modifiedFace The face with existing chamfer
/// @param chamferEdgeIndex 0-based index of the chamfer edge in modified face
/// @return Result face with chamfer removed, or NULL on failure
OCCTShapeRef _Nullable OCCTChFi2dRemoveChamfer(OCCTShapeRef _Nonnull originalFace,
    OCCTShapeRef _Nonnull modifiedFace, int32_t chamferEdgeIndex);

// MARK: - ChFi2d_ChamferAPI (v0.72.0)

/// Result of a 2D chamfer operation between two edges.
typedef struct {
    OCCTShapeRef _Nullable chamferEdge;
    OCCTShapeRef _Nullable modifiedEdge1;
    OCCTShapeRef _Nullable modifiedEdge2;
} OCCTChamfer2DResult;

/// Create a chamfer between two linear edges.
/// @param edge1 First edge
/// @param edge2 Second edge
/// @param d1 Distance on first edge
/// @param d2 Distance on second edge
/// @return Chamfer result with chamfer edge and modified edges
OCCTChamfer2DResult OCCTChFi2dChamferEdges(OCCTShapeRef _Nonnull edge1,
    OCCTShapeRef _Nonnull edge2, double d1, double d2);

// MARK: - ChFi2d_FilletAPI (v0.72.0)

/// Result of a 2D fillet operation between two edges.
typedef struct {
    OCCTShapeRef _Nullable filletEdge;
    OCCTShapeRef _Nullable modifiedEdge1;
    OCCTShapeRef _Nullable modifiedEdge2;
    int32_t solutionCount;
} OCCTFillet2DResult;

/// Create a fillet between two edges in a plane.
/// @param edge1 First edge
/// @param edge2 Second edge
/// @param planeNx/Ny/Nz Plane normal
/// @param radius Fillet radius
/// @param nearX/Y/Z Point near desired fillet location
/// @return Fillet result with fillet edge, modified edges, and solution count
OCCTFillet2DResult OCCTChFi2dFilletEdges(OCCTShapeRef _Nonnull edge1,
    OCCTShapeRef _Nonnull edge2,
    double planeNx, double planeNy, double planeNz,
    double radius,
    double nearX, double nearY, double nearZ);

// MARK: - FilletSurf_Builder (v0.72.0)

/// Info about a single fillet surface from FilletSurf_Builder.
typedef struct {
    OCCTSurfaceRef _Nullable surface;
    OCCTShapeRef _Nullable supportFace1;
    OCCTShapeRef _Nullable supportFace2;
    double tolerance;
    double firstParam;
    double lastParam;
    int32_t startStatus; // FilletSurf_StatusType: 0=OneExtremityOnFace, 1=TwoExtremityOnFace, etc.
    int32_t endStatus;
} OCCTFilletSurfInfo;

/// Compute fillet surfaces on a shape.
/// @param shape Input shape
/// @param edges Array of edge shapes to fillet
/// @param edgeCount Number of edges
/// @param radius Fillet radius
/// @param outSurfaces Pointer to receive allocated array of fillet surface info (caller must free surfaces + array)
/// @param outCount Number of fillet surfaces
/// @return 0=IsOk, 1=IsNotOk, 2=IsPartial
int32_t OCCTFilletSurfBuild(OCCTShapeRef _Nonnull shape,
    const OCCTShapeRef _Nonnull * _Nonnull edges, int32_t edgeCount,
    double radius,
    OCCTFilletSurfInfo* _Nullable * _Nonnull outSurfaces, int32_t* _Nonnull outCount);

/// Get the error status when FilletSurf_Builder fails.
/// @return 0=EdgeNotG1, 1=FacesNotG1, 2=EdgeNotOnShape, 3=NotSharpEdge, 4=PbFilletCompute
int32_t OCCTFilletSurfError(OCCTShapeRef _Nonnull shape,
    const OCCTShapeRef _Nonnull * _Nonnull edges, int32_t edgeCount,
    double radius);

// MARK: - v0.73.0: TKHlr — Extended HLR, ReflectLines, TopCnx, Intrv

/// Extended HLR edge category type for fine-grained edge extraction
typedef enum {
    OCCTHLREdgeVisibleSharp = 0,     ///< Visible C0-continuity (sharp) edges
    OCCTHLREdgeVisibleSmooth = 1,    ///< Visible G1-continuity (smooth) edges
    OCCTHLREdgeVisibleSewn = 2,      ///< Visible CN-continuity (sewn) edges
    OCCTHLREdgeVisibleOutline = 3,   ///< Visible silhouette/outline edges
    OCCTHLREdgeVisibleIso = 4,       ///< Visible isoparameter lines (exact HLR only)
    OCCTHLREdgeVisibleOutline3d = 5, ///< Visible outline edges in 3D (exact HLR only)
    OCCTHLREdgeHiddenSharp = 6,      ///< Hidden C0-continuity (sharp) edges
    OCCTHLREdgeHiddenSmooth = 7,     ///< Hidden G1-continuity (smooth) edges
    OCCTHLREdgeHiddenSewn = 8,       ///< Hidden CN-continuity (sewn) edges
    OCCTHLREdgeHiddenOutline = 9,    ///< Hidden silhouette/outline edges
    OCCTHLREdgeHiddenIso = 10        ///< Hidden isoparameter lines (exact HLR only)
} OCCTHLREdgeCategory;

/// Get edges by fine-grained category from an exact HLR drawing.
/// @param shape Input shape
/// @param dirX,dirY,dirZ View direction
/// @param category Edge category to extract
/// @return Shape containing edges, or NULL if none
OCCTShapeRef _Nullable OCCTHLRGetEdgesByCategory(OCCTShapeRef _Nonnull shape,
    double dirX, double dirY, double dirZ,
    OCCTHLREdgeCategory category);

/// Get edges by fine-grained category from a polygon-based (fast) HLR drawing.
/// Note: IsoLine and Outline3d categories are not available for poly HLR (returns NULL).
/// @param shape Input shape (meshed internally for the polyhedral projection)
/// @param dirX,dirY,dirZ View direction
/// @param category Edge category to extract
/// @param deflection Linear mesh deflection (mm) for the internal triangulation —
///        smaller = finer drawing (more, shorter edges), larger = coarser/faster
/// @return Shape containing edges, or NULL if none
OCCTShapeRef _Nullable OCCTHLRPolyGetEdgesByCategory(OCCTShapeRef _Nonnull shape,
    double dirX, double dirY, double dirZ,
    OCCTHLREdgeCategory category, double deflection);

/// Get edges using the generic CompoundOfEdges API from exact HLR.
/// @param shape Input shape
/// @param dirX,dirY,dirZ View direction
/// @param edgeType 0=Undefined, 1=IsoLine, 2=OutLine, 3=Rg1Line, 4=RgNLine, 5=Sharp
/// @param visible true for visible edges, false for hidden
/// @param in3d true for 3D result, false for 2D projected
/// @return Shape containing edges, or NULL if none
OCCTShapeRef _Nullable OCCTHLRCompoundOfEdges(OCCTShapeRef _Nonnull shape,
    double dirX, double dirY, double dirZ,
    int32_t edgeType, bool visible, bool in3d);

// --- HLRAppli_ReflectLines ---

/// Compute reflect (silhouette) lines on a shape.
/// @param shape Input shape
/// @param nx,ny,nz View plane normal direction
/// @param xAt,yAt,zAt View target point
/// @param xUp,yUp,zUp Up direction
/// @return Compound of reflect line edges in 3D, or NULL on failure
OCCTShapeRef _Nullable OCCTHLRReflectLines(OCCTShapeRef _Nonnull shape,
    double nx, double ny, double nz,
    double xAt, double yAt, double zAt,
    double xUp, double yUp, double zUp);

/// Compute reflect lines and get specific edge types.
/// @param shape Input shape
/// @param nx,ny,nz View plane normal direction
/// @param xAt,yAt,zAt View target point
/// @param xUp,yUp,zUp Up direction
/// @param edgeType 0=Undefined, 1=IsoLine, 2=OutLine, 3=Rg1Line, 4=RgNLine, 5=Sharp
/// @param visible true for visible, false for hidden
/// @param in3d true for 3D result, false for 2D projected
/// @return Compound of edges, or NULL on failure
OCCTShapeRef _Nullable OCCTHLRReflectLinesFiltered(OCCTShapeRef _Nonnull shape,
    double nx, double ny, double nz,
    double xAt, double yAt, double zAt,
    double xUp, double yUp, double zUp,
    int32_t edgeType, bool visible, bool in3d);

// --- TopCnx_EdgeFaceTransition ---

/// Result of edge-face transition computation.
typedef struct {
    int32_t transition;          ///< TopAbs_Orientation: 0=FORWARD, 1=REVERSED, 2=INTERNAL, 3=EXTERNAL
    int32_t boundaryTransition;  ///< TopAbs_Orientation for boundary
} OCCTEdgeFaceTransitionResult;

/// Compute cumulated edge-face transition for multiple face interferences on an edge.
/// @param edgeTangentX,Y,Z Edge tangent direction
/// @param edgeNormalX,Y,Z Edge normal direction (0,0,0 for linear edge)
/// @param edgeCurvature Edge curvature (0 for linear edge)
/// @param faceTangentX,Y,Z Array of face tangent directions (3 doubles per face)
/// @param faceNormalX,Y,Z Array of face normal directions (3 doubles per face)
/// @param faceCurvatures Array of face curvatures at edge
/// @param faceOrientations Array of face orientations (TopAbs_Orientation values)
/// @param faceTransitions Array of face transitions (TopAbs_Orientation values)
/// @param faceBoundaryTr Array of face boundary transitions (TopAbs_Orientation values)
/// @param tolerances Array of tolerances per face
/// @param faceCount Number of faces
/// @return Transition result
OCCTEdgeFaceTransitionResult OCCTTopCnxEdgeFaceTransition(
    double edgeTangentX, double edgeTangentY, double edgeTangentZ,
    double edgeNormalX, double edgeNormalY, double edgeNormalZ,
    double edgeCurvature,
    const double* _Nonnull faceTangents,
    const double* _Nonnull faceNormals,
    const double* _Nonnull faceCurvatures,
    const int32_t* _Nonnull faceOrientations,
    const int32_t* _Nonnull faceTransitions,
    const int32_t* _Nonnull faceBoundaryTransitions,
    const double* _Nonnull tolerances,
    int32_t faceCount);

// --- Intrv_Interval ---

/// Opaque handle for an interval with tolerances
typedef struct OCCTIntrvInterval* OCCTIntrvIntervalRef;

/// Create an interval [start, end] with optional tolerances.
OCCTIntrvIntervalRef _Nonnull OCCTIntrvIntervalCreate(double start, double end,
    float tolStart, float tolEnd);

/// Release an interval.
void OCCTIntrvIntervalRelease(OCCTIntrvIntervalRef _Nonnull interval);

/// Get interval bounds.
typedef struct {
    double start;
    double end;
    float tolStart;
    float tolEnd;
} OCCTIntrvBounds;

OCCTIntrvBounds OCCTIntrvIntervalBounds(OCCTIntrvIntervalRef _Nonnull interval);

/// Check if interval is probably empty.
bool OCCTIntrvIntervalIsProbablyEmpty(OCCTIntrvIntervalRef _Nonnull interval);

/// Get position of interval relative to another.
/// Returns Intrv_Position enum: 0=Before, 1=JustBefore, 2=OverlappingAtStart, ...12=After
int32_t OCCTIntrvIntervalPosition(OCCTIntrvIntervalRef _Nonnull interval,
    OCCTIntrvIntervalRef _Nonnull other);

/// Check spatial relationships between intervals.
bool OCCTIntrvIntervalIsBefore(OCCTIntrvIntervalRef _Nonnull interval,
    OCCTIntrvIntervalRef _Nonnull other);
bool OCCTIntrvIntervalIsAfter(OCCTIntrvIntervalRef _Nonnull interval,
    OCCTIntrvIntervalRef _Nonnull other);
bool OCCTIntrvIntervalIsInside(OCCTIntrvIntervalRef _Nonnull interval,
    OCCTIntrvIntervalRef _Nonnull other);
bool OCCTIntrvIntervalIsEnclosing(OCCTIntrvIntervalRef _Nonnull interval,
    OCCTIntrvIntervalRef _Nonnull other);
bool OCCTIntrvIntervalIsSimilar(OCCTIntrvIntervalRef _Nonnull interval,
    OCCTIntrvIntervalRef _Nonnull other);

/// Modify interval bounds.
void OCCTIntrvIntervalSetStart(OCCTIntrvIntervalRef _Nonnull interval, double start, float tol);
void OCCTIntrvIntervalSetEnd(OCCTIntrvIntervalRef _Nonnull interval, double end, float tol);
void OCCTIntrvIntervalFuseAtStart(OCCTIntrvIntervalRef _Nonnull interval, double start, float tol);
void OCCTIntrvIntervalFuseAtEnd(OCCTIntrvIntervalRef _Nonnull interval, double end, float tol);
void OCCTIntrvIntervalCutAtStart(OCCTIntrvIntervalRef _Nonnull interval, double start, float tol);
void OCCTIntrvIntervalCutAtEnd(OCCTIntrvIntervalRef _Nonnull interval, double end, float tol);

// --- Intrv_Intervals ---

/// Opaque handle for a sorted sequence of non-overlapping intervals
typedef struct OCCTIntrvIntervals* OCCTIntrvIntervalsRef;

/// Create an interval sequence from a single interval.
OCCTIntrvIntervalsRef _Nonnull OCCTIntrvIntervalsCreate(double start, double end);

/// Create an empty interval sequence.
OCCTIntrvIntervalsRef _Nonnull OCCTIntrvIntervalsCreateEmpty(void);

/// Release an interval sequence.
void OCCTIntrvIntervalsRelease(OCCTIntrvIntervalsRef _Nonnull intervals);

/// Get number of intervals in the sequence.
int32_t OCCTIntrvIntervalsCount(OCCTIntrvIntervalsRef _Nonnull intervals);

/// Get bounds of interval at index (1-based).
OCCTIntrvBounds OCCTIntrvIntervalsValue(OCCTIntrvIntervalsRef _Nonnull intervals, int32_t index);

/// Set operations on interval sequences (mutate in place).
void OCCTIntrvIntervalsUnite(OCCTIntrvIntervalsRef _Nonnull intervals, double start, double end);
void OCCTIntrvIntervalsSubtract(OCCTIntrvIntervalsRef _Nonnull intervals, double start, double end);
void OCCTIntrvIntervalsIntersect(OCCTIntrvIntervalsRef _Nonnull intervals, double start, double end);
void OCCTIntrvIntervalsXUnite(OCCTIntrvIntervalsRef _Nonnull intervals, double start, double end);

// MARK: - BRepIntCurveSurface_Inter (Ray/Curve–Shape Intersection)

/// Opaque handle for BRepIntCurveSurface_Inter iterator.
typedef struct OCCTCurveSurfaceInter* OCCTCurveSurfaceInterRef;

/// Result for each intersection hit.
typedef struct {
    double x, y, z;  // Intersection point
    double u, v;      // Surface parameters
    double w;         // Curve parameter
} OCCTCurveSurfaceHit;

/// Create a line–shape intersection iterator.
OCCTCurveSurfaceInterRef _Nullable OCCTCurveSurfaceInterCreateLine(
    OCCTShapeRef _Nonnull shape,
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double tolerance);

/// Create a curve–shape intersection iterator (uses existing Curve3D).
OCCTCurveSurfaceInterRef _Nullable OCCTCurveSurfaceInterCreateCurve(
    OCCTShapeRef _Nonnull shape,
    OCCTCurve3DRef _Nonnull curve,
    double tolerance);

/// Release the iterator.
void OCCTCurveSurfaceInterRelease(OCCTCurveSurfaceInterRef _Nonnull inter);

/// Check if more results are available.
bool OCCTCurveSurfaceInterMore(OCCTCurveSurfaceInterRef _Nonnull inter);

/// Advance to next result.
void OCCTCurveSurfaceInterNext(OCCTCurveSurfaceInterRef _Nonnull inter);

/// Get current hit data.
OCCTCurveSurfaceHit OCCTCurveSurfaceInterHit(OCCTCurveSurfaceInterRef _Nonnull inter);

/// Get the face hit at current position.
OCCTFaceRef _Nullable OCCTCurveSurfaceInterFace(OCCTCurveSurfaceInterRef _Nonnull inter);

/// Collect all hits into an array. Returns count, fills hits array (caller provides buffer).
int32_t OCCTCurveSurfaceInterAllHits(OCCTCurveSurfaceInterRef _Nonnull inter,
                                      OCCTCurveSurfaceHit* _Nonnull hits,
                                      int32_t maxHits);

// MARK: - ShapeConstruct_MakeTriangulation

/// Build a triangulated face from an array of 3D points.
OCCTShapeRef _Nullable OCCTShapeConstructTriangulationFromPoints(
    const double* _Nonnull coords, int32_t pointCount);

/// Build a triangulated face from a wire.
OCCTShapeRef _Nullable OCCTShapeConstructTriangulationFromWire(OCCTWireRef _Nonnull wire);

// MARK: - ShapeCustom_Surface (additional: ConvertToPeriodic, Gap)

/// Convert surface to periodic form. Returns null if already periodic or not convertible.
OCCTSurfaceRef _Nullable OCCTSurfaceConvertToPeriodic(OCCTSurfaceRef _Nonnull surface);

/// Get gap after last ShapeCustom_Surface conversion.
double OCCTSurfaceConversionGap(OCCTSurfaceRef _Nonnull surface);

// MARK: - BRepGProp_MeshCinert (Mesh Linear Properties)

/// Prepare polygon points from a meshed edge. Returns point count, fills coords (x,y,z triples).
int32_t OCCTMeshCinertPreparePolygon(OCCTEdgeRef _Nonnull edge,
                                      double* _Nonnull coords,
                                      int32_t maxPoints);

/// Compute linear mass properties of a polygon (length, center of mass).
typedef struct {
    double mass;       // Length
    double centerX, centerY, centerZ;
} OCCTMeshCinertResult;

OCCTMeshCinertResult OCCTMeshCinertCompute(const double* _Nonnull coords, int32_t pointCount);

// MARK: - BRepGProp_MeshProps (Mesh Surface/Volume Properties)

/// Mesh property type.
typedef enum {
    OCCTMeshPropsVolume = 0,  // Vinert
    OCCTMeshPropsSurface = 1  // Sinert
} OCCTMeshPropsType;

/// Compute mesh properties for a triangulated face.
typedef struct {
    double mass;  // Area (Sinert) or volume contribution (Vinert)
    double centerX, centerY, centerZ;
} OCCTMeshPropsResult;

OCCTMeshPropsResult OCCTMeshPropsCompute(OCCTFaceRef _Nonnull face, OCCTMeshPropsType type);

// MARK: - BRepMesh_ShapeTool (Static Mesh Utilities)

/// Get maximum tolerance of edges/vertices on a face.
double OCCTMeshShapeToolMaxFaceTolerance(OCCTFaceRef _Nonnull face);

/// Get maximum dimension of a shape's bounding box.
double OCCTMeshShapeToolBoxMaxDimension(OCCTShapeRef _Nonnull shape);

/// Get UV parameter points of an edge on a face.
typedef struct {
    double u1, v1, u2, v2;
    bool success;
} OCCTUVPointsResult;

OCCTUVPointsResult OCCTMeshShapeToolUVPoints(OCCTEdgeRef _Nonnull edge, OCCTFaceRef _Nonnull face);

// MARK: - BRepLib_ValidateEdge

/// Validate edge geometry (3D curve vs curve-on-surface consistency).
typedef struct {
    bool isDone;
    bool isWithinTolerance;  // at default tolerance
    double maxDistance;
    double tolerance;        // tolerance used for check
} OCCTValidateEdgeResult;

/// Validate an edge on a face. Returns validation metrics.
OCCTValidateEdgeResult OCCTValidateEdge(OCCTEdgeRef _Nonnull edge, OCCTFaceRef _Nonnull face, double tolerance);

// MARK: - BiTgte_Blend (Rolling-Ball Blend)

/// Result of BiTgte_Blend operation.
typedef struct {
    bool isDone;
    int32_t nbSurfaces;
} OCCTBiTgteBlendInfo;

/// Create rolling-ball blend on shape edges.
OCCTShapeRef _Nullable OCCTBiTgteBlend(OCCTShapeRef _Nonnull shape,
                                        const int32_t* _Nonnull edgeIndices,
                                        int32_t edgeCount,
                                        double radius,
                                        double tolerance,
                                        bool nubs);

/// Get blend info (isDone, nbSurfaces) without building result.
OCCTBiTgteBlendInfo OCCTBiTgteBlendInfo_(OCCTShapeRef _Nonnull shape,
                                          const int32_t* _Nonnull edgeIndices,
                                          int32_t edgeCount,
                                          double radius,
                                          double tolerance);

// MARK: - GeomConvert_ApproxCurve

/// Approximate a curve as BSpline.
typedef struct {
    OCCTCurve3DRef _Nullable curve;  // result BSpline (as Curve3D)
    double maxError;
    bool isDone;
    bool hasResult;
} OCCTApproxCurveResult;

OCCTApproxCurveResult OCCTGeomConvertApproxCurve(OCCTCurve3DRef _Nonnull curve,
                                                  double tolerance,
                                                  int32_t continuity,
                                                  int32_t maxSegments,
                                                  int32_t maxDegree);

// MARK: - GeomConvert_ApproxSurface

/// Approximate a surface as BSpline surface.
typedef struct {
    OCCTSurfaceRef _Nullable surface;  // result BSpline surface
    double maxError;
    bool isDone;
    bool hasResult;
} OCCTApproxSurfaceResult;

OCCTApproxSurfaceResult OCCTGeomConvertApproxSurface(OCCTSurfaceRef _Nonnull surface,
                                                      double tolerance,
                                                      int32_t uContinuity,
                                                      int32_t vContinuity,
                                                      int32_t maxDegree,
                                                      int32_t maxSegments);

// MARK: - GCPnts_QuasiUniformAbscissa

/// Compute quasi-uniform parameter distribution on an edge curve.
/// Returns parameter count, fills params array.
int32_t OCCTGCPntsQuasiUniform(OCCTEdgeRef _Nonnull edge,
                                int32_t nbPoints,
                                double* _Nonnull params,
                                int32_t maxParams);

/// Quasi-uniform sampling on a Curve3D.
int32_t OCCTGCPntsQuasiUniformCurve(OCCTCurve3DRef _Nonnull curve,
                                      int32_t nbPoints,
                                      double* _Nonnull params,
                                      int32_t maxParams);

// MARK: - GCPnts_TangentialDeflection

/// Tangential deflection-based parameter/point sampling on an edge curve.
/// Returns point count, fills params and optionally coords (x,y,z triples).
int32_t OCCTGCPntsTangentialDeflection(OCCTEdgeRef _Nonnull edge,
                                        double angularDeflection,
                                        double curvatureDeflection,
                                        int32_t minPoints,
                                        double* _Nonnull params,
                                        double* _Nullable coords,
                                        int32_t maxPoints);

/// Tangential deflection sampling on a Curve3D.
int32_t OCCTGCPntsTangentialDeflectionCurve(OCCTCurve3DRef _Nonnull curve,
                                             double angularDeflection,
                                             double curvatureDeflection,
                                             int32_t minPoints,
                                             double* _Nonnull params,
                                             double* _Nullable coords,
                                             int32_t maxPoints);

// MARK: - BRepGProp_Cinert (Curve Inertia)

/// Compute curve linear inertia properties for an edge.
typedef struct {
    double mass;  // Length
    double centerX, centerY, centerZ;
} OCCTCurveInertiaResult;

OCCTCurveInertiaResult OCCTBRepGPropCinert(OCCTEdgeRef _Nonnull edge);

// MARK: - BRepGProp_Sinert (Surface Inertia per Face)

/// Compute surface inertia properties for a single face.
typedef struct {
    double mass;  // Area
    double centerX, centerY, centerZ;
    double epsilon;  // Adaptive integration error (0 for non-adaptive)
} OCCTFaceSurfaceInertia;

OCCTFaceSurfaceInertia OCCTBRepGPropSinert(OCCTFaceRef _Nonnull face);
OCCTFaceSurfaceInertia OCCTBRepGPropSinertAdaptive(OCCTFaceRef _Nonnull face, double epsilon);

// MARK: - BRepGProp_Vinert (Volume Inertia per Face)

/// Compute volume inertia properties from a single face.
typedef struct {
    double mass;  // Volume contribution
    double centerX, centerY, centerZ;
} OCCTFaceVolumeInertia;

OCCTFaceVolumeInertia OCCTBRepGPropVinert(OCCTFaceRef _Nonnull face);
OCCTFaceVolumeInertia OCCTBRepGPropVinertPlane(OCCTFaceRef _Nonnull face,
                                                double planeNX, double planeNY, double planeNZ,
                                                double planeDist);

// MARK: - ShapeConstruct_ProjectCurveOnSurface

/// Project a 3D curve onto a surface, returning a 2D curve.
OCCTCurve2DRef _Nullable OCCTProjectCurveOnSurface(OCCTCurve3DRef _Nonnull curve,
                                                     OCCTSurfaceRef _Nonnull surface,
                                                     double firstParam,
                                                     double lastParam,
                                                     double precision);

// MARK: - BRepPreviewAPI_MakeBox

/// Create a preview box shape (handles degenerate dimensions: face, edge, vertex).
OCCTShapeRef _Nullable OCCTPreviewBox(double dx, double dy, double dz);

// MARK: - Geom_CartesianPoint (3D Geometric Point)

typedef struct OCCTGeomPoint3D* OCCTGeomPoint3DRef;

OCCTGeomPoint3DRef _Nonnull OCCTGeomPoint3DCreate(double x, double y, double z);
void OCCTGeomPoint3DRelease(OCCTGeomPoint3DRef _Nonnull ref);
double OCCTGeomPoint3DX(OCCTGeomPoint3DRef _Nonnull ref);
double OCCTGeomPoint3DY(OCCTGeomPoint3DRef _Nonnull ref);
double OCCTGeomPoint3DZ(OCCTGeomPoint3DRef _Nonnull ref);
void OCCTGeomPoint3DSetCoord(OCCTGeomPoint3DRef _Nonnull ref, double x, double y, double z);
double OCCTGeomPoint3DDistance(OCCTGeomPoint3DRef _Nonnull ref, OCCTGeomPoint3DRef _Nonnull other);
double OCCTGeomPoint3DSquareDistance(OCCTGeomPoint3DRef _Nonnull ref, OCCTGeomPoint3DRef _Nonnull other);
void OCCTGeomPoint3DTranslate(OCCTGeomPoint3DRef _Nonnull ref, double dx, double dy, double dz);

// MARK: - Geom_Direction (3D Unit Vector)

typedef struct OCCTGeomDirection* OCCTGeomDirectionRef;

OCCTGeomDirectionRef _Nonnull OCCTGeomDirectionCreate(double x, double y, double z);
void OCCTGeomDirectionRelease(OCCTGeomDirectionRef _Nonnull ref);
void OCCTGeomDirectionCoords(OCCTGeomDirectionRef _Nonnull ref, double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);
void OCCTGeomDirectionSetCoord(OCCTGeomDirectionRef _Nonnull ref, double x, double y, double z);
/// Cross product of two unit directions, returns new direction.
OCCTGeomDirectionRef _Nullable OCCTGeomDirectionCrossed(OCCTGeomDirectionRef _Nonnull ref, OCCTGeomDirectionRef _Nonnull other);

// MARK: - Geom_VectorWithMagnitude (3D Vector)

typedef struct OCCTGeomVector3D* OCCTGeomVector3DRef;

OCCTGeomVector3DRef _Nonnull OCCTGeomVector3DCreate(double x, double y, double z);
OCCTGeomVector3DRef _Nonnull OCCTGeomVector3DFromPoints(double x1, double y1, double z1,
                                                         double x2, double y2, double z2);
void OCCTGeomVector3DRelease(OCCTGeomVector3DRef _Nonnull ref);
void OCCTGeomVector3DCoords(OCCTGeomVector3DRef _Nonnull ref, double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);
double OCCTGeomVector3DMagnitude(OCCTGeomVector3DRef _Nonnull ref);
double OCCTGeomVector3DDot(OCCTGeomVector3DRef _Nonnull ref, OCCTGeomVector3DRef _Nonnull other);
OCCTGeomVector3DRef _Nonnull OCCTGeomVector3DAdded(OCCTGeomVector3DRef _Nonnull ref, OCCTGeomVector3DRef _Nonnull other);
OCCTGeomVector3DRef _Nonnull OCCTGeomVector3DMultiplied(OCCTGeomVector3DRef _Nonnull ref, double scalar);
OCCTGeomVector3DRef _Nullable OCCTGeomVector3DNormalized(OCCTGeomVector3DRef _Nonnull ref);
OCCTGeomVector3DRef _Nonnull OCCTGeomVector3DCrossed(OCCTGeomVector3DRef _Nonnull ref, OCCTGeomVector3DRef _Nonnull other);

// MARK: - Geom_Axis1Placement (3D Axis)

typedef struct OCCTAxis1Placement* OCCTAxis1PlacementRef;

OCCTAxis1PlacementRef _Nonnull OCCTAxis1PlacementCreate(double px, double py, double pz,
                                                         double dx, double dy, double dz);
void OCCTAxis1PlacementRelease(OCCTAxis1PlacementRef _Nonnull ref);
void OCCTAxis1PlacementLocation(OCCTAxis1PlacementRef _Nonnull ref, double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);
void OCCTAxis1PlacementDirection(OCCTAxis1PlacementRef _Nonnull ref, double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);
void OCCTAxis1PlacementReverse(OCCTAxis1PlacementRef _Nonnull ref);
OCCTAxis1PlacementRef _Nonnull OCCTAxis1PlacementReversed(OCCTAxis1PlacementRef _Nonnull ref);
void OCCTAxis1PlacementSetDirection(OCCTAxis1PlacementRef _Nonnull ref, double dx, double dy, double dz);
void OCCTAxis1PlacementSetLocation(OCCTAxis1PlacementRef _Nonnull ref, double px, double py, double pz);

// MARK: - Geom_Axis2Placement (3D Coordinate System)

typedef struct OCCTAxis2Placement* OCCTAxis2PlacementRef;

OCCTAxis2PlacementRef _Nonnull OCCTAxis2PlacementCreate(double px, double py, double pz,
                                                         double nx, double ny, double nz,
                                                         double vx, double vy, double vz);
void OCCTAxis2PlacementRelease(OCCTAxis2PlacementRef _Nonnull ref);
void OCCTAxis2PlacementLocation(OCCTAxis2PlacementRef _Nonnull ref, double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);
void OCCTAxis2PlacementDirection(OCCTAxis2PlacementRef _Nonnull ref, double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);
void OCCTAxis2PlacementXDirection(OCCTAxis2PlacementRef _Nonnull ref, double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);
void OCCTAxis2PlacementYDirection(OCCTAxis2PlacementRef _Nonnull ref, double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);
void OCCTAxis2PlacementSetDirection(OCCTAxis2PlacementRef _Nonnull ref, double nx, double ny, double nz);
void OCCTAxis2PlacementSetXDirection(OCCTAxis2PlacementRef _Nonnull ref, double vx, double vy, double vz);

// MARK: - ShapeConstruct_Curve

/// Convert any 3D curve segment to BSpline.
OCCTCurve3DRef _Nullable OCCTShapeConstructConvertToBSpline3D(OCCTCurve3DRef _Nonnull curve,
                                                                double first, double last, double precision);
/// Convert any 2D curve segment to BSpline.
OCCTCurve2DRef _Nullable OCCTShapeConstructConvertToBSpline2D(OCCTCurve2DRef _Nonnull curve,
                                                                double first, double last, double precision);
/// Adjust 3D curve endpoints to match given points.
bool OCCTShapeConstructAdjustCurve3D(OCCTCurve3DRef _Nonnull curve,
                                      double p1x, double p1y, double p1z,
                                      double p2x, double p2y, double p2z);
/// Adjust 2D curve endpoints to match given points.
bool OCCTShapeConstructAdjustCurve2D(OCCTCurve2DRef _Nonnull curve,
                                      double p1x, double p1y,
                                      double p2x, double p2y);

// MARK: - Bisector_PointOnBis / PolyBis / Inter

typedef struct {
    double paramOnC1;
    double paramOnC2;
    double paramOnBis;
    double distance;
    double pointX, pointY;
    bool isInfinite;
} OCCTBisectorPointOnBis;

/// Create a PointOnBis value.
OCCTBisectorPointOnBis OCCTBisectorPointOnBisCreate(double param1, double param2,
                                                      double paramBis, double distance,
                                                      double px, double py);

/// Bisector intersection point result.
typedef struct {
    double x, y;
    double paramOnFirst;
    double paramOnSecond;
} OCCTBisectorIntersectionPoint;

/// Compute intersections between two point-bisectors. Returns number of intersection points.
/// Bisector of (ax,ay)-(bx,by) is intersected with bisector of (cx,cy)-(dx,dy).
int OCCTBisectorInterPointPoint(double ax, double ay, double bx, double by,
                                 double cx, double cy, double dx, double dy,
                                 OCCTBisectorIntersectionPoint* _Nullable outPoints,
                                 int maxPoints);

// MARK: - GeomLib_Tool (Parameter Finding)

/// Find parameter of 3D point on 3D curve. Returns false if point is beyond maxDist.
bool OCCTGeomLibToolParameter3D(OCCTCurve3DRef _Nonnull curve, double px, double py, double pz,
                                 double maxDist, double* _Nonnull outParam);

/// Find UV parameters of 3D point on surface. Returns false if point is beyond maxDist.
bool OCCTGeomLibToolParametersSurface(OCCTSurfaceRef _Nonnull surface,
                                       double px, double py, double pz,
                                       double maxDist,
                                       double* _Nonnull outU, double* _Nonnull outV);

/// Find parameter of 2D point on 2D curve. Returns false if point is beyond maxDist.
bool OCCTGeomLibToolParameter2D(OCCTCurve2DRef _Nonnull curve, double px, double py,
                                 double maxDist, double* _Nonnull outParam);

// MARK: - GeomLib_IsPlanarSurface

/// Check if a surface is planar within tolerance. Returns true if planar.
bool OCCTGeomLibIsPlanarSurface(OCCTSurfaceRef _Nonnull surface, double tolerance);

/// If surface is planar, get the plane parameters (origin + normal + X direction).
bool OCCTGeomLibPlanarSurfacePlane(OCCTSurfaceRef _Nonnull surface, double tolerance,
                                    double* _Nonnull ox, double* _Nonnull oy, double* _Nonnull oz,
                                    double* _Nonnull nx, double* _Nonnull ny, double* _Nonnull nz,
                                    double* _Nonnull xx, double* _Nonnull xy, double* _Nonnull xz);

// MARK: - GeomLib_CheckBSplineCurve / Check2dBSplineCurve

/// Check BSpline 3D curve for reversed end tangents. Returns true if check completed.
bool OCCTGeomLibCheckBSpline3D(OCCTCurve3DRef _Nonnull curve, double tolerance, double angularTol,
                                bool* _Nonnull needFixFirst, bool* _Nonnull needFixLast);

/// Fix BSpline 3D curve end tangents, returns new curve or NULL if not needed.
OCCTCurve3DRef _Nullable OCCTGeomLibFixBSpline3D(OCCTCurve3DRef _Nonnull curve,
                                                   double tolerance, double angularTol,
                                                   bool fixFirst, bool fixLast);

/// Check BSpline 2D curve for reversed end tangents. Returns true if check completed.
bool OCCTGeomLibCheckBSpline2D(OCCTCurve2DRef _Nonnull curve, double tolerance, double angularTol,
                                bool* _Nonnull needFixFirst, bool* _Nonnull needFixLast);

/// Fix BSpline 2D curve end tangents, returns new curve or NULL if not needed.
OCCTCurve2DRef _Nullable OCCTGeomLibFixBSpline2D(OCCTCurve2DRef _Nonnull curve,
                                                   double tolerance, double angularTol,
                                                   bool fixFirst, bool fixLast);

// MARK: - GeomLib_Interpolate

/// Interpolate 3D points at given parameters to create BSpline curve.
/// degree: polynomial degree (typically 3). numPoints: count of points/params.
OCCTCurve3DRef _Nullable OCCTGeomLibInterpolate(int degree, int numPoints,
                                                  const double* _Nonnull pointsXYZ,
                                                  const double* _Nonnull parameters);

// MARK: - GccAna_Circ2d2TanRad

/// Find circles tangent to two lines with given radius. Returns solution count.
int OCCTGccAnaCirc2d2TanRadLineLin(double l1px, double l1py, double l1dx, double l1dy,
                                     double l2px, double l2py, double l2dx, double l2dy,
                                     double radius, double tolerance,
                                     OCCTCircle2DSolution* _Nullable outSolutions, int maxSolutions);

/// Find circles through two points with given radius. Returns solution count.
int OCCTGccAnaCirc2d2TanRadPntPnt(double p1x, double p1y, double p2x, double p2y,
                                    double radius, double tolerance,
                                    OCCTCircle2DSolution* _Nullable outSolutions, int maxSolutions);

// MARK: - GccAna_Circ2dTanCen

/// Find circle through a point centered at another point. Returns solution count.
int OCCTGccAnaCirc2dTanCenPntPnt(double px, double py, double cx, double cy,
                                   OCCTCircle2DSolution* _Nullable outSolutions, int maxSolutions);

/// Find circle tangent to a line centered at a point. Returns solution count.
int OCCTGccAnaCirc2dTanCenLinPnt(double lpx, double lpy, double ldx, double ldy,
                                   double cx, double cy,
                                   OCCTCircle2DSolution* _Nullable outSolutions, int maxSolutions);

// MARK: - GccAna_Lin2d2Tan

/// Line through two points result.
typedef struct {
    double originX, originY;
    double dirX, dirY;
} OCCTLine2DSolution;

/// Find line through two points. Returns solution count (0 or 1).
int OCCTGccAnaLin2d2TanPntPnt(double p1x, double p1y, double p2x, double p2y,
                                double tolerance,
                                OCCTLine2DSolution* _Nullable outSolutions, int maxSolutions);

/// Find lines tangent to a circle through a point. Returns solution count.
int OCCTGccAnaLin2d2TanCircPnt(double cx, double cy, double radius,
                                 double px, double py, double tolerance,
                                 OCCTLine2DSolution* _Nullable outSolutions, int maxSolutions);

// MARK: - Approx_SameParameter

/// Check if 2D curve on surface has same parameterization as 3D curve.
/// Returns true if check completed. outIsSame is true if already same parameter.
/// outTolReached is the max distance between 3D curve and surface evaluation.
bool OCCTApproxSameParameter(OCCTCurve3DRef _Nonnull curve3d,
                              OCCTCurve2DRef _Nonnull curve2d,
                              OCCTSurfaceRef _Nonnull surface,
                              double tolerance,
                              bool* _Nonnull outIsSame,
                              double* _Nonnull outTolReached);

// MARK: - ShapeUpgrade_SplitCurve3dContinuity

/// Split 3D curve at continuity breaks. criterion: 0=C0, 1=C1, 2=C2, 3=C3, 4=CN.
/// Returns number of resulting curve segments, or 0 on failure.
int OCCTSplitCurve3dContinuity(OCCTCurve3DRef _Nonnull curve, int criterion, double tolerance,
                                 OCCTCurve3DRef _Nullable* _Nullable outCurves, int maxCurves);

// MARK: - ShapeUpgrade_SplitCurve2dContinuity

/// Split 2D curve at continuity breaks. criterion: 0=C0, 1=C1, 2=C2, 3=C3, 4=CN.
/// Returns number of resulting curve segments, or 0 on failure.
int OCCTSplitCurve2dContinuity(OCCTCurve2DRef _Nonnull curve, int criterion, double tolerance,
                                 OCCTCurve2DRef _Nullable* _Nullable outCurves, int maxCurves);

// MARK: - ShapeUpgrade_ConvertCurve2dToBezier

/// Convert 2D curve to Bezier segments. Returns number of segments, or 0 on failure.
int OCCTConvertCurve2dToBezier(OCCTCurve2DRef _Nonnull curve,
                                OCCTCurve2DRef _Nullable* _Nullable outCurves, int maxCurves);

// MARK: - v0.78.0: Shape Modifications, Surface Recognition & Polygon Data

// MARK: - BRepTools_TrsfModification

/// Apply a gp_Trsf transformation to a shape via BRepTools_Modifier.
/// Returns the modified shape, or NULL on failure.
OCCTShapeRef _Nullable OCCTShapeTrsfModification(OCCTShapeRef _Nonnull shapeRef,
                                                   double a11, double a12, double a13, double a14,
                                                   double a21, double a22, double a23, double a24,
                                                   double a31, double a32, double a33, double a34);

// MARK: - BRepTools_GTrsfModification

/// Apply a gp_GTrsf general transformation to a shape via BRepTools_Modifier.
/// The shape should be NURBS-converted first for non-uniform scaling.
/// Returns the modified shape, or NULL on failure.
OCCTShapeRef _Nullable OCCTShapeGTrsfModification(OCCTShapeRef _Nonnull shapeRef,
                                                    double a11, double a12, double a13, double a14,
                                                    double a21, double a22, double a23, double a24,
                                                    double a31, double a32, double a33, double a34);

// MARK: - BRepTools_CopyModification

/// Deep copy a shape via BRepTools_Modifier with optional geometry/mesh copying.
/// Returns the copied shape, or NULL on failure.
OCCTShapeRef _Nullable OCCTShapeCopyModification(OCCTShapeRef _Nonnull shapeRef,
                                                   bool copyGeometry, bool copyMesh);

// MARK: - ShapeCustom_BSplineRestriction (advanced)

/// Restrict BSpline degree and segments with full control over parameters.
/// Returns modified shape, or NULL on failure.
OCCTShapeRef _Nullable OCCTShapeBSplineRestrictionAdvanced(OCCTShapeRef _Nonnull shapeRef,
                                                             bool approxSurface, bool approxCurve3d, bool approxCurve2d,
                                                             double tol3d, double tol2d,
                                                             int continuity3d, int continuity2d,
                                                             int maxDegree, int maxSegments,
                                                             bool priorityDegree, bool convertRational);

// MARK: - ShapeCustom_ConvertToBSpline (advanced)

/// Convert surfaces of a shape to BSpline with per-type control.
/// Returns modified shape, or NULL on failure.
OCCTShapeRef _Nullable OCCTShapeConvertToBSplineAdvanced(OCCTShapeRef _Nonnull shapeRef,
                                                           bool extrusionMode, bool revolutionMode,
                                                           bool offsetMode, bool planeMode);

// MARK: - ShapeUpgrade_SplitSurfaceContinuity

/// Split a surface by continuity criterion.
/// criterion: 0=C0, 1=G1, 2=C1, 3=G2, 4=C2, 5=C3, 6=CN
/// Returns number of U split values (0 on failure).
int OCCTSplitSurfaceContinuity(OCCTSurfaceRef _Nonnull surfaceRef,
                                 int criterion, double tolerance,
                                 int* _Nullable outUSplitCount, int* _Nullable outVSplitCount);

// MARK: - ShapeUpgrade_SplitSurfaceAngle

/// Split a surface by maximum angle (radians).
/// Returns number of U split values (0 on failure).
int OCCTSplitSurfaceAngle(OCCTSurfaceRef _Nonnull surfaceRef, double maxAngle,
                            int* _Nullable outUSplitCount, int* _Nullable outVSplitCount);

// MARK: - ShapeUpgrade_SplitSurfaceArea

/// Split a surface into approximately equal-area parts.
/// Returns number of U split values (0 on failure).
int OCCTSplitSurfaceArea(OCCTSurfaceRef _Nonnull surfaceRef, int nbParts, bool intoSquares,
                           int* _Nullable outUSplitCount, int* _Nullable outVSplitCount);

// MARK: - GeomConvert_CurveToAnaCurve

/// Result struct for curve-to-analytical conversion.
typedef struct {
    OCCTCurve3DRef _Nullable curve;
    double newFirst;
    double newLast;
    double gap;
    bool success;
} OCCTCurveToAnaCurveResult;

/// Convert a BSpline curve to an analytical curve (line, circle, ellipse).
OCCTCurveToAnaCurveResult OCCTGeomConvertCurveToAnalytical(OCCTCurve3DRef _Nonnull curveRef,
                                                             double tolerance, double first, double last);

/// Check if an array of points is linear within tolerance.
bool OCCTGeomConvertIsLinear(const double* _Nonnull points, int count, double tolerance,
                               double* _Nullable deviation);

// MARK: - GeomConvert_SurfToAnaSurf

/// Result struct for surface-to-analytical conversion.
typedef struct {
    OCCTSurfaceRef _Nullable surface;
    double gap;
    bool success;
} OCCTSurfToAnaSurfResult;

/// Convert a BSpline surface to an analytical surface (plane, cylinder, cone, sphere, torus).
OCCTSurfToAnaSurfResult OCCTGeomConvertSurfToAnalytical(OCCTSurfaceRef _Nonnull surfaceRef, double tolerance);

/// Convert with UV bounds.
OCCTSurfToAnaSurfResult OCCTGeomConvertSurfToAnalyticalBounded(OCCTSurfaceRef _Nonnull surfaceRef,
                                                                  double tolerance,
                                                                  double uMin, double uMax,
                                                                  double vMin, double vMax);

/// Check if a surface is already canonical (analytical).
bool OCCTGeomConvertIsCanonical(OCCTSurfaceRef _Nonnull surfaceRef);

// MARK: - Geom2dConvert_ApproxArcsSegments

/// Approximate a 2D curve as arcs and line segments.
/// Returns number of resulting curves, or 0 on failure.
int OCCTGeom2dConvertApproxArcsSegments(OCCTCurve2DRef _Nonnull curveRef,
                                          double tolerance, double angleTolerance,
                                          OCCTCurve2DRef _Nullable* _Nullable outCurves, int maxCurves);

// MARK: - Poly_Polygon2D

typedef struct Poly_Polygon2DOpaque* OCCTPolyPolygon2DRef;

/// Create a 2D polygon from points (x,y pairs).
OCCTPolyPolygon2DRef _Nullable OCCTPolyPolygon2DCreate(const double* _Nonnull points, int count);

/// Get number of nodes.
int OCCTPolyPolygon2DNbNodes(OCCTPolyPolygon2DRef _Nonnull ref);

/// Get a node's coordinates (0-based index). Returns false if out of range.
bool OCCTPolyPolygon2DNode(OCCTPolyPolygon2DRef _Nonnull ref, int index,
                             double* _Nonnull x, double* _Nonnull y);

/// Get/set deflection.
double OCCTPolyPolygon2DDeflection(OCCTPolyPolygon2DRef _Nonnull ref);
void OCCTPolyPolygon2DSetDeflection(OCCTPolyPolygon2DRef _Nonnull ref, double deflection);

/// Release.
void OCCTPolyPolygon2DRelease(OCCTPolyPolygon2DRef _Nonnull ref);

// MARK: - Poly_Triangulation (v0.160.0)

typedef struct Poly_TriangulationOpaque* OCCTPolyTriangulationRef;

/// Create a Poly_Triangulation from flat node and triangle arrays.
/// - Parameter nodes: flat array of node coordinates (count*3 doubles).
/// - Parameter nbNodes: number of nodes.
/// - Parameter triangles: flat array of triangle vertex indices, 0-based (count*3 ints).
/// - Parameter nbTriangles: number of triangles.
OCCTPolyTriangulationRef _Nullable OCCTPolyTriangulationCreate(
    const double* _Nonnull nodes, int nbNodes,
    const int* _Nonnull triangles, int nbTriangles);

/// Number of nodes.
int OCCTPolyTriangulationNbNodes(OCCTPolyTriangulationRef _Nonnull ref);

/// Number of triangles.
int OCCTPolyTriangulationNbTriangles(OCCTPolyTriangulationRef _Nonnull ref);

/// Get a node's coordinates (0-based index in Swift, 1-based internally).
bool OCCTPolyTriangulationNode(OCCTPolyTriangulationRef _Nonnull ref, int index,
                                 double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Get a triangle's three node indices (0-based externally, returns 0-based indices).
bool OCCTPolyTriangulationTriangle(OCCTPolyTriangulationRef _Nonnull ref, int index,
                                     int* _Nonnull n1, int* _Nonnull n2, int* _Nonnull n3);

/// Get / set deflection.
double OCCTPolyTriangulationDeflection(OCCTPolyTriangulationRef _Nonnull ref);
void OCCTPolyTriangulationSetDeflection(OCCTPolyTriangulationRef _Nonnull ref, double deflection);

/// Release.
void OCCTPolyTriangulationRelease(OCCTPolyTriangulationRef _Nonnull ref);

// MARK: - Poly_Polygon3D

typedef struct Poly_Polygon3DOpaque* OCCTPolyPolygon3DRef;

/// Create a 3D polygon from points (x,y,z triples).
OCCTPolyPolygon3DRef _Nullable OCCTPolyPolygon3DCreate(const double* _Nonnull points, int count);

/// Create a 3D polygon from points with parameters.
OCCTPolyPolygon3DRef _Nullable OCCTPolyPolygon3DCreateWithParams(const double* _Nonnull points, int count,
                                                                    const double* _Nonnull params);

/// Get number of nodes.
int OCCTPolyPolygon3DNbNodes(OCCTPolyPolygon3DRef _Nonnull ref);

/// Get a node's coordinates (0-based index).
bool OCCTPolyPolygon3DNode(OCCTPolyPolygon3DRef _Nonnull ref, int index,
                             double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Check if polygon has parameters.
bool OCCTPolyPolygon3DHasParameters(OCCTPolyPolygon3DRef _Nonnull ref);

/// Get parameter at index (0-based).
double OCCTPolyPolygon3DParameter(OCCTPolyPolygon3DRef _Nonnull ref, int index);

/// Get/set deflection.
double OCCTPolyPolygon3DDeflection(OCCTPolyPolygon3DRef _Nonnull ref);
void OCCTPolyPolygon3DSetDeflection(OCCTPolyPolygon3DRef _Nonnull ref, double deflection);

/// Release.
void OCCTPolyPolygon3DRelease(OCCTPolyPolygon3DRef _Nonnull ref);

// MARK: - Poly_PolygonOnTriangulation

typedef struct Poly_PolygonOnTriangulationOpaque* OCCTPolyPolygonOnTriRef;

/// Create a polygon on triangulation from node indices (0-based in Swift, 1-based internally).
OCCTPolyPolygonOnTriRef _Nullable OCCTPolyPolygonOnTriCreate(const int* _Nonnull nodeIndices, int count);

/// Create with parameters.
OCCTPolyPolygonOnTriRef _Nullable OCCTPolyPolygonOnTriCreateWithParams(const int* _Nonnull nodeIndices, int count,
                                                                         const double* _Nonnull params);

/// Get number of nodes.
int OCCTPolyPolygonOnTriNbNodes(OCCTPolyPolygonOnTriRef _Nonnull ref);

/// Get node index at position (0-based).
int OCCTPolyPolygonOnTriNode(OCCTPolyPolygonOnTriRef _Nonnull ref, int index);

/// Check if has parameters.
bool OCCTPolyPolygonOnTriHasParameters(OCCTPolyPolygonOnTriRef _Nonnull ref);

/// Get parameter at index (0-based).
double OCCTPolyPolygonOnTriParameter(OCCTPolyPolygonOnTriRef _Nonnull ref, int index);

/// Get/set deflection.
double OCCTPolyPolygonOnTriDeflection(OCCTPolyPolygonOnTriRef _Nonnull ref);
void OCCTPolyPolygonOnTriSetDeflection(OCCTPolyPolygonOnTriRef _Nonnull ref, double deflection);

/// Release.
void OCCTPolyPolygonOnTriRelease(OCCTPolyPolygonOnTriRef _Nonnull ref);

// MARK: - Poly_MergeNodesTool

/// Merge nodes of a shape's face triangulations. Returns merged vertex count, 0 on failure.
/// smoothAngle: angle threshold for normal smoothing (radians).
/// mergeTolerance: distance threshold for merging nodes.
/// outVertices/outNormals: interleaved x,y,z float arrays; outIndices: triangle indices.
int OCCTPolyMergeNodes(OCCTShapeRef _Nonnull shapeRef,
                         double smoothAngle, double mergeTolerance,
                         float* _Nullable outVertices, float* _Nullable outNormals,
                         uint32_t* _Nullable outIndices,
                         int maxVertices, int maxIndices,
                         int* _Nullable outTriangleCount);

// MARK: - v0.79.0: Poly_CoherentTriangulation, BRepFill_Evolved/OffsetAncestors/NSections,
//                   BRepExtrema_DistanceSS, BRepGProp_VinertGK, GeomFill_Profiler/Stretch/
//                   LocationDraft/GuideTrihedronAC/GuideTrihedronPlan/SectionPlacement/AppSurf,
//                   ShapeFix_ComposeShell

// --- Poly_CoherentTriangulation ---
typedef void* OCCTCoherentTriangulationRef;

OCCTCoherentTriangulationRef OCCTCoherentTriangulationCreate(void);
OCCTCoherentTriangulationRef OCCTCoherentTriangulationCreateFromMesh(OCCTShapeRef _Nonnull shapeRef, double deflection);
int OCCTCoherentTriangulationSetNode(OCCTCoherentTriangulationRef _Nonnull ref, double x, double y, double z);
bool OCCTCoherentTriangulationAddTriangle(OCCTCoherentTriangulationRef _Nonnull ref, int n0, int n1, int n2);
bool OCCTCoherentTriangulationRemoveTriangle(OCCTCoherentTriangulationRef _Nonnull ref, int triIndex);
int OCCTCoherentTriangulationNTriangles(OCCTCoherentTriangulationRef _Nonnull ref);
int OCCTCoherentTriangulationComputeLinks(OCCTCoherentTriangulationRef _Nonnull ref);
int OCCTCoherentTriangulationNLinks(OCCTCoherentTriangulationRef _Nonnull ref);
void OCCTCoherentTriangulationSetDeflection(OCCTCoherentTriangulationRef _Nonnull ref, double deflection);
double OCCTCoherentTriangulationDeflection(OCCTCoherentTriangulationRef _Nonnull ref);
bool OCCTCoherentTriangulationRemoveDegenerated(OCCTCoherentTriangulationRef _Nonnull ref, double tolerance);
/// Converts back to standard Poly_Triangulation; returns vertex/triangle counts
bool OCCTCoherentTriangulationGetResult(OCCTCoherentTriangulationRef _Nonnull ref,
                                         int* _Nonnull outNbNodes, int* _Nonnull outNbTriangles);
/// Gets node coordinates (1-based index into result triangulation)
bool OCCTCoherentTriangulationNodeCoords(OCCTCoherentTriangulationRef _Nonnull ref, int nodeIndex,
                                          double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);
void OCCTCoherentTriangulationRelease(OCCTCoherentTriangulationRef _Nonnull ref);

// --- BRepFill_Evolved ---
/// Create evolved shape from face spine + wire profile
OCCTShapeRef _Nullable OCCTBRepFillEvolved(OCCTShapeRef _Nonnull spineFaceRef,
                                            OCCTShapeRef _Nonnull profileWireRef,
                                            double axOriginX, double axOriginY, double axOriginZ,
                                            double axNormalX, double axNormalY, double axNormalZ,
                                            double axXDirX, double axXDirY, double axXDirZ,
                                            int joinType, bool makeSolid);

// --- BRepFill_OffsetAncestors ---
typedef void* OCCTOffsetAncestorsRef;

OCCTOffsetAncestorsRef OCCTBRepFillOffsetAncestorsCreate(OCCTShapeRef _Nonnull faceRef, double offset, int joinType);
bool OCCTBRepFillOffsetAncestorsIsDone(OCCTOffsetAncestorsRef _Nonnull ref);
bool OCCTBRepFillOffsetAncestorsHasAncestor(OCCTOffsetAncestorsRef _Nonnull ref, OCCTShapeRef _Nonnull edgeRef);
OCCTShapeRef _Nullable OCCTBRepFillOffsetAncestorsGetAncestor(OCCTOffsetAncestorsRef _Nonnull ref, OCCTShapeRef _Nonnull edgeRef);
void OCCTBRepFillOffsetAncestorsRelease(OCCTOffsetAncestorsRef _Nonnull ref);

// --- BRepExtrema_DistanceSS ---
typedef struct {
    double distance;
    double point1X, point1Y, point1Z;
    double point2X, point2Y, point2Z;
    int solutionCount;
    bool isDone;
} OCCTDistanceSSResult;

OCCTDistanceSSResult OCCTBRepExtremaDistanceSS(OCCTShapeRef _Nonnull shape1Ref,
                                                OCCTShapeRef _Nonnull shape2Ref,
                                                double deflection);

// --- BRepGProp_VinertGK ---
typedef struct {
    double mass;
    double errorReached;
    double absoluteError;
    double centerX, centerY, centerZ;
} OCCTVinertGKResult;

OCCTVinertGKResult OCCTBRepGPropVinertGK(OCCTShapeRef _Nonnull faceRef,
                                           double locX, double locY, double locZ,
                                           double tolerance, bool computeCG);

// --- GeomFill_Profiler ---
typedef void* OCCTGeomFillProfilerRef;

OCCTGeomFillProfilerRef OCCTGeomFillProfilerCreate(void);
void OCCTGeomFillProfilerAddCurve(OCCTGeomFillProfilerRef _Nonnull ref, OCCTCurve3DRef _Nonnull curveRef);
bool OCCTGeomFillProfilerPerform(OCCTGeomFillProfilerRef _Nonnull ref, double tolerance);
int OCCTGeomFillProfilerDegree(OCCTGeomFillProfilerRef _Nonnull ref);
int OCCTGeomFillProfilerNbPoles(OCCTGeomFillProfilerRef _Nonnull ref);
int OCCTGeomFillProfilerNbKnots(OCCTGeomFillProfilerRef _Nonnull ref);
bool OCCTGeomFillProfilerIsPeriodic(OCCTGeomFillProfilerRef _Nonnull ref);
/// Gets poles for curve at index (1-based). outX/Y/Z must be sized to NbPoles.
bool OCCTGeomFillProfilerPoles(OCCTGeomFillProfilerRef _Nonnull ref, int curveIndex,
                                double* _Nonnull outX, double* _Nonnull outY, double* _Nonnull outZ, int maxPoles);
/// Gets knots and multiplicities. Arrays must be sized to NbKnots.
bool OCCTGeomFillProfilerKnotsAndMults(OCCTGeomFillProfilerRef _Nonnull ref,
                                        double* _Nonnull outKnots, int* _Nonnull outMults, int maxKnots);
void OCCTGeomFillProfilerRelease(OCCTGeomFillProfilerRef _Nonnull ref);

// --- GeomFill_Stretch ---
typedef struct {
    int nbUPoles;
    int nbVPoles;
    bool isRational;
} OCCTStretchFillResult;

/// Create stretch-filled surface from 4 boundary point arrays.
/// Each array is (x,y,z) triples; count is number of points per boundary.
OCCTStretchFillResult OCCTGeomFillStretch(const double* _Nonnull p1, const double* _Nonnull p2,
                                           const double* _Nonnull p3, const double* _Nonnull p4,
                                           int count,
                                           double* _Nullable outPoles, int maxPoles);

// --- GeomFill_LocationDraft ---
typedef void* OCCTLocationDraftRef;

OCCTLocationDraftRef OCCTGeomFillLocationDraftCreate(double dirX, double dirY, double dirZ, double angle);
bool OCCTGeomFillLocationDraftSetCurve(OCCTLocationDraftRef _Nonnull ref, OCCTCurve3DRef _Nonnull curveRef);
bool OCCTGeomFillLocationDraftD0(OCCTLocationDraftRef _Nonnull ref, double param,
                                  double* _Nonnull mat, double* _Nonnull vecX, double* _Nonnull vecY, double* _Nonnull vecZ);
void OCCTGeomFillLocationDraftSetAngle(OCCTLocationDraftRef _Nonnull ref, double angle);
void OCCTGeomFillLocationDraftDirection(OCCTLocationDraftRef _Nonnull ref,
                                         double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);
void OCCTGeomFillLocationDraftRelease(OCCTLocationDraftRef _Nonnull ref);

// --- GeomFill_GuideTrihedronAC ---
typedef void* OCCTGuideTrihedronACRef;

OCCTGuideTrihedronACRef OCCTGeomFillGuideTrihedronACCreate(OCCTCurve3DRef _Nonnull guideCurveRef);
bool OCCTGeomFillGuideTrihedronACSetCurve(OCCTGuideTrihedronACRef _Nonnull ref, OCCTCurve3DRef _Nonnull pathCurveRef);
bool OCCTGeomFillGuideTrihedronACD0(OCCTGuideTrihedronACRef _Nonnull ref, double param,
                                     double* _Nonnull tX, double* _Nonnull tY, double* _Nonnull tZ,
                                     double* _Nonnull nX, double* _Nonnull nY, double* _Nonnull nZ,
                                     double* _Nonnull bX, double* _Nonnull bY, double* _Nonnull bZ);
void OCCTGeomFillGuideTrihedronACRelease(OCCTGuideTrihedronACRef _Nonnull ref);

// --- GeomFill_GuideTrihedronPlan ---
typedef void* OCCTGuideTrihedronPlanRef;

OCCTGuideTrihedronPlanRef OCCTGeomFillGuideTrihedronPlanCreate(OCCTCurve3DRef _Nonnull guideCurveRef);
bool OCCTGeomFillGuideTrihedronPlanSetCurve(OCCTGuideTrihedronPlanRef _Nonnull ref, OCCTCurve3DRef _Nonnull pathCurveRef);
bool OCCTGeomFillGuideTrihedronPlanD0(OCCTGuideTrihedronPlanRef _Nonnull ref, double param,
                                       double* _Nonnull tX, double* _Nonnull tY, double* _Nonnull tZ,
                                       double* _Nonnull nX, double* _Nonnull nY, double* _Nonnull nZ,
                                       double* _Nonnull bX, double* _Nonnull bY, double* _Nonnull bZ);
void OCCTGeomFillGuideTrihedronPlanRelease(OCCTGuideTrihedronPlanRef _Nonnull ref);

// --- GeomFill_SectionPlacement ---
typedef struct {
    double parameterOnPath;
    double parameterOnSection;
    double distance;
    double angle;
    bool isDone;
} OCCTSectionPlacementResult;

/// Place a section curve on a path using LocationDraft law
OCCTSectionPlacementResult OCCTGeomFillSectionPlacement(OCCTCurve3DRef _Nonnull pathCurveRef,
                                                         OCCTCurve3DRef _Nonnull sectionCurveRef,
                                                         double dirX, double dirY, double dirZ,
                                                         double draftAngle, double tolerance);

// --- BRepFill_NSections ---
typedef void* OCCTNSectionsRef;

/// Create N-section law from array of wire shapes
OCCTNSectionsRef OCCTBRepFillNSectionsCreate(const OCCTShapeRef _Nonnull * _Nonnull wireRefs, int count);
int OCCTBRepFillNSectionsNbLaw(OCCTNSectionsRef _Nonnull ref);
bool OCCTBRepFillNSectionsIsConstant(OCCTNSectionsRef _Nonnull ref);
bool OCCTBRepFillNSectionsIsVertex(OCCTNSectionsRef _Nonnull ref);
void OCCTBRepFillNSectionsRelease(OCCTNSectionsRef _Nonnull ref);

// --- GeomFill_AppSurf ---
typedef struct {
    int uDegree;
    int vDegree;
    int nbUPoles;
    int nbVPoles;
    int nbUKnots;
    int nbVKnots;
    bool isDone;
} OCCTAppSurfResult;

/// Approximate surface from N section curves (uses GeomFill_SectionGenerator + GeomFill_AppSurf)
OCCTAppSurfResult OCCTGeomFillAppSurf(const OCCTCurve3DRef _Nonnull * _Nonnull curveRefs, int count,
                                       int degMin, int degMax, double tol3d, double tol2d);

// --- ShapeFix_ComposeShell ---
/// Perform compose shell on a face with composite surface grid
/// Returns the result shape (shell or compound of faces)
OCCTShapeRef _Nullable OCCTShapeFixComposeShell(OCCTShapeRef _Nonnull faceRef, double precision);

// MARK: - v0.80.0: Extrema 3D/2D, GeomTools persistence, ProjLib, gce_* factories

// --- Extrema_ExtCC: Curve-Curve distance ---
typedef struct {
    bool isDone;
    bool isParallel;
    int nbExt;
} OCCTExtremaExtCCResult;

/// Compute curve-to-curve extrema
OCCTExtremaExtCCResult OCCTExtremaExtCC(OCCTCurve3DRef _Nonnull curve1, double u1First, double u1Last,
                                         OCCTCurve3DRef _Nonnull curve2, double u2First, double u2Last);

typedef struct {
    double squareDistance;
    double x1, y1, z1;  // Point on curve 1
    double param1;
    double x2, y2, z2;  // Point on curve 2
    double param2;
} OCCTExtremaPointPair;

/// Get Nth extremum from curve-curve computation (1-based index)
OCCTExtremaPointPair OCCTExtremaExtCCPoint(OCCTCurve3DRef _Nonnull curve1, double u1First, double u1Last,
                                            OCCTCurve3DRef _Nonnull curve2, double u2First, double u2Last,
                                            int index);

// --- Extrema_ExtCS: Curve-Surface distance ---
typedef struct {
    bool isDone;
    bool isParallel;
    int nbExt;
} OCCTExtremaExtCSResult;

/// Compute curve-to-surface extrema
OCCTExtremaExtCSResult OCCTExtremaExtCS(OCCTCurve3DRef _Nonnull curve, double uFirst, double uLast,
                                         OCCTSurfaceRef _Nonnull surface);

/// Get Nth extremum from curve-surface computation
OCCTExtremaPointPair OCCTExtremaExtCSPoint(OCCTCurve3DRef _Nonnull curve, double uFirst, double uLast,
                                            OCCTSurfaceRef _Nonnull surface, int index);

// --- Extrema_ExtPS: Point-Surface distance ---
typedef struct {
    bool isDone;
    int nbExt;
} OCCTExtremaExtPSResult;

/// Compute point-to-surface extrema
OCCTExtremaExtPSResult OCCTExtremaExtPS(double px, double py, double pz,
                                         OCCTSurfaceRef _Nonnull surface);

typedef struct {
    double squareDistance;
    double x, y, z;
    double u, v;
} OCCTExtremaPointOnSurf;

/// Get Nth extremum from point-surface computation
OCCTExtremaPointOnSurf OCCTExtremaExtPSPoint(double px, double py, double pz,
                                              OCCTSurfaceRef _Nonnull surface, int index);

// --- Extrema_ExtSS: Surface-Surface distance ---
typedef struct {
    bool isDone;
    bool isParallel;
    int nbExt;
} OCCTExtremaExtSSResult;

/// Compute surface-to-surface extrema
OCCTExtremaExtSSResult OCCTExtremaExtSS(OCCTSurfaceRef _Nonnull surface1,
                                         OCCTSurfaceRef _Nonnull surface2);

/// Get Nth extremum from surface-surface computation
OCCTExtremaPointPair OCCTExtremaExtSSPoint(OCCTSurfaceRef _Nonnull surface1,
                                            OCCTSurfaceRef _Nonnull surface2, int index);

// --- Extrema_LocateExtCC: Local curve-curve distance ---
typedef struct {
    bool isDone;
    double squareDistance;
    double x1, y1, z1, param1;
    double x2, y2, z2, param2;
} OCCTExtremaLocateExtCCResult;

/// Find local curve-curve extremum near seed parameters
OCCTExtremaLocateExtCCResult OCCTExtremaLocateExtCC(OCCTCurve3DRef _Nonnull curve1, double u1First, double u1Last,
                                                     OCCTCurve3DRef _Nonnull curve2, double u2First, double u2Last,
                                                     double seedU, double seedV);

// --- Extrema_LocateExtCC2d: Local 2D curve-curve distance ---
typedef struct {
    bool isDone;
    double squareDistance;
    double x1, y1, param1;
    double x2, y2, param2;
} OCCTExtremaLocateExtCC2dResult;

/// Find local 2D curve-curve extremum near seed parameters
OCCTExtremaLocateExtCC2dResult OCCTExtremaLocateExtCC2d(OCCTCurve2DRef _Nonnull curve1, double u1First, double u1Last,
                                                         OCCTCurve2DRef _Nonnull curve2, double u2First, double u2Last,
                                                         double seedU, double seedV);

// --- GeomTools_CurveSet: 3D curve collection with persistence ---
/// Serialize a set of 3D curves to string
const char * _Nullable OCCTGeomToolsCurveSetWrite(const OCCTCurve3DRef _Nonnull * _Nonnull curveRefs, int count);

/// Deserialize 3D curves from string; returns array count via outCount
OCCTCurve3DRef _Nullable * _Nullable OCCTGeomToolsCurveSetRead(const char * _Nonnull data, int * _Nonnull outCount);

/// Free array of curve refs returned by CurveSetRead
void OCCTGeomToolsCurveSetFreeArray(OCCTCurve3DRef _Nullable * _Nullable array, int count);

// --- GeomTools_Curve2dSet: 2D curve collection with persistence ---
/// Serialize a set of 2D curves to string
const char * _Nullable OCCTGeomToolsCurve2dSetWrite(const OCCTCurve2DRef _Nonnull * _Nonnull curveRefs, int count);

/// Deserialize 2D curves from string
OCCTCurve2DRef _Nullable * _Nullable OCCTGeomToolsCurve2dSetRead(const char * _Nonnull data, int * _Nonnull outCount);

/// Free array of curve2d refs
void OCCTGeomToolsCurve2dSetFreeArray(OCCTCurve2DRef _Nullable * _Nullable array, int count);

// --- GeomTools_SurfaceSet: Surface collection with persistence ---
/// Serialize a set of surfaces to string
const char * _Nullable OCCTGeomToolsSurfaceSetWrite(const OCCTSurfaceRef _Nonnull * _Nonnull surfRefs, int count);

/// Deserialize surfaces from string
OCCTSurfaceRef _Nullable * _Nullable OCCTGeomToolsSurfaceSetRead(const char * _Nonnull data, int * _Nonnull outCount);

/// Free array of surface refs
void OCCTGeomToolsSurfaceSetFreeArray(OCCTSurfaceRef _Nullable * _Nullable array, int count);

/// Free string returned by GeomTools*Write functions
void OCCTGeomToolsFreeString(const char * _Nullable str);

// --- ProjLib_ProjectOnSurface ---
/// Project a 3D curve onto a surface, returning BSpline approximation
OCCTCurve3DRef _Nullable OCCTProjLibProjectOnSurface(OCCTCurve3DRef _Nonnull curve, double uFirst, double uLast,
                                                      OCCTSurfaceRef _Nonnull surface, double tolerance);

// --- gce_MakeCirc: Circle from 3 points ---
/// Create a 3D circle through 3 points (returns Geom_Circle)
OCCTCurve3DRef _Nullable OCCTGceMakeCircFrom3Points(double p1x, double p1y, double p1z,
                                                     double p2x, double p2y, double p2z,
                                                     double p3x, double p3y, double p3z);

/// Create a 3D circle from center + normal + radius
OCCTCurve3DRef _Nullable OCCTGceMakeCircFromCenterNormal(double cx, double cy, double cz,
                                                          double nx, double ny, double nz,
                                                          double radius);

// --- gce_MakeCone ---
/// Create a conical surface from 2 points (axis) + 2 radii
OCCTSurfaceRef _Nullable OCCTGceMakeCone(double p1x, double p1y, double p1z,
                                          double p2x, double p2y, double p2z,
                                          double radius1, double radius2);

// --- gce_MakeCylinder ---
/// Create a cylindrical surface from 3 points (P1-P2 axis, P3 radius)
OCCTSurfaceRef _Nullable OCCTGceMakeCylinderFrom3Points(double p1x, double p1y, double p1z,
                                                         double p2x, double p2y, double p2z,
                                                         double p3x, double p3y, double p3z);

// --- gce_MakeLin ---
/// Create a line from 2 points
OCCTCurve3DRef _Nullable OCCTGceMakeLinFrom2Points(double p1x, double p1y, double p1z,
                                                    double p2x, double p2y, double p2z);

// --- gce_MakePln ---
/// Create a plane from equation Ax+By+Cz+D=0
OCCTSurfaceRef _Nullable OCCTGceMakePlnFromEquation(double a, double b, double c, double d);

/// Create a plane from 3 points
OCCTSurfaceRef _Nullable OCCTGceMakePlnFrom3Points(double p1x, double p1y, double p1z,
                                                    double p2x, double p2y, double p2z,
                                                    double p3x, double p3y, double p3z);

// --- gce_MakeDir ---
/// Create a direction from 2 points (P1→P2)
bool OCCTGceMakeDir(double p1x, double p1y, double p1z,
                     double p2x, double p2y, double p2z,
                     double * _Nonnull outX, double * _Nonnull outY, double * _Nonnull outZ);

// --- gce_MakeElips ---
/// Create an ellipse from center, normal, major axis direction, and radii
OCCTCurve3DRef _Nullable OCCTGceMakeElips(double cx, double cy, double cz,
                                           double nx, double ny, double nz,
                                           double majorRadius, double minorRadius);

// --- gce_MakeHypr ---
/// Create a hyperbola from center, normal, and radii
OCCTCurve3DRef _Nullable OCCTGceMakeHypr(double cx, double cy, double cz,
                                          double nx, double ny, double nz,
                                          double majorRadius, double minorRadius);

// --- gce_MakeParab ---
/// Create a parabola from center, normal, and focal length
OCCTCurve3DRef _Nullable OCCTGceMakeParab(double cx, double cy, double cz,
                                           double nx, double ny, double nz,
                                           double focal);

// --- gce_MakeCirc2d ---
/// Create a 2D circle from center + radius
OCCTCurve2DRef _Nullable OCCTGceMakeCirc2dFromCenterRadius(double cx, double cy, double radius);

/// Create a 2D circle from 3 points
OCCTCurve2DRef _Nullable OCCTGceMakeCirc2dFrom3Points(double p1x, double p1y,
                                                       double p2x, double p2y,
                                                       double p3x, double p3y);

// --- gce_MakeLin2d ---
/// Create a 2D line from 2 points
OCCTCurve2DRef _Nullable OCCTGceMakeLin2dFrom2Points(double p1x, double p1y,
                                                      double p2x, double p2y);

/// Create a 2D line from equation Ax+By+C=0
OCCTCurve2DRef _Nullable OCCTGceMakeLin2dFromEquation(double a, double b, double c);

// --- gce_MakeElips2d ---
/// Create a 2D ellipse from center, major axis direction, and radii
OCCTCurve2DRef _Nullable OCCTGceMakeElips2d(double cx, double cy,
                                             double dirX, double dirY,
                                             double majorRadius, double minorRadius);

// --- gce_MakeHypr2d ---
/// Create a 2D hyperbola from center, major axis direction, and radii
OCCTCurve2DRef _Nullable OCCTGceMakeHypr2d(double cx, double cy,
                                             double dirX, double dirY,
                                             double majorRadius, double minorRadius);

// --- gce_MakeParab2d ---
/// Create a 2D parabola from center, axis direction, and focal length
OCCTCurve2DRef _Nullable OCCTGceMakeParab2d(double cx, double cy,
                                              double dirX, double dirY,
                                              double focal);

// MARK: - v0.81.0: Visualization — Quantity_Color, Quantity_ColorRGBA, Graphic3d_MaterialAspect, Graphic3d_PBRMaterial

// --- Quantity_Color ---

/// HLS color components
typedef struct {
    double hue;
    double lightness;
    double saturation;
} OCCTColorHLS;

/// CIE Lab color components
typedef struct {
    double l;
    double a;
    double b;
} OCCTColorLab;

/// Create color from named color string (e.g., "RED", "BLUE")
/// Returns false if name not recognized
bool OCCTColorFromName(const char *_Nonnull name,
                       double *_Nonnull outR, double *_Nonnull outG, double *_Nonnull outB);

/// Create color from hex string (e.g., "#FF0000")
/// Returns false if parse fails
bool OCCTColorFromHex(const char *_Nonnull hex,
                      double *_Nonnull outR, double *_Nonnull outG, double *_Nonnull outB);

/// Convert linear RGB color to hex string. Caller must free returned string with OCCTGeomToolsFreeString.
const char *_Nullable OCCTColorToHex(double r, double g, double b, bool useSRGB);

/// Euclidean distance between two colors in linear RGB space
double OCCTColorDistance(double r1, double g1, double b1,
                         double r2, double g2, double b2);

/// Square distance between two colors in linear RGB space
double OCCTColorSquareDistance(double r1, double g1, double b1,
                                double r2, double g2, double b2);

/// CIE DeltaE2000 perceptual color difference
double OCCTColorDeltaE2000(double r1, double g1, double b1,
                            double r2, double g2, double b2);

/// Convert linear RGB to HLS
OCCTColorHLS OCCTColorToHLS(double r, double g, double b);

/// Create linear RGB color from HLS values
void OCCTColorFromHLS(double h, double l, double s,
                      double *_Nonnull outR, double *_Nonnull outG, double *_Nonnull outB);

/// Modify color intensity (lightness delta)
void OCCTColorChangeIntensity(double *_Nonnull r, double *_Nonnull g, double *_Nonnull b, double delta);

/// Modify color contrast (saturation percentage delta)
void OCCTColorChangeContrast(double *_Nonnull r, double *_Nonnull g, double *_Nonnull b, double delta);

/// Convert linear RGB to sRGB
void OCCTColorLinearToSRGB(float inR, float inG, float inB,
                            float *_Nonnull outR, float *_Nonnull outG, float *_Nonnull outB);

/// Convert sRGB to linear RGB
void OCCTColorSRGBToLinear(float inR, float inG, float inB,
                            float *_Nonnull outR, float *_Nonnull outG, float *_Nonnull outB);

/// Convert linear RGB to CIE Lab
OCCTColorLab OCCTColorToLab(double r, double g, double b);

/// Get string name for a named color index (0-based)
const char *_Nullable OCCTColorStringName(int index);

/// Color comparison epsilon
double OCCTColorEpsilon(void);

// --- Quantity_ColorRGBA ---

/// Create RGBA color from hex string with alpha (e.g., "#FF000080")
bool OCCTColorRGBAFromHex(const char *_Nonnull hex,
                           double *_Nonnull outR, double *_Nonnull outG, double *_Nonnull outB,
                           double *_Nonnull outA);

/// Convert RGBA color to hex string (with alpha). Caller must free with OCCTGeomToolsFreeString.
const char *_Nullable OCCTColorRGBAToHex(double r, double g, double b, double a, bool useSRGB);

// --- Graphic3d_MaterialAspect ---

/// Material properties struct
typedef struct {
    double ambientR, ambientG, ambientB;
    double diffuseR, diffuseG, diffuseB;
    double specularR, specularG, specularB;
    double emissiveR, emissiveG, emissiveB;
    float transparency;
    float shininess;
    float refractionIndex;
    bool isPhysic;  // true = PHYSIC, false = ASPECT
    // PBR properties
    float pbrMetallic;
    float pbrRoughness;
    float pbrIOR;
    float pbrAlpha;
    float pbrEmissionR, pbrEmissionG, pbrEmissionB;
} OCCTMaterialProperties;

/// Number of predefined materials
int OCCTMaterialNumberOfMaterials(void);

/// Get name of predefined material by 1-based index. Caller must free with OCCTGeomToolsFreeString.
const char *_Nullable OCCTMaterialName(int index);

/// Get properties of a predefined material by name
bool OCCTMaterialFromName(const char *_Nonnull name, OCCTMaterialProperties *_Nonnull outProps);

/// Get properties of a predefined material by 1-based index
bool OCCTMaterialFromIndex(int index, OCCTMaterialProperties *_Nonnull outProps);

// --- Graphic3d_PBRMaterial ---

/// Minimum roughness value
float OCCTMaterialMinRoughness(void);

/// Compute roughness from specular color and shininess
float OCCTMaterialRoughnessFromSpecular(double specR, double specG, double specB, double shininess);

/// Compute metallic factor from specular color
float OCCTMaterialMetallicFromSpecular(double specR, double specG, double specB);

// MARK: - v0.82.0: Quantity_Period, Quantity_Date, Font_FontMgr, Image_AlienPixMap

// --- Quantity_Period ---

/// Period components
typedef struct {
    int days;
    int hours;
    int minutes;
    int seconds;
    int milliseconds;
    int microseconds;
} OCCTPeriodComponents;

/// Create a period from days/hours/minutes/seconds/ms/us
/// Returns false if values are invalid
bool OCCTPeriodCreate(int dd, int hh, int mn, int ss, int mis, int mics,
                      int *_Nonnull outSec, int *_Nonnull outUSec);

/// Create a period from total seconds and microseconds
/// Returns false if values are invalid
bool OCCTPeriodCreateFromSeconds(int ss, int mics,
                                  int *_Nonnull outSec, int *_Nonnull outUSec);

/// Decompose period into components
OCCTPeriodComponents OCCTPeriodValues(int sec, int usec);

/// Get total seconds and microseconds from period
void OCCTPeriodTotalSeconds(int sec, int usec, int *_Nonnull outSec, int *_Nonnull outUSec);

/// Add two periods
void OCCTPeriodAdd(int sec1, int usec1, int sec2, int usec2,
                    int *_Nonnull outSec, int *_Nonnull outUSec);

/// Subtract period2 from period1
void OCCTPeriodSubtract(int sec1, int usec1, int sec2, int usec2,
                         int *_Nonnull outSec, int *_Nonnull outUSec);

/// Compare two periods: returns -1 (shorter), 0 (equal), 1 (longer)
int OCCTPeriodCompare(int sec1, int usec1, int sec2, int usec2);

/// Check if period values are valid
bool OCCTPeriodIsValid(int dd, int hh, int mn, int ss, int mis, int mics);

/// Check if period seconds are valid
bool OCCTPeriodIsValidSeconds(int ss, int mics);

// --- Quantity_Date ---

/// Date components
typedef struct {
    int month;
    int day;
    int year;
    int hour;
    int minute;
    int second;
    int millisecond;
    int microsecond;
} OCCTDateComponents;

/// Create a date and return its internal representation
/// Returns false if date is invalid
bool OCCTDateCreate(int mm, int dd, int yyyy, int hh, int mn, int ss, int mis, int mics,
                     int *_Nonnull outSec, int *_Nonnull outUSec);

/// Get default date (Jan 1, 1979)
void OCCTDateDefault(int *_Nonnull outSec, int *_Nonnull outUSec);

/// Decompose date into components
OCCTDateComponents OCCTDateValues(int sec, int usec);

/// Add period to date
void OCCTDateAddPeriod(int dateSec, int dateUSec, int periodSec, int periodUSec,
                        int *_Nonnull outSec, int *_Nonnull outUSec);

/// Subtract period from date
bool OCCTDateSubtractPeriod(int dateSec, int dateUSec, int periodSec, int periodUSec,
                             int *_Nonnull outSec, int *_Nonnull outUSec);

/// Difference between two dates (returns period)
void OCCTDateDifference(int sec1, int usec1, int sec2, int usec2,
                         int *_Nonnull outPeriodSec, int *_Nonnull outPeriodUSec);

/// Compare two dates: returns -1 (earlier), 0 (equal), 1 (later)
int OCCTDateCompare(int sec1, int usec1, int sec2, int usec2);

/// Check if date is valid
bool OCCTDateIsValid(int mm, int dd, int yyyy, int hh, int mn, int ss, int mis, int mics);

/// Check if year is a leap year
bool OCCTDateIsLeap(int year);

// --- Font_FontMgr ---

/// Initialize the system font database
void OCCTFontMgrInitDatabase(void);

/// Get number of available fonts
int OCCTFontMgrFontCount(void);

/// Get font name by 0-based index. Caller must free with OCCTGeomToolsFreeString.
const char *_Nullable OCCTFontMgrFontName(int index);

/// Get font path for a given font index and aspect (0=Regular, 1=Bold, 2=Italic, 3=BoldItalic)
/// Caller must free with OCCTGeomToolsFreeString.
const char *_Nullable OCCTFontMgrFontPath(int index, int aspect);

/// Check if font has a given aspect (0=Regular, 1=Bold, 2=Italic, 3=BoldItalic)
bool OCCTFontMgrFontHasAspect(int index, int aspect);

/// Get font aspect as string ("regular", "bold", "italic", "bold-italic")
const char *_Nonnull OCCTFontMgrAspectToString(int aspect);

// --- Image_AlienPixMap ---

/// Opaque handle to Image_AlienPixMap
typedef void *_Nullable OCCTImageRef;

/// Create an empty image
OCCTImageRef OCCTImageCreate(void);

/// Release image
void OCCTImageRelease(OCCTImageRef ref);

/// Initialize image with given format and dimensions
/// format: 0=Gray, 1=Alpha, 2=RGB, 3=BGR, 4=RGB32, 5=BGR32, 6=RGBA, 7=BGRA
bool OCCTImageInitTrash(OCCTImageRef ref, int format, int width, int height);

/// Copy image from another
bool OCCTImageInitCopy(OCCTImageRef dst, OCCTImageRef src);

/// Clear image data
void OCCTImageClear(OCCTImageRef ref);

/// Get image width
int OCCTImageWidth(OCCTImageRef ref);

/// Get image height
int OCCTImageHeight(OCCTImageRef ref);

/// Get image format
int OCCTImageFormat(OCCTImageRef ref);

/// Check if image is empty
bool OCCTImageIsEmpty(OCCTImageRef ref);

/// Get pixel color (RGBA) at coordinates
void OCCTImageGetPixel(OCCTImageRef ref, int x, int y,
                        float *_Nonnull r, float *_Nonnull g, float *_Nonnull b, float *_Nonnull a);

/// Set pixel color (RGBA) at coordinates
void OCCTImageSetPixel(OCCTImageRef ref, int x, int y, float r, float g, float b, float a);

/// Save image to file (format determined by extension)
bool OCCTImageSave(OCCTImageRef ref, const char *_Nonnull filePath);

/// Load image from file
bool OCCTImageLoad(OCCTImageRef ref, const char *_Nonnull filePath);

/// Apply gamma correction
bool OCCTImageAdjustGamma(OCCTImageRef ref, double gamma);

/// Get size of a single pixel in bytes for a given format
int OCCTImageSizePixelBytes(int format);

/// Check if top-down is default row order
bool OCCTImageIsTopDownDefault(void);

// MARK: - v0.83.0: XDE Attributes — Location, GraphNode, Color, Material, Notes, Views, Styles

// --- XCAFDoc_Location ---

/// Set a TopLoc_Location (translation) on a label
bool OCCTDocumentSetLocation(OCCTDocumentRef doc, int64_t labelId,
                              double tx, double ty, double tz);

/// Get the TopLoc_Location translation from a label
bool OCCTDocumentGetLocationTranslation(OCCTDocumentRef doc, int64_t labelId,
                                         double *_Nonnull outX, double *_Nonnull outY, double *_Nonnull outZ);

/// Check if a label has an XCAFDoc_Location attribute
bool OCCTDocumentHasLocation(OCCTDocumentRef doc, int64_t labelId);

// --- XCAFDoc_GraphNode ---

/// Set an XCAFDoc_GraphNode attribute on a label (creates or retrieves it)
bool OCCTDocumentSetGraphNodeAttr(OCCTDocumentRef doc, int64_t labelId);

/// Set a child relationship: parent's graph node gets child's graph node
bool OCCTDocumentGraphNodeSetChild(OCCTDocumentRef doc, int64_t parentLabelId, int64_t childLabelId);

/// Set a father relationship: child's graph node gets parent's graph node
bool OCCTDocumentGraphNodeSetFather(OCCTDocumentRef doc, int64_t childLabelId, int64_t parentLabelId);

/// Unset a child relationship
bool OCCTDocumentGraphNodeUnSetChild(OCCTDocumentRef doc, int64_t parentLabelId, int64_t childLabelId);

/// Unset a father relationship
bool OCCTDocumentGraphNodeUnSetFather(OCCTDocumentRef doc, int64_t childLabelId, int64_t parentLabelId);

/// Get number of children of a graph node
int32_t OCCTDocumentGraphNodeNbChildren(OCCTDocumentRef doc, int64_t labelId);

/// Get number of fathers of a graph node
int32_t OCCTDocumentGraphNodeNbFathers(OCCTDocumentRef doc, int64_t labelId);

/// Check if node is father of another
bool OCCTDocumentGraphNodeIsFather(OCCTDocumentRef doc, int64_t labelId, int64_t otherLabelId);

/// Check if node is child of another
bool OCCTDocumentGraphNodeIsChild(OCCTDocumentRef doc, int64_t labelId, int64_t otherLabelId);

// --- XCAFDoc_Color ---

/// Set color attribute from RGB on a label
bool OCCTDocumentSetColorAttr(OCCTDocumentRef doc, int64_t labelId,
                               double r, double g, double b);

/// Set color attribute from RGBA on a label
bool OCCTDocumentSetColorRGBAAttr(OCCTDocumentRef doc, int64_t labelId,
                                    double r, double g, double b, float alpha);

/// Set color attribute from named color on a label
bool OCCTDocumentSetColorNOCAttr(OCCTDocumentRef doc, int64_t labelId, int32_t noc);

/// Get color from XCAFDoc_Color attribute on a label
bool OCCTDocumentGetColorAttr(OCCTDocumentRef doc, int64_t labelId,
                               double *_Nonnull outR, double *_Nonnull outG, double *_Nonnull outB);

/// Get RGBA from XCAFDoc_Color attribute on a label
bool OCCTDocumentGetColorRGBAAttr(OCCTDocumentRef doc, int64_t labelId,
                                    double *_Nonnull outR, double *_Nonnull outG, double *_Nonnull outB,
                                    float *_Nonnull outAlpha);

/// Get alpha from XCAFDoc_Color attribute
float OCCTDocumentGetColorAlphaAttr(OCCTDocumentRef doc, int64_t labelId);

/// Get named color from XCAFDoc_Color attribute
int32_t OCCTDocumentGetColorNOCAttr(OCCTDocumentRef doc, int64_t labelId);

// --- XCAFDoc_Material ---

/// Set material attribute on a label
bool OCCTDocumentSetMaterialAttr(OCCTDocumentRef doc, int64_t labelId,
                                  const char *_Nonnull name,
                                  const char *_Nonnull description,
                                  double density,
                                  const char *_Nonnull densName,
                                  const char *_Nonnull densValType);

/// Get material name from attribute. Caller must free with OCCTStringFree.
const char *_Nullable OCCTDocumentGetMaterialAttrName(OCCTDocumentRef doc, int64_t labelId);

/// Get material description. Caller must free with OCCTStringFree.
const char *_Nullable OCCTDocumentGetMaterialAttrDescription(OCCTDocumentRef doc, int64_t labelId);

/// Get material density from attribute
bool OCCTDocumentGetMaterialAttrDensity(OCCTDocumentRef doc, int64_t labelId,
                                          double *_Nonnull outDensity);

/// Check if label has XCAFDoc_Material attribute
bool OCCTDocumentHasMaterialAttr(OCCTDocumentRef doc, int64_t labelId);

// --- XCAFDoc_NoteComment ---

/// Set a NoteComment attribute on a label
bool OCCTDocumentSetNoteComment(OCCTDocumentRef doc, int64_t labelId,
                                 const char *_Nonnull userName,
                                 const char *_Nonnull timeStamp,
                                 const char *_Nonnull comment);

/// Get comment text from NoteComment. Caller must free with OCCTStringFree.
const char *_Nullable OCCTDocumentGetNoteCommentText(OCCTDocumentRef doc, int64_t labelId);

/// Get note user name. Caller must free with OCCTStringFree.
const char *_Nullable OCCTDocumentGetNoteUserName(OCCTDocumentRef doc, int64_t labelId);

// --- XCAFDoc_NoteBalloon ---

/// Set a NoteBalloon attribute on a label
bool OCCTDocumentSetNoteBalloon(OCCTDocumentRef doc, int64_t labelId,
                                 const char *_Nonnull userName,
                                 const char *_Nonnull timeStamp,
                                 const char *_Nonnull comment);

// --- XCAFDoc_NoteBinData ---

/// Set a NoteBinData attribute on a label (binary data from byte array)
bool OCCTDocumentSetNoteBinData(OCCTDocumentRef doc, int64_t labelId,
                                 const char *_Nonnull userName,
                                 const char *_Nonnull timeStamp,
                                 const char *_Nonnull title,
                                 const char *_Nonnull mimeType,
                                 const uint8_t *_Nonnull data,
                                 int32_t dataSize);

/// Get binary data size from NoteBinData
int32_t OCCTDocumentGetNoteBinDataSize(OCCTDocumentRef doc, int64_t labelId);

// --- XCAFDoc_NotesTool ---

/// Get or create NotesTool on document, returns number of notes (≥0) or -1 on error
int32_t OCCTDocumentNotesToolNbNotes(OCCTDocumentRef doc);

/// Create a comment note via NotesTool. Returns label ID of created note.
int64_t OCCTDocumentNotesToolCreateComment(OCCTDocumentRef doc,
                                             const char *_Nonnull userName,
                                             const char *_Nonnull timeStamp,
                                             const char *_Nonnull comment);

/// Create a balloon note via NotesTool. Returns label ID of created note.
int64_t OCCTDocumentNotesToolCreateBalloon(OCCTDocumentRef doc,
                                             const char *_Nonnull userName,
                                             const char *_Nonnull timeStamp,
                                             const char *_Nonnull comment);

/// Create a binary data note via NotesTool. Returns label ID of created note.
int64_t OCCTDocumentNotesToolCreateBinData(OCCTDocumentRef doc,
                                             const char *_Nonnull userName,
                                             const char *_Nonnull timeStamp,
                                             const char *_Nonnull title,
                                             const char *_Nonnull mimeType,
                                             const uint8_t *_Nonnull data,
                                             int32_t dataSize);

/// Delete a note by label ID. Returns true on success.
bool OCCTDocumentNotesToolDeleteNote(OCCTDocumentRef doc, int64_t noteLabelId);

/// Delete all notes. Returns the number of deleted notes.
int32_t OCCTDocumentNotesToolDeleteAllNotes(OCCTDocumentRef doc);

/// Get number of orphan notes.
int32_t OCCTDocumentNotesToolNbOrphanNotes(OCCTDocumentRef doc);

/// Delete all orphan notes. Returns number of deleted notes.
int32_t OCCTDocumentNotesToolDeleteOrphanNotes(OCCTDocumentRef doc);

// --- XCAFDoc_ClippingPlaneTool ---

/// Add a clipping plane. Returns label ID of created plane or -1 on error.
int64_t OCCTDocumentClipPlaneToolAdd(OCCTDocumentRef doc,
                                       double planeOrigX, double planeOrigY, double planeOrigZ,
                                       double planeNormX, double planeNormY, double planeNormZ,
                                       const char *_Nonnull name, bool capping);

/// Get clipping plane from label.
bool OCCTDocumentClipPlaneToolGet(OCCTDocumentRef doc, int64_t labelId,
                                    double *_Nonnull origX, double *_Nonnull origY, double *_Nonnull origZ,
                                    double *_Nonnull normX, double *_Nonnull normY, double *_Nonnull normZ,
                                    bool *_Nonnull capping);

/// Check if label is a clipping plane
bool OCCTDocumentClipPlaneToolIsClipPlane(OCCTDocumentRef doc, int64_t labelId);

/// Remove a clipping plane
bool OCCTDocumentClipPlaneToolRemove(OCCTDocumentRef doc, int64_t labelId);

// --- XCAFDoc_ShapeMapTool ---

/// Set ShapeMapTool attribute on a label
bool OCCTDocumentSetShapeMapTool(OCCTDocumentRef doc, int64_t labelId);

/// Set shape on ShapeMapTool
bool OCCTDocumentShapeMapToolSetShape(OCCTDocumentRef doc, int64_t labelId, OCCTShapeRef shape);

/// Check if shape is a sub-shape in the ShapeMapTool
bool OCCTDocumentShapeMapToolIsSubShape(OCCTDocumentRef doc, int64_t labelId, OCCTShapeRef shape);

/// Get the extent (number of entries) of the ShapeMapTool's map
int32_t OCCTDocumentShapeMapToolExtent(OCCTDocumentRef doc, int64_t labelId);

// --- XCAFDoc_AssemblyGraph ---

/// Opaque handle to assembly graph
typedef void *_Nullable OCCTAssemblyGraphRef;

/// Create an assembly graph from a document
OCCTAssemblyGraphRef OCCTAssemblyGraphCreate(OCCTDocumentRef doc);

/// Release assembly graph
void OCCTAssemblyGraphRelease(OCCTAssemblyGraphRef ref);

/// Number of nodes in the assembly graph
int32_t OCCTAssemblyGraphNbNodes(OCCTAssemblyGraphRef ref);

/// Number of links in the assembly graph
int32_t OCCTAssemblyGraphNbLinks(OCCTAssemblyGraphRef ref);

/// Number of root nodes in the assembly graph
int32_t OCCTAssemblyGraphNbRoots(OCCTAssemblyGraphRef ref);

/// Get node type (0=node, 1=occurrence, 2=part, 3=instance, 4=subshape, 5=free)
int32_t OCCTAssemblyGraphGetNodeType(OCCTAssemblyGraphRef ref, int32_t nodeIndex);

// --- XCAFDoc_AssemblyItemId ---

/// Create an AssemblyItemId from string, check if valid. Returns true if valid.
bool OCCTAssemblyItemIdIsValid(const char *_Nonnull str);

/// Get path count from an AssemblyItemId string
int32_t OCCTAssemblyItemIdPathCount(const char *_Nonnull str);

/// Check equality of two AssemblyItemId strings
bool OCCTAssemblyItemIdIsEqual(const char *_Nonnull str1, const char *_Nonnull str2);

// --- XCAFView_Object ---

/// Opaque handle to XCAFView_Object
typedef void *_Nullable OCCTViewObjectRef;

/// Create a new XCAFView_Object
OCCTViewObjectRef OCCTViewObjectCreate(void);

/// Release view object
void OCCTViewObjectRelease(OCCTViewObjectRef ref);

/// Set projection type (0=central, 1=parallel)
void OCCTViewObjectSetType(OCCTViewObjectRef ref, int32_t type);

/// Get projection type (0=central, 1=parallel)
int32_t OCCTViewObjectGetType(OCCTViewObjectRef ref);

/// Set view direction
void OCCTViewObjectSetViewDirection(OCCTViewObjectRef ref, double x, double y, double z);

/// Get view direction
void OCCTViewObjectGetViewDirection(OCCTViewObjectRef ref,
                                      double *_Nonnull x, double *_Nonnull y, double *_Nonnull z);

/// Set up direction
void OCCTViewObjectSetUpDirection(OCCTViewObjectRef ref, double x, double y, double z);

/// Get up direction
void OCCTViewObjectGetUpDirection(OCCTViewObjectRef ref,
                                    double *_Nonnull x, double *_Nonnull y, double *_Nonnull z);

/// Set window horizontal size
void OCCTViewObjectSetWindowHSize(OCCTViewObjectRef ref, double size);

/// Get window horizontal size
double OCCTViewObjectGetWindowHSize(OCCTViewObjectRef ref);

/// Set window vertical size
void OCCTViewObjectSetWindowVSize(OCCTViewObjectRef ref, double size);

/// Get window vertical size
double OCCTViewObjectGetWindowVSize(OCCTViewObjectRef ref);

/// Set front plane distance (enables front clipping)
void OCCTViewObjectSetFrontPlaneDistance(OCCTViewObjectRef ref, double dist);

/// Get front plane distance
double OCCTViewObjectGetFrontPlaneDistance(OCCTViewObjectRef ref);

/// Has front plane clipping
bool OCCTViewObjectHasFrontPlaneClipping(OCCTViewObjectRef ref);

/// Unset front plane clipping
void OCCTViewObjectUnsetFrontPlaneClipping(OCCTViewObjectRef ref);

/// Set back plane distance (enables back clipping)
void OCCTViewObjectSetBackPlaneDistance(OCCTViewObjectRef ref, double dist);

/// Get back plane distance
double OCCTViewObjectGetBackPlaneDistance(OCCTViewObjectRef ref);

/// Has back plane clipping
bool OCCTViewObjectHasBackPlaneClipping(OCCTViewObjectRef ref);

/// Unset back plane clipping
void OCCTViewObjectUnsetBackPlaneClipping(OCCTViewObjectRef ref);

/// Set name. Pass empty string for no name.
void OCCTViewObjectSetName(OCCTViewObjectRef ref, const char *_Nonnull name);

/// Get name. Caller must free with OCCTStringFree.
const char *_Nullable OCCTViewObjectGetName(OCCTViewObjectRef ref);

// --- XCAFNoteObjects_NoteObject ---

/// Opaque handle to XCAFNoteObjects_NoteObject
typedef void *_Nullable OCCTNoteObjectRef;

/// Create a new NoteObject
OCCTNoteObjectRef OCCTNoteObjectCreate(void);

/// Release note object
void OCCTNoteObjectRelease(OCCTNoteObjectRef ref);

/// Has plane
bool OCCTNoteObjectHasPlane(OCCTNoteObjectRef ref);

/// Has point
bool OCCTNoteObjectHasPoint(OCCTNoteObjectRef ref);

/// Has point text
bool OCCTNoteObjectHasPointText(OCCTNoteObjectRef ref);

/// Set plane (origin + normal)
void OCCTNoteObjectSetPlane(OCCTNoteObjectRef ref,
                              double origX, double origY, double origZ,
                              double normX, double normY, double normZ);

/// Get plane origin
void OCCTNoteObjectGetPlane(OCCTNoteObjectRef ref,
                              double *_Nonnull origX, double *_Nonnull origY, double *_Nonnull origZ);

/// Set point
void OCCTNoteObjectSetPoint(OCCTNoteObjectRef ref, double x, double y, double z);

/// Get point
void OCCTNoteObjectGetPoint(OCCTNoteObjectRef ref,
                              double *_Nonnull x, double *_Nonnull y, double *_Nonnull z);

/// Set presentation shape
void OCCTNoteObjectSetPresentation(OCCTNoteObjectRef ref, OCCTShapeRef shape);

/// Get presentation shape (returns null if not set)
OCCTShapeRef OCCTNoteObjectGetPresentation(OCCTNoteObjectRef ref);

/// Reset all data
void OCCTNoteObjectReset(OCCTNoteObjectRef ref);

// --- XCAFPrs_Style ---

/// XCAFPrs_Style data as a struct
typedef struct {
    double surfR, surfG, surfB;
    float surfAlpha;
    bool hasSurfColor;
    double curvR, curvG, curvB;
    bool hasCurvColor;
    bool isVisible;
    bool isEmpty;
} OCCTXCAFPrsStyle;

/// Create a default (empty) style
OCCTXCAFPrsStyle OCCTXCAFPrsStyleCreate(void);

/// Create a style with surface color
OCCTXCAFPrsStyle OCCTXCAFPrsStyleCreateWithSurfColor(double r, double g, double b, float alpha);

/// Create a style with surface and curve colors
OCCTXCAFPrsStyle OCCTXCAFPrsStyleCreateFull(double surfR, double surfG, double surfB, float surfAlpha,
                                              double curvR, double curvG, double curvB,
                                              bool visible);

/// Check if two styles are equal
bool OCCTXCAFPrsStyleIsEqual(const OCCTXCAFPrsStyle *_Nonnull s1, const OCCTXCAFPrsStyle *_Nonnull s2);

// --- XCAFDoc_VisMaterialCommon ---

/// Phong material data struct
typedef struct {
    double diffuseR, diffuseG, diffuseB;
    double ambientR, ambientG, ambientB;
    double specularR, specularG, specularB;
    double emissiveR, emissiveG, emissiveB;
    float shininess;
    float transparency;
    bool isDefined;
} OCCTVisMaterialCommon;

/// Get default VisMaterialCommon values
OCCTVisMaterialCommon OCCTVisMaterialCommonDefault(void);

/// Check equality of two VisMaterialCommon
bool OCCTVisMaterialCommonIsEqual(const OCCTVisMaterialCommon *_Nonnull a,
                                    const OCCTVisMaterialCommon *_Nonnull b);

// --- XCAFDoc_VisMaterialPBR ---

/// PBR material data struct
typedef struct {
    double baseColorR, baseColorG, baseColorB;
    float baseColorAlpha;
    float metallic;
    float roughness;
    float refractionIndex;
    double emissionR, emissionG, emissionB;
    bool isDefined;
} OCCTVisMaterialPBR;

/// Get default VisMaterialPBR values
OCCTVisMaterialPBR OCCTVisMaterialPBRDefault(void);

/// Check equality of two VisMaterialPBR
bool OCCTVisMaterialPBRIsEqual(const OCCTVisMaterialPBR *_Nonnull a,
                                 const OCCTVisMaterialPBR *_Nonnull b);

// =============================================================================
// MARK: - v0.84.0: VrmlAPI, TDataStd Directory/Variable/Expression, TDocStd_XLink,
//         XCAFDimTolObjects_Tool, TPrsStd_DriverTable, TObj_Application
// =============================================================================

// --- VrmlAPI_Writer ---

/// VRML representation mode
typedef enum {
    OCCTVrmlRepresentationShaded = 0,
    OCCTVrmlRepresentationWireFrame = 1,
    OCCTVrmlRepresentationBoth = 2
} OCCTVrmlRepresentation;

/// Write a shape to VRML file (version 1 or 2)
bool OCCTVrmlWriteShape(OCCTShapeRef _Nonnull shape,
                        const char* _Nonnull filePath,
                        int version,
                        double deflection,
                        int representation);

/// Write an XDE document to VRML file with scale
bool OCCTVrmlWriteDocument(OCCTDocumentRef _Nonnull document,
                           const char* _Nonnull filePath,
                           double scale);

// --- TDataStd_Directory ---

/// Create a new directory attribute on a document label
/// labelTag: 0 = main label, >0 = child tag
bool OCCTDocumentDirectoryNew(OCCTDocumentRef _Nonnull document, int labelTag);

/// Find a directory attribute on a label
bool OCCTDocumentDirectoryFind(OCCTDocumentRef _Nonnull document, int labelTag);

/// Add a sub-directory under an existing directory, returns child label tag
int OCCTDocumentDirectoryAddSubDirectory(OCCTDocumentRef _Nonnull document, int parentLabelTag);

/// Make an object label under a directory, returns child label tag
int OCCTDocumentDirectoryMakeObjectLabel(OCCTDocumentRef _Nonnull document, int parentLabelTag);

// --- TDataStd_Variable ---

/// Set a variable attribute on a label
bool OCCTDocumentVariableSet(OCCTDocumentRef _Nonnull document, int labelTag);

/// Set variable name
bool OCCTDocumentVariableSetName(OCCTDocumentRef _Nonnull document, int labelTag,
                                  const char* _Nonnull name);

/// Get variable name (caller must free with OCCTGeomToolsFreeString)
const char* _Nullable OCCTDocumentVariableGetName(OCCTDocumentRef _Nonnull document, int labelTag);

/// Set variable value
bool OCCTDocumentVariableSetValue(OCCTDocumentRef _Nonnull document, int labelTag, double value);

/// Get variable value
double OCCTDocumentVariableGetValue(OCCTDocumentRef _Nonnull document, int labelTag);

/// Check if variable is valued
bool OCCTDocumentVariableIsValued(OCCTDocumentRef _Nonnull document, int labelTag);

/// Set variable unit
bool OCCTDocumentVariableSetUnit(OCCTDocumentRef _Nonnull document, int labelTag,
                                  const char* _Nonnull unit);

/// Get variable unit (caller must free with OCCTGeomToolsFreeString)
const char* _Nullable OCCTDocumentVariableGetUnit(OCCTDocumentRef _Nonnull document, int labelTag);

/// Set variable constant flag
bool OCCTDocumentVariableSetConstant(OCCTDocumentRef _Nonnull document, int labelTag, bool isConstant);

/// Get variable constant flag
bool OCCTDocumentVariableIsConstant(OCCTDocumentRef _Nonnull document, int labelTag);

// --- TDataStd_Expression ---

/// Set an expression attribute on a label
bool OCCTDocumentExpressionSet(OCCTDocumentRef _Nonnull document, int labelTag);

/// Set expression string
bool OCCTDocumentExpressionSetString(OCCTDocumentRef _Nonnull document, int labelTag,
                                      const char* _Nonnull expression);

/// Get expression string (caller must free with OCCTGeomToolsFreeString)
const char* _Nullable OCCTDocumentExpressionGetString(OCCTDocumentRef _Nonnull document, int labelTag);

/// Get expression name (caller must free with OCCTGeomToolsFreeString)
const char* _Nullable OCCTDocumentExpressionGetName(OCCTDocumentRef _Nonnull document, int labelTag);

/// Assign expression to variable on same label (creates expression if needed)
bool OCCTDocumentVariableAssignExpression(OCCTDocumentRef _Nonnull document, int labelTag);

/// Remove expression assignment from variable
bool OCCTDocumentVariableDesassignExpression(OCCTDocumentRef _Nonnull document, int labelTag);

/// Check if variable has assigned expression
bool OCCTDocumentVariableIsAssigned(OCCTDocumentRef _Nonnull document, int labelTag);

// --- TDocStd_XLink ---

/// Set an external link attribute on a label
bool OCCTDocumentXLinkSet(OCCTDocumentRef _Nonnull document, int labelTag);

/// Set XLink document entry path
bool OCCTDocumentXLinkSetDocumentEntry(OCCTDocumentRef _Nonnull document, int labelTag,
                                        const char* _Nonnull entry);

/// Get XLink document entry path (caller must free with OCCTGeomToolsFreeString)
const char* _Nullable OCCTDocumentXLinkGetDocumentEntry(OCCTDocumentRef _Nonnull document, int labelTag);

/// Set XLink label entry string
bool OCCTDocumentXLinkSetLabelEntry(OCCTDocumentRef _Nonnull document, int labelTag,
                                     const char* _Nonnull entry);

/// Get XLink label entry string (caller must free with OCCTGeomToolsFreeString)
const char* _Nullable OCCTDocumentXLinkGetLabelEntry(OCCTDocumentRef _Nonnull document, int labelTag);

// --- XCAFDimTolObjects_Tool ---

/// Get count of dimension objects in XDE document
int OCCTDocumentDimTolDimensionCount(OCCTDocumentRef _Nonnull document);

/// Get count of geometric tolerance objects in XDE document
int OCCTDocumentDimTolToleranceCount(OCCTDocumentRef _Nonnull document);

// --- TPrsStd_DriverTable ---

/// Initialize global presentation driver table with standard drivers
void OCCTDriverTableInitStandard(void);

/// Check if global driver table exists
bool OCCTDriverTableExists(void);

/// Clear all drivers from global table
void OCCTDriverTableClear(void);

// --- TObj_Application ---

/// Opaque handle for TObj_Application
typedef void* OCCTTObjAppRef;

/// Get singleton TObj_Application instance
OCCTTObjAppRef _Nullable OCCTTObjApplicationGetInstance(void);

/// Set verbose flag on TObj_Application
void OCCTTObjApplicationSetVerbose(OCCTTObjAppRef _Nonnull app, bool verbose);

/// Get verbose flag from TObj_Application
bool OCCTTObjApplicationIsVerbose(OCCTTObjAppRef _Nonnull app);

/// Create a new document via TObj_Application
OCCTDocumentRef _Nullable OCCTTObjApplicationCreateDocument(OCCTTObjAppRef _Nonnull app);

// =============================================================================
// MARK: - v0.85.0: UnitsAPI, BinTools, Message, RWMesh_CoordinateSystemConverter, TDF_IDFilter
// =============================================================================

// --- UnitsAPI ---

/// Convert value between any two units (e.g., "mm" to "m", "deg" to "rad")
double OCCTUnitsAnyToAny(double value, const char* _Nonnull fromUnit, const char* _Nonnull toUnit);

/// Convert value from any unit to SI base unit
double OCCTUnitsAnyToSI(double value, const char* _Nonnull unit);

/// Convert value from SI base unit to any unit
double OCCTUnitsAnyFromSI(double value, const char* _Nonnull unit);

/// Convert value from any unit to local system
double OCCTUnitsAnyToLS(double value, const char* _Nonnull unit);

/// Convert value from local system to any unit
double OCCTUnitsAnyFromLS(double value, const char* _Nonnull unit);

/// Set local unit system (0=DEFAULT, 1=SI, 2=MDTV)
void OCCTUnitsSetLocalSystem(int system);

/// Get local unit system (0=DEFAULT, 1=SI, 2=MDTV)
int OCCTUnitsGetLocalSystem(void);

// --- BinTools Shape I/O ---

/// Write a shape to binary data, returns data length (caller must free with free())
const void* _Nullable OCCTBinToolsWriteShape(OCCTShapeRef _Nonnull shape, int* _Nonnull outLength);

/// Read a shape from binary data
OCCTShapeRef _Nullable OCCTBinToolsReadShape(const void* _Nonnull data, int length);

/// Write shape to binary file
bool OCCTBinToolsWriteShapeToFile(OCCTShapeRef _Nonnull shape, const char* _Nonnull filePath);

/// Read shape from binary file
OCCTShapeRef _Nullable OCCTBinToolsReadShapeFromFile(const char* _Nonnull filePath);

// --- Message_Messenger ---

/// Opaque handle for Message_Messenger
typedef void* OCCTMessengerRef;

/// Create a new messenger with default cout printer
OCCTMessengerRef _Nullable OCCTMessengerCreate(void);

/// Release a messenger
void OCCTMessengerRelease(OCCTMessengerRef _Nonnull messenger);

/// Get printer count
int OCCTMessengerPrinterCount(OCCTMessengerRef _Nonnull messenger);

/// Send a message with gravity level (0=Trace, 1=Info, 2=Warning, 3=Alarm, 4=Fail)
void OCCTMessengerSend(OCCTMessengerRef _Nonnull messenger, const char* _Nonnull message, int gravity);

/// Add a file printer to messenger, returns true if added
bool OCCTMessengerAddFilePrinter(OCCTMessengerRef _Nonnull messenger, const char* _Nonnull filePath, int gravity);

/// Remove all printers
void OCCTMessengerRemoveAllPrinters(OCCTMessengerRef _Nonnull messenger);

// --- Message_Report ---

/// Opaque handle for Message_Report
typedef void* OCCTReportRef;

/// Create a new empty report
OCCTReportRef _Nullable OCCTReportCreate(void);

/// Release a report
void OCCTReportRelease(OCCTReportRef _Nonnull report);

/// Set alert limit
void OCCTReportSetLimit(OCCTReportRef _Nonnull report, int limit);

/// Get alert limit
int OCCTReportGetLimit(OCCTReportRef _Nonnull report);

/// Clear all alerts
void OCCTReportClear(OCCTReportRef _Nonnull report);

/// Clear alerts by gravity
void OCCTReportClearByGravity(OCCTReportRef _Nonnull report, int gravity);

/// Dump report to string (caller must free with OCCTGeomToolsFreeString)
const char* _Nullable OCCTReportDump(OCCTReportRef _Nonnull report);

/// Dump report by gravity to string (caller must free with OCCTGeomToolsFreeString)
const char* _Nullable OCCTReportDumpByGravity(OCCTReportRef _Nonnull report, int gravity);

// --- RWMesh_CoordinateSystemConverter ---

/// Coordinate system enum (Z-up=0, Y-up=1)
typedef enum {
    OCCTCoordinateSystemZup = 0,
    OCCTCoordinateSystemYup = 1
} OCCTCoordinateSystem;

/// Coordinate system converter result
typedef struct {
    double x, y, z;
} OCCTPoint3D;

/// Convert a 3D point between coordinate systems with unit scaling
OCCTPoint3D OCCTCoordSystemConvert(double x, double y, double z,
                                    int inputSystem, double inputLengthUnit,
                                    int outputSystem, double outputLengthUnit);

/// Get standard axis direction for a coordinate system
OCCTPoint3D OCCTCoordSystemUpDirection(int system);

// --- TDF_IDFilter ---

/// Opaque handle for TDF_IDFilter
typedef void* OCCTIDFilterRef;

/// Create an ID filter (ignoreAll=true: ignore all except kept; false: keep all except ignored)
OCCTIDFilterRef _Nullable OCCTIDFilterCreate(bool ignoreAll);

/// Release an ID filter
void OCCTIDFilterRelease(OCCTIDFilterRef _Nonnull filter);

/// Check if filter is in ignore-all mode
bool OCCTIDFilterIgnoreAll(OCCTIDFilterRef _Nonnull filter);

/// Set ignore-all mode
void OCCTIDFilterSetIgnoreAll(OCCTIDFilterRef _Nonnull filter, bool ignoreAll);

/// Keep a GUID (in ignore-all mode, this marks the GUID as kept)
void OCCTIDFilterKeep(OCCTIDFilterRef _Nonnull filter, const char* _Nonnull guidString);

/// Ignore a GUID (in keep-all mode, this marks the GUID as ignored)
void OCCTIDFilterIgnore(OCCTIDFilterRef _Nonnull filter, const char* _Nonnull guidString);

/// Check if a GUID is kept
bool OCCTIDFilterIsKept(OCCTIDFilterRef _Nonnull filter, const char* _Nonnull guidString);

/// Check if a GUID is ignored
bool OCCTIDFilterIsIgnored(OCCTIDFilterRef _Nonnull filter, const char* _Nonnull guidString);

// MARK: - TDataStd_BooleanArray

/// Set a boolean array attribute on a label (1-based indices)
bool OCCTDocumentSetBooleanArray(OCCTDocumentRef _Nonnull document, int tag,
                                  int lower, int upper,
                                  const bool* _Nonnull values, int count);

/// Get a boolean array attribute from a label. Returns count, fills values buffer.
int OCCTDocumentGetBooleanArray(OCCTDocumentRef _Nonnull document, int tag,
                                 bool* _Nullable values, int maxCount);

/// Check if a label has a boolean array attribute
bool OCCTDocumentHasBooleanArray(OCCTDocumentRef _Nonnull document, int tag);

// MARK: - TDataStd_BooleanList

/// Set a boolean list attribute on a label
bool OCCTDocumentSetBooleanList(OCCTDocumentRef _Nonnull document, int tag,
                                 const bool* _Nonnull values, int count);

/// Get a boolean list attribute from a label. Returns count, fills values buffer.
int OCCTDocumentGetBooleanList(OCCTDocumentRef _Nonnull document, int tag,
                                bool* _Nullable values, int maxCount);

/// Append a value to a boolean list attribute
bool OCCTDocumentBooleanListAppend(OCCTDocumentRef _Nonnull document, int tag, bool value);

/// Clear a boolean list attribute
bool OCCTDocumentBooleanListClear(OCCTDocumentRef _Nonnull document, int tag);

/// Check if a label has a boolean list attribute
bool OCCTDocumentHasBooleanList(OCCTDocumentRef _Nonnull document, int tag);

// MARK: - TDataStd_ByteArray

/// Set a byte array attribute on a label (0-based indices)
bool OCCTDocumentSetByteArray(OCCTDocumentRef _Nonnull document, int tag,
                               int lower, int upper,
                               const uint8_t* _Nonnull values, int count);

/// Get a byte array attribute from a label. Returns count, fills values buffer.
int OCCTDocumentGetByteArray(OCCTDocumentRef _Nonnull document, int tag,
                              uint8_t* _Nullable values, int maxCount);

/// Check if a label has a byte array attribute
bool OCCTDocumentHasByteArray(OCCTDocumentRef _Nonnull document, int tag);

// MARK: - TDataStd_IntegerList

/// Set an integer list attribute on a label
bool OCCTDocumentSetIntegerList(OCCTDocumentRef _Nonnull document, int tag,
                                 const int* _Nonnull values, int count);

/// Get an integer list attribute from a label. Returns count, fills values buffer.
int OCCTDocumentGetIntegerList(OCCTDocumentRef _Nonnull document, int tag,
                                int* _Nullable values, int maxCount);

/// Append a value to an integer list attribute
bool OCCTDocumentIntegerListAppend(OCCTDocumentRef _Nonnull document, int tag, int value);

/// Clear an integer list attribute
bool OCCTDocumentIntegerListClear(OCCTDocumentRef _Nonnull document, int tag);

/// Check if a label has an integer list attribute
bool OCCTDocumentHasIntegerList(OCCTDocumentRef _Nonnull document, int tag);

// MARK: - TDataStd_RealList

/// Set a real list attribute on a label
bool OCCTDocumentSetRealList(OCCTDocumentRef _Nonnull document, int tag,
                              const double* _Nonnull values, int count);

/// Get a real list attribute from a label. Returns count, fills values buffer.
int OCCTDocumentGetRealList(OCCTDocumentRef _Nonnull document, int tag,
                             double* _Nullable values, int maxCount);

/// Append a value to a real list attribute
bool OCCTDocumentRealListAppend(OCCTDocumentRef _Nonnull document, int tag, double value);

/// Clear a real list attribute
bool OCCTDocumentRealListClear(OCCTDocumentRef _Nonnull document, int tag);

/// Check if a label has a real list attribute
bool OCCTDocumentHasRealList(OCCTDocumentRef _Nonnull document, int tag);

// MARK: - TDataStd_ExtStringArray

/// Set an extended string array attribute on a label (1-based indices)
bool OCCTDocumentSetExtStringArray(OCCTDocumentRef _Nonnull document, int tag,
                                    int lower, int upper,
                                    const char* _Nonnull const* _Nonnull values, int count);

/// Get an extended string array element by index (1-based). Caller must free() the result.
char* _Nullable OCCTDocumentGetExtStringArrayValue(OCCTDocumentRef _Nonnull document, int tag, int index);

/// Get the bounds of an extended string array. Returns length, or -1 if not found.
int OCCTDocumentGetExtStringArrayLength(OCCTDocumentRef _Nonnull document, int tag);

/// Check if a label has an extended string array attribute
bool OCCTDocumentHasExtStringArray(OCCTDocumentRef _Nonnull document, int tag);

// MARK: - TDataStd_ExtStringList

/// Set an extended string list attribute on a label
bool OCCTDocumentSetExtStringList(OCCTDocumentRef _Nonnull document, int tag,
                                   const char* _Nonnull const* _Nonnull values, int count);

/// Get extended string list count from a label. Returns count, or -1 if not found.
int OCCTDocumentGetExtStringListCount(OCCTDocumentRef _Nonnull document, int tag);

/// Get extended string list element by index (0-based). Caller must free() the result.
char* _Nullable OCCTDocumentGetExtStringListValue(OCCTDocumentRef _Nonnull document, int tag, int index);

/// Append a string to an extended string list attribute
bool OCCTDocumentExtStringListAppend(OCCTDocumentRef _Nonnull document, int tag,
                                      const char* _Nonnull value);

/// Clear an extended string list attribute
bool OCCTDocumentExtStringListClear(OCCTDocumentRef _Nonnull document, int tag);

/// Check if a label has an extended string list attribute
bool OCCTDocumentHasExtStringList(OCCTDocumentRef _Nonnull document, int tag);

// MARK: - TDataStd_ReferenceArray

/// Set a reference array attribute on a label (array of label tags)
bool OCCTDocumentSetReferenceArray(OCCTDocumentRef _Nonnull document, int tag,
                                    int lower, int upper,
                                    const int* _Nonnull refTags, int count);

/// Get a reference array from a label. Returns count, fills refTags buffer with tags.
int OCCTDocumentGetReferenceArray(OCCTDocumentRef _Nonnull document, int tag,
                                   int* _Nullable refTags, int maxCount);

/// Check if a label has a reference array attribute
bool OCCTDocumentHasReferenceArray(OCCTDocumentRef _Nonnull document, int tag);

// MARK: - TDataStd_ReferenceList

/// Set a reference list attribute on a label (list of label tags)
bool OCCTDocumentSetReferenceList(OCCTDocumentRef _Nonnull document, int tag,
                                   const int* _Nonnull refTags, int count);

/// Get a reference list from a label. Returns count, fills refTags buffer with tags.
int OCCTDocumentGetReferenceList(OCCTDocumentRef _Nonnull document, int tag,
                                  int* _Nullable refTags, int maxCount);

/// Append a reference to a reference list attribute
bool OCCTDocumentReferenceListAppend(OCCTDocumentRef _Nonnull document, int tag, int refTag);

/// Clear a reference list attribute
bool OCCTDocumentReferenceListClear(OCCTDocumentRef _Nonnull document, int tag);

/// Check if a label has a reference list attribute
bool OCCTDocumentHasReferenceList(OCCTDocumentRef _Nonnull document, int tag);

// MARK: - TDataStd_Relation

/// Set a relation string on a label
bool OCCTDocumentSetRelation(OCCTDocumentRef _Nonnull document, int tag,
                              const char* _Nonnull relation);

/// Get a relation string from a label. Caller must free() the result.
char* _Nullable OCCTDocumentGetRelation(OCCTDocumentRef _Nonnull document, int tag);

/// Check if a label has a relation attribute
bool OCCTDocumentHasRelation(OCCTDocumentRef _Nonnull document, int tag);

// MARK: - ShapeFix_Solid

/// Fix a solid shape (topology and orientation). Returns fixed shape or NULL.
OCCTShapeRef _Nullable OCCTShapeFixSolid(OCCTShapeRef _Nonnull shape);

/// Create a solid from a shell using ShapeFix_Solid
OCCTShapeRef _Nullable OCCTShapeSolidFromShell(OCCTShapeRef _Nonnull shellShape);

// MARK: - ShapeFix_EdgeConnect

/// Connect edges in a shape by extending/trimming to match
OCCTShapeRef _Nullable OCCTShapeFixEdgeConnect(OCCTShapeRef _Nonnull shape);

// MARK: - BRepOffsetAPI_FindContigousEdges

/// Result struct for contiguous edge finding
typedef struct {
    int contigousEdgeCount;
    int degeneratedShapeCount;
} OCCTContigousEdgeResult;

/// Find contiguous edges in a shape
OCCTContigousEdgeResult OCCTShapeFindContigousEdges(OCCTShapeRef _Nonnull shape, double tolerance);

// MARK: - TDataStd_Tick

/// Set a tick (boolean flag) attribute on a label
bool OCCTDocumentSetTick(OCCTDocumentRef _Nonnull document, int tag);

/// Check if a label has a tick attribute
bool OCCTDocumentHasTick(OCCTDocumentRef _Nonnull document, int tag);

/// Remove a tick attribute from a label
bool OCCTDocumentRemoveTick(OCCTDocumentRef _Nonnull document, int tag);

// MARK: - TDataStd_Current

/// Set a label as the current label in the document
bool OCCTDocumentSetCurrentLabel(OCCTDocumentRef _Nonnull document, int tag);

/// Get the current label tag. Returns -1 if no current label.
int OCCTDocumentGetCurrentLabel(OCCTDocumentRef _Nonnull document);

/// Check if the document has a current label set
bool OCCTDocumentHasCurrentLabel(OCCTDocumentRef _Nonnull document);

// MARK: - ShapeAnalysis_Shell

/// Result struct for shell analysis
typedef struct {
    bool hasOrientationProblems;
    bool hasFreeEdges;
    bool hasBadEdges;
    bool hasConnectedEdges;
    int freeEdgeCount;
} OCCTShellAnalysisResult;

/// Analyze shell orientation and edge connectivity
OCCTShellAnalysisResult OCCTShapeAnalyzeShell(OCCTShapeRef _Nonnull shape);

// MARK: - ShapeAnalysis_CanonicalRecognition (detailed)

/// Canonical geometry types for detailed recognition
typedef enum {
    OCCTCanonicalTypeNone = 0,
    OCCTCanonicalTypePlane = 1,
    OCCTCanonicalTypeCylinder = 2,
    OCCTCanonicalTypeCone = 3,
    OCCTCanonicalTypeSphere = 4,
    OCCTCanonicalTypeLine = 5,
    OCCTCanonicalTypeCircle = 6,
    OCCTCanonicalTypeEllipse = 7
} OCCTCanonicalType;

/// Result struct for detailed canonical recognition with geometry parameters
typedef struct {
    OCCTCanonicalType type;
    double gap;
    double originX, originY, originZ;
    double dirX, dirY, dirZ;
    double param1, param2;
} OCCTCanonicalResult;

/// Recognize canonical surface geometry with detailed parameters (plane/cylinder/cone/sphere)
OCCTCanonicalResult OCCTShapeRecognizeCanonicalSurface(OCCTShapeRef _Nonnull faceShape, double tolerance);

/// Recognize canonical curve geometry with detailed parameters (line/circle/ellipse)
OCCTCanonicalResult OCCTShapeRecognizeCanonicalCurve(OCCTShapeRef _Nonnull edgeShape, double tolerance);

// MARK: - Geom_Transformation

/// Opaque handle for Geom_Transformation
typedef void* OCCTGeomTransformRef;

/// Create an identity transformation
OCCTGeomTransformRef _Nullable OCCTGeomTransformCreate(void);

/// Release a Geom_Transformation
void OCCTGeomTransformRelease(OCCTGeomTransformRef _Nonnull transform);

/// Set translation by vector
void OCCTGeomTransformSetTranslation(OCCTGeomTransformRef _Nonnull transform,
                                      double dx, double dy, double dz);

/// Set rotation about an axis
void OCCTGeomTransformSetRotation(OCCTGeomTransformRef _Nonnull transform,
                                   double originX, double originY, double originZ,
                                   double dirX, double dirY, double dirZ,
                                   double angleRadians);

/// Set scale about a point
void OCCTGeomTransformSetScale(OCCTGeomTransformRef _Nonnull transform,
                                double centerX, double centerY, double centerZ,
                                double scaleFactor);

/// Set point mirror
void OCCTGeomTransformSetMirrorPoint(OCCTGeomTransformRef _Nonnull transform,
                                      double x, double y, double z);

/// Set axis mirror
void OCCTGeomTransformSetMirrorAxis(OCCTGeomTransformRef _Nonnull transform,
                                     double originX, double originY, double originZ,
                                     double dirX, double dirY, double dirZ);

/// Get scale factor
double OCCTGeomTransformScaleFactor(OCCTGeomTransformRef _Nonnull transform);

/// Check if negative (reflection)
bool OCCTGeomTransformIsNegative(OCCTGeomTransformRef _Nonnull transform);

/// Transform a point (in-place)
void OCCTGeomTransformApply(OCCTGeomTransformRef _Nonnull transform,
                             double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Get matrix value (row 1-3, col 1-4)
double OCCTGeomTransformValue(OCCTGeomTransformRef _Nonnull transform, int row, int col);

/// Multiply two transformations, return new
OCCTGeomTransformRef _Nullable OCCTGeomTransformMultiplied(OCCTGeomTransformRef _Nonnull t1,
                                                            OCCTGeomTransformRef _Nonnull t2);

/// Invert a transformation, return new
OCCTGeomTransformRef _Nullable OCCTGeomTransformInverted(OCCTGeomTransformRef _Nonnull transform);

// MARK: - Geom_OffsetCurve

/// Create an offset curve from a Curve3D handle
OCCTCurve3DRef _Nullable OCCTCurve3DCreateOffset(OCCTCurve3DRef _Nonnull basisCurve,
                                                   double offset,
                                                   double dirX, double dirY, double dirZ);

/// Get offset value from an offset curve
double OCCTCurve3DOffsetValue(OCCTCurve3DRef _Nonnull curve);

/// Get offset direction from an offset curve
bool OCCTCurve3DOffsetDirection(OCCTCurve3DRef _Nonnull curve,
                                 double* _Nonnull dirX, double* _Nonnull dirY, double* _Nonnull dirZ);

// MARK: - Geom_RectangularTrimmedSurface

/// Create a rectangular trimmed surface from a surface handle
OCCTSurfaceRef _Nullable OCCTSurfaceCreateRectangularTrimmed(OCCTSurfaceRef _Nonnull basisSurface,
                                                               double u1, double u2,
                                                               double v1, double v2);

/// Create a single-direction trimmed surface (U or V only)
OCCTSurfaceRef _Nullable OCCTSurfaceCreateTrimmedInU(OCCTSurfaceRef _Nonnull basisSurface,
                                                       double param1, double param2);

OCCTSurfaceRef _Nullable OCCTSurfaceCreateTrimmedInV(OCCTSurfaceRef _Nonnull basisSurface,
                                                       double param1, double param2);

// MARK: - TNaming Extensions (v0.88.0)

/// Check if a TNaming_NamedShape exists and is not empty on a label (by labelId)
bool OCCTNamingIsEmpty(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Get the version of a TNaming_NamedShape attribute
int OCCTNamingGetVersion(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Set the version of a TNaming_NamedShape attribute
bool OCCTNamingSetVersion(OCCTDocumentRef _Nonnull doc, int64_t labelId, int version);

/// Get the original (old) shape from a named shape attribute
OCCTShapeRef _Nullable OCCTNamingOriginalShape(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Check if a shape has a label in the document
bool OCCTNamingHasLabel(OCCTDocumentRef _Nonnull doc, OCCTShapeRef _Nonnull shape);

/// Find the label ID for a shape in the document; returns -1 if not found
int64_t OCCTNamingFindLabel(OCCTDocumentRef _Nonnull doc, OCCTShapeRef _Nonnull shape);

/// Get the valid-until transaction number for a shape
int OCCTNamingValidUntil(OCCTDocumentRef _Nonnull doc, OCCTShapeRef _Nonnull shape);

// MARK: - TNaming_SameShapeIterator

/// Get count of labels that contain the same shape
int32_t OCCTNamingSameShapeCount(OCCTDocumentRef _Nonnull doc, OCCTShapeRef _Nonnull shape);

/// Get label IDs that contain the same shape (up to maxCount)
/// Returns actual count written to outLabelIds. Caller provides pre-allocated buffer.
int32_t OCCTNamingSameShapeLabels(OCCTDocumentRef _Nonnull doc, OCCTShapeRef _Nonnull shape,
                                   int64_t* _Nonnull outLabelIds, int32_t maxCount);

// MARK: - TDataStd_IntPackedMap

/// Set (find or create) an IntPackedMap attribute on a label
bool OCCTIntPackedMapSet(OCCTDocumentRef _Nonnull doc, int tag, bool isDelta);

/// Add an integer to the IntPackedMap
bool OCCTIntPackedMapAdd(OCCTDocumentRef _Nonnull doc, int tag, int value);

/// Remove an integer from the IntPackedMap
bool OCCTIntPackedMapRemove(OCCTDocumentRef _Nonnull doc, int tag, int value);

/// Check if the IntPackedMap contains an integer
bool OCCTIntPackedMapContains(OCCTDocumentRef _Nonnull doc, int tag, int value);

/// Get the count of elements in the IntPackedMap
int OCCTIntPackedMapExtent(OCCTDocumentRef _Nonnull doc, int tag);

/// Clear all elements from the IntPackedMap
bool OCCTIntPackedMapClear(OCCTDocumentRef _Nonnull doc, int tag);

/// Check if the IntPackedMap is empty
bool OCCTIntPackedMapIsEmpty(OCCTDocumentRef _Nonnull doc, int tag);

/// Get all values from the IntPackedMap
/// Returns count; caller must free the values array
int OCCTIntPackedMapGetValues(OCCTDocumentRef _Nonnull doc, int tag,
                               int* _Nullable* _Nonnull values);

/// Free values array from OCCTIntPackedMapGetValues
void OCCTIntPackedMapFreeValues(int* _Nullable values);

/// Replace all values in the IntPackedMap
bool OCCTIntPackedMapChangeValues(OCCTDocumentRef _Nonnull doc, int tag,
                                    const int* _Nonnull values, int count);

// MARK: - TDataStd_NoteBook

/// Create a NoteBook attribute on a label
bool OCCTNoteBookNew(OCCTDocumentRef _Nonnull doc, int tag);

/// Append a real value to the NoteBook, returns the child label tag or -1
int OCCTNoteBookAppendReal(OCCTDocumentRef _Nonnull doc, int tag, double value);

/// Append an integer value to the NoteBook, returns the child label tag or -1
int OCCTNoteBookAppendInteger(OCCTDocumentRef _Nonnull doc, int tag, int value);

/// Check if a NoteBook exists on a label (searches up hierarchy)
bool OCCTNoteBookFind(OCCTDocumentRef _Nonnull doc, int tag);

// MARK: - TDataStd_UAttribute

/// Set a UAttribute with a GUID string on a label
bool OCCTUAttributeSet(OCCTDocumentRef _Nonnull doc, int tag, const char* _Nonnull guidString);

/// Check if a UAttribute with a given GUID exists on a label
bool OCCTUAttributeHas(OCCTDocumentRef _Nonnull doc, int tag, const char* _Nonnull guidString);

/// Get the GUID string of a UAttribute on a label (caller must free the string)
const char* _Nullable OCCTUAttributeGetID(OCCTDocumentRef _Nonnull doc, int tag,
                                            const char* _Nonnull guidString);

/// Free a GUID string returned by OCCTUAttributeGetID
void OCCTUAttributeFreeGUID(const char* _Nullable guidString);

// MARK: - TDataStd_ChildNodeIterator

/// Get child node count for a TreeNode on a label
int OCCTChildNodeIteratorCount(OCCTDocumentRef _Nonnull doc, int tag, bool allLevels);

// MARK: - TDF_Transaction Named (v0.89.0)

/// Open a named transaction on the document data.
/// @return Transaction index (>= 1 on success, 0 on error)
int32_t OCCTDocumentOpenNamedTransaction(OCCTDocumentRef _Nonnull doc, const char* _Nonnull name);

/// Commit the current transaction and return a delta for undo.
/// The returned delta can be queried with OCCTDelta* functions.
/// @return Opaque delta pointer (NULL if no changes or error). Caller must free with OCCTDeltaRelease.
void* _Nullable OCCTDocumentCommitWithDelta(OCCTDocumentRef _Nonnull doc);

/// Get the transaction number of the current open transaction.
/// @return Transaction number, or 0 if no transaction is open
int32_t OCCTDocumentGetTransactionNumber(OCCTDocumentRef _Nonnull doc);

// MARK: - TDF_Delta (v0.89.0)

/// Check if a delta is empty (no attribute changes recorded).
bool OCCTDeltaIsEmpty(void* _Nonnull delta);

/// Get the begin time of a delta.
int32_t OCCTDeltaBeginTime(void* _Nonnull delta);

/// Get the end time of a delta.
int32_t OCCTDeltaEndTime(void* _Nonnull delta);

/// Get the number of attribute deltas in a delta.
int32_t OCCTDeltaAttributeDeltaCount(void* _Nonnull delta);

/// Set the name of a delta.
void OCCTDeltaSetName(void* _Nonnull delta, const char* _Nonnull name);

/// Get the name of a delta. Caller must free the returned string.
const char* _Nullable OCCTDeltaGetName(void* _Nonnull delta);

/// Free a delta name string.
void OCCTDeltaFreeName(const char* _Nullable name);

/// Release a delta object.
void OCCTDeltaRelease(void* _Nonnull delta);

// MARK: - TDF_ComparisonTool (v0.89.0)

/// Check if a label's references are all contained within its descendants.
/// @return true if self-contained
bool OCCTDocumentIsSelfContained(OCCTDocumentRef _Nonnull doc, int64_t labelId);

// MARK: - TDocStd_XLinkTool (v0.89.0)

/// Copy a label to another label using TDocStd_XLinkTool (simple copy without link).
/// @return true on success
bool OCCTDocumentXLinkCopy(OCCTDocumentRef _Nonnull doc, int64_t tgtLabelId, int64_t srcLabelId);

/// Copy a label to another label with an XLink attribute for cross-document references.
/// @return true on success
bool OCCTDocumentXLinkCopyWithLink(OCCTDocumentRef _Nonnull doc, int64_t tgtLabelId, int64_t srcLabelId);

// MARK: - TFunction_IFunction (v0.89.0)

/// Create a new function at a label with a given GUID.
/// Requires TFunction_Scope to be set on the document root.
/// @return true on success
bool OCCTDocumentNewFunction(OCCTDocumentRef _Nonnull doc, int64_t labelId, const char* _Nonnull guidString);

/// Delete a function from a label.
/// @return true on success
bool OCCTDocumentDeleteFunction(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Get the execution status of a function.
/// 0=WrongDefinition, 1=NotExecuted, 2=Executing, 3=Succeeded, 4=Failed
/// @return status value, or -1 if no function found
int32_t OCCTDocumentFunctionGetExecStatus(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Set the execution status of a function via IFunction.
/// @return true on success
bool OCCTDocumentFunctionSetExecStatus(OCCTDocumentRef _Nonnull doc, int64_t labelId, int32_t status);

// MARK: - TFunction_Scope (v0.89.0)

/// Set (find or create) a TFunction_Scope on the document root.
/// @return true on success
bool OCCTDocumentSetFunctionScope(OCCTDocumentRef _Nonnull doc);

/// Add a label to the function scope.
/// @return true on success
bool OCCTDocumentFunctionScopeAdd(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Remove a label from the function scope.
/// @return true on success
bool OCCTDocumentFunctionScopeRemove(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Check if a label is in the function scope.
bool OCCTDocumentFunctionScopeHas(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Remove all functions from the scope.
/// @return true on success
bool OCCTDocumentFunctionScopeRemoveAll(OCCTDocumentRef _Nonnull doc);

/// Get the number of functions in the scope.
int32_t OCCTDocumentFunctionScopeCount(OCCTDocumentRef _Nonnull doc);

/// Get the free (next available) function ID from the scope.
int32_t OCCTDocumentFunctionScopeGetFreeID(OCCTDocumentRef _Nonnull doc);

// MARK: - TDF_AttributeIterator (v0.89.0)

/// Count the number of attributes on a label.
/// @param withoutForgotten If true, skip forgotten (deleted) attributes
int32_t OCCTDocumentAttributeCount(OCCTDocumentRef _Nonnull doc, int64_t labelId, bool withoutForgotten);

// MARK: - TDF_DataSet (v0.89.0)

/// Check if a DataSet containing a label is empty after adding it.
/// (Utility to verify label has content)
bool OCCTDocumentDataSetIsEmpty(OCCTDocumentRef _Nonnull doc, int64_t labelId);

// MARK: - TDF_ChildIDIterator (v0.90.0)

/// Count child labels that have an attribute with the given GUID string.
/// @param allLevels If true, recurse into all descendants
int32_t OCCTDocumentChildIDCount(OCCTDocumentRef _Nonnull doc, int64_t labelId,
                                  const char* _Nonnull guidString, bool allLevels);

// MARK: - TDocStd_PathParser (v0.90.0)

/// Parse a file path and return the directory (trek) component.
/// Caller must free the returned string.
const char* _Nullable OCCTPathParserTrek(const char* _Nonnull path);

/// Parse a file path and return the filename (without extension).
/// Caller must free the returned string.
const char* _Nullable OCCTPathParserName(const char* _Nonnull path);

/// Parse a file path and return the file extension.
/// Caller must free the returned string.
const char* _Nullable OCCTPathParserExtension(const char* _Nonnull path);

/// Free a string returned by OCCTPathParser* functions.
void OCCTPathParserFreeString(const char* _Nullable str);

// MARK: - TFunction_DriverTable (v0.90.0)

/// Check if a function driver with the given GUID is registered.
bool OCCTFunctionDriverTableHasDriver(const char* _Nonnull guidString);

/// Clear all registered function drivers.
void OCCTFunctionDriverTableClear(void);

// MARK: - TNaming_Scope (v0.90.0)

/// Mark a label as valid in a naming scope context.
/// @return true on success
bool OCCTDocumentNamingScopeValid(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Mark a label and its children as valid.
/// @return true on success
bool OCCTDocumentNamingScopeValidChildren(OCCTDocumentRef _Nonnull doc, int64_t labelId, bool withRoot);

/// Check if a label is valid in the naming scope.
bool OCCTDocumentNamingScopeIsValid(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Invalidate (unvalid) a label in the naming scope.
/// @return true on success
bool OCCTDocumentNamingScopeUnvalid(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Clear all valid labels in the naming scope.
void OCCTDocumentNamingScopeClear(OCCTDocumentRef _Nonnull doc);

/// Get the count of valid labels in the naming scope.
int32_t OCCTDocumentNamingScopeValidCount(OCCTDocumentRef _Nonnull doc);

// MARK: - TNaming_Translator (v0.90.0)

/// Deep-copy a shape using TNaming_Translator.
/// @return New copied shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeTranslatorCopy(OCCTShapeRef _Nonnull shape);

/// Check if two shapes are the same TShape (identity check).
bool OCCTShapeIsSame(OCCTShapeRef _Nonnull shape1, OCCTShapeRef _Nonnull shape2);

// MARK: - TDataXtd_Placement (v0.90.0)

/// Set a TDataXtd_Placement marker attribute on a label.
/// @return true on success
bool OCCTDocumentSetPlacement(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Check if a label has a TDataXtd_Placement attribute.
bool OCCTDocumentHasPlacement(OCCTDocumentRef _Nonnull doc, int64_t labelId);

// MARK: - TDataXtd_Presentation (v0.90.0)

/// Set a TDataXtd_Presentation attribute on a label with a driver GUID.
/// @return true on success
bool OCCTDocumentSetPresentation(OCCTDocumentRef _Nonnull doc, int64_t labelId,
                                  const char* _Nonnull driverGUID);

/// Remove a TDataXtd_Presentation attribute from a label.
void OCCTDocumentUnsetPresentation(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Check if a presentation attribute exists on a label.
bool OCCTDocumentHasPresentation(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Set the display state of a presentation.
bool OCCTDocumentPresentationSetDisplayed(OCCTDocumentRef _Nonnull doc, int64_t labelId, bool displayed);

/// Get the display state of a presentation.
bool OCCTDocumentPresentationIsDisplayed(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Set the color of a presentation (Quantity_NameOfColor as int).
bool OCCTDocumentPresentationSetColor(OCCTDocumentRef _Nonnull doc, int64_t labelId, int32_t colorIndex);

/// Get the color of a presentation. Returns -1 if no own color.
int32_t OCCTDocumentPresentationGetColor(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Set the transparency of a presentation [0.0, 1.0].
bool OCCTDocumentPresentationSetTransparency(OCCTDocumentRef _Nonnull doc, int64_t labelId, double value);

/// Get the transparency. Returns -1.0 if no own transparency.
double OCCTDocumentPresentationGetTransparency(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Set the line width of a presentation.
bool OCCTDocumentPresentationSetWidth(OCCTDocumentRef _Nonnull doc, int64_t labelId, double width);

/// Get the line width. Returns -1.0 if no own width.
double OCCTDocumentPresentationGetWidth(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Set the display mode of a presentation (0=wireframe, 1=shaded, etc.).
bool OCCTDocumentPresentationSetMode(OCCTDocumentRef _Nonnull doc, int64_t labelId, int32_t mode);

/// Get the display mode. Returns -1 if no own mode.
int32_t OCCTDocumentPresentationGetMode(OCCTDocumentRef _Nonnull doc, int64_t labelId);

// MARK: - XCAFDoc_AssemblyIterator (v0.90.0)

/// Count the number of assembly items in a document.
/// @param maxDepth Maximum depth to traverse (0 = unlimited)
int32_t OCCTDocumentAssemblyItemCount(OCCTDocumentRef _Nonnull doc, int32_t maxDepth);

// MARK: - XCAFDoc_DimTol (v0.90.0)

/// Set a DimTol attribute on a label.
/// @param kind Dimension/tolerance type code
/// @param values Array of numeric values
/// @param valueCount Number of values
/// @param name Name string
/// @param description Description string
/// @return true on success
bool OCCTDocumentSetDimTol(OCCTDocumentRef _Nonnull doc, int64_t labelId,
                            int32_t kind,
                            const double* _Nonnull values, int32_t valueCount,
                            const char* _Nonnull name,
                            const char* _Nonnull description);

/// Get the kind of a DimTol attribute. Returns -1 if not found.
int32_t OCCTDocumentGetDimTolKind(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Get the name of a DimTol attribute. Caller must free.
const char* _Nullable OCCTDocumentGetDimTolName(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Get the description of a DimTol attribute. Caller must free.
const char* _Nullable OCCTDocumentGetDimTolDescription(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Get the values of a DimTol attribute.
/// @param outValues Output buffer for values
/// @param maxCount Maximum values to return
/// @return Number of values written
int32_t OCCTDocumentGetDimTolValues(OCCTDocumentRef _Nonnull doc, int64_t labelId,
                                     double* _Nonnull outValues, int32_t maxCount);

/// Free a DimTol string (name or description).
void OCCTDocumentFreeDimTolString(const char* _Nullable str);

// MARK: - IntTools_Tools (v0.90.0)

/// Check if two vertices are coincident (within tolerance).
/// @return 0 if coincident, non-zero otherwise
int32_t OCCTIntToolsComputeVV(OCCTShapeRef _Nonnull vertex1, OCCTShapeRef _Nonnull vertex2);

/// Compute an intermediate parameter between two values.
double OCCTIntToolsIntermediatePoint(double first, double last);

/// Check if two directions are coincident (parallel or anti-parallel).
bool OCCTIntToolsIsDirsCoinside(double dx1, double dy1, double dz1,
                                 double dx2, double dy2, double dz2);

/// Check if two directions are coincident within a tolerance.
bool OCCTIntToolsIsDirsCoinisdeWithTol(double dx1, double dy1, double dz1,
                                        double dx2, double dy2, double dz2, double tol);

/// Compute intersection range from tolerances and angle.
double OCCTIntToolsComputeIntRange(double tol1, double tol2, double angle);

// MARK: - ElCLib — Elementary Curve Library (v0.91.0)

/// Evaluate point on a line at parameter u. Line defined by origin + direction.
void OCCTElCLibValueOnLine(double u, double ox, double oy, double oz,
                            double dx, double dy, double dz,
                            double* _Nonnull outX, double* _Nonnull outY, double* _Nonnull outZ);

/// Evaluate point on a circle at parameter u. Circle defined by axis + radius.
void OCCTElCLibValueOnCircle(double u, double cx, double cy, double cz,
                              double nx, double ny, double nz, double radius,
                              double* _Nonnull outX, double* _Nonnull outY, double* _Nonnull outZ);

/// Evaluate point on an ellipse at parameter u.
void OCCTElCLibValueOnEllipse(double u, double cx, double cy, double cz,
                               double nx, double ny, double nz,
                               double majorRadius, double minorRadius,
                               double* _Nonnull outX, double* _Nonnull outY, double* _Nonnull outZ);

/// Evaluate point + tangent on a line at parameter u.
void OCCTElCLibD1OnLine(double u, double ox, double oy, double oz,
                         double dx, double dy, double dz,
                         double* _Nonnull outPX, double* _Nonnull outPY, double* _Nonnull outPZ,
                         double* _Nonnull outVX, double* _Nonnull outVY, double* _Nonnull outVZ);

/// Evaluate point + tangent on a circle at parameter u.
void OCCTElCLibD1OnCircle(double u, double cx, double cy, double cz,
                           double nx, double ny, double nz, double radius,
                           double* _Nonnull outPX, double* _Nonnull outPY, double* _Nonnull outPZ,
                           double* _Nonnull outVX, double* _Nonnull outVY, double* _Nonnull outVZ);

/// Get parameter of nearest point on line.
double OCCTElCLibParameterOnLine(double ox, double oy, double oz,
                                  double dx, double dy, double dz,
                                  double px, double py, double pz);

/// Get parameter of nearest point on circle.
double OCCTElCLibParameterOnCircle(double cx, double cy, double cz,
                                    double nx, double ny, double nz, double radius,
                                    double px, double py, double pz);

/// Normalize parameter to periodic range [uFirst, uLast).
double OCCTElCLibInPeriod(double u, double uFirst, double uLast);

// MARK: - ElSLib — Elementary Surface Library (v0.91.0)

/// Evaluate point on a plane at (u,v). Plane defined by origin + normal.
void OCCTElSLibValueOnPlane(double u, double v,
                             double ox, double oy, double oz,
                             double nx, double ny, double nz,
                             double* _Nonnull outX, double* _Nonnull outY, double* _Nonnull outZ);

/// Evaluate point on a cylinder at (u,v).
void OCCTElSLibValueOnCylinder(double u, double v,
                                double ox, double oy, double oz,
                                double nx, double ny, double nz, double radius,
                                double* _Nonnull outX, double* _Nonnull outY, double* _Nonnull outZ);

/// Evaluate point on a cone at (u,v).
void OCCTElSLibValueOnCone(double u, double v,
                            double ox, double oy, double oz,
                            double nx, double ny, double nz,
                            double refRadius, double semiAngle,
                            double* _Nonnull outX, double* _Nonnull outY, double* _Nonnull outZ);

/// Evaluate point on a sphere at (u,v).
void OCCTElSLibValueOnSphere(double u, double v,
                              double ox, double oy, double oz,
                              double nx, double ny, double nz, double radius,
                              double* _Nonnull outX, double* _Nonnull outY, double* _Nonnull outZ);

/// Evaluate point on a torus at (u,v).
void OCCTElSLibValueOnTorus(double u, double v,
                             double ox, double oy, double oz,
                             double nx, double ny, double nz,
                             double majorRadius, double minorRadius,
                             double* _Nonnull outX, double* _Nonnull outY, double* _Nonnull outZ);

/// Get (u,v) parameters of nearest point on sphere.
void OCCTElSLibParametersOnSphere(double ox, double oy, double oz,
                                   double nx, double ny, double nz, double radius,
                                   double px, double py, double pz,
                                   double* _Nonnull outU, double* _Nonnull outV);

/// Evaluate point + partial derivatives on sphere at (u,v).
void OCCTElSLibD1OnSphere(double u, double v,
                           double ox, double oy, double oz,
                           double nx, double ny, double nz, double radius,
                           double* _Nonnull outPX, double* _Nonnull outPY, double* _Nonnull outPZ,
                           double* _Nonnull outVuX, double* _Nonnull outVuY, double* _Nonnull outVuZ,
                           double* _Nonnull outVvX, double* _Nonnull outVvY, double* _Nonnull outVvZ);

// MARK: - gp_Quaternion (v0.91.0)

/// Opaque quaternion reference.
typedef struct OCCTQuaternion* OCCTQuaternionRef;

/// Create a quaternion from components (x, y, z, w).
OCCTQuaternionRef _Nonnull OCCTQuaternionCreate(double x, double y, double z, double w);

/// Create a quaternion from axis-angle rotation.
OCCTQuaternionRef _Nonnull OCCTQuaternionCreateFromAxisAngle(double ax, double ay, double az, double angle);

/// Create a quaternion from two vectors (shortest arc rotation).
OCCTQuaternionRef _Nonnull OCCTQuaternionCreateFromVectors(double fromX, double fromY, double fromZ,
                                                            double toX, double toY, double toZ);

/// Release a quaternion.
void OCCTQuaternionRelease(OCCTQuaternionRef _Nonnull q);

/// Get quaternion components.
void OCCTQuaternionGetComponents(OCCTQuaternionRef _Nonnull q,
                                  double* _Nonnull x, double* _Nonnull y,
                                  double* _Nonnull z, double* _Nonnull w);

/// Set Euler angles on a quaternion. Order: 0=Intrinsic_XYZ, etc.
void OCCTQuaternionSetEulerAngles(OCCTQuaternionRef _Nonnull q, int32_t order,
                                   double alpha, double beta, double gamma);

/// Get Euler angles from a quaternion.
void OCCTQuaternionGetEulerAngles(OCCTQuaternionRef _Nonnull q, int32_t order,
                                   double* _Nonnull alpha, double* _Nonnull beta, double* _Nonnull gamma);

/// Get rotation matrix as 9 doubles (row-major).
void OCCTQuaternionGetMatrix(OCCTQuaternionRef _Nonnull q, double* _Nonnull matrix9);

/// Rotate a vector by the quaternion.
void OCCTQuaternionMultiplyVec(OCCTQuaternionRef _Nonnull q,
                                double vx, double vy, double vz,
                                double* _Nonnull outX, double* _Nonnull outY, double* _Nonnull outZ);

/// Multiply two quaternions (Hamilton product). Returns new quaternion.
OCCTQuaternionRef _Nonnull OCCTQuaternionMultiply(OCCTQuaternionRef _Nonnull q1, OCCTQuaternionRef _Nonnull q2);

/// Get axis-angle representation.
void OCCTQuaternionGetVectorAndAngle(OCCTQuaternionRef _Nonnull q,
                                      double* _Nonnull ax, double* _Nonnull ay, double* _Nonnull az,
                                      double* _Nonnull angle);

/// Get the rotation angle.
double OCCTQuaternionGetRotationAngle(OCCTQuaternionRef _Nonnull q);

/// Normalize the quaternion to unit length.
void OCCTQuaternionNormalize(OCCTQuaternionRef _Nonnull q);

// MARK: - OSD_Timer (v0.91.0)

/// Opaque timer reference.
typedef struct OCCTTimer* OCCTTimerRef;

/// Create a new timer (stopped).
OCCTTimerRef _Nonnull OCCTTimerCreate(void);

/// Release a timer.
void OCCTTimerRelease(OCCTTimerRef _Nonnull timer);

/// Start the timer.
void OCCTTimerStart(OCCTTimerRef _Nonnull timer);

/// Stop the timer.
void OCCTTimerStop(OCCTTimerRef _Nonnull timer);

/// Reset the timer to zero.
void OCCTTimerReset(OCCTTimerRef _Nonnull timer);

/// Get elapsed wall-clock time in seconds.
double OCCTTimerElapsedTime(OCCTTimerRef _Nonnull timer);

/// Get current wall-clock time in seconds (static).
double OCCTTimerGetWallClockTime(void);

// MARK: - Bnd_OBB — Oriented Bounding Box (v0.92.0)

/// Opaque OBB reference.
typedef struct OCCTOBB* OCCTOBBRef;

/// Create an OBB from center, axes, and half-sizes.
OCCTOBBRef _Nonnull OCCTOBBCreate(double cx, double cy, double cz,
                                    double xDirX, double xDirY, double xDirZ,
                                    double yDirX, double yDirY, double yDirZ,
                                    double zDirX, double zDirY, double zDirZ,
                                    double hx, double hy, double hz);

/// Create an OBB from a shape's bounding box.
OCCTOBBRef _Nullable OCCTOBBCreateFromShape(OCCTShapeRef _Nonnull shape);

/// Release an OBB.
void OCCTOBBRelease(OCCTOBBRef _Nonnull obb);

/// Check if OBB is void (empty).
bool OCCTOBBIsVoid(OCCTOBBRef _Nonnull obb);

/// Get center of OBB.
void OCCTOBBGetCenter(OCCTOBBRef _Nonnull obb, double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Get half-sizes of OBB.
void OCCTOBBGetHalfSizes(OCCTOBBRef _Nonnull obb, double* _Nonnull hx, double* _Nonnull hy, double* _Nonnull hz);

/// Check if a point is outside the OBB.
bool OCCTOBBIsOutPoint(OCCTOBBRef _Nonnull obb, double px, double py, double pz);

/// Check if another OBB is outside this OBB.
bool OCCTOBBIsOutOBB(OCCTOBBRef _Nonnull obb1, OCCTOBBRef _Nonnull obb2);

/// Enlarge the OBB by a gap value.
void OCCTOBBEnlarge(OCCTOBBRef _Nonnull obb, double gap);

/// Get square extent (diagonal squared).
double OCCTOBBSquareExtent(OCCTOBBRef _Nonnull obb);

// MARK: - Bnd_Range — 1D Range (v0.92.0)

/// Opaque range reference.
typedef struct OCCTRange* OCCTRangeRef;

/// Create a range [min, max].
OCCTRangeRef _Nonnull OCCTRangeCreate(double min, double max);

/// Create a void range.
OCCTRangeRef _Nonnull OCCTRangeCreateVoid(void);

/// Release a range.
void OCCTRangeRelease(OCCTRangeRef _Nonnull range);

/// Check if range is void.
bool OCCTRangeIsVoid(OCCTRangeRef _Nonnull range);

/// Get bounds. Returns false if void.
bool OCCTRangeGetBounds(OCCTRangeRef _Nonnull range, double* _Nonnull first, double* _Nonnull last);

/// Get delta (max - min).
double OCCTRangeDelta(OCCTRangeRef _Nonnull range);

/// Check if value is in range.
bool OCCTRangeContains(OCCTRangeRef _Nonnull range, double value);

/// Extend range to include a value.
void OCCTRangeAddValue(OCCTRangeRef _Nonnull range, double value);

/// Extend range to include another range.
void OCCTRangeAddRange(OCCTRangeRef _Nonnull range, OCCTRangeRef _Nonnull other);

/// Intersect with another range (modifies this range).
void OCCTRangeCommon(OCCTRangeRef _Nonnull range, OCCTRangeRef _Nonnull other);

/// Enlarge both boundaries by delta.
void OCCTRangeEnlarge(OCCTRangeRef _Nonnull range, double delta);

/// Trim lower boundary.
void OCCTRangeTrimFrom(OCCTRangeRef _Nonnull range, double lower);

/// Trim upper boundary.
void OCCTRangeTrimTo(OCCTRangeRef _Nonnull range, double upper);

// MARK: - BRepClass3d — Point Classification (v0.92.0)

/// Classify a 3D point relative to a solid shape.
/// @return 0=IN, 1=OUT, 2=ON, 3=UNKNOWN
int32_t OCCTShapeClassifyPoint(OCCTShapeRef _Nonnull shape,
                                double px, double py, double pz, double tolerance);

// MARK: - TDataXtd_Constraint (v0.92.0)

/// Set a TDataXtd_Constraint attribute on a label.
bool OCCTDocumentSetConstraint(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Set the constraint type. Types: 0=RADIUS..22=FROM
bool OCCTDocumentConstraintSetType(OCCTDocumentRef _Nonnull doc, int64_t labelId, int32_t type);

/// Get the constraint type. Returns -1 if not found.
int32_t OCCTDocumentConstraintGetType(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Get the number of geometries in the constraint.
int32_t OCCTDocumentConstraintNbGeometries(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Check if constraint is planar (2D).
bool OCCTDocumentConstraintIsPlanar(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Check if constraint is a dimension (has value).
bool OCCTDocumentConstraintIsDimension(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Set the verified flag on a constraint.
bool OCCTDocumentConstraintSetVerified(OCCTDocumentRef _Nonnull doc, int64_t labelId, bool verified);

/// Get the verified flag.
bool OCCTDocumentConstraintGetVerified(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Clear all geometries from a constraint.
bool OCCTDocumentConstraintClearGeometries(OCCTDocumentRef _Nonnull doc, int64_t labelId);

// MARK: - OSD_MemInfo (v0.93.0)

/// Get heap usage in bytes.
int64_t OCCTMemInfoHeapUsage(void);

/// Get working set in bytes.
int64_t OCCTMemInfoWorkingSet(void);

/// Get heap usage in precise MiB.
double OCCTMemInfoHeapUsageMiB(void);

/// Get a full memory info string. Caller must free.
const char* _Nullable OCCTMemInfoString(void);

/// Free a memory info string.
void OCCTMemInfoFreeString(const char* _Nullable str);

// MARK: - ShapeFix_EdgeProjAux (v0.93.0)

/// Project edge endpoints onto face pcurve.
/// @param outFirst Output first parameter
/// @param outLast Output last parameter
/// @return true if both projections done
bool OCCTShapeFixEdgeProjAux(OCCTShapeRef _Nonnull shape, int32_t faceIndex, int32_t edgeIndex,
                              double precision,
                              double* _Nonnull outFirst, double* _Nonnull outLast);

// MARK: - Geom2dAPI_Interpolate (v0.93.0)

/// Interpolate a 2D BSpline curve through points.
/// @param xs Array of X coordinates
/// @param ys Array of Y coordinates
/// @param count Number of points
/// @param periodic If true, create a periodic (closed) curve
/// @param tolerance Interpolation tolerance
/// @return Opaque curve handle, or NULL on failure. Caller must free with OCCTCurve2DRelease.
OCCTCurve2DRef _Nullable OCCTCurve2DInterpolate2D(const double* _Nonnull xs, const double* _Nonnull ys,
                                                     int32_t count, bool periodic, double tolerance);

// MARK: - Geom2dAPI_PointsToBSpline (v0.93.0)

/// Approximate a 2D BSpline curve through points.
/// @param xs Array of X coordinates
/// @param ys Array of Y coordinates
/// @param count Number of points
/// @return Opaque curve handle, or NULL on failure. Caller must free with OCCTCurve2DRelease.
OCCTCurve2DRef _Nullable OCCTCurve2DApproximate2D(const double* _Nonnull xs, const double* _Nonnull ys,
                                                     int32_t count);

// MARK: - TDataXtd_PatternStd (v0.93.0)

/// Set a TDataXtd_PatternStd attribute on a label.
bool OCCTDocumentSetPatternStd(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Set pattern signature (1=linear, 2=circular, 3=rectangular, 4=radial, 5=mirror).
bool OCCTDocumentPatternSetSignature(OCCTDocumentRef _Nonnull doc, int64_t labelId, int32_t signature);

/// Get pattern signature. Returns -1 if not found.
int32_t OCCTDocumentPatternGetSignature(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Get number of transforms in the pattern.
int32_t OCCTDocumentPatternNbTrsfs(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Check if a label has a pattern attribute.
bool OCCTDocumentHasPattern(OCCTDocumentRef _Nonnull doc, int64_t labelId);

// MARK: - BRepAlgo_FaceRestrictor (v0.93.0)

/// Restrict a face to its wires using BRepAlgo_FaceRestrictor and return result face count.
/// @return Number of result faces, or -1 on error
int32_t OCCTShapeFaceRestrictAlgo(OCCTShapeRef _Nonnull shape, int32_t faceIndex,
                                    OCCTShapeRef _Nullable * _Nullable outFaces, int32_t maxFaces);

// MARK: - math_Matrix (v0.94.0)

typedef struct OCCTMathMatrix* OCCTMathMatrixRef;

/// Create an NxN matrix initialized to a value.
OCCTMathMatrixRef _Nonnull OCCTMathMatrixCreate(int32_t rows, int32_t cols, double initValue);

/// Release a matrix.
void OCCTMathMatrixRelease(OCCTMathMatrixRef _Nonnull m);

/// Get matrix dimensions.
int32_t OCCTMathMatrixRows(OCCTMathMatrixRef _Nonnull m);
int32_t OCCTMathMatrixCols(OCCTMathMatrixRef _Nonnull m);

/// Get/set matrix value (1-based indices).
double OCCTMathMatrixGetValue(OCCTMathMatrixRef _Nonnull m, int32_t row, int32_t col);
void OCCTMathMatrixSetValue(OCCTMathMatrixRef _Nonnull m, int32_t row, int32_t col, double value);

/// Get matrix determinant.
double OCCTMathMatrixDeterminant(OCCTMathMatrixRef _Nonnull m);

/// Invert the matrix in-place.
bool OCCTMathMatrixInvert(OCCTMathMatrixRef _Nonnull m);

/// Multiply all elements by a scalar.
void OCCTMathMatrixMultiplyScalar(OCCTMathMatrixRef _Nonnull m, double scalar);

/// Transpose the matrix in-place.
void OCCTMathMatrixTranspose(OCCTMathMatrixRef _Nonnull m);

// MARK: - math_Gauss (v0.94.0)

/// Solve linear system Ax=b using Gaussian elimination.
/// @param matrixData Row-major NxN matrix
/// @param n Matrix dimension
/// @param rhs Right-hand side vector (length n)
/// @param outSolution Output solution vector (length n)
/// @return true on success
bool OCCTMathGaussSolve(const double* _Nonnull matrixData, int32_t n,
                         const double* _Nonnull rhs, double* _Nonnull outSolution);

/// Compute determinant using Gauss elimination.
double OCCTMathGaussDeterminant(const double* _Nonnull matrixData, int32_t n);

// MARK: - math_SVD (v0.94.0)

/// Solve least-squares system using SVD.
/// @param matrixData Row-major MxN matrix
/// @param rows Number of rows (M)
/// @param cols Number of cols (N)
/// @param rhs Right-hand side vector (length M)
/// @param outSolution Output solution vector (length N)
/// @return true on success
bool OCCTMathSVDSolve(const double* _Nonnull matrixData, int32_t rows, int32_t cols,
                       const double* _Nonnull rhs, double* _Nonnull outSolution);

// MARK: - math_DirectPolynomialRoots (v0.94.0)

/// Find real roots of polynomial up to degree 4.
/// Coefficients: a*x^n + b*x^(n-1) + ... + constant
/// @param coeffs Array of coefficients [a, b, c, ...] (2-5 elements)
/// @param nCoeffs Number of coefficients (2=linear, 3=quadratic, 4=cubic, 5=quartic)
/// @param outRoots Output buffer for roots (max 4)
/// @return Number of real roots found, or -1 on error
int32_t OCCTMathPolynomialRoots(const double* _Nonnull coeffs, int32_t nCoeffs,
                                  double* _Nonnull outRoots);

// MARK: - math_Jacobi (v0.94.0)

/// Compute eigenvalues of a symmetric NxN matrix using Jacobi method.
/// @param matrixData Row-major NxN symmetric matrix
/// @param n Matrix dimension
/// @param outEigenvalues Output eigenvalues (length n)
/// @return true on success
bool OCCTMathJacobiEigenvalues(const double* _Nonnull matrixData, int32_t n,
                                double* _Nonnull outEigenvalues);

// MARK: - Convert_CircleToBSplineCurve (v0.94.0)

/// Convert a 2D circle (arc) to a BSpline curve.
/// @param cx,cy Center coordinates
/// @param radius Circle radius
/// @param u1,u2 Parameter range (0 to 2*PI for full circle)
/// @return Opaque 2D curve handle, or NULL on failure
OCCTCurve2DRef _Nullable OCCTConvertCircleToBSpline2D(double cx, double cy, double radius,
                                                        double u1, double u2);

// MARK: - Convert_SphereToBSplineSurface (v0.94.0)

/// Convert a sphere to a BSpline surface.
/// @param ox,oy,oz Center
/// @param nx,ny,nz Axis direction
/// @param radius Sphere radius
/// @return Opaque surface handle, or NULL on failure
OCCTSurfaceRef _Nullable OCCTConvertSphereToBSplineSurface(double ox, double oy, double oz,
                                                             double nx, double ny, double nz,
                                                             double radius);

// MARK: - OSD_Environment (v0.94.0)

/// Get the value of an environment variable. Caller must free.
const char* _Nullable OCCTEnvironmentGet(const char* _Nonnull name);

/// Set an environment variable. Returns true on success.
bool OCCTEnvironmentSet(const char* _Nonnull name, const char* _Nonnull value);

/// Remove an environment variable.
void OCCTEnvironmentRemove(const char* _Nonnull name);

/// Free an environment string.
void OCCTEnvironmentFreeString(const char* _Nullable str);

// MARK: - Convert_EllipseToBSplineCurve (v0.95.0)

/// Convert a 2D ellipse arc to a BSpline curve.
OCCTCurve2DRef _Nullable OCCTConvertEllipseToBSpline2D(double cx, double cy,
                                                         double majorRadius, double minorRadius,
                                                         double u1, double u2);

// MARK: - Convert_HyperbolaToBSplineCurve (v0.95.0)

/// Convert a 2D hyperbola arc to a BSpline curve.
OCCTCurve2DRef _Nullable OCCTConvertHyperbolaToBSpline2D(double cx, double cy,
                                                           double majorRadius, double minorRadius,
                                                           double u1, double u2);

// MARK: - Convert_ParabolaToBSplineCurve (v0.95.0)

/// Convert a 2D parabola arc to a BSpline curve.
OCCTCurve2DRef _Nullable OCCTConvertParabolaToBSpline2D(double cx, double cy, double focal,
                                                          double u1, double u2);

// MARK: - Convert_CylinderToBSplineSurface (v0.95.0)

/// Convert a cylinder patch to a BSpline surface.
OCCTSurfaceRef _Nullable OCCTConvertCylinderToBSplineSurface(double ox, double oy, double oz,
                                                               double nx, double ny, double nz,
                                                               double radius,
                                                               double u1, double u2,
                                                               double v1, double v2);

// MARK: - Convert_ConeToBSplineSurface (v0.95.0)

/// Convert a cone patch to a BSpline surface.
OCCTSurfaceRef _Nullable OCCTConvertConeToBSplineSurface(double ox, double oy, double oz,
                                                           double nx, double ny, double nz,
                                                           double semiAngle, double refRadius,
                                                           double u1, double u2,
                                                           double v1, double v2);

// MARK: - Convert_TorusToBSplineSurface (v0.95.0)

/// Convert a full torus to a BSpline surface.
OCCTSurfaceRef _Nullable OCCTConvertTorusToBSplineSurface(double ox, double oy, double oz,
                                                            double nx, double ny, double nz,
                                                            double majorRadius, double minorRadius);

// MARK: - math_Householder (v0.95.0)

/// Solve overdetermined system using Householder QR.
/// @param matrixData Row-major MxN matrix (M >= N)
/// @param rows M, cols N
/// @param rhs Right-hand side (length M)
/// @param outSolution Output (length N)
/// @return true on success
bool OCCTMathHouseholderSolve(const double* _Nonnull matrixData, int32_t rows, int32_t cols,
                               const double* _Nonnull rhs, double* _Nonnull outSolution);

// MARK: - math_Crout (v0.95.0)

/// Solve symmetric system using Crout LDL^T decomposition.
/// @param matrixData Row-major NxN symmetric matrix
/// @param n Matrix dimension
/// @param rhs Right-hand side (length N)
/// @param outSolution Output (length N)
/// @return true on success
bool OCCTMathCroutSolve(const double* _Nonnull matrixData, int32_t n,
                          const double* _Nonnull rhs, double* _Nonnull outSolution);

/// Determinant of symmetric matrix via Crout decomposition.
double OCCTMathCroutDeterminant(const double* _Nonnull matrixData, int32_t n);

// MARK: - ShapeFix_IntersectionTool (v0.95.0)

/// Fix intersecting wires on a face of a shape.
/// @return true if any fixes were applied
bool OCCTShapeFixIntersectingWires(OCCTShapeRef _Nonnull shape, int32_t faceIndex, double precision);

// MARK: - XCAFDoc_AssemblyItemRef (v0.96.0)

/// Set an assembly item reference on a label.
bool OCCTDocumentSetAssemblyItemRef(OCCTDocumentRef _Nonnull doc, int64_t labelId,
                                     const char* _Nonnull itemPath);

/// Get the assembly item path string. Caller must free.
const char* _Nullable OCCTDocumentGetAssemblyItemRef(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Set subshape index on an assembly item ref.
bool OCCTDocumentAssemblyItemRefSetSubshape(OCCTDocumentRef _Nonnull doc, int64_t labelId, int32_t index);

/// Get subshape index. Returns -1 if not set.
int32_t OCCTDocumentAssemblyItemRefGetSubshape(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Check if assembly item ref has extra reference (GUID or subshape).
bool OCCTDocumentAssemblyItemRefHasExtra(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Clear extra reference from assembly item ref.
bool OCCTDocumentAssemblyItemRefClearExtra(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Check if assembly item ref points to orphan (nonexistent item).
bool OCCTDocumentAssemblyItemRefIsOrphan(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Free an assembly item ref string.
void OCCTDocumentFreeAssemblyItemRefString(const char* _Nullable str);

// MARK: - BRepAlgo_Image (v0.96.0)

typedef struct OCCTBRepAlgoImage* OCCTBRepAlgoImageRef;

/// Create a shape image mapping.
OCCTBRepAlgoImageRef _Nonnull OCCTBRepAlgoImageCreate(void);

/// Release a shape image.
void OCCTBRepAlgoImageRelease(OCCTBRepAlgoImageRef _Nonnull img);

/// Set root shape.
void OCCTBRepAlgoImageSetRoot(OCCTBRepAlgoImageRef _Nonnull img, OCCTShapeRef _Nonnull shape);

/// Bind old shape to new shape (replacement).
void OCCTBRepAlgoImageBind(OCCTBRepAlgoImageRef _Nonnull img,
                            OCCTShapeRef _Nonnull oldShape, OCCTShapeRef _Nonnull newShape);

/// Check if shape has image.
bool OCCTBRepAlgoImageHasImage(OCCTBRepAlgoImageRef _Nonnull img, OCCTShapeRef _Nonnull shape);

/// Check if shape is an image of another.
bool OCCTBRepAlgoImageIsImage(OCCTBRepAlgoImageRef _Nonnull img, OCCTShapeRef _Nonnull shape);

/// Clear all mappings.
void OCCTBRepAlgoImageClear(OCCTBRepAlgoImageRef _Nonnull img);

// MARK: - OSD_Path (v0.96.0)

/// Parse a path and return the filename (without extension). Caller must free.
const char* _Nullable OCCTOSDPathName(const char* _Nonnull path);

/// Parse a path and return the file extension (with dot). Caller must free.
const char* _Nullable OCCTOSDPathExtension(const char* _Nonnull path);

/// Parse a path and return the directory trek. Caller must free.
const char* _Nullable OCCTOSDPathTrek(const char* _Nonnull path);

/// Get the system name (full path). Caller must free.
const char* _Nullable OCCTOSDPathSystemName(const char* _Nonnull path);

/// Split path into folder and filename. Caller must free both.
void OCCTOSDPathFolderAndFile(const char* _Nonnull path,
                               const char* _Nullable * _Nonnull outFolder,
                               const char* _Nullable * _Nonnull outFile);

/// Check if a path is valid.
bool OCCTOSDPathIsValid(const char* _Nonnull path);

/// Check if path is a Unix absolute path.
bool OCCTOSDPathIsUnixPath(const char* _Nonnull path);

/// Check if path is relative.
bool OCCTOSDPathIsRelative(const char* _Nonnull path);

/// Check if path is absolute.
bool OCCTOSDPathIsAbsolute(const char* _Nonnull path);

/// Free an OSD path string.
void OCCTOSDPathFreeString(const char* _Nullable str);

// MARK: - BRepClass_FClassifier (v0.96.0)

/// Classify a 2D point on a face (in UV space).
/// @return 0=IN, 1=OUT, 2=ON, 3=UNKNOWN
int32_t OCCTShapeClassifyPoint2D(OCCTShapeRef _Nonnull shape, int32_t faceIndex,
                                   double u, double v, double tolerance);

// MARK: - BRepAlgo_Loop (v0.97.0)

/// Build loops (wires) from edges on a face, then optionally convert to faces.
/// @return Number of result wires/faces, or -1 on error
int32_t OCCTShapeBuildLoops(OCCTShapeRef _Nonnull shape, int32_t faceIndex);

// MARK: - Bnd_BoundSortBox (v0.97.0)

typedef struct OCCTBoundSortBox* OCCTBoundSortBoxRef;

/// Create a bound sort box with boxes.
/// @param boxes Array of bounding boxes (6 doubles each: xmin,ymin,zmin,xmax,ymax,zmax)
/// @param count Number of boxes
OCCTBoundSortBoxRef _Nonnull OCCTBoundSortBoxCreate(const double* _Nonnull boxes, int32_t count);

/// Release a bound sort box.
void OCCTBoundSortBoxRelease(OCCTBoundSortBoxRef _Nonnull bsb);

/// Find indices of boxes that intersect a query box.
/// @return Number of hits
int32_t OCCTBoundSortBoxCompare(OCCTBoundSortBoxRef _Nonnull bsb,
                                  double xmin, double ymin, double zmin,
                                  double xmax, double ymax, double zmax,
                                  int32_t* _Nonnull outIndices, int32_t maxIndices);

// MARK: - BRepGProp_Domain (v0.97.0)

/// Count boundary edges of a face.
int32_t OCCTShapeFaceDomainEdgeCount(OCCTShapeRef _Nonnull shape, int32_t faceIndex);

// MARK: - TNaming_Naming (v0.97.0)

/// Insert a TNaming_Naming attribute on a label.
bool OCCTDocumentInsertNaming(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Check if a naming attribute is defined on a label.
bool OCCTDocumentNamingIsDefined(OCCTDocumentRef _Nonnull doc, int64_t labelId);

// MARK: - Precision (v0.97.0)

/// Get OCCT confusion tolerance (1e-7).
double OCCTPrecisionConfusion(void);

/// Get OCCT angular tolerance (1e-12).
double OCCTPrecisionAngular(void);

/// Get OCCT intersection tolerance.
double OCCTPrecisionIntersection(void);

/// Get OCCT approximation tolerance.
double OCCTPrecisionApproximation(void);

/// Get OCCT infinite value (2e100).
double OCCTPrecisionInfinite(void);

/// Get OCCT parametric confusion tolerance.
double OCCTPrecisionPConfusion(void);

/// Check if a value is considered infinite.
bool OCCTPrecisionIsInfinite(double value);

// MARK: - IntAna_IntConicQuad (v0.98.0)

/// Result of a conic-quadric intersection.
typedef struct {
    double points[12]; // up to 4 points (x,y,z each)
    double params[4];  // parameter on conic for each point
    int32_t count;     // number of intersection points
    bool isParallel;
    bool isInQuadric;
} OCCTIntConicQuadResult;

/// Intersect a line with a plane.
OCCTIntConicQuadResult OCCTIntAnaLineQuad(double lox, double loy, double loz,
                                            double ldx, double ldy, double ldz,
                                            double pox, double poy, double poz,
                                            double pnx, double pny, double pnz);

/// Intersect a line with a sphere.
OCCTIntConicQuadResult OCCTIntAnaLineSphere(double lox, double loy, double loz,
                                              double ldx, double ldy, double ldz,
                                              double sx, double sy, double sz,
                                              double snx, double sny, double snz, double radius);

// MARK: - IntAna_QuadQuadGeo (v0.98.0)

/// Result of a quadric-quadric intersection.
typedef struct {
    int32_t solutionCount;
    int32_t resultType; // IntAna_ResultType enum
    double points[12];  // up to 4 result points
    double lines[24];   // up to 4 lines (origin xyz + direction xyz)
} OCCTQuadQuadGeoResult;

/// Intersect two planes.
OCCTQuadQuadGeoResult OCCTIntAnaPlanePlane(double p1ox, double p1oy, double p1oz,
                                             double p1nx, double p1ny, double p1nz,
                                             double p2ox, double p2oy, double p2oz,
                                             double p2nx, double p2ny, double p2nz);

/// Intersect a plane with a sphere.
OCCTQuadQuadGeoResult OCCTIntAnaPlaneSphere(double pox, double poy, double poz,
                                              double pnx, double pny, double pnz,
                                              double sx, double sy, double sz,
                                              double snx, double sny, double snz, double radius);

// MARK: - IntAna_Int3Pln (v0.98.0)

/// Intersect three planes. Returns intersection point or invalid point if parallel.
/// @param outX,outY,outZ Output intersection point
/// @return true if intersection exists
bool OCCTIntAna3Planes(double p1ox, double p1oy, double p1oz, double p1nx, double p1ny, double p1nz,
                        double p2ox, double p2oy, double p2oz, double p2nx, double p2ny, double p2nz,
                        double p3ox, double p3oy, double p3oz, double p3nx, double p3ny, double p3nz,
                        double* _Nonnull outX, double* _Nonnull outY, double* _Nonnull outZ);

// MARK: - IntAna_IntLinTorus (v0.98.0)

/// Intersect a line with a torus.
/// @param outPoints Output buffer for intersection points (max 4 * 3 = 12 doubles)
/// @return Number of intersection points (0-4)
int32_t OCCTIntAnaLineTorus(double lox, double loy, double loz,
                              double ldx, double ldy, double ldz,
                              double tox, double toy, double toz,
                              double tnx, double tny, double tnz,
                              double majorRadius, double minorRadius,
                              double* _Nonnull outPoints);

// MARK: - OSD_Chronometer (v0.98.0)

/// Get process CPU time (user + system).
void OCCTGetProcessCPU(double* _Nonnull userSeconds, double* _Nonnull systemSeconds);

/// Get current thread CPU time.
void OCCTGetThreadCPU(double* _Nonnull userSeconds, double* _Nonnull systemSeconds);

// MARK: - OSD_Process (v0.98.0)

/// Get process ID.
int32_t OCCTProcessId(void);

/// Get username. Caller must free.
const char* _Nullable OCCTProcessUserName(void);

/// Get executable path. Caller must free.
const char* _Nullable OCCTProcessExecutablePath(void);

/// Get executable folder. Caller must free.
const char* _Nullable OCCTProcessExecutableFolder(void);

/// Free a process string.
void OCCTProcessFreeString(const char* _Nullable str);

// MARK: - Draft_Modification (v0.98.0)

/// Apply a draft angle to a face of a shape.
/// @return Result shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeDraftModification(OCCTShapeRef _Nonnull shape, int32_t faceIndex,
                                        double dirX, double dirY, double dirZ,
                                        double angle,
                                        double planeOX, double planeOY, double planeOZ,
                                        double planeNX, double planeNY, double planeNZ);

// MARK: - Convert_CompBezierCurvesToBSplineCurve (v0.99.0)

/// Result structure for composite Bezier → BSpline 3D curve conversion.
typedef struct {
    int32_t degree;
    int32_t nbPoles;
    int32_t nbKnots;
    double poles[300];   ///< Up to 100 3D poles (x,y,z interleaved)
    double knots[50];
    int32_t mults[50];
} OCCTBezierBSplineResult;

/// Convert N composite Bezier segments (3D) to a single BSpline curve.
/// @param poles Flattened array of [x,y,z] control points; length = segCount * ptsPerSeg * 3
/// @param segCount Number of Bezier segments
/// @param ptsPerSeg Number of control points per segment (degree+1)
/// @param out Result filled on success
/// @return true on success
bool OCCTConvertCompBezierToBSpline(const double* _Nonnull poles,
                                    int32_t segCount, int32_t ptsPerSeg,
                                    OCCTBezierBSplineResult* _Nonnull out);

/// Result structure for composite Bezier → BSpline 2D curve conversion.
typedef struct {
    int32_t degree;
    int32_t nbPoles;
    int32_t nbKnots;
    double poles[200];   ///< Up to 100 2D poles (x,y interleaved)
    double knots[50];
    int32_t mults[50];
} OCCTBezierBSpline2dResult;

/// Convert N composite Bezier segments (2D) to a single BSpline curve.
/// @param poles Flattened array of [x,y] control points; length = segCount * ptsPerSeg * 2
/// @param segCount Number of Bezier segments
/// @param ptsPerSeg Number of control points per segment (degree+1)
/// @param out Result filled on success
/// @return true on success
bool OCCTConvertCompBezier2dToBSpline2d(const double* _Nonnull poles,
                                        int32_t segCount, int32_t ptsPerSeg,
                                        OCCTBezierBSpline2dResult* _Nonnull out);

// MARK: - Geom_OffsetSurface Extensions (v0.99.0)

/// Get the offset distance of an offset surface.
/// @return The offset value, or 0.0 if not an offset surface
double OCCTSurfaceOffsetValue(OCCTSurfaceRef _Nonnull surface);

/// Set the offset distance of an offset surface (mutates in place).
void OCCTSurfaceSetOffsetValue(OCCTSurfaceRef _Nonnull surface, double offset);

/// Get the basis (underlying) surface of an offset surface.
/// @return The basis surface, or NULL if not an offset surface
OCCTSurfaceRef _Nullable OCCTSurfaceOffsetBasis(OCCTSurfaceRef _Nonnull surface);

// MARK: - OSD_File (v0.99.0)

/// Opaque reference to an OSD_File object.
typedef struct OCCTOSDFile* OCCTOSDFileRef;

/// Create an OSD_File object for the given path.
OCCTOSDFileRef _Nonnull OCCTFileCreate(const char* _Nonnull path);

/// Create a temporary OSD_File object (path chosen by OCCT).
OCCTOSDFileRef _Nonnull OCCTFileCreateTemporary(void);

/// Release an OSD_File object.
void OCCTFileRelease(OCCTOSDFileRef _Nonnull file);

/// Build (create/truncate) and open the file for reading and writing.
/// @return true on success
bool OCCTFileOpen(OCCTOSDFileRef _Nonnull file);

/// Open an existing file for reading only.
/// @return true on success
bool OCCTFileOpenReadOnly(OCCTOSDFileRef _Nonnull file);

/// Write data to an open file.
/// @param data Pointer to the bytes to write
/// @param length Number of bytes to write
/// @return true on success
bool OCCTFileWrite(OCCTOSDFileRef _Nonnull file, const char* _Nonnull data, int32_t length);

/// Read a line from an open file. Caller must free the returned string.
/// @param bufSize Maximum line buffer size
/// @return Heap-allocated null-terminated string, or NULL on error/EOF
char* _Nullable OCCTFileReadLine(OCCTOSDFileRef _Nonnull file, int32_t bufSize);

/// Read the entire contents of an open file. Caller must free the returned buffer.
/// @param outLength Filled with the number of bytes returned
/// @return Heap-allocated buffer, or NULL on error
char* _Nullable OCCTFileReadAll(OCCTOSDFileRef _Nonnull file, int32_t* _Nonnull outLength);

/// Close the file.
void OCCTFileClose(OCCTOSDFileRef _Nonnull file);

/// Return whether the file is currently open.
bool OCCTFileIsOpen(OCCTOSDFileRef _Nonnull file);

/// Return the size of the file in bytes, or -1 on error.
int64_t OCCTFileSize(OCCTOSDFileRef _Nonnull file);

/// Rewind the file position to the beginning.
void OCCTFileRewind(OCCTOSDFileRef _Nonnull file);

/// Return whether the file position is at the end.
bool OCCTFileIsAtEnd(OCCTOSDFileRef _Nonnull file);

/// Free a string returned by OCCTFileReadLine or OCCTFileReadAll.
void OCCTFileFreeString(char* _Nullable str);

// MARK: - ShapeFix_Wireframe Extensions (v0.99.0)

/// Fix only wire gaps in a shape (no small-edge removal).
/// @param shape The shape to fix
/// @param tolerance Precision for gap detection
/// @return Fixed shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeFixWireGaps(OCCTShapeRef _Nonnull shape, double tolerance);

/// Fix only small edges in a shape (no gap repair).
/// @param shape The shape to fix
/// @param tolerance Precision for small-edge detection
/// @param dropSmall If true, drop small edges; if false, merge them
/// @param limitAngle Maximum angle between tangents for merging (radians); use -1 for no limit
/// @return Fixed shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeFixSmallEdges(OCCTShapeRef _Nonnull shape, double tolerance,
                                               bool dropSmall, double limitAngle);

// MARK: - v0.100.0: RWStl, ShapeAnalysis_Curve statics, BRepExtrema_SelfIntersection pairs,
//                    Geom_OffsetCurve basis, APIHeaderSection_MakeHeader, ShapeAnalysis_FreeBounds simplified

// --- RWStl direct binary/ASCII STL I/O ---

/// Write a shape's triangulation to binary STL file. Shape is meshed automatically.
/// @param shape The shape to write
/// @param filePath Output file path
/// @param deflection Linear mesh deflection (mm) for the auto-triangulation
/// @return true on success
bool OCCTShapeWriteSTLBinary(OCCTShapeRef _Nonnull shape, const char* _Nonnull filePath, double deflection);

/// Write a shape's triangulation to ASCII STL file. Shape is meshed automatically.
/// @param shape The shape to write
/// @param filePath Output file path
/// @param deflection Linear mesh deflection (mm) for the auto-triangulation
/// @return true on success
bool OCCTShapeWriteSTLAscii(OCCTShapeRef _Nonnull shape, const char* _Nonnull filePath, double deflection);

/// Read an STL file and return as a triangulated shape (face with triangulation).
/// @param filePath Input STL file path
/// @return Shape with triangulation, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeReadSTL(const char* _Nonnull filePath);

// --- ShapeAnalysis_Curve static methods ---

/// Check if a 3D curve is closed within the given precision.
/// Uses ShapeAnalysis_Curve::IsClosed (static).
bool OCCTCurve3DIsClosedWithPreci(OCCTCurve3DRef _Nonnull curve, double preci);

/// Check if a 3D curve is periodic.
/// Uses ShapeAnalysis_Curve::IsPeriodic (static).
bool OCCTCurve3DIsPeriodicSA(OCCTCurve3DRef _Nonnull curve);

// --- BRepExtrema_SelfIntersection face pair reporting ---

/// Detect self-intersections and report overlapping face index pairs.
/// @param shape The shape to check (will be meshed automatically)
/// @param tolerance Overlap tolerance
/// @param outFaceIdx1 Output array of first face indices for each overlapping pair
/// @param outFaceIdx2 Output array of second face indices for each overlapping pair
/// @param maxPairs Maximum number of pairs to return
/// @return Number of overlapping pairs found, or -1 on error
int32_t OCCTShapeSelfIntersectionPairs(OCCTShapeRef _Nonnull shape, double tolerance,
                                        int32_t* _Nonnull outFaceIdx1,
                                        int32_t* _Nonnull outFaceIdx2,
                                        int32_t maxPairs, double deflection);

// --- Geom_OffsetCurve basis curve ---

/// Get the basis curve of an offset curve.
/// @return Basis curve, or NULL if not an offset curve
OCCTCurve3DRef _Nullable OCCTCurve3DOffsetBasis(OCCTCurve3DRef _Nonnull curve);

// --- APIHeaderSection_MakeHeader ---

/// Opaque type for STEP file header
typedef struct OCCTStepHeader* OCCTStepHeaderRef;

/// Create a STEP header from scratch with the given filename.
OCCTStepHeaderRef _Nullable OCCTStepHeaderCreate(const char* _Nonnull filename);

/// Release a STEP header.
void OCCTStepHeaderRelease(OCCTStepHeaderRef _Nullable header);

/// Check if the header is fully defined.
bool OCCTStepHeaderIsDone(OCCTStepHeaderRef _Nonnull header);

/// Get the file name from the header. Caller must free() the returned string.
char* _Nullable OCCTStepHeaderGetName(OCCTStepHeaderRef _Nonnull header);

/// Set the file name in the header.
void OCCTStepHeaderSetName(OCCTStepHeaderRef _Nonnull header, const char* _Nonnull name);

/// Get the timestamp. Caller must free() the returned string.
char* _Nullable OCCTStepHeaderGetTimeStamp(OCCTStepHeaderRef _Nonnull header);

/// Set the timestamp.
void OCCTStepHeaderSetTimeStamp(OCCTStepHeaderRef _Nonnull header, const char* _Nonnull timestamp);

/// Get the first author value. Caller must free() the returned string.
char* _Nullable OCCTStepHeaderGetAuthor(OCCTStepHeaderRef _Nonnull header);

/// Set the first author value.
void OCCTStepHeaderSetAuthor(OCCTStepHeaderRef _Nonnull header, const char* _Nonnull author);

/// Get the first organization value. Caller must free() the returned string.
char* _Nullable OCCTStepHeaderGetOrganization(OCCTStepHeaderRef _Nonnull header);

/// Set the first organization value.
void OCCTStepHeaderSetOrganization(OCCTStepHeaderRef _Nonnull header, const char* _Nonnull org);

/// Get the preprocessor version. Caller must free() the returned string.
char* _Nullable OCCTStepHeaderGetPreprocessorVersion(OCCTStepHeaderRef _Nonnull header);

/// Set the preprocessor version.
void OCCTStepHeaderSetPreprocessorVersion(OCCTStepHeaderRef _Nonnull header, const char* _Nonnull ppv);

/// Get the originating system. Caller must free() the returned string.
char* _Nullable OCCTStepHeaderGetOriginatingSystem(OCCTStepHeaderRef _Nonnull header);

/// Set the originating system.
void OCCTStepHeaderSetOriginatingSystem(OCCTStepHeaderRef _Nonnull header, const char* _Nonnull os);

// --- ShapeAnalysis_FreeBounds simplified API ---

/// Get the number of closed free-boundary wires in a shape.
int32_t OCCTShapeFreeBoundsClosedCount(OCCTShapeRef _Nonnull shape, double tolerance);

/// Get the compound of closed free-boundary wires.
OCCTShapeRef _Nullable OCCTShapeFreeBoundsClosed(OCCTShapeRef _Nonnull shape, double tolerance);

/// Get the compound of open free-boundary wires.
OCCTShapeRef _Nullable OCCTShapeFreeBoundsOpen(OCCTShapeRef _Nonnull shape, double tolerance);

// MARK: - v0.101.0: Geom_TrimmedCurve, BRepLib_FindSurface, ShapeAnalysis_Surface,
//                    Resource_Manager

// --- Geom_TrimmedCurve ---

/// Create a trimmed curve from basis curve between u1 and u2.
OCCTCurve3DRef _Nullable OCCTCurve3DTrimmed(OCCTCurve3DRef _Nonnull basisCurve, double u1, double u2);

/// Get start point of a trimmed (bounded) curve.
void OCCTCurve3DStartPoint(OCCTCurve3DRef _Nonnull curve, double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Get end point of a trimmed (bounded) curve.
void OCCTCurve3DEndPoint(OCCTCurve3DRef _Nonnull curve, double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Get basis curve of a trimmed curve (returns null if not a trimmed curve).
OCCTCurve3DRef _Nullable OCCTCurve3DTrimmedBasis(OCCTCurve3DRef _Nonnull curve);

/// Change trim parameters on a trimmed curve.
bool OCCTCurve3DSetTrim(OCCTCurve3DRef _Nonnull curve, double u1, double u2);

// --- BRepLib_FindSurface ---

/// Find a surface (typically plane) through the edges of a shape.
/// @param onlyPlane If true, only planes are considered
/// @return Found surface, or NULL if not found
OCCTSurfaceRef _Nullable OCCTFindSurface(OCCTShapeRef _Nonnull shape, double tolerance, bool onlyPlane);

/// Find surface and return the tolerance reached.
double OCCTFindSurfaceTolerance(OCCTShapeRef _Nonnull shape, double tolerance, bool onlyPlane);

/// Check if the surface already existed on the shape.
bool OCCTFindSurfaceExisted(OCCTShapeRef _Nonnull shape, double tolerance, bool onlyPlane);

// --- ShapeAnalysis_Surface ---

/// Project a 3D point onto a surface, returning UV parameters and gap distance.
double OCCTSurfaceProjectPointUV(OCCTSurfaceRef _Nonnull surface,
                                   double px, double py, double pz, double preci,
                                   double* _Nonnull u, double* _Nonnull v);

/// Check if a surface has singularities at the given precision.
bool OCCTSurfaceHasSingularities(OCCTSurfaceRef _Nonnull surface, double preci);

/// Get number of singularities on a surface.
int32_t OCCTSurfaceNbSingularities(OCCTSurfaceRef _Nonnull surface, double preci);

/// Check if surface is spatially U-closed at given precision.
bool OCCTSurfaceIsUClosedSA(OCCTSurfaceRef _Nonnull surface, double preci);

/// Check if surface is spatially V-closed at given precision.
bool OCCTSurfaceIsVClosedSA(OCCTSurfaceRef _Nonnull surface, double preci);

// --- Resource_Manager ---

typedef struct OCCTResourceManager* OCCTResourceManagerRef;

/// Create an empty resource manager.
OCCTResourceManagerRef _Nonnull OCCTResourceManagerCreate(void);

/// Release a resource manager.
void OCCTResourceManagerRelease(OCCTResourceManagerRef _Nonnull mgr);

/// Set a string resource.
void OCCTResourceManagerSetString(OCCTResourceManagerRef _Nonnull mgr, const char* _Nonnull key, const char* _Nonnull value);

/// Set an integer resource.
void OCCTResourceManagerSetInt(OCCTResourceManagerRef _Nonnull mgr, const char* _Nonnull key, int32_t value);

/// Set a real resource.
void OCCTResourceManagerSetReal(OCCTResourceManagerRef _Nonnull mgr, const char* _Nonnull key, double value);

/// Check if a resource key exists.
bool OCCTResourceManagerFind(OCCTResourceManagerRef _Nonnull mgr, const char* _Nonnull key);

/// Get a string resource value. Caller must free() the returned string.
char* _Nullable OCCTResourceManagerGetString(OCCTResourceManagerRef _Nonnull mgr, const char* _Nonnull key);

/// Get an integer resource value.
int32_t OCCTResourceManagerGetInt(OCCTResourceManagerRef _Nonnull mgr, const char* _Nonnull key);

/// Get a real resource value.
double OCCTResourceManagerGetReal(OCCTResourceManagerRef _Nonnull mgr, const char* _Nonnull key);

// MARK: - TopExp Adjacency (v0.102.0)

/// Get the first (FORWARD) vertex of an edge. Returns vertex coordinates. Returns false if no vertex.
bool OCCTEdgeFirstVertex(OCCTShapeRef _Nonnull edge, double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Get the last (REVERSED) vertex of an edge. Returns vertex coordinates. Returns false if no vertex.
bool OCCTEdgeLastVertex(OCCTShapeRef _Nonnull edge, double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Get both vertices of an edge. Returns false if null vertices.
bool OCCTEdgeVertices(OCCTShapeRef _Nonnull edge,
                      double* _Nonnull x1, double* _Nonnull y1, double* _Nonnull z1,
                      double* _Nonnull x2, double* _Nonnull y2, double* _Nonnull z2);

/// Get first and last vertices of a wire. For closed wires, both are the same vertex. Returns false if null.
bool OCCTWireVertices(OCCTShapeRef _Nonnull wire,
                      double* _Nonnull x1, double* _Nonnull y1, double* _Nonnull z1,
                      double* _Nonnull x2, double* _Nonnull y2, double* _Nonnull z2);

/// Find common vertex between two edges. Returns false if no shared vertex.
bool OCCTEdgeCommonVertex(OCCTShapeRef _Nonnull edge1, OCCTShapeRef _Nonnull edge2,
                          double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Build edge→face adjacency map. Returns number of edges, and for each edge the count of adjacent faces.
/// adjacentFaceCounts must be pre-allocated with edgeCount entries (call with NULL first to get count).
int32_t OCCTEdgeFaceAdjacency(OCCTShapeRef _Nonnull shape, int32_t* _Nullable adjacentFaceCounts);

/// Build vertex→edge adjacency map. Returns number of vertices, and for each vertex the count of adjacent edges.
int32_t OCCTVertexEdgeAdjacency(OCCTShapeRef _Nonnull shape, int32_t* _Nullable adjacentEdgeCounts);

/// Get adjacent faces for a specific edge within a shape. Returns count of faces found.
/// faceIndices is an output array of face indices (1-based, into indexed map). Caller allocates (max 64).
int32_t OCCTEdgeAdjacentFaces(OCCTShapeRef _Nonnull shape, OCCTShapeRef _Nonnull edge,
                              int32_t* _Nonnull faceIndices, int32_t maxFaces);

/// Get adjacent edges for a specific vertex within a shape. Returns count of edges found.
int32_t OCCTVertexAdjacentEdges(OCCTShapeRef _Nonnull shape, OCCTShapeRef _Nonnull vertex,
                                int32_t* _Nonnull edgeIndices, int32_t maxEdges);

// MARK: - Poly_Connect Mesh Adjacency (v0.102.0)

/// Get adjacent triangles for a triangle in a mesh. adj1/adj2/adj3 are 0 if no neighbor.
/// Returns false if invalid triangle index or no triangulation on shape.
bool OCCTMeshTriangleAdjacency(OCCTShapeRef _Nonnull shape, int32_t faceIndex, int32_t triangleIndex,
                                int32_t* _Nonnull adj1, int32_t* _Nonnull adj2, int32_t* _Nonnull adj3);

/// Get a triangle index containing the given node. Returns 0 if invalid.
int32_t OCCTMeshNodeTriangle(OCCTShapeRef _Nonnull shape, int32_t faceIndex, int32_t nodeIndex);

/// Count triangles sharing a given node (fan count). Returns 0 if invalid.
int32_t OCCTMeshNodeTriangleCount(OCCTShapeRef _Nonnull shape, int32_t faceIndex, int32_t nodeIndex);

// MARK: - BRepOffset_Analyse Edge Classification (v0.102.0)

/// Analyze edge concavity for all edges in a shape. Returns number of edges analyzed.
/// edgeTypes must be pre-allocated with returned count entries (call with NULL first to get count).
/// Uses existing OCCTConcavityType: 0=Convex, 1=Concave, 2=Tangent.
int32_t OCCTAnalyseEdgeConcavity(OCCTShapeRef _Nonnull shape, double angle,
                                  int32_t* _Nullable edgeTypes);

/// Get faces grouped by edge concavity type. Returns compound of connected face groups.
/// concavityType: 0=Convex, 1=Concave, 2=Tangent (matches OCCTConcavityType)
OCCTShapeRef _Nullable OCCTAnalyseExplode(OCCTShapeRef _Nonnull shape, double angle,
                                           int32_t concavityType);

/// Count edges of a given concavity type on a specific face. 0=Convex, 1=Concave, 2=Tangent
int32_t OCCTAnalyseEdgesOnFace(OCCTShapeRef _Nonnull shape, double angle,
                                OCCTShapeRef _Nonnull face, int32_t concavityType);

/// Get ancestor faces for an edge in the offset analysis.
int32_t OCCTAnalyseAncestorCount(OCCTShapeRef _Nonnull shape, double angle, OCCTShapeRef _Nonnull edge);

/// Count tangent edges at a vertex along a given edge.
int32_t OCCTAnalyseTangentEdgeCount(OCCTShapeRef _Nonnull shape, double angle,
                                     OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull vertex);

// MARK: - BRepTools_WireExplorer Extensions (v0.102.0)

/// Explore wire edges with face context. Returns edge orientations (0=FORWARD, 1=REVERSED, 2=INTERNAL, 3=EXTERNAL).
/// orientations must be pre-allocated. Returns edge count.
int32_t OCCTWireExplorerOrientations(OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nullable face,
                                      int32_t* _Nullable orientations);

/// Get connecting vertices from wire explorer (vertex between consecutive edges).
/// xs/ys/zs must be pre-allocated with edge count entries. Returns vertex count.
int32_t OCCTWireExplorerVertices(OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nullable face,
                                  double* _Nullable xs, double* _Nullable ys, double* _Nullable zs);

// MARK: - BndLib Analytic Bounding (v0.104.0)

/// Bounding box of a line segment. Returns xmin,ymin,zmin,xmax,ymax,zmax.
void OCCTBndLibLine(double px, double py, double pz, double dx, double dy, double dz,
                     double p1, double p2, double tol,
                     double* _Nonnull xmin, double* _Nonnull ymin, double* _Nonnull zmin,
                     double* _Nonnull xmax, double* _Nonnull ymax, double* _Nonnull zmax);

/// Bounding box of a full circle.
void OCCTBndLibCircle(double cx, double cy, double cz, double nx, double ny, double nz,
                       double radius, double tol,
                       double* _Nonnull xmin, double* _Nonnull ymin, double* _Nonnull zmin,
                       double* _Nonnull xmax, double* _Nonnull ymax, double* _Nonnull zmax);

/// Bounding box of a full sphere.
void OCCTBndLibSphere(double cx, double cy, double cz, double radius, double tol,
                       double* _Nonnull xmin, double* _Nonnull ymin, double* _Nonnull zmin,
                       double* _Nonnull xmax, double* _Nonnull ymax, double* _Nonnull zmax);

/// Bounding box of a cylinder patch (V range).
void OCCTBndLibCylinder(double cx, double cy, double cz, double nx, double ny, double nz,
                          double radius, double vmin, double vmax, double tol,
                          double* _Nonnull xmin, double* _Nonnull ymin, double* _Nonnull zmin,
                          double* _Nonnull xmax, double* _Nonnull ymax, double* _Nonnull zmax);

/// Bounding box of a full torus.
void OCCTBndLibTorus(double cx, double cy, double cz, double nx, double ny, double nz,
                      double majorRadius, double minorRadius, double tol,
                      double* _Nonnull xmin, double* _Nonnull ymin, double* _Nonnull zmin,
                      double* _Nonnull xmax, double* _Nonnull ymax, double* _Nonnull zmax);

/// Bounding box of a 3D edge curve (BndLib_Add3dCurve).
void OCCTBndLibEdge(OCCTShapeRef _Nonnull edge, double tol,
                     double* _Nonnull xmin, double* _Nonnull ymin, double* _Nonnull zmin,
                     double* _Nonnull xmax, double* _Nonnull ymax, double* _Nonnull zmax);

/// Bounding box of a face surface (BndLib_AddSurface).
void OCCTBndLibFace(OCCTShapeRef _Nonnull face, double tol,
                     double* _Nonnull xmin, double* _Nonnull ymin, double* _Nonnull zmin,
                     double* _Nonnull xmax, double* _Nonnull ymax, double* _Nonnull zmax);

// MARK: - OSD_Host (v0.104.0)

/// Get the hostname. Caller must free() the returned string.
char* _Nullable OCCTHostName(void);

/// Get the OS version string. Caller must free().
char* _Nullable OCCTSystemVersion(void);

/// Get the internet address. Caller must free().
char* _Nullable OCCTInternetAddress(void);

// MARK: - OSD_PerfMeter (v0.104.0)

typedef struct OCCTPerfMeter* OCCTPerfMeterRef;
OCCTPerfMeterRef _Nonnull OCCTPerfMeterCreate(const char* _Nonnull name);
void OCCTPerfMeterRelease(OCCTPerfMeterRef _Nonnull meter);
void OCCTPerfMeterStart(OCCTPerfMeterRef _Nonnull meter);
void OCCTPerfMeterStop(OCCTPerfMeterRef _Nonnull meter);
double OCCTPerfMeterElapsed(OCCTPerfMeterRef _Nonnull meter);

// MARK: - GProp Cylinder/Cone (v0.104.0)

/// Cylinder lateral surface area.
double OCCTGPropCylinderSurface(double radius, double height);

/// Cylinder volume.
double OCCTGPropCylinderVolume(double radius, double height);

/// Cone lateral surface area (from V=0 to V=height).
double OCCTGPropConeSurface(double semiAngle, double refRadius, double height);

/// Cone volume (from V=0 to V=height).
double OCCTGPropConeVolume(double semiAngle, double refRadius, double height);

// MARK: - IntAna_IntQuadQuad (v0.104.0)

/// Cylinder-sphere intersection. Returns number of curves found.
int32_t OCCTIntAnaCylinderSphere(double cylRadius,
                                   double sphCx, double sphCy, double sphCz, double sphRadius,
                                   double tol);

/// Check if cylinder-sphere intersection produced identical elements.
bool OCCTIntAnaCylinderSphereIdentical(double cylRadius,
                                         double sphCx, double sphCy, double sphCz, double sphRadius,
                                         double tol);

// MARK: - XCAFPrs_DocumentExplorer (v0.104.0)

/// Count leaf shape nodes in a document.
int32_t OCCTDocumentExplorerCount(OCCTDocumentRef _Nonnull doc);

/// Get shape at index from document explorer (0-based). Returns shape ref.
OCCTShapeRef _Nullable OCCTDocumentExplorerShape(OCCTDocumentRef _Nonnull doc, int32_t index);

/// Get path ID at index from document explorer. Caller must free().
char* _Nullable OCCTDocumentExplorerPathId(OCCTDocumentRef _Nonnull doc, int32_t index);

/// Find shape from path ID string.
OCCTShapeRef _Nullable OCCTDocumentExplorerFindShape(OCCTDocumentRef _Nonnull doc, const char* _Nonnull pathId);

// MARK: - gce Transform Factories 3D (v0.103.0)

/// Create a 3D point mirror transformation. Stores result in 12-element matrix (row-major 3x4).
void OCCTMakeMirrorPoint(double px, double py, double pz, double* _Nonnull matrix);

/// Create a 3D axis mirror transformation.
void OCCTMakeMirrorAxis(double px, double py, double pz, double dx, double dy, double dz, double* _Nonnull matrix);

/// Create a 3D plane mirror transformation.
void OCCTMakeMirrorPlane(double px, double py, double pz, double nx, double ny, double nz, double* _Nonnull matrix);

/// Create a 3D rotation transformation.
void OCCTMakeRotation(double px, double py, double pz, double dx, double dy, double dz, double angle, double* _Nonnull matrix);

/// Create a 3D scale transformation.
void OCCTMakeScaleTransform(double px, double py, double pz, double factor, double* _Nonnull matrix);

/// Create a 3D translation transformation from vector.
void OCCTMakeTranslationVec(double vx, double vy, double vz, double* _Nonnull matrix);

/// Create a 3D translation transformation from two points.
void OCCTMakeTranslationPoints(double x1, double y1, double z1, double x2, double y2, double z2, double* _Nonnull matrix);

// MARK: - gce Transform Factories 2D (v0.103.0)

/// Create a 2D point mirror transformation. Stores result in 6-element matrix (row-major 2x3).
void OCCTMakeMirror2dPoint(double px, double py, double* _Nonnull matrix);

/// Create a 2D axis mirror transformation.
void OCCTMakeMirror2dAxis(double px, double py, double dx, double dy, double* _Nonnull matrix);

/// Create a 2D rotation transformation.
void OCCTMakeRotation2d(double px, double py, double angle, double* _Nonnull matrix);

/// Create a 2D scale transformation.
void OCCTMakeScale2d(double px, double py, double factor, double* _Nonnull matrix);

/// Create a 2D translation from vector.
void OCCTMakeTranslation2dVec(double vx, double vy, double* _Nonnull matrix);

/// Create a 2D translation from two points.
void OCCTMakeTranslation2dPoints(double x1, double y1, double x2, double y2, double* _Nonnull matrix);

/// Create a 2D direction from coordinates. Returns false if zero vector.
bool OCCTMakeDir2d(double x, double y, double* _Nonnull outX, double* _Nonnull outY);

/// Create a 2D direction from two points. Returns false if coincident.
bool OCCTMakeDir2dFromPoints(double x1, double y1, double x2, double y2, double* _Nonnull outX, double* _Nonnull outY);

// MARK: - GProp Element Properties (v0.103.0)

/// Compute curve element (line segment) properties. Returns mass (length), center of mass.
double OCCTGPropLineSegment(double x1, double y1, double z1, double x2, double y2, double z2,
                             double* _Nonnull cx, double* _Nonnull cy, double* _Nonnull cz);

/// Compute curve element (circular arc) properties. Returns mass (arc length), center of mass.
double OCCTGPropCircularArc(double centerX, double centerY, double centerZ,
                             double normalX, double normalY, double normalZ,
                             double radius, double u1, double u2,
                             double* _Nonnull cx, double* _Nonnull cy, double* _Nonnull cz);

/// Compute point set center of mass. points is array of [x,y,z,...]. Returns mass (count).
double OCCTGPropPointSetCentroid(const double* _Nonnull points, int32_t count,
                                  double* _Nonnull cx, double* _Nonnull cy, double* _Nonnull cz);

/// Compute sphere surface area and center of mass.
double OCCTGPropSphereSurface(double radius, double* _Nonnull cx, double* _Nonnull cy, double* _Nonnull cz);

/// Compute sphere volume and center of mass.
double OCCTGPropSphereVolume(double radius, double* _Nonnull cx, double* _Nonnull cy, double* _Nonnull cz);

// MARK: - Plate Constraint Extensions (v0.103.0)

/// Create plate plane constraint and load into solver. Returns true if loaded.
bool OCCTPlateLoadPlaneConstraint(OCCTPlateRef _Nonnull plate, double u, double v,
                                   double px, double py, double pz,
                                   double nx, double ny, double nz);

/// Create plate line constraint and load into solver. Returns true if loaded.
bool OCCTPlateLoadLineConstraint(OCCTPlateRef _Nonnull plate, double u, double v,
                                  double px, double py, double pz,
                                  double dx, double dy, double dz);

/// Create plate free G1 constraint. Returns true if loaded.
bool OCCTPlateLoadFreeG1Constraint(OCCTPlateRef _Nonnull plate, double u, double v,
                                    double duX, double duY, double duZ,
                                    double dvX, double dvY, double dvZ);

// MARK: - Law_Interpolate (v0.103.0)

/// Create an interpolated law function from values. Returns law function ref.
/// values/parameters are arrays of length count. If parameters is NULL, auto-parameterized.
OCCTLawFunctionRef _Nullable OCCTLawInterpolate(const double* _Nonnull values, int32_t count,
                                                 const double* _Nullable parameters, bool periodic);

// MARK: - Bnd_Sphere (v0.103.0)

/// Create a bounding sphere. Returns opaque ref.
typedef struct OCCTBndSphere* OCCTBndSphereRef;
OCCTBndSphereRef _Nonnull OCCTBndSphereCreate(double cx, double cy, double cz, double radius);
void OCCTBndSphereRelease(OCCTBndSphereRef _Nonnull sphere);
double OCCTBndSphereRadius(OCCTBndSphereRef _Nonnull sphere);
void OCCTBndSphereCenter(OCCTBndSphereRef _Nonnull sphere, double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);
double OCCTBndSphereDistance(OCCTBndSphereRef _Nonnull sphere, double x, double y, double z);
bool OCCTBndSphereIsOut(OCCTBndSphereRef _Nonnull sphere, double x, double y, double z);
bool OCCTBndSphereIsOutSphere(OCCTBndSphereRef _Nonnull s1, OCCTBndSphereRef _Nonnull s2);
void OCCTBndSphereAdd(OCCTBndSphereRef _Nonnull sphere, OCCTBndSphereRef _Nonnull other);

// MARK: - GC_MakeCircle (v0.105.0)

/// Create a 3D circle from axis (center+normal) and radius.
OCCTCurve3DRef _Nullable OCCTGCMakeCircle(double cx, double cy, double cz,
                                            double nx, double ny, double nz,
                                            double radius);

/// Create a 3D circle through 3 points.
OCCTCurve3DRef _Nullable OCCTGCMakeCircle3Points(double x1, double y1, double z1,
                                                   double x2, double y2, double z2,
                                                   double x3, double y3, double z3);

/// Create a 3D circle from center, normal direction, and radius.
OCCTCurve3DRef _Nullable OCCTGCMakeCircleCenterNormal(double cx, double cy, double cz,
                                                        double nx, double ny, double nz,
                                                        double radius);

/// Create a 3D circle parallel to an existing circle at given distance.
OCCTCurve3DRef _Nullable OCCTGCMakeCircleParallel(double cx, double cy, double cz,
                                                    double nx, double ny, double nz,
                                                    double radius, double dist);

// MARK: - GC_MakeEllipse (v0.105.0)

/// Create a 3D ellipse from axis and major/minor radii.
OCCTCurve3DRef _Nullable OCCTGCMakeEllipse(double cx, double cy, double cz,
                                             double nx, double ny, double nz,
                                             double major, double minor);

/// Create a 3D ellipse from 3 points (S1, S2, center).
OCCTCurve3DRef _Nullable OCCTGCMakeEllipse3Points(double x1, double y1, double z1,
                                                    double x2, double y2, double z2,
                                                    double x3, double y3, double z3);

/// Create a 3D ellipse from full Ax2 (center+normal+xdir) and radii.
OCCTCurve3DRef _Nullable OCCTGCMakeEllipseFromElips(double cx, double cy, double cz,
                                                      double nx, double ny, double nz,
                                                      double xdx, double xdy, double xdz,
                                                      double major, double minor);

// MARK: - GC_MakeHyperbola (v0.105.0)

/// Create a 3D hyperbola from axis and major/minor radii.
OCCTCurve3DRef _Nullable OCCTGCMakeHyperbola(double cx, double cy, double cz,
                                               double nx, double ny, double nz,
                                               double major, double minor);

/// Create a 3D hyperbola from 3 points (S1, S2, center).
OCCTCurve3DRef _Nullable OCCTGCMakeHyperbola3Points(double x1, double y1, double z1,
                                                      double x2, double y2, double z2,
                                                      double x3, double y3, double z3);

// MARK: - GC_MakeCircle2d (v0.105.0)

/// Create a 2D circle from center and radius.
OCCTCurve2DRef _Nullable OCTGCE2dMakeCircleCenterRadius(double cx, double cy, double radius);

/// Create a 2D circle through 3 points.
OCCTCurve2DRef _Nullable OCTGCE2dMakeCircle3Points(double x1, double y1,
                                                     double x2, double y2,
                                                     double x3, double y3);

/// Create a 2D circle from center and point on circle.
OCCTCurve2DRef _Nullable OCTGCE2dMakeCircleCenterPoint(double cx, double cy, double px, double py);

/// Create a 2D circle parallel to existing circle at distance.
OCCTCurve2DRef _Nullable OCTGCE2dMakeCircleParallel(double cx, double cy,
                                                      double dx, double dy,
                                                      double radius, double dist);

/// Create a 2D circle from axis and radius.
OCCTCurve2DRef _Nullable OCTGCE2dMakeCircleAxis(double cx, double cy,
                                                  double dx, double dy,
                                                  double radius);

// MARK: - GC_MakeEllipse2d (v0.105.0)

/// Create a 2D ellipse from axis and radii.
OCCTCurve2DRef _Nullable OCTGCE2dMakeEllipse(double cx, double cy,
                                               double dx, double dy,
                                               double major, double minor);

/// Create a 2D ellipse from 3 points (S1, S2, center).
OCCTCurve2DRef _Nullable OCTGCE2dMakeEllipse3Points(double x1, double y1,
                                                      double x2, double y2,
                                                      double x3, double y3);

/// Create a 2D ellipse from full Ax22d and radii.
OCCTCurve2DRef _Nullable OCTGCE2dMakeEllipseAxis22d(double cx, double cy,
                                                      double xdx, double xdy,
                                                      double ydx, double ydy,
                                                      double major, double minor);

// MARK: - GC_MakeHyperbola2d (v0.105.0)

/// Create a 2D hyperbola from axis and radii.
OCCTCurve2DRef _Nullable OCTGCE2dMakeHyperbola(double cx, double cy,
                                                 double dx, double dy,
                                                 double major, double minor);

/// Create a 2D hyperbola from 3 points (S1, S2, center).
OCCTCurve2DRef _Nullable OCTGCE2dMakeHyperbola3Points(double x1, double y1,
                                                        double x2, double y2,
                                                        double x3, double y3);

// MARK: - GC_MakeParabola2d (v0.105.0)

/// Create a 2D parabola from axis and focal distance.
OCCTCurve2DRef _Nullable OCTGCE2dMakeParabola(double cx, double cy,
                                                double dx, double dy,
                                                double focal);

/// Create a 2D parabola from directrix and focus.
OCCTCurve2DRef _Nullable OCTGCE2dMakeParabolaDirectrixFocus(double dx, double dy,
                                                              double ddx, double ddy,
                                                              double fx, double fy);

// MARK: - GCPnts_UniformAbscissa (v0.105.0)

/// Uniform abscissa sampling by point count. Call with params=NULL to get count, then with allocated array.
int32_t OCCTUniformAbscissaByCount(OCCTShapeRef _Nonnull edge, int32_t nbPoints,
                                    double* _Nullable params);

/// Uniform abscissa sampling by arc distance. Call with params=NULL to get count, then with allocated array.
int32_t OCCTUniformAbscissaByDistance(OCCTShapeRef _Nonnull edge, double abscissa,
                                      double* _Nullable params);

/// Uniform abscissa by count within parameter range.
int32_t OCCTUniformAbscissaByCountRange(OCCTShapeRef _Nonnull edge, int32_t nbPoints,
                                         double u1, double u2,
                                         double* _Nullable params);

/// Uniform abscissa by distance within parameter range.
int32_t OCCTUniformAbscissaByDistanceRange(OCCTShapeRef _Nonnull edge, double abscissa,
                                            double u1, double u2,
                                            double* _Nullable params);

// MARK: - GeomConvert_CompCurveToBSplineCurve (v0.105.0)

/// Concatenate an array of bounded 3D curves into a single BSpline curve.
OCCTCurve3DRef _Nullable OCCTConcatenateCurves3D(OCCTCurve3DRef _Nonnull * _Nonnull curves,
                                                   int32_t count, double tolerance);

// MARK: - Geom2dConvert_CompCurveToBSplineCurve (v0.105.0)

/// Concatenate an array of bounded 2D curves into a single BSpline curve.
OCCTCurve2DRef _Nullable OCCTConcatenateCurves2D(OCCTCurve2DRef _Nonnull * _Nonnull curves,
                                                   int32_t count, double tolerance);

// MARK: - GeomConvert_BSplineSurfaceKnotSplitting (v0.105.0)

/// Get number of U-direction knot splits for a BSpline surface at given continuity.
int32_t OCCTBSplineSurfaceKnotSplitsU(OCCTSurfaceRef _Nonnull surface, int32_t continuity);

/// Get number of V-direction knot splits for a BSpline surface at given continuity.
int32_t OCCTBSplineSurfaceKnotSplitsV(OCCTSurfaceRef _Nonnull surface, int32_t continuity);

/// Get U and V knot split indices for a BSpline surface at given continuity.
void OCCTBSplineSurfaceKnotSplitValues(OCCTSurfaceRef _Nonnull surface, int32_t continuity,
                                        int32_t* _Nonnull uSplits, int32_t* _Nonnull vSplits);

// MARK: - Geom2dConvert_BSplineCurveKnotSplitting (v0.105.0)

/// Get number of knot splits for a 2D BSpline curve at given continuity.
int32_t OCCTBSplineCurve2dKnotSplits(OCCTCurve2DRef _Nonnull curve, int32_t continuity);

/// Get knot split indices for a 2D BSpline curve at given continuity.
void OCCTBSplineCurve2dKnotSplitValues(OCCTCurve2DRef _Nonnull curve, int32_t continuity,
                                        int32_t* _Nonnull splits);

// MARK: - BndLib extras (v0.105.0)

/// Compute bounding box of an ellipse. bounds6 = [xmin,ymin,zmin,xmax,ymax,zmax].
void OCCTBndLibEllipse(double cx, double cy, double cz,
                        double nx, double ny, double nz,
                        double xdx, double xdy, double xdz,
                        double major, double minor, double tol,
                        double* _Nonnull bounds6);

/// Compute bounding box of a cone segment.
void OCCTBndLibCone(double cx, double cy, double cz,
                     double nx, double ny, double nz,
                     double semiAngle, double refRadius,
                     double vmin, double vmax, double tol,
                     double* _Nonnull bounds6);

/// Compute bounding box of a circular arc.
void OCCTBndLibCircleArc(double cx, double cy, double cz,
                          double nx, double ny, double nz,
                          double radius, double u1, double u2, double tol,
                          double* _Nonnull bounds6);

/// Compute bounding box of an ellipse arc.
void OCCTBndLibEllipseArc(double cx, double cy, double cz,
                           double nx, double ny, double nz,
                           double xdx, double xdy, double xdz,
                           double major, double minor,
                           double u1, double u2, double tol,
                           double* _Nonnull bounds6);

/// Compute bounding box of a parabola arc.
void OCCTBndLibParabolaArc(double cx, double cy, double cz,
                            double nx, double ny, double nz,
                            double xdx, double xdy, double xdz,
                            double focal, double u1, double u2, double tol,
                            double* _Nonnull bounds6);

/// Compute bounding box of a hyperbola arc.
void OCCTBndLibHyperbolaArc(double cx, double cy, double cz,
                             double nx, double ny, double nz,
                             double xdx, double xdy, double xdz,
                             double major, double minor,
                             double u1, double u2, double tol,
                             double* _Nonnull bounds6);

// MARK: - GProp Torus (v0.105.0)

/// Compute torus surface area (full torus).
double OCCTGPropTorusSurface(double majorRadius, double minorRadius);

/// Compute torus volume (full torus).
double OCCTGPropTorusVolume(double majorRadius, double minorRadius);

// MARK: - BRepTools_ReShape (v0.105.0)

typedef struct OCCTReShape* OCCTReShapeRef;

/// Create a new ReShape context.
OCCTReShapeRef _Nonnull OCCTReShapeCreate(void);

/// Release a ReShape context.
void OCCTReShapeRelease(OCCTReShapeRef _Nonnull rs);

/// Clear all recorded modifications.
void OCCTReShapeClear(OCCTReShapeRef _Nonnull rs);

/// Record a shape removal.
void OCCTReShapeRemove(OCCTReShapeRef _Nonnull rs, OCCTShapeRef _Nonnull shape);

/// Record a shape replacement.
void OCCTReShapeReplace(OCCTReShapeRef _Nonnull rs, OCCTShapeRef _Nonnull oldShape,
                         OCCTShapeRef _Nonnull newShape);

/// Check if a shape has been recorded for modification.
bool OCCTReShapeIsRecorded(OCCTReShapeRef _Nonnull rs, OCCTShapeRef _Nonnull shape);

/// Apply all recorded modifications to a shape.
OCCTShapeRef _Nullable OCCTReShapeApply(OCCTReShapeRef _Nonnull rs, OCCTShapeRef _Nonnull shape);

/// Get the replacement value for a specific shape.
OCCTShapeRef _Nullable OCCTReShapeValue(OCCTReShapeRef _Nonnull rs, OCCTShapeRef _Nonnull shape);

// MARK: - BRepTools_Substitution (v0.105.0)

/// Substitute a subshape with a list of new shapes. newSubs can be NULL (count=0) to remove.
OCCTShapeRef _Nullable OCCTShapeSubstitute(OCCTShapeRef _Nonnull shape,
                                            OCCTShapeRef _Nonnull oldSub,
                                            OCCTShapeRef _Nullable * _Nullable newSubs,
                                            int32_t newCount);

/// Check if a shape was copied during substitution build.
bool OCCTSubstitutionIsCopied(OCCTShapeRef _Nonnull shape, OCCTShapeRef _Nonnull subshape);

// MARK: - BRepLib_MakeVertex (v0.105.0)

/// Create a vertex shape at the given point.
OCCTShapeRef _Nullable OCCTMakeVertex(double x, double y, double z);

// MARK: - BRepFill_PipeShell (v0.105.0)

typedef struct OCCTPipeShell* OCCTPipeShellRef;

/// Create a pipe shell from a spine wire.
OCCTPipeShellRef _Nullable OCCTPipeShellCreate(OCCTShapeRef _Nonnull spineWire);

/// Release a pipe shell.
void OCCTPipeShellRelease(OCCTPipeShellRef _Nonnull ps);

/// Set Frenet trihedron mode.
void OCCTPipeShellSetFrenet(OCCTPipeShellRef _Nonnull ps, bool frenet);

/// Set discrete trihedron mode.
void OCCTPipeShellSetDiscrete(OCCTPipeShellRef _Nonnull ps);

/// Set fixed binormal direction.
void OCCTPipeShellSetFixed(OCCTPipeShellRef _Nonnull ps, double bx, double by, double bz);

/// Add a profile (wire or vertex) at the current location.
void OCCTPipeShellAdd(OCCTPipeShellRef _Nonnull ps, OCCTShapeRef _Nonnull profile);

/// Add a profile at a specific vertex on the spine.
void OCCTPipeShellAddAtVertex(OCCTPipeShellRef _Nonnull ps, OCCTShapeRef _Nonnull profile,
                               OCCTShapeRef _Nonnull vertex);

/// Set a profile with a scaling law.
void OCCTPipeShellSetLaw(OCCTPipeShellRef _Nonnull ps, OCCTShapeRef _Nonnull profile,
                          OCCTLawFunctionRef _Nonnull law);

/// Set tolerances.
void OCCTPipeShellSetTolerance(OCCTPipeShellRef _Nonnull ps, double tol3d, double boundTol,
                                double tolAngular);

/// Set transition mode (0=Modified, 1=Right, 2=Round).
void OCCTPipeShellSetTransition(OCCTPipeShellRef _Nonnull ps, int32_t mode);

/// Build the pipe shell. Returns true on success.
bool OCCTPipeShellBuild(OCCTPipeShellRef _Nonnull ps);

/// Get the resulting shape.
OCCTShapeRef _Nullable OCCTPipeShellShape(OCCTPipeShellRef _Nonnull ps);

/// Make the result into a solid. Returns true on success.
bool OCCTPipeShellMakeSolid(OCCTPipeShellRef _Nonnull ps);

/// Get the approximation error.
double OCCTPipeShellError(OCCTPipeShellRef _Nonnull ps);

/// Check if the pipe shell is ready to build.
bool OCCTPipeShellIsReady(OCCTPipeShellRef _Nonnull ps);

// MARK: - OSD_Directory (v0.105.0)

/// Check if a directory exists.
bool OCCTDirectoryExists(const char* _Nonnull path);

/// Create a directory. Returns true on success.
bool OCCTDirectoryCreate(const char* _Nonnull path);

/// Build a temporary directory. Returns path (caller must free).
char* _Nullable OCCTDirectoryBuildTemporary(void);

/// Remove a directory. Returns true on success.
bool OCCTDirectoryRemove(const char* _Nonnull path);

// MARK: - IntAna extensions (v0.105.0)

/// Cone-sphere intersection curve count. Returns -1 on error, -2 if identical.
int32_t OCCTIntAnaConeSphere(double semiAngle, double refRadius,
                              double sphCx, double sphCy, double sphCz, double sphRadius,
                              double tol);

/// Sample points along a cone-sphere intersection curve. Returns actual number of points.
int32_t OCCTIntAnaConeSpherePoints(double semiAngle, double refRadius,
                                    double sphCx, double sphCy, double sphCz, double sphRadius,
                                    double tol, int32_t curveIndex, int32_t nbSamples,
                                    double* _Nonnull xs, double* _Nonnull ys, double* _Nonnull zs);

/// Check if a cone-sphere intersection curve is open.
bool OCCTIntAnaConeSphereIsOpen(double semiAngle, double refRadius,
                                 double sphCx, double sphCy, double sphCz, double sphRadius,
                                 double tol, int32_t curveIndex);

/// Get the domain of a cone-sphere intersection curve.
void OCCTIntAnaConeSphereGetDomain(double semiAngle, double refRadius,
                                    double sphCx, double sphCy, double sphCz, double sphRadius,
                                    double tol, int32_t curveIndex,
                                    double* _Nonnull first, double* _Nonnull last);

// MARK: - XCAFPrs_DocumentExplorer extensions (v0.105.0)

/// Get the depth of a document explorer node at given index.
int32_t OCCTDocumentExplorerDepth(OCCTDocumentRef _Nonnull doc, int32_t index);

/// Check if a document explorer node is an assembly.
bool OCCTDocumentExplorerIsAssembly(OCCTDocumentRef _Nonnull doc, int32_t index);

/// Get the location matrix (12 doubles, row-major 3x4) for a document explorer node.
void OCCTDocumentExplorerLocation(OCCTDocumentRef _Nonnull doc, int32_t index,
                                   double* _Nonnull matrix12);

// MARK: - Resource_Unicode (v0.105.0)

/// Set the Resource_Unicode format. 0=SJIS, 1=EUC, 2=GB, 3=ANSI.
void OCCTUnicodeSetFormat(int32_t format);

/// Get the current Resource_Unicode format.
int32_t OCCTUnicodeGetFormat(void);

/// Convert a string from current format to UTF-8. Returns allocated string (caller must free).
char* _Nullable OCCTUnicodeConvertToUnicode(const char* _Nonnull input);

/// Convert from UTF-8 to current format. Returns true on success.
bool OCCTUnicodeConvertFromUnicode(const char* _Nonnull utf8Input,
                                    char* _Nonnull output, int32_t maxSize);

// MARK: - GProp weighted point sets (v0.105.0)

/// Compute weighted centroid of a point set. Returns total mass (sum of weights).
double OCCTGPropPointSetWeightedCentroid(const double* _Nonnull points,
                                          const double* _Nonnull weights, int32_t count,
                                          double* _Nonnull cx, double* _Nonnull cy, double* _Nonnull cz);

/// Compute barycentre of a point set (equal weights).
void OCCTGPropBarycentre(const double* _Nonnull points, int32_t count,
                          double* _Nonnull cx, double* _Nonnull cy, double* _Nonnull cz);

// MARK: - Draft info types (v0.105.0)

/// Create a Draft_EdgeInfo and query NewGeometry status.
bool OCCTDraftEdgeInfoNewGeometry(void);

/// Create a Draft_FaceInfo and query NewGeometry status.
bool OCCTDraftFaceInfoNewGeometry(void);

/// Create a Draft_VertexInfo and query its geometry point.
void OCCTDraftVertexInfoGeometry(double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Create a Draft_EdgeInfo with tangent direction.
bool OCCTDraftEdgeInfoSetTangent(double dx, double dy, double dz);

/// Create a Draft_FaceInfo from a surface and check RootFace.
bool OCCTDraftFaceInfoFromSurface(OCCTSurfaceRef _Nonnull surface);

/// Create a Draft_VertexInfo, add a parameter, and check ChangeParameter.
double OCCTDraftVertexInfoAddParameter(double param);

// MARK: - GeomLib_LogSample (v0.105.0)

/// Compute logarithmically spaced parameter values. params must be allocated with n elements.
void OCCTLogSample(double a, double b, int32_t n, double* _Nonnull params);

// MARK: - GC_MakeConicalSurface (v0.106.0)

/// Create a conical surface from axis (center+normal), semi-angle, and reference radius.
OCCTSurfaceRef _Nullable OCCTGCMakeConicalSurface(double cx, double cy, double cz,
                                                    double nx, double ny, double nz,
                                                    double semiAngle, double radius);

/// Create a conical surface from 2 points and 2 radii.
OCCTSurfaceRef _Nullable OCCTGCMakeConicalSurface2Pts(double x1, double y1, double z1,
                                                       double x2, double y2, double z2,
                                                       double r1, double r2);

/// Create a conical surface from 4 points (2 on each circle).
OCCTSurfaceRef _Nullable OCCTGCMakeConicalSurface4Pts(double x1, double y1, double z1,
                                                       double x2, double y2, double z2,
                                                       double x3, double y3, double z3,
                                                       double x4, double y4, double z4);

// MARK: - GC_MakeCylindricalSurface (v0.106.0)

/// Create a cylindrical surface from axis (center+normal) and radius.
OCCTSurfaceRef _Nullable OCCTGCMakeCylindricalSurface(double cx, double cy, double cz,
                                                        double nx, double ny, double nz,
                                                        double radius);

/// Create a cylindrical surface from 3 points.
OCCTSurfaceRef _Nullable OCCTGCMakeCylindricalSurface3Pts(double x1, double y1, double z1,
                                                            double x2, double y2, double z2,
                                                            double x3, double y3, double z3);

/// Create a cylindrical surface from a circle (center+normal+radius).
OCCTSurfaceRef _Nullable OCCTGCMakeCylindricalSurfaceFromCircle(double cx, double cy, double cz,
                                                                  double nx, double ny, double nz,
                                                                  double radius);

/// Create a cylindrical surface parallel to another at a given distance.
OCCTSurfaceRef _Nullable OCCTGCMakeCylindricalSurfaceParallel(double cx, double cy, double cz,
                                                                double nx, double ny, double nz,
                                                                double radius, double dist);

/// Create a cylindrical surface from axis (point+direction) and radius.
OCCTSurfaceRef _Nullable OCCTGCMakeCylindricalSurfaceAxis(double px, double py, double pz,
                                                            double dx, double dy, double dz,
                                                            double radius);

// MARK: - GC_MakeTrimmedCone (v0.106.0)

/// Create a trimmed cone from 2 points and 2 radii.
OCCTSurfaceRef _Nullable OCCTGCMakeTrimmedCone2Pts(double x1, double y1, double z1,
                                                     double x2, double y2, double z2,
                                                     double r1, double r2);

/// Create a trimmed cone from 4 points.
OCCTSurfaceRef _Nullable OCCTGCMakeTrimmedCone4Pts(double x1, double y1, double z1,
                                                     double x2, double y2, double z2,
                                                     double x3, double y3, double z3,
                                                     double x4, double y4, double z4);

// MARK: - GC_MakeTrimmedCylinder (v0.106.0)

/// Create a trimmed cylinder from a circle (center+normal+radius) and height.
OCCTSurfaceRef _Nullable OCCTGCMakeTrimmedCylinderCircle(double cx, double cy, double cz,
                                                           double nx, double ny, double nz,
                                                           double radius, double height);

/// Create a trimmed cylinder from axis (point+direction), radius, and height.
OCCTSurfaceRef _Nullable OCCTGCMakeTrimmedCylinderAxis(double px, double py, double pz,
                                                         double dx, double dy, double dz,
                                                         double radius, double height);

/// Create a trimmed cylinder from 3 points.
OCCTSurfaceRef _Nullable OCCTGCMakeTrimmedCylinder3Pts(double x1, double y1, double z1,
                                                         double x2, double y2, double z2,
                                                         double x3, double y3, double z3);

// MARK: - BRepLib_MakeEdge2d extensions (v0.106.0)

/// Create a 2D edge from a full circle.
OCCTShapeRef _Nullable OCCTMakeEdge2dFullCircle(double cx, double cy, double dx, double dy,
                                                  double radius);

/// Create a 2D edge from an ellipse.
OCCTShapeRef _Nullable OCCTMakeEdge2dEllipse(double cx, double cy, double dx, double dy,
                                               double major, double minor);

/// Create a 2D edge from an ellipse arc with parameter range.
OCCTShapeRef _Nullable OCCTMakeEdge2dEllipseArc(double cx, double cy, double dx, double dy,
                                                  double major, double minor, double u1, double u2);

/// Create a 2D edge from a Geom2d_Curve.
OCCTShapeRef _Nullable OCCTMakeEdge2dCurve(OCCTCurve2DRef _Nonnull curve);

/// Create a 2D edge from a Geom2d_Curve with parameter range.
OCCTShapeRef _Nullable OCCTMakeEdge2dCurveRange(OCCTCurve2DRef _Nonnull curve, double u1, double u2);

// MARK: - ShapeAnalysis_Wire (v0.106.0)

/// Check wire edge ordering. Returns true if problem found.
bool OCCTWireCheckOrder(OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nonnull face, double prec);

/// Check wire connectivity. Returns true if problem found.
bool OCCTWireCheckConnected(OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nonnull face, double prec);

/// Check for small edges. Returns true if problem found.
bool OCCTWireCheckSmall(OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nonnull face, double prec);

/// Check for degenerated edges. Returns true if problem found.
bool OCCTWireCheckDegenerated(OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nonnull face, double prec);

/// Check wire closure. Returns true if problem found.
bool OCCTWireCheckClosed(OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nonnull face, double prec);

/// Check for self-intersection. Returns true if problem found.
bool OCCTWireCheckSelfIntersection(OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nonnull face, double prec);

/// Check for 3D gaps. Returns true if problem found.
bool OCCTWireCheckGaps3d(OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nonnull face, double prec);

/// Check for 2D gaps. Returns true if problem found.
bool OCCTWireCheckGaps2d(OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nonnull face, double prec);

/// Check edge curves consistency. Returns true if problem found.
bool OCCTWireCheckEdgeCurves(OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nonnull face, double prec);

/// Check for lacking edges. Returns true if problem found.
bool OCCTWireCheckLacking(OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nonnull face, double prec);

/// Get the number of edges in a wire on a face.
int32_t OCCTWireEdgeCount(OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nonnull face, double prec);

/// Get the minimum 3D distance gap in a wire.
double OCCTWireMinDistance3d(OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nonnull face, double prec);

/// Get the maximum 3D distance gap in a wire.
double OCCTWireMaxDistance3d(OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nonnull face, double prec);

/// Get the minimum 2D distance gap in a wire.
double OCCTWireMinDistance2d(OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nonnull face, double prec);

/// Get the maximum 2D distance gap in a wire.
double OCCTWireMaxDistance2d(OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nonnull face, double prec);

/// Check connectivity of a specific edge by index (1-based).
bool OCCTWireCheckConnectedEdge(OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nonnull face, double prec, int32_t edgeIndex);

/// Check if a specific edge is small (1-based).
bool OCCTWireCheckSmallEdge(OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nonnull face, double prec, int32_t edgeIndex);

/// Check if a specific edge is degenerated (1-based).
bool OCCTWireCheckDegeneratedEdge(OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nonnull face, double prec, int32_t edgeIndex);

/// Check 3D gap at a specific edge (1-based).
bool OCCTWireCheckGap3dEdge(OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nonnull face, double prec, int32_t edgeIndex);

/// Check if a face has an outer bound wire.
bool OCCTWireCheckOuterBound(OCCTShapeRef _Nonnull face, double prec);

// MARK: - ShapeAnalysis_Edge (v0.106.0)

/// Check if an edge has a 3D curve.
bool OCCTEdgeHasCurve3dSA(OCCTShapeRef _Nonnull edge);

/// Check if an edge is closed in 3D.
bool OCCTEdgeIsClosed3dSA(OCCTShapeRef _Nonnull edge);

/// Check if an edge has a PCurve on a face.
bool OCCTEdgeHasPCurveSA(OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull face);

/// Check if an edge is a seam edge on a face.
bool OCCTEdgeIsSeamSA(OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull face);

/// Check same parameter consistency. maxdev returns the maximum deviation.
bool OCCTEdgeCheckSameParameter(OCCTShapeRef _Nonnull edge, double* _Nonnull maxdev);

/// Check vertices with 3D curve positions.
bool OCCTEdgeCheckVerticesWithCurve3d(OCCTShapeRef _Nonnull edge, double prec);

/// Check vertices with PCurve positions on a face.
bool OCCTEdgeCheckVerticesWithPCurve(OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull face, double prec);

/// Check 3D curve vs PCurve consistency on a face.
bool OCCTEdgeCheckCurve3dWithPCurve(OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull face);

/// Get the first vertex position of an edge.
void OCCTEdgeFirstVertexSA(OCCTShapeRef _Nonnull edge, double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Get the last vertex position of an edge.
void OCCTEdgeLastVertexSA(OCCTShapeRef _Nonnull edge, double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Check vertex tolerances on a face edge. Returns true if tolerance is OK.
bool OCCTEdgeCheckVertexTolerance(OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull face,
                                   double* _Nonnull toler1, double* _Nonnull toler2);

/// Check if two edges overlap. Returns true if overlapping.
bool OCCTEdgeCheckOverlapping(OCCTShapeRef _Nonnull edge1, OCCTShapeRef _Nonnull edge2,
                                double* _Nonnull tolOverlap);

/// Get UV bounds of an edge on a face.
bool OCCTEdgeBoundUV(OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull face,
                      double* _Nonnull uFirst, double* _Nonnull vFirst,
                      double* _Nonnull uLast, double* _Nonnull vLast);

/// Get end tangent in 2D for an edge on a face. atEnd=true for last vertex.
bool OCCTEdgeGetEndTangent2d(OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull face,
                              bool atEnd, double* _Nonnull px, double* _Nonnull py,
                              double* _Nonnull tx, double* _Nonnull ty);

/// Check PCurve range on a face.
bool OCCTEdgeCheckPCurveRange(OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull face,
                               double first, double last);

// MARK: - OSD_DirectoryIterator (v0.106.0)

/// Count directories matching a mask in a path.
int32_t OCCTDirectoryIteratorCount(const char* _Nonnull path, const char* _Nonnull mask);

/// Get directory name at index from directory listing. Caller must free returned string.
char* _Nullable OCCTDirectoryIteratorName(const char* _Nonnull path, const char* _Nonnull mask,
                                           int32_t index);

/// List directory names matching mask. Returns count of entries written. names array must be pre-allocated.
int32_t OCCTDirectoryList(const char* _Nonnull path, const char* _Nonnull mask,
                           char* _Nullable * _Nonnull names, int32_t maxCount);

// MARK: - OSD_FileIterator (v0.106.0)

/// Count files matching a mask in a path.
int32_t OCCTFileIteratorCount(const char* _Nonnull path, const char* _Nonnull mask);

/// Get file name at index from file listing. Caller must free returned string.
char* _Nullable OCCTFileIteratorName(const char* _Nonnull path, const char* _Nonnull mask,
                                      int32_t index);

/// List file names matching mask. Returns count of entries written. names array must be pre-allocated.
int32_t OCCTFileList(const char* _Nonnull path, const char* _Nonnull mask,
                      char* _Nullable * _Nonnull names, int32_t maxCount);

// MARK: - BRepFill_PipeShell extensions (v0.106.0)

/// Set maximum degree for pipe shell approximation.
void OCCTPipeShellSetMaxDegree(OCCTPipeShellRef _Nonnull ps, int32_t maxDeg);

/// Set maximum number of segments for pipe shell approximation.
void OCCTPipeShellSetMaxSegments(OCCTPipeShellRef _Nonnull ps, int32_t maxSeg);

/// Force C1 approximation on pipe shell.
void OCCTPipeShellSetForceApproxC1(OCCTPipeShellRef _Nonnull ps, bool force);

/// Get the error on the generated surface.
double OCCTPipeShellErrorOnSurface(OCCTPipeShellRef _Nonnull ps);

/// Get the first shape of the pipe shell (start cap).
OCCTShapeRef _Nullable OCCTPipeShellFirstShape(OCCTPipeShellRef _Nonnull ps);

/// Get the last shape of the pipe shell (end cap).
OCCTShapeRef _Nullable OCCTPipeShellLastShape(OCCTPipeShellRef _Nonnull ps);

// MARK: - Shape topology extensions (v0.106.0)

/// Get shape orientation: 0=FORWARD, 1=REVERSED, 2=INTERNAL, 3=EXTERNAL.
int32_t OCCTShapeGetOrientation(OCCTShapeRef _Nonnull shape);

/// Set shape orientation: 0=FORWARD, 1=REVERSED, 2=INTERNAL, 3=EXTERNAL.
void OCCTShapeSetOrientation(OCCTShapeRef _Nonnull shape, int32_t orientation);

/// Get a reversed copy of the shape.
OCCTShapeRef _Nullable OCCTShapeReversed(OCCTShapeRef _Nonnull shape);

/// Get a complemented copy of the shape (reversed orientation).
OCCTShapeRef _Nullable OCCTShapeComplemented(OCCTShapeRef _Nonnull shape);

/// Compose two shape orientations. Returns new shape with composed orientation.
OCCTShapeRef _Nullable OCCTShapeComposed(OCCTShapeRef _Nonnull shape, int32_t orientation);

/// Check if the shape's Free flag is set.
bool OCCTShapeIsFree(OCCTShapeRef _Nonnull shape);

/// Check if the shape's Modified flag is set.
bool OCCTShapeIsModified(OCCTShapeRef _Nonnull shape);

/// Check if the shape's Checked flag is set.
bool OCCTShapeIsChecked(OCCTShapeRef _Nonnull shape);

/// Check if the shape's Orientable flag is set.
bool OCCTShapeIsOrientable(OCCTShapeRef _Nonnull shape);

/// Check if the shape's Infinite flag is set.
bool OCCTShapeIsInfinite(OCCTShapeRef _Nonnull shape);

/// Check if the shape's Convex flag is set.
bool OCCTShapeIsConvex(OCCTShapeRef _Nonnull shape);

/// Check if the shape is empty (null).
bool OCCTShapeIsEmpty(OCCTShapeRef _Nonnull shape);

/// Check if two shapes are partners (same TShape).
bool OCCTShapeIsPartner(OCCTShapeRef _Nonnull shape1, OCCTShapeRef _Nonnull shape2);

/// Check if two shapes are equal (same TShape + same location + same orientation).
bool OCCTShapeIsEqual(OCCTShapeRef _Nonnull shape1, OCCTShapeRef _Nonnull shape2);

/// Get the number of direct children sub-shapes.
int32_t OCCTShapeNbChildren(OCCTShapeRef _Nonnull shape);

/// Get the hash code of a shape.
int32_t OCCTShapeHashCode(OCCTShapeRef _Nonnull shape);

// MARK: - Curve3D continuity (v0.106.0)

/// Get the global continuity of a 3D curve. Returns GeomAbs_Shape as int: 0=C0, 1=C1, 2=C2, 3=C3, 4=CN, 5=G1, 6=G2.
int32_t OCCTCurve3DGetContinuity(OCCTCurve3DRef _Nonnull curve);

// MARK: - Curve2D continuity (v0.106.0)

/// Get the global continuity of a 2D curve. Returns GeomAbs_Shape as int.
int32_t OCCTCurve2DGetContinuity(OCCTCurve2DRef _Nonnull curve);

// MARK: - Surface continuity (v0.106.0)

/// Get the global continuity of a surface. Returns GeomAbs_Shape as int.
int32_t OCCTSurfaceGetContinuity(OCCTSurfaceRef _Nonnull surface);

/// Get number of UV bounds for a surface.
void OCCTSurfaceGetNBounds(OCCTSurfaceRef _Nonnull surface, int32_t* _Nonnull uSpans, int32_t* _Nonnull vSpans);

// MARK: - Geom_BSplineCurve Methods (v0.107.0)

/// Get the number of knots of a BSpline curve. Returns 0 if not a BSpline.
int32_t OCCTCurve3DBSplineKnotCount(OCCTCurve3DRef _Nonnull curve);

/// Get the number of poles (control points) of a BSpline curve.
int32_t OCCTCurve3DBSplinePoleCount(OCCTCurve3DRef _Nonnull curve);

/// Get the degree of a BSpline curve.
int32_t OCCTCurve3DBSplineDegree(OCCTCurve3DRef _Nonnull curve);

/// Check if a BSpline curve is rational.
bool OCCTCurve3DBSplineIsRational(OCCTCurve3DRef _Nonnull curve);

/// Get all knot values (pre-allocated array of size NbKnots).
void OCCTCurve3DBSplineGetKnots(OCCTCurve3DRef _Nonnull curve, double* _Nonnull knots);

/// Get all knot multiplicities (pre-allocated array of size NbKnots).
void OCCTCurve3DBSplineGetMults(OCCTCurve3DRef _Nonnull curve, int32_t* _Nonnull mults);

/// Get a pole (1-based index).
void OCCTCurve3DBSplineGetPole(OCCTCurve3DRef _Nonnull curve, int32_t index, double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Set a pole (1-based index).
bool OCCTCurve3DBSplineSetPole(OCCTCurve3DRef _Nonnull curve, int32_t index, double x, double y, double z);

/// Set a weight for a pole (1-based index).
bool OCCTCurve3DBSplineSetWeight(OCCTCurve3DRef _Nonnull curve, int32_t index, double weight);

/// Get the weight of a pole (1-based index).
double OCCTCurve3DBSplineGetWeight(OCCTCurve3DRef _Nonnull curve, int32_t index);

/// Insert a knot at parameter u with given multiplicity.
bool OCCTCurve3DBSplineInsertKnot(OCCTCurve3DRef _Nonnull curve, double u, int32_t mult, double tol);

/// Remove a knot at index down to given multiplicity.
bool OCCTCurve3DBSplineRemoveKnot(OCCTCurve3DRef _Nonnull curve, int32_t index, int32_t mult, double tol);

/// Segment the BSpline to [u1, u2].
bool OCCTCurve3DBSplineSegment(OCCTCurve3DRef _Nonnull curve, double u1, double u2);

/// Increase the degree to the given value.
bool OCCTCurve3DBSplineIncreaseDegree(OCCTCurve3DRef _Nonnull curve, int32_t degree);

/// Compute the parametric resolution for a given 3D tolerance.
double OCCTCurve3DBSplineResolution(OCCTCurve3DRef _Nonnull curve, double tolerance3d);

/// Set periodic/non-periodic.
bool OCCTCurve3DBSplineSetPeriodic(OCCTCurve3DRef _Nonnull curve, bool periodic);

// MARK: - Geom_BSplineSurface Methods (v0.107.0)

/// Get the number of U knots.
int32_t OCCTSurfaceBSplineNbUKnots(OCCTSurfaceRef _Nonnull surface);

/// Get the number of V knots.
int32_t OCCTSurfaceBSplineNbVKnots(OCCTSurfaceRef _Nonnull surface);

/// Get the number of U poles.
int32_t OCCTSurfaceBSplineNbUPoles(OCCTSurfaceRef _Nonnull surface);

/// Get the number of V poles.
int32_t OCCTSurfaceBSplineNbVPoles(OCCTSurfaceRef _Nonnull surface);

/// Get the U degree.
int32_t OCCTSurfaceBSplineUDegree(OCCTSurfaceRef _Nonnull surface);

/// Get the V degree.
int32_t OCCTSurfaceBSplineVDegree(OCCTSurfaceRef _Nonnull surface);

/// Check if the surface is U-rational.
bool OCCTSurfaceBSplineIsURational(OCCTSurfaceRef _Nonnull surface);

/// Check if the surface is V-rational.
bool OCCTSurfaceBSplineIsVRational(OCCTSurfaceRef _Nonnull surface);

/// Get a pole at (uIndex, vIndex) — both 1-based.
void OCCTSurfaceBSplineGetPole(OCCTSurfaceRef _Nonnull surface, int32_t uIndex, int32_t vIndex, double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Set a pole at (uIndex, vIndex) — both 1-based.
bool OCCTSurfaceBSplineSetPole(OCCTSurfaceRef _Nonnull surface, int32_t uIndex, int32_t vIndex, double x, double y, double z);

/// Set the weight at (uIndex, vIndex).
bool OCCTSurfaceBSplineSetWeight(OCCTSurfaceRef _Nonnull surface, int32_t uIndex, int32_t vIndex, double weight);

/// Insert a U knot.
bool OCCTSurfaceBSplineInsertUKnot(OCCTSurfaceRef _Nonnull surface, double u, int32_t mult, double tol);

/// Insert a V knot.
bool OCCTSurfaceBSplineInsertVKnot(OCCTSurfaceRef _Nonnull surface, double v, int32_t mult, double tol);

/// Segment the BSpline surface to [u1,u2] x [v1,v2].
bool OCCTSurfaceBSplineSegment(OCCTSurfaceRef _Nonnull surface, double u1, double u2, double v1, double v2);

/// Increase the degree to (uDeg, vDeg).
bool OCCTSurfaceBSplineIncreaseDegree(OCCTSurfaceRef _Nonnull surface, int32_t uDeg, int32_t vDeg);

/// Exchange U and V directions.
bool OCCTSurfaceBSplineExchangeUV(OCCTSurfaceRef _Nonnull surface);

// MARK: - Geom2d_BSplineCurve Methods (v0.107.0)

/// Get the number of knots of a 2D BSpline curve.
int32_t OCCTCurve2DBSplineKnotCount(OCCTCurve2DRef _Nonnull curve);

/// Get the number of poles of a 2D BSpline curve.
int32_t OCCTCurve2DBSplinePoleCount(OCCTCurve2DRef _Nonnull curve);

/// Get the degree of a 2D BSpline curve.
int32_t OCCTCurve2DBSplineDegree(OCCTCurve2DRef _Nonnull curve);

/// Check if a 2D BSpline curve is rational.
bool OCCTCurve2DBSplineIsRational(OCCTCurve2DRef _Nonnull curve);

/// Get a 2D pole (1-based index).
void OCCTCurve2DBSplineGetPole(OCCTCurve2DRef _Nonnull curve, int32_t index, double* _Nonnull x, double* _Nonnull y);

/// Set a 2D pole (1-based index).
bool OCCTCurve2DBSplineSetPole(OCCTCurve2DRef _Nonnull curve, int32_t index, double x, double y);

/// Set a weight for a 2D pole (1-based index).
bool OCCTCurve2DBSplineSetWeight(OCCTCurve2DRef _Nonnull curve, int32_t index, double weight);

/// Insert a knot into a 2D BSpline curve.
bool OCCTCurve2DBSplineInsertKnot(OCCTCurve2DRef _Nonnull curve, double u, int32_t mult, double tol);

/// Remove a knot from a 2D BSpline curve.
bool OCCTCurve2DBSplineRemoveKnot(OCCTCurve2DRef _Nonnull curve, int32_t index, int32_t mult, double tol);

/// Segment a 2D BSpline curve to [u1, u2].
bool OCCTCurve2DBSplineSegment(OCCTCurve2DRef _Nonnull curve, double u1, double u2);

/// Increase the degree of a 2D BSpline curve.
bool OCCTCurve2DBSplineIncreaseDegree(OCCTCurve2DRef _Nonnull curve, int32_t degree);

/// Compute parametric resolution for a 2D BSpline curve.
double OCCTCurve2DBSplineResolution(OCCTCurve2DRef _Nonnull curve, double tolerance);

// MARK: - Bezier Curve Methods (v0.107.0)

/// Get a Bezier pole (1-based index).
void OCCTCurve3DBezierGetPole(OCCTCurve3DRef _Nonnull curve, int32_t index, double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Set a Bezier pole (1-based index).
bool OCCTCurve3DBezierSetPole(OCCTCurve3DRef _Nonnull curve, int32_t index, double x, double y, double z);

/// Set a Bezier weight (1-based index).
bool OCCTCurve3DBezierSetWeight(OCCTCurve3DRef _Nonnull curve, int32_t index, double weight);

/// Insert a pole after given index.
bool OCCTCurve3DBezierInsertPoleAfter(OCCTCurve3DRef _Nonnull curve, int32_t index, double x, double y, double z);

/// Remove a pole at given index.
bool OCCTCurve3DBezierRemovePole(OCCTCurve3DRef _Nonnull curve, int32_t index);

/// Segment a Bezier curve to [u1, u2].
bool OCCTCurve3DBezierSegment(OCCTCurve3DRef _Nonnull curve, double u1, double u2);

/// Increase the degree of a Bezier curve.
bool OCCTCurve3DBezierIncreaseDegree(OCCTCurve3DRef _Nonnull curve, int32_t degree);

/// Check if a Bezier curve is rational.
bool OCCTCurve3DBezierIsRational(OCCTCurve3DRef _Nonnull curve);

/// Get the degree of a Bezier curve.
int32_t OCCTCurve3DBezierDegree(OCCTCurve3DRef _Nonnull curve);

/// Get the number of poles of a Bezier curve.
int32_t OCCTCurve3DBezierPoleCount(OCCTCurve3DRef _Nonnull curve);

// MARK: - BRepTools/BRepLib Utilities (v0.107.0)

/// Clean all tessellation data from a shape.
void OCCTShapeClean(OCCTShapeRef _Nonnull shape);

/// Clean geometry (PCurves etc.) from a shape.
void OCCTShapeCleanGeometry(OCCTShapeRef _Nonnull shape);

/// Remove unused PCurves from edges of a shape.
void OCCTShapeRemoveUnusedPCurves(OCCTShapeRef _Nonnull shape);

/// Update BRep data structures.
void OCCTShapeUpdate(OCCTShapeRef _Nonnull shape);

/// Check if an edge has same-range parametrisation.
bool OCCTBRepLibCheckSameRange(OCCTShapeRef _Nonnull edge);

/// Ensure edge has same-range parametrisation.
bool OCCTBRepLibSameRange(OCCTShapeRef _Nonnull edge, double tol);

/// Build 3D curve for an edge from PCurves.
bool OCCTBRepLibBuildCurve3d(OCCTShapeRef _Nonnull edge, double tol);

/// Update tolerances of all sub-shapes.
void OCCTBRepLibUpdateTolerances(OCCTShapeRef _Nonnull shape);

/// Update inner tolerances of all sub-shapes.
void OCCTBRepLibUpdateInnerTolerances(OCCTShapeRef _Nonnull shape);

/// Update tolerance of a specific edge.
bool OCCTBRepLibUpdateEdgeTolerance(OCCTShapeRef _Nonnull edge, double tol);

// MARK: - MakeFace Extras (v0.107.0)

/// Create a face from a sphere with UV bounds (no tolerance param).
OCCTShapeRef _Nullable OCCTMakeFaceFromSphere(double cx, double cy, double cz, double radius, double umin, double umax, double vmin, double vmax);

/// Create a face from a torus with UV bounds.
OCCTShapeRef _Nullable OCCTMakeFaceFromTorus(double cx, double cy, double cz, double nx, double ny, double nz, double major, double minor, double umin, double umax, double vmin, double vmax);

/// Create a face from a cone with UV bounds.
OCCTShapeRef _Nullable OCCTMakeFaceFromCone(double cx, double cy, double cz, double nx, double ny, double nz, double angle, double radius, double umin, double umax, double vmin, double vmax);

/// Create a face from a surface trimmed by a wire.
OCCTShapeRef _Nullable OCCTMakeFaceFromSurfaceWire(OCCTSurfaceRef _Nonnull surface, OCCTShapeRef _Nonnull wire, bool inside);

/// Add a hole (inner wire) to a face.
OCCTShapeRef _Nullable OCCTMakeFaceAddHole(OCCTShapeRef _Nonnull face, OCCTShapeRef _Nonnull wire);

/// Copy a face.
OCCTShapeRef _Nullable OCCTMakeFaceCopy(OCCTShapeRef _Nonnull face);

// MARK: - Sewing (v0.107.0)

/// Opaque sewing builder handle.
typedef struct OCCTSewing* OCCTSewingRef;

/// Create a sewing builder with given tolerance.
OCCTSewingRef _Nullable OCCTSewingCreate(double tolerance);

/// Release a sewing builder.
void OCCTSewingRelease(OCCTSewingRef _Nullable sewing);

/// Add a shape to the sewing builder.
void OCCTSewingAdd(OCCTSewingRef _Nonnull sewing, OCCTShapeRef _Nonnull shape);

/// Perform sewing.
void OCCTSewingPerform(OCCTSewingRef _Nonnull sewing);

/// Get the result of sewing.
OCCTShapeRef _Nullable OCCTSewingResult(OCCTSewingRef _Nonnull sewing);

/// Get the number of free edges after sewing.
int32_t OCCTSewingNbFreeEdges(OCCTSewingRef _Nonnull sewing);

/// Get the number of contiguous edges after sewing.
int32_t OCCTSewingNbContigousEdges(OCCTSewingRef _Nonnull sewing);

/// Get the number of degenerated shapes after sewing.
int32_t OCCTSewingNbDegeneratedShapes(OCCTSewingRef _Nonnull sewing);

// MARK: - Hatch_Hatcher (v0.107.0)

/// Opaque hatcher handle.
typedef struct OCCTHatcher* OCCTHatcherRef;

/// Create a Hatch_Hatcher with given tolerance.
OCCTHatcherRef _Nullable OCCTHatcherCreate(double tolerance);

/// Release a hatcher.
void OCCTHatcherRelease(OCCTHatcherRef _Nullable hatcher);

/// Add a vertical line at x.
void OCCTHatcherAddXLine(OCCTHatcherRef _Nonnull hatcher, double x);

/// Add a horizontal line at y.
void OCCTHatcherAddYLine(OCCTHatcherRef _Nonnull hatcher, double y);

/// Trim hatch lines with a segment from (x1,y1) to (x2,y2).
void OCCTHatcherTrim(OCCTHatcherRef _Nonnull hatcher, double x1, double y1, double x2, double y2);

/// Get the number of hatch lines.
int32_t OCCTHatcherNbLines(OCCTHatcherRef _Nonnull hatcher);

/// Get the number of intervals on a line (1-based index).
int32_t OCCTHatcherNbIntervals(OCCTHatcherRef _Nonnull hatcher, int32_t lineIndex);

// MARK: - Edge/Face Extraction (v0.107.0)

/// Extract the 3D curve from an edge. Returns null if no curve. Writes first/last parameters.
OCCTCurve3DRef _Nullable OCCTEdgeExtractCurve3D(OCCTShapeRef _Nonnull edge, double* _Nonnull first, double* _Nonnull last);

/// Extract the PCurve of an edge on a face. Returns null if no PCurve.
OCCTCurve2DRef _Nullable OCCTEdgeExtractPCurve(OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull face, double* _Nonnull first, double* _Nonnull last);

/// Get the tolerance of an edge.
double OCCTEdgeGetTolerance(OCCTShapeRef _Nonnull edge);

/// Check if an edge is degenerated.
bool OCCTEdgeIsDegenerated(OCCTShapeRef _Nonnull edge);

/// Extract the surface from a face.
OCCTSurfaceRef _Nullable OCCTFaceExtractSurface(OCCTShapeRef _Nonnull face);

/// Get the tolerance of a face.
double OCCTFaceGetTolerance(OCCTShapeRef _Nonnull face);

/// Get the number of wires on a face.
int32_t OCCTFaceWireCount(OCCTShapeRef _Nonnull face);

/// Get the tolerance of a vertex.
double OCCTVertexGetTolerance(OCCTShapeRef _Nonnull vertex);

/// Get the point of a vertex.
void OCCTVertexGetPoint(OCCTShapeRef _Nonnull vertex, double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

// MARK: - Geom_Circle Methods (v0.108.0)

/// Get the radius of a Geom_Circle.
double OCCTCurve3DCircleRadius(OCCTCurve3DRef _Nonnull curve);

/// Set the radius of a Geom_Circle. Returns false if not a circle.
bool OCCTCurve3DCircleSetRadius(OCCTCurve3DRef _Nonnull curve, double radius);

/// Get the eccentricity of a Geom_Circle (always 0).
double OCCTCurve3DCircleEccentricity(OCCTCurve3DRef _Nonnull curve);

/// Get the XAxis of a Geom_Circle.
void OCCTCurve3DCircleXAxis(OCCTCurve3DRef _Nonnull curve, double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz, double* _Nonnull dx, double* _Nonnull dy, double* _Nonnull dz);

/// Get the YAxis of a Geom_Circle.
void OCCTCurve3DCircleYAxis(OCCTCurve3DRef _Nonnull curve, double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz, double* _Nonnull dx, double* _Nonnull dy, double* _Nonnull dz);

/// Get the center of a Geom_Circle.
void OCCTCurve3DCircleCenter(OCCTCurve3DRef _Nonnull curve, double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

// MARK: - Geom_Ellipse Methods (v0.108.0)

/// Get the major radius of a Geom_Ellipse.
double OCCTCurve3DEllipseMajorRadius(OCCTCurve3DRef _Nonnull curve);

/// Get the minor radius of a Geom_Ellipse.
double OCCTCurve3DEllipseMinorRadius(OCCTCurve3DRef _Nonnull curve);

/// Set the major radius of a Geom_Ellipse.
bool OCCTCurve3DEllipseSetMajorRadius(OCCTCurve3DRef _Nonnull curve, double r);

/// Set the minor radius of a Geom_Ellipse.
bool OCCTCurve3DEllipseSetMinorRadius(OCCTCurve3DRef _Nonnull curve, double r);

/// Get the eccentricity of a Geom_Ellipse.
double OCCTCurve3DEllipseEccentricity(OCCTCurve3DRef _Nonnull curve);

/// Get the focal distance of a Geom_Ellipse.
double OCCTCurve3DEllipseFocal(OCCTCurve3DRef _Nonnull curve);

/// Get the first focus of a Geom_Ellipse.
void OCCTCurve3DEllipseFocus1(OCCTCurve3DRef _Nonnull curve, double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Get the second focus of a Geom_Ellipse.
void OCCTCurve3DEllipseFocus2(OCCTCurve3DRef _Nonnull curve, double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Get the parameter (semi-latus rectum) of a Geom_Ellipse.
double OCCTCurve3DEllipseParameter(OCCTCurve3DRef _Nonnull curve);

/// Get the first directrix of a Geom_Ellipse.
void OCCTCurve3DEllipseDirectrix1(OCCTCurve3DRef _Nonnull curve, double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz, double* _Nonnull dx, double* _Nonnull dy, double* _Nonnull dz);

// MARK: - Geom_Hyperbola Methods (v0.108.0)

/// Get the major radius of a Geom_Hyperbola.
double OCCTCurve3DHyperbolaMajorRadius(OCCTCurve3DRef _Nonnull curve);

/// Get the minor radius of a Geom_Hyperbola.
double OCCTCurve3DHyperbolaMinorRadius(OCCTCurve3DRef _Nonnull curve);

/// Set the major radius of a Geom_Hyperbola.
bool OCCTCurve3DHyperbolaSetMajorRadius(OCCTCurve3DRef _Nonnull curve, double r);

/// Set the minor radius of a Geom_Hyperbola.
bool OCCTCurve3DHyperbolaSetMinorRadius(OCCTCurve3DRef _Nonnull curve, double r);

/// Get the eccentricity of a Geom_Hyperbola.
double OCCTCurve3DHyperbolaEccentricity(OCCTCurve3DRef _Nonnull curve);

/// Get the focal distance of a Geom_Hyperbola.
double OCCTCurve3DHyperbolaFocal(OCCTCurve3DRef _Nonnull curve);

/// Get the first focus of a Geom_Hyperbola.
void OCCTCurve3DHyperbolaFocus1(OCCTCurve3DRef _Nonnull curve, double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Get the first asymptote of a Geom_Hyperbola.
void OCCTCurve3DHyperbolaAsymptote1(OCCTCurve3DRef _Nonnull curve, double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz, double* _Nonnull dx, double* _Nonnull dy, double* _Nonnull dz);

// MARK: - Geom_Parabola Methods (v0.108.0)

/// Get the focal distance of a Geom_Parabola.
double OCCTCurve3DParabolaFocal(OCCTCurve3DRef _Nonnull curve);

/// Set the focal distance of a Geom_Parabola.
bool OCCTCurve3DParabolaSetFocal(OCCTCurve3DRef _Nonnull curve, double focal);

/// Get the focus point of a Geom_Parabola.
void OCCTCurve3DParabolaFocus(OCCTCurve3DRef _Nonnull curve, double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Get the eccentricity of a Geom_Parabola (always 1).
double OCCTCurve3DParabolaEccentricity(OCCTCurve3DRef _Nonnull curve);

/// Get the parameter (2*focal) of a Geom_Parabola.
double OCCTCurve3DParabolaParameter(OCCTCurve3DRef _Nonnull curve);

/// Get the directrix of a Geom_Parabola.
void OCCTCurve3DParabolaDirectrix(OCCTCurve3DRef _Nonnull curve, double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz, double* _Nonnull dx, double* _Nonnull dy, double* _Nonnull dz);

// MARK: - Geom_Line Methods (v0.108.0)

/// Get the direction of a Geom_Line.
void OCCTCurve3DLineDirection(OCCTCurve3DRef _Nonnull curve, double* _Nonnull dx, double* _Nonnull dy, double* _Nonnull dz);

/// Get the location of a Geom_Line.
void OCCTCurve3DLineLocation(OCCTCurve3DRef _Nonnull curve, double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Set the direction of a Geom_Line.
bool OCCTCurve3DLineSetDirection(OCCTCurve3DRef _Nonnull curve, double dx, double dy, double dz);

/// Set the location of a Geom_Line.
bool OCCTCurve3DLineSetLocation(OCCTCurve3DRef _Nonnull curve, double x, double y, double z);

/// Get the position (Ax1) of a Geom_Line.
void OCCTCurve3DLinePosition(OCCTCurve3DRef _Nonnull curve, double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz, double* _Nonnull dx, double* _Nonnull dy, double* _Nonnull dz);

/// Get the gp_Lin of a Geom_Line.
void OCCTCurve3DLineLin(OCCTCurve3DRef _Nonnull curve, double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz, double* _Nonnull dx, double* _Nonnull dy, double* _Nonnull dz);

// MARK: - Geom_Plane Methods (v0.108.0)

/// Get the plane coefficients (A, B, C, D) of a Geom_Plane.
void OCCTSurfacePlaneCoefficients(OCCTSurfaceRef _Nonnull surface, double* _Nonnull A, double* _Nonnull B, double* _Nonnull C, double* _Nonnull D);

/// Get a U iso-curve from a Geom_Plane.
OCCTCurve3DRef _Nullable OCCTSurfacePlaneUIso(OCCTSurfaceRef _Nonnull surface, double u);

/// Get a V iso-curve from a Geom_Plane.
OCCTCurve3DRef _Nullable OCCTSurfacePlaneVIso(OCCTSurfaceRef _Nonnull surface, double v);

/// Get the gp_Pln data (origin + normal) from a Geom_Plane.
void OCCTSurfacePlanePln(OCCTSurfaceRef _Nonnull surface, double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz, double* _Nonnull nx, double* _Nonnull ny, double* _Nonnull nz);

// MARK: - Geom_SphericalSurface Methods (v0.108.0)

/// Get the radius of a Geom_SphericalSurface.
double OCCTSurfaceSphereRadius(OCCTSurfaceRef _Nonnull surface);

/// Set the radius of a Geom_SphericalSurface.
bool OCCTSurfaceSphereSetRadius(OCCTSurfaceRef _Nonnull surface, double radius);

/// Get the area of a Geom_SphericalSurface.
double OCCTSurfaceSphereArea(OCCTSurfaceRef _Nonnull surface);

/// Get the volume of a Geom_SphericalSurface.
double OCCTSurfaceSphereVolume(OCCTSurfaceRef _Nonnull surface);

/// Get the center of a Geom_SphericalSurface.
void OCCTSurfaceSphereCenter(OCCTSurfaceRef _Nonnull surface, double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Get a U iso-curve from a Geom_SphericalSurface.
OCCTCurve3DRef _Nullable OCCTSurfaceSphereUIso(OCCTSurfaceRef _Nonnull surface, double u);

/// Get a V iso-curve from a Geom_SphericalSurface.
OCCTCurve3DRef _Nullable OCCTSurfaceSphereVIso(OCCTSurfaceRef _Nonnull surface, double v);

/// Get the gp_Sphere data (center + radius) from a Geom_SphericalSurface.
void OCCTSurfaceSphereSphere(OCCTSurfaceRef _Nonnull surface, double* _Nonnull cx, double* _Nonnull cy, double* _Nonnull cz, double* _Nonnull radius);

// MARK: - Geom_ToroidalSurface Methods (v0.108.0)

/// Get the major radius of a Geom_ToroidalSurface.
double OCCTSurfaceTorusMajorRadius(OCCTSurfaceRef _Nonnull surface);

/// Get the minor radius of a Geom_ToroidalSurface.
double OCCTSurfaceTorusMinorRadius(OCCTSurfaceRef _Nonnull surface);

/// Set the major radius of a Geom_ToroidalSurface.
bool OCCTSurfaceTorusSetMajorRadius(OCCTSurfaceRef _Nonnull surface, double r);

/// Set the minor radius of a Geom_ToroidalSurface.
bool OCCTSurfaceTorusSetMinorRadius(OCCTSurfaceRef _Nonnull surface, double r);

/// Get the area of a Geom_ToroidalSurface.
double OCCTSurfaceTorusArea(OCCTSurfaceRef _Nonnull surface);

/// Get the volume of a Geom_ToroidalSurface.
double OCCTSurfaceTorusVolume(OCCTSurfaceRef _Nonnull surface);

/// Get the axis of a Geom_ToroidalSurface (origin + direction of rotation axis). v0.137.
void OCCTSurfaceTorusAxis(OCCTSurfaceRef _Nonnull surface, double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz, double* _Nonnull dx, double* _Nonnull dy, double* _Nonnull dz);

// MARK: - Geom_SurfaceOfRevolution Methods (v0.137)

/// Get the axis of revolution (origin + direction). Valid only when surface type == Revolution.
void OCCTSurfaceRevolutionAxis(OCCTSurfaceRef _Nonnull surface, double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz, double* _Nonnull dx, double* _Nonnull dy, double* _Nonnull dz);

/// Get the location (anchor point on the axis) of a Geom_SurfaceOfRevolution.
void OCCTSurfaceRevolutionLocation(OCCTSurfaceRef _Nonnull surface, double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

// MARK: - Geom_CylindricalSurface Methods (v0.108.0)

/// Get the radius of a Geom_CylindricalSurface.
double OCCTSurfaceCylinderRadius(OCCTSurfaceRef _Nonnull surface);

/// Set the radius of a Geom_CylindricalSurface.
bool OCCTSurfaceCylinderSetRadius(OCCTSurfaceRef _Nonnull surface, double r);

/// Get the axis of a Geom_CylindricalSurface.
void OCCTSurfaceCylinderAxis(OCCTSurfaceRef _Nonnull surface, double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz, double* _Nonnull dx, double* _Nonnull dy, double* _Nonnull dz);

/// Get a U iso-curve from a Geom_CylindricalSurface.
OCCTCurve3DRef _Nullable OCCTSurfaceCylinderUIso(OCCTSurfaceRef _Nonnull surface, double u);

// MARK: - Geom_ConicalSurface Methods (v0.108.0)

/// Get the semi-angle of a Geom_ConicalSurface.
double OCCTSurfaceConeSemiAngle(OCCTSurfaceRef _Nonnull surface);

/// Get the reference radius of a Geom_ConicalSurface.
double OCCTSurfaceConeRefRadius(OCCTSurfaceRef _Nonnull surface);

/// Get the apex of a Geom_ConicalSurface.
void OCCTSurfaceConeApex(OCCTSurfaceRef _Nonnull surface, double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Get the axis of a Geom_ConicalSurface.
void OCCTSurfaceConeAxis(OCCTSurfaceRef _Nonnull surface, double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz, double* _Nonnull dx, double* _Nonnull dy, double* _Nonnull dz);

// MARK: - Geom_SweptSurface Methods (v0.108.0)

/// Get the extrusion/revolution direction of a Geom_SweptSurface.
void OCCTSurfaceSweptDirection(OCCTSurfaceRef _Nonnull surface, double* _Nonnull dx, double* _Nonnull dy, double* _Nonnull dz);

/// Get the basis curve of a Geom_SweptSurface.
OCCTCurve3DRef _Nullable OCCTSurfaceSweptBasisCurve(OCCTSurfaceRef _Nonnull surface);

// MARK: - Geom2d_Circle Methods (v0.108.0)

/// Get the radius of a Geom2d_Circle.
double OCCTCurve2DCircleRadius(OCCTCurve2DRef _Nonnull curve);

/// Set the radius of a Geom2d_Circle.
bool OCCTCurve2DCircleSetRadius(OCCTCurve2DRef _Nonnull curve, double r);

/// Get the eccentricity of a Geom2d_Circle (always 0).
double OCCTCurve2DCircleEccentricity(OCCTCurve2DRef _Nonnull curve);

/// Get the center of a Geom2d_Circle.
void OCCTCurve2DCircleCenter(OCCTCurve2DRef _Nonnull curve, double* _Nonnull x, double* _Nonnull y);

/// Get the XAxis of a Geom2d_Circle.
void OCCTCurve2DCircleXAxis(OCCTCurve2DRef _Nonnull curve, double* _Nonnull px, double* _Nonnull py, double* _Nonnull dx, double* _Nonnull dy);

// MARK: - Geom2d_Ellipse Methods (v0.108.0)

/// Get the major radius of a Geom2d_Ellipse.
double OCCTCurve2DEllipseMajorRadius(OCCTCurve2DRef _Nonnull curve);

/// Get the minor radius of a Geom2d_Ellipse.
double OCCTCurve2DEllipseMinorRadius(OCCTCurve2DRef _Nonnull curve);

/// Set the major radius of a Geom2d_Ellipse.
bool OCCTCurve2DEllipseSetMajorRadius(OCCTCurve2DRef _Nonnull curve, double r);

/// Set the minor radius of a Geom2d_Ellipse.
bool OCCTCurve2DEllipseSetMinorRadius(OCCTCurve2DRef _Nonnull curve, double r);

/// Get the eccentricity of a Geom2d_Ellipse.
double OCCTCurve2DEllipseEccentricity(OCCTCurve2DRef _Nonnull curve);

/// Get the focal distance of a Geom2d_Ellipse.
double OCCTCurve2DEllipseFocal(OCCTCurve2DRef _Nonnull curve);

/// Get the first focus of a Geom2d_Ellipse.
void OCCTCurve2DEllipseFocus1(OCCTCurve2DRef _Nonnull curve, double* _Nonnull x, double* _Nonnull y);

// MARK: - Geom2d_Hyperbola Methods (v0.108.0)

/// Get the major radius of a Geom2d_Hyperbola.
double OCCTCurve2DHyperbolaMajorRadius(OCCTCurve2DRef _Nonnull curve);

/// Get the minor radius of a Geom2d_Hyperbola.
double OCCTCurve2DHyperbolaMinorRadius(OCCTCurve2DRef _Nonnull curve);

/// Get the eccentricity of a Geom2d_Hyperbola.
double OCCTCurve2DHyperbolaEccentricity(OCCTCurve2DRef _Nonnull curve);

/// Get the focal distance of a Geom2d_Hyperbola.
double OCCTCurve2DHyperbolaFocal(OCCTCurve2DRef _Nonnull curve);

/// Get the first focus of a Geom2d_Hyperbola.
void OCCTCurve2DHyperbolaFocus1(OCCTCurve2DRef _Nonnull curve, double* _Nonnull x, double* _Nonnull y);

// MARK: - Geom2d_Parabola Methods (v0.108.0)

/// Get the focal distance of a Geom2d_Parabola.
double OCCTCurve2DParabolaFocal(OCCTCurve2DRef _Nonnull curve);

/// Set the focal distance of a Geom2d_Parabola.
bool OCCTCurve2DParabolaSetFocal(OCCTCurve2DRef _Nonnull curve, double focal);

/// Get the focus of a Geom2d_Parabola.
void OCCTCurve2DParabolaFocus(OCCTCurve2DRef _Nonnull curve, double* _Nonnull x, double* _Nonnull y);

/// Get the eccentricity of a Geom2d_Parabola (always 1).
double OCCTCurve2DParabolaEccentricity(OCCTCurve2DRef _Nonnull curve);

/// Get the parameter (2*focal) of a Geom2d_Parabola.
double OCCTCurve2DParabolaParameter(OCCTCurve2DRef _Nonnull curve);

// MARK: - Geom2d_Line Methods (v0.108.0)

/// Get the direction of a Geom2d_Line.
void OCCTCurve2DLineDirection(OCCTCurve2DRef _Nonnull curve, double* _Nonnull dx, double* _Nonnull dy);

/// Get the location of a Geom2d_Line.
void OCCTCurve2DLineLocation(OCCTCurve2DRef _Nonnull curve, double* _Nonnull x, double* _Nonnull y);

/// Set the direction of a Geom2d_Line.
bool OCCTCurve2DLineSetDirection(OCCTCurve2DRef _Nonnull curve, double dx, double dy);

/// Set the location of a Geom2d_Line.
bool OCCTCurve2DLineSetLocation(OCCTCurve2DRef _Nonnull curve, double x, double y);

/// Get the distance from a Geom2d_Line to a point.
double OCCTCurve2DLineDistance(OCCTCurve2DRef _Nonnull curve, double px, double py);

/// Get the gp_Lin2d of a Geom2d_Line.
void OCCTCurve2DLineLin2d(OCCTCurve2DRef _Nonnull curve, double* _Nonnull px, double* _Nonnull py, double* _Nonnull dx, double* _Nonnull dy);

// MARK: - Geom2d_OffsetCurve Methods (v0.108.0)

/// Get the offset value of a Geom2d_OffsetCurve.
double OCCTCurve2DOffsetValue(OCCTCurve2DRef _Nonnull curve);

/// Set the offset value of a Geom2d_OffsetCurve.
bool OCCTCurve2DOffsetSetValue(OCCTCurve2DRef _Nonnull curve, double offset);

/// Get the basis curve of a Geom2d_OffsetCurve.
OCCTCurve2DRef _Nullable OCCTCurve2DOffsetBasisCurve(OCCTCurve2DRef _Nonnull curve);

// MARK: - Extrema_ExtElC: Elementary Curve-Curve Distance (v0.109.0)

/// 3D elementary extrema result
typedef struct {
    double squareDistance;
    double x1, y1, z1;  ///< Point on first element
    double x2, y2, z2;  ///< Point on second element
} OCCTExtremaElResult;

/// Distance between two 3D lines (Extrema_ExtElC).
/// @param outIsParallel Set to true if lines are parallel
/// @return Number of extrema (-1 on error)
int32_t OCCTExtremaElCLinLin(double l1px, double l1py, double l1pz, double l1dx, double l1dy, double l1dz,
                              double l2px, double l2py, double l2pz, double l2dx, double l2dy, double l2dz,
                              double tolerance,
                              bool* _Nonnull outIsParallel,
                              OCCTExtremaElResult* _Nonnull out, int32_t max);

/// Distance between a 3D line and circle (Extrema_ExtElC).
/// @return Number of extrema (-1 on error)
int32_t OCCTExtremaElCLinCirc(double lpx, double lpy, double lpz, double ldx, double ldy, double ldz,
                               double cx, double cy, double cz, double nx, double ny, double nz, double radius,
                               double tolerance,
                               OCCTExtremaElResult* _Nonnull out, int32_t max);

/// Distance between two 3D circles (Extrema_ExtElC).
/// @return Number of extrema (-1 on error)
int32_t OCCTExtremaElCCircCirc(double c1x, double c1y, double c1z, double n1x, double n1y, double n1z, double r1,
                                double c2x, double c2y, double c2z, double n2x, double n2y, double n2z, double r2,
                                OCCTExtremaElResult* _Nonnull out, int32_t max);

/// Distance between a 3D line and ellipse (Extrema_ExtElC).
/// @return Number of extrema (-1 on error)
int32_t OCCTExtremaElCLinElips(double lpx, double lpy, double lpz, double ldx, double ldy, double ldz,
                                double cx, double cy, double cz, double nx, double ny, double nz,
                                double xdx, double xdy, double xdz,
                                double majorRadius, double minorRadius,
                                double tolerance,
                                OCCTExtremaElResult* _Nonnull out, int32_t max);

// MARK: - Extrema_ExtElCS: Elementary Curve-Surface Distance (v0.109.0)

/// Distance between a 3D line and plane (Extrema_ExtElCS).
/// @return Number of extrema (-1 on error)
int32_t OCCTExtremaElCSLinPlane(double lpx, double lpy, double lpz, double ldx, double ldy, double ldz,
                                 double plx, double ply, double plz, double pnx, double pny, double pnz,
                                 bool* _Nonnull outIsParallel,
                                 OCCTExtremaElResult* _Nonnull out, int32_t max);

/// Distance between a 3D line and sphere (Extrema_ExtElCS).
/// @return Number of extrema (-1 on error)
int32_t OCCTExtremaElCSLinSphere(double lpx, double lpy, double lpz, double ldx, double ldy, double ldz,
                                   double cx, double cy, double cz, double radius,
                                   OCCTExtremaElResult* _Nonnull out, int32_t max);

/// Distance between a 3D line and cylinder (Extrema_ExtElCS).
/// @return Number of extrema (-1 on error)
int32_t OCCTExtremaElCSLinCylinder(double lpx, double lpy, double lpz, double ldx, double ldy, double ldz,
                                     double cx, double cy, double cz, double nx, double ny, double nz, double radius,
                                     OCCTExtremaElResult* _Nonnull out, int32_t max);

// MARK: - Extrema_ExtElSS: Elementary Surface-Surface Distance (v0.109.0)

/// Distance between two planes (Extrema_ExtElSS).
/// @return Number of extrema (-1 on error)
int32_t OCCTExtremaElSSPlanePlane(double pl1x, double pl1y, double pl1z, double pn1x, double pn1y, double pn1z,
                                    double pl2x, double pl2y, double pl2z, double pn2x, double pn2y, double pn2z,
                                    bool* _Nonnull outIsParallel,
                                    OCCTExtremaElResult* _Nonnull out, int32_t max);

/// Distance between a plane and sphere (Extrema_ExtElSS).
/// @return Number of extrema (-1 on error)
int32_t OCCTExtremaElSSPlaneSphere(double plx, double ply, double plz, double pnx, double pny, double pnz,
                                     double cx, double cy, double cz, double radius,
                                     OCCTExtremaElResult* _Nonnull out, int32_t max);

/// Distance between two spheres (Extrema_ExtElSS).
/// @return Number of extrema (-1 on error)
int32_t OCCTExtremaElSSSphereSphere(double c1x, double c1y, double c1z, double r1,
                                      double c2x, double c2y, double c2z, double r2,
                                      OCCTExtremaElResult* _Nonnull out, int32_t max);

// MARK: - Extrema_ExtPElC: Point to Elementary Curve Distance (v0.109.0)

/// Closest distance from a point to a 3D line (Extrema_ExtPElC).
/// @return Number of extrema (-1 on error)
int32_t OCCTExtremaExtPElCLin(double px, double py, double pz,
                                double lx, double ly, double lz, double ldx, double ldy, double ldz,
                                double tolerance,
                                OCCTExtremaElResult* _Nonnull out, int32_t max);

/// Closest distance from a point to a 3D circle (Extrema_ExtPElC).
/// @return Number of extrema (-1 on error)
int32_t OCCTExtremaExtPElCCirc(double px, double py, double pz,
                                 double cx, double cy, double cz, double nx, double ny, double nz, double radius,
                                 double tolerance,
                                 OCCTExtremaElResult* _Nonnull out, int32_t max);

/// Closest distance from a point to a 3D ellipse (Extrema_ExtPElC).
/// @return Number of extrema (-1 on error)
int32_t OCCTExtremaExtPElCElips(double px, double py, double pz,
                                  double cx, double cy, double cz, double nx, double ny, double nz,
                                  double xdx, double xdy, double xdz,
                                  double majorRadius, double minorRadius,
                                  double tolerance,
                                  OCCTExtremaElResult* _Nonnull out, int32_t max);

/// Closest distance from a point to a 3D parabola (Extrema_ExtPElC).
/// @return Number of extrema (-1 on error)
int32_t OCCTExtremaExtPElCParab(double px, double py, double pz,
                                  double cx, double cy, double cz, double nx, double ny, double nz,
                                  double xdx, double xdy, double xdz,
                                  double focal,
                                  double tolerance,
                                  OCCTExtremaElResult* _Nonnull out, int32_t max);

// MARK: - Extrema_ExtPElS: Point to Elementary Surface Distance (v0.109.0)

/// Closest distance from a point to a plane (Extrema_ExtPElS).
/// @return Number of extrema (-1 on error)
int32_t OCCTExtremaExtPElSPlane(double px, double py, double pz,
                                  double plx, double ply, double plz, double pnx, double pny, double pnz,
                                  double tolerance,
                                  OCCTExtremaElResult* _Nonnull out, int32_t max);

/// Closest distance from a point to a sphere (Extrema_ExtPElS).
/// @return Number of extrema (-1 on error)
int32_t OCCTExtremaExtPElSSphere(double px, double py, double pz,
                                   double cx, double cy, double cz, double radius,
                                   double tolerance,
                                   OCCTExtremaElResult* _Nonnull out, int32_t max);

/// Closest distance from a point to a cylinder (Extrema_ExtPElS).
/// @return Number of extrema (-1 on error)
int32_t OCCTExtremaExtPElSCylinder(double px, double py, double pz,
                                     double cx, double cy, double cz, double nx, double ny, double nz, double radius,
                                     double tolerance,
                                     OCCTExtremaElResult* _Nonnull out, int32_t max);

/// Closest distance from a point to a cone (Extrema_ExtPElS).
/// @return Number of extrema (-1 on error)
int32_t OCCTExtremaExtPElSCone(double px, double py, double pz,
                                 double cx, double cy, double cz, double nx, double ny, double nz,
                                 double semiAngle, double refRadius,
                                 double tolerance,
                                 OCCTExtremaElResult* _Nonnull out, int32_t max);

/// Closest distance from a point to a torus (Extrema_ExtPElS).
/// @return Number of extrema (-1 on error)
int32_t OCCTExtremaExtPElSTorus(double px, double py, double pz,
                                  double cx, double cy, double cz, double nx, double ny, double nz,
                                  double majorRadius, double minorRadius,
                                  double tolerance,
                                  OCCTExtremaElResult* _Nonnull out, int32_t max);

// MARK: - math_TrigonometricFunctionRoots (v0.109.0)

/// Find roots of A*cos(x) + B*sin(x) + C*cos(2x) + D*sin(2x) + E = 0 on [inf,sup].
/// @return Number of roots found (-1 on error)
int32_t OCCTTrigRoots(double A, double B, double C, double D, double E,
                       double inf, double sup,
                       double* _Nonnull roots, int32_t maxRoots);

/// Check if all reals in [inf,sup] are solutions.
bool OCCTTrigRootsInfinite(double A, double B, double C, double D, double E,
                            double inf, double sup);

// MARK: - IntAna2d_Conic (v0.109.0)

/// Get 6 conic coefficients from a 2D circle: A*x^2 + B*x*y + C*y^2 + D*x + E*y + F = 0.
void OCCTConic2dFromCircle(double cx, double cy, double dx, double dy, double radius,
                            double* _Nonnull coeffs);

/// Get 6 conic coefficients from a 2D line.
void OCCTConic2dFromLine(double px, double py, double dx, double dy,
                          double* _Nonnull coeffs);

/// Get 6 conic coefficients from a 2D ellipse.
void OCCTConic2dFromEllipse(double cx, double cy, double dx, double dy,
                             double majorRadius, double minorRadius,
                             double* _Nonnull coeffs);

/// Intersect a 2D line with a 2D circle conic. Returns intersection points.
/// @return Number of intersection points (-1 on error)
int32_t OCCTConic2dLineCircleIntersect(double lpx, double lpy, double ldx, double ldy,
                                        double cx, double cy, double cdx, double cdy, double radius,
                                        double* _Nonnull xs, double* _Nonnull ys, int32_t max);

// MARK: - BRepAlgo_NormalProjection (v0.109.0)

typedef struct OCCTNormalProjection* OCCTNormalProjectionRef;

/// Create a normal projection tool targeting the given shape.
OCCTNormalProjectionRef _Nullable OCCTNormalProjectionCreate(OCCTShapeRef _Nonnull targetShape);

/// Release a normal projection tool.
void OCCTNormalProjectionRelease(OCCTNormalProjectionRef _Nullable proj);

/// Add a wire/edge to be projected.
void OCCTNormalProjectionAdd(OCCTNormalProjectionRef _Nonnull proj, OCCTShapeRef _Nonnull wire);

/// Build the projection. Returns true on success.
bool OCCTNormalProjectionBuild(OCCTNormalProjectionRef _Nonnull proj);

/// Get the projection result shape.
OCCTShapeRef _Nullable OCCTNormalProjectionResult(OCCTNormalProjectionRef _Nonnull proj);

// MARK: - OSD_Disk (v0.109.0)

/// Get disk total size in KB for path (0 if unavailable).
int64_t OCCTDiskSize(const char* _Nonnull path);

/// Get disk free space in KB for path (0 if unavailable).
int64_t OCCTDiskFree(const char* _Nonnull path);

/// Check if a disk path is valid/accessible.
bool OCCTDiskIsValid(const char* _Nonnull path);

/// Get the disk/volume name. Caller must free() the result.
char* _Nullable OCCTDiskName(const char* _Nonnull path);

// MARK: - OSD_SharedLibrary (v0.109.0)

typedef struct OCCTSharedLib* OCCTSharedLibRef;

/// Create a shared library handle by name/path.
OCCTSharedLibRef _Nullable OCCTSharedLibCreate(const char* _Nonnull name);

/// Release a shared library handle.
void OCCTSharedLibRelease(OCCTSharedLibRef _Nullable lib);

/// Open (dlopen) the shared library.
bool OCCTSharedLibOpen(OCCTSharedLibRef _Nonnull lib);

/// Close (dlclose) the shared library.
void OCCTSharedLibClose(OCCTSharedLibRef _Nonnull lib);

/// Get the name of the shared library. Caller must free() the result.
char* _Nullable OCCTSharedLibName(OCCTSharedLibRef _Nonnull lib);

// MARK: - Message_Msg (v0.109.0)

/// Create a message from a key and return its text. Caller must free() the result.
char* _Nullable OCCTMessageMsgGet(const char* _Nonnull key);

/// Load message definitions from a file.
bool OCCTMessageMsgFileLoad(const char* _Nonnull fileName);

/// Load the default OCCT message file.
bool OCCTMessageMsgFileLoadDefault(void);

/// Check if a message key is registered.
bool OCCTMessageMsgHasMsg(const char* _Nonnull key);

// MARK: - Plate Constraints Extensions (v0.109.0)

/// Load a global translation constraint on the plate solver.
/// All sample points are constrained to move by the same unknown displacement.
/// @param plate The Plate_Plate solver ref
/// @param uvs Array of [u,v] pairs (count*2 doubles)
/// @param count Number of UV points
/// @return true on success
bool OCCTPlateLoadGlobalTranslation(OCCTPlateRef _Nonnull plate,
                                     const double* _Nonnull uvs, int32_t count);

/// Load a linear XYZ constraint on the plate solver.
/// @param plate The Plate_Plate solver ref
/// @param uvs Array of [u,v] pairs (count*2 doubles)
/// @param targets Array of [x,y,z] target values (count*3 doubles)
/// @param coeffs Array of coefficients (count doubles)
/// @param count Number of constraint points
/// @return true on success
bool OCCTPlateLoadLinearXYZ(OCCTPlateRef _Nonnull plate,
                             const double* _Nonnull uvs,
                             const double* _Nonnull targets,
                             const double* _Nonnull coeffs,
                             int32_t count);

// MARK: - Shape Topology Counting (v0.109.0)

/// Count the number of faces in a shape.
int32_t OCCTShapeCountFaces(OCCTShapeRef _Nonnull shape);

/// Count the number of edges in a shape.
int32_t OCCTShapeCountEdges(OCCTShapeRef _Nonnull shape);

/// Get the shape type as a string. Caller must free() the result.
char* _Nullable OCCTShapeTypeString(OCCTShapeRef _Nonnull shape);

// MARK: - Curve3D Extras (v0.109.0)

/// Reverse the curve in-place.
bool OCCTCurve3DReverse(OCCTCurve3DRef _Nonnull curve);

/// Deep copy a 3D curve.
OCCTCurve3DRef _Nullable OCCTCurve3DCopy(OCCTCurve3DRef _Nonnull curve);

/// Get the continuity order of a 3D curve (0=C0, 1=C1, 2=C2, 3=C3, ...).
int32_t OCCTCurve3DContinuity(OCCTCurve3DRef _Nonnull curve);

// MARK: - Curve2D Extras (v0.109.0)

/// Reverse a 2D curve in-place.
bool OCCTCurve2DReverse(OCCTCurve2DRef _Nonnull curve);

/// Deep copy a 2D curve.
OCCTCurve2DRef _Nullable OCCTCurve2DCopy(OCCTCurve2DRef _Nonnull curve);

/// Get the continuity order of a 2D curve.
int32_t OCCTCurve2DContinuity(OCCTCurve2DRef _Nonnull curve);

// MARK: - Surface Extras (v0.109.0)

/// Get the parameter bounds of a surface.
void OCCTSurfaceBounds(OCCTSurfaceRef _Nonnull surface,
                        double* _Nonnull uMin, double* _Nonnull uMax,
                        double* _Nonnull vMin, double* _Nonnull vMax);

/// Get the continuity order of a surface (0=C0, 1=C1, 2=C2...).
int32_t OCCTSurfaceContinuity(OCCTSurfaceRef _Nonnull surface);

/// Deep copy a surface.
OCCTSurfaceRef _Nullable OCCTSurfaceCopy(OCCTSurfaceRef _Nonnull surface);

// MARK: - Math Solver Callbacks (v0.110.0)

/// Callback for 1D function with derivative: f(x) -> (value, derivative). Returns true on success.
typedef bool (*OCCTMathFuncDerivCallback)(double x, double* _Nonnull value, double* _Nonnull derivative, void* _Nullable context);

/// Callback for N-dim function: f(X[n]) -> value. Returns true on success.
typedef bool (*OCCTMathMultiVarCallback)(const double* _Nonnull x, int32_t n, double* _Nonnull value, void* _Nullable context);

/// Callback for N-dim function with gradient: f(X[n]) -> (value, grad[n]). Returns true on success.
typedef bool (*OCCTMathMultiVarGradCallback)(const double* _Nonnull x, int32_t n, double* _Nonnull value, double* _Nonnull gradient, void* _Nullable context);

/// Callback for equation system values: F(X[nVars]) -> values[nEqs]. Returns true on success.
typedef bool (*OCCTMathFuncSetCallback)(const double* _Nonnull x, int32_t nVars, double* _Nonnull values, int32_t nEqs, void* _Nullable context);

/// Callback for equation system Jacobian: J(X[nVars]) -> jacobian[nEqs*nVars] (row-major). Returns true on success.
typedef bool (*OCCTMathFuncSetDerivCallback)(const double* _Nonnull x, int32_t nVars, double* _Nonnull jacobian, int32_t nEqs, void* _Nullable context);

// MARK: - math_FunctionRoot (v0.110.0)

/// Find root of f(x)=0 near guess using Newton-Raphson. Returns root value; isDone indicates convergence.
double OCCTMathFunctionRoot(OCCTMathFuncDerivCallback _Nonnull callback, void* _Nullable context,
                             double guess, double tolerance, int32_t maxIter, bool* _Nonnull isDone);

/// Find root of f(x)=0 near guess in [a,b] using Newton-Raphson. Returns root value; isDone indicates convergence.
double OCCTMathFunctionRootBounded(OCCTMathFuncDerivCallback _Nonnull callback, void* _Nullable context,
                                     double guess, double tolerance, double a, double b, int32_t maxIter, bool* _Nonnull isDone);

/// Find root of f(x)=0 in [a,b] using bisection+Newton hybrid. Returns root value; isDone indicates convergence.
double OCCTMathBissecNewton(OCCTMathFuncDerivCallback _Nonnull callback, void* _Nullable context,
                              double a, double b, double tolerance, int32_t maxIter, bool* _Nonnull isDone);

// MARK: - math_FunctionSetRoot (v0.110.0)

/// Solve a system of nEqs equations in nVars variables using Newton's method.
/// startPoint[nVars], tolerance: scalar tolerance, result[nVars]. Returns true on convergence.
bool OCCTMathFunctionSetRoot(int32_t nVars, int32_t nEqs,
                              OCCTMathFuncSetCallback _Nonnull valueCallback,
                              OCCTMathFuncSetDerivCallback _Nonnull derivCallback,
                              void* _Nullable context,
                              const double* _Nonnull startPoint, double tolerance,
                              int32_t maxIter, double* _Nonnull result);

// MARK: - math_BFGS (v0.110.0)

/// Minimize a multivariate function using BFGS quasi-Newton method.
/// startPoint[nVars], result[nVars]. Returns true on convergence.
bool OCCTMathBFGS(int32_t nVars,
                    OCCTMathMultiVarGradCallback _Nonnull callback, void* _Nullable context,
                    const double* _Nonnull startPoint, double tolerance, int32_t maxIter,
                    double* _Nonnull result, double* _Nonnull minimum);

// MARK: - math_Powell (v0.110.0)

/// Minimize a multivariate function using Powell's method (derivative-free).
/// startPoint[nVars], result[nVars]. Returns true on convergence.
bool OCCTMathPowell(int32_t nVars,
                     OCCTMathMultiVarCallback _Nonnull callback, void* _Nullable context,
                     const double* _Nonnull startPoint, double tolerance, int32_t maxIter,
                     double* _Nonnull result, double* _Nonnull minimum);

// MARK: - math_BrentMinimum (v0.110.0)

/// Minimize a 1D function using Brent's method on [ax, cx] with initial bracket at bx.
/// Returns true on convergence; location and minimum are output.
bool OCCTMathBrentMinimum(OCCTMathFuncDerivCallback _Nonnull callback, void* _Nullable context,
                            double ax, double bx, double cx, double tolerance, int32_t maxIter,
                            double* _Nonnull location, double* _Nonnull minimum);

// MARK: - Curve3D Evaluation (v0.110.0)

/// Evaluate curve at parameter u, returning point (x, y, z).
void OCCTCurve3DEvalD0(OCCTCurve3DRef _Nonnull curve, double u, double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Evaluate curve at parameter u, returning point and first derivative.
void OCCTCurve3DEvalD1(OCCTCurve3DRef _Nonnull curve, double u,
                         double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz,
                         double* _Nonnull d1x, double* _Nonnull d1y, double* _Nonnull d1z);

/// Evaluate curve at parameter u, returning point, first and second derivatives.
void OCCTCurve3DEvalD2(OCCTCurve3DRef _Nonnull curve, double u,
                         double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz,
                         double* _Nonnull d1x, double* _Nonnull d1y, double* _Nonnull d1z,
                         double* _Nonnull d2x, double* _Nonnull d2y, double* _Nonnull d2z);

/// Evaluate curve at parameter u, returning point, first, second and third derivatives.
void OCCTCurve3DEvalD3(OCCTCurve3DRef _Nonnull curve, double u,
                         double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz,
                         double* _Nonnull d1x, double* _Nonnull d1y, double* _Nonnull d1z,
                         double* _Nonnull d2x, double* _Nonnull d2y, double* _Nonnull d2z,
                         double* _Nonnull d3x, double* _Nonnull d3y, double* _Nonnull d3z);

// MARK: - Curve2D Evaluation (v0.110.0)

/// Evaluate 2D curve at parameter u, returning point (x, y).
void OCCTCurve2DEvalD0(OCCTCurve2DRef _Nonnull curve, double u, double* _Nonnull x, double* _Nonnull y);

/// Evaluate 2D curve at parameter u, returning point and first derivative.
void OCCTCurve2DEvalD1(OCCTCurve2DRef _Nonnull curve, double u,
                         double* _Nonnull px, double* _Nonnull py,
                         double* _Nonnull d1x, double* _Nonnull d1y);

/// Evaluate 2D curve at parameter u, returning point, first and second derivatives.
void OCCTCurve2DEvalD2(OCCTCurve2DRef _Nonnull curve, double u,
                         double* _Nonnull px, double* _Nonnull py,
                         double* _Nonnull d1x, double* _Nonnull d1y,
                         double* _Nonnull d2x, double* _Nonnull d2y);

// MARK: - Surface Evaluation (v0.110.0)

/// Evaluate surface at (u, v), returning point (x, y, z).
void OCCTSurfaceEvalD0(OCCTSurfaceRef _Nonnull surface, double u, double v,
                         double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Evaluate surface at (u, v), returning point and first partial derivatives D1U, D1V.
void OCCTSurfaceEvalD1(OCCTSurfaceRef _Nonnull surface, double u, double v,
                         double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz,
                         double* _Nonnull d1ux, double* _Nonnull d1uy, double* _Nonnull d1uz,
                         double* _Nonnull d1vx, double* _Nonnull d1vy, double* _Nonnull d1vz);

/// Evaluate surface at (u, v), returning point, D1U, D1V, D2U, D2V, D2UV.
void OCCTSurfaceEvalD2(OCCTSurfaceRef _Nonnull surface, double u, double v,
                         double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz,
                         double* _Nonnull d1ux, double* _Nonnull d1uy, double* _Nonnull d1uz,
                         double* _Nonnull d1vx, double* _Nonnull d1vy, double* _Nonnull d1vz,
                         double* _Nonnull d2ux, double* _Nonnull d2uy, double* _Nonnull d2uz,
                         double* _Nonnull d2vx, double* _Nonnull d2vy, double* _Nonnull d2vz,
                         double* _Nonnull d2uvx, double* _Nonnull d2uvy, double* _Nonnull d2uvz);

// MARK: - Batch Curve Evaluation (v0.110.0)

/// Evaluate 3D curve at multiple parameters, returning points.
void OCCTCurve3DEvalBatchD0(OCCTCurve3DRef _Nonnull curve, const double* _Nonnull params, int32_t count,
                              double* _Nonnull xs, double* _Nonnull ys, double* _Nonnull zs);

/// Evaluate 3D curve at multiple parameters, returning points and first derivatives.
void OCCTCurve3DEvalBatchD1(OCCTCurve3DRef _Nonnull curve, const double* _Nonnull params, int32_t count,
                              double* _Nonnull xs, double* _Nonnull ys, double* _Nonnull zs,
                              double* _Nonnull d1xs, double* _Nonnull d1ys, double* _Nonnull d1zs);

/// Evaluate 2D curve at multiple parameters, returning points.
void OCCTCurve2DEvalBatchD0(OCCTCurve2DRef _Nonnull curve, const double* _Nonnull params, int32_t count,
                              double* _Nonnull xs, double* _Nonnull ys);

/// Evaluate 2D curve at multiple parameters, returning points and first derivatives.
void OCCTCurve2DEvalBatchD1(OCCTCurve2DRef _Nonnull curve, const double* _Nonnull params, int32_t count,
                              double* _Nonnull xs, double* _Nonnull ys,
                              double* _Nonnull d1xs, double* _Nonnull d1ys);

// MARK: - math_PSO (v0.111.0)

/// Minimize a multivariate function using Particle Swarm Optimization.
/// lower[nVars], upper[nVars], steps[nVars], result[nVars]. Returns true on success.
bool OCCTMathPSO(int32_t nVars, OCCTMathMultiVarCallback _Nonnull callback, void* _Nullable context,
                  const double* _Nonnull lower, const double* _Nonnull upper, const double* _Nonnull steps,
                  int32_t nbParticles, int32_t nbIter, double* _Nonnull result, double* _Nonnull minimum);

// MARK: - math_GlobOptMin (v0.111.0)

/// Find global minimum of a multivariate function using Lipschitz optimization.
/// lower[nVars], upper[nVars], result[nVars]. Returns true on success.
bool OCCTMathGlobOptMin(int32_t nVars, OCCTMathMultiVarCallback _Nonnull callback, void* _Nullable context,
                          const double* _Nonnull lower, const double* _Nonnull upper,
                          double* _Nonnull result, double* _Nonnull minimum);

// MARK: - math_FunctionRoots (v0.111.0)

/// Find all roots of f(x)=0 in [a, b] using derivative-based method.
/// Returns number of roots found; roots[maxRoots] is filled with values.
int32_t OCCTMathFunctionRoots(OCCTMathFuncDerivCallback _Nonnull callback, void* _Nullable context,
                                double a, double b, int32_t nbSample,
                                double* _Nonnull roots, int32_t maxRoots);

// MARK: - math_GaussSingleIntegration (v0.111.0)

/// Callback for simple 1D function (no derivative): f(x) -> value. Returns true on success.
typedef bool (*OCCTMathSimpleFuncCallback)(double x, double* _Nonnull value, void* _Nullable context);

/// Integrate a function from lower to upper using Gauss quadrature of given order.
/// Returns the integral value.
double OCCTMathGaussIntegrate(OCCTMathSimpleFuncCallback _Nonnull callback, void* _Nullable context,
                                double lower, double upper, int32_t order);

// MARK: - math_NewtonFunctionSetRoot (v0.111.0)

/// Solve a system of equations using Newton's method (NewtonFunctionSetRoot variant).
/// start[nVars], result[nVars]. Returns true on convergence.
bool OCCTMathNewtonFuncSetRoot(int32_t nVars, int32_t nEqs,
                                 OCCTMathFuncSetCallback _Nonnull valCb,
                                 OCCTMathFuncSetDerivCallback _Nonnull derivCb,
                                 void* _Nullable context,
                                 const double* _Nonnull start, double tol, int32_t maxIter,
                                 double* _Nonnull result);

// MARK: - GeomGridEval_Curve 3D (v0.111.0)

/// Evaluate 3D curve at multiple parameters using GeomGridEval_Curve (batch D0).
void OCCTGridEvalCurveD0(OCCTCurve3DRef _Nonnull curve, const double* _Nonnull params, int32_t count,
                           double* _Nonnull xs, double* _Nonnull ys, double* _Nonnull zs);

/// Evaluate 3D curve at multiple parameters using GeomGridEval_Curve (batch D1).
void OCCTGridEvalCurveD1(OCCTCurve3DRef _Nonnull curve, const double* _Nonnull params, int32_t count,
                           double* _Nonnull xs, double* _Nonnull ys, double* _Nonnull zs,
                           double* _Nonnull d1xs, double* _Nonnull d1ys, double* _Nonnull d1zs);

// MARK: - Geom2dGridEval_Curve (v0.111.0)

/// Evaluate 2D curve at multiple parameters using Geom2dGridEval_Curve (batch D0).
void OCCTGridEvalCurve2dD0(OCCTCurve2DRef _Nonnull curve, const double* _Nonnull params, int32_t count,
                              double* _Nonnull xs, double* _Nonnull ys);

/// Evaluate 2D curve at multiple parameters using Geom2dGridEval_Curve (batch D1).
void OCCTGridEvalCurve2dD1(OCCTCurve2DRef _Nonnull curve, const double* _Nonnull params, int32_t count,
                              double* _Nonnull xs, double* _Nonnull ys,
                              double* _Nonnull d1xs, double* _Nonnull d1ys);

// MARK: - GeomGridEval_Surface (v0.111.0)

/// Evaluate surface at grid of (u, v) parameters using GeomGridEval_Surface (batch D0).
/// Output arrays are row-major: xs[uCount * vCount], etc.
void OCCTGridEvalSurfaceD0(OCCTSurfaceRef _Nonnull surface,
                              const double* _Nonnull uParams, int32_t uCount,
                              const double* _Nonnull vParams, int32_t vCount,
                              double* _Nonnull xs, double* _Nonnull ys, double* _Nonnull zs);

/// Evaluate surface at grid of (u, v) parameters using GeomGridEval_Surface (batch D1).
/// Output arrays are row-major: xs[uCount * vCount], etc.
void OCCTGridEvalSurfaceD1(OCCTSurfaceRef _Nonnull surface,
                              const double* _Nonnull uParams, int32_t uCount,
                              const double* _Nonnull vParams, int32_t vCount,
                              double* _Nonnull xs, double* _Nonnull ys, double* _Nonnull zs,
                              double* _Nonnull d1uxs, double* _Nonnull d1uys, double* _Nonnull d1uzs,
                              double* _Nonnull d1vxs, double* _Nonnull d1vys, double* _Nonnull d1vzs);

// MARK: - BRepLProp_CLProps (v0.111.0)

/// Get point on edge at parameter using local properties.
void OCCTEdgeLPropValue(OCCTShapeRef _Nonnull edge, double param,
                          double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Get tangent direction on edge at parameter. Returns true if tangent is defined.
bool OCCTEdgeLPropTangent(OCCTShapeRef _Nonnull edge, double param,
                            double* _Nonnull dx, double* _Nonnull dy, double* _Nonnull dz);

/// Get curvature on edge at parameter.
double OCCTEdgeLPropCurvature(OCCTShapeRef _Nonnull edge, double param);

/// Get normal direction on edge at parameter.
void OCCTEdgeLPropNormal(OCCTShapeRef _Nonnull edge, double param,
                           double* _Nonnull dx, double* _Nonnull dy, double* _Nonnull dz);

/// Get centre of curvature on edge at parameter.
void OCCTEdgeLPropCentreOfCurvature(OCCTShapeRef _Nonnull edge, double param,
                                       double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Get first derivative on edge at parameter.
void OCCTEdgeLPropD1(OCCTShapeRef _Nonnull edge, double param,
                       double* _Nonnull d1x, double* _Nonnull d1y, double* _Nonnull d1z);

// MARK: - BRepLProp_SLProps (v0.111.0)

/// Get point on face at (u, v) using local surface properties.
void OCCTFaceLPropValue(OCCTShapeRef _Nonnull face, double u, double v,
                          double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Get normal on face at (u, v). Returns true if normal is defined.
bool OCCTFaceLPropNormal(OCCTShapeRef _Nonnull face, double u, double v,
                           double* _Nonnull dx, double* _Nonnull dy, double* _Nonnull dz);

/// Get maximum curvature on face at (u, v).
double OCCTFaceLPropMaxCurvature(OCCTShapeRef _Nonnull face, double u, double v);

/// Get minimum curvature on face at (u, v).
double OCCTFaceLPropMinCurvature(OCCTShapeRef _Nonnull face, double u, double v);

/// Get mean curvature on face at (u, v).
double OCCTFaceLPropMeanCurvature(OCCTShapeRef _Nonnull face, double u, double v);

/// Get Gaussian curvature on face at (u, v).
double OCCTFaceLPropGaussianCurvature(OCCTShapeRef _Nonnull face, double u, double v);

/// Check if face at (u, v) is umbilic (all curvatures equal).
bool OCCTFaceLPropIsUmbilic(OCCTShapeRef _Nonnull face, double u, double v);

/// Get tangent in U direction on face at (u, v). Returns true if tangent is defined.
bool OCCTFaceLPropTangentU(OCCTShapeRef _Nonnull face, double u, double v,
                              double* _Nonnull dx, double* _Nonnull dy, double* _Nonnull dz);

// MARK: - MathPoly_Laguerre (v0.111.0)

/// Find real roots of a polynomial using Laguerre's method.
/// coefficients[degree+1] in ascending order (constant first). Returns number of real roots found.
int32_t OCCTPolyLaguerreRoots(const double* _Nonnull coefficients, int32_t degree,
                                double* _Nonnull roots, int32_t maxRoots);

/// Find complex roots of a polynomial using Laguerre's method.
/// Returns number of complex roots found; realParts[maxRoots], imagParts[maxRoots].
int32_t OCCTPolyLaguerreComplexRoots(const double* _Nonnull coefficients, int32_t degree,
                                        double* _Nonnull realParts, double* _Nonnull imagParts, int32_t maxRoots);

/// Find real roots of quintic: a*x^5 + b*x^4 + c*x^3 + d*x^2 + e*x + f = 0.
/// Returns number of real roots found.
int32_t OCCTPolyQuinticRoots(double a, double b, double c, double d, double e, double f,
                                double* _Nonnull roots, int32_t maxRoots);

// MARK: - math_NewtonMinimum (v0.111.1)

/// Callback for N-dim function with gradient AND Hessian.
/// hessian is row-major n*n matrix.
typedef bool (*OCCTMathHessianCallback)(const double* _Nonnull x, int32_t n,
                                         double* _Nonnull value,
                                         double* _Nonnull gradient,
                                         double* _Nonnull hessian,
                                         void* _Nullable context);

/// Minimize using Newton's method with Hessian.
/// Returns true if converged. result is n-element array.
bool OCCTMathNewtonMinimum(int32_t nVars,
                             OCCTMathHessianCallback _Nonnull callback, void* _Nullable context,
                             const double* _Nonnull startPoint,
                             double tolerance, int32_t maxIter,
                             double* _Nonnull result, double* _Nonnull minimum);

// MARK: - v0.112.0: RWMesh iterators, Intf_Tool, BRepAlgo_AsDes, BiTgte_CurveOnEdge, Shape extras, Extrema

// --- RWMesh_FaceIterator ---

/// Opaque handle for face mesh iterator.
typedef struct OCCTMeshFaceIter* OCCTMeshFaceIterRef;

/// Create a face iterator over a meshed shape.
OCCTMeshFaceIterRef _Nullable OCCTMeshFaceIterCreate(OCCTShapeRef _Nonnull shape);

/// Release a face iterator.
void OCCTMeshFaceIterRelease(OCCTMeshFaceIterRef _Nonnull iter);

/// Check if the iterator has more faces.
bool OCCTMeshFaceIterMore(OCCTMeshFaceIterRef _Nonnull iter);

/// Advance to the next face.
void OCCTMeshFaceIterNext(OCCTMeshFaceIterRef _Nonnull iter);

/// Number of nodes in the current face triangulation.
int32_t OCCTMeshFaceIterNbNodes(OCCTMeshFaceIterRef _Nonnull iter);

/// Number of triangles in the current face triangulation.
int32_t OCCTMeshFaceIterNbTriangles(OCCTMeshFaceIterRef _Nonnull iter);

/// Get node position at 1-based index (transformed).
void OCCTMeshFaceIterNode(OCCTMeshFaceIterRef _Nonnull iter, int32_t index,
                          double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Check if current face has normals.
bool OCCTMeshFaceIterHasNormals(OCCTMeshFaceIterRef _Nonnull iter);

/// Get normal at 1-based node index (transformed).
void OCCTMeshFaceIterNormal(OCCTMeshFaceIterRef _Nonnull iter, int32_t index,
                            double* _Nonnull nx, double* _Nonnull ny, double* _Nonnull nz);

/// Get triangle node indices at 1-based triangle index (oriented).
void OCCTMeshFaceIterTriangle(OCCTMeshFaceIterRef _Nonnull iter, int32_t index,
                              int32_t* _Nonnull n1, int32_t* _Nonnull n2, int32_t* _Nonnull n3);

// --- RWMesh_VertexIterator ---

/// Opaque handle for vertex mesh iterator.
typedef struct OCCTMeshVertexIter* OCCTMeshVertexIterRef;

/// Create a vertex iterator over a shape.
OCCTMeshVertexIterRef _Nullable OCCTMeshVertexIterCreate(OCCTShapeRef _Nonnull shape);

/// Release a vertex iterator.
void OCCTMeshVertexIterRelease(OCCTMeshVertexIterRef _Nonnull iter);

/// Check if the iterator has more vertices.
bool OCCTMeshVertexIterMore(OCCTMeshVertexIterRef _Nonnull iter);

/// Advance to the next vertex.
void OCCTMeshVertexIterNext(OCCTMeshVertexIterRef _Nonnull iter);

/// Get the current vertex point.
void OCCTMeshVertexIterPoint(OCCTMeshVertexIterRef _Nonnull iter,
                             double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

// --- Intf_Tool ---

/// Opaque handle for Intf_Tool line-box clipping.
typedef struct OCCTIntfTool* OCCTIntfToolRef;

/// Create an Intf_Tool instance.
OCCTIntfToolRef _Nonnull OCCTIntfToolCreate(void);

/// Release an Intf_Tool instance.
void OCCTIntfToolRelease(OCCTIntfToolRef _Nonnull tool);

/// Clip a line to a bounding box. Returns number of segments.
int32_t OCCTIntfToolLinBox(OCCTIntfToolRef _Nonnull tool,
                           double px, double py, double pz,
                           double dx, double dy, double dz,
                           double xmin, double ymin, double zmin,
                           double xmax, double ymax, double zmax);

/// Get the begin parameter of a segment (1-based index).
double OCCTIntfToolBeginParam(OCCTIntfToolRef _Nonnull tool, int32_t segIndex);

/// Get the end parameter of a segment (1-based index).
double OCCTIntfToolEndParam(OCCTIntfToolRef _Nonnull tool, int32_t segIndex);

// --- BRepAlgo_AsDes ---

/// Opaque handle for BRepAlgo_AsDes ascendant-descendant tracker.
typedef struct OCCTAsDes* OCCTAsDesRef;

/// Create an AsDes tracker.
OCCTAsDesRef _Nonnull OCCTAsDesCreate(void);

/// Release an AsDes tracker.
void OCCTAsDesRelease(OCCTAsDesRef _Nonnull ad);

/// Add a parent-child relationship.
void OCCTAsDesAdd(OCCTAsDesRef _Nonnull ad, OCCTShapeRef _Nonnull parent, OCCTShapeRef _Nonnull child);

/// Check if a shape has descendants.
bool OCCTAsDesHasDescendant(OCCTAsDesRef _Nonnull ad, OCCTShapeRef _Nonnull shape);

/// Get number of descendants for a shape.
int32_t OCCTAsDesDescendantCount(OCCTAsDesRef _Nonnull ad, OCCTShapeRef _Nonnull shape);

// --- BiTgte_CurveOnEdge ---

/// Opaque handle for BiTgte_CurveOnEdge.
typedef struct OCCTBiTgteCurveOnEdge* OCCTBiTgteCurveOnEdgeRef;

/// Create a curve-on-edge adaptor.
OCCTBiTgteCurveOnEdgeRef _Nullable OCCTBiTgteCurveOnEdgeCreate(
    OCCTShapeRef _Nonnull edgeOnFace, OCCTShapeRef _Nonnull edge);

/// Release a curve-on-edge.
void OCCTBiTgteCurveOnEdgeRelease(OCCTBiTgteCurveOnEdgeRef _Nonnull curve);

/// Get the parameter domain.
void OCCTBiTgteCurveOnEdgeDomain(OCCTBiTgteCurveOnEdgeRef _Nonnull curve,
                                 double* _Nonnull first, double* _Nonnull last);

/// Evaluate point at parameter u.
void OCCTBiTgteCurveOnEdgeValue(OCCTBiTgteCurveOnEdgeRef _Nonnull curve, double u,
                                double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

// --- Additional Shape operations ---

/// Get child shape at 0-based index.
OCCTShapeRef _Nullable OCCTShapeChild(OCCTShapeRef _Nonnull shape, int32_t index);

/// Check if shape is locked.
bool OCCTShapeIsLocked(OCCTShapeRef _Nonnull shape);

/// Set locked state on a shape.
void OCCTShapeSetLocked(OCCTShapeRef _Nonnull shape, bool locked);

/// Create a shape with an applied location transform (4x3 row-major matrix).
OCCTShapeRef _Nullable OCCTShapeLocated(OCCTShapeRef _Nonnull shape, const double* _Nonnull matrix12);

/// Get the current location transform as a 4x3 row-major matrix.
void OCCTShapeGetLocation(OCCTShapeRef _Nonnull shape, double* _Nonnull matrix12);

/// Set location transform in-place (4x3 row-major matrix).
void OCCTShapeSetLocation(OCCTShapeRef _Nonnull shape, const double* _Nonnull matrix12);

/// Create a shape with a specific orientation (0=FWD, 1=REV, 2=INT, 3=EXT).
OCCTShapeRef _Nullable OCCTShapeOriented(OCCTShapeRef _Nonnull shape, int32_t orientation);

/// Create a compound from an array of shapes.
OCCTShapeRef _Nullable OCCTShapeCompounded(const OCCTShapeRef _Nonnull * _Nonnull shapes, int32_t count);

/// Create an empty shape of a given type (0=COMPOUND..7=VERTEX).
OCCTShapeRef _Nullable OCCTShapeEmpty(int32_t type);

// --- Wire/Face construction ---

/// Create a wire from an array of edge shapes.
OCCTShapeRef _Nullable OCCTMakeWireFromEdges(const OCCTShapeRef _Nonnull * _Nonnull edges, int32_t count);

/// Create a compound from an array of shapes.
OCCTShapeRef _Nullable OCCTMakeCompound(const OCCTShapeRef _Nonnull * _Nonnull shapes, int32_t count);

/// Create a shell from an array of face shapes.
OCCTShapeRef _Nullable OCCTMakeShell(const OCCTShapeRef _Nonnull * _Nonnull faces, int32_t count);

/// Check if shape is a compound.
bool OCCTShapeIsCompound(OCCTShapeRef _Nonnull shape);

/// Check if shape is a solid.
bool OCCTShapeIsSolid(OCCTShapeRef _Nonnull shape);

/// Check if shape is a shell.
bool OCCTShapeIsShell(OCCTShapeRef _Nonnull shape);

/// Check if shape is a face.
bool OCCTShapeIsFace(OCCTShapeRef _Nonnull shape);

/// Check if shape is an edge.
bool OCCTShapeIsEdge(OCCTShapeRef _Nonnull shape);

// --- BRepCheck extended ---

/// Check status of a specific face within a shape. Returns BRepCheck_Status enum.
int32_t OCCTCheckFaceStatus(OCCTShapeRef _Nonnull shape, OCCTShapeRef _Nonnull face);

/// Check status of a specific edge within a shape.
int32_t OCCTCheckEdgeStatus(OCCTShapeRef _Nonnull shape, OCCTShapeRef _Nonnull edge);

/// Check status of a specific vertex within a shape.
int32_t OCCTCheckVertexStatus(OCCTShapeRef _Nonnull shape, OCCTShapeRef _Nonnull vertex);

/// Get max tolerance of sub-shapes of given type (0=vertex, 1=edge, 2=face).
double OCCTShapeMaxTolerance(OCCTShapeRef _Nonnull shape, int32_t type);

/// Get min tolerance of sub-shapes of given type.
double OCCTShapeMinTolerance(OCCTShapeRef _Nonnull shape, int32_t type);

/// Get average tolerance of sub-shapes of given type.
double OCCTShapeAvgTolerance(OCCTShapeRef _Nonnull shape, int32_t type);

/// Fix tolerance on a shape to specified value. Returns true on success.
bool OCCTShapeFixTolerance(OCCTShapeRef _Nonnull shape, double tolerance);

/// Limit max tolerance on a shape. Returns true on success.
bool OCCTShapeLimitMaxTolerance(OCCTShapeRef _Nonnull shape, double maxTol);

// --- Curve3D extras ---

/// Get the curve type enum (GeomAbs_CurveType: 0=Line..7=OtherCurve).
int32_t OCCTCurve3DCurveType(OCCTCurve3DRef _Nonnull curve);

/// Find parameter on curve nearest to a 3D point.
double OCCTCurve3DParameterAtPoint(OCCTCurve3DRef _Nonnull curve,
                                   double x, double y, double z);

// --- Curve2D extras ---

/// Get the 2D curve type enum.
int32_t OCCTCurve2DCurveType(OCCTCurve2DRef _Nonnull curve);

/// Find parameter on 2D curve nearest to a 2D point.
double OCCTCurve2DParameterAtPoint(OCCTCurve2DRef _Nonnull curve,
                                   double x, double y);

// --- Surface extras ---

/// Get the surface type enum (GeomAbs_SurfaceType: 0=Plane..10=OtherSurface).
int32_t OCCTSurfaceGetType(OCCTSurfaceRef _Nonnull surface);

// --- Extrema extras ---

/// Local point-on-curve search from initial parameter guess.
bool OCCTExtremaLocateOnCurve(OCCTCurve3DRef _Nonnull curve,
                              double px, double py, double pz,
                              double initParam, double tol,
                              double* _Nonnull param, double* _Nonnull distance);

/// Local point-on-surface search from initial (u,v) guess.
bool OCCTExtremaLocateOnSurface(OCCTSurfaceRef _Nonnull surface,
                                double px, double py, double pz,
                                double initU, double initV, double tol,
                                double* _Nonnull u, double* _Nonnull v, double* _Nonnull distance);

/// Global point-to-curve extrema. Returns number of solutions found.
int32_t OCCTExtremaPointCurve(OCCTCurve3DRef _Nonnull curve,
                              double px, double py, double pz,
                              double* _Nonnull params, double* _Nonnull distances, int32_t maxResults);

/// Global point-to-surface extrema. Returns number of solutions found.
int32_t OCCTExtremaPointSurface(OCCTSurfaceRef _Nonnull surface,
                                double px, double py, double pz,
                                double* _Nonnull us, double* _Nonnull vs, double* _Nonnull distances,
                                int32_t maxResults);

// MARK: - v0.113.0: MakeEdge completions, ProjOnCurve/Surf, DistShapeShape, ShapeFix_Wire/Face,
//                    MakeFace extras, IntCS, BSplineCurve/Surface mutations

// --- BRepBuilderAPI_MakeEdge completions ---

/// Create a full ellipse edge.
OCCTShapeRef _Nullable OCCTMakeEdgeFromEllipse(double cx, double cy, double cz,
                                                double nx, double ny, double nz,
                                                double major, double minor);

/// Create an ellipse arc edge between parameters u1 and u2.
OCCTShapeRef _Nullable OCCTMakeEdgeFromEllipseArc(double cx, double cy, double cz,
                                                    double nx, double ny, double nz,
                                                    double major, double minor,
                                                    double u1, double u2);

/// Create a hyperbola arc edge between parameters u1 and u2.
OCCTShapeRef _Nullable OCCTMakeEdgeFromHyperbolaArc(double cx, double cy, double cz,
                                                      double nx, double ny, double nz,
                                                      double major, double minor,
                                                      double u1, double u2);

/// Create a parabola arc edge between parameters u1 and u2.
OCCTShapeRef _Nullable OCCTMakeEdgeFromParabolaArc(double cx, double cy, double cz,
                                                     double nx, double ny, double nz,
                                                     double focal, double u1, double u2);

/// Create an edge from a Geom_Curve (full domain).
OCCTShapeRef _Nullable OCCTMakeEdgeFromCurve(OCCTCurve3DRef _Nonnull curve);

/// Create an edge from a Geom_Curve with parameter bounds.
OCCTShapeRef _Nullable OCCTMakeEdgeFromCurveParams(OCCTCurve3DRef _Nonnull curve, double u1, double u2);

/// Create an edge from a Geom_Curve with point bounds.
OCCTShapeRef _Nullable OCCTMakeEdgeFromCurvePoints(OCCTCurve3DRef _Nonnull curve,
                                                     double x1, double y1, double z1,
                                                     double x2, double y2, double z2);

/// Create an edge from a 2D pcurve on a surface (full domain).
OCCTShapeRef _Nullable OCCTMakeEdgeOnSurface(OCCTCurve2DRef _Nonnull pcurve,
                                               OCCTSurfaceRef _Nonnull surface);

/// Create an edge from a 2D pcurve on a surface with parameter bounds.
OCCTShapeRef _Nullable OCCTMakeEdgeOnSurfaceParams(OCCTCurve2DRef _Nonnull pcurve,
                                                     OCCTSurfaceRef _Nonnull surface,
                                                     double u1, double u2);

/// Get the first vertex point of an edge.
void OCCTEdgeVertex1(OCCTShapeRef _Nonnull edge, double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Get the last vertex point of an edge.
void OCCTEdgeVertex2(OCCTShapeRef _Nonnull edge, double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Get the BRepBuilderAPI_EdgeError for the last MakeEdge (0=done, 1=PointProjectionFailed, etc).
int32_t OCCTMakeEdgeError(OCCTShapeRef _Nonnull edge);

// --- GeomAPI_ProjectPointOnCurve (multi-result) ---

typedef struct OCCTProjOnCurve* OCCTProjOnCurveRef;

/// Create a multi-result projection of a point onto a curve.
OCCTProjOnCurveRef _Nullable OCCTProjOnCurveCreate(OCCTCurve3DRef _Nonnull curve,
                                                     double px, double py, double pz);

/// Release a projection on curve object.
void OCCTProjOnCurveRelease(OCCTProjOnCurveRef _Nonnull proj);

/// Number of projection results.
int32_t OCCTProjOnCurveNbPoints(OCCTProjOnCurveRef _Nonnull proj);

/// Get the i-th projection point (1-based index).
void OCCTProjOnCurvePoint(OCCTProjOnCurveRef _Nonnull proj, int32_t index,
                           double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Get the parameter of the i-th projection (1-based).
double OCCTProjOnCurveParameter(OCCTProjOnCurveRef _Nonnull proj, int32_t index);

/// Get the distance of the i-th projection (1-based).
double OCCTProjOnCurveDistance(OCCTProjOnCurveRef _Nonnull proj, int32_t index);

/// Get the minimum distance across all projections.
double OCCTProjOnCurveLowerDistance(OCCTProjOnCurveRef _Nonnull proj);

/// Get the parameter of the nearest projection.
double OCCTProjOnCurveLowerParam(OCCTProjOnCurveRef _Nonnull proj);

// --- GeomAPI_ProjectPointOnSurf (multi-result) ---

typedef struct OCCTProjOnSurf* OCCTProjOnSurfRef;

/// Create a multi-result projection of a point onto a surface.
OCCTProjOnSurfRef _Nullable OCCTProjOnSurfCreate(OCCTSurfaceRef _Nonnull surface,
                                                   double px, double py, double pz);

/// Release a projection on surface object.
void OCCTProjOnSurfRelease(OCCTProjOnSurfRef _Nonnull proj);

/// Number of projection results.
int32_t OCCTProjOnSurfNbPoints(OCCTProjOnSurfRef _Nonnull proj);

/// Get the i-th projection point (1-based index).
void OCCTProjOnSurfPoint(OCCTProjOnSurfRef _Nonnull proj, int32_t index,
                          double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Get the (u,v) parameters of the i-th projection (1-based).
void OCCTProjOnSurfParameters(OCCTProjOnSurfRef _Nonnull proj, int32_t index,
                               double* _Nonnull u, double* _Nonnull v);

/// Get the distance of the i-th projection (1-based).
double OCCTProjOnSurfDistance(OCCTProjOnSurfRef _Nonnull proj, int32_t index);

/// Get the minimum distance across all projections.
double OCCTProjOnSurfLowerDistance(OCCTProjOnSurfRef _Nonnull proj);

/// Get the (u,v) parameters of the nearest projection.
void OCCTProjOnSurfLowerParams(OCCTProjOnSurfRef _Nonnull proj,
                                double* _Nonnull u, double* _Nonnull v);

// --- BRepExtrema_DistShapeShape (full results) ---

typedef struct OCCTDistSS* OCCTDistSSRef;

/// Create a distance computation between two shapes.
OCCTDistSSRef _Nullable OCCTDistSSCreate(OCCTShapeRef _Nonnull s1, OCCTShapeRef _Nonnull s2);

/// Release a DistShapeShape object.
void OCCTDistSSRelease(OCCTDistSSRef _Nonnull dist);

/// Check if distance computation succeeded.
bool OCCTDistSSIsDone(OCCTDistSSRef _Nonnull dist);

/// Get the minimum distance value.
double OCCTDistSSValue(OCCTDistSSRef _Nonnull dist);

/// Get the number of solutions.
int32_t OCCTDistSSNbSolution(OCCTDistSSRef _Nonnull dist);

/// Get the i-th point on shape 1 (1-based).
void OCCTDistSSPointOnShape1(OCCTDistSSRef _Nonnull dist, int32_t index,
                              double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Get the i-th point on shape 2 (1-based).
void OCCTDistSSPointOnShape2(OCCTDistSSRef _Nonnull dist, int32_t index,
                              double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Get the support type on shape 1 (0=vertex, 1=edge, 2=face).
int32_t OCCTDistSSSupportType1(OCCTDistSSRef _Nonnull dist, int32_t index);

/// Get the support type on shape 2 (0=vertex, 1=edge, 2=face).
int32_t OCCTDistSSSupportType2(OCCTDistSSRef _Nonnull dist, int32_t index);

/// Get the support sub-shape on shape 1 (1-based).
OCCTShapeRef _Nullable OCCTDistSSSupportShape1(OCCTDistSSRef _Nonnull dist, int32_t index);

/// Get the support sub-shape on shape 2 (1-based).
OCCTShapeRef _Nullable OCCTDistSSSupportShape2(OCCTDistSSRef _Nonnull dist, int32_t index);

// --- ShapeFix_Wire individual fixes ---

typedef struct OCCTWireFixer* OCCTWireFixerRef;

/// Create a wire fixer from a wire shape on a face with given precision.
OCCTWireFixerRef _Nullable OCCTWireFixerCreate(OCCTShapeRef _Nonnull wire,
                                                 OCCTShapeRef _Nonnull face,
                                                 double precision);

/// Release a wire fixer.
void OCCTWireFixerRelease(OCCTWireFixerRef _Nonnull fixer);

/// Fix the order of edges in the wire.
bool OCCTWireFixerFixReorder(OCCTWireFixerRef _Nonnull fixer);

/// Fix connectivity of edges.
bool OCCTWireFixerFixConnected(OCCTWireFixerRef _Nonnull fixer);

/// Fix small edges.
bool OCCTWireFixerFixSmall(OCCTWireFixerRef _Nonnull fixer, double precSmall);

/// Fix degenerated edges.
bool OCCTWireFixerFixDegenerated(OCCTWireFixerRef _Nonnull fixer);

/// Fix self-intersection.
bool OCCTWireFixerFixSelfIntersection(OCCTWireFixerRef _Nonnull fixer);

/// Fix lacking edges.
bool OCCTWireFixerFixLacking(OCCTWireFixerRef _Nonnull fixer);

/// Fix closed wire.
bool OCCTWireFixerFixClosed(OCCTWireFixerRef _Nonnull fixer);

/// Fix 3D gaps between edges.
bool OCCTWireFixerFixGaps3d(OCCTWireFixerRef _Nonnull fixer);

/// Fix edge curves.
bool OCCTWireFixerFixEdgeCurves(OCCTWireFixerRef _Nonnull fixer);

/// Get the resulting fixed wire.
OCCTShapeRef _Nullable OCCTWireFixerWire(OCCTWireFixerRef _Nonnull fixer);

// --- ShapeFix_Face individual fixes ---

typedef struct OCCTFaceFixer* OCCTFaceFixerRef;

/// Create a face fixer from a face shape with given precision.
OCCTFaceFixerRef _Nullable OCCTFaceFixerCreate(OCCTShapeRef _Nonnull face, double precision);

/// Release a face fixer.
void OCCTFaceFixerRelease(OCCTFaceFixerRef _Nonnull fixer);

/// Perform all fixes on the face.
bool OCCTFaceFixerPerform(OCCTFaceFixerRef _Nonnull fixer);

/// Fix orientation of wires.
bool OCCTFaceFixerFixOrientation(OCCTFaceFixerRef _Nonnull fixer);

/// Add natural bound (outer wire) if missing.
bool OCCTFaceFixerFixAddNaturalBound(OCCTFaceFixerRef _Nonnull fixer);

/// Fix missing seam edge.
bool OCCTFaceFixerFixMissingSeam(OCCTFaceFixerRef _Nonnull fixer);

/// Fix small area wires.
bool OCCTFaceFixerFixSmallAreaWire(OCCTFaceFixerRef _Nonnull fixer);

/// Get the resulting fixed face.
OCCTShapeRef _Nullable OCCTFaceFixerFace(OCCTFaceFixerRef _Nonnull fixer);

// --- BRepBuilderAPI_MakeFace completions ---

/// Create a face from a Geom_Surface with UV bounds and tolerance.
OCCTShapeRef _Nullable OCCTMakeFaceFromSurfaceUV(OCCTSurfaceRef _Nonnull surface,
                                                   double umin, double umax,
                                                   double vmin, double vmax, double tol);

/// Create a face from a gp_Plane with UV bounds.
OCCTShapeRef _Nullable OCCTMakeFaceFromGpPlane(double px, double py, double pz,
                                                 double nx, double ny, double nz,
                                                 double umin, double umax,
                                                 double vmin, double vmax);

/// Create a face from a gp_Cylinder with UV bounds.
OCCTShapeRef _Nullable OCCTMakeFaceFromGpCylinder(double cx, double cy, double cz,
                                                    double nx, double ny, double nz,
                                                    double radius,
                                                    double umin, double umax,
                                                    double vmin, double vmax);

// --- GeomAPI_IntCS full results ---

typedef struct OCCTIntCS* OCCTIntCSRef;

/// Create a curve-surface intersection computation.
OCCTIntCSRef _Nullable OCCTIntCSCreate(OCCTCurve3DRef _Nonnull curve,
                                        OCCTSurfaceRef _Nonnull surface);

/// Release an IntCS object.
void OCCTIntCSRelease(OCCTIntCSRef _Nonnull intcs);

/// Number of intersection points.
int32_t OCCTIntCSNbPoints(OCCTIntCSRef _Nonnull intcs);

/// Get the i-th intersection point (1-based) with curve param (w) and surface params (u,v).
void OCCTIntCSPoint(OCCTIntCSRef _Nonnull intcs, int32_t index,
                     double* _Nonnull x, double* _Nonnull y, double* _Nonnull z,
                     double* _Nonnull w, double* _Nonnull u, double* _Nonnull v);

/// Number of intersection segments.
int32_t OCCTIntCSNbSegments(OCCTIntCSRef _Nonnull intcs);

// --- BSplineCurve remaining mutations ---

/// Set the knot value at a given index (1-based).
bool OCCTCurve3DBSplineSetKnot(OCCTCurve3DRef _Nonnull curve, int32_t index, double knot);

/// Get the full knot sequence (with multiplicities expanded). Caller must pre-allocate knotSeq.
/// Returns the count in *count.
void OCCTCurve3DBSplineGetKnotSequence(OCCTCurve3DRef _Nonnull curve,
                                        double* _Nonnull knotSeq, int32_t* _Nonnull count);

/// Get all weights (one per pole). Caller must pre-allocate weights array.
void OCCTCurve3DBSplineGetWeights(OCCTCurve3DRef _Nonnull curve, double* _Nonnull weights);

/// Insert multiple knots at once with specified multiplicities.
bool OCCTCurve3DBSplineInsertKnots(OCCTCurve3DRef _Nonnull curve,
                                     const double* _Nonnull knots,
                                     const int32_t* _Nonnull mults,
                                     int32_t count, double tol);

/// Move a point on the curve to a new position. index1/index2 define the pole range to modify.
bool OCCTCurve3DBSplineMovePoint(OCCTCurve3DRef _Nonnull curve, double u,
                                   double x, double y, double z,
                                   int32_t index1, int32_t index2);

/// Evaluate the curve locally within a knot span (fromK1..toK2 are 1-based knot indices).
void OCCTCurve3DBSplineLocalValue(OCCTCurve3DRef _Nonnull curve, double u,
                                    int32_t fromK1, int32_t toK2,
                                    double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Get the maximum BSpline degree supported (static).
int32_t OCCTCurve3DBSplineMaxDegree(void);

/// Locate the knot span containing parameter u.
int32_t OCCTCurve3DBSplineLocateU(OCCTCurve3DRef _Nonnull curve, double u, double tol);

// --- BSplineSurface remaining mutations ---

/// Set U knot at given index (1-based).
bool OCCTSurfaceBSplineSetUKnot(OCCTSurfaceRef _Nonnull surface, int32_t index, double knot);

/// Set V knot at given index (1-based).
bool OCCTSurfaceBSplineSetVKnot(OCCTSurfaceRef _Nonnull surface, int32_t index, double knot);

/// Get all U knots. Caller must pre-allocate array of size NbUKnots.
void OCCTSurfaceBSplineGetUKnots(OCCTSurfaceRef _Nonnull surface, double* _Nonnull knots);

/// Get all V knots. Caller must pre-allocate array of size NbVKnots.
void OCCTSurfaceBSplineGetVKnots(OCCTSurfaceRef _Nonnull surface, double* _Nonnull knots);

/// Get all weights. Caller must pre-allocate array of size NbUPoles * NbVPoles (row-major).
void OCCTSurfaceBSplineGetWeights(OCCTSurfaceRef _Nonnull surface,
                                    double* _Nonnull weights,
                                    int32_t* _Nonnull rows, int32_t* _Nonnull cols);

/// Remove a U knot. Returns true if successful.
bool OCCTSurfaceBSplineRemoveUKnot(OCCTSurfaceRef _Nonnull surface,
                                     int32_t index, int32_t mult, double tol);

// MARK: - v0.114.0: TopoDS_Builder, ShapeContents expanded, FreeBoundsProperties, WireBuilder,
//                    Boolean tolerances, Offset wire/face, ThickSolid tolerance, BRepLib utilities,
//                    Mass properties expansion, Curve isBounded

// --- TopoDS_Builder ---

/// Create an empty wire via TopoDS_Builder.
OCCTShapeRef _Nullable OCCTBuilderMakeWire(void);

/// Create an empty shell via TopoDS_Builder.
OCCTShapeRef _Nullable OCCTBuilderMakeShell(void);

/// Create an empty solid via TopoDS_Builder.
OCCTShapeRef _Nullable OCCTBuilderMakeSolid(void);

/// Create an empty compound via TopoDS_Builder.
OCCTShapeRef _Nullable OCCTBuilderMakeCompound(void);

/// Create an empty comp-solid via TopoDS_Builder.
OCCTShapeRef _Nullable OCCTBuilderMakeCompSolid(void);

/// Add child shape into parent shape using TopoDS_Builder.
bool OCCTBuilderAdd(OCCTShapeRef _Nonnull parent, OCCTShapeRef _Nonnull child);

/// Remove child shape from parent shape using TopoDS_Builder.
bool OCCTBuilderRemove(OCCTShapeRef _Nonnull parent, OCCTShapeRef _Nonnull child);

// --- ShapeAnalysis_ShapeContents expanded ---

/// Extended shape contents structure with additional detail counts.
typedef struct {
    int32_t nbSolids;
    int32_t nbShells;
    int32_t nbFaces;
    int32_t nbWires;
    int32_t nbEdges;
    int32_t nbVertices;
    int32_t nbFreeEdges;
    int32_t nbFreeWires;
    int32_t nbFreeFaces;
    int32_t nbSolidsWithVoids;
    int32_t nbBigSplines;
    int32_t nbC0Surfaces;
    int32_t nbC0Curves;
    int32_t nbOffsetSurf;
    int32_t nbIndirectSurf;
    int32_t nbOffsetCurves;
    int32_t nbTrimmedCurve2d;
    int32_t nbTrimmedCurve3d;
    int32_t nbBSplineSurf;
    int32_t nbBezierSurf;
    int32_t nbTrimSurf;
    int32_t nbWireWithSeam;
    int32_t nbWireWithSevSeams;
    int32_t nbFaceWithSevWires;
    int32_t nbNoPCurve;
    int32_t nbSharedSolids;
    int32_t nbSharedShells;
    int32_t nbSharedFaces;
    int32_t nbSharedWires;
    int32_t nbSharedEdges;
    int32_t nbSharedVertices;
} OCCTShapeContentsExtended;

/// Get extended shape contents analysis.
OCCTShapeContentsExtended OCCTShapeGetContentsExtended(OCCTShapeRef _Nonnull shape);

// --- ShapeAnalysis_FreeBoundsProperties (handle-based) ---

typedef struct OCCTFreeBoundsProps* OCCTFreeBoundsPropsRef;

/// Create a FreeBoundsProperties analyzer.
OCCTFreeBoundsPropsRef _Nullable OCCTFreeBoundsPropsCreate(OCCTShapeRef _Nonnull shape, double tolerance);

/// Release a FreeBoundsProperties analyzer.
void OCCTFreeBoundsPropsRelease(OCCTFreeBoundsPropsRef _Nonnull props);

/// Perform the analysis.
bool OCCTFreeBoundsPropsPerform(OCCTFreeBoundsPropsRef _Nonnull props);

/// Number of closed free bounds.
int32_t OCCTFreeBoundsPropsNbClosedFreeBounds(OCCTFreeBoundsPropsRef _Nonnull props);

/// Number of open free bounds.
int32_t OCCTFreeBoundsPropsNbOpenFreeBounds(OCCTFreeBoundsPropsRef _Nonnull props);

/// Get area of closed free bound by 1-based index.
double OCCTFreeBoundsPropsClosedArea(OCCTFreeBoundsPropsRef _Nonnull props, int32_t index);

/// Get perimeter of closed free bound by 1-based index.
double OCCTFreeBoundsPropsClosedPerimeter(OCCTFreeBoundsPropsRef _Nonnull props, int32_t index);

/// Get ratio (length/width) of closed free bound by 1-based index.
double OCCTFreeBoundsPropsClosedRatio(OCCTFreeBoundsPropsRef _Nonnull props, int32_t index);

/// Get width of closed free bound by 1-based index.
double OCCTFreeBoundsPropsClosedWidth(OCCTFreeBoundsPropsRef _Nonnull props, int32_t index);

/// Get wire of closed free bound by 1-based index.
OCCTShapeRef _Nullable OCCTFreeBoundsPropsClosedWire(OCCTFreeBoundsPropsRef _Nonnull props, int32_t index);

/// Get area of open free bound by 1-based index.
double OCCTFreeBoundsPropsOpenArea(OCCTFreeBoundsPropsRef _Nonnull props, int32_t index);

/// Get perimeter of open free bound by 1-based index.
double OCCTFreeBoundsPropsOpenPerimeter(OCCTFreeBoundsPropsRef _Nonnull props, int32_t index);

/// Get wire of open free bound by 1-based index.
OCCTShapeRef _Nullable OCCTFreeBoundsPropsOpenWire(OCCTFreeBoundsPropsRef _Nonnull props, int32_t index);

// --- BRepBuilderAPI_MakeWire (incremental) ---

typedef struct OCCTWireBuilder* OCCTWireBuilderRef;

/// Create an empty wire builder.
OCCTWireBuilderRef _Nonnull OCCTWireBuilderCreate(void);

/// Release a wire builder.
void OCCTWireBuilderRelease(OCCTWireBuilderRef _Nonnull wb);

/// Add an edge to the wire builder.
void OCCTWireBuilderAddEdge(OCCTWireBuilderRef _Nonnull wb, OCCTShapeRef _Nonnull edge);

/// Add a wire to the wire builder.
void OCCTWireBuilderAddWire(OCCTWireBuilderRef _Nonnull wb, OCCTShapeRef _Nonnull wire);

/// Get the resulting wire.
OCCTShapeRef _Nullable OCCTWireBuilderWire(OCCTWireBuilderRef _Nonnull wb);

/// Check if the wire builder succeeded.
bool OCCTWireBuilderIsDone(OCCTWireBuilderRef _Nonnull wb);

/// Get error status: 0=WireDone, 1=EmptyWire, 2=DisconnectedWire, 3=NonManifoldWire.
int32_t OCCTWireBuilderError(OCCTWireBuilderRef _Nonnull wb);

// --- Boolean operations with tolerance ---

/// Fuse two shapes with fuzzy tolerance.
OCCTShapeRef _Nullable OCCTBooleanFuseWithTolerance(OCCTShapeRef _Nonnull s1, OCCTShapeRef _Nonnull s2, double fuzzyTol);

/// Cut s2 from s1 with fuzzy tolerance.
OCCTShapeRef _Nullable OCCTBooleanCutWithTolerance(OCCTShapeRef _Nonnull s1, OCCTShapeRef _Nonnull s2, double fuzzyTol);

/// Common of two shapes with fuzzy tolerance.
OCCTShapeRef _Nullable OCCTBooleanCommonWithTolerance(OCCTShapeRef _Nonnull s1, OCCTShapeRef _Nonnull s2, double fuzzyTol);

/// Fuse two shapes with glue mode (0=shift, 1=full, 2=none).
OCCTShapeRef _Nullable OCCTBooleanFuseGlue(OCCTShapeRef _Nonnull s1, OCCTShapeRef _Nonnull s2, int32_t glueMode);

/// Cut with glue mode.
OCCTShapeRef _Nullable OCCTBooleanCutGlue(OCCTShapeRef _Nonnull s1, OCCTShapeRef _Nonnull s2, int32_t glueMode);

/// Common with glue mode.
OCCTShapeRef _Nullable OCCTBooleanCommonGlue(OCCTShapeRef _Nonnull s1, OCCTShapeRef _Nonnull s2, int32_t glueMode);

// --- BRepOffsetAPI_MakeOffset expansion ---

/// Offset a wire on a plane. joinType: 0=Arc, 1=Tangent, 2=Intersection.
OCCTShapeRef _Nullable OCCTOffsetWireOnPlane(OCCTShapeRef _Nonnull wire, double distance, int32_t joinType);

/// Offset a face. joinType: 0=Arc, 1=Tangent, 2=Intersection.
OCCTShapeRef _Nullable OCCTOffsetFace(OCCTShapeRef _Nonnull face, double distance, int32_t joinType);

// --- BRepOffsetAPI_MakeThickSolid expansion ---

/// Create thick solid with tolerance and join type control.
/// joinType: 0=Arc, 1=Tangent, 2=Intersection.
OCCTShapeRef _Nullable OCCTThickSolidWithOptions(OCCTShapeRef _Nonnull shape,
                                                   OCCTShapeRef _Nonnull const * _Nonnull facesToRemove,
                                                   int32_t faceCount,
                                                   double offset, double tolerance,
                                                   int32_t joinType);

// --- BRepLib utilities ---

/// Orient a closed solid so that its faces' normals point outward.
bool OCCTBRepLibOrientClosedSolid(OCCTShapeRef _Nonnull solid);

/// Build 3D curves for all edges in a shape.
bool OCCTBRepLibBuildCurves3dForShape(OCCTShapeRef _Nonnull shape, double tolerance);

/// Sort faces of a shape by decreasing area (returns sorted face list as a compound).
OCCTShapeRef _Nullable OCCTBRepLibSortFaces(OCCTShapeRef _Nonnull shape);

/// Reverse sort faces (increasing area).
OCCTShapeRef _Nullable OCCTBRepLibReverseSortFaces(OCCTShapeRef _Nonnull shape);

// --- Shape mass properties expansion ---

/// Get linear properties (length + center of mass) for wires/edges.
double OCCTShapeLinearProperties(OCCTShapeRef _Nonnull shape,
                                   double* _Nonnull cx, double* _Nonnull cy, double* _Nonnull cz);

/// Get the static moments (Ix, Iy, Iz) and products of inertia (Ixy, Ixz, Iyz) for a shape.
void OCCTShapeMomentOfInertia(OCCTShapeRef _Nonnull shape,
                                double* _Nonnull ixx, double* _Nonnull iyy, double* _Nonnull izz,
                                double* _Nonnull ixy, double* _Nonnull ixz, double* _Nonnull iyz);

/// Get the principal axes of inertia (3 direction vectors = 9 doubles).
void OCCTShapePrincipalAxes(OCCTShapeRef _Nonnull shape, double* _Nonnull axes9);

/// Get the radius of gyration about an arbitrary axis.
double OCCTShapeRadiusOfGyration(OCCTShapeRef _Nonnull shape,
                                    double ax, double ay, double az,
                                    double dx, double dy, double dz);

// --- Curve isBounded ---

/// Check if a 3D curve is bounded (Geom_BoundedCurve subclass).
bool OCCTCurve3DIsBounded(OCCTCurve3DRef _Nonnull curve);

/// Check if a 2D curve is bounded (Geom2d_BoundedCurve subclass).
bool OCCTCurve2DIsBounded(OCCTCurve2DRef _Nonnull curve);

// --- Quantity_Color named color count ---

/// Get the total number of named colors in OCCT.
int32_t OCCTNamedColorCount(void);

// --- BRep_Tool queries on Shape ---

/// Get the tolerance of an edge shape.
double OCCTShapeEdgeTolerance(OCCTShapeRef _Nonnull edge);

/// Get the tolerance of a face shape.
double OCCTShapeFaceTolerance(OCCTShapeRef _Nonnull face);

/// Get the tolerance of a vertex shape.
double OCCTShapeVertexTolerance(OCCTShapeRef _Nonnull vertex);

/// Get the 3D point of a vertex shape.
void OCCTShapeVertexPoint(OCCTShapeRef _Nonnull vertex,
                           double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Get the curve from an edge shape. Returns NULL if edge has no 3D curve.
OCCTCurve3DRef _Nullable OCCTShapeEdgeCurve(OCCTShapeRef _Nonnull edge,
                                              double* _Nonnull first, double* _Nonnull last);

/// Get the surface from a face shape. Returns NULL if face has no surface.
OCCTSurfaceRef _Nullable OCCTShapeFaceSurface(OCCTShapeRef _Nonnull face);

/// Check if a shape is closed (for wire or shell).
bool OCCTShapeIsClosed(OCCTShapeRef _Nonnull shape);

// --- Unique sub-shape counts (TopExp::MapShapes) ---

/// Count unique sub-shapes of a given type.
/// type: 0=compound, 1=compsolid, 2=solid, 3=shell, 4=face, 5=wire, 6=edge, 7=vertex
int32_t OCCTShapeUniqueSubShapeCount(OCCTShapeRef _Nonnull shape, int32_t type);

// --- Geom_Curve DN (arbitrary derivative) ---

/// Evaluate the N-th derivative of a 3D curve at parameter u.
void OCCTCurve3DDN(OCCTCurve3DRef _Nonnull curve, double u, int32_t n,
                    double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Evaluate the N-th derivative of a 2D curve at parameter u.
void OCCTCurve2DDN(OCCTCurve2DRef _Nonnull curve, double u, int32_t n,
                    double* _Nonnull x, double* _Nonnull y);

/// Evaluate the (Nu, Nv) partial derivative of a surface at (u,v).
void OCCTSurfaceDN(OCCTSurfaceRef _Nonnull surface, double u, double v,
                    int32_t nu, int32_t nv,
                    double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

// --- Curve/Surface type names ---

/// Get the 3D curve type as a string (Geom_Line, Geom_Circle, etc.).
const char* _Nullable OCCTCurve3DTypeName(OCCTCurve3DRef _Nonnull curve);

/// Get the 2D curve type as a string (Geom2d_Line, Geom2d_Circle, etc.).
const char* _Nullable OCCTCurve2DTypeName(OCCTCurve2DRef _Nonnull curve);

/// Get the surface type as a string (Geom_Plane, Geom_SphericalSurface, etc.).
const char* _Nullable OCCTSurfaceTypeName(OCCTSurfaceRef _Nonnull surface);

// --- Shape topology queries ---

/// Get the number of unique edges in a shape.
int32_t OCCTShapeUniqueEdgeCount(OCCTShapeRef _Nonnull shape);

/// Get the number of unique faces in a shape.
int32_t OCCTShapeUniqueFaceCount(OCCTShapeRef _Nonnull shape);

/// Get the number of unique vertices in a shape.
int32_t OCCTShapeUniqueVertexCount(OCCTShapeRef _Nonnull shape);

// --- Shape empty copy ---

/// Create an empty copy of a shape (same TShape, no sub-shapes).
OCCTShapeRef _Nullable OCCTShapeEmptyCopied(OCCTShapeRef _Nonnull shape);

// MARK: - v0.115.0: Interpolation expansion, ThruSections builder, Triangulation queries, Adaptor exposure, Shape queries

// --- GeomAPI_Interpolate expansion ---

/// Interpolate 3D BSpline with endpoint tangents.
OCCTCurve3DRef _Nullable OCCTInterpolateWithTangents(const double* _Nonnull points, int32_t count,
                                                       double t1x, double t1y, double t1z,
                                                       double t2x, double t2y, double t2z);

/// Interpolate 3D BSpline with per-point tangents. tangentFlags[i] indicates if tangent[i] is set.
OCCTCurve3DRef _Nullable OCCTInterpolateWithAllTangents(const double* _Nonnull points, int32_t count,
                                                          const double* _Nonnull tangents,
                                                          const bool* _Nonnull tangentFlags);

/// Interpolate 3D BSpline with explicit parameters.
OCCTCurve3DRef _Nullable OCCTInterpolateWithParameters(const double* _Nonnull points, int32_t count,
                                                         const double* _Nonnull parameters);

/// Interpolate 3D BSpline as periodic (closed) curve.
OCCTCurve3DRef _Nullable OCCTInterpolatePeriodic(const double* _Nonnull points, int32_t count);

/// Interpolate 2D BSpline with endpoint tangents.
OCCTCurve2DRef _Nullable OCCTInterpolate2DWithTangents(const double* _Nonnull points, int32_t count,
                                                         double t1x, double t1y,
                                                         double t2x, double t2y);

/// Interpolate 2D BSpline as periodic (closed) curve.
OCCTCurve2DRef _Nullable OCCTInterpolate2DPeriodic(const double* _Nonnull points, int32_t count);

// --- GeomAPI_PointsToBSpline expansion ---

/// Approximate 3D BSpline through points with degree and continuity control.
/// continuity: 0=C0, 1=C1, 2=C2, 3=C3
OCCTCurve3DRef _Nullable OCCTPointsToBSplineWithParams(const double* _Nonnull points, int32_t count,
                                                         int32_t degMin, int32_t degMax,
                                                         int32_t continuity, double tol);

/// Approximate 3D BSpline with explicit parameter values.
OCCTCurve3DRef _Nullable OCCTPointsToBSplineWithParameters(const double* _Nonnull points,
                                                             const double* _Nonnull params,
                                                             int32_t count, int32_t degMin, int32_t degMax,
                                                             int32_t continuity, double tol);

/// Approximate 2D BSpline through points with degree and continuity control.
OCCTCurve2DRef _Nullable OCCTPoints2DToBSplineWithParams(const double* _Nonnull points, int32_t count,
                                                            int32_t degMin, int32_t degMax,
                                                            int32_t continuity, double tol);

/// Approximate a BSpline surface through a grid of 3D points.
/// points is row-major (u varies fastest): point[v*uCount+u] = (x,y,z).
OCCTSurfaceRef _Nullable OCCTPointsToSurfaceBSpline(const double* _Nonnull points,
                                                       int32_t uCount, int32_t vCount,
                                                       int32_t degMin, int32_t degMax,
                                                       int32_t continuity, double tol);

// --- BRepBuilderAPI_Transform expansion ---

/// Apply a general gp_Trsf (12 doubles: 3x3 rotation matrix + 3 translation).
/// matrix12 = [r00,r01,r02, r10,r11,r12, r20,r21,r22, tx,ty,tz]
OCCTShapeRef _Nullable OCCTShapeTransformed(OCCTShapeRef _Nonnull shape,
                                              const double* _Nonnull matrix12);

/// Apply a gp_GTrsf (non-uniform scaling). matrix12 = 3x4 affine matrix row-major.
OCCTShapeRef _Nullable OCCTShapeGTransformed(OCCTShapeRef _Nonnull shape,
                                               const double* _Nonnull matrix12);

// --- BRepAlgoAPI expansion ---

/// Boolean section (intersection curves) with fuzzy tolerance.
OCCTShapeRef _Nullable OCCTBooleanSectionWithTolerance(OCCTShapeRef _Nonnull s1,
                                                         OCCTShapeRef _Nonnull s2,
                                                         double fuzzyTol);

/// Split shape by multiple tool shapes with fuzzy tolerance.
OCCTShapeRef _Nullable OCCTBooleanSplitMulti(OCCTShapeRef _Nonnull shape,
                                               const OCCTShapeRef _Nonnull * _Nonnull tools,
                                               int32_t toolCount, double fuzzyTol);

/// Boolean cut with history tracking. Returns result and sets hasDeleted/hasModified/hasGenerated.
OCCTShapeRef _Nullable OCCTBooleanCutWithHistory(OCCTShapeRef _Nonnull s1, OCCTShapeRef _Nonnull s2,
                                                    double fuzzyTol,
                                                    bool* _Nonnull hasDeleted,
                                                    bool* _Nonnull hasModified,
                                                    bool* _Nonnull hasGenerated);

/// Defeature (remove faces) with fuzzy tolerance.
OCCTShapeRef _Nullable OCCTDefeatureWithTolerance(OCCTShapeRef _Nonnull shape,
                                                    const OCCTShapeRef _Nonnull * _Nonnull facesToRemove,
                                                    int32_t count, double fuzzyTol);

// --- BRepOffsetAPI_ThruSections builder ---

typedef void* OCCTThruSectionsRef;

/// Create a ThruSections builder.
OCCTThruSectionsRef _Nonnull OCCTThruSectionsCreate(bool isSolid, bool isRuled, double pres3d);

/// Release a ThruSections builder.
void OCCTThruSectionsRelease(OCCTThruSectionsRef _Nonnull ts);

/// Add a wire profile to the ThruSections builder.
void OCCTThruSectionsAddWire(OCCTThruSectionsRef _Nonnull ts, OCCTShapeRef _Nonnull wire);

/// Add a vertex (point) as a degenerate section.
void OCCTThruSectionsAddVertex(OCCTThruSectionsRef _Nonnull ts, OCCTShapeRef _Nonnull vertex);

/// Enable/disable smoothing (default: true for non-ruled).
void OCCTThruSectionsSetSmoothing(OCCTThruSectionsRef _Nonnull ts, bool smoothing);

/// Set maximum BSpline degree.
void OCCTThruSectionsSetMaxDegree(OCCTThruSectionsRef _Nonnull ts, int32_t maxDeg);

/// Set continuity (0=C0, 1=C1, 2=C2).
void OCCTThruSectionsSetContinuity(OCCTThruSectionsRef _Nonnull ts, int32_t continuity);

/// Build the ThruSections shape. Returns true if successful.
bool OCCTThruSectionsBuild(OCCTThruSectionsRef _Nonnull ts);

/// Get the result shape from the ThruSections builder.
OCCTShapeRef _Nullable OCCTThruSectionsShape(OCCTThruSectionsRef _Nonnull ts);

// --- GeomConvert utilities ---

/// Split a 3D curve at discontinuities of given continuity.
/// Returns number of segments written to outSegments (up to maxSegments).
int32_t OCCTCurve3DSplitAtContinuity(OCCTCurve3DRef _Nonnull curve, int32_t continuity, double tol,
                                        OCCTCurve3DRef _Nullable * _Nonnull outSegments, int32_t maxSegments);

/// Split a 2D curve at discontinuities of given continuity.
int32_t OCCTCurve2DSplitAtContinuity(OCCTCurve2DRef _Nonnull curve, int32_t continuity, double tol,
                                        OCCTCurve2DRef _Nullable * _Nonnull outSegments, int32_t maxSegments);

/// Concatenate an array of 3D curves with G1 continuity.
OCCTCurve3DRef _Nullable OCCTCurve3DConcatenateG1(const OCCTCurve3DRef _Nonnull * _Nonnull curves,
                                                     int32_t count, double tol);

// --- ShapeFix_Shape builder ---

typedef void* OCCTShapeFixerRef;

/// Create a ShapeFix_Shape fixer for the given shape.
OCCTShapeFixerRef _Nonnull OCCTShapeFixerCreate(OCCTShapeRef _Nonnull shape);

/// Release a ShapeFix_Shape fixer.
void OCCTShapeFixerRelease(OCCTShapeFixerRef _Nonnull fixer);

/// Set the precision for the shape fixer.
void OCCTShapeFixerSetPrecision(OCCTShapeFixerRef _Nonnull fixer, double precision);

/// Set the maximum tolerance for the shape fixer.
void OCCTShapeFixerSetMaxTolerance(OCCTShapeFixerRef _Nonnull fixer, double maxTol);

/// Set the minimum tolerance for the shape fixer.
void OCCTShapeFixerSetMinTolerance(OCCTShapeFixerRef _Nonnull fixer, double minTol);

/// Perform the shape fix. Returns true if something was fixed.
bool OCCTShapeFixerPerform(OCCTShapeFixerRef _Nonnull fixer);

/// Get the result shape after fixing.
OCCTShapeRef _Nullable OCCTShapeFixerShape(OCCTShapeFixerRef _Nonnull fixer);

/// Query status. statusType: 1=ShapeFixOk, 2=ShapeFixDone, 3=ShapeFixFail.
bool OCCTShapeFixerStatus(OCCTShapeFixerRef _Nonnull fixer, int32_t statusType);

// --- Poly_Triangulation queries on faces ---

/// Get the number of nodes in the triangulation of a face.
int32_t OCCTFaceTriangulationNodeCount(OCCTShapeRef _Nonnull face);

/// Get the number of triangles in the triangulation of a face.
int32_t OCCTFaceTriangulationTriangleCount(OCCTShapeRef _Nonnull face);

/// Get the deflection of the triangulation.
double OCCTFaceTriangulationDeflection(OCCTShapeRef _Nonnull face);

/// Get the coordinates of a node (1-based index).
void OCCTFaceTriangulationNode(OCCTShapeRef _Nonnull face, int32_t index,
                                 double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Get the node indices of a triangle (1-based index). Returns 1-based node indices.
void OCCTFaceTriangulationTriangle(OCCTShapeRef _Nonnull face, int32_t index,
                                     int32_t* _Nonnull n1, int32_t* _Nonnull n2, int32_t* _Nonnull n3);

/// Check if the face triangulation has normals.
bool OCCTFaceTriangulationHasNormals(OCCTShapeRef _Nonnull face);

/// Get the normal at a node (1-based index).
void OCCTFaceTriangulationNormal(OCCTShapeRef _Nonnull face, int32_t index,
                                   double* _Nonnull nx, double* _Nonnull ny, double* _Nonnull nz);

/// Check if the face triangulation has UV nodes.
bool OCCTFaceTriangulationHasUVNodes(OCCTShapeRef _Nonnull face);

/// Get the UV coordinates of a node (1-based index).
void OCCTFaceTriangulationUVNode(OCCTShapeRef _Nonnull face, int32_t index,
                                   double* _Nonnull u, double* _Nonnull v);

// --- GCPnts_AbscissaPoint expansion ---

/// Find parameter on an edge at a given arc length from startParam.
double OCCTEdgeParameterAtArcLength(OCCTShapeRef _Nonnull edge, double arcLength, double startParam);

/// Compute total arc length of an edge.
double OCCTEdgeArcLength(OCCTShapeRef _Nonnull edge);

/// Find parameter on a 3D curve at a given arc length from startParam.
double OCCTCurve3DParameterAtLength(OCCTCurve3DRef _Nonnull curve, double arcLength, double fromParam);

/// Compute total arc length of a 3D curve within its domain.
double OCCTCurve3DArcLength(OCCTCurve3DRef _Nonnull curve);

/// Compute arc length of a 3D curve between two parameters.
double OCCTCurve3DArcLengthBetween(OCCTCurve3DRef _Nonnull curve, double param1, double param2);

/// Compute arc length between two parameters on an edge.
double OCCTEdgeArcLengthBetween(OCCTShapeRef _Nonnull edge, double u1, double u2);

/// Find parameter at a fraction (0..1) of total edge length.
double OCCTEdgeParameterAtFraction(OCCTShapeRef _Nonnull edge, double fraction);

// --- BRepAdaptor exposure ---

/// Get the parameter domain of an edge curve.
void OCCTEdgeAdaptorDomain(OCCTShapeRef _Nonnull edge, double* _Nonnull first, double* _Nonnull last);

/// Evaluate the edge curve at a parameter.
void OCCTEdgeAdaptorValue(OCCTShapeRef _Nonnull edge, double param,
                            double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Get the curve type of an edge (GeomAbs_CurveType: 0=Line, 1=Circle, etc.).
int32_t OCCTEdgeAdaptorCurveType(OCCTShapeRef _Nonnull edge);

/// Get the UV bounds of a face surface.
void OCCTFaceAdaptorBounds(OCCTShapeRef _Nonnull face,
                             double* _Nonnull uMin, double* _Nonnull uMax,
                             double* _Nonnull vMin, double* _Nonnull vMax);

/// Evaluate the face surface at (u,v).
void OCCTFaceAdaptorValue(OCCTShapeRef _Nonnull face, double u, double v,
                            double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Get the surface type of a face (GeomAbs_SurfaceType: 0=Plane, 1=Cylinder, etc.).
int32_t OCCTFaceAdaptorSurfaceType(OCCTShapeRef _Nonnull face);

// --- Additional shape queries ---

/// Compute the volume of the oriented bounding box (OBB) of a shape.
double OCCTShapeOBBVolume(OCCTShapeRef _Nonnull shape);

/// Get the maximum edge tolerance in a shape.
double OCCTShapeMaxEdgeTolerance(OCCTShapeRef _Nonnull shape);

/// Get the maximum face tolerance in a shape.
double OCCTShapeMaxFaceTolerance(OCCTShapeRef _Nonnull shape);

/// Get the maximum vertex tolerance in a shape.
double OCCTShapeMaxVertexTolerance(OCCTShapeRef _Nonnull shape);

/// Check if a shape has any free (non-shared) edges.
bool OCCTShapeHasFreeEdges(OCCTShapeRef _Nonnull shape);

/// Check if a shape has any free (non-shared) wires.
bool OCCTShapeHasFreeWires(OCCTShapeRef _Nonnull shape);

/// Check if a shape has any free (non-shared) faces.
bool OCCTShapeHasFreeFaces(OCCTShapeRef _Nonnull shape);

/// Compute the bounding box diagonal length.
double OCCTShapeBoundingDiagonal(OCCTShapeRef _Nonnull shape);

/// Compute the volumetric centroid of a shape.
void OCCTShapeCentroid(OCCTShapeRef _Nonnull shape,
                         double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Compute the total edge length of all edges in a shape.
double OCCTShapeTotalEdgeLength(OCCTShapeRef _Nonnull shape);

// --- Curve3D/2D additional (v0.115.0) ---

/// Compute the length of a 3D curve between parameters u1 and u2.
double OCCTCurve3DLength(OCCTCurve3DRef _Nonnull curve, double u1, double u2);

/// Find the closest point on a 3D curve to a given point. Returns parameter.
double OCCTCurve3DClosestParameter(OCCTCurve3DRef _Nonnull curve, double px, double py, double pz);

/// Create a trimmed copy of a 2D curve between parameters u1 and u2.
OCCTCurve2DRef _Nullable OCCTCurve2DTrimmed(OCCTCurve2DRef _Nonnull curve, double u1, double u2);

/// Compute the length of a 2D curve between parameters u1 and u2.
double OCCTCurve2DLength(OCCTCurve2DRef _Nonnull curve, double u1, double u2);

// --- Surface additional (v0.115.0) ---

/// Compute the surface normal at (u,v).
void OCCTSurfaceNormal(OCCTSurfaceRef _Nonnull surface, double u, double v,
                         double* _Nonnull nx, double* _Nonnull ny, double* _Nonnull nz);

/// Compute Gaussian and mean curvature at (u,v).
void OCCTSurfaceCurvatures(OCCTSurfaceRef _Nonnull surface, double u, double v,
                             double* _Nonnull gaussian, double* _Nonnull mean);

// MARK: - HelixGeom (v0.116.0)

/// Build a helix curve approximated as BSpline. Returns curve handle; NULL on failure.
/// t1/t2: parameter range, pitch: helix pitch, rStart: radius, taperAngle: taper in radians, isClockwise.
/// posX/Y/Z + dirX/Y/Z + xDirX/Y/Z define the gp_Ax2 position.
OCCTCurve3DRef _Nullable OCCTHelixBuild(double posX, double posY, double posZ,
                                          double dirX, double dirY, double dirZ,
                                          double xDirX, double xDirY, double xDirZ,
                                          double t1, double t2, double pitch, double rStart,
                                          double taperAngle, bool isClockwise,
                                          double tolerance, double* _Nonnull tolReached);

/// Build a helix coil (closed loop helix). Returns curve handle; NULL on failure.
OCCTCurve3DRef _Nullable OCCTHelixCoilBuild(double t1, double t2, double pitch, double rStart,
                                              double taperAngle, bool isClockwise,
                                              double tolerance, double* _Nonnull tolReached);

/// Evaluate helix curve at parameter u. Returns point.
void OCCTHelixCurveEval(double t1, double t2, double pitch, double rStart,
                          double taperAngle, bool isClockwise, double u,
                          double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz);

/// Evaluate helix curve D1 (point + first derivative) at parameter u.
void OCCTHelixCurveD1(double t1, double t2, double pitch, double rStart,
                        double taperAngle, bool isClockwise, double u,
                        double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz,
                        double* _Nonnull vx, double* _Nonnull vy, double* _Nonnull vz);

/// Evaluate helix curve D2 at parameter u.
void OCCTHelixCurveD2(double t1, double t2, double pitch, double rStart,
                        double taperAngle, bool isClockwise, double u,
                        double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz,
                        double* _Nonnull v1x, double* _Nonnull v1y, double* _Nonnull v1z,
                        double* _Nonnull v2x, double* _Nonnull v2y, double* _Nonnull v2z);

/// Approximate a helix to BSpline directly via HelixGeom_Tools::ApprHelix.
OCCTCurve3DRef _Nullable OCCTHelixApproxToBSpline(double t1, double t2, double pitch, double rStart,
                                                     double taperAngle, bool isClockwise,
                                                     double tolerance, double* _Nonnull maxError);

// MARK: - gp_Ax3 (v0.116.0)

/// Create Ax3 from point + main direction + X direction. isDirect reports handedness.
void OCCTAx3Create(double px, double py, double pz,
                     double nx, double ny, double nz,
                     double xDirX, double xDirY, double xDirZ,
                     bool* _Nonnull isDirect,
                     double* _Nonnull xDx, double* _Nonnull xDy, double* _Nonnull xDz,
                     double* _Nonnull yDx, double* _Nonnull yDy, double* _Nonnull yDz);

/// Create Ax3 from point + main direction only (X/Y auto-computed).
void OCCTAx3CreateFromNormal(double px, double py, double pz,
                               double nx, double ny, double nz,
                               bool* _Nonnull isDirect,
                               double* _Nonnull xDx, double* _Nonnull xDy, double* _Nonnull xDz,
                               double* _Nonnull yDx, double* _Nonnull yDy, double* _Nonnull yDz);

/// Angle between two Ax3 coordinate systems.
double OCCTAx3Angle(double p1x, double p1y, double p1z, double n1x, double n1y, double n1z, double x1x, double x1y, double x1z,
                      double p2x, double p2y, double p2z, double n2x, double n2y, double n2z, double x2x, double x2y, double x2z);

/// Check if two Ax3 are coplanar.
bool OCCTAx3IsCoplanar(double p1x, double p1y, double p1z, double n1x, double n1y, double n1z, double x1x, double x1y, double x1z,
                         double p2x, double p2y, double p2z, double n2x, double n2y, double n2z, double x2x, double x2y, double x2z,
                         double linearTol, double angularTol);

/// Mirror Ax3 about a point.
void OCCTAx3MirrorPoint(double px, double py, double pz, double nx, double ny, double nz, double xDx, double xDy, double xDz,
                          double mx, double my, double mz,
                          double* _Nonnull rpx, double* _Nonnull rpy, double* _Nonnull rpz,
                          double* _Nonnull rnx, double* _Nonnull rny, double* _Nonnull rnz,
                          double* _Nonnull rxDx, double* _Nonnull rxDy, double* _Nonnull rxDz);

/// Rotate Ax3 about an axis.
void OCCTAx3Rotate(double px, double py, double pz, double nx, double ny, double nz, double xDx, double xDy, double xDz,
                     double axPx, double axPy, double axPz, double axDx, double axDy, double axDz, double angle,
                     double* _Nonnull rpx, double* _Nonnull rpy, double* _Nonnull rpz,
                     double* _Nonnull rnx, double* _Nonnull rny, double* _Nonnull rnz,
                     double* _Nonnull rxDx, double* _Nonnull rxDy, double* _Nonnull rxDz);

/// Translate Ax3.
void OCCTAx3Translate(double px, double py, double pz, double nx, double ny, double nz, double xDx, double xDy, double xDz,
                        double vx, double vy, double vz,
                        double* _Nonnull rpx, double* _Nonnull rpy, double* _Nonnull rpz);

// MARK: - gp_GTrsf2d (v0.116.0)

/// Create a 2D affinity transformation about an axis with given ratio.
/// Returns the 2x2 matrix (row-major) and translation vector.
void OCCTGTrsf2dAffinity(double axPx, double axPy, double axDx, double axDy, double ratio,
                           double* _Nonnull mat, double* _Nonnull tx, double* _Nonnull ty);

/// Multiply two GTrsf2d (each as 2x2 matrix + translation). Result = A * B.
void OCCTGTrsf2dMultiply(const double* _Nonnull matA, double txA, double tyA,
                           const double* _Nonnull matB, double txB, double tyB,
                           double* _Nonnull matR, double* _Nonnull txR, double* _Nonnull tyR);

/// Invert a GTrsf2d. Returns false if singular.
bool OCCTGTrsf2dInvert(const double* _Nonnull mat, double tx, double ty,
                         double* _Nonnull matR, double* _Nonnull txR, double* _Nonnull tyR);

/// Transform a 2D point by GTrsf2d.
void OCCTGTrsf2dTransformPoint(const double* _Nonnull mat, double tx, double ty,
                                 double px, double py, double* _Nonnull rx, double* _Nonnull ry);

// MARK: - gp_Mat2d (v0.116.0)

/// Create 2x2 identity matrix (row-major output: m11, m12, m21, m22).
void OCCTMat2dIdentity(double* _Nonnull mat);

/// Create 2x2 rotation matrix.
void OCCTMat2dRotation(double angle, double* _Nonnull mat);

/// Create 2x2 scale matrix.
void OCCTMat2dScale(double s, double* _Nonnull mat);

/// Determinant of 2x2 matrix.
double OCCTMat2dDeterminant(const double* _Nonnull mat);

/// Invert 2x2 matrix. Returns false if singular.
bool OCCTMat2dInvert(const double* _Nonnull mat, double* _Nonnull result);

/// Multiply two 2x2 matrices. Result = A * B.
void OCCTMat2dMultiply(const double* _Nonnull matA, const double* _Nonnull matB, double* _Nonnull result);

/// Transpose 2x2 matrix.
void OCCTMat2dTranspose(const double* _Nonnull mat, double* _Nonnull result);

// MARK: - Quaternion Interpolation (v0.116.0)

/// Spherical linear interpolation (SLERP) between two quaternions at parameter t.
void OCCTQuaternionSLerp(double x1, double y1, double z1, double w1,
                           double x2, double y2, double z2, double w2,
                           double t,
                           double* _Nonnull rx, double* _Nonnull ry, double* _Nonnull rz, double* _Nonnull rw);

/// Linear interpolation (NLERP) between two quaternions at parameter t. Result is normalized.
void OCCTQuaternionNLerp(double x1, double y1, double z1, double w1,
                           double x2, double y2, double z2, double w2,
                           double t,
                           double* _Nonnull rx, double* _Nonnull ry, double* _Nonnull rz, double* _Nonnull rw);

/// Interpolate between two gp_Trsf at parameter t (translation + rotation interpolation).
/// Each transform is: translation(tx,ty,tz) + quaternion(qx,qy,qz,qw) + scale.
void OCCTTrsfInterpolate(double tx1, double ty1, double tz1, double qx1, double qy1, double qz1, double qw1,
                           double tx2, double ty2, double tz2, double qx2, double qy2, double qz2, double qw2,
                           double t,
                           double* _Nonnull rtx, double* _Nonnull rty, double* _Nonnull rtz,
                           double* _Nonnull rqx, double* _Nonnull rqy, double* _Nonnull rqz, double* _Nonnull rqw);

// MARK: - gp_XY (v0.116.0)

/// 2D vector modulus (length).
double OCCTXYModulus(double x, double y);

/// 2D cross product (scalar).
double OCCTXYCrossed(double x1, double y1, double x2, double y2);

/// 2D dot product.
double OCCTXYDot(double x1, double y1, double x2, double y2);

/// Normalize 2D vector. Returns false if zero length.
bool OCCTXYNormalize(double x, double y, double* _Nonnull rx, double* _Nonnull ry);

// MARK: - gp_XYZ (v0.116.0)

/// 3D vector modulus (length).
double OCCTXYZModulus(double x, double y, double z);

/// 3D cross product.
void OCCTXYZCrossed(double x1, double y1, double z1, double x2, double y2, double z2,
                      double* _Nonnull rx, double* _Nonnull ry, double* _Nonnull rz);

/// 3D dot product.
double OCCTXYZDot(double x1, double y1, double z1, double x2, double y2, double z2);

/// Scalar triple product (a . (b x c)).
double OCCTXYZDotCross(double ax, double ay, double az,
                         double bx, double by, double bz,
                         double cx, double cy, double cz);

/// Normalize 3D vector. Returns false if zero length.
bool OCCTXYZNormalize(double x, double y, double z,
                        double* _Nonnull rx, double* _Nonnull ry, double* _Nonnull rz);

// MARK: - math_BracketedRoot (v0.116.0)

/// Find root of f(x)=0 in [bound1, bound2] using Brent's method.
/// Uses OCCTMathFuncDerivCallback. Returns root value; isDone indicates convergence.
double OCCTMathBracketedRoot(OCCTMathFuncDerivCallback _Nonnull callback, void* _Nullable context,
                               double bound1, double bound2, double tolerance, int32_t maxIter,
                               bool* _Nonnull isDone, int32_t* _Nonnull nbIter);

// MARK: - math_BracketMinimum (v0.116.0)

/// Bracket a minimum of f(x) starting from points a and b.
/// Returns the bracketing triplet (a,b,c) with f(b) < f(a) and f(b) < f(c).
bool OCCTMathBracketMinimum(OCCTMathSimpleFuncCallback _Nonnull callback, void* _Nullable context,
                              double a, double b,
                              double* _Nonnull ra, double* _Nonnull rb, double* _Nonnull rc,
                              double* _Nonnull fa, double* _Nonnull fb, double* _Nonnull fc);

// MARK: - math_FRPR (v0.116.0)

/// Minimize a multivariate function using Fletcher-Reeves-Polak-Ribiere conjugate gradient.
/// startPoint[nVars], result[nVars]. Returns true on convergence.
bool OCCTMathFRPR(int32_t nVars,
                    OCCTMathMultiVarGradCallback _Nonnull callback, void* _Nullable context,
                    const double* _Nonnull startPoint, double tolerance, int32_t maxIter,
                    double* _Nonnull result, double* _Nonnull minimum, int32_t* _Nonnull nbIter);

// MARK: - math_FunctionAllRoots (v0.116.0)

/// Find all roots of f(x)=0 in [a,b] using sampling + refinement.
/// Returns number of isolated roots found. roots[] must be pre-allocated with maxRoots capacity.
int32_t OCCTMathFunctionAllRoots(OCCTMathFuncDerivCallback _Nonnull callback, void* _Nullable context,
                                   double a, double b, int32_t nbSamples,
                                   double epsX, double epsF, double epsNul,
                                   double* _Nonnull roots, int32_t maxRoots);

// MARK: - math_GaussLeastSquare (v0.116.0)

/// Solve overdetermined linear system Ax=b in least-squares sense.
/// matA is row-major [nRows x nCols], b[nRows], x[nCols]. Returns true on success.
bool OCCTMathGaussLeastSquare(const double* _Nonnull matA, int32_t nRows, int32_t nCols,
                                const double* _Nonnull b, double* _Nonnull x);

// MARK: - math_NewtonFunctionRoot (v0.116.0)

/// Find root of f(x)=0 starting from guess, optionally bounded.
/// Uses OCCTMathFuncDerivCallback. Returns root; isDone on convergence.
double OCCTMathNewtonFunctionRoot(OCCTMathFuncDerivCallback _Nonnull callback, void* _Nullable context,
                                    double guess, double epsX, double epsF, int32_t maxIter,
                                    bool* _Nonnull isDone, double* _Nonnull derivative, int32_t* _Nonnull nbIter);

/// Bounded variant.
double OCCTMathNewtonFunctionRootBounded(OCCTMathFuncDerivCallback _Nonnull callback, void* _Nullable context,
                                           double guess, double epsX, double epsF, double a, double b,
                                           int32_t maxIter, bool* _Nonnull isDone);

// MARK: - math_Uzawa (v0.116.0)

/// Solve constrained optimization: minimize ||x||^2 subject to Cont * x = Secont.
/// Cont is row-major [nConstraints x nVars], Secont[nConstraints], startPoint[nVars], result[nVars].
bool OCCTMathUzawa(const double* _Nonnull contData, int32_t nConstraints, int32_t nVars,
                     const double* _Nonnull secont, const double* _Nonnull startPoint,
                     double epsLix, double epsLic, int32_t maxIter,
                     double* _Nonnull result, int32_t* _Nonnull nbIter);

// MARK: - math_EigenValuesSearcher (v0.116.0)

/// Find eigenvalues of symmetric tridiagonal matrix.
/// diagonal[n], subdiagonal[n] (last element unused). eigenvalues[n].
/// Returns number of eigenvalues found (n on success, 0 on failure).
int32_t OCCTMathEigenValues(const double* _Nonnull diagonal, const double* _Nonnull subdiagonal,
                              int32_t n, double* _Nonnull eigenvalues);

/// Find eigenvalues and eigenvectors. eigenvectors is row-major [n x n].
int32_t OCCTMathEigenValuesAndVectors(const double* _Nonnull diagonal, const double* _Nonnull subdiagonal,
                                        int32_t n, double* _Nonnull eigenvalues, double* _Nonnull eigenvectors);

// MARK: - math_KronrodSingleIntegration (v0.116.0)

/// Gauss-Kronrod integration of f(x) over [lower, upper].
/// Returns integral value; errorReached and nbIterReached are output.
double OCCTMathKronrodIntegration(OCCTMathSimpleFuncCallback _Nonnull callback, void* _Nullable context,
                                    double lower, double upper, int32_t nbPoints,
                                    bool* _Nonnull isDone, double* _Nonnull errorReached);

/// Adaptive Gauss-Kronrod with tolerance.
double OCCTMathKronrodIntegrationAdaptive(OCCTMathSimpleFuncCallback _Nonnull callback, void* _Nullable context,
                                            double lower, double upper, int32_t nbPoints,
                                            double tolerance, int32_t maxIter,
                                            bool* _Nonnull isDone, double* _Nonnull errorReached,
                                            int32_t* _Nonnull nbIterReached);

// MARK: - math_GaussMultipleIntegration (v0.116.0)

/// Multi-dimensional Gauss-Legendre integration.
/// lower[nVars], upper[nVars], order[nVars]. Returns integral value.
double OCCTMathGaussMultipleIntegration(OCCTMathMultiVarCallback _Nonnull callback, void* _Nullable context,
                                          int32_t nVars, const double* _Nonnull lower, const double* _Nonnull upper,
                                          const int32_t* _Nonnull order, bool* _Nonnull isDone);

// MARK: - math_GaussSetIntegration (v0.116.0)

/// Gauss-Legendre integration for function sets.
/// lower[nVars], upper[nVars], order[nVars], result[nEqs].
bool OCCTMathGaussSetIntegration(OCCTMathFuncSetCallback _Nonnull callback, void* _Nullable context,
                                   int32_t nVars, int32_t nEqs,
                                   const double* _Nonnull lower, const double* _Nonnull upper,
                                   const int32_t* _Nonnull order, double* _Nonnull result);

// MARK: - MathPoly rc4 polynomial solvers (v0.117.0)

/// Solve linear equation: a*x + b = 0. Returns number of roots found (-1 on error).
int32_t OCCTMathPolyLinear(double a, double b, double* _Nonnull roots, int32_t maxRoots);

/// Solve quadratic equation: a*x^2 + b*x + c = 0. Returns number of roots found (-1 on error).
int32_t OCCTMathPolyQuadratic(double a, double b, double c, double* _Nonnull roots, int32_t maxRoots);

/// Solve cubic equation: a*x^3 + b*x^2 + c*x + d = 0. Returns number of roots found (-1 on error).
int32_t OCCTMathPolyCubic(double a, double b, double c, double d, double* _Nonnull roots, int32_t maxRoots);

/// Solve quartic equation: a*x^4 + b*x^3 + c*x^2 + d*x + e = 0. Returns number of roots found (-1 on error).
int32_t OCCTMathPolyQuartic(double a, double b, double c, double d, double e, double* _Nonnull roots, int32_t maxRoots);

// MARK: - MathInteg rc4 integration (v0.117.0)

/// Gauss-Legendre quadrature using rc4 MathInteg templates.
double OCCTMathIntegGauss(OCCTMathSimpleFuncCallback _Nonnull callback, void* _Nullable context,
                           double lower, double upper, int32_t nbPoints,
                           bool* _Nonnull isDone, double* _Nonnull error);

/// Adaptive Gauss-Legendre using rc4 MathInteg templates.
double OCCTMathIntegGaussAdaptive(OCCTMathSimpleFuncCallback _Nonnull callback, void* _Nullable context,
                                    double lower, double upper,
                                    double tolerance, int32_t maxIter,
                                    bool* _Nonnull isDone, double* _Nonnull error, int32_t* _Nonnull nbIter);

/// Gauss-Kronrod rule using rc4 MathInteg templates.
double OCCTMathIntegKronrod(OCCTMathSimpleFuncCallback _Nonnull callback, void* _Nullable context,
                              double lower, double upper, int32_t nbGaussPoints,
                              bool* _Nonnull isDone, double* _Nonnull error);

/// Adaptive Gauss-Kronrod using rc4 MathInteg templates.
double OCCTMathIntegKronrodAdaptive(OCCTMathSimpleFuncCallback _Nonnull callback, void* _Nullable context,
                                      double lower, double upper, int32_t nbGaussPoints,
                                      double tolerance, int32_t maxIter,
                                      bool* _Nonnull isDone, double* _Nonnull error, int32_t* _Nonnull nbIter);

/// Tanh-Sinh (double exponential) quadrature using rc4 MathInteg templates.
double OCCTMathIntegTanhSinh(OCCTMathSimpleFuncCallback _Nonnull callback, void* _Nullable context,
                               double lower, double upper, double tolerance, int32_t maxLevels,
                               bool* _Nonnull isDone, double* _Nonnull error, int32_t* _Nonnull nbIter);

// MARK: - UnitsMethods (v0.117.0)

/// Get length factor value for IGES unit code.
double OCCTUnitsGetLengthFactor(int32_t unit);

/// Get scale factor between two length units.
double OCCTUnitsGetLengthUnitScale(int32_t fromUnit, int32_t toUnit);

/// Get string name for a length unit enum value.
const char* _Nullable OCCTUnitsDumpLengthUnit(int32_t unit);

// MARK: - LProp3d_CLProps (v0.117.0)

/// Get curvature at parameter on a 3D curve.
double OCCTCurve3DLocalCurvature(OCCTCurve3DRef _Nonnull curve, double u);

/// Get tangent direction at parameter on a 3D curve.
void OCCTCurve3DLocalTangent(OCCTCurve3DRef _Nonnull curve, double u,
                               double* _Nonnull tx, double* _Nonnull ty, double* _Nonnull tz,
                               bool* _Nonnull isDefined);

/// Get normal direction at parameter on a 3D curve.
void OCCTCurve3DLocalNormal(OCCTCurve3DRef _Nonnull curve, double u,
                              double* _Nonnull nx, double* _Nonnull ny, double* _Nonnull nz,
                              bool* _Nonnull isDefined);

/// Get centre of curvature at parameter on a 3D curve.
void OCCTCurve3DLocalCentreOfCurvature(OCCTCurve3DRef _Nonnull curve, double u,
                                         double* _Nonnull cx, double* _Nonnull cy, double* _Nonnull cz,
                                         bool* _Nonnull isDefined);

// MARK: - LProp3d_SLProps (v0.117.0)

/// Get surface curvatures at (u,v).
void OCCTSurfaceLocalCurvatures(OCCTSurfaceRef _Nonnull surface, double u, double v,
                                  double* _Nonnull gaussian, double* _Nonnull mean,
                                  double* _Nonnull maxCurvature, double* _Nonnull minCurvature,
                                  bool* _Nonnull isDefined);

/// Get curvature directions at (u,v).
void OCCTSurfaceLocalCurvatureDirections(OCCTSurfaceRef _Nonnull surface, double u, double v,
                                           double* _Nonnull maxDx, double* _Nonnull maxDy, double* _Nonnull maxDz,
                                           double* _Nonnull minDx, double* _Nonnull minDy, double* _Nonnull minDz,
                                           bool* _Nonnull isDefined);

// MARK: - ProjLib (v0.117.0)

/// Project 3D line onto plane, return 2D line parameters.
bool OCCTProjLibPlaneProjectLine(double plnPx, double plnPy, double plnPz,
                                   double plnNx, double plnNy, double plnNz,
                                   double linPx, double linPy, double linPz,
                                   double linDx, double linDy, double linDz,
                                   double* _Nonnull resPx, double* _Nonnull resPy,
                                   double* _Nonnull resDx, double* _Nonnull resDy);

/// Project 3D line onto cylinder, return 2D line parameters.
bool OCCTProjLibCylinderProjectLine(double cylPx, double cylPy, double cylPz,
                                      double cylDx, double cylDy, double cylDz,
                                      double cylRadius,
                                      double linPx, double linPy, double linPz,
                                      double linDx, double linDy, double linDz,
                                      double* _Nonnull resPx, double* _Nonnull resPy,
                                      double* _Nonnull resDx, double* _Nonnull resDy);

/// Project 3D circle onto plane, return 2D circle parameters.
bool OCCTProjLibPlaneProjectCircle(double plnPx, double plnPy, double plnPz,
                                     double plnNx, double plnNy, double plnNz,
                                     double cirCx, double cirCy, double cirCz,
                                     double cirNx, double cirNy, double cirNz,
                                     double cirRadius,
                                     double* _Nonnull resCx, double* _Nonnull resCy,
                                     double* _Nonnull resRadius);

// MARK: - BRepBndLib (v0.118.0)

/// Compute axis-aligned bounding box for a shape.
void OCCTShapeBoundingBox(OCCTShapeRef _Nonnull shape,
                          double* _Nonnull xmin, double* _Nonnull ymin, double* _Nonnull zmin,
                          double* _Nonnull xmax, double* _Nonnull ymax, double* _Nonnull zmax);

/// Compute optimal (tight) axis-aligned bounding box for a shape.
void OCCTShapeBoundingBoxOptimal(OCCTShapeRef _Nonnull shape, bool useShapeTolerance,
                                  double* _Nonnull xmin, double* _Nonnull ymin, double* _Nonnull zmin,
                                  double* _Nonnull xmax, double* _Nonnull ymax, double* _Nonnull zmax);

/// Compute oriented bounding box (OBB) for a shape with detailed axes output.
void OCCTShapeOrientedBoundingBoxDetailed(OCCTShapeRef _Nonnull shape, bool isOptimal,
                                           double* _Nonnull cx, double* _Nonnull cy, double* _Nonnull cz,
                                           double* _Nonnull xDirX, double* _Nonnull xDirY, double* _Nonnull xDirZ,
                                           double* _Nonnull yDirX, double* _Nonnull yDirY, double* _Nonnull yDirZ,
                                           double* _Nonnull zDirX, double* _Nonnull zDirY, double* _Nonnull zDirZ,
                                           double* _Nonnull xHSize, double* _Nonnull yHSize, double* _Nonnull zHSize,
                                           bool* _Nonnull isVoid);

// MARK: - ShapeAnalysis_ShapeTolerance (v0.118.0)

/// Get shape tolerance: mode 0=average, >0=max, <0=min. type: 0=all, 7=VERTEX, 6=EDGE, 4=FACE.
double OCCTShapeToleranceValue(OCCTShapeRef _Nonnull shape, int32_t mode, int32_t shapeType);

/// Count shapes with tolerance over given value.
int32_t OCCTShapeToleranceOverCount(OCCTShapeRef _Nonnull shape, double value, int32_t shapeType);

/// Count shapes with tolerance in given interval.
int32_t OCCTShapeToleranceInRangeCount(OCCTShapeRef _Nonnull shape, double valmin, double valmax, int32_t shapeType);

// MARK: - BRepAlgoAPI_Check (v0.118.0)

/// Check validity of a single shape for boolean operations. Returns true if valid.
bool OCCTShapeBooleanCheckSingle(OCCTShapeRef _Nonnull shape, bool testSmallEdges, bool testSelfInterference);

/// Check validity of two shapes for boolean operation. Returns true if valid.
bool OCCTShapeBooleanCheckPair(OCCTShapeRef _Nonnull shape1, OCCTShapeRef _Nonnull shape2,
                                int32_t operation, bool testSmallEdges, bool testSelfInterference);

// MARK: - BRepAlgoAPI_Defeaturing (v0.118.0)

/// Remove faces (features) from a solid shape. facesArray contains face shapes to remove.
OCCTShapeRef _Nullable OCCTShapeDefeature(OCCTShapeRef _Nonnull shape,
                                           const OCCTShapeRef _Nonnull * _Nonnull faces, int32_t faceCount);

// MARK: - Convert_CompPolynomialToPoles (v0.118.0)

/// Convert a single polynomial segment to BSpline poles/knots/mults.
/// Returns true on success. Caller must free outPoles and outKnots with free().
bool OCCTConvertPolynomialToPoles(int32_t dimension, int32_t maxDegree, int32_t degree,
                                   const double* _Nonnull coefficients, int32_t coeffCount,
                                   double polyStart, double polyEnd,
                                   double trueStart, double trueEnd,
                                   double* _Nullable * _Nonnull outPoles, int32_t* _Nonnull outPoleCount,
                                   double* _Nullable * _Nonnull outKnots, int32_t* _Nonnull outKnotCount,
                                   int32_t* _Nonnull outDegree);

// MARK: - gp_Trsf extras (v0.118.0)

/// Create a transform from 3x4 matrix values.
void OCCTShapeTransformFromMatrix(OCCTShapeRef _Nonnull shape,
                                   double a11, double a12, double a13, double a14,
                                   double a21, double a22, double a23, double a24,
                                   double a31, double a32, double a33, double a34,
                                   OCCTShapeRef _Nullable * _Nonnull result);

/// Check if a transform is negative (IsNegative).
bool OCCTShapeTransformIsNegative(OCCTShapeRef _Nonnull shape);

/// Create displacement transform from one coordinate system to another.
void OCCTTrsfDisplacement(double fromPx, double fromPy, double fromPz,
                           double fromDx, double fromDy, double fromDz,
                           double toPx, double toPy, double toPz,
                           double toDx, double toDy, double toDz,
                           double* _Nonnull a11, double* _Nonnull a12, double* _Nonnull a13, double* _Nonnull a14,
                           double* _Nonnull a21, double* _Nonnull a22, double* _Nonnull a23, double* _Nonnull a24,
                           double* _Nonnull a31, double* _Nonnull a32, double* _Nonnull a33, double* _Nonnull a34);

/// Create transformation between two coordinate systems.
void OCCTTrsfTransformation(double fromPx, double fromPy, double fromPz,
                             double fromDx, double fromDy, double fromDz,
                             double toPx, double toPy, double toPz,
                             double toDx, double toDy, double toDz,
                             double* _Nonnull a11, double* _Nonnull a12, double* _Nonnull a13, double* _Nonnull a14,
                             double* _Nonnull a21, double* _Nonnull a22, double* _Nonnull a23, double* _Nonnull a24,
                             double* _Nonnull a31, double* _Nonnull a32, double* _Nonnull a33, double* _Nonnull a34);

// MARK: - TopExp extras (v0.118.0)

/// Find common vertex between two edges. Returns false if none.
bool OCCTEdgesCommonVertex(OCCTShapeRef _Nonnull edge1, OCCTShapeRef _Nonnull edge2,
                            double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

// MARK: - BRep_Tool extras (v0.118.0)

/// Check if edge has SameParameter flag set.
bool OCCTEdgeSameParameter(OCCTShapeRef _Nonnull edge);

/// Check if edge has SameRange flag set.
bool OCCTEdgeSameRange(OCCTShapeRef _Nonnull edge);

/// Check if face has NaturalRestriction flag.
bool OCCTFaceNaturalRestriction(OCCTShapeRef _Nonnull face);

/// Check if edge is geometric (has 3D curve or curve on surface).
bool OCCTEdgeIsGeometric(OCCTShapeRef _Nonnull edge);

/// Check if face is geometric (has underlying surface).
bool OCCTFaceIsGeometric(OCCTShapeRef _Nonnull face);

// MARK: - Sewing extras (v0.118.0)

/// Get number of multiple edges from sewing operation.
int32_t OCCTSewingNbMultipleEdges(OCCTSewingRef _Nonnull sewing);

/// Check if edge is a multiple edge (shared by >2 faces) after sewing.
bool OCCTSewingIsMultipleEdge(OCCTSewingRef _Nonnull sewing, int32_t index,
                               OCCTShapeRef _Nullable * _Nonnull outEdge);

// MARK: - v0.119.0: BREP serialization, gp distance/contains, BezierSurface, Curve2D Bezier/BSpline extras, BSplineSurface extras

// --- BREP string serialization ---

/// Serialize a shape to BREP format string. Caller must free the returned string with free().
char* _Nullable OCCTShapeToBREPString(OCCTShapeRef _Nonnull shape);

/// Deserialize a shape from a BREP format string.
OCCTShapeRef _Nullable OCCTShapeFromBREPString(const char* _Nonnull brepString);

// --- gp_Pln distance/contains ---

/// Distance from a plane (given by origin + normal) to a point.
double OCCTPlaneDistanceToPoint(double ox, double oy, double oz,
                                double nx, double ny, double nz,
                                double px, double py, double pz);

/// Distance from a plane to a line (given by line point + direction).
double OCCTPlaneDistanceToLine(double ox, double oy, double oz,
                               double nx, double ny, double nz,
                               double lx, double ly, double lz,
                               double dx, double dy, double dz);

/// Check if a plane contains a point within tolerance.
bool OCCTPlaneContainsPoint(double ox, double oy, double oz,
                            double nx, double ny, double nz,
                            double px, double py, double pz,
                            double tolerance);

// --- gp_Lin distance/contains ---

/// Distance from a line (point + direction) to a point.
double OCCTLineDistanceToPoint(double lx, double ly, double lz,
                               double dx, double dy, double dz,
                               double px, double py, double pz);

/// Distance between two lines.
double OCCTLineDistanceToLine(double l1x, double l1y, double l1z,
                              double d1x, double d1y, double d1z,
                              double l2x, double l2y, double l2z,
                              double d2x, double d2y, double d2z);

/// Check if a line contains a point within tolerance.
bool OCCTLineContainsPoint(double lx, double ly, double lz,
                           double dx, double dy, double dz,
                           double px, double py, double pz,
                           double tolerance);

// --- Geom_BezierSurface queries ---

/// Number of U poles of a Bezier surface.
int32_t OCCTSurfaceBezierNbUPoles(OCCTSurfaceRef _Nonnull surface);

/// Number of V poles of a Bezier surface.
int32_t OCCTSurfaceBezierNbVPoles(OCCTSurfaceRef _Nonnull surface);

/// U degree of a Bezier surface.
int32_t OCCTSurfaceBezierUDegree(OCCTSurfaceRef _Nonnull surface);

/// V degree of a Bezier surface.
int32_t OCCTSurfaceBezierVDegree(OCCTSurfaceRef _Nonnull surface);

/// Get a pole from a Bezier surface (1-based indices).
void OCCTSurfaceBezierGetPole(OCCTSurfaceRef _Nonnull surface, int32_t uIndex, int32_t vIndex,
                              double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Set a pole on a Bezier surface (1-based indices).
bool OCCTSurfaceBezierSetPole(OCCTSurfaceRef _Nonnull surface, int32_t uIndex, int32_t vIndex,
                              double x, double y, double z);

/// Set a weight on a Bezier surface (1-based indices).
bool OCCTSurfaceBezierSetWeight(OCCTSurfaceRef _Nonnull surface, int32_t uIndex, int32_t vIndex,
                                double weight);

/// Extract a segment of a Bezier surface.
bool OCCTSurfaceBezierSegment(OCCTSurfaceRef _Nonnull surface,
                              double u1, double u2, double v1, double v2);

/// Check if Bezier surface is rational in U.
bool OCCTSurfaceBezierIsURational(OCCTSurfaceRef _Nonnull surface);

/// Check if Bezier surface is rational in V.
bool OCCTSurfaceBezierIsVRational(OCCTSurfaceRef _Nonnull surface);

/// Exchange U and V parametric directions of a Bezier surface.
bool OCCTSurfaceBezierExchangeUV(OCCTSurfaceRef _Nonnull surface);

// --- Curve2D Bezier methods ---

/// Get a pole from a 2D Bezier curve (1-based index).
void OCCTCurve2DBezierGetPole(OCCTCurve2DRef _Nonnull curve, int32_t index,
                              double* _Nonnull x, double* _Nonnull y);

/// Set a pole on a 2D Bezier curve (1-based index).
bool OCCTCurve2DBezierSetPole(OCCTCurve2DRef _Nonnull curve, int32_t index,
                              double x, double y);

/// Set a weight on a 2D Bezier curve (1-based index).
bool OCCTCurve2DBezierSetWeight(OCCTCurve2DRef _Nonnull curve, int32_t index, double weight);

/// Degree of a 2D Bezier curve.
int32_t OCCTCurve2DBezierDegree(OCCTCurve2DRef _Nonnull curve);

/// Number of poles of a 2D Bezier curve.
int32_t OCCTCurve2DBezierPoleCount(OCCTCurve2DRef _Nonnull curve);

/// Check if a 2D Bezier curve is rational.
bool OCCTCurve2DBezierIsRational(OCCTCurve2DRef _Nonnull curve);

/// Compute parameter resolution from 2D tolerance for a 2D Bezier curve.
double OCCTCurve2DBezierResolution(OCCTCurve2DRef _Nonnull curve, double tolerance);

// --- Curve2D BSpline extras ---

/// Set periodic/non-periodic on a 2D BSpline curve.
bool OCCTCurve2DBSplineSetPeriodic(OCCTCurve2DRef _Nonnull curve, bool periodic);

/// Get weight at index (1-based) from a 2D BSpline curve.
double OCCTCurve2DBSplineGetWeight(OCCTCurve2DRef _Nonnull curve, int32_t index);

/// Get all weights from a 2D BSpline curve (caller allocates array of size PoleCount).
void OCCTCurve2DBSplineGetWeights(OCCTCurve2DRef _Nonnull curve, double* _Nonnull weights);

// --- BSplineSurface extras ---

/// Compute U and V parameter resolution for a given 3D tolerance.
void OCCTSurfaceBSplineResolution(OCCTSurfaceRef _Nonnull surface, double tolerance3d,
                                  double* _Nonnull uResolution, double* _Nonnull vResolution);

/// Set U periodic on a BSpline surface.
bool OCCTSurfaceBSplineSetUPeriodic(OCCTSurfaceRef _Nonnull surface, bool periodic);

/// Set V periodic on a BSpline surface.
bool OCCTSurfaceBSplineSetVPeriodic(OCCTSurfaceRef _Nonnull surface, bool periodic);

/// Get a weight from a BSpline surface (1-based indices).
double OCCTSurfaceBSplineGetWeight(OCCTSurfaceRef _Nonnull surface, int32_t uIndex, int32_t vIndex);

// MARK: - v0.120.0: Final cleanup — IsCN, ReversedParameter, ParametricTransformation,
//                    gp extras, surface reversed copies, BSpline/Bezier MaxDegree/Resolution

// --- Curve3D continuity queries ---

/// Check if a 3D curve has Cn continuity.
bool OCCTCurve3DIsCN(OCCTCurve3DRef _Nonnull curve, int32_t n);

/// Get the reversed parameter value for a 3D curve.
double OCCTCurve3DReversedParameter(OCCTCurve3DRef _Nonnull curve, double u);

/// Get the parametric transformation scale factor for a 3D curve under a geometric transform.
/// Pass the transform as 12 doubles: 3x3 rotation matrix (row-major) + 3 translation.
double OCCTCurve3DParametricTransformation(OCCTCurve3DRef _Nonnull curve,
                                            const double* _Nonnull trsf12);

// --- Curve2D continuity queries ---

/// Check if a 2D curve has Cn continuity.
bool OCCTCurve2DIsCN(OCCTCurve2DRef _Nonnull curve, int32_t n);

/// Get the reversed parameter value for a 2D curve.
double OCCTCurve2DReversedParameter(OCCTCurve2DRef _Nonnull curve, double u);

// --- Surface continuity queries ---

/// Check if a surface has Cn continuity in U direction.
bool OCCTSurfaceIsCNu(OCCTSurfaceRef _Nonnull surface, int32_t n);

/// Check if a surface has Cn continuity in V direction.
bool OCCTSurfaceIsCNv(OCCTSurfaceRef _Nonnull surface, int32_t n);

/// Create a U-reversed copy of a surface.
OCCTSurfaceRef _Nullable OCCTSurfaceUReversed(OCCTSurfaceRef _Nonnull surface);

/// Create a V-reversed copy of a surface.
OCCTSurfaceRef _Nullable OCCTSurfaceVReversed(OCCTSurfaceRef _Nonnull surface);

/// Get the reversed U parameter value.
double OCCTSurfaceUReversedParameter(OCCTSurfaceRef _Nonnull surface, double u);

/// Get the reversed V parameter value.
double OCCTSurfaceVReversedParameter(OCCTSurfaceRef _Nonnull surface, double v);

// --- BSpline surface RemoveVKnot ---

/// Remove a V knot from a BSpline surface. Returns true if successful.
bool OCCTSurfaceBSplineRemoveVKnot(OCCTSurfaceRef _Nonnull surface,
                                     int32_t index, int32_t mult, double tol);

// --- gp_Vec extras ---

/// Compute the magnitude of the cross product of two vectors.
double OCCTVecCrossMagnitude(double v1x, double v1y, double v1z,
                              double v2x, double v2y, double v2z);

/// Compute the square magnitude of the cross product of two vectors.
double OCCTVecCrossSquareMagnitude(double v1x, double v1y, double v1z,
                                    double v2x, double v2y, double v2z);

// --- gp_Dir extras ---

/// Check if two directions are opposite within angular tolerance (radians).
bool OCCTDirIsOpposite(double d1x, double d1y, double d1z,
                        double d2x, double d2y, double d2z,
                        double angularTolerance);

/// Check if two directions are normal (perpendicular) within angular tolerance (radians).
bool OCCTDirIsNormal(double d1x, double d1y, double d1z,
                      double d2x, double d2y, double d2z,
                      double angularTolerance);

// --- Bezier curve/surface Resolution + MaxDegree ---

/// Compute parameter resolution for a 3D Bezier curve from a 3D tolerance.
double OCCTCurve3DBezierResolution(OCCTCurve3DRef _Nonnull curve, double tolerance3d);

/// Get the maximum degree for Bezier curves (3D).
int32_t OCCTCurve3DBezierMaxDegree(void);

/// Get the maximum degree for 2D Bezier curves.
int32_t OCCTCurve2DBezierMaxDegree(void);

/// Compute U and V parameter resolution for a Bezier surface from a 3D tolerance.
void OCCTSurfaceBezierResolution(OCCTSurfaceRef _Nonnull surface, double tolerance3d,
                                  double* _Nonnull uResolution, double* _Nonnull vResolution);

/// Get the maximum degree for Bezier surfaces.
int32_t OCCTSurfaceBezierMaxDegree(void);

// --- BSpline MaxDegree (surface + 2D curve) ---

/// Get the maximum degree for BSpline surfaces (static).
int32_t OCCTSurfaceBSplineMaxDegree(void);

/// Get the maximum degree for 2D BSpline curves (static).
int32_t OCCTCurve2DBSplineMaxDegree(void);

// =============================================================================
// MARK: - v0.121.0: BSpline completions, FilletBuilder, ChamferBuilder
// =============================================================================

// --- BSplineSurface completions ---

/// Remove U periodicity from BSpline surface.
bool OCCTSurfaceBSplineSetUNotPeriodic(OCCTSurfaceRef _Nonnull surface);

/// Remove V periodicity from BSpline surface.
bool OCCTSurfaceBSplineSetVNotPeriodic(OCCTSurfaceRef _Nonnull surface);

/// Set origin knot index in U direction (1-based).
bool OCCTSurfaceBSplineSetUOrigin(OCCTSurfaceRef _Nonnull surface, int32_t index);

/// Set origin knot index in V direction (1-based).
bool OCCTSurfaceBSplineSetVOrigin(OCCTSurfaceRef _Nonnull surface, int32_t index);

/// Increase U multiplicity at knot index to at least mult (1-based).
bool OCCTSurfaceBSplineIncreaseUMultiplicity(OCCTSurfaceRef _Nonnull surface, int32_t index, int32_t mult);

/// Increase V multiplicity at knot index to at least mult (1-based).
bool OCCTSurfaceBSplineIncreaseVMultiplicity(OCCTSurfaceRef _Nonnull surface, int32_t index, int32_t mult);

/// Batch insert U knots with multiplicities.
bool OCCTSurfaceBSplineInsertUKnots(OCCTSurfaceRef _Nonnull surface,
                                     const double* _Nonnull knots,
                                     const int32_t* _Nonnull mults,
                                     int32_t count, double tol);

/// Batch insert V knots with multiplicities.
bool OCCTSurfaceBSplineInsertVKnots(OCCTSurfaceRef _Nonnull surface,
                                     const double* _Nonnull knots,
                                     const int32_t* _Nonnull mults,
                                     int32_t count, double tol);

/// Move point on BSpline surface to pass through (px,py,pz) at (u,v), adjusting poles in range.
bool OCCTSurfaceBSplineMovePoint(OCCTSurfaceRef _Nonnull surface,
                                  double u, double v,
                                  double px, double py, double pz,
                                  int32_t uIndex1, int32_t uIndex2,
                                  int32_t vIndex1, int32_t vIndex2);

/// Set an entire column of poles (all U poles at vIndex, 1-based).
bool OCCTSurfaceBSplineSetPoleCol(OCCTSurfaceRef _Nonnull surface,
                                   int32_t vIndex,
                                   const double* _Nonnull coords, int32_t count);

/// Set an entire row of poles (all V poles at uIndex, 1-based).
bool OCCTSurfaceBSplineSetPoleRow(OCCTSurfaceRef _Nonnull surface,
                                   int32_t uIndex,
                                   const double* _Nonnull coords, int32_t count);

// --- BSplineCurve 3D completions ---

/// Remove periodicity from 3D BSpline curve.
bool OCCTCurve3DBSplineSetNotPeriodic(OCCTCurve3DRef _Nonnull curve);

/// Set origin knot index (1-based) on periodic 3D BSpline curve.
bool OCCTCurve3DBSplineSetOrigin(OCCTCurve3DRef _Nonnull curve, int32_t index);

/// Increase multiplicity of knot at index to at least mult (1-based).
bool OCCTCurve3DBSplineIncreaseMultiplicity(OCCTCurve3DRef _Nonnull curve, int32_t index, int32_t mult);

/// Increment multiplicity of all knots from index1 to index2 by step (1-based).
bool OCCTCurve3DBSplineIncrementMultiplicity(OCCTCurve3DRef _Nonnull curve, int32_t index1, int32_t index2, int32_t step);

/// Set all knot values at once (count must match NbKnots).
bool OCCTCurve3DBSplineSetKnots(OCCTCurve3DRef _Nonnull curve, const double* _Nonnull knots, int32_t count);

/// Reverse parameterization of 3D BSpline curve.
bool OCCTCurve3DBSplineReverse(OCCTCurve3DRef _Nonnull curve);

/// Move point and tangent at parameter u on 3D BSpline curve.
bool OCCTCurve3DBSplineMovePointAndTangent(OCCTCurve3DRef _Nonnull curve, double u,
                                            double px, double py, double pz,
                                            double tx, double ty, double tz,
                                            double tolerance,
                                            int32_t startIndex, int32_t endIndex);

// --- BSplineCurve 2D completions ---

/// Remove periodicity from 2D BSpline curve.
bool OCCTCurve2DBSplineSetNotPeriodic(OCCTCurve2DRef _Nonnull curve);

/// Set origin knot index (1-based) on periodic 2D BSpline curve.
bool OCCTCurve2DBSplineSetOrigin(OCCTCurve2DRef _Nonnull curve, int32_t index);

/// Increase multiplicity of knot at index to at least mult (1-based).
bool OCCTCurve2DBSplineIncreaseMultiplicity(OCCTCurve2DRef _Nonnull curve, int32_t index, int32_t mult);

/// Increment multiplicity of all knots from index1 to index2 by step (1-based).
bool OCCTCurve2DBSplineIncrementMultiplicity(OCCTCurve2DRef _Nonnull curve, int32_t index1, int32_t index2, int32_t step);

/// Set all knot values at once (count must match NbKnots).
bool OCCTCurve2DBSplineSetKnots(OCCTCurve2DRef _Nonnull curve, const double* _Nonnull knots, int32_t count);

/// Reverse parameterization of 2D BSpline curve.
bool OCCTCurve2DBSplineReverse(OCCTCurve2DRef _Nonnull curve);

/// Move point and tangent at parameter u on 2D BSpline curve.
bool OCCTCurve2DBSplineMovePointAndTangent(OCCTCurve2DRef _Nonnull curve, double u,
                                            double px, double py,
                                            double tx, double ty,
                                            double tolerance,
                                            int32_t startIndex, int32_t endIndex);

// --- FilletBuilder (BRepFilletAPI_MakeFillet) ---

typedef struct OCCTFilletBuilder* OCCTFilletBuilderRef;

/// Create a fillet builder on a shape.
OCCTFilletBuilderRef _Nullable OCCTFilletBuilderCreate(OCCTShapeRef _Nonnull shape);

/// Release a fillet builder.
void OCCTFilletBuilderRelease(OCCTFilletBuilderRef _Nonnull builder);

/// Add an edge with constant radius.
bool OCCTFilletBuilderAddEdge(OCCTFilletBuilderRef _Nonnull builder,
                               OCCTEdgeRef _Nonnull edge, double radius);

/// Add an edge with evolving radius (r1 at start, r2 at end).
bool OCCTFilletBuilderAddEdgeEvolving(OCCTFilletBuilderRef _Nonnull builder,
                                       OCCTEdgeRef _Nonnull edge, double r1, double r2);

/// Build the filleted result.
OCCTShapeRef _Nullable OCCTFilletBuilderBuild(OCCTFilletBuilderRef _Nonnull builder);

/// Number of contours.
int32_t OCCTFilletBuilderNbContours(OCCTFilletBuilderRef _Nonnull builder);

/// Number of edges in a contour (1-based index).
int32_t OCCTFilletBuilderNbEdges(OCCTFilletBuilderRef _Nonnull builder, int32_t contourIndex);

/// Whether the builder has a result (may be partial).
bool OCCTFilletBuilderHasResult(OCCTFilletBuilderRef _Nonnull builder);

/// Get the shape that caused failure (if any).
OCCTShapeRef _Nullable OCCTFilletBuilderBadShape(OCCTFilletBuilderRef _Nonnull builder);

/// Number of faulty contours.
int32_t OCCTFilletBuilderNbFaultyContours(OCCTFilletBuilderRef _Nonnull builder);

/// Number of faulty vertices.
int32_t OCCTFilletBuilderNbFaultyVertices(OCCTFilletBuilderRef _Nonnull builder);

/// Get radius of a contour (1-based index).
double OCCTFilletBuilderGetRadius(OCCTFilletBuilderRef _Nonnull builder, int32_t contourIndex);

/// Get length of a contour (1-based index).
double OCCTFilletBuilderGetLength(OCCTFilletBuilderRef _Nonnull builder, int32_t contourIndex);

/// Whether a contour has constant radius (1-based index).
bool OCCTFilletBuilderIsConstant(OCCTFilletBuilderRef _Nonnull builder, int32_t contourIndex);

/// Remove an edge from its contour.
bool OCCTFilletBuilderRemoveEdge(OCCTFilletBuilderRef _Nonnull builder, OCCTEdgeRef _Nonnull edge);

/// Reset all contours.
void OCCTFilletBuilderReset(OCCTFilletBuilderRef _Nonnull builder);

// --- ChamferBuilder (BRepFilletAPI_MakeChamfer) ---

typedef struct OCCTChamferBuilder* OCCTChamferBuilderRef;

/// Create a chamfer builder on a shape.
OCCTChamferBuilderRef _Nullable OCCTChamferBuilderCreate(OCCTShapeRef _Nonnull shape);

/// Release a chamfer builder.
void OCCTChamferBuilderRelease(OCCTChamferBuilderRef _Nonnull builder);

/// Add an edge with symmetric distance.
bool OCCTChamferBuilderAddEdge(OCCTChamferBuilderRef _Nonnull builder,
                                OCCTEdgeRef _Nonnull edge, double dist);

/// Add an edge with two distances (requires face for orientation).
bool OCCTChamferBuilderAddEdgeTwoDists(OCCTChamferBuilderRef _Nonnull builder,
                                        OCCTEdgeRef _Nonnull edge,
                                        OCCTFaceRef _Nonnull face,
                                        double d1, double d2);

/// Add an edge with distance and angle (requires face for orientation).
bool OCCTChamferBuilderAddEdgeDistAngle(OCCTChamferBuilderRef _Nonnull builder,
                                         OCCTEdgeRef _Nonnull edge,
                                         OCCTFaceRef _Nonnull face,
                                         double dist, double angle);

/// Build the chamfered result.
OCCTShapeRef _Nullable OCCTChamferBuilderBuild(OCCTChamferBuilderRef _Nonnull builder);

/// Number of contours.
int32_t OCCTChamferBuilderNbContours(OCCTChamferBuilderRef _Nonnull builder);

/// Whether a contour uses distance-angle mode (1-based index).
bool OCCTChamferBuilderIsDistAngle(OCCTChamferBuilderRef _Nonnull builder, int32_t contourIndex);

// --- ChamferBuilder completions (v0.124.0) ---

/// Number of edges in a contour (1-based index).
int32_t OCCTChamferBuilderNbEdges(OCCTChamferBuilderRef _Nonnull builder, int32_t contourIndex);

/// Get the symmetric distance for contour IC (1-based).
void OCCTChamferBuilderGetDist(OCCTChamferBuilderRef _Nonnull builder, int32_t contourIndex, double* _Nonnull dist);

/// Get the two distances for contour IC (1-based).
void OCCTChamferBuilderGetDists(OCCTChamferBuilderRef _Nonnull builder, int32_t contourIndex,
                                 double* _Nonnull d1, double* _Nonnull d2);

/// Get distance and angle for contour IC (1-based).
void OCCTChamferBuilderGetDistAngle(OCCTChamferBuilderRef _Nonnull builder, int32_t contourIndex,
                                     double* _Nonnull dist, double* _Nonnull angle);

/// Set symmetric distance on a contour (requires face for orientation).
bool OCCTChamferBuilderSetDist(OCCTChamferBuilderRef _Nonnull builder, double dist,
                                int32_t contourIndex, OCCTFaceRef _Nonnull face);

/// Set two distances on a contour (requires face for orientation).
bool OCCTChamferBuilderSetDists(OCCTChamferBuilderRef _Nonnull builder, double d1, double d2,
                                 int32_t contourIndex, OCCTFaceRef _Nonnull face);

/// Set distance and angle on a contour (requires face for orientation).
bool OCCTChamferBuilderSetDistAngle(OCCTChamferBuilderRef _Nonnull builder, double dist, double angle,
                                     int32_t contourIndex, OCCTFaceRef _Nonnull face);

/// Length of contour IC (1-based).
double OCCTChamferBuilderLength(OCCTChamferBuilderRef _Nonnull builder, int32_t contourIndex);

/// Remove the contour containing the given edge.
bool OCCTChamferBuilderRemoveEdge(OCCTChamferBuilderRef _Nonnull builder, OCCTEdgeRef _Nonnull edge);

/// Reset all contours, canceling effects of Build.
void OCCTChamferBuilderReset(OCCTChamferBuilderRef _Nonnull builder);

/// Whether contour IC (1-based) is closed.
bool OCCTChamferBuilderClosed(OCCTChamferBuilderRef _Nonnull builder, int32_t contourIndex);

/// Whether contour IC (1-based) is closed and tangent at closure.
bool OCCTChamferBuilderClosedAndTangent(OCCTChamferBuilderRef _Nonnull builder, int32_t contourIndex);

/// Whether contour IC is symmetric.
bool OCCTChamferBuilderIsSymmetric(OCCTChamferBuilderRef _Nonnull builder, int32_t contourIndex);

/// Whether contour IC uses two distances.
bool OCCTChamferBuilderIsTwoDists(OCCTChamferBuilderRef _Nonnull builder, int32_t contourIndex);

/// Get edge J in contour I (both 1-based).
OCCTShapeRef _Nullable OCCTChamferBuilderEdge(OCCTChamferBuilderRef _Nonnull builder, int32_t contourIndex, int32_t edgeIndex);

/// Get first vertex of contour IC (1-based).
OCCTShapeRef _Nullable OCCTChamferBuilderFirstVertex(OCCTChamferBuilderRef _Nonnull builder, int32_t contourIndex);

/// Get last vertex of contour IC (1-based).
OCCTShapeRef _Nullable OCCTChamferBuilderLastVertex(OCCTChamferBuilderRef _Nonnull builder, int32_t contourIndex);

/// Get the contour index containing the given edge (0 if not found).
int32_t OCCTChamferBuilderContour(OCCTChamferBuilderRef _Nonnull builder, OCCTEdgeRef _Nonnull edge);

/// Curvilinear abscissa of vertex on contour IC (1-based).
double OCCTChamferBuilderAbscissa(OCCTChamferBuilderRef _Nonnull builder, int32_t contourIndex, OCCTShapeRef _Nonnull vertex);

/// Relative abscissa (0..1) of vertex on contour IC (1-based).
double OCCTChamferBuilderRelativeAbscissa(OCCTChamferBuilderRef _Nonnull builder, int32_t contourIndex, OCCTShapeRef _Nonnull vertex);

// --- FilletBuilder completions (v0.124.0) ---

/// Set radius on a specific edge in a contour (1-based indices).
bool OCCTFilletBuilderSetRadiusOnEdge(OCCTFilletBuilderRef _Nonnull builder, double radius,
                                       int32_t contourIndex, OCCTEdgeRef _Nonnull edge);

/// Set radius at a specific vertex in a contour (1-based index).
bool OCCTFilletBuilderSetRadiusAtVertex(OCCTFilletBuilderRef _Nonnull builder, double radius,
                                         int32_t contourIndex, OCCTShapeRef _Nonnull vertex);

/// Set two radii (evolving) on a contour edge (1-based indices).
bool OCCTFilletBuilderSetTwoRadii(OCCTFilletBuilderRef _Nonnull builder, double r1, double r2,
                                   int32_t contourIndex, int32_t edgeInContour);

/// Get contour index for an edge (0 if not found, 1-based otherwise).
int32_t OCCTFilletBuilderContour(OCCTFilletBuilderRef _Nonnull builder, OCCTEdgeRef _Nonnull edge);

/// Get edge J in contour I (both 1-based).
OCCTShapeRef _Nullable OCCTFilletBuilderEdge(OCCTFilletBuilderRef _Nonnull builder, int32_t contourIndex, int32_t edgeIndex);

/// First vertex of contour IC (1-based).
OCCTShapeRef _Nullable OCCTFilletBuilderFirstVertex(OCCTFilletBuilderRef _Nonnull builder, int32_t contourIndex);

/// Last vertex of contour IC (1-based).
OCCTShapeRef _Nullable OCCTFilletBuilderLastVertex(OCCTFilletBuilderRef _Nonnull builder, int32_t contourIndex);

/// Curvilinear abscissa of vertex on contour IC (1-based).
double OCCTFilletBuilderAbscissa(OCCTFilletBuilderRef _Nonnull builder, int32_t contourIndex, OCCTShapeRef _Nonnull vertex);

/// Relative abscissa (0..1) of vertex on contour IC (1-based).
double OCCTFilletBuilderRelativeAbscissa(OCCTFilletBuilderRef _Nonnull builder, int32_t contourIndex, OCCTShapeRef _Nonnull vertex);

/// Whether contour IC (1-based) is closed and tangent.
bool OCCTFilletBuilderClosedAndTangent(OCCTFilletBuilderRef _Nonnull builder, int32_t contourIndex);

/// Whether contour IC (1-based) is closed.
bool OCCTFilletBuilderClosed(OCCTFilletBuilderRef _Nonnull builder, int32_t contourIndex);

/// Number of surfaces after build.
int32_t OCCTFilletBuilderNbSurfaces(OCCTFilletBuilderRef _Nonnull builder);

/// Number of computed surfaces for contour IC (1-based).
int32_t OCCTFilletBuilderNbComputedSurfaces(OCCTFilletBuilderRef _Nonnull builder, int32_t contourIndex);

/// Error status for contour IC (1-based). Returns ChFiDS_ErrorStatus as int.
int32_t OCCTFilletBuilderStripeStatus(OCCTFilletBuilderRef _Nonnull builder, int32_t contourIndex);

/// Get the faulty contour index for the I-th fault (1-based).
int32_t OCCTFilletBuilderFaultyContour(OCCTFilletBuilderRef _Nonnull builder, int32_t faultIndex);

/// Get the faulty vertex for the I-th fault (1-based).
OCCTShapeRef _Nullable OCCTFilletBuilderFaultyVertex(OCCTFilletBuilderRef _Nonnull builder, int32_t faultIndex);

// --- WireAnalyzer (ShapeAnalysis_Wire) (v0.124.0) ---

typedef struct OCCTWireAnalyzer* OCCTWireAnalyzerRef;

/// Create a wire analyzer from a wire, face, and precision.
OCCTWireAnalyzerRef _Nullable OCCTWireAnalyzerCreate(OCCTShapeRef _Nonnull wire,
                                                       OCCTShapeRef _Nonnull face,
                                                       double precision);

/// Release a wire analyzer.
void OCCTWireAnalyzerRelease(OCCTWireAnalyzerRef _Nonnull analyzer);

/// Run all checks (CheckOrder, CheckSmall, CheckConnected, etc.).
bool OCCTWireAnalyzerPerform(OCCTWireAnalyzerRef _Nonnull analyzer);

/// Check edge ordering.
bool OCCTWireAnalyzerCheckOrder(OCCTWireAnalyzerRef _Nonnull analyzer);

/// Check if edge num (1-based) is connected to previous.
bool OCCTWireAnalyzerCheckConnected(OCCTWireAnalyzerRef _Nonnull analyzer, int32_t edgeNum);

/// Check if edge num (1-based) is small.
bool OCCTWireAnalyzerCheckSmall(OCCTWireAnalyzerRef _Nonnull analyzer, int32_t edgeNum);

/// Check if edge num (1-based) is degenerated.
bool OCCTWireAnalyzerCheckDegenerated(OCCTWireAnalyzerRef _Nonnull analyzer, int32_t edgeNum);

/// Check 3D gap at edge num (1-based, 0 = all).
bool OCCTWireAnalyzerCheckGap3d(OCCTWireAnalyzerRef _Nonnull analyzer, int32_t edgeNum);

/// Check 2D gap at edge num (1-based, 0 = all).
bool OCCTWireAnalyzerCheckGap2d(OCCTWireAnalyzerRef _Nonnull analyzer, int32_t edgeNum);

/// Check if edge num (1-based) is a seam.
bool OCCTWireAnalyzerCheckSeam(OCCTWireAnalyzerRef _Nonnull analyzer, int32_t edgeNum);

/// Check if edge num (1-based) is lacking.
bool OCCTWireAnalyzerCheckLacking(OCCTWireAnalyzerRef _Nonnull analyzer, int32_t edgeNum);

/// Check wire self-intersection.
bool OCCTWireAnalyzerCheckSelfIntersection(OCCTWireAnalyzerRef _Nonnull analyzer);

/// Check if wire is closed.
bool OCCTWireAnalyzerCheckClosed(OCCTWireAnalyzerRef _Nonnull analyzer);

/// Get the minimum 3D distance computed.
double OCCTWireAnalyzerMinDistance3d(OCCTWireAnalyzerRef _Nonnull analyzer);

/// Get the maximum 3D distance computed.
double OCCTWireAnalyzerMaxDistance3d(OCCTWireAnalyzerRef _Nonnull analyzer);

/// Number of edges in the wire.
int32_t OCCTWireAnalyzerNbEdges(OCCTWireAnalyzerRef _Nonnull analyzer);

/// Whether the wire is loaded.
bool OCCTWireAnalyzerIsLoaded(OCCTWireAnalyzerRef _Nonnull analyzer);

/// Whether the analyzer is ready (wire + face loaded).
bool OCCTWireAnalyzerIsReady(OCCTWireAnalyzerRef _Nonnull analyzer);

// MARK: - GLTF Import/Export (v0.121.0)

/// Import a GLTF/GLB file as a shape (mesh-based). Returns NULL on failure.
OCCTShapeRef _Nullable OCCTImportGLTF(const char* _Nonnull path);

/// Export a shape to GLTF format. isBinary=true for GLB, false for GLTF.
/// The shape must be meshed first (call mesh() before exporting).
bool OCCTExportGLTF(OCCTShapeRef _Nonnull shape, const char* _Nonnull path,
                      bool isBinary, double deflection);

/// Load a GLTF/GLB file into an XDE document (preserves names, materials, colors).
OCCTDocumentRef _Nullable OCCTDocumentLoadGLTF(const char* _Nonnull path);

/// Write an XDE document to GLTF/GLB format.
bool OCCTDocumentWriteGLTF(OCCTDocumentRef _Nonnull doc, const char* _Nonnull path, bool isBinary);

// MARK: - v0.122.0: WireFixer extended, ShapeFix_Edge, BRepTools/BRepLib statics, History extended, Sewing extended

// --- WireFixer extended (ShapeFix_Wire) ---

/// Fix 2D gaps between edges.
bool OCCTWireFixerFixGaps2d(OCCTWireFixerRef _Nonnull fixer);

/// Fix seam edge at the given index (1-based).
bool OCCTWireFixerFixSeam(OCCTWireFixerRef _Nonnull fixer, int32_t edgeIndex);

/// Fix shifted pcurves.
bool OCCTWireFixerFixShifted(OCCTWireFixerRef _Nonnull fixer);

/// Fix notched edges.
bool OCCTWireFixerFixNotchedEdges(OCCTWireFixerRef _Nonnull fixer);

/// Fix tail edges.
bool OCCTWireFixerFixTails(OCCTWireFixerRef _Nonnull fixer);

/// Set the maximum tail angle (radians).
void OCCTWireFixerSetMaxTailAngle(OCCTWireFixerRef _Nonnull fixer, double angle);

/// Set the maximum tail width.
void OCCTWireFixerSetMaxTailWidth(OCCTWireFixerRef _Nonnull fixer, double width);

// --- ShapeFix_Edge extended ---

/// Add missing 3D curve to an edge. Returns true if fixed.
bool OCCTShapeFixEdgeAddCurve3d(OCCTShapeRef _Nonnull edge);

/// Add missing PCurve to an edge on a face. isSeam: true for seam edges.
bool OCCTShapeFixEdgeAddPCurve(OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull face, bool isSeam);

/// Remove 3D curve from an edge. Returns true if removed.
bool OCCTShapeFixEdgeRemoveCurve3d(OCCTShapeRef _Nonnull edge);

/// Remove PCurve from an edge on a face. Returns true if removed.
bool OCCTShapeFixEdgeRemovePCurve(OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull face);

/// Fix reversed 2D curve on an edge/face pair.
bool OCCTShapeFixEdgeFixReversed2d(OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull face);

// --- BRepTools statics ---

/// Remove triangulation from a shape (BRepTools::Clean).
void OCCTBRepToolsCleanTriangulation(OCCTShapeRef _Nonnull shape);

/// Remove internal edges/vertices from a shape (BRepTools::RemoveInternals).
void OCCTBRepToolsRemoveInternals(OCCTShapeRef _Nonnull shape);

/// Detect if a face is closed in U and/or V (BRepTools::DetectClosedness).
/// Sets isClosedU and isClosedV.
void OCCTBRepToolsDetectClosedness(OCCTShapeRef _Nonnull face,
                                    bool* _Nonnull isClosedU, bool* _Nonnull isClosedV);

/// Evaluate and update tolerance of an edge on a face. Returns the new tolerance.
/// Uses BRep_Tool to extract curves, then BRepTools::EvalAndUpdateTol.
double OCCTBRepToolsEvalAndUpdateTol(OCCTShapeRef _Nonnull edge,
                                      OCCTShapeRef _Nonnull face);

/// Count 3D edges in a shape (via BRepTools::Map3DEdges).
int32_t OCCTBRepToolsMap3DEdgeCount(OCCTShapeRef _Nonnull shape);

/// Update face UV points (BRepTools::UpdateFaceUVPoints).
void OCCTBRepToolsUpdateFaceUVPoints(OCCTShapeRef _Nonnull face);

/// Compare two vertices for geometric equality.
bool OCCTBRepToolsCompareVertices(OCCTShapeRef _Nonnull v1, OCCTShapeRef _Nonnull v2);

/// Compare two edges for geometric equality.
bool OCCTBRepToolsCompareEdges(OCCTShapeRef _Nonnull e1, OCCTShapeRef _Nonnull e2);

/// Check if an edge is really closed on a face.
bool OCCTBRepToolsIsReallyClosed(OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull face);

/// Update a shape (all sub-shape types, BRepTools::Update).
void OCCTBRepToolsUpdate(OCCTShapeRef _Nonnull shape);

// --- BRepLib extended statics ---

/// Ensure normal consistency of triangulated shape. Returns true if normals were fixed.
bool OCCTBRepLibEnsureNormalConsistency(OCCTShapeRef _Nonnull shape, double maxAngleRad);

/// Update deflection information of a shape.
void OCCTBRepLibUpdateDeflection(OCCTShapeRef _Nonnull shape);

/// Get the continuity of the surface across an edge between two faces.
/// Returns GeomAbs_Shape: 0=C0, 1=G1, 2=C1, 3=G2, 4=C2, 5=CN, -1=error.
int32_t OCCTBRepLibContinuityOfFaces(OCCTShapeRef _Nonnull edge,
                                      OCCTShapeRef _Nonnull face1, OCCTShapeRef _Nonnull face2,
                                      double tolerance);

/// Build 3D curves for all edges in a shape. Returns true if all curves built.
bool OCCTBRepLibBuildCurves3dAll(OCCTShapeRef _Nonnull shape, double tolerance);

/// Same-parameter all edges in a shape.
void OCCTBRepLibSameParameterAll(OCCTShapeRef _Nonnull shape, double tolerance,
                                  bool forced);

// --- History extended ---

/// Merge another history into this one.
void OCCTHistoryMerge(OCCTHistoryRef history, OCCTHistoryRef other);

/// Replace a generated entry.
void OCCTHistoryReplaceGenerated(OCCTHistoryRef history,
                                  OCCTShapeRef initial,
                                  OCCTShapeRef generated);

/// Replace a modified entry.
void OCCTHistoryReplaceModified(OCCTHistoryRef history,
                                 OCCTShapeRef initial,
                                 OCCTShapeRef modified);

/// Get the list of shapes that the initial shape was modified to.
/// Writes up to maxCount shape refs into outShapes, returns actual count.
int32_t OCCTHistoryGetModifiedShapes(OCCTHistoryRef history,
                                      OCCTShapeRef initial,
                                      OCCTShapeRef _Nullable* _Nonnull outShapes,
                                      int32_t maxCount);

/// Get the list of shapes generated from the initial shape.
int32_t OCCTHistoryGetGeneratedShapes(OCCTHistoryRef history,
                                       OCCTShapeRef initial,
                                       OCCTShapeRef _Nullable* _Nonnull outShapes,
                                       int32_t maxCount);

// --- Sewing extended ---

/// Get the number of deleted faces after sewing.
int32_t OCCTSewingNbDeletedFaces(OCCTSewingRef _Nonnull sewing);

/// Get a deleted face by index (1-based).
OCCTShapeRef _Nullable OCCTSewingDeletedFace(OCCTSewingRef _Nonnull sewing, int32_t index);

/// Check if a sub-shape was modified by sewing.
bool OCCTSewingIsModified(OCCTSewingRef _Nonnull sewing, OCCTShapeRef _Nonnull shape);

/// Get the modified version of a shape. Returns NULL if not modified.
OCCTShapeRef _Nullable OCCTSewingModified(OCCTSewingRef _Nonnull sewing, OCCTShapeRef _Nonnull shape);

/// Check if a shape is degenerated.
bool OCCTSewingIsDegenerated(OCCTSewingRef _Nonnull sewing, OCCTShapeRef _Nonnull shape);

/// Check if an edge is a section bound.
bool OCCTSewingIsSectionBound(OCCTSewingRef _Nonnull sewing, OCCTShapeRef _Nonnull edge);

/// Get the face that contains the given edge (after sewing).
OCCTShapeRef _Nullable OCCTSewingWhichFace(OCCTSewingRef _Nonnull sewing, OCCTShapeRef _Nonnull edge);

/// Load the base shape context for sewing.
void OCCTSewingLoad(OCCTSewingRef _Nonnull sewing, OCCTShapeRef _Nonnull shape);

/// Set non-manifold mode for sewing.
void OCCTSewingSetNonManifoldMode(OCCTSewingRef _Nonnull sewing, bool nonManifold);

/// Set face mode for sewing (controls face analysis).
void OCCTSewingSetFaceMode(OCCTSewingRef _Nonnull sewing, bool faceMode);

/// Set floating edges mode for sewing.
void OCCTSewingSetFloatingEdgesMode(OCCTSewingRef _Nonnull sewing, bool floatingEdges);

/// Set minimum tolerance for sewing.
void OCCTSewingSetMinTolerance(OCCTSewingRef _Nonnull sewing, double minTol);

/// Set maximum tolerance for sewing.
void OCCTSewingSetMaxTolerance(OCCTSewingRef _Nonnull sewing, double maxTol);

// MARK: - v0.123.0: Builder extensions, Section ops, Curve/Surface queries

// --- ThruSections extensions ---

/// Enable/disable wire compatibility checking.
void OCCTThruSectionsCheckCompatibility(OCCTThruSectionsRef _Nonnull ts, bool check);

/// Set parameterization type (0=ChordLength, 1=Centripetal, 2=IsoParametric).
void OCCTThruSectionsSetParType(OCCTThruSectionsRef _Nonnull ts, int32_t parType);

/// Set criterium weights for the approximation.
void OCCTThruSectionsSetCriteriumWeight(OCCTThruSectionsRef _Nonnull ts, double w1, double w2, double w3);

/// Get the face generated from an edge after building.
OCCTShapeRef _Nullable OCCTThruSectionsGeneratedFace(OCCTThruSectionsRef _Nonnull ts, OCCTShapeRef _Nonnull edge);

// --- CellsBuilder extensions ---

/// Add cells to result selectively: take shapes present in theLSToTake, avoid shapes in theLSToAvoid.
void OCCTCellsBuilderAddToResultSelective(OCCTCellsBuilderRef _Nonnull builder,
                                           const OCCTShapeRef _Nonnull * _Nonnull takeShapes, int32_t takeCount,
                                           const OCCTShapeRef _Nonnull * _Nonnull avoidShapes, int32_t avoidCount,
                                           int32_t material, bool update);

/// Remove cells from result selectively: remove shapes in take but not in avoid.
void OCCTCellsBuilderRemoveFromResult(OCCTCellsBuilderRef _Nonnull builder,
                                       const OCCTShapeRef _Nonnull * _Nonnull takeShapes, int32_t takeCount,
                                       const OCCTShapeRef _Nonnull * _Nonnull avoidShapes, int32_t avoidCount);

/// Get all split parts (before any result composition).
OCCTShapeRef _Nullable OCCTCellsBuilderGetAllParts(OCCTCellsBuilderRef _Nonnull builder);

/// Make containers (wires from edges, shells from faces, etc.).
void OCCTCellsBuilderMakeContainers(OCCTCellsBuilderRef _Nonnull builder);

// --- PipeShell extensions ---

/// Get the pipe shell build status (0=Ok, 1=NotOk, 2=PlaneNotIntersectGuide, 3=ImpossibleContact).
int32_t OCCTPipeShellGetStatus(OCCTPipeShellRef _Nonnull ps);

/// Simulate the pipe shell with a given number of sections.
/// Returns an array of simulated section shapes and their count.
OCCTShapeRef _Nullable * _Nullable OCCTPipeShellSimulate(OCCTPipeShellRef _Nonnull ps, int32_t numSections, int32_t* _Nonnull outCount);

/// Free an array of shapes returned by OCCTPipeShellSimulate.
void OCCTPipeShellSimulateFree(OCCTShapeRef _Nullable * _Nullable shapes, int32_t count);

/// Enable or disable build history tracking. Disabled by default to avoid
/// segfault on closed spine+profile geometries (OCCT bug in BuildHistory).
void OCCTPipeShellSetBuildHistory(OCCTPipeShellRef _Nonnull ps, bool enabled);

// --- UnifySameDomain builder ---

typedef void* OCCTUnifySameDomainRef;

/// Create a UnifySameDomain builder.
OCCTUnifySameDomainRef _Nonnull OCCTUnifySameDomainCreate(OCCTShapeRef _Nonnull shape,
                                                           bool unifyEdges, bool unifyFaces, bool concatBSplines);

/// Release a UnifySameDomain builder.
void OCCTUnifySameDomainRelease(OCCTUnifySameDomainRef _Nonnull usd);

/// Allow or disallow internal edges in unification.
void OCCTUnifySameDomainAllowInternalEdges(OCCTUnifySameDomainRef _Nonnull usd, bool allow);

/// Keep a specific shape from being unified.
void OCCTUnifySameDomainKeepShape(OCCTUnifySameDomainRef _Nonnull usd, OCCTShapeRef _Nonnull shape);

/// Set safe input mode (copies input shape).
void OCCTUnifySameDomainSetSafeInputMode(OCCTUnifySameDomainRef _Nonnull usd, bool safe);

/// Set linear tolerance for unification.
void OCCTUnifySameDomainSetLinearTolerance(OCCTUnifySameDomainRef _Nonnull usd, double tol);

/// Set angular tolerance for unification.
void OCCTUnifySameDomainSetAngularTolerance(OCCTUnifySameDomainRef _Nonnull usd, double tol);

/// Build (perform unification).
void OCCTUnifySameDomainBuild(OCCTUnifySameDomainRef _Nonnull usd);

/// Get the unified result shape.
OCCTShapeRef _Nullable OCCTUnifySameDomainShape(OCCTUnifySameDomainRef _Nonnull usd);

// --- BRepAlgoAPI_Section extended ---

/// Compute section between two shapes with approximation and pcurve options.
/// Returns the section shape.
OCCTShapeRef _Nullable OCCTShapeSectionWithOptions(OCCTShapeRef _Nonnull shape1, OCCTShapeRef _Nonnull shape2,
                                                    bool approximation, bool computePCurve1, bool computePCurve2);

/// Check if an edge of the section has an ancestor face on shape1.
/// Returns the ancestor face, or NULL.
OCCTShapeRef _Nullable OCCTSectionAncestorFaceOn1(OCCTShapeRef _Nonnull shape1, OCCTShapeRef _Nonnull shape2,
                                                    OCCTShapeRef _Nonnull edge,
                                                    bool approximation, bool computePCurve1, bool computePCurve2);

/// Check if an edge of the section has an ancestor face on shape2.
OCCTShapeRef _Nullable OCCTSectionAncestorFaceOn2(OCCTShapeRef _Nonnull shape1, OCCTShapeRef _Nonnull shape2,
                                                    OCCTShapeRef _Nonnull edge,
                                                    bool approximation, bool computePCurve1, bool computePCurve2);

// --- Curve3D queries ---

/// Get the period of a periodic curve (0.0 if not periodic).
double OCCTCurve3DPeriod(OCCTCurve3DRef _Nonnull curve);

/// Get the first parameter of a curve.
double OCCTCurve3DFirstParameter(OCCTCurve3DRef _Nonnull curve);

/// Get the last parameter of a curve.
double OCCTCurve3DLastParameter(OCCTCurve3DRef _Nonnull curve);

// --- Surface queries ---

/// Get the U period of a periodic surface (0.0 if not periodic in U).
double OCCTSurfaceUPeriod(OCCTSurfaceRef _Nonnull surface);

/// Get the V period of a periodic surface (0.0 if not periodic in V).
double OCCTSurfaceVPeriod(OCCTSurfaceRef _Nonnull surface);

// --- Additional Shape queries ---

/// Get a nullified copy of the shape (cleared TShape).
OCCTShapeRef _Nullable OCCTShapeNullified(OCCTShapeRef _Nonnull shape);

/// Get the shape type as a string name.
const char* _Nullable OCCTShapeTypeName(OCCTShapeRef _Nonnull shape);

/// Check if this shape is NOT equal to other.
bool OCCTShapeIsNotEqual(OCCTShapeRef _Nonnull shape1, OCCTShapeRef _Nonnull shape2);

// --- Shape emptied/moved ---

/// Get an emptied copy of the shape (no sub-shapes).
OCCTShapeRef _Nullable OCCTShapeEmptied(OCCTShapeRef _Nonnull shape);

/// Move a shape by an XYZ translation. Returns a new copy.
OCCTShapeRef _Nullable OCCTShapeMoved(OCCTShapeRef _Nonnull shape, double dx, double dy, double dz);

/// Get the shape orientation as integer (0=FORWARD, 1=REVERSED, 2=INTERNAL, 3=EXTERNAL).
int32_t OCCTShapeOrientationValue(OCCTShapeRef _Nonnull shape);

/// Get the number of edges in a shape.
int32_t OCCTShapeNbEdges(OCCTShapeRef _Nonnull shape);

/// Get the number of faces in a shape.
int32_t OCCTShapeNbFaces(OCCTShapeRef _Nonnull shape);

/// Get the number of vertices in a shape.
int32_t OCCTShapeNbVertices(OCCTShapeRef _Nonnull shape);

// MARK: - v0.125.0: BSpline/Bezier deep method completion

// --- Geom_BSplineSurface completions ---

/// Local evaluation D0 within knot span.
void OCCTSurfaceBSplineLocalD0(OCCTSurfaceRef _Nonnull surface, double u, double v,
                                int32_t fromUK1, int32_t toUK2, int32_t fromVK1, int32_t toVK2,
                                double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Local evaluation D1 within knot span.
void OCCTSurfaceBSplineLocalD1(OCCTSurfaceRef _Nonnull surface, double u, double v,
                                int32_t fromUK1, int32_t toUK2, int32_t fromVK1, int32_t toVK2,
                                double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz,
                                double* _Nonnull d1ux, double* _Nonnull d1uy, double* _Nonnull d1uz,
                                double* _Nonnull d1vx, double* _Nonnull d1vy, double* _Nonnull d1vz);

/// Local evaluation D2 within knot span.
void OCCTSurfaceBSplineLocalD2(OCCTSurfaceRef _Nonnull surface, double u, double v,
                                int32_t fromUK1, int32_t toUK2, int32_t fromVK1, int32_t toVK2,
                                double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz,
                                double* _Nonnull d1ux, double* _Nonnull d1uy, double* _Nonnull d1uz,
                                double* _Nonnull d1vx, double* _Nonnull d1vy, double* _Nonnull d1vz,
                                double* _Nonnull d2ux, double* _Nonnull d2uy, double* _Nonnull d2uz,
                                double* _Nonnull d2vx, double* _Nonnull d2vy, double* _Nonnull d2vz,
                                double* _Nonnull d2uvx, double* _Nonnull d2uvy, double* _Nonnull d2uvz);

/// Local evaluation D3 within knot span.
void OCCTSurfaceBSplineLocalD3(OCCTSurfaceRef _Nonnull surface, double u, double v,
                                int32_t fromUK1, int32_t toUK2, int32_t fromVK1, int32_t toVK2,
                                double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz,
                                double* _Nonnull d1ux, double* _Nonnull d1uy, double* _Nonnull d1uz,
                                double* _Nonnull d1vx, double* _Nonnull d1vy, double* _Nonnull d1vz,
                                double* _Nonnull d2ux, double* _Nonnull d2uy, double* _Nonnull d2uz,
                                double* _Nonnull d2vx, double* _Nonnull d2vy, double* _Nonnull d2vz,
                                double* _Nonnull d2uvx, double* _Nonnull d2uvy, double* _Nonnull d2uvz,
                                double* _Nonnull d3ux, double* _Nonnull d3uy, double* _Nonnull d3uz,
                                double* _Nonnull d3vx, double* _Nonnull d3vy, double* _Nonnull d3vz,
                                double* _Nonnull d3uuvx, double* _Nonnull d3uuvy, double* _Nonnull d3uuvz,
                                double* _Nonnull d3uvvx, double* _Nonnull d3uvvy, double* _Nonnull d3uvvz);

/// Local derivative DN within knot span.
void OCCTSurfaceBSplineLocalDN(OCCTSurfaceRef _Nonnull surface, double u, double v,
                                int32_t fromUK1, int32_t toUK2, int32_t fromVK1, int32_t toVK2,
                                int32_t nu, int32_t nv,
                                double* _Nonnull vx, double* _Nonnull vy, double* _Nonnull vz);

/// Local value within knot span.
void OCCTSurfaceBSplineLocalValue(OCCTSurfaceRef _Nonnull surface, double u, double v,
                                   int32_t fromUK1, int32_t toUK2, int32_t fromVK1, int32_t toVK2,
                                   double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// UIso: extract isoparametric curve at U.
OCCTCurve3DRef _Nullable OCCTSurfaceBSplineUIso(OCCTSurfaceRef _Nonnull surface, double u);

/// VIso: extract isoparametric curve at V.
OCCTCurve3DRef _Nullable OCCTSurfaceBSplineVIso(OCCTSurfaceRef _Nonnull surface, double v);

/// Locate U knot span. Returns I1 and I2 via out params.
void OCCTSurfaceBSplineLocateU(OCCTSurfaceRef _Nonnull surface, double u, double paramTol,
                                int32_t* _Nonnull i1, int32_t* _Nonnull i2);

/// Locate V knot span. Returns I1 and I2 via out params.
void OCCTSurfaceBSplineLocateV(OCCTSurfaceRef _Nonnull surface, double v, double paramTol,
                                int32_t* _Nonnull i1, int32_t* _Nonnull i2);

/// Get a single U knot value by index (1-based).
double OCCTSurfaceBSplineUKnot(OCCTSurfaceRef _Nonnull surface, int32_t index);

/// Get a single V knot value by index (1-based).
double OCCTSurfaceBSplineVKnot(OCCTSurfaceRef _Nonnull surface, int32_t index);

/// Get U multiplicity by index (1-based).
int32_t OCCTSurfaceBSplineUMultiplicity(OCCTSurfaceRef _Nonnull surface, int32_t index);

/// Get V multiplicity by index (1-based).
int32_t OCCTSurfaceBSplineVMultiplicity(OCCTSurfaceRef _Nonnull surface, int32_t index);

/// U knot distribution: 0=NonUniform, 1=Uniform, 2=QuasiUniform, 3=PiecewiseBezier.
int32_t OCCTSurfaceBSplineUKnotDistribution(OCCTSurfaceRef _Nonnull surface);

/// V knot distribution: 0=NonUniform, 1=Uniform, 2=QuasiUniform, 3=PiecewiseBezier.
int32_t OCCTSurfaceBSplineVKnotDistribution(OCCTSurfaceRef _Nonnull surface);

/// Get all poles as flat array (x1,y1,z1,x2,...). Array must be pre-allocated to NbUPoles*NbVPoles*3.
void OCCTSurfaceBSplineGetPoles(OCCTSurfaceRef _Nonnull surface, double* _Nonnull poles);

/// Get parameter bounds (u1, u2, v1, v2).
void OCCTSurfaceBSplineBounds(OCCTSurfaceRef _Nonnull surface,
                               double* _Nonnull u1, double* _Nonnull u2,
                               double* _Nonnull v1, double* _Nonnull v2);

/// Is the surface closed in U?
bool OCCTSurfaceBSplineIsUClosed(OCCTSurfaceRef _Nonnull surface);

/// Is the surface closed in V?
bool OCCTSurfaceBSplineIsVClosed(OCCTSurfaceRef _Nonnull surface);

// --- Geom2d_BSplineCurve completions ---

/// Local D0 within knot span.
void OCCTCurve2DBSplineLocalD0(OCCTCurve2DRef _Nonnull curve, double u, int32_t fromK1, int32_t toK2,
                                double* _Nonnull x, double* _Nonnull y);

/// Local D1 within knot span.
void OCCTCurve2DBSplineLocalD1(OCCTCurve2DRef _Nonnull curve, double u, int32_t fromK1, int32_t toK2,
                                double* _Nonnull px, double* _Nonnull py,
                                double* _Nonnull v1x, double* _Nonnull v1y);

/// Local D2 within knot span.
void OCCTCurve2DBSplineLocalD2(OCCTCurve2DRef _Nonnull curve, double u, int32_t fromK1, int32_t toK2,
                                double* _Nonnull px, double* _Nonnull py,
                                double* _Nonnull v1x, double* _Nonnull v1y,
                                double* _Nonnull v2x, double* _Nonnull v2y);

/// Local D3 within knot span.
void OCCTCurve2DBSplineLocalD3(OCCTCurve2DRef _Nonnull curve, double u, int32_t fromK1, int32_t toK2,
                                double* _Nonnull px, double* _Nonnull py,
                                double* _Nonnull v1x, double* _Nonnull v1y,
                                double* _Nonnull v2x, double* _Nonnull v2y,
                                double* _Nonnull v3x, double* _Nonnull v3y);

/// Local DN within knot span.
void OCCTCurve2DBSplineLocalDN(OCCTCurve2DRef _Nonnull curve, double u, int32_t fromK1, int32_t toK2,
                                int32_t n, double* _Nonnull vx, double* _Nonnull vy);

/// Local value within knot span.
void OCCTCurve2DBSplineLocalValue(OCCTCurve2DRef _Nonnull curve, double u, int32_t fromK1, int32_t toK2,
                                   double* _Nonnull x, double* _Nonnull y);

/// Locate U knot span. Returns I1 and I2 via out params.
void OCCTCurve2DBSplineLocateU(OCCTCurve2DRef _Nonnull curve, double u, double paramTol,
                                int32_t* _Nonnull i1, int32_t* _Nonnull i2);

/// First U knot index.
int32_t OCCTCurve2DBSplineFirstUKnotIndex(OCCTCurve2DRef _Nonnull curve);

/// Last U knot index.
int32_t OCCTCurve2DBSplineLastUKnotIndex(OCCTCurve2DRef _Nonnull curve);

/// Get a single knot value by index (1-based).
double OCCTCurve2DBSplineKnot(OCCTCurve2DRef _Nonnull curve, int32_t index);

/// Knot distribution: 0=NonUniform, 1=Uniform, 2=QuasiUniform, 3=PiecewiseBezier.
int32_t OCCTCurve2DBSplineKnotDistribution(OCCTCurve2DRef _Nonnull curve);

/// Get multiplicity by index (1-based).
int32_t OCCTCurve2DBSplineMultiplicity(OCCTCurve2DRef _Nonnull curve, int32_t index);

/// Get all multiplicities. Array must be pre-allocated to KnotCount.
void OCCTCurve2DBSplineGetMultiplicities(OCCTCurve2DRef _Nonnull curve, int32_t* _Nonnull mults);

/// Get start point.
void OCCTCurve2DBSplineStartPoint(OCCTCurve2DRef _Nonnull curve, double* _Nonnull x, double* _Nonnull y);

/// Get end point.
void OCCTCurve2DBSplineEndPoint(OCCTCurve2DRef _Nonnull curve, double* _Nonnull x, double* _Nonnull y);

/// Get all poles as flat array (x1,y1,x2,y2,...). Array must be pre-allocated to NbPoles*2.
void OCCTCurve2DBSplineGetPoles(OCCTCurve2DRef _Nonnull curve, double* _Nonnull poles);

/// Is the curve closed?
bool OCCTCurve2DBSplineIsClosed(OCCTCurve2DRef _Nonnull curve);

/// Is the curve periodic?
bool OCCTCurve2DBSplineIsPeriodic(OCCTCurve2DRef _Nonnull curve);

/// Continuity: 0=C0, 1=C1, 2=C2, 3=C3, 4=CN, 5=G1, 6=G2.
int32_t OCCTCurve2DBSplineContinuity(OCCTCurve2DRef _Nonnull curve);

/// IsCN: is the curve at least CN continuous?
bool OCCTCurve2DBSplineIsCN(OCCTCurve2DRef _Nonnull curve, int32_t n);

// --- Geom_BezierCurve completions ---

/// Get start point.
void OCCTCurve3DBezierStartPoint(OCCTCurve3DRef _Nonnull curve,
                                  double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Get end point.
void OCCTCurve3DBezierEndPoint(OCCTCurve3DRef _Nonnull curve,
                                double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Get all poles as flat array (x1,y1,z1,...). Array must be pre-allocated to NbPoles*3.
void OCCTCurve3DBezierGetPoles(OCCTCurve3DRef _Nonnull curve, double* _Nonnull poles);

/// Get all weights. Array must be pre-allocated to NbPoles. Returns false if non-rational.
bool OCCTCurve3DBezierGetWeights(OCCTCurve3DRef _Nonnull curve, double* _Nonnull weights);

/// Is the curve closed?
bool OCCTCurve3DBezierIsClosed(OCCTCurve3DRef _Nonnull curve);

/// Is the curve periodic?
bool OCCTCurve3DBezierIsPeriodic(OCCTCurve3DRef _Nonnull curve);

/// Continuity: 0=C0, 1=C1, 2=C2, 3=C3, 4=CN, 5=G1, 6=G2.
int32_t OCCTCurve3DBezierContinuity(OCCTCurve3DRef _Nonnull curve);

/// IsCN: is the curve at least CN continuous?
bool OCCTCurve3DBezierIsCN(OCCTCurve3DRef _Nonnull curve, int32_t n);

// --- Geom_BezierSurface completions ---

/// UIso: extract isoparametric curve at U.
OCCTCurve3DRef _Nullable OCCTSurfaceBezierUIso(OCCTSurfaceRef _Nonnull surface, double u);

/// VIso: extract isoparametric curve at V.
OCCTCurve3DRef _Nullable OCCTSurfaceBezierVIso(OCCTSurfaceRef _Nonnull surface, double v);

/// Is the surface closed in U?
bool OCCTSurfaceBezierIsUClosed(OCCTSurfaceRef _Nonnull surface);

/// Is the surface closed in V?
bool OCCTSurfaceBezierIsVClosed(OCCTSurfaceRef _Nonnull surface);

/// Is the surface periodic in U?
bool OCCTSurfaceBezierIsUPeriodic(OCCTSurfaceRef _Nonnull surface);

/// Is the surface periodic in V?
bool OCCTSurfaceBezierIsVPeriodic(OCCTSurfaceRef _Nonnull surface);

/// Continuity: 0=C0, 1=C1, 2=C2, 3=C3, 4=CN, 5=G1, 6=G2.
int32_t OCCTSurfaceBezierContinuity(OCCTSurfaceRef _Nonnull surface);

/// IsCNu: is the surface at least CN continuous in U?
bool OCCTSurfaceBezierIsCNu(OCCTSurfaceRef _Nonnull surface, int32_t n);

/// IsCNv: is the surface at least CN continuous in V?
bool OCCTSurfaceBezierIsCNv(OCCTSurfaceRef _Nonnull surface, int32_t n);

/// Get all poles as flat array (x1,y1,z1,...). Array must be pre-allocated to NbUPoles*NbVPoles*3.
void OCCTSurfaceBezierGetPoles(OCCTSurfaceRef _Nonnull surface, double* _Nonnull poles);

/// Get all weights as flat array. Array must be pre-allocated to NbUPoles*NbVPoles. Returns false if non-rational.
bool OCCTSurfaceBezierGetWeights(OCCTSurfaceRef _Nonnull surface, double* _Nonnull weights);

/// Get parameter bounds (u1, u2, v1, v2).
void OCCTSurfaceBezierBounds(OCCTSurfaceRef _Nonnull surface,
                              double* _Nonnull u1, double* _Nonnull u2,
                              double* _Nonnull v1, double* _Nonnull v2);

// MARK: - v0.126.0: Final completeness release

// --- BRep_Tool completions ---

/// Get the 2D curve (pcurve) of an edge on a face. Returns the Curve2D ref and parameter range.
OCCTCurve2DRef _Nullable OCCTBRepToolCurveOnSurface(OCCTShapeRef _Nonnull edge,
                                                     OCCTShapeRef _Nonnull face,
                                                     double* _Nonnull outFirst,
                                                     double* _Nonnull outLast);

/// Check if edge has continuity regularity between two faces.
bool OCCTBRepToolHasContinuity(OCCTShapeRef _Nonnull edge,
                                OCCTShapeRef _Nonnull face1,
                                OCCTShapeRef _Nonnull face2);

/// Get the continuity of edge between two faces. Returns GeomAbs_Shape as int.
int32_t OCCTBRepToolContinuity(OCCTShapeRef _Nonnull edge,
                                OCCTShapeRef _Nonnull face1,
                                OCCTShapeRef _Nonnull face2);

/// Check if edge has any regularity on some two surfaces.
bool OCCTBRepToolHasAnyContinuity(OCCTShapeRef _Nonnull edge);

/// Get the maximum continuity of edge between all its surfaces. Returns GeomAbs_Shape as int.
int32_t OCCTBRepToolMaxContinuity(OCCTShapeRef _Nonnull edge);

/// Check if edge is degenerated.
bool OCCTBRepToolDegenerated(OCCTShapeRef _Nonnull edge);

/// Check if face has the NaturalRestriction flag set.
bool OCCTBRepToolNaturalRestriction(OCCTShapeRef _Nonnull face);

/// Get the parameter range of edge on a face (pcurve range).
bool OCCTBRepToolRangeOnFace(OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull face,
                              double* _Nonnull outFirst, double* _Nonnull outLast);

/// Get the parameter of vertex on pcurve of edge on face.
bool OCCTBRepToolParameterOnFace(OCCTShapeRef _Nonnull vertex, OCCTShapeRef _Nonnull edge,
                                  OCCTShapeRef _Nonnull face, double* _Nonnull outParam);

/// Get the UV parameters of vertex on face.
bool OCCTBRepToolParametersOnFace(OCCTShapeRef _Nonnull vertex, OCCTShapeRef _Nonnull face,
                                   double* _Nonnull outU, double* _Nonnull outV);

/// Get UV points at extremities of edge on face.
bool OCCTBRepToolUVPoints(OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull face,
                           double* _Nonnull firstU, double* _Nonnull firstV,
                           double* _Nonnull lastU, double* _Nonnull lastV);

/// Get maximum tolerance of sub-shapes of given type. type: 6=EDGE, 4=FACE, 7=VERTEX.
double OCCTBRepToolMaxTolerance(OCCTShapeRef _Nonnull shape, int32_t subShapeType);

// --- XCAFDoc_ColorTool completions ---

/// Add a color to the document color table. Returns label id.
int64_t OCCTDocumentColorToolAddColor(OCCTDocumentRef _Nonnull doc, double r, double g, double b);

/// Remove a color from the document color table by label id.
bool OCCTDocumentColorToolRemoveColor(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Get the number of colors in the color table.
int32_t OCCTDocumentColorToolGetColorCount(OCCTDocumentRef _Nonnull doc);

/// Unset color of a specific type from a label.
bool OCCTDocumentColorToolUnSetColor(OCCTDocumentRef _Nonnull doc, int64_t labelId, int32_t colorType);

/// Check if a label is visible.
bool OCCTDocumentColorToolIsVisible(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Set visibility of a label.
bool OCCTDocumentColorToolSetVisibility(OCCTDocumentRef _Nonnull doc, int64_t labelId, bool visible);

/// Check if color is defined by layer.
bool OCCTDocumentColorToolIsColorByLayer(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Set color-by-layer flag on a label.
bool OCCTDocumentColorToolSetColorByLayer(OCCTDocumentRef _Nonnull doc, int64_t labelId, bool isByLayer);

/// Find a color in the color table. Returns label id or -1 if not found.
int64_t OCCTDocumentColorToolFindColor(OCCTDocumentRef _Nonnull doc, double r, double g, double b);

/// Set instance color on a shape component. Returns false if shape not found.
bool OCCTDocumentColorToolSetInstanceColor(OCCTDocumentRef _Nonnull doc,
                                            OCCTShapeRef _Nonnull shape,
                                            int32_t colorType,
                                            double r, double g, double b);

/// Get instance color of a shape component. Returns false if not set.
bool OCCTDocumentColorToolGetInstanceColor(OCCTDocumentRef _Nonnull doc,
                                            OCCTShapeRef _Nonnull shape,
                                            int32_t colorType,
                                            double* _Nonnull r, double* _Nonnull g, double* _Nonnull b);

// --- Geom2d_BezierCurve completions ---

/// Insert a pole after index in a 2D Bezier curve.
bool OCCTCurve2DBezierInsertPoleAfter(OCCTCurve2DRef _Nonnull curve, int32_t index, double x, double y);

/// Remove a pole at index from a 2D Bezier curve.
bool OCCTCurve2DBezierRemovePole(OCCTCurve2DRef _Nonnull curve, int32_t index);

/// Segment a 2D Bezier curve to [u1, u2].
bool OCCTCurve2DBezierSegment(OCCTCurve2DRef _Nonnull curve, double u1, double u2);

/// Increase degree of a 2D Bezier curve.
bool OCCTCurve2DBezierIncreaseDegree(OCCTCurve2DRef _Nonnull curve, int32_t degree);

/// Get start point of a 2D Bezier curve.
void OCCTCurve2DBezierStartPoint(OCCTCurve2DRef _Nonnull curve, double* _Nonnull x, double* _Nonnull y);

/// Get end point of a 2D Bezier curve.
void OCCTCurve2DBezierEndPoint(OCCTCurve2DRef _Nonnull curve, double* _Nonnull x, double* _Nonnull y);

/// Get all poles of a 2D Bezier curve as flat array (x1,y1,x2,y2,...). Array must be pre-allocated to PoleCount*2.
void OCCTCurve2DBezierGetPoles(OCCTCurve2DRef _Nonnull curve, double* _Nonnull poles);

/// Reverse the parameterization of a 2D Bezier curve.
bool OCCTCurve2DBezierReverse(OCCTCurve2DRef _Nonnull curve);

// --- BSpline Surface bulk multiplicities and reverse ---

/// Get all U multiplicities. Array must be pre-allocated to NbUKnots.
void OCCTSurfaceBSplineGetUMultiplicities(OCCTSurfaceRef _Nonnull surface, int32_t* _Nonnull mults);

/// Get all V multiplicities. Array must be pre-allocated to NbVKnots.
void OCCTSurfaceBSplineGetVMultiplicities(OCCTSurfaceRef _Nonnull surface, int32_t* _Nonnull mults);

/// Reverse the U parameter direction of a BSpline surface (in-place).
bool OCCTSurfaceBSplineUReverse(OCCTSurfaceRef _Nonnull surface);

/// Reverse the V parameter direction of a BSpline surface (in-place).
bool OCCTSurfaceBSplineVReverse(OCCTSurfaceRef _Nonnull surface);

/// Normalize U,V parameters for a periodic BSpline surface.
bool OCCTSurfaceBSplinePeriodicNormalization(OCCTSurfaceRef _Nonnull surface,
                                              double* _Nonnull u, double* _Nonnull v);

// --- FilletBuilder completions ---

/// Set fillet tolerances: tang, tesp, t2d, tApp3d, tApp2d, fleche.
void OCCTFilletBuilderSetParams(OCCTFilletBuilderRef _Nonnull builder,
                                 double tang, double tesp, double t2d,
                                 double tApp3d, double tApp2d, double fleche);

/// Set fillet continuity: internalContinuity (0=C0, 1=C1, 2=C2), angularTolerance.
void OCCTFilletBuilderSetContinuity(OCCTFilletBuilderRef _Nonnull builder,
                                     int32_t internalContinuity, double angularTolerance);

/// Set fillet shape type: 0=Rational, 1=QuasiAngular, 2=Polynomial.
void OCCTFilletBuilderSetFilletShape(OCCTFilletBuilderRef _Nonnull builder, int32_t filletShape);

/// Get fillet shape type: 0=Rational, 1=QuasiAngular, 2=Polynomial.
int32_t OCCTFilletBuilderGetFilletShape(OCCTFilletBuilderRef _Nonnull builder);

/// Reset a specific contour's radius info.
void OCCTFilletBuilderResetContour(OCCTFilletBuilderRef _Nonnull builder, int32_t contourIndex);

/// Simulate filleting on contour IC (computes sections without building).
void OCCTFilletBuilderSimulate(OCCTFilletBuilderRef _Nonnull builder, int32_t contourIndex);

/// Get the number of simulated surfaces for contour IC.
int32_t OCCTFilletBuilderNbSimulatedSurf(OCCTFilletBuilderRef _Nonnull builder, int32_t contourIndex);

// --- XCAFDoc_ShapeTool completions ---

/// Check if a label is a free shape (top-level, not referenced by other shapes).
bool OCCTDocumentShapeToolIsFree(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Check if a label is a simple shape (not assembly, not compound).
bool OCCTDocumentShapeToolIsSimpleShape(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Check if a label is a component (reference to another shape).
bool OCCTDocumentShapeToolIsComponent(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Check if a label is a compound shape.
bool OCCTDocumentShapeToolIsCompound(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Check if a label is a sub-shape.
bool OCCTDocumentShapeToolIsSubShape(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Check if a label is an external reference.
bool OCCTDocumentShapeToolIsExternRef(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Get the number of users (references) of a shape label.
int32_t OCCTDocumentShapeToolGetUsers(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Compute shapes (update internal state) for a label.
void OCCTDocumentShapeToolComputeShapes(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Get the number of components of a label.
int32_t OCCTDocumentShapeToolNbComponents(OCCTDocumentRef _Nonnull doc, int64_t labelId, bool getSubChildren);

// --- Bezier 3D curve InsertPoleBefore (complement to InsertPoleAfter) ---

/// Insert a pole before index in a 3D Bezier curve. Index is 1-based.
bool OCCTCurve3DBezierInsertPoleBefore(OCCTCurve3DRef _Nonnull curve, int32_t index, double x, double y, double z);

/// Reverse the parameterization of a 3D Bezier curve.
bool OCCTCurve3DBezierReverse(OCCTCurve3DRef _Nonnull curve);

/// Get all poles of a 3D Bezier curve as flat array (x1,y1,z1,...). Already exists as OCCTCurve3DBezierGetPoles.

/// Set pole with weight for a 3D Bezier curve.
bool OCCTCurve3DBezierSetPoleWithWeight(OCCTCurve3DRef _Nonnull curve, int32_t index,
                                         double x, double y, double z, double weight);

// --- Bezier Surface insert/remove poles ---

/// Insert a pole column after index in a Bezier surface.
bool OCCTSurfaceBezierInsertPoleColAfter(OCCTSurfaceRef _Nonnull surface, int32_t colIndex,
                                          const double* _Nonnull poles, int32_t poleCount);

/// Insert a pole row after index in a Bezier surface.
bool OCCTSurfaceBezierInsertPoleRowAfter(OCCTSurfaceRef _Nonnull surface, int32_t rowIndex,
                                          const double* _Nonnull poles, int32_t poleCount);

/// Remove a pole column from a Bezier surface.
bool OCCTSurfaceBezierRemovePoleCol(OCCTSurfaceRef _Nonnull surface, int32_t colIndex);

/// Remove a pole row from a Bezier surface.
bool OCCTSurfaceBezierRemovePoleRow(OCCTSurfaceRef _Nonnull surface, int32_t rowIndex);

/// Increase the degree of a Bezier surface.
bool OCCTSurfaceBezierIncreaseDegree(OCCTSurfaceRef _Nonnull surface, int32_t uDeg, int32_t vDeg);

/// Reverse U parameter direction of a Bezier surface (in-place).
bool OCCTSurfaceBezierUReverse(OCCTSurfaceRef _Nonnull surface);

/// Reverse V parameter direction of a Bezier surface (in-place).
bool OCCTSurfaceBezierVReverse(OCCTSurfaceRef _Nonnull surface);

// MARK: - v0.127.0: Section ops, BSpline/Bezier completions, BRep_Tool, ColorTool, FilletBuilder history

// --- BRepAlgoAPI_Section with plane ---

/// Compute section of a shape with a plane (ax + by + cz + d = 0).
/// @param normalX,normalY,normalZ Plane normal direction
/// @param originX,originY,originZ A point on the plane
OCCTShapeRef _Nullable OCCTShapeSectionWithPlane(OCCTShapeRef _Nonnull shape,
                                                  double normalX, double normalY, double normalZ,
                                                  double originX, double originY, double originZ);

/// Compute section of a shape with a surface.
OCCTShapeRef _Nullable OCCTShapeSectionWithSurface(OCCTShapeRef _Nonnull shape,
                                                    OCCTSurfaceRef _Nonnull surface);

// --- Geom_BSplineCurve completions ---

/// Normalize parameter for periodic BSpline curve. Returns normalized u.
/// Returns false if curve is not periodic.
bool OCCTCurve3DBSplinePeriodicNormalization(OCCTCurve3DRef _Nonnull curve, double* _Nonnull u);

/// Check G1 continuity on parameter range [tFirst, tLast] with angular tolerance.
bool OCCTCurve3DBSplineIsG1(OCCTCurve3DRef _Nonnull curve, double tFirst, double tLast, double angTol);

// --- BRep_Tool completions ---

/// Get the 2D curve of an edge computed on a plane surface.
/// Returns the Curve2D and parameter range. May return NULL for non-planar surfaces.
OCCTCurve2DRef _Nullable OCCTBRepToolCurveOnPlane(OCCTShapeRef _Nonnull edge,
                                                    OCCTSurfaceRef _Nonnull surface,
                                                    double* _Nonnull outFirst,
                                                    double* _Nonnull outLast);

/// Get the 3D polygon of a meshed edge. Returns node count (0 if not available).
/// Points are returned as flat array [x1,y1,z1,...]. Caller must free with free().
int32_t OCCTBRepToolPolygon3D(OCCTShapeRef _Nonnull edge,
                               double* _Nullable * _Nonnull outPoints);

/// Get the polygon-on-triangulation of a meshed edge.
/// Returns node indices (1-based) into the triangulation. Count returned. Caller must free with free().
int32_t OCCTBRepToolPolygonOnTriangulation(OCCTShapeRef _Nonnull edge,
                                            int32_t* _Nullable * _Nonnull outIndices);

// --- Geom_BezierSurface completions ---

/// Set a pole column with weights on a Bezier surface. vIndex is 1-based.
/// poles: flat array [x1,y1,z1,...] of NbUPoles points. weights: array of NbUPoles values.
bool OCCTSurfaceBezierSetPoleColWeights(OCCTSurfaceRef _Nonnull surface, int32_t vIndex,
                                         const double* _Nonnull poles, const double* _Nonnull weights,
                                         int32_t count);

/// Set a pole row with weights on a Bezier surface. uIndex is 1-based.
/// poles: flat array [x1,y1,z1,...] of NbVPoles points. weights: array of NbVPoles values.
bool OCCTSurfaceBezierSetPoleRowWeights(OCCTSurfaceRef _Nonnull surface, int32_t uIndex,
                                         const double* _Nonnull poles, const double* _Nonnull weights,
                                         int32_t count);

// --- XCAFDoc_ColorTool completions ---

/// Get all color labels in the document. Returns array of label IDs. Caller must free with free().
int32_t OCCTDocumentColorToolGetAllColors(OCCTDocumentRef _Nonnull doc,
                                           int64_t* _Nullable * _Nonnull outLabelIds);

// --- FilletBuilder history queries ---

/// Get the parameter bounds of a fillet on a contour edge. Returns false if not found.
bool OCCTFilletBuilderGetBounds(OCCTFilletBuilderRef _Nonnull builder,
                                 int32_t contourIndex, OCCTShapeRef _Nonnull edge,
                                 double* _Nonnull outFirst, double* _Nonnull outLast);

/// Get the law function for a fillet edge on a contour. Returns NULL if not available.
OCCTLawFunctionRef _Nullable OCCTFilletBuilderGetLaw(OCCTFilletBuilderRef _Nonnull builder,
                                                      int32_t contourIndex, OCCTShapeRef _Nonnull edge);

/// Set a law function for a fillet edge on a contour.
bool OCCTFilletBuilderSetLaw(OCCTFilletBuilderRef _Nonnull builder,
                              int32_t contourIndex, OCCTEdgeRef _Nonnull edge,
                              OCCTLawFunctionRef _Nonnull law);

/// Get shapes generated from an input shape by the fillet operation.
/// Returns array of shape refs. Caller must free the array (not the shapes) with free().
int32_t OCCTFilletBuilderGenerated(OCCTFilletBuilderRef _Nonnull builder,
                                    OCCTShapeRef _Nonnull shape,
                                    OCCTShapeRef _Nullable * _Nullable * _Nonnull outShapes);

/// Get shapes modified from an input shape by the fillet operation.
/// Returns array of shape refs. Caller must free the array (not the shapes) with free().
int32_t OCCTFilletBuilderModified(OCCTFilletBuilderRef _Nonnull builder,
                                   OCCTShapeRef _Nonnull shape,
                                   OCCTShapeRef _Nullable * _Nullable * _Nonnull outShapes);

/// Check if a shape was deleted by the fillet operation.
bool OCCTFilletBuilderIsDeleted(OCCTFilletBuilderRef _Nonnull builder,
                                 OCCTShapeRef _Nonnull shape);

// MARK: - v0.128.0: ChamferBuilder history, SectionBuilder, BRep_Tool extras, Curve/Surface Transform

// --- ChamferBuilder history & extras ---

/// Get shapes generated from an input shape by the chamfer operation.
/// Returns count. Caller must free the array (not the shapes) with free().
int32_t OCCTChamferBuilderGenerated(OCCTChamferBuilderRef _Nonnull builder,
                                     OCCTShapeRef _Nonnull shape,
                                     OCCTShapeRef _Nullable * _Nullable * _Nonnull outShapes);

/// Get shapes modified from an input shape by the chamfer operation.
/// Returns count. Caller must free the array (not the shapes) with free().
int32_t OCCTChamferBuilderModified(OCCTChamferBuilderRef _Nonnull builder,
                                    OCCTShapeRef _Nonnull shape,
                                    OCCTShapeRef _Nullable * _Nullable * _Nonnull outShapes);

/// Check if a shape was deleted by the chamfer operation.
bool OCCTChamferBuilderIsDeleted(OCCTChamferBuilderRef _Nonnull builder,
                                  OCCTShapeRef _Nonnull shape);

/// Set the chamfer mode: 0=ClassicChamfer, 1=ConstThroatChamfer, 2=ConstThroatWithPenetrationChamfer.
void OCCTChamferBuilderSetMode(OCCTChamferBuilderRef _Nonnull builder, int32_t mode);

/// Simulate the chamfer on a contour (1-based) to prepare surface data.
bool OCCTChamferBuilderSimulate(OCCTChamferBuilderRef _Nonnull builder, int32_t contourIndex);

/// Get the number of simulated surfaces for a contour (1-based). Call after Simulate.
int32_t OCCTChamferBuilderNbSurf(OCCTChamferBuilderRef _Nonnull builder, int32_t contourIndex);

// --- SectionBuilder (BRepAlgoAPI_Section) ---

typedef struct OCCTSectionBuilder* OCCTSectionBuilderRef;

/// Create a section builder with default initialization.
OCCTSectionBuilderRef _Nullable OCCTSectionBuilderCreate(void);

/// Create a section builder from two shapes.
OCCTSectionBuilderRef _Nullable OCCTSectionBuilderCreateFromShapes(OCCTShapeRef _Nonnull shape1,
                                                                     OCCTShapeRef _Nonnull shape2);

/// Release a section builder.
void OCCTSectionBuilderRelease(OCCTSectionBuilderRef _Nonnull builder);

/// Set the first argument as a shape.
void OCCTSectionBuilderInit1Shape(OCCTSectionBuilderRef _Nonnull builder,
                                   OCCTShapeRef _Nonnull shape);

/// Set the first argument as a plane (ax + by + cz + d = 0).
void OCCTSectionBuilderInit1Plane(OCCTSectionBuilderRef _Nonnull builder,
                                   double a, double b, double c, double d);

/// Set the first argument as a surface.
void OCCTSectionBuilderInit1Surface(OCCTSectionBuilderRef _Nonnull builder,
                                     OCCTSurfaceRef _Nonnull surface);

/// Set the second argument as a shape.
void OCCTSectionBuilderInit2Shape(OCCTSectionBuilderRef _Nonnull builder,
                                   OCCTShapeRef _Nonnull shape);

/// Set the second argument as a plane (ax + by + cz + d = 0).
void OCCTSectionBuilderInit2Plane(OCCTSectionBuilderRef _Nonnull builder,
                                   double a, double b, double c, double d);

/// Set the second argument as a surface.
void OCCTSectionBuilderInit2Surface(OCCTSectionBuilderRef _Nonnull builder,
                                     OCCTSurfaceRef _Nonnull surface);

/// Toggle curve approximation (default: false).
void OCCTSectionBuilderSetApproximation(OCCTSectionBuilderRef _Nonnull builder, bool approx);

/// Toggle computation of PCurves on first shape.
void OCCTSectionBuilderComputePCurveOn1(OCCTSectionBuilderRef _Nonnull builder, bool compute);

/// Toggle computation of PCurves on second shape.
void OCCTSectionBuilderComputePCurveOn2(OCCTSectionBuilderRef _Nonnull builder, bool compute);

/// Build the section. Returns the result shape, or NULL on failure.
OCCTShapeRef _Nullable OCCTSectionBuilderBuild(OCCTSectionBuilderRef _Nonnull builder);

/// Check if an edge has an ancestor face on the first shape. Returns the face, or NULL.
OCCTShapeRef _Nullable OCCTSectionBuilderAncestorFaceOn1(OCCTSectionBuilderRef _Nonnull builder,
                                                           OCCTShapeRef _Nonnull edge);

/// Check if an edge has an ancestor face on the second shape. Returns the face, or NULL.
OCCTShapeRef _Nullable OCCTSectionBuilderAncestorFaceOn2(OCCTSectionBuilderRef _Nonnull builder,
                                                           OCCTShapeRef _Nonnull edge);

// --- BRep_Tool completions ---

/// Check if an edge is closed on a face (has same PCurve with different orientations).
bool OCCTBRepToolIsClosedOnFace(OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull face);

/// Get the 2D polygon of an edge on a face. Returns 2D point count (0 if not available).
/// Points are returned as flat array [x1,y1,x2,y2,...]. Caller must free with free().
int32_t OCCTBRepToolPolygonOnSurface(OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull face,
                                      double* _Nullable * _Nonnull outPoints);

/// Set UV points of an edge on a face.
bool OCCTBRepToolSetUVPoints(OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull face,
                              double fU, double fV, double lU, double lV);

// --- Geometry Transform (in-place) ---

/// Transform a 3D curve in place using a gp_Trsf (translate/rotate/scale/mirror).
/// transformType: 0=translation(dx,dy,dz), 1=rotation(ox,oy,oz,dx,dy,dz,angle), 2=scale(cx,cy,cz,factor),
/// 3=mirror point(px,py,pz), 4=mirror axis(ox,oy,oz,dx,dy,dz), 5=mirror plane(ox,oy,oz,nx,ny,nz)
bool OCCTCurve3DTransform(OCCTCurve3DRef _Nonnull curve, int32_t transformType,
                           double p1, double p2, double p3,
                           double p4, double p5, double p6,
                           double p7);

/// Transform a 2D curve in place using a gp_Trsf2d.
/// transformType: 0=translation(dx,dy), 1=rotation(cx,cy,angle), 2=scale(cx,cy,factor),
/// 3=mirror point(px,py), 4=mirror axis(ox,oy,dx,dy)
bool OCCTCurve2DTransform(OCCTCurve2DRef _Nonnull curve, int32_t transformType,
                           double p1, double p2, double p3, double p4, double p5);

/// Transform a surface in place using a gp_Trsf.
/// Same transformType as OCCTCurve3DTransform.
bool OCCTSurfaceTransform(OCCTSurfaceRef _Nonnull surface, int32_t transformType,
                           double p1, double p2, double p3,
                           double p4, double p5, double p6,
                           double p7);

// --- v0.129.0: BSplineCurve3D LocalD0-D3/DN, BSplineSurface completions, BezierSurface completions ---

// BSplineCurve3D local evaluation on knot span

/// Evaluate point on BSpline curve within knot span [fromK1, toK2].
void OCCTCurve3DBSplineLocalD0(OCCTCurve3DRef _Nonnull curve, double u,
                                int32_t fromK1, int32_t toK2,
                                double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz);

/// Evaluate point + 1st derivative on BSpline curve within knot span.
void OCCTCurve3DBSplineLocalD1(OCCTCurve3DRef _Nonnull curve, double u,
                                int32_t fromK1, int32_t toK2,
                                double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz,
                                double* _Nonnull vx, double* _Nonnull vy, double* _Nonnull vz);

/// Evaluate point + 1st + 2nd derivative on BSpline curve within knot span.
void OCCTCurve3DBSplineLocalD2(OCCTCurve3DRef _Nonnull curve, double u,
                                int32_t fromK1, int32_t toK2,
                                double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz,
                                double* _Nonnull v1x, double* _Nonnull v1y, double* _Nonnull v1z,
                                double* _Nonnull v2x, double* _Nonnull v2y, double* _Nonnull v2z);

/// Evaluate point + 1st + 2nd + 3rd derivative on BSpline curve within knot span.
void OCCTCurve3DBSplineLocalD3(OCCTCurve3DRef _Nonnull curve, double u,
                                int32_t fromK1, int32_t toK2,
                                double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz,
                                double* _Nonnull v1x, double* _Nonnull v1y, double* _Nonnull v1z,
                                double* _Nonnull v2x, double* _Nonnull v2y, double* _Nonnull v2z,
                                double* _Nonnull v3x, double* _Nonnull v3y, double* _Nonnull v3z);

/// Evaluate Nth derivative on BSpline curve within knot span.
void OCCTCurve3DBSplineLocalDN(OCCTCurve3DRef _Nonnull curve, double u,
                                int32_t fromK1, int32_t toK2, int32_t n,
                                double* _Nonnull vx, double* _Nonnull vy, double* _Nonnull vz);

// BSplineSurface completions

/// Set a column of weights on a BSpline surface. vIndex is 1-based. count = NbUPoles.
bool OCCTSurfaceBSplineSetWeightCol(OCCTSurfaceRef _Nonnull surface, int32_t vIndex,
                                     const double* _Nonnull weights, int32_t count);

/// Set a row of weights on a BSpline surface. uIndex is 1-based. count = NbVPoles.
bool OCCTSurfaceBSplineSetWeightRow(OCCTSurfaceRef _Nonnull surface, int32_t uIndex,
                                     const double* _Nonnull weights, int32_t count);

/// Increment U knot multiplicities in range [fromIndex, toIndex] by step.
bool OCCTSurfaceBSplineIncrementUMultiplicity(OCCTSurfaceRef _Nonnull surface,
                                               int32_t fromIndex, int32_t toIndex, int32_t step);

/// Increment V knot multiplicities in range [fromIndex, toIndex] by step.
bool OCCTSurfaceBSplineIncrementVMultiplicity(OCCTSurfaceRef _Nonnull surface,
                                               int32_t fromIndex, int32_t toIndex, int32_t step);

/// First U knot index of a BSpline surface.
int32_t OCCTSurfaceBSplineFirstUKnotIndex(OCCTSurfaceRef _Nonnull surface);

/// Last U knot index of a BSpline surface.
int32_t OCCTSurfaceBSplineLastUKnotIndex(OCCTSurfaceRef _Nonnull surface);

/// First V knot index of a BSpline surface.
int32_t OCCTSurfaceBSplineFirstVKnotIndex(OCCTSurfaceRef _Nonnull surface);

/// Last V knot index of a BSpline surface.
int32_t OCCTSurfaceBSplineLastVKnotIndex(OCCTSurfaceRef _Nonnull surface);

/// Validate parameter ranges and segment the BSpline surface.
bool OCCTSurfaceBSplineCheckAndSegment(OCCTSurfaceRef _Nonnull surface,
                                        double u1, double u2, double v1, double v2,
                                        double uTol, double vTol);

// BezierSurface completions

/// Insert a pole column before index in a Bezier surface. poles: flat [x,y,z,...], count = NbUPoles.
bool OCCTSurfaceBezierInsertPoleColBefore(OCCTSurfaceRef _Nonnull surface, int32_t colIndex,
                                           const double* _Nonnull poles, int32_t poleCount);

/// Insert a pole row before index in a Bezier surface. poles: flat [x,y,z,...], count = NbVPoles.
bool OCCTSurfaceBezierInsertPoleRowBefore(OCCTSurfaceRef _Nonnull surface, int32_t rowIndex,
                                           const double* _Nonnull poles, int32_t poleCount);

/// Set a pole column (without weights) on a Bezier surface. vIndex is 1-based.
bool OCCTSurfaceBezierSetPoleCol(OCCTSurfaceRef _Nonnull surface, int32_t vIndex,
                                  const double* _Nonnull poles, int32_t count);

/// Set a pole row (without weights) on a Bezier surface. uIndex is 1-based.
bool OCCTSurfaceBezierSetPoleRow(OCCTSurfaceRef _Nonnull surface, int32_t uIndex,
                                  const double* _Nonnull poles, int32_t count);

/// Set a column of weights on a Bezier surface. vIndex is 1-based. count = NbUPoles.
bool OCCTSurfaceBezierSetWeightCol(OCCTSurfaceRef _Nonnull surface, int32_t vIndex,
                                    const double* _Nonnull weights, int32_t count);

/// Set a row of weights on a Bezier surface. uIndex is 1-based. count = NbVPoles.
bool OCCTSurfaceBezierSetWeightRow(OCCTSurfaceRef _Nonnull surface, int32_t uIndex,
                                    const double* _Nonnull weights, int32_t count);

// MARK: - v0.130.0: GeomEval Curves, GeomEval Surfaces, Geom2dEval Curves, GeomFill Gordon, PointSetLib, ExtremaPC

// --- GeomEval 3D Curve Evaluators ---

/// Evaluate a circular helix at parameter u. Returns point (px,py,pz).
/// Helix: C(t) = O + R*cos(t)*XDir + R*sin(t)*YDir + (P*t/(2*Pi))*ZDir
void OCCTGeomEvalCircularHelixD0(double radius, double pitch, double u,
                                  double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz);

/// Evaluate circular helix D1: point + first derivative.
void OCCTGeomEvalCircularHelixD1(double radius, double pitch, double u,
                                  double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz,
                                  double* _Nonnull vx, double* _Nonnull vy, double* _Nonnull vz);

/// Evaluate circular helix D2: point + first + second derivatives.
void OCCTGeomEvalCircularHelixD2(double radius, double pitch, double u,
                                  double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz,
                                  double* _Nonnull d1x, double* _Nonnull d1y, double* _Nonnull d1z,
                                  double* _Nonnull d2x, double* _Nonnull d2y, double* _Nonnull d2z);

/// Create circular helix as OCCTCurve3DRef (Geom_Curve subclass). Returns NULL on error.
OCCTCurve3DRef _Nullable OCCTGeomEvalCircularHelixCurveCreate(double radius, double pitch);

/// Evaluate a 3D sine wave at parameter u. Returns point.
/// C(t) = O + t*XDir + A*sin(omega*t + phi)*YDir
void OCCTGeomEvalSineWaveD0(double amplitude, double omega, double phase, double u,
                             double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz);

/// Evaluate 3D sine wave D1: point + first derivative.
void OCCTGeomEvalSineWaveD1(double amplitude, double omega, double phase, double u,
                             double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz,
                             double* _Nonnull vx, double* _Nonnull vy, double* _Nonnull vz);

/// Create 3D sine wave as OCCTCurve3DRef. Returns NULL on error.
OCCTCurve3DRef _Nullable OCCTGeomEvalSineWaveCurveCreate(double amplitude, double omega, double phase);

// --- GeomEval Surfaces ---

/// Evaluate ellipsoid surface D0 at (u,v). Returns point.
void OCCTGeomEvalEllipsoidD0(double a, double b, double c, double u, double v,
                              double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz);

/// Create ellipsoid as OCCTSurfaceRef. Returns NULL on error.
OCCTSurfaceRef _Nullable OCCTGeomEvalEllipsoidCreate(double a, double b, double c);

/// Evaluate hyperboloid D0 at (u,v). mode: 0=one-sheet, 1=two-sheets.
void OCCTGeomEvalHyperboloidD0(double r1, double r2, int32_t mode, double u, double v,
                                double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz);

/// Create hyperboloid as OCCTSurfaceRef. mode: 0=one-sheet, 1=two-sheets.
OCCTSurfaceRef _Nullable OCCTGeomEvalHyperboloidCreate(double r1, double r2, int32_t mode);

/// Evaluate paraboloid D0 at (u,v).
void OCCTGeomEvalParaboloidD0(double focal, double u, double v,
                               double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz);

/// Create paraboloid as OCCTSurfaceRef.
OCCTSurfaceRef _Nullable OCCTGeomEvalParaboloidCreate(double focal);

/// Evaluate circular helicoid D0 at (u,v).
void OCCTGeomEvalCircularHelicoidD0(double pitch, double u, double v,
                                     double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz);

/// Create circular helicoid as OCCTSurfaceRef.
OCCTSurfaceRef _Nullable OCCTGeomEvalCircularHelicoidCreate(double pitch);

/// Evaluate hyperbolic paraboloid D0 at (u,v).
void OCCTGeomEvalHypParaboloidD0(double a, double b, double u, double v,
                                  double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz);

/// Create hyperbolic paraboloid as OCCTSurfaceRef.
OCCTSurfaceRef _Nullable OCCTGeomEvalHypParaboloidCreate(double a, double b);

// --- Geom2dEval 2D Curve Evaluators ---

/// Evaluate Archimedean spiral D0 at parameter u. Returns 2D point.
/// C(t) = O + (a + b*t)*cos(t)*XDir + (a + b*t)*sin(t)*YDir
void OCCTGeom2dEvalArchimedeanSpiralD0(double initialRadius, double growthRate, double u,
                                        double* _Nonnull px, double* _Nonnull py);

/// Evaluate Archimedean spiral D1: point + first derivative.
void OCCTGeom2dEvalArchimedeanSpiralD1(double initialRadius, double growthRate, double u,
                                        double* _Nonnull px, double* _Nonnull py,
                                        double* _Nonnull vx, double* _Nonnull vy);

/// Evaluate logarithmic spiral D0 at parameter u.
/// C(t) = O + a*exp(b*t)*cos(t)*XDir + a*exp(b*t)*sin(t)*YDir
void OCCTGeom2dEvalLogSpiralD0(double scale, double growthExponent, double u,
                                double* _Nonnull px, double* _Nonnull py);

/// Evaluate logarithmic spiral D1: point + derivative.
void OCCTGeom2dEvalLogSpiralD1(double scale, double growthExponent, double u,
                                double* _Nonnull px, double* _Nonnull py,
                                double* _Nonnull vx, double* _Nonnull vy);

/// Evaluate circle involute D0 at parameter u.
/// C(t) = O + R*(cos(t) + t*sin(t))*XDir + R*(sin(t) - t*cos(t))*YDir
void OCCTGeom2dEvalCircleInvoluteD0(double radius, double u,
                                     double* _Nonnull px, double* _Nonnull py);

/// Evaluate circle involute D1: point + derivative.
void OCCTGeom2dEvalCircleInvoluteD1(double radius, double u,
                                     double* _Nonnull px, double* _Nonnull py,
                                     double* _Nonnull vx, double* _Nonnull vy);

/// Evaluate 2D sine wave D0 at parameter u.
/// C(t) = O + t*XDir + A*sin(omega*t + phi)*YDir
void OCCTGeom2dEvalSineWaveD0(double amplitude, double omega, double phase, double u,
                               double* _Nonnull px, double* _Nonnull py);

/// Evaluate 2D sine wave D1: point + derivative.
void OCCTGeom2dEvalSineWaveD1(double amplitude, double omega, double phase, double u,
                               double* _Nonnull px, double* _Nonnull py,
                               double* _Nonnull vx, double* _Nonnull vy);

// --- GeomFill_Gordon ---

/// Build a Gordon surface from a network of profile and guide curves.
/// profiles and guides are arrays of OCCTCurve3DRef. Returns surface or NULL.
OCCTSurfaceRef _Nullable OCCTGeomFillGordon(const OCCTCurve3DRef _Nonnull * _Nonnull profiles,
                                             int32_t profileCount,
                                             const OCCTCurve3DRef _Nonnull * _Nonnull guides,
                                             int32_t guideCount,
                                             double tolerance);

// --- ExtremaPC (Point-Curve Extrema) ---

/// Find closest point on a Geom_Curve to a query point.
/// Returns number of extrema found (0 on failure).
/// outParams[i] = parameter on curve, outDistances[i] = distance.
int32_t OCCTExtremaPCCurve(OCCTCurve3DRef _Nonnull curve,
                            double px, double py, double pz,
                            double* _Nonnull outParams, double* _Nonnull outDistances,
                            double* _Nonnull outPx, double* _Nonnull outPy, double* _Nonnull outPz,
                            int32_t maxResults);

/// Find closest point on a bounded Geom_Curve segment to a query point.
int32_t OCCTExtremaPCCurveBounded(OCCTCurve3DRef _Nonnull curve,
                                   double px, double py, double pz,
                                   double uMin, double uMax,
                                   double* _Nonnull outParams, double* _Nonnull outDistances,
                                   double* _Nonnull outPx, double* _Nonnull outPy, double* _Nonnull outPz,
                                   int32_t maxResults);

/// Find minimum distance from point to curve (convenience — returns distance, -1 on error).
double OCCTExtremaPCMinDistance(OCCTCurve3DRef _Nonnull curve,
                                double px, double py, double pz);

// MARK: - v0.131.0: Approx_BSplineApproxInterp, GeomEval TBezier/AHTBezier, GeomAdaptor_TransformedCurve

// --- Approx_BSplineApproxInterp ---

/// Opaque ref to Approx_BSplineApproxInterp solver.
typedef struct OCCTBSplineApproxInterp* OCCTBSplineApproxInterpRef;

/// Create a constrained least-squares B-spline approximation solver.
/// points: flat [x,y,z,...], count = number of 3D points.
OCCTBSplineApproxInterpRef _Nullable OCCTBSplineApproxInterpCreate(
    const double* _Nonnull points, int32_t count,
    int32_t nbControlPts, int32_t degree, bool continuousIfClosed);

/// Release the solver.
void OCCTBSplineApproxInterpRelease(OCCTBSplineApproxInterpRef _Nonnull ref);

/// Mark a point to be exactly interpolated (0-based index). withKink inserts C0 break.
void OCCTBSplineApproxInterpInterpolatePoint(OCCTBSplineApproxInterpRef _Nonnull ref,
                                              int32_t pointIndex, bool withKink);

/// Perform the fit using auto-computed parameters.
void OCCTBSplineApproxInterpPerform(OCCTBSplineApproxInterpRef _Nonnull ref);

/// Perform the fit with iterative parameter optimization.
void OCCTBSplineApproxInterpPerformOptimal(OCCTBSplineApproxInterpRef _Nonnull ref,
                                            int32_t maxIter);

/// Returns true if the fit was computed successfully.
bool OCCTBSplineApproxInterpIsDone(OCCTBSplineApproxInterpRef _Nonnull ref);

/// Returns the resulting curve, or null if not done.
OCCTCurve3DRef _Nullable OCCTBSplineApproxInterpCurve(OCCTBSplineApproxInterpRef _Nonnull ref);

/// Returns the maximum approximation error.
double OCCTBSplineApproxInterpMaxError(OCCTBSplineApproxInterpRef _Nonnull ref);

/// Set parametrization alpha: 0=uniform, 0.5=centripetal (default), 1=chord-length.
void OCCTBSplineApproxInterpSetAlpha(OCCTBSplineApproxInterpRef _Nonnull ref, double alpha);

/// Set minimum pivot value for Gauss solver (default 1e-20).
void OCCTBSplineApproxInterpSetMinPivot(OCCTBSplineApproxInterpRef _Nonnull ref, double val);

/// Set closed-curve detection tolerance (default 1e-12).
void OCCTBSplineApproxInterpSetClosedTol(OCCTBSplineApproxInterpRef _Nonnull ref, double val);

/// Set knot insertion tolerance (default 1e-4).
void OCCTBSplineApproxInterpSetKnotTol(OCCTBSplineApproxInterpRef _Nonnull ref, double val);

/// Set convergence tolerance for optimization (default 1e-3).
void OCCTBSplineApproxInterpSetConvergenceTol(OCCTBSplineApproxInterpRef _Nonnull ref, double val);

/// Set projection tolerance for optimization (default 1e-6).
void OCCTBSplineApproxInterpSetProjectionTol(OCCTBSplineApproxInterpRef _Nonnull ref, double val);

// --- GeomAdaptor_TransformedCurve ---

/// Create a transformed curve adaptor: wraps a Geom_Curve with a translation.
/// Returns a new Curve3D that evaluates the curve with the transform applied.
OCCTCurve3DRef _Nullable OCCTGeomAdaptorTransformedCurveCreate(
    OCCTCurve3DRef _Nonnull curve,
    double tx, double ty, double tz);

// --- GeomEval TBezier / AHTBezier Curves ---

/// Create a 3D Trigonometric Bezier curve. poles: flat [x,y,z,...], count must be odd >= 3.
OCCTCurve3DRef _Nullable OCCTGeomEvalTBezierCurveCreate(
    const double* _Nonnull poles, int32_t count, double alpha);

/// Create a 3D rational Trigonometric Bezier curve.
OCCTCurve3DRef _Nullable OCCTGeomEvalTBezierCurveCreateRational(
    const double* _Nonnull poles, const double* _Nonnull weights,
    int32_t count, double alpha);

/// Create a 3D AHT Bezier curve. count = algDeg+1 + 2*(alpha>0) + 2*(beta>0).
OCCTCurve3DRef _Nullable OCCTGeomEvalAHTBezierCurveCreate(
    const double* _Nonnull poles, int32_t count,
    int32_t algDegree, double alpha, double beta);

/// Create a 3D rational AHT Bezier curve.
OCCTCurve3DRef _Nullable OCCTGeomEvalAHTBezierCurveCreateRational(
    const double* _Nonnull poles, const double* _Nonnull weights,
    int32_t count, int32_t algDegree, double alpha, double beta);

// --- GeomEval TBezier / AHTBezier Surfaces ---

/// Create a Trigonometric Bezier surface. poles: flat row-major [x,y,z,...], uCount*vCount poles.
OCCTSurfaceRef _Nullable OCCTGeomEvalTBezierSurfaceCreate(
    const double* _Nonnull poles, int32_t uCount, int32_t vCount,
    double alphaU, double alphaV);

/// Create an AHT Bezier surface. poles: flat row-major, uCount*vCount poles.
OCCTSurfaceRef _Nullable OCCTGeomEvalAHTBezierSurfaceCreate(
    const double* _Nonnull poles, int32_t uCount, int32_t vCount,
    int32_t algDegreeU, int32_t algDegreeV,
    double alphaU, double alphaV, double betaU, double betaV);

// --- Geom2dEval TBezier / AHTBezier Curves ---

/// Create a 2D Trigonometric Bezier curve. poles: flat [x,y,...], count must be odd >= 3.
OCCTCurve2DRef _Nullable OCCTGeom2dEvalTBezierCurveCreate(
    const double* _Nonnull poles, int32_t count, double alpha);

/// Create a 2D AHT Bezier curve. count = algDeg+1 + 2*(alpha>0) + 2*(beta>0).
OCCTCurve2DRef _Nullable OCCTGeom2dEvalAHTBezierCurveCreate(
    const double* _Nonnull poles, int32_t count,
    int32_t algDegree, double alpha, double beta);

// MARK: - BRepGraph (Topology Graph)

/// Opaque handle to a BRepGraph instance.
typedef struct OCCTBRepGraph* OCCTBRepGraphRef;

/// Create a BRepGraph from a shape.
OCCTBRepGraphRef _Nullable OCCTBRepGraphCreate(OCCTShapeRef _Nonnull shape, bool parallel);

/// Release a BRepGraph.
void OCCTBRepGraphRelease(OCCTBRepGraphRef _Nonnull graph);

/// Check if the graph was built successfully.
bool OCCTBRepGraphIsDone(OCCTBRepGraphRef _Nonnull graph);

/// Total number of nodes in the graph.
int32_t OCCTBRepGraphNbNodes(OCCTBRepGraphRef _Nonnull graph);

// --- Topology Counts ---

/// Number of faces in the graph.
int32_t OCCTBRepGraphNbFaces(OCCTBRepGraphRef _Nonnull graph);
/// Number of active (non-removed) faces.
int32_t OCCTBRepGraphNbActiveFaces(OCCTBRepGraphRef _Nonnull graph);
/// Number of edges in the graph.
int32_t OCCTBRepGraphNbEdges(OCCTBRepGraphRef _Nonnull graph);
/// Number of active edges.
int32_t OCCTBRepGraphNbActiveEdges(OCCTBRepGraphRef _Nonnull graph);
/// Number of vertices in the graph.
int32_t OCCTBRepGraphNbVertices(OCCTBRepGraphRef _Nonnull graph);
/// Number of active vertices.
int32_t OCCTBRepGraphNbActiveVertices(OCCTBRepGraphRef _Nonnull graph);
/// Number of wires.
int32_t OCCTBRepGraphNbWires(OCCTBRepGraphRef _Nonnull graph);
/// Number of shells.
int32_t OCCTBRepGraphNbShells(OCCTBRepGraphRef _Nonnull graph);
/// Number of solids.
int32_t OCCTBRepGraphNbSolids(OCCTBRepGraphRef _Nonnull graph);
/// Number of coedges (half-edges).
int32_t OCCTBRepGraphNbCoEdges(OCCTBRepGraphRef _Nonnull graph);
/// Number of compounds.
int32_t OCCTBRepGraphNbCompounds(OCCTBRepGraphRef _Nonnull graph);

// --- Geometry Counts ---

/// Number of surfaces in the graph.
int32_t OCCTBRepGraphNbSurfaces(OCCTBRepGraphRef _Nonnull graph);
/// Number of 3D curves.
int32_t OCCTBRepGraphNbCurves3D(OCCTBRepGraphRef _Nonnull graph);
/// Number of 2D curves.
int32_t OCCTBRepGraphNbCurves2D(OCCTBRepGraphRef _Nonnull graph);

// --- Face Queries ---

/// Number of faces adjacent to a given face.
int32_t OCCTBRepGraphFaceAdjacentCount(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex);
/// Get adjacent face indices. Caller provides buffer of size adjacentCount.
void OCCTBRepGraphFaceAdjacentIndices(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex,
                                       int32_t* _Nonnull outIndices);
/// Number of edges shared between two faces.
int32_t OCCTBRepGraphFaceSharedEdgeCount(OCCTBRepGraphRef _Nonnull graph,
                                          int32_t faceA, int32_t faceB);
/// Get shared edge indices between two faces. Caller provides buffer.
void OCCTBRepGraphFaceSharedEdgeIndices(OCCTBRepGraphRef _Nonnull graph,
                                         int32_t faceA, int32_t faceB,
                                         int32_t* _Nonnull outIndices);
/// Index of the outer wire of a face.
int32_t OCCTBRepGraphFaceOuterWire(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex);

// --- Edge Queries ---

/// Number of faces an edge belongs to.
int32_t OCCTBRepGraphEdgeNbFaces(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex);
/// Get face indices for an edge. Caller provides buffer of size nbFaces.
void OCCTBRepGraphEdgeFaceIndices(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex,
                                   int32_t* _Nonnull outIndices);
/// Whether an edge is a boundary edge (belongs to only one face).
bool OCCTBRepGraphEdgeIsBoundary(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex);
/// Whether an edge is manifold (belongs to exactly two faces).
bool OCCTBRepGraphEdgeIsManifold(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex);
/// Number of edges adjacent to a given edge (share a vertex).
int32_t OCCTBRepGraphEdgeAdjacentCount(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex);
/// Get adjacent edge indices. Caller provides buffer.
void OCCTBRepGraphEdgeAdjacentIndices(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex,
                                       int32_t* _Nonnull outIndices);

// --- Vertex Queries ---

/// Number of edges connected to a vertex.
int32_t OCCTBRepGraphVertexEdgeCount(OCCTBRepGraphRef _Nonnull graph, int32_t vertexIndex);
/// Get edge indices connected to a vertex. Caller provides buffer.
void OCCTBRepGraphVertexEdgeIndices(OCCTBRepGraphRef _Nonnull graph, int32_t vertexIndex,
                                     int32_t* _Nonnull outIndices);

// --- Child Explorer ---

/// Count descendant nodes of a given kind from a root node.
/// rootKind: 0=Solid,1=Shell,2=Face,3=Wire,4=Edge,5=Vertex,6=Compound,7=CompSolid,8=CoEdge
/// targetKind: same enum.
int32_t OCCTBRepGraphChildCount(OCCTBRepGraphRef _Nonnull graph,
                                 int32_t rootKind, int32_t rootIndex,
                                 int32_t targetKind);

/// List descendant node indices of a given kind from a root node. Writes up to
/// maxCount indices into outIndices; returns the actual count (may exceed maxCount).
/// Used by TopologyRef.containedIn resolution and construction-geometry accessors.
int32_t OCCTBRepGraphChildIndices(OCCTBRepGraphRef _Nonnull graph,
                                    int32_t rootKind, int32_t rootIndex,
                                    int32_t targetKind,
                                    int32_t* _Nonnull outIndices,
                                    int32_t maxCount);

// --- Parent Explorer ---

/// Count parent nodes of a given node.
int32_t OCCTBRepGraphParentCount(OCCTBRepGraphRef _Nonnull graph,
                                  int32_t nodeKind, int32_t nodeIndex);

// --- Validate ---

/// Validate the graph. Returns true if valid (no errors).
bool OCCTBRepGraphValidate(OCCTBRepGraphRef _Nonnull graph);
/// Count validation issues.
int32_t OCCTBRepGraphValidateIssueCount(OCCTBRepGraphRef _Nonnull graph);

/// Validate result struct.
typedef struct {
    bool isValid;
    int32_t errorCount;
    int32_t warningCount;
} OCCTBRepGraphValidateResult;

/// Validate and return detailed result.
OCCTBRepGraphValidateResult OCCTBRepGraphValidateDetailed(OCCTBRepGraphRef _Nonnull graph);

// --- Compact ---

/// Compact result struct.
typedef struct {
    int32_t removedVertices;
    int32_t removedEdges;
    int32_t removedFaces;
    int32_t nodesAfter;
} OCCTBRepGraphCompactResult;

/// Compact the graph (remove unreferenced nodes).
OCCTBRepGraphCompactResult OCCTBRepGraphCompact(OCCTBRepGraphRef _Nonnull graph);

// --- Deduplicate ---

/// Deduplicate result struct.
typedef struct {
    int32_t canonicalSurfaces;
    int32_t canonicalCurves;
    int32_t surfaceRewrites;
    int32_t curveRewrites;
} OCCTBRepGraphDeduplicateResult;

/// Deduplicate geometry in the graph.
OCCTBRepGraphDeduplicateResult OCCTBRepGraphDeduplicate(OCCTBRepGraphRef _Nonnull graph);

// --- Node Removal Check ---

/// Check if a node has been soft-removed.
bool OCCTBRepGraphIsRemoved(OCCTBRepGraphRef _Nonnull graph, int32_t nodeKind, int32_t nodeIndex);

// --- Root Nodes ---

/// Number of root nodes in the graph.
int32_t OCCTBRepGraphRootCount(OCCTBRepGraphRef _Nonnull graph);
/// Get root node kinds and indices. Caller provides buffers of size rootCount.
void OCCTBRepGraphRootNodes(OCCTBRepGraphRef _Nonnull graph,
                             int32_t* _Nonnull outKinds, int32_t* _Nonnull outIndices);

// --- Topology Statistics ---

/// Get all topology counts at once.
typedef struct {
    int32_t solids;
    int32_t shells;
    int32_t faces;
    int32_t wires;
    int32_t edges;
    int32_t vertices;
    int32_t coedges;
    int32_t compounds;
    int32_t totalNodes;
    int32_t surfaces;
    int32_t curves3d;
    int32_t curves2d;
} OCCTBRepGraphStats;

/// Get comprehensive graph statistics.
OCCTBRepGraphStats OCCTBRepGraphGetStats(OCCTBRepGraphRef _Nonnull graph);

// MARK: - BRepGraph Extended (v0.133.0)

/// Reconstruct a TopoDS_Shape from a graph node.
OCCTShapeRef _Nullable OCCTBRepGraphShapeFromNode(OCCTBRepGraphRef _Nonnull graph,
                                                   int32_t nodeKind, int32_t nodeIndex);

/// Find the node (kind+index) for a shape. Returns -1 in outKind if not found.
void OCCTBRepGraphFindNode(OCCTBRepGraphRef _Nonnull graph, OCCTShapeRef _Nonnull shape,
                           int32_t* _Nonnull outKind, int32_t* _Nonnull outIndex);

/// Check if a shape is known to the graph.
bool OCCTBRepGraphHasNode(OCCTBRepGraphRef _Nonnull graph, OCCTShapeRef _Nonnull shape);

// --- Vertex Geometry ---

/// Get vertex 3D point.
void OCCTBRepGraphVertexPoint(OCCTBRepGraphRef _Nonnull graph, int32_t vertexIndex,
                              double* _Nonnull outX, double* _Nonnull outY, double* _Nonnull outZ);

/// Get vertex tolerance.
double OCCTBRepGraphVertexTolerance(OCCTBRepGraphRef _Nonnull graph, int32_t vertexIndex);

// --- Edge Geometry ---

/// Get edge tolerance.
double OCCTBRepGraphEdgeTolerance(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex);

/// Check if edge is degenerated.
bool OCCTBRepGraphEdgeIsDegenerated(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex);

/// Check if edge has SameParameter flag.
bool OCCTBRepGraphEdgeIsSameParameter(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex);

/// Check if edge has SameRange flag.
bool OCCTBRepGraphEdgeIsSameRange(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex);

/// Get edge parameter range.
void OCCTBRepGraphEdgeRange(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex,
                            double* _Nonnull outFirst, double* _Nonnull outLast);

/// Check if edge has a 3D curve.
bool OCCTBRepGraphEdgeHasCurve(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex);

/// Check if edge is closed (seam) on a face.
bool OCCTBRepGraphEdgeIsClosedOnFace(OCCTBRepGraphRef _Nonnull graph,
                                     int32_t edgeIndex, int32_t faceIndex);

/// Check if edge has a 3D polygon.
bool OCCTBRepGraphEdgeHasPolygon3D(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex);

/// Get maximum continuity order of an edge.
int32_t OCCTBRepGraphEdgeMaxContinuity(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex);

// --- Face Geometry ---

/// Get face tolerance.
double OCCTBRepGraphFaceTolerance(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex);

/// Check if face has natural restriction.
bool OCCTBRepGraphFaceIsNaturalRestriction(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex);

/// Check if face has a surface.
bool OCCTBRepGraphFaceHasSurface(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex);

/// Check if face has a triangulation.
bool OCCTBRepGraphFaceHasTriangulation(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex);

// --- Wire Queries ---

/// Check if wire is closed.
bool OCCTBRepGraphWireIsClosed(OCCTBRepGraphRef _Nonnull graph, int32_t wireIndex);

/// Number of coedges in a wire.
int32_t OCCTBRepGraphWireNbCoEdges(OCCTBRepGraphRef _Nonnull graph, int32_t wireIndex);

/// Number of faces a wire belongs to.
int32_t OCCTBRepGraphWireFaceCount(OCCTBRepGraphRef _Nonnull graph, int32_t wireIndex);

/// Get face indices a wire belongs to.
void OCCTBRepGraphWireFaceIndices(OCCTBRepGraphRef _Nonnull graph, int32_t wireIndex,
                                  int32_t* _Nonnull outIndices);

// --- CoEdge Queries ---

/// Get edge index for a coedge.
int32_t OCCTBRepGraphCoEdgeEdge(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex);

/// Get face index for a coedge.
int32_t OCCTBRepGraphCoEdgeFace(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex);

/// Get seam pair coedge index (-1 if none).
int32_t OCCTBRepGraphCoEdgeSeamPair(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex);

/// Check if coedge has a PCurve.
bool OCCTBRepGraphCoEdgeHasPCurve(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex);

/// Get coedge PCurve range.
void OCCTBRepGraphCoEdgeRange(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex,
                              double* _Nonnull outFirst, double* _Nonnull outLast);

// --- Shell Queries ---

/// Number of solids a shell belongs to.
int32_t OCCTBRepGraphShellSolidCount(OCCTBRepGraphRef _Nonnull graph, int32_t shellIndex);

/// Get solid indices a shell belongs to.
void OCCTBRepGraphShellSolidIndices(OCCTBRepGraphRef _Nonnull graph, int32_t shellIndex,
                                    int32_t* _Nonnull outIndices);

// --- Solid Queries ---

/// Number of comp-solids a solid belongs to.
int32_t OCCTBRepGraphSolidCompSolidCount(OCCTBRepGraphRef _Nonnull graph, int32_t solidIndex);

// --- History ---

/// Number of history records.
int32_t OCCTBRepGraphHistoryNbRecords(OCCTBRepGraphRef _Nonnull graph);

/// Check if history recording is enabled.
bool OCCTBRepGraphHistoryIsEnabled(OCCTBRepGraphRef _Nonnull graph);

/// Enable or disable history recording.
void OCCTBRepGraphHistorySetEnabled(OCCTBRepGraphRef _Nonnull graph, bool enabled);

/// Clear all history records.
void OCCTBRepGraphHistoryClear(OCCTBRepGraphRef _Nonnull graph);

// --- History Record Readback (v0.141, #72 Phase 0) ---

/// Get operation name and sequence number of history record at index.
/// outOpName is written with a NUL-terminated string up to outOpNameMax bytes.
/// Returns false on invalid index.
bool OCCTBRepGraphHistoryGetRecordInfo(OCCTBRepGraphRef _Nonnull graph,
                                        int32_t recordIdx,
                                        char* _Nonnull outOpName,
                                        int32_t outOpNameMax,
                                        int32_t* _Nonnull outSequenceNumber);

/// Number of original (pre-mutation) nodes in record's mapping.
int32_t OCCTBRepGraphHistoryGetRecordOriginalsCount(OCCTBRepGraphRef _Nonnull graph,
                                                     int32_t recordIdx);

/// List the original nodes of a history record. Writes up to maxCount pairs;
/// returns actual count (may exceed maxCount if truncated).
int32_t OCCTBRepGraphHistoryGetRecordOriginals(OCCTBRepGraphRef _Nonnull graph,
                                                int32_t recordIdx,
                                                int32_t* _Nonnull outKinds,
                                                int32_t* _Nonnull outIndices,
                                                int32_t maxCount);

/// For a specific original node in a record, list the replacement nodes.
/// Empty result = node was deleted. Single element = modified-in-place. Multiple = split.
/// Returns -1 if the original is not in the record's mapping.
int32_t OCCTBRepGraphHistoryGetRecordMapping(OCCTBRepGraphRef _Nonnull graph,
                                              int32_t recordIdx,
                                              int32_t origKind,
                                              int32_t origIndex,
                                              int32_t* _Nonnull outKinds,
                                              int32_t* _Nonnull outIndices,
                                              int32_t maxCount);

/// Walk backwards from a derived node to its root original via the reverse map.
/// Returns true if an original is found; outputs the original's (kind, index).
/// If the node has no recorded history, returns true with the input node itself.
bool OCCTBRepGraphHistoryFindOriginal(OCCTBRepGraphRef _Nonnull graph,
                                       int32_t derivedKind,
                                       int32_t derivedIndex,
                                       int32_t* _Nonnull outKind,
                                       int32_t* _Nonnull outIndex);

/// Walk forward from an original node to all transitively derived nodes.
/// Returns the total count; writes up to maxCount pairs.
int32_t OCCTBRepGraphHistoryFindDerived(OCCTBRepGraphRef _Nonnull graph,
                                         int32_t origKind,
                                         int32_t origIndex,
                                         int32_t* _Nonnull outKinds,
                                         int32_t* _Nonnull outIndices,
                                         int32_t maxCount);

/// Record a 1-to-N modification event on the graph's history log.
/// Useful for consumers that mutate the graph outside BRepGraph's own builder API
/// and want their changes to participate in history queries.
void OCCTBRepGraphHistoryRecord(OCCTBRepGraphRef _Nonnull graph,
                                 const char* _Nonnull opName,
                                 int32_t origKind,
                                 int32_t origIndex,
                                 const int32_t* _Nullable replKinds,
                                 const int32_t* _Nullable replIndices,
                                 int32_t replCount);

// --- Poly Counts ---

/// Number of triangulations.
int32_t OCCTBRepGraphNbTriangulations(OCCTBRepGraphRef _Nonnull graph);

/// Number of 3D polygons.
int32_t OCCTBRepGraphNbPolygons3D(OCCTBRepGraphRef _Nonnull graph);

// --- MeshView additions (v0.158.0, OCCT 8.0.0 beta1 two-tier mesh storage) ---

/// Number of 2D polygons (PCurve discretizations).
int32_t OCCTBRepGraphMeshNbPolygons2D(OCCTBRepGraphRef _Nonnull graph);

/// Number of polygon-on-triangulation reps (coedge discretizations parameterized on a face triangulation).
int32_t OCCTBRepGraphMeshNbPolygonsOnTri(OCCTBRepGraphRef _Nonnull graph);

/// Number of active (non-removed) triangulations.
int32_t OCCTBRepGraphMeshNbActiveTriangulations(OCCTBRepGraphRef _Nonnull graph);

/// Number of active 3D polygons.
int32_t OCCTBRepGraphMeshNbActivePolygons3D(OCCTBRepGraphRef _Nonnull graph);

/// Number of active 2D polygons.
int32_t OCCTBRepGraphMeshNbActivePolygons2D(OCCTBRepGraphRef _Nonnull graph);

/// Number of active polygon-on-triangulation reps.
int32_t OCCTBRepGraphMeshNbActivePolygonsOnTri(OCCTBRepGraphRef _Nonnull graph);

/// Active triangulation rep id for a face (cache-first, persistent fallback).
/// Returns the rep id, or -1 if no mesh available.
int32_t OCCTBRepGraphMeshFaceActiveTriangulationRepId(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex);

/// Active polygon-3D rep id for an edge (cache-first, persistent fallback).
/// Returns the rep id, or -1 if no polygon3D mesh available.
int32_t OCCTBRepGraphMeshEdgePolygon3DRepId(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex);

/// Whether a coedge has cached mesh data (polygon-on-tri or polygon-2D). Cache-only check.
bool OCCTBRepGraphMeshCoEdgeHasMesh(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex);

// --- MeshCache write API (v0.160.0): BRepGraph_Tool::Mesh statics ---

/// Create a TriangulationRep in mesh storage. Returns the rep id, or -1 on null/failure.
int32_t OCCTBRepGraphMeshCreateTriangulationRep(OCCTBRepGraphRef _Nonnull graph, OCCTPolyTriangulationRef _Nonnull triangulation);

/// Create a Polygon3DRep in mesh storage. Returns the rep id, or -1 on null/failure.
int32_t OCCTBRepGraphMeshCreatePolygon3DRep(OCCTBRepGraphRef _Nonnull graph, OCCTPolyPolygon3DRef _Nonnull polygon);

/// Create a PolygonOnTriRep linked to an existing triangulation rep. Returns the rep id, or -1 on failure.
int32_t OCCTBRepGraphMeshCreatePolygonOnTriRep(OCCTBRepGraphRef _Nonnull graph, OCCTPolyPolygonOnTriRef _Nonnull polygon, int32_t triRepId);

/// Append a triangulation rep to a face's cached mesh (multi-LOD support).
void OCCTBRepGraphMeshAppendCachedTriangulation(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex, int32_t triRepId);

/// Set the active triangulation index in a face's cached mesh.
void OCCTBRepGraphMeshSetCachedActiveIndex(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex, int32_t activeIndex);

/// Set the polygon-3D rep in an edge's cached mesh.
void OCCTBRepGraphMeshSetCachedPolygon3D(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex, int32_t polyRepId);

/// Append a polygon-on-tri rep to a coedge's cached mesh (seam edge support).
void OCCTBRepGraphMeshAppendCachedPolygonOnTri(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex, int32_t polyRepId);

/// Set the polygon-2D rep in a coedge's cached mesh.
void OCCTBRepGraphMeshSetCachedPolygon2D(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex, int32_t poly2DRepId);

// --- Active Geometry Counts ---

/// Number of active (non-removed) surfaces.
int32_t OCCTBRepGraphNbActiveSurfaces(OCCTBRepGraphRef _Nonnull graph);

/// Number of active 3D curves.
int32_t OCCTBRepGraphNbActiveCurves3D(OCCTBRepGraphRef _Nonnull graph);

/// Number of active 2D curves.
int32_t OCCTBRepGraphNbActiveCurves2D(OCCTBRepGraphRef _Nonnull graph);

// --- SameDomain ---

/// Number of same-domain faces for a given face.
int32_t OCCTBRepGraphFaceSameDomainCount(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex);

/// Get same-domain face indices.
void OCCTBRepGraphFaceSameDomainIndices(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex,
                                        int32_t* _Nonnull outIndices);

// --- Copy and Transform ---

/// Deep copy the graph.
OCCTBRepGraphRef _Nullable OCCTBRepGraphCopy(OCCTBRepGraphRef _Nonnull graph, bool copyGeom);

/// Copy a single face sub-graph.
OCCTBRepGraphRef _Nullable OCCTBRepGraphCopyFace(OCCTBRepGraphRef _Nonnull graph,
                                                  int32_t faceIndex, bool copyGeom);

/// Transform the graph by a translation vector.
OCCTBRepGraphRef _Nullable OCCTBRepGraphTransformTranslation(OCCTBRepGraphRef _Nonnull graph,
                                                              double dx, double dy, double dz,
                                                              bool copyGeom);

// MARK: - BRepGraph Assembly & Refs (v0.134.0)

// --- Product (Assembly) Queries ---

/// Number of products in the graph.
int32_t OCCTBRepGraphNbProducts(OCCTBRepGraphRef _Nonnull graph);

/// Number of occurrences in the graph.
int32_t OCCTBRepGraphNbOccurrences(OCCTBRepGraphRef _Nonnull graph);

/// Whether product at index is an assembly (has child occurrences, no topology root).
bool OCCTBRepGraphProductIsAssembly(OCCTBRepGraphRef _Nonnull graph, int32_t productIndex);

/// Whether product at index is a part (has a valid topology root).
bool OCCTBRepGraphProductIsPart(OCCTBRepGraphRef _Nonnull graph, int32_t productIndex);

/// Number of active child occurrences of a product.
int32_t OCCTBRepGraphProductNbComponents(OCCTBRepGraphRef _Nonnull graph, int32_t productIndex);

/// Shape root node kind for a product (-1 if invalid/assembly).
int32_t OCCTBRepGraphProductShapeRootKind(OCCTBRepGraphRef _Nonnull graph, int32_t productIndex);

/// Shape root node index for a product (-1 if invalid/assembly).
int32_t OCCTBRepGraphProductShapeRootIndex(OCCTBRepGraphRef _Nonnull graph, int32_t productIndex);

/// Product index of an occurrence.
int32_t OCCTBRepGraphOccurrenceProduct(OCCTBRepGraphRef _Nonnull graph, int32_t occIndex);

/// Parent product index of an occurrence.
int32_t OCCTBRepGraphOccurrenceParentProduct(OCCTBRepGraphRef _Nonnull graph, int32_t occIndex);

/// Number of root products (not referenced by an active occurrence).
int32_t OCCTBRepGraphRootProductCount(OCCTBRepGraphRef _Nonnull graph);

/// Get root product indices.
void OCCTBRepGraphRootProductIndices(OCCTBRepGraphRef _Nonnull graph,
                                     int32_t* _Nonnull outIndices);

// --- RefsView Per-Kind Counts ---

/// Number of shell reference entries.
int32_t OCCTBRepGraphNbShellRefs(OCCTBRepGraphRef _Nonnull graph);

/// Number of face reference entries.
int32_t OCCTBRepGraphNbFaceRefs(OCCTBRepGraphRef _Nonnull graph);

/// Number of wire reference entries.
int32_t OCCTBRepGraphNbWireRefs(OCCTBRepGraphRef _Nonnull graph);

/// Number of coedge reference entries.
int32_t OCCTBRepGraphNbCoEdgeRefs(OCCTBRepGraphRef _Nonnull graph);

/// Number of vertex reference entries.
int32_t OCCTBRepGraphNbVertexRefs(OCCTBRepGraphRef _Nonnull graph);

/// Number of solid reference entries.
int32_t OCCTBRepGraphNbSolidRefs(OCCTBRepGraphRef _Nonnull graph);

/// Number of child reference entries.
int32_t OCCTBRepGraphNbChildRefs(OCCTBRepGraphRef _Nonnull graph);

/// Number of occurrence reference entries.
int32_t OCCTBRepGraphNbOccurrenceRefs(OCCTBRepGraphRef _Nonnull graph);

// --- RefsView Global Methods ---

/// Child node kind from a reference entry. refKind uses BRepGraph_RefId::Kind values.
int32_t OCCTBRepGraphRefChildNodeKind(OCCTBRepGraphRef _Nonnull graph,
                                       int32_t refKind, int32_t refIndex);

/// Child node index from a reference entry.
int32_t OCCTBRepGraphRefChildNodeIndex(OCCTBRepGraphRef _Nonnull graph,
                                        int32_t refKind, int32_t refIndex);

/// Whether a reference entry is removed.
bool OCCTBRepGraphRefIsRemoved(OCCTBRepGraphRef _Nonnull graph,
                                int32_t refKind, int32_t refIndex);

/// Orientation of a reference entry (TopAbs_Orientation as int).
int32_t OCCTBRepGraphRefOrientation(OCCTBRepGraphRef _Nonnull graph,
                                     int32_t refKind, int32_t refIndex);

// --- Face Definition Details ---

/// Number of wire refs on a face.
int32_t OCCTBRepGraphFaceNbWires(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex);

/// Number of isolated vertex refs on a face.
int32_t OCCTBRepGraphFaceNbVertexRefs(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex);

// --- Edge Definition Details ---

/// Start vertex definition index of an edge (-1 if invalid).
int32_t OCCTBRepGraphEdgeStartVertex(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex);

/// End vertex definition index of an edge (-1 if invalid).
int32_t OCCTBRepGraphEdgeEndVertex(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex);

/// Whether an edge is topologically closed (start == end vertex).
bool OCCTBRepGraphEdgeIsClosed(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex);

// --- Compound/CompSolid Queries ---

/// Number of parent compounds of a compound.
int32_t OCCTBRepGraphCompoundParentCount(OCCTBRepGraphRef _Nonnull graph, int32_t compoundIndex);

/// Number of child refs of a compound.
int32_t OCCTBRepGraphCompoundChildCount(OCCTBRepGraphRef _Nonnull graph, int32_t compoundIndex);

/// Number of solid refs in a comp-solid.
int32_t OCCTBRepGraphCompSolidSolidCount(OCCTBRepGraphRef _Nonnull graph, int32_t compSolidIndex);

/// Number of parent compounds of a comp-solid.
int32_t OCCTBRepGraphCompSolidCompoundCount(OCCTBRepGraphRef _Nonnull graph, int32_t compSolidIndex);

// --- Edge Additional Queries ---

/// Number of wires an edge belongs to.
int32_t OCCTBRepGraphEdgeWireCount(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex);

/// Get wire indices an edge belongs to.
void OCCTBRepGraphEdgeWireIndices(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex,
                                   int32_t* _Nonnull outIndices);

/// Number of coedges of an edge.
int32_t OCCTBRepGraphEdgeCoEdgeCount(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex);

/// Get coedge indices of an edge.
void OCCTBRepGraphEdgeCoEdgeIndices(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex,
                                     int32_t* _Nonnull outIndices);

// --- Face Additional Queries ---

/// Number of shells a face belongs to.
int32_t OCCTBRepGraphFaceShellCount(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex);

/// Get shell indices a face belongs to.
void OCCTBRepGraphFaceShellIndices(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex,
                                    int32_t* _Nonnull outIndices);

/// Number of compounds a face belongs to.
int32_t OCCTBRepGraphFaceCompoundCount(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex);

// --- Shell Additional Queries ---

/// Number of compounds a shell belongs to.
int32_t OCCTBRepGraphShellCompoundCount(OCCTBRepGraphRef _Nonnull graph, int32_t shellIndex);

/// Whether a shell is closed.
bool OCCTBRepGraphShellIsClosed(OCCTBRepGraphRef _Nonnull graph, int32_t shellIndex);

// --- Solid Additional Queries ---

/// Number of compounds a solid belongs to.
int32_t OCCTBRepGraphSolidCompoundCount(OCCTBRepGraphRef _Nonnull graph, int32_t solidIndex);

// --- CompSolid Count ---

/// Number of comp-solids in the graph.
int32_t OCCTBRepGraphNbCompSolids(OCCTBRepGraphRef _Nonnull graph);

// --- Edge FindCoEdge ---

/// Find the coedge index for an (edge, face) pair (-1 if not found).
int32_t OCCTBRepGraphEdgeFindCoEdge(OCCTBRepGraphRef _Nonnull graph,
                                     int32_t edgeIndex, int32_t faceIndex);

// MARK: - BRepGraph Builder (v0.135.0)

// --- Add Topology Nodes ---

/// Add a vertex to the graph. Returns vertex definition index (-1 on failure).
int32_t OCCTBRepGraphBuilderAddVertex(OCCTBRepGraphRef _Nonnull graph,
                                       double x, double y, double z,
                                       double tolerance);

/// Add an empty shell to the graph. Returns shell definition index (-1 on failure).
int32_t OCCTBRepGraphBuilderAddShell(OCCTBRepGraphRef _Nonnull graph);

/// Add an empty solid to the graph. Returns solid definition index (-1 on failure).
int32_t OCCTBRepGraphBuilderAddSolid(OCCTBRepGraphRef _Nonnull graph);

/// Link a face to a shell. Returns face ref index (-1 on failure).
/// orientation: 0=FORWARD, 1=REVERSED, 2=INTERNAL, 3=EXTERNAL
int32_t OCCTBRepGraphBuilderAddFaceToShell(OCCTBRepGraphRef _Nonnull graph,
                                            int32_t shellIndex, int32_t faceIndex,
                                            int32_t orientation);

/// Link a shell to a solid. Returns shell ref index (-1 on failure).
int32_t OCCTBRepGraphBuilderAddShellToSolid(OCCTBRepGraphRef _Nonnull graph,
                                             int32_t solidIndex, int32_t shellIndex,
                                             int32_t orientation);

/// Add a compound with child node entries. Returns compound definition index (-1 on failure).
/// kinds and indices are parallel arrays of length count.
int32_t OCCTBRepGraphBuilderAddCompound(OCCTBRepGraphRef _Nonnull graph,
                                         const int32_t* _Nonnull kinds,
                                         const int32_t* _Nonnull indices,
                                         int32_t count);

/// Add a comp-solid with child solid indices. Returns compsolid definition index (-1 on failure).
int32_t OCCTBRepGraphBuilderAddCompSolid(OCCTBRepGraphRef _Nonnull graph,
                                          const int32_t* _Nonnull solidIndices,
                                          int32_t count);

// --- Remove/Modify Nodes ---

/// Mark a node as removed (soft deletion).
void OCCTBRepGraphBuilderRemoveNode(OCCTBRepGraphRef _Nonnull graph,
                                     int32_t nodeKind, int32_t nodeIndex);

/// Mark a node and all its descendants as removed.
void OCCTBRepGraphBuilderRemoveSubgraph(OCCTBRepGraphRef _Nonnull graph,
                                         int32_t nodeKind, int32_t nodeIndex);

// --- Append Shapes ---

/// Append a shape flattened (container nodes removed, faces as roots).
void OCCTBRepGraphBuilderAppendFlattenedShape(OCCTBRepGraphRef _Nonnull graph,
                                               OCCTShapeRef _Nonnull shape,
                                               bool parallel);

/// Append a shape preserving full topology hierarchy.
void OCCTBRepGraphBuilderAppendFullShape(OCCTBRepGraphRef _Nonnull graph,
                                          OCCTShapeRef _Nonnull shape,
                                          bool parallel);

// --- Deferred Invalidation ---

/// Begin deferred invalidation mode for batch mutations.
void OCCTBRepGraphBuilderBeginDeferred(OCCTBRepGraphRef _Nonnull graph);

/// End deferred invalidation mode and flush.
void OCCTBRepGraphBuilderEndDeferred(OCCTBRepGraphRef _Nonnull graph);

/// Check if deferred invalidation mode is active.
bool OCCTBRepGraphBuilderIsDeferredMode(OCCTBRepGraphRef _Nonnull graph);

/// Finalize batch mutations (validate reverse-index consistency).
void OCCTBRepGraphBuilderCommitMutation(OCCTBRepGraphRef _Nonnull graph);

// --- Edge Splitting ---

/// Split an edge at a vertex and parameter. Returns sub-edge indices via out params (-1 on failure).
void OCCTBRepGraphBuilderSplitEdge(OCCTBRepGraphRef _Nonnull graph,
                                    int32_t edgeIndex, int32_t vertexIndex,
                                    double param,
                                    int32_t* _Nonnull outSubA, int32_t* _Nonnull outSubB);

// --- Replace Edge in Wire ---

/// Replace one edge with another in a wire definition.
void OCCTBRepGraphBuilderReplaceEdgeInWire(OCCTBRepGraphRef _Nonnull graph,
                                            int32_t wireIndex, int32_t oldEdgeIndex,
                                            int32_t newEdgeIndex, bool reversed);

// --- Remove Ref ---

/// Mark a reference entry as removed. Returns true if transitioned from active to removed.
bool OCCTBRepGraphBuilderRemoveRef(OCCTBRepGraphRef _Nonnull graph,
                                    int32_t refKind, int32_t refIndex);

// --- Clear Mesh ---

/// Clear all mesh representations for a face and its coedges.
void OCCTBRepGraphBuilderClearFaceMesh(OCCTBRepGraphRef _Nonnull graph,
                                        int32_t faceIndex);

/// Clear Polygon3D representation from an edge.
void OCCTBRepGraphBuilderClearEdgePolygon3D(OCCTBRepGraphRef _Nonnull graph,
                                             int32_t edgeIndex);

// --- Validate Mutation Boundary ---

/// Validate mutation-boundary invariants. Returns true if no issues found.
bool OCCTBRepGraphBuilderValidateMutation(OCCTBRepGraphRef _Nonnull graph);

// MARK: - BRepGraph EditorView Field Setters (v0.159.0)
//
// Pure-value setters on the per-entity Ops classes of BRepGraph::EditorView.
// All take a typed entity id + scalar/bool argument and return void; on
// invalid id or out-of-range value the underlying call is a no-op.

// VertexOps
void OCCTBRepGraphSetVertexPoint(OCCTBRepGraphRef _Nonnull graph, int32_t vertexIndex, double x, double y, double z);
void OCCTBRepGraphSetVertexTolerance(OCCTBRepGraphRef _Nonnull graph, int32_t vertexIndex, double tolerance);

// EdgeOps
void OCCTBRepGraphSetEdgeTolerance(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex, double tolerance);
void OCCTBRepGraphSetEdgeParamRange(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex, double first, double last);
void OCCTBRepGraphSetEdgeSameParameter(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex, bool sameParameter);
void OCCTBRepGraphSetEdgeSameRange(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex, bool sameRange);
void OCCTBRepGraphSetEdgeDegenerate(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex, bool degenerate);
void OCCTBRepGraphSetEdgeIsClosed(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex, bool isClosed);

// CoEdgeOps
void OCCTBRepGraphSetCoEdgeParamRange(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex, double first, double last);
void OCCTBRepGraphSetCoEdgeOrientation(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex, int32_t orientation);

// WireOps
void OCCTBRepGraphSetWireIsClosed(OCCTBRepGraphRef _Nonnull graph, int32_t wireIndex, bool isClosed);

// FaceOps
void OCCTBRepGraphSetFaceTolerance(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex, double tolerance);
void OCCTBRepGraphSetFaceNaturalRestriction(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex, bool naturalRestriction);

// ShellOps
void OCCTBRepGraphSetShellIsClosed(OCCTBRepGraphRef _Nonnull graph, int32_t shellIndex, bool isClosed);

// MARK: - BRepGraph EditorView Add/Remove + Ref Setters (v0.161.0)
//
// Add operations return the typed ref id (or -1 on failure). Remove operations return
// bool indicating whether the active usage was removed. Ref setters are no-ops on
// invalid ids.

// Add operations (Ref-typed return)
int32_t OCCTBRepGraphEdgeAddInternalVertex(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex, int32_t vertexIndex, int32_t orientation);
int32_t OCCTBRepGraphFaceAddVertex(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex, int32_t vertexIndex, int32_t orientation);
int32_t OCCTBRepGraphShellAddChild(OCCTBRepGraphRef _Nonnull graph, int32_t shellIndex, int32_t childKind, int32_t childIndex, int32_t orientation);
int32_t OCCTBRepGraphSolidAddChild(OCCTBRepGraphRef _Nonnull graph, int32_t solidIndex, int32_t childKind, int32_t childIndex, int32_t orientation);
int32_t OCCTBRepGraphCompoundAddChild(OCCTBRepGraphRef _Nonnull graph, int32_t compoundIndex, int32_t childKind, int32_t childIndex, int32_t orientation);
int32_t OCCTBRepGraphCompSolidAddSolid(OCCTBRepGraphRef _Nonnull graph, int32_t compSolidIndex, int32_t solidIndex, int32_t orientation);

// Remove operations
bool OCCTBRepGraphEdgeRemoveVertex(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex, int32_t vertexRefIndex);
int32_t OCCTBRepGraphEdgeReplaceVertex(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex, int32_t oldVertexRefIndex, int32_t newVertexIndex);
bool OCCTBRepGraphWireRemoveCoEdge(OCCTBRepGraphRef _Nonnull graph, int32_t wireIndex, int32_t coedgeRefIndex);
bool OCCTBRepGraphFaceRemoveVertex(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex, int32_t vertexRefIndex);
bool OCCTBRepGraphFaceRemoveWire(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex, int32_t wireRefIndex);
bool OCCTBRepGraphShellRemoveFace(OCCTBRepGraphRef _Nonnull graph, int32_t shellIndex, int32_t faceRefIndex);
bool OCCTBRepGraphShellRemoveChild(OCCTBRepGraphRef _Nonnull graph, int32_t shellIndex, int32_t childRefIndex);
bool OCCTBRepGraphSolidRemoveShell(OCCTBRepGraphRef _Nonnull graph, int32_t solidIndex, int32_t shellRefIndex);
bool OCCTBRepGraphSolidRemoveChild(OCCTBRepGraphRef _Nonnull graph, int32_t solidIndex, int32_t childRefIndex);
bool OCCTBRepGraphCompoundRemoveChild(OCCTBRepGraphRef _Nonnull graph, int32_t compoundIndex, int32_t childRefIndex);
bool OCCTBRepGraphCompSolidRemoveSolid(OCCTBRepGraphRef _Nonnull graph, int32_t compSolidIndex, int32_t solidRefIndex);
void OCCTBRepGraphRemoveRep(OCCTBRepGraphRef _Nonnull graph, int32_t repKind, int32_t repIndex);

// Simple Ref setters (no TopLoc_Location, no Bnd_Box2d)
void OCCTBRepGraphSetVertexRefOrientation(OCCTBRepGraphRef _Nonnull graph, int32_t vertexRefIndex, int32_t orientation);
void OCCTBRepGraphSetVertexRefVertexDefId(OCCTBRepGraphRef _Nonnull graph, int32_t vertexRefIndex, int32_t vertexIndex);
void OCCTBRepGraphSetEdgeStartVertexRefId(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex, int32_t vertexRefIndex);
void OCCTBRepGraphSetEdgeEndVertexRefId(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex, int32_t vertexRefIndex);
void OCCTBRepGraphSetEdgeCurve3DRepId(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex, int32_t curve3DRepId);
void OCCTBRepGraphSetEdgePolygon3DRepId(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex, int32_t polygon3DRepId);
void OCCTBRepGraphSetCoEdgeRefCoEdgeDefId(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeRefIndex, int32_t coedgeIndex);
void OCCTBRepGraphSetCoEdgeEdgeDefId(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex, int32_t edgeIndex);
void OCCTBRepGraphSetCoEdgeFaceDefId(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex, int32_t faceIndex);
void OCCTBRepGraphSetCoEdgeCurve2DRepId(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex, int32_t curve2DRepId);
void OCCTBRepGraphSetCoEdgePolygon2DRepId(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex, int32_t polygon2DRepId);
void OCCTBRepGraphSetCoEdgePolygonOnTriRepId(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex, int32_t polygonOnTriRepId);
void OCCTBRepGraphClearCoEdgePCurveBinding(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex);
void OCCTBRepGraphSetWireRefIsOuter(OCCTBRepGraphRef _Nonnull graph, int32_t wireRefIndex, bool isOuter);
void OCCTBRepGraphSetWireRefOrientation(OCCTBRepGraphRef _Nonnull graph, int32_t wireRefIndex, int32_t orientation);
void OCCTBRepGraphSetWireRefWireDefId(OCCTBRepGraphRef _Nonnull graph, int32_t wireRefIndex, int32_t wireIndex);
void OCCTBRepGraphSetFaceSurfaceRepId(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex, int32_t surfaceRepId);
void OCCTBRepGraphSetFaceRefOrientation(OCCTBRepGraphRef _Nonnull graph, int32_t faceRefIndex, int32_t orientation);
void OCCTBRepGraphSetFaceRefFaceDefId(OCCTBRepGraphRef _Nonnull graph, int32_t faceRefIndex, int32_t faceIndex);
void OCCTBRepGraphSetShellRefOrientation(OCCTBRepGraphRef _Nonnull graph, int32_t shellRefIndex, int32_t orientation);
void OCCTBRepGraphSetShellRefShellDefId(OCCTBRepGraphRef _Nonnull graph, int32_t shellRefIndex, int32_t shellIndex);
void OCCTBRepGraphSetSolidRefOrientation(OCCTBRepGraphRef _Nonnull graph, int32_t solidRefIndex, int32_t orientation);
void OCCTBRepGraphSetSolidRefSolidDefId(OCCTBRepGraphRef _Nonnull graph, int32_t solidRefIndex, int32_t solidIndex);
void OCCTBRepGraphSetOccurrenceChildDefId(OCCTBRepGraphRef _Nonnull graph, int32_t occurrenceIndex, int32_t childKind, int32_t childIndex);
void OCCTBRepGraphSetOccurrenceRefOccurrenceDefId(OCCTBRepGraphRef _Nonnull graph, int32_t occurrenceRefIndex, int32_t occurrenceIndex);
void OCCTBRepGraphSetChildRefOrientation(OCCTBRepGraphRef _Nonnull graph, int32_t childRefIndex, int32_t orientation);
void OCCTBRepGraphSetChildRefChildDefId(OCCTBRepGraphRef _Nonnull graph, int32_t childRefIndex, int32_t childKind, int32_t childIndex);

// MARK: - BRepGraph EditorView v0.162.0 — geometric setters, location setters, PCurve API

// CoEdge geometric setters
void OCCTBRepGraphSetCoEdgeUVBox(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex, double u1, double v1, double u2, double v2);
/// Set the geometric regularity (C^k continuity) for an edge across a pair of faces.
/// face1Index == face2Index sets the seam continuity across a closed-surface seam line.
/// Continuity uses GeomAbs_Shape: 0=C0, 1=C1, 2=C2, 3=C3, 4=CN.
/// Returns 1 if written, 0 if the LayerRegularity layer is not registered.
/// (OCCT 8.0.0 GA replaced per-coedge SetContinuity / SetSeamContinuity / SetSeamPairId
///  with this per-(edge, face1, face2) layer model. Seam-pair-id is structural in GA —
///  no setter exists; query via BRepGraph_Tool::CoEdge::SeamPair.)
int32_t OCCTBRepGraphSetEdgeRegularity(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex, int32_t face1Index, int32_t face2Index, int32_t continuity);

// Face triangulation rep binding
void OCCTBRepGraphSetFaceTriangulationRep(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex, int32_t triRepId);

// CoEdge PCurve operations (Geom2d_Curve handle from OCCTCurve2D opaque)
int32_t OCCTBRepGraphCoEdgeCreateCurve2DRep(OCCTBRepGraphRef _Nonnull graph, OCCTCurve2DRef _Nonnull curve2d);
/// Pass nullptr for curve2d to clear the PCurve binding.
void OCCTBRepGraphCoEdgeSetPCurve(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex, OCCTCurve2DRef _Nullable curve2d);
void OCCTBRepGraphCoEdgeAddPCurve(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex, int32_t faceIndex,
                                   OCCTCurve2DRef _Nonnull curve2d, double first, double last,
                                   int32_t orientation);

// Location setters (12-double 3x4 matrix, gp_Trsf::SetValues convention; row-major).
void OCCTBRepGraphSetVertexRefLocalLocation(OCCTBRepGraphRef _Nonnull graph, int32_t vertexRefIndex, const double* _Nonnull matrix);
void OCCTBRepGraphSetCoEdgeRefLocalLocation(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeRefIndex, const double* _Nonnull matrix);
void OCCTBRepGraphSetWireRefLocalLocation(OCCTBRepGraphRef _Nonnull graph, int32_t wireRefIndex, const double* _Nonnull matrix);
void OCCTBRepGraphSetFaceRefLocalLocation(OCCTBRepGraphRef _Nonnull graph, int32_t faceRefIndex, const double* _Nonnull matrix);
void OCCTBRepGraphSetShellRefLocalLocation(OCCTBRepGraphRef _Nonnull graph, int32_t shellRefIndex, const double* _Nonnull matrix);
void OCCTBRepGraphSetSolidRefLocalLocation(OCCTBRepGraphRef _Nonnull graph, int32_t solidRefIndex, const double* _Nonnull matrix);
void OCCTBRepGraphSetOccurrenceRefLocalLocation(OCCTBRepGraphRef _Nonnull graph, int32_t occurrenceRefIndex, const double* _Nonnull matrix);
void OCCTBRepGraphSetChildRefLocalLocation(OCCTBRepGraphRef _Nonnull graph, int32_t childRefIndex, const double* _Nonnull matrix);

// MARK: - BRepGraph EditorView v0.163.0 — ProductOps assembly building

/// Wrap an existing topology root in a Product. Returns the new product id or -1.
int32_t OCCTBRepGraphLinkProductToTopology(OCCTBRepGraphRef _Nonnull graph,
                                             int32_t shapeRootKind, int32_t shapeRootIndex,
                                             const double* _Nullable placementMatrix);

/// Create an empty product (assembly node with no direct topology). Returns product id or -1.
int32_t OCCTBRepGraphCreateEmptyProduct(OCCTBRepGraphRef _Nonnull graph);

/// Link two products via a fresh occurrence. Returns occurrence id, -1 on failure.
/// Outputs the new occurrence ref id via outOccurrenceRefId (-1 on failure or when null).
/// Pass parentOccurrenceIndex = -1 for an unparented occurrence.
int32_t OCCTBRepGraphLinkProducts(OCCTBRepGraphRef _Nonnull graph, int32_t parentProductIndex,
                                    int32_t referencedProductIndex,
                                    const double* _Nonnull placementMatrix,
                                    int32_t parentOccurrenceIndex,
                                    int32_t* _Nullable outOccurrenceRefId);

/// Detach an occurrence ref from a product.
bool OCCTBRepGraphProductRemoveOccurrence(OCCTBRepGraphRef _Nonnull graph, int32_t productIndex, int32_t occurrenceRefIndex);

/// Detach the scalar shape-root from a product.
bool OCCTBRepGraphProductRemoveShapeRoot(OCCTBRepGraphRef _Nonnull graph, int32_t productIndex);

// MARK: - BRepGraph EditorView RepOps non-guard setters (v0.164.0)
//
// Swap the geometry / mesh content bound to an existing rep id without recreating
// the rep. Pass a valid handle to bind, or skip — the bridge no-ops on null.

void OCCTBRepGraphRepSetSurface(OCCTBRepGraphRef _Nonnull graph, int32_t surfaceRepId, OCCTSurfaceRef _Nonnull surface);
void OCCTBRepGraphRepSetCurve3D(OCCTBRepGraphRef _Nonnull graph, int32_t curve3DRepId, OCCTCurve3DRef _Nonnull curve);
void OCCTBRepGraphRepSetCurve2D(OCCTBRepGraphRef _Nonnull graph, int32_t curve2DRepId, OCCTCurve2DRef _Nonnull curve);
void OCCTBRepGraphRepSetTriangulation(OCCTBRepGraphRef _Nonnull graph, int32_t triRepId, OCCTPolyTriangulationRef _Nonnull tri);
void OCCTBRepGraphRepSetPolygon3D(OCCTBRepGraphRef _Nonnull graph, int32_t polyRepId, OCCTPolyPolygon3DRef _Nonnull poly);
void OCCTBRepGraphRepSetPolygon2D(OCCTBRepGraphRef _Nonnull graph, int32_t polyRepId, OCCTPolyPolygon2DRef _Nonnull poly);
void OCCTBRepGraphRepSetPolygonOnTri(OCCTBRepGraphRef _Nonnull graph, int32_t polyRepId, OCCTPolyPolygonOnTriRef _Nonnull poly);
void OCCTBRepGraphRepSetPolygonOnTriTriangulationId(OCCTBRepGraphRef _Nonnull graph, int32_t polyOnTriRepId, int32_t triRepId);

// MARK: - BRepGraph MeshView cache entry inspection (v0.164.0)
//
// Detailed access to the algorithm-derived cache entries for diagnostics and
// non-destructive mesh tooling. All return 0/false/-1 for absent entries.

bool OCCTBRepGraphCachedFaceMeshIsPresent(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex);
int32_t OCCTBRepGraphCachedFaceMeshTriRepCount(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex);
int32_t OCCTBRepGraphCachedFaceMeshActiveIndex(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex);
uint32_t OCCTBRepGraphCachedFaceMeshStoredOwnGen(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex);
int32_t OCCTBRepGraphCachedFaceMeshTriRepId(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex, int32_t repIndex);

bool OCCTBRepGraphCachedEdgeMeshIsPresent(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex);
int32_t OCCTBRepGraphCachedEdgeMeshPolygon3DRepId(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex);
uint32_t OCCTBRepGraphCachedEdgeMeshStoredOwnGen(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex);

bool OCCTBRepGraphCachedCoEdgeMeshIsPresent(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex);
int32_t OCCTBRepGraphCachedCoEdgeMeshPolygon2DRepId(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex);
int32_t OCCTBRepGraphCachedCoEdgeMeshPolygonOnTriRepCount(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex);
int32_t OCCTBRepGraphCachedCoEdgeMeshPolygonOnTriRepId(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex, int32_t repIndex);
uint32_t OCCTBRepGraphCachedCoEdgeMeshStoredOwnGen(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex);

// MARK: - BRepGraph ML Export & Sampling (v0.136.0)

/// Sample a regular UV grid on a face surface. Returns point count (uSamples * vSamples),
/// or 0 on failure. Caller provides output buffers: positions (count*3 doubles),
/// normals (count*3 doubles), gaussianCurvatures (count doubles), meanCurvatures (count doubles).
int32_t OCCTBRepGraphSampleFaceUVGrid(
    OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex,
    int32_t uSamples, int32_t vSamples,
    double* _Nonnull outPositions, double* _Nonnull outNormals,
    double* _Nonnull outGaussianCurvatures, double* _Nonnull outMeanCurvatures);

/// Sample N evenly-spaced points along an edge curve.
/// Caller provides outPoints buffer of size count*3.
/// Returns actual number of points sampled (0 if edge has no curve).
int32_t OCCTBRepGraphSampleEdgeCurve(
    OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex,
    int32_t count, double* _Nonnull outPoints);

#ifdef __cplusplus
}
#endif

#pragma clang diagnostic pop

#endif /* OCCTBridge_h */
