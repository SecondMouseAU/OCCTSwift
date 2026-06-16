//
//  OCCTBridge_Topology.mm
//  OCCTSwift
//
//  Per-OCCT-module TU for topology traversal + classification:
//
//  - TopExp_*, TopTools_*, TopoDS_*, TopAbs_*
//  - BRepTools_WireExplorer (ordered wire-edge iteration)
//  - BRepTools_ReShape (sub-shape replacement / removal)
//  - BRepClass / BRepClass3d (point-in-shape classification)
//  - BRepBndLib + Bnd_OBB (oriented bounding box)
//  - ShapeAnalysis_ShapeContents (sub-shape census)
//  - BRepLib_FindSurface (planar surface from edge group)
//  - BRepGProp helpers when not delegated to Properties
//
//  Public C surface unchanged. No symbol changes — pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

#include <BRep_Tool.hxx>
#include <BRep_Builder.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_Copy.hxx>
#include <BRepClass_FaceClassifier.hxx>
#include <BRepClass3d_SolidClassifier.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepGProp.hxx>
#include <IntCurvesFace_Intersector.hxx>
#include <IntCurvesFace_ShapeIntersector.hxx>
#include <TopCnx_EdgeFaceTransition.hxx>
#include <TopTrans_SurfaceTransition.hxx>
#include <BRepIntCurveSurface_Inter.hxx>
#include <BRepTools.hxx>
#include <BRepLib.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_MakeShell.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <TColgp_Array1OfPnt2d.hxx>
#include <ShapeAnalysis_ShapeTolerance.hxx>
#include <TopTools_IndexedDataMapOfShapeListOfShape.hxx>
#include <BRepExtrema_DistanceSS.hxx>
#include <BRepExtrema_SolutionElem.hxx>
#include <BRepLib_FindSurface.hxx>
#include <BRepTools_ReShape.hxx>
#include <BRepTools_WireExplorer.hxx>

#include <Bnd_Box.hxx>
#include <Bnd_OBB.hxx>

#include <Geom_Plane.hxx>

#include <GCPnts_TangentialDeflection.hxx>
#include <GProp_GProps.hxx>

#include <ShapeAnalysis_ShapeContents.hxx>
#include <ShapeAnalysis_Wire.hxx>
#include <ShapeExtend_WireData.hxx>
#include <Geom_SurfaceOfRevolution.hxx>
#include <Geom_SurfaceOfLinearExtrusion.hxx>
#include <GProp_PrincipalProps.hxx>
#include <BRepExtrema_DistShapeShape.hxx>
#include <BRepExtrema_ExtCC.hxx>
#include <BRepExtrema_ExtCF.hxx>
#include <BRepExtrema_ExtFF.hxx>
#include <BRepExtrema_ExtPC.hxx>
#include <BRepExtrema_ExtPF.hxx>
#include <BRepExtrema_Poly.hxx>
#include <BRepExtrema_SelfIntersection.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepOffset_Analyse.hxx>
#include <BRepOffset_Interval.hxx>
#include <ChFiDS_TypeOfConcavity.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <gp_Cylinder.hxx>
#include <gp_Cone.hxx>
#include <gp_Sphere.hxx>
#include <gp_Torus.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_BezierSurface.hxx>
#include <Geom_BSplineCurve.hxx>
#include <GeomConvert_BSplineSurfaceToBezierSurface.hxx>
#include <GeomConvert_BSplineCurveKnotSplitting.hxx>

#include <gp_Ax1.hxx>
#include <gp_Dir.hxx>
#include <gp_Pln.hxx>
#include <gp_Pnt.hxx>
#include <gp_XYZ.hxx>

#include <TopAbs.hxx>
#include <TopAbs_State.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>

#include <algorithm>

// MARK: - Wire Explorer (v0.29.0)

#include <BRepTools_WireExplorer.hxx>

int32_t OCCTWireExplorerEdgeCount(OCCTWireRef wire) {
    if (!wire) return 0;
    try {
        int32_t count = 0;
        for (BRepTools_WireExplorer exp(wire->wire); exp.More(); exp.Next()) {
            count++;
        }
        return count;
    } catch (...) {
        return 0;
    }
}

bool OCCTWireExplorerGetEdge(OCCTWireRef wire, int32_t index,
                              double* outPoints, int32_t maxPoints, int32_t* outPointCount) {
    if (!wire || !outPoints || !outPointCount || maxPoints <= 0 || index < 0) return false;
    try {
        int32_t current = 0;
        for (BRepTools_WireExplorer exp(wire->wire); exp.More(); exp.Next()) {
            if (current == index) {
                TopoDS_Edge edge = exp.Current();
                BRepAdaptor_Curve curve(edge);
                GCPnts_TangentialDeflection discretizer(curve, 0.01, 0.1);
                int32_t numPoints = std::min(discretizer.NbPoints(), maxPoints);
                for (int32_t i = 0; i < numPoints; i++) {
                    gp_Pnt pt = discretizer.Value(i + 1);
                    outPoints[i*3]   = pt.X();
                    outPoints[i*3+1] = pt.Y();
                    outPoints[i*3+2] = pt.Z();
                }
                *outPointCount = numPoints;
                return true;
            }
            current++;
        }
        return false;
    } catch (...) {
        return false;
    }
}

int32_t OCCTWireExplorerGetEdgePointCount(OCCTWireRef wire, int32_t index) {
    if (!wire || index < 0) return 0;
    try {
        int32_t current = 0;
        for (BRepTools_WireExplorer exp(wire->wire); exp.More(); exp.Next()) {
            if (current == index) {
                TopoDS_Edge edge = exp.Current();
                BRepAdaptor_Curve curve(edge);
                GCPnts_TangentialDeflection discretizer(curve, 0.01, 0.1);
                return discretizer.NbPoints();
            }
            current++;
        }
        return 0;
    } catch (...) {
        return 0;
    }
}

// MARK: - Sub-Shape Replacement (v0.29.0)

#include <BRepTools_ReShape.hxx>

