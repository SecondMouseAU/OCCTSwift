//
//  OCCTBridge_ProjLib_NLPlate.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm — issue #99.
//
//  Two adjacent v0.22 / v0.23 areas that both project / fit curves onto
//  surfaces:
//
//  - ProjLib (v0.22): curve projection onto planes + general surfaces
//    (ProjLib_CompProjectedCurve / ProjectedCurve / ProjectOnPlane,
//    GeomProjLib helpers)
//  - NLPlate (v0.23): non-linear plate surfaces — point + curve
//    constraints fitted into a smooth surface (NLPlate_NLPlate +
//    GeomPlate_*)
//
//  Public C surface unchanged. No symbol changes — pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// === Area-specific OCCT headers ===

#include <BRep_Tool.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <Geom2d_BezierCurve.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <ProjLib_ComputeApprox.hxx>
#include <ProjLib_ComputeApproxOnPolarSurface.hxx>
#include <NLPlate_HPG0G2Constraint.hxx>
#include <NLPlate_HPG0G3Constraint.hxx>
#include <Plate_D1.hxx>
#include <Plate_D2.hxx>
#include <Plate_D3.hxx>
#include <Plate_GtoCConstraint.hxx>
#include <Plate_PinpointConstraint.hxx>
#include <Plate_Plate.hxx>
#include <Geom_Line.hxx>
#include <ShapeConstruct_ProjectCurveOnSurface.hxx>
#include <ProjLib_ProjectOnSurface.hxx>
#include <ProjLib_Plane.hxx>
#include <ProjLib_Cylinder.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_TrimmedCurve.hxx>

#include <Geom_BSplineSurface.hxx>
#include <Geom_Curve.hxx>
#include <Geom_Plane.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <Geom_Surface.hxx>
#include <Geom2d_Curve.hxx>

#include <GeomAbs_Shape.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <GeomAdaptor_Surface.hxx>
#include <GeomAPI_PointsToBSplineSurface.hxx>
#include <GeomAPI_ProjectPointOnSurf.hxx>
#include <GeomPlate_BuildAveragePlane.hxx>
#include <GeomPlate_BuildPlateSurface.hxx>
#include <GeomPlate_CurveConstraint.hxx>
#include <GeomPlate_MakeApprox.hxx>
#include <GeomPlate_PointConstraint.hxx>
#include <GeomPlate_Surface.hxx>
#include <GeomProjLib.hxx>

#include <NLPlate_HPG0Constraint.hxx>
#include <NLPlate_HPG1Constraint.hxx>
#include <NLPlate_NLPlate.hxx>
#include <Plate_D1.hxx>

#include <ProjLib_CompProjectedCurve.hxx>
#include <ProjLib_ProjectedCurve.hxx>
#include <ProjLib_ProjectOnPlane.hxx>

#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>
#include <gp_XY.hxx>
#include <gp_XYZ.hxx>

#include <TColgp_Array2OfPnt.hxx>

#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>

// MARK: - ProjLib: Curve Projection onto Surfaces (v0.22.0)

#include <GeomProjLib.hxx>
#include <ProjLib_CompProjectedCurve.hxx>
#include <ProjLib_ProjectedCurve.hxx>
#include <ProjLib_ProjectOnPlane.hxx>
#include <Geom_Plane.hxx>

OCCTCurve2DRef OCCTSurfaceProjectCurve2D(OCCTSurfaceRef surface,
                                          OCCTCurve3DRef curve,
                                          double tolerance) {
    if (!surface || surface->surface.IsNull()) return nullptr;
    if (!curve || curve->curve.IsNull()) return nullptr;
    try {
        Standard_Real first = curve->curve->FirstParameter();
        Standard_Real last = curve->curve->LastParameter();
        Standard_Real tol = tolerance;
        Handle(Geom2d_Curve) result = GeomProjLib::Curve2d(
            curve->curve, first, last, surface->surface, tol);
        if (result.IsNull()) return nullptr;
        return new OCCTCurve2D(result);
    } catch (...) {
        return nullptr;
    }
}

int32_t OCCTSurfaceProjectCurveSegments(OCCTSurfaceRef surface,
                                         OCCTCurve3DRef curve,
                                         double tolerance,
                                         OCCTCurve2DRef* outCurves,
                                         int32_t maxCurves) {
    if (!surface || surface->surface.IsNull()) return 0;
    if (!curve || curve->curve.IsNull()) return 0;
    if (!outCurves || maxCurves <= 0) return 0;
    try {
        Handle(GeomAdaptor_Surface) surfAdaptor =
            new GeomAdaptor_Surface(surface->surface);
        Handle(GeomAdaptor_Curve) curveAdaptor =
            new GeomAdaptor_Curve(curve->curve);

        ProjLib_CompProjectedCurve comp(tolerance, surfAdaptor, curveAdaptor);
        comp.Perform();

        int32_t nbCurves = comp.NbCurves();
        int32_t count = 0;
        for (int32_t i = 1; i <= nbCurves && count < maxCurves; i++) {
            Handle(Geom2d_Curve) c2d = comp.GetResult2dC(i);
            if (!c2d.IsNull()) {
                outCurves[count] = new OCCTCurve2D(c2d);
                count++;
            }
        }
        return count;
    } catch (...) {
        return 0;
    }
}

