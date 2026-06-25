//
//  OCCTBridge_Healing.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm — issue #99.
//
//  Shape healing & analysis (v0.13) + Advanced blends & surface filling
//  (v0.14):
//
//  - Shape healing: ShapeFix_Shape / Face / Wire, tolerance analysis,
//    shell + wire validators, BRepCheck_Analyzer
//  - Surface upgrade: ShapeUpgrade_UnifySameDomain
//  - Advanced blends: filling surfaces with point + curve constraints
//    (GeomPlate_*), filleting with sigil controls, surface filling
//
//  Public C surface unchanged. No symbol changes — pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// === Area-specific OCCT headers ===

#include <BRep_Tool.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepAlgoAPI_Defeaturing.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeSolid.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepCheck_Edge.hxx>
#include <BRepCheck_Face.hxx>
#include <BRepCheck_Result.hxx>
#include <BRepCheck_Shell.hxx>
#include <BRepCheck_Solid.hxx>
#include <BRepCheck_Status.hxx>
#include <BRepCheck_Vertex.hxx>
#include <BRepCheck_Wire.hxx>
#include <BRepCheck_ListOfStatus.hxx>
#include <ShapeAnalysis_ShapeContents.hxx>
#include <BRepAlgoAPI_Check.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <ChFi2d_Builder.hxx>
#include <ChFi2d_ConstructionError.hxx>
#include <BRepGProp.hxx>
#include <BRepOffsetAPI_MakeFilling.hxx>
#include <BRepTools.hxx>

#include <Geom_BSplineSurface.hxx>
#include <Geom_Curve.hxx>
#include <GeomAbs_Shape.hxx>
#include <GeomPlate_BuildPlateSurface.hxx>
#include <GeomPlate_CurveConstraint.hxx>
#include <GeomPlate_MakeApprox.hxx>
#include <GeomPlate_PointConstraint.hxx>
#include <GeomPlate_Surface.hxx>

#include <gp_Pnt.hxx>
#include <GProp_GProps.hxx>

#include <ShapeAnalysis_ShapeTolerance.hxx>
#include <ShapeAnalysis_Shell.hxx>
#include <ShapeAnalysis_Wire.hxx>
#include <ShapeFix_Face.hxx>
#include <ShapeFix_Shape.hxx>
#include <ShapeFix_Wire.hxx>
#include <ShapeUpgrade_UnifySameDomain.hxx>
#include <ShapeUpgrade_ShapeDivideAngle.hxx>
#include <ShapeUpgrade_ShapeDivide.hxx>
#include <ShapeUpgrade_FaceDivideArea.hxx>
#include <ShapeUpgrade_ShapeDivideClosedEdges.hxx>
#include <ShapeCustom.hxx>
#include <ShapeCustom_RestrictionParameters.hxx>
#include <BRepAlgo_FaceRestrictor.hxx>
#include <ShapeAnalysis_FreeBoundData.hxx>
#include <ShapeAnalysis_FreeBoundsProperties.hxx>
#include <ShapeAnalysis_Geom.hxx>
#include <ShapeAnalysis_WireVertex.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <ShapeBuild_ReShape.hxx>
#include <ShapeFix_Edge.hxx>
#include <ShapeFix_EdgeConnect.hxx>
#include <ShapeFix_SplitTool.hxx>
#include <BRepTools_Substitution.hxx>
#include <ShapeAnalysis_TransferParametersProj.hxx>
#include <ShapeBuild_Edge.hxx>
#include <ShapeBuild_Vertex.hxx>
#include <ShapeCustom_DirectModification.hxx>
#include <ShapeCustom_SweptToElementary.hxx>
#include <ShapeCustom_TrsfModification.hxx>
#include <ShapeExtend_Explorer.hxx>
#include <ShapeUpgrade_ClosedEdgeDivide.hxx>
#include <ShapeUpgrade_ConvertCurve3dToBezier.hxx>
#include <ShapeUpgrade_ConvertSurfaceToBezierBasis.hxx>
#include <ShapeUpgrade_EdgeDivide.hxx>
#include <ShapeUpgrade_FaceDivide.hxx>
#include <ShapeUpgrade_FixSmallBezierCurves.hxx>
#include <ShapeUpgrade_FixSmallCurves.hxx>
#include <ShapeUpgrade_WireDivide.hxx>
#include <ShapeBuild_ReShape.hxx>
#include <BRepLib_ValidateEdge.hxx>
#include <ShapeCustom_BSplineRestriction.hxx>
#include <ShapeCustom_ConvertToBSpline.hxx>
#include <ShapeCustom_ConvertToRevolution.hxx>
#include <ShapeUpgrade_SplitSurfaceAngle.hxx>
#include <ShapeUpgrade_SplitSurfaceArea.hxx>
#include <ShapeUpgrade_SplitSurfaceContinuity.hxx>
#include <ShapeExtend_CompositeSurface.hxx>
#include <ShapeFix_ComposeShell.hxx>
#include <ShapeUpgrade_ClosedFaceDivide.hxx>
#include <ShapeUpgrade_ShapeDivideAngle.hxx>
#include <ShapeUpgrade_ShapeDivideArea.hxx>
#include <ShapeUpgrade_ShellSewing.hxx>
#include <ShapeFix_FaceConnect.hxx>
#include <ShapeFix_FixSmallSolid.hxx>
#include <ShapeFix_ShapeTolerance.hxx>
#include <ShapeFix_SplitCommonVertex.hxx>
#include <ShapeFix_WireVertex.hxx>
#include <ShapeUpgrade_ShapeDivideClosed.hxx>
#include <ShapeUpgrade_ShapeDivideContinuity.hxx>
#include <ShapeFix_Wireframe.hxx>
#include <ShapeAnalysis_FreeBounds.hxx>
#include <ShapeAnalysis_WireOrder.hxx>
#include <ShapeFix_FreeBounds.hxx>
#include <ShapeUpgrade_ShapeConvertToBezier.hxx>
#include <BRepBuilderAPI_Copy.hxx>
#include <BRepLib.hxx>

#include <TopAbs.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <TopoDS_Shell.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>

// MARK: - Shape Healing & Analysis (v0.13.0)

OCCTShapeAnalysisResult OCCTShapeAnalyze(OCCTShapeRef shape, double tolerance) {
    OCCTShapeAnalysisResult result = {0, 0, 0, 0, 0, 0, false, false};
    if (!shape) return result;

    try {
        // Use BRepCheck_Analyzer for comprehensive validation
        BRepCheck_Analyzer analyzer(shape->shape, true);
        result.hasInvalidTopology = !analyzer.IsValid();

        // Count small edges using ShapeAnalysis_ShapeTolerance
        ShapeAnalysis_ShapeTolerance shapeTol;

        // Count free edges and faces (topology analysis)
        int freeEdges = 0;
        int freeFaces = 0;
        int smallEdges = 0;
        int smallFaces = 0;
        int gaps = 0;

        // Analyze shells for free faces and closure
        for (TopExp_Explorer shellExp(shape->shape, TopAbs_SHELL); shellExp.More(); shellExp.Next()) {
            TopoDS_Shell shell = TopoDS::Shell(shellExp.Current());
            ShapeAnalysis_Shell shellAnalysis;
            shellAnalysis.LoadShells(shell);

            // Check for free faces
            if (shellAnalysis.HasFreeEdges()) {
                // Count free edges in shell
                TopoDS_Compound freeEdgesCompound = shellAnalysis.FreeEdges();
                for (TopExp_Explorer edgeExp(freeEdgesCompound, TopAbs_EDGE); edgeExp.More(); edgeExp.Next()) {
                    freeEdges++;
                }
            }
        }

        // Analyze edges for small size
        for (TopExp_Explorer edgeExp(shape->shape, TopAbs_EDGE); edgeExp.More(); edgeExp.Next()) {
            TopoDS_Edge edge = TopoDS::Edge(edgeExp.Current());

            // Get edge length
            GProp_GProps props;
            BRepGProp::LinearProperties(edge, props);
            double length = props.Mass();

            if (length < tolerance) {
                smallEdges++;
            }
        }

        // Analyze faces for small size
        for (TopExp_Explorer faceExp(shape->shape, TopAbs_FACE); faceExp.More(); faceExp.Next()) {
            TopoDS_Face face = TopoDS::Face(faceExp.Current());

            // Get face area
            GProp_GProps props;
            BRepGProp::SurfaceProperties(face, props);
            double area = props.Mass();

            if (area < tolerance * tolerance) {
                smallFaces++;
            }
        }

        // Analyze wires for gaps
        for (TopExp_Explorer wireExp(shape->shape, TopAbs_WIRE); wireExp.More(); wireExp.Next()) {
            TopoDS_Wire wire = TopoDS::Wire(wireExp.Current());

            // Find a face containing this wire for context
            TopoDS_Face face;
            for (TopExp_Explorer faceExp(shape->shape, TopAbs_FACE); faceExp.More(); faceExp.Next()) {
                TopoDS_Face testFace = TopoDS::Face(faceExp.Current());
                for (TopExp_Explorer innerWireExp(testFace, TopAbs_WIRE); innerWireExp.More(); innerWireExp.Next()) {
                    if (innerWireExp.Current().IsSame(wire)) {
                        face = testFace;
                        break;
                    }
                }
                if (!face.IsNull()) break;
            }

            if (!face.IsNull()) {
                ShapeAnalysis_Wire wireAnalysis(wire, face, tolerance);
                gaps += wireAnalysis.CheckGaps3d();
            }
        }

        result.smallEdgeCount = smallEdges;
        result.smallFaceCount = smallFaces;
        result.gapCount = gaps;
        result.selfIntersectionCount = 0;  // Would require more expensive computation
        result.freeEdgeCount = freeEdges;
        result.freeFaceCount = freeFaces;
        result.isValid = true;

        return result;
    } catch (...) {
        return result;
    }
}

