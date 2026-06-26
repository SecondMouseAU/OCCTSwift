//
//  OCCTBridge_Surface.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm — issue #99.
//
//  3D parametric surface cluster (v0.20):
//
//  - Geom_Surface construction (plane, cylinder, cone, sphere, torus,
//    surface-of-revolution, surface-of-extrusion, BSpline, Bezier,
//    rectangular-trimmed, offset)
//  - GeomConvert + GeomConvert_ApproxSurface
//  - GeomFill_Pipe (parametric pipe surface)
//  - Local properties (GeomLProp_SLProps)
//  - Adaptor (GeomAdaptor_Surface) introspection: surface type, axes,
//    UV bounds, periodic flags, degrees, knot/pole counts
//
//  OCCTSurface struct definition kept in BOTH this TU and OCCTBridge.mm
//  (identical layout, ODR-safe across TUs) — main still uses
//  surface->surface field access in projection / surface-grid eval / etc.
//
//  Public C surface unchanged. No symbol changes — pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// === Area-specific OCCT headers ===

#include <Geom_BezierSurface.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_ConicalSurface.hxx>
#include <Geom_Curve.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_OffsetSurface.hxx>
#include <Geom_Plane.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <Geom_SphericalSurface.hxx>
#include <Geom_Surface.hxx>
#include <Geom_SurfaceOfLinearExtrusion.hxx>
#include <Geom_SurfaceOfRevolution.hxx>
#include <Geom_ToroidalSurface.hxx>

#include <GeomAbs_Shape.hxx>
#include <GeomAdaptor_Surface.hxx>
#include <GeomConvert.hxx>
#include <GeomConvert_ApproxSurface.hxx>
#include <GeomConvert_BSplineSurfaceToBezierSurface.hxx>
#include <GeomAPI_IntSS.hxx>
#include <GeomAPI_IntCS.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_BezierSurface.hxx>
#include <GC_MakeConicalSurface.hxx>
#include <GC_MakeCylindricalSurface.hxx>
#include <GC_MakePlane.hxx>
#include <GC_MakeTrimmedCone.hxx>
#include <GC_MakeTrimmedCylinder.hxx>
#include <GeomConvert_BSplineSurfaceKnotSplitting.hxx>
#include <GeomConvert_CompBezierSurfacesToBSplineSurface.hxx>
#include <GeomFill_Pipe.hxx>
#include <GeomFill_BSplineCurves.hxx>
#include <Adaptor3d_IsoCurve.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <LocalAnalysis_SurfaceContinuity.hxx>
#include <GeomFill_ConstantBiNormal.hxx>
#include <GeomFill_Darboux.hxx>
#include <GeomFill_Fixed.hxx>
#include <GeomFill_Frenet.hxx>
#include <GeomFill_NSections.hxx>
#include <GeomFill_BoundWithSurf.hxx>
#include <GeomLib_Tool.hxx>
#include <GeomLib_IsPlanarSurface.hxx>
#include <GeomFill_AppSurf.hxx>
#include <GeomFill_DegeneratedBound.hxx>
#include <GeomFill_GuideTrihedronAC.hxx>
#include <GeomFill_GuideTrihedronPlan.hxx>
#include <GeomFill_Line.hxx>
#include <GeomFill_LocationDraft.hxx>
#include <GeomFill_Profiler.hxx>
#include <GeomFill_SectionGenerator.hxx>
#include <GeomFill_SectionPlacement.hxx>
#include <GeomFill_Stretch.hxx>
#include <GeomFill_Generator.hxx>
#include <Extrema_ExtPS.hxx>
#include <Extrema_ExtSS.hxx>
#include <Extrema_POnSurf.hxx>
#include <gce_MakeCone.hxx>
#include <gce_MakeCylinder.hxx>
#include <gce_MakePln.hxx>
#include <Convert_CylinderToBSplineSurface.hxx>
#include <Convert_ConeToBSplineSurface.hxx>
#include <Convert_TorusToBSplineSurface.hxx>
#include <Convert_SphereToBSplineSurface.hxx>
#include <BiTgte_CurveOnEdge.hxx>
#include <GeomAPI_ProjectPointOnSurf.hxx>
#include <GeomAPI_PointsToBSplineSurface.hxx>
#include <TColgp_HArray2OfPnt.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TColgp_Array2OfPnt.hxx>
#include <TColStd_Array2OfReal.hxx>
#include <Adaptor3d_CurveOnSurface.hxx>
#include <BRepTopAdaptor_TopolTool.hxx>
#include <Contap_ContAna.hxx>
#include <Contap_Contour.hxx>
#include <Contap_IType.hxx>
#include <Contap_Line.hxx>
#include <Approx_MCurvesToBSpCurve.hxx>
#include <GeomFill_Coons.hxx>
#include <GeomFill_CoonsAlgPatch.hxx>
#include <GeomFill_CorrectedFrenet.hxx>
#include <GeomFill_Curved.hxx>
#include <GeomFill_CurveAndTrihedron.hxx>
#include <GeomFill_DiscreteTrihedron.hxx>
#include <GeomFill_DraftTrihedron.hxx>
#include <GeomFill_EvolvedSection.hxx>
#include <GeomFill_Sweep.hxx>
#include <GeomFill_UniformSection.hxx>
#include <GeomInt_IntSS.hxx>
#include <IntSurf_PntOn2S.hxx>
#include <Law_Constant.hxx>
#include <GeomFill_ConstrainedFilling.hxx>
#include <GeomFill_SimpleBound.hxx>
#include <ShapeCustom_Surface.hxx>
#include <ShapeUpgrade_SplitSurfaceContinuity.hxx>
#include <TColGeom_Array2OfBezierSurface.hxx>
#include <TColStd_HSequenceOfReal.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepAdaptor_CompCurve.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <GeomLProp_SLProps.hxx>
#include <TopExp_Explorer.hxx>
#include <TopAbs.hxx>
#include <TopoDS.hxx>
#include <BRep_Tool.hxx>
#include <GeomAPI_ExtremaSurfaceSurface.hxx>

#include <gp_Ax1.hxx>
#include <gp_Ax2.hxx>
#include <gp_Ax3.hxx>
#include <gp_Cone.hxx>
#include <gp_Cylinder.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>
#include <gp_Sphere.hxx>
#include <gp_Torus.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>

#include <TColgp_Array2OfPnt.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColStd_Array2OfReal.hxx>

// MARK: - Surface: Parametric Surfaces (v0.20.0)
// ============================================================================

#include <Geom_Surface.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_ConicalSurface.hxx>
#include <Geom_SphericalSurface.hxx>
#include <Geom_ToroidalSurface.hxx>
#include <Geom_BezierSurface.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <Geom_OffsetSurface.hxx>
#include <Geom_SurfaceOfLinearExtrusion.hxx>
#include <Geom_SurfaceOfRevolution.hxx>
#include <GeomFill_Pipe.hxx>
#include <GeomConvert_ApproxSurface.hxx>
#include <GeomAdaptor_Surface.hxx>
#include <BndLib_AddSurface.hxx>
#include <TColgp_Array2OfPnt.hxx>
#include <TColStd_Array2OfReal.hxx>
#include <gp_Cylinder.hxx>
#include <gp_Cone.hxx>
#include <gp_Sphere.hxx>
#include <gp_Torus.hxx>

void OCCTSurfaceRelease(OCCTSurfaceRef s) {
    delete s;
}

// Properties

void OCCTSurfaceGetDomain(OCCTSurfaceRef s,
                           double* uMin, double* uMax,
                           double* vMin, double* vMax) {
    if (!s || s->surface.IsNull() || !uMin || !uMax || !vMin || !vMax) return;
    s->surface->Bounds(*uMin, *uMax, *vMin, *vMax);
}

bool OCCTSurfaceIsUClosed(OCCTSurfaceRef s) {
    if (!s || s->surface.IsNull()) return false;
    return s->surface->IsUClosed() == Standard_True;
}

bool OCCTSurfaceIsVClosed(OCCTSurfaceRef s) {
    if (!s || s->surface.IsNull()) return false;
    return s->surface->IsVClosed() == Standard_True;
}

bool OCCTSurfaceIsUPeriodic(OCCTSurfaceRef s) {
    if (!s || s->surface.IsNull()) return false;
    return s->surface->IsUPeriodic() == Standard_True;
}

bool OCCTSurfaceIsVPeriodic(OCCTSurfaceRef s) {
    if (!s || s->surface.IsNull()) return false;
    return s->surface->IsVPeriodic() == Standard_True;
}

double OCCTSurfaceGetUPeriod(OCCTSurfaceRef s) {
    if (!s || s->surface.IsNull() || !s->surface->IsUPeriodic()) return 0.0;
    return s->surface->UPeriod();
}

double OCCTSurfaceGetVPeriod(OCCTSurfaceRef s) {
    if (!s || s->surface.IsNull() || !s->surface->IsVPeriodic()) return 0.0;
    return s->surface->VPeriod();
}

// Evaluation

void OCCTSurfaceGetPoint(OCCTSurfaceRef s, double u, double v,
                          double* x, double* y, double* z) {
    if (!s || s->surface.IsNull() || !x || !y || !z) return;
    gp_Pnt p;
    s->surface->D0(u, v, p);
    *x = p.X(); *y = p.Y(); *z = p.Z();
}

void OCCTSurfaceD1(OCCTSurfaceRef s, double u, double v,
                    double* px, double* py, double* pz,
                    double* dux, double* duy, double* duz,
                    double* dvx, double* dvy, double* dvz) {
    if (!s || s->surface.IsNull() ||
        !px || !py || !pz || !dux || !duy || !duz || !dvx || !dvy || !dvz) return;
    gp_Pnt p;
    gp_Vec du, dv;
    s->surface->D1(u, v, p, du, dv);
    *px = p.X(); *py = p.Y(); *pz = p.Z();
    *dux = du.X(); *duy = du.Y(); *duz = du.Z();
    *dvx = dv.X(); *dvy = dv.Y(); *dvz = dv.Z();
}

void OCCTSurfaceD2(OCCTSurfaceRef s, double u, double v,
                    double* px, double* py, double* pz,
                    double* d1ux, double* d1uy, double* d1uz,
                    double* d1vx, double* d1vy, double* d1vz,
                    double* d2ux, double* d2uy, double* d2uz,
                    double* d2vx, double* d2vy, double* d2vz,
                    double* d2uvx, double* d2uvy, double* d2uvz) {
    if (!s || s->surface.IsNull() ||
        !px || !py || !pz ||
        !d1ux || !d1uy || !d1uz || !d1vx || !d1vy || !d1vz ||
        !d2ux || !d2uy || !d2uz || !d2vx || !d2vy || !d2vz ||
        !d2uvx || !d2uvy || !d2uvz) return;
    gp_Pnt p;
    gp_Vec d1u, d1v, d2u, d2v, d2uv;
    s->surface->D2(u, v, p, d1u, d1v, d2u, d2v, d2uv);
    *px = p.X(); *py = p.Y(); *pz = p.Z();
    *d1ux = d1u.X(); *d1uy = d1u.Y(); *d1uz = d1u.Z();
    *d1vx = d1v.X(); *d1vy = d1v.Y(); *d1vz = d1v.Z();
    *d2ux = d2u.X(); *d2uy = d2u.Y(); *d2uz = d2u.Z();
    *d2vx = d2v.X(); *d2vy = d2v.Y(); *d2vz = d2v.Z();
    *d2uvx = d2uv.X(); *d2uvy = d2uv.Y(); *d2uvz = d2uv.Z();
}

bool OCCTSurfaceGetNormal(OCCTSurfaceRef s, double u, double v,
                           double* nx, double* ny, double* nz) {
    if (!s || s->surface.IsNull() || !nx || !ny || !nz) return false;
    try {
        GeomLProp_SLProps props(s->surface, u, v, 1, Precision::Confusion());
        if (!props.IsNormalDefined()) return false;
        gp_Dir n = props.Normal();
        *nx = n.X(); *ny = n.Y(); *nz = n.Z();
        return true;
    } catch (...) {
        return false;
    }
}

// Analytic Surfaces