OCCTCurve3DRef OCCTSurfaceProjectCurve3D(OCCTSurfaceRef surface,
                                          OCCTCurve3DRef curve) {
    if (!surface || surface->surface.IsNull()) return nullptr;
    if (!curve || curve->curve.IsNull()) return nullptr;
    try {
        Handle(Geom_Curve) result = GeomProjLib::Project(
            curve->curve, surface->surface);
        if (result.IsNull()) return nullptr;
        return new OCCTCurve3D(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DProjectOnPlane(OCCTCurve3DRef curve,
                                          double oX, double oY, double oZ,
                                          double nX, double nY, double nZ,
                                          double dX, double dY, double dZ) {
    if (!curve || curve->curve.IsNull()) return nullptr;
    try {
        gp_Pnt origin(oX, oY, oZ);
        gp_Dir normal(nX, nY, nZ);
        gp_Dir direction(dX, dY, dZ);
        Handle(Geom_Plane) plane = new Geom_Plane(origin, normal);

        Handle(Geom_Curve) result = GeomProjLib::ProjectOnPlane(
            curve->curve, plane, direction, Standard_True);
        if (result.IsNull()) return nullptr;
        return new OCCTCurve3D(result);
    } catch (...) {
        return nullptr;
    }
}

bool OCCTSurfaceProjectPoint(OCCTSurfaceRef surface,
                              double px, double py, double pz,
                              double* u, double* v, double* distance) {
    if (!surface || surface->surface.IsNull()) return false;
    if (!u || !v || !distance) return false;
    try {
        GeomAPI_ProjectPointOnSurf proj(gp_Pnt(px, py, pz), surface->surface);
        if (!proj.IsDone() || proj.NbPoints() == 0) return false;
        proj.LowerDistanceParameters(*u, *v);
        *distance = proj.LowerDistance();
        return true;
    } catch (...) {
        return false;
    }
}


// MARK: - NLPlate: Advanced Plate Surfaces (v0.23.0)

#include <NLPlate_NLPlate.hxx>
#include <NLPlate_HPG0Constraint.hxx>
#include <NLPlate_HPG1Constraint.hxx>
#include <NLPlate_HPG0G1Constraint.hxx>
#include <Plate_D1.hxx>
#include <GeomPlate_BuildAveragePlane.hxx>
#include <GeomAPI_PointsToBSplineSurface.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>

OCCTShapeRef OCCTShapePlatePointsAdvanced(const double* points, int32_t pointCount,
                                           const int32_t* orders, int32_t degree,
                                           int32_t nbPtsOnCur, int32_t nbIter,
                                           double tolerance) {
    if (!points || pointCount < 3 || !orders) return nullptr;
    try {
        GeomPlate_BuildPlateSurface plateBuilder(degree, nbPtsOnCur, nbIter);

        for (int32_t i = 0; i < pointCount; i++) {
            gp_Pnt pt(points[i*3], points[i*3+1], points[i*3+2]);
            int32_t order = orders[i];
            if (order < 0) order = 0;
            if (order > 2) order = 2;
            Handle(GeomPlate_PointConstraint) constraint =
                new GeomPlate_PointConstraint(pt, order);
            plateBuilder.Add(constraint);
        }

        plateBuilder.Perform();
        if (!plateBuilder.IsDone()) return nullptr;

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

OCCTShapeRef OCCTShapePlateMixed(const double* points, const int32_t* pointOrders,
                                  int32_t pointCount,
                                  const OCCTWireRef* curves, const int32_t* curveOrders,
                                  int32_t curveCount,
                                  int32_t degree, double tolerance) {
    if (pointCount < 1 && curveCount < 1) return nullptr;
    try {
        GeomPlate_BuildPlateSurface plateBuilder(degree, 15, 2);

        // Add point constraints
        if (points && pointOrders) {
            for (int32_t i = 0; i < pointCount; i++) {
                gp_Pnt pt(points[i*3], points[i*3+1], points[i*3+2]);
                int32_t order = pointOrders[i];
                if (order < 0) order = 0;
                if (order > 2) order = 2;
                Handle(GeomPlate_PointConstraint) constraint =
                    new GeomPlate_PointConstraint(pt, order);
                plateBuilder.Add(constraint);
            }
        }

        // Add curve constraints
        if (curves && curveOrders) {
            for (int32_t i = 0; i < curveCount; i++) {
                if (!curves[i]) continue;
                int32_t order = curveOrders[i];
                if (order < 0) order = 0;
                if (order > 2) order = 2;

                for (TopExp_Explorer exp(curves[i]->wire, TopAbs_EDGE); exp.More(); exp.Next()) {
                    TopoDS_Edge edge = TopoDS::Edge(exp.Current());
                    BRepAdaptor_Curve adaptor(edge);
                    Handle(Adaptor3d_Curve) curve = new BRepAdaptor_Curve(adaptor);
                    Handle(GeomPlate_CurveConstraint) constraint =
                        new GeomPlate_CurveConstraint(curve, order);
                    plateBuilder.Add(constraint);
                }
            }
        }

        plateBuilder.Perform();
        if (!plateBuilder.IsDone()) return nullptr;

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

OCCTSurfaceRef OCCTSurfacePlateThrough(const double* points, int32_t pointCount,
                                        int32_t degree, double tolerance) {
    if (!points || pointCount < 3) return nullptr;
    try {
        GeomPlate_BuildPlateSurface plateBuilder(degree, 15, 2);

        for (int32_t i = 0; i < pointCount; i++) {
            gp_Pnt pt(points[i*3], points[i*3+1], points[i*3+2]);
            Handle(GeomPlate_PointConstraint) constraint =
                new GeomPlate_PointConstraint(pt, 0);
            plateBuilder.Add(constraint);
        }

        plateBuilder.Perform();
        if (!plateBuilder.IsDone()) return nullptr;

        Handle(GeomPlate_Surface) plateSurface = plateBuilder.Surface();
        if (plateSurface.IsNull()) return nullptr;

        GeomPlate_MakeApprox approx(plateSurface, tolerance, 1, 8, tolerance * 10, 0);
        Handle(Geom_BSplineSurface) bsplineSurf = approx.Surface();
        if (bsplineSurf.IsNull()) return nullptr;

        return new OCCTSurface(bsplineSurf);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceNLPlateG0(OCCTSurfaceRef initialSurface,
                                     const double* constraints, int32_t constraintCount,
                                     int32_t maxIter, double tolerance) {
    if (!initialSurface || initialSurface->surface.IsNull()) return nullptr;
    if (!constraints || constraintCount < 1) return nullptr;
    try {
        // NLPlate needs a bounded surface; if infinite, create a trimmed version
        Standard_Real u1, u2, v1, v2;
        initialSurface->surface->Bounds(u1, u2, v1, v2);

        Handle(Geom_Surface) workSurface = initialSurface->surface;
        bool needsTrim = Precision::IsNegativeInfinite(u1) || Precision::IsPositiveInfinite(u2) ||
                         Precision::IsNegativeInfinite(v1) || Precision::IsPositiveInfinite(v2);

        if (needsTrim) {
            // Find bounds from constraint points
            double minU = 1e30, maxU = -1e30, minV = 1e30, maxV = -1e30;
            for (int32_t i = 0; i < constraintCount; i++) {
                double cu = constraints[i * 5 + 0];
                double cv = constraints[i * 5 + 1];
                minU = std::min(minU, cu); maxU = std::max(maxU, cu);
                minV = std::min(minV, cv); maxV = std::max(maxV, cv);
            }
            // Extend domain beyond constraints
            double padU = std::max(10.0, (maxU - minU) * 0.5);
            double padV = std::max(10.0, (maxV - minV) * 0.5);
            u1 = minU - padU; u2 = maxU + padU;
            v1 = minV - padV; v2 = maxV + padV;

            workSurface = new Geom_RectangularTrimmedSurface(initialSurface->surface, u1, u2, v1, v2);
        }

        NLPlate_NLPlate solver(workSurface);

        for (int32_t i = 0; i < constraintCount; i++) {
            double u = constraints[i * 5 + 0];
            double v = constraints[i * 5 + 1];
            double tx = constraints[i * 5 + 2];
            double ty = constraints[i * 5 + 3];
            double tz = constraints[i * 5 + 4];

            gp_XY uv(u, v);
            gp_XYZ target(tx, ty, tz);
            Handle(NLPlate_HPG0Constraint) g0 = new NLPlate_HPG0Constraint(uv, target);
            solver.Load(g0);
        }

        solver.Solve2(maxIter);
        if (!solver.IsDone()) return nullptr;

        // Get working domain
        if (!needsTrim) {
            workSurface->Bounds(u1, u2, v1, v2);
            if (Precision::IsNegativeInfinite(u1)) u1 = -100.0;
            if (Precision::IsPositiveInfinite(u2)) u2 = 100.0;
            if (Precision::IsNegativeInfinite(v1)) v1 = -100.0;
            if (Precision::IsPositiveInfinite(v2)) v2 = 100.0;
        }

        // Sample the deformed surface and create BSpline approximation
        int nuPts = 20, nvPts = 20;
        TColgp_Array2OfPnt poles(1, nuPts, 1, nvPts);
        for (int iu = 1; iu <= nuPts; iu++) {
            double pu = u1 + (u2 - u1) * (iu - 1) / (nuPts - 1);
            for (int iv = 1; iv <= nvPts; iv++) {
                double pv = v1 + (v2 - v1) * (iv - 1) / (nvPts - 1);
                gp_XY uv(pu, pv);
                gp_XYZ disp = solver.Evaluate(uv);
                gp_Pnt origPt;
                workSurface->D0(pu, pv, origPt);
                gp_Pnt newPt(origPt.X() + disp.X(), origPt.Y() + disp.Y(), origPt.Z() + disp.Z());
                poles(iu, iv) = newPt;
            }
        }

        GeomAPI_PointsToBSplineSurface approx;
        approx.Init(poles, 3, 8, GeomAbs_C2, tolerance);
        Handle(Geom_BSplineSurface) result = approx.Surface();
        if (result.IsNull()) return nullptr;

        return new OCCTSurface(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceNLPlateG1(OCCTSurfaceRef initialSurface,
                                     const double* constraints, int32_t constraintCount,
                                     int32_t maxIter, double tolerance) {
    if (!initialSurface || initialSurface->surface.IsNull()) return nullptr;
    if (!constraints || constraintCount < 1) return nullptr;
    try {
        // NLPlate needs bounded surface
        Standard_Real u1, u2, v1, v2;
        initialSurface->surface->Bounds(u1, u2, v1, v2);

        Handle(Geom_Surface) workSurface = initialSurface->surface;
        bool needsTrim = Precision::IsNegativeInfinite(u1) || Precision::IsPositiveInfinite(u2) ||
                         Precision::IsNegativeInfinite(v1) || Precision::IsPositiveInfinite(v2);

        if (needsTrim) {
            double minU = 1e30, maxU = -1e30, minV = 1e30, maxV = -1e30;
            for (int32_t i = 0; i < constraintCount; i++) {
                double cu = constraints[i * 11 + 0];
                double cv = constraints[i * 11 + 1];
                minU = std::min(minU, cu); maxU = std::max(maxU, cu);
                minV = std::min(minV, cv); maxV = std::max(maxV, cv);
            }
            double padU = std::max(10.0, (maxU - minU) * 0.5);
            double padV = std::max(10.0, (maxV - minV) * 0.5);
            u1 = minU - padU; u2 = maxU + padU;
            v1 = minV - padV; v2 = maxV + padV;

            workSurface = new Geom_RectangularTrimmedSurface(initialSurface->surface, u1, u2, v1, v2);
        }

        NLPlate_NLPlate solver(workSurface);

        // constraints: flat (u, v, targetX, targetY, targetZ, d1uX, d1uY, d1uZ, d1vX, d1vY, d1vZ)
        for (int32_t i = 0; i < constraintCount; i++) {
            double u = constraints[i * 11 + 0];
            double v = constraints[i * 11 + 1];
            double tx = constraints[i * 11 + 2];
            double ty = constraints[i * 11 + 3];
            double tz = constraints[i * 11 + 4];
            double d1ux = constraints[i * 11 + 5];
            double d1uy = constraints[i * 11 + 6];
            double d1uz = constraints[i * 11 + 7];
            double d1vx = constraints[i * 11 + 8];
            double d1vy = constraints[i * 11 + 9];
            double d1vz = constraints[i * 11 + 10];

            gp_XY uv(u, v);
            gp_XYZ target(tx, ty, tz);
            gp_XYZ du(d1ux, d1uy, d1uz);
            gp_XYZ dv(d1vx, d1vy, d1vz);
            Plate_D1 d1(du, dv);
            Handle(NLPlate_HPG0G1Constraint) g0g1 = new NLPlate_HPG0G1Constraint(uv, target, d1);
            solver.Load(g0g1);
        }

        solver.Solve2(maxIter);
        if (!solver.IsDone()) return nullptr;

        if (!needsTrim) {
            workSurface->Bounds(u1, u2, v1, v2);
            if (Precision::IsNegativeInfinite(u1)) u1 = -100.0;
            if (Precision::IsPositiveInfinite(u2)) u2 = 100.0;
            if (Precision::IsNegativeInfinite(v1)) v1 = -100.0;
            if (Precision::IsPositiveInfinite(v2)) v2 = 100.0;
        }

        int nuPts = 20, nvPts = 20;
        TColgp_Array2OfPnt poles(1, nuPts, 1, nvPts);
        for (int iu = 1; iu <= nuPts; iu++) {
            double pu = u1 + (u2 - u1) * (iu - 1) / (nuPts - 1);
            for (int iv = 1; iv <= nvPts; iv++) {
                double pv = v1 + (v2 - v1) * (iv - 1) / (nvPts - 1);
                gp_XY uv(pu, pv);
                gp_XYZ disp = solver.Evaluate(uv);
                gp_Pnt origPt;
                workSurface->D0(pu, pv, origPt);
                gp_Pnt newPt(origPt.X() + disp.X(), origPt.Y() + disp.Y(), origPt.Z() + disp.Z());
                poles(iu, iv) = newPt;
            }
        }

        GeomAPI_PointsToBSplineSurface approx;
        approx.Init(poles, 3, 8, GeomAbs_C2, tolerance);
        Handle(Geom_BSplineSurface) result = approx.Surface();
        if (result.IsNull()) return nullptr;

        return new OCCTSurface(result);
    } catch (...) {
        return nullptr;
    }
}



// MARK: - GeomPlate_Surface (v0.61)
// MARK: - GeomPlate_Surface (v0.61.0)

OCCTShapeRef OCCTGeomPlateSurface(const double* points, int32_t ptCount,
    double tolerance, int32_t maxDegree, int32_t maxSegments) {
    if (!points || ptCount < 3) return nullptr;
    try {
        GeomPlate_BuildPlateSurface builder(3, 10, 5, tolerance);

        for (int32_t i = 0; i < ptCount; i++) {
            Handle(GeomPlate_PointConstraint) pc =
                new GeomPlate_PointConstraint(
                    gp_Pnt(points[i*3], points[i*3+1], points[i*3+2]), 0);
            builder.Add(pc);
        }

        builder.Perform();
        if (!builder.IsDone()) return nullptr;

        Handle(GeomPlate_Surface) plateSurf = builder.Surface();
        if (plateSurf.IsNull()) return nullptr;

        // Convert to BSpline for use as a face
        GeomPlate_MakeApprox approx(plateSurf, tolerance, maxSegments, maxDegree,
                                     tolerance * 0.1, 0);
        Handle(Geom_BSplineSurface) bspline = approx.Surface();
        if (bspline.IsNull()) return nullptr;

        BRepBuilderAPI_MakeFace faceMaker(bspline, tolerance);
        if (!faceMaker.IsDone()) return nullptr;
        return new OCCTShape(faceMaker.Face());
    } catch (...) { return nullptr; }
}

// MARK: - ProjLib Compute Approx (v0.64)
// --- ProjLib_ComputeApprox ---

OCCTShapeRef _Nullable OCCTProjLibComputeApprox(OCCTShapeRef edgeShape, OCCTShapeRef faceShape,
    double tolerance) {
    if (!edgeShape || !faceShape) return nullptr;
    try {
        TopoDS_Edge edge = TopoDS::Edge(edgeShape->shape);
        TopoDS_Face face = TopoDS::Face(faceShape->shape);
        double f, l;
        Handle(Geom_Curve) curve3d = BRep_Tool::Curve(edge, f, l);
        if (curve3d.IsNull()) return nullptr;
        Handle(Geom_Surface) surface = BRep_Tool::Surface(face);
        if (surface.IsNull()) return nullptr;

        Handle(GeomAdaptor_Curve) curveAdaptor = new GeomAdaptor_Curve(curve3d, f, l);
        Handle(GeomAdaptor_Surface) surfAdaptor = new GeomAdaptor_Surface(surface);

        ProjLib_ComputeApprox proj(curveAdaptor, surfAdaptor, tolerance);
        Handle(Geom2d_BSplineCurve) bsp = proj.BSpline();
        if (!bsp.IsNull()) {
            // Convert 2D curve to a 3D edge on the surface
            BRepBuilderAPI_MakeEdge me(bsp, surface);
            if (me.IsDone()) return new OCCTShape(me.Edge());
        }
        Handle(Geom2d_BezierCurve) bez = proj.Bezier();
        if (!bez.IsNull()) {
            BRepBuilderAPI_MakeEdge me(bez, surface);
            if (me.IsDone()) return new OCCTShape(me.Edge());
        }
        return nullptr;
    } catch (...) { return nullptr; }
}

// --- ProjLib_ComputeApproxOnPolarSurface ---

OCCTShapeRef _Nullable OCCTProjLibComputeApproxOnPolarSurface(OCCTShapeRef edgeShape,
    OCCTShapeRef faceShape, double tolerance) {
    if (!edgeShape || !faceShape) return nullptr;
    try {
        TopoDS_Edge edge = TopoDS::Edge(edgeShape->shape);
        TopoDS_Face face = TopoDS::Face(faceShape->shape);
        double f, l;
        Handle(Geom_Curve) curve3d = BRep_Tool::Curve(edge, f, l);
        if (curve3d.IsNull()) return nullptr;
        Handle(Geom_Surface) surface = BRep_Tool::Surface(face);
        if (surface.IsNull()) return nullptr;

        Handle(GeomAdaptor_Curve) curveAdaptor = new GeomAdaptor_Curve(curve3d, f, l);
        Handle(GeomAdaptor_Surface) surfAdaptor = new GeomAdaptor_Surface(surface);

        ProjLib_ComputeApproxOnPolarSurface proj(curveAdaptor, surfAdaptor, tolerance);
        if (!proj.IsDone()) return nullptr;

        Handle(Geom2d_BSplineCurve) bsp = proj.BSpline();
        if (!bsp.IsNull()) {
            BRepBuilderAPI_MakeEdge me(bsp, surface);
            if (me.IsDone()) return new OCCTShape(me.Edge());
        }
        Handle(Geom2d_Curve) curve2d = proj.Curve2d();
        if (!curve2d.IsNull()) {
            BRepBuilderAPI_MakeEdge me(curve2d, surface);
            if (me.IsDone()) return new OCCTShape(me.Edge());
        }
        return nullptr;
    } catch (...) { return nullptr; }
}

// MARK: - NLPlate G2/G3 / Incremental G0 (v0.69)
// --- NLPlate G0+G2 ---

OCCTSurfaceRef OCCTSurfaceNLPlateG2(OCCTSurfaceRef initialSurface,
    const double* constraints, int32_t constraintCount,
    int32_t maxIter, double tolerance)
{
    try {
        auto wrapper = (OCCTSurface*)initialSurface;
        Handle(Geom_Surface) workSurface = wrapper->surface;
        if (workSurface.IsNull()) return nullptr;

        NLPlate_NLPlate solver(workSurface);

        // Each constraint: 20 doubles (u, v, x,y,z, d1u(3), d1v(3), d2uu(3), d2uv(3), d2vv(3))
        for (int i = 0; i < constraintCount; i++) {
            const double* c = constraints + i * 20;
            gp_XY uv(c[0], c[1]);
            gp_XYZ target(c[2], c[3], c[4]);
            Plate_D1 d1(gp_XYZ(c[5], c[6], c[7]), gp_XYZ(c[8], c[9], c[10]));
            Plate_D2 d2(gp_XYZ(c[11], c[12], c[13]),
                        gp_XYZ(c[14], c[15], c[16]),
                        gp_XYZ(c[17], c[18], c[19]));

            Handle(NLPlate_HPG0G2Constraint) g0g2 = new NLPlate_HPG0G2Constraint(uv, target, d1, d2);
            solver.Load(g0g2);
        }

        solver.Solve2(2, 1);
        if (!solver.IsDone()) return nullptr;

        // Evaluate on a grid and create a BSpline surface
        int nu = 20, nv = 20;
        TColgp_Array2OfPnt poles(1, nu, 1, nv);
        for (int i = 1; i <= nu; i++) {
            for (int j = 1; j <= nv; j++) {
                double u = (double)(i-1)/(nu-1);
                double v = (double)(j-1)/(nv-1);
                gp_XYZ val = solver.Evaluate(gp_XY(u, v));
                poles(i, j) = gp_Pnt(val.X(), val.Y(), val.Z());
            }
        }

        GeomAPI_PointsToBSplineSurface fitter;
        fitter.Init(poles, 3, 8, GeomAbs_C2, tolerance > 0 ? tolerance : 1e-3);
        if (!fitter.IsDone()) return nullptr;

        Handle(Geom_BSplineSurface) result = fitter.Surface();
        if (result.IsNull()) return nullptr;

        auto* out = new OCCTSurface();
        out->surface = result;
        return (OCCTSurfaceRef)out;
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceNLPlateG3(OCCTSurfaceRef initialSurface,
    const double* constraints, int32_t constraintCount,
    int32_t maxIter, double tolerance)
{
    try {
        auto wrapper = (OCCTSurface*)initialSurface;
        Handle(Geom_Surface) workSurface = wrapper->surface;
        if (workSurface.IsNull()) return nullptr;

        NLPlate_NLPlate solver(workSurface);

        // Each constraint: 32 doubles
        for (int i = 0; i < constraintCount; i++) {
            const double* c = constraints + i * 32;
            gp_XY uv(c[0], c[1]);
            gp_XYZ target(c[2], c[3], c[4]);
            Plate_D1 d1(gp_XYZ(c[5], c[6], c[7]), gp_XYZ(c[8], c[9], c[10]));
            Plate_D2 d2(gp_XYZ(c[11], c[12], c[13]),
                        gp_XYZ(c[14], c[15], c[16]),
                        gp_XYZ(c[17], c[18], c[19]));
            Plate_D3 d3(gp_XYZ(c[20], c[21], c[22]),
                        gp_XYZ(c[23], c[24], c[25]),
                        gp_XYZ(c[26], c[27], c[28]),
                        gp_XYZ(c[29], c[30], c[31]));

            Handle(NLPlate_HPG0G3Constraint) g0g3 = new NLPlate_HPG0G3Constraint(uv, target, d1, d2, d3);
            solver.Load(g0g3);
        }

        solver.Solve2(3, 1);
        if (!solver.IsDone()) return nullptr;

        int nu = 20, nv = 20;
        TColgp_Array2OfPnt poles(1, nu, 1, nv);
        for (int i = 1; i <= nu; i++) {
            for (int j = 1; j <= nv; j++) {
                double u = (double)(i-1)/(nu-1);
                double v = (double)(j-1)/(nv-1);
                gp_XYZ val = solver.Evaluate(gp_XY(u, v));
                poles(i, j) = gp_Pnt(val.X(), val.Y(), val.Z());
            }
        }

        GeomAPI_PointsToBSplineSurface fitter;
        fitter.Init(poles, 3, 8, GeomAbs_C2, tolerance > 0 ? tolerance : 1e-3);
        if (!fitter.IsDone()) return nullptr;

        Handle(Geom_BSplineSurface) result = fitter.Surface();
        if (result.IsNull()) return nullptr;

        auto* out = new OCCTSurface();
        out->surface = result;
        return (OCCTSurfaceRef)out;
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceNLPlateIncrementalG0(OCCTSurfaceRef initialSurface,
    const double* constraints, int32_t constraintCount,
    int32_t maxOrder, int32_t initConstraintOrder, int32_t nbIncrements)
{
    try {
        auto wrapper = (OCCTSurface*)initialSurface;
        Handle(Geom_Surface) workSurface = wrapper->surface;
        if (workSurface.IsNull()) return nullptr;

        NLPlate_NLPlate solver(workSurface);

        for (int i = 0; i < constraintCount; i++) {
            const double* c = constraints + i * 5;
            gp_XY uv(c[0], c[1]);
            gp_XYZ target(c[2], c[3], c[4]);
            Handle(NLPlate_HPG0Constraint) g0 = new NLPlate_HPG0Constraint(uv, target);
            solver.Load(g0);
        }

        solver.IncrementalSolve(maxOrder, initConstraintOrder, nbIncrements, false);
        if (!solver.IsDone()) return nullptr;

        int nu = 20, nv = 20;
        TColgp_Array2OfPnt poles(1, nu, 1, nv);
        for (int i = 1; i <= nu; i++) {
            for (int j = 1; j <= nv; j++) {
                double u = (double)(i-1)/(nu-1);
                double v = (double)(j-1)/(nv-1);
                gp_XYZ val = solver.Evaluate(gp_XY(u, v));
                poles(i, j) = gp_Pnt(val.X(), val.Y(), val.Z());
            }
        }

        GeomAPI_PointsToBSplineSurface fitter;
        fitter.Init(poles, 3, 8, GeomAbs_C2, 1e-3);
        if (!fitter.IsDone()) return nullptr;

        Handle(Geom_BSplineSurface) result = fitter.Surface();
        if (result.IsNull()) return nullptr;

        auto* out = new OCCTSurface();
        out->surface = result;
        return (OCCTSurfaceRef)out;
    } catch (...) {
        return nullptr;
    }
}

bool OCCTSurfaceNLPlateEvaluateDerivative(OCCTSurfaceRef initialSurface,
    const double* constraints, int32_t constraintCount,
    double u, double v, int32_t iu, int32_t iv,
    double* outX, double* outY, double* outZ)
{
    try {
        auto wrapper = (OCCTSurface*)initialSurface;
        Handle(Geom_Surface) workSurface = wrapper->surface;
        if (workSurface.IsNull()) return false;

        NLPlate_NLPlate solver(workSurface);

        for (int i = 0; i < constraintCount; i++) {
            const double* c = constraints + i * 5;
            gp_XY uv(c[0], c[1]);
            gp_XYZ target(c[2], c[3], c[4]);
            Handle(NLPlate_HPG0Constraint) g0 = new NLPlate_HPG0Constraint(uv, target);
            solver.Load(g0);
        }

        solver.Solve2(2, 1);
        if (!solver.IsDone()) return false;

        gp_XYZ result = solver.EvaluateDerivative(gp_XY(u, v), iu, iv);
        *outX = result.X();
        *outY = result.Y();
        *outZ = result.Z();
        return true;
    } catch (...) {
        return false;
    }
}

// MARK: - Plate_Plate Solver (v0.69)
// --- Plate_Plate solver ---

OCCTPlateRef OCCTPlateCreate(void)
{
    try {
        return (OCCTPlateRef)(new Plate_Plate());
    } catch (...) {
        return nullptr;
    }
}

void OCCTPlateRelease(OCCTPlateRef plate)
{
    if (plate) {
        delete (Plate_Plate*)plate;
    }
}

void OCCTPlateLoadPinpoint(OCCTPlateRef plate,
    double u, double v, double x, double y, double z,
    int32_t iu, int32_t iv)
{
    try {
        auto* p = (Plate_Plate*)plate;
        p->Load(Plate_PinpointConstraint(gp_XY(u, v), gp_XYZ(x, y, z), iu, iv));
    } catch (...) {}
}

void OCCTPlateLoadGtoC(OCCTPlateRef plate,
    double u, double v,
    const double* d1s, const double* d1t)
{
    try {
        auto* p = (Plate_Plate*)plate;
        Plate_D1 src(gp_XYZ(d1s[0], d1s[1], d1s[2]), gp_XYZ(d1s[3], d1s[4], d1s[5]));
        Plate_D1 tgt(gp_XYZ(d1t[0], d1t[1], d1t[2]), gp_XYZ(d1t[3], d1t[4], d1t[5]));
        p->Load(Plate_GtoCConstraint(gp_XY(u, v), src, tgt));
    } catch (...) {}
}

bool OCCTPlateSolve(OCCTPlateRef plate, int32_t order, double anisotropy)
{
    try {
        auto* p = (Plate_Plate*)plate;
        p->SolveTI(order, anisotropy, Message_ProgressRange());
        return p->IsDone();
    } catch (...) {
        return false;
    }
}

bool OCCTPlateIsDone(OCCTPlateRef plate)
{
    try {
        return ((Plate_Plate*)plate)->IsDone();
    } catch (...) {
        return false;
    }
}

void OCCTPlateEvaluate(OCCTPlateRef plate,
    double u, double v,
    double* outX, double* outY, double* outZ)
{
    try {
        auto* p = (Plate_Plate*)plate;
        gp_XYZ result = p->Evaluate(gp_XY(u, v));
        *outX = result.X();
        *outY = result.Y();
        *outZ = result.Z();
    } catch (...) {
        *outX = *outY = *outZ = 0;
    }
}

void OCCTPlateEvaluateDerivative(OCCTPlateRef plate,
    double u, double v, int32_t iu, int32_t iv,
    double* outX, double* outY, double* outZ)
{
    try {
        auto* p = (Plate_Plate*)plate;
        gp_XYZ result = p->EvaluateDerivative(gp_XY(u, v), iu, iv);
        *outX = result.X();
        *outY = result.Y();
        *outZ = result.Z();
    } catch (...) {
        *outX = *outY = *outZ = 0;
    }
}

void OCCTPlateUVBox(OCCTPlateRef plate,
    double* umin, double* umax,
    double* vmin, double* vmax)
{
    try {
        auto* p = (Plate_Plate*)plate;
        p->UVBox(*umin, *umax, *vmin, *vmax);
    } catch (...) {
        *umin = *umax = *vmin = *vmax = 0;
    }
}

int32_t OCCTPlateContinuity(OCCTPlateRef plate)
{
    try {
        return (int32_t)((Plate_Plate*)plate)->Continuity();
    } catch (...) {
        return -1;
    }
}

// MARK: - GeomPlate_BuildAveragePlane (v0.69)
// --- GeomPlate_BuildAveragePlane ---

OCCTAveragePlaneResult OCCTGeomPlateBuildAveragePlane(
    const double* points, int32_t pointCount,
    int32_t nbBoundPoints, double tolerance)
{
    OCCTAveragePlaneResult result = {};
    try {
        Handle(NCollection_HArray1<gp_Pnt>) pts = new NCollection_HArray1<gp_Pnt>(1, pointCount);
        for (int i = 0; i < pointCount; i++) {
            pts->SetValue(i + 1, gp_Pnt(points[i*3], points[i*3+1], points[i*3+2]));
        }

        GeomPlate_BuildAveragePlane avgPlane(pts, nbBoundPoints, tolerance, 1, 1);

        result.isPlane = avgPlane.IsPlane();
        result.isLine = avgPlane.IsLine();

        if (result.isPlane) {
            Handle(Geom_Plane) plane = avgPlane.Plane();
            if (!plane.IsNull()) {
                gp_Pnt origin = plane->Location();
                gp_Dir normal = plane->Axis().Direction();
                result.normalX = normal.X();
                result.normalY = normal.Y();
                result.normalZ = normal.Z();
                result.originX = origin.X();
                result.originY = origin.Y();
                result.originZ = origin.Z();
            }
            avgPlane.MinMaxBox(result.umin, result.umax, result.vmin, result.vmax);
        }

        if (result.isLine) {
            Handle(Geom_Line) line = avgPlane.Line();
            if (!line.IsNull()) {
                gp_Pnt origin = line->Lin().Location();
                gp_Dir dir = line->Lin().Direction();
                result.lineOriginX = origin.X();
                result.lineOriginY = origin.Y();
                result.lineOriginZ = origin.Z();
                result.lineDirX = dir.X();
                result.lineDirY = dir.Y();
                result.lineDirZ = dir.Z();
            }
        }
    } catch (...) {}
    return result;
}

bool OCCTGeomPlateErrors(const double* points, int32_t ptCount,
    double tolerance, int32_t maxDegree, int32_t maxSegments,
    double* g0Error, double* g1Error, double* g2Error)
{
    try {
        GeomPlate_BuildPlateSurface builder(3, 10, 5, tolerance);

        for (int i = 0; i < ptCount; i++) {
            gp_Pnt pt(points[i*3], points[i*3+1], points[i*3+2]);
            Handle(GeomPlate_PointConstraint) pc = new GeomPlate_PointConstraint(pt, 0, tolerance);
            builder.Add(pc);
        }

        builder.Perform(Message_ProgressRange());
        if (!builder.IsDone()) return false;

        *g0Error = builder.G0Error();
        *g1Error = builder.G1Error();
        *g2Error = builder.G2Error();
        return true;
    } catch (...) {
        return false;
    }
}

// MARK: - ShapeConstruct_ProjectCurveOnSurface (v0.75)
// --- ShapeConstruct_ProjectCurveOnSurface ---

OCCTCurve2DRef _Nullable OCCTProjectCurveOnSurface(OCCTCurve3DRef _Nonnull curve,
                                                     OCCTSurfaceRef _Nonnull surface,
                                                     double firstParam,
                                                     double lastParam,
                                                     double precision) {
    if (!curve || !surface || curve->curve.IsNull() || surface->surface.IsNull()) return nullptr;
    try {
        Handle(ShapeConstruct_ProjectCurveOnSurface) projector =
            new ShapeConstruct_ProjectCurveOnSurface();
        projector->Init(surface->surface, precision);

        Handle(Geom2d_Curve) curve2d;
        bool ok = projector->Perform(curve->curve, firstParam, lastParam, curve2d);
        if (!ok || curve2d.IsNull()) return nullptr;

        auto* ref = new OCCTCurve2D();
        ref->curve = curve2d;
        return ref;
    } catch (...) {
        return nullptr;
    }
}

// MARK: - ProjLib_ProjectOnSurface (v0.80)
// --- ProjLib_ProjectOnSurface ---

OCCTCurve3DRef _Nullable OCCTProjLibProjectOnSurface(OCCTCurve3DRef curve, double uFirst, double uLast,
                                                      OCCTSurfaceRef surface, double tolerance) {
    try {
        auto* c = (OCCTCurve3D*)curve;
        auto* s = (OCCTSurface*)surface;
        Handle(GeomAdaptor_Surface) as = new GeomAdaptor_Surface(s->surface);
        Handle(Geom_TrimmedCurve) trimmed = new Geom_TrimmedCurve(c->curve, uFirst, uLast);
        Handle(GeomAdaptor_Curve) ac = new GeomAdaptor_Curve(trimmed);

        ProjLib_ProjectOnSurface proj;
        proj.Load(as);
        proj.Load(ac, tolerance);

        if (proj.IsDone()) {
            Handle(Geom_BSplineCurve) bsp = proj.BSpline();
            if (!bsp.IsNull()) return (OCCTCurve3DRef)new OCCTCurve3D{bsp};
        }
        return nullptr;
    } catch (...) { return nullptr; }
}

// MARK: - v0.103: Plate Constraint Extensions
// MARK: - Plate Constraint Extensions (v0.103.0)

#include <Plate_PlaneConstraint.hxx>
#include <Plate_LineConstraint.hxx>
#include <Plate_FreeGtoCConstraint.hxx>
#include <Plate_LinearScalarConstraint.hxx>

bool OCCTPlateLoadPlaneConstraint(OCCTPlateRef plate, double u, double v,
                                   double px, double py, double pz,
                                   double nx, double ny, double nz) {
    try {
        auto* p = (Plate_Plate*)plate;
        gp_XY uv(u, v);
        gp_Pln pln(gp_Pnt(px,py,pz), gp_Dir(nx,ny,nz));
        Plate_PlaneConstraint pc(uv, pln);
        p->Load(pc.LSC());
        return true;
    } catch (...) { return false; }
}

bool OCCTPlateLoadLineConstraint(OCCTPlateRef plate, double u, double v,
                                  double px, double py, double pz,
                                  double dx, double dy, double dz) {
    try {
        auto* p = (Plate_Plate*)plate;
        gp_XY uv(u, v);
        gp_Lin lin(gp_Pnt(px,py,pz), gp_Dir(dx,dy,dz));
        Plate_LineConstraint lc(uv, lin);
        p->Load(lc.LSC());
        return true;
    } catch (...) { return false; }
}

bool OCCTPlateLoadFreeG1Constraint(OCCTPlateRef plate, double u, double v,
                                    double duX, double duY, double duZ,
                                    double dvX, double dvY, double dvZ) {
    try {
        auto* p = (Plate_Plate*)plate;
        gp_XY uv(u, v);
        Plate_D1 d1s(gp_XYZ(duX,duY,duZ), gp_XYZ(dvX,dvY,dvZ));
        Plate_D1 d1t(gp_XYZ(duX,duY,duZ), gp_XYZ(dvX,dvY,dvZ));
        Plate_FreeGtoCConstraint fgtoc(uv, d1s, d1t);
        for (int i = 1; i <= fgtoc.nb_LSC(); i++) {
            p->Load(fgtoc.LSC(i));
        }
        for (int i = 1; i <= fgtoc.nb_PPC(); i++) {
            p->Load(fgtoc.GetPPC(i));
        }
        return true;
    } catch (...) { return false; }
}

// MARK: - v0.109: Plate Constraints Extensions
// MARK: - Plate Constraints Extensions (v0.109.0)

#include <Plate_GlobalTranslationConstraint.hxx>
#include <Plate_LinearXYZConstraint.hxx>

bool OCCTPlateLoadGlobalTranslation(OCCTPlateRef plate, const double* uvs, int32_t count) {
    if (!plate || !uvs || count <= 0) return false;
    try {
        Plate_Plate* pp = (Plate_Plate*)plate;
        NCollection_Sequence<gp_XY> pts;
        for (int i = 0; i < count; i++) {
            pts.Append(gp_XY(uvs[i * 2], uvs[i * 2 + 1]));
        }
        Plate_GlobalTranslationConstraint constraint(pts);
        pp->Load(constraint.LXYZC());
        return true;
    } catch (...) { return false; }
}

bool OCCTPlateLoadLinearXYZ(OCCTPlateRef plate,
                             const double* uvs,
                             const double* targets,
                             const double* coeffs,
                             int32_t count) {
    if (!plate || !uvs || !targets || !coeffs || count <= 0) return false;
    try {
        Plate_Plate* pp = (Plate_Plate*)plate;
        // Build PinpointConstraints from UV+target pairs
        NCollection_Array1<Plate_PinpointConstraint> ppc(1, count);
        NCollection_Array2<double> coefs(1, 1, 1, count);
        for (int i = 0; i < count; i++) {
            gp_XY uv(uvs[i * 2], uvs[i * 2 + 1]);
            gp_XYZ target(targets[i * 3], targets[i * 3 + 1], targets[i * 3 + 2]);
            ppc.SetValue(i + 1, Plate_PinpointConstraint(uv, target));
            coefs.SetValue(1, i + 1, coeffs[i]);
        }
        Plate_LinearXYZConstraint lc(ppc, coefs);
        pp->Load(lc);
        return true;
    } catch (...) { return false; }
}

// MARK: - v0.116: ProjLib Plane/Cylinder Project Line + Plane Project Circle
bool OCCTProjLibPlaneProjectLine(double plnPx, double plnPy, double plnPz,
                                   double plnNx, double plnNy, double plnNz,
                                   double linPx, double linPy, double linPz,
                                   double linDx, double linDy, double linDz,
                                   double* _Nonnull resPx, double* _Nonnull resPy,
                                   double* _Nonnull resDx, double* _Nonnull resDy) {
    try {
        gp_Pln pln(gp_Pnt(plnPx, plnPy, plnPz), gp_Dir(plnNx, plnNy, plnNz));
        gp_Lin lin(gp_Pnt(linPx, linPy, linPz), gp_Dir(linDx, linDy, linDz));
        ProjLib_Plane proj(pln, lin);
        if (proj.IsDone()) {
            gp_Lin2d l2d = proj.Line();
            *resPx = l2d.Location().X(); *resPy = l2d.Location().Y();
            *resDx = l2d.Direction().X(); *resDy = l2d.Direction().Y();
            return true;
        }
        return false;
    } catch (...) { return false; }
}

bool OCCTProjLibCylinderProjectLine(double cylPx, double cylPy, double cylPz,
                                      double cylDx, double cylDy, double cylDz,
                                      double cylRadius,
                                      double linPx, double linPy, double linPz,
                                      double linDx, double linDy, double linDz,
                                      double* _Nonnull resPx, double* _Nonnull resPy,
                                      double* _Nonnull resDx, double* _Nonnull resDy) {
    try {
        gp_Ax3 ax(gp_Pnt(cylPx, cylPy, cylPz), gp_Dir(cylDx, cylDy, cylDz));
        gp_Cylinder cyl(ax, cylRadius);
        gp_Lin lin(gp_Pnt(linPx, linPy, linPz), gp_Dir(linDx, linDy, linDz));
        ProjLib_Cylinder proj(cyl, lin);
        if (proj.IsDone()) {
            gp_Lin2d l2d = proj.Line();
            *resPx = l2d.Location().X(); *resPy = l2d.Location().Y();
            *resDx = l2d.Direction().X(); *resDy = l2d.Direction().Y();
            return true;
        }
        return false;
    } catch (...) { return false; }
}

bool OCCTProjLibPlaneProjectCircle(double plnPx, double plnPy, double plnPz,
                                     double plnNx, double plnNy, double plnNz,
                                     double cirCx, double cirCy, double cirCz,
                                     double cirNx, double cirNy, double cirNz,
                                     double cirRadius,
                                     double* _Nonnull resCx, double* _Nonnull resCy,
                                     double* _Nonnull resRadius) {
    try {
        gp_Pln pln(gp_Pnt(plnPx, plnPy, plnPz), gp_Dir(plnNx, plnNy, plnNz));
        gp_Ax2 ax(gp_Pnt(cirCx, cirCy, cirCz), gp_Dir(cirNx, cirNy, cirNz));
        gp_Circ circ(ax, cirRadius);
        ProjLib_Plane proj(pln, circ);
        if (proj.IsDone()) {
            gp_Circ2d c2d = proj.Circle();
            *resCx = c2d.Location().X(); *resCy = c2d.Location().Y();
            *resRadius = c2d.Radius();
            return true;
        }
        return false;
    } catch (...) { return false; }
}

// end of v0.117.0 implementations