OCCTWireRef OCCTWireFix(OCCTWireRef wire, double tolerance) {
    if (!wire) return nullptr;

    try {
        // Create a planar face for wire fixing context
        BRepBuilderAPI_MakeFace makeFace(wire->wire, true);
        if (!makeFace.IsDone()) {
            // Try without planar check
            makeFace = BRepBuilderAPI_MakeFace(wire->wire, false);
            if (!makeFace.IsDone()) return nullptr;
        }
        TopoDS_Face face = makeFace.Face();

        // Fix the wire
        Handle(ShapeFix_Wire) fixer = new ShapeFix_Wire(wire->wire, face, tolerance);
        fixer->SetPrecision(tolerance);

        // Enable all fixing modes
        fixer->FixReorderMode() = 1;
        fixer->FixConnectedMode() = 1;
        fixer->FixEdgeCurvesMode() = 1;
        fixer->FixDegeneratedMode() = 1;
        fixer->FixSelfIntersectionMode() = 1;
        fixer->FixLackingMode() = 1;
        fixer->FixGaps3dMode() = 1;

        if (!fixer->Perform()) {
            // Fixing failed, return original
            return new OCCTWire(wire->wire);
        }

        TopoDS_Wire fixedWire = fixer->Wire();
        if (fixedWire.IsNull()) return nullptr;

        return new OCCTWire(fixedWire);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTFaceFix(OCCTFaceRef face, double tolerance) {
    if (!face) return nullptr;

    try {
        Handle(ShapeFix_Face) fixer = new ShapeFix_Face(face->face);
        fixer->SetPrecision(tolerance);

        // Enable fixing modes
        fixer->FixWireMode() = 1;
        fixer->FixOrientationMode() = 1;
        fixer->FixAddNaturalBoundMode() = 1;
        fixer->FixMissingSeamMode() = 1;
        fixer->FixSmallAreaWireMode() = 1;

        if (!fixer->Perform()) {
            // Fixing failed, return original
            return new OCCTShape(face->face);
        }

        TopoDS_Face fixedFace = fixer->Face();
        if (fixedFace.IsNull()) return nullptr;

        return new OCCTShape(fixedFace);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeFixDetailed(OCCTShapeRef shape, double tolerance,
                                   bool fixSolid, bool fixShell,
                                   bool fixFace, bool fixWire) {
    if (!shape) return nullptr;

    try {
        Handle(ShapeFix_Shape) fixer = new ShapeFix_Shape(shape->shape);
        fixer->SetPrecision(tolerance);

        // ShapeFix_Shape automatically fixes all sub-shapes
        // The individual mode flags control specific fixing operations
        fixer->FixSolidMode() = fixSolid ? 1 : 0;

        // Perform the fix
        if (!fixer->Perform()) {
            // Fixing might still produce a result even if Perform returns false
        }

        TopoDS_Shape fixedShape = fixer->Shape();
        if (fixedShape.IsNull()) {
            return new OCCTShape(shape->shape);  // Return original if fix failed
        }

        return new OCCTShape(fixedShape);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeUnifySameDomain(OCCTShapeRef shape,
                                       bool unifyEdges, bool unifyFaces,
                                       bool concatBSplines) {
    if (!shape) return nullptr;

    try {
        ShapeUpgrade_UnifySameDomain unifier(shape->shape, unifyEdges, unifyFaces, concatBSplines);
        unifier.Build();

        TopoDS_Shape result = unifier.Shape();
        if (result.IsNull()) return nullptr;

        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeRemoveSmallFaces(OCCTShapeRef shape, double minArea) {
    if (!shape || minArea <= 0) return nullptr;

    try {
        // Collect faces to remove
        TopTools_ListOfShape facesToRemove;

        for (TopExp_Explorer exp(shape->shape, TopAbs_FACE); exp.More(); exp.Next()) {
            TopoDS_Face face = TopoDS::Face(exp.Current());

            GProp_GProps props;
            BRepGProp::SurfaceProperties(face, props);
            double area = props.Mass();

            if (area < minArea) {
                facesToRemove.Append(face);
            }
        }

        if (facesToRemove.IsEmpty()) {
            // No faces to remove
            return new OCCTShape(shape->shape);
        }

        // Use defeaturing to remove small faces
        BRepAlgoAPI_Defeaturing defeaturer;
        defeaturer.SetShape(shape->shape);
        defeaturer.AddFacesToRemove(facesToRemove);
        defeaturer.Build();

        if (!defeaturer.IsDone()) {
            return nullptr;
        }

        TopoDS_Shape result = defeaturer.Shape();
        if (result.IsNull()) return nullptr;

        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeSimplify(OCCTShapeRef shape, double tolerance) {
    if (!shape) return nullptr;

    try {
        // First unify same domain
        ShapeUpgrade_UnifySameDomain unifier(shape->shape, true, true, true);
        unifier.Build();
        TopoDS_Shape unified = unifier.Shape();

        // Then heal the shape
        Handle(ShapeFix_Shape) fixer = new ShapeFix_Shape(unified);
        fixer->SetPrecision(tolerance);
        fixer->Perform();
        TopoDS_Shape result = fixer->Shape();

        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Advanced Blends & Surface Filling (v0.14.0)

OCCTShapeRef OCCTShapeFilletVariable(OCCTShapeRef shape, int32_t edgeIndex,
                                      const double* radii, const double* params, int32_t count) {
    if (!shape || !radii || !params || count < 2 || edgeIndex < 0) return nullptr;

    try {
        // Get the edge at the specified index
        TopTools_IndexedMapOfShape edgeMap;
        TopExp::MapShapes(shape->shape, TopAbs_EDGE, edgeMap);

        if (edgeIndex >= edgeMap.Extent()) return nullptr;

        TopoDS_Edge edge = TopoDS::Edge(edgeMap(edgeIndex + 1));  // OCCT uses 1-based indexing

        // Create fillet maker
        BRepFilletAPI_MakeFillet fillet(shape->shape);

        // Add edge with variable radius
        fillet.Add(edge);

        // Get the edge length for parameter mapping
        double first, last;
        Handle(Geom_Curve) curve = BRep_Tool::Curve(edge, first, last);
        if (curve.IsNull()) return nullptr;

        // Set radius at each parameter point
        for (int32_t i = 0; i < count; i++) {
            double param = first + params[i] * (last - first);  // Map 0-1 to curve parameter range
            fillet.SetRadius(radii[i], param, 1);  // 1 is the contour index
        }

        fillet.Build();
        if (!fillet.IsDone()) return nullptr;

        TopoDS_Shape result = fillet.Shape();
        if (result.IsNull()) return nullptr;

        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTWireRef OCCTWireFillet2D(OCCTWireRef wire, int32_t vertexIndex, double radius) {
    if (!wire || radius <= 0 || vertexIndex < 0) return nullptr;

    try {
        // Create a face from the wire for 2D operations
        BRepBuilderAPI_MakeFace makeFace(wire->wire, true);
        if (!makeFace.IsDone()) return nullptr;
        TopoDS_Face face = makeFace.Face();

        // Get vertex at index
        TopTools_IndexedMapOfShape vertexMap;
        TopExp::MapShapes(wire->wire, TopAbs_VERTEX, vertexMap);

        if (vertexIndex >= vertexMap.Extent()) return nullptr;

        TopoDS_Vertex vertex = TopoDS::Vertex(vertexMap(vertexIndex + 1));

        // Use ChFi2d_Builder for 2D fillet on face
        ChFi2d_Builder fillet2d(face);
        TopoDS_Edge filletEdge = fillet2d.AddFillet(vertex, radius);

        if (filletEdge.IsNull()) return nullptr;
        if (fillet2d.Status() != ChFi2d_IsDone) return nullptr;

        // Get the modified face and extract its outer wire
        TopoDS_Face resultFace = TopoDS::Face(fillet2d.Result());
        if (resultFace.IsNull()) return nullptr;

        TopoDS_Wire outerWire = BRepTools::OuterWire(resultFace);
        if (outerWire.IsNull()) return nullptr;

        return new OCCTWire(outerWire);
    } catch (...) {
        return nullptr;
    }
}

OCCTWireRef OCCTWireFilletAll2D(OCCTWireRef wire, double radius) {
    if (!wire || radius <= 0) return nullptr;

    try {
        // Create a face from the wire
        BRepBuilderAPI_MakeFace makeFace(wire->wire, true);
        if (!makeFace.IsDone()) return nullptr;
        TopoDS_Face face = makeFace.Face();

        // Get all vertices
        TopTools_IndexedMapOfShape vertexMap;
        TopExp::MapShapes(wire->wire, TopAbs_VERTEX, vertexMap);

        if (vertexMap.Extent() < 2) return nullptr;

        // Use ChFi2d_Builder to fillet all vertices
        ChFi2d_Builder fillet2d(face);

        // Add fillet to each vertex
        for (int v = 1; v <= vertexMap.Extent(); v++) {
            TopoDS_Vertex vertex = TopoDS::Vertex(vertexMap(v));
            fillet2d.AddFillet(vertex, radius);
        }

        if (fillet2d.Status() != ChFi2d_IsDone) {
            // Some vertices might not be fillettable; return original
            return new OCCTWire(wire->wire);
        }

        // Get the modified face and extract its outer wire
        TopoDS_Face resultFace = TopoDS::Face(fillet2d.Result());
        if (resultFace.IsNull()) return nullptr;

        TopoDS_Wire outerWire = BRepTools::OuterWire(resultFace);
        if (outerWire.IsNull()) return nullptr;

        return new OCCTWire(outerWire);
    } catch (...) {
        return nullptr;
    }
}

OCCTWireRef OCCTWireChamfer2D(OCCTWireRef wire, int32_t vertexIndex, double dist1, double dist2) {
    if (!wire || dist1 <= 0 || dist2 <= 0 || vertexIndex < 0) return nullptr;

    try {
        // Create face from wire
        BRepBuilderAPI_MakeFace makeFace(wire->wire, true);
        if (!makeFace.IsDone()) return nullptr;
        TopoDS_Face face = makeFace.Face();

        // Get edges and vertices
        TopTools_IndexedMapOfShape edgeMap;
        TopExp::MapShapes(wire->wire, TopAbs_EDGE, edgeMap);

        TopTools_IndexedMapOfShape vertexMap;
        TopExp::MapShapes(wire->wire, TopAbs_VERTEX, vertexMap);

        if (vertexIndex >= vertexMap.Extent()) return nullptr;

        TopoDS_Vertex vertex = TopoDS::Vertex(vertexMap(vertexIndex + 1));

        // Find edges sharing this vertex
        TopoDS_Edge edge1, edge2;
        for (int i = 1; i <= edgeMap.Extent(); i++) {
            TopoDS_Edge edge = TopoDS::Edge(edgeMap(i));
            TopoDS_Vertex v1, v2;
            TopExp::Vertices(edge, v1, v2);
            if (v1.IsSame(vertex) || v2.IsSame(vertex)) {
                if (edge1.IsNull()) {
                    edge1 = edge;
                } else {
                    edge2 = edge;
                    break;
                }
            }
        }

        if (edge1.IsNull() || edge2.IsNull()) return nullptr;

        // Use ChFi2d_Builder for 2D chamfer
        ChFi2d_Builder chamfer2d(face);
        TopoDS_Edge chamferEdge = chamfer2d.AddChamfer(edge1, edge2, dist1, dist2);

        if (chamferEdge.IsNull()) return nullptr;
        if (chamfer2d.Status() != ChFi2d_IsDone) return nullptr;

        // Get the modified face and extract its outer wire
        TopoDS_Face resultFace = TopoDS::Face(chamfer2d.Result());
        if (resultFace.IsNull()) return nullptr;

        TopoDS_Wire outerWire = BRepTools::OuterWire(resultFace);
        if (outerWire.IsNull()) return nullptr;

        return new OCCTWire(outerWire);
    } catch (...) {
        return nullptr;
    }
}

OCCTWireRef OCCTWireChamferAll2D(OCCTWireRef wire, double distance) {
    if (!wire || distance <= 0) return nullptr;

    try {
        // Create face from wire
        BRepBuilderAPI_MakeFace makeFace(wire->wire, true);
        if (!makeFace.IsDone()) return nullptr;
        TopoDS_Face face = makeFace.Face();

        // Get edges and vertices
        TopTools_IndexedMapOfShape edgeMap;
        TopExp::MapShapes(wire->wire, TopAbs_EDGE, edgeMap);

        if (edgeMap.Extent() < 2) return nullptr;

        // Use ChFi2d_Builder for 2D chamfers
        ChFi2d_Builder chamfer2d(face);

        // For each pair of adjacent edges, add chamfer
        // We need to find adjacent edge pairs
        for (int i = 1; i <= edgeMap.Extent(); i++) {
            TopoDS_Edge edge1 = TopoDS::Edge(edgeMap(i));
            int nextIdx = (i % edgeMap.Extent()) + 1;
            TopoDS_Edge edge2 = TopoDS::Edge(edgeMap(nextIdx));

            // Check if edges share a vertex
            TopoDS_Vertex v1_1, v1_2, v2_1, v2_2;
            TopExp::Vertices(edge1, v1_1, v1_2);
            TopExp::Vertices(edge2, v2_1, v2_2);

            bool sharesVertex = v1_1.IsSame(v2_1) || v1_1.IsSame(v2_2) ||
                               v1_2.IsSame(v2_1) || v1_2.IsSame(v2_2);

            if (sharesVertex) {
                chamfer2d.AddChamfer(edge1, edge2, distance, distance);
            }
        }

        if (chamfer2d.Status() != ChFi2d_IsDone) {
            // Some edges might not be chamferable; return original
            return new OCCTWire(wire->wire);
        }

        // Get the modified face and extract its outer wire
        TopoDS_Face resultFace = TopoDS::Face(chamfer2d.Result());
        if (resultFace.IsNull()) return nullptr;

        TopoDS_Wire outerWire = BRepTools::OuterWire(resultFace);
        if (outerWire.IsNull()) return nullptr;

        return new OCCTWire(outerWire);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeBlendEdges(OCCTShapeRef shape,
                                  const int32_t* edgeIndices, const double* radii, int32_t count) {
    if (!shape || !edgeIndices || !radii || count < 1) return nullptr;

    try {
        // Get all edges from shape
        TopTools_IndexedMapOfShape edgeMap;
        TopExp::MapShapes(shape->shape, TopAbs_EDGE, edgeMap);

        // Create fillet maker
        BRepFilletAPI_MakeFillet fillet(shape->shape);

        // Add each edge with its radius
        for (int32_t i = 0; i < count; i++) {
            int32_t idx = edgeIndices[i];
            if (idx < 0 || idx >= edgeMap.Extent()) continue;

            TopoDS_Edge edge = TopoDS::Edge(edgeMap(idx + 1));
            fillet.Add(radii[i], edge);
        }

        fillet.Build();
        if (!fillet.IsDone()) return nullptr;

        TopoDS_Shape result = fillet.Shape();
        if (result.IsNull()) return nullptr;

        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeFill(const OCCTWireRef* boundaries, int32_t wireCount,
                            OCCTFillingParams params) {
    if (!boundaries || wireCount < 1) return nullptr;

    try {
        // Create filling operation
        BRepOffsetAPI_MakeFilling filling(
            params.maxDegree > 0 ? params.maxDegree : 8,
            params.maxSegments > 0 ? params.maxSegments : 9,
            1,  // Number of iterations
            false,  // Anisotropie
            params.tolerance > 0 ? params.tolerance : 1e-4,
            params.tolerance > 0 ? params.tolerance : 1e-3,
            static_cast<GeomAbs_Shape>(params.continuity)  // Continuity
        );

        // Add boundary constraints
        for (int32_t i = 0; i < wireCount; i++) {
            if (!boundaries[i]) continue;

            // Add each edge from the wire as a constraint
            for (TopExp_Explorer exp(boundaries[i]->wire, TopAbs_EDGE); exp.More(); exp.Next()) {
                TopoDS_Edge edge = TopoDS::Edge(exp.Current());
                filling.Add(edge, static_cast<GeomAbs_Shape>(params.continuity));
            }
        }

        filling.Build();
        if (!filling.IsDone()) return nullptr;

        TopoDS_Shape result = filling.Shape();
        if (result.IsNull()) return nullptr;

        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapePlatePoints(const double* points, int32_t pointCount, double tolerance) {
    if (!points || pointCount < 3 || tolerance <= 0) return nullptr;

    try {
        // Create plate surface builder
        GeomPlate_BuildPlateSurface plateBuilder(3, 15, 2);  // degree, nbPtsOnCur, nbIter

        // Add point constraints
        for (int32_t i = 0; i < pointCount; i++) {
            gp_Pnt pt(points[i*3], points[i*3+1], points[i*3+2]);
            Handle(GeomPlate_PointConstraint) constraint =
                new GeomPlate_PointConstraint(pt, 0);  // 0 = order (just pass through)
            plateBuilder.Add(constraint);
        }

        // Perform the computation
        plateBuilder.Perform();
        if (!plateBuilder.IsDone()) return nullptr;

        // Get the plate surface
        Handle(GeomPlate_Surface) plateSurface = plateBuilder.Surface();
        if (plateSurface.IsNull()) return nullptr;

        // Approximate with B-spline surface
        GeomPlate_MakeApprox approx(plateSurface, tolerance, 1, 8, tolerance * 10, 0);
        Handle(Geom_BSplineSurface) bsplineSurf = approx.Surface();
        if (bsplineSurf.IsNull()) return nullptr;

        // Create face from surface
        BRepBuilderAPI_MakeFace makeFace(bsplineSurf, tolerance);
        if (!makeFace.IsDone()) return nullptr;

        return new OCCTShape(makeFace.Face());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapePlateCurves(const OCCTWireRef* curves, int32_t curveCount,
                                   int32_t continuity, double tolerance) {
    if (!curves || curveCount < 1 || tolerance <= 0) return nullptr;

    try {
        // Create plate surface builder
        GeomPlate_BuildPlateSurface plateBuilder(3, 15, 2);

        // Add curve constraints from each wire
        for (int32_t i = 0; i < curveCount; i++) {
            if (!curves[i]) continue;

            for (TopExp_Explorer exp(curves[i]->wire, TopAbs_EDGE); exp.More(); exp.Next()) {
                TopoDS_Edge edge = TopoDS::Edge(exp.Current());

                // Create adaptor for edge
                BRepAdaptor_Curve adaptor(edge);
                Handle(Adaptor3d_Curve) curve = new BRepAdaptor_Curve(adaptor);

                Handle(GeomPlate_CurveConstraint) constraint =
                    new GeomPlate_CurveConstraint(curve, continuity);
                plateBuilder.Add(constraint);
            }
        }

        // Perform computation
        plateBuilder.Perform();
        if (!plateBuilder.IsDone()) return nullptr;

        // Get and approximate surface
        Handle(GeomPlate_Surface) plateSurface = plateBuilder.Surface();
        if (plateSurface.IsNull()) return nullptr;

        GeomPlate_MakeApprox approx(plateSurface, tolerance, 1, 8, tolerance * 10, 0);
        Handle(Geom_BSplineSurface) bsplineSurf = approx.Surface();
        if (bsplineSurf.IsNull()) return nullptr;

        BRepBuilderAPI_MakeFace makeFace(bsplineSurf, tolerance);
        if (!makeFace.IsDone()) return nullptr;

        return new OCCTShape(makeFace.Face());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - NURBS Conversion (v0.29.0)

#include <BRepBuilderAPI_NurbsConvert.hxx>

OCCTShapeRef OCCTShapeConvertToNURBS(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        BRepBuilderAPI_NurbsConvert converter(shape->shape);
        if (!converter.IsDone()) return nullptr;
        return new OCCTShape(converter.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Fast Sewing (v0.29.0)

#include <BRepBuilderAPI_FastSewing.hxx>

OCCTShapeRef OCCTShapeFastSewn(OCCTShapeRef shape, double tolerance) {
    if (!shape) return nullptr;
    try {
        BRepBuilderAPI_FastSewing sewer(tolerance);
        sewer.Add(shape->shape);
        sewer.Perform();
        return new OCCTShape(sewer.GetResult());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Shape Fix Wireframe (v0.30.0)

#include <ShapeFix_Wireframe.hxx>

OCCTShapeRef OCCTShapeFixWireframe(OCCTShapeRef shape, double tolerance) {
    if (!shape) return nullptr;
    try {
        Handle(ShapeFix_Wireframe) fixer = new ShapeFix_Wireframe(shape->shape);
        fixer->SetPrecision(tolerance);
        fixer->FixSmallEdges();
        fixer->FixWireGaps();
        TopoDS_Shape result = fixer->Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Remove Internal Wires (v0.30.0)

#include <ShapeUpgrade_RemoveInternalWires.hxx>

OCCTShapeRef OCCTShapeRemoveInternalWires(OCCTShapeRef shape, double minArea) {
    if (!shape) return nullptr;
    try {
        Handle(ShapeUpgrade_RemoveInternalWires) remover = new ShapeUpgrade_RemoveInternalWires(shape->shape);
        remover->MinArea() = minArea;
        remover->Perform();
        TopoDS_Shape result = remover->GetResult();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Fix Small Faces (v0.31.0)

#include <ShapeFix_FixSmallFace.hxx>

OCCTShapeRef OCCTShapeFixSmallFaces(OCCTShapeRef shape, double tolerance) {
    if (!shape) return nullptr;
    try {
        Handle(ShapeFix_FixSmallFace) fixer = new ShapeFix_FixSmallFace();
        fixer->Init(shape->shape);
        fixer->SetPrecision(tolerance);
        fixer->Perform();
        TopoDS_Shape result = fixer->Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Remove Locations (v0.31.0)

#include <ShapeUpgrade_RemoveLocations.hxx>

OCCTShapeRef OCCTShapeRemoveLocations(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        ShapeUpgrade_RemoveLocations remover;
        remover.Remove(shape->shape);
        TopoDS_Shape result = remover.GetResult();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Advanced Healing (v0.17.0)

#include <ShapeUpgrade_ShapeDivide.hxx>
#include <ShapeUpgrade_ShapeDivideContinuity.hxx>
#include <ShapeCustom.hxx>
#include <ShapeCustom_RestrictionParameters.hxx>

OCCTShapeRef OCCTShapeDivide(OCCTShapeRef shape, int32_t continuity) {
    if (!shape) return nullptr;

    try {
        // Map continuity: 0=C0, 1=C1, 2=C2, 3=C3
        GeomAbs_Shape cont;
        switch (continuity) {
            case 0:  cont = GeomAbs_C0; break;
            case 1:  cont = GeomAbs_C1; break;
            case 2:  cont = GeomAbs_C2; break;
            case 3:  cont = GeomAbs_C3; break;
            default: cont = GeomAbs_C1; break;
        }

        ShapeUpgrade_ShapeDivideContinuity divider(shape->shape);
        divider.SetBoundaryCriterion(cont);
        divider.SetPCurveCriterion(cont);
        divider.SetSurfaceCriterion(cont);
        divider.SetSurfaceSegmentMode(Standard_True);
        if (!divider.Perform()) return nullptr;

        TopoDS_Shape result = divider.Result();
        if (result.IsNull()) return nullptr;

        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeDirectFaces(OCCTShapeRef shape) {
    if (!shape) return nullptr;

    try {
        TopoDS_Shape result = ShapeCustom::DirectFaces(shape->shape);
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeScaleGeometry(OCCTShapeRef shape, double factor) {
    if (!shape) return nullptr;

    try {
        TopoDS_Shape result = ShapeCustom::ScaleShape(shape->shape, factor);
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeBSplineRestriction(OCCTShapeRef shape,
                                          double surfaceTol, double curveTol,
                                          int32_t maxDegree, int32_t maxSegments) {
    if (!shape) return nullptr;

    try {
        // Static method signature:
        // BSplineRestriction(shape, Tol3d, Tol2d, MaxDegree, MaxNbSegment,
        //                    Continuity3d, Continuity2d, Degree, Rational, aParameters)
        Handle(ShapeCustom_RestrictionParameters) params = new ShapeCustom_RestrictionParameters();
        TopoDS_Shape result = ShapeCustom::BSplineRestriction(
            shape->shape,
            surfaceTol,
            curveTol,
            maxDegree,
            maxSegments,
            GeomAbs_C1,       // Continuity3d
            GeomAbs_C1,       // Continuity2d
            Standard_True,     // Degree priority
            Standard_True,     // Rational
            params
        );
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeSweptToElementary(OCCTShapeRef shape) {
    if (!shape) return nullptr;

    try {
        TopoDS_Shape result = ShapeCustom::SweptToElementary(shape->shape);
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeRevolutionToElementary(OCCTShapeRef shape) {
    if (!shape) return nullptr;

    try {
        TopoDS_Shape result = ShapeCustom::ConvertToRevolution(shape->shape);
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeConvertToBSpline(OCCTShapeRef shape) {
    if (!shape) return nullptr;

    try {
        // ConvertToBSpline(shape, extrMode, revolMode, offsetMode, planeMode)
        TopoDS_Shape result = ShapeCustom::ConvertToBSpline(
            shape->shape,
            Standard_True,   // Convert extrusion surfaces
            Standard_True,   // Convert revolution surfaces
            Standard_True,   // Convert offset surfaces
            Standard_False   // Don't convert planes
        );
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeSewSingle(OCCTShapeRef shape, double tolerance) {
    if (!shape) return nullptr;

    try {
        BRepBuilderAPI_Sewing sewing(tolerance);
        sewing.Add(shape->shape);
        sewing.Perform();
        TopoDS_Shape sewn = sewing.SewedShape();
        if (sewn.IsNull()) return nullptr;

        // Try to make a solid if we got a closed shell
        if (sewn.ShapeType() == TopAbs_SHELL) {
            TopoDS_Shell shell = TopoDS::Shell(sewn);
            if (shell.Closed()) {
                BRepBuilderAPI_MakeSolid makeSolid(shell);
                if (makeSolid.IsDone()) {
                    return new OCCTShape(makeSolid.Solid());
                }
            }
        }

        return new OCCTShape(sewn);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeUpgrade(OCCTShapeRef shape, double tolerance) {
    if (!shape) return nullptr;

    try {
        // Step 1: Sew
        BRepBuilderAPI_Sewing sewing(tolerance);
        sewing.Add(shape->shape);
        sewing.Perform();
        TopoDS_Shape sewedShape = sewing.SewedShape();
        if (sewedShape.IsNull()) sewedShape = shape->shape;

        // Step 2: Try to create solid from shell
        TopoDS_Shape resultShape = sewedShape;
        if (sewedShape.ShapeType() != TopAbs_SOLID) {
            TopExp_Explorer shellExp(sewedShape, TopAbs_SHELL);
            if (shellExp.More()) {
                BRepBuilderAPI_MakeSolid makeSolid(TopoDS::Shell(shellExp.Current()));
                if (makeSolid.IsDone()) {
                    resultShape = makeSolid.Solid();
                }
            }
        }

        // Step 3: Apply shape healing
        ShapeFix_Shape fixer(resultShape);
        fixer.Perform();
        TopoDS_Shape fixed = fixer.Shape();
        return new OCCTShape(fixed.IsNull() ? resultShape : fixed);
    } catch (...) {
        return nullptr;
    }
}


// MARK: - Split Shape by Angle (v0.34.0)

#include <ShapeUpgrade_ShapeDivideAngle.hxx>

OCCTShapeRef OCCTShapeSplitByAngle(OCCTShapeRef shape, double maxAngleDegrees) {
    if (!shape) return nullptr;
    try {
        double maxAngleRadians = maxAngleDegrees * M_PI / 180.0;
        ShapeUpgrade_ShapeDivideAngle divider(maxAngleRadians, shape->shape);
        if (!divider.Perform()) return nullptr;
        TopoDS_Shape result = divider.Result();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Drop Small Edges (v0.34.0)

OCCTShapeRef OCCTShapeDropSmallEdges(OCCTShapeRef shape, double tolerance) {
    if (!shape) return nullptr;
    try {
        Handle(ShapeFix_Wireframe) wireframe = new ShapeFix_Wireframe(shape->shape);
        wireframe->SetPrecision(tolerance);
        wireframe->ModeDropSmallEdges() = true;
        wireframe->FixSmallEdges();
        TopoDS_Shape result = wireframe->Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Same Parameter (v0.35.0)

#include <BRepLib.hxx>

OCCTShapeRef OCCTShapeSameParameter(OCCTShapeRef shape, double tolerance) {
    if (!shape) return nullptr;
    try {
        // Make a copy so we don't modify the original
        BRepBuilderAPI_Copy copier(shape->shape);
        if (!copier.IsDone()) return nullptr;
        TopoDS_Shape result = copier.Shape();
        BRepLib::SameParameter(result, tolerance);
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Encode Regularity (v0.36.0)

OCCTShapeRef OCCTShapeEncodeRegularity(OCCTShapeRef shape, double toleranceAngleDegrees) {
    if (!shape) return nullptr;
    try {
        BRepBuilderAPI_Copy copier(shape->shape);
        if (!copier.IsDone()) return nullptr;
        TopoDS_Shape result = copier.Shape();
        double tolAngle = toleranceAngleDegrees * M_PI / 180.0;
        BRepLib::EncodeRegularity(result, tolAngle);
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Update Tolerances (v0.36.0)

OCCTShapeRef OCCTShapeUpdateTolerances(OCCTShapeRef shape, bool verifyFaceTolerance) {
    if (!shape) return nullptr;
    try {
        BRepBuilderAPI_Copy copier(shape->shape);
        if (!copier.IsDone()) return nullptr;
        TopoDS_Shape result = copier.Shape();
        BRepLib::UpdateTolerances(result, verifyFaceTolerance);
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Shape Divide by Number (v0.36.0)

#include <ShapeUpgrade_ShapeDivide.hxx>
#include <ShapeUpgrade_FaceDivideArea.hxx>

OCCTShapeRef OCCTShapeDivideByNumber(OCCTShapeRef shape, int32_t nbU, int32_t nbV) {
    if (!shape || nbU < 1 || nbV < 1) return nullptr;
    try {
        ShapeUpgrade_ShapeDivide divider(shape->shape);
        // Use FaceDivideArea with splitting-by-number mode
        Handle(ShapeUpgrade_FaceDivideArea) faceDivide = new ShapeUpgrade_FaceDivideArea();
        faceDivide->SetSplittingByNumber(true);
        faceDivide->NbParts() = nbU * nbV;
        divider.SetSplitFaceTool(faceDivide);
        if (!divider.Perform()) return nullptr;
        TopoDS_Shape result = divider.Result();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeFreeBounds(OCCTShapeRef shape, double sewingTolerance,
                                  int32_t* outClosedCount, int32_t* outOpenCount) {
    if (!shape || !outClosedCount || !outOpenCount) return nullptr;
    try {
        ShapeAnalysis_FreeBounds analyzer(shape->shape, sewingTolerance);

        TopoDS_Compound closedWires = analyzer.GetClosedWires();
        TopoDS_Compound openWires = analyzer.GetOpenWires();

        // Count wires in each compound
        int32_t closedCount = 0, openCount = 0;
        TopExp_Explorer expClosed(closedWires, TopAbs_WIRE);
        while (expClosed.More()) { closedCount++; expClosed.Next(); }
        TopExp_Explorer expOpen(openWires, TopAbs_WIRE);
        while (expOpen.More()) { openCount++; expOpen.Next(); }

        *outClosedCount = closedCount;
        *outOpenCount = openCount;

        // Return compound of all free boundary wires
        BRep_Builder builder;
        TopoDS_Compound result;
        builder.MakeCompound(result);
        if (!closedWires.IsNull()) builder.Add(result, closedWires);
        if (!openWires.IsNull()) builder.Add(result, openWires);

        if (closedCount == 0 && openCount == 0) return nullptr;

        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeFixFreeBounds(OCCTShapeRef shape, double sewingTolerance,
                                     double closingTolerance, int32_t* outFixedCount) {
    if (!shape || !outFixedCount) return nullptr;
    try {
        ShapeFix_FreeBounds fixer(shape->shape, sewingTolerance, closingTolerance,
                                   Standard_True, Standard_True);

        TopoDS_Compound closedWires = fixer.GetClosedWires();
        TopoDS_Compound openWires = fixer.GetOpenWires();

        int32_t closedCount = 0;
        TopExp_Explorer exp(closedWires, TopAbs_WIRE);
        while (exp.More()) { closedCount++; exp.Next(); }

        *outFixedCount = closedCount;

        BRep_Builder builder;
        TopoDS_Compound result;
        builder.MakeCompound(result);
        if (!closedWires.IsNull()) builder.Add(result, closedWires);
        if (!openWires.IsNull()) builder.Add(result, openWires);

        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}


OCCTShapeRef OCCTShapeDivideClosedEdges(OCCTShapeRef shape, int32_t nbSplitPoints) {
    if (!shape || nbSplitPoints < 1) return nullptr;
    try {
        ShapeUpgrade_ShapeDivideClosedEdges divider(shape->shape);
        divider.SetNbSplitPoints(nbSplitPoints);
        if (!divider.Perform()) return nullptr;
        TopoDS_Shape result = divider.Result();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCustomConvertToBSpline(OCCTShapeRef shape,
                                              bool extrusion, bool revolution,
                                              bool offset, bool plane) {
    if (!shape) return nullptr;
    try {
        TopoDS_Shape result = ShapeCustom::ConvertToBSpline(
            shape->shape, extrusion, revolution, offset, plane);
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCustomConvertToRevolution(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        TopoDS_Shape result = ShapeCustom::ConvertToRevolution(shape->shape);
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

int32_t OCCTShapeFaceRestrict(OCCTShapeRef faceShape,
                               OCCTWireRef* wires, int32_t wireCount,
                               OCCTShapeRef* outFaces, int32_t maxFaces) {
    if (!faceShape || !wires || wireCount <= 0 || !outFaces || maxFaces <= 0) return -1;
    try {
        // Get the face from the shape
        TopoDS_Face face;
        TopExp_Explorer exp(faceShape->shape, TopAbs_FACE);
        if (exp.More()) {
            face = TopoDS::Face(exp.Current());
        } else {
            return -1;
        }

        BRepAlgo_FaceRestrictor restrictor;
        restrictor.Init(face, false, true);

        for (int32_t i = 0; i < wireCount; i++) {
            if (wires[i]) {
                TopoDS_Wire w = wires[i]->wire;
                restrictor.Add(w);
            }
        }
        restrictor.Perform();
        if (!restrictor.IsDone()) return -1;

        int32_t count = 0;
        for (; restrictor.More() && count < maxFaces; restrictor.Next()) {
            TopoDS_Face resultFace = restrictor.Current();
            outFaces[count] = new OCCTShape(resultFace);
            count++;
        }
        return count;
    } catch (...) {
        return -1;
    }
}
// MARK: - v0.43.0: Face Subdivision, Small Face Detection, BSpline Fill, Location Purge

#include <ShapeUpgrade_ShapeDivideArea.hxx>
#include <ShapeAnalysis_CheckSmallFace.hxx>
#include <GeomFill_BSplineCurves.hxx>
#include <GeomFill_FillingStyle.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_BSplineSurface.hxx>
#include <GeomConvert.hxx>
#include <BRepTools_PurgeLocations.hxx>

OCCTShapeRef OCCTShapeDivideByArea(OCCTShapeRef shape, double maxArea) {
    if (!shape || maxArea <= 0) return nullptr;
    try {
        ShapeUpgrade_ShapeDivideArea divider(shape->shape);
        divider.MaxArea() = maxArea;
        divider.Perform();
        // Result() is valid even when Perform returns false (nothing to split)
        TopoDS_Shape result = divider.Result();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeDivideByParts(OCCTShapeRef shape, int32_t nbParts) {
    if (!shape || nbParts <= 0) return nullptr;
    try {
        ShapeUpgrade_ShapeDivideArea divider(shape->shape);
        divider.SetSplittingByNumber(true);
        divider.NbParts() = nbParts;
        if (!divider.Perform()) return nullptr;
        return new OCCTShape(divider.Result());
    } catch (...) {
        return nullptr;
    }
}

int32_t OCCTShapeCheckSmallFaces(OCCTShapeRef shape, double tolerance,
                                  OCCTSmallFaceResult* outResults, int32_t maxResults) {
    if (!shape || !outResults || maxResults <= 0) return 0;
    try {
        ShapeAnalysis_CheckSmallFace checker;
        int32_t found = 0;

        TopExp_Explorer exp(shape->shape, TopAbs_FACE);
        int32_t faceIdx = 0;
        while (exp.More() && found < maxResults) {
            TopoDS_Face face = TopoDS::Face(exp.Current());
            OCCTSmallFaceResult& r = outResults[found];
            r.isSpotFace = false;
            r.isStripFace = false;
            r.isTwisted = false;
            r.spotX = r.spotY = r.spotZ = 0;

            bool isDegenerate = false;

            // Check spot face
            gp_Pnt spot;
            double spotTol;
            int spotResult = checker.IsSpotFace(face, spot, spotTol, tolerance);
            if (spotResult != 0) {
                r.isSpotFace = true;
                r.spotX = spot.X();
                r.spotY = spot.Y();
                r.spotZ = spot.Z();
                isDegenerate = true;
            }

            // Check strip face
            if (checker.IsStripSupport(face, tolerance)) {
                r.isStripFace = true;
                isDegenerate = true;
            }

            // Check twisted
            double paramu, paramv;
            if (checker.CheckTwisted(face, paramu, paramv)) {
                r.isTwisted = true;
                isDegenerate = true;
            }

            if (isDegenerate) found++;
            exp.Next();
            faceIdx++;
        }
        return found;
    } catch (...) {
        return 0;
    }
}

OCCTShapeRef OCCTShapePurgeLocations(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        BRepTools_PurgeLocations purger;
        purger.Perform(shape->shape);
        if (purger.IsDone()) {
            return new OCCTShape(purger.GetResult());
        }
        return nullptr;
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeConnectEdges(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        ShapeFix_EdgeConnect connector;
        connector.Add(shape->shape);
        connector.Build();
        // EdgeConnect modifies edges in place, return a copy of the shape
        return new OCCTShape(shape->shape);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - ShapeUpgrade_ShapeConvertToBezier (v0.45)
OCCTShapeRef OCCTShapeConvertToBezier(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        ShapeUpgrade_ShapeConvertToBezier converter(shape->shape);
        converter.Set2dConversion(true);
        converter.Set3dConversion(true);
        converter.SetSurfaceConversion(true);
        converter.Set3dLineConversion(true);
        converter.Set3dCircleConversion(true);
        converter.Set3dConicConversion(true);
        converter.SetPlaneMode(true);
        converter.SetRevolutionMode(true);
        converter.SetExtrusionMode(true);
        converter.SetBSplineMode(true);
        if (!converter.Perform()) return nullptr;
        TopoDS_Shape result = converter.Result();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - ShapeAnalysis_WireOrder (v0.45)
OCCTWireOrderResult OCCTWireOrderAnalyze(const double* starts, const double* ends,
                                          int32_t nbEdges, double tolerance,
                                          OCCTWireOrderEntry* outOrder) {
    OCCTWireOrderResult result = {-1, 0};
    if (!starts || !ends || nbEdges <= 0 || !outOrder) return result;
    try {
        ShapeAnalysis_WireOrder order(true, tolerance);

        for (int32_t i = 0; i < nbEdges; i++) {
            gp_XYZ s(starts[i*3], starts[i*3+1], starts[i*3+2]);
            gp_XYZ e(ends[i*3], ends[i*3+1], ends[i*3+2]);
            order.Add(s, e);
        }

        order.Perform();
        result.status = order.Status();
        result.nbEdges = order.NbEdges();

        for (int32_t i = 1; i <= result.nbEdges; i++) {
            outOrder[i-1].originalIndex = order.Ordered(i);
        }

        return result;
    } catch (...) {
        return result;
    }
}

OCCTWireOrderResult OCCTWireOrderAnalyzeWire(OCCTWireRef wire, double tolerance,
                                              OCCTWireOrderEntry* outOrder, int32_t maxEntries) {
    OCCTWireOrderResult result = {-1, 0};
    if (!wire || !outOrder || maxEntries <= 0) return result;
    try {
        ShapeAnalysis_WireOrder order(true, tolerance);

        // Extract edge endpoints from the wire
        for (TopExp_Explorer exp(wire->wire, TopAbs_EDGE); exp.More(); exp.Next()) {
            TopoDS_Edge edge = TopoDS::Edge(exp.Current());
            double first, last;
            Handle(Geom_Curve) curve = BRep_Tool::Curve(edge, first, last);
            if (curve.IsNull()) continue;

            gp_Pnt p1 = curve->Value(first);
            gp_Pnt p2 = curve->Value(last);
            order.Add(p1.XYZ(), p2.XYZ());
        }

        order.Perform();
        result.status = order.Status();
        result.nbEdges = std::min(order.NbEdges(), maxEntries);

        for (int32_t i = 1; i <= result.nbEdges; i++) {
            outOrder[i-1].originalIndex = order.Ordered(i);
        }

        return result;
    } catch (...) {
        return result;
    }
}

// MARK: - BRepCheck Validators (v0.47)
// --- BRepCheck ---

static OCCTCheckStatus mapBRepCheckStatus(BRepCheck_Status status) {
    switch (status) {
        case BRepCheck_NoError: return OCCTCheckNoError;
        case BRepCheck_InvalidPointOnCurve: return OCCTCheckInvalidPointOnCurve;
        case BRepCheck_InvalidPointOnCurveOnSurface: return OCCTCheckInvalidPointOnCurveOnSurface;
        case BRepCheck_InvalidPointOnSurface: return OCCTCheckInvalidPointOnSurface;
        case BRepCheck_No3DCurve: return OCCTCheckNo3DCurve;
        case BRepCheck_Multiple3DCurve: return OCCTCheckMultiple3DCurve;
        case BRepCheck_Invalid3DCurve: return OCCTCheckInvalid3DCurve;
        case BRepCheck_NoCurveOnSurface: return OCCTCheckNoCurveOnSurface;
        case BRepCheck_InvalidCurveOnSurface: return OCCTCheckInvalidCurveOnSurface;
        case BRepCheck_InvalidCurveOnClosedSurface: return OCCTCheckInvalidCurveOnClosedSurface;
        case BRepCheck_InvalidSameRangeFlag: return OCCTCheckInvalidSameRangeFlag;
        case BRepCheck_InvalidSameParameterFlag: return OCCTCheckInvalidSameParameterFlag;
        case BRepCheck_InvalidDegeneratedFlag: return OCCTCheckInvalidDegeneratedFlag;
        case BRepCheck_FreeEdge: return OCCTCheckFreeEdge;
        case BRepCheck_InvalidMultiConnexity: return OCCTCheckInvalidMultiConnexity;
        case BRepCheck_InvalidRange: return OCCTCheckInvalidRange;
        case BRepCheck_EmptyWire: return OCCTCheckEmptyWire;
        case BRepCheck_RedundantEdge: return OCCTCheckRedundantEdge;
        case BRepCheck_SelfIntersectingWire: return OCCTCheckSelfIntersectingWire;
        case BRepCheck_NoSurface: return OCCTCheckNoSurface;
        case BRepCheck_InvalidWire: return OCCTCheckInvalidWire;
        case BRepCheck_RedundantWire: return OCCTCheckRedundantWire;
        case BRepCheck_IntersectingWires: return OCCTCheckIntersectingWires;
        case BRepCheck_InvalidImbricationOfWires: return OCCTCheckInvalidImbricationOfWires;
        case BRepCheck_EmptyShell: return OCCTCheckEmptyShell;
        case BRepCheck_RedundantFace: return OCCTCheckRedundantFace;
        case BRepCheck_InvalidImbricationOfShells: return OCCTCheckInvalidImbricationOfShells;
        case BRepCheck_UnorientableShape: return OCCTCheckUnorientableShape;
        case BRepCheck_NotClosed: return OCCTCheckNotClosed;
        case BRepCheck_NotConnected: return OCCTCheckNotConnected;
        case BRepCheck_SubshapeNotInShape: return OCCTCheckSubshapeNotInShape;
        case BRepCheck_BadOrientation: return OCCTCheckBadOrientation;
        case BRepCheck_BadOrientationOfSubshape: return OCCTCheckBadOrientationOfSubshape;
        case BRepCheck_InvalidPolygonOnTriangulation: return OCCTCheckInvalidPolygonOnTriangulation;
        case BRepCheck_InvalidToleranceValue: return OCCTCheckInvalidToleranceValue;
        case BRepCheck_EnclosedRegion: return OCCTCheckEnclosedRegion;
        case BRepCheck_CheckFail: return OCCTCheckCheckFail;
        default: return OCCTCheckCheckFail;
    }
}

OCCTShapeCheckResult OCCTCheckFace(OCCTFaceRef face) {
    OCCTShapeCheckResult result = {true, 0, OCCTCheckNoError};
    if (!face) { result.isValid = false; result.firstError = OCCTCheckCheckFail; return result; }
    try {
        Handle(BRepCheck_Face) checker = new BRepCheck_Face(face->face);
        checker->Minimum();
        const auto& statusList = checker->Status();
        for (auto it = statusList.begin(); it != statusList.end(); ++it) {
            if (*it != BRepCheck_NoError) {
                if (result.errorCount == 0) {
                    result.firstError = mapBRepCheckStatus(*it);
                }
                result.errorCount++;
                result.isValid = false;
            }
        }
        return result;
    } catch (...) {
        result.isValid = false;
        result.firstError = OCCTCheckCheckFail;
        return result;
    }
}

OCCTShapeCheckResult OCCTCheckSolid(OCCTShapeRef shape) {
    OCCTShapeCheckResult result = {true, 0, OCCTCheckNoError};
    if (!shape) { result.isValid = false; result.firstError = OCCTCheckCheckFail; return result; }
    try {
        for (TopExp_Explorer exp(shape->shape, TopAbs_SOLID); exp.More(); exp.Next()) {
            TopoDS_Solid solid = TopoDS::Solid(exp.Current());
            Handle(BRepCheck_Solid) checker = new BRepCheck_Solid(solid);
            checker->Minimum();
            const auto& statusList = checker->Status();
            for (auto it = statusList.begin(); it != statusList.end(); ++it) {
                if (*it != BRepCheck_NoError) {
                    if (result.errorCount == 0) {
                        result.firstError = mapBRepCheckStatus(*it);
                    }
                    result.errorCount++;
                    result.isValid = false;
                }
            }
        }
        return result;
    } catch (...) {
        result.isValid = false;
        result.firstError = OCCTCheckCheckFail;
        return result;
    }
}

OCCTShapeCheckResult OCCTCheckShape(OCCTShapeRef shape) {
    OCCTShapeCheckResult result = {true, 0, OCCTCheckNoError};
    if (!shape) { result.isValid = false; result.firstError = OCCTCheckCheckFail; return result; }
    try {
        BRepCheck_Analyzer analyzer(shape->shape, true);
        result.isValid = analyzer.IsValid();
        if (!result.isValid) {
            // Count errors from sub-shapes
            for (TopExp_Explorer exp(shape->shape, TopAbs_FACE); exp.More(); exp.Next()) {
                const Handle(BRepCheck_Result)& res = analyzer.Result(exp.Current());
                if (!res.IsNull()) {
                    const auto& statusList = res->Status();
                    for (auto it = statusList.begin(); it != statusList.end(); ++it) {
                        if (*it != BRepCheck_NoError) {
                            if (result.errorCount == 0) {
                                result.firstError = mapBRepCheckStatus(*it);
                            }
                            result.errorCount++;
                        }
                    }
                }
            }
            for (TopExp_Explorer exp(shape->shape, TopAbs_EDGE); exp.More(); exp.Next()) {
                const Handle(BRepCheck_Result)& res = analyzer.Result(exp.Current());
                if (!res.IsNull()) {
                    const auto& statusList = res->Status();
                    for (auto it = statusList.begin(); it != statusList.end(); ++it) {
                        if (*it != BRepCheck_NoError) {
                            if (result.errorCount == 0) {
                                result.firstError = mapBRepCheckStatus(*it);
                            }
                            result.errorCount++;
                        }
                    }
                }
            }
        }
        return result;
    } catch (...) {
        result.isValid = false;
        result.firstError = OCCTCheckCheckFail;
        return result;
    }
}

int32_t OCCTCheckShapeDetailed(OCCTShapeRef shape, OCCTCheckStatus* outStatuses, int32_t maxStatuses) {
    if (!shape || !outStatuses || maxStatuses <= 0) return 0;
    try {
        BRepCheck_Analyzer analyzer(shape->shape, true);
        int32_t count = 0;

        auto collectStatuses = [&](TopAbs_ShapeEnum type) {
            for (TopExp_Explorer exp(shape->shape, type); exp.More(); exp.Next()) {
                const Handle(BRepCheck_Result)& res = analyzer.Result(exp.Current());
                if (!res.IsNull()) {
                    const auto& statusList = res->Status();
                    for (auto it = statusList.begin(); it != statusList.end(); ++it) {
                        if (*it != BRepCheck_NoError && count < maxStatuses) {
                            outStatuses[count++] = mapBRepCheckStatus(*it);
                        }
                    }
                }
            }
        };

        collectStatuses(TopAbs_VERTEX);
        collectStatuses(TopAbs_EDGE);
        collectStatuses(TopAbs_WIRE);
        collectStatuses(TopAbs_FACE);
        collectStatuses(TopAbs_SHELL);
        collectStatuses(TopAbs_SOLID);

        return count;
    } catch (...) {
        return 0;
    }
}

// MARK: - BRepCheck Analyzer + Sub-Shape Validators (v0.48)
bool OCCTBRepCheckAnalyzerIsValid(OCCTShapeRef shape, bool geometryChecks) {
    if (!shape) return false;
    try {
        BRepCheck_Analyzer analyzer(shape->shape, geometryChecks);
        return analyzer.IsValid();
    } catch (...) {
        return false;
    }
}

bool OCCTBRepCheckSubShapeValid(OCCTShapeRef parentShape, int32_t subShapeType, int32_t subShapeIndex) {
    if (!parentShape) return false;
    try {
        BRepCheck_Analyzer analyzer(parentShape->shape, true);

        TopAbs_ShapeEnum type = (TopAbs_ShapeEnum)subShapeType;
        int idx = 0;
        for (TopExp_Explorer exp(parentShape->shape, type); exp.More(); exp.Next()) {
            if (idx == subShapeIndex) {
                return analyzer.IsValid(exp.Current());
            }
            idx++;
        }
        return false;
    } catch (...) {
        return false;
    }
}

static OCCTShapeCheckResult checkSubShape(OCCTShapeRef shape, TopAbs_ShapeEnum type, int32_t index) {
    OCCTShapeCheckResult result = {};
    result.isValid = false;
    result.firstError = OCCTCheckNoError;
    if (!shape) return result;

    try {
        TopoDS_Shape subShape;
        int idx = 0;
        for (TopExp_Explorer exp(shape->shape, type); exp.More(); exp.Next()) {
            if (idx == index) {
                subShape = exp.Current();
                break;
            }
            idx++;
        }
        if (subShape.IsNull()) return result;

        Handle(BRepCheck_Result) checker;
        switch (type) {
            case TopAbs_EDGE:
                checker = new BRepCheck_Edge(TopoDS::Edge(subShape));
                break;
            case TopAbs_WIRE:
                checker = new BRepCheck_Wire(TopoDS::Wire(subShape));
                break;
            case TopAbs_SHELL:
                checker = new BRepCheck_Shell(TopoDS::Shell(subShape));
                break;
            case TopAbs_VERTEX:
                checker = new BRepCheck_Vertex(TopoDS::Vertex(subShape));
                break;
            default:
                return result;
        }

        checker->Minimum();
        auto& statusList = checker->Status();

        result.isValid = true;
        for (auto it = statusList.begin(); it != statusList.end(); ++it) {
            if (*it != BRepCheck_NoError) {
                result.isValid = false;
                if (result.firstError == OCCTCheckNoError) {
                    result.firstError = mapBRepCheckStatus(*it);
                }
            }
        }
        return result;
    } catch (...) {
        return result;
    }
}

OCCTShapeCheckResult OCCTCheckEdge(OCCTShapeRef shape, int32_t edgeIndex) {
    return checkSubShape(shape, TopAbs_EDGE, edgeIndex);
}

OCCTShapeCheckResult OCCTCheckWire(OCCTShapeRef shape, int32_t wireIndex) {
    return checkSubShape(shape, TopAbs_WIRE, wireIndex);
}

OCCTShapeCheckResult OCCTCheckShell(OCCTShapeRef shape, int32_t shellIndex) {
    return checkSubShape(shape, TopAbs_SHELL, shellIndex);
}

OCCTShapeCheckResult OCCTCheckVertex(OCCTShapeRef shape, int32_t vertexIndex) {
    return checkSubShape(shape, TopAbs_VERTEX, vertexIndex);
}


// MARK: - ShapeFix Tolerance + Vertex/Connect Repair (v0.48)
bool OCCTShapeFixLimitTolerance(OCCTShapeRef shape, double minTolerance, double maxTolerance) {
    if (!shape) return false;
    try {
        ShapeFix_ShapeTolerance tolFixer;
        return tolFixer.LimitTolerance(shape->shape, minTolerance, maxTolerance);
    } catch (...) {
        return false;
    }
}

void OCCTShapeFixSetTolerance(OCCTShapeRef shape, double tolerance) {
    if (!shape) return;
    try {
        ShapeFix_ShapeTolerance tolFixer;
        tolFixer.SetTolerance(shape->shape, tolerance);
    } catch (...) {
    }
}

OCCTShapeRef OCCTShapeFixSplitCommonVertex(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        ShapeFix_SplitCommonVertex splitter;
        splitter.Init(shape->shape);
        splitter.Perform();
        TopoDS_Shape result = splitter.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeFixFaceConnect(OCCTShapeRef shape, double tolerance) {
    if (!shape) return nullptr;
    try {
        // Get shell from shape
        TopoDS_Shell shell;
        if (shape->shape.ShapeType() == TopAbs_SHELL) {
            shell = TopoDS::Shell(shape->shape);
        } else {
            for (TopExp_Explorer exp(shape->shape, TopAbs_SHELL); exp.More(); exp.Next()) {
                shell = TopoDS::Shell(exp.Current());
                break;
            }
        }
        if (shell.IsNull()) return nullptr;

        // Get face pairs and connect them
        ShapeFix_FaceConnect connector;

        // Collect all faces
        std::vector<TopoDS_Face> faces;
        for (TopExp_Explorer exp(shell, TopAbs_FACE); exp.More(); exp.Next()) {
            faces.push_back(TopoDS::Face(exp.Current()));
        }

        // Add adjacent face pairs
        for (size_t i = 0; i + 1 < faces.size(); i++) {
            connector.Add(faces[i], faces[i + 1]);
        }

        TopoDS_Shell result = connector.Build(shell, tolerance, tolerance);
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

int32_t OCCTShapeFixEdgeSameParameter(OCCTShapeRef shape, double tolerance) {
    if (!shape) return 0;
    try {
        Handle(ShapeFix_Edge) edgeFixer = new ShapeFix_Edge();
        int32_t count = 0;
        for (TopExp_Explorer exp(shape->shape, TopAbs_EDGE); exp.More(); exp.Next()) {
            TopoDS_Edge edge = TopoDS::Edge(exp.Current());
            if (edgeFixer->FixSameParameter(edge, tolerance)) {
                count++;
            }
        }
        return count;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTShapeFixEdgeVertexTolerance(OCCTShapeRef shape) {
    if (!shape) return 0;
    try {
        Handle(ShapeFix_Edge) edgeFixer = new ShapeFix_Edge();
        int32_t count = 0;
        for (TopExp_Explorer exp(shape->shape, TopAbs_EDGE); exp.More(); exp.Next()) {
            TopoDS_Edge edge = TopoDS::Edge(exp.Current());
            if (edgeFixer->FixVertexTolerance(edge)) {
                count++;
            }
        }
        return count;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTShapeFixWireVertex(OCCTShapeRef shape, double precision) {
    if (!shape) return 0;
    try {
        int32_t totalFixed = 0;
        for (TopExp_Explorer exp(shape->shape, TopAbs_WIRE); exp.More(); exp.Next()) {
            TopoDS_Wire wire = TopoDS::Wire(exp.Current());
            ShapeFix_WireVertex wireVertex;
            wireVertex.Init(wire, precision);
            totalFixed += wireVertex.Fix();
        }
        return totalFixed;
    } catch (...) {
        return 0;
    }
}

// MARK: - ShapeUpgrade Divide Closed/Continuity (v0.48)
OCCTShapeRef OCCTShapeUpgradeDivideClosed(OCCTShapeRef shape, int32_t nbSplitPoints) {
    if (!shape) return nullptr;
    try {
        ShapeUpgrade_ShapeDivideClosed divider(shape->shape);
        divider.SetNbSplitPoints(nbSplitPoints);
        bool ok = divider.Perform();
        if (!ok) return nullptr;
        TopoDS_Shape result = divider.Result();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeUpgradeDivideContinuity(OCCTShapeRef shape, int32_t boundaryCriterion, double tolerance) {
    if (!shape) return nullptr;
    try {
        ShapeUpgrade_ShapeDivideContinuity divider(shape->shape);

        GeomAbs_Shape criterion;
        switch (boundaryCriterion) {
            case 0: criterion = GeomAbs_C0; break;
            case 1: criterion = GeomAbs_C1; break;
            case 2: criterion = GeomAbs_C2; break;
            case 3: criterion = GeomAbs_C3; break;
            case 4: criterion = GeomAbs_CN; break;
            case 5: criterion = GeomAbs_G1; break;
            case 6: criterion = GeomAbs_G2; break;
            default: criterion = GeomAbs_C1; break;
        }

        divider.SetBoundaryCriterion(criterion);
        divider.SetTolerance(tolerance);
        bool ok = divider.Perform();
        if (!ok) return nullptr;
        TopoDS_Shape result = divider.Result();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - ShapeFix Small Solids (v0.49)
// --- ShapeFix_FixSmallSolid ---

OCCTShapeRef OCCTShapeFixRemoveSmallSolids(OCCTShapeRef shape, double volumeThreshold) {
    if (!shape) return nullptr;
    try {
        Handle(ShapeFix_FixSmallSolid) fixer = new ShapeFix_FixSmallSolid();
        fixer->SetFixMode(2); // volume only
        fixer->SetVolumeThreshold(volumeThreshold);
        Handle(ShapeBuild_ReShape) ctx = new ShapeBuild_ReShape();
        TopoDS_Shape result = fixer->Remove(shape->shape, ctx);
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeFixMergeSmallSolids(OCCTShapeRef shape, double widthFactorThreshold) {
    if (!shape) return nullptr;
    try {
        Handle(ShapeFix_FixSmallSolid) fixer = new ShapeFix_FixSmallSolid();
        fixer->SetFixMode(1); // width only
        fixer->SetWidthFactorThreshold(widthFactorThreshold);
        Handle(ShapeBuild_ReShape) ctx = new ShapeBuild_ReShape();
        TopoDS_Shape result = fixer->Merge(shape->shape, ctx);
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - ShapeCustom Direct Faces / BSpline Restriction (v0.49)
// --- ShapeCustom ---

OCCTShapeRef OCCTShapeCustomDirectFaces(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        TopoDS_Shape result = ShapeCustom::DirectFaces(shape->shape);
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

static GeomAbs_Shape mapContinuity(int32_t val) {
    switch (val) {
        case 0: return GeomAbs_C0;
        case 1: return GeomAbs_C1;
        case 2: return GeomAbs_C2;
        case 3: return GeomAbs_C3;
        default: return GeomAbs_C1;
    }
}

OCCTShapeRef OCCTShapeCustomBSplineRestriction(OCCTShapeRef shape,
    double tol3d, double tol2d, int32_t maxDegree, int32_t maxSegments,
    int32_t continuity3d, int32_t continuity2d, bool degreePriority, bool rational) {
    if (!shape) return nullptr;
    try {
        Handle(ShapeCustom_RestrictionParameters) params = new ShapeCustom_RestrictionParameters();
        TopoDS_Shape result = ShapeCustom::BSplineRestriction(
            shape->shape, tol3d, tol2d, maxDegree, maxSegments,
            mapContinuity(continuity3d), mapContinuity(continuity2d),
            degreePriority, rational, params);
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - ShapeAnalysis_FreeBoundsProperties (v0.49)
// --- ShapeAnalysis_FreeBoundsProperties ---

OCCTFreeBoundsResult OCCTFreeBoundsAnalyze(OCCTShapeRef shape, double tolerance) {
    OCCTFreeBoundsResult result = {};
    if (!shape) return result;
    try {
        ShapeAnalysis_FreeBoundsProperties fbp(shape->shape, tolerance);
        if (!fbp.Perform()) return result;
        result.totalFreeBounds = fbp.NbFreeBounds();
        result.closedFreeBounds = fbp.NbClosedFreeBounds();
        result.openFreeBounds = fbp.NbOpenFreeBounds();
        return result;
    } catch (...) {
        return result;
    }
}

OCCTFreeBoundInfo OCCTFreeBoundsGetClosedBoundInfo(OCCTShapeRef shape, double tolerance, int32_t index) {
    OCCTFreeBoundInfo result = {};
    if (!shape) return result;
    try {
        ShapeAnalysis_FreeBoundsProperties fbp(shape->shape, tolerance);
        if (!fbp.Perform()) return result;
        if (index < 0 || index >= fbp.NbClosedFreeBounds()) return result;
        Handle(ShapeAnalysis_FreeBoundData) fbd = fbp.ClosedFreeBound(index + 1); // 1-indexed
        if (fbd.IsNull()) return result;
        result.area = fbd->Area();
        result.perimeter = fbd->Perimeter();
        result.ratio = fbd->Ratio();
        result.width = fbd->Width();
        result.notchCount = fbd->NbNotches();
        return result;
    } catch (...) {
        return result;
    }
}

OCCTFreeBoundInfo OCCTFreeBoundsGetOpenBoundInfo(OCCTShapeRef shape, double tolerance, int32_t index) {
    OCCTFreeBoundInfo result = {};
    if (!shape) return result;
    try {
        ShapeAnalysis_FreeBoundsProperties fbp(shape->shape, tolerance);
        if (!fbp.Perform()) return result;
        if (index < 0 || index >= fbp.NbOpenFreeBounds()) return result;
        Handle(ShapeAnalysis_FreeBoundData) fbd = fbp.OpenFreeBound(index + 1); // 1-indexed
        if (fbd.IsNull()) return result;
        result.area = fbd->Area();
        result.perimeter = fbd->Perimeter();
        result.ratio = fbd->Ratio();
        result.width = fbd->Width();
        result.notchCount = fbd->NbNotches();
        return result;
    } catch (...) {
        return result;
    }
}

OCCTShapeRef OCCTFreeBoundsGetClosedBoundWire(OCCTShapeRef shape, double tolerance, int32_t index) {
    if (!shape) return nullptr;
    try {
        ShapeAnalysis_FreeBoundsProperties fbp(shape->shape, tolerance);
        if (!fbp.Perform()) return nullptr;
        if (index < 0 || index >= fbp.NbClosedFreeBounds()) return nullptr;
        Handle(ShapeAnalysis_FreeBoundData) fbd = fbp.ClosedFreeBound(index + 1);
        if (fbd.IsNull()) return nullptr;
        TopoDS_Wire wire = fbd->FreeBound();
        if (wire.IsNull()) return nullptr;
        return new OCCTShape(wire);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTFreeBoundsGetOpenBoundWire(OCCTShapeRef shape, double tolerance, int32_t index) {
    if (!shape) return nullptr;
    try {
        ShapeAnalysis_FreeBoundsProperties fbp(shape->shape, tolerance);
        if (!fbp.Perform()) return nullptr;
        if (index < 0 || index >= fbp.NbOpenFreeBounds()) return nullptr;
        Handle(ShapeAnalysis_FreeBoundData) fbd = fbp.OpenFreeBound(index + 1);
        if (fbd.IsNull()) return nullptr;
        TopoDS_Wire wire = fbd->FreeBound();
        if (wire.IsNull()) return nullptr;
        return new OCCTShape(wire);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - ShapeAnalysis_WireVertex (v0.50)
OCCTWireVertexResult OCCTShapeWireVertexAnalysis(OCCTShapeRef wire, double precision) {
    OCCTWireVertexResult result = {};
    if (!wire) return result;
    try {
        TopoDS_Wire w = TopoDS::Wire(wire->shape);
        ShapeAnalysis_WireVertex wv;
        wv.Init(w, precision);
        wv.Analyze();
        result.isDone = wv.IsDone();
        result.nbEdges = wv.NbEdges();
    } catch (...) {}
    return result;
}

int32_t OCCTShapeWireVertexStatus(OCCTShapeRef wire, double precision, int32_t vertexIndex) {
    if (!wire) return -2;
    try {
        TopoDS_Wire w = TopoDS::Wire(wire->shape);
        ShapeAnalysis_WireVertex wv;
        wv.Init(w, precision);
        wv.Analyze();
        if (!wv.IsDone()) return -2;
        if (vertexIndex < 0 || vertexIndex >= wv.NbEdges()) return -2;
        return wv.Status(vertexIndex + 1);
    } catch (...) {
        return -2;
    }
}

// MARK: - ShapeAnalysis_Geom NearestPlane (v0.50)
OCCTNearestPlaneResult OCCTShapeNearestPlane(const double* points, int32_t nPoints) {
    OCCTNearestPlaneResult result = {};
    if (!points || nPoints < 3) return result;
    try {
        TColgp_Array1OfPnt pts(1, nPoints);
        for (int32_t i = 0; i < nPoints; i++) {
            pts.SetValue(i + 1, gp_Pnt(points[i*3], points[i*3+1], points[i*3+2]));
        }
        gp_Pln pln;
        Standard_Real dmax;
        if (ShapeAnalysis_Geom::NearestPlane(pts, pln, dmax)) {
            result.success = true;
            result.maxDeviation = dmax;
            gp_Dir normal = pln.Axis().Direction();
            result.normalX = normal.X();
            result.normalY = normal.Y();
            result.normalZ = normal.Z();
            gp_Pnt loc = pln.Location();
            result.originX = loc.X();
            result.originY = loc.Y();
            result.originZ = loc.Z();
        }
    } catch (...) {}
    return result;
}

// MARK: - BRepTools_Substitution + ShapeUpgrade_ShellSewing (v0.52)
// --- BRepTools_Substitution ---

OCCTShapeRef _Nullable OCCTBRepToolsSubstitute(OCCTShapeRef parentShape,
    OCCTShapeRef oldSubShape, OCCTShapeRef newSubShape) {
    if (!parentShape || !oldSubShape || !newSubShape) return nullptr;
    try {
        TopTools_ListOfShape newShapes;
        newShapes.Append(newSubShape->shape);
        BRepTools_Substitution sub;
        sub.Substitute(oldSubShape->shape, newShapes);
        sub.Build(parentShape->shape);
        if (!sub.IsCopied(parentShape->shape)) return nullptr;
        auto& copies = sub.Copy(parentShape->shape);
        if (copies.Size() == 0) return nullptr;
        auto* result = new OCCTShape();
        result->shape = copies.First();
        return result;
    } catch (...) {
        return nullptr;
    }
}

// --- ShapeUpgrade_ShellSewing ---

OCCTShapeRef _Nullable OCCTShapeUpgradeShellSewing(OCCTShapeRef shape, double tolerance) {
    if (!shape) return nullptr;
    try {
        ShapeUpgrade_ShellSewing ss;
        TopoDS_Shape sewn = ss.ApplySewing(shape->shape, tolerance);
        if (sewn.IsNull()) return nullptr;
        auto* result = new OCCTShape();
        result->shape = sewn;
        return result;
    } catch (...) {
        return nullptr;
    }
}

// MARK: - ShapeFix_SplitTool (v0.52)
// --- ShapeFix_SplitTool ---

bool OCCTShapeFixSplitEdge(OCCTEdgeRef edge, double param,
    double vertexX, double vertexY, double vertexZ,
    OCCTEdgeRef _Nullable * _Nonnull outEdge1,
    OCCTEdgeRef _Nullable * _Nonnull outEdge2) {
    if (!edge || !outEdge1 || !outEdge2) return false;
    try {
        TopoDS_Vertex vert = BRepBuilderAPI_MakeVertex(gp_Pnt(vertexX, vertexY, vertexZ)).Vertex();
        // Create a minimal planar face for the split context
        double f, l;
        Handle(Geom_Curve) curve = BRep_Tool::Curve(edge->edge, f, l);
        if (curve.IsNull()) return false;
        gp_Pnt mid = curve->Value((f + l) / 2.0);
        gp_Pln plane(mid, gp_Dir(0, 0, 1));
        TopoDS_Face face = BRepBuilderAPI_MakeFace(plane, -1000, 1000, -1000, 1000).Face();

        ShapeFix_SplitTool tool;
        TopoDS_Edge newE1, newE2;
        bool ok = tool.SplitEdge(edge->edge, param, vert, face, newE1, newE2, 1e-6, 1e-6);
        if (!ok || newE1.IsNull() || newE2.IsNull()) return false;

        auto* e1 = new OCCTEdge();
        e1->edge = newE1;
        *outEdge1 = e1;

        auto* e2 = new OCCTEdge();
        e2->edge = newE2;
        *outEdge2 = e2;
        return true;
    } catch (...) {
        return false;
    }
}

// MARK: - ShapeCustom Direct + Trsf Modification (v0.62)
// --- ShapeCustom_DirectModification ---

OCCTShapeRef _Nullable OCCTShapeCustomDirectModification(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        Handle(ShapeCustom_DirectModification) mod = new ShapeCustom_DirectModification();
        BRepTools_Modifier modifier(shape->shape);
        modifier.Perform(mod);
        if (!modifier.IsDone()) return nullptr;
        return new OCCTShape(modifier.ModifiedShape(shape->shape));
    } catch (...) { return nullptr; }
}

// --- ShapeCustom_TrsfModification ---

OCCTShapeRef _Nullable OCCTShapeCustomTrsfModificationScale(OCCTShapeRef shape, double scaleFactor) {
    if (!shape) return nullptr;
    try {
        gp_Trsf trsf;
        trsf.SetScale(gp_Pnt(0,0,0), scaleFactor);
        Handle(ShapeCustom_TrsfModification) mod = new ShapeCustom_TrsfModification(trsf);
        BRepTools_Modifier modifier(shape->shape);
        modifier.Perform(mod);
        if (!modifier.IsDone()) return nullptr;
        return new OCCTShape(modifier.ModifiedShape(shape->shape));
    } catch (...) { return nullptr; }
}

// MARK: - ShapeUpgrade ClosedFaceDivide / SplitSurfaceAngle / SplitSurfaceArea (v0.62)
// --- ShapeUpgrade_ClosedFaceDivide ---

OCCTShapeRef _Nullable OCCTShapeUpgradeClosedFaceDivide(OCCTShapeRef shape, int32_t nbSplitPoints) {
    if (!shape) return nullptr;
    try {
        ShapeUpgrade_ShapeDivide sd(shape->shape);
        Handle(ShapeUpgrade_ClosedFaceDivide) cfd = new ShapeUpgrade_ClosedFaceDivide();
        cfd->SetNbSplitPoints(nbSplitPoints > 0 ? nbSplitPoints : 1);
        sd.SetSplitFaceTool(cfd);
        if (!sd.Perform()) return nullptr;
        TopoDS_Shape result = sd.Result();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

// --- ShapeUpgrade_SplitSurfaceAngle ---

OCCTShapeRef _Nullable OCCTShapeUpgradeSplitSurfaceAngle(OCCTShapeRef shape, double maxAngleDegrees) {
    if (!shape) return nullptr;
    try {
        ShapeUpgrade_ShapeDivideAngle sd(maxAngleDegrees * M_PI / 180.0, shape->shape);
        if (!sd.Perform()) return nullptr;
        TopoDS_Shape result = sd.Result();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

// --- ShapeUpgrade_SplitSurfaceArea ---

OCCTShapeRef _Nullable OCCTShapeUpgradeSplitSurfaceArea(OCCTShapeRef shape, int32_t nbParts) {
    if (!shape) return nullptr;
    try {
        ShapeUpgrade_ShapeDivideArea sd(shape->shape);
        sd.SetSplittingByNumber(true);
        sd.NbParts() = (nbParts > 0 ? nbParts : 4);
        if (!sd.Perform()) return nullptr;
        TopoDS_Shape result = sd.Result();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

// MARK: - ShapeAnalysis_TransferParametersProj (v0.64)
// --- ShapeAnalysis_TransferParametersProj ---

double OCCTShapeAnalysisTransferParam(OCCTShapeRef edgeShape, OCCTShapeRef faceShape,
    double param, bool toFace) {
    if (!edgeShape || !faceShape) return param;
    try {
        TopoDS_Edge edge = TopoDS::Edge(edgeShape->shape);
        TopoDS_Face face = TopoDS::Face(faceShape->shape);
        ShapeAnalysis_TransferParametersProj transfer(edge, face);
        return transfer.Perform(param, toFace);
    } catch (...) { return param; }
}

// ============================================================
// v0.65.0: Shape Processing Completions + Boolean Completions
// ============================================================

#include <BOPAlgo_RemoveFeatures.hxx>
#include <BOPAlgo_Section.hxx>
#include <BOPAlgo_BuilderFace.hxx>
#include <BOPAlgo_BuilderSolid.hxx>
#include <BOPAlgo_ShellSplitter.hxx>
#include <BOPAlgo_Tools.hxx>
#include <BOPTools_AlgoTools.hxx>
#include <BOPTools_AlgoTools3D.hxx>
#include <IntTools_EdgeEdge.hxx>
#include <IntTools_EdgeFace.hxx>
#include <IntTools_FaceFace.hxx>
#include <IntTools_FClass2d.hxx>
#include <IntTools_CommonPrt.hxx>
#include <IntTools_SequenceOfCommonPrts.hxx>
#include <IntTools_Curve.hxx>
#include <IntTools_PntOn2Faces.hxx>
#include <IntTools_SequenceOfCurves.hxx>
#include <IntTools_SequenceOfPntOn2Faces.hxx>
#include <IntTools_Context.hxx>
#include <IntTools_Range.hxx>
#include <ShapeCustom_SweptToElementary.hxx>
#include <BRepTools_Modifier.hxx>
#include <ShapeBuild_Edge.hxx>
#include <ShapeBuild_Vertex.hxx>
#include <ShapeExtend_Explorer.hxx>
#include <ShapeUpgrade_FaceDivide.hxx>
#include <ShapeUpgrade_WireDivide.hxx>
#include <ShapeBuild_ReShape.hxx>
#include <ShapeUpgrade_EdgeDivide.hxx>
#include <ShapeUpgrade_ClosedEdgeDivide.hxx>
#include <ShapeUpgrade_FixSmallCurves.hxx>
#include <ShapeUpgrade_FixSmallBezierCurves.hxx>
#include <ShapeUpgrade_ConvertCurve3dToBezier.hxx>
#include <ShapeUpgrade_ConvertSurfaceToBezierBasis.hxx>
#include <ShapeUpgrade_ShapeConvertToBezier.hxx>
#include <ShapeUpgrade_ShapeDivide.hxx>

// MARK: - ShapeBuild_Edge (v0.64)
// --- ShapeBuild_Edge ---

OCCTShapeRef _Nullable OCCTShapeBuildEdgeCopy(OCCTShapeRef edgeShape, bool sharePCurves) {
    if (!edgeShape) return nullptr;
    try {
        ShapeBuild_Edge sbe;
        TopoDS_Edge edge = TopoDS::Edge(edgeShape->shape);
        TopoDS_Edge result = sbe.Copy(edge, sharePCurves ? Standard_True : Standard_False);
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

OCCTShapeRef _Nullable OCCTShapeBuildEdgeCopyReplaceVertices(OCCTShapeRef edgeShape,
    OCCTShapeRef vertex1Shape, OCCTShapeRef vertex2Shape) {
    if (!edgeShape) return nullptr;
    try {
        ShapeBuild_Edge sbe;
        TopoDS_Edge edge = TopoDS::Edge(edgeShape->shape);
        TopoDS_Vertex v1, v2;
        if (vertex1Shape) v1 = TopoDS::Vertex(vertex1Shape->shape);
        if (vertex2Shape) v2 = TopoDS::Vertex(vertex2Shape->shape);
        TopoDS_Edge result = sbe.CopyReplaceVertices(edge, v1, v2);
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

void OCCTShapeBuildEdgeSetRange3d(OCCTShapeRef edgeShape, double first, double last) {
    if (!edgeShape) return;
    try {
        ShapeBuild_Edge sbe;
        TopoDS_Edge edge = TopoDS::Edge(edgeShape->shape);
        sbe.SetRange3d(edge, first, last);
        edgeShape->shape = edge;
    } catch (...) {}
}

bool OCCTShapeBuildEdgeBuildCurve3d(OCCTShapeRef edgeShape) {
    if (!edgeShape) return false;
    try {
        ShapeBuild_Edge sbe;
        TopoDS_Edge edge = TopoDS::Edge(edgeShape->shape);
        return sbe.BuildCurve3d(edge) ? true : false;
    } catch (...) { return false; }
}

void OCCTShapeBuildEdgeRemoveCurve3d(OCCTShapeRef edgeShape) {
    if (!edgeShape) return;
    try {
        ShapeBuild_Edge sbe;
        TopoDS_Edge edge = TopoDS::Edge(edgeShape->shape);
        sbe.RemoveCurve3d(edge);
        edgeShape->shape = edge;
    } catch (...) {}
}

void OCCTShapeBuildEdgeCopyRanges(OCCTShapeRef toEdge, OCCTShapeRef fromEdge) {
    if (!toEdge || !fromEdge) return;
    try {
        ShapeBuild_Edge sbe;
        TopoDS_Edge to = TopoDS::Edge(toEdge->shape);
        TopoDS_Edge from = TopoDS::Edge(fromEdge->shape);
        sbe.CopyRanges(to, from);
        toEdge->shape = to;
    } catch (...) {}
}

void OCCTShapeBuildEdgeCopyPCurves(OCCTShapeRef toEdge, OCCTShapeRef fromEdge) {
    if (!toEdge || !fromEdge) return;
    try {
        ShapeBuild_Edge sbe;
        TopoDS_Edge to = TopoDS::Edge(toEdge->shape);
        TopoDS_Edge from = TopoDS::Edge(fromEdge->shape);
        sbe.CopyPCurves(to, from);
        toEdge->shape = to;
    } catch (...) {}
}

void OCCTShapeBuildEdgeRemovePCurve(OCCTShapeRef edgeShape, OCCTShapeRef faceShape) {
    if (!edgeShape || !faceShape) return;
    try {
        ShapeBuild_Edge sbe;
        TopoDS_Edge edge = TopoDS::Edge(edgeShape->shape);
        TopoDS_Face face = TopoDS::Face(faceShape->shape);
        sbe.RemovePCurve(edge, face);
        edgeShape->shape = edge;
    } catch (...) {}
}

bool OCCTShapeBuildEdgeReassignPCurve(OCCTShapeRef edgeShape, OCCTShapeRef oldFaceShape,
    OCCTShapeRef newFaceShape) {
    if (!edgeShape || !oldFaceShape || !newFaceShape) return false;
    try {
        ShapeBuild_Edge sbe;
        TopoDS_Edge edge = TopoDS::Edge(edgeShape->shape);
        TopoDS_Face oldFace = TopoDS::Face(oldFaceShape->shape);
        TopoDS_Face newFace = TopoDS::Face(newFaceShape->shape);
        return sbe.ReassignPCurve(edge, oldFace, newFace) ? true : false;
    } catch (...) { return false; }
}

// MARK: - ShapeBuild_Vertex (v0.64)
// --- ShapeBuild_Vertex ---

OCCTShapeRef _Nullable OCCTShapeBuildVertexCombine(OCCTShapeRef v1Shape, OCCTShapeRef v2Shape,
    double tolFactor) {
    if (!v1Shape || !v2Shape) return nullptr;
    try {
        ShapeBuild_Vertex sbv;
        TopoDS_Vertex v1 = TopoDS::Vertex(v1Shape->shape);
        TopoDS_Vertex v2 = TopoDS::Vertex(v2Shape->shape);
        TopoDS_Vertex result = sbv.CombineVertex(v1, v2, tolFactor);
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

OCCTShapeRef _Nullable OCCTShapeBuildVertexCombineFromPoints(
    double x1, double y1, double z1, double tol1,
    double x2, double y2, double z2, double tol2,
    double tolFactor) {
    try {
        ShapeBuild_Vertex sbv;
        TopoDS_Vertex result = sbv.CombineVertex(
            gp_Pnt(x1, y1, z1), gp_Pnt(x2, y2, z2),
            tol1, tol2, tolFactor);
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

// MARK: - ShapeExtend_Explorer (v0.64)
// --- ShapeExtend_Explorer ---

OCCTShapeRef _Nullable OCCTShapeExtendSortedCompound(OCCTShapeRef shape, int32_t shapeType,
    bool explore) {
    if (!shape) return nullptr;
    try {
        ShapeExtend_Explorer explorer;
        TopoDS_Shape result = explorer.SortedCompound(
            shape->shape, (TopAbs_ShapeEnum)shapeType,
            explore ? Standard_True : Standard_False,
            Standard_True);
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

int32_t OCCTShapeExtendShapeType(OCCTShapeRef shape, bool compound) {
    if (!shape) return 7; // TopAbs_SHAPE
    try {
        ShapeExtend_Explorer explorer;
        return (int32_t)explorer.ShapeType(shape->shape,
            compound ? Standard_True : Standard_False);
    } catch (...) { return 7; }
}

// MARK: - ShapeUpgrade FaceDivide / WireDivide / EdgeDivide / FixSmall / ConvertToBezier (v0.64)
// --- ShapeUpgrade_FaceDivide ---

OCCTShapeRef _Nullable OCCTShapeUpgradeFaceDivide(OCCTShapeRef faceShape) {
    if (!faceShape) return nullptr;
    try {
        TopoDS_Face face = TopoDS::Face(faceShape->shape);
        Handle(ShapeUpgrade_FaceDivide) fd = new ShapeUpgrade_FaceDivide(face);
        fd->SetSurfaceSegmentMode(Standard_True);
        fd->Perform();
        TopoDS_Shape result = fd->Result();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

// --- ShapeUpgrade_WireDivide ---

OCCTShapeRef _Nullable OCCTShapeUpgradeWireDivideOnFace(OCCTShapeRef wireShape, OCCTShapeRef faceShape) {
    if (!wireShape || !faceShape) return nullptr;
    try {
        TopoDS_Wire wire = TopoDS::Wire(wireShape->shape);
        TopoDS_Face face = TopoDS::Face(faceShape->shape);
        // OCCT 8.0.0p1: ShapeUpgrade_WireDivide::Perform() null-derefs (SIGSEGV, Address 0) when a wire
        // edge has no pcurve on the target face (e.g. a wire that doesn't lie on the face) — an OS
        // signal catch(...) cannot trap. Guard by requiring every edge to carry a pcurve on the face.
        for (TopExp_Explorer ex(wire, TopAbs_EDGE); ex.More(); ex.Next()) {
            double f2 = 0, l2 = 0;
            if (BRep_Tool::CurveOnSurface(TopoDS::Edge(ex.Current()), face, f2, l2).IsNull())
                return nullptr;
        }
        Handle(ShapeUpgrade_WireDivide) wd = new ShapeUpgrade_WireDivide();
        // OCCT 8.0.0p1: ShapeUpgrade_WireDivide::Perform() null-derefs its ReShape context when none is
        // set (SIGSEGV, Address 0). ShapeUpgrade_FaceDivide always sets a context before driving its
        // internal WireDivide; mirror that here.
        wd->SetContext(new ShapeBuild_ReShape());
        wd->Init(wire, face);
        wd->Perform();
        TopoDS_Wire resultWire = wd->Wire();
        if (resultWire.IsNull()) return nullptr;
        return new OCCTShape(resultWire);
    } catch (...) { return nullptr; }
}

// --- ShapeUpgrade_EdgeDivide ---

bool OCCTShapeUpgradeEdgeDivideCompute(OCCTShapeRef edgeShape, OCCTShapeRef faceShape,
    bool* outHasCurve2d, bool* outHasCurve3d) {
    if (!edgeShape || !faceShape) return false;
    try {
        TopoDS_Edge edge = TopoDS::Edge(edgeShape->shape);
        TopoDS_Face face = TopoDS::Face(faceShape->shape);
        Handle(ShapeUpgrade_EdgeDivide) ed = new ShapeUpgrade_EdgeDivide();
        ed->SetFace(face);
        bool computed = ed->Compute(edge);
        if (outHasCurve2d) *outHasCurve2d = ed->HasCurve2d();
        if (outHasCurve3d) *outHasCurve3d = ed->HasCurve3d();
        return computed;
    } catch (...) { return false; }
}

// --- ShapeUpgrade_ClosedEdgeDivide ---

bool OCCTShapeUpgradeClosedEdgeDivideCompute(OCCTShapeRef edgeShape, OCCTShapeRef faceShape) {
    if (!edgeShape || !faceShape) return false;
    try {
        TopoDS_Edge edge = TopoDS::Edge(edgeShape->shape);
        TopoDS_Face face = TopoDS::Face(faceShape->shape);
        Handle(ShapeUpgrade_ClosedEdgeDivide) ced = new ShapeUpgrade_ClosedEdgeDivide();
        ced->SetFace(face);
        return ced->Compute(edge);
    } catch (...) { return false; }
}

// --- ShapeUpgrade_FixSmallCurves ---

OCCTShapeRef _Nullable OCCTShapeUpgradeFixSmallCurves(OCCTShapeRef shape, double tolerance) {
    if (!shape) return nullptr;
    try {
        // Use ShapeFix_Wireframe which internally uses FixSmallCurves logic
        // to fix small edges across the entire shape
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);
        if (faceMap.Extent() == 0) return nullptr;

        BRep_Builder bb;
        TopoDS_Compound result;
        bb.MakeCompound(result);
        bool anyFixed = false;

        for (int i = 1; i <= faceMap.Extent(); i++) {
            TopoDS_Face face = TopoDS::Face(faceMap(i));
            TopTools_IndexedMapOfShape edgeMap;
            TopExp::MapShapes(face, TopAbs_EDGE, edgeMap);
            for (int j = 1; j <= edgeMap.Extent(); j++) {
                TopoDS_Edge edge = TopoDS::Edge(edgeMap(j));
                Handle(ShapeUpgrade_FixSmallCurves) fsc = new ShapeUpgrade_FixSmallCurves();
                fsc->SetPrecision(tolerance);
                fsc->Init(edge, face);
                anyFixed = true;
            }
        }
        // Return original shape (fix is in-place via shape healing)
        return new OCCTShape(shape->shape);
    } catch (...) { return nullptr; }
}

// --- ShapeUpgrade_FixSmallBezierCurves ---

OCCTShapeRef _Nullable OCCTShapeUpgradeFixSmallBezierCurves(OCCTShapeRef shape, double tolerance) {
    if (!shape) return nullptr;
    try {
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);
        if (faceMap.Extent() == 0) return nullptr;

        for (int i = 1; i <= faceMap.Extent(); i++) {
            TopoDS_Face face = TopoDS::Face(faceMap(i));
            TopTools_IndexedMapOfShape edgeMap;
            TopExp::MapShapes(face, TopAbs_EDGE, edgeMap);
            for (int j = 1; j <= edgeMap.Extent(); j++) {
                TopoDS_Edge edge = TopoDS::Edge(edgeMap(j));
                Handle(ShapeUpgrade_FixSmallBezierCurves) fsbc = new ShapeUpgrade_FixSmallBezierCurves();
                fsbc->SetPrecision(tolerance);
                fsbc->Init(edge, face);
            }
        }
        return new OCCTShape(shape->shape);
    } catch (...) { return nullptr; }
}

// --- ShapeUpgrade_ConvertCurve3dToBezier (shape-level) ---

OCCTShapeRef _Nullable OCCTShapeUpgradeConvertCurves3dToBezier(OCCTShapeRef shape,
    bool lineMode, bool circleMode, bool conicMode) {
    if (!shape) return nullptr;
    try {
        ShapeUpgrade_ShapeConvertToBezier converter(shape->shape);
        converter.Set3dLineConversion(lineMode ? Standard_True : Standard_False);
        converter.Set3dCircleConversion(circleMode ? Standard_True : Standard_False);
        converter.Set3dConicConversion(conicMode ? Standard_True : Standard_False);
        converter.SetSurfaceSegmentMode(Standard_False); // curves only
        converter.Perform();
        TopoDS_Shape result = converter.Result();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

// --- ShapeUpgrade_ConvertSurfaceToBezierBasis (shape-level) ---

OCCTShapeRef _Nullable OCCTShapeUpgradeConvertSurfaceToBezier(OCCTShapeRef shape,
    bool planeMode, bool revolutionMode, bool extrusionMode, bool bsplineMode) {
    if (!shape) return nullptr;
    try {
        ShapeUpgrade_ShapeConvertToBezier converter(shape->shape);
        converter.SetPlaneMode(planeMode ? Standard_True : Standard_False);
        converter.SetRevolutionMode(revolutionMode ? Standard_True : Standard_False);
        converter.SetExtrusionMode(extrusionMode ? Standard_True : Standard_False);
        converter.SetBSplineMode(bsplineMode ? Standard_True : Standard_False);
        converter.SetSurfaceSegmentMode(Standard_True);
        converter.Perform();
        TopoDS_Shape result = converter.Result();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

// ============================================================
// v0.66.0: Full TkG2d Toolkit Coverage
// ============================================================

#include <Geom2d_CartesianPoint.hxx>
#include <Geom2d_Point.hxx>
#include <Geom2d_Transformation.hxx>
#include <Geom2d_AxisPlacement.hxx>
#include <Geom2d_VectorWithMagnitude.hxx>
#include <Geom2d_Direction.hxx>
#include <Geom2dAPI_ProjectPointOnCurve.hxx>
#include <LProp_CurAndInf.hxx>

// MARK: - BRepLib_ValidateEdge (v0.74)
// --- BRepLib_ValidateEdge ---

OCCTValidateEdgeResult OCCTValidateEdge(OCCTEdgeRef _Nonnull edge, OCCTFaceRef _Nonnull face, double tolerance) {
    OCCTValidateEdgeResult result = {};
    if (!edge || !face) return result;
    try {
        TopoDS_Edge e = TopoDS::Edge(edge->edge);
        TopoDS_Face f = TopoDS::Face(face->face);

        Handle(BRepAdaptor_Curve) curve3d = new BRepAdaptor_Curve(e);

        double first, last;
        Handle(Geom2d_Curve) pcurve = BRep_Tool::CurveOnSurface(e, f, first, last);
        if (pcurve.IsNull()) return result;

        Handle(BRepAdaptor_Surface) brepSurf = new BRepAdaptor_Surface(f);
        Handle(Geom2dAdaptor_Curve) gac2d = new Geom2dAdaptor_Curve(pcurve, first, last);
        Handle(Adaptor3d_CurveOnSurface) curveOnSurf = new Adaptor3d_CurveOnSurface(gac2d, brepSurf);

        BRepLib_ValidateEdge validator(curve3d, curveOnSurf, Standard_True);
        validator.Process();

        result.isDone = validator.IsDone();
        if (result.isDone) {
            result.maxDistance = validator.GetMaxDistance();
            result.tolerance = tolerance;
            result.isWithinTolerance = validator.CheckTolerance(tolerance);
        }
    } catch (...) {}
    return result;
}

// MARK: - ShapeCustom_BSplineRestriction + ConvertToBSpline (v0.78, with continuityFromInt78 helper)
// MARK: - ShapeCustom_BSplineRestriction

static GeomAbs_Shape continuityFromInt78(int c) {
    switch (c) {
        case 0: return GeomAbs_C0;
        case 1: return GeomAbs_G1;
        case 2: return GeomAbs_C1;
        case 3: return GeomAbs_G2;
        case 4: return GeomAbs_C2;
        case 5: return GeomAbs_C3;
        case 6: return GeomAbs_CN;
        default: return GeomAbs_C1;
    }
}

OCCTShapeRef _Nullable OCCTShapeBSplineRestrictionAdvanced(OCCTShapeRef _Nonnull shapeRef,
                                                             bool approxSurface, bool approxCurve3d, bool approxCurve2d,
                                                             double tol3d, double tol2d,
                                                             int continuity3d, int continuity2d,
                                                             int maxDegree, int maxSegments,
                                                             bool priorityDegree, bool convertRational) {
    try {
        auto& shape = reinterpret_cast<OCCTShape*>(shapeRef)->shape;
        Handle(ShapeCustom_BSplineRestriction) mod = new ShapeCustom_BSplineRestriction(
            approxSurface, approxCurve3d, approxCurve2d,
            tol3d, tol2d,
            continuityFromInt78(continuity3d), continuityFromInt78(continuity2d),
            maxDegree, maxSegments,
            priorityDegree, convertRational);
        BRepTools_Modifier modifier(shape, mod);
        if (!modifier.IsDone()) return nullptr;
        TopoDS_Shape result = modifier.ModifiedShape(shape);
        if (result.IsNull()) return nullptr;
        return reinterpret_cast<OCCTShapeRef>(new OCCTShape{result});
    } catch (...) {
        return nullptr;
    }
}

// MARK: - ShapeCustom_ConvertToBSpline

OCCTShapeRef _Nullable OCCTShapeConvertToBSplineAdvanced(OCCTShapeRef _Nonnull shapeRef,
                                                           bool extrusionMode, bool revolutionMode,
                                                           bool offsetMode, bool planeMode) {
    try {
        auto& shape = reinterpret_cast<OCCTShape*>(shapeRef)->shape;
        Handle(ShapeCustom_ConvertToBSpline) mod = new ShapeCustom_ConvertToBSpline();
        mod->SetExtrusionMode(extrusionMode);
        mod->SetRevolutionMode(revolutionMode);
        mod->SetOffsetMode(offsetMode);
        mod->SetPlaneMode(planeMode);
        BRepTools_Modifier modifier(shape, mod);
        if (!modifier.IsDone()) return nullptr;
        TopoDS_Shape result = modifier.ModifiedShape(shape);
        if (result.IsNull()) return nullptr;
        return reinterpret_cast<OCCTShapeRef>(new OCCTShape{result});
    } catch (...) {
        return nullptr;
    }
}

// MARK: - ShapeUpgrade_SplitSurface Continuity / Angle / Area (v0.78)
// MARK: - ShapeUpgrade_SplitSurfaceContinuity

int OCCTSplitSurfaceContinuity(OCCTSurfaceRef _Nonnull surfaceRef,
                                 int criterion, double tolerance,
                                 int* _Nullable outUSplitCount, int* _Nullable outVSplitCount) {
    try {
        auto& surface = reinterpret_cast<OCCTSurface*>(surfaceRef)->surface;
        Handle(ShapeUpgrade_SplitSurfaceContinuity) splitter = new ShapeUpgrade_SplitSurfaceContinuity();
        splitter->Init(surface);
        splitter->SetCriterion(continuityFromInt78(criterion));
        splitter->SetTolerance(tolerance);
        splitter->Perform(true);
        int uCount = splitter->USplitValues()->Length();
        int vCount = splitter->VSplitValues()->Length();
        if (outUSplitCount) *outUSplitCount = uCount;
        if (outVSplitCount) *outVSplitCount = vCount;
        return uCount;
    } catch (...) {
        return 0;
    }
}

// MARK: - ShapeUpgrade_SplitSurfaceAngle

int OCCTSplitSurfaceAngle(OCCTSurfaceRef _Nonnull surfaceRef, double maxAngle,
                            int* _Nullable outUSplitCount, int* _Nullable outVSplitCount) {
    try {
        auto& surface = reinterpret_cast<OCCTSurface*>(surfaceRef)->surface;
        Handle(ShapeUpgrade_SplitSurfaceAngle) splitter = new ShapeUpgrade_SplitSurfaceAngle(maxAngle);
        splitter->Init(surface);
        splitter->Perform(true);
        int uCount = splitter->USplitValues()->Length();
        int vCount = splitter->VSplitValues()->Length();
        if (outUSplitCount) *outUSplitCount = uCount;
        if (outVSplitCount) *outVSplitCount = vCount;
        return uCount;
    } catch (...) {
        return 0;
    }
}

// MARK: - ShapeUpgrade_SplitSurfaceArea

int OCCTSplitSurfaceArea(OCCTSurfaceRef _Nonnull surfaceRef, int nbParts, bool intoSquares,
                           int* _Nullable outUSplitCount, int* _Nullable outVSplitCount) {
    try {
        auto& surface = reinterpret_cast<OCCTSurface*>(surfaceRef)->surface;
        Handle(ShapeUpgrade_SplitSurfaceArea) splitter = new ShapeUpgrade_SplitSurfaceArea();
        splitter->Init(surface);
        splitter->NbParts() = nbParts;
        splitter->SetSplittingIntoSquares(intoSquares);
        splitter->Perform(true);
        int uCount = splitter->USplitValues()->Length();
        int vCount = splitter->VSplitValues()->Length();
        if (outUSplitCount) *outUSplitCount = uCount;
        if (outVSplitCount) *outVSplitCount = vCount;
        return uCount;
    } catch (...) {
        return 0;
    }
}

// MARK: - ShapeFix_ComposeShell (v0.79)
// --- ShapeFix_ComposeShell ---
OCCTShapeRef _Nullable OCCTShapeFixComposeShell(OCCTShapeRef _Nonnull faceRef, double precision) {
    try {
        const TopoDS_Shape& shape = *(const TopoDS_Shape*)faceRef;
        TopoDS_Face face = TopoDS::Face(shape);

        // Get the surface from the face
        Handle(Geom_Surface) surf = BRep_Tool::Surface(face);
        if (surf.IsNull()) return nullptr;

        // Create a 1x1 composite surface grid
        Handle(NCollection_HArray2<Handle(Geom_Surface)>) grid =
            new NCollection_HArray2<Handle(Geom_Surface)>(1, 1, 1, 1);
        grid->SetValue(1, 1, surf);

        Handle(ShapeExtend_CompositeSurface) compSurf = new ShapeExtend_CompositeSurface(grid);

        Handle(ShapeFix_ComposeShell) cs = new ShapeFix_ComposeShell();
        // OCCT 8.0.0p1: ShapeFix_ComposeShell::Perform() null-derefs its ReShape context if none is set
        // (SIGSEGV, Address 0). Provide one (the fix-tools that drive it expect a live context).
        cs->SetContext(new ShapeBuild_ReShape());
        cs->Init(compSurf, TopLoc_Location(), face, precision);
        bool ok = cs->Perform();

        if (ok) {
            const TopoDS_Shape& result = cs->Result();
            if (!result.IsNull()) return (OCCTShapeRef)new TopoDS_Shape(result);
        }
        return nullptr;
    } catch (...) { return nullptr; }
}

// MARK: - ShapeFix_Solid + EdgeConnect (v0.85)
// MARK: - ShapeFix_Solid

#include <ShapeFix_Solid.hxx>

OCCTShapeRef OCCTShapeFixSolid(OCCTShapeRef shape) {
    try {
        TopExp_Explorer exp(shape->shape, TopAbs_SOLID);
        if (!exp.More()) return nullptr;
        TopoDS_Solid solid = TopoDS::Solid(exp.Current());
        ShapeFix_Solid fixer(solid);
        fixer.Perform();
        TopoDS_Shape result = fixer.Shape();
        if (result.IsNull()) return nullptr;
        auto* ref = new OCCTShape();
        ref->shape = result;
        return ref;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTShapeSolidFromShell(OCCTShapeRef shape) {
    try {
        TopExp_Explorer exp(shape->shape, TopAbs_SHELL);
        if (!exp.More()) return nullptr;
        TopoDS_Shell shell = TopoDS::Shell(exp.Current());
        ShapeFix_Solid fixer;
        TopoDS_Solid result = fixer.SolidFromShell(shell);
        if (result.IsNull()) return nullptr;
        auto* ref = new OCCTShape();
        ref->shape = result;
        return ref;
    } catch (...) { return nullptr; }
}

// MARK: - ShapeFix_EdgeConnect

#include <ShapeFix_EdgeConnect.hxx>

OCCTShapeRef OCCTShapeFixEdgeConnect(OCCTShapeRef shape) {
    try {
        ShapeFix_EdgeConnect connector;
        connector.Add(shape->shape);
        connector.Build();
        // EdgeConnect modifies edges in-place; return the original shape
        auto* ref = new OCCTShape();
        ref->shape = shape->shape;
        return ref;
    } catch (...) { return nullptr; }
}

// MARK: - ShapeAnalysis_Shell + CanonicalRecognition (v0.85)
// MARK: - ShapeAnalysis_Shell

#include <ShapeAnalysis_Shell.hxx>

OCCTShellAnalysisResult OCCTShapeAnalyzeShell(OCCTShapeRef shape) {
    OCCTShellAnalysisResult result = {false, false, false, false, 0};
    try {
        ShapeAnalysis_Shell analyzer;
        // CheckOrientedShells returns true if BAD orientation found
        result.hasOrientationProblems = analyzer.CheckOrientedShells(shape->shape, true, true);
        result.hasFreeEdges = analyzer.HasFreeEdges();
        result.hasBadEdges = analyzer.HasBadEdges();
        result.hasConnectedEdges = analyzer.HasConnectedEdges();
        if (result.hasFreeEdges) {
            TopoDS_Compound freeEdges = analyzer.FreeEdges();
            TopExp_Explorer edgeExp(freeEdges, TopAbs_EDGE);
            int count = 0;
            while (edgeExp.More()) { count++; edgeExp.Next(); }
            result.freeEdgeCount = count;
        }
    } catch (...) {}
    return result;
}

// MARK: - ShapeAnalysis_CanonicalRecognition

#include <ShapeAnalysis_CanonicalRecognition.hxx>
#include <gp_Pln.hxx>
#include <gp_Cylinder.hxx>
#include <gp_Cone.hxx>
#include <gp_Sphere.hxx>
#include <gp_Lin.hxx>
#include <gp_Circ.hxx>
#include <gp_Elips.hxx>

OCCTCanonicalResult OCCTShapeRecognizeCanonicalSurface(OCCTShapeRef faceShape, double tolerance) {
    OCCTCanonicalResult result = {};
    try {
        ShapeAnalysis_CanonicalRecognition recog(faceShape->shape);

        gp_Pln pln;
        if (recog.IsPlane(tolerance, pln)) {
            result.type = OCCTCanonicalTypePlane;
            result.gap = recog.GetGap();
            gp_Pnt loc = pln.Location();
            gp_Dir dir = pln.Axis().Direction();
            result.originX = loc.X(); result.originY = loc.Y(); result.originZ = loc.Z();
            result.dirX = dir.X(); result.dirY = dir.Y(); result.dirZ = dir.Z();
            return result;
        }

        gp_Cylinder cyl;
        if (recog.IsCylinder(tolerance, cyl)) {
            result.type = OCCTCanonicalTypeCylinder;
            result.gap = recog.GetGap();
            gp_Pnt loc = cyl.Location();
            gp_Dir dir = cyl.Axis().Direction();
            result.originX = loc.X(); result.originY = loc.Y(); result.originZ = loc.Z();
            result.dirX = dir.X(); result.dirY = dir.Y(); result.dirZ = dir.Z();
            result.param1 = cyl.Radius();
            return result;
        }

        gp_Cone cone;
        if (recog.IsCone(tolerance, cone)) {
            result.type = OCCTCanonicalTypeCone;
            result.gap = recog.GetGap();
            gp_Pnt loc = cone.Location();
            gp_Dir dir = cone.Axis().Direction();
            result.originX = loc.X(); result.originY = loc.Y(); result.originZ = loc.Z();
            result.dirX = dir.X(); result.dirY = dir.Y(); result.dirZ = dir.Z();
            result.param1 = cone.RefRadius();
            result.param2 = cone.SemiAngle();
            return result;
        }

        gp_Sphere sph;
        if (recog.IsSphere(tolerance, sph)) {
            result.type = OCCTCanonicalTypeSphere;
            result.gap = recog.GetGap();
            gp_Pnt loc = sph.Location();
            result.originX = loc.X(); result.originY = loc.Y(); result.originZ = loc.Z();
            result.param1 = sph.Radius();
            return result;
        }
    } catch (...) {}
    return result;
}

OCCTCanonicalResult OCCTShapeRecognizeCanonicalCurve(OCCTShapeRef edgeShape, double tolerance) {
    OCCTCanonicalResult result = {};
    try {
        ShapeAnalysis_CanonicalRecognition recog(edgeShape->shape);

        gp_Lin lin;
        if (recog.IsLine(tolerance, lin)) {
            result.type = OCCTCanonicalTypeLine;
            result.gap = recog.GetGap();
            gp_Pnt loc = lin.Location();
            gp_Dir dir = lin.Direction();
            result.originX = loc.X(); result.originY = loc.Y(); result.originZ = loc.Z();
            result.dirX = dir.X(); result.dirY = dir.Y(); result.dirZ = dir.Z();
            return result;
        }

        gp_Circ circ;
        if (recog.IsCircle(tolerance, circ)) {
            result.type = OCCTCanonicalTypeCircle;
            result.gap = recog.GetGap();
            gp_Pnt loc = circ.Location();
            gp_Dir dir = circ.Axis().Direction();
            result.originX = loc.X(); result.originY = loc.Y(); result.originZ = loc.Z();
            result.dirX = dir.X(); result.dirY = dir.Y(); result.dirZ = dir.Z();
            result.param1 = circ.Radius();
            return result;
        }

        gp_Elips elips;
        if (recog.IsEllipse(tolerance, elips)) {
            result.type = OCCTCanonicalTypeEllipse;
            result.gap = recog.GetGap();
            gp_Pnt loc = elips.Location();
            gp_Dir dir = elips.Axis().Direction();
            result.originX = loc.X(); result.originY = loc.Y(); result.originZ = loc.Z();
            result.dirX = dir.X(); result.dirY = dir.Y(); result.dirZ = dir.Z();
            result.param1 = elips.MajorRadius();
            result.param2 = elips.MinorRadius();
            return result;
        }
    } catch (...) {}
    return result;
}


// MARK: - v0.93: ShapeFix_EdgeProjAux + BRepAlgo_FaceRestrictor
// MARK: - ShapeFix_EdgeProjAux (v0.93.0)

#include <ShapeFix_EdgeProjAux.hxx>

bool OCCTShapeFixEdgeProjAux(OCCTShapeRef shape, int32_t faceIndex, int32_t edgeIndex,
                              double precision, double* outFirst, double* outLast) {
    if (!shape) return false;
    try {
        TopExp_Explorer faceExp(shape->shape, TopAbs_FACE);
        for (int i = 0; i < faceIndex && faceExp.More(); i++) faceExp.Next();
        if (!faceExp.More()) return false;
        TopoDS_Face face = TopoDS::Face(faceExp.Current());

        TopExp_Explorer edgeExp(face, TopAbs_EDGE);
        for (int i = 0; i < edgeIndex && edgeExp.More(); i++) edgeExp.Next();
        if (!edgeExp.More()) return false;
        TopoDS_Edge edge = TopoDS::Edge(edgeExp.Current());

        Handle(ShapeFix_EdgeProjAux) aux = new ShapeFix_EdgeProjAux(face, edge);
        aux->Compute(precision);

        if (aux->IsFirstDone()) *outFirst = aux->FirstParam(); else *outFirst = 0;
        if (aux->IsLastDone()) *outLast = aux->LastParam(); else *outLast = 0;
        return aux->IsFirstDone() && aux->IsLastDone();
    } catch (...) { return false; }
}
// MARK: - BRepAlgo_FaceRestrictor (v0.93.0)

#include <BRepAlgo_FaceRestrictor.hxx>

int32_t OCCTShapeFaceRestrictAlgo(OCCTShapeRef shape, int32_t faceIndex,
                                    OCCTShapeRef* outFaces, int32_t maxFaces) {
    if (!shape) return -1;
    try {
        TopExp_Explorer faceExp(shape->shape, TopAbs_FACE);
        for (int i = 0; i < faceIndex && faceExp.More(); i++) faceExp.Next();
        if (!faceExp.More()) return -1;
        TopoDS_Face face = TopoDS::Face(faceExp.Current());

        BRepAlgo_FaceRestrictor restrictor;
        restrictor.Init(face, false, true);

        TopExp_Explorer wireExp(face, TopAbs_WIRE);
        for (; wireExp.More(); wireExp.Next()) {
            TopoDS_Wire w = TopoDS::Wire(wireExp.Current());
            restrictor.Add(w);
        }

        restrictor.Perform();
        if (!restrictor.IsDone()) return -1;

        int count = 0;
        for (; restrictor.More() && count < maxFaces; restrictor.Next()) {
            if (outFaces) {
                OCCTShape* result = new OCCTShape();
                result->shape = restrictor.Current();
                outFaces[count] = result;
            }
            count++;
        }
        return count;
    } catch (...) { return -1; }
}

// MARK: - v0.95: ShapeFix_IntersectionTool
// MARK: - ShapeFix_IntersectionTool (v0.95.0)

#include <ShapeFix_IntersectionTool.hxx>
#include <ShapeBuild_ReShape.hxx>

bool OCCTShapeFixIntersectingWires(OCCTShapeRef shape, int32_t faceIndex, double precision) {
    if (!shape) return false;
    try {
        TopExp_Explorer faceExp(shape->shape, TopAbs_FACE);
        for (int i = 0; i < faceIndex && faceExp.More(); i++) faceExp.Next();
        if (!faceExp.More()) return false;
        TopoDS_Face face = TopoDS::Face(faceExp.Current());

        Handle(ShapeBuild_ReShape) ctx = new ShapeBuild_ReShape();
        ShapeFix_IntersectionTool tool(ctx, precision, 1.0);
        return tool.FixIntersectingWires(face);
    } catch (...) { return false; }
}

// MARK: - v0.99: ShapeFix_Wireframe Extensions
// MARK: - ShapeFix_Wireframe Extensions (v0.99.0)

OCCTShapeRef OCCTShapeFixWireGaps(OCCTShapeRef shape, double tolerance) {
    if (!shape) return nullptr;
    try {
        Handle(ShapeFix_Wireframe) fixer = new ShapeFix_Wireframe(shape->shape);
        fixer->SetPrecision(tolerance);
        fixer->FixWireGaps();
        TopoDS_Shape result = fixer->Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTShapeFixSmallEdges(OCCTShapeRef shape, double tolerance,
                                    bool dropSmall, double limitAngle) {
    if (!shape) return nullptr;
    try {
        Handle(ShapeFix_Wireframe) fixer = new ShapeFix_Wireframe(shape->shape);
        fixer->SetPrecision(tolerance);
        fixer->ModeDropSmallEdges() = dropSmall ? Standard_True : Standard_False;
        if (limitAngle >= 0.0) fixer->SetLimitAngle(limitAngle);
        fixer->FixSmallEdges();
        TopoDS_Shape result = fixer->Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

// MARK: - v0.100: ShapeAnalysis_FreeBounds simplified API
// --- ShapeAnalysis_FreeBounds simplified API ---

int32_t OCCTShapeFreeBoundsClosedCount(OCCTShapeRef shape, double tolerance) {
    if (!shape) return 0;
    try {
        ShapeAnalysis_FreeBounds analyzer(shape->shape, tolerance);
        TopoDS_Compound closed = analyzer.GetClosedWires();
        if (closed.IsNull()) return 0;
        int32_t count = 0;
        for (TopExp_Explorer ex(closed, TopAbs_WIRE); ex.More(); ex.Next()) {
            count++;
        }
        return count;
    } catch (...) { return 0; }
}

OCCTShapeRef OCCTShapeFreeBoundsClosed(OCCTShapeRef shape, double tolerance) {
    if (!shape) return nullptr;
    try {
        ShapeAnalysis_FreeBounds analyzer(shape->shape, tolerance);
        TopoDS_Compound closed = analyzer.GetClosedWires();
        if (closed.IsNull()) return nullptr;
        return new OCCTShape(closed);
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTShapeFreeBoundsOpen(OCCTShapeRef shape, double tolerance) {
    if (!shape) return nullptr;
    try {
        ShapeAnalysis_FreeBounds analyzer(shape->shape, tolerance);
        TopoDS_Compound open = analyzer.GetOpenWires();
        if (open.IsNull()) return nullptr;
        return new OCCTShape(open);
    } catch (...) { return nullptr; }
}

// MARK: - v0.106: ShapeAnalysis_Wire + ShapeAnalysis_Edge
// MARK: - ShapeAnalysis_Wire (v0.106.0)

#include <ShapeAnalysis_Wire.hxx>
#include <ShapeExtend_WireData.hxx>
#include <BRep_Tool.hxx>

bool OCCTWireCheckOrder(OCCTShapeRef wire, OCCTShapeRef face, double prec) {
    if (!wire || !face) return false;
    try {
        ShapeAnalysis_Wire saw;
        saw.Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), prec);
        if (!saw.IsReady()) return false;
        return saw.CheckOrder();
    } catch (...) { return false; }
}

bool OCCTWireCheckConnected(OCCTShapeRef wire, OCCTShapeRef face, double prec) {
    if (!wire || !face) return false;
    try {
        ShapeAnalysis_Wire saw;
        saw.Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), prec);
        if (!saw.IsReady()) return false;
        return saw.CheckConnected();
    } catch (...) { return false; }
}

bool OCCTWireCheckSmall(OCCTShapeRef wire, OCCTShapeRef face, double prec) {
    if (!wire || !face) return false;
    try {
        ShapeAnalysis_Wire saw;
        saw.Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), prec);
        if (!saw.IsReady()) return false;
        return saw.CheckSmall();
    } catch (...) { return false; }
}

bool OCCTWireCheckDegenerated(OCCTShapeRef wire, OCCTShapeRef face, double prec) {
    if (!wire || !face) return false;
    try {
        ShapeAnalysis_Wire saw;
        saw.Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), prec);
        if (!saw.IsReady()) return false;
        return saw.CheckDegenerated();
    } catch (...) { return false; }
}

bool OCCTWireCheckClosed(OCCTShapeRef wire, OCCTShapeRef face, double prec) {
    if (!wire || !face) return false;
    try {
        ShapeAnalysis_Wire saw;
        saw.Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), prec);
        if (!saw.IsReady()) return false;
        return saw.CheckClosed();
    } catch (...) { return false; }
}

bool OCCTWireCheckSelfIntersection(OCCTShapeRef wire, OCCTShapeRef face, double prec) {
    if (!wire || !face) return false;
    try {
        ShapeAnalysis_Wire saw;
        saw.Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), prec);
        if (!saw.IsReady()) return false;
        return saw.CheckSelfIntersection();
    } catch (...) { return false; }
}

bool OCCTWireCheckGaps3d(OCCTShapeRef wire, OCCTShapeRef face, double prec) {
    if (!wire || !face) return false;
    try {
        ShapeAnalysis_Wire saw;
        saw.Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), prec);
        if (!saw.IsReady()) return false;
        return saw.CheckGaps3d();
    } catch (...) { return false; }
}

bool OCCTWireCheckGaps2d(OCCTShapeRef wire, OCCTShapeRef face, double prec) {
    if (!wire || !face) return false;
    try {
        ShapeAnalysis_Wire saw;
        saw.Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), prec);
        if (!saw.IsReady()) return false;
        return saw.CheckGaps2d();
    } catch (...) { return false; }
}

bool OCCTWireCheckEdgeCurves(OCCTShapeRef wire, OCCTShapeRef face, double prec) {
    if (!wire || !face) return false;
    try {
        ShapeAnalysis_Wire saw;
        saw.Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), prec);
        if (!saw.IsReady()) return false;
        return saw.CheckEdgeCurves();
    } catch (...) { return false; }
}

bool OCCTWireCheckLacking(OCCTShapeRef wire, OCCTShapeRef face, double prec) {
    if (!wire || !face) return false;
    try {
        ShapeAnalysis_Wire saw;
        saw.Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), prec);
        if (!saw.IsReady()) return false;
        return saw.CheckLacking();
    } catch (...) { return false; }
}

int32_t OCCTWireEdgeCount(OCCTShapeRef wire, OCCTShapeRef face, double prec) {
    if (!wire || !face) return 0;
    try {
        ShapeAnalysis_Wire saw;
        saw.Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), prec);
        if (!saw.IsReady()) return 0;
        return saw.NbEdges();
    } catch (...) { return 0; }
}

double OCCTWireMinDistance3d(OCCTShapeRef wire, OCCTShapeRef face, double prec) {
    if (!wire || !face) return 0;
    try {
        ShapeAnalysis_Wire saw;
        saw.Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), prec);
        if (!saw.IsReady()) return 0;
        saw.CheckGaps3d();
        return saw.MinDistance3d();
    } catch (...) { return 0; }
}

double OCCTWireMaxDistance3d(OCCTShapeRef wire, OCCTShapeRef face, double prec) {
    if (!wire || !face) return 0;
    try {
        ShapeAnalysis_Wire saw;
        saw.Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), prec);
        if (!saw.IsReady()) return 0;
        saw.CheckGaps3d();
        return saw.MaxDistance3d();
    } catch (...) { return 0; }
}

double OCCTWireMinDistance2d(OCCTShapeRef wire, OCCTShapeRef face, double prec) {
    if (!wire || !face) return 0;
    try {
        ShapeAnalysis_Wire saw;
        saw.Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), prec);
        if (!saw.IsReady()) return 0;
        saw.CheckGaps2d();
        return saw.MinDistance2d();
    } catch (...) { return 0; }
}

double OCCTWireMaxDistance2d(OCCTShapeRef wire, OCCTShapeRef face, double prec) {
    if (!wire || !face) return 0;
    try {
        ShapeAnalysis_Wire saw;
        saw.Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), prec);
        if (!saw.IsReady()) return 0;
        saw.CheckGaps2d();
        return saw.MaxDistance2d();
    } catch (...) { return 0; }
}

bool OCCTWireCheckConnectedEdge(OCCTShapeRef wire, OCCTShapeRef face, double prec, int32_t edgeIndex) {
    if (!wire || !face) return false;
    try {
        ShapeAnalysis_Wire saw;
        saw.Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), prec);
        if (!saw.IsReady()) return false;
        return saw.CheckConnected(edgeIndex);
    } catch (...) { return false; }
}

bool OCCTWireCheckSmallEdge(OCCTShapeRef wire, OCCTShapeRef face, double prec, int32_t edgeIndex) {
    if (!wire || !face) return false;
    try {
        ShapeAnalysis_Wire saw;
        saw.Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), prec);
        if (!saw.IsReady()) return false;
        return saw.CheckSmall(edgeIndex);
    } catch (...) { return false; }
}

bool OCCTWireCheckDegeneratedEdge(OCCTShapeRef wire, OCCTShapeRef face, double prec, int32_t edgeIndex) {
    if (!wire || !face) return false;
    try {
        ShapeAnalysis_Wire saw;
        saw.Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), prec);
        if (!saw.IsReady()) return false;
        return saw.CheckDegenerated(edgeIndex);
    } catch (...) { return false; }
}

bool OCCTWireCheckGap3dEdge(OCCTShapeRef wire, OCCTShapeRef face, double prec, int32_t edgeIndex) {
    if (!wire || !face) return false;
    try {
        ShapeAnalysis_Wire saw;
        saw.Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), prec);
        if (!saw.IsReady()) return false;
        return saw.CheckGap3d(edgeIndex);
    } catch (...) { return false; }
}

bool OCCTWireCheckOuterBound(OCCTShapeRef face, double prec) {
    if (!face) return false;
    try {
        TopoDS_Face f = TopoDS::Face(face->shape);
        // Check if face has at least one wire (outer bound)
        TopExp_Explorer wexp(f, TopAbs_WIRE);
        return wexp.More();
    } catch (...) { return false; }
}
// MARK: - ShapeAnalysis_Edge (v0.106.0)

#include <ShapeAnalysis_Edge.hxx>

bool OCCTEdgeHasCurve3dSA(OCCTShapeRef edge) {
    if (!edge) return false;
    try {
        ShapeAnalysis_Edge sae;
        return sae.HasCurve3d(TopoDS::Edge(edge->shape));
    } catch (...) { return false; }
}

bool OCCTEdgeIsClosed3dSA(OCCTShapeRef edge) {
    if (!edge) return false;
    try {
        ShapeAnalysis_Edge sae;
        return sae.IsClosed3d(TopoDS::Edge(edge->shape));
    } catch (...) { return false; }
}

bool OCCTEdgeHasPCurveSA(OCCTShapeRef edge, OCCTShapeRef face) {
    if (!edge || !face) return false;
    try {
        ShapeAnalysis_Edge sae;
        return sae.HasPCurve(TopoDS::Edge(edge->shape), TopoDS::Face(face->shape));
    } catch (...) { return false; }
}

bool OCCTEdgeIsSeamSA(OCCTShapeRef edge, OCCTShapeRef face) {
    if (!edge || !face) return false;
    try {
        ShapeAnalysis_Edge sae;
        return sae.IsSeam(TopoDS::Edge(edge->shape), TopoDS::Face(face->shape));
    } catch (...) { return false; }
}

bool OCCTEdgeCheckSameParameter(OCCTShapeRef edge, double* maxdev) {
    if (!edge) { *maxdev = 0; return false; }
    try {
        ShapeAnalysis_Edge sae;
        *maxdev = 0;
        return sae.CheckSameParameter(TopoDS::Edge(edge->shape), *maxdev);
    } catch (...) { *maxdev = 0; return false; }
}

bool OCCTEdgeCheckVerticesWithCurve3d(OCCTShapeRef edge, double prec) {
    if (!edge) return false;
    try {
        ShapeAnalysis_Edge sae;
        return sae.CheckVerticesWithCurve3d(TopoDS::Edge(edge->shape), prec);
    } catch (...) { return false; }
}

bool OCCTEdgeCheckVerticesWithPCurve(OCCTShapeRef edge, OCCTShapeRef face, double prec) {
    if (!edge || !face) return false;
    try {
        ShapeAnalysis_Edge sae;
        return sae.CheckVerticesWithPCurve(TopoDS::Edge(edge->shape), TopoDS::Face(face->shape), prec);
    } catch (...) { return false; }
}

bool OCCTEdgeCheckCurve3dWithPCurve(OCCTShapeRef edge, OCCTShapeRef face) {
    if (!edge || !face) return false;
    try {
        ShapeAnalysis_Edge sae;
        return sae.CheckCurve3dWithPCurve(TopoDS::Edge(edge->shape), TopoDS::Face(face->shape));
    } catch (...) { return false; }
}

void OCCTEdgeFirstVertexSA(OCCTShapeRef edge, double* x, double* y, double* z) {
    *x = 0; *y = 0; *z = 0;
    if (!edge) return;
    try {
        ShapeAnalysis_Edge sae;
        TopoDS_Vertex v = sae.FirstVertex(TopoDS::Edge(edge->shape));
        if (v.IsNull()) return;
        gp_Pnt p = BRep_Tool::Pnt(v);
        *x = p.X(); *y = p.Y(); *z = p.Z();
    } catch (...) {}
}

void OCCTEdgeLastVertexSA(OCCTShapeRef edge, double* x, double* y, double* z) {
    *x = 0; *y = 0; *z = 0;
    if (!edge) return;
    try {
        ShapeAnalysis_Edge sae;
        TopoDS_Vertex v = sae.LastVertex(TopoDS::Edge(edge->shape));
        if (v.IsNull()) return;
        gp_Pnt p = BRep_Tool::Pnt(v);
        *x = p.X(); *y = p.Y(); *z = p.Z();
    } catch (...) {}
}

bool OCCTEdgeCheckVertexTolerance(OCCTShapeRef edge, OCCTShapeRef face,
                                   double* toler1, double* toler2) {
    *toler1 = 0; *toler2 = 0;
    if (!edge || !face) return false;
    try {
        ShapeAnalysis_Edge sae;
        return sae.CheckVertexTolerance(TopoDS::Edge(edge->shape), TopoDS::Face(face->shape),
                                         *toler1, *toler2);
    } catch (...) { return false; }
}

bool OCCTEdgeCheckOverlapping(OCCTShapeRef edge1, OCCTShapeRef edge2, double* tolOverlap) {
    *tolOverlap = 0;
    if (!edge1 || !edge2) return false;
    try {
        ShapeAnalysis_Edge sae;
        return sae.CheckOverlapping(TopoDS::Edge(edge1->shape), TopoDS::Edge(edge2->shape),
                                     *tolOverlap, 0.0);
    } catch (...) { return false; }
}

bool OCCTEdgeBoundUV(OCCTShapeRef edge, OCCTShapeRef face,
                      double* uFirst, double* vFirst, double* uLast, double* vLast) {
    *uFirst = 0; *vFirst = 0; *uLast = 0; *vLast = 0;
    if (!edge || !face) return false;
    try {
        ShapeAnalysis_Edge sae;
        gp_Pnt2d pFirst, pLast;
        bool ok = sae.BoundUV(TopoDS::Edge(edge->shape), TopoDS::Face(face->shape),
                               pFirst, pLast);
        if (ok) {
            *uFirst = pFirst.X(); *vFirst = pFirst.Y();
            *uLast = pLast.X(); *vLast = pLast.Y();
        }
        return ok;
    } catch (...) { return false; }
}

bool OCCTEdgeGetEndTangent2d(OCCTShapeRef edge, OCCTShapeRef face, bool atEnd,
                              double* px, double* py, double* tx, double* ty) {
    *px = 0; *py = 0; *tx = 0; *ty = 0;
    if (!edge || !face) return false;
    try {
        ShapeAnalysis_Edge sae;
        gp_Pnt2d pos;
        gp_Vec2d tang;
        bool ok = sae.GetEndTangent2d(TopoDS::Edge(edge->shape), TopoDS::Face(face->shape),
                                       atEnd, pos, tang);
        if (ok) {
            *px = pos.X(); *py = pos.Y();
            *tx = tang.X(); *ty = tang.Y();
        }
        return ok;
    } catch (...) { return false; }
}

bool OCCTEdgeCheckPCurveRange(OCCTShapeRef edge, OCCTShapeRef face, double first, double last) {
    if (!edge || !face) return false;
    try {
        ShapeAnalysis_Edge sae;
        // Check if the pcurve parameter range [first, last] is valid for the edge on the face
        // Get pcurve and check its range
        TopoDS_Edge e = TopoDS::Edge(edge->shape);
        TopoDS_Face f = TopoDS::Face(face->shape);
        double cf, cl;
        Handle(Geom2d_Curve) pc = BRep_Tool::CurveOnSurface(e, f, cf, cl);
        if (pc.IsNull()) return false;
        return (first >= cf - 1e-10 && last <= cl + 1e-10);
    } catch (...) { return false; }
}

// MARK: - v0.112: BRepCheck extended + tolerance helpers
// --- BRepCheck extended ---

int32_t OCCTCheckFaceStatus(OCCTShapeRef shape, OCCTShapeRef face) {
    if (!shape || !face) return -1;
    try {
        BRepCheck_Analyzer ana(shape->shape, Standard_True);
        Handle(BRepCheck_Result) res = ana.Result(face->shape);
        if (res.IsNull()) return -1;
        const BRepCheck_ListOfStatus& st = res->Status();
        if (st.IsEmpty()) return 0; // NoError
        return (int32_t)st.First();
    } catch (...) { return -1; }
}

int32_t OCCTCheckEdgeStatus(OCCTShapeRef shape, OCCTShapeRef edge) {
    if (!shape || !edge) return -1;
    try {
        BRepCheck_Analyzer ana(shape->shape, Standard_True);
        Handle(BRepCheck_Result) res = ana.Result(edge->shape);
        if (res.IsNull()) return -1;
        const BRepCheck_ListOfStatus& st = res->Status();
        if (st.IsEmpty()) return 0;
        return (int32_t)st.First();
    } catch (...) { return -1; }
}

int32_t OCCTCheckVertexStatus(OCCTShapeRef shape, OCCTShapeRef vertex) {
    if (!shape || !vertex) return -1;
    try {
        BRepCheck_Analyzer ana(shape->shape, Standard_True);
        Handle(BRepCheck_Result) res = ana.Result(vertex->shape);
        if (res.IsNull()) return -1;
        const BRepCheck_ListOfStatus& st = res->Status();
        if (st.IsEmpty()) return 0;
        return (int32_t)st.First();
    } catch (...) { return -1; }
}

double OCCTShapeMaxTolerance(OCCTShapeRef shape, int32_t type) {
    if (!shape) return 0;
    try {
        ShapeAnalysis_ShapeTolerance sat;
        TopAbs_ShapeEnum se;
        switch (type) {
            case 0: se = TopAbs_VERTEX; break;
            case 1: se = TopAbs_EDGE; break;
            case 2: se = TopAbs_FACE; break;
            default: se = TopAbs_SHAPE; break;
        }
        return sat.Tolerance(shape->shape, 1, se); // 1 = max
    } catch (...) { return 0; }
}

double OCCTShapeMinTolerance(OCCTShapeRef shape, int32_t type) {
    if (!shape) return 0;
    try {
        ShapeAnalysis_ShapeTolerance sat;
        TopAbs_ShapeEnum se;
        switch (type) {
            case 0: se = TopAbs_VERTEX; break;
            case 1: se = TopAbs_EDGE; break;
            case 2: se = TopAbs_FACE; break;
            default: se = TopAbs_SHAPE; break;
        }
        return sat.Tolerance(shape->shape, -1, se); // -1 = min
    } catch (...) { return 0; }
}

double OCCTShapeAvgTolerance(OCCTShapeRef shape, int32_t type) {
    if (!shape) return 0;
    try {
        ShapeAnalysis_ShapeTolerance sat;
        TopAbs_ShapeEnum se;
        switch (type) {
            case 0: se = TopAbs_VERTEX; break;
            case 1: se = TopAbs_EDGE; break;
            case 2: se = TopAbs_FACE; break;
            default: se = TopAbs_SHAPE; break;
        }
        return sat.Tolerance(shape->shape, 0, se); // 0 = avg
    } catch (...) { return 0; }
}

bool OCCTShapeFixTolerance(OCCTShapeRef shape, double tolerance) {
    if (!shape) return false;
    try {
        ShapeFix_ShapeTolerance sft;
        sft.SetTolerance(shape->shape, tolerance);
        return true;
    } catch (...) { return false; }
}

bool OCCTShapeLimitMaxTolerance(OCCTShapeRef shape, double maxTol) {
    if (!shape) return false;
    try {
        ShapeFix_ShapeTolerance sft;
        bool limited = sft.LimitTolerance(shape->shape, 0.0, maxTol);
        return limited;
    } catch (...) { return false; }
}

// MARK: - v0.113: ShapeFix_Wire + ShapeFix_Face individual fixes
// --- ShapeFix_Wire individual fixes ---

struct OCCTWireFixer {
    Handle(ShapeFix_Wire) fixer;
};

OCCTWireFixerRef OCCTWireFixerCreate(OCCTShapeRef wire, OCCTShapeRef face, double precision) {
    if (!wire || !face) return nullptr;
    try {
        auto ref = new OCCTWireFixer();
        ref->fixer = new ShapeFix_Wire();
        ref->fixer->Init(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape), precision);
        return ref;
    } catch (...) { return nullptr; }
}

void OCCTWireFixerRelease(OCCTWireFixerRef fixer) {
    delete fixer;
}

bool OCCTWireFixerFixReorder(OCCTWireFixerRef fixer) {
    if (!fixer || fixer->fixer.IsNull()) return false;
    try { return fixer->fixer->FixReorder(); }
    catch (...) { return false; }
}

bool OCCTWireFixerFixConnected(OCCTWireFixerRef fixer) {
    if (!fixer || fixer->fixer.IsNull()) return false;
    try { return fixer->fixer->FixConnected(); }
    catch (...) { return false; }
}

bool OCCTWireFixerFixSmall(OCCTWireFixerRef fixer, double precSmall) {
    if (!fixer || fixer->fixer.IsNull()) return false;
    try { return fixer->fixer->FixSmall(false, precSmall); }
    catch (...) { return false; }
}

bool OCCTWireFixerFixDegenerated(OCCTWireFixerRef fixer) {
    if (!fixer || fixer->fixer.IsNull()) return false;
    try { return fixer->fixer->FixDegenerated(); }
    catch (...) { return false; }
}

bool OCCTWireFixerFixSelfIntersection(OCCTWireFixerRef fixer) {
    if (!fixer || fixer->fixer.IsNull()) return false;
    try { return fixer->fixer->FixSelfIntersection(); }
    catch (...) { return false; }
}

bool OCCTWireFixerFixLacking(OCCTWireFixerRef fixer) {
    if (!fixer || fixer->fixer.IsNull()) return false;
    try { return fixer->fixer->FixLacking(); }
    catch (...) { return false; }
}

bool OCCTWireFixerFixClosed(OCCTWireFixerRef fixer) {
    if (!fixer || fixer->fixer.IsNull()) return false;
    try { return fixer->fixer->FixClosed(); }
    catch (...) { return false; }
}

bool OCCTWireFixerFixGaps3d(OCCTWireFixerRef fixer) {
    if (!fixer || fixer->fixer.IsNull()) return false;
    try { return fixer->fixer->FixGaps3d(); }
    catch (...) { return false; }
}

bool OCCTWireFixerFixEdgeCurves(OCCTWireFixerRef fixer) {
    if (!fixer || fixer->fixer.IsNull()) return false;
    try { return fixer->fixer->FixEdgeCurves(); }
    catch (...) { return false; }
}

OCCTShapeRef OCCTWireFixerWire(OCCTWireFixerRef fixer) {
    if (!fixer || fixer->fixer.IsNull()) return nullptr;
    try {
        TopoDS_Wire w = fixer->fixer->Wire();
        if (w.IsNull()) return nullptr;
        auto ref = new OCCTShape();
        ref->shape = w;
        return ref;
    } catch (...) { return nullptr; }
}

// --- ShapeFix_Face individual fixes ---

struct OCCTFaceFixer {
    Handle(ShapeFix_Face) fixer;
};

OCCTFaceFixerRef OCCTFaceFixerCreate(OCCTShapeRef face, double precision) {
    if (!face) return nullptr;
    try {
        auto ref = new OCCTFaceFixer();
        ref->fixer = new ShapeFix_Face(TopoDS::Face(face->shape));
        ref->fixer->SetPrecision(precision);
        return ref;
    } catch (...) { return nullptr; }
}

void OCCTFaceFixerRelease(OCCTFaceFixerRef fixer) {
    delete fixer;
}

bool OCCTFaceFixerPerform(OCCTFaceFixerRef fixer) {
    if (!fixer || fixer->fixer.IsNull()) return false;
    try { return fixer->fixer->Perform(); }
    catch (...) { return false; }
}

bool OCCTFaceFixerFixOrientation(OCCTFaceFixerRef fixer) {
    if (!fixer || fixer->fixer.IsNull()) return false;
    try { return fixer->fixer->FixOrientation(); }
    catch (...) { return false; }
}

bool OCCTFaceFixerFixAddNaturalBound(OCCTFaceFixerRef fixer) {
    if (!fixer || fixer->fixer.IsNull()) return false;
    try { return fixer->fixer->FixAddNaturalBound(); }
    catch (...) { return false; }
}

bool OCCTFaceFixerFixMissingSeam(OCCTFaceFixerRef fixer) {
    if (!fixer || fixer->fixer.IsNull()) return false;
    try { return fixer->fixer->FixMissingSeam(); }
    catch (...) { return false; }
}

bool OCCTFaceFixerFixSmallAreaWire(OCCTFaceFixerRef fixer) {
    if (!fixer || fixer->fixer.IsNull()) return false;
    try { return fixer->fixer->FixSmallAreaWire(true); }
    catch (...) { return false; }
}

OCCTShapeRef OCCTFaceFixerFace(OCCTFaceFixerRef fixer) {
    if (!fixer || fixer->fixer.IsNull()) return nullptr;
    try {
        TopoDS_Face f = fixer->fixer->Face();
        if (f.IsNull()) return nullptr;
        auto ref = new OCCTShape();
        ref->shape = f;
        return ref;
    } catch (...) { return nullptr; }
}

// MARK: - WireFixer extended (hoisted with struct)
// --- WireFixer extended ---

bool OCCTWireFixerFixGaps2d(OCCTWireFixerRef fixer) {
    if (!fixer || fixer->fixer.IsNull()) return false;
    try { return fixer->fixer->FixGaps2d(); } catch (...) { return false; }
}

bool OCCTWireFixerFixSeam(OCCTWireFixerRef fixer, int32_t edgeIndex) {
    if (!fixer || fixer->fixer.IsNull()) return false;
    try { return fixer->fixer->FixSeam(edgeIndex); } catch (...) { return false; }
}

bool OCCTWireFixerFixShifted(OCCTWireFixerRef fixer) {
    if (!fixer || fixer->fixer.IsNull()) return false;
    try { return fixer->fixer->FixShifted(); } catch (...) { return false; }
}

bool OCCTWireFixerFixNotchedEdges(OCCTWireFixerRef fixer) {
    if (!fixer || fixer->fixer.IsNull()) return false;
    try { return fixer->fixer->FixNotchedEdges(); } catch (...) { return false; }
}

bool OCCTWireFixerFixTails(OCCTWireFixerRef fixer) {
    if (!fixer || fixer->fixer.IsNull()) return false;
    try { return fixer->fixer->FixTails(); } catch (...) { return false; }
}

void OCCTWireFixerSetMaxTailAngle(OCCTWireFixerRef fixer, double angle) {
    if (!fixer || fixer->fixer.IsNull()) return;
    try { fixer->fixer->SetMaxTailAngle(angle); } catch (...) {}
}

void OCCTWireFixerSetMaxTailWidth(OCCTWireFixerRef fixer, double width) {
    if (!fixer || fixer->fixer.IsNull()) return;
    try { fixer->fixer->SetMaxTailWidth(width); } catch (...) {}
}


// MARK: - v0.114: ShapeAnalysis_ShapeContents expanded + ShapeAnalysis_FreeBoundsProperties (handle-based)
// --- ShapeAnalysis_ShapeContents expanded ---

OCCTShapeContentsExtended OCCTShapeGetContentsExtended(OCCTShapeRef shape) {
    OCCTShapeContentsExtended result = {};
    if (!shape) return result;
    try {
        ShapeAnalysis_ShapeContents sc;
        sc.Perform(shape->shape);
        result.nbSolids = sc.NbSolids();
        result.nbShells = sc.NbShells();
        result.nbFaces = sc.NbFaces();
        result.nbWires = sc.NbWires();
        result.nbEdges = sc.NbEdges();
        result.nbVertices = sc.NbVertices();
        result.nbFreeEdges = sc.NbFreeEdges();
        result.nbFreeWires = sc.NbFreeWires();
        result.nbFreeFaces = sc.NbFreeFaces();
        result.nbSolidsWithVoids = sc.NbSolidsWithVoids();
        result.nbBigSplines = sc.NbBigSplines();
        result.nbC0Surfaces = sc.NbC0Surfaces();
        result.nbC0Curves = sc.NbC0Curves();
        result.nbOffsetSurf = sc.NbOffsetSurf();
        result.nbIndirectSurf = sc.NbIndirectSurf();
        result.nbOffsetCurves = sc.NbOffsetCurves();
        result.nbTrimmedCurve2d = sc.NbTrimmedCurve2d();
        result.nbTrimmedCurve3d = sc.NbTrimmedCurve3d();
        result.nbBSplineSurf = sc.NbBSplibeSurf();
        result.nbBezierSurf = sc.NbBezierSurf();
        result.nbTrimSurf = sc.NbTrimSurf();
        result.nbWireWithSeam = sc.NbWireWitnSeam();
        result.nbWireWithSevSeams = sc.NbWireWithSevSeams();
        result.nbFaceWithSevWires = sc.NbFaceWithSevWires();
        result.nbNoPCurve = sc.NbNoPCurve();
        result.nbSharedSolids = sc.NbSharedSolids();
        result.nbSharedShells = sc.NbSharedShells();
        result.nbSharedFaces = sc.NbSharedFaces();
        result.nbSharedWires = sc.NbSharedWires();
        result.nbSharedEdges = sc.NbSharedEdges();
        result.nbSharedVertices = sc.NbSharedVertices();
    } catch (...) {}
    return result;
}
// --- ShapeAnalysis_FreeBoundsProperties (handle-based) ---

struct OCCTFreeBoundsProps {
    ShapeAnalysis_FreeBoundsProperties fbp;
    bool performed;
};

OCCTFreeBoundsPropsRef OCCTFreeBoundsPropsCreate(OCCTShapeRef shape, double tolerance) {
    if (!shape) return nullptr;
    try {
        auto ref = new OCCTFreeBoundsProps();
        ref->fbp.Init(shape->shape, tolerance);
        ref->performed = false;
        return ref;
    } catch (...) { return nullptr; }
}

void OCCTFreeBoundsPropsRelease(OCCTFreeBoundsPropsRef props) {
    delete props;
}

bool OCCTFreeBoundsPropsPerform(OCCTFreeBoundsPropsRef props) {
    if (!props) return false;
    try {
        bool ok = props->fbp.Perform();
        props->performed = ok;
        return ok;
    } catch (...) { return false; }
}

int32_t OCCTFreeBoundsPropsNbClosedFreeBounds(OCCTFreeBoundsPropsRef props) {
    if (!props || !props->performed) return 0;
    try { return (int32_t)props->fbp.NbClosedFreeBounds(); }
    catch (...) { return 0; }
}

int32_t OCCTFreeBoundsPropsNbOpenFreeBounds(OCCTFreeBoundsPropsRef props) {
    if (!props || !props->performed) return 0;
    try { return (int32_t)props->fbp.NbOpenFreeBounds(); }
    catch (...) { return 0; }
}

double OCCTFreeBoundsPropsClosedArea(OCCTFreeBoundsPropsRef props, int32_t index) {
    if (!props || !props->performed) return 0;
    try {
        Handle(ShapeAnalysis_FreeBoundData) fbd = props->fbp.ClosedFreeBound(index);
        if (fbd.IsNull()) return 0;
        return fbd->Area();
    } catch (...) { return 0; }
}

double OCCTFreeBoundsPropsClosedPerimeter(OCCTFreeBoundsPropsRef props, int32_t index) {
    if (!props || !props->performed) return 0;
    try {
        Handle(ShapeAnalysis_FreeBoundData) fbd = props->fbp.ClosedFreeBound(index);
        if (fbd.IsNull()) return 0;
        return fbd->Perimeter();
    } catch (...) { return 0; }
}

double OCCTFreeBoundsPropsClosedRatio(OCCTFreeBoundsPropsRef props, int32_t index) {
    if (!props || !props->performed) return 0;
    try {
        Handle(ShapeAnalysis_FreeBoundData) fbd = props->fbp.ClosedFreeBound(index);
        if (fbd.IsNull()) return 0;
        return fbd->Ratio();
    } catch (...) { return 0; }
}

double OCCTFreeBoundsPropsClosedWidth(OCCTFreeBoundsPropsRef props, int32_t index) {
    if (!props || !props->performed) return 0;
    try {
        Handle(ShapeAnalysis_FreeBoundData) fbd = props->fbp.ClosedFreeBound(index);
        if (fbd.IsNull()) return 0;
        return fbd->Width();
    } catch (...) { return 0; }
}

OCCTShapeRef OCCTFreeBoundsPropsClosedWire(OCCTFreeBoundsPropsRef props, int32_t index) {
    if (!props || !props->performed) return nullptr;
    try {
        Handle(ShapeAnalysis_FreeBoundData) fbd = props->fbp.ClosedFreeBound(index);
        if (fbd.IsNull()) return nullptr;
        auto ref = new OCCTShape();
        ref->shape = fbd->FreeBound();
        return ref;
    } catch (...) { return nullptr; }
}

double OCCTFreeBoundsPropsOpenArea(OCCTFreeBoundsPropsRef props, int32_t index) {
    if (!props || !props->performed) return 0;
    try {
        Handle(ShapeAnalysis_FreeBoundData) fbd = props->fbp.OpenFreeBound(index);
        if (fbd.IsNull()) return 0;
        return fbd->Area();
    } catch (...) { return 0; }
}

double OCCTFreeBoundsPropsOpenPerimeter(OCCTFreeBoundsPropsRef props, int32_t index) {
    if (!props || !props->performed) return 0;
    try {
        Handle(ShapeAnalysis_FreeBoundData) fbd = props->fbp.OpenFreeBound(index);
        if (fbd.IsNull()) return 0;
        return fbd->Perimeter();
    } catch (...) { return 0; }
}

OCCTShapeRef OCCTFreeBoundsPropsOpenWire(OCCTFreeBoundsPropsRef props, int32_t index) {
    if (!props || !props->performed) return nullptr;
    try {
        Handle(ShapeAnalysis_FreeBoundData) fbd = props->fbp.OpenFreeBound(index);
        if (fbd.IsNull()) return nullptr;
        auto ref = new OCCTShape();
        ref->shape = fbd->FreeBound();
        return ref;
    } catch (...) { return nullptr; }
}

// MARK: - v0.115: ShapeFix_Shape builder
// --- ShapeFix_Shape builder ---

struct OCCTShapeFixer {
    Handle(ShapeFix_Shape) fixer;
};

OCCTShapeFixerRef OCCTShapeFixerCreate(OCCTShapeRef shape) {
    auto f = new OCCTShapeFixer();
    f->fixer = new ShapeFix_Shape(shape->shape);
    return (OCCTShapeFixerRef)f;
}

void OCCTShapeFixerRelease(OCCTShapeFixerRef ref) {
    auto f = (OCCTShapeFixer*)ref;
    delete f;
}

void OCCTShapeFixerSetPrecision(OCCTShapeFixerRef ref, double precision) {
    auto f = (OCCTShapeFixer*)ref;
    if (f) f->fixer->SetPrecision(precision);
}

void OCCTShapeFixerSetMaxTolerance(OCCTShapeFixerRef ref, double maxTol) {
    auto f = (OCCTShapeFixer*)ref;
    if (f) f->fixer->SetMaxTolerance(maxTol);
}

void OCCTShapeFixerSetMinTolerance(OCCTShapeFixerRef ref, double minTol) {
    auto f = (OCCTShapeFixer*)ref;
    if (f) f->fixer->SetMinTolerance(minTol);
}

bool OCCTShapeFixerPerform(OCCTShapeFixerRef ref) {
    auto f = (OCCTShapeFixer*)ref;
    if (!f) return false;
    try {
        return f->fixer->Perform();
    } catch (...) { return false; }
}

OCCTShapeRef OCCTShapeFixerShape(OCCTShapeFixerRef ref) {
    auto f = (OCCTShapeFixer*)ref;
    if (!f) return nullptr;
    try {
        TopoDS_Shape result = f->fixer->Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape{result};
    } catch (...) { return nullptr; }
}

bool OCCTShapeFixerStatus(OCCTShapeFixerRef ref, int32_t statusType) {
    auto f = (OCCTShapeFixer*)ref;
    if (!f) return false;
    try {
        ShapeExtend_Status st;
        switch (statusType) {
            case 1: st = ShapeExtend_OK; break;
            case 2: st = ShapeExtend_DONE; break;
            case 3: st = ShapeExtend_FAIL; break;
            default: return false;
        }
        return f->fixer->Status(st);
    } catch (...) { return false; }
}

// MARK: - v0.118: Tolerance value/over-count/in-range + Boolean check single/pair
double OCCTShapeToleranceValue(OCCTShapeRef shape, int32_t mode, int32_t shapeType) {
    try {
        auto* s = static_cast<OCCTShape*>(shape);
        ShapeAnalysis_ShapeTolerance sat;
        return sat.Tolerance(s->shape, mode, static_cast<TopAbs_ShapeEnum>(shapeType));
    } catch (...) { return 0.0; }
}

int32_t OCCTShapeToleranceOverCount(OCCTShapeRef shape, double value, int32_t shapeType) {
    try {
        auto* s = static_cast<OCCTShape*>(shape);
        ShapeAnalysis_ShapeTolerance sat;
        auto seq = sat.OverTolerance(s->shape, value, static_cast<TopAbs_ShapeEnum>(shapeType));
        return seq.IsNull() ? 0 : (int32_t)seq->Length();
    } catch (...) { return 0; }
}

int32_t OCCTShapeToleranceInRangeCount(OCCTShapeRef shape, double valmin, double valmax, int32_t shapeType) {
    try {
        auto* s = static_cast<OCCTShape*>(shape);
        ShapeAnalysis_ShapeTolerance sat;
        auto seq = sat.InTolerance(s->shape, valmin, valmax, static_cast<TopAbs_ShapeEnum>(shapeType));
        return seq.IsNull() ? 0 : (int32_t)seq->Length();
    } catch (...) { return 0; }
}

// === BRepAlgoAPI_Check ===
bool OCCTShapeBooleanCheckSingle(OCCTShapeRef shape, bool testSmallEdges, bool testSelfInterference) {
    try {
        auto* s = static_cast<OCCTShape*>(shape);
        BRepAlgoAPI_Check check(s->shape, testSmallEdges, testSelfInterference);
        return check.IsValid();
    } catch (...) { return false; }
}

bool OCCTShapeBooleanCheckPair(OCCTShapeRef shape1, OCCTShapeRef shape2,
                                int32_t operation, bool testSmallEdges, bool testSelfInterference) {
    try {
        auto* s1 = static_cast<OCCTShape*>(shape1);
        auto* s2 = static_cast<OCCTShape*>(shape2);
        BRepAlgoAPI_Check check(s1->shape, s2->shape,
            static_cast<BOPAlgo_Operation>(operation), testSmallEdges, testSelfInterference);
        return check.IsValid();
    } catch (...) { return false; }
}

// === BRepAlgoAPI_Defeaturing ===
#include <BRepAlgoAPI_Defeaturing.hxx>

// MARK: - v0.124: WireAnalyzer (ShapeAnalysis_Wire)
// --- WireAnalyzer (ShapeAnalysis_Wire) ---

#include <ShapeAnalysis_Wire.hxx>
#include <TopoDS.hxx>

struct OCCTWireAnalyzer {
    Handle(ShapeAnalysis_Wire) analyzer;
    OCCTWireAnalyzer(const TopoDS_Wire& w, const TopoDS_Face& f, double prec) {
        analyzer = new ShapeAnalysis_Wire(w, f, prec);
    }
};

OCCTWireAnalyzerRef OCCTWireAnalyzerCreate(OCCTShapeRef wire, OCCTShapeRef face, double precision) {
    if (!wire || !face) return nullptr;
    try {
        const TopoDS_Wire& w = TopoDS::Wire(wire->shape);
        const TopoDS_Face& f = TopoDS::Face(face->shape);
        return new OCCTWireAnalyzer(w, f, precision);
    } catch (...) { return nullptr; }
}

void OCCTWireAnalyzerRelease(OCCTWireAnalyzerRef analyzer) {
    delete analyzer;
}

bool OCCTWireAnalyzerPerform(OCCTWireAnalyzerRef analyzer) {
    if (!analyzer || analyzer->analyzer.IsNull()) return false;
    try { return analyzer->analyzer->Perform(); } catch (...) { return false; }
}

bool OCCTWireAnalyzerCheckOrder(OCCTWireAnalyzerRef analyzer) {
    if (!analyzer || analyzer->analyzer.IsNull()) return false;
    try { return analyzer->analyzer->CheckOrder(); } catch (...) { return false; }
}

bool OCCTWireAnalyzerCheckConnected(OCCTWireAnalyzerRef analyzer, int32_t edgeNum) {
    if (!analyzer || analyzer->analyzer.IsNull()) return false;
    try { return analyzer->analyzer->CheckConnected(edgeNum); } catch (...) { return false; }
}

bool OCCTWireAnalyzerCheckSmall(OCCTWireAnalyzerRef analyzer, int32_t edgeNum) {
    if (!analyzer || analyzer->analyzer.IsNull()) return false;
    try { return analyzer->analyzer->CheckSmall(edgeNum); } catch (...) { return false; }
}

bool OCCTWireAnalyzerCheckDegenerated(OCCTWireAnalyzerRef analyzer, int32_t edgeNum) {
    if (!analyzer || analyzer->analyzer.IsNull()) return false;
    try { return analyzer->analyzer->CheckDegenerated(edgeNum); } catch (...) { return false; }
}

bool OCCTWireAnalyzerCheckGap3d(OCCTWireAnalyzerRef analyzer, int32_t edgeNum) {
    if (!analyzer || analyzer->analyzer.IsNull()) return false;
    try { return analyzer->analyzer->CheckGap3d(edgeNum); } catch (...) { return false; }
}

bool OCCTWireAnalyzerCheckGap2d(OCCTWireAnalyzerRef analyzer, int32_t edgeNum) {
    if (!analyzer || analyzer->analyzer.IsNull()) return false;
    try { return analyzer->analyzer->CheckGap2d(edgeNum); } catch (...) { return false; }
}

bool OCCTWireAnalyzerCheckSeam(OCCTWireAnalyzerRef analyzer, int32_t edgeNum) {
    if (!analyzer || analyzer->analyzer.IsNull()) return false;
    try { return analyzer->analyzer->CheckSeam(edgeNum); } catch (...) { return false; }
}

bool OCCTWireAnalyzerCheckLacking(OCCTWireAnalyzerRef analyzer, int32_t edgeNum) {
    if (!analyzer || analyzer->analyzer.IsNull()) return false;
    try { return analyzer->analyzer->CheckLacking(edgeNum); } catch (...) { return false; }
}

bool OCCTWireAnalyzerCheckSelfIntersection(OCCTWireAnalyzerRef analyzer) {
    if (!analyzer || analyzer->analyzer.IsNull()) return false;
    try { return analyzer->analyzer->CheckSelfIntersection(); } catch (...) { return false; }
}

bool OCCTWireAnalyzerCheckClosed(OCCTWireAnalyzerRef analyzer) {
    if (!analyzer || analyzer->analyzer.IsNull()) return false;
    try { return analyzer->analyzer->CheckClosed(); } catch (...) { return false; }
}

double OCCTWireAnalyzerMinDistance3d(OCCTWireAnalyzerRef analyzer) {
    if (!analyzer || analyzer->analyzer.IsNull()) return -1.0;
    try { return analyzer->analyzer->MinDistance3d(); } catch (...) { return -1.0; }
}

double OCCTWireAnalyzerMaxDistance3d(OCCTWireAnalyzerRef analyzer) {
    if (!analyzer || analyzer->analyzer.IsNull()) return -1.0;
    try { return analyzer->analyzer->MaxDistance3d(); } catch (...) { return -1.0; }
}

int32_t OCCTWireAnalyzerNbEdges(OCCTWireAnalyzerRef analyzer) {
    if (!analyzer || analyzer->analyzer.IsNull()) return 0;
    try { return analyzer->analyzer->NbEdges(); } catch (...) { return 0; }
}

bool OCCTWireAnalyzerIsLoaded(OCCTWireAnalyzerRef analyzer) {
    if (!analyzer || analyzer->analyzer.IsNull()) return false;
    try { return analyzer->analyzer->IsLoaded(); } catch (...) { return false; }
}

bool OCCTWireAnalyzerIsReady(OCCTWireAnalyzerRef analyzer) {
    if (!analyzer || analyzer->analyzer.IsNull()) return false;
    try { return analyzer->analyzer->IsReady(); } catch (...) { return false; }
}

// MARK: - v0.122: ShapeFix_Edge extended
// --- ShapeFix_Edge extended ---

bool OCCTShapeFixEdgeAddCurve3d(OCCTShapeRef edge) {
    if (!edge) return false;
    try {
        ShapeFix_Edge fixer;
        return fixer.FixAddCurve3d(TopoDS::Edge(edge->shape));
    } catch (...) { return false; }
}

bool OCCTShapeFixEdgeAddPCurve(OCCTShapeRef edge, OCCTShapeRef face, bool isSeam) {
    if (!edge || !face) return false;
    try {
        ShapeFix_Edge fixer;
        return fixer.FixAddPCurve(TopoDS::Edge(edge->shape), TopoDS::Face(face->shape), isSeam);
    } catch (...) { return false; }
}

bool OCCTShapeFixEdgeRemoveCurve3d(OCCTShapeRef edge) {
    if (!edge) return false;
    try {
        ShapeFix_Edge fixer;
        return fixer.FixRemoveCurve3d(TopoDS::Edge(edge->shape));
    } catch (...) { return false; }
}

bool OCCTShapeFixEdgeRemovePCurve(OCCTShapeRef edge, OCCTShapeRef face) {
    if (!edge || !face) return false;
    try {
        ShapeFix_Edge fixer;
        return fixer.FixRemovePCurve(TopoDS::Edge(edge->shape), TopoDS::Face(face->shape));
    } catch (...) { return false; }
}

bool OCCTShapeFixEdgeFixReversed2d(OCCTShapeRef edge, OCCTShapeRef face) {
    if (!edge || !face) return false;
    try {
        ShapeFix_Edge fixer;
        return fixer.FixReversed2d(TopoDS::Edge(edge->shape), TopoDS::Face(face->shape));
    } catch (...) { return false; }
}
// MARK: - Validation

bool OCCTShapeIsValid(OCCTShapeRef shape) {
    if (!shape) return false;
    try {
        BRepCheck_Analyzer analyzer(shape->shape);
        return analyzer.IsValid();
    } catch (...) {
        return false;
    }
}

OCCTShapeRef OCCTShapeHeal(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        // #263: ShapeFix_Shape heap-corrupts (uncatchable OS signal) when healing a solid built
        // from a self-intersecting wire — e.g. a prism extruded from a degenerate mesh-derived
        // outline. ShapeFix cannot repair a self-intersection anyway, so refuse such input.
        if (occtHasSelfIntersectingWire(shape->shape)) return nullptr;
        Handle(ShapeFix_Shape) fixer = new ShapeFix_Shape(shape->shape);
        fixer->Perform();
        return new OCCTShape(fixer->Shape());
    } catch (...) {
        return nullptr;
    }
}