OCCTSurfaceRef OCCTSurfaceCreatePlane(double px, double py, double pz,
                                       double nx, double ny, double nz) {
    try {
        gp_Pnt origin(px, py, pz);
        gp_Dir normal(nx, ny, nz);
        Handle(Geom_Plane) plane = new Geom_Plane(origin, normal);
        return new OCCTSurface(plane);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceCreateCylinder(double px, double py, double pz,
                                          double dx, double dy, double dz,
                                          double radius) {
    try {
        if (radius <= 0) return nullptr;
        gp_Pnt origin(px, py, pz);
        gp_Dir dir(dx, dy, dz);
        gp_Ax3 axis(origin, dir);
        Handle(Geom_CylindricalSurface) cyl = new Geom_CylindricalSurface(axis, radius);
        return new OCCTSurface(cyl);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceCreateCone(double px, double py, double pz,
                                      double dx, double dy, double dz,
                                      double radius, double semiAngle) {
    try {
        if (radius < 0) return nullptr;
        gp_Pnt origin(px, py, pz);
        gp_Dir dir(dx, dy, dz);
        gp_Ax3 axis(origin, dir);
        Handle(Geom_ConicalSurface) cone = new Geom_ConicalSurface(axis, semiAngle, radius);
        return new OCCTSurface(cone);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceCreateSphere(double cx, double cy, double cz,
                                        double radius) {
    try {
        if (radius <= 0) return nullptr;
        gp_Pnt center(cx, cy, cz);
        gp_Ax3 axis(center, gp::DZ());
        Handle(Geom_SphericalSurface) sphere = new Geom_SphericalSurface(axis, radius);
        return new OCCTSurface(sphere);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceCreateTorus(double px, double py, double pz,
                                       double dx, double dy, double dz,
                                       double majorRadius, double minorRadius) {
    try {
        if (majorRadius <= 0 || minorRadius <= 0 || minorRadius >= majorRadius)
            return nullptr;
        gp_Pnt origin(px, py, pz);
        gp_Dir dir(dx, dy, dz);
        gp_Ax3 axis(origin, dir);
        Handle(Geom_ToroidalSurface) torus = new Geom_ToroidalSurface(axis, majorRadius, minorRadius);
        return new OCCTSurface(torus);
    } catch (...) {
        return nullptr;
    }
}

// Swept Surfaces

OCCTSurfaceRef OCCTSurfaceCreateExtrusion(OCCTCurve3DRef profile,
                                           double dx, double dy, double dz) {
    if (!profile || profile->curve.IsNull()) return nullptr;
    try {
        gp_Dir dir(dx, dy, dz);
        Handle(Geom_SurfaceOfLinearExtrusion) ext =
            new Geom_SurfaceOfLinearExtrusion(profile->curve, dir);
        return new OCCTSurface(ext);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceCreateRevolution(OCCTCurve3DRef meridian,
                                            double px, double py, double pz,
                                            double dx, double dy, double dz) {
    if (!meridian || meridian->curve.IsNull()) return nullptr;
    try {
        gp_Pnt origin(px, py, pz);
        gp_Dir dir(dx, dy, dz);
        gp_Ax1 axis(origin, dir);
        Handle(Geom_SurfaceOfRevolution) rev =
            new Geom_SurfaceOfRevolution(meridian->curve, axis);
        return new OCCTSurface(rev);
    } catch (...) {
        return nullptr;
    }
}

// Freeform Surfaces

OCCTSurfaceRef OCCTSurfaceCreateBezier(const double* poles,
                                        int32_t uCount, int32_t vCount,
                                        const double* weights) {
    if (!poles || uCount < 2 || vCount < 2) return nullptr;
    try {
        TColgp_Array2OfPnt poleArray(1, uCount, 1, vCount);
        for (int32_t i = 0; i < uCount; i++) {
            for (int32_t j = 0; j < vCount; j++) {
                int idx = (i * vCount + j) * 3;
                poleArray.SetValue(i + 1, j + 1,
                    gp_Pnt(poles[idx], poles[idx+1], poles[idx+2]));
            }
        }
        Handle(Geom_BezierSurface) bez;
        if (weights) {
            TColStd_Array2OfReal wArr(1, uCount, 1, vCount);
            for (int32_t i = 0; i < uCount; i++) {
                for (int32_t j = 0; j < vCount; j++) {
                    wArr.SetValue(i + 1, j + 1, weights[i * vCount + j]);
                }
            }
            bez = new Geom_BezierSurface(poleArray, wArr);
        } else {
            bez = new Geom_BezierSurface(poleArray);
        }
        return new OCCTSurface(bez);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceCreateBSpline(const double* poles,
                                         int32_t uPoleCount, int32_t vPoleCount,
                                         const double* weights,
                                         const double* uKnots, int32_t uKnotCount,
                                         const double* vKnots, int32_t vKnotCount,
                                         const int32_t* uMults, const int32_t* vMults,
                                         int32_t uDegree, int32_t vDegree) {
    if (!poles || !uKnots || !vKnots || !uMults || !vMults) return nullptr;
    if (uPoleCount < 2 || vPoleCount < 2 || uKnotCount < 2 || vKnotCount < 2) return nullptr;
    try {
        TColgp_Array2OfPnt poleArray(1, uPoleCount, 1, vPoleCount);
        for (int32_t i = 0; i < uPoleCount; i++) {
            for (int32_t j = 0; j < vPoleCount; j++) {
                int idx = (i * vPoleCount + j) * 3;
                poleArray.SetValue(i + 1, j + 1,
                    gp_Pnt(poles[idx], poles[idx+1], poles[idx+2]));
            }
        }

        TColStd_Array1OfReal uKnotArr(1, uKnotCount);
        for (int32_t i = 0; i < uKnotCount; i++) uKnotArr.SetValue(i + 1, uKnots[i]);
        TColStd_Array1OfReal vKnotArr(1, vKnotCount);
        for (int32_t i = 0; i < vKnotCount; i++) vKnotArr.SetValue(i + 1, vKnots[i]);

        TColStd_Array1OfInteger uMultArr(1, uKnotCount);
        for (int32_t i = 0; i < uKnotCount; i++) uMultArr.SetValue(i + 1, uMults[i]);
        TColStd_Array1OfInteger vMultArr(1, vKnotCount);
        for (int32_t i = 0; i < vKnotCount; i++) vMultArr.SetValue(i + 1, vMults[i]);

        Handle(Geom_BSplineSurface) bsp;
        if (weights) {
            TColStd_Array2OfReal wArr(1, uPoleCount, 1, vPoleCount);
            for (int32_t i = 0; i < uPoleCount; i++) {
                for (int32_t j = 0; j < vPoleCount; j++) {
                    wArr.SetValue(i + 1, j + 1, weights[i * vPoleCount + j]);
                }
            }
            bsp = new Geom_BSplineSurface(poleArray, wArr,
                uKnotArr, vKnotArr, uMultArr, vMultArr, uDegree, vDegree);
        } else {
            bsp = new Geom_BSplineSurface(poleArray,
                uKnotArr, vKnotArr, uMultArr, vMultArr, uDegree, vDegree);
        }
        return new OCCTSurface(bsp);
    } catch (...) {
        return nullptr;
    }
}

// Operations

OCCTSurfaceRef OCCTSurfaceTrim(OCCTSurfaceRef s,
                                double u1, double u2, double v1, double v2) {
    if (!s || s->surface.IsNull()) return nullptr;
    try {
        Handle(Geom_RectangularTrimmedSurface) trimmed =
            new Geom_RectangularTrimmedSurface(s->surface, u1, u2, v1, v2);
        return new OCCTSurface(trimmed);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceOffset(OCCTSurfaceRef s, double distance) {
    if (!s || s->surface.IsNull()) return nullptr;
    try {
        Handle(Geom_OffsetSurface) offset =
            new Geom_OffsetSurface(s->surface, distance);
        return new OCCTSurface(offset);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceTranslate(OCCTSurfaceRef s,
                                     double dx, double dy, double dz) {
    if (!s || s->surface.IsNull()) return nullptr;
    try {
        Handle(Geom_Surface) copy = Handle(Geom_Surface)::DownCast(s->surface->Copy());
        gp_Trsf trsf;
        trsf.SetTranslation(gp_Vec(dx, dy, dz));
        copy->Transform(trsf);
        return new OCCTSurface(copy);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceRotate(OCCTSurfaceRef s,
                                  double axOx, double axOy, double axOz,
                                  double axDx, double axDy, double axDz,
                                  double angle) {
    if (!s || s->surface.IsNull()) return nullptr;
    try {
        Handle(Geom_Surface) copy = Handle(Geom_Surface)::DownCast(s->surface->Copy());
        gp_Trsf trsf;
        trsf.SetRotation(gp_Ax1(gp_Pnt(axOx, axOy, axOz), gp_Dir(axDx, axDy, axDz)), angle);
        copy->Transform(trsf);
        return new OCCTSurface(copy);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceScale(OCCTSurfaceRef s,
                                 double cx, double cy, double cz, double factor) {
    if (!s || s->surface.IsNull()) return nullptr;
    try {
        Handle(Geom_Surface) copy = Handle(Geom_Surface)::DownCast(s->surface->Copy());
        gp_Trsf trsf;
        trsf.SetScale(gp_Pnt(cx, cy, cz), factor);
        copy->Transform(trsf);
        return new OCCTSurface(copy);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceMirrorPlane(OCCTSurfaceRef s,
                                       double px, double py, double pz,
                                       double nx, double ny, double nz) {
    if (!s || s->surface.IsNull()) return nullptr;
    try {
        Handle(Geom_Surface) copy = Handle(Geom_Surface)::DownCast(s->surface->Copy());
        gp_Trsf trsf;
        trsf.SetMirror(gp_Ax2(gp_Pnt(px, py, pz), gp_Dir(nx, ny, nz)));
        copy->Transform(trsf);
        return new OCCTSurface(copy);
    } catch (...) {
        return nullptr;
    }
}

// Conversion

OCCTSurfaceRef OCCTSurfaceToBSpline(OCCTSurfaceRef s) {
    if (!s || s->surface.IsNull()) return nullptr;
    try {
        Handle(Geom_BSplineSurface) bsp = GeomConvert::SurfaceToBSplineSurface(s->surface);
        if (bsp.IsNull()) return nullptr;
        return new OCCTSurface(bsp);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceApproximate(OCCTSurfaceRef s, double tolerance,
                                       int32_t continuity, int32_t maxSegments,
                                       int32_t maxDegree) {
    if (!s || s->surface.IsNull()) return nullptr;
    try {
        GeomAbs_Shape cont = GeomAbs_C2;
        switch (continuity) {
            case 0: cont = GeomAbs_C0; break;
            case 1: cont = GeomAbs_C1; break;
            case 2: cont = GeomAbs_C2; break;
            case 3: cont = GeomAbs_C3; break;
        }
        GeomConvert_ApproxSurface approx(s->surface, tolerance,
                                          cont, cont, maxDegree, maxDegree, maxSegments, 0);
        if (!approx.HasResult()) return nullptr;
        return new OCCTSurface(approx.Surface());
    } catch (...) {
        return nullptr;
    }
}

// Iso Curves

OCCTCurve3DRef OCCTSurfaceUIso(OCCTSurfaceRef s, double u) {
    if (!s || s->surface.IsNull()) return nullptr;
    try {
        Handle(Geom_Curve) iso = s->surface->UIso(u);
        if (iso.IsNull()) return nullptr;
        return new OCCTCurve3D(iso);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTSurfaceVIso(OCCTSurfaceRef s, double v) {
    if (!s || s->surface.IsNull()) return nullptr;
    try {
        Handle(Geom_Curve) iso = s->surface->VIso(v);
        if (iso.IsNull()) return nullptr;
        return new OCCTCurve3D(iso);
    } catch (...) {
        return nullptr;
    }
}

// Pipe Surface

OCCTSurfaceRef OCCTSurfaceCreatePipe(OCCTCurve3DRef path, double radius) {
    if (!path || path->curve.IsNull() || radius <= 0) return nullptr;
    try {
        GeomFill_Pipe pipe(path->curve, radius);
        pipe.Perform(Standard_True, Standard_False);
        Handle(Geom_Surface) result = pipe.Surface();
        if (result.IsNull()) return nullptr;
        return new OCCTSurface(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceCreatePipeWithSection(OCCTCurve3DRef path,
                                                 OCCTCurve3DRef section) {
    if (!path || path->curve.IsNull() || !section || section->curve.IsNull())
        return nullptr;
    try {
        GeomFill_Pipe pipe(path->curve, section->curve);
        pipe.Perform(Standard_True, Standard_False);
        Handle(Geom_Surface) result = pipe.Surface();
        if (result.IsNull()) return nullptr;
        return new OCCTSurface(result);
    } catch (...) {
        return nullptr;
    }
}

// Draw Methods

int32_t OCCTSurfaceDrawGrid(OCCTSurfaceRef s,
                             int32_t uCount, int32_t vCount,
                             int32_t pointsPerLine,
                             double* outXYZ, int32_t maxPoints,
                             int32_t* outLineLengths, int32_t maxLines) {
    if (!s || s->surface.IsNull() || !outXYZ || !outLineLengths ||
        maxPoints <= 0 || maxLines <= 0) return 0;
    try {
        double uMin, uMax, vMin, vMax;
        s->surface->Bounds(uMin, uMax, vMin, vMax);

        // Clamp infinite bounds
        if (uMin < -1e6) uMin = -100;
        if (uMax >  1e6) uMax = 100;
        if (vMin < -1e6) vMin = -100;
        if (vMax >  1e6) vMax = 100;

        int32_t totalPoints = 0;
        int32_t lineIdx = 0;

        // U-iso lines (constant U, varying V)
        for (int32_t i = 0; i < uCount && lineIdx < maxLines; i++) {
            double u = uMin + (uMax - uMin) * i / (uCount > 1 ? (uCount - 1) : 1);
            int32_t ptsInLine = 0;
            for (int32_t j = 0; j < pointsPerLine && totalPoints < maxPoints; j++) {
                double v = vMin + (vMax - vMin) * j / (pointsPerLine > 1 ? (pointsPerLine - 1) : 1);
                gp_Pnt p;
                s->surface->D0(u, v, p);
                outXYZ[totalPoints * 3]     = p.X();
                outXYZ[totalPoints * 3 + 1] = p.Y();
                outXYZ[totalPoints * 3 + 2] = p.Z();
                totalPoints++;
                ptsInLine++;
            }
            outLineLengths[lineIdx++] = ptsInLine;
        }

        // V-iso lines (constant V, varying U)
        for (int32_t j = 0; j < vCount && lineIdx < maxLines; j++) {
            double v = vMin + (vMax - vMin) * j / (vCount > 1 ? (vCount - 1) : 1);
            int32_t ptsInLine = 0;
            for (int32_t i = 0; i < pointsPerLine && totalPoints < maxPoints; i++) {
                double u = uMin + (uMax - uMin) * i / (pointsPerLine > 1 ? (pointsPerLine - 1) : 1);
                gp_Pnt p;
                s->surface->D0(u, v, p);
                outXYZ[totalPoints * 3]     = p.X();
                outXYZ[totalPoints * 3 + 1] = p.Y();
                outXYZ[totalPoints * 3 + 2] = p.Z();
                totalPoints++;
                ptsInLine++;
            }
            outLineLengths[lineIdx++] = ptsInLine;
        }

        return totalPoints;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTSurfaceDrawMesh(OCCTSurfaceRef s,
                             int32_t uCount, int32_t vCount,
                             double* outXYZ) {
    if (!s || s->surface.IsNull() || !outXYZ || uCount < 2 || vCount < 2) return 0;
    try {
        double uMin, uMax, vMin, vMax;
        s->surface->Bounds(uMin, uMax, vMin, vMax);

        // Clamp infinite bounds
        if (uMin < -1e6) uMin = -100;
        if (uMax >  1e6) uMax = 100;
        if (vMin < -1e6) vMin = -100;
        if (vMax >  1e6) vMax = 100;

        int32_t idx = 0;
        for (int32_t i = 0; i < uCount; i++) {
            double u = uMin + (uMax - uMin) * i / (uCount - 1);
            for (int32_t j = 0; j < vCount; j++) {
                double v = vMin + (vMax - vMin) * j / (vCount - 1);
                gp_Pnt p;
                s->surface->D0(u, v, p);
                outXYZ[idx * 3]     = p.X();
                outXYZ[idx * 3 + 1] = p.Y();
                outXYZ[idx * 3 + 2] = p.Z();
                idx++;
            }
        }
        return idx;
    } catch (...) {
        return 0;
    }
}

// Local Properties

double OCCTSurfaceGetGaussianCurvature(OCCTSurfaceRef s, double u, double v) {
    if (!s || s->surface.IsNull()) return 0.0;
    try {
        GeomLProp_SLProps props(s->surface, u, v, 2, Precision::Confusion());
        if (!props.IsCurvatureDefined()) return 0.0;
        return props.GaussianCurvature();
    } catch (...) {
        return 0.0;
    }
}

double OCCTSurfaceGetMeanCurvature(OCCTSurfaceRef s, double u, double v) {
    if (!s || s->surface.IsNull()) return 0.0;
    try {
        GeomLProp_SLProps props(s->surface, u, v, 2, Precision::Confusion());
        if (!props.IsCurvatureDefined()) return 0.0;
        return props.MeanCurvature();
    } catch (...) {
        return 0.0;
    }
}

bool OCCTSurfaceGetPrincipalCurvatures(OCCTSurfaceRef s, double u, double v,
                                        double* kMin, double* kMax,
                                        double* d1x, double* d1y, double* d1z,
                                        double* d2x, double* d2y, double* d2z) {
    if (!s || s->surface.IsNull() || !kMin || !kMax ||
        !d1x || !d1y || !d1z || !d2x || !d2y || !d2z) return false;
    try {
        GeomLProp_SLProps props(s->surface, u, v, 2, Precision::Confusion());
        if (!props.IsCurvatureDefined()) return false;
        *kMin = props.MinCurvature();
        *kMax = props.MaxCurvature();
        gp_Dir dir1, dir2;
        props.CurvatureDirections(dir1, dir2);
        *d1x = dir1.X(); *d1y = dir1.Y(); *d1z = dir1.Z();
        *d2x = dir2.X(); *d2y = dir2.Y(); *d2z = dir2.Z();
        return true;
    } catch (...) {
        return false;
    }
}

// Bounding Box

bool OCCTSurfaceGetBoundingBox(OCCTSurfaceRef s,
                                double* xMin, double* yMin, double* zMin,
                                double* xMax, double* yMax, double* zMax) {
    if (!s || s->surface.IsNull() || !xMin || !yMin || !zMin || !xMax || !yMax || !zMax)
        return false;
    try {
        GeomAdaptor_Surface adaptor(s->surface);
        Bnd_Box box;
        BndLib_AddSurface::Add(adaptor, 0.01, box);
        if (box.IsVoid()) return false;
        box.Get(*xMin, *yMin, *zMin, *xMax, *yMax, *zMax);
        return true;
    } catch (...) {
        return false;
    }
}

// BSpline Queries

int32_t OCCTSurfaceGetUPoleCount(OCCTSurfaceRef s) {
    if (!s || s->surface.IsNull()) return 0;
    Handle(Geom_BSplineSurface) bsp = Handle(Geom_BSplineSurface)::DownCast(s->surface);
    if (bsp.IsNull()) {
        Handle(Geom_BezierSurface) bez = Handle(Geom_BezierSurface)::DownCast(s->surface);
        if (!bez.IsNull()) return bez->NbUPoles();
        return 0;
    }
    return bsp->NbUPoles();
}

int32_t OCCTSurfaceGetVPoleCount(OCCTSurfaceRef s) {
    if (!s || s->surface.IsNull()) return 0;
    Handle(Geom_BSplineSurface) bsp = Handle(Geom_BSplineSurface)::DownCast(s->surface);
    if (bsp.IsNull()) {
        Handle(Geom_BezierSurface) bez = Handle(Geom_BezierSurface)::DownCast(s->surface);
        if (!bez.IsNull()) return bez->NbVPoles();
        return 0;
    }
    return bsp->NbVPoles();
}

int32_t OCCTSurfaceGetPoles(OCCTSurfaceRef s, double* outXYZ) {
    if (!s || s->surface.IsNull() || !outXYZ) return 0;
    try {
        Handle(Geom_BSplineSurface) bsp = Handle(Geom_BSplineSurface)::DownCast(s->surface);
        Handle(Geom_BezierSurface) bez = Handle(Geom_BezierSurface)::DownCast(s->surface);

        int uCount = 0, vCount = 0;
        if (!bsp.IsNull()) {
            uCount = bsp->NbUPoles();
            vCount = bsp->NbVPoles();
            int idx = 0;
            for (int i = 1; i <= uCount; i++) {
                for (int j = 1; j <= vCount; j++) {
                    gp_Pnt p = bsp->Pole(i, j);
                    outXYZ[idx*3]     = p.X();
                    outXYZ[idx*3 + 1] = p.Y();
                    outXYZ[idx*3 + 2] = p.Z();
                    idx++;
                }
            }
            return idx;
        } else if (!bez.IsNull()) {
            uCount = bez->NbUPoles();
            vCount = bez->NbVPoles();
            int idx = 0;
            for (int i = 1; i <= uCount; i++) {
                for (int j = 1; j <= vCount; j++) {
                    gp_Pnt p = bez->Pole(i, j);
                    outXYZ[idx*3]     = p.X();
                    outXYZ[idx*3 + 1] = p.Y();
                    outXYZ[idx*3 + 2] = p.Z();
                    idx++;
                }
            }
            return idx;
        }
        return 0;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTSurfaceGetUDegree(OCCTSurfaceRef s) {
    if (!s || s->surface.IsNull()) return 0;
    Handle(Geom_BSplineSurface) bsp = Handle(Geom_BSplineSurface)::DownCast(s->surface);
    if (bsp.IsNull()) {
        Handle(Geom_BezierSurface) bez = Handle(Geom_BezierSurface)::DownCast(s->surface);
        if (!bez.IsNull()) return bez->UDegree();
        return 0;
    }
    return bsp->UDegree();
}

int32_t OCCTSurfaceGetVDegree(OCCTSurfaceRef s) {
    if (!s || s->surface.IsNull()) return 0;
    Handle(Geom_BSplineSurface) bsp = Handle(Geom_BSplineSurface)::DownCast(s->surface);
    if (bsp.IsNull()) {
        Handle(Geom_BezierSurface) bez = Handle(Geom_BezierSurface)::DownCast(s->surface);
        if (!bez.IsNull()) return bez->VDegree();
        return 0;
    }
    return bsp->VDegree();
}

// MARK: - Batch Surface Evaluation (v0.29.0)

#include <GeomGridEval_Surface.hxx>

int32_t OCCTSurfaceEvaluateGrid(OCCTSurfaceRef surface,
                                 const double* uParams, int32_t uCount,
                                 const double* vParams, int32_t vCount,
                                 double* outXYZ) {
    if (!surface || surface->surface.IsNull() || !uParams || !vParams || !outXYZ
        || uCount <= 0 || vCount <= 0) return 0;
    try {
        GeomGridEval_Surface evaluator(surface->surface);

        NCollection_Array1<double> uArr(1, uCount);
        for (int32_t i = 0; i < uCount; i++) {
            uArr.SetValue(i + 1, uParams[i]);
        }
        NCollection_Array1<double> vArr(1, vCount);
        for (int32_t i = 0; i < vCount; i++) {
            vArr.SetValue(i + 1, vParams[i]);
        }

        NCollection_Array2<gp_Pnt> results = evaluator.EvaluateGrid(uArr, vArr);
        int32_t total = uCount * vCount;
        int32_t idx = 0;
        // Row-major: v (rows) varies slowest, u (cols) varies fastest
        for (int32_t iv = 1; iv <= vCount; iv++) {
            for (int32_t iu = 1; iu <= uCount; iu++) {
                const gp_Pnt& pt = results.Value(iu, iv);
                outXYZ[idx*3]   = pt.X();
                outXYZ[idx*3+1] = pt.Y();
                outXYZ[idx*3+2] = pt.Z();
                idx++;
            }
        }
        return total;
    } catch (...) {
        return 0;
    }
}

// MARK: - Curve-Surface Intersection (v0.30.0)

#include <GeomAPI_IntCS.hxx>

int32_t OCCTCurve3DIntersectSurface(OCCTCurve3DRef curve, OCCTSurfaceRef surface,
                                     OCCTCurveSurfaceIntersection* outHits, int32_t maxHits) {
    if (!curve || curve->curve.IsNull() || !surface || surface->surface.IsNull() || !outHits || maxHits <= 0) return 0;
    try {
        GeomAPI_IntCS inter(curve->curve, surface->surface);
        if (!inter.IsDone()) return 0;
        int32_t nb = inter.NbPoints();
        int32_t count = (nb < maxHits) ? nb : maxHits;
        for (int32_t i = 0; i < count; i++) {
            gp_Pnt pt = inter.Point(i + 1);
            double w, u, v;
            inter.Parameters(i + 1, u, v, w);
            outHits[i].point[0] = pt.X();
            outHits[i].point[1] = pt.Y();
            outHits[i].point[2] = pt.Z();
            outHits[i].paramCurve = w;
            outHits[i].paramU = u;
            outHits[i].paramV = v;
        }
        return count;
    } catch (...) {
        return 0;
    }
}

// MARK: - Surface-Surface Intersection (v0.30.0)

#include <GeomAPI_IntSS.hxx>

int32_t OCCTSurfaceIntersect(OCCTSurfaceRef s1, OCCTSurfaceRef s2, double tolerance,
                              OCCTCurve3DRef* outCurves, int32_t maxCurves) {
    if (!s1 || s1->surface.IsNull() || !s2 || s2->surface.IsNull() || !outCurves || maxCurves <= 0) return 0;
    try {
        GeomAPI_IntSS inter(s1->surface, s2->surface, tolerance);
        if (!inter.IsDone()) return 0;
        int32_t nb = inter.NbLines();
        int32_t count = (nb < maxCurves) ? nb : maxCurves;
        for (int32_t i = 0; i < count; i++) {
            Handle(Geom_Curve) c = inter.Line(i + 1);
            if (c.IsNull()) {
                outCurves[i] = nullptr;
            } else {
                outCurves[i] = new OCCTCurve3D(c);
            }
        }
        return count;
    } catch (...) {
        return 0;
    }
}

// MARK: - Curve-Surface Distance (v0.30.0)

#include <GeomAPI_ExtremaCurveSurface.hxx>

double OCCTCurve3DDistanceToSurface(OCCTCurve3DRef curve, OCCTSurfaceRef surface) {
    if (!curve || curve->curve.IsNull() || !surface || surface->surface.IsNull()) return -1.0;
    try {
        GeomAPI_ExtremaCurveSurface extrema(curve->curve, surface->surface);
        if (extrema.NbExtrema() == 0) return -1.0;
        return extrema.LowerDistance();
    } catch (...) {
        return -1.0;
    }
}

// MARK: - Surface to Analytical (v0.30.0)

#include <GeomConvert_SurfToAnaSurf.hxx>

OCCTSurfaceRef OCCTSurfaceToAnalytical(OCCTSurfaceRef surface, double tolerance) {
    if (!surface || surface->surface.IsNull()) return nullptr;
    try {
        GeomConvert_SurfToAnaSurf converter(surface->surface);
        Handle(Geom_Surface) result = converter.ConvertToAnalytical(tolerance);
        if (result.IsNull()) return nullptr;
        // If the result is the same handle, it was already analytical or couldn't convert
        if (result == surface->surface) return nullptr;
        return new OCCTSurface(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Canonical Recognition (v0.30.0)

#include <ShapeAnalysis_CanonicalRecognition.hxx>
#include <gp_Elips.hxx>

OCCTCanonicalForm OCCTShapeRecognizeCanonical(OCCTShapeRef shape, double tolerance) {
    OCCTCanonicalForm result = {};
    if (!shape) return result;
    try {
        ShapeAnalysis_CanonicalRecognition recog(shape->shape);
        gp_Pln pln;
        if (recog.IsPlane(tolerance, pln)) {
            result.type = 1;
            result.origin[0] = pln.Location().X();
            result.origin[1] = pln.Location().Y();
            result.origin[2] = pln.Location().Z();
            result.direction[0] = pln.Axis().Direction().X();
            result.direction[1] = pln.Axis().Direction().Y();
            result.direction[2] = pln.Axis().Direction().Z();
            result.gap = recog.GetGap();
            return result;
        }
        gp_Cylinder cyl;
        if (recog.IsCylinder(tolerance, cyl)) {
            result.type = 2;
            result.origin[0] = cyl.Location().X();
            result.origin[1] = cyl.Location().Y();
            result.origin[2] = cyl.Location().Z();
            result.direction[0] = cyl.Axis().Direction().X();
            result.direction[1] = cyl.Axis().Direction().Y();
            result.direction[2] = cyl.Axis().Direction().Z();
            result.radius = cyl.Radius();
            result.gap = recog.GetGap();
            return result;
        }
        gp_Cone cone;
        if (recog.IsCone(tolerance, cone)) {
            result.type = 3;
            result.origin[0] = cone.Location().X();
            result.origin[1] = cone.Location().Y();
            result.origin[2] = cone.Location().Z();
            result.direction[0] = cone.Axis().Direction().X();
            result.direction[1] = cone.Axis().Direction().Y();
            result.direction[2] = cone.Axis().Direction().Z();
            result.radius = cone.RefRadius();
            result.radius2 = cone.SemiAngle();
            result.gap = recog.GetGap();
            return result;
        }
        gp_Sphere sph;
        if (recog.IsSphere(tolerance, sph)) {
            result.type = 4;
            result.origin[0] = sph.Location().X();
            result.origin[1] = sph.Location().Y();
            result.origin[2] = sph.Location().Z();
            result.direction[0] = sph.Position().Direction().X();
            result.direction[1] = sph.Position().Direction().Y();
            result.direction[2] = sph.Position().Direction().Z();
            result.radius = sph.Radius();
            result.gap = recog.GetGap();
            return result;
        }
        gp_Lin lin;
        if (recog.IsLine(tolerance, lin)) {
            result.type = 5;
            result.origin[0] = lin.Location().X();
            result.origin[1] = lin.Location().Y();
            result.origin[2] = lin.Location().Z();
            result.direction[0] = lin.Direction().X();
            result.direction[1] = lin.Direction().Y();
            result.direction[2] = lin.Direction().Z();
            result.gap = recog.GetGap();
            return result;
        }
        gp_Circ circ;
        if (recog.IsCircle(tolerance, circ)) {
            result.type = 6;
            result.origin[0] = circ.Location().X();
            result.origin[1] = circ.Location().Y();
            result.origin[2] = circ.Location().Z();
            result.direction[0] = circ.Axis().Direction().X();
            result.direction[1] = circ.Axis().Direction().Y();
            result.direction[2] = circ.Axis().Direction().Z();
            result.radius = circ.Radius();
            result.gap = recog.GetGap();
            return result;
        }
        gp_Elips elips;
        if (recog.IsEllipse(tolerance, elips)) {
            result.type = 7;
            result.origin[0] = elips.Location().X();
            result.origin[1] = elips.Location().Y();
            result.origin[2] = elips.Location().Z();
            result.direction[0] = elips.Axis().Direction().X();
            result.direction[1] = elips.Axis().Direction().Y();
            result.direction[2] = elips.Axis().Direction().Z();
            result.radius = elips.MajorRadius();
            result.radius2 = elips.MinorRadius();
            result.gap = recog.GetGap();
            return result;
        }
        return result;
    } catch (...) {
        return result;
    }
}

// MARK: - Bezier Surface Fill (v0.31.0)

#include <GeomFill_BezierCurves.hxx>
#include <GeomFill_FillingStyle.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom_BezierSurface.hxx>

OCCTSurfaceRef OCCTSurfaceBezierFill4(OCCTCurve3DRef c1, OCCTCurve3DRef c2,
                                        OCCTCurve3DRef c3, OCCTCurve3DRef c4,
                                        int32_t fillStyle) {
    if (!c1 || c1->curve.IsNull() ||
        !c2 || c2->curve.IsNull() ||
        !c3 || c3->curve.IsNull() ||
        !c4 || c4->curve.IsNull()) return nullptr;
    try {
        Handle(Geom_BezierCurve) bc1 = Handle(Geom_BezierCurve)::DownCast(c1->curve);
        Handle(Geom_BezierCurve) bc2 = Handle(Geom_BezierCurve)::DownCast(c2->curve);
        Handle(Geom_BezierCurve) bc3 = Handle(Geom_BezierCurve)::DownCast(c3->curve);
        Handle(Geom_BezierCurve) bc4 = Handle(Geom_BezierCurve)::DownCast(c4->curve);
        if (bc1.IsNull() || bc2.IsNull() || bc3.IsNull() || bc4.IsNull()) return nullptr;
        GeomFill_FillingStyle style = GeomFill_StretchStyle;
        if (fillStyle == 1) style = GeomFill_CoonsStyle;
        else if (fillStyle == 2) style = GeomFill_CurvedStyle;
        GeomFill_BezierCurves filler(bc1, bc2, bc3, bc4, style);
        Handle(Geom_BezierSurface) surf = filler.Surface();
        if (surf.IsNull()) return nullptr;
        return new OCCTSurface(surf);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceBezierFill2(OCCTCurve3DRef c1, OCCTCurve3DRef c2,
                                        int32_t fillStyle) {
    if (!c1 || c1->curve.IsNull() ||
        !c2 || c2->curve.IsNull()) return nullptr;
    try {
        Handle(Geom_BezierCurve) bc1 = Handle(Geom_BezierCurve)::DownCast(c1->curve);
        Handle(Geom_BezierCurve) bc2 = Handle(Geom_BezierCurve)::DownCast(c2->curve);
        if (bc1.IsNull() || bc2.IsNull()) return nullptr;
        GeomFill_FillingStyle style = GeomFill_StretchStyle;
        if (fillStyle == 1) style = GeomFill_CoonsStyle;
        else if (fillStyle == 2) style = GeomFill_CurvedStyle;
        GeomFill_BezierCurves filler(bc1, bc2, style);
        Handle(Geom_BezierSurface) surf = filler.Surface();
        if (surf.IsNull()) return nullptr;
        return new OCCTSurface(surf);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Surface-Surface Intersection (v0.35.0)

#include <GeomAPI_IntSS.hxx>

int32_t OCCTSurfaceSurfaceIntersect(OCCTSurfaceRef surface1, OCCTSurfaceRef surface2,
                                     double tolerance,
                                     OCCTCurve3DRef* outCurves, int32_t maxCurves) {
    if (!surface1 || !surface2 || !outCurves || maxCurves < 1) return 0;
    if (surface1->surface.IsNull() || surface2->surface.IsNull()) return 0;
    try {
        GeomAPI_IntSS intersector(surface1->surface, surface2->surface, tolerance);
        if (!intersector.IsDone()) return 0;
        int32_t nbLines = intersector.NbLines();
        int32_t count = std::min(nbLines, maxCurves);
        for (int32_t i = 0; i < count; ++i) {
            Handle(Geom_Curve) curve = intersector.Line(i + 1); // 1-based
            if (curve.IsNull()) {
                outCurves[i] = nullptr;
            } else {
                outCurves[i] = new OCCTCurve3D(curve);
            }
        }
        return count;
    } catch (...) {
        return 0;
    }
}

// MARK: - Curve-Surface Intersection (v0.35.0)

#include <GeomAPI_IntCS.hxx>

int32_t OCCTCurveSurfaceIntersect(OCCTCurve3DRef curve, OCCTSurfaceRef surface,
                                   OCCTCurveSurfacePoint* outPoints, int32_t maxPoints) {
    if (!curve || !surface || !outPoints || maxPoints < 1) return 0;
    if (curve->curve.IsNull() || surface->surface.IsNull()) return 0;
    try {
        GeomAPI_IntCS intersector(curve->curve, surface->surface);
        if (!intersector.IsDone()) return 0;
        int32_t nbPoints = intersector.NbPoints();
        int32_t count = std::min(nbPoints, maxPoints);
        for (int32_t i = 0; i < count; ++i) {
            gp_Pnt pt = intersector.Point(i + 1);
            double u, v, w;
            intersector.Parameters(i + 1, u, v, w);
            outPoints[i].x = pt.X();
            outPoints[i].y = pt.Y();
            outPoints[i].z = pt.Z();
            outPoints[i].u = u;
            outPoints[i].v = v;
            outPoints[i].w = w;
        }
        return count;
    } catch (...) {
        return 0;
    }
}

// MARK: - Surface to Bezier Patches (v0.36.0)

#include <GeomConvert_BSplineSurfaceToBezierSurface.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_BezierSurface.hxx>

int32_t OCCTSurfaceToBezierPatches(OCCTSurfaceRef surface,
                                    OCCTSurfaceRef* outPatches, int32_t maxPatches) {
    if (!surface || !outPatches || maxPatches < 1) return 0;
    if (surface->surface.IsNull()) return 0;
    try {
        // First convert to BSpline if needed
        Handle(Geom_BSplineSurface) bspline = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
        if (bspline.IsNull()) {
            // Try approximate conversion
            Handle(Geom_Surface) surf = surface->surface;
            // Use ShapeConstruct to convert
            bspline = GeomConvert::SurfaceToBSplineSurface(surf);
            if (bspline.IsNull()) return 0;
        }
        GeomConvert_BSplineSurfaceToBezierSurface converter(bspline);
        int32_t nbU = converter.NbUPatches();
        int32_t nbV = converter.NbVPatches();
        int32_t total = nbU * nbV;
        int32_t count = std::min(total, maxPatches);
        int32_t idx = 0;
        for (int32_t i = 1; i <= nbU && idx < count; ++i) {
            for (int32_t j = 1; j <= nbV && idx < count; ++j) {
                Handle(Geom_BezierSurface) patch = converter.Patch(i, j);
                if (!patch.IsNull()) {
                    outPatches[idx] = new OCCTSurface(patch);
                    idx++;
                } else {
                    outPatches[idx] = nullptr;
                    idx++;
                }
            }
        }
        return idx;
    } catch (...) {
        return 0;
    }
}

// MARK: - Surface Singularity Analysis (v0.37.0)

#include <ShapeAnalysis_Surface.hxx>

int32_t OCCTSurfaceSingularityCount(OCCTSurfaceRef surface, double tolerance) {
    if (!surface || surface->surface.IsNull()) return 0;
    try {
        ShapeAnalysis_Surface analyzer(surface->surface);
        return analyzer.NbSingularities(tolerance);
    } catch (...) {
        return 0;
    }
}

bool OCCTSurfaceIsDegenerated(OCCTSurfaceRef surface, double x, double y, double z, double tolerance) {
    if (!surface || surface->surface.IsNull()) return false;
    try {
        ShapeAnalysis_Surface analyzer(surface->surface);
        gp_Pnt point(x, y, z);
        return analyzer.IsDegenerated(point, tolerance);
    } catch (...) {
        return false;
    }
}


static Handle(Geom_BSplineCurve) toBSplineCurve(const Handle(Geom_Curve)& curve) {
    Handle(Geom_BSplineCurve) bsc = Handle(Geom_BSplineCurve)::DownCast(curve);
    if (!bsc.IsNull()) {
        // Re-convert to ensure consistent parameterization
        return GeomConvert::CurveToBSplineCurve(curve, Convert_QuasiAngular);
    }
    // Convert any Geom_Curve to BSpline
    return GeomConvert::CurveToBSplineCurve(curve, Convert_QuasiAngular);
}

OCCTSurfaceRef OCCTSurfaceFillBSpline2Curves(OCCTCurve3DRef curve1, OCCTCurve3DRef curve2,
                                               int32_t fillStyle) {
    if (!curve1 || !curve2) return nullptr;
    try {
        Handle(Geom_BSplineCurve) c1 = toBSplineCurve(curve1->curve);
        Handle(Geom_BSplineCurve) c2 = toBSplineCurve(curve2->curve);
        if (c1.IsNull() || c2.IsNull()) return nullptr;

        GeomFill_FillingStyle style = GeomFill_StretchStyle;
        if (fillStyle == 1) style = GeomFill_CoonsStyle;
        else if (fillStyle == 2) style = GeomFill_CurvedStyle;

        GeomFill_BSplineCurves filler(c1, c2, style);
        Handle(Geom_BSplineSurface) surf = filler.Surface();
        if (surf.IsNull()) return nullptr;
        return new OCCTSurface(surf);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceFillBSpline4Curves(OCCTCurve3DRef c1, OCCTCurve3DRef c2,
                                               OCCTCurve3DRef c3, OCCTCurve3DRef c4,
                                               int32_t fillStyle) {
    if (!c1 || !c2 || !c3 || !c4) return nullptr;
    try {
        Handle(Geom_BSplineCurve) bc1 = toBSplineCurve(c1->curve);
        Handle(Geom_BSplineCurve) bc2 = toBSplineCurve(c2->curve);
        Handle(Geom_BSplineCurve) bc3 = toBSplineCurve(c3->curve);
        Handle(Geom_BSplineCurve) bc4 = toBSplineCurve(c4->curve);
        if (bc1.IsNull() || bc2.IsNull() || bc3.IsNull() || bc4.IsNull()) return nullptr;

        GeomFill_FillingStyle style = GeomFill_StretchStyle;
        if (fillStyle == 1) style = GeomFill_CoonsStyle;
        else if (fillStyle == 2) style = GeomFill_CurvedStyle;

        GeomFill_BSplineCurves filler(bc1, bc2, bc3, bc4, style);
        Handle(Geom_BSplineSurface) surf = filler.Surface();
        if (surf.IsNull()) return nullptr;
        return new OCCTSurface(surf);
    } catch (...) {
        return nullptr;
    }
}
// MARK: - v0.44.0: Surface Extrema, Curve-on-Surface Check, Ellipse Arc, Edge Connect, Bezier Convert

#include <GeomAPI_ExtremaSurfaceSurface.hxx>
#include <BRepLib_CheckCurveOnSurface.hxx>
#include <GC_MakeArcOfEllipse.hxx>
#include <gp_Elips.hxx>
#include <ShapeFix_EdgeConnect.hxx>
#include <ShapeUpgrade_ShapeConvertToBezier.hxx>
// v0.45.0
#include <BRepFill_Filling.hxx>
#include <GeomAbs_Shape.hxx>
#include <BRepExtrema_SelfIntersection.hxx>
#include <BRepGProp_Face.hxx>
#include <ShapeAnalysis_WireOrder.hxx>

int32_t OCCTSurfaceExtrema(OCCTSurfaceRef s1, OCCTSurfaceRef s2,
                            double u1Min, double u1Max, double v1Min, double v1Max,
                            double u2Min, double u2Max, double v2Min, double v2Max,
                            OCCTSurfaceExtremaResult* outResult) {
    if (!s1 || !s2 || !outResult) return 0;
    try {
        GeomAPI_ExtremaSurfaceSurface extrema(
            s1->surface, s2->surface,
            u1Min, u1Max, v1Min, v1Max,
            u2Min, u2Max, v2Min, v2Max);

        int32_t nb = extrema.NbExtrema();
        if (nb <= 0) return 0;

        outResult->distance = extrema.LowerDistance();
        gp_Pnt p1, p2;
        extrema.NearestPoints(p1, p2);
        outResult->p1X = p1.X(); outResult->p1Y = p1.Y(); outResult->p1Z = p1.Z();
        outResult->p2X = p2.X(); outResult->p2Y = p2.Y(); outResult->p2Z = p2.Z();
        extrema.LowerDistanceParameters(outResult->u1, outResult->v1,
                                         outResult->u2, outResult->v2);
        return nb;
    } catch (...) {
        return 0;
    }
}

bool OCCTShapeCheckCurveOnSurface(OCCTShapeRef shape, double* outMaxDist, double* outMaxParam) {
    if (!shape || !outMaxDist || !outMaxParam) return false;
    try {
        double globalMaxDist = 0;
        double globalMaxParam = 0;
        bool anyChecked = false;

        for (TopExp_Explorer fExp(shape->shape, TopAbs_FACE); fExp.More(); fExp.Next()) {
            TopoDS_Face face = TopoDS::Face(fExp.Current());
            for (TopExp_Explorer eExp(face, TopAbs_EDGE); eExp.More(); eExp.Next()) {
                TopoDS_Edge edge = TopoDS::Edge(eExp.Current());
                double f, l;
                Handle(Geom2d_Curve) pcurve = BRep_Tool::CurveOnSurface(edge, face, f, l);
                if (pcurve.IsNull()) continue;

                BRepLib_CheckCurveOnSurface checker(edge, face);
                checker.Perform();
                if (checker.IsDone()) {
                    double dist = checker.MaxDistance();
                    if (dist > globalMaxDist) {
                        globalMaxDist = dist;
                        globalMaxParam = checker.MaxParameter();
                    }
                    anyChecked = true;
                }
            }
        }

        *outMaxDist = globalMaxDist;
        *outMaxParam = globalMaxParam;
        return anyChecked;
    } catch (...) {
        return false;
    }
}

// MARK: - GeomFill_ConstrainedFilling (v0.47)
// --- GeomFill_ConstrainedFilling ---

OCCTShapeRef OCCTGeomFillConstrained(OCCTEdgeRef edge1, OCCTEdgeRef edge2,
                                      OCCTEdgeRef edge3, OCCTEdgeRef edge4,
                                      int32_t maxDeg, int32_t maxSeg) {
    if (!edge1 || !edge2 || !edge3) return nullptr;
    try {
        // Extract curves from edges
        auto getCurve = [](const TopoDS_Edge& edge) -> Handle(Geom_TrimmedCurve) {
            double first, last;
            Handle(Geom_Curve) curve = BRep_Tool::Curve(edge, first, last);
            if (curve.IsNull()) return nullptr;
            return new Geom_TrimmedCurve(curve, first, last);
        };

        Handle(Geom_TrimmedCurve) c1 = getCurve(edge1->edge);
        Handle(Geom_TrimmedCurve) c2 = getCurve(edge2->edge);
        Handle(Geom_TrimmedCurve) c3 = getCurve(edge3->edge);
        if (c1.IsNull() || c2.IsNull() || c3.IsNull()) return nullptr;

        Handle(GeomFill_SimpleBound) b1 = new GeomFill_SimpleBound(
            new GeomAdaptor_Curve(c1), 1e-4, 1e-4);
        Handle(GeomFill_SimpleBound) b2 = new GeomFill_SimpleBound(
            new GeomAdaptor_Curve(c2), 1e-4, 1e-4);
        Handle(GeomFill_SimpleBound) b3 = new GeomFill_SimpleBound(
            new GeomAdaptor_Curve(c3), 1e-4, 1e-4);

        GeomFill_ConstrainedFilling filler(maxDeg, maxSeg);

        if (edge4) {
            Handle(Geom_TrimmedCurve) c4 = getCurve(edge4->edge);
            if (c4.IsNull()) return nullptr;
            Handle(GeomFill_SimpleBound) b4 = new GeomFill_SimpleBound(
                new GeomAdaptor_Curve(c4), 1e-4, 1e-4);
            filler.Init(b1, b2, b3, b4);
        } else {
            filler.Init(b1, b2, b3);
        }

        Handle(Geom_BSplineSurface) surface = filler.Surface();
        if (surface.IsNull()) return nullptr;

        // Build a face from the surface
        BRepBuilderAPI_MakeFace faceMaker(surface, 1e-6);
        if (!faceMaker.IsDone()) return nullptr;
        return new OCCTShape(faceMaker.Shape());
    } catch (...) {
        return nullptr;
    }
}

bool OCCTGeomFillConstrainedInfo(OCCTShapeRef face, OCCTConstrainedFillingInfo* info) {
    if (!face || !info) return false;
    try {
        // Extract the BSpline surface from the face
        for (TopExp_Explorer exp(face->shape, TopAbs_FACE); exp.More(); exp.Next()) {
            TopoDS_Face f = TopoDS::Face(exp.Current());
            Handle(Geom_Surface) surf = BRep_Tool::Surface(f);
            Handle(Geom_BSplineSurface) bspline = Handle(Geom_BSplineSurface)::DownCast(surf);
            if (!bspline.IsNull()) {
                info->isValid = true;
                info->uDegree = bspline->UDegree();
                info->vDegree = bspline->VDegree();
                info->uPoles = bspline->NbUPoles();
                info->vPoles = bspline->NbVPoles();
                return true;
            }
        }
        info->isValid = false;
        return false;
    } catch (...) {
        return false;
    }
}

// MARK: - Surface Value-of-UV / Next-Value-of-UV (v0.49)
// --- ShapeAnalysis_Surface expansion ---

OCCTSurfaceUVResult OCCTSurfaceValueOfUV(OCCTSurfaceRef surface,
    double px, double py, double pz, double precision) {
    OCCTSurfaceUVResult result = {};
    if (!surface) return result;
    try {
        Handle(ShapeAnalysis_Surface) sa = new ShapeAnalysis_Surface(surface->surface);
        gp_Pnt2d uv = sa->ValueOfUV(gp_Pnt(px, py, pz), precision);
        result.u = uv.X();
        result.v = uv.Y();
        result.gap = sa->Gap();
        return result;
    } catch (...) {
        return result;
    }
}

OCCTSurfaceUVResult OCCTSurfaceNextValueOfUV(OCCTSurfaceRef surface,
    double prevU, double prevV, double px, double py, double pz, double precision) {
    OCCTSurfaceUVResult result = {};
    if (!surface) return result;
    try {
        Handle(ShapeAnalysis_Surface) sa = new ShapeAnalysis_Surface(surface->surface);
        gp_Pnt2d uv = sa->NextValueOfUV(gp_Pnt2d(prevU, prevV), gp_Pnt(px, py, pz), precision);
        result.u = uv.X();
        result.v = uv.Y();
        result.gap = sa->Gap();
        return result;
    } catch (...) {
        return result;
    }
}

// MARK: - Surface Makers from Axis/Points/Normal (v0.50)
OCCTSurfaceRef OCCTSurfaceConicalFromAxis(
    double axisX, double axisY, double axisZ,
    double dirX, double dirY, double dirZ,
    double semiAngle, double radius) {
    try {
        gp_Ax2 ax(gp_Pnt(axisX, axisY, axisZ), gp_Dir(dirX, dirY, dirZ));
        GC_MakeConicalSurface maker(ax, semiAngle, radius);
        if (!maker.IsDone()) return nullptr;
        Handle(Geom_ConicalSurface) surf = maker.Value();
        if (surf.IsNull()) return nullptr;
        auto* ref = new OCCTSurface();
        ref->surface = surf;
        return ref;
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceConicalFromPointsRadii(
    double p1x, double p1y, double p1z,
    double p2x, double p2y, double p2z,
    double r1, double r2) {
    try {
        GC_MakeConicalSurface maker(gp_Pnt(p1x, p1y, p1z), gp_Pnt(p2x, p2y, p2z), r1, r2);
        if (!maker.IsDone()) return nullptr;
        Handle(Geom_ConicalSurface) surf = maker.Value();
        if (surf.IsNull()) return nullptr;
        auto* ref = new OCCTSurface();
        ref->surface = surf;
        return ref;
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceCylindricalFromAxis(
    double axisX, double axisY, double axisZ,
    double dirX, double dirY, double dirZ,
    double radius) {
    try {
        gp_Ax2 ax(gp_Pnt(axisX, axisY, axisZ), gp_Dir(dirX, dirY, dirZ));
        GC_MakeCylindricalSurface maker(ax, radius);
        if (!maker.IsDone()) return nullptr;
        Handle(Geom_CylindricalSurface) surf = maker.Value();
        if (surf.IsNull()) return nullptr;
        auto* ref = new OCCTSurface();
        ref->surface = surf;
        return ref;
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceCylindricalFromPoints(
    double p1x, double p1y, double p1z,
    double p2x, double p2y, double p2z,
    double p3x, double p3y, double p3z) {
    try {
        GC_MakeCylindricalSurface maker(
            gp_Pnt(p1x, p1y, p1z), gp_Pnt(p2x, p2y, p2z), gp_Pnt(p3x, p3y, p3z));
        if (!maker.IsDone()) return nullptr;
        Handle(Geom_CylindricalSurface) surf = maker.Value();
        if (surf.IsNull()) return nullptr;
        auto* ref = new OCCTSurface();
        ref->surface = surf;
        return ref;
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfacePlaneFromPoints(
    double p1x, double p1y, double p1z,
    double p2x, double p2y, double p2z,
    double p3x, double p3y, double p3z) {
    try {
        GC_MakePlane maker(gp_Pnt(p1x, p1y, p1z), gp_Pnt(p2x, p2y, p2z), gp_Pnt(p3x, p3y, p3z));
        if (!maker.IsDone()) return nullptr;
        Handle(Geom_Plane) plane = maker.Value();
        if (plane.IsNull()) return nullptr;
        auto* ref = new OCCTSurface();
        ref->surface = plane;
        return ref;
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfacePlaneFromPointNormal(
    double px, double py, double pz,
    double nx, double ny, double nz) {
    try {
        GC_MakePlane maker(gp_Pnt(px, py, pz), gp_Dir(nx, ny, nz));
        if (!maker.IsDone()) return nullptr;
        Handle(Geom_Plane) plane = maker.Value();
        if (plane.IsNull()) return nullptr;
        auto* ref = new OCCTSurface();
        ref->surface = plane;
        return ref;
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceTrimmedCone(
    double p1x, double p1y, double p1z,
    double p2x, double p2y, double p2z,
    double r1, double r2) {
    try {
        GC_MakeTrimmedCone maker(gp_Pnt(p1x, p1y, p1z), gp_Pnt(p2x, p2y, p2z), r1, r2);
        if (!maker.IsDone()) return nullptr;
        Handle(Geom_RectangularTrimmedSurface) surf = maker.Value();
        if (surf.IsNull()) return nullptr;
        auto* ref = new OCCTSurface();
        ref->surface = surf;
        return ref;
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceTrimmedCylinder(
    double axisX, double axisY, double axisZ,
    double dirX, double dirY, double dirZ,
    double radius, double height) {
    try {
        gp_Ax1 ax(gp_Pnt(axisX, axisY, axisZ), gp_Dir(dirX, dirY, dirZ));
        GC_MakeTrimmedCylinder maker(ax, radius, height);
        if (!maker.IsDone()) return nullptr;
        Handle(Geom_RectangularTrimmedSurface) surf = maker.Value();
        if (surf.IsNull()) return nullptr;
        auto* ref = new OCCTSurface();
        ref->surface = surf;
        return ref;
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Surface KnotSplitting / JoinBezierPatches (v0.50)
OCCTSurfaceKnotSplitResult OCCTSurfaceKnotSplitting(OCCTSurfaceRef surface,
    int32_t uContinuity, int32_t vContinuity) {
    OCCTSurfaceKnotSplitResult result = {};
    if (!surface) return result;
    try {
        Handle(Geom_BSplineSurface) bsurf = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
        if (bsurf.IsNull()) return result;
        GeomConvert_BSplineSurfaceKnotSplitting splitter(bsurf, uContinuity, vContinuity);
        result.nbUSplits = splitter.NbUSplits();
        result.nbVSplits = splitter.NbVSplits();
    } catch (...) {}
    return result;
}

OCCTSurfaceRef OCCTSurfaceJoinBezierPatches(
    const OCCTSurfaceRef* patches, int32_t nRows, int32_t nCols) {
    if (!patches || nRows <= 0 || nCols <= 0) return nullptr;
    try {
        TColGeom_Array2OfBezierSurface bezArray(1, nRows, 1, nCols);
        for (int32_t r = 0; r < nRows; r++) {
            for (int32_t c = 0; c < nCols; c++) {
                auto* sref = patches[r * nCols + c];
                if (!sref) return nullptr;
                Handle(Geom_BezierSurface) bez = Handle(Geom_BezierSurface)::DownCast(sref->surface);
                if (bez.IsNull()) return nullptr;
                bezArray.SetValue(r + 1, c + 1, bez);
            }
        }
        GeomConvert_CompBezierSurfacesToBSplineSurface conv(bezArray);
        if (!conv.IsDone()) return nullptr;
        Handle(Geom_BSplineSurface) bsurf = new Geom_BSplineSurface(
            conv.Poles()->Array2(),
            conv.UKnots()->Array1(), conv.VKnots()->Array1(),
            conv.UMultiplicities()->Array1(), conv.VMultiplicities()->Array1(),
            conv.UDegree(), conv.VDegree());
        if (bsurf.IsNull()) return nullptr;
        auto* ref = new OCCTSurface();
        ref->surface = bsurf;
        return ref;
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Surface ConvertToAnalytical (v0.50)
OCCTSurfaceAnalyticalResult OCCTSurfaceConvertToAnalytical(OCCTSurfaceRef surface, double tolerance) {
    OCCTSurfaceAnalyticalResult result = {};
    if (!surface) return result;
    try {
        ShapeCustom_Surface sc(surface->surface);
        Handle(Geom_Surface) recognized = sc.ConvertToAnalytical(tolerance, Standard_False);
        if (!recognized.IsNull()) {
            auto* ref = new OCCTSurface();
            ref->surface = recognized;
            result.surface = ref;
            result.gap = sc.Gap();
        }
    } catch (...) {}
    return result;
}

// MARK: - Surface SplitByContinuity (v0.50)
OCCTSurfaceContinuitySplitResult OCCTSurfaceSplitByContinuity(OCCTSurfaceRef surface,
    int32_t criterion, double tolerance) {
    OCCTSurfaceContinuitySplitResult result = {};
    if (!surface) return result;
    try {
        Handle(Geom_BSplineSurface) bsurf = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
        if (bsurf.IsNull()) return result;

        Handle(ShapeUpgrade_SplitSurfaceContinuity) splitter = new ShapeUpgrade_SplitSurfaceContinuity();
        splitter->Init(bsurf);
        GeomAbs_Shape cont = GeomAbs_C0;
        if (criterion == 1) cont = GeomAbs_C1;
        else if (criterion == 2) cont = GeomAbs_C2;
        else if (criterion >= 3) cont = GeomAbs_C3;
        splitter->SetCriterion(cont);
        splitter->SetTolerance(tolerance);
        splitter->Perform();

        result.isOk = splitter->Status(ShapeExtend_OK);
        result.wasSplit = splitter->Status(ShapeExtend_DONE1);

        const Handle(TColStd_HSequenceOfReal)& uVals = splitter->USplitValues();
        const Handle(TColStd_HSequenceOfReal)& vVals = splitter->VSplitValues();
        result.nUSplits = uVals.IsNull() ? 0 : uVals->Length();
        result.nVSplits = vVals.IsNull() ? 0 : vVals->Length();
    } catch (...) {}
    return result;
}

// MARK: - Contap Contour Analysis (v0.61)
// MARK: - Contap — Contour Analysis (v0.61.0)

int32_t OCCTContapSphereDir(double cx, double cy, double cz, double radius,
    double dirX, double dirY, double dirZ,
    int32_t* outType, double* outData) {
    if (!outType || !outData) return -1;
    try {
        gp_Sphere sphere(gp_Ax3(gp_Pnt(cx, cy, cz), gp_Dir(0, 0, 1)), radius);
        gp_Dir viewDir(dirX, dirY, dirZ);
        Contap_ContAna contAna;
        contAna.Perform(sphere, viewDir);
        if (!contAna.IsDone()) return -1;
        int32_t nb = contAna.NbContours();
        if (nb > 0) {
            GeomAbs_CurveType ctype = contAna.TypeContour();
            if (ctype == GeomAbs_Circle) {
                *outType = 1; // circle
                gp_Circ circ = contAna.Circle();
                gp_Pnt center = circ.Location();
                outData[0] = center.X();
                outData[1] = center.Y();
                outData[2] = center.Z();
                outData[3] = circ.Radius();
            } else if (ctype == GeomAbs_Line) {
                *outType = 0; // line
                gp_Lin line = contAna.Line(1);
                gp_Pnt loc = line.Location();
                gp_Dir dir = line.Direction();
                outData[0] = loc.X(); outData[1] = loc.Y(); outData[2] = loc.Z();
                outData[3] = dir.X(); outData[4] = dir.Y(); outData[5] = dir.Z();
            } else {
                *outType = 2; // walking/other
            }
        }
        return nb;
    } catch (...) { return -1; }
}

int32_t OCCTContapCylinderDir(double px, double py, double pz,
    double axX, double axY, double axZ, double radius,
    double dirX, double dirY, double dirZ,
    int32_t* outType, double* outData) {
    if (!outType || !outData) return -1;
    try {
        gp_Cylinder cyl(gp_Ax3(gp_Pnt(px, py, pz), gp_Dir(axX, axY, axZ)), radius);
        gp_Dir viewDir(dirX, dirY, dirZ);
        Contap_ContAna contAna;
        contAna.Perform(cyl, viewDir);
        if (!contAna.IsDone()) return -1;
        int32_t nb = contAna.NbContours();
        if (nb > 0) {
            GeomAbs_CurveType ctype = contAna.TypeContour();
            if (ctype == GeomAbs_Line) {
                *outType = 0; // line
                // Return first line
                gp_Lin line = contAna.Line(1);
                gp_Pnt loc = line.Location();
                gp_Dir dir = line.Direction();
                outData[0] = loc.X(); outData[1] = loc.Y(); outData[2] = loc.Z();
                outData[3] = dir.X(); outData[4] = dir.Y(); outData[5] = dir.Z();
            } else if (ctype == GeomAbs_Circle) {
                *outType = 1; // circle
                gp_Circ circ = contAna.Circle();
                gp_Pnt center = circ.Location();
                outData[0] = center.X(); outData[1] = center.Y(); outData[2] = center.Z();
                outData[3] = circ.Radius();
            } else {
                *outType = 2;
            }
        }
        return nb;
    } catch (...) { return -1; }
}

int32_t OCCTContapSphereEye(double cx, double cy, double cz, double radius,
    double eyeX, double eyeY, double eyeZ,
    int32_t* outType, double* outData) {
    if (!outType || !outData) return -1;
    try {
        gp_Sphere sphere(gp_Ax3(gp_Pnt(cx, cy, cz), gp_Dir(0, 0, 1)), radius);
        gp_Pnt eye(eyeX, eyeY, eyeZ);
        Contap_ContAna contAna;
        contAna.Perform(sphere, eye);
        if (!contAna.IsDone()) return -1;
        int32_t nb = contAna.NbContours();
        if (nb > 0) {
            GeomAbs_CurveType ctype = contAna.TypeContour();
            if (ctype == GeomAbs_Circle) {
                *outType = 1;
                gp_Circ circ = contAna.Circle();
                gp_Pnt center = circ.Location();
                outData[0] = center.X(); outData[1] = center.Y(); outData[2] = center.Z();
                outData[3] = circ.Radius();
            } else if (ctype == GeomAbs_Line) {
                *outType = 0;
                gp_Lin line = contAna.Line(1);
                gp_Pnt loc = line.Location();
                gp_Dir dir = line.Direction();
                outData[0] = loc.X(); outData[1] = loc.Y(); outData[2] = loc.Z();
                outData[3] = dir.X(); outData[4] = dir.Y(); outData[5] = dir.Z();
            } else {
                *outType = 2;
            }
        }
        return nb;
    } catch (...) { return -1; }
}

// MARK: - GeomInt_IntSS (v0.63)
// --- GeomInt_IntSS ---

struct OCCTGeomIntSS {
    GeomInt_IntSS intss;
    bool valid;
};

OCCTGeomIntSSRef _Nullable OCCTGeomIntSSCreate(OCCTShapeRef face1, OCCTShapeRef face2, double tolerance) {
    if (!face1 || !face2) return nullptr;
    try {
        TopoDS_Face f1 = TopoDS::Face(face1->shape);
        TopoDS_Face f2 = TopoDS::Face(face2->shape);
        Handle(Geom_Surface) s1 = BRep_Tool::Surface(f1);
        Handle(Geom_Surface) s2 = BRep_Tool::Surface(f2);
        if (s1.IsNull() || s2.IsNull()) return nullptr;
        auto* ref = new OCCTGeomIntSS();
        ref->intss.Perform(s1, s2, tolerance, true, false, false);
        ref->valid = ref->intss.IsDone();
        return ref;
    } catch (...) { return nullptr; }
}

int OCCTGeomIntSSLineCount(OCCTGeomIntSSRef ref) {
    if (!ref) return 0;
    auto* r = static_cast<OCCTGeomIntSS*>(ref);
    if (!r->valid) return 0;
    return r->intss.NbLines();
}

OCCTShapeRef _Nullable OCCTGeomIntSSLine(OCCTGeomIntSSRef ref, int index) {
    if (!ref) return nullptr;
    auto* r = static_cast<OCCTGeomIntSS*>(ref);
    if (!r->valid || index < 1 || index > r->intss.NbLines()) return nullptr;
    try {
        Handle(Geom_Curve) curve = r->intss.Line(index);
        if (curve.IsNull()) return nullptr;
        BRepBuilderAPI_MakeEdge me(curve);
        if (!me.IsDone()) return nullptr;
        return new OCCTShape(me.Edge());
    } catch (...) { return nullptr; }
}

int OCCTGeomIntSSPointCount(OCCTGeomIntSSRef ref) {
    if (!ref) return 0;
    auto* r = static_cast<OCCTGeomIntSS*>(ref);
    if (!r->valid) return 0;
    return r->intss.NbPoints();
}

void OCCTGeomIntSSPoint(OCCTGeomIntSSRef ref, int index, double* x, double* y, double* z) {
    if (!ref || !x || !y || !z) return;
    auto* r = static_cast<OCCTGeomIntSS*>(ref);
    if (!r->valid || index < 1 || index > r->intss.NbPoints()) return;
    try {
        gp_Pnt pt = r->intss.Point(index);
        *x = pt.X(); *y = pt.Y(); *z = pt.Z();
    } catch (...) {}
}

void OCCTGeomIntSSRelease(OCCTGeomIntSSRef ref) {
    if (ref) delete static_cast<OCCTGeomIntSS*>(ref);
}

// MARK: - Contap_Contour (v0.63)
// --- Contap_Contour ---

struct OCCTContapContour {
    Contap_Contour contour;
    bool valid;
    bool empty;
};

OCCTContapContourRef _Nullable OCCTContapContourDirection(OCCTShapeRef faceShape,
    double dx, double dy, double dz) {
    if (!faceShape) return nullptr;
    try {
        TopoDS_Face face = TopoDS::Face(faceShape->shape);
        Handle(BRepAdaptor_Surface) surf = new BRepAdaptor_Surface(face);
        Handle(BRepTopAdaptor_TopolTool) tool = new BRepTopAdaptor_TopolTool(surf);
        auto* ref = new OCCTContapContour();
        ref->contour.Init(gp_Vec(dx, dy, dz));
        ref->contour.Perform(surf, tool);
        ref->valid = ref->contour.IsDone();
        ref->empty = ref->contour.IsEmpty();
        return ref;
    } catch (...) { return nullptr; }
}

OCCTContapContourRef _Nullable OCCTContapContourEye(OCCTShapeRef faceShape,
    double ex, double ey, double ez) {
    if (!faceShape) return nullptr;
    try {
        TopoDS_Face face = TopoDS::Face(faceShape->shape);
        Handle(BRepAdaptor_Surface) surf = new BRepAdaptor_Surface(face);
        Handle(BRepTopAdaptor_TopolTool) tool = new BRepTopAdaptor_TopolTool(surf);
        auto* ref = new OCCTContapContour();
        ref->contour.Init(gp_Pnt(ex, ey, ez));
        ref->contour.Perform(surf, tool);
        ref->valid = ref->contour.IsDone();
        ref->empty = ref->contour.IsEmpty();
        return ref;
    } catch (...) { return nullptr; }
}

int OCCTContapContourLineCount(OCCTContapContourRef ref) {
    if (!ref) return 0;
    auto* r = static_cast<OCCTContapContour*>(ref);
    if (!r->valid || r->empty) return 0;
    return r->contour.NbLines();
}

int OCCTContapContourLinePointCount(OCCTContapContourRef ref, int lineIndex) {
    if (!ref) return 0;
    auto* r = static_cast<OCCTContapContour*>(ref);
    if (!r->valid || r->empty) return 0;
    if (lineIndex < 1 || lineIndex > r->contour.NbLines()) return 0;
    try {
        return r->contour.Line(lineIndex).NbPnts();
    } catch (...) { return 0; }
}

void OCCTContapContourLinePoint(OCCTContapContourRef ref, int lineIndex, int pointIndex,
    double* x, double* y, double* z) {
    if (!ref || !x || !y || !z) return;
    auto* r = static_cast<OCCTContapContour*>(ref);
    if (!r->valid || r->empty) return;
    try {
        const Contap_Line& line = r->contour.Line(lineIndex);
        if (pointIndex < 1 || pointIndex > line.NbPnts()) return;
        gp_Pnt pt = line.Point(pointIndex).Value();
        *x = pt.X(); *y = pt.Y(); *z = pt.Z();
    } catch (...) {}
}

int OCCTContapContourLineType(OCCTContapContourRef ref, int lineIndex) {
    if (!ref) return -1;
    auto* r = static_cast<OCCTContapContour*>(ref);
    if (!r->valid || r->empty) return -1;
    if (lineIndex < 1 || lineIndex > r->contour.NbLines()) return -1;
    try {
        Contap_IType t = r->contour.Line(lineIndex).TypeContour();
        return static_cast<int>(t);
    } catch (...) { return -1; }
}

void OCCTContapContourRelease(OCCTContapContourRef ref) {
    if (ref) delete static_cast<OCCTContapContour*>(ref);
}

// MARK: - GeomFill Trihedron Laws + Coons/Curved Filling Poles (v0.63)
// --- GeomFill Trihedron Laws ---

static OCCTTrihedronFrame makeEmptyFrame() {
    return {0,0,0, 0,0,0, 0,0,0};
}

OCCTTrihedronFrame OCCTGeomFillDraftTrihedron(OCCTShapeRef edgeShape, double param,
    double biNormalX, double biNormalY, double biNormalZ, double angle) {
    if (!edgeShape) return makeEmptyFrame();
    try {
        TopoDS_Edge edge = TopoDS::Edge(edgeShape->shape);
        Handle(BRepAdaptor_Curve) adaptor = new BRepAdaptor_Curve(edge);
        GeomFill_DraftTrihedron draft(gp_Vec(biNormalX, biNormalY, biNormalZ), angle);
        draft.SetCurve(adaptor);
        gp_Vec tangent, normal, binormal;
        if (!draft.D0(param, tangent, normal, binormal)) return makeEmptyFrame();
        return {tangent.X(), tangent.Y(), tangent.Z(),
                normal.X(), normal.Y(), normal.Z(),
                binormal.X(), binormal.Y(), binormal.Z()};
    } catch (...) { return makeEmptyFrame(); }
}

OCCTTrihedronFrame OCCTGeomFillDiscreteTrihedron(OCCTShapeRef edgeShape, double param) {
    if (!edgeShape) return makeEmptyFrame();
    try {
        TopoDS_Edge edge = TopoDS::Edge(edgeShape->shape);
        Handle(BRepAdaptor_Curve) adaptor = new BRepAdaptor_Curve(edge);
        GeomFill_DiscreteTrihedron discrete;
        discrete.SetCurve(adaptor);
        gp_Vec tangent, normal, binormal;
        if (!discrete.D0(param, tangent, normal, binormal)) return makeEmptyFrame();
        return {tangent.X(), tangent.Y(), tangent.Z(),
                normal.X(), normal.Y(), normal.Z(),
                binormal.X(), binormal.Y(), binormal.Z()};
    } catch (...) { return makeEmptyFrame(); }
}

OCCTTrihedronFrame OCCTGeomFillCorrectedFrenet(OCCTShapeRef edgeShape, double param) {
    if (!edgeShape) return makeEmptyFrame();
    try {
        TopoDS_Edge edge = TopoDS::Edge(edgeShape->shape);
        Handle(BRepAdaptor_Curve) adaptor = new BRepAdaptor_Curve(edge);
        GeomFill_CorrectedFrenet corrected;
        corrected.SetCurve(adaptor);
        gp_Vec tangent, normal, binormal;
        if (!corrected.D0(param, tangent, normal, binormal)) return makeEmptyFrame();
        return {tangent.X(), tangent.Y(), tangent.Z(),
                normal.X(), normal.Y(), normal.Z(),
                binormal.X(), binormal.Y(), binormal.Z()};
    } catch (...) { return makeEmptyFrame(); }
}

// --- GeomFill_Coons / GeomFill_Curved ---

// Helper: extract poles from GeomFill_Filling into flat array
// Returns actual pole count (nbU * nbV), outPoints must be pre-sized
static int extractFillingPoles(GeomFill_Filling& filling, double* outPoints, int maxPoints) {
    int nbU = filling.NbUPoles();
    int nbV = filling.NbVPoles();
    int total = nbU * nbV;
    if (total > maxPoints) total = maxPoints;
    NCollection_Array2<gp_Pnt> poles(1, nbU, 1, nbV);
    filling.Poles(poles);
    int idx = 0;
    for (int i = 1; i <= nbU && idx < maxPoints; i++) {
        for (int j = 1; j <= nbV && idx < maxPoints; j++) {
            gp_Pnt pt = poles(i, j);
            outPoints[idx*3]     = pt.X();
            outPoints[idx*3 + 1] = pt.Y();
            outPoints[idx*3 + 2] = pt.Z();
            idx++;
        }
    }
    return total;
}

int OCCTGeomFillCoonsPoles(
    const double* b1, const double* b2, const double* b3, const double* b4,
    int pointsPerSide, double* outPoints, int maxPoints,
    int* outNbU, int* outNbV) {
    if (!b1 || !b2 || !b3 || !b4 || !outPoints || pointsPerSide < 2) return 0;
    try {
        NCollection_Array1<gp_Pnt> P1(1, pointsPerSide), P2(1, pointsPerSide),
                                    P3(1, pointsPerSide), P4(1, pointsPerSide);
        for (int i = 0; i < pointsPerSide; i++) {
            P1(i+1) = gp_Pnt(b1[i*3], b1[i*3+1], b1[i*3+2]);
            P2(i+1) = gp_Pnt(b2[i*3], b2[i*3+1], b2[i*3+2]);
            P3(i+1) = gp_Pnt(b3[i*3], b3[i*3+1], b3[i*3+2]);
            P4(i+1) = gp_Pnt(b4[i*3], b4[i*3+1], b4[i*3+2]);
        }
        GeomFill_Coons coons(P1, P2, P3, P4);
        if (outNbU) *outNbU = coons.NbUPoles();
        if (outNbV) *outNbV = coons.NbVPoles();
        return extractFillingPoles(coons, outPoints, maxPoints);
    } catch (...) { return 0; }
}

int OCCTGeomFillCurvedPoles(
    const double* b1, const double* b2, const double* b3, const double* b4,
    int pointsPerSide, double* outPoints, int maxPoints,
    int* outNbU, int* outNbV) {
    if (!b1 || !b2 || !b3 || !b4 || !outPoints || pointsPerSide < 2) return 0;
    try {
        NCollection_Array1<gp_Pnt> P1(1, pointsPerSide), P2(1, pointsPerSide),
                                    P3(1, pointsPerSide), P4(1, pointsPerSide);
        for (int i = 0; i < pointsPerSide; i++) {
            P1(i+1) = gp_Pnt(b1[i*3], b1[i*3+1], b1[i*3+2]);
            P2(i+1) = gp_Pnt(b2[i*3], b2[i*3+1], b2[i*3+2]);
            P3(i+1) = gp_Pnt(b3[i*3], b3[i*3+1], b3[i*3+2]);
            P4(i+1) = gp_Pnt(b4[i*3], b4[i*3+1], b4[i*3+2]);
        }
        GeomFill_Curved curved(P1, P2, P3, P4);
        if (outNbU) *outNbU = curved.NbUPoles();
        if (outNbV) *outNbV = curved.NbVPoles();
        return extractFillingPoles(curved, outPoints, maxPoints);
    } catch (...) { return 0; }
}

// MARK: - GeomFill_CoonsAlgPatch (v0.63)
// --- GeomFill_CoonsAlgPatch ---

void OCCTGeomFillCoonsAlgPatchEval(
    OCCTShapeRef edge1, OCCTShapeRef edge2, OCCTShapeRef edge3, OCCTShapeRef edge4,
    int evalU, int evalV, double* outPoints) {
    if (!edge1 || !edge2 || !edge3 || !edge4 || !outPoints) return;
    try {
        auto makeAdaptor = [](OCCTShapeRef e) -> Handle(GeomAdaptor_Curve) {
            TopoDS_Edge edge = TopoDS::Edge(e->shape);
            double f, l;
            Handle(Geom_Curve) curve = BRep_Tool::Curve(edge, f, l);
            return new GeomAdaptor_Curve(curve, f, l);
        };
        Handle(GeomAdaptor_Curve) ac1 = makeAdaptor(edge1);
        Handle(GeomAdaptor_Curve) ac2 = makeAdaptor(edge2);
        Handle(GeomAdaptor_Curve) ac3 = makeAdaptor(edge3);
        Handle(GeomAdaptor_Curve) ac4 = makeAdaptor(edge4);

        Handle(GeomFill_SimpleBound) b1 = new GeomFill_SimpleBound(ac1, 1e-3, 1e-3);
        Handle(GeomFill_SimpleBound) b2 = new GeomFill_SimpleBound(ac2, 1e-3, 1e-3);
        Handle(GeomFill_SimpleBound) b3 = new GeomFill_SimpleBound(ac3, 1e-3, 1e-3);
        Handle(GeomFill_SimpleBound) b4 = new GeomFill_SimpleBound(ac4, 1e-3, 1e-3);

        GeomFill_CoonsAlgPatch patch(b1, b2, b3, b4);
        for (int i = 0; i < evalU; i++) {
            for (int j = 0; j < evalV; j++) {
                double u = (evalU > 1) ? (double)i / (evalU - 1) : 0.5;
                double v = (evalV > 1) ? (double)j / (evalV - 1) : 0.5;
                gp_Pnt pt = patch.Value(u, v);
                int idx = (i * evalV + j) * 3;
                outPoints[idx]     = pt.X();
                outPoints[idx + 1] = pt.Y();
                outPoints[idx + 2] = pt.Z();
            }
        }
    } catch (...) {}
}

// MARK: - GeomFill_Sweep (v0.63)
// --- GeomFill_Sweep ---

OCCTShapeRef _Nullable OCCTGeomFillSweep(OCCTShapeRef pathEdge, OCCTShapeRef sectionEdge) {
    if (!pathEdge || !sectionEdge) return nullptr;
    try {
        // Path curve
        TopoDS_Edge path = TopoDS::Edge(pathEdge->shape);
        double pf, pl;
        Handle(Geom_Curve) pathCurve = BRep_Tool::Curve(path, pf, pl);
        if (pathCurve.IsNull()) return nullptr;
        Handle(GeomAdaptor_Curve) pathAdaptor = new GeomAdaptor_Curve(pathCurve, pf, pl);

        // Section curve
        TopoDS_Edge section = TopoDS::Edge(sectionEdge->shape);
        double sf, sl;
        Handle(Geom_Curve) sectionCurve = BRep_Tool::Curve(section, sf, sl);
        if (sectionCurve.IsNull()) return nullptr;

        // Trihedron + location
        Handle(GeomFill_CorrectedFrenet) trihedron = new GeomFill_CorrectedFrenet();
        Handle(GeomFill_CurveAndTrihedron) location = new GeomFill_CurveAndTrihedron(trihedron);
        location->SetCurve(pathAdaptor);

        // Section law
        Handle(GeomFill_UniformSection) sectionLaw = new GeomFill_UniformSection(sectionCurve);

        // Sweep
        GeomFill_Sweep sweep(location);
        sweep.Build(sectionLaw, GeomFill_Location, GeomAbs_C2, 10, 50);
        if (!sweep.IsDone()) return nullptr;

        Handle(Geom_Surface) surface = sweep.Surface();
        if (surface.IsNull()) return nullptr;

        BRepBuilderAPI_MakeFace mf(surface, 1e-6);
        if (!mf.IsDone()) return nullptr;
        return new OCCTShape(mf.Face());
    } catch (...) { return nullptr; }
}

// MARK: - GeomFill_EvolvedSection (v0.63)
// --- GeomFill_EvolvedSection ---

OCCTEvolvedSectionInfo OCCTGeomFillEvolvedSectionInfo(OCCTShapeRef edgeShape) {
    OCCTEvolvedSectionInfo result = {0, 0, 0, false};
    if (!edgeShape) return result;
    try {
        TopoDS_Edge edge = TopoDS::Edge(edgeShape->shape);
        double f, l;
        Handle(Geom_Curve) curve = BRep_Tool::Curve(edge, f, l);
        if (curve.IsNull()) return result;

        Handle(Law_Constant) law = new Law_Constant();
        law->Set(1.0, 0.0, 1.0);
        GeomFill_EvolvedSection evolved(curve, law);

        int nbPoles, nbKnots, degree;
        evolved.SectionShape(nbPoles, nbKnots, degree);
        result.nbPoles = nbPoles;
        result.nbKnots = nbKnots;
        result.degree = degree;
        result.isRational = evolved.IsRational();
    } catch (...) {}
    return result;
}

// MARK: - Adaptor3d_IsoCurve (v0.64)
// --- Adaptor3d_IsoCurve ---

void OCCTAdaptor3dIsoCurveEval(OCCTShapeRef faceShape, int isoType, double param,
    int evalCount, double* outPoints) {
    if (!faceShape || !outPoints || evalCount < 1) return;
    try {
        TopoDS_Face face = TopoDS::Face(faceShape->shape);
        Handle(Geom_Surface) surface = BRep_Tool::Surface(face);
        if (surface.IsNull()) return;
        Handle(GeomAdaptor_Surface) surfAdaptor = new GeomAdaptor_Surface(surface);

        GeomAbs_IsoType type = (isoType == 0) ? GeomAbs_IsoU : GeomAbs_IsoV;
        Adaptor3d_IsoCurve iso(surfAdaptor, type, param);

        double first = iso.FirstParameter();
        double last = iso.LastParameter();
        // Clamp infinite parameters
        if (first < -1e6) first = -1e6;
        if (last > 1e6) last = 1e6;

        for (int i = 0; i < evalCount; i++) {
            double t = (evalCount > 1) ? first + (last - first) * i / (evalCount - 1) : first;
            gp_Pnt pt;
            iso.D0(t, pt);
            outPoints[i*3]     = pt.X();
            outPoints[i*3 + 1] = pt.Y();
            outPoints[i*3 + 2] = pt.Z();
        }
    } catch (...) {}
}

OCCTShapeRef _Nullable OCCTAdaptor3dIsoCurveEdge(OCCTShapeRef faceShape, int isoType,
    double param, double p1, double p2) {
    if (!faceShape) return nullptr;
    try {
        TopoDS_Face face = TopoDS::Face(faceShape->shape);
        Handle(Geom_Surface) surface = BRep_Tool::Surface(face);
        if (surface.IsNull()) return nullptr;

        // Create iso-curve as a Geom_Curve
        Handle(Geom_Curve) isoCurve;
        if (isoType == 0) {
            isoCurve = surface->UIso(param);
        } else {
            isoCurve = surface->VIso(param);
        }
        if (isoCurve.IsNull()) return nullptr;

        BRepBuilderAPI_MakeEdge me(isoCurve, p1, p2);
        if (!me.IsDone()) return nullptr;
        return new OCCTShape(me.Edge());
    } catch (...) { return nullptr; }
}

// MARK: - LocalAnalysis_SurfaceContinuity (v0.67)
static GeomAbs_Shape orderToShape(int32_t order) {
    switch (order) {
        case 0: return GeomAbs_C0;
        case 1: return GeomAbs_G1;
        case 2: return GeomAbs_C1;
        case 3: return GeomAbs_G2;
        case 4: return GeomAbs_C2;
        default: return GeomAbs_C2;
    }
}

static int32_t shapeToOrder(GeomAbs_Shape shape) {
    switch (shape) {
        case GeomAbs_C0: return 0;
        case GeomAbs_G1: return 1;
        case GeomAbs_C1: return 2;
        case GeomAbs_G2: return 3;
        case GeomAbs_C2: return 4;
        default: return -1;
    }
}

// --- LocalAnalysis_SurfaceContinuity ---

bool OCCTLocalAnalysisSurfaceContinuity(OCCTSurfaceRef _Nonnull surface1, double u1, double v1,
    OCCTSurfaceRef _Nonnull surface2, double u2, double v2, int32_t order,
    int32_t* _Nonnull outStatus,
    double* _Nonnull outC0Value, double* _Nonnull outG1Angle,
    double* _Nonnull outC1UAngle, double* _Nonnull outC1VAngle) {
    try {
        auto s1 = (OCCTSurface*)surface1;
        auto s2 = (OCCTSurface*)surface2;

        LocalAnalysis_SurfaceContinuity sc(s1->surface, u1, v1, s2->surface, u2, v2,
                                            orderToShape(order));
        if (!sc.IsDone()) return false;

        *outStatus = shapeToOrder(sc.ContinuityStatus());
        *outC0Value = sc.C0Value();
        *outG1Angle = sc.IsG1() ? sc.G1Angle() : -1.0;
        *outC1UAngle = sc.IsC1() ? sc.C1UAngle() : -1.0;
        *outC1VAngle = sc.IsC1() ? sc.C1VAngle() : -1.0;
        return true;
    } catch (...) { return false; }
}

int32_t OCCTLocalAnalysisSurfaceContinuityFlags(OCCTSurfaceRef _Nonnull surface1, double u1, double v1,
    OCCTSurfaceRef _Nonnull surface2, double u2, double v2, int32_t order) {
    try {
        auto s1 = (OCCTSurface*)surface1;
        auto s2 = (OCCTSurface*)surface2;

        LocalAnalysis_SurfaceContinuity sc(s1->surface, u1, v1, s2->surface, u2, v2,
                                            orderToShape(order));
        if (!sc.IsDone()) return 0;

        int32_t flags = 0;
        if (sc.IsC0()) flags |= 1;
        if (sc.IsG1()) flags |= 2;
        if (sc.IsC1()) flags |= 4;
        if (sc.IsG2()) flags |= 8;
        if (sc.IsC2()) flags |= 16;
        return flags;
    } catch (...) { return 0; }
}

// MARK: - GeomFill Trihedrons (Darboux/Fixed/Frenet/ConstantBiNormal) (v0.68)
// --- GeomFill Trihedrons ---

OCCTTrihedronFrame OCCTGeomFillDarbouxTrihedron(OCCTShapeRef edgeShape, OCCTShapeRef faceShape, double param) {
    OCCTTrihedronFrame frame = {};
    try {
        auto* edgeWrapper = reinterpret_cast<OCCTShape*>(edgeShape);
        auto* faceWrapper = reinterpret_cast<OCCTShape*>(faceShape);
        TopoDS_Edge edge = TopoDS::Edge(edgeWrapper->shape);
        TopoDS_Face face = TopoDS::Face(faceWrapper->shape);

        Handle(GeomFill_Darboux) darboux = new GeomFill_Darboux();
        // Darboux needs a curve on surface — use BRepAdaptor_Curve with face context
        Handle(BRepAdaptor_Curve) adaptor = new BRepAdaptor_Curve(edge);
        darboux->SetCurve(adaptor);

        gp_Vec t, n, b;
        if (darboux->D0(param, t, n, b)) {
            frame.tx = t.X(); frame.ty = t.Y(); frame.tz = t.Z();
            frame.nx = n.X(); frame.ny = n.Y(); frame.nz = n.Z();
            frame.bx = b.X(); frame.by = b.Y(); frame.bz = b.Z();
        }
    } catch (...) {}
    return frame;
}

OCCTTrihedronFrame OCCTGeomFillFixedTrihedron(
    double tangentX, double tangentY, double tangentZ,
    double normalX, double normalY, double normalZ, double param)
{
    OCCTTrihedronFrame frame = {};
    try {
        Handle(GeomFill_Fixed) fixed = new GeomFill_Fixed(
            gp_Vec(tangentX, tangentY, tangentZ),
            gp_Vec(normalX, normalY, normalZ));
        gp_Vec t, n, b;
        if (fixed->D0(param, t, n, b)) {
            frame.tx = t.X(); frame.ty = t.Y(); frame.tz = t.Z();
            frame.nx = n.X(); frame.ny = n.Y(); frame.nz = n.Z();
            frame.bx = b.X(); frame.by = b.Y(); frame.bz = b.Z();
        }
    } catch (...) {}
    return frame;
}

OCCTTrihedronFrame OCCTGeomFillFrenetTrihedron(OCCTShapeRef edgeShape, double param) {
    OCCTTrihedronFrame frame = {};
    try {
        auto* wrapper = reinterpret_cast<OCCTShape*>(edgeShape);
        TopoDS_Edge edge = TopoDS::Edge(wrapper->shape);
        Handle(BRepAdaptor_Curve) adaptor = new BRepAdaptor_Curve(edge);

        Handle(GeomFill_Frenet) frenet = new GeomFill_Frenet();
        frenet->SetCurve(adaptor);

        gp_Vec t, n, b;
        if (frenet->D0(param, t, n, b)) {
            frame.tx = t.X(); frame.ty = t.Y(); frame.tz = t.Z();
            frame.nx = n.X(); frame.ny = n.Y(); frame.nz = n.Z();
            frame.bx = b.X(); frame.by = b.Y(); frame.bz = b.Z();
        }
    } catch (...) {}
    return frame;
}

OCCTTrihedronFrame OCCTGeomFillConstantBiNormalTrihedron(OCCTShapeRef edgeShape, double param,
    double biNormalX, double biNormalY, double biNormalZ)
{
    OCCTTrihedronFrame frame = {};
    try {
        auto* wrapper = reinterpret_cast<OCCTShape*>(edgeShape);
        TopoDS_Edge edge = TopoDS::Edge(wrapper->shape);
        Handle(BRepAdaptor_Curve) adaptor = new BRepAdaptor_Curve(edge);

        Handle(GeomFill_ConstantBiNormal) cbn = new GeomFill_ConstantBiNormal(
            gp_Dir(biNormalX, biNormalY, biNormalZ));
        cbn->SetCurve(adaptor);

        gp_Vec t, n, b;
        if (cbn->D0(param, t, n, b)) {
            frame.tx = t.X(); frame.ty = t.Y(); frame.tz = t.Z();
            frame.nx = n.X(); frame.ny = n.Y(); frame.nz = n.Z();
            frame.bx = b.X(); frame.by = b.Y(); frame.bz = b.Z();
        }
    } catch (...) {}
    return frame;
}

// MARK: - GeomFill_NSections (v0.68)
// --- GeomFill_NSections ---

OCCTSurfaceRef OCCTGeomFillNSections(
    const OCCTCurve3DRef* curveRefs,
    const double* params, int32_t count)
{
    try {
        NCollection_Sequence<Handle(Geom_Curve)> sections;
        NCollection_Sequence<double> paramSeq;
        for (int32_t i = 0; i < count; i++) {
            auto* wrapper = reinterpret_cast<OCCTCurve3D*>(curveRefs[i]);
            sections.Append(wrapper->curve);
            paramSeq.Append(params[i]);
        }

        Handle(GeomFill_NSections) nsec = new GeomFill_NSections(sections, paramSeq);
        nsec->ComputeSurface();
        Handle(Geom_BSplineSurface) surf = nsec->BSplineSurface();
        if (surf.IsNull()) return nullptr;

        auto* result = new OCCTSurface();
        result->surface = surf;
        return reinterpret_cast<OCCTSurfaceRef>(result);
    } catch (...) {
        return nullptr;
    }
}

void OCCTGeomFillNSectionsInfo(
    const OCCTCurve3DRef* curveRefs,
    const double* params, int32_t count,
    int32_t* outNbPoles, int32_t* outNbKnots, int32_t* outDegree)
{
    *outNbPoles = 0; *outNbKnots = 0; *outDegree = 0;
    try {
        NCollection_Sequence<Handle(Geom_Curve)> sections;
        NCollection_Sequence<double> paramSeq;
        for (int32_t i = 0; i < count; i++) {
            auto* wrapper = reinterpret_cast<OCCTCurve3D*>(curveRefs[i]);
            sections.Append(wrapper->curve);
            paramSeq.Append(params[i]);
        }

        Handle(GeomFill_NSections) nsec = new GeomFill_NSections(sections, paramSeq);
        int nbP = 0, nbK = 0, deg = 0;
        nsec->SectionShape(nbP, nbK, deg);
        *outNbPoles = (int32_t)nbP;
        *outNbKnots = (int32_t)nbK;
        *outDegree = (int32_t)deg;
    } catch (...) {}
}

// MARK: - GeomFill_Generator (v0.69)
// --- GeomFill_Generator ---

OCCTSurfaceRef OCCTGeomFillGenerator(
    const OCCTCurve3DRef* curves, int32_t curveCount,
    double tolerance)
{
    try {
        GeomFill_Generator gen;

        for (int i = 0; i < curveCount; i++) {
            auto* cw = (OCCTCurve3D*)curves[i];
            if (!cw || cw->curve.IsNull()) return nullptr;
            gen.AddCurve(cw->curve);
        }

        gen.Perform(tolerance);
        Handle(Geom_Surface) surf = gen.Surface();
        if (surf.IsNull()) return nullptr;

        auto* out = new OCCTSurface();
        out->surface = surf;
        return (OCCTSurfaceRef)out;
    } catch (...) {
        return nullptr;
    }
}

// MARK: - GeomFill_DegeneratedBound (v0.69)
// --- GeomFill_DegeneratedBound ---

OCCTBoundaryPoint OCCTGeomFillDegeneratedBoundValue(
    double px, double py, double pz,
    double first, double last, double param)
{
    OCCTBoundaryPoint result = {};
    try {
        Handle(GeomFill_DegeneratedBound) db = new GeomFill_DegeneratedBound(
            gp_Pnt(px, py, pz), first, last, 1e-3, 1e-3);
        gp_Pnt val = db->Value(param);
        result.x = val.X();
        result.y = val.Y();
        result.z = val.Z();
    } catch (...) {}
    return result;
}

bool OCCTGeomFillDegeneratedBoundIsDegenerated(
    double px, double py, double pz, double first, double last)
{
    try {
        Handle(GeomFill_DegeneratedBound) db = new GeomFill_DegeneratedBound(
            gp_Pnt(px, py, pz), first, last, 1e-3, 1e-3);
        return db->IsDegenerated();
    } catch (...) {
        return false;
    }
}

// MARK: - GeomFill_BoundWithSurf Eval (v0.69)
// --- GeomFill_BoundWithSurf ---

bool OCCTGeomFillBoundWithSurfEvaluate(
    OCCTSurfaceRef surface,
    OCCTCurve2DRef curve2d,
    double first, double last, double param,
    double* outX, double* outY, double* outZ,
    double* outNX, double* outNY, double* outNZ)
{
    try {
        auto* sw = (OCCTSurface*)surface;
        auto* cw = (OCCTCurve2D*)curve2d;
        if (!sw || sw->surface.IsNull() || !cw || cw->curve.IsNull()) return false;

        Handle(GeomAdaptor_Surface) adapSurf = new GeomAdaptor_Surface(sw->surface);
        Handle(Geom2dAdaptor_Curve) adapCurve = new Geom2dAdaptor_Curve(cw->curve, first, last);

        Adaptor3d_CurveOnSurface cos(adapCurve, adapSurf);
        Handle(GeomFill_BoundWithSurf) bws = new GeomFill_BoundWithSurf(cos, 1e-3, 1e-3);

        gp_Pnt val = bws->Value(param);
        *outX = val.X();
        *outY = val.Y();
        *outZ = val.Z();

        if (bws->HasNormals()) {
            gp_Vec norm = bws->Norm(param);
            *outNX = norm.X();
            *outNY = norm.Y();
            *outNZ = norm.Z();
        } else {
            *outNX = *outNY = *outNZ = 0;
        }
        return true;
    } catch (...) {
        return false;
    }
}

// MARK: - ShapeCustom_Surface ConvertToPeriodic + Gap (v0.74)
// --- ShapeCustom_Surface: ConvertToPeriodic, Gap ---

OCCTSurfaceRef _Nullable OCCTSurfaceConvertToPeriodic(OCCTSurfaceRef _Nonnull surface) {
    if (!surface) return nullptr;
    try {
        ShapeCustom_Surface sc(surface->surface);
        Handle(Geom_Surface) periodic = sc.ConvertToPeriodic(Standard_False);
        if (periodic.IsNull()) return nullptr;
        auto* ref = new OCCTSurface();
        ref->surface = periodic;
        return ref;
    } catch (...) {
        return nullptr;
    }
}

double OCCTSurfaceConversionGap(OCCTSurfaceRef _Nonnull surface) {
    if (!surface) return -1.0;
    try {
        ShapeCustom_Surface sc(surface->surface);
        // Trigger a conversion to populate gap
        sc.ConvertToAnalytical(1e-3, Standard_False);
        return sc.Gap();
    } catch (...) {
        return -1.0;
    }
}

// MARK: - GeomConvert_ApproxSurface (v0.75)
static GeomAbs_Shape intToContinuity(int32_t c) {
    switch (c) {
        case 0: return GeomAbs_C0;
        case 1: return GeomAbs_C1;
        case 2: return GeomAbs_C2;
        case 3: return GeomAbs_C3;
        default: return GeomAbs_C2;
    }
}

// --- GeomConvert_ApproxSurface ---

OCCTApproxSurfaceResult OCCTGeomConvertApproxSurface(OCCTSurfaceRef _Nonnull surface,
                                                      double tolerance,
                                                      int32_t uContinuity,
                                                      int32_t vContinuity,
                                                      int32_t maxDegree,
                                                      int32_t maxSegments) {
    OCCTApproxSurfaceResult result = {};
    if (!surface) return result;
    try {
        GeomConvert_ApproxSurface approx(surface->surface, tolerance,
                                          intToContinuity(uContinuity),
                                          intToContinuity(vContinuity),
                                          maxDegree, maxDegree, maxSegments, 1);
        result.isDone = approx.IsDone();
        result.hasResult = approx.HasResult();
        if (result.hasResult) {
            result.maxError = approx.MaxError();
            Handle(Geom_BSplineSurface) bspl = approx.Surface();
            if (!bspl.IsNull()) {
                auto* ref = new OCCTSurface();
                ref->surface = bspl;
                result.surface = ref;
            }
        }
    } catch (...) {}
    return result;
}

// MARK: - GeomLib_Tool Surface Param + IsPlanar (v0.77)
bool OCCTGeomLibToolParametersSurface(OCCTSurfaceRef _Nonnull surfRef,
                                       double px, double py, double pz,
                                       double maxDist,
                                       double* _Nonnull outU, double* _Nonnull outV) {
    try {
        auto& surf = reinterpret_cast<OCCTSurface*>(surfRef)->surface;
        double u = 0, v = 0;
        bool ok = GeomLib_Tool::Parameters(surf, gp_Pnt(px, py, pz), maxDist, u, v);
        if (ok) { *outU = u; *outV = v; }
        return ok;
    } catch (...) {
        return false;
    }
}
// MARK: - GeomLib_IsPlanarSurface

bool OCCTGeomLibIsPlanarSurface(OCCTSurfaceRef _Nonnull surfRef, double tolerance) {
    try {
        auto& surf = reinterpret_cast<OCCTSurface*>(surfRef)->surface;
        GeomLib_IsPlanarSurface checker(surf, tolerance);
        return checker.IsPlanar();
    } catch (...) {
        return false;
    }
}

bool OCCTGeomLibPlanarSurfacePlane(OCCTSurfaceRef _Nonnull surfRef, double tolerance,
                                    double* _Nonnull ox, double* _Nonnull oy, double* _Nonnull oz,
                                    double* _Nonnull nx, double* _Nonnull ny, double* _Nonnull nz,
                                    double* _Nonnull xx, double* _Nonnull xy, double* _Nonnull xz) {
    try {
        auto& surf = reinterpret_cast<OCCTSurface*>(surfRef)->surface;
        GeomLib_IsPlanarSurface checker(surf, tolerance);
        if (!checker.IsPlanar()) return false;
        const gp_Pln& pln = checker.Plan();
        gp_Pnt loc = pln.Location();
        gp_Dir dir = pln.Axis().Direction();
        gp_Dir xdir = pln.XAxis().Direction();
        *ox = loc.X(); *oy = loc.Y(); *oz = loc.Z();
        *nx = dir.X(); *ny = dir.Y(); *nz = dir.Z();
        *xx = xdir.X(); *xy = xdir.Y(); *xz = xdir.Z();
        return true;
    } catch (...) {
        return false;
    }
}

// MARK: - GeomConvert_SurfToAnaSurf (v0.78)
// MARK: - GeomConvert_SurfToAnaSurf

OCCTSurfToAnaSurfResult OCCTGeomConvertSurfToAnalytical(OCCTSurfaceRef _Nonnull surfaceRef, double tolerance) {
    OCCTSurfToAnaSurfResult result = {nullptr, 0, false};
    try {
        auto& surface = reinterpret_cast<OCCTSurface*>(surfaceRef)->surface;
        GeomConvert_SurfToAnaSurf converter(surface);
        Handle(Geom_Surface) resSurf = converter.ConvertToAnalytical(tolerance);
        if (!resSurf.IsNull()) {
            result.surface = reinterpret_cast<OCCTSurfaceRef>(new OCCTSurface{resSurf});
            result.gap = converter.Gap();
            result.success = true;
        }
    } catch (...) {}
    return result;
}

OCCTSurfToAnaSurfResult OCCTGeomConvertSurfToAnalyticalBounded(OCCTSurfaceRef _Nonnull surfaceRef,
                                                                  double tolerance,
                                                                  double uMin, double uMax,
                                                                  double vMin, double vMax) {
    OCCTSurfToAnaSurfResult result = {nullptr, 0, false};
    try {
        auto& surface = reinterpret_cast<OCCTSurface*>(surfaceRef)->surface;
        GeomConvert_SurfToAnaSurf converter(surface);
        Handle(Geom_Surface) resSurf = converter.ConvertToAnalytical(tolerance, uMin, uMax, vMin, vMax);
        if (!resSurf.IsNull()) {
            result.surface = reinterpret_cast<OCCTSurfaceRef>(new OCCTSurface{resSurf});
            result.gap = converter.Gap();
            result.success = true;
        }
    } catch (...) {}
    return result;
}

bool OCCTGeomConvertIsCanonical(OCCTSurfaceRef _Nonnull surfaceRef) {
    try {
        auto& surface = reinterpret_cast<OCCTSurface*>(surfaceRef)->surface;
        return GeomConvert_SurfToAnaSurf::IsCanonical(surface);
    } catch (...) {
        return false;
    }
}

// MARK: - GeomFill_Profiler (v0.79)
// --- GeomFill_Profiler ---
struct GeomFillProfilerOpaque {
    GeomFill_Profiler profiler;
    bool isDone;
};

OCCTGeomFillProfilerRef OCCTGeomFillProfilerCreate(void) {
    try {
        auto* opaque = new GeomFillProfilerOpaque();
        opaque->isDone = false;
        return opaque;
    } catch (...) { return nullptr; }
}

void OCCTGeomFillProfilerAddCurve(OCCTGeomFillProfilerRef _Nonnull ref, OCCTCurve3DRef _Nonnull curveRef) {
    try {
        auto* opaque = (GeomFillProfilerOpaque*)ref;
        const Handle(Geom_Curve)& curve = *(const Handle(Geom_Curve)*)curveRef;
        opaque->profiler.AddCurve(curve);
    } catch (...) {}
}

bool OCCTGeomFillProfilerPerform(OCCTGeomFillProfilerRef _Nonnull ref, double tolerance) {
    try {
        auto* opaque = (GeomFillProfilerOpaque*)ref;
        opaque->profiler.Perform(tolerance);
        opaque->isDone = true;
        return true;
    } catch (...) { return false; }
}

int OCCTGeomFillProfilerDegree(OCCTGeomFillProfilerRef _Nonnull ref) {
    try {
        auto* opaque = (GeomFillProfilerOpaque*)ref;
        return opaque->profiler.Degree();
    } catch (...) { return 0; }
}

int OCCTGeomFillProfilerNbPoles(OCCTGeomFillProfilerRef _Nonnull ref) {
    try {
        auto* opaque = (GeomFillProfilerOpaque*)ref;
        return opaque->profiler.NbPoles();
    } catch (...) { return 0; }
}

int OCCTGeomFillProfilerNbKnots(OCCTGeomFillProfilerRef _Nonnull ref) {
    try {
        auto* opaque = (GeomFillProfilerOpaque*)ref;
        return opaque->profiler.NbKnots();
    } catch (...) { return 0; }
}

bool OCCTGeomFillProfilerIsPeriodic(OCCTGeomFillProfilerRef _Nonnull ref) {
    try {
        auto* opaque = (GeomFillProfilerOpaque*)ref;
        return opaque->profiler.IsPeriodic();
    } catch (...) { return false; }
}

bool OCCTGeomFillProfilerPoles(OCCTGeomFillProfilerRef _Nonnull ref, int curveIndex,
                                double* _Nonnull outX, double* _Nonnull outY, double* _Nonnull outZ, int maxPoles) {
    try {
        auto* opaque = (GeomFillProfilerOpaque*)ref;
        int nPoles = opaque->profiler.NbPoles();
        if (nPoles > maxPoles) return false;
        NCollection_Array1<gp_Pnt> poles(1, nPoles);
        opaque->profiler.Poles(curveIndex, poles);
        for (int i = 1; i <= nPoles; i++) {
            outX[i-1] = poles(i).X();
            outY[i-1] = poles(i).Y();
            outZ[i-1] = poles(i).Z();
        }
        return true;
    } catch (...) { return false; }
}

bool OCCTGeomFillProfilerKnotsAndMults(OCCTGeomFillProfilerRef _Nonnull ref,
                                        double* _Nonnull outKnots, int* _Nonnull outMults, int maxKnots) {
    try {
        auto* opaque = (GeomFillProfilerOpaque*)ref;
        int nKnots = opaque->profiler.NbKnots();
        if (nKnots > maxKnots) return false;
        NCollection_Array1<double> knots(1, nKnots);
        NCollection_Array1<int> mults(1, nKnots);
        opaque->profiler.KnotsAndMults(knots, mults);
        for (int i = 1; i <= nKnots; i++) {
            outKnots[i-1] = knots(i);
            outMults[i-1] = mults(i);
        }
        return true;
    } catch (...) { return false; }
}

void OCCTGeomFillProfilerRelease(OCCTGeomFillProfilerRef _Nonnull ref) {
    delete (GeomFillProfilerOpaque*)ref;
}

// MARK: - GeomFill_Stretch (v0.79)
// --- GeomFill_Stretch ---
OCCTStretchFillResult OCCTGeomFillStretch(const double* _Nonnull p1, const double* _Nonnull p2,
                                           const double* _Nonnull p3, const double* _Nonnull p4,
                                           int count,
                                           double* _Nullable outPoles, int maxPoles) {
    OCCTStretchFillResult result = {};
    try {
        NCollection_Array1<gp_Pnt> P1(1, count), P2(1, count), P3(1, count), P4(1, count);
        for (int i = 0; i < count; i++) {
            P1(i+1) = gp_Pnt(p1[i*3], p1[i*3+1], p1[i*3+2]);
            P2(i+1) = gp_Pnt(p2[i*3], p2[i*3+1], p2[i*3+2]);
            P3(i+1) = gp_Pnt(p3[i*3], p3[i*3+1], p3[i*3+2]);
            P4(i+1) = gp_Pnt(p4[i*3], p4[i*3+1], p4[i*3+2]);
        }

        GeomFill_Stretch stretch(P1, P2, P3, P4);
        result.nbUPoles = stretch.NbUPoles();
        result.nbVPoles = stretch.NbVPoles();
        result.isRational = stretch.isRational();

        if (outPoles && maxPoles >= result.nbUPoles * result.nbVPoles) {
            NCollection_Array2<gp_Pnt> poles(1, result.nbUPoles, 1, result.nbVPoles);
            stretch.Poles(poles);
            int idx = 0;
            for (int u = 1; u <= result.nbUPoles; u++) {
                for (int v = 1; v <= result.nbVPoles; v++) {
                    outPoles[idx++] = poles(u, v).X();
                    outPoles[idx++] = poles(u, v).Y();
                    outPoles[idx++] = poles(u, v).Z();
                }
            }
        }
    } catch (...) {}
    return result;
}

// MARK: - GeomFill_LocationDraft (v0.79)
// --- GeomFill_LocationDraft ---
struct LocationDraftOpaque {
    Handle(GeomFill_LocationDraft) loc;
};

OCCTLocationDraftRef OCCTGeomFillLocationDraftCreate(double dirX, double dirY, double dirZ, double angle) {
    try {
        auto* opaque = new LocationDraftOpaque();
        opaque->loc = new GeomFill_LocationDraft(gp_Dir(dirX, dirY, dirZ), angle);
        return opaque;
    } catch (...) { return nullptr; }
}

bool OCCTGeomFillLocationDraftSetCurve(OCCTLocationDraftRef _Nonnull ref, OCCTCurve3DRef _Nonnull curveRef) {
    try {
        auto* opaque = (LocationDraftOpaque*)ref;
        const Handle(Geom_Curve)& curve = *(const Handle(Geom_Curve)*)curveRef;
        Handle(GeomAdaptor_Curve) adaptor = new GeomAdaptor_Curve(curve);
        return opaque->loc->SetCurve(adaptor);
    } catch (...) { return false; }
}

bool OCCTGeomFillLocationDraftD0(OCCTLocationDraftRef _Nonnull ref, double param,
                                  double* _Nonnull mat, double* _Nonnull vecX, double* _Nonnull vecY, double* _Nonnull vecZ) {
    try {
        auto* opaque = (LocationDraftOpaque*)ref;
        gp_Mat M;
        gp_Vec V;
        bool ok = opaque->loc->D0(param, M, V);
        if (ok) {
            // Store 3x3 matrix row-major
            for (int r = 1; r <= 3; r++)
                for (int c = 1; c <= 3; c++)
                    mat[(r-1)*3 + (c-1)] = M.Value(r, c);
            *vecX = V.X(); *vecY = V.Y(); *vecZ = V.Z();
        }
        return ok;
    } catch (...) { return false; }
}

void OCCTGeomFillLocationDraftSetAngle(OCCTLocationDraftRef _Nonnull ref, double angle) {
    try {
        auto* opaque = (LocationDraftOpaque*)ref;
        opaque->loc->SetAngle(angle);
    } catch (...) {}
}

void OCCTGeomFillLocationDraftDirection(OCCTLocationDraftRef _Nonnull ref,
                                         double* _Nonnull x, double* _Nonnull y, double* _Nonnull z) {
    try {
        auto* opaque = (LocationDraftOpaque*)ref;
        gp_Dir d = opaque->loc->Direction();
        *x = d.X(); *y = d.Y(); *z = d.Z();
    } catch (...) {}
}

void OCCTGeomFillLocationDraftRelease(OCCTLocationDraftRef _Nonnull ref) {
    delete (LocationDraftOpaque*)ref;
}

// MARK: - GeomFill_GuideTrihedronAC (v0.79)
// --- GeomFill_GuideTrihedronAC ---
struct GuideTrihedronACOpaque {
    Handle(GeomFill_GuideTrihedronAC) tri;
};

OCCTGuideTrihedronACRef OCCTGeomFillGuideTrihedronACCreate(OCCTCurve3DRef _Nonnull guideCurveRef) {
    try {
        const Handle(Geom_Curve)& curve = *(const Handle(Geom_Curve)*)guideCurveRef;
        Handle(GeomAdaptor_Curve) adaptor = new GeomAdaptor_Curve(curve);
        auto* opaque = new GuideTrihedronACOpaque();
        opaque->tri = new GeomFill_GuideTrihedronAC(adaptor);
        return opaque;
    } catch (...) { return nullptr; }
}

bool OCCTGeomFillGuideTrihedronACSetCurve(OCCTGuideTrihedronACRef _Nonnull ref, OCCTCurve3DRef _Nonnull pathCurveRef) {
    try {
        auto* opaque = (GuideTrihedronACOpaque*)ref;
        const Handle(Geom_Curve)& curve = *(const Handle(Geom_Curve)*)pathCurveRef;
        Handle(GeomAdaptor_Curve) adaptor = new GeomAdaptor_Curve(curve);
        return opaque->tri->SetCurve(adaptor);
    } catch (...) { return false; }
}

bool OCCTGeomFillGuideTrihedronACD0(OCCTGuideTrihedronACRef _Nonnull ref, double param,
                                     double* _Nonnull tX, double* _Nonnull tY, double* _Nonnull tZ,
                                     double* _Nonnull nX, double* _Nonnull nY, double* _Nonnull nZ,
                                     double* _Nonnull bX, double* _Nonnull bY, double* _Nonnull bZ) {
    try {
        auto* opaque = (GuideTrihedronACOpaque*)ref;
        gp_Vec T, N, B;
        bool ok = opaque->tri->D0(param, T, N, B);
        if (ok) {
            *tX = T.X(); *tY = T.Y(); *tZ = T.Z();
            *nX = N.X(); *nY = N.Y(); *nZ = N.Z();
            *bX = B.X(); *bY = B.Y(); *bZ = B.Z();
        }
        return ok;
    } catch (...) { return false; }
}

void OCCTGeomFillGuideTrihedronACRelease(OCCTGuideTrihedronACRef _Nonnull ref) {
    delete (GuideTrihedronACOpaque*)ref;
}

// MARK: - GeomFill_GuideTrihedronPlan (v0.79)
// --- GeomFill_GuideTrihedronPlan ---
struct GuideTrihedronPlanOpaque {
    Handle(GeomFill_GuideTrihedronPlan) tri;
};

OCCTGuideTrihedronPlanRef OCCTGeomFillGuideTrihedronPlanCreate(OCCTCurve3DRef _Nonnull guideCurveRef) {
    try {
        const Handle(Geom_Curve)& curve = *(const Handle(Geom_Curve)*)guideCurveRef;
        Handle(GeomAdaptor_Curve) adaptor = new GeomAdaptor_Curve(curve);
        auto* opaque = new GuideTrihedronPlanOpaque();
        opaque->tri = new GeomFill_GuideTrihedronPlan(adaptor);
        return opaque;
    } catch (...) { return nullptr; }
}

bool OCCTGeomFillGuideTrihedronPlanSetCurve(OCCTGuideTrihedronPlanRef _Nonnull ref, OCCTCurve3DRef _Nonnull pathCurveRef) {
    try {
        auto* opaque = (GuideTrihedronPlanOpaque*)ref;
        const Handle(Geom_Curve)& curve = *(const Handle(Geom_Curve)*)pathCurveRef;
        Handle(GeomAdaptor_Curve) adaptor = new GeomAdaptor_Curve(curve);
        return opaque->tri->SetCurve(adaptor);
    } catch (...) { return false; }
}

bool OCCTGeomFillGuideTrihedronPlanD0(OCCTGuideTrihedronPlanRef _Nonnull ref, double param,
                                       double* _Nonnull tX, double* _Nonnull tY, double* _Nonnull tZ,
                                       double* _Nonnull nX, double* _Nonnull nY, double* _Nonnull nZ,
                                       double* _Nonnull bX, double* _Nonnull bY, double* _Nonnull bZ) {
    try {
        auto* opaque = (GuideTrihedronPlanOpaque*)ref;
        gp_Vec T, N, B;
        bool ok = opaque->tri->D0(param, T, N, B);
        if (ok) {
            *tX = T.X(); *tY = T.Y(); *tZ = T.Z();
            *nX = N.X(); *nY = N.Y(); *nZ = N.Z();
            *bX = B.X(); *bY = B.Y(); *bZ = B.Z();
        }
        return ok;
    } catch (...) { return false; }
}

void OCCTGeomFillGuideTrihedronPlanRelease(OCCTGuideTrihedronPlanRef _Nonnull ref) {
    delete (GuideTrihedronPlanOpaque*)ref;
}

// MARK: - GeomFill_SectionPlacement (v0.79)
// --- GeomFill_SectionPlacement ---
OCCTSectionPlacementResult OCCTGeomFillSectionPlacement(OCCTCurve3DRef _Nonnull pathCurveRef,
                                                         OCCTCurve3DRef _Nonnull sectionCurveRef,
                                                         double dirX, double dirY, double dirZ,
                                                         double draftAngle, double tolerance) {
    OCCTSectionPlacementResult result = {};
    try {
        const Handle(Geom_Curve)& pathCurve = *(const Handle(Geom_Curve)*)pathCurveRef;
        const Handle(Geom_Curve)& sectionCurve = *(const Handle(Geom_Curve)*)sectionCurveRef;

        Handle(GeomFill_LocationDraft) loc = new GeomFill_LocationDraft(gp_Dir(dirX, dirY, dirZ), draftAngle);
        Handle(GeomAdaptor_Curve) pathAdaptor = new GeomAdaptor_Curve(pathCurve);
        loc->SetCurve(pathAdaptor);

        GeomFill_SectionPlacement placement(loc, sectionCurve);
        placement.Perform(tolerance);

        result.isDone = placement.IsDone();
        if (result.isDone) {
            result.parameterOnPath = placement.ParameterOnPath();
            result.parameterOnSection = placement.ParameterOnSection();
            result.distance = placement.Distance();
            result.angle = placement.Angle();
        }
    } catch (...) {}
    return result;
}

// MARK: - GeomFill_AppSurf (v0.79)
// --- GeomFill_AppSurf ---
OCCTAppSurfResult OCCTGeomFillAppSurf(const OCCTCurve3DRef _Nonnull * _Nonnull curveRefs, int count,
                                       int degMin, int degMax, double tol3d, double tol2d) {
    OCCTAppSurfResult result = {};
    try {
        GeomFill_SectionGenerator secGen;
        for (int i = 0; i < count; i++) {
            const Handle(Geom_Curve)& curve = *(const Handle(Geom_Curve)*)curveRefs[i];
            secGen.AddCurve(curve);
        }
        secGen.Perform(1e-6);

        Handle(NCollection_HArray1<double>) params = new NCollection_HArray1<double>(1, count);
        for (int i = 0; i < count; i++) {
            params->SetValue(i + 1, (double)i / (double)(count - 1));
        }
        secGen.SetParam(params);

        Handle(GeomFill_Line) line = new GeomFill_Line(count);

        GeomFill_AppSurf appSurf(degMin, degMax, tol3d, tol2d, 10, false);
        appSurf.Perform(line, secGen, false);

        result.isDone = appSurf.IsDone();
        if (result.isDone) {
            appSurf.SurfShape(result.uDegree, result.vDegree,
                             result.nbUPoles, result.nbVPoles,
                             result.nbUKnots, result.nbVKnots);
        }
    } catch (...) {}
    return result;
}

// MARK: - Extrema_ExtPS + ExtSS (v0.80)
// --- Extrema_ExtPS ---

OCCTExtremaExtPSResult OCCTExtremaExtPS(double px, double py, double pz,
                                         OCCTSurfaceRef surface) {
    OCCTExtremaExtPSResult result = {false, 0};
    try {
        auto* s = (OCCTSurface*)surface;
        Handle(GeomAdaptor_Surface) as = new GeomAdaptor_Surface(s->surface);
        Extrema_ExtPS ext(gp_Pnt(px, py, pz), *as, 1e-6, 1e-6);
        result.isDone = ext.IsDone();
        if (result.isDone) result.nbExt = ext.NbExt();
    } catch (...) {}
    return result;
}

OCCTExtremaPointOnSurf OCCTExtremaExtPSPoint(double px, double py, double pz,
                                              OCCTSurfaceRef surface, int index) {
    OCCTExtremaPointOnSurf result = {};
    try {
        auto* s = (OCCTSurface*)surface;
        Handle(GeomAdaptor_Surface) as = new GeomAdaptor_Surface(s->surface);
        Extrema_ExtPS ext(gp_Pnt(px, py, pz), *as, 1e-6, 1e-6);
        if (ext.IsDone() && index >= 1 && index <= ext.NbExt()) {
            result.squareDistance = ext.SquareDistance(index);
            const Extrema_POnSurf& ps = ext.Point(index);
            result.x = ps.Value().X(); result.y = ps.Value().Y(); result.z = ps.Value().Z();
            ps.Parameter(result.u, result.v);
        }
    } catch (...) {}
    return result;
}

// --- Extrema_ExtSS ---

OCCTExtremaExtSSResult OCCTExtremaExtSS(OCCTSurfaceRef surface1, OCCTSurfaceRef surface2) {
    OCCTExtremaExtSSResult result = {false, false, 0};
    try {
        auto* s1 = (OCCTSurface*)surface1;
        auto* s2 = (OCCTSurface*)surface2;
        Handle(GeomAdaptor_Surface) as1 = new GeomAdaptor_Surface(s1->surface);
        Handle(GeomAdaptor_Surface) as2 = new GeomAdaptor_Surface(s2->surface);
        Extrema_ExtSS ext(*as1, *as2, 1e-6, 1e-6);
        result.isDone = ext.IsDone();
        if (result.isDone) {
            result.isParallel = ext.IsParallel();
            if (!result.isParallel) result.nbExt = ext.NbExt();
        }
    } catch (...) {}
    return result;
}

OCCTExtremaPointPair OCCTExtremaExtSSPoint(OCCTSurfaceRef surface1, OCCTSurfaceRef surface2,
                                            int index) {
    OCCTExtremaPointPair result = {};
    try {
        auto* s1 = (OCCTSurface*)surface1;
        auto* s2 = (OCCTSurface*)surface2;
        Handle(GeomAdaptor_Surface) as1 = new GeomAdaptor_Surface(s1->surface);
        Handle(GeomAdaptor_Surface) as2 = new GeomAdaptor_Surface(s2->surface);
        Extrema_ExtSS ext(*as1, *as2, 1e-6, 1e-6);
        if (ext.IsDone() && !ext.IsParallel() && index >= 1 && index <= ext.NbExt()) {
            result.squareDistance = ext.SquareDistance(index);
            Extrema_POnSurf p1, p2;
            ext.Points(index, p1, p2);
            result.x1 = p1.Value().X(); result.y1 = p1.Value().Y(); result.z1 = p1.Value().Z();
            double u1, v1;
            p1.Parameter(u1, v1);
            result.param1 = u1;
            result.x2 = p2.Value().X(); result.y2 = p2.Value().Y(); result.z2 = p2.Value().Z();
            double u2, v2;
            p2.Parameter(u2, v2);
            result.param2 = u2;
        }
    } catch (...) {}
    return result;
}

// MARK: - gce_Make Cone / Cylinder / Pln (v0.80)
OCCTSurfaceRef _Nullable OCCTGceMakeCone(double p1x, double p1y, double p1z,
                                          double p2x, double p2y, double p2z,
                                          double radius1, double radius2) {
    try {
        gce_MakeCone mc(gp_Pnt(p1x, p1y, p1z), gp_Pnt(p2x, p2y, p2z), radius1, radius2);
        if (!mc.IsDone()) return nullptr;
        Handle(Geom_ConicalSurface) cone = new Geom_ConicalSurface(mc.Value().Position(), mc.Value().SemiAngle(), mc.Value().RefRadius());
        return (OCCTSurfaceRef)new OCCTSurface{cone};
    } catch (...) { return nullptr; }
}

OCCTSurfaceRef _Nullable OCCTGceMakeCylinderFrom3Points(double p1x, double p1y, double p1z,
                                                         double p2x, double p2y, double p2z,
                                                         double p3x, double p3y, double p3z) {
    try {
        gce_MakeCylinder mc(gp_Pnt(p1x, p1y, p1z), gp_Pnt(p2x, p2y, p2z), gp_Pnt(p3x, p3y, p3z));
        if (!mc.IsDone()) return nullptr;
        Handle(Geom_CylindricalSurface) cyl = new Geom_CylindricalSurface(mc.Value().Position(), mc.Value().Radius());
        return (OCCTSurfaceRef)new OCCTSurface{cyl};
    } catch (...) { return nullptr; }
}
OCCTSurfaceRef _Nullable OCCTGceMakePlnFromEquation(double a, double b, double c, double d) {
    try {
        gce_MakePln mp(a, b, c, d);
        if (!mp.IsDone()) return nullptr;
        Handle(Geom_Plane) plane = new Geom_Plane(mp.Value());
        return (OCCTSurfaceRef)new OCCTSurface{plane};
    } catch (...) { return nullptr; }
}

OCCTSurfaceRef _Nullable OCCTGceMakePlnFrom3Points(double p1x, double p1y, double p1z,
                                                    double p2x, double p2y, double p2z,
                                                    double p3x, double p3y, double p3z) {
    try {
        gce_MakePln mp(gp_Pnt(p1x, p1y, p1z), gp_Pnt(p2x, p2y, p2z), gp_Pnt(p3x, p3y, p3z));
        if (!mp.IsDone()) return nullptr;
        Handle(Geom_Plane) plane = new Geom_Plane(mp.Value());
        return (OCCTSurfaceRef)new OCCTSurface{plane};
    } catch (...) { return nullptr; }
}

// MARK: - Geom_RectangularTrimmedSurface handle (v0.86)
// MARK: - Geom_RectangularTrimmedSurface

#include <Geom_RectangularTrimmedSurface.hxx>

OCCTSurfaceRef OCCTSurfaceCreateRectangularTrimmed(OCCTSurfaceRef basisSurface,
                                                     double u1, double u2,
                                                     double v1, double v2) {
    try {
        Handle(Geom_RectangularTrimmedSurface) ts =
            new Geom_RectangularTrimmedSurface(basisSurface->surface, u1, u2, v1, v2);
        auto* ref = new OCCTSurface();
        ref->surface = ts;
        return ref;
    } catch (...) { return nullptr; }
}

OCCTSurfaceRef OCCTSurfaceCreateTrimmedInU(OCCTSurfaceRef basisSurface,
                                             double param1, double param2) {
    try {
        Handle(Geom_RectangularTrimmedSurface) ts =
            new Geom_RectangularTrimmedSurface(basisSurface->surface, param1, param2, true);
        auto* ref = new OCCTSurface();
        ref->surface = ts;
        return ref;
    } catch (...) { return nullptr; }
}

OCCTSurfaceRef OCCTSurfaceCreateTrimmedInV(OCCTSurfaceRef basisSurface,
                                             double param1, double param2) {
    try {
        Handle(Geom_RectangularTrimmedSurface) ts =
            new Geom_RectangularTrimmedSurface(basisSurface->surface, param1, param2, false);
        auto* ref = new OCCTSurface();
        ref->surface = ts;
        return ref;
    } catch (...) { return nullptr; }
}

// MARK: - v0.91: ElSLib
// MARK: - ElSLib (v0.91.0)

#include <ElSLib.hxx>

void OCCTElSLibValueOnPlane(double u, double v,
                             double ox, double oy, double oz,
                             double nx, double ny, double nz,
                             double* outX, double* outY, double* outZ) {
    gp_Pnt p = ElSLib::Value(u, v, gp_Pln(gp_Pnt(ox,oy,oz), gp_Dir(nx,ny,nz)));
    *outX = p.X(); *outY = p.Y(); *outZ = p.Z();
}

void OCCTElSLibValueOnCylinder(double u, double v,
                                double ox, double oy, double oz,
                                double nx, double ny, double nz, double radius,
                                double* outX, double* outY, double* outZ) {
    gp_Pnt p = ElSLib::Value(u, v, gp_Cylinder(gp_Ax3(gp_Pnt(ox,oy,oz), gp_Dir(nx,ny,nz)), radius));
    *outX = p.X(); *outY = p.Y(); *outZ = p.Z();
}

void OCCTElSLibValueOnCone(double u, double v,
                            double ox, double oy, double oz,
                            double nx, double ny, double nz,
                            double refRadius, double semiAngle,
                            double* outX, double* outY, double* outZ) {
    gp_Pnt p = ElSLib::Value(u, v, gp_Cone(gp_Ax3(gp_Pnt(ox,oy,oz), gp_Dir(nx,ny,nz)), semiAngle, refRadius));
    *outX = p.X(); *outY = p.Y(); *outZ = p.Z();
}

void OCCTElSLibValueOnSphere(double u, double v,
                              double ox, double oy, double oz,
                              double nx, double ny, double nz, double radius,
                              double* outX, double* outY, double* outZ) {
    gp_Pnt p = ElSLib::Value(u, v, gp_Sphere(gp_Ax3(gp_Pnt(ox,oy,oz), gp_Dir(nx,ny,nz)), radius));
    *outX = p.X(); *outY = p.Y(); *outZ = p.Z();
}

void OCCTElSLibValueOnTorus(double u, double v,
                             double ox, double oy, double oz,
                             double nx, double ny, double nz,
                             double majorRadius, double minorRadius,
                             double* outX, double* outY, double* outZ) {
    gp_Pnt p = ElSLib::Value(u, v, gp_Torus(gp_Ax3(gp_Pnt(ox,oy,oz), gp_Dir(nx,ny,nz)), majorRadius, minorRadius));
    *outX = p.X(); *outY = p.Y(); *outZ = p.Z();
}

void OCCTElSLibParametersOnSphere(double ox, double oy, double oz,
                                   double nx, double ny, double nz, double radius,
                                   double px, double py, double pz,
                                   double* outU, double* outV) {
    double u, v;
    ElSLib::Parameters(gp_Sphere(gp_Ax3(gp_Pnt(ox,oy,oz), gp_Dir(nx,ny,nz)), radius), gp_Pnt(px,py,pz), u, v);
    *outU = u; *outV = v;
}

void OCCTElSLibD1OnSphere(double u, double v,
                           double ox, double oy, double oz,
                           double nx, double ny, double nz, double radius,
                           double* outPX, double* outPY, double* outPZ,
                           double* outVuX, double* outVuY, double* outVuZ,
                           double* outVvX, double* outVvY, double* outVvZ) {
    gp_Pnt p; gp_Vec vu, vv;
    ElSLib::D1(u, v, gp_Sphere(gp_Ax3(gp_Pnt(ox,oy,oz), gp_Dir(nx,ny,nz)), radius), p, vu, vv);
    *outPX = p.X(); *outPY = p.Y(); *outPZ = p.Z();
    *outVuX = vu.X(); *outVuY = vu.Y(); *outVuZ = vu.Z();
    *outVvX = vv.X(); *outVvY = vv.Y(); *outVvZ = vv.Z();
}

// MARK: - v0.94: Convert_SphereToBSplineSurface
// MARK: - Convert_SphereToBSplineSurface (v0.94.0)

#include <Convert_SphereToBSplineSurface.hxx>
#include <Convert_ElementarySurfaceToBSplineSurface.hxx>

OCCTSurfaceRef OCCTConvertSphereToBSplineSurface(double ox, double oy, double oz,
                                                   double nx, double ny, double nz, double radius) {
    try {
        gp_Sphere sphere(gp_Ax3(gp_Pnt(ox,oy,oz), gp_Dir(nx,ny,nz)), radius);
        Convert_SphereToBSplineSurface conv(sphere);
        int nup = conv.NbUPoles(), nvp = conv.NbVPoles();
        int nuk = conv.NbUKnots(), nvk = conv.NbVKnots();
        int udeg = conv.UDegree(), vdeg = conv.VDegree();

        TColgp_Array2OfPnt poles(1, nup, 1, nvp);
        TColStd_Array2OfReal weights(1, nup, 1, nvp);
        for (int i = 1; i <= nup; i++)
            for (int j = 1; j <= nvp; j++) {
                poles(i,j) = conv.Pole(i,j);
                weights(i,j) = conv.Weight(i,j);
            }

        TColStd_Array1OfReal uknots(1, nuk), vknots(1, nvk);
        TColStd_Array1OfInteger umults(1, nuk), vmults(1, nvk);
        for (int i = 1; i <= nuk; i++) { uknots(i) = conv.UKnot(i); umults(i) = conv.UMultiplicity(i); }
        for (int i = 1; i <= nvk; i++) { vknots(i) = conv.VKnot(i); vmults(i) = conv.VMultiplicity(i); }

        Handle(Geom_BSplineSurface) bss = new Geom_BSplineSurface(
            poles, weights, uknots, vknots, umults, vmults, udeg, vdeg,
            conv.IsUPeriodic(), conv.IsVPeriodic());
        if (bss.IsNull()) return nullptr;
        OCCTSurface* result = new OCCTSurface();
        result->surface = bss;
        return result;
    } catch (...) { return nullptr; }
}

// MARK: - v0.95: Convert_Cylinder/Cone/TorusToBSplineSurface (with buildSurfaceFromElementary helper)

#include <Convert_ElementarySurfaceToBSplineSurface.hxx>

// Helper: build Geom_BSplineSurface from Convert_ElementarySurfaceToBSplineSurface result
static OCCTSurfaceRef buildSurfaceFromElementary(const Convert_ElementarySurfaceToBSplineSurface& conv) {
    int nup = conv.NbUPoles(), nvp = conv.NbVPoles();
    int nuk = conv.NbUKnots(), nvk = conv.NbVKnots();
    int udeg = conv.UDegree(), vdeg = conv.VDegree();

    TColgp_Array2OfPnt poles(1, nup, 1, nvp);
    TColStd_Array2OfReal weights(1, nup, 1, nvp);
    for (int i = 1; i <= nup; i++)
        for (int j = 1; j <= nvp; j++) {
            poles(i,j) = conv.Pole(i,j);
            weights(i,j) = conv.Weight(i,j);
        }

    TColStd_Array1OfReal uknots(1, nuk), vknots(1, nvk);
    TColStd_Array1OfInteger umults(1, nuk), vmults(1, nvk);
    for (int i = 1; i <= nuk; i++) { uknots(i) = conv.UKnot(i); umults(i) = conv.UMultiplicity(i); }
    for (int i = 1; i <= nvk; i++) { vknots(i) = conv.VKnot(i); vmults(i) = conv.VMultiplicity(i); }

    Handle(Geom_BSplineSurface) bss = new Geom_BSplineSurface(
        poles, weights, uknots, vknots, umults, vmults, udeg, vdeg,
        conv.IsUPeriodic(), conv.IsVPeriodic());
    if (bss.IsNull()) return nullptr;
    OCCTSurface* result = new OCCTSurface();
    result->surface = bss;
    return result;
}

OCCTSurfaceRef OCCTConvertCylinderToBSplineSurface(double ox, double oy, double oz,
                                                     double nx, double ny, double nz,
                                                     double radius,
                                                     double u1, double u2, double v1, double v2) {
    try {
        gp_Cylinder cyl(gp_Ax3(gp_Pnt(ox,oy,oz), gp_Dir(nx,ny,nz)), radius);
        Convert_CylinderToBSplineSurface conv(cyl, u1, u2, v1, v2);
        return buildSurfaceFromElementary(conv);
    } catch (...) { return nullptr; }
}

OCCTSurfaceRef OCCTConvertConeToBSplineSurface(double ox, double oy, double oz,
                                                 double nx, double ny, double nz,
                                                 double semiAngle, double refRadius,
                                                 double u1, double u2, double v1, double v2) {
    try {
        gp_Cone cone(gp_Ax3(gp_Pnt(ox,oy,oz), gp_Dir(nx,ny,nz)), semiAngle, refRadius);
        Convert_ConeToBSplineSurface conv(cone, u1, u2, v1, v2);
        return buildSurfaceFromElementary(conv);
    } catch (...) { return nullptr; }
}

OCCTSurfaceRef OCCTConvertTorusToBSplineSurface(double ox, double oy, double oz,
                                                  double nx, double ny, double nz,
                                                  double majorRadius, double minorRadius) {
    try {
        gp_Torus torus(gp_Ax3(gp_Pnt(ox,oy,oz), gp_Dir(nx,ny,nz)), majorRadius, minorRadius);
        Convert_TorusToBSplineSurface conv(torus);
        return buildSurfaceFromElementary(conv);
    } catch (...) { return nullptr; }
}

// MARK: - v0.99: Geom_OffsetSurface Extensions
// MARK: - Geom_OffsetSurface Extensions (v0.99.0)

#include <Geom_OffsetCurve.hxx>
#include <Geom_OffsetSurface.hxx>

double OCCTSurfaceOffsetValue(OCCTSurfaceRef surface) {
    if (!surface || surface->surface.IsNull()) return 0.0;
    Handle(Geom_OffsetSurface) off = Handle(Geom_OffsetSurface)::DownCast(surface->surface);
    if (off.IsNull()) return 0.0;
    return off->Offset();
}

void OCCTSurfaceSetOffsetValue(OCCTSurfaceRef surface, double offset) {
    if (!surface || surface->surface.IsNull()) return;
    Handle(Geom_OffsetSurface) off = Handle(Geom_OffsetSurface)::DownCast(surface->surface);
    if (off.IsNull()) return;
    try { off->SetOffsetValue(offset); } catch (...) {}
}

OCCTSurfaceRef OCCTSurfaceOffsetBasis(OCCTSurfaceRef surface) {
    if (!surface || surface->surface.IsNull()) return nullptr;
    Handle(Geom_OffsetSurface) off = Handle(Geom_OffsetSurface)::DownCast(surface->surface);
    if (off.IsNull()) return nullptr;
    Handle(Geom_Surface) basis = off->BasisSurface();
    if (basis.IsNull()) return nullptr;
    auto* ref = new OCCTSurface();
    ref->surface = basis;
    return ref;
}

// MARK: - v0.101: ShapeAnalysis_Surface (project / singularities / closed)
// --- ShapeAnalysis_Surface ---

double OCCTSurfaceProjectPointUV(OCCTSurfaceRef surface, double px, double py, double pz,
                                   double preci, double* u, double* v) {
    try {
        Handle(ShapeAnalysis_Surface) sas = new ShapeAnalysis_Surface(surface->surface);
        gp_Pnt2d uv = sas->ValueOfUV(gp_Pnt(px, py, pz), preci);
        *u = uv.X();
        *v = uv.Y();
        return sas->Gap();
    } catch (...) { *u = 0; *v = 0; return -1.0; }
}

bool OCCTSurfaceHasSingularities(OCCTSurfaceRef surface, double preci) {
    try {
        Handle(ShapeAnalysis_Surface) sas = new ShapeAnalysis_Surface(surface->surface);
        return sas->HasSingularities(preci);
    } catch (...) { return false; }
}

int32_t OCCTSurfaceNbSingularities(OCCTSurfaceRef surface, double preci) {
    try {
        Handle(ShapeAnalysis_Surface) sas = new ShapeAnalysis_Surface(surface->surface);
        return sas->NbSingularities(preci);
    } catch (...) { return 0; }
}

bool OCCTSurfaceIsUClosedSA(OCCTSurfaceRef surface, double preci) {
    try {
        Handle(ShapeAnalysis_Surface) sas = new ShapeAnalysis_Surface(surface->surface);
        return sas->IsUClosed(preci);
    } catch (...) { return false; }
}

bool OCCTSurfaceIsVClosedSA(OCCTSurfaceRef surface, double preci) {
    try {
        Handle(ShapeAnalysis_Surface) sas = new ShapeAnalysis_Surface(surface->surface);
        return sas->IsVClosed(preci);
    } catch (...) { return false; }
}

// --- ShapeAnalysis_Surface extras + BRepGProp_Face (#266 follow-up) ---
#include <gp_Pnt2d.hxx>
#include <BRepGProp_Face.hxx>
#include <NCollection_HArray1.hxx>

/// UVFromIso: refine a (U,V) for P3D by projecting onto the surface's iso-lines; returns the best
/// 3D gap (very large on failure).
double OCCTSurfaceUVFromIso(OCCTSurfaceRef surface, double px, double py, double pz,
                            double preci, double* u, double* v) {
    try {
        Handle(ShapeAnalysis_Surface) sas = new ShapeAnalysis_Surface(surface->surface);
        double U = 0, V = 0;
        double d = sas->UVFromIso(gp_Pnt(px, py, pz), preci, U, V);
        if (u) *u = U;
        if (v) *v = V;
        return d;
    } catch (...) { if (u) *u = 0; if (v) *v = 0; return -1.0; }
}

/// Detail of singularity #num (1-based): 3D pole point, first/last 2D points of the degenerate
/// iso-line, its first/last parameters, and whether it is a U-iso (else V-iso). `preci` is in/out.
bool OCCTSurfaceSingularityDetail(OCCTSurfaceRef surface, int32_t num, double* preci,
                                  double* px, double* py, double* pz,
                                  double* firstU, double* firstV, double* lastU, double* lastV,
                                  double* firstPar, double* lastPar, bool* uIsoDegenerate) {
    try {
        Handle(ShapeAnalysis_Surface) sas = new ShapeAnalysis_Surface(surface->surface);
        gp_Pnt P3d; gp_Pnt2d f2, l2; double fp = 0, lp = 0; Standard_Boolean uiso = Standard_False;
        double pr = preci ? *preci : 0.0;
        if (!sas->Singularity(num, pr, P3d, f2, l2, fp, lp, uiso)) return false;
        if (preci) *preci = pr;
        if (px) *px = P3d.X(); if (py) *py = P3d.Y(); if (pz) *pz = P3d.Z();
        if (firstU) *firstU = f2.X(); if (firstV) *firstV = f2.Y();
        if (lastU) *lastU = l2.X(); if (lastV) *lastV = l2.Y();
        if (firstPar) *firstPar = fp; if (lastPar) *lastPar = lp;
        if (uIsoDegenerate) *uIsoDegenerate = uiso;
        return true;
    } catch (...) { return false; }
}

/// ProjectDegenerated: adjust the indeterminate 2D coordinate of a point lying in a surface
/// singularity, taking the fixed coordinate from a `neighbour` 2D point. Returns the resolved (ru,rv).
bool OCCTSurfaceProjectDegenerated(OCCTSurfaceRef surface, double px, double py, double pz,
                                   double preci, double neighbourU, double neighbourV,
                                   double* ru, double* rv) {
    try {
        Handle(ShapeAnalysis_Surface) sas = new ShapeAnalysis_Surface(surface->surface);
        gp_Pnt2d result;
        if (!sas->ProjectDegenerated(gp_Pnt(px, py, pz), preci, gp_Pnt2d(neighbourU, neighbourV), result))
            return false;
        if (ru) *ru = result.X();
        if (rv) *rv = result.Y();
        return true;
    } catch (...) { return false; }
}

/// Like OCCTSurfaceProjectPointUV but restricts the search to the [u1,u2]×[v1,v2] domain
/// (ShapeAnalysis_Surface::SetDomain) — disambiguates projection on periodic / self-overlapping
/// surfaces. Returns the 3D gap (Gap()), or -1 on failure.
double OCCTSurfaceProjectPointUVInDomain(OCCTSurfaceRef surface, double px, double py, double pz,
                                         double preci, double u1, double u2, double v1, double v2,
                                         double* u, double* v) {
    try {
        Handle(ShapeAnalysis_Surface) sas = new ShapeAnalysis_Surface(surface->surface);
        sas->SetDomain(u1, u2, v1, v2);
        gp_Pnt2d uv = sas->ValueOfUV(gp_Pnt(px, py, pz), preci);
        if (u) *u = uv.X();
        if (v) *v = uv.Y();
        return sas->Gap();
    } catch (...) { if (u) *u = 0; if (v) *v = 0; return -1.0; }
}

/// BRepGProp_Face Gauss-integration orders (number of integration points) in U and V — non-zero
/// only for BSpline faces. Returns false if `face` is not a face.
bool OCCTBRepGPropFaceIntegrationOrders(OCCTShapeRef face, int32_t* uOrder, int32_t* vOrder) {
    if (!face || face->shape.IsNull() || face->shape.ShapeType() != TopAbs_FACE) return false;
    try {
        BRepGProp_Face gf(TopoDS::Face(face->shape));
        if (uOrder) *uOrder = gf.UIntegrationOrder();
        if (vOrder) *vOrder = gf.VIntegrationOrder();
        return true;
    } catch (...) { return false; }
}

/// BRepGProp_Face U-direction integration knots (BSpline spans over the face's U range). Fills up to
/// `maxCount` into `buffer` and returns the count, or 0 on failure.
int32_t OCCTBRepGPropFaceUKnots(OCCTShapeRef face, double* buffer, int32_t maxCount) {
    if (!face || face->shape.IsNull() || face->shape.ShapeType() != TopAbs_FACE) return 0;
    try {
        BRepGProp_Face gf(TopoDS::Face(face->shape));
        double u1, u2, v1, v2; gf.Bounds(u1, u2, v1, v2);
        Handle(NCollection_HArray1<double>) knots = gf.GetUKnots(u1, u2);
        if (knots.IsNull()) return 0;
        int32_t n = 0;
        for (int i = knots->Lower(); i <= knots->Upper() && n < maxCount; i++, n++) {
            if (buffer) buffer[n] = knots->Value(i);
        }
        return n;
    } catch (...) { return 0; }
}

// MARK: - v0.105: GeomConvert_BSplineSurfaceKnotSplitting
// MARK: - GeomConvert_BSplineSurfaceKnotSplitting (v0.105.0)

#include <GeomConvert_BSplineSurfaceKnotSplitting.hxx>
#include <Geom_BSplineSurface.hxx>

int32_t OCCTBSplineSurfaceKnotSplitsU(OCCTSurfaceRef surface, int32_t continuity) {
    if (!surface) return 0;
    try {
        Handle(Geom_BSplineSurface) bsurf = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
        if (bsurf.IsNull()) return 0;
        GeomConvert_BSplineSurfaceKnotSplitting splitter(bsurf, continuity, continuity);
        return (int32_t)splitter.NbUSplits();
    } catch (...) { return 0; }
}

int32_t OCCTBSplineSurfaceKnotSplitsV(OCCTSurfaceRef surface, int32_t continuity) {
    if (!surface) return 0;
    try {
        Handle(Geom_BSplineSurface) bsurf = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
        if (bsurf.IsNull()) return 0;
        GeomConvert_BSplineSurfaceKnotSplitting splitter(bsurf, continuity, continuity);
        return (int32_t)splitter.NbVSplits();
    } catch (...) { return 0; }
}

void OCCTBSplineSurfaceKnotSplitValues(OCCTSurfaceRef surface, int32_t continuity,
                                        int32_t* uSplits, int32_t* vSplits) {
    if (!surface || !uSplits || !vSplits) return;
    try {
        Handle(Geom_BSplineSurface) bsurf = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
        if (bsurf.IsNull()) return;
        GeomConvert_BSplineSurfaceKnotSplitting splitter(bsurf, continuity, continuity);
        for (int i = 1; i <= splitter.NbUSplits(); i++) {
            uSplits[i - 1] = splitter.USplitValue(i);
        }
        for (int i = 1; i <= splitter.NbVSplits(); i++) {
            vSplits[i - 1] = splitter.VSplitValue(i);
        }
    } catch (...) {}
}

// MARK: - v0.106: GC_MakeConical/Cylindrical/TrimmedCone/TrimmedCylinder + Surface continuity
// MARK: - GC_MakeConicalSurface (v0.106.0)

#include <GC_MakeConicalSurface.hxx>
#include <Geom_ConicalSurface.hxx>

OCCTSurfaceRef OCCTGCMakeConicalSurface(double cx, double cy, double cz,
                                         double nx, double ny, double nz,
                                         double semiAngle, double radius) {
    try {
        gp_Ax2 ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
        GC_MakeConicalSurface mc(ax, semiAngle, radius);
        if (!mc.IsDone()) return nullptr;
        return new OCCTSurface(mc.Value());
    } catch (...) { return nullptr; }
}

OCCTSurfaceRef OCCTGCMakeConicalSurface2Pts(double x1, double y1, double z1,
                                              double x2, double y2, double z2,
                                              double r1, double r2) {
    try {
        GC_MakeConicalSurface mc(gp_Pnt(x1, y1, z1), gp_Pnt(x2, y2, z2), r1, r2);
        if (!mc.IsDone()) return nullptr;
        return new OCCTSurface(mc.Value());
    } catch (...) { return nullptr; }
}

OCCTSurfaceRef OCCTGCMakeConicalSurface4Pts(double x1, double y1, double z1,
                                              double x2, double y2, double z2,
                                              double x3, double y3, double z3,
                                              double x4, double y4, double z4) {
    try {
        GC_MakeConicalSurface mc(gp_Pnt(x1, y1, z1), gp_Pnt(x2, y2, z2),
                                  gp_Pnt(x3, y3, z3), gp_Pnt(x4, y4, z4));
        if (!mc.IsDone()) return nullptr;
        return new OCCTSurface(mc.Value());
    } catch (...) { return nullptr; }
}
// MARK: - GC_MakeCylindricalSurface (v0.106.0)

#include <GC_MakeCylindricalSurface.hxx>
#include <Geom_CylindricalSurface.hxx>

OCCTSurfaceRef OCCTGCMakeCylindricalSurface(double cx, double cy, double cz,
                                              double nx, double ny, double nz,
                                              double radius) {
    try {
        gp_Ax2 ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
        GC_MakeCylindricalSurface mc(ax, radius);
        if (!mc.IsDone()) return nullptr;
        return new OCCTSurface(mc.Value());
    } catch (...) { return nullptr; }
}

OCCTSurfaceRef OCCTGCMakeCylindricalSurface3Pts(double x1, double y1, double z1,
                                                  double x2, double y2, double z2,
                                                  double x3, double y3, double z3) {
    try {
        GC_MakeCylindricalSurface mc(gp_Pnt(x1, y1, z1), gp_Pnt(x2, y2, z2),
                                      gp_Pnt(x3, y3, z3));
        if (!mc.IsDone()) return nullptr;
        return new OCCTSurface(mc.Value());
    } catch (...) { return nullptr; }
}

OCCTSurfaceRef OCCTGCMakeCylindricalSurfaceFromCircle(double cx, double cy, double cz,
                                                        double nx, double ny, double nz,
                                                        double radius) {
    try {
        gp_Ax2 ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
        gp_Circ circ(ax, radius);
        GC_MakeCylindricalSurface mc(circ);
        if (!mc.IsDone()) return nullptr;
        return new OCCTSurface(mc.Value());
    } catch (...) { return nullptr; }
}

OCCTSurfaceRef OCCTGCMakeCylindricalSurfaceParallel(double cx, double cy, double cz,
                                                      double nx, double ny, double nz,
                                                      double radius, double dist) {
    try {
        gp_Ax2 ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
        gp_Cylinder cyl(ax, radius);
        GC_MakeCylindricalSurface mc(cyl, dist);
        if (!mc.IsDone()) return nullptr;
        return new OCCTSurface(mc.Value());
    } catch (...) { return nullptr; }
}

OCCTSurfaceRef OCCTGCMakeCylindricalSurfaceAxis(double px, double py, double pz,
                                                  double dx, double dy, double dz,
                                                  double radius) {
    try {
        gp_Ax1 ax(gp_Pnt(px, py, pz), gp_Dir(dx, dy, dz));
        GC_MakeCylindricalSurface mc(ax, radius);
        if (!mc.IsDone()) return nullptr;
        return new OCCTSurface(mc.Value());
    } catch (...) { return nullptr; }
}
// MARK: - GC_MakeTrimmedCone (v0.106.0)

#include <GC_MakeTrimmedCone.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>

OCCTSurfaceRef OCCTGCMakeTrimmedCone2Pts(double x1, double y1, double z1,
                                           double x2, double y2, double z2,
                                           double r1, double r2) {
    try {
        GC_MakeTrimmedCone mc(gp_Pnt(x1, y1, z1), gp_Pnt(x2, y2, z2), r1, r2);
        if (!mc.IsDone()) return nullptr;
        return new OCCTSurface(mc.Value());
    } catch (...) { return nullptr; }
}

OCCTSurfaceRef OCCTGCMakeTrimmedCone4Pts(double x1, double y1, double z1,
                                           double x2, double y2, double z2,
                                           double x3, double y3, double z3,
                                           double x4, double y4, double z4) {
    try {
        GC_MakeTrimmedCone mc(gp_Pnt(x1, y1, z1), gp_Pnt(x2, y2, z2),
                               gp_Pnt(x3, y3, z3), gp_Pnt(x4, y4, z4));
        if (!mc.IsDone()) return nullptr;
        return new OCCTSurface(mc.Value());
    } catch (...) { return nullptr; }
}
// MARK: - GC_MakeTrimmedCylinder (v0.106.0)

#include <GC_MakeTrimmedCylinder.hxx>

OCCTSurfaceRef OCCTGCMakeTrimmedCylinderCircle(double cx, double cy, double cz,
                                                 double nx, double ny, double nz,
                                                 double radius, double height) {
    try {
        gp_Ax2 ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
        gp_Circ circ(ax, radius);
        GC_MakeTrimmedCylinder mc(circ, height);
        if (!mc.IsDone()) return nullptr;
        return new OCCTSurface(mc.Value());
    } catch (...) { return nullptr; }
}

OCCTSurfaceRef OCCTGCMakeTrimmedCylinderAxis(double px, double py, double pz,
                                               double dx, double dy, double dz,
                                               double radius, double height) {
    try {
        gp_Ax1 ax(gp_Pnt(px, py, pz), gp_Dir(dx, dy, dz));
        GC_MakeTrimmedCylinder mc(ax, radius, height);
        if (!mc.IsDone()) return nullptr;
        return new OCCTSurface(mc.Value());
    } catch (...) { return nullptr; }
}

OCCTSurfaceRef OCCTGCMakeTrimmedCylinder3Pts(double x1, double y1, double z1,
                                               double x2, double y2, double z2,
                                               double x3, double y3, double z3) {
    try {
        GC_MakeTrimmedCylinder mc(gp_Pnt(x1, y1, z1), gp_Pnt(x2, y2, z2),
                                   gp_Pnt(x3, y3, z3));
        if (!mc.IsDone()) return nullptr;
        return new OCCTSurface(mc.Value());
    } catch (...) { return nullptr; }
}
// MARK: - Surface continuity (v0.106.0)

int32_t OCCTSurfaceGetContinuity(OCCTSurfaceRef surface) {
    if (!surface || surface->surface.IsNull()) return 0;
    try {
        return static_cast<int32_t>(surface->surface->Continuity());
    } catch (...) { return 0; }
}

void OCCTSurfaceGetNBounds(OCCTSurfaceRef surface, int32_t* uSpans, int32_t* vSpans) {
    *uSpans = 0; *vSpans = 0;
    if (!surface || surface->surface.IsNull()) return;
    try {
        double u1, u2, v1, v2;
        surface->surface->Bounds(u1, u2, v1, v2);
        *uSpans = (u2 > u1) ? 1 : 0;
        *vSpans = (v2 > v1) ? 1 : 0;
    } catch (...) {}
}

// MARK: - v0.107: Geom_BSplineSurface Methods
// MARK: - Geom_BSplineSurface Methods (v0.107.0)

int32_t OCCTSurfaceBSplineNbUKnots(OCCTSurfaceRef surface) {
    if (!surface || surface->surface.IsNull()) return 0;
    Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return 0;
    return bs->NbUKnots();
}

int32_t OCCTSurfaceBSplineNbVKnots(OCCTSurfaceRef surface) {
    if (!surface || surface->surface.IsNull()) return 0;
    Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return 0;
    return bs->NbVKnots();
}

int32_t OCCTSurfaceBSplineNbUPoles(OCCTSurfaceRef surface) {
    if (!surface || surface->surface.IsNull()) return 0;
    Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return 0;
    return bs->NbUPoles();
}

int32_t OCCTSurfaceBSplineNbVPoles(OCCTSurfaceRef surface) {
    if (!surface || surface->surface.IsNull()) return 0;
    Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return 0;
    return bs->NbVPoles();
}

int32_t OCCTSurfaceBSplineUDegree(OCCTSurfaceRef surface) {
    if (!surface || surface->surface.IsNull()) return 0;
    Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return 0;
    return bs->UDegree();
}

int32_t OCCTSurfaceBSplineVDegree(OCCTSurfaceRef surface) {
    if (!surface || surface->surface.IsNull()) return 0;
    Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return 0;
    return bs->VDegree();
}

bool OCCTSurfaceBSplineIsURational(OCCTSurfaceRef surface) {
    if (!surface || surface->surface.IsNull()) return false;
    Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return false;
    return bs->IsURational();
}

bool OCCTSurfaceBSplineIsVRational(OCCTSurfaceRef surface) {
    if (!surface || surface->surface.IsNull()) return false;
    Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return false;
    return bs->IsVRational();
}

void OCCTSurfaceBSplineGetPole(OCCTSurfaceRef surface, int32_t uIndex, int32_t vIndex, double* x, double* y, double* z) {
    *x = 0; *y = 0; *z = 0;
    if (!surface || surface->surface.IsNull()) return;
    Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return;
    if (uIndex < 1 || uIndex > bs->NbUPoles() || vIndex < 1 || vIndex > bs->NbVPoles()) return;
    gp_Pnt p = bs->Pole(uIndex, vIndex);
    *x = p.X(); *y = p.Y(); *z = p.Z();
}

bool OCCTSurfaceBSplineSetPole(OCCTSurfaceRef surface, int32_t uIndex, int32_t vIndex, double x, double y, double z) {
    if (!surface || surface->surface.IsNull()) return false;
    Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return false;
    try { bs->SetPole(uIndex, vIndex, gp_Pnt(x, y, z)); return true; } catch (...) { return false; }
}

bool OCCTSurfaceBSplineSetWeight(OCCTSurfaceRef surface, int32_t uIndex, int32_t vIndex, double weight) {
    if (!surface || surface->surface.IsNull()) return false;
    Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return false;
    try { bs->SetWeight(uIndex, vIndex, weight); return true; } catch (...) { return false; }
}

bool OCCTSurfaceBSplineInsertUKnot(OCCTSurfaceRef surface, double u, int32_t mult, double tol) {
    if (!surface || surface->surface.IsNull()) return false;
    Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return false;
    try { bs->InsertUKnot(u, mult, tol); return true; } catch (...) { return false; }
}

bool OCCTSurfaceBSplineInsertVKnot(OCCTSurfaceRef surface, double v, int32_t mult, double tol) {
    if (!surface || surface->surface.IsNull()) return false;
    Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return false;
    try { bs->InsertVKnot(v, mult, tol); return true; } catch (...) { return false; }
}

bool OCCTSurfaceBSplineSegment(OCCTSurfaceRef surface, double u1, double u2, double v1, double v2) {
    if (!surface || surface->surface.IsNull()) return false;
    Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return false;
    try { bs->Segment(u1, u2, v1, v2); return true; } catch (...) { return false; }
}

bool OCCTSurfaceBSplineIncreaseDegree(OCCTSurfaceRef surface, int32_t uDeg, int32_t vDeg) {
    if (!surface || surface->surface.IsNull()) return false;
    Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return false;
    try { bs->IncreaseDegree(uDeg, vDeg); return true; } catch (...) { return false; }
}

bool OCCTSurfaceBSplineExchangeUV(OCCTSurfaceRef surface) {
    if (!surface || surface->surface.IsNull()) return false;
    Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return false;
    try { bs->ExchangeUV(); return true; } catch (...) { return false; }
}

// MARK: - v0.108: Geom_Plane/Spherical/Toroidal/SurfaceOfRevolution/Cylindrical/Conical/Swept Methods
// MARK: - Geom_Plane Methods (v0.108.0)

void OCCTSurfacePlaneCoefficients(OCCTSurfaceRef surface, double* A, double* B, double* C, double* D) {
    *A = 0; *B = 0; *C = 0; *D = 0;
    if (!surface) return;
    try {
        Handle(Geom_Plane) p = Handle(Geom_Plane)::DownCast(surface->surface);
        if (p.IsNull()) return;
        p->Coefficients(*A, *B, *C, *D);
    } catch (...) {}
}

OCCTCurve3DRef OCCTSurfacePlaneUIso(OCCTSurfaceRef surface, double u) {
    if (!surface) return nullptr;
    try {
        Handle(Geom_Plane) p = Handle(Geom_Plane)::DownCast(surface->surface);
        if (p.IsNull()) return nullptr;
        Handle(Geom_Curve) iso = p->UIso(u);
        if (iso.IsNull()) return nullptr;
        return new OCCTCurve3D(iso);
    } catch (...) { return nullptr; }
}

OCCTCurve3DRef OCCTSurfacePlaneVIso(OCCTSurfaceRef surface, double v) {
    if (!surface) return nullptr;
    try {
        Handle(Geom_Plane) p = Handle(Geom_Plane)::DownCast(surface->surface);
        if (p.IsNull()) return nullptr;
        Handle(Geom_Curve) iso = p->VIso(v);
        if (iso.IsNull()) return nullptr;
        return new OCCTCurve3D(iso);
    } catch (...) { return nullptr; }
}

void OCCTSurfacePlanePln(OCCTSurfaceRef surface, double* px, double* py, double* pz, double* nx, double* ny, double* nz) {
    *px = 0; *py = 0; *pz = 0; *nx = 0; *ny = 0; *nz = 0;
    if (!surface) return;
    try {
        Handle(Geom_Plane) p = Handle(Geom_Plane)::DownCast(surface->surface);
        if (p.IsNull()) return;
        gp_Pln pln = p->Pln();
        gp_Pnt loc = pln.Location();
        gp_Dir norm = pln.Axis().Direction();
        *px = loc.X(); *py = loc.Y(); *pz = loc.Z();
        *nx = norm.X(); *ny = norm.Y(); *nz = norm.Z();
    } catch (...) {}
}
// MARK: - Geom_SphericalSurface Methods (v0.108.0)

double OCCTSurfaceSphereRadius(OCCTSurfaceRef surface) {
    if (!surface) return 0;
    try {
        Handle(Geom_SphericalSurface) s = Handle(Geom_SphericalSurface)::DownCast(surface->surface);
        if (s.IsNull()) return 0;
        return s->Radius();
    } catch (...) { return 0; }
}

bool OCCTSurfaceSphereSetRadius(OCCTSurfaceRef surface, double radius) {
    if (!surface) return false;
    try {
        Handle(Geom_SphericalSurface) s = Handle(Geom_SphericalSurface)::DownCast(surface->surface);
        if (s.IsNull()) return false;
        s->SetRadius(radius);
        return true;
    } catch (...) { return false; }
}

double OCCTSurfaceSphereArea(OCCTSurfaceRef surface) {
    if (!surface) return 0;
    try {
        Handle(Geom_SphericalSurface) s = Handle(Geom_SphericalSurface)::DownCast(surface->surface);
        if (s.IsNull()) return 0;
        return s->Area();
    } catch (...) { return 0; }
}

double OCCTSurfaceSphereVolume(OCCTSurfaceRef surface) {
    if (!surface) return 0;
    try {
        Handle(Geom_SphericalSurface) s = Handle(Geom_SphericalSurface)::DownCast(surface->surface);
        if (s.IsNull()) return 0;
        return s->Volume();
    } catch (...) { return 0; }
}

void OCCTSurfaceSphereCenter(OCCTSurfaceRef surface, double* x, double* y, double* z) {
    *x = 0; *y = 0; *z = 0;
    if (!surface) return;
    try {
        Handle(Geom_SphericalSurface) s = Handle(Geom_SphericalSurface)::DownCast(surface->surface);
        if (s.IsNull()) return;
        gp_Pnt c = s->Sphere().Location();
        *x = c.X(); *y = c.Y(); *z = c.Z();
    } catch (...) {}
}

OCCTCurve3DRef OCCTSurfaceSphereUIso(OCCTSurfaceRef surface, double u) {
    if (!surface) return nullptr;
    try {
        Handle(Geom_SphericalSurface) s = Handle(Geom_SphericalSurface)::DownCast(surface->surface);
        if (s.IsNull()) return nullptr;
        Handle(Geom_Curve) iso = s->UIso(u);
        if (iso.IsNull()) return nullptr;
        return new OCCTCurve3D(iso);
    } catch (...) { return nullptr; }
}

OCCTCurve3DRef OCCTSurfaceSphereVIso(OCCTSurfaceRef surface, double v) {
    if (!surface) return nullptr;
    try {
        Handle(Geom_SphericalSurface) s = Handle(Geom_SphericalSurface)::DownCast(surface->surface);
        if (s.IsNull()) return nullptr;
        Handle(Geom_Curve) iso = s->VIso(v);
        if (iso.IsNull()) return nullptr;
        return new OCCTCurve3D(iso);
    } catch (...) { return nullptr; }
}

void OCCTSurfaceSphereSphere(OCCTSurfaceRef surface, double* cx, double* cy, double* cz, double* radius) {
    *cx = 0; *cy = 0; *cz = 0; *radius = 0;
    if (!surface) return;
    try {
        Handle(Geom_SphericalSurface) s = Handle(Geom_SphericalSurface)::DownCast(surface->surface);
        if (s.IsNull()) return;
        gp_Sphere sph = s->Sphere();
        gp_Pnt c = sph.Location();
        *cx = c.X(); *cy = c.Y(); *cz = c.Z();
        *radius = sph.Radius();
    } catch (...) {}
}

// MARK: - Geom_ToroidalSurface Methods (v0.108.0)

double OCCTSurfaceTorusMajorRadius(OCCTSurfaceRef surface) {
    if (!surface) return 0;
    try {
        Handle(Geom_ToroidalSurface) t = Handle(Geom_ToroidalSurface)::DownCast(surface->surface);
        if (t.IsNull()) return 0;
        return t->MajorRadius();
    } catch (...) { return 0; }
}

double OCCTSurfaceTorusMinorRadius(OCCTSurfaceRef surface) {
    if (!surface) return 0;
    try {
        Handle(Geom_ToroidalSurface) t = Handle(Geom_ToroidalSurface)::DownCast(surface->surface);
        if (t.IsNull()) return 0;
        return t->MinorRadius();
    } catch (...) { return 0; }
}

bool OCCTSurfaceTorusSetMajorRadius(OCCTSurfaceRef surface, double r) {
    if (!surface) return false;
    try {
        Handle(Geom_ToroidalSurface) t = Handle(Geom_ToroidalSurface)::DownCast(surface->surface);
        if (t.IsNull()) return false;
        t->SetMajorRadius(r);
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceTorusSetMinorRadius(OCCTSurfaceRef surface, double r) {
    if (!surface) return false;
    try {
        Handle(Geom_ToroidalSurface) t = Handle(Geom_ToroidalSurface)::DownCast(surface->surface);
        if (t.IsNull()) return false;
        t->SetMinorRadius(r);
        return true;
    } catch (...) { return false; }
}

double OCCTSurfaceTorusArea(OCCTSurfaceRef surface) {
    if (!surface) return 0;
    try {
        Handle(Geom_ToroidalSurface) t = Handle(Geom_ToroidalSurface)::DownCast(surface->surface);
        if (t.IsNull()) return 0;
        return t->Area();
    } catch (...) { return 0; }
}

double OCCTSurfaceTorusVolume(OCCTSurfaceRef surface) {
    if (!surface) return 0;
    try {
        Handle(Geom_ToroidalSurface) t = Handle(Geom_ToroidalSurface)::DownCast(surface->surface);
        if (t.IsNull()) return 0;
        return t->Volume();
    } catch (...) { return 0; }
}

void OCCTSurfaceTorusAxis(OCCTSurfaceRef surface, double* px, double* py, double* pz, double* dx, double* dy, double* dz) {
    *px = 0; *py = 0; *pz = 0; *dx = 0; *dy = 0; *dz = 1;
    if (!surface) return;
    try {
        Handle(Geom_ToroidalSurface) t = Handle(Geom_ToroidalSurface)::DownCast(surface->surface);
        if (t.IsNull()) return;
        gp_Ax1 a = t->Axis();
        const gp_Pnt& p = a.Location();
        const gp_Dir& d = a.Direction();
        *px = p.X(); *py = p.Y(); *pz = p.Z();
        *dx = d.X(); *dy = d.Y(); *dz = d.Z();
    } catch (...) {}
}
// MARK: - Geom_SurfaceOfRevolution Methods (v0.137)

void OCCTSurfaceRevolutionAxis(OCCTSurfaceRef surface, double* px, double* py, double* pz, double* dx, double* dy, double* dz) {
    *px = 0; *py = 0; *pz = 0; *dx = 0; *dy = 0; *dz = 1;
    if (!surface) return;
    try {
        Handle(Geom_SurfaceOfRevolution) r = Handle(Geom_SurfaceOfRevolution)::DownCast(surface->surface);
        if (r.IsNull()) return;
        gp_Ax1 a = r->Axis();
        const gp_Pnt& p = a.Location();
        const gp_Dir& d = a.Direction();
        *px = p.X(); *py = p.Y(); *pz = p.Z();
        *dx = d.X(); *dy = d.Y(); *dz = d.Z();
    } catch (...) {}
}

void OCCTSurfaceRevolutionLocation(OCCTSurfaceRef surface, double* x, double* y, double* z) {
    *x = 0; *y = 0; *z = 0;
    if (!surface) return;
    try {
        Handle(Geom_SurfaceOfRevolution) r = Handle(Geom_SurfaceOfRevolution)::DownCast(surface->surface);
        if (r.IsNull()) return;
        gp_Pnt p = r->Location();
        *x = p.X(); *y = p.Y(); *z = p.Z();
    } catch (...) {}
}
// MARK: - Geom_CylindricalSurface Methods (v0.108.0)

double OCCTSurfaceCylinderRadius(OCCTSurfaceRef surface) {
    if (!surface) return 0;
    try {
        Handle(Geom_CylindricalSurface) c = Handle(Geom_CylindricalSurface)::DownCast(surface->surface);
        if (c.IsNull()) return 0;
        return c->Radius();
    } catch (...) { return 0; }
}

bool OCCTSurfaceCylinderSetRadius(OCCTSurfaceRef surface, double r) {
    if (!surface) return false;
    try {
        Handle(Geom_CylindricalSurface) c = Handle(Geom_CylindricalSurface)::DownCast(surface->surface);
        if (c.IsNull()) return false;
        c->SetRadius(r);
        return true;
    } catch (...) { return false; }
}

void OCCTSurfaceCylinderAxis(OCCTSurfaceRef surface, double* px, double* py, double* pz, double* dx, double* dy, double* dz) {
    *px = 0; *py = 0; *pz = 0; *dx = 0; *dy = 0; *dz = 0;
    if (!surface) return;
    try {
        Handle(Geom_CylindricalSurface) c = Handle(Geom_CylindricalSurface)::DownCast(surface->surface);
        if (c.IsNull()) return;
        gp_Ax1 ax = c->Cylinder().Axis();
        *px = ax.Location().X(); *py = ax.Location().Y(); *pz = ax.Location().Z();
        *dx = ax.Direction().X(); *dy = ax.Direction().Y(); *dz = ax.Direction().Z();
    } catch (...) {}
}

OCCTCurve3DRef OCCTSurfaceCylinderUIso(OCCTSurfaceRef surface, double u) {
    if (!surface) return nullptr;
    try {
        Handle(Geom_CylindricalSurface) c = Handle(Geom_CylindricalSurface)::DownCast(surface->surface);
        if (c.IsNull()) return nullptr;
        Handle(Geom_Curve) iso = c->UIso(u);
        if (iso.IsNull()) return nullptr;
        return new OCCTCurve3D(iso);
    } catch (...) { return nullptr; }
}

// MARK: - Geom_ConicalSurface Methods (v0.108.0)

double OCCTSurfaceConeSemiAngle(OCCTSurfaceRef surface) {
    if (!surface) return 0;
    try {
        Handle(Geom_ConicalSurface) c = Handle(Geom_ConicalSurface)::DownCast(surface->surface);
        if (c.IsNull()) return 0;
        return c->SemiAngle();
    } catch (...) { return 0; }
}

double OCCTSurfaceConeRefRadius(OCCTSurfaceRef surface) {
    if (!surface) return 0;
    try {
        Handle(Geom_ConicalSurface) c = Handle(Geom_ConicalSurface)::DownCast(surface->surface);
        if (c.IsNull()) return 0;
        return c->RefRadius();
    } catch (...) { return 0; }
}

void OCCTSurfaceConeApex(OCCTSurfaceRef surface, double* x, double* y, double* z) {
    *x = 0; *y = 0; *z = 0;
    if (!surface) return;
    try {
        Handle(Geom_ConicalSurface) c = Handle(Geom_ConicalSurface)::DownCast(surface->surface);
        if (c.IsNull()) return;
        gp_Pnt a = c->Apex();
        *x = a.X(); *y = a.Y(); *z = a.Z();
    } catch (...) {}
}

void OCCTSurfaceConeAxis(OCCTSurfaceRef surface, double* px, double* py, double* pz, double* dx, double* dy, double* dz) {
    *px = 0; *py = 0; *pz = 0; *dx = 0; *dy = 0; *dz = 0;
    if (!surface) return;
    try {
        Handle(Geom_ConicalSurface) c = Handle(Geom_ConicalSurface)::DownCast(surface->surface);
        if (c.IsNull()) return;
        gp_Ax1 ax = c->Cone().Axis();
        *px = ax.Location().X(); *py = ax.Location().Y(); *pz = ax.Location().Z();
        *dx = ax.Direction().X(); *dy = ax.Direction().Y(); *dz = ax.Direction().Z();
    } catch (...) {}
}
// MARK: - Geom_SweptSurface Methods (v0.108.0)

void OCCTSurfaceSweptDirection(OCCTSurfaceRef surface, double* dx, double* dy, double* dz) {
    *dx = 0; *dy = 0; *dz = 0;
    if (!surface) return;
    try {
        Handle(Geom_SweptSurface) sw = Handle(Geom_SweptSurface)::DownCast(surface->surface);
        if (sw.IsNull()) return;
        gp_Dir d = sw->Direction();
        *dx = d.X(); *dy = d.Y(); *dz = d.Z();
    } catch (...) {}
}

OCCTCurve3DRef OCCTSurfaceSweptBasisCurve(OCCTSurfaceRef surface) {
    if (!surface) return nullptr;
    try {
        Handle(Geom_SweptSurface) sw = Handle(Geom_SweptSurface)::DownCast(surface->surface);
        if (sw.IsNull()) return nullptr;
        Handle(Geom_Curve) basis = sw->BasisCurve();
        if (basis.IsNull()) return nullptr;
        return new OCCTCurve3D(basis);
    } catch (...) { return nullptr; }
}

// MARK: - v0.109-v0.111: Extrema_ExtElSS + ExtPElS + Surface Extras + Surface Evaluation + GridEval
// MARK: - Extrema_ExtElSS (v0.109.0)

int32_t OCCTExtremaElSSPlanePlane(double pl1x, double pl1y, double pl1z, double pn1x, double pn1y, double pn1z,
                                    double pl2x, double pl2y, double pl2z, double pn2x, double pn2y, double pn2z,
                                    bool* outIsParallel,
                                    OCCTExtremaElResult* out, int32_t max) {
    *outIsParallel = false;
    try {
        gp_Pln pl1(gp_Pnt(pl1x, pl1y, pl1z), gp_Dir(pn1x, pn1y, pn1z));
        gp_Pln pl2(gp_Pnt(pl2x, pl2y, pl2z), gp_Dir(pn2x, pn2y, pn2z));
        Extrema_ExtElSS ext(pl1, pl2);
        if (!ext.IsDone()) return -1;
        *outIsParallel = ext.IsParallel();
        if (ext.IsParallel()) {
            if (max > 0) {
                out[0].squareDistance = ext.SquareDistance(1);
                out[0].x1 = 0; out[0].y1 = 0; out[0].z1 = 0;
                out[0].x2 = 0; out[0].y2 = 0; out[0].z2 = 0;
            }
            return 1;
        }
        int n = ext.NbExt();
        int count = 0;
        for (int i = 1; i <= n && count < max; i++) {
            Extrema_POnSurf ps1, ps2;
            ext.Points(i, ps1, ps2);
            out[count].squareDistance = ext.SquareDistance(i);
            out[count].x1 = ps1.Value().X(); out[count].y1 = ps1.Value().Y(); out[count].z1 = ps1.Value().Z();
            out[count].x2 = ps2.Value().X(); out[count].y2 = ps2.Value().Y(); out[count].z2 = ps2.Value().Z();
            count++;
        }
        return count;
    } catch (...) { return -1; }
}

int32_t OCCTExtremaElSSPlaneSphere(double plx, double ply, double plz, double pnx, double pny, double pnz,
                                     double cx, double cy, double cz, double radius,
                                     OCCTExtremaElResult* out, int32_t max) {
    try {
        gp_Pln pl(gp_Pnt(plx, ply, plz), gp_Dir(pnx, pny, pnz));
        gp_Sphere sp(gp_Ax3(gp_Pnt(cx, cy, cz), gp_Dir(0, 0, 1)), radius);
        Extrema_ExtElSS ext(pl, sp);
        if (!ext.IsDone()) return -1;
        int n = ext.NbExt();
        int count = 0;
        for (int i = 1; i <= n && count < max; i++) {
            Extrema_POnSurf ps1, ps2;
            ext.Points(i, ps1, ps2);
            out[count].squareDistance = ext.SquareDistance(i);
            out[count].x1 = ps1.Value().X(); out[count].y1 = ps1.Value().Y(); out[count].z1 = ps1.Value().Z();
            out[count].x2 = ps2.Value().X(); out[count].y2 = ps2.Value().Y(); out[count].z2 = ps2.Value().Z();
            count++;
        }
        return count;
    } catch (...) { return -1; }
}

int32_t OCCTExtremaElSSSphereSphere(double c1x, double c1y, double c1z, double r1,
                                      double c2x, double c2y, double c2z, double r2,
                                      OCCTExtremaElResult* out, int32_t max) {
    try {
        gp_Sphere sp1(gp_Ax3(gp_Pnt(c1x, c1y, c1z), gp_Dir(0, 0, 1)), r1);
        gp_Sphere sp2(gp_Ax3(gp_Pnt(c2x, c2y, c2z), gp_Dir(0, 0, 1)), r2);
        Extrema_ExtElSS ext(sp1, sp2);
        if (!ext.IsDone()) return -1;
        int n = ext.NbExt();
        int count = 0;
        for (int i = 1; i <= n && count < max; i++) {
            Extrema_POnSurf ps1, ps2;
            ext.Points(i, ps1, ps2);
            out[count].squareDistance = ext.SquareDistance(i);
            out[count].x1 = ps1.Value().X(); out[count].y1 = ps1.Value().Y(); out[count].z1 = ps1.Value().Z();
            out[count].x2 = ps2.Value().X(); out[count].y2 = ps2.Value().Y(); out[count].z2 = ps2.Value().Z();
            count++;
        }
        return count;
    } catch (...) { return -1; }
}
// MARK: - Extrema_ExtPElS (v0.109.0)

int32_t OCCTExtremaExtPElSPlane(double px, double py, double pz,
                                  double plx, double ply, double plz, double pnx, double pny, double pnz,
                                  double tolerance,
                                  OCCTExtremaElResult* out, int32_t max) {
    try {
        gp_Pnt p(px, py, pz);
        gp_Pln pl(gp_Pnt(plx, ply, plz), gp_Dir(pnx, pny, pnz));
        Extrema_ExtPElS ext(p, pl, tolerance);
        if (!ext.IsDone()) return -1;
        int n = ext.NbExt();
        int count = 0;
        for (int i = 1; i <= n && count < max; i++) {
            out[count].squareDistance = ext.SquareDistance(i);
            gp_Pnt pt = ext.Point(i).Value();
            out[count].x1 = px; out[count].y1 = py; out[count].z1 = pz;
            out[count].x2 = pt.X(); out[count].y2 = pt.Y(); out[count].z2 = pt.Z();
            count++;
        }
        return count;
    } catch (...) { return -1; }
}

int32_t OCCTExtremaExtPElSSphere(double px, double py, double pz,
                                   double cx, double cy, double cz, double radius,
                                   double tolerance,
                                   OCCTExtremaElResult* out, int32_t max) {
    try {
        gp_Pnt p(px, py, pz);
        gp_Sphere sp(gp_Ax3(gp_Pnt(cx, cy, cz), gp_Dir(0, 0, 1)), radius);
        Extrema_ExtPElS ext(p, sp, tolerance);
        if (!ext.IsDone()) return -1;
        int n = ext.NbExt();
        int count = 0;
        for (int i = 1; i <= n && count < max; i++) {
            out[count].squareDistance = ext.SquareDistance(i);
            gp_Pnt pt = ext.Point(i).Value();
            out[count].x1 = px; out[count].y1 = py; out[count].z1 = pz;
            out[count].x2 = pt.X(); out[count].y2 = pt.Y(); out[count].z2 = pt.Z();
            count++;
        }
        return count;
    } catch (...) { return -1; }
}

int32_t OCCTExtremaExtPElSCylinder(double px, double py, double pz,
                                     double cx, double cy, double cz, double nx, double ny, double nz, double radius,
                                     double tolerance,
                                     OCCTExtremaElResult* out, int32_t max) {
    try {
        gp_Pnt p(px, py, pz);
        gp_Cylinder cyl(gp_Ax3(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz)), radius);
        Extrema_ExtPElS ext(p, cyl, tolerance);
        if (!ext.IsDone()) return -1;
        int n = ext.NbExt();
        int count = 0;
        for (int i = 1; i <= n && count < max; i++) {
            out[count].squareDistance = ext.SquareDistance(i);
            gp_Pnt pt = ext.Point(i).Value();
            out[count].x1 = px; out[count].y1 = py; out[count].z1 = pz;
            out[count].x2 = pt.X(); out[count].y2 = pt.Y(); out[count].z2 = pt.Z();
            count++;
        }
        return count;
    } catch (...) { return -1; }
}

int32_t OCCTExtremaExtPElSCone(double px, double py, double pz,
                                 double cx, double cy, double cz, double nx, double ny, double nz,
                                 double semiAngle, double refRadius,
                                 double tolerance,
                                 OCCTExtremaElResult* out, int32_t max) {
    try {
        gp_Pnt p(px, py, pz);
        gp_Cone cone(gp_Ax3(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz)), semiAngle, refRadius);
        Extrema_ExtPElS ext(p, cone, tolerance);
        if (!ext.IsDone()) return -1;
        int n = ext.NbExt();
        int count = 0;
        for (int i = 1; i <= n && count < max; i++) {
            out[count].squareDistance = ext.SquareDistance(i);
            gp_Pnt pt = ext.Point(i).Value();
            out[count].x1 = px; out[count].y1 = py; out[count].z1 = pz;
            out[count].x2 = pt.X(); out[count].y2 = pt.Y(); out[count].z2 = pt.Z();
            count++;
        }
        return count;
    } catch (...) { return -1; }
}

int32_t OCCTExtremaExtPElSTorus(double px, double py, double pz,
                                  double cx, double cy, double cz, double nx, double ny, double nz,
                                  double majorRadius, double minorRadius,
                                  double tolerance,
                                  OCCTExtremaElResult* out, int32_t max) {
    try {
        gp_Pnt p(px, py, pz);
        gp_Torus tor(gp_Ax3(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz)), majorRadius, minorRadius);
        Extrema_ExtPElS ext(p, tor, tolerance);
        if (!ext.IsDone()) return -1;
        int n = ext.NbExt();
        int count = 0;
        for (int i = 1; i <= n && count < max; i++) {
            out[count].squareDistance = ext.SquareDistance(i);
            gp_Pnt pt = ext.Point(i).Value();
            out[count].x1 = px; out[count].y1 = py; out[count].z1 = pz;
            out[count].x2 = pt.X(); out[count].y2 = pt.Y(); out[count].z2 = pt.Z();
            count++;
        }
        return count;
    } catch (...) { return -1; }
}
// MARK: - Surface Extras (v0.109.0)

void OCCTSurfaceBounds(OCCTSurfaceRef surface,
                        double* uMin, double* uMax,
                        double* vMin, double* vMax) {
    *uMin = 0; *uMax = 0; *vMin = 0; *vMax = 0;
    if (!surface) return;
    try {
        surface->surface->Bounds(*uMin, *uMax, *vMin, *vMax);
    } catch (...) {}
}

int32_t OCCTSurfaceContinuity(OCCTSurfaceRef surface) {
    if (!surface) return -1;
    try {
        GeomAbs_Shape cont = surface->surface->Continuity();
        switch (cont) {
            case GeomAbs_C0: return 0;
            case GeomAbs_C1: return 1;
            case GeomAbs_C2: return 2;
            case GeomAbs_C3: return 3;
            case GeomAbs_CN: return 99;
            case GeomAbs_G1: return -2;
            case GeomAbs_G2: return -3;
            default: return -1;
        }
    } catch (...) { return -1; }
}

OCCTSurfaceRef OCCTSurfaceCopy(OCCTSurfaceRef surface) {
    if (!surface) return nullptr;
    try {
        Handle(Geom_Surface) copy = Handle(Geom_Surface)::DownCast(surface->surface->Copy());
        if (copy.IsNull()) return nullptr;
        return new OCCTSurface(copy);
    } catch (...) { return nullptr; }
}
// MARK: - Surface Evaluation (v0.110.0)

void OCCTSurfaceEvalD0(OCCTSurfaceRef surface, double u, double v,
                         double* x, double* y, double* z) {
    *x = 0; *y = 0; *z = 0;
    if (!surface || surface->surface.IsNull()) return;
    try {
        gp_Pnt p = surface->surface->EvalD0(u, v);
        *x = p.X(); *y = p.Y(); *z = p.Z();
    } catch (...) {}
}

void OCCTSurfaceEvalD1(OCCTSurfaceRef surface, double u, double v,
                         double* px, double* py, double* pz,
                         double* d1ux, double* d1uy, double* d1uz,
                         double* d1vx, double* d1vy, double* d1vz) {
    *px = 0; *py = 0; *pz = 0;
    *d1ux = 0; *d1uy = 0; *d1uz = 0;
    *d1vx = 0; *d1vy = 0; *d1vz = 0;
    if (!surface || surface->surface.IsNull()) return;
    try {
        Geom_Surface::ResD1 r = surface->surface->EvalD1(u, v);
        *px = r.Point.X(); *py = r.Point.Y(); *pz = r.Point.Z();
        *d1ux = r.D1U.X(); *d1uy = r.D1U.Y(); *d1uz = r.D1U.Z();
        *d1vx = r.D1V.X(); *d1vy = r.D1V.Y(); *d1vz = r.D1V.Z();
    } catch (...) {}
}

void OCCTSurfaceEvalD2(OCCTSurfaceRef surface, double u, double v,
                         double* px, double* py, double* pz,
                         double* d1ux, double* d1uy, double* d1uz,
                         double* d1vx, double* d1vy, double* d1vz,
                         double* d2ux, double* d2uy, double* d2uz,
                         double* d2vx, double* d2vy, double* d2vz,
                         double* d2uvx, double* d2uvy, double* d2uvz) {
    *px = 0; *py = 0; *pz = 0;
    *d1ux = 0; *d1uy = 0; *d1uz = 0;
    *d1vx = 0; *d1vy = 0; *d1vz = 0;
    *d2ux = 0; *d2uy = 0; *d2uz = 0;
    *d2vx = 0; *d2vy = 0; *d2vz = 0;
    *d2uvx = 0; *d2uvy = 0; *d2uvz = 0;
    if (!surface || surface->surface.IsNull()) return;
    try {
        Geom_Surface::ResD2 r = surface->surface->EvalD2(u, v);
        *px = r.Point.X(); *py = r.Point.Y(); *pz = r.Point.Z();
        *d1ux = r.D1U.X(); *d1uy = r.D1U.Y(); *d1uz = r.D1U.Z();
        *d1vx = r.D1V.X(); *d1vy = r.D1V.Y(); *d1vz = r.D1V.Z();
        *d2ux = r.D2U.X(); *d2uy = r.D2U.Y(); *d2uz = r.D2U.Z();
        *d2vx = r.D2V.X(); *d2vy = r.D2V.Y(); *d2vz = r.D2V.Z();
        *d2uvx = r.D2UV.X(); *d2uvy = r.D2UV.Y(); *d2uvz = r.D2UV.Z();
    } catch (...) {}
}
// MARK: - GeomGridEval_Surface (v0.111.0)

void OCCTGridEvalSurfaceD0(OCCTSurfaceRef surface, const double* uParams, int32_t uCount,
                              const double* vParams, int32_t vCount,
                              double* xs, double* ys, double* zs) {
    if (!surface || surface->surface.IsNull() || uCount <= 0 || vCount <= 0) return;
    try {
        GeomGridEval_Surface eval(surface->surface);
        NCollection_Array1<double> uArr(1, uCount), vArr(1, vCount);
        for (int i = 0; i < uCount; i++) uArr(i+1) = uParams[i];
        for (int i = 0; i < vCount; i++) vArr(i+1) = vParams[i];
        NCollection_Array2<gp_Pnt> results = eval.EvaluateGrid(uArr, vArr);
        for (int iu = 0; iu < uCount; iu++) {
            for (int iv = 0; iv < vCount; iv++) {
                int idx = iu * vCount + iv;
                const gp_Pnt& p = results(iu+1, iv+1);
                xs[idx] = p.X(); ys[idx] = p.Y(); zs[idx] = p.Z();
            }
        }
    } catch (...) {}
}

void OCCTGridEvalSurfaceD1(OCCTSurfaceRef surface, const double* uParams, int32_t uCount,
                              const double* vParams, int32_t vCount,
                              double* xs, double* ys, double* zs,
                              double* d1uxs, double* d1uys, double* d1uzs,
                              double* d1vxs, double* d1vys, double* d1vzs) {
    if (!surface || surface->surface.IsNull() || uCount <= 0 || vCount <= 0) return;
    try {
        GeomGridEval_Surface eval(surface->surface);
        NCollection_Array1<double> uArr(1, uCount), vArr(1, vCount);
        for (int i = 0; i < uCount; i++) uArr(i+1) = uParams[i];
        for (int i = 0; i < vCount; i++) vArr(i+1) = vParams[i];
        NCollection_Array2<GeomGridEval::SurfD1> results = eval.EvaluateGridD1(uArr, vArr);
        for (int iu = 0; iu < uCount; iu++) {
            for (int iv = 0; iv < vCount; iv++) {
                int idx = iu * vCount + iv;
                const auto& r = results(iu+1, iv+1);
                xs[idx] = r.Point.X(); ys[idx] = r.Point.Y(); zs[idx] = r.Point.Z();
                d1uxs[idx] = r.D1U.X(); d1uys[idx] = r.D1U.Y(); d1uzs[idx] = r.D1U.Z();
                d1vxs[idx] = r.D1V.X(); d1vys[idx] = r.D1V.Y(); d1vzs[idx] = r.D1V.Z();
            }
        }
    } catch (...) {}
}

// MARK: - v0.112: BiTgte_CurveOnEdge + Surface extras
// --- BiTgte_CurveOnEdge ---

struct OCCTBiTgteCurveOnEdge {
    BiTgte_CurveOnEdge curve;
    OCCTBiTgteCurveOnEdge(const TopoDS_Edge& e1, const TopoDS_Edge& e2)
        : curve(e1, e2) {}
};

OCCTBiTgteCurveOnEdgeRef OCCTBiTgteCurveOnEdgeCreate(OCCTShapeRef edgeOnFace, OCCTShapeRef edge) {
    if (!edgeOnFace || !edge) return nullptr;
    try {
        TopoDS_Edge e1 = TopoDS::Edge(edgeOnFace->shape);
        TopoDS_Edge e2 = TopoDS::Edge(edge->shape);
        return new OCCTBiTgteCurveOnEdge(e1, e2);
    } catch (...) { return nullptr; }
}

void OCCTBiTgteCurveOnEdgeRelease(OCCTBiTgteCurveOnEdgeRef curve) { delete curve; }

void OCCTBiTgteCurveOnEdgeDomain(OCCTBiTgteCurveOnEdgeRef curve,
                                 double* first, double* last) {
    if (!curve) return;
    try {
        *first = curve->curve.FirstParameter();
        *last = curve->curve.LastParameter();
    } catch (...) {}
}

void OCCTBiTgteCurveOnEdgeValue(OCCTBiTgteCurveOnEdgeRef curve, double u,
                                double* x, double* y, double* z) {
    if (!curve) return;
    try {
        gp_Pnt p;
        curve->curve.D0(u, p);
        *x = p.X(); *y = p.Y(); *z = p.Z();
    } catch (...) {}
}
// --- Surface extras ---

int32_t OCCTSurfaceGetType(OCCTSurfaceRef surface) {
    if (!surface || surface->surface.IsNull()) return 10; // OtherSurface
    try {
        GeomAdaptor_Surface as(surface->surface);
        return (int32_t)as.GetType();
    } catch (...) { return 10; }
}

// MARK: - v0.113: GeomAPI_ProjectPointOnSurf (multi-result) + GeomAPI_IntCS + BSplineSurface mutations
// --- GeomAPI_ProjectPointOnSurf (multi-result) ---

struct OCCTProjOnSurf {
    GeomAPI_ProjectPointOnSurf proj;
};

OCCTProjOnSurfRef OCCTProjOnSurfCreate(OCCTSurfaceRef surface, double px, double py, double pz) {
    if (!surface || surface->surface.IsNull()) return nullptr;
    try {
        auto ref = new OCCTProjOnSurf();
        ref->proj.Init(gp_Pnt(px, py, pz), surface->surface);
        return ref;
    } catch (...) { return nullptr; }
}

void OCCTProjOnSurfRelease(OCCTProjOnSurfRef proj) {
    delete proj;
}

int32_t OCCTProjOnSurfNbPoints(OCCTProjOnSurfRef proj) {
    if (!proj) return 0;
    try { return (int32_t)proj->proj.NbPoints(); }
    catch (...) { return 0; }
}

void OCCTProjOnSurfPoint(OCCTProjOnSurfRef proj, int32_t index,
                          double* x, double* y, double* z) {
    if (!proj) { *x = *y = *z = 0; return; }
    try {
        gp_Pnt p = proj->proj.Point(index);
        *x = p.X(); *y = p.Y(); *z = p.Z();
    } catch (...) { *x = *y = *z = 0; }
}

void OCCTProjOnSurfParameters(OCCTProjOnSurfRef proj, int32_t index,
                               double* u, double* v) {
    if (!proj) { *u = *v = 0; return; }
    try { proj->proj.Parameters(index, *u, *v); }
    catch (...) { *u = *v = 0; }
}

double OCCTProjOnSurfDistance(OCCTProjOnSurfRef proj, int32_t index) {
    if (!proj) return -1;
    try { return proj->proj.Distance(index); }
    catch (...) { return -1; }
}

double OCCTProjOnSurfLowerDistance(OCCTProjOnSurfRef proj) {
    if (!proj) return -1;
    try { return proj->proj.LowerDistance(); }
    catch (...) { return -1; }
}

void OCCTProjOnSurfLowerParams(OCCTProjOnSurfRef proj, double* u, double* v) {
    if (!proj) { *u = *v = 0; return; }
    try { proj->proj.LowerDistanceParameters(*u, *v); }
    catch (...) { *u = *v = 0; }
}
// --- GeomAPI_IntCS full results ---

struct OCCTIntCS {
    GeomAPI_IntCS intcs;
};

OCCTIntCSRef OCCTIntCSCreate(OCCTCurve3DRef curve, OCCTSurfaceRef surface) {
    if (!curve || curve->curve.IsNull() || !surface || surface->surface.IsNull()) return nullptr;
    try {
        auto ref = new OCCTIntCS();
        ref->intcs.Perform(curve->curve, surface->surface);
        return ref;
    } catch (...) { return nullptr; }
}

void OCCTIntCSRelease(OCCTIntCSRef intcs) {
    delete intcs;
}

int32_t OCCTIntCSNbPoints(OCCTIntCSRef intcs) {
    if (!intcs) return 0;
    try { return (int32_t)intcs->intcs.NbPoints(); }
    catch (...) { return 0; }
}

void OCCTIntCSPoint(OCCTIntCSRef intcs, int32_t index,
                     double* x, double* y, double* z,
                     double* w, double* u, double* v) {
    if (!intcs) { *x = *y = *z = *w = *u = *v = 0; return; }
    try {
        gp_Pnt p = intcs->intcs.Point(index);
        *x = p.X(); *y = p.Y(); *z = p.Z();
        intcs->intcs.Parameters(index, *u, *v, *w);
    } catch (...) { *x = *y = *z = *w = *u = *v = 0; }
}

int32_t OCCTIntCSNbSegments(OCCTIntCSRef intcs) {
    if (!intcs) return 0;
    try { return (int32_t)intcs->intcs.NbSegments(); }
    catch (...) { return 0; }
}
// --- BSplineSurface remaining mutations ---

bool OCCTSurfaceBSplineSetUKnot(OCCTSurfaceRef surface, int32_t index, double knot) {
    if (!surface || surface->surface.IsNull()) return false;
    try {
        Handle(Geom_BSplineSurface) bss = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
        if (bss.IsNull()) return false;
        bss->SetUKnot(index, knot);
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBSplineSetVKnot(OCCTSurfaceRef surface, int32_t index, double knot) {
    if (!surface || surface->surface.IsNull()) return false;
    try {
        Handle(Geom_BSplineSurface) bss = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
        if (bss.IsNull()) return false;
        bss->SetVKnot(index, knot);
        return true;
    } catch (...) { return false; }
}

void OCCTSurfaceBSplineGetUKnots(OCCTSurfaceRef surface, double* knots) {
    if (!surface || surface->surface.IsNull()) return;
    try {
        Handle(Geom_BSplineSurface) bss = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
        if (bss.IsNull()) return;
        TColStd_Array1OfReal k(1, bss->NbUKnots());
        bss->UKnots(k);
        for (int i = 1; i <= k.Length(); i++) knots[i - 1] = k(i);
    } catch (...) {}
}

void OCCTSurfaceBSplineGetVKnots(OCCTSurfaceRef surface, double* knots) {
    if (!surface || surface->surface.IsNull()) return;
    try {
        Handle(Geom_BSplineSurface) bss = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
        if (bss.IsNull()) return;
        TColStd_Array1OfReal k(1, bss->NbVKnots());
        bss->VKnots(k);
        for (int i = 1; i <= k.Length(); i++) knots[i - 1] = k(i);
    } catch (...) {}
}

void OCCTSurfaceBSplineGetWeights(OCCTSurfaceRef surface, double* weights,
                                    int32_t* rows, int32_t* cols) {
    if (!surface || surface->surface.IsNull()) { *rows = *cols = 0; return; }
    try {
        Handle(Geom_BSplineSurface) bss = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
        if (bss.IsNull()) { *rows = *cols = 0; return; }
        int nr = bss->NbUPoles(), nc = bss->NbVPoles();
        *rows = nr; *cols = nc;
        TColStd_Array2OfReal w(1, nr, 1, nc);
        bss->Weights(w);
        int idx = 0;
        for (int i = 1; i <= nr; i++)
            for (int j = 1; j <= nc; j++)
                weights[idx++] = w(i, j);
    } catch (...) { *rows = *cols = 0; }
}

bool OCCTSurfaceBSplineRemoveUKnot(OCCTSurfaceRef surface, int32_t index, int32_t mult, double tol) {
    if (!surface || surface->surface.IsNull()) return false;
    try {
        Handle(Geom_BSplineSurface) bss = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
        if (bss.IsNull()) return false;
        return bss->RemoveUKnot(index, mult, tol);
    } catch (...) { return false; }
}


// MARK: - v0.114: Surface DN + type-name

void OCCTSurfaceDN(OCCTSurfaceRef surface, double u, double v,
                    int32_t nu, int32_t nv,
                    double* x, double* y, double* z) {
    if (!surface || surface->surface.IsNull()) { *x = *y = *z = 0; return; }
    try {
        gp_Vec vec = surface->surface->DN(u, v, nu, nv);
        *x = vec.X(); *y = vec.Y(); *z = vec.Z();
    } catch (...) { *x = *y = *z = 0; }
}
const char* OCCTSurfaceTypeName(OCCTSurfaceRef surface) {
    if (!surface || surface->surface.IsNull()) return nullptr;
    try {
        return surface->surface->DynamicType()->Name();
    } catch (...) { return nullptr; }
}

// MARK: - v0.115: Surface additional (Normal + Curvatures)
// --- Surface additional (new in v0.115.0) ---

void OCCTSurfaceNormal(OCCTSurfaceRef surface, double u, double v,
                         double* nx, double* ny, double* nz) {
    *nx = *ny = *nz = 0;
    if (!surface || surface->surface.IsNull()) return;
    try {
        gp_Pnt p;
        gp_Vec d1u, d1v;
        surface->surface->D1(u, v, p, d1u, d1v);
        gp_Vec normal = d1u.Crossed(d1v);
        if (normal.Magnitude() > 1e-15) {
            normal.Normalize();
            *nx = normal.X(); *ny = normal.Y(); *nz = normal.Z();
        }
    } catch (...) {}
}

#include <GeomLProp_SLProps.hxx>

void OCCTSurfaceCurvatures(OCCTSurfaceRef surface, double u, double v,
                             double* gaussian, double* mean) {
    *gaussian = *mean = 0;
    if (!surface || surface->surface.IsNull()) return;
    try {
        GeomLProp_SLProps props(surface->surface, u, v, 2, 1e-6);
        if (props.IsCurvatureDefined()) {
            *gaussian = props.GaussianCurvature();
            *mean = props.MeanCurvature();
        }
    } catch (...) {}
}

// end of v0.115.0 implementations

// MARK: - v0.115: PointsToSurfaceBSpline (re-routed from Curve3D)

// Helper duplicate of mapContinuityV115
static GeomAbs_Shape mapContinuityV115(int32_t c) {
    switch (c) {
        case 0: return GeomAbs_C0;
        case 1: return GeomAbs_C1;
        case 2: return GeomAbs_C2;
        case 3: return GeomAbs_C3;
        default: return GeomAbs_C2;
    }
}

OCCTSurfaceRef OCCTPointsToSurfaceBSpline(const double* points, int32_t uCount, int32_t vCount,
                                            int32_t degMin, int32_t degMax,
                                            int32_t continuity, double tol) {
    if (!points || uCount < 2 || vCount < 2) return nullptr;
    try {
        TColgp_Array2OfPnt pts(1, uCount, 1, vCount);
        for (int v = 0; v < vCount; v++) {
            for (int u = 0; u < uCount; u++) {
                int idx = (v * uCount + u) * 3;
                pts.SetValue(u + 1, v + 1, gp_Pnt(points[idx], points[idx+1], points[idx+2]));
            }
        }
        GeomAPI_PointsToBSplineSurface approx(pts, degMin, degMax, mapContinuityV115(continuity), tol);
        if (approx.IsDone()) {
            return (OCCTSurfaceRef)new OCCTSurface{approx.Surface()};
        }
        return nullptr;
    } catch (...) { return nullptr; }
}
// --- GeomConvert utilities ---

// MARK: - v0.116: Surface Local Curvatures + Curvature Directions
void OCCTSurfaceLocalCurvatures(OCCTSurfaceRef _Nonnull surface, double u, double v,
                                  double* _Nonnull gaussian, double* _Nonnull mean,
                                  double* _Nonnull maxCurvature, double* _Nonnull minCurvature,
                                  bool* _Nonnull isDefined) {
    try {
        GeomLProp_SLProps props(surface->surface, u, v, 2, 1e-10);
        *isDefined = props.IsCurvatureDefined();
        if (*isDefined) {
            *gaussian = props.GaussianCurvature();
            *mean = props.MeanCurvature();
            *maxCurvature = props.MaxCurvature();
            *minCurvature = props.MinCurvature();
        } else {
            *gaussian = 0; *mean = 0; *maxCurvature = 0; *minCurvature = 0;
        }
    } catch (...) { *isDefined = false; *gaussian = 0; *mean = 0; *maxCurvature = 0; *minCurvature = 0; }
}

void OCCTSurfaceLocalCurvatureDirections(OCCTSurfaceRef _Nonnull surface, double u, double v,
                                           double* _Nonnull maxDx, double* _Nonnull maxDy, double* _Nonnull maxDz,
                                           double* _Nonnull minDx, double* _Nonnull minDy, double* _Nonnull minDz,
                                           bool* _Nonnull isDefined) {
    try {
        GeomLProp_SLProps props(surface->surface, u, v, 2, 1e-10);
        *isDefined = props.IsCurvatureDefined() && !props.IsUmbilic();
        if (*isDefined) {
            gp_Dir maxD, minD;
            props.CurvatureDirections(maxD, minD);
            *maxDx = maxD.X(); *maxDy = maxD.Y(); *maxDz = maxD.Z();
            *minDx = minD.X(); *minDy = minD.Y(); *minDz = minD.Z();
        } else {
            *maxDx = 0; *maxDy = 0; *maxDz = 0;
            *minDx = 0; *minDy = 0; *minDz = 0;
        }
    } catch (...) {
        *isDefined = false;
        *maxDx = 0; *maxDy = 0; *maxDz = 0;
        *minDx = 0; *minDy = 0; *minDz = 0;
    }
}

// ProjLib

#include <ProjLib_Plane.hxx>
#include <ProjLib_Cylinder.hxx>
#include <gp_Pln.hxx>
#include <gp_Lin.hxx>
#include <gp_Circ.hxx>
#include <gp_Ax3.hxx>

// MARK: - v0.118: Geom_BezierSurface + BSplineSurface extras
// --- Geom_BezierSurface ---

int32_t OCCTSurfaceBezierNbUPoles(OCCTSurfaceRef surface) {
    try {
        auto* s = static_cast<OCCTSurface*>(surface);
        auto bezier = occ::handle<Geom_BezierSurface>::DownCast(s->surface);
        if (bezier.IsNull()) return 0;
        return (int32_t)bezier->NbUPoles();
    } catch (...) { return 0; }
}

int32_t OCCTSurfaceBezierNbVPoles(OCCTSurfaceRef surface) {
    try {
        auto* s = static_cast<OCCTSurface*>(surface);
        auto bezier = occ::handle<Geom_BezierSurface>::DownCast(s->surface);
        if (bezier.IsNull()) return 0;
        return (int32_t)bezier->NbVPoles();
    } catch (...) { return 0; }
}

int32_t OCCTSurfaceBezierUDegree(OCCTSurfaceRef surface) {
    try {
        auto* s = static_cast<OCCTSurface*>(surface);
        auto bezier = occ::handle<Geom_BezierSurface>::DownCast(s->surface);
        if (bezier.IsNull()) return -1;
        return (int32_t)bezier->UDegree();
    } catch (...) { return -1; }
}

int32_t OCCTSurfaceBezierVDegree(OCCTSurfaceRef surface) {
    try {
        auto* s = static_cast<OCCTSurface*>(surface);
        auto bezier = occ::handle<Geom_BezierSurface>::DownCast(s->surface);
        if (bezier.IsNull()) return -1;
        return (int32_t)bezier->VDegree();
    } catch (...) { return -1; }
}

void OCCTSurfaceBezierGetPole(OCCTSurfaceRef surface, int32_t uIndex, int32_t vIndex,
                              double* x, double* y, double* z) {
    try {
        auto* s = static_cast<OCCTSurface*>(surface);
        auto bezier = occ::handle<Geom_BezierSurface>::DownCast(s->surface);
        if (bezier.IsNull()) { *x = *y = *z = 0; return; }
        gp_Pnt p = bezier->Pole(uIndex, vIndex);
        *x = p.X(); *y = p.Y(); *z = p.Z();
    } catch (...) { *x = *y = *z = 0; }
}

bool OCCTSurfaceBezierSetPole(OCCTSurfaceRef surface, int32_t uIndex, int32_t vIndex,
                              double x, double y, double z) {
    try {
        auto* s = static_cast<OCCTSurface*>(surface);
        auto bezier = occ::handle<Geom_BezierSurface>::DownCast(s->surface);
        if (bezier.IsNull()) return false;
        bezier->SetPole(uIndex, vIndex, gp_Pnt(x, y, z));
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBezierSetWeight(OCCTSurfaceRef surface, int32_t uIndex, int32_t vIndex,
                                double weight) {
    try {
        auto* s = static_cast<OCCTSurface*>(surface);
        auto bezier = occ::handle<Geom_BezierSurface>::DownCast(s->surface);
        if (bezier.IsNull()) return false;
        bezier->SetWeight(uIndex, vIndex, weight);
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBezierSegment(OCCTSurfaceRef surface,
                              double u1, double u2, double v1, double v2) {
    try {
        auto* s = static_cast<OCCTSurface*>(surface);
        auto bezier = occ::handle<Geom_BezierSurface>::DownCast(s->surface);
        if (bezier.IsNull()) return false;
        bezier->Segment(u1, u2, v1, v2);
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBezierIsURational(OCCTSurfaceRef surface) {
    try {
        auto* s = static_cast<OCCTSurface*>(surface);
        auto bezier = occ::handle<Geom_BezierSurface>::DownCast(s->surface);
        if (bezier.IsNull()) return false;
        return bezier->IsURational();
    } catch (...) { return false; }
}

bool OCCTSurfaceBezierIsVRational(OCCTSurfaceRef surface) {
    try {
        auto* s = static_cast<OCCTSurface*>(surface);
        auto bezier = occ::handle<Geom_BezierSurface>::DownCast(s->surface);
        if (bezier.IsNull()) return false;
        return bezier->IsVRational();
    } catch (...) { return false; }
}

bool OCCTSurfaceBezierExchangeUV(OCCTSurfaceRef surface) {
    try {
        auto* s = static_cast<OCCTSurface*>(surface);
        auto bezier = occ::handle<Geom_BezierSurface>::DownCast(s->surface);
        if (bezier.IsNull()) return false;
        bezier->ExchangeUV();
        return true;
    } catch (...) { return false; }
}
// --- BSplineSurface extras ---

void OCCTSurfaceBSplineResolution(OCCTSurfaceRef surface, double tolerance3d,
                                  double* uResolution, double* vResolution) {
    try {
        auto* s = static_cast<OCCTSurface*>(surface);
        auto bsp = occ::handle<Geom_BSplineSurface>::DownCast(s->surface);
        if (bsp.IsNull()) { *uResolution = *vResolution = 0; return; }
        bsp->Resolution(tolerance3d, *uResolution, *vResolution);
    } catch (...) { *uResolution = *vResolution = 0; }
}

bool OCCTSurfaceBSplineSetUPeriodic(OCCTSurfaceRef surface, bool periodic) {
    try {
        auto* s = static_cast<OCCTSurface*>(surface);
        auto bsp = occ::handle<Geom_BSplineSurface>::DownCast(s->surface);
        if (bsp.IsNull()) return false;
        if (periodic) bsp->SetUPeriodic(); else bsp->SetUNotPeriodic();
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBSplineSetVPeriodic(OCCTSurfaceRef surface, bool periodic) {
    try {
        auto* s = static_cast<OCCTSurface*>(surface);
        auto bsp = occ::handle<Geom_BSplineSurface>::DownCast(s->surface);
        if (bsp.IsNull()) return false;
        if (periodic) bsp->SetVPeriodic(); else bsp->SetVNotPeriodic();
        return true;
    } catch (...) { return false; }
}

double OCCTSurfaceBSplineGetWeight(OCCTSurfaceRef surface, int32_t uIndex, int32_t vIndex) {
    try {
        auto* s = static_cast<OCCTSurface*>(surface);
        auto bsp = occ::handle<Geom_BSplineSurface>::DownCast(s->surface);
        if (bsp.IsNull()) return 0;
        return bsp->Weight(uIndex, vIndex);
    } catch (...) { return 0; }
}

// end of v0.119.0 implementations


// MARK: - v0.120: Surface continuity + BSpline RemoveVKnot + Bezier Resolution + MaxDegree + BSplineMaxDegree
// --- Surface continuity queries ---

bool OCCTSurfaceIsCNu(OCCTSurfaceRef _Nonnull surface, int32_t n) {
    try {
        auto s = *(occ::handle<Geom_Surface>*)surface;
        if (s.IsNull()) return false;
        return s->IsCNu(n);
    } catch (...) { return false; }
}

bool OCCTSurfaceIsCNv(OCCTSurfaceRef _Nonnull surface, int32_t n) {
    try {
        auto s = *(occ::handle<Geom_Surface>*)surface;
        if (s.IsNull()) return false;
        return s->IsCNv(n);
    } catch (...) { return false; }
}

OCCTSurfaceRef _Nullable OCCTSurfaceUReversed(OCCTSurfaceRef _Nonnull surface) {
    try {
        auto s = *(occ::handle<Geom_Surface>*)surface;
        if (s.IsNull()) return nullptr;
        auto rev = s->UReversed();
        if (rev.IsNull()) return nullptr;
        auto* result = new occ::handle<Geom_Surface>(rev);
        return (OCCTSurfaceRef)result;
    } catch (...) { return nullptr; }
}

OCCTSurfaceRef _Nullable OCCTSurfaceVReversed(OCCTSurfaceRef _Nonnull surface) {
    try {
        auto s = *(occ::handle<Geom_Surface>*)surface;
        if (s.IsNull()) return nullptr;
        auto rev = s->VReversed();
        if (rev.IsNull()) return nullptr;
        auto* result = new occ::handle<Geom_Surface>(rev);
        return (OCCTSurfaceRef)result;
    } catch (...) { return nullptr; }
}

double OCCTSurfaceUReversedParameter(OCCTSurfaceRef _Nonnull surface, double u) {
    try {
        auto s = *(occ::handle<Geom_Surface>*)surface;
        if (s.IsNull()) return u;
        return s->UReversedParameter(u);
    } catch (...) { return u; }
}

double OCCTSurfaceVReversedParameter(OCCTSurfaceRef _Nonnull surface, double v) {
    try {
        auto s = *(occ::handle<Geom_Surface>*)surface;
        if (s.IsNull()) return v;
        return s->VReversedParameter(v);
    } catch (...) { return v; }
}

// --- BSpline surface RemoveVKnot ---

bool OCCTSurfaceBSplineRemoveVKnot(OCCTSurfaceRef _Nonnull surface,
                                     int32_t index, int32_t mult, double tol) {
    try {
        auto s = *(occ::handle<Geom_Surface>*)surface;
        if (s.IsNull()) return false;
        auto bsp = occ::handle<Geom_BSplineSurface>::DownCast(s);
        if (bsp.IsNull()) return false;
        return bsp->RemoveVKnot(index, mult, tol);
    } catch (...) { return false; }
}
void OCCTSurfaceBezierResolution(OCCTSurfaceRef _Nonnull surface, double tolerance3d,
                                  double* _Nonnull uResolution, double* _Nonnull vResolution) {
    try {
        auto s = *(occ::handle<Geom_Surface>*)surface;
        if (s.IsNull()) { *uResolution = 0; *vResolution = 0; return; }
        auto bez = occ::handle<Geom_BezierSurface>::DownCast(s);
        if (bez.IsNull()) { *uResolution = 0; *vResolution = 0; return; }
        bez->Resolution(tolerance3d, *uResolution, *vResolution);
    } catch (...) { *uResolution = 0; *vResolution = 0; }
}

int32_t OCCTSurfaceBezierMaxDegree(void) {
    return Geom_BezierSurface::MaxDegree();
}
// --- BSpline MaxDegree (surface + 2D curve) ---

int32_t OCCTSurfaceBSplineMaxDegree(void) {
    return Geom_BSplineSurface::MaxDegree();
}

// MARK: - v0.121: BSplineSurface completions
// --- BSplineSurface completions ---

bool OCCTSurfaceBSplineSetUNotPeriodic(OCCTSurfaceRef surface) {
    if (!surface || surface->surface.IsNull()) return false;
    Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return false;
    try { bs->SetUNotPeriodic(); return true; } catch (...) { return false; }
}

bool OCCTSurfaceBSplineSetVNotPeriodic(OCCTSurfaceRef surface) {
    if (!surface || surface->surface.IsNull()) return false;
    Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return false;
    try { bs->SetVNotPeriodic(); return true; } catch (...) { return false; }
}

bool OCCTSurfaceBSplineSetUOrigin(OCCTSurfaceRef surface, int32_t index) {
    if (!surface || surface->surface.IsNull()) return false;
    Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return false;
    try { bs->SetUOrigin(index); return true; } catch (...) { return false; }
}

bool OCCTSurfaceBSplineSetVOrigin(OCCTSurfaceRef surface, int32_t index) {
    if (!surface || surface->surface.IsNull()) return false;
    Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return false;
    try { bs->SetVOrigin(index); return true; } catch (...) { return false; }
}

bool OCCTSurfaceBSplineIncreaseUMultiplicity(OCCTSurfaceRef surface, int32_t index, int32_t mult) {
    if (!surface || surface->surface.IsNull()) return false;
    Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return false;
    try { bs->IncreaseUMultiplicity(index, mult); return true; } catch (...) { return false; }
}

bool OCCTSurfaceBSplineIncreaseVMultiplicity(OCCTSurfaceRef surface, int32_t index, int32_t mult) {
    if (!surface || surface->surface.IsNull()) return false;
    Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return false;
    try { bs->IncreaseVMultiplicity(index, mult); return true; } catch (...) { return false; }
}

bool OCCTSurfaceBSplineInsertUKnots(OCCTSurfaceRef surface,
                                     const double* knots, const int32_t* mults,
                                     int32_t count, double tol) {
    if (!surface || surface->surface.IsNull() || !knots || !mults || count <= 0) return false;
    Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return false;
    try {
        TColStd_Array1OfReal kArr(1, count);
        TColStd_Array1OfInteger mArr(1, count);
        for (int32_t i = 0; i < count; i++) {
            kArr.SetValue(i + 1, knots[i]);
            mArr.SetValue(i + 1, mults[i]);
        }
        bs->InsertUKnots(kArr, mArr, tol);
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBSplineInsertVKnots(OCCTSurfaceRef surface,
                                     const double* knots, const int32_t* mults,
                                     int32_t count, double tol) {
    if (!surface || surface->surface.IsNull() || !knots || !mults || count <= 0) return false;
    Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return false;
    try {
        TColStd_Array1OfReal kArr(1, count);
        TColStd_Array1OfInteger mArr(1, count);
        for (int32_t i = 0; i < count; i++) {
            kArr.SetValue(i + 1, knots[i]);
            mArr.SetValue(i + 1, mults[i]);
        }
        bs->InsertVKnots(kArr, mArr, tol);
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBSplineMovePoint(OCCTSurfaceRef surface,
                                  double u, double v,
                                  double px, double py, double pz,
                                  int32_t uIndex1, int32_t uIndex2,
                                  int32_t vIndex1, int32_t vIndex2) {
    if (!surface || surface->surface.IsNull()) return false;
    Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return false;
    try {
        Standard_Integer uFirstIndex, uLastIndex, vFirstIndex, vLastIndex;
        bs->MovePoint(u, v, gp_Pnt(px, py, pz),
                      uIndex1, uIndex2, vIndex1, vIndex2,
                      uFirstIndex, uLastIndex, vFirstIndex, vLastIndex);
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBSplineSetPoleCol(OCCTSurfaceRef surface,
                                   int32_t vIndex,
                                   const double* coords, int32_t count) {
    if (!surface || surface->surface.IsNull() || !coords || count <= 0) return false;
    Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return false;
    try {
        int32_t nUPoles = bs->NbUPoles();
        if (count != nUPoles) return false;
        TColgp_Array1OfPnt poles(1, nUPoles);
        for (int32_t i = 0; i < nUPoles; i++) {
            poles.SetValue(i + 1, gp_Pnt(coords[i * 3], coords[i * 3 + 1], coords[i * 3 + 2]));
        }
        bs->SetPoleCol(vIndex, poles);
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBSplineSetPoleRow(OCCTSurfaceRef surface,
                                   int32_t uIndex,
                                   const double* coords, int32_t count) {
    if (!surface || surface->surface.IsNull() || !coords || count <= 0) return false;
    Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return false;
    try {
        int32_t nVPoles = bs->NbVPoles();
        if (count != nVPoles) return false;
        TColgp_Array1OfPnt poles(1, nVPoles);
        for (int32_t i = 0; i < nVPoles; i++) {
            poles.SetValue(i + 1, gp_Pnt(coords[i * 3], coords[i * 3 + 1], coords[i * 3 + 2]));
        }
        bs->SetPoleRow(uIndex, poles);
        return true;
    } catch (...) { return false; }
}

// MARK: - v0.122: Surface queries + v0.125: Geom_BSplineSurface + BezierSurface completions
// --- Surface queries ---

double OCCTSurfaceUPeriod(OCCTSurfaceRef surface) {
    if (!surface) return 0.0;
    try {
        if (!surface->surface->IsUPeriodic()) return 0.0;
        return surface->surface->UPeriod();
    } catch (...) { return 0.0; }
}

double OCCTSurfaceVPeriod(OCCTSurfaceRef surface) {
    if (!surface) return 0.0;
    try {
        if (!surface->surface->IsVPeriodic()) return 0.0;
        return surface->surface->VPeriod();
    } catch (...) { return 0.0; }
}
// MARK: - v0.125.0: BSpline/Bezier deep method completion

// --- Geom_BSplineSurface completions ---

void OCCTSurfaceBSplineLocalD0(OCCTSurfaceRef surface, double u, double v,
                                int32_t fromUK1, int32_t toUK2, int32_t fromVK1, int32_t toVK2,
                                double* x, double* y, double* z) {
    if (!surface) return;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return;
    try {
        gp_Pnt P;
        bs->LocalD0(u, v, fromUK1, toUK2, fromVK1, toVK2, P);
        *x = P.X(); *y = P.Y(); *z = P.Z();
    } catch (...) {}
}

void OCCTSurfaceBSplineLocalD1(OCCTSurfaceRef surface, double u, double v,
                                int32_t fromUK1, int32_t toUK2, int32_t fromVK1, int32_t toVK2,
                                double* px, double* py, double* pz,
                                double* d1ux, double* d1uy, double* d1uz,
                                double* d1vx, double* d1vy, double* d1vz) {
    if (!surface) return;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return;
    try {
        gp_Pnt P; gp_Vec D1U, D1V;
        bs->LocalD1(u, v, fromUK1, toUK2, fromVK1, toVK2, P, D1U, D1V);
        *px = P.X(); *py = P.Y(); *pz = P.Z();
        *d1ux = D1U.X(); *d1uy = D1U.Y(); *d1uz = D1U.Z();
        *d1vx = D1V.X(); *d1vy = D1V.Y(); *d1vz = D1V.Z();
    } catch (...) {}
}

void OCCTSurfaceBSplineLocalD2(OCCTSurfaceRef surface, double u, double v,
                                int32_t fromUK1, int32_t toUK2, int32_t fromVK1, int32_t toVK2,
                                double* px, double* py, double* pz,
                                double* d1ux, double* d1uy, double* d1uz,
                                double* d1vx, double* d1vy, double* d1vz,
                                double* d2ux, double* d2uy, double* d2uz,
                                double* d2vx, double* d2vy, double* d2vz,
                                double* d2uvx, double* d2uvy, double* d2uvz) {
    if (!surface) return;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return;
    try {
        gp_Pnt P; gp_Vec D1U, D1V, D2U, D2V, D2UV;
        bs->LocalD2(u, v, fromUK1, toUK2, fromVK1, toVK2, P, D1U, D1V, D2U, D2V, D2UV);
        *px = P.X(); *py = P.Y(); *pz = P.Z();
        *d1ux = D1U.X(); *d1uy = D1U.Y(); *d1uz = D1U.Z();
        *d1vx = D1V.X(); *d1vy = D1V.Y(); *d1vz = D1V.Z();
        *d2ux = D2U.X(); *d2uy = D2U.Y(); *d2uz = D2U.Z();
        *d2vx = D2V.X(); *d2vy = D2V.Y(); *d2vz = D2V.Z();
        *d2uvx = D2UV.X(); *d2uvy = D2UV.Y(); *d2uvz = D2UV.Z();
    } catch (...) {}
}

void OCCTSurfaceBSplineLocalD3(OCCTSurfaceRef surface, double u, double v,
                                int32_t fromUK1, int32_t toUK2, int32_t fromVK1, int32_t toVK2,
                                double* px, double* py, double* pz,
                                double* d1ux, double* d1uy, double* d1uz,
                                double* d1vx, double* d1vy, double* d1vz,
                                double* d2ux, double* d2uy, double* d2uz,
                                double* d2vx, double* d2vy, double* d2vz,
                                double* d2uvx, double* d2uvy, double* d2uvz,
                                double* d3ux, double* d3uy, double* d3uz,
                                double* d3vx, double* d3vy, double* d3vz,
                                double* d3uuvx, double* d3uuvy, double* d3uuvz,
                                double* d3uvvx, double* d3uvvy, double* d3uvvz) {
    if (!surface) return;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return;
    try {
        gp_Pnt P; gp_Vec D1U, D1V, D2U, D2V, D2UV, D3U, D3V, D3UUV, D3UVV;
        bs->LocalD3(u, v, fromUK1, toUK2, fromVK1, toVK2, P, D1U, D1V, D2U, D2V, D2UV, D3U, D3V, D3UUV, D3UVV);
        *px = P.X(); *py = P.Y(); *pz = P.Z();
        *d1ux = D1U.X(); *d1uy = D1U.Y(); *d1uz = D1U.Z();
        *d1vx = D1V.X(); *d1vy = D1V.Y(); *d1vz = D1V.Z();
        *d2ux = D2U.X(); *d2uy = D2U.Y(); *d2uz = D2U.Z();
        *d2vx = D2V.X(); *d2vy = D2V.Y(); *d2vz = D2V.Z();
        *d2uvx = D2UV.X(); *d2uvy = D2UV.Y(); *d2uvz = D2UV.Z();
        *d3ux = D3U.X(); *d3uy = D3U.Y(); *d3uz = D3U.Z();
        *d3vx = D3V.X(); *d3vy = D3V.Y(); *d3vz = D3V.Z();
        *d3uuvx = D3UUV.X(); *d3uuvy = D3UUV.Y(); *d3uuvz = D3UUV.Z();
        *d3uvvx = D3UVV.X(); *d3uvvy = D3UVV.Y(); *d3uvvz = D3UVV.Z();
    } catch (...) {}
}

void OCCTSurfaceBSplineLocalDN(OCCTSurfaceRef surface, double u, double v,
                                int32_t fromUK1, int32_t toUK2, int32_t fromVK1, int32_t toVK2,
                                int32_t nu, int32_t nv,
                                double* vx, double* vy, double* vz) {
    if (!surface) return;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return;
    try {
        gp_Vec V = bs->LocalDN(u, v, fromUK1, toUK2, fromVK1, toVK2, nu, nv);
        *vx = V.X(); *vy = V.Y(); *vz = V.Z();
    } catch (...) {}
}

void OCCTSurfaceBSplineLocalValue(OCCTSurfaceRef surface, double u, double v,
                                   int32_t fromUK1, int32_t toUK2, int32_t fromVK1, int32_t toVK2,
                                   double* x, double* y, double* z) {
    if (!surface) return;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return;
    try {
        gp_Pnt P = bs->LocalValue(u, v, fromUK1, toUK2, fromVK1, toVK2);
        *x = P.X(); *y = P.Y(); *z = P.Z();
    } catch (...) {}
}

OCCTCurve3DRef OCCTSurfaceBSplineUIso(OCCTSurfaceRef surface, double u) {
    if (!surface) return nullptr;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return nullptr;
    try {
        auto curve = bs->UIso(u);
        if (curve.IsNull()) return nullptr;
        auto* ref = new OCCTCurve3D;
        ref->curve = curve;
        return ref;
    } catch (...) { return nullptr; }
}

OCCTCurve3DRef OCCTSurfaceBSplineVIso(OCCTSurfaceRef surface, double v) {
    if (!surface) return nullptr;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return nullptr;
    try {
        auto curve = bs->VIso(v);
        if (curve.IsNull()) return nullptr;
        auto* ref = new OCCTCurve3D;
        ref->curve = curve;
        return ref;
    } catch (...) { return nullptr; }
}

void OCCTSurfaceBSplineLocateU(OCCTSurfaceRef surface, double u, double paramTol,
                                int32_t* i1, int32_t* i2) {
    if (!surface) return;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return;
    try {
        int I1 = 0, I2 = 0;
        bs->LocateU(u, paramTol, I1, I2);
        *i1 = I1; *i2 = I2;
    } catch (...) {}
}

void OCCTSurfaceBSplineLocateV(OCCTSurfaceRef surface, double v, double paramTol,
                                int32_t* i1, int32_t* i2) {
    if (!surface) return;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return;
    try {
        int I1 = 0, I2 = 0;
        bs->LocateV(v, paramTol, I1, I2);
        *i1 = I1; *i2 = I2;
    } catch (...) {}
}

double OCCTSurfaceBSplineUKnot(OCCTSurfaceRef surface, int32_t index) {
    if (!surface) return 0.0;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return 0.0;
    try { return bs->UKnot(index); } catch (...) { return 0.0; }
}

double OCCTSurfaceBSplineVKnot(OCCTSurfaceRef surface, int32_t index) {
    if (!surface) return 0.0;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return 0.0;
    try { return bs->VKnot(index); } catch (...) { return 0.0; }
}

int32_t OCCTSurfaceBSplineUMultiplicity(OCCTSurfaceRef surface, int32_t index) {
    if (!surface) return 0;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return 0;
    try { return bs->UMultiplicity(index); } catch (...) { return 0; }
}

int32_t OCCTSurfaceBSplineVMultiplicity(OCCTSurfaceRef surface, int32_t index) {
    if (!surface) return 0;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return 0;
    try { return bs->VMultiplicity(index); } catch (...) { return 0; }
}

int32_t OCCTSurfaceBSplineUKnotDistribution(OCCTSurfaceRef surface) {
    if (!surface) return 0;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return 0;
    try { return (int32_t)bs->UKnotDistribution(); } catch (...) { return 0; }
}

int32_t OCCTSurfaceBSplineVKnotDistribution(OCCTSurfaceRef surface) {
    if (!surface) return 0;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return 0;
    try { return (int32_t)bs->VKnotDistribution(); } catch (...) { return 0; }
}

void OCCTSurfaceBSplineGetPoles(OCCTSurfaceRef surface, double* poles) {
    if (!surface || !poles) return;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return;
    try {
        const auto& p = bs->Poles();
        int idx = 0;
        for (int i = p.LowerRow(); i <= p.UpperRow(); i++) {
            for (int j = p.LowerCol(); j <= p.UpperCol(); j++) {
                const gp_Pnt& pt = p(i, j);
                poles[idx++] = pt.X();
                poles[idx++] = pt.Y();
                poles[idx++] = pt.Z();
            }
        }
    } catch (...) {}
}

void OCCTSurfaceBSplineBounds(OCCTSurfaceRef surface,
                               double* u1, double* u2, double* v1, double* v2) {
    if (!surface) return;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return;
    try { bs->Bounds(*u1, *u2, *v1, *v2); } catch (...) {}
}

bool OCCTSurfaceBSplineIsUClosed(OCCTSurfaceRef surface) {
    if (!surface) return false;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return false;
    try { return bs->IsUClosed(); } catch (...) { return false; }
}

bool OCCTSurfaceBSplineIsVClosed(OCCTSurfaceRef surface) {
    if (!surface) return false;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return false;
    try { return bs->IsVClosed(); } catch (...) { return false; }
}
// --- Geom_BezierSurface completions ---

OCCTCurve3DRef OCCTSurfaceBezierUIso(OCCTSurfaceRef surface, double u) {
    if (!surface) return nullptr;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return nullptr;
    try {
        auto curve = bz->UIso(u);
        if (curve.IsNull()) return nullptr;
        auto* ref = new OCCTCurve3D;
        ref->curve = curve;
        return ref;
    } catch (...) { return nullptr; }
}

OCCTCurve3DRef OCCTSurfaceBezierVIso(OCCTSurfaceRef surface, double v) {
    if (!surface) return nullptr;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return nullptr;
    try {
        auto curve = bz->VIso(v);
        if (curve.IsNull()) return nullptr;
        auto* ref = new OCCTCurve3D;
        ref->curve = curve;
        return ref;
    } catch (...) { return nullptr; }
}

bool OCCTSurfaceBezierIsUClosed(OCCTSurfaceRef surface) {
    if (!surface) return false;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return false;
    try { return bz->IsUClosed(); } catch (...) { return false; }
}

bool OCCTSurfaceBezierIsVClosed(OCCTSurfaceRef surface) {
    if (!surface) return false;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return false;
    try { return bz->IsVClosed(); } catch (...) { return false; }
}

bool OCCTSurfaceBezierIsUPeriodic(OCCTSurfaceRef surface) {
    if (!surface) return false;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return false;
    try { return bz->IsUPeriodic(); } catch (...) { return false; }
}

bool OCCTSurfaceBezierIsVPeriodic(OCCTSurfaceRef surface) {
    if (!surface) return false;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return false;
    try { return bz->IsVPeriodic(); } catch (...) { return false; }
}

int32_t OCCTSurfaceBezierContinuity(OCCTSurfaceRef surface) {
    if (!surface) return 0;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return 0;
    try { return (int32_t)bz->Continuity(); } catch (...) { return 0; }
}

bool OCCTSurfaceBezierIsCNu(OCCTSurfaceRef surface, int32_t n) {
    if (!surface) return false;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return false;
    try { return bz->IsCNu(n); } catch (...) { return false; }
}

bool OCCTSurfaceBezierIsCNv(OCCTSurfaceRef surface, int32_t n) {
    if (!surface) return false;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return false;
    try { return bz->IsCNv(n); } catch (...) { return false; }
}

void OCCTSurfaceBezierGetPoles(OCCTSurfaceRef surface, double* poles) {
    if (!surface || !poles) return;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return;
    try {
        const auto& p = bz->Poles();
        int idx = 0;
        for (int i = p.LowerRow(); i <= p.UpperRow(); i++) {
            for (int j = p.LowerCol(); j <= p.UpperCol(); j++) {
                const gp_Pnt& pt = p(i, j);
                poles[idx++] = pt.X();
                poles[idx++] = pt.Y();
                poles[idx++] = pt.Z();
            }
        }
    } catch (...) {}
}

bool OCCTSurfaceBezierGetWeights(OCCTSurfaceRef surface, double* weights) {
    if (!surface || !weights) return false;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return false;
    try {
        const auto* w = bz->Weights();
        if (!w) return false;
        int idx = 0;
        for (int i = w->LowerRow(); i <= w->UpperRow(); i++) {
            for (int j = w->LowerCol(); j <= w->UpperCol(); j++) {
                weights[idx++] = (*w)(i, j);
            }
        }
        return true;
    } catch (...) { return false; }
}

void OCCTSurfaceBezierBounds(OCCTSurfaceRef surface,
                              double* u1, double* u2, double* v1, double* v2) {
    if (!surface) return;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return;
    try { bz->Bounds(*u1, *u2, *v1, *v2); } catch (...) {}
}

// end of v0.125.0 implementations

// MARK: - v0.126/v0.127: BSplineSurface bulk + Surface BSpline+Bezier + Bezier insert/remove + GeomEval Surfaces + GeomFill_Gordon + GeomEval_TBezier/AHTBezierSurface
// --- BSpline Surface bulk multiplicities and reverse ---

void OCCTSurfaceBSplineGetUMultiplicities(OCCTSurfaceRef surface, int32_t* mults) {
    if (!surface || !mults) return;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return;
    try {
        int n = bs->NbUKnots();
        for (int i = 1; i <= n; i++) {
            mults[i-1] = bs->UMultiplicity(i);
        }
    } catch (...) {}
}

void OCCTSurfaceBSplineGetVMultiplicities(OCCTSurfaceRef surface, int32_t* mults) {
    if (!surface || !mults) return;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return;
    try {
        int n = bs->NbVKnots();
        for (int i = 1; i <= n; i++) {
            mults[i-1] = bs->VMultiplicity(i);
        }
    } catch (...) {}
}

bool OCCTSurfaceBSplineUReverse(OCCTSurfaceRef surface) {
    if (!surface) return false;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return false;
    try {
        bs->UReverse();
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBSplineVReverse(OCCTSurfaceRef surface) {
    if (!surface) return false;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return false;
    try {
        bs->VReverse();
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBSplinePeriodicNormalization(OCCTSurfaceRef surface, double* u, double* v) {
    if (!surface) return false;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return false;
    try {
        bs->PeriodicNormalization(*u, *v);
        return true;
    } catch (...) { return false; }
}
// --- Bezier Surface insert/remove poles ---

bool OCCTSurfaceBezierInsertPoleColAfter(OCCTSurfaceRef surface, int32_t colIndex,
                                          const double* poles, int32_t poleCount) {
    if (!surface || !poles) return false;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return false;
    try {
        int nbUPoles = bz->NbUPoles();
        if (poleCount != nbUPoles) return false;
        NCollection_Array1<gp_Pnt> col(1, nbUPoles);
        for (int i = 0; i < nbUPoles; i++) {
            col.SetValue(i+1, gp_Pnt(poles[i*3], poles[i*3+1], poles[i*3+2]));
        }
        bz->InsertPoleColAfter(colIndex, col);
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBezierInsertPoleRowAfter(OCCTSurfaceRef surface, int32_t rowIndex,
                                          const double* poles, int32_t poleCount) {
    if (!surface || !poles) return false;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return false;
    try {
        int nbVPoles = bz->NbVPoles();
        if (poleCount != nbVPoles) return false;
        NCollection_Array1<gp_Pnt> row(1, nbVPoles);
        for (int i = 0; i < nbVPoles; i++) {
            row.SetValue(i+1, gp_Pnt(poles[i*3], poles[i*3+1], poles[i*3+2]));
        }
        bz->InsertPoleRowAfter(rowIndex, row);
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBezierRemovePoleCol(OCCTSurfaceRef surface, int32_t colIndex) {
    if (!surface) return false;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return false;
    try {
        bz->RemovePoleCol(colIndex);
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBezierRemovePoleRow(OCCTSurfaceRef surface, int32_t rowIndex) {
    if (!surface) return false;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return false;
    try {
        bz->RemovePoleRow(rowIndex);
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBezierIncreaseDegree(OCCTSurfaceRef surface, int32_t uDeg, int32_t vDeg) {
    if (!surface) return false;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return false;
    try {
        bz->Increase(uDeg, vDeg);
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBezierUReverse(OCCTSurfaceRef surface) {
    if (!surface) return false;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return false;
    try {
        bz->UReverse();
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBezierVReverse(OCCTSurfaceRef surface) {
    if (!surface) return false;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return false;
    try {
        bz->VReverse();
        return true;
    } catch (...) { return false; }
}
// --- Geom_BezierSurface completions ---

bool OCCTSurfaceBezierSetPoleColWeights(OCCTSurfaceRef surface, int32_t vIndex,
                                         const double* poles, const double* weights,
                                         int32_t count) {
    if (!surface || !poles || !weights || count <= 0) return false;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return false;
    try {
        NCollection_Array1<gp_Pnt> colPoles(1, count);
        NCollection_Array1<double> colWeights(1, count);
        for (int i = 0; i < count; i++) {
            colPoles.SetValue(i+1, gp_Pnt(poles[i*3], poles[i*3+1], poles[i*3+2]));
            colWeights.SetValue(i+1, weights[i]);
        }
        bz->SetPoleCol(vIndex, colPoles, colWeights);
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBezierSetPoleRowWeights(OCCTSurfaceRef surface, int32_t uIndex,
                                         const double* poles, const double* weights,
                                         int32_t count) {
    if (!surface || !poles || !weights || count <= 0) return false;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return false;
    try {
        NCollection_Array1<gp_Pnt> rowPoles(1, count);
        NCollection_Array1<double> rowWeights(1, count);
        for (int i = 0; i < count; i++) {
            rowPoles.SetValue(i+1, gp_Pnt(poles[i*3], poles[i*3+1], poles[i*3+2]));
            rowWeights.SetValue(i+1, weights[i]);
        }
        bz->SetPoleRow(uIndex, rowPoles, rowWeights);
        return true;
    } catch (...) { return false; }
}
static bool buildTrsf3D(gp_Trsf& trsf, int32_t type,
                          double p1, double p2, double p3,
                          double p4, double p5, double p6, double p7) {
    switch (type) {
        case 0: // translation (dx, dy, dz)
            trsf.SetTranslation(gp_Vec(p1, p2, p3));
            return true;
        case 1: // rotation (ox, oy, oz, dx, dy, dz, angle)
            trsf.SetRotation(gp_Ax1(gp_Pnt(p1, p2, p3), gp_Dir(p4, p5, p6)), p7);
            return true;
        case 2: // scale (cx, cy, cz, factor)
            trsf.SetScale(gp_Pnt(p1, p2, p3), p4);
            return true;
        case 3: // mirror point (px, py, pz)
            trsf.SetMirror(gp_Pnt(p1, p2, p3));
            return true;
        case 4: // mirror axis (ox, oy, oz, dx, dy, dz)
            trsf.SetMirror(gp_Ax1(gp_Pnt(p1, p2, p3), gp_Dir(p4, p5, p6)));
            return true;
        case 5: // mirror plane (ox, oy, oz, nx, ny, nz)
            trsf.SetMirror(gp_Ax2(gp_Pnt(p1, p2, p3), gp_Dir(p4, p5, p6)));
            return true;
        default:
            return false;
    }
}

bool OCCTSurfaceTransform(OCCTSurfaceRef surface, int32_t transformType,
                           double p1, double p2, double p3,
                           double p4, double p5, double p6, double p7) {
    if (!surface) return false;
    try {
        gp_Trsf trsf;
        if (!buildTrsf3D(trsf, transformType, p1, p2, p3, p4, p5, p6, p7)) return false;
        surface->surface->Transform(trsf);
        return true;
    } catch (...) { return false; }
}
bool OCCTSurfaceBSplineSetWeightCol(OCCTSurfaceRef surface, int32_t vIndex,
                                     const double* weights, int32_t count) {
    if (!surface || surface->surface.IsNull() || !weights || count <= 0) return false;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return false;
    try {
        TColStd_Array1OfReal w(1, count);
        for (int i = 0; i < count; i++) w.SetValue(i + 1, weights[i]);
        bs->SetWeightCol(vIndex, w);
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBSplineSetWeightRow(OCCTSurfaceRef surface, int32_t uIndex,
                                     const double* weights, int32_t count) {
    if (!surface || surface->surface.IsNull() || !weights || count <= 0) return false;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return false;
    try {
        TColStd_Array1OfReal w(1, count);
        for (int i = 0; i < count; i++) w.SetValue(i + 1, weights[i]);
        bs->SetWeightRow(uIndex, w);
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBSplineIncrementUMultiplicity(OCCTSurfaceRef surface,
                                               int32_t fromIndex, int32_t toIndex, int32_t step) {
    if (!surface || surface->surface.IsNull()) return false;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return false;
    try { bs->IncrementUMultiplicity(fromIndex, toIndex, step); return true; } catch (...) { return false; }
}

bool OCCTSurfaceBSplineIncrementVMultiplicity(OCCTSurfaceRef surface,
                                               int32_t fromIndex, int32_t toIndex, int32_t step) {
    if (!surface || surface->surface.IsNull()) return false;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return false;
    try { bs->IncrementVMultiplicity(fromIndex, toIndex, step); return true; } catch (...) { return false; }
}

int32_t OCCTSurfaceBSplineFirstUKnotIndex(OCCTSurfaceRef surface) {
    if (!surface || surface->surface.IsNull()) return 0;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return 0;
    try { return (int32_t)bs->FirstUKnotIndex(); } catch (...) { return 0; }
}

int32_t OCCTSurfaceBSplineLastUKnotIndex(OCCTSurfaceRef surface) {
    if (!surface || surface->surface.IsNull()) return 0;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return 0;
    try { return (int32_t)bs->LastUKnotIndex(); } catch (...) { return 0; }
}

int32_t OCCTSurfaceBSplineFirstVKnotIndex(OCCTSurfaceRef surface) {
    if (!surface || surface->surface.IsNull()) return 0;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return 0;
    try { return (int32_t)bs->FirstVKnotIndex(); } catch (...) { return 0; }
}

int32_t OCCTSurfaceBSplineLastVKnotIndex(OCCTSurfaceRef surface) {
    if (!surface || surface->surface.IsNull()) return 0;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return 0;
    try { return (int32_t)bs->LastVKnotIndex(); } catch (...) { return 0; }
}

bool OCCTSurfaceBSplineCheckAndSegment(OCCTSurfaceRef surface,
                                        double u1, double u2, double v1, double v2,
                                        double uTol, double vTol) {
    if (!surface || surface->surface.IsNull()) return false;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return false;
    try { bs->CheckAndSegment(u1, u2, v1, v2, uTol, vTol); return true; } catch (...) { return false; }
}

// BezierSurface completions

bool OCCTSurfaceBezierInsertPoleColBefore(OCCTSurfaceRef surface, int32_t colIndex,
                                           const double* poles, int32_t poleCount) {
    if (!surface || !poles) return false;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return false;
    try {
        int nbUPoles = bz->NbUPoles();
        if (poleCount != nbUPoles) return false;
        NCollection_Array1<gp_Pnt> col(1, nbUPoles);
        for (int i = 0; i < nbUPoles; i++) {
            col.SetValue(i + 1, gp_Pnt(poles[i * 3], poles[i * 3 + 1], poles[i * 3 + 2]));
        }
        bz->InsertPoleColBefore(colIndex, col);
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBezierInsertPoleRowBefore(OCCTSurfaceRef surface, int32_t rowIndex,
                                           const double* poles, int32_t poleCount) {
    if (!surface || !poles) return false;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return false;
    try {
        int nbVPoles = bz->NbVPoles();
        if (poleCount != nbVPoles) return false;
        NCollection_Array1<gp_Pnt> row(1, nbVPoles);
        for (int i = 0; i < nbVPoles; i++) {
            row.SetValue(i + 1, gp_Pnt(poles[i * 3], poles[i * 3 + 1], poles[i * 3 + 2]));
        }
        bz->InsertPoleRowBefore(rowIndex, row);
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBezierSetPoleCol(OCCTSurfaceRef surface, int32_t vIndex,
                                  const double* poles, int32_t count) {
    if (!surface || !poles || count <= 0) return false;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return false;
    try {
        NCollection_Array1<gp_Pnt> col(1, count);
        for (int i = 0; i < count; i++) {
            col.SetValue(i + 1, gp_Pnt(poles[i * 3], poles[i * 3 + 1], poles[i * 3 + 2]));
        }
        bz->SetPoleCol(vIndex, col);
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBezierSetPoleRow(OCCTSurfaceRef surface, int32_t uIndex,
                                  const double* poles, int32_t count) {
    if (!surface || !poles || count <= 0) return false;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return false;
    try {
        NCollection_Array1<gp_Pnt> row(1, count);
        for (int i = 0; i < count; i++) {
            row.SetValue(i + 1, gp_Pnt(poles[i * 3], poles[i * 3 + 1], poles[i * 3 + 2]));
        }
        bz->SetPoleRow(uIndex, row);
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBezierSetWeightCol(OCCTSurfaceRef surface, int32_t vIndex,
                                    const double* weights, int32_t count) {
    if (!surface || !weights || count <= 0) return false;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return false;
    try {
        TColStd_Array1OfReal w(1, count);
        for (int i = 0; i < count; i++) w.SetValue(i + 1, weights[i]);
        bz->SetWeightCol(vIndex, w);
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBezierSetWeightRow(OCCTSurfaceRef surface, int32_t uIndex,
                                    const double* weights, int32_t count) {
    if (!surface || !weights || count <= 0) return false;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return false;
    try {
        TColStd_Array1OfReal w(1, count);
        for (int i = 0; i < count; i++) w.SetValue(i + 1, weights[i]);
        bz->SetWeightRow(uIndex, w);
        return true;
    } catch (...) { return false; }
}

// end of v0.128.0 implementations
// --- GeomEval Surfaces ---

#include <GeomEval_EllipsoidSurface.hxx>
#include <GeomEval_HyperboloidSurface.hxx>
#include <GeomEval_ParaboloidSurface.hxx>
#include <GeomEval_CircularHelicoidSurface.hxx>
#include <GeomEval_HypParaboloidSurface.hxx>
#include <GeomFill_Gordon.hxx>
#include <GeomEval_TBezierSurface.hxx>
#include <GeomEval_AHTBezierSurface.hxx>

void OCCTGeomEvalEllipsoidD0(double a, double b, double c, double u, double v,
                              double* px, double* py, double* pz) {
    gp_Ax3 ax(gp_Pnt(0,0,0), gp_Dir(0,0,1));
    GeomEval_EllipsoidSurface ell(ax, a, b, c);
    gp_Pnt p = ell.EvalD0(u, v);
    *px = p.X(); *py = p.Y(); *pz = p.Z();
}

OCCTSurfaceRef OCCTGeomEvalEllipsoidCreate(double a, double b, double c) {
    try {
        gp_Ax3 ax(gp_Pnt(0,0,0), gp_Dir(0,0,1));
        auto ell = new GeomEval_EllipsoidSurface(ax, a, b, c);
        occ::handle<Geom_Surface> hSurf(ell);
        auto ref = new OCCTSurface();
        ref->surface = hSurf;
        return ref;
    } catch (...) { return nullptr; }
}

void OCCTGeomEvalHyperboloidD0(double r1, double r2, int32_t mode, double u, double v,
                                double* px, double* py, double* pz) {
    gp_Ax3 ax(gp_Pnt(0,0,0), gp_Dir(0,0,1));
    auto sm = mode == 0 ? GeomEval_HyperboloidSurface::SheetMode::OneSheet
                        : GeomEval_HyperboloidSurface::SheetMode::TwoSheets;
    GeomEval_HyperboloidSurface hyp(ax, r1, r2, sm);
    gp_Pnt p = hyp.EvalD0(u, v);
    *px = p.X(); *py = p.Y(); *pz = p.Z();
}

OCCTSurfaceRef OCCTGeomEvalHyperboloidCreate(double r1, double r2, int32_t mode) {
    try {
        gp_Ax3 ax(gp_Pnt(0,0,0), gp_Dir(0,0,1));
        auto sm = mode == 0 ? GeomEval_HyperboloidSurface::SheetMode::OneSheet
                            : GeomEval_HyperboloidSurface::SheetMode::TwoSheets;
        auto hyp = new GeomEval_HyperboloidSurface(ax, r1, r2, sm);
        occ::handle<Geom_Surface> hSurf(hyp);
        auto ref = new OCCTSurface();
        ref->surface = hSurf;
        return ref;
    } catch (...) { return nullptr; }
}

void OCCTGeomEvalParaboloidD0(double focal, double u, double v,
                               double* px, double* py, double* pz) {
    gp_Ax3 ax(gp_Pnt(0,0,0), gp_Dir(0,0,1));
    GeomEval_ParaboloidSurface par(ax, focal);
    gp_Pnt p = par.EvalD0(u, v);
    *px = p.X(); *py = p.Y(); *pz = p.Z();
}

OCCTSurfaceRef OCCTGeomEvalParaboloidCreate(double focal) {
    try {
        gp_Ax3 ax(gp_Pnt(0,0,0), gp_Dir(0,0,1));
        auto par = new GeomEval_ParaboloidSurface(ax, focal);
        occ::handle<Geom_Surface> hSurf(par);
        auto ref = new OCCTSurface();
        ref->surface = hSurf;
        return ref;
    } catch (...) { return nullptr; }
}

void OCCTGeomEvalCircularHelicoidD0(double pitch, double u, double v,
                                     double* px, double* py, double* pz) {
    gp_Ax3 ax(gp_Pnt(0,0,0), gp_Dir(0,0,1));
    GeomEval_CircularHelicoidSurface hel(ax, pitch);
    gp_Pnt p = hel.EvalD0(u, v);
    *px = p.X(); *py = p.Y(); *pz = p.Z();
}

OCCTSurfaceRef OCCTGeomEvalCircularHelicoidCreate(double pitch) {
    try {
        gp_Ax3 ax(gp_Pnt(0,0,0), gp_Dir(0,0,1));
        auto hel = new GeomEval_CircularHelicoidSurface(ax, pitch);
        occ::handle<Geom_Surface> hSurf(hel);
        auto ref = new OCCTSurface();
        ref->surface = hSurf;
        return ref;
    } catch (...) { return nullptr; }
}

void OCCTGeomEvalHypParaboloidD0(double a, double b, double u, double v,
                                  double* px, double* py, double* pz) {
    gp_Ax3 ax(gp_Pnt(0,0,0), gp_Dir(0,0,1));
    GeomEval_HypParaboloidSurface hp(ax, a, b);
    gp_Pnt p = hp.EvalD0(u, v);
    *px = p.X(); *py = p.Y(); *pz = p.Z();
}

OCCTSurfaceRef OCCTGeomEvalHypParaboloidCreate(double a, double b) {
    try {
        gp_Ax3 ax(gp_Pnt(0,0,0), gp_Dir(0,0,1));
        auto hp = new GeomEval_HypParaboloidSurface(ax, a, b);
        occ::handle<Geom_Surface> hSurf(hp);
        auto ref = new OCCTSurface();
        ref->surface = hSurf;
        return ref;
    } catch (...) { return nullptr; }
}
// --- GeomFill_Gordon ---

OCCTSurfaceRef OCCTGeomFillGordon(const OCCTCurve3DRef* profiles, int32_t profileCount,
                                   const OCCTCurve3DRef* guides, int32_t guideCount,
                                   double tolerance) {
    if (!profiles || !guides || profileCount < 2 || guideCount < 2) return nullptr;
    try {
        NCollection_Array1<occ::handle<Geom_Curve>> profs(0, profileCount - 1);
        for (int i = 0; i < profileCount; i++) {
            if (!profiles[i]) return nullptr;
            profs.SetValue(i, profiles[i]->curve);
        }
        NCollection_Array1<occ::handle<Geom_Curve>> gds(0, guideCount - 1);
        for (int i = 0; i < guideCount; i++) {
            if (!guides[i]) return nullptr;
            gds.SetValue(i, guides[i]->curve);
        }

        GeomFill_Gordon gordon;
        gordon.Init(profs, gds, tolerance);
        gordon.Perform();
        if (!gordon.IsDone()) return nullptr;

        auto surf = gordon.Surface();
        if (surf.IsNull()) return nullptr;

        auto ref = new OCCTSurface();
        ref->surface = surf;
        return ref;
    } catch (...) { return nullptr; }
}
// --- GeomEval_TBezierSurface ---

OCCTSurfaceRef OCCTGeomEvalTBezierSurfaceCreate(
    const double* poles, int32_t uCount, int32_t vCount,
    double alphaU, double alphaV) {
    if (!poles || uCount < 3 || vCount < 3 || uCount % 2 == 0 || vCount % 2 == 0) return nullptr;
    try {
        NCollection_Array2<gp_Pnt> pts(1, uCount, 1, vCount);
        for (int i = 0; i < uCount; i++)
            for (int j = 0; j < vCount; j++) {
                int idx = (i * vCount + j) * 3;
                pts(i + 1, j + 1) = gp_Pnt(poles[idx], poles[idx+1], poles[idx+2]);
            }
        auto ts = new GeomEval_TBezierSurface(pts, alphaU, alphaV);
        occ::handle<Geom_Surface> hSurf(ts);
        auto ref = new OCCTSurface(hSurf);
        return ref;
    } catch (...) { return nullptr; }
}

// --- GeomEval_AHTBezierSurface ---

OCCTSurfaceRef OCCTGeomEvalAHTBezierSurfaceCreate(
    const double* poles, int32_t uCount, int32_t vCount,
    int32_t algDegreeU, int32_t algDegreeV,
    double alphaU, double alphaV, double betaU, double betaV) {
    if (!poles || uCount < 1 || vCount < 1) return nullptr;
    try {
        NCollection_Array2<gp_Pnt> pts(1, uCount, 1, vCount);
        for (int i = 0; i < uCount; i++)
            for (int j = 0; j < vCount; j++) {
                int idx = (i * vCount + j) * 3;
                pts(i + 1, j + 1) = gp_Pnt(poles[idx], poles[idx+1], poles[idx+2]);
            }
        auto as = new GeomEval_AHTBezierSurface(pts, algDegreeU, algDegreeV,
                                                  alphaU, alphaV, betaU, betaV);
        occ::handle<Geom_Surface> hSurf(as);
        auto ref = new OCCTSurface(hSurf);
        return ref;
    } catch (...) { return nullptr; }
}

// MARK: - GeomFill_Gordon report + GeomFill_NetworkSurface — OCCT 8.0.0p1

#include <GeomFill_NetworkSurface.hxx>

// Build a Gordon surface reporting status + approximate flag.
OCCTSurfaceRef OCCTGeomFillGordonReport(const OCCTCurve3DRef* profiles, int32_t profileCount,
                                        const OCCTCurve3DRef* guides, int32_t guideCount,
                                        double tolerance, int32_t approximationMode,
                                        int32_t* outStatus, bool* outIsApproximate) {
    if (outStatus) *outStatus = (int32_t)GeomFill_Gordon::ResultStatus::NotStarted;
    if (outIsApproximate) *outIsApproximate = false;
    if (!profiles || !guides || profileCount < 2 || guideCount < 2) {
        if (outStatus) *outStatus = (int32_t)GeomFill_Gordon::ResultStatus::InvalidInput;
        return nullptr;
    }
    try {
        NCollection_Array1<occ::handle<Geom_Curve>> profs(0, profileCount - 1);
        for (int i = 0; i < profileCount; i++) {
            if (!profiles[i]) return nullptr;
            profs.SetValue(i, profiles[i]->curve);
        }
        NCollection_Array1<occ::handle<Geom_Curve>> gds(0, guideCount - 1);
        for (int i = 0; i < guideCount; i++) {
            if (!guides[i]) return nullptr;
            gds.SetValue(i, guides[i]->curve);
        }

        GeomFill_Gordon gordon;
        gordon.SetApproximationMode(approximationMode == 1
            ? GeomFill_Gordon::ApproximationMode::AllowApproximateFallback
            : GeomFill_Gordon::ApproximationMode::ExactOnly);
        gordon.Init(profs, gds, tolerance);
        gordon.Perform();

        if (outStatus) *outStatus = (int32_t)gordon.Status();
        if (outIsApproximate) *outIsApproximate = gordon.IsApproximate();

        if (!gordon.IsDone()) return nullptr;
        auto surf = gordon.Surface();
        if (surf.IsNull()) return nullptr;

        auto ref = new OCCTSurface();
        ref->surface = surf;
        return ref;
    } catch (...) {
        return nullptr;
    }
}

// Low-level GeomFill_NetworkSurface builder. Takes profile + guide curves and
// builds a compatible non-periodic B-spline network: profiles are evaluated in
// U, guides in V; the intersection grid is sampled at the natural [first,last]
// parameter range of each curve, and the profile/guide locator parameters are
// uniformly spaced. Returns the surface or NULL; writes the ResultStatus ordinal.
OCCTSurfaceRef OCCTGeomFillNetworkSurface(const OCCTCurve3DRef* profiles, int32_t profileCount,
                                          const OCCTCurve3DRef* guides, int32_t guideCount,
                                          double tolerance, int32_t* outStatus) {
    if (outStatus) *outStatus = (int32_t)GeomFill_NetworkSurface::ResultStatus::NotStarted;
    if (!profiles || !guides || profileCount < 2 || guideCount < 2) {
        if (outStatus) *outStatus = (int32_t)GeomFill_NetworkSurface::ResultStatus::InvalidInput;
        return nullptr;
    }
    try {
        // Convert inputs to explicit non-periodic B-spline curves.
        NCollection_Array1<occ::handle<Geom_BSplineCurve>> profs(1, profileCount);
        for (int i = 0; i < profileCount; i++) {
            if (!profiles[i] || profiles[i]->curve.IsNull()) return nullptr;
            Handle(Geom_BSplineCurve) bs = GeomConvert::CurveToBSplineCurve(profiles[i]->curve);
            if (bs.IsNull()) return nullptr;
            if (bs->IsPeriodic()) bs->SetNotPeriodic();
            profs.SetValue(i + 1, bs);
        }
        NCollection_Array1<occ::handle<Geom_BSplineCurve>> gds(1, guideCount);
        for (int i = 0; i < guideCount; i++) {
            if (!guides[i] || guides[i]->curve.IsNull()) return nullptr;
            Handle(Geom_BSplineCurve) bs = GeomConvert::CurveToBSplineCurve(guides[i]->curve);
            if (bs.IsNull()) return nullptr;
            if (bs->IsPeriodic()) bs->SetNotPeriodic();
            gds.SetValue(i + 1, bs);
        }

        // Uniform locator parameters in [0,1].
        NCollection_Array1<double> profileParams(1, profileCount);
        for (int i = 0; i < profileCount; i++)
            profileParams.SetValue(i + 1, profileCount > 1 ? (double)i / (profileCount - 1) : 0.0);
        NCollection_Array1<double> guideParams(1, guideCount);
        for (int j = 0; j < guideCount; j++)
            guideParams.SetValue(j + 1, guideCount > 1 ? (double)j / (guideCount - 1) : 0.0);

        // Intersection grid: row = profile (i), col = guide (j). Sample profile i
        // at the parameter matching guide j's normalized position along the profile.
        NCollection_Array2<gp_Pnt> ipts(1, profileCount, 1, guideCount);
        NCollection_Array2<double> iwts(1, profileCount, 1, guideCount);
        for (int i = 0; i < profileCount; i++) {
            const Handle(Geom_BSplineCurve)& pc = profs.Value(i + 1);
            double f = pc->FirstParameter(), l = pc->LastParameter();
            for (int j = 0; j < guideCount; j++) {
                double t = guideCount > 1 ? f + (l - f) * ((double)j / (guideCount - 1)) : f;
                ipts.SetValue(i + 1, j + 1, pc->Value(t));
                iwts.SetValue(i + 1, j + 1, 1.0);
            }
        }

        GeomFill_NetworkSurface net;
        net.Init(profs, gds, profileParams, guideParams, ipts, iwts, tolerance, false, false);
        net.Perform();
        if (outStatus) *outStatus = (int32_t)net.Status();
        if (!net.IsDone()) return nullptr;

        const Handle(Geom_BSplineSurface)& surf = net.Surface();
        if (surf.IsNull()) return nullptr;
        auto ref = new OCCTSurface();
        ref->surface = surf;
        return ref;
    } catch (...) {
        return nullptr;
    }
}