OCCTShapeRef OCCTShapeReplaceSubShape(OCCTShapeRef shape, OCCTShapeRef oldSub, OCCTShapeRef newSub) {
    if (!shape || !oldSub || !newSub) return nullptr;
    try {
        Handle(BRepTools_ReShape) reshaper = new BRepTools_ReShape();
        reshaper->Replace(oldSub->shape, newSub->shape);
        TopoDS_Shape result = reshaper->Apply(shape->shape);
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeRemoveSubShape(OCCTShapeRef shape, OCCTShapeRef subToRemove) {
    if (!shape || !subToRemove) return nullptr;
    try {
        Handle(BRepTools_ReShape) reshaper = new BRepTools_ReShape();
        reshaper->Remove(subToRemove->shape);
        TopoDS_Shape result = reshaper->Apply(shape->shape);
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Shape Contents (v0.30.0)

#include <ShapeAnalysis_ShapeContents.hxx>

OCCTShapeContents OCCTShapeGetContents(OCCTShapeRef shape) {
    OCCTShapeContents result = {};
    if (!shape) return result;
    try {
        ShapeAnalysis_ShapeContents contents;
        contents.Perform(shape->shape);
        result.nbSolids = contents.NbSolids();
        result.nbShells = contents.NbShells();
        result.nbFaces = contents.NbFaces();
        result.nbWires = contents.NbWires();
        result.nbEdges = contents.NbEdges();
        result.nbVertices = contents.NbVertices();
        result.nbFreeEdges = contents.NbFreeEdges();
        result.nbFreeWires = contents.NbFreeWires();
        result.nbFreeFaces = contents.NbFreeFaces();
        return result;
    } catch (...) {
        return result;
    }
}

// MARK: - Edge Analysis (v0.30.0)

#include <ShapeAnalysis_Edge.hxx>

bool OCCTEdgeHasCurve3D(OCCTShapeRef edge) {
    if (!edge) return false;
    try {
        if (edge->shape.ShapeType() != TopAbs_EDGE) return false;
        ShapeAnalysis_Edge analyzer;
        return analyzer.HasCurve3d(TopoDS::Edge(edge->shape));
    } catch (...) {
        return false;
    }
}

bool OCCTEdgeIsClosed3D(OCCTShapeRef edge) {
    if (!edge) return false;
    try {
        if (edge->shape.ShapeType() != TopAbs_EDGE) return false;
        ShapeAnalysis_Edge analyzer;
        return analyzer.IsClosed3d(TopoDS::Edge(edge->shape));
    } catch (...) {
        return false;
    }
}

bool OCCTEdgeIsSeam(OCCTShapeRef edge, OCCTShapeRef face) {
    if (!edge || !face) return false;
    try {
        if (edge->shape.ShapeType() != TopAbs_EDGE) return false;
        if (face->shape.ShapeType() != TopAbs_FACE) return false;
        ShapeAnalysis_Edge analyzer;
        return analyzer.IsSeam(TopoDS::Edge(edge->shape), TopoDS::Face(face->shape));
    } catch (...) {
        return false;
    }
}

// MARK: - Find Surface (v0.30.0)

#include <BRepLib_FindSurface.hxx>

OCCTSurfaceRef OCCTShapeFindSurface(OCCTShapeRef shape, double tolerance) {
    if (!shape) return nullptr;
    try {
        BRepLib_FindSurface finder(shape->shape, tolerance);
        if (!finder.Found()) return nullptr;
        Handle(Geom_Surface) surf = finder.Surface();
        if (surf.IsNull()) return nullptr;
        return new OCCTSurface(surf);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Contiguous Edges (v0.30.0)

#include <BRepOffsetAPI_FindContigousEdges.hxx>

int32_t OCCTShapeFindContiguousEdges(OCCTShapeRef shape, double tolerance) {
    if (!shape) return 0;
    try {
        BRepOffsetAPI_FindContigousEdges finder(tolerance);
        finder.Add(shape->shape);
        finder.Perform();
        return finder.NbContigousEdges();
    } catch (...) {
        return 0;
    }
}

// MARK: - Point Classification (v0.17.0)

#include <BRepClass3d_SolidClassifier.hxx>
#include <BRepClass_FaceClassifier.hxx>
#include <BRepClass3d.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Solid.hxx>
#include <TopoDS_Shell.hxx>
#include <TopAbs_State.hxx>

// Outer shell of a solid (BRepClass3d::OuterShell) — distinguishes the outer body from
// internal void shells of a multi-shell solid. #211
OCCTShapeRef OCCTShapeOuterShell(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        TopoDS_Solid solid;
        if (shape->shape.ShapeType() == TopAbs_SOLID) {
            solid = TopoDS::Solid(shape->shape);
        } else {
            // Accept a compound/compsolid wrapping a single solid.
            TopExp_Explorer ex(shape->shape, TopAbs_SOLID);
            if (!ex.More()) return nullptr;
            solid = TopoDS::Solid(ex.Current());
        }
        TopoDS_Shell shell = BRepClass3d::OuterShell(solid);
        if (shell.IsNull()) return nullptr;
        return new OCCTShape(shell);
    } catch (...) {
        return nullptr;
    }
}

// Inner (void/cavity) shells = every shell of the solid except the outer one. #212
int32_t OCCTShapeInnerShells(OCCTShapeRef shape, OCCTShapeRef* outShells, int32_t maxCount) {
    if (!shape) return 0;
    try {
        TopoDS_Solid solid;
        if (shape->shape.ShapeType() == TopAbs_SOLID) {
            solid = TopoDS::Solid(shape->shape);
        } else {
            TopExp_Explorer se(shape->shape, TopAbs_SOLID);
            if (!se.More()) return 0;
            solid = TopoDS::Solid(se.Current());
        }
        TopoDS_Shell outer = BRepClass3d::OuterShell(solid);
        int32_t n = 0;
        for (TopExp_Explorer ex(solid, TopAbs_SHELL); ex.More(); ex.Next()) {
            const TopoDS_Shape& sh = ex.Current();
            if (!outer.IsNull() && sh.IsSame(outer)) continue;   // skip the outer shell
            if (outShells && n < maxCount) outShells[n] = new OCCTShape(sh);
            n++;
        }
        return n;
    } catch (...) {
        return 0;
    }
}

static int32_t mapTopAbsState(TopAbs_State state) {
    switch (state) {
        case TopAbs_IN:      return 0;
        case TopAbs_OUT:     return 1;
        case TopAbs_ON:      return 2;
        case TopAbs_UNKNOWN: return 3;
        default:             return 3;
    }
}

OCCTTopAbsState OCCTClassifyPointInSolid(OCCTShapeRef solid,
                                          double px, double py, double pz,
                                          double tolerance) {
    if (!solid) return 3; // UNKNOWN

    try {
        BRepClass3d_SolidClassifier classifier(solid->shape, gp_Pnt(px, py, pz), tolerance);
        return mapTopAbsState(classifier.State());
    } catch (...) {
        return 3; // UNKNOWN
    }
}

OCCTTopAbsState OCCTClassifyPointOnFace(OCCTFaceRef face,
                                         double px, double py, double pz,
                                         double tolerance) {
    if (!face) return 3; // UNKNOWN

    try {
        BRepClass_FaceClassifier classifier(face->face, gp_Pnt(px, py, pz), tolerance);
        return mapTopAbsState(classifier.State());
    } catch (...) {
        return 3; // UNKNOWN
    }
}

OCCTTopAbsState OCCTClassifyPointOnFaceUV(OCCTFaceRef face,
                                           double u, double v,
                                           double tolerance) {
    if (!face) return 3; // UNKNOWN

    try {
        BRepClass_FaceClassifier classifier(face->face, gp_Pnt2d(u, v), tolerance);
        return mapTopAbsState(classifier.State());
    } catch (...) {
        return 3; // UNKNOWN
    }
}


// MARK: - Wire Analysis (v0.37.0)

#include <ShapeAnalysis_Wire.hxx>
#include <ShapeExtend_WireData.hxx>

bool OCCTWireAnalyze(OCCTWireRef wire, double tolerance, OCCTWireAnalysisResult* result) {
    if (!wire || !result) return false;
    try {
        // Create a dummy planar face for wire analysis
        TopoDS_Face face;
        ShapeAnalysis_Wire analyzer;
        analyzer.Load(wire->wire);
        analyzer.SetPrecision(tolerance);

        result->edgeCount = analyzer.NbEdges();
        // CheckClosed returns true when there IS a problem, so negate it
        result->isClosed = wire->wire.Closed() || !analyzer.CheckClosed(tolerance);
        result->hasSmallEdges = analyzer.CheckSmall(tolerance);
        result->hasGaps3d = analyzer.CheckGaps3d();
        result->hasSelfIntersection = analyzer.CheckSelfIntersection();
        result->isOrdered = !analyzer.CheckOrder();
        result->minDistance3d = analyzer.MinDistance3d();
        result->maxDistance3d = analyzer.MaxDistance3d();
        return true;
    } catch (...) {
        return false;
    }
}

// MARK: - Oriented Bounding Box (v0.38.0)

#include <Bnd_OBB.hxx>
#include <BRepBndLib.hxx>

bool OCCTShapeOrientedBoundingBox(OCCTShapeRef shape, bool optimal, OCCTOrientedBoundingBox* result) {
    if (!shape || !result) return false;
    try {
        Bnd_OBB obb;
        BRepBndLib::AddOBB(shape->shape, obb, true, optimal, true);
        if (obb.IsVoid()) return false;

        gp_XYZ center = obb.Center();
        result->centerX = center.X();
        result->centerY = center.Y();
        result->centerZ = center.Z();

        gp_XYZ xDir = obb.XDirection();
        result->xDirX = xDir.X(); result->xDirY = xDir.Y(); result->xDirZ = xDir.Z();
        gp_XYZ yDir = obb.YDirection();
        result->yDirX = yDir.X(); result->yDirY = yDir.Y(); result->yDirZ = yDir.Z();
        gp_XYZ zDir = obb.ZDirection();
        result->zDirX = zDir.X(); result->zDirY = zDir.Y(); result->zDirZ = zDir.Z();

        result->halfX = obb.XHSize();
        result->halfY = obb.YHSize();
        result->halfZ = obb.ZHSize();
        return true;
    } catch (...) {
        return false;
    }
}

double OCCTOrientedBoundingBoxVolume(const OCCTOrientedBoundingBox* result) {
    if (!result) return 0.0;
    return 8.0 * result->halfX * result->halfY * result->halfZ;
}

void OCCTOrientedBoundingBoxCorners(const OCCTOrientedBoundingBox* result, double* outCorners) {
    if (!result || !outCorners) return;
    gp_XYZ center(result->centerX, result->centerY, result->centerZ);
    gp_XYZ xDir(result->xDirX, result->xDirY, result->xDirZ);
    gp_XYZ yDir(result->yDirX, result->yDirY, result->yDirZ);
    gp_XYZ zDir(result->zDirX, result->zDirY, result->zDirZ);
    gp_XYZ hx = xDir * result->halfX;
    gp_XYZ hy = yDir * result->halfY;
    gp_XYZ hz = zDir * result->halfZ;

    // 8 corners: all combinations of +/- half-sizes
    int idx = 0;
    for (int sx = -1; sx <= 1; sx += 2) {
        for (int sy = -1; sy <= 1; sy += 2) {
            for (int sz = -1; sz <= 1; sz += 2) {
                gp_XYZ corner = center;
                corner += hx * sx;
                corner += hy * sy;
                corner += hz * sz;
                outCorners[idx++] = corner.X();
                outCorners[idx++] = corner.Y();
                outCorners[idx++] = corner.Z();
            }
        }
    }
}

// MARK: - Deep Shape Copy (v0.38.0)

#include <BRepBuilderAPI_Copy.hxx>

OCCTShapeRef OCCTShapeCopy(OCCTShapeRef shape, bool copyGeom, bool copyMesh) {
    if (!shape) return nullptr;
    try {
        BRepBuilderAPI_Copy copier(shape->shape, copyGeom, copyMesh);
        if (!copier.IsDone()) return nullptr;
        TopoDS_Shape result = copier.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Sub-Shape Extraction (v0.38.0)

#include <TopExp_Explorer.hxx>

int32_t OCCTShapeGetSolidCount(OCCTShapeRef shape) {
    if (!shape) return 0;
    int32_t count = 0;
    for (TopExp_Explorer exp(shape->shape, TopAbs_SOLID); exp.More(); exp.Next()) {
        count++;
    }
    return count;
}

int32_t OCCTShapeGetSolids(OCCTShapeRef shape, OCCTShapeRef* outSolids, int32_t maxCount) {
    if (!shape || !outSolids || maxCount <= 0) return 0;
    int32_t count = 0;
    for (TopExp_Explorer exp(shape->shape, TopAbs_SOLID); exp.More() && count < maxCount; exp.Next()) {
        outSolids[count++] = new OCCTShape(exp.Current());
    }
    return count;
}

int32_t OCCTShapeGetShellCount(OCCTShapeRef shape) {
    if (!shape) return 0;
    int32_t count = 0;
    for (TopExp_Explorer exp(shape->shape, TopAbs_SHELL); exp.More(); exp.Next()) {
        count++;
    }
    return count;
}

int32_t OCCTShapeGetShells(OCCTShapeRef shape, OCCTShapeRef* outShells, int32_t maxCount) {
    if (!shape || !outShells || maxCount <= 0) return 0;
    int32_t count = 0;
    for (TopExp_Explorer exp(shape->shape, TopAbs_SHELL); exp.More() && count < maxCount; exp.Next()) {
        outShells[count++] = new OCCTShape(exp.Current());
    }
    return count;
}

int32_t OCCTShapeGetWireCount(OCCTShapeRef shape) {
    if (!shape) return 0;
    int32_t count = 0;
    for (TopExp_Explorer exp(shape->shape, TopAbs_WIRE); exp.More(); exp.Next()) {
        count++;
    }
    return count;
}

int32_t OCCTShapeGetWires(OCCTShapeRef shape, OCCTShapeRef* outWires, int32_t maxCount) {
    if (!shape || !outWires || maxCount <= 0) return 0;
    int32_t count = 0;
    for (TopExp_Explorer exp(shape->shape, TopAbs_WIRE); exp.More() && count < maxCount; exp.Next()) {
        outWires[count++] = new OCCTShape(exp.Current());
    }
    return count;
}

// MARK: - Memory Management

// MARK: - Shape Conversion

OCCTShapeRef OCCTShapeFromWire(OCCTWireRef wireRef) {
    if (!wireRef) return nullptr;
    return new OCCTShape(wireRef->wire);
}

OCCTShapeRef OCCTShapeFromFace(OCCTFaceRef faceRef) {
    if (!faceRef) return nullptr;
    return new OCCTShape(faceRef->face);
}

OCCTFaceRef OCCTFaceFromShape(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        if (shape->shape.IsNull()) return nullptr;
        if (shape->shape.ShapeType() != TopAbs_FACE) return nullptr;
        return new OCCTFace(TopoDS::Face(shape->shape));
    } catch (...) { return nullptr; }
}

OCCTWireRef OCCTWireFromShape(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        if (shape->shape.IsNull()) return nullptr;
        if (shape->shape.ShapeType() != TopAbs_WIRE) return nullptr;
        return new OCCTWire(TopoDS::Wire(shape->shape));
    } catch (...) { return nullptr; }
}

void OCCTShapeRelease(OCCTShapeRef shape) {
    delete shape;
}

void OCCTWireRelease(OCCTWireRef wire) {
    delete wire;
}

void OCCTMeshRelease(OCCTMeshRef mesh) {
    delete mesh;
}

// MARK: - Shape Axis Extraction (v0.137)

static bool axesCoincide(const OCCTShapeAxis& a, double ox, double oy, double oz,
                          double dx, double dy, double dz, double tol) {
    gp_Dir d1(a.directionX, a.directionY, a.directionZ);
    gp_Dir d2(dx, dy, dz);
    // Direction parallel (either same or opposite)
    if (fabs(fabs(d1.Dot(d2)) - 1.0) > tol) return false;
    // Origin-to-origin vector parallel to direction (i.e. same line)
    gp_Vec sep(ox - a.originX, oy - a.originY, oz - a.originZ);
    if (sep.Magnitude() < tol) return true;
    gp_Vec axisVec(d1.X(), d1.Y(), d1.Z());
    gp_Vec cross = sep.Crossed(axisVec);
    return cross.Magnitude() < tol;
}

int32_t OCCTShapeRevolutionAxes(OCCTShapeRef shape, double tolerance,
                                 OCCTShapeAxis* outAxes, int32_t maxAxes) {
    if (!shape || !outAxes || maxAxes <= 0) return -1;
    try {
        std::vector<OCCTShapeAxis> collected;
        for (TopExp_Explorer ex(shape->shape, TopAbs_FACE); ex.More(); ex.Next()) {
            TopoDS_Face face = TopoDS::Face(ex.Current());
            BRepAdaptor_Surface adaptor(face);
            gp_Ax1 axis;
            int kind = 0;
            try {
                switch (adaptor.GetType()) {
                    case GeomAbs_Cylinder: axis = adaptor.Cylinder().Axis(); kind = 1; break;
                    case GeomAbs_Cone:     axis = adaptor.Cone().Axis();     kind = 2; break;
                    case GeomAbs_Sphere: {
                        gp_Sphere s = adaptor.Sphere();
                        axis = gp_Ax1(s.Location(), s.Position().Direction());
                        kind = 3;
                        break;
                    }
                    case GeomAbs_Torus: axis = adaptor.Torus().Axis(); kind = 4; break;
                    case GeomAbs_SurfaceOfRevolution: {
                        Handle(Geom_Surface) surf = BRep_Tool::Surface(face);
                        Handle(Geom_SurfaceOfRevolution) rev = Handle(Geom_SurfaceOfRevolution)::DownCast(surf);
                        if (rev.IsNull()) continue;
                        axis = rev->Axis();
                        kind = 5;
                        break;
                    }
                    default: continue;
                }
            } catch (...) { continue; }
            const gp_Pnt& p = axis.Location();
            const gp_Dir& d = axis.Direction();
            bool dup = false;
            for (const auto& existing : collected) {
                if (axesCoincide(existing, p.X(), p.Y(), p.Z(), d.X(), d.Y(), d.Z(), tolerance)) {
                    dup = true;
                    break;
                }
            }
            if (dup) continue;
            OCCTShapeAxis a;
            a.originX = p.X(); a.originY = p.Y(); a.originZ = p.Z();
            a.directionX = d.X(); a.directionY = d.Y(); a.directionZ = d.Z();
            a.extentMin = 0; a.extentMax = 0; a.hasExtent = false;
            a.kind = kind;
            collected.push_back(a);
        }
        int32_t count = std::min((int32_t)collected.size(), maxAxes);
        for (int32_t i = 0; i < count; i++) outAxes[i] = collected[i];
        return (int32_t)collected.size();
    } catch (...) {
        return -1;
    }
}

int32_t OCCTShapeSymmetryAxes(OCCTShapeRef shape, double fractionalTolerance,
                               OCCTShapeAxis* outAxes, int32_t maxAxes) {
    if (!shape || !outAxes || maxAxes <= 0) return -1;
    try {
        GProp_GProps props;
        BRepGProp::VolumeProperties(shape->shape, props);
        gp_Pnt cm = props.CentreOfMass();
        GProp_PrincipalProps pp = props.PrincipalProperties();
        double Ix, Iy, Iz;
        pp.Moments(Ix, Iy, Iz);
        gp_Vec v1 = pp.FirstAxisOfInertia();
        gp_Vec v2 = pp.SecondAxisOfInertia();
        gp_Vec v3 = pp.ThirdAxisOfInertia();
        double moments[3] = { Ix, Iy, Iz };
        gp_Vec axes[3] = { v1, v2, v3 };
        double maxM = std::max({ Ix, Iy, Iz });
        std::vector<OCCTShapeAxis> collected;
        if (pp.HasSymmetryPoint()) {
            // Spherical — add all three principal axes (all equal).
            for (int i = 0; i < 3; i++) {
                OCCTShapeAxis a;
                a.originX = cm.X(); a.originY = cm.Y(); a.originZ = cm.Z();
                a.directionX = axes[i].X(); a.directionY = axes[i].Y(); a.directionZ = axes[i].Z();
                a.extentMin = 0; a.extentMax = 0; a.hasExtent = false; a.kind = 7;
                collected.push_back(a);
            }
        } else if (pp.HasSymmetryAxis()) {
            // Rotational — the unique (different) moment's axis IS the symmetry axis.
            int uniqueIdx = 0;
            for (int i = 0; i < 3; i++) {
                int j = (i + 1) % 3, k = (i + 2) % 3;
                if (fabs(moments[j] - moments[k]) < fractionalTolerance * maxM &&
                    fabs(moments[i] - moments[j]) > fractionalTolerance * maxM) {
                    uniqueIdx = i;
                    break;
                }
            }
            OCCTShapeAxis a;
            a.originX = cm.X(); a.originY = cm.Y(); a.originZ = cm.Z();
            a.directionX = axes[uniqueIdx].X();
            a.directionY = axes[uniqueIdx].Y();
            a.directionZ = axes[uniqueIdx].Z();
            a.extentMin = 0; a.extentMax = 0; a.hasExtent = false; a.kind = 7;
            collected.push_back(a);
        }
        int32_t count = std::min((int32_t)collected.size(), maxAxes);
        for (int32_t i = 0; i < count; i++) outAxes[i] = collected[i];
        return (int32_t)collected.size();
    } catch (...) {
        return -1;
    }
}

int32_t OCCTShapeAllDistanceSolutions(OCCTShapeRef shape1, OCCTShapeRef shape2,
                                       OCCTDistanceSolution* outSolutions, int32_t maxSolutions) {
    if (!shape1 || !shape2 || !outSolutions || maxSolutions <= 0) return -1;
    try {
        BRepExtrema_DistShapeShape dist(shape1->shape, shape2->shape);
        if (!dist.IsDone()) return -1;

        int32_t nbSol = dist.NbSolution();
        int32_t count = std::min(nbSol, maxSolutions);

        for (int32_t i = 0; i < count; i++) {
            gp_Pnt p1 = dist.PointOnShape1(i + 1);
            gp_Pnt p2 = dist.PointOnShape2(i + 1);
            outSolutions[i].point1X = p1.X();
            outSolutions[i].point1Y = p1.Y();
            outSolutions[i].point1Z = p1.Z();
            outSolutions[i].point2X = p2.X();
            outSolutions[i].point2Y = p2.Y();
            outSolutions[i].point2Z = p2.Z();
            outSolutions[i].distance = dist.Value();
        }
        return nbSol;
    } catch (...) {
        return -1;
    }
}

int32_t OCCTShapeIsInnerDistance(OCCTShapeRef shape1, OCCTShapeRef shape2) {
    if (!shape1 || !shape2) return -1;
    try {
        BRepExtrema_DistShapeShape dist(shape1->shape, shape2->shape);
        if (!dist.IsDone()) return -1;
        return dist.InnerSolution() ? 1 : 0;
    } catch (...) {
        return -1;
    }
}

bool OCCTShapeDistanceSolutionDetail(OCCTShapeRef shape1, OCCTShapeRef shape2,
    int32_t solutionIndex, OCCTDistanceSolutionDetail* outDetail) {
    if (!shape1 || !shape2 || !outDetail) return false;
    try {
        BRepExtrema_DistShapeShape dist(shape1->shape, shape2->shape);
        if (!dist.IsDone()) return false;
        int idx = solutionIndex + 1; // OCCT is 1-based
        if (idx < 1 || idx > dist.NbSolution()) return false;

        memset(outDetail, 0, sizeof(OCCTDistanceSolutionDetail));

        // Support types: BRepExtrema_IsVertex=0, BRepExtrema_IsOnEdge=1, BRepExtrema_IsInFace=2
        outDetail->supportType1 = (int32_t)dist.SupportTypeShape1(idx);
        outDetail->supportType2 = (int32_t)dist.SupportTypeShape2(idx);

        // Edge parameters
        if (outDetail->supportType1 == 1) { // IsOnEdge
            double t = 0;
            dist.ParOnEdgeS1(idx, t);
            outDetail->paramEdge1 = t;
        }
        if (outDetail->supportType2 == 1) {
            double t = 0;
            dist.ParOnEdgeS2(idx, t);
            outDetail->paramEdge2 = t;
        }

        // Face parameters
        if (outDetail->supportType1 == 2) { // IsInFace
            double u = 0, v = 0;
            dist.ParOnFaceS1(idx, u, v);
            outDetail->paramFaceU1 = u;
            outDetail->paramFaceV1 = v;
        }
        if (outDetail->supportType2 == 2) {
            double u = 0, v = 0;
            dist.ParOnFaceS2(idx, u, v);
            outDetail->paramFaceU2 = u;
            outDetail->paramFaceV2 = v;
        }
        return true;
    } catch (...) { return false; }
}

int32_t OCCTSurfaceBSplineToBezierPatches(OCCTSurfaceRef surface,
                                           OCCTSurfaceRef* outPatches, int32_t maxPatches,
                                           int32_t* outNbUPatches, int32_t* outNbVPatches) {
    if (!surface || !outPatches || !outNbUPatches || !outNbVPatches || maxPatches <= 0) return -1;
    try {
        Handle(Geom_BSplineSurface) bspline = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
        if (bspline.IsNull()) return -1;

        GeomConvert_BSplineSurfaceToBezierSurface conv(bspline);
        int32_t nbU = conv.NbUPatches();
        int32_t nbV = conv.NbVPatches();
        *outNbUPatches = nbU;
        *outNbVPatches = nbV;

        int32_t total = nbU * nbV;
        int32_t count = std::min(total, maxPatches);

        int32_t idx = 0;
        for (int32_t u = 1; u <= nbU && idx < count; u++) {
            for (int32_t v = 1; v <= nbV && idx < count; v++) {
                Handle(Geom_BezierSurface) patch = conv.Patch(u, v);
                if (!patch.IsNull()) {
                    outPatches[idx] = new OCCTSurface(patch);
                } else {
                    outPatches[idx] = nullptr;
                }
                idx++;
            }
        }
        return total;
    } catch (...) {
        return -1;
    }
}

int32_t OCCTCurve3DBSplineKnotSplits(OCCTCurve3DRef curve3D, int32_t continuityOrder,
                                       double* outParams, int32_t maxParams) {
    if (!curve3D || !outParams || maxParams <= 0) return -1;
    try {
        Handle(Geom_BSplineCurve) bspline = Handle(Geom_BSplineCurve)::DownCast(curve3D->curve);
        if (bspline.IsNull()) return -1;

        GeomConvert_BSplineCurveKnotSplitting splitter(bspline, continuityOrder);
        int32_t nbSplits = splitter.NbSplits();
        int32_t count = std::min(nbSplits, maxParams);

        for (int32_t i = 0; i < count; i++) {
            int32_t knotIndex = splitter.SplitValue(i + 1);
            outParams[i] = bspline->Knot(knotIndex);
        }
        return nbSplits;
    } catch (...) {
        return -1;
    }
}

OCCTSurfaceRef OCCTShapeFindSurfaceEx(OCCTShapeRef shape, double tolerance,
                                       bool onlyPlane, bool* outFound) {
    if (!shape || !outFound) return nullptr;
    try {
        BRepLib_FindSurface finder(shape->shape, tolerance, onlyPlane);
        *outFound = finder.Found();
        if (!finder.Found()) return nullptr;

        Handle(Geom_Surface) surf = finder.Surface();
        if (surf.IsNull()) return nullptr;

        return new OCCTSurface(surf);
    } catch (...) {
        *outFound = false;
        return nullptr;
    }
}

// MARK: - v0.41.0: Shape Surgery, Plane Detection, Geometry Conversion

#include <BRepTools_ReShape.hxx>
#include <BRepBuilderAPI_FindPlane.hxx>
#include <Geom_Plane.hxx>
#include <ShapeUpgrade_ShapeDivideClosedEdges.hxx>
#include <ShapeCustom.hxx>
#include <BRepAlgo_FaceRestrictor.hxx>

OCCTShapeRef OCCTShapeRemoveSubShapes(OCCTShapeRef shape, OCCTShapeRef* subShapes, int32_t count) {
    if (!shape || !subShapes || count <= 0) return nullptr;
    try {
        Handle(BRepTools_ReShape) reshaper = new BRepTools_ReShape();
        for (int32_t i = 0; i < count; i++) {
            if (subShapes[i]) {
                reshaper->Remove(subShapes[i]->shape);
            }
        }
        TopoDS_Shape result = reshaper->Apply(shape->shape);
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeReplaceSubShapes(OCCTShapeRef shape,
                                        OCCTShapeRef* oldShapes, OCCTShapeRef* newShapes,
                                        int32_t count) {
    if (!shape || !oldShapes || !newShapes || count <= 0) return nullptr;
    try {
        Handle(BRepTools_ReShape) reshaper = new BRepTools_ReShape();
        for (int32_t i = 0; i < count; i++) {
            if (oldShapes[i] && newShapes[i]) {
                reshaper->Replace(oldShapes[i]->shape, newShapes[i]->shape);
            }
        }
        TopoDS_Shape result = reshaper->Apply(shape->shape);
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

bool OCCTShapeFindPlane(OCCTShapeRef shape, double tolerance,
                         double* outNormalX, double* outNormalY, double* outNormalZ,
                         double* outOriginX, double* outOriginY, double* outOriginZ) {
    if (!shape || !outNormalX || !outNormalY || !outNormalZ ||
        !outOriginX || !outOriginY || !outOriginZ) return false;
    try {
        BRepBuilderAPI_FindPlane finder(shape->shape, tolerance);
        if (!finder.Found()) return false;

        Handle(Geom_Plane) plane = finder.Plane();
        if (plane.IsNull()) return false;

        gp_Pln pln = plane->Pln();
        gp_Dir norm = pln.Axis().Direction();
        gp_Pnt loc = pln.Location();

        *outNormalX = norm.X();
        *outNormalY = norm.Y();
        *outNormalZ = norm.Z();
        *outOriginX = loc.X();
        *outOriginY = loc.Y();
        *outOriginZ = loc.Z();

        return true;
    } catch (...) {
        return false;
    }
}
// MARK: - Sub-Shape Extraction (fixes #36)

int32_t OCCTShapeGetSubShapeCount(OCCTShapeRef shape, int32_t type) {
    if (!shape) return 0;
    try {
        TopTools_IndexedMapOfShape map;
        TopExp::MapShapes(shape->shape, static_cast<TopAbs_ShapeEnum>(type), map);
        return map.Extent();
    } catch (...) {
        return 0;
    }
}

OCCTShapeRef OCCTShapeGetSubShapeByTypeIndex(OCCTShapeRef shape, int32_t type, int32_t index) {
    if (!shape || index < 0) return nullptr;
    try {
        TopTools_IndexedMapOfShape map;
        TopExp::MapShapes(shape->shape, static_cast<TopAbs_ShapeEnum>(type), map);
        if (index >= map.Extent()) return nullptr;
        return new OCCTShape(map(index + 1)); // OCCT uses 1-based indexing
    } catch (...) {
        return nullptr;
    }
}


// MARK: - BRepExtrema_SelfIntersection (v0.45)
OCCTSelfIntersectionResult OCCTShapeSelfIntersection(OCCTShapeRef shape, double tolerance,
                                                      double meshDeflection) {
    OCCTSelfIntersectionResult result = {0, false};
    if (!shape) return result;
    try {
        // Ensure the shape is meshed
        BRepMesh_IncrementalMesh mesh(shape->shape, meshDeflection);

        BRepExtrema_SelfIntersection selfInt(shape->shape, tolerance);
        selfInt.Perform();

        result.isDone = selfInt.IsDone();
        if (result.isDone) {
            result.overlapCount = (int32_t)selfInt.OverlapElements().Size();
        }
        return result;
    } catch (...) {
        return result;
    }
}

// MARK: - BRepOffset_Analyse Edge Concavity (v0.46)
int32_t OCCTShapeAnalyzeEdgeConcavity(OCCTShapeRef shape, double angle,
                                       OCCTEdgeConcavity* outEdgeTypes, int32_t maxEntries) {
    if (!shape || !outEdgeTypes || maxEntries <= 0) return -1;
    try {
        BRepOffset_Analyse analyser(shape->shape, angle);
        if (!analyser.IsDone()) return -1;

        int32_t count = 0;
        for (TopExp_Explorer exp(shape->shape, TopAbs_EDGE); exp.More() && count < maxEntries; exp.Next()) {
            TopoDS_Edge edge = TopoDS::Edge(exp.Current());
            const auto& intervals = analyser.Type(edge);
            // Use the first interval's type for the overall edge classification
            for (auto it = intervals.begin(); it != intervals.end(); ++it) {
                OCCTConcavityType type;
                if (it->Type() == ChFiDS_Convex) type = OCCTConcavityConvex;
                else if (it->Type() == ChFiDS_Concave) type = OCCTConcavityConcave;
                else type = OCCTConcavityTangent;
                outEdgeTypes[count].type = type;
                count++;
                break; // One classification per edge
            }
        }
        return count;
    } catch (...) {
        return -1;
    }
}

int32_t OCCTShapeCountEdgeConcavity(OCCTShapeRef shape, double angle, int32_t type) {
    if (!shape) return -1;
    try {
        BRepOffset_Analyse analyser(shape->shape, angle);
        if (!analyser.IsDone()) return -1;

        ChFiDS_TypeOfConcavity targetType;
        if (type == 0) targetType = ChFiDS_Convex;
        else if (type == 1) targetType = ChFiDS_Concave;
        else targetType = ChFiDS_Tangential;

        int32_t count = 0;
        for (TopExp_Explorer exp(shape->shape, TopAbs_EDGE); exp.More(); exp.Next()) {
            TopoDS_Edge edge = TopoDS::Edge(exp.Current());
            const auto& intervals = analyser.Type(edge);
            for (auto it = intervals.begin(); it != intervals.end(); ++it) {
                if (it->Type() == targetType) {
                    count++;
                    break;
                }
            }
        }
        return count;
    } catch (...) {
        return -1;
    }
}

// MARK: - BRepExtrema Ext CC/PF/FF (v0.48)
OCCTEdgeEdgeExtremaResult OCCTBRepExtremaExtCC(OCCTShapeRef shape1, int32_t edgeIndex1,
                                                OCCTShapeRef shape2, int32_t edgeIndex2) {
    OCCTEdgeEdgeExtremaResult result = {};
    if (!shape1 || !shape2) return result;
    try {
        // Find edges
        TopoDS_Edge e1, e2;
        int idx = 0;
        for (TopExp_Explorer exp(shape1->shape, TopAbs_EDGE); exp.More(); exp.Next()) {
            if (idx == edgeIndex1) { e1 = TopoDS::Edge(exp.Current()); break; }
            idx++;
        }
        idx = 0;
        for (TopExp_Explorer exp(shape2->shape, TopAbs_EDGE); exp.More(); exp.Next()) {
            if (idx == edgeIndex2) { e2 = TopoDS::Edge(exp.Current()); break; }
            idx++;
        }
        if (e1.IsNull() || e2.IsNull()) return result;

        BRepExtrema_ExtCC extCC(e1, e2);
        if (!extCC.IsDone()) return result;

        result.isParallel = extCC.IsParallel();
        if (result.isParallel) {
            result.solutionCount = 0;
            return result;
        }
        result.solutionCount = extCC.NbExt();

        if (result.solutionCount >= 1 && !result.isParallel) {
            result.distance = sqrt(extCC.SquareDistance(1));
            result.paramOnE1 = extCC.ParameterOnE1(1);
            result.paramOnE2 = extCC.ParameterOnE2(1);
            gp_Pnt p1 = extCC.PointOnE1(1);
            gp_Pnt p2 = extCC.PointOnE2(1);
            result.pt1x = p1.X(); result.pt1y = p1.Y(); result.pt1z = p1.Z();
            result.pt2x = p2.X(); result.pt2y = p2.Y(); result.pt2z = p2.Z();
        }
        return result;
    } catch (...) {
        return result;
    }
}

OCCTEdgeEdgeExtremaResult OCCTBRepExtremaExtCCEdges(OCCTShapeRef edge1, OCCTShapeRef edge2) {
    OCCTEdgeEdgeExtremaResult result = {};
    if (!edge1 || !edge2) return result;
    try {
        TopoDS_Edge e1, e2;
        if (edge1->shape.ShapeType() == TopAbs_EDGE) {
            e1 = TopoDS::Edge(edge1->shape);
        } else {
            for (TopExp_Explorer exp(edge1->shape, TopAbs_EDGE); exp.More(); exp.Next()) {
                e1 = TopoDS::Edge(exp.Current()); break;
            }
        }
        if (edge2->shape.ShapeType() == TopAbs_EDGE) {
            e2 = TopoDS::Edge(edge2->shape);
        } else {
            for (TopExp_Explorer exp(edge2->shape, TopAbs_EDGE); exp.More(); exp.Next()) {
                e2 = TopoDS::Edge(exp.Current()); break;
            }
        }
        if (e1.IsNull() || e2.IsNull()) return result;

        BRepExtrema_ExtCC extCC(e1, e2);
        if (!extCC.IsDone()) return result;

        result.isParallel = extCC.IsParallel();
        if (result.isParallel) {
            result.solutionCount = 0;
            return result;
        }
        result.solutionCount = extCC.NbExt();

        if (result.solutionCount >= 1 && !result.isParallel) {
            result.distance = sqrt(extCC.SquareDistance(1));
            result.paramOnE1 = extCC.ParameterOnE1(1);
            result.paramOnE2 = extCC.ParameterOnE2(1);
            gp_Pnt p1 = extCC.PointOnE1(1);
            gp_Pnt p2 = extCC.PointOnE2(1);
            result.pt1x = p1.X(); result.pt1y = p1.Y(); result.pt1z = p1.Z();
            result.pt2x = p2.X(); result.pt2y = p2.Y(); result.pt2z = p2.Z();
        }
        return result;
    } catch (...) {
        return result;
    }
}

OCCTPointFaceExtremaResult OCCTBRepExtremaExtPF(double px, double py, double pz,
                                                 OCCTShapeRef shape, int32_t faceIndex) {
    OCCTPointFaceExtremaResult result = {};
    if (!shape) return result;
    try {
        // Find face
        TopoDS_Face face;
        int idx = 0;
        for (TopExp_Explorer exp(shape->shape, TopAbs_FACE); exp.More(); exp.Next()) {
            if (idx == faceIndex) { face = TopoDS::Face(exp.Current()); break; }
            idx++;
        }
        if (face.IsNull()) return result;

        TopoDS_Vertex vertex = BRepBuilderAPI_MakeVertex(gp_Pnt(px, py, pz));
        BRepExtrema_ExtPF extPF(vertex, face);
        if (!extPF.IsDone()) return result;

        result.solutionCount = extPF.NbExt();
        if (result.solutionCount >= 1) {
            result.distance = sqrt(extPF.SquareDistance(1));
            gp_Pnt pt = extPF.Point(1);
            result.ptx = pt.X(); result.pty = pt.Y(); result.ptz = pt.Z();
            extPF.Parameter(1, result.u, result.v);
        }
        return result;
    } catch (...) {
        return result;
    }
}

OCCTFaceFaceExtremaResult OCCTBRepExtremaExtFF(OCCTShapeRef shape1, int32_t faceIndex1,
                                                OCCTShapeRef shape2, int32_t faceIndex2) {
    OCCTFaceFaceExtremaResult result = {};
    if (!shape1 || !shape2) return result;
    try {
        // Find faces
        TopoDS_Face f1, f2;
        int idx = 0;
        for (TopExp_Explorer exp(shape1->shape, TopAbs_FACE); exp.More(); exp.Next()) {
            if (idx == faceIndex1) { f1 = TopoDS::Face(exp.Current()); break; }
            idx++;
        }
        idx = 0;
        for (TopExp_Explorer exp(shape2->shape, TopAbs_FACE); exp.More(); exp.Next()) {
            if (idx == faceIndex2) { f2 = TopoDS::Face(exp.Current()); break; }
            idx++;
        }
        if (f1.IsNull() || f2.IsNull()) return result;

        BRepExtrema_ExtFF extFF(f1, f2);
        if (!extFF.IsDone()) return result;

        result.solutionCount = extFF.NbExt();
        if (result.solutionCount >= 1) {
            result.distance = sqrt(extFF.SquareDistance(1));
            extFF.ParameterOnFace1(1, result.u1, result.v1);
            extFF.ParameterOnFace2(1, result.u2, result.v2);
            gp_Pnt p1 = extFF.PointOnFace1(1);
            gp_Pnt p2 = extFF.PointOnFace2(1);
            result.pt1x = p1.X(); result.pt1y = p1.Y(); result.pt1z = p1.Z();
            result.pt2x = p2.X(); result.pt2y = p2.Y(); result.pt2z = p2.Z();
        }
        return result;
    } catch (...) {
        return result;
    }
}

// MARK: - BRepExtrema Ext PC/CF (v0.49)
OCCTPointEdgeExtremaResult OCCTBRepExtremaExtPC(double px, double py, double pz,
                                                 OCCTShapeRef shape, int32_t edgeIndex) {
    OCCTPointEdgeExtremaResult result = {};
    if (!shape) return result;
    try {
        TopoDS_Edge edge;
        int idx = 0;
        for (TopExp_Explorer exp(shape->shape, TopAbs_EDGE); exp.More(); exp.Next()) {
            if (idx == edgeIndex) { edge = TopoDS::Edge(exp.Current()); break; }
            idx++;
        }
        if (edge.IsNull()) return result;

        TopoDS_Vertex vertex = BRepBuilderAPI_MakeVertex(gp_Pnt(px, py, pz));
        BRepExtrema_ExtPC ext(vertex, edge);
        if (!ext.IsDone()) return result;

        result.solutionCount = ext.NbExt();
        if (result.solutionCount >= 1) {
            // Find minimum distance
            double minDist2 = ext.SquareDistance(1);
            int minIdx = 1;
            for (int i = 2; i <= ext.NbExt(); i++) {
                if (ext.SquareDistance(i) < minDist2) {
                    minDist2 = ext.SquareDistance(i);
                    minIdx = i;
                }
            }
            result.distance = sqrt(minDist2);
            result.parameter = ext.Parameter(minIdx);
            gp_Pnt pt = ext.Point(minIdx);
            result.ptx = pt.X(); result.pty = pt.Y(); result.ptz = pt.Z();
        }
        return result;
    } catch (...) {
        return result;
    }
}
// --- BRepExtrema_ExtCF ---

OCCTEdgeFaceExtremaResult OCCTBRepExtremaExtCF(OCCTShapeRef shape1, int32_t edgeIndex,
                                                OCCTShapeRef shape2, int32_t faceIndex) {
    OCCTEdgeFaceExtremaResult result = {};
    if (!shape1 || !shape2) return result;
    try {
        TopoDS_Edge edge;
        int idx = 0;
        for (TopExp_Explorer exp(shape1->shape, TopAbs_EDGE); exp.More(); exp.Next()) {
            if (idx == edgeIndex) { edge = TopoDS::Edge(exp.Current()); break; }
            idx++;
        }
        if (edge.IsNull()) return result;

        TopoDS_Face face;
        idx = 0;
        for (TopExp_Explorer exp(shape2->shape, TopAbs_FACE); exp.More(); exp.Next()) {
            if (idx == faceIndex) { face = TopoDS::Face(exp.Current()); break; }
            idx++;
        }
        if (face.IsNull()) return result;

        BRepExtrema_ExtCF ext(edge, face);
        if (!ext.IsDone()) return result;

        result.isParallel = ext.IsParallel();
        if (result.isParallel) {
            result.solutionCount = 0;
            return result;
        }

        result.solutionCount = ext.NbExt();
        if (result.solutionCount >= 1) {
            // Find minimum distance
            double minDist2 = ext.SquareDistance(1);
            int minIdx = 1;
            for (int i = 2; i <= ext.NbExt(); i++) {
                if (ext.SquareDistance(i) < minDist2) {
                    minDist2 = ext.SquareDistance(i);
                    minIdx = i;
                }
            }
            result.distance = sqrt(minDist2);
            result.paramOnEdge = ext.ParameterOnEdge(minIdx);
            ext.ParameterOnFace(minIdx, result.uOnFace, result.vOnFace);
            gp_Pnt pe = ext.PointOnEdge(minIdx);
            result.edgePtx = pe.X(); result.edgePty = pe.Y(); result.edgePtz = pe.Z();
            gp_Pnt pf = ext.PointOnFace(minIdx);
            result.facePtx = pf.X(); result.facePty = pf.Y(); result.facePtz = pf.Z();
        }
        return result;
    } catch (...) {
        return result;
    }
}

// MARK: - BRepExtrema_Poly Distance (v0.50)
OCCTPolyDistanceResult OCCTShapePolyhedralDistance(OCCTShapeRef shape1, OCCTShapeRef shape2) {
    OCCTPolyDistanceResult result = {};
    if (!shape1 || !shape2) return result;
    try {
        gp_Pnt p1, p2;
        Standard_Real dist;
        Standard_Boolean ok = BRepExtrema_Poly::Distance(
            shape1->shape, shape2->shape, p1, p2, dist);
        if (ok) {
            result.success = true;
            result.distance = dist;
            result.p1x = p1.X(); result.p1y = p1.Y(); result.p1z = p1.Z();
            result.p2x = p2.X(); result.p2y = p2.Y(); result.p2z = p2.Z();
        }
    } catch (...) {}
    return result;
}

// MARK: - IntCurvesFace Curve-Face Intersection (v0.61)
// MARK: - IntCurvesFace — Curve-Face Intersection (v0.61.0)

int32_t OCCTIntersectLineFace(OCCTShapeRef face,
    double origX, double origY, double origZ,
    double dirX, double dirY, double dirZ,
    double pInf, double pSup,
    double* outPoints, double* outParams, int32_t maxPts) {
    if (!face || !outPoints || !outParams || maxPts <= 0) return 0;
    try {
        if (face->shape.ShapeType() != TopAbs_FACE) return 0;
        TopoDS_Face f = TopoDS::Face(face->shape);
        IntCurvesFace_Intersector intersector(f, 1e-6);
        gp_Lin line(gp_Pnt(origX, origY, origZ), gp_Dir(dirX, dirY, dirZ));
        intersector.Perform(line, pInf, pSup);
        if (!intersector.IsDone()) return 0;
        int32_t nb = std::min((int32_t)intersector.NbPnt(), maxPts);
        for (int32_t i = 0; i < nb; i++) {
            gp_Pnt pt = intersector.Pnt(i + 1);
            outPoints[i * 3] = pt.X();
            outPoints[i * 3 + 1] = pt.Y();
            outPoints[i * 3 + 2] = pt.Z();
            outParams[i] = intersector.WParameter(i + 1);
        }
        return nb;
    } catch (...) { return 0; }
}

// MARK: - IntCurvesFace_ShapeIntersector (v0.62)
// --- IntCurvesFace_ShapeIntersector ---

bool OCCTIntCurvesFaceShapeIntersect(OCCTShapeRef shape,
    double ox, double oy, double oz,
    double dx, double dy, double dz,
    double* _Nullable * _Nonnull outPoints,
    double* _Nullable * _Nonnull outParams,
    int32_t* outCount) {
    if (!shape) return false;
    try {
        IntCurvesFace_ShapeIntersector si;
        si.Load(shape->shape, 1e-6);
        gp_Lin ray(gp_Pnt(ox, oy, oz), gp_Dir(dx, dy, dz));
        si.Perform(ray, -1e10, 1e10);
        int32_t n = si.NbPnt();
        *outCount = n;
        if (n == 0) { *outPoints = nullptr; *outParams = nullptr; return false; }
        si.SortResult();
        *outPoints = (double*)malloc(n * 3 * sizeof(double));
        *outParams = (double*)malloc(n * sizeof(double));
        for (int32_t i = 0; i < n; i++) {
            gp_Pnt pt = si.Pnt(i + 1);
            (*outPoints)[i*3]   = pt.X();
            (*outPoints)[i*3+1] = pt.Y();
            (*outPoints)[i*3+2] = pt.Z();
            (*outParams)[i] = si.WParameter(i + 1);
        }
        return true;
    } catch (...) { return false; }
}

bool OCCTIntCurvesFaceShapeIntersectNearest(OCCTShapeRef shape,
    double ox, double oy, double oz,
    double dx, double dy, double dz,
    double* outX, double* outY, double* outZ,
    double* outParam) {
    if (!shape) return false;
    try {
        IntCurvesFace_ShapeIntersector si;
        si.Load(shape->shape, 1e-6);
        gp_Lin ray(gp_Pnt(ox, oy, oz), gp_Dir(dx, dy, dz));
        si.PerformNearest(ray, -1e10, 1e10);
        if (si.NbPnt() < 1) return false;
        gp_Pnt pt = si.Pnt(1);
        *outX = pt.X(); *outY = pt.Y(); *outZ = pt.Z();
        *outParam = si.WParameter(1);
        return true;
    } catch (...) { return false; }
}

// MARK: - TopTrans_SurfaceTransition (v0.67)
// --- TopTrans_SurfaceTransition ---

static TopAbs_Orientation intToOrientation(int32_t o) {
    switch (o) {
        case 0: return TopAbs_FORWARD;
        case 1: return TopAbs_REVERSED;
        case 2: return TopAbs_INTERNAL;
        case 3: return TopAbs_EXTERNAL;
        default: return TopAbs_FORWARD;
    }
}

void OCCTTopTransSurfaceTransition(
    double tgtX, double tgtY, double tgtZ,
    double normX, double normY, double normZ,
    double surfNormX, double surfNormY, double surfNormZ,
    double tolerance,
    int32_t surfOrientation, int32_t boundOrientation,
    int32_t* _Nonnull outStateBefore, int32_t* _Nonnull outStateAfter) {
    try {
        TopTrans_SurfaceTransition st;
        st.Reset(gp_Dir(tgtX, tgtY, tgtZ), gp_Dir(normX, normY, normZ));
        st.Compare(tolerance, gp_Dir(surfNormX, surfNormY, surfNormZ),
                   intToOrientation(surfOrientation), intToOrientation(boundOrientation));
        *outStateBefore = (int32_t)st.StateBefore();
        *outStateAfter = (int32_t)st.StateAfter();
    } catch (...) {
        *outStateBefore = 3; // UNKNOWN
        *outStateAfter = 3;
    }
}

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
    int32_t* _Nonnull outStateBefore, int32_t* _Nonnull outStateAfter) {
    try {
        TopTrans_SurfaceTransition st;
        st.Reset(gp_Dir(tgtX, tgtY, tgtZ), gp_Dir(normX, normY, normZ),
                 gp_Dir(maxDX, maxDY, maxDZ), gp_Dir(minDX, minDY, minDZ),
                 maxCurv, minCurv);
        st.Compare(tolerance,
                   gp_Dir(surfNormX, surfNormY, surfNormZ),
                   gp_Dir(surfMaxDX, surfMaxDY, surfMaxDZ),
                   gp_Dir(surfMinDX, surfMinDY, surfMinDZ),
                   surfMaxCurv, surfMinCurv,
                   intToOrientation(surfOrientation), intToOrientation(boundOrientation));
        *outStateBefore = (int32_t)st.StateBefore();
        *outStateAfter = (int32_t)st.StateAfter();
    } catch (...) {
        *outStateBefore = 3;
        *outStateAfter = 3;
    }
}

// MARK: - TopTrans_CurveTransition (helper located alongside SurfaceTransition)
// --- TopTrans_CurveTransition ---

void OCCTTopTransCurveTransition(
    double tgtX, double tgtY, double tgtZ,
    double tangX, double tangY, double tangZ,
    double normX, double normY, double normZ,
    double curvature, double tolerance,
    int32_t surfOrientation, int32_t boundOrientation,
    int32_t* outStateBefore, int32_t* outStateAfter)
{
    try {
        TopTrans_CurveTransition ct;
        ct.Reset(gp_Dir(tgtX, tgtY, tgtZ));
        ct.Compare(tolerance,
                   gp_Dir(tangX, tangY, tangZ),
                   gp_Dir(normX, normY, normZ),
                   curvature,
                   intToOrientation(surfOrientation),
                   intToOrientation(boundOrientation));
        *outStateBefore = (int32_t)ct.StateBefore();
        *outStateAfter = (int32_t)ct.StateAfter();
    } catch (...) {
        *outStateBefore = 3;
        *outStateAfter = 3;
    }
}

void OCCTTopTransCurveTransitionWithCurvature(
    double tgtX, double tgtY, double tgtZ,
    double curveNormX, double curveNormY, double curveNormZ,
    double curveCurv,
    double tangX, double tangY, double tangZ,
    double normX, double normY, double normZ,
    double surfCurv, double tolerance,
    int32_t surfOrientation, int32_t boundOrientation,
    int32_t* outStateBefore, int32_t* outStateAfter)
{
    try {
        TopTrans_CurveTransition ct;
        ct.Reset(gp_Dir(tgtX, tgtY, tgtZ),
                 gp_Dir(curveNormX, curveNormY, curveNormZ),
                 curveCurv);
        ct.Compare(tolerance,
                   gp_Dir(tangX, tangY, tangZ),
                   gp_Dir(normX, normY, normZ),
                   surfCurv,
                   intToOrientation(surfOrientation),
                   intToOrientation(boundOrientation));
        *outStateBefore = (int32_t)ct.StateBefore();
        *outStateAfter = (int32_t)ct.StateAfter();
    } catch (...) {
        *outStateBefore = 3;
        *outStateAfter = 3;
    }
}

// MARK: - TopCnx_EdgeFaceTransition (v0.73)
// --- TopCnx_EdgeFaceTransition ---

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
    int32_t faceCount) {
    OCCTEdgeFaceTransitionResult result = {0, 0};
    try {
        TopCnx_EdgeFaceTransition eft;
        gp_Dir tgt(edgeTangentX, edgeTangentY, edgeTangentZ);

        // Check if edge is linear (zero normal)
        double normMag = sqrt(edgeNormalX*edgeNormalX + edgeNormalY*edgeNormalY + edgeNormalZ*edgeNormalZ);
        if (normMag < 1e-10) {
            eft.Reset(tgt);
        } else {
            gp_Dir norm(edgeNormalX, edgeNormalY, edgeNormalZ);
            eft.Reset(tgt, norm, edgeCurvature);
        }

        for (int32_t i = 0; i < faceCount; i++) {
            gp_Dir faceTang(faceTangents[i*3], faceTangents[i*3+1], faceTangents[i*3+2]);
            gp_Dir faceNorm(faceNormals[i*3], faceNormals[i*3+1], faceNormals[i*3+2]);
            eft.AddInterference(tolerances[i], faceTang, faceNorm, faceCurvatures[i],
                (TopAbs_Orientation)faceOrientations[i],
                (TopAbs_Orientation)faceTransitions[i],
                (TopAbs_Orientation)faceBoundaryTransitions[i]);
        }

        result.transition = (int32_t)eft.Transition();
        result.boundaryTransition = (int32_t)eft.BoundaryTransition();
    } catch (...) {}
    return result;
}

// MARK: - BRepIntCurveSurface_Inter (v0.74)
struct OCCTCurveSurfaceInter {
    BRepIntCurveSurface_Inter inter;
};

// --- BRepIntCurveSurface_Inter ---

OCCTCurveSurfaceInterRef _Nullable OCCTCurveSurfaceInterCreateLine(
    OCCTShapeRef _Nonnull shape,
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double tolerance) {
    if (!shape) return nullptr;
    try {
        auto* ref = new OCCTCurveSurfaceInter();
        gp_Lin line(gp_Pnt(originX, originY, originZ), gp_Dir(dirX, dirY, dirZ));
        ref->inter.Init(shape->shape, line, tolerance);
        return ref;
    } catch (...) {
        return nullptr;
    }
}

OCCTCurveSurfaceInterRef _Nullable OCCTCurveSurfaceInterCreateCurve(
    OCCTShapeRef _Nonnull shape,
    OCCTCurve3DRef _Nonnull curve,
    double tolerance) {
    if (!shape || !curve) return nullptr;
    try {
        auto* ref = new OCCTCurveSurfaceInter();
        GeomAdaptor_Curve gac(curve->curve);
        ref->inter.Init(shape->shape, gac, tolerance);
        return ref;
    } catch (...) {
        return nullptr;
    }
}

void OCCTCurveSurfaceInterRelease(OCCTCurveSurfaceInterRef _Nonnull inter) {
    delete inter;
}

bool OCCTCurveSurfaceInterMore(OCCTCurveSurfaceInterRef _Nonnull inter) {
    try { return inter->inter.More(); } catch (...) { return false; }
}

void OCCTCurveSurfaceInterNext(OCCTCurveSurfaceInterRef _Nonnull inter) {
    try { inter->inter.Next(); } catch (...) {}
}

OCCTCurveSurfaceHit OCCTCurveSurfaceInterHit(OCCTCurveSurfaceInterRef _Nonnull inter) {
    OCCTCurveSurfaceHit hit = {};
    try {
        gp_Pnt pt = inter->inter.Pnt();
        hit.x = pt.X(); hit.y = pt.Y(); hit.z = pt.Z();
        hit.u = inter->inter.U();
        hit.v = inter->inter.V();
        hit.w = inter->inter.W();
    } catch (...) {}
    return hit;
}

OCCTFaceRef _Nullable OCCTCurveSurfaceInterFace(OCCTCurveSurfaceInterRef _Nonnull inter) {
    try {
        TopoDS_Face face = inter->inter.Face();
        if (face.IsNull()) return nullptr;
        auto* ref = new OCCTFace();
        ref->face = face;
        return ref;
    } catch (...) {
        return nullptr;
    }
}

int32_t OCCTCurveSurfaceInterAllHits(OCCTCurveSurfaceInterRef _Nonnull inter,
                                      OCCTCurveSurfaceHit* _Nonnull hits,
                                      int32_t maxHits) {
    int32_t count = 0;
    try {
        while (inter->inter.More() && count < maxHits) {
            gp_Pnt pt = inter->inter.Pnt();
            hits[count].x = pt.X(); hits[count].y = pt.Y(); hits[count].z = pt.Z();
            hits[count].u = inter->inter.U();
            hits[count].v = inter->inter.V();
            hits[count].w = inter->inter.W();
            count++;
            inter->inter.Next();
        }
    } catch (...) {}
    return count;
}

// MARK: - BRepExtrema_DistanceSS (v0.79)
// --- BRepExtrema_DistanceSS ---
OCCTDistanceSSResult OCCTBRepExtremaDistanceSS(OCCTShapeRef _Nonnull shape1Ref,
                                                OCCTShapeRef _Nonnull shape2Ref,
                                                double deflection) {
    OCCTDistanceSSResult result = {};
    try {
        const TopoDS_Shape& s1 = *(const TopoDS_Shape*)shape1Ref;
        const TopoDS_Shape& s2 = *(const TopoDS_Shape*)shape2Ref;

        Bnd_Box b1, b2;
        BRepBndLib::Add(s1, b1);
        BRepBndLib::Add(s2, b2);

        BRepExtrema_DistanceSS dss(s1, s2, b1, b2, 1e10, deflection);
        result.isDone = dss.IsDone();
        result.distance = dss.DistValue();
        result.solutionCount = (int)dss.Seq1Value().Size();

        if (result.solutionCount > 0) {
            gp_Pnt p1 = dss.Seq1Value().First().Point();
            gp_Pnt p2 = dss.Seq2Value().First().Point();
            result.point1X = p1.X(); result.point1Y = p1.Y(); result.point1Z = p1.Z();
            result.point2X = p2.X(); result.point2Y = p2.Y(); result.point2Z = p2.Z();
        }
    } catch (...) {}
    return result;
}

// MARK: - v0.92: Bnd_OBB + BRepClass3d
// MARK: - Bnd_OBB (v0.92.0)

#include <Bnd_OBB.hxx>
#include <BRepBndLib.hxx>

struct OCCTOBB {
    Bnd_OBB obb;
};

OCCTOBBRef OCCTOBBCreate(double cx, double cy, double cz,
                           double xDirX, double xDirY, double xDirZ,
                           double yDirX, double yDirY, double yDirZ,
                           double zDirX, double zDirY, double zDirZ,
                           double hx, double hy, double hz) {
    auto* ref = new OCCTOBB();
    ref->obb = Bnd_OBB(gp_Pnt(cx,cy,cz),
                        gp_Dir(xDirX,xDirY,xDirZ),
                        gp_Dir(yDirX,yDirY,yDirZ),
                        gp_Dir(zDirX,zDirY,zDirZ),
                        hx, hy, hz);
    return ref;
}

OCCTOBBRef OCCTOBBCreateFromShape(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        auto* ref = new OCCTOBB();
        Bnd_Box bbox;
        BRepBndLib::Add(shape->shape, bbox);
        ref->obb = Bnd_OBB(bbox);
        return ref;
    } catch (...) { return nullptr; }
}

void OCCTOBBRelease(OCCTOBBRef obb) { delete obb; }

bool OCCTOBBIsVoid(OCCTOBBRef obb) { return obb->obb.IsVoid(); }

void OCCTOBBGetCenter(OCCTOBBRef obb, double* x, double* y, double* z) {
    gp_XYZ c = obb->obb.Center();
    *x = c.X(); *y = c.Y(); *z = c.Z();
}

void OCCTOBBGetHalfSizes(OCCTOBBRef obb, double* hx, double* hy, double* hz) {
    *hx = obb->obb.XHSize(); *hy = obb->obb.YHSize(); *hz = obb->obb.ZHSize();
}

bool OCCTOBBIsOutPoint(OCCTOBBRef obb, double px, double py, double pz) {
    return obb->obb.IsOut(gp_Pnt(px, py, pz));
}

bool OCCTOBBIsOutOBB(OCCTOBBRef obb1, OCCTOBBRef obb2) {
    return obb1->obb.IsOut(obb2->obb);
}

void OCCTOBBEnlarge(OCCTOBBRef obb, double gap) {
    obb->obb.Enlarge(gap);
}

double OCCTOBBSquareExtent(OCCTOBBRef obb) {
    return obb->obb.SquareExtent();
}
// MARK: - BRepClass3d (v0.92.0)

#include <BRepClass3d_SClassifier.hxx>
#include <BRepClass3d_SolidExplorer.hxx>

int32_t OCCTShapeClassifyPoint(OCCTShapeRef shape, double px, double py, double pz, double tolerance) {
    if (!shape) return 3; // UNKNOWN
    try {
        BRepClass3d_SolidExplorer explorer(shape->shape);
        BRepClass3d_SClassifier classifier(explorer, gp_Pnt(px, py, pz), tolerance);
        return (int32_t)classifier.State();
    } catch (...) { return 3; }
}

// MARK: - v0.96-v0.97: BRepClass_FClassifier + Bnd_BoundSortBox
// MARK: - BRepClass_FClassifier (v0.96.0)

#include <BRepClass_FaceExplorer.hxx>
#include <BRepClass_FClassifier.hxx>

int32_t OCCTShapeClassifyPoint2D(OCCTShapeRef shape, int32_t faceIndex,
                                   double u, double v, double tolerance) {
    if (!shape) return 3;
    try {
        TopExp_Explorer faceExp(shape->shape, TopAbs_FACE);
        for (int i = 0; i < faceIndex && faceExp.More(); i++) faceExp.Next();
        if (!faceExp.More()) return 3;
        TopoDS_Face face = TopoDS::Face(faceExp.Current());

        BRepClass_FaceExplorer explorer(face);
        BRepClass_FClassifier classifier(explorer, gp_Pnt2d(u, v), tolerance);
        return (int32_t)classifier.State();
    } catch (...) { return 3; }
}
// MARK: - Bnd_BoundSortBox (v0.97.0)

#include <Bnd_BoundSortBox.hxx>

struct OCCTBoundSortBox {
    Bnd_BoundSortBox sorter;
    Handle(NCollection_HArray1<Bnd_Box>) boxes;
};

OCCTBoundSortBoxRef OCCTBoundSortBoxCreate(const double* boxData, int32_t count) {
    try {
        auto* ref = new OCCTBoundSortBox();
        ref->boxes = new NCollection_HArray1<Bnd_Box>(1, count);
        Bnd_Box enclosing;
        for (int i = 0; i < count; i++) {
            Bnd_Box b;
            b.Update(boxData[i*6], boxData[i*6+1], boxData[i*6+2],
                     boxData[i*6+3], boxData[i*6+4], boxData[i*6+5]);
            ref->boxes->SetValue(i+1, b);
            enclosing.Add(b);
        }
        ref->sorter.Initialize(enclosing, ref->boxes);
        return ref;
    } catch (...) { return new OCCTBoundSortBox(); }
}

void OCCTBoundSortBoxRelease(OCCTBoundSortBoxRef bsb) { delete bsb; }

int32_t OCCTBoundSortBoxCompare(OCCTBoundSortBoxRef bsb,
                                  double xmin, double ymin, double zmin,
                                  double xmax, double ymax, double zmax,
                                  int32_t* outIndices, int32_t maxIndices) {
    try {
        Bnd_Box query;
        query.Update(xmin, ymin, zmin, xmax, ymax, zmax);
        auto& result = bsb->sorter.Compare(query);
        int count = 0;
        for (auto it = result.cbegin(); it != result.cend() && count < maxIndices; ++it) {
            outIndices[count++] = *it;
        }
        return count;
    } catch (...) { return 0; }
}

// MARK: - v0.100: BRepExtrema_SelfIntersection face pair reporting
// --- BRepExtrema_SelfIntersection face pair reporting ---

int32_t OCCTShapeSelfIntersectionPairs(OCCTShapeRef shape, double tolerance,
                                        int32_t* outFaceIdx1, int32_t* outFaceIdx2,
                                        int32_t maxPairs, double deflection) {
    if (!shape || !outFaceIdx1 || !outFaceIdx2 || maxPairs <= 0) return -1;
    try {
        BRepMesh_IncrementalMesh mesher(shape->shape, deflection);

        BRepExtrema_SelfIntersection selfInt(shape->shape, tolerance);
        selfInt.Perform();

        if (!selfInt.IsDone()) return -1;

        const auto& overlaps = selfInt.OverlapElements();
        int32_t count = 0;

        for (NCollection_DataMap<int, TColStd_PackedMapOfInteger>::Iterator it(overlaps);
             it.More() && count < maxPairs; it.Next()) {
            int faceIdx1 = it.Key();
            const TColStd_PackedMapOfInteger& partners = it.Value();
            for (TColStd_PackedMapOfInteger::Iterator mit(partners);
                 mit.More() && count < maxPairs; mit.Next()) {
                int faceIdx2 = mit.Key();
                if (faceIdx2 > faceIdx1) { // avoid duplicates
                    outFaceIdx1[count] = (int32_t)faceIdx1;
                    outFaceIdx2[count] = (int32_t)faceIdx2;
                    count++;
                }
            }
        }
        return count;
    } catch (...) { return -1; }
}

// MARK: - v0.101: BRepLib_FindSurface
// --- BRepLib_FindSurface ---

OCCTSurfaceRef OCCTFindSurface(OCCTShapeRef shape, double tolerance, bool onlyPlane) {
    try {
        BRepLib_FindSurface finder(shape->shape, tolerance, onlyPlane);
        if (!finder.Found()) return nullptr;
        Handle(Geom_Surface) surf = finder.Surface();
        if (surf.IsNull()) return nullptr;
        return new OCCTSurface(surf);
    } catch (...) { return nullptr; }
}

double OCCTFindSurfaceTolerance(OCCTShapeRef shape, double tolerance, bool onlyPlane) {
    try {
        BRepLib_FindSurface finder(shape->shape, tolerance, onlyPlane);
        if (!finder.Found()) return -1.0;
        return finder.ToleranceReached();
    } catch (...) { return -1.0; }
}

bool OCCTFindSurfaceExisted(OCCTShapeRef shape, double tolerance, bool onlyPlane) {
    try {
        BRepLib_FindSurface finder(shape->shape, tolerance, onlyPlane);
        if (!finder.Found()) return false;
        return finder.Existed();
    } catch (...) { return false; }
}

// MARK: - v0.102: TopExp Adjacency + BRepOffset_Analyse Edge Classification + BRepTools_WireExplorer Extensions
// MARK: - TopExp Adjacency (v0.102.0)

bool OCCTEdgeFirstVertex(OCCTShapeRef shape, double* x, double* y, double* z) {
    try {
        TopoDS_Edge edge = TopoDS::Edge(shape->shape);
        TopoDS_Vertex v = TopExp::FirstVertex(edge);
        if (v.IsNull()) return false;
        gp_Pnt p = BRep_Tool::Pnt(v);
        *x = p.X(); *y = p.Y(); *z = p.Z();
        return true;
    } catch (...) { return false; }
}

bool OCCTEdgeLastVertex(OCCTShapeRef shape, double* x, double* y, double* z) {
    try {
        TopoDS_Edge edge = TopoDS::Edge(shape->shape);
        TopoDS_Vertex v = TopExp::LastVertex(edge);
        if (v.IsNull()) return false;
        gp_Pnt p = BRep_Tool::Pnt(v);
        *x = p.X(); *y = p.Y(); *z = p.Z();
        return true;
    } catch (...) { return false; }
}

bool OCCTEdgeVertices(OCCTShapeRef shape,
                      double* x1, double* y1, double* z1,
                      double* x2, double* y2, double* z2) {
    try {
        TopoDS_Edge edge = TopoDS::Edge(shape->shape);
        TopoDS_Vertex v1, v2;
        TopExp::Vertices(edge, v1, v2);
        if (v1.IsNull() || v2.IsNull()) return false;
        gp_Pnt p1 = BRep_Tool::Pnt(v1), p2 = BRep_Tool::Pnt(v2);
        *x1 = p1.X(); *y1 = p1.Y(); *z1 = p1.Z();
        *x2 = p2.X(); *y2 = p2.Y(); *z2 = p2.Z();
        return true;
    } catch (...) { return false; }
}

bool OCCTWireVertices(OCCTShapeRef shape,
                      double* x1, double* y1, double* z1,
                      double* x2, double* y2, double* z2) {
    try {
        TopoDS_Wire wire = TopoDS::Wire(shape->shape);
        TopoDS_Vertex v1, v2;
        TopExp::Vertices(wire, v1, v2);
        if (v1.IsNull()) return false;
        gp_Pnt p1 = BRep_Tool::Pnt(v1);
        *x1 = p1.X(); *y1 = p1.Y(); *z1 = p1.Z();
        if (v2.IsNull()) {
            *x2 = p1.X(); *y2 = p1.Y(); *z2 = p1.Z();
        } else {
            gp_Pnt p2 = BRep_Tool::Pnt(v2);
            *x2 = p2.X(); *y2 = p2.Y(); *z2 = p2.Z();
        }
        return true;
    } catch (...) { return false; }
}

bool OCCTEdgeCommonVertex(OCCTShapeRef edge1, OCCTShapeRef edge2,
                          double* x, double* y, double* z) {
    try {
        TopoDS_Edge e1 = TopoDS::Edge(edge1->shape);
        TopoDS_Edge e2 = TopoDS::Edge(edge2->shape);
        TopoDS_Vertex v;
        if (!TopExp::CommonVertex(e1, e2, v)) return false;
        gp_Pnt p = BRep_Tool::Pnt(v);
        *x = p.X(); *y = p.Y(); *z = p.Z();
        return true;
    } catch (...) { return false; }
}

int32_t OCCTEdgeFaceAdjacency(OCCTShapeRef shape, int32_t* adjacentFaceCounts) {
    try {
        NCollection_IndexedDataMap<TopoDS_Shape, TopTools_ListOfShape, TopTools_ShapeMapHasher> map;
        TopExp::MapShapesAndUniqueAncestors(shape->shape, TopAbs_EDGE, TopAbs_FACE, map);
        int32_t count = (int32_t)map.Extent();
        if (adjacentFaceCounts) {
            for (int i = 1; i <= count; i++) {
                adjacentFaceCounts[i-1] = (int32_t)map(i).Extent();
            }
        }
        return count;
    } catch (...) { return 0; }
}

int32_t OCCTVertexEdgeAdjacency(OCCTShapeRef shape, int32_t* adjacentEdgeCounts) {
    try {
        NCollection_IndexedDataMap<TopoDS_Shape, TopTools_ListOfShape, TopTools_ShapeMapHasher> map;
        TopExp::MapShapesAndUniqueAncestors(shape->shape, TopAbs_VERTEX, TopAbs_EDGE, map);
        int32_t count = (int32_t)map.Extent();
        if (adjacentEdgeCounts) {
            for (int i = 1; i <= count; i++) {
                adjacentEdgeCounts[i-1] = (int32_t)map(i).Extent();
            }
        }
        return count;
    } catch (...) { return 0; }
}

int32_t OCCTEdgeAdjacentFaces(OCCTShapeRef shape, OCCTShapeRef edge,
                              int32_t* faceIndices, int32_t maxFaces) {
    try {
        NCollection_IndexedDataMap<TopoDS_Shape, TopTools_ListOfShape, TopTools_ShapeMapHasher> map;
        TopExp::MapShapesAndUniqueAncestors(shape->shape, TopAbs_EDGE, TopAbs_FACE, map);
        // Find the edge in the map
        TopoDS_Edge e = TopoDS::Edge(edge->shape);
        int edgeIdx = map.FindIndex(e);
        if (edgeIdx == 0) return 0;
        // Build face index map for lookup
        NCollection_IndexedMap<TopoDS_Shape, TopTools_ShapeMapHasher> faceMap;
        TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);
        const TopTools_ListOfShape& faces = map(edgeIdx);
        int32_t count = 0;
        for (auto it = faces.cbegin(); it != faces.cend() && count < maxFaces; ++it) {
            int fi = faceMap.FindIndex(*it);
            if (fi > 0) faceIndices[count++] = (int32_t)fi;
        }
        return count;
    } catch (...) { return 0; }
}

int32_t OCCTVertexAdjacentEdges(OCCTShapeRef shape, OCCTShapeRef vertex,
                                int32_t* edgeIndices, int32_t maxEdges) {
    try {
        NCollection_IndexedDataMap<TopoDS_Shape, TopTools_ListOfShape, TopTools_ShapeMapHasher> map;
        TopExp::MapShapesAndUniqueAncestors(shape->shape, TopAbs_VERTEX, TopAbs_EDGE, map);
        TopoDS_Vertex v = TopoDS::Vertex(vertex->shape);
        int vertIdx = map.FindIndex(v);
        if (vertIdx == 0) return 0;
        NCollection_IndexedMap<TopoDS_Shape, TopTools_ShapeMapHasher> edgeMap;
        TopExp::MapShapes(shape->shape, TopAbs_EDGE, edgeMap);
        const TopTools_ListOfShape& edges = map(vertIdx);
        int32_t count = 0;
        for (auto it = edges.cbegin(); it != edges.cend() && count < maxEdges; ++it) {
            int ei = edgeMap.FindIndex(*it);
            if (ei > 0) edgeIndices[count++] = (int32_t)ei;
        }
        return count;
    } catch (...) { return 0; }
}
// MARK: - BRepOffset_Analyse Edge Classification (v0.102.0)

// Map our convention (0=Convex,1=Concave,2=Tangent) to ChFiDS (0=Concave,1=Convex,2=Tangential)
static ChFiDS_TypeOfConcavity _mapConcavity(int32_t ourType) {
    switch (ourType) {
        case 0: return ChFiDS_Convex;
        case 1: return ChFiDS_Concave;
        case 2: return ChFiDS_Tangential;
        default: return ChFiDS_Convex;
    }
}

static int32_t _mapConcavityBack(ChFiDS_TypeOfConcavity chiType) {
    switch (chiType) {
        case ChFiDS_Convex: return 0;
        case ChFiDS_Concave: return 1;
        case ChFiDS_Tangential: return 2;
        case ChFiDS_FreeBound: return 3;
        default: return 4;
    }
}

int32_t OCCTAnalyseEdgeConcavity(OCCTShapeRef shape, double angle, int32_t* edgeTypes) {
    try {
        BRepOffset_Analyse analyse(shape->shape, angle);
        if (!analyse.IsDone()) return 0;
        NCollection_IndexedMap<TopoDS_Shape, TopTools_ShapeMapHasher> edges;
        TopExp::MapShapes(shape->shape, TopAbs_EDGE, edges);
        int32_t count = (int32_t)edges.Extent();
        if (edgeTypes) {
            for (int i = 1; i <= count; i++) {
                TopoDS_Edge e = TopoDS::Edge(edges(i));
                const NCollection_List<BRepOffset_Interval>& intervals = analyse.Type(e);
                if (intervals.IsEmpty()) {
                    edgeTypes[i-1] = 4; // Other
                } else {
                    edgeTypes[i-1] = _mapConcavityBack(intervals.First().Type());
                }
            }
        }
        return count;
    } catch (...) { return 0; }
}

OCCTShapeRef OCCTAnalyseExplode(OCCTShapeRef shape, double angle, int32_t concavityType) {
    try {
        BRepOffset_Analyse analyse(shape->shape, angle);
        if (!analyse.IsDone()) return nullptr;
        ChFiDS_TypeOfConcavity type = _mapConcavity(concavityType);
        TopTools_ListOfShape groups;
        analyse.Explode(groups, type);
        if (groups.IsEmpty()) return nullptr;
        // Build compound from all groups
        BRep_Builder bb;
        TopoDS_Compound compound;
        bb.MakeCompound(compound);
        for (auto it = groups.cbegin(); it != groups.cend(); ++it) {
            bb.Add(compound, *it);
        }
        auto result = new OCCTShape();
        result->shape = compound;
        return result;
    } catch (...) { return nullptr; }
}

int32_t OCCTAnalyseEdgesOnFace(OCCTShapeRef shape, double angle, OCCTShapeRef face, int32_t concavityType) {
    try {
        BRepOffset_Analyse analyse(shape->shape, angle);
        if (!analyse.IsDone()) return 0;
        ChFiDS_TypeOfConcavity type = _mapConcavity(concavityType);
        TopoDS_Face f = TopoDS::Face(face->shape);
        TopTools_ListOfShape edges;
        analyse.Edges(f, type, edges);
        return (int32_t)edges.Extent();
    } catch (...) { return 0; }
}

int32_t OCCTAnalyseAncestorCount(OCCTShapeRef shape, double angle, OCCTShapeRef edge) {
    try {
        BRepOffset_Analyse analyse(shape->shape, angle);
        if (!analyse.IsDone()) return 0;
        if (!analyse.HasAncestor(edge->shape)) return 0;
        const NCollection_List<TopoDS_Shape>& ancestors = analyse.Ancestors(edge->shape);
        return (int32_t)ancestors.Extent();
    } catch (...) { return 0; }
}

int32_t OCCTAnalyseTangentEdgeCount(OCCTShapeRef shape, double angle, OCCTShapeRef edge, OCCTShapeRef vertex) {
    try {
        BRepOffset_Analyse analyse(shape->shape, angle);
        if (!analyse.IsDone()) return 0;
        TopoDS_Edge e = TopoDS::Edge(edge->shape);
        TopoDS_Vertex v = TopoDS::Vertex(vertex->shape);
        TopTools_ListOfShape tangents;
        analyse.TangentEdges(e, v, tangents);
        return (int32_t)tangents.Extent();
    } catch (...) { return 0; }
}
// MARK: - BRepTools_WireExplorer Extensions (v0.102.0)

int32_t OCCTWireExplorerOrientations(OCCTShapeRef wire, OCCTShapeRef face, int32_t* orientations) {
    try {
        TopoDS_Wire w = TopoDS::Wire(wire->shape);
        BRepTools_WireExplorer we;
        if (face) {
            TopoDS_Face f = TopoDS::Face(face->shape);
            we.Init(w, f);
        } else {
            we.Init(w);
        }
        int32_t count = 0;
        while (we.More()) {
            if (orientations) {
                orientations[count] = (int32_t)we.Orientation();
            }
            count++;
            we.Next();
        }
        return count;
    } catch (...) { return 0; }
}

int32_t OCCTWireExplorerVertices(OCCTShapeRef wire, OCCTShapeRef face,
                                  double* xs, double* ys, double* zs) {
    try {
        TopoDS_Wire w = TopoDS::Wire(wire->shape);
        BRepTools_WireExplorer we;
        if (face) {
            TopoDS_Face f = TopoDS::Face(face->shape);
            we.Init(w, f);
        } else {
            we.Init(w);
        }
        int32_t count = 0;
        while (we.More()) {
            if (xs) {
                TopoDS_Vertex v = we.CurrentVertex();
                if (!v.IsNull()) {
                    gp_Pnt p = BRep_Tool::Pnt(v);
                    xs[count] = p.X(); ys[count] = p.Y(); zs[count] = p.Z();
                }
            }
            count++;
            we.Next();
        }
        return count;
    } catch (...) { return 0; }
}

// MARK: - v0.105: BRepTools_ReShape + BRepLib_MakeVertex
// MARK: - BRepTools_ReShape (v0.105.0)

struct OCCTReShape {
    Handle(BRepTools_ReShape) rs;
    OCCTReShape() : rs(new BRepTools_ReShape()) {}
};

OCCTReShapeRef OCCTReShapeCreate(void) {
    return new OCCTReShape();
}

void OCCTReShapeRelease(OCCTReShapeRef rs) { delete rs; }

void OCCTReShapeClear(OCCTReShapeRef rs) {
    if (!rs) return;
    try { rs->rs->Clear(); } catch (...) {}
}

void OCCTReShapeRemove(OCCTReShapeRef rs, OCCTShapeRef shape) {
    if (!rs || !shape) return;
    try { rs->rs->Remove(shape->shape); } catch (...) {}
}

void OCCTReShapeReplace(OCCTReShapeRef rs, OCCTShapeRef oldShape, OCCTShapeRef newShape) {
    if (!rs || !oldShape || !newShape) return;
    try { rs->rs->Replace(oldShape->shape, newShape->shape); } catch (...) {}
}

bool OCCTReShapeIsRecorded(OCCTReShapeRef rs, OCCTShapeRef shape) {
    if (!rs || !shape) return false;
    try { return rs->rs->IsRecorded(shape->shape); } catch (...) { return false; }
}

OCCTShapeRef OCCTReShapeApply(OCCTReShapeRef rs, OCCTShapeRef shape) {
    if (!rs || !shape) return nullptr;
    try {
        TopoDS_Shape result = rs->rs->Apply(shape->shape);
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTReShapeValue(OCCTReShapeRef rs, OCCTShapeRef shape) {
    if (!rs || !shape) return nullptr;
    try {
        TopoDS_Shape result = rs->rs->Value(shape->shape);
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) { return nullptr; }
}

// MARK: - BRepTools_Substitution (v0.105.0)

#include <BRepTools_Substitution.hxx>

OCCTShapeRef OCCTShapeSubstitute(OCCTShapeRef shape, OCCTShapeRef oldSub,
                                  OCCTShapeRef* newSubs, int32_t newCount) {
    if (!shape || !oldSub) return nullptr;
    try {
        BRepTools_Substitution sub;
        NCollection_List<TopoDS_Shape> newList;
        if (newSubs && newCount > 0) {
            for (int32_t i = 0; i < newCount; i++) {
                if (newSubs[i]) newList.Append(newSubs[i]->shape);
            }
        }
        sub.Substitute(oldSub->shape, newList);
        sub.Build(shape->shape);
        if (!sub.IsCopied(shape->shape)) return nullptr;
        const NCollection_List<TopoDS_Shape>& copies = sub.Copy(shape->shape);
        if (copies.IsEmpty()) return nullptr;
        return new OCCTShape(copies.First());
    } catch (...) { return nullptr; }
}

bool OCCTSubstitutionIsCopied(OCCTShapeRef shape, OCCTShapeRef subshape) {
    if (!shape || !subshape) return false;
    try {
        BRepTools_Substitution sub;
        NCollection_List<TopoDS_Shape> empty;
        sub.Substitute(subshape->shape, empty);
        sub.Build(shape->shape);
        return sub.IsCopied(shape->shape);
    } catch (...) { return false; }
}
// MARK: - BRepLib_MakeVertex (v0.105.0)

#include <BRepLib_MakeVertex.hxx>
#include <BRep_Tool.hxx>

OCCTShapeRef OCCTMakeVertex(double x, double y, double z) {
    try {
        BRepLib_MakeVertex mv(gp_Pnt(x, y, z));
        TopoDS_Vertex v = mv.Vertex();
        return new OCCTShape(v);
    } catch (...) { return nullptr; }
}

// MARK: - v0.106: Shape topology extensions
// MARK: - Shape topology extensions (v0.106.0)

int32_t OCCTShapeGetOrientation(OCCTShapeRef shape) {
    if (!shape) return 0;
    return static_cast<int32_t>(shape->shape.Orientation());
}

void OCCTShapeSetOrientation(OCCTShapeRef shape, int32_t orientation) {
    if (!shape) return;
    shape->shape.Orientation(static_cast<TopAbs_Orientation>(orientation));
}

OCCTShapeRef OCCTShapeReversed(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        auto result = new OCCTShape();
        result->shape = shape->shape.Reversed();
        return result;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTShapeComplemented(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        auto result = new OCCTShape();
        result->shape = shape->shape.Complemented();
        return result;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTShapeComposed(OCCTShapeRef shape, int32_t orientation) {
    if (!shape) return nullptr;
    try {
        auto result = new OCCTShape();
        result->shape = shape->shape.Composed(static_cast<TopAbs_Orientation>(orientation));
        return result;
    } catch (...) { return nullptr; }
}

bool OCCTShapeIsFree(OCCTShapeRef shape) {
    if (!shape) return false;
    return shape->shape.Free();
}

bool OCCTShapeIsModified(OCCTShapeRef shape) {
    if (!shape) return false;
    return shape->shape.Modified();
}

bool OCCTShapeIsChecked(OCCTShapeRef shape) {
    if (!shape) return false;
    return shape->shape.Checked();
}

bool OCCTShapeIsOrientable(OCCTShapeRef shape) {
    if (!shape) return false;
    return shape->shape.Orientable();
}

bool OCCTShapeIsInfinite(OCCTShapeRef shape) {
    if (!shape) return false;
    return shape->shape.Infinite();
}

bool OCCTShapeIsConvex(OCCTShapeRef shape) {
    if (!shape) return false;
    return shape->shape.Convex();
}

bool OCCTShapeIsEmpty(OCCTShapeRef shape) {
    if (!shape) return true;
    return shape->shape.IsNull();
}

bool OCCTShapeIsPartner(OCCTShapeRef shape1, OCCTShapeRef shape2) {
    if (!shape1 || !shape2) return false;
    return shape1->shape.IsPartner(shape2->shape);
}

bool OCCTShapeIsEqual(OCCTShapeRef shape1, OCCTShapeRef shape2) {
    if (!shape1 || !shape2) return false;
    return shape1->shape.IsEqual(shape2->shape);
}

int32_t OCCTShapeNbChildren(OCCTShapeRef shape) {
    if (!shape) return 0;
    return shape->shape.NbChildren();
}

int32_t OCCTShapeHashCode(OCCTShapeRef shape) {
    if (!shape) return 0;
    return static_cast<int32_t>(std::hash<TopoDS_Shape>{}(shape->shape) & 0x7FFFFFFF);
}

// MARK: - v0.107: BRepTools/BRepLib Utilities + Edge/Face Extraction
// MARK: - BRepTools/BRepLib Utilities (v0.107.0)

void OCCTShapeClean(OCCTShapeRef shape) {
    if (!shape) return;
    try { BRepTools::Clean(shape->shape); } catch (...) {}
}

void OCCTShapeCleanGeometry(OCCTShapeRef shape) {
    if (!shape) return;
    try { BRepTools::CleanGeometry(shape->shape); } catch (...) {}
}

void OCCTShapeRemoveUnusedPCurves(OCCTShapeRef shape) {
    if (!shape) return;
    try { BRepTools::RemoveUnusedPCurves(shape->shape); } catch (...) {}
}

void OCCTShapeUpdate(OCCTShapeRef shape) {
    if (!shape) return;
    try { BRepTools::Update(shape->shape); } catch (...) {}
}

bool OCCTBRepLibCheckSameRange(OCCTShapeRef edge) {
    if (!edge) return false;
    try { return BRepLib::CheckSameRange(TopoDS::Edge(edge->shape)); } catch (...) { return false; }
}

bool OCCTBRepLibSameRange(OCCTShapeRef edge, double tol) {
    if (!edge) return false;
    try { BRepLib::SameRange(TopoDS::Edge(edge->shape), tol); return true; } catch (...) { return false; }
}

bool OCCTBRepLibBuildCurve3d(OCCTShapeRef edge, double tol) {
    if (!edge) return false;
    try { return BRepLib::BuildCurve3d(TopoDS::Edge(edge->shape), tol); } catch (...) { return false; }
}

void OCCTBRepLibUpdateTolerances(OCCTShapeRef shape) {
    if (!shape) return;
    try { BRepLib::UpdateTolerances(shape->shape); } catch (...) {}
}

void OCCTBRepLibUpdateInnerTolerances(OCCTShapeRef shape) {
    if (!shape) return;
    try { BRepLib::UpdateInnerTolerances(shape->shape); } catch (...) {}
}

bool OCCTBRepLibUpdateEdgeTolerance(OCCTShapeRef edge, double tol) {
    if (!edge) return false;
    try { return BRepLib::UpdateEdgeTol(TopoDS::Edge(edge->shape), tol, tol * 100.0); } catch (...) { return false; }
}
// MARK: - Edge/Face Extraction (v0.107.0)

OCCTCurve3DRef OCCTEdgeExtractCurve3D(OCCTShapeRef edge, double* first, double* last) {
    *first = 0; *last = 0;
    if (!edge) return nullptr;
    try {
        double f, l;
        Handle(Geom_Curve) curve = BRep_Tool::Curve(TopoDS::Edge(edge->shape), f, l);
        if (curve.IsNull()) return nullptr;
        *first = f; *last = l;
        auto result = new OCCTCurve3D(curve);
        return result;
    } catch (...) { return nullptr; }
}

OCCTCurve2DRef OCCTEdgeExtractPCurve(OCCTShapeRef edge, OCCTShapeRef face, double* first, double* last) {
    *first = 0; *last = 0;
    if (!edge || !face) return nullptr;
    try {
        double f, l;
        Handle(Geom2d_Curve) pcurve = BRep_Tool::CurveOnSurface(
            TopoDS::Edge(edge->shape), TopoDS::Face(face->shape), f, l);
        if (pcurve.IsNull()) return nullptr;
        *first = f; *last = l;
        auto result = new OCCTCurve2D(pcurve);
        return result;
    } catch (...) { return nullptr; }
}

double OCCTEdgeGetTolerance(OCCTShapeRef edge) {
    if (!edge) return 0;
    try { return BRep_Tool::Tolerance(TopoDS::Edge(edge->shape)); } catch (...) { return 0; }
}

bool OCCTEdgeIsDegenerated(OCCTShapeRef edge) {
    if (!edge) return false;
    try { return BRep_Tool::Degenerated(TopoDS::Edge(edge->shape)); } catch (...) { return false; }
}

OCCTSurfaceRef OCCTFaceExtractSurface(OCCTShapeRef face) {
    if (!face) return nullptr;
    try {
        Handle(Geom_Surface) surf = BRep_Tool::Surface(TopoDS::Face(face->shape));
        if (surf.IsNull()) return nullptr;
        return new OCCTSurface(surf);
    } catch (...) { return nullptr; }
}

double OCCTFaceGetTolerance(OCCTShapeRef face) {
    if (!face) return 0;
    try { return BRep_Tool::Tolerance(TopoDS::Face(face->shape)); } catch (...) { return 0; }
}

int32_t OCCTFaceWireCount(OCCTShapeRef face) {
    if (!face) return 0;
    try {
        int count = 0;
        for (TopExp_Explorer ex(face->shape, TopAbs_WIRE); ex.More(); ex.Next()) count++;
        return count;
    } catch (...) { return 0; }
}

double OCCTVertexGetTolerance(OCCTShapeRef vertex) {
    if (!vertex) return 0;
    try { return BRep_Tool::Tolerance(TopoDS::Vertex(vertex->shape)); } catch (...) { return 0; }
}

void OCCTVertexGetPoint(OCCTShapeRef vertex, double* x, double* y, double* z) {
    *x = 0; *y = 0; *z = 0;
    if (!vertex) return;
    try {
        gp_Pnt p = BRep_Tool::Pnt(TopoDS::Vertex(vertex->shape));
        *x = p.X(); *y = p.Y(); *z = p.Z();
    } catch (...) {}
}

// MARK: - v0.109: Shape Topology Counting
// MARK: - Shape Topology Counting (v0.109.0)

int32_t OCCTShapeCountFaces(OCCTShapeRef shape) {
    if (!shape) return 0;
    try {
        int count = 0;
        for (TopExp_Explorer ex(shape->shape, TopAbs_FACE); ex.More(); ex.Next()) count++;
        return count;
    } catch (...) { return 0; }
}

int32_t OCCTShapeCountEdges(OCCTShapeRef shape) {
    if (!shape) return 0;
    try {
        int count = 0;
        for (TopExp_Explorer ex(shape->shape, TopAbs_EDGE); ex.More(); ex.Next()) count++;
        return count;
    } catch (...) { return 0; }
}

char* OCCTShapeTypeString(OCCTShapeRef shape) {
    if (!shape) return strdup("null");
    try {
        switch (shape->shape.ShapeType()) {
            case TopAbs_COMPOUND:  return strdup("compound");
            case TopAbs_COMPSOLID: return strdup("compsolid");
            case TopAbs_SOLID:     return strdup("solid");
            case TopAbs_SHELL:     return strdup("shell");
            case TopAbs_FACE:      return strdup("face");
            case TopAbs_WIRE:      return strdup("wire");
            case TopAbs_EDGE:      return strdup("edge");
            case TopAbs_VERTEX:    return strdup("vertex");
            default:               return strdup("shape");
        }
    } catch (...) { return strdup("unknown"); }
}

// MARK: - v0.112: Additional Shape operations + Wire/Face construction
// --- Additional Shape operations ---

OCCTShapeRef OCCTShapeChild(OCCTShapeRef shape, int32_t index) {
    if (!shape) return nullptr;
    try {
        TopoDS_Iterator it(shape->shape);
        for (int32_t i = 0; i < index && it.More(); i++, it.Next()) {}
        if (!it.More()) return nullptr;
        OCCTShape* result = new OCCTShape();
        result->shape = it.Value();
        return result;
    } catch (...) { return nullptr; }
}

bool OCCTShapeIsLocked(OCCTShapeRef shape) {
    if (!shape) return false;
    return shape->shape.Locked();
}

void OCCTShapeSetLocked(OCCTShapeRef shape, bool locked) {
    if (!shape) return;
    shape->shape.Locked(locked);
}

static gp_Trsf trsfFromMatrix12(const double* m) {
    gp_Trsf t;
    t.SetValues(m[0], m[1], m[2], m[3],
                m[4], m[5], m[6], m[7],
                m[8], m[9], m[10], m[11]);
    return t;
}

static void matrix12FromTrsf(const gp_Trsf& t, double* m) {
    m[0] = t.Value(1,1); m[1] = t.Value(1,2); m[2] = t.Value(1,3); m[3] = t.Value(1,4);
    m[4] = t.Value(2,1); m[5] = t.Value(2,2); m[6] = t.Value(2,3); m[7] = t.Value(2,4);
    m[8] = t.Value(3,1); m[9] = t.Value(3,2); m[10] = t.Value(3,3); m[11] = t.Value(3,4);
}

OCCTShapeRef OCCTShapeLocated(OCCTShapeRef shape, const double* matrix12) {
    if (!shape) return nullptr;
    try {
        gp_Trsf t = trsfFromMatrix12(matrix12);
        TopLoc_Location loc(t);
        OCCTShape* result = new OCCTShape();
        result->shape = shape->shape.Located(loc);
        return result;
    } catch (...) { return nullptr; }
}

void OCCTShapeGetLocation(OCCTShapeRef shape, double* matrix12) {
    if (!shape) return;
    try {
        gp_Trsf t = shape->shape.Location().IsIdentity() ? gp_Trsf() : shape->shape.Location().Transformation();
        matrix12FromTrsf(t, matrix12);
    } catch (...) {}
}

void OCCTShapeSetLocation(OCCTShapeRef shape, const double* matrix12) {
    if (!shape) return;
    try {
        gp_Trsf t = trsfFromMatrix12(matrix12);
        TopLoc_Location loc(t);
        shape->shape.Location(loc);
    } catch (...) {}
}

OCCTShapeRef OCCTShapeOriented(OCCTShapeRef shape, int32_t orientation) {
    if (!shape) return nullptr;
    try {
        OCCTShape* result = new OCCTShape();
        result->shape = shape->shape.Oriented(static_cast<TopAbs_Orientation>(orientation));
        return result;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTShapeCompounded(const OCCTShapeRef* shapes, int32_t count) {
    try {
        BRep_Builder builder;
        TopoDS_Compound compound;
        builder.MakeCompound(compound);
        for (int32_t i = 0; i < count; i++) {
            if (shapes[i]) builder.Add(compound, shapes[i]->shape);
        }
        OCCTShape* result = new OCCTShape();
        result->shape = compound;
        return result;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTShapeEmpty(int32_t type) {
    try {
        BRep_Builder builder;
        OCCTShape* result = new OCCTShape();
        switch (type) {
            case 0: { // COMPOUND
                TopoDS_Compound c;
                builder.MakeCompound(c);
                result->shape = c;
                break;
            }
            case 1: { // COMPSOLID
                TopoDS_CompSolid cs;
                builder.MakeCompSolid(cs);
                result->shape = cs;
                break;
            }
            case 2: { // SOLID
                TopoDS_Solid s;
                builder.MakeSolid(s);
                result->shape = s;
                break;
            }
            case 3: { // SHELL
                TopoDS_Shell sh;
                builder.MakeShell(sh);
                result->shape = sh;
                break;
            }
            case 5: { // WIRE
                TopoDS_Wire w;
                builder.MakeWire(w);
                result->shape = w;
                break;
            }
            default:
                delete result;
                return nullptr;
        }
        return result;
    } catch (...) { return nullptr; }
}

// --- Wire/Face construction ---

OCCTShapeRef OCCTMakeWireFromEdges(const OCCTShapeRef* edges, int32_t count) {
    try {
        BRepBuilderAPI_MakeWire mw;
        for (int32_t i = 0; i < count; i++) {
            if (edges[i]) mw.Add(TopoDS::Edge(edges[i]->shape));
        }
        if (!mw.IsDone()) return nullptr;
        OCCTShape* result = new OCCTShape();
        result->shape = mw.Wire();
        return result;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTMakeCompound(const OCCTShapeRef* shapes, int32_t count) {
    return OCCTShapeCompounded(shapes, count);
}

OCCTShapeRef OCCTMakeShell(const OCCTShapeRef* faces, int32_t count) {
    try {
        BRep_Builder builder;
        TopoDS_Shell shell;
        builder.MakeShell(shell);
        for (int32_t i = 0; i < count; i++) {
            if (faces[i]) builder.Add(shell, TopoDS::Face(faces[i]->shape));
        }
        OCCTShape* result = new OCCTShape();
        result->shape = shell;
        return result;
    } catch (...) { return nullptr; }
}

bool OCCTShapeIsCompound(OCCTShapeRef shape) {
    if (!shape) return false;
    return shape->shape.ShapeType() == TopAbs_COMPOUND;
}

bool OCCTShapeIsSolid(OCCTShapeRef shape) {
    if (!shape) return false;
    return shape->shape.ShapeType() == TopAbs_SOLID;
}

bool OCCTShapeIsShell(OCCTShapeRef shape) {
    if (!shape) return false;
    return shape->shape.ShapeType() == TopAbs_SHELL;
}

bool OCCTShapeIsFace(OCCTShapeRef shape) {
    if (!shape) return false;
    return shape->shape.ShapeType() == TopAbs_FACE;
}

bool OCCTShapeIsEdge(OCCTShapeRef shape) {
    if (!shape) return false;
    return shape->shape.ShapeType() == TopAbs_EDGE;
}

// MARK: - v0.113: BRepExtrema_DistShapeShape (full results)
// --- BRepExtrema_DistShapeShape (full results) ---

struct OCCTDistSS {
    BRepExtrema_DistShapeShape dist;
};

OCCTDistSSRef OCCTDistSSCreate(OCCTShapeRef s1, OCCTShapeRef s2) {
    if (!s1 || !s2) return nullptr;
    try {
        auto ref = new OCCTDistSS();
        ref->dist.LoadS1(s1->shape);
        ref->dist.LoadS2(s2->shape);
        ref->dist.Perform();
        return ref;
    } catch (...) { return nullptr; }
}

void OCCTDistSSRelease(OCCTDistSSRef dist) {
    delete dist;
}

bool OCCTDistSSIsDone(OCCTDistSSRef dist) {
    if (!dist) return false;
    return dist->dist.IsDone();
}

double OCCTDistSSValue(OCCTDistSSRef dist) {
    if (!dist) return -1;
    try { return dist->dist.Value(); }
    catch (...) { return -1; }
}

int32_t OCCTDistSSNbSolution(OCCTDistSSRef dist) {
    if (!dist) return 0;
    try { return (int32_t)dist->dist.NbSolution(); }
    catch (...) { return 0; }
}

void OCCTDistSSPointOnShape1(OCCTDistSSRef dist, int32_t index,
                              double* x, double* y, double* z) {
    if (!dist) { *x = *y = *z = 0; return; }
    try {
        gp_Pnt p = dist->dist.PointOnShape1(index);
        *x = p.X(); *y = p.Y(); *z = p.Z();
    } catch (...) { *x = *y = *z = 0; }
}

void OCCTDistSSPointOnShape2(OCCTDistSSRef dist, int32_t index,
                              double* x, double* y, double* z) {
    if (!dist) { *x = *y = *z = 0; return; }
    try {
        gp_Pnt p = dist->dist.PointOnShape2(index);
        *x = p.X(); *y = p.Y(); *z = p.Z();
    } catch (...) { *x = *y = *z = 0; }
}

int32_t OCCTDistSSSupportType1(OCCTDistSSRef dist, int32_t index) {
    if (!dist) return -1;
    try {
        BRepExtrema_SupportType t = dist->dist.SupportTypeShape1(index);
        switch (t) {
            case BRepExtrema_IsVertex: return 0;
            case BRepExtrema_IsOnEdge: return 1;
            case BRepExtrema_IsInFace: return 2;
            default: return -1;
        }
    } catch (...) { return -1; }
}

int32_t OCCTDistSSSupportType2(OCCTDistSSRef dist, int32_t index) {
    if (!dist) return -1;
    try {
        BRepExtrema_SupportType t = dist->dist.SupportTypeShape2(index);
        switch (t) {
            case BRepExtrema_IsVertex: return 0;
            case BRepExtrema_IsOnEdge: return 1;
            case BRepExtrema_IsInFace: return 2;
            default: return -1;
        }
    } catch (...) { return -1; }
}

OCCTShapeRef OCCTDistSSSupportShape1(OCCTDistSSRef dist, int32_t index) {
    if (!dist) return nullptr;
    try {
        TopoDS_Shape s = dist->dist.SupportOnShape1(index);
        if (s.IsNull()) return nullptr;
        auto ref = new OCCTShape();
        ref->shape = s;
        return ref;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTDistSSSupportShape2(OCCTDistSSRef dist, int32_t index) {
    if (!dist) return nullptr;
    try {
        TopoDS_Shape s = dist->dist.SupportOnShape2(index);
        if (s.IsNull()) return nullptr;
        auto ref = new OCCTShape();
        ref->shape = s;
        return ref;
    } catch (...) { return nullptr; }
}

// MARK: - v0.114: TopoDS_Builder + BRepLib utilities + BRep_Tool queries + unique counts + Curve3D type-name + EmptyCopy
// --- TopoDS_Builder ---

#include <TopoDS_Builder.hxx>
#include <TopoDS_CompSolid.hxx>

OCCTShapeRef OCCTBuilderMakeWire() {
    try {
        TopoDS_Builder builder;
        TopoDS_Wire wire;
        builder.MakeWire(wire);
        auto ref = new OCCTShape();
        ref->shape = wire;
        return ref;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTBuilderMakeShell() {
    try {
        TopoDS_Builder builder;
        TopoDS_Shell shell;
        builder.MakeShell(shell);
        auto ref = new OCCTShape();
        ref->shape = shell;
        return ref;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTBuilderMakeSolid() {
    try {
        TopoDS_Builder builder;
        TopoDS_Solid solid;
        builder.MakeSolid(solid);
        auto ref = new OCCTShape();
        ref->shape = solid;
        return ref;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTBuilderMakeCompound() {
    try {
        TopoDS_Builder builder;
        TopoDS_Compound compound;
        builder.MakeCompound(compound);
        auto ref = new OCCTShape();
        ref->shape = compound;
        return ref;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTBuilderMakeCompSolid() {
    try {
        TopoDS_Builder builder;
        TopoDS_CompSolid cs;
        builder.MakeCompSolid(cs);
        auto ref = new OCCTShape();
        ref->shape = cs;
        return ref;
    } catch (...) { return nullptr; }
}

bool OCCTBuilderAdd(OCCTShapeRef parent, OCCTShapeRef child) {
    if (!parent || !child) return false;
    try {
        TopoDS_Builder builder;
        builder.Add(parent->shape, child->shape);
        return true;
    } catch (...) { return false; }
}

bool OCCTBuilderRemove(OCCTShapeRef parent, OCCTShapeRef child) {
    if (!parent || !child) return false;
    try {
        TopoDS_Builder builder;
        builder.Remove(parent->shape, child->shape);
        return true;
    } catch (...) { return false; }
}
// --- BRepLib utilities ---

bool OCCTBRepLibOrientClosedSolid(OCCTShapeRef shape) {
    if (!shape) return false;
    try {
        TopoDS_Solid solid = TopoDS::Solid(shape->shape);
        return BRepLib::OrientClosedSolid(solid);
    } catch (...) { return false; }
}

bool OCCTBRepLibBuildCurves3dForShape(OCCTShapeRef shape, double tolerance) {
    if (!shape) return false;
    try {
        return BRepLib::BuildCurves3d(shape->shape, tolerance);
    } catch (...) { return false; }
}

OCCTShapeRef OCCTBRepLibSortFaces(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        NCollection_List<TopoDS_Shape> faceList;
        BRepLib::SortFaces(shape->shape, faceList);
        BRep_Builder builder;
        TopoDS_Compound compound;
        builder.MakeCompound(compound);
        for (auto it = faceList.cbegin(); it != faceList.cend(); ++it) {
            builder.Add(compound, *it);
        }
        auto ref = new OCCTShape();
        ref->shape = compound;
        return ref;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTBRepLibReverseSortFaces(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        NCollection_List<TopoDS_Shape> faceList;
        BRepLib::ReverseSortFaces(shape->shape, faceList);
        BRep_Builder builder;
        TopoDS_Compound compound;
        builder.MakeCompound(compound);
        for (auto it = faceList.cbegin(); it != faceList.cend(); ++it) {
            builder.Add(compound, *it);
        }
        auto ref = new OCCTShape();
        ref->shape = compound;
        return ref;
    } catch (...) { return nullptr; }
}
// --- BRep_Tool queries on Shape ---

double OCCTShapeEdgeTolerance(OCCTShapeRef shape) {
    if (!shape) return 0;
    try {
        return BRep_Tool::Tolerance(TopoDS::Edge(shape->shape));
    } catch (...) { return 0; }
}

double OCCTShapeFaceTolerance(OCCTShapeRef shape) {
    if (!shape) return 0;
    try {
        return BRep_Tool::Tolerance(TopoDS::Face(shape->shape));
    } catch (...) { return 0; }
}

double OCCTShapeVertexTolerance(OCCTShapeRef shape) {
    if (!shape) return 0;
    try {
        return BRep_Tool::Tolerance(TopoDS::Vertex(shape->shape));
    } catch (...) { return 0; }
}

void OCCTShapeVertexPoint(OCCTShapeRef shape, double* x, double* y, double* z) {
    if (!shape) { *x = *y = *z = 0; return; }
    try {
        gp_Pnt p = BRep_Tool::Pnt(TopoDS::Vertex(shape->shape));
        *x = p.X(); *y = p.Y(); *z = p.Z();
    } catch (...) { *x = *y = *z = 0; }
}

OCCTCurve3DRef OCCTShapeEdgeCurve(OCCTShapeRef shape, double* first, double* last) {
    if (!shape) { *first = *last = 0; return nullptr; }
    try {
        double f, l;
        Handle(Geom_Curve) curve = BRep_Tool::Curve(TopoDS::Edge(shape->shape), f, l);
        if (curve.IsNull()) { *first = *last = 0; return nullptr; }
        *first = f; *last = l;
        auto ref = new OCCTCurve3D();
        ref->curve = curve;
        return ref;
    } catch (...) { *first = *last = 0; return nullptr; }
}

OCCTSurfaceRef OCCTShapeFaceSurface(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        Handle(Geom_Surface) surf = BRep_Tool::Surface(TopoDS::Face(shape->shape));
        if (surf.IsNull()) return nullptr;
        auto ref = new OCCTSurface();
        ref->surface = surf;
        return ref;
    } catch (...) { return nullptr; }
}

bool OCCTShapeIsClosed(OCCTShapeRef shape) {
    if (!shape) return false;
    return shape->shape.Closed();
}
// --- Unique sub-shape counts ---

#include <TopTools_IndexedMapOfShape.hxx>

int32_t OCCTShapeUniqueSubShapeCount(OCCTShapeRef shape, int32_t type) {
    if (!shape) return 0;
    try {
        TopTools_IndexedMapOfShape map;
        TopExp::MapShapes(shape->shape, (TopAbs_ShapeEnum)type, map);
        return (int32_t)map.Extent();
    } catch (...) { return 0; }
}
// --- Convenience unique counts ---

int32_t OCCTShapeUniqueEdgeCount(OCCTShapeRef shape) {
    return OCCTShapeUniqueSubShapeCount(shape, 6); // TopAbs_EDGE
}

int32_t OCCTShapeUniqueFaceCount(OCCTShapeRef shape) {
    return OCCTShapeUniqueSubShapeCount(shape, 4); // TopAbs_FACE
}

int32_t OCCTShapeUniqueVertexCount(OCCTShapeRef shape) {
    return OCCTShapeUniqueSubShapeCount(shape, 7); // TopAbs_VERTEX
}
// --- Shape empty copy ---

OCCTShapeRef OCCTShapeEmptyCopied(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        auto ref = new OCCTShape();
        ref->shape = shape->shape.EmptyCopied();
        return ref;
    } catch (...) { return nullptr; }
}


// MARK: - v0.115: GCPnts_AbscissaPoint expansion (edge) + BRepAdaptor exposure + Additional shape queries
// --- GCPnts_AbscissaPoint expansion ---

double OCCTEdgeParameterAtArcLength(OCCTShapeRef edge, double arcLength, double startParam) {
    if (!edge) return 0;
    try {
        BRepAdaptor_Curve adaptor(TopoDS::Edge(edge->shape));
        GCPnts_AbscissaPoint ap(adaptor, arcLength, startParam);
        if (ap.IsDone()) return ap.Parameter();
        return 0;
    } catch (...) { return 0; }
}

double OCCTEdgeArcLength(OCCTShapeRef edge) {
    if (!edge) return 0;
    try {
        BRepAdaptor_Curve adaptor(TopoDS::Edge(edge->shape));
        return GCPnts_AbscissaPoint::Length(adaptor);
    } catch (...) { return 0; }
}

double OCCTEdgeArcLengthBetween(OCCTShapeRef edge, double u1, double u2) {
    if (!edge) return 0;
    try {
        BRepAdaptor_Curve adaptor(TopoDS::Edge(edge->shape));
        return GCPnts_AbscissaPoint::Length(adaptor, u1, u2);
    } catch (...) { return 0; }
}

double OCCTEdgeParameterAtFraction(OCCTShapeRef edge, double fraction) {
    if (!edge) return 0;
    try {
        BRepAdaptor_Curve adaptor(TopoDS::Edge(edge->shape));
        double totalLen = GCPnts_AbscissaPoint::Length(adaptor);
        double targetLen = totalLen * fraction;
        GCPnts_AbscissaPoint ap(adaptor, targetLen, adaptor.FirstParameter());
        if (ap.IsDone()) return ap.Parameter();
        return 0;
    } catch (...) { return 0; }
}
// --- BRepAdaptor exposure ---

void OCCTEdgeAdaptorDomain(OCCTShapeRef edge, double* first, double* last) {
    *first = *last = 0;
    if (!edge) return;
    try {
        BRepAdaptor_Curve adaptor(TopoDS::Edge(edge->shape));
        *first = adaptor.FirstParameter();
        *last = adaptor.LastParameter();
    } catch (...) {}
}

void OCCTEdgeAdaptorValue(OCCTShapeRef edge, double param,
                            double* x, double* y, double* z) {
    *x = *y = *z = 0;
    if (!edge) return;
    try {
        BRepAdaptor_Curve adaptor(TopoDS::Edge(edge->shape));
        gp_Pnt p = adaptor.Value(param);
        *x = p.X(); *y = p.Y(); *z = p.Z();
    } catch (...) {}
}

int32_t OCCTEdgeAdaptorCurveType(OCCTShapeRef edge) {
    if (!edge) return -1;
    try {
        BRepAdaptor_Curve adaptor(TopoDS::Edge(edge->shape));
        return (int32_t)adaptor.GetType();
    } catch (...) { return -1; }
}

void OCCTFaceAdaptorBounds(OCCTShapeRef face,
                             double* uMin, double* uMax,
                             double* vMin, double* vMax) {
    *uMin = *uMax = *vMin = *vMax = 0;
    if (!face) return;
    try {
        BRepAdaptor_Surface adaptor(TopoDS::Face(face->shape));
        *uMin = adaptor.FirstUParameter();
        *uMax = adaptor.LastUParameter();
        *vMin = adaptor.FirstVParameter();
        *vMax = adaptor.LastVParameter();
    } catch (...) {}
}

void OCCTFaceAdaptorValue(OCCTShapeRef face, double u, double v,
                            double* x, double* y, double* z) {
    *x = *y = *z = 0;
    if (!face) return;
    try {
        BRepAdaptor_Surface adaptor(TopoDS::Face(face->shape));
        gp_Pnt p = adaptor.Value(u, v);
        *x = p.X(); *y = p.Y(); *z = p.Z();
    } catch (...) {}
}

int32_t OCCTFaceAdaptorSurfaceType(OCCTShapeRef face) {
    if (!face) return -1;
    try {
        BRepAdaptor_Surface adaptor(TopoDS::Face(face->shape));
        return (int32_t)adaptor.GetType();
    } catch (...) { return -1; }
}
// --- Additional shape queries ---

double OCCTShapeOBBVolume(OCCTShapeRef shape) {
    if (!shape) return 0;
    try {
        Bnd_OBB obb;
        BRepBndLib::AddOBB(shape->shape, obb);
        if (obb.IsVoid()) return 0;
        // Volume = 8 * halfX * halfY * halfZ
        double hx = obb.XHSize(), hy = obb.YHSize(), hz = obb.ZHSize();
        return 8.0 * hx * hy * hz;
    } catch (...) { return 0; }
}

double OCCTShapeMaxEdgeTolerance(OCCTShapeRef shape) {
    if (!shape) return 0;
    try {
        ShapeAnalysis_ShapeTolerance sat;
        return sat.Tolerance(shape->shape, 1, TopAbs_EDGE); // 1 = max
    } catch (...) { return 0; }
}

double OCCTShapeMaxFaceTolerance(OCCTShapeRef shape) {
    if (!shape) return 0;
    try {
        ShapeAnalysis_ShapeTolerance sat;
        return sat.Tolerance(shape->shape, 1, TopAbs_FACE); // 1 = max
    } catch (...) { return 0; }
}

double OCCTShapeMaxVertexTolerance(OCCTShapeRef shape) {
    if (!shape) return 0;
    try {
        ShapeAnalysis_ShapeTolerance sat;
        return sat.Tolerance(shape->shape, 1, TopAbs_VERTEX); // 1 = max
    } catch (...) { return 0; }
}

bool OCCTShapeHasFreeEdges(OCCTShapeRef shape) {
    if (!shape) return false;
    try {
        // Count edges that appear in only one face
        TopTools_IndexedDataMapOfShapeListOfShape edgeFaceMap;
        TopExp::MapShapesAndAncestors(shape->shape, TopAbs_EDGE, TopAbs_FACE, edgeFaceMap);
        for (int i = 1; i <= edgeFaceMap.Extent(); i++) {
            if (edgeFaceMap(i).Extent() < 2) return true;
        }
        return false;
    } catch (...) { return false; }
}

#include <TopTools_IndexedDataMapOfShapeListOfShape.hxx>

bool OCCTShapeHasFreeWires(OCCTShapeRef shape) {
    if (!shape) return false;
    try {
        TopTools_IndexedDataMapOfShapeListOfShape wireFaceMap;
        TopExp::MapShapesAndAncestors(shape->shape, TopAbs_WIRE, TopAbs_FACE, wireFaceMap);
        for (int i = 1; i <= wireFaceMap.Extent(); i++) {
            if (wireFaceMap(i).Extent() < 1) return true;
        }
        return false;
    } catch (...) { return false; }
}

bool OCCTShapeHasFreeFaces(OCCTShapeRef shape) {
    if (!shape) return false;
    try {
        TopTools_IndexedDataMapOfShapeListOfShape faceShellMap;
        TopExp::MapShapesAndAncestors(shape->shape, TopAbs_FACE, TopAbs_SHELL, faceShellMap);
        for (int i = 1; i <= faceShellMap.Extent(); i++) {
            if (faceShellMap(i).Extent() < 1) return true;
        }
        return false;
    } catch (...) { return false; }
}

double OCCTShapeBoundingDiagonal(OCCTShapeRef shape) {
    if (!shape) return 0;
    try {
        Bnd_Box box;
        BRepBndLib::Add(shape->shape, box);
        if (box.IsVoid()) return 0;
        double xMin, yMin, zMin, xMax, yMax, zMax;
        box.Get(xMin, yMin, zMin, xMax, yMax, zMax);
        double dx = xMax - xMin, dy = yMax - yMin, dz = zMax - zMin;
        return sqrt(dx*dx + dy*dy + dz*dz);
    } catch (...) { return 0; }
}

void OCCTShapeCentroid(OCCTShapeRef shape, double* x, double* y, double* z) {
    *x = *y = *z = 0;
    if (!shape) return;
    try {
        GProp_GProps props;
        BRepGProp::VolumeProperties(shape->shape, props);
        gp_Pnt cg = props.CentreOfMass();
        *x = cg.X(); *y = cg.Y(); *z = cg.Z();
    } catch (...) {}
}

double OCCTShapeTotalEdgeLength(OCCTShapeRef shape) {
    if (!shape) return 0;
    try {
        GProp_GProps props;
        BRepGProp::LinearProperties(shape->shape, props);
        return props.Mass();
    } catch (...) { return 0; }
}

// MARK: - v0.118: BoundingBox + Optimal + OBB + Shape transforms + EdgesCommonVertex + SameParam/Range/NaturalRestriction/IsGeometric
void OCCTShapeBoundingBox(OCCTShapeRef shape,
                          double* xmin, double* ymin, double* zmin,
                          double* xmax, double* ymax, double* zmax) {
    try {
        auto* s = static_cast<OCCTShape*>(shape);
        Bnd_Box box;
        BRepBndLib::Add(s->shape, box);
        if (box.IsVoid()) {
            *xmin = *ymin = *zmin = *xmax = *ymax = *zmax = 0.0;
        } else {
            box.Get(*xmin, *ymin, *zmin, *xmax, *ymax, *zmax);
        }
    } catch (...) {
        *xmin = *ymin = *zmin = *xmax = *ymax = *zmax = 0.0;
    }
}

void OCCTShapeBoundingBoxOptimal(OCCTShapeRef shape, bool useShapeTolerance,
                                  double* xmin, double* ymin, double* zmin,
                                  double* xmax, double* ymax, double* zmax) {
    try {
        auto* s = static_cast<OCCTShape*>(shape);
        Bnd_Box box;
        BRepBndLib::AddOptimal(s->shape, box, true, useShapeTolerance);
        if (box.IsVoid()) {
            *xmin = *ymin = *zmin = *xmax = *ymax = *zmax = 0.0;
        } else {
            box.Get(*xmin, *ymin, *zmin, *xmax, *ymax, *zmax);
        }
    } catch (...) {
        *xmin = *ymin = *zmin = *xmax = *ymax = *zmax = 0.0;
    }
}

#include <Bnd_OBB.hxx>

void OCCTShapeOrientedBoundingBoxDetailed(OCCTShapeRef shape, bool isOptimal,
                                   double* cx, double* cy, double* cz,
                                   double* xDirX, double* xDirY, double* xDirZ,
                                   double* yDirX, double* yDirY, double* yDirZ,
                                   double* zDirX, double* zDirY, double* zDirZ,
                                   double* xHSize, double* yHSize, double* zHSize,
                                   bool* isVoid) {
    try {
        auto* s = static_cast<OCCTShape*>(shape);
        Bnd_OBB obb;
        BRepBndLib::AddOBB(s->shape, obb, true, isOptimal, true);
        *isVoid = obb.IsVoid();
        if (!obb.IsVoid()) {
            gp_Pnt center = obb.Center();
            *cx = center.X(); *cy = center.Y(); *cz = center.Z();
            gp_XYZ xDir = obb.XDirection();
            *xDirX = xDir.X(); *xDirY = xDir.Y(); *xDirZ = xDir.Z();
            gp_XYZ yDir = obb.YDirection();
            *yDirX = yDir.X(); *yDirY = yDir.Y(); *yDirZ = yDir.Z();
            gp_XYZ zDir = obb.ZDirection();
            *zDirX = zDir.X(); *zDirY = zDir.Y(); *zDirZ = zDir.Z();
            *xHSize = obb.XHSize(); *yHSize = obb.YHSize(); *zHSize = obb.ZHSize();
        } else {
            *cx = *cy = *cz = 0.0;
            *xDirX = 1; *xDirY = 0; *xDirZ = 0;
            *yDirX = 0; *yDirY = 1; *yDirZ = 0;
            *zDirX = 0; *zDirY = 0; *zDirZ = 1;
            *xHSize = *yHSize = *zHSize = 0.0;
        }
    } catch (...) {
        *isVoid = true;
        *cx = *cy = *cz = 0.0;
        *xDirX = 1; *xDirY = 0; *xDirZ = 0;
        *yDirX = 0; *yDirY = 1; *yDirZ = 0;
        *zDirX = 0; *zDirY = 0; *zDirZ = 1;
        *xHSize = *yHSize = *zHSize = 0.0;
    }
}

// === ShapeAnalysis_ShapeTolerance ===
#include <ShapeAnalysis_ShapeTolerance.hxx>
void OCCTShapeTransformFromMatrix(OCCTShapeRef shape,
                                   double a11, double a12, double a13, double a14,
                                   double a21, double a22, double a23, double a24,
                                   double a31, double a32, double a33, double a34,
                                   OCCTShapeRef* result) {
    try {
        auto* s = static_cast<OCCTShape*>(shape);
        gp_Trsf trsf;
        trsf.SetValues(a11, a12, a13, a14,
                       a21, a22, a23, a24,
                       a31, a32, a33, a34);
        BRepBuilderAPI_Transform xform(s->shape, trsf, true);
        if (xform.IsDone()) {
            auto* r = new OCCTShape();
            r->shape = xform.Shape();
            *result = r;
        } else {
            *result = nullptr;
        }
    } catch (...) { *result = nullptr; }
}

bool OCCTShapeTransformIsNegative(OCCTShapeRef shape) {
    try {
        auto* s = static_cast<OCCTShape*>(shape);
        if (s->shape.IsNull()) return false;
        const TopLoc_Location& loc = s->shape.Location();
        return loc.IsIdentity() ? false : loc.Transformation().IsNegative();
    } catch (...) { return false; }
}
bool OCCTEdgesCommonVertex(OCCTShapeRef edge1, OCCTShapeRef edge2,
                            double* x, double* y, double* z) {
    try {
        auto* s1 = static_cast<OCCTShape*>(edge1);
        auto* s2 = static_cast<OCCTShape*>(edge2);
        TopoDS_Edge e1 = TopoDS::Edge(s1->shape);
        TopoDS_Edge e2 = TopoDS::Edge(s2->shape);
        TopoDS_Vertex cv;
        if (TopExp::CommonVertex(e1, e2, cv)) {
            gp_Pnt p = BRep_Tool::Pnt(cv);
            *x = p.X(); *y = p.Y(); *z = p.Z();
            return true;
        }
        return false;
    } catch (...) { return false; }
}

// === BRep_Tool extras ===
bool OCCTEdgeSameParameter(OCCTShapeRef edge) {
    try {
        auto* s = static_cast<OCCTShape*>(edge);
        return BRep_Tool::SameParameter(TopoDS::Edge(s->shape));
    } catch (...) { return false; }
}

bool OCCTEdgeSameRange(OCCTShapeRef edge) {
    try {
        auto* s = static_cast<OCCTShape*>(edge);
        return BRep_Tool::SameRange(TopoDS::Edge(s->shape));
    } catch (...) { return false; }
}

bool OCCTFaceNaturalRestriction(OCCTShapeRef face) {
    try {
        auto* s = static_cast<OCCTShape*>(face);
        return BRep_Tool::NaturalRestriction(TopoDS::Face(s->shape));
    } catch (...) { return false; }
}

bool OCCTEdgeIsGeometric(OCCTShapeRef edge) {
    try {
        auto* s = static_cast<OCCTShape*>(edge);
        return BRep_Tool::IsGeometric(TopoDS::Edge(s->shape));
    } catch (...) { return false; }
}

bool OCCTFaceIsGeometric(OCCTShapeRef face) {
    try {
        auto* s = static_cast<OCCTShape*>(face);
        return BRep_Tool::IsGeometric(TopoDS::Face(s->shape));
    } catch (...) { return false; }
}

// === Sewing extras ===

// MARK: - v0.122: BRepTools statics + BRepLib extended statics + Additional Shape queries + Shape emptied/moved
// --- BRepTools statics ---

void OCCTBRepToolsCleanTriangulation(OCCTShapeRef shape) {
    if (!shape) return;
    try { BRepTools::Clean(shape->shape); } catch (...) {}
}

void OCCTBRepToolsRemoveInternals(OCCTShapeRef shape) {
    if (!shape) return;
    try { BRepTools::RemoveInternals(shape->shape); } catch (...) {}
}

void OCCTBRepToolsDetectClosedness(OCCTShapeRef face, bool* isClosedU, bool* isClosedV) {
    if (!face || !isClosedU || !isClosedV) return;
    try {
        bool u = false, v = false;
        BRepTools::DetectClosedness(TopoDS::Face(face->shape), u, v);
        *isClosedU = u;
        *isClosedV = v;
    } catch (...) {
        *isClosedU = false;
        *isClosedV = false;
    }
}

double OCCTBRepToolsEvalAndUpdateTol(OCCTShapeRef edge, OCCTShapeRef face) {
    if (!edge || !face) return 0.0;
    try {
        const TopoDS_Edge& e = TopoDS::Edge(edge->shape);
        const TopoDS_Face& f = TopoDS::Face(face->shape);
        double first, last;
        Handle(Geom_Curve) c3d = BRep_Tool::Curve(e, first, last);
        Handle(Geom2d_Curve) c2d = BRep_Tool::CurveOnSurface(e, f, first, last);
        Handle(Geom_Surface) surf = BRep_Tool::Surface(f);
        if (c3d.IsNull() || surf.IsNull()) return BRep_Tool::Tolerance(e);
        return BRepTools::EvalAndUpdateTol(e, c3d, c2d, surf, first, last);
    } catch (...) { return 0.0; }
}

int32_t OCCTBRepToolsMap3DEdgeCount(OCCTShapeRef shape) {
    if (!shape) return 0;
    try {
        TopTools_IndexedMapOfShape edgeMap;
        BRepTools::Map3DEdges(shape->shape, edgeMap);
        return (int32_t)edgeMap.Extent();
    } catch (...) { return 0; }
}

void OCCTBRepToolsUpdateFaceUVPoints(OCCTShapeRef face) {
    if (!face) return;
    try { BRepTools::UpdateFaceUVPoints(TopoDS::Face(face->shape)); } catch (...) {}
}

bool OCCTBRepToolsCompareVertices(OCCTShapeRef v1, OCCTShapeRef v2) {
    if (!v1 || !v2) return false;
    try {
        return BRepTools::Compare(TopoDS::Vertex(v1->shape), TopoDS::Vertex(v2->shape));
    } catch (...) { return false; }
}

bool OCCTBRepToolsCompareEdges(OCCTShapeRef e1, OCCTShapeRef e2) {
    if (!e1 || !e2) return false;
    try {
        return BRepTools::Compare(TopoDS::Edge(e1->shape), TopoDS::Edge(e2->shape));
    } catch (...) { return false; }
}

bool OCCTBRepToolsIsReallyClosed(OCCTShapeRef edge, OCCTShapeRef face) {
    if (!edge || !face) return false;
    try {
        return BRepTools::IsReallyClosed(TopoDS::Edge(edge->shape), TopoDS::Face(face->shape));
    } catch (...) { return false; }
}

void OCCTBRepToolsUpdate(OCCTShapeRef shape) {
    if (!shape) return;
    try { BRepTools::Update(shape->shape); } catch (...) {}
}

// --- BRepLib extended statics ---

bool OCCTBRepLibEnsureNormalConsistency(OCCTShapeRef shape, double maxAngleRad) {
    if (!shape) return false;
    try {
        return BRepLib::EnsureNormalConsistency(shape->shape, maxAngleRad);
    } catch (...) { return false; }
}

void OCCTBRepLibUpdateDeflection(OCCTShapeRef shape) {
    if (!shape) return;
    try { BRepLib::UpdateDeflection(shape->shape); } catch (...) {}
}

int32_t OCCTBRepLibContinuityOfFaces(OCCTShapeRef edge, OCCTShapeRef face1, OCCTShapeRef face2,
                                      double tolerance) {
    if (!edge || !face1 || !face2) return -1;
    try {
        GeomAbs_Shape cont = BRepLib::ContinuityOfFaces(
            TopoDS::Edge(edge->shape),
            TopoDS::Face(face1->shape),
            TopoDS::Face(face2->shape),
            tolerance);
        return (int32_t)cont;
    } catch (...) { return -1; }
}

bool OCCTBRepLibBuildCurves3dAll(OCCTShapeRef shape, double tolerance) {
    if (!shape) return false;
    try {
        return BRepLib::BuildCurves3d(shape->shape, tolerance);
    } catch (...) { return false; }
}

void OCCTBRepLibSameParameterAll(OCCTShapeRef shape, double tolerance, bool forced) {
    if (!shape) return;
    try {
        BRepLib::SameParameter(shape->shape, tolerance, forced);
    } catch (...) {}
}
// --- Additional Shape queries ---

OCCTShapeRef OCCTShapeNullified(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        TopoDS_Shape s = shape->shape;
        s.Nullify();
        return new OCCTShape{s};
    } catch (...) { return nullptr; }
}

const char* OCCTShapeTypeName(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    switch (shape->shape.ShapeType()) {
        case TopAbs_COMPOUND: return "COMPOUND";
        case TopAbs_COMPSOLID: return "COMPSOLID";
        case TopAbs_SOLID: return "SOLID";
        case TopAbs_SHELL: return "SHELL";
        case TopAbs_FACE: return "FACE";
        case TopAbs_WIRE: return "WIRE";
        case TopAbs_EDGE: return "EDGE";
        case TopAbs_VERTEX: return "VERTEX";
        case TopAbs_SHAPE: return "SHAPE";
        default: return "UNKNOWN";
    }
}

bool OCCTShapeIsNotEqual(OCCTShapeRef shape1, OCCTShapeRef shape2) {
    if (!shape1 || !shape2) return true;
    return !shape1->shape.IsEqual(shape2->shape);
}

// --- Shape emptied/moved ---

OCCTShapeRef OCCTShapeEmptied(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        TopoDS_Shape s = shape->shape.EmptyCopied();
        if (s.IsNull()) return nullptr;
        return new OCCTShape{s};
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTShapeMoved(OCCTShapeRef shape, double dx, double dy, double dz) {
    if (!shape) return nullptr;
    try {
        gp_Trsf trsf;
        trsf.SetTranslation(gp_Vec(dx, dy, dz));
        TopoDS_Shape moved = shape->shape.Moved(TopLoc_Location(trsf));
        if (moved.IsNull()) return nullptr;
        return new OCCTShape{moved};
    } catch (...) { return nullptr; }
}

int32_t OCCTShapeOrientationValue(OCCTShapeRef shape) {
    if (!shape) return 0;
    return (int32_t)shape->shape.Orientation();
}

int32_t OCCTShapeNbEdges(OCCTShapeRef shape) {
    if (!shape) return 0;
    int32_t count = 0;
    for (TopExp_Explorer exp(shape->shape, TopAbs_EDGE); exp.More(); exp.Next()) {
        count++;
    }
    return count;
}

int32_t OCCTShapeNbFaces(OCCTShapeRef shape) {
    if (!shape) return 0;
    int32_t count = 0;
    for (TopExp_Explorer exp(shape->shape, TopAbs_FACE); exp.More(); exp.Next()) {
        count++;
    }
    return count;
}

int32_t OCCTShapeNbVertices(OCCTShapeRef shape) {
    if (!shape) return 0;
    int32_t count = 0;
    for (TopExp_Explorer exp(shape->shape, TopAbs_VERTEX); exp.More(); exp.Next()) {
        count++;
    }
    return count;
}

// end of v0.123.0 implementations

// MARK: - v0.126: BRep_Tool completions
// --- BRep_Tool completions ---

#import <BRep_Tool.hxx>
#import <Geom2d_Curve.hxx>

OCCTCurve2DRef OCCTBRepToolCurveOnSurface(OCCTShapeRef edge, OCCTShapeRef face,
                                           double* outFirst, double* outLast) {
    if (!edge || !face) return nullptr;
    try {
        const TopoDS_Edge& e = TopoDS::Edge(edge->shape);
        const TopoDS_Face& f = TopoDS::Face(face->shape);
        double first, last;
        auto c2d = BRep_Tool::CurveOnSurface(e, f, first, last);
        if (c2d.IsNull()) return nullptr;
        *outFirst = first;
        *outLast = last;
        auto* result = new OCCTCurve2D();
        result->curve = c2d;
        return result;
    } catch (...) { return nullptr; }
}

bool OCCTBRepToolHasContinuity(OCCTShapeRef edge, OCCTShapeRef face1, OCCTShapeRef face2) {
    if (!edge || !face1 || !face2) return false;
    try {
        const TopoDS_Edge& e = TopoDS::Edge(edge->shape);
        const TopoDS_Face& f1 = TopoDS::Face(face1->shape);
        const TopoDS_Face& f2 = TopoDS::Face(face2->shape);
        return BRep_Tool::HasContinuity(e, f1, f2);
    } catch (...) { return false; }
}

int32_t OCCTBRepToolContinuity(OCCTShapeRef edge, OCCTShapeRef face1, OCCTShapeRef face2) {
    if (!edge || !face1 || !face2) return 0;
    try {
        const TopoDS_Edge& e = TopoDS::Edge(edge->shape);
        const TopoDS_Face& f1 = TopoDS::Face(face1->shape);
        const TopoDS_Face& f2 = TopoDS::Face(face2->shape);
        return (int32_t)BRep_Tool::Continuity(e, f1, f2);
    } catch (...) { return 0; }
}

bool OCCTBRepToolHasAnyContinuity(OCCTShapeRef edge) {
    if (!edge) return false;
    try {
        const TopoDS_Edge& e = TopoDS::Edge(edge->shape);
        return BRep_Tool::HasContinuity(e);
    } catch (...) { return false; }
}

int32_t OCCTBRepToolMaxContinuity(OCCTShapeRef edge) {
    if (!edge) return 0;
    try {
        const TopoDS_Edge& e = TopoDS::Edge(edge->shape);
        return (int32_t)BRep_Tool::MaxContinuity(e);
    } catch (...) { return 0; }
}

bool OCCTBRepToolDegenerated(OCCTShapeRef edge) {
    if (!edge) return false;
    try {
        const TopoDS_Edge& e = TopoDS::Edge(edge->shape);
        return BRep_Tool::Degenerated(e);
    } catch (...) { return false; }
}

bool OCCTBRepToolNaturalRestriction(OCCTShapeRef face) {
    if (!face) return false;
    try {
        const TopoDS_Face& f = TopoDS::Face(face->shape);
        return BRep_Tool::NaturalRestriction(f);
    } catch (...) { return false; }
}

bool OCCTBRepToolRangeOnFace(OCCTShapeRef edge, OCCTShapeRef face,
                              double* outFirst, double* outLast) {
    if (!edge || !face) return false;
    try {
        const TopoDS_Edge& e = TopoDS::Edge(edge->shape);
        const TopoDS_Face& f = TopoDS::Face(face->shape);
        double first, last;
        BRep_Tool::Range(e, f, first, last);
        *outFirst = first;
        *outLast = last;
        return true;
    } catch (...) { return false; }
}

bool OCCTBRepToolParameterOnFace(OCCTShapeRef vertex, OCCTShapeRef edge,
                                  OCCTShapeRef face, double* outParam) {
    if (!vertex || !edge || !face) return false;
    try {
        const TopoDS_Vertex& v = TopoDS::Vertex(vertex->shape);
        const TopoDS_Edge& e = TopoDS::Edge(edge->shape);
        const TopoDS_Face& f = TopoDS::Face(face->shape);
        *outParam = BRep_Tool::Parameter(v, e, f);
        return true;
    } catch (...) { return false; }
}

bool OCCTBRepToolParametersOnFace(OCCTShapeRef vertex, OCCTShapeRef face,
                                   double* outU, double* outV) {
    if (!vertex || !face) return false;
    try {
        const TopoDS_Vertex& v = TopoDS::Vertex(vertex->shape);
        const TopoDS_Face& f = TopoDS::Face(face->shape);
        gp_Pnt2d uv = BRep_Tool::Parameters(v, f);
        *outU = uv.X();
        *outV = uv.Y();
        return true;
    } catch (...) { return false; }
}

bool OCCTBRepToolUVPoints(OCCTShapeRef edge, OCCTShapeRef face,
                           double* firstU, double* firstV,
                           double* lastU, double* lastV) {
    if (!edge || !face) return false;
    try {
        const TopoDS_Edge& e = TopoDS::Edge(edge->shape);
        const TopoDS_Face& f = TopoDS::Face(face->shape);
        gp_Pnt2d pFirst, pLast;
        BRep_Tool::UVPoints(e, f, pFirst, pLast);
        *firstU = pFirst.X();
        *firstV = pFirst.Y();
        *lastU = pLast.X();
        *lastV = pLast.Y();
        return true;
    } catch (...) { return false; }
}

double OCCTBRepToolMaxTolerance(OCCTShapeRef shape, int32_t subShapeType) {
    if (!shape) return 0.0;
    try {
        return BRep_Tool::MaxTolerance(shape->shape, (TopAbs_ShapeEnum)subShapeType);
    } catch (...) { return 0.0; }
}

// MARK: - v0.127: BRep_Tool completions (continued)
// --- BRep_Tool completions ---

OCCTCurve2DRef OCCTBRepToolCurveOnPlane(OCCTShapeRef edge, OCCTSurfaceRef surface,
                                         double* outFirst, double* outLast) {
    if (!edge || !surface || !outFirst || !outLast) return nullptr;
    try {
        TopoDS_Edge e = TopoDS::Edge(edge->shape);
        TopLoc_Location loc;
        double first = 0, last = 0;
        Handle(Geom2d_Curve) pcurve = BRep_Tool::CurveOnPlane(e, surface->surface, loc, first, last);
        if (pcurve.IsNull()) return nullptr;
        *outFirst = first;
        *outLast = last;
        return new OCCTCurve2D(pcurve);
    } catch (...) { return nullptr; }
}

int32_t OCCTBRepToolPolygon3D(OCCTShapeRef edge, double** outPoints) {
    if (!edge || !outPoints) return 0;
    *outPoints = nullptr;
    try {
        TopoDS_Edge e = TopoDS::Edge(edge->shape);
        TopLoc_Location loc;
        Handle(Poly_Polygon3D) poly = BRep_Tool::Polygon3D(e, loc);
        if (poly.IsNull()) return 0;
        int nb = poly->NbNodes();
        if (nb == 0) return 0;
        double* pts = (double*)malloc(nb * 3 * sizeof(double));
        if (!pts) return 0;
        gp_Trsf trsf = loc.IsIdentity() ? gp_Trsf() : loc.Transformation();
        const NCollection_Array1<gp_Pnt>& nodes = poly->Nodes();
        for (int i = 1; i <= nb; i++) {
            gp_Pnt p = nodes.Value(i).Transformed(trsf);
            pts[(i-1)*3+0] = p.X();
            pts[(i-1)*3+1] = p.Y();
            pts[(i-1)*3+2] = p.Z();
        }
        *outPoints = pts;
        return nb;
    } catch (...) { return 0; }
}

int32_t OCCTBRepToolPolygonOnTriangulation(OCCTShapeRef edge, int32_t** outIndices) {
    if (!edge || !outIndices) return 0;
    *outIndices = nullptr;
    try {
        TopoDS_Edge e = TopoDS::Edge(edge->shape);
        TopLoc_Location loc;
        Handle(Poly_PolygonOnTriangulation) pot;
        Handle(Poly_Triangulation) tri;
        BRep_Tool::PolygonOnTriangulation(e, pot, tri, loc);
        if (pot.IsNull()) return 0;
        int nb = pot->NbNodes();
        if (nb == 0) return 0;
        int32_t* indices = (int32_t*)malloc(nb * sizeof(int32_t));
        if (!indices) return 0;
        for (int i = 1; i <= nb; i++) {
            indices[i-1] = pot->Node(i);
        }
        *outIndices = indices;
        return nb;
    } catch (...) { return 0; }
}
// --- BRep_Tool completions ---

bool OCCTBRepToolIsClosedOnFace(OCCTShapeRef edge, OCCTShapeRef face) {
    if (!edge || !face) return false;
    try {
        TopoDS_Edge e = TopoDS::Edge(edge->shape);
        TopoDS_Face f = TopoDS::Face(face->shape);
        return BRep_Tool::IsClosed(e, f);
    } catch (...) { return false; }
}

int32_t OCCTBRepToolPolygonOnSurface(OCCTShapeRef edge, OCCTShapeRef face,
                                      double** outPoints) {
    if (!edge || !face || !outPoints) return 0;
    *outPoints = nullptr;
    try {
        TopoDS_Edge e = TopoDS::Edge(edge->shape);
        TopoDS_Face f = TopoDS::Face(face->shape);
        Handle(Poly_Polygon2D) poly = BRep_Tool::PolygonOnSurface(e, f);
        if (poly.IsNull()) return 0;
        int32_t count = poly->NbNodes();
        if (count == 0) return 0;
        *outPoints = (double*)malloc(count * 2 * sizeof(double));
        const TColgp_Array1OfPnt2d& nodes = poly->Nodes();
        for (int i = 1; i <= count; i++) {
            (*outPoints)[(i-1)*2] = nodes.Value(i).X();
            (*outPoints)[(i-1)*2+1] = nodes.Value(i).Y();
        }
        return count;
    } catch (...) { return 0; }
}

bool OCCTBRepToolSetUVPoints(OCCTShapeRef edge, OCCTShapeRef face,
                              double fU, double fV, double lU, double lV) {
    if (!edge || !face) return false;
    try {
        TopoDS_Edge e = TopoDS::Edge(edge->shape);
        TopoDS_Face f = TopoDS::Face(face->shape);
        gp_Pnt2d p1(fU, fV), p2(lU, lV);
        BRep_Tool::SetUVPoints(e, f, p1, p2);
        return true;
    } catch (...) { return false; }
}
// MARK: - Face Analysis

#include <BRepLProp_SLProps.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <GeomAbs_SurfaceType.hxx>

OCCTFaceRef* OCCTShapeGetFaces(OCCTShapeRef shape, int32_t* outCount) {
    if (!shape || !outCount) return nullptr;
    *outCount = 0;

    try {
        // First, count faces
        std::vector<TopoDS_Face> faces;
        TopExp_Explorer explorer(shape->shape, TopAbs_FACE);
        while (explorer.More()) {
            faces.push_back(TopoDS::Face(explorer.Current()));
            explorer.Next();
        }

        if (faces.empty()) return nullptr;

        // Allocate array
        OCCTFaceRef* result = new OCCTFaceRef[faces.size()];
        for (size_t i = 0; i < faces.size(); i++) {
            result[i] = new OCCTFace(faces[i]);
        }

        *outCount = static_cast<int32_t>(faces.size());
        return result;
    } catch (...) {
        return nullptr;
    }
}

void OCCTFreeFaceArray(OCCTFaceRef* faces, int32_t count) {
    if (!faces) return;
    for (int32_t i = 0; i < count; i++) {
        delete faces[i];
    }
    delete[] faces;
}

void OCCTFreeFaceArrayOnly(OCCTFaceRef* faces) {
    if (!faces) return;
    delete[] faces;
}

void OCCTFaceRelease(OCCTFaceRef face) {
    delete face;
}

bool OCCTFaceGetNormal(OCCTFaceRef face, double* outNx, double* outNy, double* outNz) {
    if (!face || !outNx || !outNy || !outNz) return false;

    try {
        // Get surface from face
        BRepAdaptor_Surface adaptor(face->face);

        // Get parameter range
        double uMin, uMax, vMin, vMax;
        uMin = adaptor.FirstUParameter();
        uMax = adaptor.LastUParameter();
        vMin = adaptor.FirstVParameter();
        vMax = adaptor.LastVParameter();

        // Evaluate at center of parameter space
        double uMid = (uMin + uMax) / 2.0;
        double vMid = (vMin + vMax) / 2.0;

        // Get surface properties at center
        BRepLProp_SLProps props(adaptor, uMid, vMid, 1, 1e-6);
        if (!props.IsNormalDefined()) return false;

        gp_Dir normal = props.Normal();

        // Account for face orientation
        if (face->face.Orientation() == TopAbs_REVERSED) {
            normal.Reverse();
        }

        *outNx = normal.X();
        *outNy = normal.Y();
        *outNz = normal.Z();
        return true;
    } catch (...) {
        return false;
    }
}

OCCTWireRef OCCTFaceGetOuterWire(OCCTFaceRef face) {
    if (!face) return nullptr;

    try {
        TopoDS_Wire outerWire = BRepTools::OuterWire(face->face);
        if (outerWire.IsNull()) return nullptr;
        return new OCCTWire(outerWire);
    } catch (...) {
        return nullptr;
    }
}

void OCCTFaceGetBounds(OCCTFaceRef face, double* minX, double* minY, double* minZ, double* maxX, double* maxY, double* maxZ) {
    if (!face || !minX || !minY || !minZ || !maxX || !maxY || !maxZ) return;

    try {
        Bnd_Box box;
        BRepBndLib::Add(face->face, box);
        box.Get(*minX, *minY, *minZ, *maxX, *maxY, *maxZ);
    } catch (...) {
        *minX = *minY = *minZ = *maxX = *maxY = *maxZ = 0;
    }
}

bool OCCTFaceIsPlanar(OCCTFaceRef face) {
    if (!face) return false;

    try {
        BRepAdaptor_Surface adaptor(face->face);
        return adaptor.GetType() == GeomAbs_Plane;
    } catch (...) {
        return false;
    }
}

bool OCCTFaceGetZLevel(OCCTFaceRef face, double* outZ) {
    if (!face || !outZ) return false;

    try {
        BRepAdaptor_Surface adaptor(face->face);

        // Check if planar
        if (adaptor.GetType() != GeomAbs_Plane) return false;

        gp_Pln plane = adaptor.Plane();
        gp_Dir normal = plane.Axis().Direction();

        // Account for face orientation
        if (face->face.Orientation() == TopAbs_REVERSED) {
            normal.Reverse();
        }

        // Check if horizontal (normal is parallel to Z axis)
        double dotZ = std::abs(normal.Z());
        if (dotZ < 0.99) return false;  // Not horizontal enough

        // Get Z from plane location
        gp_Pnt location = plane.Location();
        *outZ = location.Z();
        return true;
    } catch (...) {
        return false;
    }
}

OCCTFaceRef* OCCTShapeGetHorizontalFaces(OCCTShapeRef shape, double tolerance, int32_t* outCount) {
    if (!shape || !outCount) return nullptr;
    *outCount = 0;

    try {
        std::vector<TopoDS_Face> horizontalFaces;

        TopExp_Explorer explorer(shape->shape, TopAbs_FACE);
        while (explorer.More()) {
            TopoDS_Face face = TopoDS::Face(explorer.Current());

            // Get normal at face center
            BRepAdaptor_Surface adaptor(face);
            double uMid = (adaptor.FirstUParameter() + adaptor.LastUParameter()) / 2.0;
            double vMid = (adaptor.FirstVParameter() + adaptor.LastVParameter()) / 2.0;

            BRepLProp_SLProps props(adaptor, uMid, vMid, 1, 1e-6);
            if (props.IsNormalDefined()) {
                gp_Dir normal = props.Normal();
                if (face.Orientation() == TopAbs_REVERSED) {
                    normal.Reverse();
                }

                // Check if horizontal (normal is nearly parallel to Z axis)
                double angleToZ = std::abs(normal.Z());
                if (angleToZ > std::cos(tolerance)) {
                    horizontalFaces.push_back(face);
                }
            }

            explorer.Next();
        }

        if (horizontalFaces.empty()) return nullptr;

        OCCTFaceRef* result = new OCCTFaceRef[horizontalFaces.size()];
        for (size_t i = 0; i < horizontalFaces.size(); i++) {
            result[i] = new OCCTFace(horizontalFaces[i]);
        }

        *outCount = static_cast<int32_t>(horizontalFaces.size());
        return result;
    } catch (...) {
        return nullptr;
    }
}

OCCTFaceRef* OCCTShapeGetUpwardFaces(OCCTShapeRef shape, double tolerance, int32_t* outCount) {
    if (!shape || !outCount) return nullptr;
    *outCount = 0;

    try {
        std::vector<TopoDS_Face> upwardFaces;

        TopExp_Explorer explorer(shape->shape, TopAbs_FACE);
        while (explorer.More()) {
            TopoDS_Face face = TopoDS::Face(explorer.Current());

            // Get normal at face center
            BRepAdaptor_Surface adaptor(face);
            double uMid = (adaptor.FirstUParameter() + adaptor.LastUParameter()) / 2.0;
            double vMid = (adaptor.FirstVParameter() + adaptor.LastVParameter()) / 2.0;

            BRepLProp_SLProps props(adaptor, uMid, vMid, 1, 1e-6);
            if (props.IsNormalDefined()) {
                gp_Dir normal = props.Normal();
                if (face.Orientation() == TopAbs_REVERSED) {
                    normal.Reverse();
                }

                // Check if upward-facing (normal Z > 0 and nearly vertical)
                if (normal.Z() > std::cos(tolerance)) {
                    upwardFaces.push_back(face);
                }
            }

            explorer.Next();
        }

        if (upwardFaces.empty()) return nullptr;

        OCCTFaceRef* result = new OCCTFaceRef[upwardFaces.size()];
        for (size_t i = 0; i < upwardFaces.size(); i++) {
            result[i] = new OCCTFace(upwardFaces[i]);
        }

        *outCount = static_cast<int32_t>(upwardFaces.size());
        return result;
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Edge Structure
// OCCTEdge is now defined in OCCTBridge_Internal.h.

OCCTEdgeRef OCCTEdgeFromShape(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        if (shape->shape.IsNull()) return nullptr;
        if (shape->shape.ShapeType() != TopAbs_EDGE) return nullptr;
        return new OCCTEdge(TopoDS::Edge(shape->shape));
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTShapeFromEdge(OCCTEdgeRef edgeRef) {
    if (!edgeRef) return nullptr;
    return new OCCTShape(edgeRef->edge);
}

// MARK: - Face Index Access (Issue #13)

int32_t OCCTShapeGetFaceCount(OCCTShapeRef shape) {
    if (!shape) return 0;
    
    try {
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);
        return faceMap.Extent();
    } catch (...) {
        return 0;
    }
}

OCCTFaceRef OCCTShapeGetFaceAtIndex(OCCTShapeRef shape, int32_t index) {
    if (!shape || index < 0) return nullptr;
    
    try {
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);
        
        if (index >= faceMap.Extent()) return nullptr;
        
        TopoDS_Face face = TopoDS::Face(faceMap(index + 1));  // OCCT is 1-based
        return new OCCTFace(face);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Edge Access (Issue #14)

int32_t OCCTShapeGetTotalEdgeCount(OCCTShapeRef shape) {
    if (!shape) return 0;
    
    try {
        TopTools_IndexedMapOfShape edgeMap;
        TopExp::MapShapes(shape->shape, TopAbs_EDGE, edgeMap);
        return edgeMap.Extent();
    } catch (...) {
        return 0;
    }
}

OCCTEdgeRef OCCTShapeGetEdgeAtIndex(OCCTShapeRef shape, int32_t index) {
    if (!shape || index < 0) return nullptr;
    
    try {
        TopTools_IndexedMapOfShape edgeMap;
        TopExp::MapShapes(shape->shape, TopAbs_EDGE, edgeMap);
        
        if (index >= edgeMap.Extent()) return nullptr;
        
        TopoDS_Edge edge = TopoDS::Edge(edgeMap(index + 1));  // OCCT is 1-based
        return new OCCTEdge(edge);
    } catch (...) {
        return nullptr;
    }
}

void OCCTEdgeRelease(OCCTEdgeRef edge) {
    delete edge;
}

double OCCTEdgeGetLength(OCCTEdgeRef edge) {
    if (!edge) return 0;
    
    try {
        GProp_GProps props;
        BRepGProp::LinearProperties(edge->edge, props);
        return props.Mass();  // For curves, Mass() returns length
    } catch (...) {
        return 0;
    }
}

void OCCTEdgeGetBounds(OCCTEdgeRef edge, double* minX, double* minY, double* minZ, double* maxX, double* maxY, double* maxZ) {
    if (!edge || !minX || !minY || !minZ || !maxX || !maxY || !maxZ) return;

    try {
        Bnd_Box box;
        BRepBndLib::Add(edge->edge, box);
        box.Get(*minX, *minY, *minZ, *maxX, *maxY, *maxZ);
    } catch (...) {
        *minX = *minY = *minZ = *maxX = *maxY = *maxZ = 0;
    }
}

int32_t OCCTEdgeGetPoints(OCCTEdgeRef edge, int32_t count, double* outPoints) {
    if (!edge || count <= 0 || !outPoints) return 0;

    try {
        BRepAdaptor_Curve curve(edge->edge);
        double first = curve.FirstParameter();
        double last = curve.LastParameter();

        for (int32_t i = 0; i < count; i++) {
            double t = (count == 1) ? first : first + (last - first) * i / (count - 1);
            gp_Pnt pt = curve.Value(t);
            outPoints[i * 3] = pt.X();
            outPoints[i * 3 + 1] = pt.Y();
            outPoints[i * 3 + 2] = pt.Z();
        }
        
        return count;
    } catch (...) {
        return 0;
    }
}

bool OCCTEdgeIsLine(OCCTEdgeRef edge) {
    if (!edge) return false;
    
    try {
        BRepAdaptor_Curve curve(edge->edge);
        return curve.GetType() == GeomAbs_Line;
    } catch (...) {
        return false;
    }
}

bool OCCTEdgeIsCircle(OCCTEdgeRef edge) {
    if (!edge) return false;
    
    try {
        BRepAdaptor_Curve curve(edge->edge);
        return curve.GetType() == GeomAbs_Circle;
    } catch (...) {
        return false;
    }
}

void OCCTEdgeGetEndpoints(OCCTEdgeRef edge, double* startX, double* startY, double* startZ, double* endX, double* endY, double* endZ) {
    if (!edge || !startX || !startY || !startZ || !endX || !endY || !endZ) return;

    try {
        TopoDS_Vertex v1, v2;
        TopExp::Vertices(edge->edge, v1, v2);
        
        gp_Pnt p1 = BRep_Tool::Pnt(v1);
        gp_Pnt p2 = BRep_Tool::Pnt(v2);
        
        *startX = p1.X();
        *startY = p1.Y();
        *startZ = p1.Z();
        *endX = p2.X();
        *endY = p2.Y();
        *endZ = p2.Z();
    } catch (...) {
        *startX = *startY = *startZ = *endX = *endY = *endZ = 0;
    }
}

