//
//  OCCTBridge_Curve3D.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm — issue #99.
//
//  3D parametric curve cluster (v0.19):
//
//  - Geom_Curve construction (line, circle, ellipse, hyperbola, parabola,
//    Bezier, BSpline, trimmed, offset)
//  - GC makers (segment, circle, arc-of-circle)
//  - Conversion (Bezier <-> BSpline, composite-curve to BSpline,
//    GeomConvert_ApproxCurve)
//  - Sampling (UniformAbscissa, UniformDeflection, TangentialDeflection)
//  - Interpolation + fitting (Geom_BSpline through points)
//  - Local properties (GeomLProp_CLProps)
//  - Tangent / curvature evaluation
//
//  Defines `struct OCCTCurve3D` locally; the matching definition in
//  OCCTBridge.mm has identical layout (ODR-safe across TUs).
//
//  Public C surface unchanged. No symbol changes — pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// === Area-specific OCCT headers ===

#include <Approx_Curve3d.hxx>
#include <Approx_CurveOnSurface.hxx>
#include <Approx_CurvilinearParameter.hxx>
#include <CPnts_UniformDeflection.hxx>
#include <LocalAnalysis_CurveContinuity.hxx>
#include <Geom_Axis1Placement.hxx>
#include <Geom_Axis2Placement.hxx>
#include <Geom_CartesianPoint.hxx>
#include <Geom_Direction.hxx>
#include <Geom_Point.hxx>
#include <Geom_Vector.hxx>
#include <Geom_VectorWithMagnitude.hxx>
#include <ShapeConstruct_Curve.hxx>
#include <GeomLib_Tool.hxx>
#include <GeomLib_CheckBSplineCurve.hxx>
#include <GeomLib_Interpolate.hxx>
#include <Approx_SameParameter.hxx>
#include <Extrema_ExtCC.hxx>
#include <Extrema_ExtCS.hxx>
#include <Extrema_LocateExtCC.hxx>
#include <Extrema_POnCurv.hxx>
#include <Extrema_POnSurf.hxx>
#include <gce_MakeCirc.hxx>
#include <gce_MakeDir.hxx>
#include <gce_MakeElips.hxx>
#include <gce_MakeHypr.hxx>
#include <gce_MakeLin.hxx>
#include <gce_MakeParab.hxx>
#include <GeomAPI_ProjectPointOnCurve.hxx>
#include <GeomAPI_ProjectPointOnSurf.hxx>
#include <Extrema_GenLocateExtPS.hxx>
#include <TColStd_HArray1OfReal.hxx>
#include <HelixGeom_BuilderHelix.hxx>
#include <HelixGeom_BuilderHelixCoil.hxx>
#include <HelixGeom_HelixCurve.hxx>
#include <HelixGeom_Tools.hxx>
#include <GeomEval_CircularHelixCurve.hxx>
#include <GeomEval_SineWaveCurve.hxx>
#include <GeomEval_TBezierCurve.hxx>
#include <GeomEval_AHTBezierCurve.hxx>
#include <GeomAdaptor_TransformedCurve.hxx>
// Approx_BSplineApproxInterp was removed in OCCT 8.0.0p1 (it backed the old Gordon
// prototype). The wrapper below is reimplemented on GeomAPI_PointsToBSpline — the
// documented replacement — keeping the same C ABI; see that section's comment for the
// resulting semantic changes (nbControlPoints/interpolation kinks become advisory).
#include <GeomAPI_PointsToBSpline.hxx>
#include <GeomAPI_ProjectPointOnCurve.hxx>
#include <Geom_BSplineCurve.hxx>
#include <GeomAbs_Shape.hxx>
#include <Extrema_ExtPC.hxx>
#include <ExtremaPC_Curve.hxx>
#include <TColStd_HArray1OfBoolean.hxx>
#include <ShapeUpgrade_SplitCurve3dContinuity.hxx>
#include <BRep_Tool.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepLib.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <GeomAdaptor_Surface.hxx>

#include <GC_MakeArcOfCircle.hxx>
#include <GC_MakeArcOfEllipse.hxx>
#include <GC_MakeArcOfHyperbola.hxx>
#include <GC_MakeArcOfParabola.hxx>
#include <GC_MakeCircle.hxx>
#include <GC_MakeEllipse.hxx>
#include <GC_MakeHyperbola.hxx>
#include <GC_MakeSegment.hxx>
#include <ShapeCustom_Curve.hxx>
#include <ShapeUpgrade_SplitCurve3d.hxx>
#include <TColGeom_HArray1OfCurve.hxx>
#include <TColStd_HSequenceOfReal.hxx>
#include <gp_Hypr.hxx>
#include <gp_Parab.hxx>

#include <GCPnts_TangentialDeflection.hxx>
#include <GCPnts_UniformAbscissa.hxx>
#include <GCPnts_UniformDeflection.hxx>

#include <Geom_BezierCurve.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Curve.hxx>
#include <Geom_Ellipse.hxx>
#include <Geom_Hyperbola.hxx>
#include <Geom_Line.hxx>
#include <Geom_OffsetCurve.hxx>
#include <Geom_Parabola.hxx>
#include <Geom_TrimmedCurve.hxx>

#include <GeomAbs_Shape.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <GeomAPI_PointsToBSpline.hxx>
#include <GeomConvert.hxx>
#include <GeomConvert_ApproxCurve.hxx>
#include <GeomConvert_BSplineCurveToBezierCurve.hxx>
#include <GeomConvert_CompCurveToBSplineCurve.hxx>
#include <GeomLProp_CLProps.hxx>

#include <gp_Ax1.hxx>
#include <gp_Ax2.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>

#include <TColgp_Array1OfPnt.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColStd_HArray1OfBoolean.hxx>

// MARK: - Curve3D: 3D Parametric Curves (v0.19.0)

#include <Geom_Curve.hxx>
#include <Geom_Line.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Ellipse.hxx>
#include <Geom_Parabola.hxx>
#include <Geom_Hyperbola.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <Geom_OffsetCurve.hxx>
#include <GC_MakeSegment.hxx>
#include <GC_MakeArcOfCircle.hxx>
#include <GC_MakeCircle.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <GeomConvert.hxx>
#include <GeomConvert_BSplineCurveToBezierCurve.hxx>
#include <GeomConvert_CompCurveToBSplineCurve.hxx>
#include <GeomConvert_ApproxCurve.hxx>
#include <GCPnts_TangentialDeflection.hxx>
#include <GCPnts_UniformAbscissa.hxx>
#include <GCPnts_UniformDeflection.hxx>
#include <Bnd_Box.hxx>
#include <BndLib_Add3dCurve.hxx>
#include <CPnts_AbscissaPoint.hxx>
#include <TColgp_HArray1OfPnt.hxx>

void OCCTCurve3DRelease(OCCTCurve3DRef c) {
    delete c;
}

OCCTCurve3DRef OCCTEdgeGetCurve3D(OCCTEdgeRef edge) {
    if (!edge) return nullptr;
    try {
        BRepLib::BuildCurves3d(edge->edge);
        Standard_Real first, last;
        Handle(Geom_Curve) curve = BRep_Tool::Curve(edge->edge, first, last);
        if (curve.IsNull()) return nullptr;
        // Return the raw curve so consumers can DownCast to Geom_Circle /
        // Geom_Line / etc. for typed-property extraction. The edge's
        // parameter range stays available via Edge.parameterBounds.
        return new OCCTCurve3D(curve);
    } catch (...) {
        return nullptr;
    }
}

// Properties

void OCCTCurve3DGetDomain(OCCTCurve3DRef c, double* first, double* last) {
    if (!c || c->curve.IsNull() || !first || !last) return;
    *first = c->curve->FirstParameter();
    *last = c->curve->LastParameter();
}

bool OCCTCurve3DIsClosed(OCCTCurve3DRef c) {
    if (!c || c->curve.IsNull()) return false;
    return c->curve->IsClosed() == Standard_True;
}

bool OCCTCurve3DIsPeriodic(OCCTCurve3DRef c) {
    if (!c || c->curve.IsNull()) return false;
    return c->curve->IsPeriodic() == Standard_True;
}

double OCCTCurve3DGetPeriod(OCCTCurve3DRef c) {
    if (!c || c->curve.IsNull()) return 0.0;
    if (!c->curve->IsPeriodic()) return 0.0;
    return c->curve->Period();
}

// Evaluation

void OCCTCurve3DGetPoint(OCCTCurve3DRef c, double u,
                         double* x, double* y, double* z) {
    if (!c || c->curve.IsNull() || !x || !y || !z) return;
    gp_Pnt p = c->curve->Value(u);
    *x = p.X(); *y = p.Y(); *z = p.Z();
}

void OCCTCurve3DD1(OCCTCurve3DRef c, double u,
                   double* px, double* py, double* pz,
                   double* vx, double* vy, double* vz) {
    if (!c || c->curve.IsNull() || !px || !py || !pz || !vx || !vy || !vz) return;
    gp_Pnt p; gp_Vec v;
    c->curve->D1(u, p, v);
    *px = p.X(); *py = p.Y(); *pz = p.Z();
    *vx = v.X(); *vy = v.Y(); *vz = v.Z();
}

void OCCTCurve3DD2(OCCTCurve3DRef c, double u,
                   double* px, double* py, double* pz,
                   double* v1x, double* v1y, double* v1z,
                   double* v2x, double* v2y, double* v2z) {
    if (!c || c->curve.IsNull() || !px || !py || !pz ||
        !v1x || !v1y || !v1z || !v2x || !v2y || !v2z) return;
    gp_Pnt p; gp_Vec v1, v2;
    c->curve->D2(u, p, v1, v2);
    *px = p.X(); *py = p.Y(); *pz = p.Z();
    *v1x = v1.X(); *v1y = v1.Y(); *v1z = v1.Z();
    *v2x = v2.X(); *v2y = v2.Y(); *v2z = v2.Z();
}

// Primitive Curves

OCCTCurve3DRef OCCTCurve3DCreateLine(double px, double py, double pz,
                                      double dx, double dy, double dz) {
    try {
        gp_Pnt origin(px, py, pz);
        gp_Dir dir(dx, dy, dz);
        Handle(Geom_Line) line = new Geom_Line(origin, dir);
        return new OCCTCurve3D(line);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DCreateSegment(double p1x, double p1y, double p1z,
                                         double p2x, double p2y, double p2z) {
    try {
        gp_Pnt pt1(p1x, p1y, p1z);
        gp_Pnt pt2(p2x, p2y, p2z);
        if (pt1.Distance(pt2) < Precision::Confusion()) return nullptr;
        GC_MakeSegment maker(pt1, pt2);
        if (!maker.IsDone()) return nullptr;
        return new OCCTCurve3D(maker.Value());
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DCreateCircle(double cx, double cy, double cz,
                                        double nx, double ny, double nz,
                                        double radius) {
    try {
        if (radius <= 0) return nullptr;
        gp_Pnt center(cx, cy, cz);
        gp_Dir normal(nx, ny, nz);
        gp_Ax2 axis(center, normal);
        Handle(Geom_Circle) circle = new Geom_Circle(axis, radius);
        return new OCCTCurve3D(circle);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DCreateArcOfCircle(double p1x, double p1y, double p1z,
                                             double p2x, double p2y, double p2z,
                                             double p3x, double p3y, double p3z) {
    try {
        GC_MakeArcOfCircle maker(gp_Pnt(p1x, p1y, p1z),
                                  gp_Pnt(p2x, p2y, p2z),
                                  gp_Pnt(p3x, p3y, p3z));
        if (!maker.IsDone()) return nullptr;
        return new OCCTCurve3D(maker.Value());
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DCreateArc3Points(double p1x, double p1y, double p1z,
                                            double pmx, double pmy, double pmz,
                                            double p2x, double p2y, double p2z) {
    try {
        GC_MakeArcOfCircle maker(gp_Pnt(p1x, p1y, p1z),
                                  gp_Pnt(pmx, pmy, pmz),
                                  gp_Pnt(p2x, p2y, p2z));
        if (!maker.IsDone()) return nullptr;
        return new OCCTCurve3D(maker.Value());
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DCreateEllipse(double cx, double cy, double cz,
                                         double nx, double ny, double nz,
                                         double majorR, double minorR) {
    try {
        if (majorR <= 0 || minorR <= 0 || minorR > majorR) return nullptr;
        gp_Ax2 axis(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
        Handle(Geom_Ellipse) ellipse = new Geom_Ellipse(axis, majorR, minorR);
        return new OCCTCurve3D(ellipse);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DCreateParabola(double cx, double cy, double cz,
                                          double nx, double ny, double nz,
                                          double focal) {
    try {
        if (focal <= 0) return nullptr;
        gp_Ax2 axis(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
        Handle(Geom_Parabola) parabola = new Geom_Parabola(axis, focal);
        return new OCCTCurve3D(parabola);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DCreateHyperbola(double cx, double cy, double cz,
                                           double nx, double ny, double nz,
                                           double majorR, double minorR) {
    try {
        if (majorR <= 0 || minorR <= 0) return nullptr;
        gp_Ax2 axis(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
        Handle(Geom_Hyperbola) hyp = new Geom_Hyperbola(axis, majorR, minorR);
        return new OCCTCurve3D(hyp);
    } catch (...) {
        return nullptr;
    }
}

// BSpline / Bezier / Interpolation

OCCTCurve3DRef OCCTCurve3DCreateBSpline(const double* poles, int32_t poleCount,
                                         const double* weights,
                                         const double* knots, int32_t knotCount,
                                         const int32_t* multiplicities, int32_t degree) {
    try {
        if (!poles || poleCount < 2 || !knots || knotCount < 2 || !multiplicities || degree < 1)
            return nullptr;

        TColgp_Array1OfPnt pArr(1, poleCount);
        for (int i = 0; i < poleCount; i++)
            pArr.SetValue(i + 1, gp_Pnt(poles[i*3], poles[i*3+1], poles[i*3+2]));

        TColStd_Array1OfReal kArr(1, knotCount);
        for (int i = 0; i < knotCount; i++)
            kArr.SetValue(i + 1, knots[i]);

        TColStd_Array1OfInteger mArr(1, knotCount);
        for (int i = 0; i < knotCount; i++)
            mArr.SetValue(i + 1, multiplicities[i]);

        Handle(Geom_BSplineCurve) bsp;
        if (weights) {
            TColStd_Array1OfReal wArr(1, poleCount);
            for (int i = 0; i < poleCount; i++)
                wArr.SetValue(i + 1, weights[i]);
            bsp = new Geom_BSplineCurve(pArr, wArr, kArr, mArr, degree);
        } else {
            bsp = new Geom_BSplineCurve(pArr, kArr, mArr, degree);
        }
        return new OCCTCurve3D(bsp);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DCreateBezier(const double* poles, int32_t poleCount,
                                        const double* weights) {
    try {
        if (!poles || poleCount < 2) return nullptr;

        TColgp_Array1OfPnt pArr(1, poleCount);
        for (int i = 0; i < poleCount; i++)
            pArr.SetValue(i + 1, gp_Pnt(poles[i*3], poles[i*3+1], poles[i*3+2]));

        Handle(Geom_BezierCurve) bez;
        if (weights) {
            TColStd_Array1OfReal wArr(1, poleCount);
            for (int i = 0; i < poleCount; i++)
                wArr.SetValue(i + 1, weights[i]);
            bez = new Geom_BezierCurve(pArr, wArr);
        } else {
            bez = new Geom_BezierCurve(pArr);
        }
        return new OCCTCurve3D(bez);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DInterpolate(const double* points, int32_t count,
                                       bool closed, double tolerance) {
    try {
        if (!points || count < 2) return nullptr;

        Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, count);
        for (int i = 0; i < count; i++)
            pts->SetValue(i + 1, gp_Pnt(points[i*3], points[i*3+1], points[i*3+2]));

        GeomAPI_Interpolate interp(pts, closed ? Standard_True : Standard_False, tolerance);
        interp.Perform();
        if (!interp.IsDone()) return nullptr;

        return new OCCTCurve3D(interp.Curve());
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DInterpolateWithTangents(const double* points, int32_t count,
                                                   double stx, double sty, double stz,
                                                   double etx, double ety, double etz,
                                                   double tolerance) {
    try {
        if (!points || count < 2) return nullptr;

        Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, count);
        for (int i = 0; i < count; i++)
            pts->SetValue(i + 1, gp_Pnt(points[i*3], points[i*3+1], points[i*3+2]));

        GeomAPI_Interpolate interp(pts, Standard_False, tolerance);
        gp_Vec startTan(stx, sty, stz);
        gp_Vec endTan(etx, ety, etz);
        interp.Load(startTan, endTan);
        interp.Perform();
        if (!interp.IsDone()) return nullptr;

        return new OCCTCurve3D(interp.Curve());
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DFitPoints(const double* points, int32_t count,
                                     int32_t minDeg, int32_t maxDeg, double tolerance) {
    try {
        if (!points || count < 2) return nullptr;

        TColgp_Array1OfPnt pArr(1, count);
        for (int i = 0; i < count; i++)
            pArr.SetValue(i + 1, gp_Pnt(points[i*3], points[i*3+1], points[i*3+2]));

        GeomAPI_PointsToBSpline fitter(pArr, minDeg, maxDeg,
                                        GeomAbs_C2, tolerance);
        if (!fitter.IsDone()) return nullptr;

        return new OCCTCurve3D(fitter.Curve());
    } catch (...) {
        return nullptr;
    }
}

// BSpline queries

int32_t OCCTCurve3DGetPoleCount(OCCTCurve3DRef c) {
    if (!c || c->curve.IsNull()) return 0;
    try {
        Handle(Geom_BSplineCurve) bsp = Handle(Geom_BSplineCurve)::DownCast(c->curve);
        if (!bsp.IsNull()) return bsp->NbPoles();
        Handle(Geom_BezierCurve) bez = Handle(Geom_BezierCurve)::DownCast(c->curve);
        if (!bez.IsNull()) return bez->NbPoles();
        return 0;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTCurve3DGetPoles(OCCTCurve3DRef c, double* outXYZ) {
    if (!c || c->curve.IsNull() || !outXYZ) return 0;
    try {
        Handle(Geom_BSplineCurve) bsp = Handle(Geom_BSplineCurve)::DownCast(c->curve);
        if (!bsp.IsNull()) {
            int n = bsp->NbPoles();
            for (int i = 1; i <= n; i++) {
                gp_Pnt p = bsp->Pole(i);
                outXYZ[(i-1)*3] = p.X();
                outXYZ[(i-1)*3+1] = p.Y();
                outXYZ[(i-1)*3+2] = p.Z();
            }
            return n;
        }
        Handle(Geom_BezierCurve) bez = Handle(Geom_BezierCurve)::DownCast(c->curve);
        if (!bez.IsNull()) {
            int n = bez->NbPoles();
            for (int i = 1; i <= n; i++) {
                gp_Pnt p = bez->Pole(i);
                outXYZ[(i-1)*3] = p.X();
                outXYZ[(i-1)*3+1] = p.Y();
                outXYZ[(i-1)*3+2] = p.Z();
            }
            return n;
        }
        return 0;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTCurve3DGetDegree(OCCTCurve3DRef c) {
    if (!c || c->curve.IsNull()) return -1;
    try {
        Handle(Geom_BSplineCurve) bsp = Handle(Geom_BSplineCurve)::DownCast(c->curve);
        if (!bsp.IsNull()) return bsp->Degree();
        Handle(Geom_BezierCurve) bez = Handle(Geom_BezierCurve)::DownCast(c->curve);
        if (!bez.IsNull()) return bez->Degree();
        return -1;
    } catch (...) {
        return -1;
    }
}

// Operations

OCCTCurve3DRef OCCTCurve3DTrim(OCCTCurve3DRef c, double u1, double u2) {
    if (!c || c->curve.IsNull()) return nullptr;
    try {
        Handle(Geom_TrimmedCurve) trimmed = new Geom_TrimmedCurve(c->curve, u1, u2);
        return new OCCTCurve3D(trimmed);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DReversed(OCCTCurve3DRef c) {
    if (!c || c->curve.IsNull()) return nullptr;
    try {
        Handle(Geom_Curve) rev = Handle(Geom_Curve)::DownCast(c->curve->Reversed());
        if (rev.IsNull()) return nullptr;
        return new OCCTCurve3D(rev);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DTranslate(OCCTCurve3DRef c, double dx, double dy, double dz) {
    if (!c || c->curve.IsNull()) return nullptr;
    try {
        Handle(Geom_Curve) copy = Handle(Geom_Curve)::DownCast(c->curve->Copy());
        gp_Trsf t;
        t.SetTranslation(gp_Vec(dx, dy, dz));
        copy->Transform(t);
        return new OCCTCurve3D(copy);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DRotate(OCCTCurve3DRef c,
                                  double axisOx, double axisOy, double axisOz,
                                  double axisDx, double axisDy, double axisDz,
                                  double angle) {
    if (!c || c->curve.IsNull()) return nullptr;
    try {
        Handle(Geom_Curve) copy = Handle(Geom_Curve)::DownCast(c->curve->Copy());
        gp_Ax1 axis(gp_Pnt(axisOx, axisOy, axisOz), gp_Dir(axisDx, axisDy, axisDz));
        gp_Trsf t;
        t.SetRotation(axis, angle);
        copy->Transform(t);
        return new OCCTCurve3D(copy);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DScale(OCCTCurve3DRef c,
                                 double cx, double cy, double cz, double factor) {
    if (!c || c->curve.IsNull()) return nullptr;
    try {
        Handle(Geom_Curve) copy = Handle(Geom_Curve)::DownCast(c->curve->Copy());
        gp_Trsf t;
        t.SetScale(gp_Pnt(cx, cy, cz), factor);
        copy->Transform(t);
        return new OCCTCurve3D(copy);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DMirrorPoint(OCCTCurve3DRef c,
                                       double px, double py, double pz) {
    if (!c || c->curve.IsNull()) return nullptr;
    try {
        Handle(Geom_Curve) copy = Handle(Geom_Curve)::DownCast(c->curve->Copy());
        gp_Trsf t;
        t.SetMirror(gp_Pnt(px, py, pz));
        copy->Transform(t);
        return new OCCTCurve3D(copy);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DMirrorAxis(OCCTCurve3DRef c,
                                      double px, double py, double pz,
                                      double dx, double dy, double dz) {
    if (!c || c->curve.IsNull()) return nullptr;
    try {
        Handle(Geom_Curve) copy = Handle(Geom_Curve)::DownCast(c->curve->Copy());
        gp_Ax1 axis(gp_Pnt(px, py, pz), gp_Dir(dx, dy, dz));
        gp_Trsf t;
        t.SetMirror(axis);
        copy->Transform(t);
        return new OCCTCurve3D(copy);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DMirrorPlane(OCCTCurve3DRef c,
                                       double px, double py, double pz,
                                       double nx, double ny, double nz) {
    if (!c || c->curve.IsNull()) return nullptr;
    try {
        Handle(Geom_Curve) copy = Handle(Geom_Curve)::DownCast(c->curve->Copy());
        gp_Ax2 plane(gp_Pnt(px, py, pz), gp_Dir(nx, ny, nz));
        gp_Trsf t;
        t.SetMirror(plane);
        copy->Transform(t);
        return new OCCTCurve3D(copy);
    } catch (...) {
        return nullptr;
    }
}

double OCCTCurve3DGetLength(OCCTCurve3DRef c) {
    if (!c || c->curve.IsNull()) return -1.0;
    try {
        GeomAdaptor_Curve adaptor(c->curve);
        return CPnts_AbscissaPoint::Length(adaptor);
    } catch (...) {
        return -1.0;
    }
}

double OCCTCurve3DGetLengthBetween(OCCTCurve3DRef c, double u1, double u2) {
    if (!c || c->curve.IsNull()) return -1.0;
    try {
        GeomAdaptor_Curve adaptor(c->curve);
        return CPnts_AbscissaPoint::Length(adaptor, u1, u2);
    } catch (...) {
        return -1.0;
    }
}

// Conversion (GeomConvert)

OCCTCurve3DRef OCCTCurve3DToBSpline(OCCTCurve3DRef c) {
    if (!c || c->curve.IsNull()) return nullptr;
    try {
        Handle(Geom_BSplineCurve) bsp = GeomConvert::CurveToBSplineCurve(c->curve);
        if (bsp.IsNull()) return nullptr;
        return new OCCTCurve3D(bsp);
    } catch (...) {
        return nullptr;
    }
}

int32_t OCCTCurve3DBSplineToBeziers(OCCTCurve3DRef c,
                                     OCCTCurve3DRef* out, int32_t max) {
    if (!c || c->curve.IsNull() || !out || max <= 0) return 0;
    try {
        Handle(Geom_BSplineCurve) bsp = Handle(Geom_BSplineCurve)::DownCast(c->curve);
        if (bsp.IsNull()) {
            bsp = GeomConvert::CurveToBSplineCurve(c->curve);
            if (bsp.IsNull()) return 0;
        }

        GeomConvert_BSplineCurveToBezierCurve converter(bsp);
        int32_t n = std::min((int32_t)converter.NbArcs(), max);
        for (int32_t i = 0; i < n; i++) {
            Handle(Geom_BezierCurve) arc = converter.Arc(i + 1);
            out[i] = new OCCTCurve3D(arc);
        }
        return n;
    } catch (...) {
        return 0;
    }
}

void OCCTCurve3DFreeArray(OCCTCurve3DRef* curves, int32_t count) {
    if (!curves) return;
    for (int32_t i = 0; i < count; i++) {
        delete curves[i];
        curves[i] = nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DJoinToBSpline(const OCCTCurve3DRef* curves, int32_t count,
                                         double tolerance) {
    if (!curves || count < 1) return nullptr;
    try {
        if (!curves[0] || curves[0]->curve.IsNull()) return nullptr;

        Handle(Geom_BSplineCurve) first = GeomConvert::CurveToBSplineCurve(curves[0]->curve);
        if (first.IsNull()) return nullptr;

        GeomConvert_CompCurveToBSplineCurve joiner(first);
        for (int32_t i = 1; i < count; i++) {
            if (!curves[i] || curves[i]->curve.IsNull()) continue;
            Handle(Geom_BSplineCurve) bsp = GeomConvert::CurveToBSplineCurve(curves[i]->curve);
            if (!bsp.IsNull()) {
                joiner.Add(bsp, tolerance);
            }
        }
        return new OCCTCurve3D(joiner.BSplineCurve());
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DApproximate(OCCTCurve3DRef c, double tolerance,
                                       int32_t continuity, int32_t maxSegments,
                                       int32_t maxDegree) {
    if (!c || c->curve.IsNull()) return nullptr;
    try {
        GeomAbs_Shape cont = GeomAbs_C2;
        switch (continuity) {
            case 0: cont = GeomAbs_C0; break;
            case 1: cont = GeomAbs_C1; break;
            case 2: cont = GeomAbs_C2; break;
            case 3: cont = GeomAbs_C3; break;
        }

        GeomConvert_ApproxCurve approx(c->curve, tolerance, cont, maxSegments, maxDegree);
        if (!approx.IsDone()) return nullptr;

        return new OCCTCurve3D(approx.Curve());
    } catch (...) {
        return nullptr;
    }
}

// Draw Methods

int32_t OCCTCurve3DDrawAdaptive(OCCTCurve3DRef c,
                                 double angularDefl, double chordalDefl,
                                 double* outXYZ, int32_t maxPoints) {
    if (!c || c->curve.IsNull() || !outXYZ || maxPoints <= 0) return 0;
    try {
        GeomAdaptor_Curve adaptor(c->curve);
        GCPnts_TangentialDeflection sampler(adaptor, angularDefl, chordalDefl);
        int32_t n = std::min((int32_t)sampler.NbPoints(), maxPoints);
        for (int32_t i = 0; i < n; i++) {
            gp_Pnt p = sampler.Value(i + 1);
            outXYZ[i*3] = p.X();
            outXYZ[i*3+1] = p.Y();
            outXYZ[i*3+2] = p.Z();
        }
        return n;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTCurve3DDrawUniform(OCCTCurve3DRef c,
                                int32_t pointCount, double* outXYZ) {
    if (!c || c->curve.IsNull() || !outXYZ || pointCount <= 0) return 0;
    try {
        GeomAdaptor_Curve adaptor(c->curve);
        GCPnts_UniformAbscissa sampler(adaptor, pointCount);
        if (!sampler.IsDone()) return 0;
        int32_t n = sampler.NbPoints();
        for (int32_t i = 0; i < n; i++) {
            double u = sampler.Parameter(i + 1);
            gp_Pnt p = adaptor.Value(u);
            outXYZ[i*3] = p.X();
            outXYZ[i*3+1] = p.Y();
            outXYZ[i*3+2] = p.Z();
        }
        return n;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTCurve3DDrawDeflection(OCCTCurve3DRef c, double deflection,
                                   double* outXYZ, int32_t maxPoints) {
    if (!c || c->curve.IsNull() || !outXYZ || maxPoints <= 0) return 0;
    try {
        GeomAdaptor_Curve adaptor(c->curve);
        GCPnts_UniformDeflection sampler(adaptor, deflection);
        if (!sampler.IsDone()) return 0;
        int32_t n = std::min((int32_t)sampler.NbPoints(), maxPoints);
        for (int32_t i = 0; i < n; i++) {
            gp_Pnt p = sampler.Value(i + 1);
            outXYZ[i*3] = p.X();
            outXYZ[i*3+1] = p.Y();
            outXYZ[i*3+2] = p.Z();
        }
        return n;
    } catch (...) {
        return 0;
    }
}

// Local Properties

double OCCTCurve3DGetCurvature(OCCTCurve3DRef c, double u) {
    if (!c || c->curve.IsNull()) return 0.0;
    try {
        GeomLProp_CLProps props(c->curve, 2, Precision::Confusion());
        props.SetParameter(u);
        if (!props.IsTangentDefined()) return 0.0;
        return props.Curvature();
    } catch (...) {
        return 0.0;
    }
}

bool OCCTCurve3DGetTangent(OCCTCurve3DRef c, double u,
                            double* tx, double* ty, double* tz) {
    if (!c || c->curve.IsNull() || !tx || !ty || !tz) return false;
    try {
        GeomLProp_CLProps props(c->curve, 1, Precision::Confusion());
        props.SetParameter(u);
        if (!props.IsTangentDefined()) return false;
        gp_Dir dir;
        props.Tangent(dir);
        *tx = dir.X(); *ty = dir.Y(); *tz = dir.Z();
        return true;
    } catch (...) {
        return false;
    }
}

bool OCCTCurve3DGetNormal(OCCTCurve3DRef c, double u,
                           double* nx, double* ny, double* nz) {
    if (!c || c->curve.IsNull() || !nx || !ny || !nz) return false;
    try {
        GeomLProp_CLProps props(c->curve, 2, Precision::Confusion());
        props.SetParameter(u);
        if (!props.IsTangentDefined()) return false;
        gp_Dir dir;
        props.Normal(dir);
        *nx = dir.X(); *ny = dir.Y(); *nz = dir.Z();
        return true;
    } catch (...) {
        return false;
    }
}

bool OCCTCurve3DGetCenterOfCurvature(OCCTCurve3DRef c, double u,
                                      double* cx, double* cy, double* cz) {
    if (!c || c->curve.IsNull() || !cx || !cy || !cz) return false;
    try {
        GeomLProp_CLProps props(c->curve, 2, Precision::Confusion());
        props.SetParameter(u);
        if (!props.IsTangentDefined()) return false;
        if (props.Curvature() < Precision::Confusion()) return false;
        gp_Pnt center;
        props.CentreOfCurvature(center);
        *cx = center.X(); *cy = center.Y(); *cz = center.Z();
        return true;
    } catch (...) {
        return false;
    }
}

double OCCTCurve3DGetTorsion(OCCTCurve3DRef c, double u) {
    if (!c || c->curve.IsNull()) return 0.0;
    try {
        gp_Pnt pnt;
        gp_Vec d1, d2, d3;
        c->curve->D3(u, pnt, d1, d2, d3);

        gp_Vec cross = d1.Crossed(d2);
        double crossMag2 = cross.SquareMagnitude();
        if (crossMag2 < Precision::Confusion()) return 0.0;
        return cross.Dot(d3) / crossMag2;
    } catch (...) {
        return 0.0;
    }
}

// Bounding Box

bool OCCTCurve3DGetBoundingBox(OCCTCurve3DRef c,
                                double* xMin, double* yMin, double* zMin,
                                double* xMax, double* yMax, double* zMax) {
    if (!c || c->curve.IsNull() || !xMin || !yMin || !zMin || !xMax || !yMax || !zMax)
        return false;
    try {
        GeomAdaptor_Curve adaptor(c->curve);
        Bnd_Box box;
        BndLib_Add3dCurve::Add(adaptor, 0.01, box);
        if (box.IsVoid()) return false;
        box.Get(*xMin, *yMin, *zMin, *xMax, *yMax, *zMax);
        return true;
    } catch (...) {
        return false;
    }
}

// ============================================================================
// MARK: - Batch Curve3D Evaluation (v0.29.0)

#include <GeomGridEval_Curve.hxx>
#include <GeomGridEval.hxx>

int32_t OCCTCurve3DEvaluateGrid(OCCTCurve3DRef curve, const double* params, int32_t paramCount,
                                 double* outXYZ) {
    if (!curve || curve->curve.IsNull() || !params || !outXYZ || paramCount <= 0) return 0;
    try {
        GeomGridEval_Curve evaluator(curve->curve);

        NCollection_Array1<double> paramArr(1, paramCount);
        for (int32_t i = 0; i < paramCount; i++) {
            paramArr.SetValue(i + 1, params[i]);
        }

        NCollection_Array1<gp_Pnt> results = evaluator.EvaluateGrid(paramArr);
        int32_t n = results.Size();
        for (int32_t i = 0; i < n; i++) {
            const gp_Pnt& pt = results.Value(i + 1);
            outXYZ[i*3]   = pt.X();
            outXYZ[i*3+1] = pt.Y();
            outXYZ[i*3+2] = pt.Z();
        }
        return n;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTCurve3DEvaluateGridD1(OCCTCurve3DRef curve, const double* params, int32_t paramCount,
                                   double* outXYZ, double* outDXDYDZ) {
    if (!curve || curve->curve.IsNull() || !params || !outXYZ || !outDXDYDZ || paramCount <= 0) return 0;
    try {
        GeomGridEval_Curve evaluator(curve->curve);

        NCollection_Array1<double> paramArr(1, paramCount);
        for (int32_t i = 0; i < paramCount; i++) {
            paramArr.SetValue(i + 1, params[i]);
        }

        NCollection_Array1<GeomGridEval::CurveD1> results = evaluator.EvaluateGridD1(paramArr);
        int32_t n = results.Size();
        for (int32_t i = 0; i < n; i++) {
            const GeomGridEval::CurveD1& r = results.Value(i + 1);
            outXYZ[i*3]     = r.Point.X();
            outXYZ[i*3+1]   = r.Point.Y();
            outXYZ[i*3+2]   = r.Point.Z();
            outDXDYDZ[i*3]   = r.D1.X();
            outDXDYDZ[i*3+1] = r.D1.Y();
            outDXDYDZ[i*3+2] = r.D1.Z();
        }
        return n;
    } catch (...) {
        return 0;
    }
}

// MARK: - Curve Planarity Check (v0.29.0)

#include <ShapeAnalysis_Curve.hxx>

bool OCCTCurve3DIsPlanar(OCCTCurve3DRef curve, double tolerance,
                          double* outNX, double* outNY, double* outNZ) {
    if (!curve || curve->curve.IsNull()) return false;
    try {
        ShapeAnalysis_Curve analyzer;
        gp_XYZ normal;
        bool result = analyzer.IsPlanar(curve->curve, normal, tolerance);
        if (result) {
            if (outNX) *outNX = normal.X();
            if (outNY) *outNY = normal.Y();
            if (outNZ) *outNZ = normal.Z();
            return true;
        }
        return false;
    } catch (...) {
        return false;
    }
}

// MARK: - Curve-Curve Extrema (v0.30.0)

#include <GeomAPI_ExtremaCurveCurve.hxx>

double OCCTCurve3DMinDistanceToCurve(OCCTCurve3DRef c1, OCCTCurve3DRef c2) {
    if (!c1 || c1->curve.IsNull() || !c2 || c2->curve.IsNull()) return -1.0;
    try {
        GeomAPI_ExtremaCurveCurve extrema(c1->curve, c2->curve);
        if (extrema.NbExtrema() == 0) return -1.0;
        return extrema.LowerDistance();
    } catch (...) {
        return -1.0;
    }
}

int32_t OCCTCurve3DExtrema(OCCTCurve3DRef c1, OCCTCurve3DRef c2, OCCTCurveExtrema* outExtrema, int32_t maxCount) {
    if (!c1 || c1->curve.IsNull() || !c2 || c2->curve.IsNull() || !outExtrema || maxCount <= 0) return 0;
    try {
        GeomAPI_ExtremaCurveCurve extrema(c1->curve, c2->curve);
        int32_t nb = extrema.NbExtrema();
        int32_t count = (nb < maxCount) ? nb : maxCount;
        for (int32_t i = 0; i < count; i++) {
            gp_Pnt p1, p2;
            extrema.Points(i + 1, p1, p2);
            double u1, u2;
            extrema.Parameters(i + 1, u1, u2);
            outExtrema[i].distance = extrema.Distance(i + 1);
            outExtrema[i].point1[0] = p1.X();
            outExtrema[i].point1[1] = p1.Y();
            outExtrema[i].point1[2] = p1.Z();
            outExtrema[i].point2[0] = p2.X();
            outExtrema[i].point2[1] = p2.Y();
            outExtrema[i].point2[2] = p2.Z();
            outExtrema[i].param1 = u1;
            outExtrema[i].param2 = u2;
        }
        return count;
    } catch (...) {
        return 0;
    }
}

// MARK: - Curve to Analytical (v0.30.0)

#include <GeomConvert_CurveToAnaCurve.hxx>

OCCTCurve3DRef OCCTCurve3DToAnalytical(OCCTCurve3DRef curve, double tolerance) {
    if (!curve || curve->curve.IsNull()) return nullptr;
    try {
        GeomConvert_CurveToAnaCurve converter(curve->curve);
        Handle(Geom_Curve) result;
        double newFirst, newLast;
        bool ok = converter.ConvertToAnalytical(tolerance, result,
                                                 curve->curve->FirstParameter(),
                                                 curve->curve->LastParameter(),
                                                 newFirst, newLast);
        if (!ok || result.IsNull()) return nullptr;
        return new OCCTCurve3D(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Quasi-Uniform Curve Sampling (v0.31.0)

#include <GCPnts_QuasiUniformAbscissa.hxx>

int32_t OCCTCurve3DQuasiUniformAbscissa(OCCTCurve3DRef curve, int32_t nbPoints, double* outParams) {
    if (!curve || curve->curve.IsNull() || !outParams || nbPoints <= 0) return 0;
    try {
        GeomAdaptor_Curve adaptor(curve->curve);
        GCPnts_QuasiUniformAbscissa sampler(adaptor, nbPoints);
        if (!sampler.IsDone()) return 0;
        int32_t n = sampler.NbPoints();
        for (int32_t i = 0; i < n; i++) {
            outParams[i] = sampler.Parameter(i + 1);
        }
        return n;
    } catch (...) {
        return 0;
    }
}

// MARK: - Quasi-Uniform Deflection Sampling (v0.31.0)

#include <GCPnts_QuasiUniformDeflection.hxx>

int32_t OCCTCurve3DQuasiUniformDeflection(OCCTCurve3DRef curve, double deflection, double* outXYZ, int32_t maxPoints) {
    if (!curve || curve->curve.IsNull() || !outXYZ || maxPoints <= 0) return 0;
    try {
        GeomAdaptor_Curve adaptor(curve->curve);
        GCPnts_QuasiUniformDeflection sampler(adaptor, deflection);
        if (!sampler.IsDone()) return 0;
        int32_t n = std::min((int32_t)sampler.NbPoints(), maxPoints);
        for (int32_t i = 0; i < n; i++) {
            gp_Pnt p = sampler.Value(i + 1);
            outXYZ[i*3] = p.X();
            outXYZ[i*3+1] = p.Y();
            outXYZ[i*3+2] = p.Z();
        }
        return n;
    } catch (...) {
        return 0;
    }
}

OCCTCurve3DRef OCCTCurve3DArcOfEllipse(double centerX, double centerY, double centerZ,
                                         double normalX, double normalY, double normalZ,
                                         double majorRadius, double minorRadius,
                                         double angle1, double angle2, bool sense) {
    try {
        gp_Ax2 ax(gp_Pnt(centerX, centerY, centerZ), gp_Dir(normalX, normalY, normalZ));
        gp_Elips elips(ax, majorRadius, minorRadius);
        GC_MakeArcOfEllipse maker(elips, angle1, angle2, sense);
        if (!maker.IsDone()) return nullptr;
        return new OCCTCurve3D(maker.Value());
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DArcOfEllipsePoints(double centerX, double centerY, double centerZ,
                                               double normalX, double normalY, double normalZ,
                                               double majorRadius, double minorRadius,
                                               double p1X, double p1Y, double p1Z,
                                               double p2X, double p2Y, double p2Z, bool sense) {
    try {
        gp_Ax2 ax(gp_Pnt(centerX, centerY, centerZ), gp_Dir(normalX, normalY, normalZ));
        gp_Elips elips(ax, majorRadius, minorRadius);
        GC_MakeArcOfEllipse maker(elips, gp_Pnt(p1X, p1Y, p1Z), gp_Pnt(p2X, p2Y, p2Z), sense);
        if (!maker.IsDone()) return nullptr;
        return new OCCTCurve3D(maker.Value());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Approx_Curve3d (v0.46)
OCCTCurve3DRef OCCTEdgeApproxCurve(OCCTEdgeRef edge, double tolerance,
                                     int32_t maxSegments, int32_t maxDegree) {
    if (!edge) return nullptr;
    try {
        BRepAdaptor_Curve adaptorCurve(edge->edge);
        Approx_Curve3d approx(new BRepAdaptor_Curve(adaptorCurve),
                               tolerance, GeomAbs_C2, maxSegments, maxDegree);
        if (!approx.IsDone() && !approx.HasResult()) return nullptr;
        auto bspline = approx.Curve();
        if (bspline.IsNull()) return nullptr;
        return new OCCTCurve3D(bspline);
    } catch (...) {
        return nullptr;
    }
}

bool OCCTEdgeApproxCurveInfo(OCCTEdgeRef edge, double tolerance,
                              int32_t maxSegments, int32_t maxDegree,
                              double* outMaxError, int32_t* outDegree, int32_t* outNbPoles) {
    if (!edge || !outMaxError || !outDegree || !outNbPoles) return false;
    try {
        BRepAdaptor_Curve adaptorCurve(edge->edge);
        Approx_Curve3d approx(new BRepAdaptor_Curve(adaptorCurve),
                               tolerance, GeomAbs_C2, maxSegments, maxDegree);
        if (!approx.IsDone() && !approx.HasResult()) return false;
        *outMaxError = approx.MaxError();
        auto bspline = approx.Curve();
        if (bspline.IsNull()) return false;
        *outDegree = bspline->Degree();
        *outNbPoles = bspline->NbPoles();
        return true;
    } catch (...) {
        return false;
    }
}

// MARK: - GeomConvert_CompCurveToBSplineCurve Join (v0.49)
// --- GeomConvert_CompCurveToBSplineCurve ---

OCCTCurve3DRef OCCTCurve3DJoinCurves(const OCCTCurve3DRef* curves, int32_t count, double tolerance) {
    if (!curves || count < 1) return nullptr;
    try {
        // First curve initializes the joiner
        Handle(Geom_BoundedCurve) first = Handle(Geom_BoundedCurve)::DownCast(curves[0]->curve);
        if (first.IsNull()) return nullptr;

        GeomConvert_CompCurveToBSplineCurve joiner(first);

        for (int i = 1; i < count; i++) {
            if (!curves[i]) return nullptr;
            Handle(Geom_BoundedCurve) bc = Handle(Geom_BoundedCurve)::DownCast(curves[i]->curve);
            if (bc.IsNull()) return nullptr;
            if (!joiner.Add(bc, tolerance)) return nullptr;
        }

        Handle(Geom_BSplineCurve) bsp = joiner.BSplineCurve();
        if (bsp.IsNull()) return nullptr;

        auto* result = new OCCTCurve3D();
        result->curve = bsp;
        return result;
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Curve3D Projection / Validate / Sample (v0.49)
// --- ShapeAnalysis_Curve expansion ---

OCCTCurveProjectResult OCCTCurve3DProjectPoint(OCCTCurve3DRef curve,
    double px, double py, double pz, double precision) {
    OCCTCurveProjectResult result = {};
    if (!curve) return result;
    try {
        ShapeAnalysis_Curve sac;
        gp_Pnt proj;
        double param;
        double dist = sac.Project(curve->curve, gp_Pnt(px, py, pz), precision, proj, param);
        result.distance = dist;
        result.parameter = param;
        result.projX = proj.X();
        result.projY = proj.Y();
        result.projZ = proj.Z();
        return result;
    } catch (...) {
        return result;
    }
}

OCCTCurveValidateRangeResult OCCTCurve3DValidateRange(OCCTCurve3DRef curve,
    double first, double last, double precision) {
    OCCTCurveValidateRangeResult result = {};
    result.first = first;
    result.last = last;
    result.wasAdjusted = false;
    if (!curve) return result;
    try {
        ShapeAnalysis_Curve sac;
        double f = first, l = last;
        bool adjusted = sac.ValidateRange(curve->curve, f, l, precision);
        result.first = f;
        result.last = l;
        result.wasAdjusted = adjusted;
        return result;
    } catch (...) {
        return result;
    }
}

int32_t OCCTCurve3DGetSamplePoints3D(OCCTCurve3DRef curve, double first, double last,
    double* outXYZ, int32_t maxPoints) {
    if (!curve || !outXYZ || maxPoints <= 0) return 0;
    try {
        ShapeAnalysis_Curve sac;
        NCollection_Sequence<gp_Pnt> pts;
        if (!sac.GetSamplePoints(curve->curve, first, last, pts)) return 0;

        int32_t count = std::min((int32_t)pts.Length(), maxPoints);
        for (int32_t i = 0; i < count; i++) {
            const gp_Pnt& p = pts.Value(i + 1); // 1-indexed
            outXYZ[i * 3]     = p.X();
            outXYZ[i * 3 + 1] = p.Y();
            outXYZ[i * 3 + 2] = p.Z();
        }
        return count;
    } catch (...) {
        return 0;
    }
}

// MARK: - GC ArcOfHyperbola / ArcOfParabola (v0.50)
OCCTCurve3DRef OCCTCurve3DArcOfHyperbola(
    double majorRadius, double minorRadius,
    double axisX, double axisY, double axisZ,
    double dirX, double dirY, double dirZ,
    double alpha1, double alpha2, bool sense) {
    try {
        gp_Ax2 ax(gp_Pnt(axisX, axisY, axisZ), gp_Dir(dirX, dirY, dirZ));
        gp_Hypr hypr(ax, majorRadius, minorRadius);
        GC_MakeArcOfHyperbola maker(hypr, alpha1, alpha2, sense ? Standard_True : Standard_False);
        if (!maker.IsDone()) return nullptr;
        Handle(Geom_TrimmedCurve) arc = maker.Value();
        if (arc.IsNull()) return nullptr;
        auto* ref = new OCCTCurve3D();
        ref->curve = arc;
        return ref;
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DArcOfParabola(
    double focalDistance,
    double axisX, double axisY, double axisZ,
    double dirX, double dirY, double dirZ,
    double alpha1, double alpha2, bool sense) {
    try {
        gp_Ax2 ax(gp_Pnt(axisX, axisY, axisZ), gp_Dir(dirX, dirY, dirZ));
        gp_Parab parab(ax, focalDistance);
        GC_MakeArcOfParabola maker(parab, alpha1, alpha2, sense ? Standard_True : Standard_False);
        if (!maker.IsDone()) return nullptr;
        Handle(Geom_TrimmedCurve) arc = maker.Value();
        if (arc.IsNull()) return nullptr;
        auto* ref = new OCCTCurve3D();
        ref->curve = arc;
        return ref;
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Curve3D ConvertToPeriodic / SplitAt (v0.50)
OCCTCurve3DRef OCCTCurve3DConvertToPeriodic(OCCTCurve3DRef curve) {
    if (!curve) return nullptr;
    try {
        ShapeCustom_Curve scc(curve->curve);
        Handle(Geom_Curve) periodic = scc.ConvertToPeriodic(Standard_False);
        if (periodic.IsNull()) return nullptr;
        auto* ref = new OCCTCurve3D();
        ref->curve = periodic;
        return ref;
    } catch (...) {
        return nullptr;
    }
}

bool OCCTCurve3DSplitAt(OCCTCurve3DRef curve, double splitParam,
    OCCTCurve3DRef* outCurve1, OCCTCurve3DRef* outCurve2) {
    if (!curve || !outCurve1 || !outCurve2) return false;
    *outCurve1 = nullptr;
    *outCurve2 = nullptr;
    try {
        Handle(Geom_Curve) c = curve->curve;
        double first = c->FirstParameter();
        double last = c->LastParameter();
        if (splitParam <= first || splitParam >= last) return false;

        Handle(ShapeUpgrade_SplitCurve3d) splitter = new ShapeUpgrade_SplitCurve3d();
        splitter->Init(c, first, last);
        Handle(TColStd_HSequenceOfReal) splitVals = new TColStd_HSequenceOfReal();
        splitVals->Append(splitParam);
        splitter->SetSplitValues(splitVals);
        splitter->Perform(Standard_True);

        Handle(TColGeom_HArray1OfCurve) curves = splitter->GetCurves();
        if (curves.IsNull() || curves->Length() < 2) return false;

        auto* ref1 = new OCCTCurve3D();
        ref1->curve = curves->Value(1);
        *outCurve1 = ref1;

        auto* ref2 = new OCCTCurve3D();
        ref2->curve = curves->Value(2);
        *outCurve2 = ref2;
        return true;
    } catch (...) {
        return false;
    }
}

// MARK: - GC MakeEllipse / MakeHyperbola (v0.51)
// --- GC_MakeEllipse ---

OCCTCurve3DRef _Nullable OCCTCurve3DMakeEllipse(double cx, double cy, double cz,
    double dx, double dy, double dz, double majorRadius, double minorRadius) {
    try {
        gp_Ax2 ax(gp_Pnt(cx, cy, cz), gp_Dir(dx, dy, dz));
        GC_MakeEllipse me(ax, majorRadius, minorRadius);
        if (!me.IsDone()) return nullptr;
        auto* curve = new OCCTCurve3D();
        curve->curve = me.Value();
        return curve;
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef _Nullable OCCTCurve3DMakeEllipseThreePoints(
    double s1x, double s1y, double s1z,
    double s2x, double s2y, double s2z,
    double centerX, double centerY, double centerZ) {
    try {
        GC_MakeEllipse me(gp_Pnt(s1x, s1y, s1z), gp_Pnt(s2x, s2y, s2z),
                          gp_Pnt(centerX, centerY, centerZ));
        if (!me.IsDone()) return nullptr;
        auto* curve = new OCCTCurve3D();
        curve->curve = me.Value();
        return curve;
    } catch (...) {
        return nullptr;
    }
}

// --- GC_MakeHyperbola ---

OCCTCurve3DRef _Nullable OCCTCurve3DMakeHyperbola(double cx, double cy, double cz,
    double dx, double dy, double dz, double majorRadius, double minorRadius) {
    try {
        gp_Ax2 ax(gp_Pnt(cx, cy, cz), gp_Dir(dx, dy, dz));
        GC_MakeHyperbola mh(ax, majorRadius, minorRadius);
        if (!mh.IsDone()) return nullptr;
        auto* curve = new OCCTCurve3D();
        curve->curve = mh.Value();
        return curve;
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef _Nullable OCCTCurve3DMakeHyperbolaThreePoints(
    double s1x, double s1y, double s1z,
    double s2x, double s2y, double s2z,
    double centerX, double centerY, double centerZ) {
    try {
        GC_MakeHyperbola mh(gp_Pnt(s1x, s1y, s1z), gp_Pnt(s2x, s2y, s2z),
                            gp_Pnt(centerX, centerY, centerZ));
        if (!mh.IsDone()) return nullptr;
        auto* curve = new OCCTCurve3D();
        curve->curve = mh.Value();
        return curve;
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Approx_CurveOnSurface (v0.61)
// MARK: - Approx_CurveOnSurface (v0.61.0)

OCCTShapeRef OCCTApproxCurveOnSurface(OCCTShapeRef edge, OCCTShapeRef face,
    double tolerance, int32_t maxSegments, int32_t maxDegree) {
    if (!edge || !face) return nullptr;
    try {
        if (edge->shape.ShapeType() != TopAbs_EDGE) return nullptr;
        if (face->shape.ShapeType() != TopAbs_FACE) return nullptr;
        TopoDS_Edge e = TopoDS::Edge(edge->shape);
        TopoDS_Face f = TopoDS::Face(face->shape);

        // Get PCurve and surface
        double first, last;
        Handle(Geom2d_Curve) pcurve = BRep_Tool::CurveOnSurface(e, f, first, last);
        if (pcurve.IsNull()) return nullptr;

        Handle(Geom_Surface) surface = BRep_Tool::Surface(f);
        if (surface.IsNull()) return nullptr;

        Handle(Geom2dAdaptor_Curve) curveAdaptor = new Geom2dAdaptor_Curve(pcurve, first, last);
        Handle(GeomAdaptor_Surface) surfAdaptor = new GeomAdaptor_Surface(surface);

        Approx_CurveOnSurface approx(curveAdaptor, surfAdaptor, first, last, tolerance);
        approx.Perform(maxSegments, maxDegree, GeomAbs_C2);

        if (!approx.IsDone() || !approx.HasResult()) return nullptr;
        Handle(Geom_BSplineCurve) curve3d = approx.Curve3d();
        if (curve3d.IsNull()) return nullptr;

        BRepBuilderAPI_MakeEdge edgeMaker(curve3d);
        if (!edgeMaker.IsDone()) return nullptr;
        return new OCCTShape(edgeMaker.Edge());
    } catch (...) { return nullptr; }
}

// MARK: - CPnts_UniformDeflection (v0.62)
// --- CPnts_UniformDeflection ---

bool OCCTCPntsUniformDeflection(OCCTShapeRef shape, double deflection,
    double* _Nullable * _Nonnull outParams,
    double* _Nullable * _Nonnull outPoints,
    int32_t* outCount) {
    if (!shape) return false;
    try {
        TopoDS_Edge edge = TopoDS::Edge(shape->shape);
        BRepAdaptor_Curve bac(edge);
        CPnts_UniformDeflection ud(bac, deflection, 1e-7, true);
        std::vector<double> params;
        std::vector<gp_Pnt> pts;
        while (ud.More()) {
            double p = ud.Value();
            params.push_back(p);
            pts.push_back(bac.Value(p));
            ud.Next();
        }
        int32_t n = (int32_t)params.size();
        *outCount = n;
        if (n == 0) { *outParams = nullptr; *outPoints = nullptr; return false; }
        *outParams = (double*)malloc(n * sizeof(double));
        *outPoints = (double*)malloc(n * 3 * sizeof(double));
        for (int32_t i = 0; i < n; i++) {
            (*outParams)[i] = params[i];
            (*outPoints)[i*3]   = pts[i].X();
            (*outPoints)[i*3+1] = pts[i].Y();
            (*outPoints)[i*3+2] = pts[i].Z();
        }
        return true;
    } catch (...) { return false; }
}

bool OCCTCPntsUniformDeflectionRange(OCCTShapeRef shape, double deflection,
    double u1, double u2,
    double* _Nullable * _Nonnull outParams,
    double* _Nullable * _Nonnull outPoints,
    int32_t* outCount) {
    if (!shape) return false;
    try {
        TopoDS_Edge edge = TopoDS::Edge(shape->shape);
        BRepAdaptor_Curve bac(edge);
        CPnts_UniformDeflection ud(bac, deflection, u1, u2, 1e-7, true);
        std::vector<double> params;
        std::vector<gp_Pnt> pts;
        while (ud.More()) {
            double p = ud.Value();
            params.push_back(p);
            pts.push_back(bac.Value(p));
            ud.Next();
        }
        int32_t n = (int32_t)params.size();
        *outCount = n;
        if (n == 0) { *outParams = nullptr; *outPoints = nullptr; return false; }
        *outParams = (double*)malloc(n * sizeof(double));
        *outPoints = (double*)malloc(n * 3 * sizeof(double));
        for (int32_t i = 0; i < n; i++) {
            (*outParams)[i] = params[i];
            (*outPoints)[i*3]   = pts[i].X();
            (*outPoints)[i*3+1] = pts[i].Y();
            (*outPoints)[i*3+2] = pts[i].Z();
        }
        return true;
    } catch (...) { return false; }
}

// MARK: - Approx_CurvilinearParameter (v0.63)
// --- Approx_CurvilinearParameter ---

OCCTShapeRef _Nullable OCCTApproxCurvilinearParameter(OCCTShapeRef edgeShape,
    double tolerance, int maxDegree, int maxSegments) {
    if (!edgeShape) return nullptr;
    try {
        TopoDS_Edge edge = TopoDS::Edge(edgeShape->shape);
        Handle(BRepAdaptor_Curve) adaptor = new BRepAdaptor_Curve(edge);
        Approx_CurvilinearParameter approx(adaptor, tolerance, GeomAbs_C1, maxDegree, maxSegments);
        if (!approx.IsDone() || !approx.HasResult()) return nullptr;
        Handle(Geom_BSplineCurve) curve = approx.Curve3d();
        if (curve.IsNull()) return nullptr;
        BRepBuilderAPI_MakeEdge me(curve);
        if (!me.IsDone()) return nullptr;
        return new OCCTShape(me.Edge());
    } catch (...) { return nullptr; }
}

// MARK: - LocalAnalysis_CurveContinuity (v0.67)
// --- LocalAnalysis_CurveContinuity ---

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

bool OCCTLocalAnalysisCurveContinuity(OCCTCurve3DRef _Nonnull curve1, double u1,
    OCCTCurve3DRef _Nonnull curve2, double u2, int32_t order,
    int32_t* _Nonnull outStatus,
    double* _Nonnull outC0Value, double* _Nonnull outG1Angle,
    double* _Nonnull outC1Angle, double* _Nonnull outC1Ratio,
    double* _Nonnull outC2Angle, double* _Nonnull outC2Ratio,
    double* _Nonnull outG2Angle, double* _Nonnull outG2CurvatureVariation) {
    try {
        auto c1 = (OCCTCurve3D*)curve1;
        auto c2 = (OCCTCurve3D*)curve2;

        LocalAnalysis_CurveContinuity cc(c1->curve, u1, c2->curve, u2, orderToShape(order));
        if (!cc.IsDone()) return false;

        *outStatus = shapeToOrder(cc.ContinuityStatus());
        *outC0Value = cc.C0Value();
        *outG1Angle = cc.IsG1() ? cc.G1Angle() : -1.0;
        *outC1Angle = cc.IsC1() ? cc.C1Angle() : -1.0;
        *outC1Ratio = cc.IsC1() ? cc.C1Ratio() : -1.0;
        *outC2Angle = cc.IsC2() ? cc.C2Angle() : -1.0;
        *outC2Ratio = cc.IsC2() ? cc.C2Ratio() : -1.0;
        *outG2Angle = cc.IsG2() ? cc.G2Angle() : -1.0;
        *outG2CurvatureVariation = cc.IsG2() ? cc.G2CurvatureVariation() : -1.0;
        return true;
    } catch (...) { return false; }
}

int32_t OCCTLocalAnalysisCurveContinuityFlags(OCCTCurve3DRef _Nonnull curve1, double u1,
    OCCTCurve3DRef _Nonnull curve2, double u2, int32_t order) {
    try {
        auto c1 = (OCCTCurve3D*)curve1;
        auto c2 = (OCCTCurve3D*)curve2;

        LocalAnalysis_CurveContinuity cc(c1->curve, u1, c2->curve, u2, orderToShape(order));
        if (!cc.IsDone()) return 0;

        int32_t flags = 0;
        if (cc.IsC0()) flags |= 1;
        if (cc.IsG1()) flags |= 2;
        if (cc.IsC1()) flags |= 4;
        if (cc.IsG2()) flags |= 8;
        if (cc.IsC2()) flags |= 16;
        return flags;
    } catch (...) { return 0; }
}

// MARK: - GeomConvert_ApproxCurve (v0.75)
// --- GeomConvert_ApproxCurve ---

static GeomAbs_Shape intToContinuity(int32_t c) {
    switch (c) {
        case 0: return GeomAbs_C0;
        case 1: return GeomAbs_C1;
        case 2: return GeomAbs_C2;
        case 3: return GeomAbs_C3;
        default: return GeomAbs_C2;
    }
}

OCCTApproxCurveResult OCCTGeomConvertApproxCurve(OCCTCurve3DRef _Nonnull curve,
                                                  double tolerance,
                                                  int32_t continuity,
                                                  int32_t maxSegments,
                                                  int32_t maxDegree) {
    OCCTApproxCurveResult result = {};
    if (!curve) return result;
    try {
        GeomConvert_ApproxCurve approx(curve->curve, tolerance,
                                        intToContinuity(continuity), maxSegments, maxDegree);
        result.isDone = approx.IsDone();
        result.hasResult = approx.HasResult();
        if (result.hasResult) {
            result.maxError = approx.MaxError();
            Handle(Geom_BSplineCurve) bspl = approx.Curve();
            if (!bspl.IsNull()) {
                auto* ref = new OCCTCurve3D();
                ref->curve = bspl;
                result.curve = ref;
            }
        }
    } catch (...) {}
    return result;
}

// MARK: - GCPnts QuasiUniform / TangentialDeflection (v0.75)
// --- GCPnts_QuasiUniformAbscissa ---

int32_t OCCTGCPntsQuasiUniform(OCCTEdgeRef _Nonnull edge,
                                int32_t nbPoints,
                                double* _Nonnull params,
                                int32_t maxParams) {
    if (!edge || nbPoints < 2) return 0;
    try {
        BRepAdaptor_Curve curve(TopoDS::Edge(edge->edge));
        GCPnts_QuasiUniformAbscissa sampler(curve, nbPoints);
        if (!sampler.IsDone()) return 0;
        int32_t count = std::min((int32_t)sampler.NbPoints(), maxParams);
        for (int32_t i = 0; i < count; i++) {
            params[i] = sampler.Parameter(i + 1); // 1-based
        }
        return count;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTGCPntsQuasiUniformCurve(OCCTCurve3DRef _Nonnull curve,
                                      int32_t nbPoints,
                                      double* _Nonnull params,
                                      int32_t maxParams) {
    if (!curve || nbPoints < 2) return 0;
    try {
        GeomAdaptor_Curve adaptor(curve->curve);
        GCPnts_QuasiUniformAbscissa sampler(adaptor, nbPoints);
        if (!sampler.IsDone()) return 0;
        int32_t count = std::min((int32_t)sampler.NbPoints(), maxParams);
        for (int32_t i = 0; i < count; i++) {
            params[i] = sampler.Parameter(i + 1);
        }
        return count;
    } catch (...) {
        return 0;
    }
}

// --- GCPnts_TangentialDeflection ---

int32_t OCCTGCPntsTangentialDeflection(OCCTEdgeRef _Nonnull edge,
                                        double angularDeflection,
                                        double curvatureDeflection,
                                        int32_t minPoints,
                                        double* _Nonnull params,
                                        double* _Nullable coords,
                                        int32_t maxPoints) {
    if (!edge) return 0;
    try {
        BRepAdaptor_Curve curve(TopoDS::Edge(edge->edge));
        GCPnts_TangentialDeflection sampler(curve, angularDeflection, curvatureDeflection,
                                             std::max((int)minPoints, 2));
        int32_t count = std::min((int32_t)sampler.NbPoints(), maxPoints);
        for (int32_t i = 0; i < count; i++) {
            params[i] = sampler.Parameter(i + 1);
            if (coords) {
                gp_Pnt pt = sampler.Value(i + 1);
                coords[i*3] = pt.X();
                coords[i*3+1] = pt.Y();
                coords[i*3+2] = pt.Z();
            }
        }
        return count;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTGCPntsTangentialDeflectionCurve(OCCTCurve3DRef _Nonnull curve,
                                             double angularDeflection,
                                             double curvatureDeflection,
                                             int32_t minPoints,
                                             double* _Nonnull params,
                                             double* _Nullable coords,
                                             int32_t maxPoints) {
    if (!curve) return 0;
    try {
        GeomAdaptor_Curve adaptor(curve->curve);
        GCPnts_TangentialDeflection sampler(adaptor, angularDeflection, curvatureDeflection,
                                             std::max((int)minPoints, 2));
        int32_t count = std::min((int32_t)sampler.NbPoints(), maxPoints);
        for (int32_t i = 0; i < count; i++) {
            params[i] = sampler.Parameter(i + 1);
            if (coords) {
                gp_Pnt pt = sampler.Value(i + 1);
                coords[i*3] = pt.X();
                coords[i*3+1] = pt.Y();
                coords[i*3+2] = pt.Z();
            }
        }
        return count;
    } catch (...) {
        return 0;
    }
}

// MARK: - Geom 3D Entities (CartesianPoint / Direction / Vector / Axis1+2 Placement) (v0.76)
// --- Geom_CartesianPoint ---

struct OCCTGeomPoint3D {
    Handle(Geom_CartesianPoint) point;
};

OCCTGeomPoint3DRef _Nonnull OCCTGeomPoint3DCreate(double x, double y, double z) {
    auto* ref = new OCCTGeomPoint3D();
    ref->point = new Geom_CartesianPoint(x, y, z);
    return ref;
}

void OCCTGeomPoint3DRelease(OCCTGeomPoint3DRef _Nonnull ref) {
    delete ref;
}

double OCCTGeomPoint3DX(OCCTGeomPoint3DRef _Nonnull ref) { return ref->point->X(); }
double OCCTGeomPoint3DY(OCCTGeomPoint3DRef _Nonnull ref) { return ref->point->Y(); }
double OCCTGeomPoint3DZ(OCCTGeomPoint3DRef _Nonnull ref) { return ref->point->Z(); }

void OCCTGeomPoint3DSetCoord(OCCTGeomPoint3DRef _Nonnull ref, double x, double y, double z) {
    ref->point->SetCoord(x, y, z);
}

double OCCTGeomPoint3DDistance(OCCTGeomPoint3DRef _Nonnull ref, OCCTGeomPoint3DRef _Nonnull other) {
    return ref->point->Distance(other->point);
}

double OCCTGeomPoint3DSquareDistance(OCCTGeomPoint3DRef _Nonnull ref, OCCTGeomPoint3DRef _Nonnull other) {
    return ref->point->SquareDistance(other->point);
}

void OCCTGeomPoint3DTranslate(OCCTGeomPoint3DRef _Nonnull ref, double dx, double dy, double dz) {
    gp_Trsf t;
    t.SetTranslation(gp_Vec(dx, dy, dz));
    ref->point->Transform(t);
}

// --- Geom_Direction ---

struct OCCTGeomDirection {
    Handle(Geom_Direction) direction;
};

OCCTGeomDirectionRef _Nonnull OCCTGeomDirectionCreate(double x, double y, double z) {
    auto* ref = new OCCTGeomDirection();
    ref->direction = new Geom_Direction(x, y, z);
    return ref;
}

void OCCTGeomDirectionRelease(OCCTGeomDirectionRef _Nonnull ref) {
    delete ref;
}

void OCCTGeomDirectionCoords(OCCTGeomDirectionRef _Nonnull ref, double* x, double* y, double* z) {
    gp_Dir d = ref->direction->Dir();
    *x = d.X(); *y = d.Y(); *z = d.Z();
}

void OCCTGeomDirectionSetCoord(OCCTGeomDirectionRef _Nonnull ref, double x, double y, double z) {
    ref->direction->SetCoord(x, y, z);
}

OCCTGeomDirectionRef _Nullable OCCTGeomDirectionCrossed(OCCTGeomDirectionRef _Nonnull ref, OCCTGeomDirectionRef _Nonnull other) {
    try {
        Handle(Geom_Vector) cross = ref->direction->Crossed(other->direction);
        if (cross.IsNull()) return nullptr;
        gp_Vec v = cross->Vec();
        auto* result = new OCCTGeomDirection();
        result->direction = new Geom_Direction(v.X(), v.Y(), v.Z());
        return result;
    } catch (...) {
        return nullptr;
    }
}

// --- Geom_VectorWithMagnitude ---

struct OCCTGeomVector3D {
    Handle(Geom_VectorWithMagnitude) vector;
};

OCCTGeomVector3DRef _Nonnull OCCTGeomVector3DCreate(double x, double y, double z) {
    auto* ref = new OCCTGeomVector3D();
    ref->vector = new Geom_VectorWithMagnitude(x, y, z);
    return ref;
}

OCCTGeomVector3DRef _Nonnull OCCTGeomVector3DFromPoints(double x1, double y1, double z1,
                                                         double x2, double y2, double z2) {
    auto* ref = new OCCTGeomVector3D();
    ref->vector = new Geom_VectorWithMagnitude(gp_Pnt(x1, y1, z1), gp_Pnt(x2, y2, z2));
    return ref;
}

void OCCTGeomVector3DRelease(OCCTGeomVector3DRef _Nonnull ref) {
    delete ref;
}

void OCCTGeomVector3DCoords(OCCTGeomVector3DRef _Nonnull ref, double* x, double* y, double* z) {
    gp_Vec v = ref->vector->Vec();
    *x = v.X(); *y = v.Y(); *z = v.Z();
}

double OCCTGeomVector3DMagnitude(OCCTGeomVector3DRef _Nonnull ref) {
    return ref->vector->Magnitude();
}

double OCCTGeomVector3DDot(OCCTGeomVector3DRef _Nonnull ref, OCCTGeomVector3DRef _Nonnull other) {
    return ref->vector->Dot(other->vector);
}

OCCTGeomVector3DRef _Nonnull OCCTGeomVector3DAdded(OCCTGeomVector3DRef _Nonnull ref, OCCTGeomVector3DRef _Nonnull other) {
    auto* result = new OCCTGeomVector3D();
    result->vector = ref->vector->Added(other->vector);
    return result;
}

OCCTGeomVector3DRef _Nonnull OCCTGeomVector3DMultiplied(OCCTGeomVector3DRef _Nonnull ref, double scalar) {
    auto* result = new OCCTGeomVector3D();
    result->vector = ref->vector->Multiplied(scalar);
    return result;
}

OCCTGeomVector3DRef _Nullable OCCTGeomVector3DNormalized(OCCTGeomVector3DRef _Nonnull ref) {
    try {
        auto* result = new OCCTGeomVector3D();
        result->vector = ref->vector->Normalized();
        return result;
    } catch (...) {
        return nullptr;
    }
}

OCCTGeomVector3DRef _Nonnull OCCTGeomVector3DCrossed(OCCTGeomVector3DRef _Nonnull ref, OCCTGeomVector3DRef _Nonnull other) {
    Handle(Geom_Vector) cross = ref->vector->Crossed(other->vector);
    gp_Vec v = cross->Vec();
    auto* result = new OCCTGeomVector3D();
    result->vector = new Geom_VectorWithMagnitude(v);
    return result;
}

// --- Geom_Axis1Placement ---

struct OCCTAxis1Placement {
    Handle(Geom_Axis1Placement) axis;
};

OCCTAxis1PlacementRef _Nonnull OCCTAxis1PlacementCreate(double px, double py, double pz,
                                                         double dx, double dy, double dz) {
    auto* ref = new OCCTAxis1Placement();
    ref->axis = new Geom_Axis1Placement(gp_Pnt(px, py, pz), gp_Dir(dx, dy, dz));
    return ref;
}

void OCCTAxis1PlacementRelease(OCCTAxis1PlacementRef _Nonnull ref) {
    delete ref;
}

void OCCTAxis1PlacementLocation(OCCTAxis1PlacementRef _Nonnull ref, double* x, double* y, double* z) {
    gp_Pnt p = ref->axis->Location();
    *x = p.X(); *y = p.Y(); *z = p.Z();
}

void OCCTAxis1PlacementDirection(OCCTAxis1PlacementRef _Nonnull ref, double* x, double* y, double* z) {
    gp_Dir d = ref->axis->Direction();
    *x = d.X(); *y = d.Y(); *z = d.Z();
}

void OCCTAxis1PlacementReverse(OCCTAxis1PlacementRef _Nonnull ref) {
    ref->axis->Reverse();
}

OCCTAxis1PlacementRef _Nonnull OCCTAxis1PlacementReversed(OCCTAxis1PlacementRef _Nonnull ref) {
    auto* result = new OCCTAxis1Placement();
    result->axis = ref->axis->Reversed();
    return result;
}

void OCCTAxis1PlacementSetDirection(OCCTAxis1PlacementRef _Nonnull ref, double dx, double dy, double dz) {
    ref->axis->SetDirection(gp_Dir(dx, dy, dz));
}

void OCCTAxis1PlacementSetLocation(OCCTAxis1PlacementRef _Nonnull ref, double px, double py, double pz) {
    ref->axis->SetLocation(gp_Pnt(px, py, pz));
}

// --- Geom_Axis2Placement ---

struct OCCTAxis2Placement {
    Handle(Geom_Axis2Placement) axis;
};

OCCTAxis2PlacementRef _Nonnull OCCTAxis2PlacementCreate(double px, double py, double pz,
                                                         double nx, double ny, double nz,
                                                         double vx, double vy, double vz) {
    auto* ref = new OCCTAxis2Placement();
    ref->axis = new Geom_Axis2Placement(gp_Pnt(px, py, pz), gp_Dir(nx, ny, nz), gp_Dir(vx, vy, vz));
    return ref;
}

void OCCTAxis2PlacementRelease(OCCTAxis2PlacementRef _Nonnull ref) {
    delete ref;
}

void OCCTAxis2PlacementLocation(OCCTAxis2PlacementRef _Nonnull ref, double* x, double* y, double* z) {
    gp_Pnt p = ref->axis->Location();
    *x = p.X(); *y = p.Y(); *z = p.Z();
}

void OCCTAxis2PlacementDirection(OCCTAxis2PlacementRef _Nonnull ref, double* x, double* y, double* z) {
    gp_Dir d = ref->axis->Direction();
    *x = d.X(); *y = d.Y(); *z = d.Z();
}

void OCCTAxis2PlacementXDirection(OCCTAxis2PlacementRef _Nonnull ref, double* x, double* y, double* z) {
    gp_Dir d = ref->axis->XDirection();
    *x = d.X(); *y = d.Y(); *z = d.Z();
}

void OCCTAxis2PlacementYDirection(OCCTAxis2PlacementRef _Nonnull ref, double* x, double* y, double* z) {
    gp_Dir d = ref->axis->YDirection();
    *x = d.X(); *y = d.Y(); *z = d.Z();
}

void OCCTAxis2PlacementSetDirection(OCCTAxis2PlacementRef _Nonnull ref, double nx, double ny, double nz) {
    ref->axis->SetDirection(gp_Dir(nx, ny, nz));
}

void OCCTAxis2PlacementSetXDirection(OCCTAxis2PlacementRef _Nonnull ref, double vx, double vy, double vz) {
    ref->axis->SetXDirection(gp_Dir(vx, vy, vz));
}

// MARK: - ShapeConstruct Curve3D Convert + Adjust (v0.76)
// --- ShapeConstruct_Curve ---

OCCTCurve3DRef _Nullable OCCTShapeConstructConvertToBSpline3D(OCCTCurve3DRef _Nonnull curve,
                                                                double first, double last, double precision) {
    if (!curve) return nullptr;
    try {
        ShapeConstruct_Curve scc;
        Handle(Geom_BSplineCurve) bsp = scc.ConvertToBSpline(curve->curve, first, last, precision);
        if (bsp.IsNull()) return nullptr;
        auto* ref = new OCCTCurve3D();
        ref->curve = bsp;
        return ref;
    } catch (...) {
        return nullptr;
    }
}
bool OCCTShapeConstructAdjustCurve3D(OCCTCurve3DRef _Nonnull curve,
                                      double p1x, double p1y, double p1z,
                                      double p2x, double p2y, double p2z) {
    if (!curve) return false;
    try {
        ShapeConstruct_Curve scc;
        return scc.AdjustCurve(curve->curve, gp_Pnt(p1x, p1y, p1z), gp_Pnt(p2x, p2y, p2z));
    } catch (...) {
        return false;
    }
}

// MARK: - GeomLib_Tool Param3D (v0.77)
bool OCCTGeomLibToolParameter3D(OCCTCurve3DRef _Nonnull curveRef, double px, double py, double pz,
                                 double maxDist, double* _Nonnull outParam) {
    try {
        auto& curve = reinterpret_cast<OCCTCurve3D*>(curveRef)->curve;
        double param = 0;
        bool ok = GeomLib_Tool::Parameter(curve, gp_Pnt(px, py, pz), maxDist, param);
        if (ok) *outParam = param;
        return ok;
    } catch (...) {
        return false;
    }
}

// MARK: - GeomLib_Check + Fix BSpline 3D (v0.77)
// MARK: - GeomLib_CheckBSplineCurve / Check2dBSplineCurve

bool OCCTGeomLibCheckBSpline3D(OCCTCurve3DRef _Nonnull curveRef, double tolerance, double angularTol,
                                bool* _Nonnull needFixFirst, bool* _Nonnull needFixLast) {
    try {
        auto& curve = reinterpret_cast<OCCTCurve3D*>(curveRef)->curve;
        Handle(Geom_BSplineCurve) bsp = Handle(Geom_BSplineCurve)::DownCast(curve);
        if (bsp.IsNull()) return false;
        GeomLib_CheckBSplineCurve checker(bsp, tolerance, angularTol);
        if (!checker.IsDone()) return false;
        bool f = false, l = false;
        checker.NeedTangentFix(f, l);
        *needFixFirst = f;
        *needFixLast = l;
        return true;
    } catch (...) {
        return false;
    }
}

OCCTCurve3DRef _Nullable OCCTGeomLibFixBSpline3D(OCCTCurve3DRef _Nonnull curveRef,
                                                   double tolerance, double angularTol,
                                                   bool fixFirst, bool fixLast) {
    try {
        auto& curve = reinterpret_cast<OCCTCurve3D*>(curveRef)->curve;
        Handle(Geom_BSplineCurve) bsp = Handle(Geom_BSplineCurve)::DownCast(curve);
        if (bsp.IsNull()) return nullptr;
        GeomLib_CheckBSplineCurve checker(bsp, tolerance, angularTol);
        Handle(Geom_BSplineCurve) fixed = checker.FixedTangent(fixFirst, fixLast);
        if (fixed.IsNull()) return nullptr;
        return reinterpret_cast<OCCTCurve3DRef>(new OCCTCurve3D{fixed});
    } catch (...) {
        return nullptr;
    }
}

// MARK: - GeomLib_Interpolate (v0.77)
// MARK: - GeomLib_Interpolate

OCCTCurve3DRef _Nullable OCCTGeomLibInterpolate(int degree, int numPoints,
                                                  const double* _Nonnull pointsXYZ,
                                                  const double* _Nonnull parameters) {
    try {
        NCollection_Array1<gp_Pnt> pts(1, numPoints);
        NCollection_Array1<double> params(1, numPoints);
        for (int i = 0; i < numPoints; i++) {
            pts(i + 1) = gp_Pnt(pointsXYZ[i*3], pointsXYZ[i*3+1], pointsXYZ[i*3+2]);
            params(i + 1) = parameters[i];
        }
        GeomLib_Interpolate interp(degree, numPoints, pts, params);
        if (!interp.IsDone()) return nullptr;
        Handle(Geom_BSplineCurve) curve = interp.Curve();
        if (curve.IsNull()) return nullptr;
        return reinterpret_cast<OCCTCurve3DRef>(new OCCTCurve3D{curve});
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Approx_SameParameter (v0.77)
// MARK: - Approx_SameParameter

#include <Approx_SameParameter.hxx>

bool OCCTApproxSameParameter(OCCTCurve3DRef _Nonnull curve3dRef,
                              OCCTCurve2DRef _Nonnull curve2dRef,
                              OCCTSurfaceRef _Nonnull surfRef,
                              double tolerance,
                              bool* _Nonnull outIsSame,
                              double* _Nonnull outTolReached) {
    try {
        auto& c3d = reinterpret_cast<OCCTCurve3D*>(curve3dRef)->curve;
        auto& c2d = reinterpret_cast<OCCTCurve2D*>(curve2dRef)->curve;
        auto& surf = reinterpret_cast<OCCTSurface*>(surfRef)->surface;
        Approx_SameParameter checker(c3d, c2d, surf, tolerance);
        if (!checker.IsDone()) return false;
        *outIsSame = checker.IsSameParameter();
        *outTolReached = checker.TolReached();
        return true;
    } catch (...) {
        return false;
    }
}

// MARK: - ShapeUpgrade_SplitCurve3dContinuity (v0.77)
// MARK: - ShapeUpgrade_SplitCurve3dContinuity

#include <ShapeUpgrade_SplitCurve3dContinuity.hxx>
#include <ShapeUpgrade_SplitCurve2dContinuity.hxx>
#include <ShapeUpgrade_ConvertCurve2dToBezier.hxx>

static GeomAbs_Shape continuityFromInt(int val) {
    switch (val) {
        case 0: return GeomAbs_C0;
        case 1: return GeomAbs_C1;
        case 2: return GeomAbs_C2;
        case 3: return GeomAbs_C3;
        default: return GeomAbs_CN;
    }
}

int OCCTSplitCurve3dContinuity(OCCTCurve3DRef _Nonnull curveRef, int criterion, double tolerance,
                                 OCCTCurve3DRef _Nullable* _Nullable outCurves, int maxCurves) {
    try {
        auto& curve = reinterpret_cast<OCCTCurve3D*>(curveRef)->curve;
        Handle(ShapeUpgrade_SplitCurve3dContinuity) splitter = new ShapeUpgrade_SplitCurve3dContinuity();
        splitter->Init(curve);
        splitter->SetCriterion(continuityFromInt(criterion));
        splitter->SetTolerance(tolerance);
        splitter->Perform(true);
        auto curves = splitter->GetCurves();
        if (curves.IsNull()) return 0;
        int n = curves->Length();
        int written = 0;
        for (int i = curves->Lower(); i <= curves->Upper() && written < maxCurves; i++) {
            Handle(Geom_Curve) c = curves->Value(i);
            if (!c.IsNull() && outCurves) {
                outCurves[written] = reinterpret_cast<OCCTCurve3DRef>(new OCCTCurve3D{c});
            }
            written++;
        }
        return written;
    } catch (...) {
        return 0;
    }
}

// MARK: - GeomConvert_CurveToAnaCurve (v0.78)
// MARK: - GeomConvert_CurveToAnaCurve

OCCTCurveToAnaCurveResult OCCTGeomConvertCurveToAnalytical(OCCTCurve3DRef _Nonnull curveRef,
                                                             double tolerance, double first, double last) {
    OCCTCurveToAnaCurveResult result = {nullptr, 0, 0, 0, false};
    try {
        auto& curve = reinterpret_cast<OCCTCurve3D*>(curveRef)->curve;
        GeomConvert_CurveToAnaCurve converter(curve);
        Handle(Geom_Curve) resCurve;
        double newF, newL;
        bool ok = converter.ConvertToAnalytical(tolerance, resCurve, first, last, newF, newL);
        if (ok && !resCurve.IsNull()) {
            result.curve = reinterpret_cast<OCCTCurve3DRef>(new OCCTCurve3D{resCurve});
            result.newFirst = newF;
            result.newLast = newL;
            result.gap = converter.Gap();
            result.success = true;
        }
    } catch (...) {}
    return result;
}

bool OCCTGeomConvertIsLinear(const double* _Nonnull points, int count, double tolerance,
                               double* _Nullable deviation) {
    try {
        NCollection_Array1<gp_Pnt> pts(1, count);
        for (int i = 0; i < count; i++) {
            pts(i + 1) = gp_Pnt(points[i * 3], points[i * 3 + 1], points[i * 3 + 2]);
        }
        double dev = 0;
        bool result = GeomConvert_CurveToAnaCurve::IsLinear(pts, tolerance, dev);
        if (deviation) *deviation = dev;
        return result;
    } catch (...) {
        return false;
    }
}

// MARK: - Extrema_ExtCC + ExtCS (v0.80)
// --- Extrema_ExtCC ---

OCCTExtremaExtCCResult OCCTExtremaExtCC(OCCTCurve3DRef curve1, double u1First, double u1Last,
                                         OCCTCurve3DRef curve2, double u2First, double u2Last) {
    OCCTExtremaExtCCResult result = {false, false, 0};
    try {
        auto* c1 = (OCCTCurve3D*)curve1;
        auto* c2 = (OCCTCurve3D*)curve2;
        Handle(GeomAdaptor_Curve) ac1 = new GeomAdaptor_Curve(c1->curve, u1First, u1Last);
        Handle(GeomAdaptor_Curve) ac2 = new GeomAdaptor_Curve(c2->curve, u2First, u2Last);
        Extrema_ExtCC ext(*ac1, *ac2);
        result.isDone = ext.IsDone();
        if (result.isDone) {
            result.isParallel = ext.IsParallel();
            if (!result.isParallel) result.nbExt = ext.NbExt();
        }
    } catch (...) {}
    return result;
}

OCCTExtremaPointPair OCCTExtremaExtCCPoint(OCCTCurve3DRef curve1, double u1First, double u1Last,
                                            OCCTCurve3DRef curve2, double u2First, double u2Last,
                                            int index) {
    OCCTExtremaPointPair result = {};
    try {
        auto* c1 = (OCCTCurve3D*)curve1;
        auto* c2 = (OCCTCurve3D*)curve2;
        Handle(GeomAdaptor_Curve) ac1 = new GeomAdaptor_Curve(c1->curve, u1First, u1Last);
        Handle(GeomAdaptor_Curve) ac2 = new GeomAdaptor_Curve(c2->curve, u2First, u2Last);
        Extrema_ExtCC ext(*ac1, *ac2);
        if (ext.IsDone() && !ext.IsParallel() && index >= 1 && index <= ext.NbExt()) {
            result.squareDistance = ext.SquareDistance(index);
            Extrema_POnCurv p1, p2;
            ext.Points(index, p1, p2);
            result.x1 = p1.Value().X(); result.y1 = p1.Value().Y(); result.z1 = p1.Value().Z();
            result.param1 = p1.Parameter();
            result.x2 = p2.Value().X(); result.y2 = p2.Value().Y(); result.z2 = p2.Value().Z();
            result.param2 = p2.Parameter();
        }
    } catch (...) {}
    return result;
}

// --- Extrema_ExtCS ---

OCCTExtremaExtCSResult OCCTExtremaExtCS(OCCTCurve3DRef curve, double uFirst, double uLast,
                                         OCCTSurfaceRef surface) {
    OCCTExtremaExtCSResult result = {false, false, 0};
    try {
        auto* c = (OCCTCurve3D*)curve;
        auto* s = (OCCTSurface*)surface;
        Handle(GeomAdaptor_Curve) ac = new GeomAdaptor_Curve(c->curve, uFirst, uLast);
        Handle(GeomAdaptor_Surface) as = new GeomAdaptor_Surface(s->surface);
        Extrema_ExtCS ext(*ac, *as, 1e-6, 1e-6);
        result.isDone = ext.IsDone();
        if (result.isDone) {
            result.isParallel = ext.IsParallel();
            if (!result.isParallel) result.nbExt = ext.NbExt();
        }
    } catch (...) {}
    return result;
}

OCCTExtremaPointPair OCCTExtremaExtCSPoint(OCCTCurve3DRef curve, double uFirst, double uLast,
                                            OCCTSurfaceRef surface, int index) {
    OCCTExtremaPointPair result = {};
    try {
        auto* c = (OCCTCurve3D*)curve;
        auto* s = (OCCTSurface*)surface;
        Handle(GeomAdaptor_Curve) ac = new GeomAdaptor_Curve(c->curve, uFirst, uLast);
        Handle(GeomAdaptor_Surface) as = new GeomAdaptor_Surface(s->surface);
        Extrema_ExtCS ext(*ac, *as, 1e-6, 1e-6);
        if (ext.IsDone() && !ext.IsParallel() && index >= 1 && index <= ext.NbExt()) {
            result.squareDistance = ext.SquareDistance(index);
            Extrema_POnCurv pc;
            Extrema_POnSurf ps;
            ext.Points(index, pc, ps);
            result.x1 = pc.Value().X(); result.y1 = pc.Value().Y(); result.z1 = pc.Value().Z();
            result.param1 = pc.Parameter();
            result.x2 = ps.Value().X(); result.y2 = ps.Value().Y(); result.z2 = ps.Value().Z();
            double u, v;
            ps.Parameter(u, v);
            result.param2 = u; // Store U in param2; V not directly available in this struct
        }
    } catch (...) {}
    return result;
}

// MARK: - Extrema_LocateExtCC (v0.80)
// --- Extrema_LocateExtCC ---

OCCTExtremaLocateExtCCResult OCCTExtremaLocateExtCC(OCCTCurve3DRef curve1, double u1First, double u1Last,
                                                     OCCTCurve3DRef curve2, double u2First, double u2Last,
                                                     double seedU, double seedV) {
    OCCTExtremaLocateExtCCResult result = {};
    try {
        auto* c1 = (OCCTCurve3D*)curve1;
        auto* c2 = (OCCTCurve3D*)curve2;
        Handle(GeomAdaptor_Curve) ac1 = new GeomAdaptor_Curve(c1->curve, u1First, u1Last);
        Handle(GeomAdaptor_Curve) ac2 = new GeomAdaptor_Curve(c2->curve, u2First, u2Last);
        Extrema_LocateExtCC ext(*ac1, *ac2, seedU, seedV);
        result.isDone = ext.IsDone();
        if (result.isDone) {
            result.squareDistance = ext.SquareDistance();
            Extrema_POnCurv p1, p2;
            ext.Point(p1, p2);
            result.x1 = p1.Value().X(); result.y1 = p1.Value().Y(); result.z1 = p1.Value().Z();
            result.param1 = p1.Parameter();
            result.x2 = p2.Value().X(); result.y2 = p2.Value().Y(); result.z2 = p2.Value().Z();
            result.param2 = p2.Parameter();
        }
    } catch (...) {}
    return result;
}

// MARK: - gce_Make Circ / Lin / Dir / Elips / Hypr / Parab (v0.80)
// --- gce factories ---

OCCTCurve3DRef _Nullable OCCTGceMakeCircFrom3Points(double p1x, double p1y, double p1z,
                                                     double p2x, double p2y, double p2z,
                                                     double p3x, double p3y, double p3z) {
    try {
        gce_MakeCirc mc(gp_Pnt(p1x, p1y, p1z), gp_Pnt(p2x, p2y, p2z), gp_Pnt(p3x, p3y, p3z));
        if (!mc.IsDone()) return nullptr;
        Handle(Geom_Circle) circ = new Geom_Circle(mc.Value());
        return (OCCTCurve3DRef)new OCCTCurve3D{circ};
    } catch (...) { return nullptr; }
}

OCCTCurve3DRef _Nullable OCCTGceMakeCircFromCenterNormal(double cx, double cy, double cz,
                                                          double nx, double ny, double nz,
                                                          double radius) {
    try {
        gce_MakeCirc mc(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz), radius);
        if (!mc.IsDone()) return nullptr;
        Handle(Geom_Circle) circ = new Geom_Circle(mc.Value());
        return (OCCTCurve3DRef)new OCCTCurve3D{circ};
    } catch (...) { return nullptr; }
}
OCCTCurve3DRef _Nullable OCCTGceMakeLinFrom2Points(double p1x, double p1y, double p1z,
                                                    double p2x, double p2y, double p2z) {
    try {
        gce_MakeLin ml(gp_Pnt(p1x, p1y, p1z), gp_Pnt(p2x, p2y, p2z));
        if (!ml.IsDone()) return nullptr;
        Handle(Geom_Line) line = new Geom_Line(ml.Value());
        return (OCCTCurve3DRef)new OCCTCurve3D{line};
    } catch (...) { return nullptr; }
}
bool OCCTGceMakeDir(double p1x, double p1y, double p1z,
                     double p2x, double p2y, double p2z,
                     double * outX, double * outY, double * outZ) {
    try {
        gce_MakeDir md(gp_Pnt(p1x, p1y, p1z), gp_Pnt(p2x, p2y, p2z));
        if (!md.IsDone()) return false;
        *outX = md.Value().X();
        *outY = md.Value().Y();
        *outZ = md.Value().Z();
        return true;
    } catch (...) { return false; }
}
OCCTCurve3DRef _Nullable OCCTGceMakeElips(double cx, double cy, double cz,
                                           double nx, double ny, double nz,
                                           double majorRadius, double minorRadius) {
    try {
        gce_MakeElips me(gp_Ax2(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz)), majorRadius, minorRadius);
        if (!me.IsDone()) return nullptr;
        Handle(Geom_Ellipse) elips = new Geom_Ellipse(me.Value());
        return (OCCTCurve3DRef)new OCCTCurve3D{elips};
    } catch (...) { return nullptr; }
}

OCCTCurve3DRef _Nullable OCCTGceMakeHypr(double cx, double cy, double cz,
                                          double nx, double ny, double nz,
                                          double majorRadius, double minorRadius) {
    try {
        gce_MakeHypr mh(gp_Ax2(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz)), majorRadius, minorRadius);
        if (!mh.IsDone()) return nullptr;
        Handle(Geom_Hyperbola) hypr = new Geom_Hyperbola(mh.Value());
        return (OCCTCurve3DRef)new OCCTCurve3D{hypr};
    } catch (...) { return nullptr; }
}

OCCTCurve3DRef _Nullable OCCTGceMakeParab(double cx, double cy, double cz,
                                           double nx, double ny, double nz,
                                           double focal) {
    try {
        gce_MakeParab mp(gp_Ax2(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz)), focal);
        if (!mp.IsDone()) return nullptr;
        Handle(Geom_Parabola) parab = new Geom_Parabola(mp.Value());
        return (OCCTCurve3DRef)new OCCTCurve3D{parab};
    } catch (...) { return nullptr; }
}

// MARK: - Geom_Transformation handle (v0.86)
// MARK: - Geom_Transformation

#include <Geom_Transformation.hxx>

OCCTGeomTransformRef OCCTGeomTransformCreate(void) {
    try {
        Handle(Geom_Transformation)* h = new Handle(Geom_Transformation)(new Geom_Transformation());
        return h;
    } catch (...) { return nullptr; }
}

void OCCTGeomTransformRelease(OCCTGeomTransformRef transform) {
    auto* h = static_cast<Handle(Geom_Transformation)*>(transform);
    delete h;
}

void OCCTGeomTransformSetTranslation(OCCTGeomTransformRef transform,
                                      double dx, double dy, double dz) {
    try {
        auto* h = static_cast<Handle(Geom_Transformation)*>(transform);
        (*h)->SetTranslation(gp_Vec(dx, dy, dz));
    } catch (...) {}
}

void OCCTGeomTransformSetRotation(OCCTGeomTransformRef transform,
                                   double originX, double originY, double originZ,
                                   double dirX, double dirY, double dirZ,
                                   double angleRadians) {
    try {
        auto* h = static_cast<Handle(Geom_Transformation)*>(transform);
        gp_Ax1 axis(gp_Pnt(originX, originY, originZ), gp_Dir(dirX, dirY, dirZ));
        (*h)->SetRotation(axis, angleRadians);
    } catch (...) {}
}

void OCCTGeomTransformSetScale(OCCTGeomTransformRef transform,
                                double centerX, double centerY, double centerZ,
                                double scaleFactor) {
    try {
        auto* h = static_cast<Handle(Geom_Transformation)*>(transform);
        (*h)->SetScale(gp_Pnt(centerX, centerY, centerZ), scaleFactor);
    } catch (...) {}
}

void OCCTGeomTransformSetMirrorPoint(OCCTGeomTransformRef transform,
                                      double x, double y, double z) {
    try {
        auto* h = static_cast<Handle(Geom_Transformation)*>(transform);
        (*h)->SetMirror(gp_Pnt(x, y, z));
    } catch (...) {}
}

void OCCTGeomTransformSetMirrorAxis(OCCTGeomTransformRef transform,
                                     double originX, double originY, double originZ,
                                     double dirX, double dirY, double dirZ) {
    try {
        auto* h = static_cast<Handle(Geom_Transformation)*>(transform);
        gp_Ax1 axis(gp_Pnt(originX, originY, originZ), gp_Dir(dirX, dirY, dirZ));
        (*h)->SetMirror(axis);
    } catch (...) {}
}

double OCCTGeomTransformScaleFactor(OCCTGeomTransformRef transform) {
    try {
        auto* h = static_cast<Handle(Geom_Transformation)*>(transform);
        return (*h)->ScaleFactor();
    } catch (...) { return 1.0; }
}

bool OCCTGeomTransformIsNegative(OCCTGeomTransformRef transform) {
    try {
        auto* h = static_cast<Handle(Geom_Transformation)*>(transform);
        return (*h)->IsNegative();
    } catch (...) { return false; }
}

void OCCTGeomTransformApply(OCCTGeomTransformRef transform,
                             double* x, double* y, double* z) {
    try {
        auto* h = static_cast<Handle(Geom_Transformation)*>(transform);
        (*h)->Transforms(*x, *y, *z);
    } catch (...) {}
}

double OCCTGeomTransformValue(OCCTGeomTransformRef transform, int row, int col) {
    try {
        auto* h = static_cast<Handle(Geom_Transformation)*>(transform);
        return (*h)->Value(row, col);
    } catch (...) { return 0.0; }
}

OCCTGeomTransformRef OCCTGeomTransformMultiplied(OCCTGeomTransformRef t1,
                                                  OCCTGeomTransformRef t2) {
    try {
        auto* h1 = static_cast<Handle(Geom_Transformation)*>(t1);
        auto* h2 = static_cast<Handle(Geom_Transformation)*>(t2);
        Handle(Geom_Transformation) result = (*h1)->Multiplied(*h2);
        return new Handle(Geom_Transformation)(result);
    } catch (...) { return nullptr; }
}

OCCTGeomTransformRef OCCTGeomTransformInverted(OCCTGeomTransformRef transform) {
    try {
        auto* h = static_cast<Handle(Geom_Transformation)*>(transform);
        Handle(Geom_Transformation) result = (*h)->Inverted();
        return new Handle(Geom_Transformation)(result);
    } catch (...) { return nullptr; }
}

// MARK: - Geom_OffsetCurve handle (v0.86)
// MARK: - Geom_OffsetCurve

#include <Geom_OffsetCurve.hxx>

OCCTCurve3DRef OCCTCurve3DCreateOffset(OCCTCurve3DRef basisCurve,
                                         double offset,
                                         double dirX, double dirY, double dirZ) {
    try {
        Handle(Geom_OffsetCurve) oc = new Geom_OffsetCurve(
            basisCurve->curve, offset, gp_Dir(dirX, dirY, dirZ));
        auto* ref = new OCCTCurve3D();
        ref->curve = oc;
        return ref;
    } catch (...) { return nullptr; }
}

double OCCTCurve3DOffsetValue(OCCTCurve3DRef curve) {
    try {
        Handle(Geom_OffsetCurve) oc = Handle(Geom_OffsetCurve)::DownCast(curve->curve);
        if (oc.IsNull()) return 0.0;
        return oc->Offset();
    } catch (...) { return 0.0; }
}

bool OCCTCurve3DOffsetDirection(OCCTCurve3DRef curve,
                                 double* dirX, double* dirY, double* dirZ) {
    try {
        Handle(Geom_OffsetCurve) oc = Handle(Geom_OffsetCurve)::DownCast(curve->curve);
        if (oc.IsNull()) return false;
        gp_Dir d = oc->Direction();
        *dirX = d.X(); *dirY = d.Y(); *dirZ = d.Z();
        return true;
    } catch (...) { return false; }
}

// MARK: - v0.91: ElCLib + gp_Quaternion
// MARK: - ElCLib (v0.91.0)

#include <ElCLib.hxx>

void OCCTElCLibValueOnLine(double u, double ox, double oy, double oz,
                            double dx, double dy, double dz,
                            double* outX, double* outY, double* outZ) {
    gp_Pnt p = ElCLib::Value(u, gp_Lin(gp_Pnt(ox,oy,oz), gp_Dir(dx,dy,dz)));
    *outX = p.X(); *outY = p.Y(); *outZ = p.Z();
}

void OCCTElCLibValueOnCircle(double u, double cx, double cy, double cz,
                              double nx, double ny, double nz, double radius,
                              double* outX, double* outY, double* outZ) {
    gp_Pnt p = ElCLib::Value(u, gp_Circ(gp_Ax2(gp_Pnt(cx,cy,cz), gp_Dir(nx,ny,nz)), radius));
    *outX = p.X(); *outY = p.Y(); *outZ = p.Z();
}

void OCCTElCLibValueOnEllipse(double u, double cx, double cy, double cz,
                               double nx, double ny, double nz,
                               double majorRadius, double minorRadius,
                               double* outX, double* outY, double* outZ) {
    gp_Pnt p = ElCLib::Value(u, gp_Elips(gp_Ax2(gp_Pnt(cx,cy,cz), gp_Dir(nx,ny,nz)), majorRadius, minorRadius));
    *outX = p.X(); *outY = p.Y(); *outZ = p.Z();
}

void OCCTElCLibD1OnLine(double u, double ox, double oy, double oz,
                         double dx, double dy, double dz,
                         double* outPX, double* outPY, double* outPZ,
                         double* outVX, double* outVY, double* outVZ) {
    gp_Pnt p; gp_Vec v;
    ElCLib::D1(u, gp_Lin(gp_Pnt(ox,oy,oz), gp_Dir(dx,dy,dz)), p, v);
    *outPX = p.X(); *outPY = p.Y(); *outPZ = p.Z();
    *outVX = v.X(); *outVY = v.Y(); *outVZ = v.Z();
}

void OCCTElCLibD1OnCircle(double u, double cx, double cy, double cz,
                           double nx, double ny, double nz, double radius,
                           double* outPX, double* outPY, double* outPZ,
                           double* outVX, double* outVY, double* outVZ) {
    gp_Pnt p; gp_Vec v;
    ElCLib::D1(u, gp_Circ(gp_Ax2(gp_Pnt(cx,cy,cz), gp_Dir(nx,ny,nz)), radius), p, v);
    *outPX = p.X(); *outPY = p.Y(); *outPZ = p.Z();
    *outVX = v.X(); *outVY = v.Y(); *outVZ = v.Z();
}

double OCCTElCLibParameterOnLine(double ox, double oy, double oz,
                                  double dx, double dy, double dz,
                                  double px, double py, double pz) {
    return ElCLib::Parameter(gp_Lin(gp_Pnt(ox,oy,oz), gp_Dir(dx,dy,dz)), gp_Pnt(px,py,pz));
}

double OCCTElCLibParameterOnCircle(double cx, double cy, double cz,
                                    double nx, double ny, double nz, double radius,
                                    double px, double py, double pz) {
    return ElCLib::Parameter(gp_Circ(gp_Ax2(gp_Pnt(cx,cy,cz), gp_Dir(nx,ny,nz)), radius), gp_Pnt(px,py,pz));
}

double OCCTElCLibInPeriod(double u, double uFirst, double uLast) {
    return ElCLib::InPeriod(u, uFirst, uLast);
}
// MARK: - gp_Quaternion (v0.91.0)

#include <gp_Quaternion.hxx>
#include <gp_EulerSequence.hxx>

struct OCCTQuaternion {
    gp_Quaternion q;
};

OCCTQuaternionRef OCCTQuaternionCreate(double x, double y, double z, double w) {
    auto* ref = new OCCTQuaternion();
    ref->q = gp_Quaternion(x, y, z, w);
    return ref;
}

OCCTQuaternionRef OCCTQuaternionCreateFromAxisAngle(double ax, double ay, double az, double angle) {
    auto* ref = new OCCTQuaternion();
    ref->q = gp_Quaternion(gp_Vec(ax, ay, az), angle);
    return ref;
}

OCCTQuaternionRef OCCTQuaternionCreateFromVectors(double fromX, double fromY, double fromZ,
                                                    double toX, double toY, double toZ) {
    auto* ref = new OCCTQuaternion();
    ref->q = gp_Quaternion(gp_Vec(fromX, fromY, fromZ), gp_Vec(toX, toY, toZ));
    return ref;
}

void OCCTQuaternionRelease(OCCTQuaternionRef q) {
    delete q;
}

void OCCTQuaternionGetComponents(OCCTQuaternionRef q, double* x, double* y, double* z, double* w) {
    *x = q->q.X(); *y = q->q.Y(); *z = q->q.Z(); *w = q->q.W();
}

void OCCTQuaternionSetEulerAngles(OCCTQuaternionRef q, int32_t order,
                                   double alpha, double beta, double gamma) {
    q->q.SetEulerAngles((gp_EulerSequence)order, alpha, beta, gamma);
}

void OCCTQuaternionGetEulerAngles(OCCTQuaternionRef q, int32_t order,
                                   double* alpha, double* beta, double* gamma) {
    q->q.GetEulerAngles((gp_EulerSequence)order, *alpha, *beta, *gamma);
}

void OCCTQuaternionGetMatrix(OCCTQuaternionRef q, double* matrix9) {
    gp_Mat m = q->q.GetMatrix();
    matrix9[0] = m.Value(1,1); matrix9[1] = m.Value(1,2); matrix9[2] = m.Value(1,3);
    matrix9[3] = m.Value(2,1); matrix9[4] = m.Value(2,2); matrix9[5] = m.Value(2,3);
    matrix9[6] = m.Value(3,1); matrix9[7] = m.Value(3,2); matrix9[8] = m.Value(3,3);
}

void OCCTQuaternionMultiplyVec(OCCTQuaternionRef q, double vx, double vy, double vz,
                                double* outX, double* outY, double* outZ) {
    gp_Vec result = q->q.Multiply(gp_Vec(vx, vy, vz));
    *outX = result.X(); *outY = result.Y(); *outZ = result.Z();
}

OCCTQuaternionRef OCCTQuaternionMultiply(OCCTQuaternionRef q1, OCCTQuaternionRef q2) {
    auto* ref = new OCCTQuaternion();
    ref->q = q1->q.Multiplied(q2->q);
    return ref;
}

void OCCTQuaternionGetVectorAndAngle(OCCTQuaternionRef q, double* ax, double* ay, double* az, double* angle) {
    gp_Vec axis; double a;
    q->q.GetVectorAndAngle(axis, a);
    *ax = axis.X(); *ay = axis.Y(); *az = axis.Z(); *angle = a;
}

double OCCTQuaternionGetRotationAngle(OCCTQuaternionRef q) {
    return q->q.GetRotationAngle();
}

void OCCTQuaternionNormalize(OCCTQuaternionRef q) {
    q->q.Normalize();
}

// MARK: - v0.94: Convert_CircleToBSplineCurve

// MARK: - v0.99: Convert_CompBezierCurvesToBSplineCurve
// MARK: - Convert_CompBezierCurvesToBSplineCurve (v0.99.0)

#include <Convert_CompBezierCurvesToBSplineCurve.hxx>
#include <Convert_CompBezierCurves2dToBSplineCurve2d.hxx>
#include <gp_Pnt2d.hxx>
#include <NCollection_Array1.hxx>

bool OCCTConvertCompBezierToBSpline(const double* poles, int32_t segCount, int32_t ptsPerSeg,
                                    OCCTBezierBSplineResult* out) {
    if (!poles || segCount <= 0 || ptsPerSeg <= 0 || !out) return false;
    try {
        Convert_CompBezierCurvesToBSplineCurve conv;
        const double* p = poles;
        for (int s = 0; s < segCount; s++) {
            NCollection_Array1<gp_Pnt> seg(1, ptsPerSeg);
            for (int i = 1; i <= ptsPerSeg; i++) {
                seg(i) = gp_Pnt(p[0], p[1], p[2]);
                p += 3;
            }
            conv.AddCurve(seg);
        }
        conv.Perform();
        int nb = conv.NbPoles();
        int nk = conv.NbKnots();
        out->degree  = conv.Degree();
        out->nbPoles = nb;
        out->nbKnots = nk;

        NCollection_Array1<gp_Pnt> resultPoles(1, nb);
        conv.Poles(resultPoles);
        for (int i = 1; i <= nb && (i - 1) * 3 + 2 < 300; i++) {
            out->poles[(i - 1) * 3]     = resultPoles(i).X();
            out->poles[(i - 1) * 3 + 1] = resultPoles(i).Y();
            out->poles[(i - 1) * 3 + 2] = resultPoles(i).Z();
        }

        NCollection_Array1<double> knots(1, nk);
        NCollection_Array1<int>    mults(1, nk);
        conv.KnotsAndMults(knots, mults);
        for (int i = 1; i <= nk && i - 1 < 50; i++) {
            out->knots[i - 1] = knots(i);
            out->mults[i - 1] = mults(i);
        }
        return true;
    } catch (...) { return false; }
}

bool OCCTConvertCompBezier2dToBSpline2d(const double* poles, int32_t segCount, int32_t ptsPerSeg,
                                        OCCTBezierBSpline2dResult* out) {
    if (!poles || segCount <= 0 || ptsPerSeg <= 0 || !out) return false;
    try {
        Convert_CompBezierCurves2dToBSplineCurve2d conv;
        const double* p = poles;
        for (int s = 0; s < segCount; s++) {
            NCollection_Array1<gp_Pnt2d> seg(1, ptsPerSeg);
            for (int i = 1; i <= ptsPerSeg; i++) {
                seg(i) = gp_Pnt2d(p[0], p[1]);
                p += 2;
            }
            conv.AddCurve(seg);
        }
        conv.Perform();
        int nb = conv.NbPoles();
        int nk = conv.NbKnots();
        out->degree  = conv.Degree();
        out->nbPoles = nb;
        out->nbKnots = nk;

        NCollection_Array1<gp_Pnt2d> resultPoles(1, nb);
        conv.Poles(resultPoles);
        for (int i = 1; i <= nb && (i - 1) * 2 + 1 < 200; i++) {
            out->poles[(i - 1) * 2]     = resultPoles(i).X();
            out->poles[(i - 1) * 2 + 1] = resultPoles(i).Y();
        }

        NCollection_Array1<double> knots(1, nk);
        NCollection_Array1<int>    mults(1, nk);
        conv.KnotsAndMults(knots, mults);
        for (int i = 1; i <= nk && i - 1 < 50; i++) {
            out->knots[i - 1] = knots(i);
            out->mults[i - 1] = mults(i);
        }
        return true;
    } catch (...) { return false; }
}

// MARK: - v0.100: ShapeAnalysis_Curve statics + Geom_OffsetCurve basis
// --- ShapeAnalysis_Curve static methods ---

bool OCCTCurve3DIsClosedWithPreci(OCCTCurve3DRef curve, double preci) {
    if (!curve) return false;
    try {
        return ShapeAnalysis_Curve::IsClosed(curve->curve, preci);
    } catch (...) { return false; }
}

bool OCCTCurve3DIsPeriodicSA(OCCTCurve3DRef curve) {
    if (!curve) return false;
    try {
        return ShapeAnalysis_Curve::IsPeriodic(curve->curve);
    } catch (...) { return false; }
}
// --- Geom_OffsetCurve basis curve ---

OCCTCurve3DRef OCCTCurve3DOffsetBasis(OCCTCurve3DRef curve) {
    if (!curve) return nullptr;
    try {
        Handle(Geom_OffsetCurve) oc = Handle(Geom_OffsetCurve)::DownCast(curve->curve);
        if (oc.IsNull()) return nullptr;
        Handle(Geom_Curve) basis = oc->BasisCurve();
        if (basis.IsNull()) return nullptr;
        return new OCCTCurve3D(basis);
    } catch (...) { return nullptr; }
}

// MARK: - v0.101: Geom_TrimmedCurve operations
// --- Geom_TrimmedCurve ---

OCCTCurve3DRef OCCTCurve3DTrimmed(OCCTCurve3DRef basisCurve, double u1, double u2) {
    try {
        Handle(Geom_TrimmedCurve) tc = new Geom_TrimmedCurve(basisCurve->curve, u1, u2);
        OCCTCurve3D* c = new OCCTCurve3D();
        c->curve = tc;
        return c;
    } catch (...) { return nullptr; }
}

void OCCTCurve3DStartPoint(OCCTCurve3DRef curve, double* x, double* y, double* z) {
    try {
        gp_Pnt p = curve->curve->Value(curve->curve->FirstParameter());
        *x = p.X(); *y = p.Y(); *z = p.Z();
    } catch (...) { *x = 0; *y = 0; *z = 0; }
}

void OCCTCurve3DEndPoint(OCCTCurve3DRef curve, double* x, double* y, double* z) {
    try {
        gp_Pnt p = curve->curve->Value(curve->curve->LastParameter());
        *x = p.X(); *y = p.Y(); *z = p.Z();
    } catch (...) { *x = 0; *y = 0; *z = 0; }
}

OCCTCurve3DRef OCCTCurve3DTrimmedBasis(OCCTCurve3DRef curve) {
    try {
        Handle(Geom_TrimmedCurve) tc = Handle(Geom_TrimmedCurve)::DownCast(curve->curve);
        if (tc.IsNull()) return nullptr;
        OCCTCurve3D* c = new OCCTCurve3D();
        c->curve = tc->BasisCurve();
        return c;
    } catch (...) { return nullptr; }
}

bool OCCTCurve3DSetTrim(OCCTCurve3DRef curve, double u1, double u2) {
    try {
        Handle(Geom_TrimmedCurve) tc = Handle(Geom_TrimmedCurve)::DownCast(curve->curve);
        if (tc.IsNull()) return false;
        tc->SetTrim(u1, u2);
        return true;
    } catch (...) { return false; }
}

// MARK: - v0.105: GC_MakeCircle/Ellipse/Hyperbola, GCPnts_UniformAbscissa, GeomConvert_CompCurveToBSplineCurve, GeomLib_LogSample
// MARK: - GC_MakeCircle (v0.105.0)

#include <GC_MakeCircle.hxx>
#include <GC_MakeEllipse.hxx>
#include <GC_MakeHyperbola.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Ellipse.hxx>
#include <Geom_Hyperbola.hxx>

OCCTCurve3DRef OCCTGCMakeCircle(double cx, double cy, double cz,
                                  double nx, double ny, double nz,
                                  double radius) {
    try {
        gp_Ax2 ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
        GC_MakeCircle mc(ax, radius);
        if (!mc.IsDone()) return nullptr;
        auto result = new OCCTCurve3D();
        result->curve = mc.Value();
        return result;
    } catch (...) { return nullptr; }
}

OCCTCurve3DRef OCCTGCMakeCircle3Points(double x1, double y1, double z1,
                                         double x2, double y2, double z2,
                                         double x3, double y3, double z3) {
    try {
        GC_MakeCircle mc(gp_Pnt(x1, y1, z1), gp_Pnt(x2, y2, z2), gp_Pnt(x3, y3, z3));
        if (!mc.IsDone()) return nullptr;
        auto result = new OCCTCurve3D();
        result->curve = mc.Value();
        return result;
    } catch (...) { return nullptr; }
}

OCCTCurve3DRef OCCTGCMakeCircleCenterNormal(double cx, double cy, double cz,
                                               double nx, double ny, double nz,
                                               double radius) {
    try {
        GC_MakeCircle mc(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz), radius);
        if (!mc.IsDone()) return nullptr;
        auto result = new OCCTCurve3D();
        result->curve = mc.Value();
        return result;
    } catch (...) { return nullptr; }
}

OCCTCurve3DRef OCCTGCMakeCircleParallel(double cx, double cy, double cz,
                                          double nx, double ny, double nz,
                                          double radius, double dist) {
    try {
        gp_Circ circ(gp_Ax2(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz)), radius);
        GC_MakeCircle mc(circ, dist);
        if (!mc.IsDone()) return nullptr;
        auto result = new OCCTCurve3D();
        result->curve = mc.Value();
        return result;
    } catch (...) { return nullptr; }
}

// MARK: - GC_MakeEllipse (v0.105.0)

OCCTCurve3DRef OCCTGCMakeEllipse(double cx, double cy, double cz,
                                   double nx, double ny, double nz,
                                   double major, double minor) {
    try {
        gp_Ax2 ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
        GC_MakeEllipse me(ax, major, minor);
        if (!me.IsDone()) return nullptr;
        auto result = new OCCTCurve3D();
        result->curve = me.Value();
        return result;
    } catch (...) { return nullptr; }
}

OCCTCurve3DRef OCCTGCMakeEllipse3Points(double x1, double y1, double z1,
                                          double x2, double y2, double z2,
                                          double x3, double y3, double z3) {
    try {
        GC_MakeEllipse me(gp_Pnt(x1, y1, z1), gp_Pnt(x2, y2, z2), gp_Pnt(x3, y3, z3));
        if (!me.IsDone()) return nullptr;
        auto result = new OCCTCurve3D();
        result->curve = me.Value();
        return result;
    } catch (...) { return nullptr; }
}

OCCTCurve3DRef OCCTGCMakeEllipseFromElips(double cx, double cy, double cz,
                                            double nx, double ny, double nz,
                                            double xdx, double xdy, double xdz,
                                            double major, double minor) {
    try {
        gp_Ax2 ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz), gp_Dir(xdx, xdy, xdz));
        GC_MakeEllipse me(ax, major, minor);
        if (!me.IsDone()) return nullptr;
        auto result = new OCCTCurve3D();
        result->curve = me.Value();
        return result;
    } catch (...) { return nullptr; }
}

// MARK: - GC_MakeHyperbola (v0.105.0)

OCCTCurve3DRef OCCTGCMakeHyperbola(double cx, double cy, double cz,
                                     double nx, double ny, double nz,
                                     double major, double minor) {
    try {
        gp_Ax2 ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
        GC_MakeHyperbola mh(ax, major, minor);
        if (!mh.IsDone()) return nullptr;
        auto result = new OCCTCurve3D();
        result->curve = mh.Value();
        return result;
    } catch (...) { return nullptr; }
}

OCCTCurve3DRef OCCTGCMakeHyperbola3Points(double x1, double y1, double z1,
                                            double x2, double y2, double z2,
                                            double x3, double y3, double z3) {
    try {
        // GC_MakeHyperbola from 3 points: S1, S2, Center
        gp_Hypr hypr;
        // There's no 3-point constructor for GC_MakeHyperbola, use gp_Hypr approach
        // S1 and S2 are on the hyperbola, center is the center
        // We'll construct from the geometry directly
        gp_Pnt s1(x1, y1, z1), s2(x2, y2, z2), center(x3, y3, z3);
        // Compute major axis direction
        gp_Dir xDir(s1.XYZ() - center.XYZ());
        double majorR = center.Distance(s1);
        // Minor axis from S2
        gp_Vec toS2(center, s2);
        gp_Vec majorVec(center, s1);
        double proj = toS2.Dot(gp_Vec(xDir));
        gp_Vec perp = toS2 - proj * gp_Vec(xDir);
        double minorR = perp.Magnitude();
        if (minorR < 1e-10) return nullptr;
        gp_Dir normal = gp_Dir(majorVec.Crossed(perp));
        gp_Ax2 ax(center, normal, xDir);
        GC_MakeHyperbola mh(ax, majorR, minorR);
        if (!mh.IsDone()) return nullptr;
        auto result = new OCCTCurve3D();
        result->curve = mh.Value();
        return result;
    } catch (...) { return nullptr; }
}
// MARK: - GCPnts_UniformAbscissa (v0.105.0)

#include <GCPnts_UniformAbscissa.hxx>
#include <BRepAdaptor_Curve.hxx>

int32_t OCCTUniformAbscissaByCount(OCCTShapeRef edge, int32_t nbPoints, double* params) {
    if (!edge) return 0;
    try {
        BRepAdaptor_Curve ac(TopoDS::Edge(edge->shape));
        GCPnts_UniformAbscissa ua(ac, nbPoints);
        if (!ua.IsDone()) return 0;
        int32_t n = (int32_t)ua.NbPoints();
        if (params) {
            for (int32_t i = 0; i < n; i++) {
                params[i] = ua.Parameter(i + 1);
            }
        }
        return n;
    } catch (...) { return 0; }
}

int32_t OCCTUniformAbscissaByDistance(OCCTShapeRef edge, double abscissa, double* params) {
    if (!edge) return 0;
    try {
        BRepAdaptor_Curve ac(TopoDS::Edge(edge->shape));
        GCPnts_UniformAbscissa ua(ac, abscissa);
        if (!ua.IsDone()) return 0;
        int32_t n = (int32_t)ua.NbPoints();
        if (params) {
            for (int32_t i = 0; i < n; i++) {
                params[i] = ua.Parameter(i + 1);
            }
        }
        return n;
    } catch (...) { return 0; }
}

int32_t OCCTUniformAbscissaByCountRange(OCCTShapeRef edge, int32_t nbPoints,
                                         double u1, double u2, double* params) {
    if (!edge) return 0;
    try {
        BRepAdaptor_Curve ac(TopoDS::Edge(edge->shape));
        GCPnts_UniformAbscissa ua(ac, nbPoints, u1, u2);
        if (!ua.IsDone()) return 0;
        int32_t n = (int32_t)ua.NbPoints();
        if (params) {
            for (int32_t i = 0; i < n; i++) {
                params[i] = ua.Parameter(i + 1);
            }
        }
        return n;
    } catch (...) { return 0; }
}

int32_t OCCTUniformAbscissaByDistanceRange(OCCTShapeRef edge, double abscissa,
                                            double u1, double u2, double* params) {
    if (!edge) return 0;
    try {
        BRepAdaptor_Curve ac(TopoDS::Edge(edge->shape));
        GCPnts_UniformAbscissa ua(ac, abscissa, u1, u2);
        if (!ua.IsDone()) return 0;
        int32_t n = (int32_t)ua.NbPoints();
        if (params) {
            for (int32_t i = 0; i < n; i++) {
                params[i] = ua.Parameter(i + 1);
            }
        }
        return n;
    } catch (...) { return 0; }
}
// MARK: - GeomConvert_CompCurveToBSplineCurve (v0.105.0)

#include <GeomConvert_CompCurveToBSplineCurve.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <Geom_BSplineCurve.hxx>

OCCTCurve3DRef OCCTConcatenateCurves3D(OCCTCurve3DRef* curves, int32_t count, double tolerance) {
    if (!curves || count <= 0) return nullptr;
    try {
        // First curve must be bounded — try to cast
        Handle(Geom_BoundedCurve) first = Handle(Geom_BoundedCurve)::DownCast(curves[0]->curve);
        if (first.IsNull()) {
            // Try trimming the curve using its parameter range
            double f = curves[0]->curve->FirstParameter();
            double l = curves[0]->curve->LastParameter();
            first = new Geom_TrimmedCurve(curves[0]->curve, f, l);
        }
        GeomConvert_CompCurveToBSplineCurve comp(first);
        for (int32_t i = 1; i < count; i++) {
            Handle(Geom_BoundedCurve) bc = Handle(Geom_BoundedCurve)::DownCast(curves[i]->curve);
            if (bc.IsNull()) {
                double f = curves[i]->curve->FirstParameter();
                double l = curves[i]->curve->LastParameter();
                bc = new Geom_TrimmedCurve(curves[i]->curve, f, l);
            }
            if (!comp.Add(bc, tolerance)) return nullptr;
        }
        Handle(Geom_BSplineCurve) result = comp.BSplineCurve();
        if (result.IsNull()) return nullptr;
        auto r = new OCCTCurve3D();
        r->curve = result;
        return r;
    } catch (...) { return nullptr; }
}
// MARK: - GeomLib_LogSample (v0.105.0)

#include <GeomLib_LogSample.hxx>

void OCCTLogSample(double a, double b, int32_t n, double* params) {
    try {
        GeomLib_LogSample sampler(a, b, n);
        for (int32_t i = 1; i <= n; i++) {
            params[i - 1] = sampler.GetParameter(i);
        }
    } catch (...) {
        for (int32_t i = 0; i < n; i++) params[i] = 0;
    }
}

// MARK: - v0.106: Curve3D continuity
// MARK: - Curve3D continuity (v0.106.0)

int32_t OCCTCurve3DGetContinuity(OCCTCurve3DRef curve) {
    if (!curve || curve->curve.IsNull()) return 0;
    try {
        return static_cast<int32_t>(curve->curve->Continuity());
    } catch (...) { return 0; }
}

// MARK: - v0.107: Geom_BSplineCurve Methods
// MARK: - Geom_BSplineCurve Methods (v0.107.0)

#include <Geom_BSplineCurve.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Hatch_Hatcher.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRep_Tool.hxx>
#include <BRepTools.hxx>
#include <BRepLib.hxx>
#include <TopoDS.hxx>
#include <TopExp_Explorer.hxx>
#include <gp_Sphere.hxx>
#include <gp_Torus.hxx>
#include <gp_Cone.hxx>

int32_t OCCTCurve3DBSplineKnotCount(OCCTCurve3DRef curve) {
    if (!curve || curve->curve.IsNull()) return 0;
    Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
    if (bs.IsNull()) return 0;
    return bs->NbKnots();
}

int32_t OCCTCurve3DBSplinePoleCount(OCCTCurve3DRef curve) {
    if (!curve || curve->curve.IsNull()) return 0;
    Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
    if (bs.IsNull()) return 0;
    return bs->NbPoles();
}

int32_t OCCTCurve3DBSplineDegree(OCCTCurve3DRef curve) {
    if (!curve || curve->curve.IsNull()) return 0;
    Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
    if (bs.IsNull()) return 0;
    return bs->Degree();
}

bool OCCTCurve3DBSplineIsRational(OCCTCurve3DRef curve) {
    if (!curve || curve->curve.IsNull()) return false;
    Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
    if (bs.IsNull()) return false;
    return bs->IsRational();
}

void OCCTCurve3DBSplineGetKnots(OCCTCurve3DRef curve, double* knots) {
    if (!curve || curve->curve.IsNull() || !knots) return;
    Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
    if (bs.IsNull()) return;
    TColStd_Array1OfReal kArr(1, bs->NbKnots());
    bs->Knots(kArr);
    for (int i = 1; i <= bs->NbKnots(); i++) knots[i-1] = kArr(i);
}

void OCCTCurve3DBSplineGetMults(OCCTCurve3DRef curve, int32_t* mults) {
    if (!curve || curve->curve.IsNull() || !mults) return;
    Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
    if (bs.IsNull()) return;
    TColStd_Array1OfInteger mArr(1, bs->NbKnots());
    bs->Multiplicities(mArr);
    for (int i = 1; i <= bs->NbKnots(); i++) mults[i-1] = mArr(i);
}

void OCCTCurve3DBSplineGetPole(OCCTCurve3DRef curve, int32_t index, double* x, double* y, double* z) {
    *x = 0; *y = 0; *z = 0;
    if (!curve || curve->curve.IsNull()) return;
    Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
    if (bs.IsNull() || index < 1 || index > bs->NbPoles()) return;
    gp_Pnt p = bs->Pole(index);
    *x = p.X(); *y = p.Y(); *z = p.Z();
}

bool OCCTCurve3DBSplineSetPole(OCCTCurve3DRef curve, int32_t index, double x, double y, double z) {
    if (!curve || curve->curve.IsNull()) return false;
    Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
    if (bs.IsNull() || index < 1 || index > bs->NbPoles()) return false;
    try { bs->SetPole(index, gp_Pnt(x, y, z)); return true; } catch (...) { return false; }
}

bool OCCTCurve3DBSplineSetWeight(OCCTCurve3DRef curve, int32_t index, double weight) {
    if (!curve || curve->curve.IsNull()) return false;
    Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
    if (bs.IsNull() || index < 1 || index > bs->NbPoles()) return false;
    try { bs->SetWeight(index, weight); return true; } catch (...) { return false; }
}

double OCCTCurve3DBSplineGetWeight(OCCTCurve3DRef curve, int32_t index) {
    if (!curve || curve->curve.IsNull()) return 1.0;
    Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
    if (bs.IsNull() || index < 1 || index > bs->NbPoles()) return 1.0;
    return bs->Weight(index);
}

bool OCCTCurve3DBSplineInsertKnot(OCCTCurve3DRef curve, double u, int32_t mult, double tol) {
    if (!curve || curve->curve.IsNull()) return false;
    Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
    if (bs.IsNull()) return false;
    try { bs->InsertKnot(u, mult, tol); return true; } catch (...) { return false; }
}

bool OCCTCurve3DBSplineRemoveKnot(OCCTCurve3DRef curve, int32_t index, int32_t mult, double tol) {
    if (!curve || curve->curve.IsNull()) return false;
    Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
    if (bs.IsNull() || index < 1 || index > bs->NbKnots()) return false;
    try { return bs->RemoveKnot(index, mult, tol); } catch (...) { return false; }
}

bool OCCTCurve3DBSplineSegment(OCCTCurve3DRef curve, double u1, double u2) {
    if (!curve || curve->curve.IsNull()) return false;
    Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
    if (bs.IsNull()) return false;
    try { bs->Segment(u1, u2); return true; } catch (...) { return false; }
}

bool OCCTCurve3DBSplineIncreaseDegree(OCCTCurve3DRef curve, int32_t degree) {
    if (!curve || curve->curve.IsNull()) return false;
    Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
    if (bs.IsNull()) return false;
    try { bs->IncreaseDegree(degree); return true; } catch (...) { return false; }
}

double OCCTCurve3DBSplineResolution(OCCTCurve3DRef curve, double tolerance3d) {
    if (!curve || curve->curve.IsNull()) return 0.0;
    Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
    if (bs.IsNull()) return 0.0;
    double uTol = 0;
    bs->Resolution(tolerance3d, uTol);
    return uTol;
}

bool OCCTCurve3DBSplineSetPeriodic(OCCTCurve3DRef curve, bool periodic) {
    if (!curve || curve->curve.IsNull()) return false;
    Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
    if (bs.IsNull()) return false;
    try {
        if (periodic) bs->SetPeriodic(); else bs->SetNotPeriodic();
        return true;
    } catch (...) { return false; }
}


// MARK: - v0.107: Bezier Curve Methods
// MARK: - Bezier Curve Methods (v0.107.0)

void OCCTCurve3DBezierGetPole(OCCTCurve3DRef curve, int32_t index, double* x, double* y, double* z) {
    *x = 0; *y = 0; *z = 0;
    if (!curve || curve->curve.IsNull()) return;
    Handle(Geom_BezierCurve) bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
    if (bz.IsNull() || index < 1 || index > bz->NbPoles()) return;
    gp_Pnt p = bz->Pole(index);
    *x = p.X(); *y = p.Y(); *z = p.Z();
}

bool OCCTCurve3DBezierSetPole(OCCTCurve3DRef curve, int32_t index, double x, double y, double z) {
    if (!curve || curve->curve.IsNull()) return false;
    Handle(Geom_BezierCurve) bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
    if (bz.IsNull()) return false;
    try { bz->SetPole(index, gp_Pnt(x, y, z)); return true; } catch (...) { return false; }
}

bool OCCTCurve3DBezierSetWeight(OCCTCurve3DRef curve, int32_t index, double weight) {
    if (!curve || curve->curve.IsNull()) return false;
    Handle(Geom_BezierCurve) bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
    if (bz.IsNull()) return false;
    try { bz->SetWeight(index, weight); return true; } catch (...) { return false; }
}

bool OCCTCurve3DBezierInsertPoleAfter(OCCTCurve3DRef curve, int32_t index, double x, double y, double z) {
    if (!curve || curve->curve.IsNull()) return false;
    Handle(Geom_BezierCurve) bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
    if (bz.IsNull()) return false;
    try { bz->InsertPoleAfter(index, gp_Pnt(x, y, z)); return true; } catch (...) { return false; }
}

bool OCCTCurve3DBezierRemovePole(OCCTCurve3DRef curve, int32_t index) {
    if (!curve || curve->curve.IsNull()) return false;
    Handle(Geom_BezierCurve) bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
    if (bz.IsNull()) return false;
    try { bz->RemovePole(index); return true; } catch (...) { return false; }
}

bool OCCTCurve3DBezierSegment(OCCTCurve3DRef curve, double u1, double u2) {
    if (!curve || curve->curve.IsNull()) return false;
    Handle(Geom_BezierCurve) bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
    if (bz.IsNull()) return false;
    try { bz->Segment(u1, u2); return true; } catch (...) { return false; }
}

bool OCCTCurve3DBezierIncreaseDegree(OCCTCurve3DRef curve, int32_t degree) {
    if (!curve || curve->curve.IsNull()) return false;
    Handle(Geom_BezierCurve) bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
    if (bz.IsNull()) return false;
    try { bz->Increase(degree); return true; } catch (...) { return false; }
}

bool OCCTCurve3DBezierIsRational(OCCTCurve3DRef curve) {
    if (!curve || curve->curve.IsNull()) return false;
    Handle(Geom_BezierCurve) bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
    if (bz.IsNull()) return false;
    return bz->IsRational();
}

int32_t OCCTCurve3DBezierDegree(OCCTCurve3DRef curve) {
    if (!curve || curve->curve.IsNull()) return 0;
    Handle(Geom_BezierCurve) bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
    if (bz.IsNull()) return 0;
    return bz->Degree();
}

int32_t OCCTCurve3DBezierPoleCount(OCCTCurve3DRef curve) {
    if (!curve || curve->curve.IsNull()) return 0;
    Handle(Geom_BezierCurve) bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
    if (bz.IsNull()) return 0;
    return bz->NbPoles();
}

// MARK: - v0.108: Geom_Circle/Ellipse/Hyperbola/Parabola/Line Methods
// MARK: - Geom_Circle Methods (v0.108.0)

#include <Geom_Circle.hxx>
#include <Geom_Ellipse.hxx>
#include <Geom_Hyperbola.hxx>
#include <Geom_Parabola.hxx>
#include <Geom_Line.hxx>
#include <Geom_Plane.hxx>
#include <Geom_SphericalSurface.hxx>
#include <Geom_ToroidalSurface.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_ConicalSurface.hxx>
#include <Geom_SweptSurface.hxx>
#include <Geom_SurfaceOfLinearExtrusion.hxx>
#include <Geom_SurfaceOfRevolution.hxx>
#include <Geom2d_Circle.hxx>
#include <Geom2d_Ellipse.hxx>
#include <Geom2d_Hyperbola.hxx>
#include <Geom2d_Parabola.hxx>
#include <Geom2d_Line.hxx>
#include <Geom2d_OffsetCurve.hxx>

double OCCTCurve3DCircleRadius(OCCTCurve3DRef curve) {
    if (!curve) return 0;
    try {
        Handle(Geom_Circle) c = Handle(Geom_Circle)::DownCast(curve->curve);
        if (c.IsNull()) return 0;
        return c->Radius();
    } catch (...) { return 0; }
}

bool OCCTCurve3DCircleSetRadius(OCCTCurve3DRef curve, double radius) {
    if (!curve) return false;
    try {
        Handle(Geom_Circle) c = Handle(Geom_Circle)::DownCast(curve->curve);
        if (c.IsNull()) return false;
        c->SetRadius(radius);
        return true;
    } catch (...) { return false; }
}

double OCCTCurve3DCircleEccentricity(OCCTCurve3DRef curve) {
    if (!curve) return 0;
    try {
        Handle(Geom_Circle) c = Handle(Geom_Circle)::DownCast(curve->curve);
        if (c.IsNull()) return 0;
        return c->Eccentricity();
    } catch (...) { return 0; }
}

void OCCTCurve3DCircleXAxis(OCCTCurve3DRef curve, double* px, double* py, double* pz, double* dx, double* dy, double* dz) {
    *px = 0; *py = 0; *pz = 0; *dx = 0; *dy = 0; *dz = 0;
    if (!curve) return;
    try {
        Handle(Geom_Circle) c = Handle(Geom_Circle)::DownCast(curve->curve);
        if (c.IsNull()) return;
        gp_Ax1 ax = c->XAxis();
        *px = ax.Location().X(); *py = ax.Location().Y(); *pz = ax.Location().Z();
        *dx = ax.Direction().X(); *dy = ax.Direction().Y(); *dz = ax.Direction().Z();
    } catch (...) {}
}

void OCCTCurve3DCircleYAxis(OCCTCurve3DRef curve, double* px, double* py, double* pz, double* dx, double* dy, double* dz) {
    *px = 0; *py = 0; *pz = 0; *dx = 0; *dy = 0; *dz = 0;
    if (!curve) return;
    try {
        Handle(Geom_Circle) c = Handle(Geom_Circle)::DownCast(curve->curve);
        if (c.IsNull()) return;
        gp_Ax1 ax = c->YAxis();
        *px = ax.Location().X(); *py = ax.Location().Y(); *pz = ax.Location().Z();
        *dx = ax.Direction().X(); *dy = ax.Direction().Y(); *dz = ax.Direction().Z();
    } catch (...) {}
}

void OCCTCurve3DCircleCenter(OCCTCurve3DRef curve, double* x, double* y, double* z) {
    *x = 0; *y = 0; *z = 0;
    if (!curve) return;
    try {
        Handle(Geom_Circle) c = Handle(Geom_Circle)::DownCast(curve->curve);
        if (c.IsNull()) return;
        gp_Pnt ctr = c->Circ().Location();
        *x = ctr.X(); *y = ctr.Y(); *z = ctr.Z();
    } catch (...) {}
}

// MARK: - Geom_Ellipse Methods (v0.108.0)

double OCCTCurve3DEllipseMajorRadius(OCCTCurve3DRef curve) {
    if (!curve) return 0;
    try {
        Handle(Geom_Ellipse) e = Handle(Geom_Ellipse)::DownCast(curve->curve);
        if (e.IsNull()) return 0;
        return e->MajorRadius();
    } catch (...) { return 0; }
}

double OCCTCurve3DEllipseMinorRadius(OCCTCurve3DRef curve) {
    if (!curve) return 0;
    try {
        Handle(Geom_Ellipse) e = Handle(Geom_Ellipse)::DownCast(curve->curve);
        if (e.IsNull()) return 0;
        return e->MinorRadius();
    } catch (...) { return 0; }
}

bool OCCTCurve3DEllipseSetMajorRadius(OCCTCurve3DRef curve, double r) {
    if (!curve) return false;
    try {
        Handle(Geom_Ellipse) e = Handle(Geom_Ellipse)::DownCast(curve->curve);
        if (e.IsNull()) return false;
        e->SetMajorRadius(r);
        return true;
    } catch (...) { return false; }
}

bool OCCTCurve3DEllipseSetMinorRadius(OCCTCurve3DRef curve, double r) {
    if (!curve) return false;
    try {
        Handle(Geom_Ellipse) e = Handle(Geom_Ellipse)::DownCast(curve->curve);
        if (e.IsNull()) return false;
        e->SetMinorRadius(r);
        return true;
    } catch (...) { return false; }
}

double OCCTCurve3DEllipseEccentricity(OCCTCurve3DRef curve) {
    if (!curve) return 0;
    try {
        Handle(Geom_Ellipse) e = Handle(Geom_Ellipse)::DownCast(curve->curve);
        if (e.IsNull()) return 0;
        return e->Eccentricity();
    } catch (...) { return 0; }
}

double OCCTCurve3DEllipseFocal(OCCTCurve3DRef curve) {
    if (!curve) return 0;
    try {
        Handle(Geom_Ellipse) e = Handle(Geom_Ellipse)::DownCast(curve->curve);
        if (e.IsNull()) return 0;
        return e->Focal();
    } catch (...) { return 0; }
}

void OCCTCurve3DEllipseFocus1(OCCTCurve3DRef curve, double* x, double* y, double* z) {
    *x = 0; *y = 0; *z = 0;
    if (!curve) return;
    try {
        Handle(Geom_Ellipse) e = Handle(Geom_Ellipse)::DownCast(curve->curve);
        if (e.IsNull()) return;
        gp_Pnt f = e->Focus1();
        *x = f.X(); *y = f.Y(); *z = f.Z();
    } catch (...) {}
}

void OCCTCurve3DEllipseFocus2(OCCTCurve3DRef curve, double* x, double* y, double* z) {
    *x = 0; *y = 0; *z = 0;
    if (!curve) return;
    try {
        Handle(Geom_Ellipse) e = Handle(Geom_Ellipse)::DownCast(curve->curve);
        if (e.IsNull()) return;
        gp_Pnt f = e->Focus2();
        *x = f.X(); *y = f.Y(); *z = f.Z();
    } catch (...) {}
}

double OCCTCurve3DEllipseParameter(OCCTCurve3DRef curve) {
    if (!curve) return 0;
    try {
        Handle(Geom_Ellipse) e = Handle(Geom_Ellipse)::DownCast(curve->curve);
        if (e.IsNull()) return 0;
        return e->Parameter();
    } catch (...) { return 0; }
}

void OCCTCurve3DEllipseDirectrix1(OCCTCurve3DRef curve, double* px, double* py, double* pz, double* dx, double* dy, double* dz) {
    *px = 0; *py = 0; *pz = 0; *dx = 0; *dy = 0; *dz = 0;
    if (!curve) return;
    try {
        Handle(Geom_Ellipse) e = Handle(Geom_Ellipse)::DownCast(curve->curve);
        if (e.IsNull()) return;
        gp_Ax1 d = e->Directrix1();
        *px = d.Location().X(); *py = d.Location().Y(); *pz = d.Location().Z();
        *dx = d.Direction().X(); *dy = d.Direction().Y(); *dz = d.Direction().Z();
    } catch (...) {}
}

// MARK: - Geom_Hyperbola Methods (v0.108.0)

double OCCTCurve3DHyperbolaMajorRadius(OCCTCurve3DRef curve) {
    if (!curve) return 0;
    try {
        Handle(Geom_Hyperbola) h = Handle(Geom_Hyperbola)::DownCast(curve->curve);
        if (h.IsNull()) return 0;
        return h->MajorRadius();
    } catch (...) { return 0; }
}

double OCCTCurve3DHyperbolaMinorRadius(OCCTCurve3DRef curve) {
    if (!curve) return 0;
    try {
        Handle(Geom_Hyperbola) h = Handle(Geom_Hyperbola)::DownCast(curve->curve);
        if (h.IsNull()) return 0;
        return h->MinorRadius();
    } catch (...) { return 0; }
}

bool OCCTCurve3DHyperbolaSetMajorRadius(OCCTCurve3DRef curve, double r) {
    if (!curve) return false;
    try {
        Handle(Geom_Hyperbola) h = Handle(Geom_Hyperbola)::DownCast(curve->curve);
        if (h.IsNull()) return false;
        h->SetMajorRadius(r);
        return true;
    } catch (...) { return false; }
}

bool OCCTCurve3DHyperbolaSetMinorRadius(OCCTCurve3DRef curve, double r) {
    if (!curve) return false;
    try {
        Handle(Geom_Hyperbola) h = Handle(Geom_Hyperbola)::DownCast(curve->curve);
        if (h.IsNull()) return false;
        h->SetMinorRadius(r);
        return true;
    } catch (...) { return false; }
}

double OCCTCurve3DHyperbolaEccentricity(OCCTCurve3DRef curve) {
    if (!curve) return 0;
    try {
        Handle(Geom_Hyperbola) h = Handle(Geom_Hyperbola)::DownCast(curve->curve);
        if (h.IsNull()) return 0;
        return h->Eccentricity();
    } catch (...) { return 0; }
}

double OCCTCurve3DHyperbolaFocal(OCCTCurve3DRef curve) {
    if (!curve) return 0;
    try {
        Handle(Geom_Hyperbola) h = Handle(Geom_Hyperbola)::DownCast(curve->curve);
        if (h.IsNull()) return 0;
        return h->Focal();
    } catch (...) { return 0; }
}

void OCCTCurve3DHyperbolaFocus1(OCCTCurve3DRef curve, double* x, double* y, double* z) {
    *x = 0; *y = 0; *z = 0;
    if (!curve) return;
    try {
        Handle(Geom_Hyperbola) h = Handle(Geom_Hyperbola)::DownCast(curve->curve);
        if (h.IsNull()) return;
        gp_Pnt f = h->Focus1();
        *x = f.X(); *y = f.Y(); *z = f.Z();
    } catch (...) {}
}

void OCCTCurve3DHyperbolaAsymptote1(OCCTCurve3DRef curve, double* px, double* py, double* pz, double* dx, double* dy, double* dz) {
    *px = 0; *py = 0; *pz = 0; *dx = 0; *dy = 0; *dz = 0;
    if (!curve) return;
    try {
        Handle(Geom_Hyperbola) h = Handle(Geom_Hyperbola)::DownCast(curve->curve);
        if (h.IsNull()) return;
        gp_Ax1 a = h->Asymptote1();
        *px = a.Location().X(); *py = a.Location().Y(); *pz = a.Location().Z();
        *dx = a.Direction().X(); *dy = a.Direction().Y(); *dz = a.Direction().Z();
    } catch (...) {}
}

// MARK: - Geom_Parabola Methods (v0.108.0)

double OCCTCurve3DParabolaFocal(OCCTCurve3DRef curve) {
    if (!curve) return 0;
    try {
        Handle(Geom_Parabola) p = Handle(Geom_Parabola)::DownCast(curve->curve);
        if (p.IsNull()) return 0;
        return p->Focal();
    } catch (...) { return 0; }
}

bool OCCTCurve3DParabolaSetFocal(OCCTCurve3DRef curve, double focal) {
    if (!curve) return false;
    try {
        Handle(Geom_Parabola) p = Handle(Geom_Parabola)::DownCast(curve->curve);
        if (p.IsNull()) return false;
        p->SetFocal(focal);
        return true;
    } catch (...) { return false; }
}

void OCCTCurve3DParabolaFocus(OCCTCurve3DRef curve, double* x, double* y, double* z) {
    *x = 0; *y = 0; *z = 0;
    if (!curve) return;
    try {
        Handle(Geom_Parabola) p = Handle(Geom_Parabola)::DownCast(curve->curve);
        if (p.IsNull()) return;
        gp_Pnt f = p->Focus();
        *x = f.X(); *y = f.Y(); *z = f.Z();
    } catch (...) {}
}

double OCCTCurve3DParabolaEccentricity(OCCTCurve3DRef curve) {
    if (!curve) return 0;
    try {
        Handle(Geom_Parabola) p = Handle(Geom_Parabola)::DownCast(curve->curve);
        if (p.IsNull()) return 0;
        return p->Eccentricity();
    } catch (...) { return 0; }
}

double OCCTCurve3DParabolaParameter(OCCTCurve3DRef curve) {
    if (!curve) return 0;
    try {
        Handle(Geom_Parabola) p = Handle(Geom_Parabola)::DownCast(curve->curve);
        if (p.IsNull()) return 0;
        return p->Parameter();
    } catch (...) { return 0; }
}

void OCCTCurve3DParabolaDirectrix(OCCTCurve3DRef curve, double* px, double* py, double* pz, double* dx, double* dy, double* dz) {
    *px = 0; *py = 0; *pz = 0; *dx = 0; *dy = 0; *dz = 0;
    if (!curve) return;
    try {
        Handle(Geom_Parabola) p = Handle(Geom_Parabola)::DownCast(curve->curve);
        if (p.IsNull()) return;
        gp_Ax1 d = p->Directrix();
        *px = d.Location().X(); *py = d.Location().Y(); *pz = d.Location().Z();
        *dx = d.Direction().X(); *dy = d.Direction().Y(); *dz = d.Direction().Z();
    } catch (...) {}
}

// MARK: - Geom_Line Methods (v0.108.0)

void OCCTCurve3DLineDirection(OCCTCurve3DRef curve, double* dx, double* dy, double* dz) {
    *dx = 0; *dy = 0; *dz = 0;
    if (!curve) return;
    try {
        Handle(Geom_Line) l = Handle(Geom_Line)::DownCast(curve->curve);
        if (l.IsNull()) return;
        gp_Dir d = l->Lin().Direction();
        *dx = d.X(); *dy = d.Y(); *dz = d.Z();
    } catch (...) {}
}

void OCCTCurve3DLineLocation(OCCTCurve3DRef curve, double* x, double* y, double* z) {
    *x = 0; *y = 0; *z = 0;
    if (!curve) return;
    try {
        Handle(Geom_Line) l = Handle(Geom_Line)::DownCast(curve->curve);
        if (l.IsNull()) return;
        gp_Pnt loc = l->Lin().Location();
        *x = loc.X(); *y = loc.Y(); *z = loc.Z();
    } catch (...) {}
}

bool OCCTCurve3DLineSetDirection(OCCTCurve3DRef curve, double dx, double dy, double dz) {
    if (!curve) return false;
    try {
        Handle(Geom_Line) l = Handle(Geom_Line)::DownCast(curve->curve);
        if (l.IsNull()) return false;
        l->SetDirection(gp_Dir(dx, dy, dz));
        return true;
    } catch (...) { return false; }
}

bool OCCTCurve3DLineSetLocation(OCCTCurve3DRef curve, double x, double y, double z) {
    if (!curve) return false;
    try {
        Handle(Geom_Line) l = Handle(Geom_Line)::DownCast(curve->curve);
        if (l.IsNull()) return false;
        l->SetLocation(gp_Pnt(x, y, z));
        return true;
    } catch (...) { return false; }
}

void OCCTCurve3DLinePosition(OCCTCurve3DRef curve, double* px, double* py, double* pz, double* dx, double* dy, double* dz) {
    *px = 0; *py = 0; *pz = 0; *dx = 0; *dy = 0; *dz = 0;
    if (!curve) return;
    try {
        Handle(Geom_Line) l = Handle(Geom_Line)::DownCast(curve->curve);
        if (l.IsNull()) return;
        gp_Ax1 pos = l->Position();
        *px = pos.Location().X(); *py = pos.Location().Y(); *pz = pos.Location().Z();
        *dx = pos.Direction().X(); *dy = pos.Direction().Y(); *dz = pos.Direction().Z();
    } catch (...) {}
}

void OCCTCurve3DLineLin(OCCTCurve3DRef curve, double* px, double* py, double* pz, double* dx, double* dy, double* dz) {
    *px = 0; *py = 0; *pz = 0; *dx = 0; *dy = 0; *dz = 0;
    if (!curve) return;
    try {
        Handle(Geom_Line) l = Handle(Geom_Line)::DownCast(curve->curve);
        if (l.IsNull()) return;
        gp_Lin gl = l->Lin();
        *px = gl.Location().X(); *py = gl.Location().Y(); *pz = gl.Location().Z();
        *dx = gl.Direction().X(); *dy = gl.Direction().Y(); *dz = gl.Direction().Z();
    } catch (...) {}
}

// MARK: - v0.109-v0.111: Extrema_ExtElC + ExtElCS + ExtPElC + Curve3D Extras + Curve3D Evaluation + Batch + GridEval
// MARK: - Extrema_ExtElC: Elementary Curve-Curve Distance (v0.109.0)

#include <Extrema_ExtElC.hxx>
#include <Extrema_ExtElCS.hxx>
#include <Extrema_ExtElSS.hxx>
#include <Extrema_ExtPElC.hxx>
#include <Extrema_ExtPElS.hxx>
#include <Extrema_POnCurv.hxx>
#include <Extrema_POnSurf.hxx>
#include <gp_Elips.hxx>
#include <gp_Parab.hxx>
#include <gp_Sphere.hxx>
#include <gp_Cylinder.hxx>
#include <gp_Cone.hxx>
#include <gp_Torus.hxx>

int32_t OCCTExtremaElCLinLin(double l1px, double l1py, double l1pz, double l1dx, double l1dy, double l1dz,
                              double l2px, double l2py, double l2pz, double l2dx, double l2dy, double l2dz,
                              double tolerance,
                              bool* outIsParallel,
                              OCCTExtremaElResult* out, int32_t max) {
    *outIsParallel = false;
    try {
        gp_Lin l1(gp_Pnt(l1px, l1py, l1pz), gp_Dir(l1dx, l1dy, l1dz));
        gp_Lin l2(gp_Pnt(l2px, l2py, l2pz), gp_Dir(l2dx, l2dy, l2dz));
        Extrema_ExtElC ext(l1, l2, tolerance);
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
            Extrema_POnCurv p1, p2;
            ext.Points(i, p1, p2);
            out[count].squareDistance = ext.SquareDistance(i);
            out[count].x1 = p1.Value().X(); out[count].y1 = p1.Value().Y(); out[count].z1 = p1.Value().Z();
            out[count].x2 = p2.Value().X(); out[count].y2 = p2.Value().Y(); out[count].z2 = p2.Value().Z();
            count++;
        }
        return count;
    } catch (...) { return -1; }
}

int32_t OCCTExtremaElCLinCirc(double lpx, double lpy, double lpz, double ldx, double ldy, double ldz,
                               double cx, double cy, double cz, double nx, double ny, double nz, double radius,
                               double tolerance,
                               OCCTExtremaElResult* out, int32_t max) {
    try {
        gp_Lin l(gp_Pnt(lpx, lpy, lpz), gp_Dir(ldx, ldy, ldz));
        gp_Circ c(gp_Ax2(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz)), radius);
        Extrema_ExtElC ext(l, c, tolerance);
        if (!ext.IsDone()) return -1;
        if (ext.IsParallel()) return 0;
        int n = ext.NbExt();
        int count = 0;
        for (int i = 1; i <= n && count < max; i++) {
            Extrema_POnCurv p1, p2;
            ext.Points(i, p1, p2);
            out[count].squareDistance = ext.SquareDistance(i);
            out[count].x1 = p1.Value().X(); out[count].y1 = p1.Value().Y(); out[count].z1 = p1.Value().Z();
            out[count].x2 = p2.Value().X(); out[count].y2 = p2.Value().Y(); out[count].z2 = p2.Value().Z();
            count++;
        }
        return count;
    } catch (...) { return -1; }
}

int32_t OCCTExtremaElCCircCirc(double c1x, double c1y, double c1z, double n1x, double n1y, double n1z, double r1,
                                double c2x, double c2y, double c2z, double n2x, double n2y, double n2z, double r2,
                                OCCTExtremaElResult* out, int32_t max) {
    try {
        gp_Circ circ1(gp_Ax2(gp_Pnt(c1x, c1y, c1z), gp_Dir(n1x, n1y, n1z)), r1);
        gp_Circ circ2(gp_Ax2(gp_Pnt(c2x, c2y, c2z), gp_Dir(n2x, n2y, n2z)), r2);
        Extrema_ExtElC ext(circ1, circ2);
        if (!ext.IsDone()) return -1;
        if (ext.IsParallel()) return 0;
        int n = ext.NbExt();
        int count = 0;
        for (int i = 1; i <= n && count < max; i++) {
            Extrema_POnCurv p1, p2;
            ext.Points(i, p1, p2);
            out[count].squareDistance = ext.SquareDistance(i);
            out[count].x1 = p1.Value().X(); out[count].y1 = p1.Value().Y(); out[count].z1 = p1.Value().Z();
            out[count].x2 = p2.Value().X(); out[count].y2 = p2.Value().Y(); out[count].z2 = p2.Value().Z();
            count++;
        }
        return count;
    } catch (...) { return -1; }
}

int32_t OCCTExtremaElCLinElips(double lpx, double lpy, double lpz, double ldx, double ldy, double ldz,
                                double cx, double cy, double cz, double nx, double ny, double nz,
                                double xdx, double xdy, double xdz,
                                double majorRadius, double minorRadius,
                                double tolerance,
                                OCCTExtremaElResult* out, int32_t max) {
    try {
        gp_Lin l(gp_Pnt(lpx, lpy, lpz), gp_Dir(ldx, ldy, ldz));
        gp_Ax2 ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz), gp_Dir(xdx, xdy, xdz));
        gp_Elips elips(ax, majorRadius, minorRadius);
        Extrema_ExtElC ext(l, elips);
        if (!ext.IsDone()) return -1;
        if (ext.IsParallel()) return 0;
        int n = ext.NbExt();
        int count = 0;
        for (int i = 1; i <= n && count < max; i++) {
            Extrema_POnCurv p1, p2;
            ext.Points(i, p1, p2);
            out[count].squareDistance = ext.SquareDistance(i);
            out[count].x1 = p1.Value().X(); out[count].y1 = p1.Value().Y(); out[count].z1 = p1.Value().Z();
            out[count].x2 = p2.Value().X(); out[count].y2 = p2.Value().Y(); out[count].z2 = p2.Value().Z();
            count++;
        }
        return count;
    } catch (...) { return -1; }
}
// MARK: - Extrema_ExtElCS (v0.109.0)

int32_t OCCTExtremaElCSLinPlane(double lpx, double lpy, double lpz, double ldx, double ldy, double ldz,
                                 double plx, double ply, double plz, double pnx, double pny, double pnz,
                                 bool* outIsParallel,
                                 OCCTExtremaElResult* out, int32_t max) {
    *outIsParallel = false;
    try {
        gp_Lin l(gp_Pnt(lpx, lpy, lpz), gp_Dir(ldx, ldy, ldz));
        gp_Pln pl(gp_Pnt(plx, ply, plz), gp_Dir(pnx, pny, pnz));
        Extrema_ExtElCS ext(l, pl);
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
            Extrema_POnCurv pc;
            Extrema_POnSurf ps;
            ext.Points(i, pc, ps);
            out[count].squareDistance = ext.SquareDistance(i);
            out[count].x1 = pc.Value().X(); out[count].y1 = pc.Value().Y(); out[count].z1 = pc.Value().Z();
            out[count].x2 = ps.Value().X(); out[count].y2 = ps.Value().Y(); out[count].z2 = ps.Value().Z();
            count++;
        }
        return count;
    } catch (...) { return -1; }
}

int32_t OCCTExtremaElCSLinSphere(double lpx, double lpy, double lpz, double ldx, double ldy, double ldz,
                                   double cx, double cy, double cz, double radius,
                                   OCCTExtremaElResult* out, int32_t max) {
    try {
        gp_Lin l(gp_Pnt(lpx, lpy, lpz), gp_Dir(ldx, ldy, ldz));
        gp_Sphere sp(gp_Ax3(gp_Pnt(cx, cy, cz), gp_Dir(0, 0, 1)), radius);
        Extrema_ExtElCS ext(l, sp);
        if (!ext.IsDone()) return -1;
        int n = ext.NbExt();
        int count = 0;
        for (int i = 1; i <= n && count < max; i++) {
            Extrema_POnCurv pc;
            Extrema_POnSurf ps;
            ext.Points(i, pc, ps);
            out[count].squareDistance = ext.SquareDistance(i);
            out[count].x1 = pc.Value().X(); out[count].y1 = pc.Value().Y(); out[count].z1 = pc.Value().Z();
            out[count].x2 = ps.Value().X(); out[count].y2 = ps.Value().Y(); out[count].z2 = ps.Value().Z();
            count++;
        }
        return count;
    } catch (...) { return -1; }
}

int32_t OCCTExtremaElCSLinCylinder(double lpx, double lpy, double lpz, double ldx, double ldy, double ldz,
                                     double cx, double cy, double cz, double nx, double ny, double nz, double radius,
                                     OCCTExtremaElResult* out, int32_t max) {
    try {
        gp_Dir lineDir(ldx, ldy, ldz), cylAxis(nx, ny, nz);
        // A line parallel to the cylinder axis has infinitely many equidistant extrema; OCCT 8.0.0p1's
        // Extrema_ExtElCS dereferences a null in this degenerate case (an OS SIGSEGV that catch(...)
        // cannot trap). Return 0 extrema, matching the documented "may be 0 if parallel to axis".
        if (Abs(lineDir.Dot(cylAxis)) > 1.0 - 1.0e-9) return 0;
        gp_Lin l(gp_Pnt(lpx, lpy, lpz), lineDir);
        gp_Cylinder cyl(gp_Ax3(gp_Pnt(cx, cy, cz), cylAxis), radius);
        Extrema_ExtElCS ext(l, cyl);
        if (!ext.IsDone()) return -1;
        int n = ext.NbExt();
        int count = 0;
        for (int i = 1; i <= n && count < max; i++) {
            Extrema_POnCurv pc;
            Extrema_POnSurf ps;
            ext.Points(i, pc, ps);
            out[count].squareDistance = ext.SquareDistance(i);
            out[count].x1 = pc.Value().X(); out[count].y1 = pc.Value().Y(); out[count].z1 = pc.Value().Z();
            out[count].x2 = ps.Value().X(); out[count].y2 = ps.Value().Y(); out[count].z2 = ps.Value().Z();
            count++;
        }
        return count;
    } catch (...) { return -1; }
}
// MARK: - Extrema_ExtPElC (v0.109.0)

int32_t OCCTExtremaExtPElCLin(double px, double py, double pz,
                                double lx, double ly, double lz, double ldx, double ldy, double ldz,
                                double tolerance,
                                OCCTExtremaElResult* out, int32_t max) {
    try {
        gp_Pnt p(px, py, pz);
        gp_Lin l(gp_Pnt(lx, ly, lz), gp_Dir(ldx, ldy, ldz));
        Extrema_ExtPElC ext(p, l, tolerance, -1e10, 1e10);
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

int32_t OCCTExtremaExtPElCCirc(double px, double py, double pz,
                                 double cx, double cy, double cz, double nx, double ny, double nz, double radius,
                                 double tolerance,
                                 OCCTExtremaElResult* out, int32_t max) {
    try {
        gp_Pnt p(px, py, pz);
        gp_Circ c(gp_Ax2(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz)), radius);
        Extrema_ExtPElC ext(p, c, tolerance, 0, 2 * M_PI);
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

int32_t OCCTExtremaExtPElCElips(double px, double py, double pz,
                                  double cx, double cy, double cz, double nx, double ny, double nz,
                                  double xdx, double xdy, double xdz,
                                  double majorRadius, double minorRadius,
                                  double tolerance,
                                  OCCTExtremaElResult* out, int32_t max) {
    try {
        gp_Pnt p(px, py, pz);
        gp_Ax2 ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz), gp_Dir(xdx, xdy, xdz));
        gp_Elips elips(ax, majorRadius, minorRadius);
        Extrema_ExtPElC ext(p, elips, tolerance, 0, 2 * M_PI);
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

int32_t OCCTExtremaExtPElCParab(double px, double py, double pz,
                                  double cx, double cy, double cz, double nx, double ny, double nz,
                                  double xdx, double xdy, double xdz,
                                  double focal,
                                  double tolerance,
                                  OCCTExtremaElResult* out, int32_t max) {
    try {
        gp_Pnt p(px, py, pz);
        gp_Ax2 ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz), gp_Dir(xdx, xdy, xdz));
        gp_Parab parab(ax, focal);
        Extrema_ExtPElC ext(p, parab, tolerance, -1e6, 1e6);
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
// MARK: - Curve3D Extras (v0.109.0)

bool OCCTCurve3DReverse(OCCTCurve3DRef curve) {
    if (!curve) return false;
    try {
        curve->curve->Reverse();
        return true;
    } catch (...) { return false; }
}

OCCTCurve3DRef OCCTCurve3DCopy(OCCTCurve3DRef curve) {
    if (!curve) return nullptr;
    try {
        Handle(Geom_Curve) copy = Handle(Geom_Curve)::DownCast(curve->curve->Copy());
        if (copy.IsNull()) return nullptr;
        return new OCCTCurve3D(copy);
    } catch (...) { return nullptr; }
}

int32_t OCCTCurve3DContinuity(OCCTCurve3DRef curve) {
    if (!curve) return -1;
    try {
        GeomAbs_Shape cont = curve->curve->Continuity();
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
// MARK: - Curve3D Evaluation (v0.110.0)

void OCCTCurve3DEvalD0(OCCTCurve3DRef curve, double u, double* x, double* y, double* z) {
    *x = 0; *y = 0; *z = 0;
    if (!curve || curve->curve.IsNull()) return;
    try {
        gp_Pnt p = curve->curve->EvalD0(u);
        *x = p.X(); *y = p.Y(); *z = p.Z();
    } catch (...) {}
}

void OCCTCurve3DEvalD1(OCCTCurve3DRef curve, double u,
                         double* px, double* py, double* pz,
                         double* d1x, double* d1y, double* d1z) {
    *px = 0; *py = 0; *pz = 0; *d1x = 0; *d1y = 0; *d1z = 0;
    if (!curve || curve->curve.IsNull()) return;
    try {
        Geom_Curve::ResD1 r = curve->curve->EvalD1(u);
        *px = r.Point.X(); *py = r.Point.Y(); *pz = r.Point.Z();
        *d1x = r.D1.X(); *d1y = r.D1.Y(); *d1z = r.D1.Z();
    } catch (...) {}
}

void OCCTCurve3DEvalD2(OCCTCurve3DRef curve, double u,
                         double* px, double* py, double* pz,
                         double* d1x, double* d1y, double* d1z,
                         double* d2x, double* d2y, double* d2z) {
    *px = 0; *py = 0; *pz = 0; *d1x = 0; *d1y = 0; *d1z = 0; *d2x = 0; *d2y = 0; *d2z = 0;
    if (!curve || curve->curve.IsNull()) return;
    try {
        Geom_Curve::ResD2 r = curve->curve->EvalD2(u);
        *px = r.Point.X(); *py = r.Point.Y(); *pz = r.Point.Z();
        *d1x = r.D1.X(); *d1y = r.D1.Y(); *d1z = r.D1.Z();
        *d2x = r.D2.X(); *d2y = r.D2.Y(); *d2z = r.D2.Z();
    } catch (...) {}
}

void OCCTCurve3DEvalD3(OCCTCurve3DRef curve, double u,
                         double* px, double* py, double* pz,
                         double* d1x, double* d1y, double* d1z,
                         double* d2x, double* d2y, double* d2z,
                         double* d3x, double* d3y, double* d3z) {
    *px = 0; *py = 0; *pz = 0; *d1x = 0; *d1y = 0; *d1z = 0;
    *d2x = 0; *d2y = 0; *d2z = 0; *d3x = 0; *d3y = 0; *d3z = 0;
    if (!curve || curve->curve.IsNull()) return;
    try {
        Geom_Curve::ResD3 r = curve->curve->EvalD3(u);
        *px = r.Point.X(); *py = r.Point.Y(); *pz = r.Point.Z();
        *d1x = r.D1.X(); *d1y = r.D1.Y(); *d1z = r.D1.Z();
        *d2x = r.D2.X(); *d2y = r.D2.Y(); *d2z = r.D2.Z();
        *d3x = r.D3.X(); *d3y = r.D3.Y(); *d3z = r.D3.Z();
    } catch (...) {}
}
// MARK: - Batch Curve Evaluation (v0.110.0)

void OCCTCurve3DEvalBatchD0(OCCTCurve3DRef curve, const double* params, int32_t count,
                              double* xs, double* ys, double* zs) {
    if (!curve || curve->curve.IsNull() || count <= 0) return;
    try {
        for (int i = 0; i < count; i++) {
            gp_Pnt p = curve->curve->EvalD0(params[i]);
            xs[i] = p.X(); ys[i] = p.Y(); zs[i] = p.Z();
        }
    } catch (...) {}
}

void OCCTCurve3DEvalBatchD1(OCCTCurve3DRef curve, const double* params, int32_t count,
                              double* xs, double* ys, double* zs,
                              double* d1xs, double* d1ys, double* d1zs) {
    if (!curve || curve->curve.IsNull() || count <= 0) return;
    try {
        for (int i = 0; i < count; i++) {
            Geom_Curve::ResD1 r = curve->curve->EvalD1(params[i]);
            xs[i] = r.Point.X(); ys[i] = r.Point.Y(); zs[i] = r.Point.Z();
            d1xs[i] = r.D1.X(); d1ys[i] = r.D1.Y(); d1zs[i] = r.D1.Z();
        }
    } catch (...) {}
}

void OCCTCurve2DEvalBatchD0(OCCTCurve2DRef curve, const double* params, int32_t count,
                              double* xs, double* ys) {
    if (!curve || curve->curve.IsNull() || count <= 0) return;
    try {
        for (int i = 0; i < count; i++) {
            gp_Pnt2d p = curve->curve->EvalD0(params[i]);
            xs[i] = p.X(); ys[i] = p.Y();
        }
    } catch (...) {}
}

void OCCTCurve2DEvalBatchD1(OCCTCurve2DRef curve, const double* params, int32_t count,
                              double* xs, double* ys,
                              double* d1xs, double* d1ys) {
    if (!curve || curve->curve.IsNull() || count <= 0) return;
    try {
        for (int i = 0; i < count; i++) {
            Geom2d_Curve::ResD1 r = curve->curve->EvalD1(params[i]);
            xs[i] = r.Point.X(); ys[i] = r.Point.Y();
            d1xs[i] = r.D1.X(); d1ys[i] = r.D1.Y();
        }
    } catch (...) {}
}
// MARK: - GeomGridEval_Curve 3D (v0.111.0)

void OCCTGridEvalCurveD0(OCCTCurve3DRef curve, const double* params, int32_t count,
                           double* xs, double* ys, double* zs) {
    if (!curve || curve->curve.IsNull() || count <= 0) return;
    try {
        GeomGridEval_Curve eval(curve->curve);
        NCollection_Array1<double> pArr(1, count);
        for (int i = 0; i < count; i++) pArr(i+1) = params[i];
        NCollection_Array1<gp_Pnt> results = eval.EvaluateGrid(pArr);
        for (int i = 0; i < count; i++) {
            xs[i] = results(i+1).X(); ys[i] = results(i+1).Y(); zs[i] = results(i+1).Z();
        }
    } catch (...) {}
}

void OCCTGridEvalCurveD1(OCCTCurve3DRef curve, const double* params, int32_t count,
                           double* xs, double* ys, double* zs,
                           double* d1xs, double* d1ys, double* d1zs) {
    if (!curve || curve->curve.IsNull() || count <= 0) return;
    try {
        GeomGridEval_Curve eval(curve->curve);
        NCollection_Array1<double> pArr(1, count);
        for (int i = 0; i < count; i++) pArr(i+1) = params[i];
        NCollection_Array1<GeomGridEval::CurveD1> results = eval.EvaluateGridD1(pArr);
        for (int i = 0; i < count; i++) {
            xs[i] = results(i+1).Point.X(); ys[i] = results(i+1).Point.Y(); zs[i] = results(i+1).Point.Z();
            d1xs[i] = results(i+1).D1.X(); d1ys[i] = results(i+1).D1.Y(); d1zs[i] = results(i+1).D1.Z();
        }
    } catch (...) {}
}

// MARK: - v0.112: Curve3D extras + Extrema extras (LocateOnCurve/Surface)
// --- Curve3D extras ---

int32_t OCCTCurve3DCurveType(OCCTCurve3DRef curve) {
    if (!curve || curve->curve.IsNull()) return 7; // OtherCurve
    try {
        GeomAdaptor_Curve ac(curve->curve);
        return (int32_t)ac.GetType();
    } catch (...) { return 7; }
}

double OCCTCurve3DParameterAtPoint(OCCTCurve3DRef curve,
                                   double x, double y, double z) {
    if (!curve || curve->curve.IsNull()) return 0;
    try {
        GeomAPI_ProjectPointOnCurve proj(gp_Pnt(x, y, z), curve->curve);
        if (proj.NbPoints() < 1) return curve->curve->FirstParameter();
        return proj.LowerDistanceParameter();
    } catch (...) { return 0; }
}
// --- Extrema extras ---

bool OCCTExtremaLocateOnCurve(OCCTCurve3DRef curve,
                              double px, double py, double pz,
                              double initParam, double tol,
                              double* param, double* distance) {
    if (!curve || curve->curve.IsNull()) return false;
    try {
        // Use ProjectPointOnCurve in a narrow window around initParam for local search
        double f = curve->curve->FirstParameter();
        double l = curve->curve->LastParameter();
        double range = (l - f) * 0.1;
        double lo = std::max(f, initParam - range);
        double hi = std::min(l, initParam + range);
        GeomAPI_ProjectPointOnCurve proj(gp_Pnt(px, py, pz), curve->curve, lo, hi);
        if (proj.NbPoints() < 1) {
            // Fallback to full range
            GeomAPI_ProjectPointOnCurve projFull(gp_Pnt(px, py, pz), curve->curve);
            if (projFull.NbPoints() < 1) return false;
            *param = projFull.LowerDistanceParameter();
            *distance = projFull.LowerDistance();
            return true;
        }
        *param = proj.LowerDistanceParameter();
        *distance = proj.LowerDistance();
        return true;
    } catch (...) { return false; }
}

bool OCCTExtremaLocateOnSurface(OCCTSurfaceRef surface,
                                double px, double py, double pz,
                                double initU, double initV, double tol,
                                double* u, double* v, double* distance) {
    if (!surface || surface->surface.IsNull()) return false;
    try {
        GeomAdaptor_Surface as(surface->surface);
        Extrema_GenLocateExtPS ext(as, tol, tol);
        ext.Perform(gp_Pnt(px, py, pz), initU, initV);
        if (!ext.IsDone()) return false;
        ext.Point().Parameter(*u, *v);
        *distance = sqrt(ext.SquareDistance());
        return true;
    } catch (...) { return false; }
}

int32_t OCCTExtremaPointCurve(OCCTCurve3DRef curve,
                              double px, double py, double pz,
                              double* params, double* distances, int32_t maxResults) {
    if (!curve || curve->curve.IsNull()) return 0;
    try {
        GeomAPI_ProjectPointOnCurve proj(gp_Pnt(px, py, pz), curve->curve);
        int32_t n = std::min((int32_t)proj.NbPoints(), maxResults);
        for (int32_t i = 0; i < n; i++) {
            params[i] = proj.Parameter(i + 1);
            distances[i] = proj.Distance(i + 1);
        }
        return n;
    } catch (...) { return 0; }
}

int32_t OCCTExtremaPointSurface(OCCTSurfaceRef surface,
                                double px, double py, double pz,
                                double* us, double* vs, double* distances,
                                int32_t maxResults) {
    if (!surface || surface->surface.IsNull()) return 0;
    try {
        GeomAPI_ProjectPointOnSurf proj(gp_Pnt(px, py, pz), surface->surface);
        if (!proj.IsDone()) return 0;
        int32_t n = std::min((int32_t)proj.NbPoints(), maxResults);
        for (int32_t i = 0; i < n; i++) {
            double pu, pv;
            proj.Parameters(i + 1, pu, pv);
            us[i] = pu;
            vs[i] = pv;
            distances[i] = proj.Distance(i + 1);
        }
        return n;
    } catch (...) { return 0; }
}

// MARK: - v0.113: GeomAPI_ProjectPointOnCurve (multi-result) + BSplineCurve mutations
// --- GeomAPI_ProjectPointOnCurve (multi-result) ---

struct OCCTProjOnCurve {
    GeomAPI_ProjectPointOnCurve proj;
};

OCCTProjOnCurveRef OCCTProjOnCurveCreate(OCCTCurve3DRef curve, double px, double py, double pz) {
    if (!curve || curve->curve.IsNull()) return nullptr;
    try {
        auto ref = new OCCTProjOnCurve();
        ref->proj.Init(gp_Pnt(px, py, pz), curve->curve);
        return ref;
    } catch (...) { return nullptr; }
}

void OCCTProjOnCurveRelease(OCCTProjOnCurveRef proj) {
    delete proj;
}

int32_t OCCTProjOnCurveNbPoints(OCCTProjOnCurveRef proj) {
    if (!proj) return 0;
    try { return (int32_t)proj->proj.NbPoints(); }
    catch (...) { return 0; }
}

void OCCTProjOnCurvePoint(OCCTProjOnCurveRef proj, int32_t index,
                           double* x, double* y, double* z) {
    if (!proj) { *x = *y = *z = 0; return; }
    try {
        gp_Pnt p = proj->proj.Point(index);
        *x = p.X(); *y = p.Y(); *z = p.Z();
    } catch (...) { *x = *y = *z = 0; }
}

double OCCTProjOnCurveParameter(OCCTProjOnCurveRef proj, int32_t index) {
    if (!proj) return 0;
    try { return proj->proj.Parameter(index); }
    catch (...) { return 0; }
}

double OCCTProjOnCurveDistance(OCCTProjOnCurveRef proj, int32_t index) {
    if (!proj) return -1;
    try { return proj->proj.Distance(index); }
    catch (...) { return -1; }
}

double OCCTProjOnCurveLowerDistance(OCCTProjOnCurveRef proj) {
    if (!proj) return -1;
    try { return proj->proj.LowerDistance(); }
    catch (...) { return -1; }
}

double OCCTProjOnCurveLowerParam(OCCTProjOnCurveRef proj) {
    if (!proj) return 0;
    try { return proj->proj.LowerDistanceParameter(); }
    catch (...) { return 0; }
}
// --- BSplineCurve remaining mutations ---

bool OCCTCurve3DBSplineSetKnot(OCCTCurve3DRef curve, int32_t index, double knot) {
    if (!curve || curve->curve.IsNull()) return false;
    try {
        Handle(Geom_BSplineCurve) bsc = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
        if (bsc.IsNull()) return false;
        bsc->SetKnot(index, knot);
        return true;
    } catch (...) { return false; }
}

void OCCTCurve3DBSplineGetKnotSequence(OCCTCurve3DRef curve, double* knotSeq, int32_t* count) {
    if (!curve || curve->curve.IsNull()) { *count = 0; return; }
    try {
        Handle(Geom_BSplineCurve) bsc = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
        if (bsc.IsNull()) { *count = 0; return; }
        TColStd_Array1OfReal seq(1, bsc->NbPoles() + bsc->Degree() + 1);
        bsc->KnotSequence(seq);
        *count = seq.Length();
        for (int i = 1; i <= seq.Length(); i++) {
            knotSeq[i - 1] = seq(i);
        }
    } catch (...) { *count = 0; }
}

void OCCTCurve3DBSplineGetWeights(OCCTCurve3DRef curve, double* weights) {
    if (!curve || curve->curve.IsNull()) return;
    try {
        Handle(Geom_BSplineCurve) bsc = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
        if (bsc.IsNull()) return;
        TColStd_Array1OfReal w(1, bsc->NbPoles());
        bsc->Weights(w);
        for (int i = 1; i <= w.Length(); i++) {
            weights[i - 1] = w(i);
        }
    } catch (...) {}
}

bool OCCTCurve3DBSplineInsertKnots(OCCTCurve3DRef curve,
                                     const double* knots, const int32_t* mults,
                                     int32_t count, double tol) {
    if (!curve || curve->curve.IsNull() || count <= 0) return false;
    try {
        Handle(Geom_BSplineCurve) bsc = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
        if (bsc.IsNull()) return false;
        TColStd_Array1OfReal knotsArr(1, count);
        TColStd_Array1OfInteger multsArr(1, count);
        for (int i = 0; i < count; i++) {
            knotsArr(i + 1) = knots[i];
            multsArr(i + 1) = mults[i];
        }
        bsc->InsertKnots(knotsArr, multsArr, tol);
        return true;
    } catch (...) { return false; }
}

bool OCCTCurve3DBSplineMovePoint(OCCTCurve3DRef curve, double u,
                                   double x, double y, double z,
                                   int32_t index1, int32_t index2) {
    if (!curve || curve->curve.IsNull()) return false;
    try {
        Handle(Geom_BSplineCurve) bsc = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
        if (bsc.IsNull()) return false;
        int first, last;
        bsc->MovePoint(u, gp_Pnt(x, y, z), index1, index2, first, last);
        return true;
    } catch (...) { return false; }
}

void OCCTCurve3DBSplineLocalValue(OCCTCurve3DRef curve, double u,
                                    int32_t fromK1, int32_t toK2,
                                    double* x, double* y, double* z) {
    if (!curve || curve->curve.IsNull()) { *x = *y = *z = 0; return; }
    try {
        Handle(Geom_BSplineCurve) bsc = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
        if (bsc.IsNull()) { *x = *y = *z = 0; return; }
        gp_Pnt p = bsc->LocalValue(u, fromK1, toK2);
        *x = p.X(); *y = p.Y(); *z = p.Z();
    } catch (...) { *x = *y = *z = 0; }
}

int32_t OCCTCurve3DBSplineMaxDegree() {
    return (int32_t)Geom_BSplineCurve::MaxDegree();
}

int32_t OCCTCurve3DBSplineLocateU(OCCTCurve3DRef curve, double u, double tol) {
    if (!curve || curve->curve.IsNull()) return 0;
    try {
        Handle(Geom_BSplineCurve) bsc = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
        if (bsc.IsNull()) return 0;
        int ki = 0;
        bsc->LocateU(u, tol, ki, ki);
        return (int32_t)ki;
    } catch (...) { return 0; }
}

// MARK: - v0.114: Curve3D isBounded + DN + type-name
// --- Curve isBounded ---

bool OCCTCurve3DIsBounded(OCCTCurve3DRef curve) {
    if (!curve || curve->curve.IsNull()) return false;
    try {
        Handle(Geom_BoundedCurve) bc = Handle(Geom_BoundedCurve)::DownCast(curve->curve);
        return !bc.IsNull();
    } catch (...) { return false; }
}
// --- Geom_Curve DN ---

void OCCTCurve3DDN(OCCTCurve3DRef curve, double u, int32_t n,
                    double* x, double* y, double* z) {
    if (!curve || curve->curve.IsNull()) { *x = *y = *z = 0; return; }
    try {
        gp_Vec v = curve->curve->DN(u, n);
        *x = v.X(); *y = v.Y(); *z = v.Z();
    } catch (...) { *x = *y = *z = 0; }
}
const char* OCCTCurve3DTypeName(OCCTCurve3DRef curve) {
    if (!curve || curve->curve.IsNull()) return nullptr;
    try {
        return curve->curve->DynamicType()->Name();
    } catch (...) { return nullptr; }
}


// MARK: - v0.115: GeomAPI_Interpolate expansion + PointsToBSpline + GeomConvert utilities + Curve extras + Arc Length
// --- GeomAPI_Interpolate expansion ---

OCCTCurve3DRef OCCTInterpolateWithTangents(const double* points, int32_t count,
                                             double t1x, double t1y, double t1z,
                                             double t2x, double t2y, double t2z) {
    if (!points || count < 2) return nullptr;
    try {
        Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, count);
        for (int i = 0; i < count; i++) {
            pts->SetValue(i + 1, gp_Pnt(points[i*3], points[i*3+1], points[i*3+2]));
        }
        GeomAPI_Interpolate interp(pts, Standard_False, 1e-6);
        gp_Vec v1(t1x, t1y, t1z), v2(t2x, t2y, t2z);
        interp.Load(v1, v2);
        interp.Perform();
        if (interp.IsDone()) {
            return (OCCTCurve3DRef)new OCCTCurve3D{interp.Curve()};
        }
        return nullptr;
    } catch (...) { return nullptr; }
}

OCCTCurve3DRef OCCTInterpolateWithAllTangents(const double* points, int32_t count,
                                                const double* tangents,
                                                const bool* tangentFlags) {
    if (!points || !tangents || !tangentFlags || count < 2) return nullptr;
    try {
        Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, count);
        for (int i = 0; i < count; i++) {
            pts->SetValue(i + 1, gp_Pnt(points[i*3], points[i*3+1], points[i*3+2]));
        }
        GeomAPI_Interpolate interp(pts, Standard_False, 1e-6);
        NCollection_Array1<gp_Vec> tans(1, count);
        Handle(NCollection_HArray1<bool>) flags = new NCollection_HArray1<bool>(1, count);
        for (int i = 0; i < count; i++) {
            tans.SetValue(i + 1, gp_Vec(tangents[i*3], tangents[i*3+1], tangents[i*3+2]));
            flags->SetValue(i + 1, tangentFlags[i]);
        }
        interp.Load(tans, flags);
        interp.Perform();
        if (interp.IsDone()) {
            return (OCCTCurve3DRef)new OCCTCurve3D{interp.Curve()};
        }
        return nullptr;
    } catch (...) { return nullptr; }
}

OCCTCurve3DRef OCCTInterpolateWithParameters(const double* points, int32_t count,
                                               const double* parameters) {
    if (!points || !parameters || count < 2) return nullptr;
    try {
        Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, count);
        for (int i = 0; i < count; i++) {
            pts->SetValue(i + 1, gp_Pnt(points[i*3], points[i*3+1], points[i*3+2]));
        }
        Handle(TColStd_HArray1OfReal) params = new TColStd_HArray1OfReal(1, count);
        for (int i = 0; i < count; i++) {
            params->SetValue(i + 1, parameters[i]);
        }
        GeomAPI_Interpolate interp(pts, params, Standard_False, 1e-6);
        interp.Perform();
        if (interp.IsDone()) {
            return (OCCTCurve3DRef)new OCCTCurve3D{interp.Curve()};
        }
        return nullptr;
    } catch (...) { return nullptr; }
}

OCCTCurve3DRef OCCTInterpolatePeriodic(const double* points, int32_t count) {
    if (!points || count < 3) return nullptr;
    try {
        Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, count);
        for (int i = 0; i < count; i++) {
            pts->SetValue(i + 1, gp_Pnt(points[i*3], points[i*3+1], points[i*3+2]));
        }
        GeomAPI_Interpolate interp(pts, Standard_True, 1e-6);
        interp.Perform();
        if (interp.IsDone()) {
            return (OCCTCurve3DRef)new OCCTCurve3D{interp.Curve()};
        }
        return nullptr;
    } catch (...) { return nullptr; }
}


static GeomAbs_Shape mapContinuityV115(int32_t c) {
    switch (c) {
        case 0: return GeomAbs_C0;
        case 1: return GeomAbs_C1;
        case 2: return GeomAbs_C2;
        case 3: return GeomAbs_C3;
        default: return GeomAbs_C2;
    }
}

OCCTCurve3DRef OCCTPointsToBSplineWithParams(const double* points, int32_t count,
                                               int32_t degMin, int32_t degMax,
                                               int32_t continuity, double tol) {
    if (!points || count < 2) return nullptr;
    try {
        TColgp_Array1OfPnt pts(1, count);
        for (int i = 0; i < count; i++) {
            pts.SetValue(i + 1, gp_Pnt(points[i*3], points[i*3+1], points[i*3+2]));
        }
        GeomAPI_PointsToBSpline approx(pts, degMin, degMax, mapContinuityV115(continuity), tol);
        if (approx.IsDone()) {
            return (OCCTCurve3DRef)new OCCTCurve3D{approx.Curve()};
        }
        return nullptr;
    } catch (...) { return nullptr; }
}

OCCTCurve3DRef OCCTPointsToBSplineWithParameters(const double* points, const double* params,
                                                   int32_t count, int32_t degMin, int32_t degMax,
                                                   int32_t continuity, double tol) {
    if (!points || !params || count < 2) return nullptr;
    try {
        TColgp_Array1OfPnt pts(1, count);
        TColStd_Array1OfReal prms(1, count);
        for (int i = 0; i < count; i++) {
            pts.SetValue(i + 1, gp_Pnt(points[i*3], points[i*3+1], points[i*3+2]));
            prms.SetValue(i + 1, params[i]);
        }
        GeomAPI_PointsToBSpline approx(pts, prms, degMin, degMax, mapContinuityV115(continuity), tol);
        if (approx.IsDone()) {
            return (OCCTCurve3DRef)new OCCTCurve3D{approx.Curve()};
        }
        return nullptr;
    } catch (...) { return nullptr; }
}



int32_t OCCTCurve3DSplitAtContinuity(OCCTCurve3DRef curve, int32_t continuity, double tol,
                                       OCCTCurve3DRef* outSegments, int32_t maxSegments) {
    if (!curve || curve->curve.IsNull() || !outSegments || maxSegments < 1) return 0;
    try {
        Handle(Geom_BSplineCurve) bsp = GeomConvert::CurveToBSplineCurve(curve->curve);
        if (bsp.IsNull()) return 0;

        if (continuity <= 1) {
            // Split at C1 discontinuities
            Handle(NCollection_HArray1<Handle(Geom_BSplineCurve)>) arr;
            GeomConvert::C0BSplineToArrayOfC1BSplineCurve(bsp, arr, tol);
            if (arr.IsNull()) return 0;
            int n = std::min((int)arr->Length(), (int)maxSegments);
            for (int i = 0; i < n; i++) {
                outSegments[i] = (OCCTCurve3DRef)new OCCTCurve3D{arr->Value(arr->Lower() + i)};
            }
            return n;
        } else {
            // For higher continuity, just return the single BSpline
            outSegments[0] = (OCCTCurve3DRef)new OCCTCurve3D{bsp};
            return 1;
        }
    } catch (...) { return 0; }
}

// TColGeom/TColGeom2d deprecated — use NCollection_HArray1 directly


OCCTCurve3DRef OCCTCurve3DConcatenateG1(const OCCTCurve3DRef* curves, int32_t count, double tol) {
    if (!curves || count < 1) return nullptr;
    try {
        Handle(Geom_BSplineCurve) first = GeomConvert::CurveToBSplineCurve(((OCCTCurve3D*)curves[0])->curve);
        if (first.IsNull()) return nullptr;
        GeomConvert_CompCurveToBSplineCurve concat(first);
        for (int i = 1; i < count; i++) {
            Handle(Geom_BSplineCurve) bsp = GeomConvert::CurveToBSplineCurve(((OCCTCurve3D*)curves[i])->curve);
            if (!bsp.IsNull()) {
                concat.Add(bsp, tol);
            }
        }
        Handle(Geom_BSplineCurve) result = concat.BSplineCurve();
        if (result.IsNull()) return nullptr;
        return (OCCTCurve3DRef)new OCCTCurve3D{result};
    } catch (...) { return nullptr; }
}
// --- Curve3D/2D additional (new in v0.115.0) ---

#include <CPnts_AbscissaPoint.hxx>
#include <GeomAdaptor_Curve.hxx>

double OCCTCurve3DLength(OCCTCurve3DRef curve, double u1, double u2) {
    if (!curve || curve->curve.IsNull()) return 0;
    try {
        GeomAdaptor_Curve ac(curve->curve, u1, u2);
        return GCPnts_AbscissaPoint::Length(ac);
    } catch (...) { return 0; }
}

double OCCTCurve3DClosestParameter(OCCTCurve3DRef curve, double px, double py, double pz) {
    if (!curve || curve->curve.IsNull()) return 0;
    try {
        GeomAPI_ProjectPointOnCurve proj(gp_Pnt(px, py, pz), curve->curve);
        if (proj.NbPoints() > 0) {
            return proj.LowerDistanceParameter();
        }
        return 0;
    } catch (...) { return 0; }
}


double OCCTCurve3DParameterAtLength(OCCTCurve3DRef curve, double arcLength, double fromParam) {
    if (!curve) return 0;
    try {
        GeomAdaptor_Curve adaptor(curve->curve);
        GCPnts_AbscissaPoint ap(adaptor, arcLength, fromParam);
        if (ap.IsDone()) return ap.Parameter();
        return 0;
    } catch (...) { return 0; }
}

double OCCTCurve3DArcLength(OCCTCurve3DRef curve) {
    if (!curve) return 0;
    try {
        GeomAdaptor_Curve adaptor(curve->curve);
        return GCPnts_AbscissaPoint::Length(adaptor);
    } catch (...) { return 0; }
}

double OCCTCurve3DArcLengthBetween(OCCTCurve3DRef curve, double param1, double param2) {
    if (!curve) return 0;
    try {
        GeomAdaptor_Curve adaptor(curve->curve);
        return GCPnts_AbscissaPoint::Length(adaptor, param1, param2);
    } catch (...) { return 0; }
}

// MARK: - v0.116: HelixGeom (BuilderHelix/Coil + HelixCurve eval/D1/D2 + ApproxToBSpline)
#include <math_IntegerVector.hxx>

// HelixGeom

OCCTCurve3DRef _Nullable OCCTHelixBuild(double posX, double posY, double posZ,
                                          double dirX, double dirY, double dirZ,
                                          double xDirX, double xDirY, double xDirZ,
                                          double t1, double t2, double pitch, double rStart,
                                          double taperAngle, bool isClockwise,
                                          double tolerance, double* _Nonnull tolReached) {
    try {
        HelixGeom_BuilderHelix builder;
        gp_Ax2 ax2(gp_Pnt(posX, posY, posZ), gp_Dir(dirX, dirY, dirZ), gp_Dir(xDirX, xDirY, xDirZ));
        builder.SetPosition(ax2);
        builder.SetCurveParameters(t1, t2, pitch, rStart, taperAngle, isClockwise);
        builder.SetTolerance(tolerance);
        builder.Perform();
        if (builder.ErrorStatus() != 0 || builder.Curves().IsEmpty()) return nullptr;
        *tolReached = builder.ToleranceReached();
        auto curve = builder.Curves().First();
        auto* ref = new OCCTCurve3D;
        ref->curve = curve;
        return ref;
    } catch (...) { return nullptr; }
}

OCCTCurve3DRef _Nullable OCCTHelixCoilBuild(double t1, double t2, double pitch, double rStart,
                                              double taperAngle, bool isClockwise,
                                              double tolerance, double* _Nonnull tolReached) {
    try {
        HelixGeom_BuilderHelixCoil builder;
        builder.SetCurveParameters(t1, t2, pitch, rStart, taperAngle, isClockwise);
        builder.SetTolerance(tolerance);
        builder.Perform();
        if (builder.ErrorStatus() != 0 || builder.Curves().IsEmpty()) return nullptr;
        *tolReached = builder.ToleranceReached();
        auto curve = builder.Curves().First();
        auto* ref = new OCCTCurve3D;
        ref->curve = curve;
        return ref;
    } catch (...) { return nullptr; }
}

void OCCTHelixCurveEval(double t1, double t2, double pitch, double rStart,
                          double taperAngle, bool isClockwise, double u,
                          double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz) {
    try {
        HelixGeom_HelixCurve hc;
        hc.Load(t1, t2, pitch, rStart, taperAngle, isClockwise);
        gp_Pnt p = hc.Value(u);
        *px = p.X(); *py = p.Y(); *pz = p.Z();
    } catch (...) { *px = *py = *pz = 0; }
}

void OCCTHelixCurveD1(double t1, double t2, double pitch, double rStart,
                        double taperAngle, bool isClockwise, double u,
                        double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz,
                        double* _Nonnull vx, double* _Nonnull vy, double* _Nonnull vz) {
    try {
        HelixGeom_HelixCurve hc;
        hc.Load(t1, t2, pitch, rStart, taperAngle, isClockwise);
        gp_Pnt p; gp_Vec v;
        hc.D1(u, p, v);
        *px = p.X(); *py = p.Y(); *pz = p.Z();
        *vx = v.X(); *vy = v.Y(); *vz = v.Z();
    } catch (...) { *px = *py = *pz = *vx = *vy = *vz = 0; }
}

void OCCTHelixCurveD2(double t1, double t2, double pitch, double rStart,
                        double taperAngle, bool isClockwise, double u,
                        double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz,
                        double* _Nonnull v1x, double* _Nonnull v1y, double* _Nonnull v1z,
                        double* _Nonnull v2x, double* _Nonnull v2y, double* _Nonnull v2z) {
    try {
        HelixGeom_HelixCurve hc;
        hc.Load(t1, t2, pitch, rStart, taperAngle, isClockwise);
        gp_Pnt p; gp_Vec v1, v2;
        hc.D2(u, p, v1, v2);
        *px = p.X(); *py = p.Y(); *pz = p.Z();
        *v1x = v1.X(); *v1y = v1.Y(); *v1z = v1.Z();
        *v2x = v2.X(); *v2y = v2.Y(); *v2z = v2.Z();
    } catch (...) { *px = *py = *pz = *v1x = *v1y = *v1z = *v2x = *v2y = *v2z = 0; }
}

OCCTCurve3DRef _Nullable OCCTHelixApproxToBSpline(double t1, double t2, double pitch, double rStart,
                                                     double taperAngle, bool isClockwise,
                                                     double tolerance, double* _Nonnull maxError) {
    try {
        Handle(Geom_BSplineCurve) bspl;
        double err = 0;
        int status = HelixGeom_Tools::ApprHelix(t1, t2, pitch, rStart, taperAngle, isClockwise, tolerance, bspl, err);
        if (status != 0 || bspl.IsNull()) return nullptr;
        *maxError = err;
        auto* ref = new OCCTCurve3D;
        ref->curve = bspl;
        return ref;
    } catch (...) { return nullptr; }
}

// gp_Ax3

// MARK: - v0.116: Curve3D Local Curvature/Tangent/Normal/CentreOfCurvature
double OCCTCurve3DLocalCurvature(OCCTCurve3DRef _Nonnull curve, double u) {
    try {
        GeomLProp_CLProps props(curve->curve, u, 2, 1e-10);
        return props.Curvature();
    } catch (...) { return 0.0; }
}

void OCCTCurve3DLocalTangent(OCCTCurve3DRef _Nonnull curve, double u,
                               double* _Nonnull tx, double* _Nonnull ty, double* _Nonnull tz,
                               bool* _Nonnull isDefined) {
    try {
        GeomLProp_CLProps props(curve->curve, u, 1, 1e-10);
        *isDefined = props.IsTangentDefined();
        if (*isDefined) {
            gp_Dir d;
            props.Tangent(d);
            *tx = d.X(); *ty = d.Y(); *tz = d.Z();
        } else {
            *tx = 0; *ty = 0; *tz = 0;
        }
    } catch (...) { *isDefined = false; *tx = 0; *ty = 0; *tz = 0; }
}

void OCCTCurve3DLocalNormal(OCCTCurve3DRef _Nonnull curve, double u,
                              double* _Nonnull nx, double* _Nonnull ny, double* _Nonnull nz,
                              bool* _Nonnull isDefined) {
    try {
        GeomLProp_CLProps props(curve->curve, u, 2, 1e-10);
        *isDefined = props.IsTangentDefined();
        if (*isDefined) {
            gp_Dir n;
            props.Normal(n);
            *nx = n.X(); *ny = n.Y(); *nz = n.Z();
        } else {
            *nx = 0; *ny = 0; *nz = 0;
        }
    } catch (...) { *isDefined = false; *nx = 0; *ny = 0; *nz = 0; }
}

void OCCTCurve3DLocalCentreOfCurvature(OCCTCurve3DRef _Nonnull curve, double u,
                                         double* _Nonnull cx, double* _Nonnull cy, double* _Nonnull cz,
                                         bool* _Nonnull isDefined) {
    try {
        GeomLProp_CLProps props(curve->curve, u, 2, 1e-10);
        double curv = props.Curvature();
        if (curv > 1e-10 && props.IsTangentDefined()) {
            gp_Pnt p;
            props.CentreOfCurvature(p);
            *cx = p.X(); *cy = p.Y(); *cz = p.Z();
            *isDefined = true;
        } else {
            *cx = 0; *cy = 0; *cz = 0;
            *isDefined = false;
        }
    } catch (...) { *isDefined = false; *cx = 0; *cy = 0; *cz = 0; }
}

// GeomLProp_SLProps (was LProp3d_SLProps in RC4)

#include <GeomLProp_SLProps.hxx>

// MARK: - v0.120: Curve3D continuity + Bezier Resolution + MaxDegree
// --- Curve3D continuity queries ---

bool OCCTCurve3DIsCN(OCCTCurve3DRef _Nonnull curve, int32_t n) {
    try {
        auto c = *(occ::handle<Geom_Curve>*)curve;
        if (c.IsNull()) return false;
        return c->IsCN(n);
    } catch (...) { return false; }
}

double OCCTCurve3DReversedParameter(OCCTCurve3DRef _Nonnull curve, double u) {
    try {
        auto c = *(occ::handle<Geom_Curve>*)curve;
        if (c.IsNull()) return u;
        return c->ReversedParameter(u);
    } catch (...) { return u; }
}

double OCCTCurve3DParametricTransformation(OCCTCurve3DRef _Nonnull curve,
                                            const double* _Nonnull trsf12) {
    try {
        auto c = *(occ::handle<Geom_Curve>*)curve;
        if (c.IsNull()) return 1.0;
        gp_Trsf t;
        t.SetValues(trsf12[0], trsf12[1], trsf12[2], trsf12[9],
                    trsf12[3], trsf12[4], trsf12[5], trsf12[10],
                    trsf12[6], trsf12[7], trsf12[8], trsf12[11]);
        return c->ParametricTransformation(t);
    } catch (...) { return 1.0; }
}
// --- Bezier curve/surface Resolution + MaxDegree ---

double OCCTCurve3DBezierResolution(OCCTCurve3DRef _Nonnull curve, double tolerance3d) {
    try {
        auto c = *(occ::handle<Geom_Curve>*)curve;
        if (c.IsNull()) return 0;
        auto bez = occ::handle<Geom_BezierCurve>::DownCast(c);
        if (bez.IsNull()) return 0;
        double uTol = 0;
        bez->Resolution(tolerance3d, uTol);
        return uTol;
    } catch (...) { return 0; }
}

int32_t OCCTCurve3DBezierMaxDegree(void) {
    return Geom_BezierCurve::MaxDegree();
}

// MARK: - v0.121: BSplineCurve 3D completions
// --- BSplineCurve 3D completions ---

bool OCCTCurve3DBSplineSetNotPeriodic(OCCTCurve3DRef curve) {
    if (!curve || curve->curve.IsNull()) return false;
    Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
    if (bs.IsNull()) return false;
    try { bs->SetNotPeriodic(); return true; } catch (...) { return false; }
}

bool OCCTCurve3DBSplineSetOrigin(OCCTCurve3DRef curve, int32_t index) {
    if (!curve || curve->curve.IsNull()) return false;
    Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
    if (bs.IsNull()) return false;
    try { bs->SetOrigin(index); return true; } catch (...) { return false; }
}

bool OCCTCurve3DBSplineIncreaseMultiplicity(OCCTCurve3DRef curve, int32_t index, int32_t mult) {
    if (!curve || curve->curve.IsNull()) return false;
    Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
    if (bs.IsNull()) return false;
    try { bs->IncreaseMultiplicity(index, mult); return true; } catch (...) { return false; }
}

bool OCCTCurve3DBSplineIncrementMultiplicity(OCCTCurve3DRef curve, int32_t index1, int32_t index2, int32_t step) {
    if (!curve || curve->curve.IsNull()) return false;
    Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
    if (bs.IsNull()) return false;
    try { bs->IncrementMultiplicity(index1, index2, step); return true; } catch (...) { return false; }
}

bool OCCTCurve3DBSplineSetKnots(OCCTCurve3DRef curve, const double* knots, int32_t count) {
    if (!curve || curve->curve.IsNull() || !knots || count <= 0) return false;
    Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
    if (bs.IsNull() || count != bs->NbKnots()) return false;
    try {
        TColStd_Array1OfReal kArr(1, count);
        for (int32_t i = 0; i < count; i++) {
            kArr.SetValue(i + 1, knots[i]);
        }
        bs->SetKnots(kArr);
        return true;
    } catch (...) { return false; }
}

bool OCCTCurve3DBSplineReverse(OCCTCurve3DRef curve) {
    if (!curve || curve->curve.IsNull()) return false;
    Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
    if (bs.IsNull()) return false;
    try { bs->Reverse(); return true; } catch (...) { return false; }
}

bool OCCTCurve3DBSplineMovePointAndTangent(OCCTCurve3DRef curve, double u,
                                            double px, double py, double pz,
                                            double tx, double ty, double tz,
                                            double tolerance,
                                            int32_t startIndex, int32_t endIndex) {
    if (!curve || curve->curve.IsNull()) return false;
    Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
    if (bs.IsNull()) return false;
    try {
        Standard_Integer errorStatus = 0;
        bs->MovePointAndTangent(u, gp_Pnt(px, py, pz), gp_Vec(tx, ty, tz),
                                tolerance, startIndex, endIndex, errorStatus);
        return (errorStatus == 0);
    } catch (...) { return false; }
}

// MARK: - v0.122: Curve3D queries + v0.125: Geom_BezierCurve completions
// --- Curve3D queries ---

double OCCTCurve3DPeriod(OCCTCurve3DRef curve) {
    if (!curve) return 0.0;
    try {
        if (!curve->curve->IsPeriodic()) return 0.0;
        return curve->curve->Period();
    } catch (...) { return 0.0; }
}

double OCCTCurve3DFirstParameter(OCCTCurve3DRef curve) {
    if (!curve) return 0.0;
    try { return curve->curve->FirstParameter(); } catch (...) { return 0.0; }
}

double OCCTCurve3DLastParameter(OCCTCurve3DRef curve) {
    if (!curve) return 0.0;
    try { return curve->curve->LastParameter(); } catch (...) { return 0.0; }
}
// --- Geom_BezierCurve completions ---

void OCCTCurve3DBezierStartPoint(OCCTCurve3DRef curve, double* x, double* y, double* z) {
    if (!curve) return;
    auto bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
    if (bz.IsNull()) return;
    try {
        gp_Pnt P = bz->StartPoint();
        *x = P.X(); *y = P.Y(); *z = P.Z();
    } catch (...) {}
}

void OCCTCurve3DBezierEndPoint(OCCTCurve3DRef curve, double* x, double* y, double* z) {
    if (!curve) return;
    auto bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
    if (bz.IsNull()) return;
    try {
        gp_Pnt P = bz->EndPoint();
        *x = P.X(); *y = P.Y(); *z = P.Z();
    } catch (...) {}
}

void OCCTCurve3DBezierGetPoles(OCCTCurve3DRef curve, double* poles) {
    if (!curve || !poles) return;
    auto bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
    if (bz.IsNull()) return;
    try {
        const auto& p = bz->Poles();
        int idx = 0;
        for (int i = p.Lower(); i <= p.Upper(); i++) {
            poles[idx++] = p(i).X();
            poles[idx++] = p(i).Y();
            poles[idx++] = p(i).Z();
        }
    } catch (...) {}
}

bool OCCTCurve3DBezierGetWeights(OCCTCurve3DRef curve, double* weights) {
    if (!curve || !weights) return false;
    auto bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
    if (bz.IsNull()) return false;
    try {
        const auto* w = bz->Weights();
        if (!w) return false;
        for (int i = w->Lower(); i <= w->Upper(); i++) {
            weights[i - w->Lower()] = (*w)(i);
        }
        return true;
    } catch (...) { return false; }
}

bool OCCTCurve3DBezierIsClosed(OCCTCurve3DRef curve) {
    if (!curve) return false;
    auto bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
    if (bz.IsNull()) return false;
    try { return bz->IsClosed(); } catch (...) { return false; }
}

bool OCCTCurve3DBezierIsPeriodic(OCCTCurve3DRef curve) {
    if (!curve) return false;
    auto bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
    if (bz.IsNull()) return false;
    try { return bz->IsPeriodic(); } catch (...) { return false; }
}

int32_t OCCTCurve3DBezierContinuity(OCCTCurve3DRef curve) {
    if (!curve) return 0;
    auto bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
    if (bz.IsNull()) return 0;
    try { return (int32_t)bz->Continuity(); } catch (...) { return 0; }
}

bool OCCTCurve3DBezierIsCN(OCCTCurve3DRef curve, int32_t n) {
    if (!curve) return false;
    auto bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
    if (bz.IsNull()) return false;
    try { return bz->IsCN(n); } catch (...) { return false; }
}

// MARK: - v0.126: Bezier 3D + Curve3D Transform + v0.127: Geom_BSplineCurve + v0.129: BSplineCurve3D Local + v0.130: GeomEval Helix/Sine/ExtremaPC + v0.131: Approx_BSplineApproxInterp + GeomAdaptor_TransformedCurve + GeomEval_TBezier/AHTBezierCurve
// --- Bezier 3D curve InsertPoleBefore and Reverse ---

bool OCCTCurve3DBezierInsertPoleBefore(OCCTCurve3DRef curve, int32_t index,
                                        double x, double y, double z) {
    if (!curve) return false;
    auto bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
    if (bz.IsNull()) return false;
    try {
        bz->InsertPoleBefore(index, gp_Pnt(x, y, z));
        return true;
    } catch (...) { return false; }
}

bool OCCTCurve3DBezierReverse(OCCTCurve3DRef curve) {
    if (!curve) return false;
    auto bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
    if (bz.IsNull()) return false;
    try {
        bz->Reverse();
        return true;
    } catch (...) { return false; }
}

bool OCCTCurve3DBezierSetPoleWithWeight(OCCTCurve3DRef curve, int32_t index,
                                         double x, double y, double z, double weight) {
    if (!curve) return false;
    auto bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
    if (bz.IsNull()) return false;
    try {
        bz->SetPole(index, gp_Pnt(x, y, z), weight);
        return true;
    } catch (...) { return false; }
}
// --- Geometry Transform (in-place) ---

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

bool OCCTCurve3DTransform(OCCTCurve3DRef curve, int32_t transformType,
                           double p1, double p2, double p3,
                           double p4, double p5, double p6, double p7) {
    if (!curve) return false;
    try {
        gp_Trsf trsf;
        if (!buildTrsf3D(trsf, transformType, p1, p2, p3, p4, p5, p6, p7)) return false;
        curve->curve->Transform(trsf);
        return true;
    } catch (...) { return false; }
}
// --- Geom_BSplineCurve completions ---

bool OCCTCurve3DBSplinePeriodicNormalization(OCCTCurve3DRef curve, double* u) {
    if (!curve || !u) return false;
    auto bsc = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
    if (bsc.IsNull() || !bsc->IsPeriodic()) return false;
    try {
        bsc->PeriodicNormalization(*u);
        return true;
    } catch (...) { return false; }
}

bool OCCTCurve3DBSplineIsG1(OCCTCurve3DRef curve, double tFirst, double tLast, double angTol) {
    if (!curve) return false;
    auto bsc = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
    if (bsc.IsNull()) return false;
    try {
        return bsc->IsG1(tFirst, tLast, angTol);
    } catch (...) { return false; }
}
// --- v0.129.0: BSplineCurve3D LocalD0-D3/DN, BSplineSurface completions, BezierSurface completions ---

void OCCTCurve3DBSplineLocalD0(OCCTCurve3DRef curve, double u,
                                int32_t fromK1, int32_t toK2,
                                double* px, double* py, double* pz) {
    if (!curve || curve->curve.IsNull()) { *px = *py = *pz = 0; return; }
    try {
        auto bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
        if (bs.IsNull()) { *px = *py = *pz = 0; return; }
        gp_Pnt p;
        bs->LocalD0(u, fromK1, toK2, p);
        *px = p.X(); *py = p.Y(); *pz = p.Z();
    } catch (...) { *px = *py = *pz = 0; }
}

void OCCTCurve3DBSplineLocalD1(OCCTCurve3DRef curve, double u,
                                int32_t fromK1, int32_t toK2,
                                double* px, double* py, double* pz,
                                double* vx, double* vy, double* vz) {
    if (!curve || curve->curve.IsNull()) { *px = *py = *pz = *vx = *vy = *vz = 0; return; }
    try {
        auto bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
        if (bs.IsNull()) { *px = *py = *pz = *vx = *vy = *vz = 0; return; }
        gp_Pnt p; gp_Vec v1;
        bs->LocalD1(u, fromK1, toK2, p, v1);
        *px = p.X(); *py = p.Y(); *pz = p.Z();
        *vx = v1.X(); *vy = v1.Y(); *vz = v1.Z();
    } catch (...) { *px = *py = *pz = *vx = *vy = *vz = 0; }
}

void OCCTCurve3DBSplineLocalD2(OCCTCurve3DRef curve, double u,
                                int32_t fromK1, int32_t toK2,
                                double* px, double* py, double* pz,
                                double* v1x, double* v1y, double* v1z,
                                double* v2x, double* v2y, double* v2z) {
    if (!curve || curve->curve.IsNull()) {
        *px = *py = *pz = *v1x = *v1y = *v1z = *v2x = *v2y = *v2z = 0; return;
    }
    try {
        auto bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
        if (bs.IsNull()) { *px = *py = *pz = *v1x = *v1y = *v1z = *v2x = *v2y = *v2z = 0; return; }
        gp_Pnt p; gp_Vec v1, v2;
        bs->LocalD2(u, fromK1, toK2, p, v1, v2);
        *px = p.X(); *py = p.Y(); *pz = p.Z();
        *v1x = v1.X(); *v1y = v1.Y(); *v1z = v1.Z();
        *v2x = v2.X(); *v2y = v2.Y(); *v2z = v2.Z();
    } catch (...) { *px = *py = *pz = *v1x = *v1y = *v1z = *v2x = *v2y = *v2z = 0; }
}

void OCCTCurve3DBSplineLocalD3(OCCTCurve3DRef curve, double u,
                                int32_t fromK1, int32_t toK2,
                                double* px, double* py, double* pz,
                                double* v1x, double* v1y, double* v1z,
                                double* v2x, double* v2y, double* v2z,
                                double* v3x, double* v3y, double* v3z) {
    if (!curve || curve->curve.IsNull()) {
        *px = *py = *pz = *v1x = *v1y = *v1z = *v2x = *v2y = *v2z = *v3x = *v3y = *v3z = 0; return;
    }
    try {
        auto bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
        if (bs.IsNull()) {
            *px = *py = *pz = *v1x = *v1y = *v1z = *v2x = *v2y = *v2z = *v3x = *v3y = *v3z = 0; return;
        }
        gp_Pnt p; gp_Vec v1, v2, v3;
        bs->LocalD3(u, fromK1, toK2, p, v1, v2, v3);
        *px = p.X(); *py = p.Y(); *pz = p.Z();
        *v1x = v1.X(); *v1y = v1.Y(); *v1z = v1.Z();
        *v2x = v2.X(); *v2y = v2.Y(); *v2z = v2.Z();
        *v3x = v3.X(); *v3y = v3.Y(); *v3z = v3.Z();
    } catch (...) {
        *px = *py = *pz = *v1x = *v1y = *v1z = *v2x = *v2y = *v2z = *v3x = *v3y = *v3z = 0;
    }
}

void OCCTCurve3DBSplineLocalDN(OCCTCurve3DRef curve, double u,
                                int32_t fromK1, int32_t toK2, int32_t n,
                                double* vx, double* vy, double* vz) {
    if (!curve || curve->curve.IsNull()) { *vx = *vy = *vz = 0; return; }
    try {
        auto bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
        if (bs.IsNull()) { *vx = *vy = *vz = 0; return; }
        gp_Vec v = bs->LocalDN(u, fromK1, toK2, n);
        *vx = v.X(); *vy = v.Y(); *vz = v.Z();
    } catch (...) { *vx = *vy = *vz = 0; }
}

// BSplineSurface completions
// --- GeomEval Circular Helix ---

void OCCTGeomEvalCircularHelixD0(double radius, double pitch, double u,
                                  double* px, double* py, double* pz) {
    gp_Ax2 ax(gp_Pnt(0,0,0), gp_Dir(0,0,1));
    GeomEval_CircularHelixCurve helix(ax, radius, pitch);
    gp_Pnt p = helix.EvalD0(u);
    *px = p.X(); *py = p.Y(); *pz = p.Z();
}

void OCCTGeomEvalCircularHelixD1(double radius, double pitch, double u,
                                  double* px, double* py, double* pz,
                                  double* vx, double* vy, double* vz) {
    gp_Ax2 ax(gp_Pnt(0,0,0), gp_Dir(0,0,1));
    GeomEval_CircularHelixCurve helix(ax, radius, pitch);
    auto res = helix.EvalD1(u);
    *px = res.Point.X(); *py = res.Point.Y(); *pz = res.Point.Z();
    *vx = res.D1.X(); *vy = res.D1.Y(); *vz = res.D1.Z();
}

void OCCTGeomEvalCircularHelixD2(double radius, double pitch, double u,
                                  double* px, double* py, double* pz,
                                  double* d1x, double* d1y, double* d1z,
                                  double* d2x, double* d2y, double* d2z) {
    gp_Ax2 ax(gp_Pnt(0,0,0), gp_Dir(0,0,1));
    GeomEval_CircularHelixCurve helix(ax, radius, pitch);
    auto res = helix.EvalD2(u);
    *px = res.Point.X(); *py = res.Point.Y(); *pz = res.Point.Z();
    *d1x = res.D1.X(); *d1y = res.D1.Y(); *d1z = res.D1.Z();
    *d2x = res.D2.X(); *d2y = res.D2.Y(); *d2z = res.D2.Z();
}

OCCTCurve3DRef OCCTGeomEvalCircularHelixCurveCreate(double radius, double pitch) {
    try {
        gp_Ax2 ax(gp_Pnt(0,0,0), gp_Dir(0,0,1));
        auto helix = new GeomEval_CircularHelixCurve(ax, radius, pitch);
        occ::handle<Geom_Curve> hCurve(helix);
        auto ref = new OCCTCurve3D();
        ref->curve = hCurve;
        return ref;
    } catch (...) { return nullptr; }
}

// --- GeomEval Sine Wave 3D ---

void OCCTGeomEvalSineWaveD0(double amplitude, double omega, double phase, double u,
                             double* px, double* py, double* pz) {
    gp_Ax2 ax(gp_Pnt(0,0,0), gp_Dir(0,0,1));
    GeomEval_SineWaveCurve sw(ax, amplitude, omega, phase);
    gp_Pnt p = sw.EvalD0(u);
    *px = p.X(); *py = p.Y(); *pz = p.Z();
}

void OCCTGeomEvalSineWaveD1(double amplitude, double omega, double phase, double u,
                             double* px, double* py, double* pz,
                             double* vx, double* vy, double* vz) {
    gp_Ax2 ax(gp_Pnt(0,0,0), gp_Dir(0,0,1));
    GeomEval_SineWaveCurve sw(ax, amplitude, omega, phase);
    auto res = sw.EvalD1(u);
    *px = res.Point.X(); *py = res.Point.Y(); *pz = res.Point.Z();
    *vx = res.D1.X(); *vy = res.D1.Y(); *vz = res.D1.Z();
}

OCCTCurve3DRef OCCTGeomEvalSineWaveCurveCreate(double amplitude, double omega, double phase) {
    try {
        gp_Ax2 ax(gp_Pnt(0,0,0), gp_Dir(0,0,1));
        auto sw = new GeomEval_SineWaveCurve(ax, amplitude, omega, phase);
        occ::handle<Geom_Curve> hCurve(sw);
        auto ref = new OCCTCurve3D();
        ref->curve = hCurve;
        return ref;
    } catch (...) { return nullptr; }
}
// --- ExtremaPC ---

int32_t OCCTExtremaPCCurve(OCCTCurve3DRef curve,
                            double px, double py, double pz,
                            double* outParams, double* outDistances,
                            double* outPx, double* outPy, double* outPz,
                            int32_t maxResults) {
    if (!curve || !outParams || !outDistances || maxResults <= 0) return 0;
    try {
        ExtremaPC_Curve extPC(curve->curve);
        if (!extPC.IsInitialized()) return 0;
        const auto& result = extPC.Perform(gp_Pnt(px, py, pz), 1e-9);
        if (!result.IsDone()) return 0;
        int n = std::min((int)result.NbExt(), (int)maxResults);
        for (int i = 0; i < n; i++) {
            outParams[i] = result[i].Parameter;
            outDistances[i] = std::sqrt(result[i].SquareDistance);
            if (outPx) outPx[i] = result[i].Point.X();
            if (outPy) outPy[i] = result[i].Point.Y();
            if (outPz) outPz[i] = result[i].Point.Z();
        }
        return n;
    } catch (...) { return 0; }
}

int32_t OCCTExtremaPCCurveBounded(OCCTCurve3DRef curve,
                                   double px, double py, double pz,
                                   double uMin, double uMax,
                                   double* outParams, double* outDistances,
                                   double* outPx, double* outPy, double* outPz,
                                   int32_t maxResults) {
    if (!curve || !outParams || !outDistances || maxResults <= 0) return 0;
    try {
        ExtremaPC_Curve extPC(curve->curve, uMin, uMax);
        if (!extPC.IsInitialized()) return 0;
        const auto& result = extPC.Perform(gp_Pnt(px, py, pz), 1e-9);
        if (!result.IsDone()) return 0;
        int n = std::min((int)result.NbExt(), (int)maxResults);
        for (int i = 0; i < n; i++) {
            outParams[i] = result[i].Parameter;
            outDistances[i] = std::sqrt(result[i].SquareDistance);
            if (outPx) outPx[i] = result[i].Point.X();
            if (outPy) outPy[i] = result[i].Point.Y();
            if (outPz) outPz[i] = result[i].Point.Z();
        }
        return n;
    } catch (...) { return 0; }
}

double OCCTExtremaPCMinDistance(OCCTCurve3DRef curve,
                                double px, double py, double pz) {
    if (!curve) return -1.0;
    try {
        ExtremaPC_Curve extPC(curve->curve);
        if (!extPC.IsInitialized()) return -1.0;
        const auto& result = extPC.Perform(gp_Pnt(px, py, pz), 1e-9);
        if (!result.IsDone() || result.NbExt() == 0) return -1.0;
        return std::sqrt(result.MinSquareDistance());
    } catch (...) { return -1.0; }
}

// --- Approx_BSplineApproxInterp (reimplemented on GeomAPI_PointsToBSpline) ---
//
// OCCT 8.0.0p1 removed Approx_BSplineApproxInterp. The C ABI here is preserved, but the
// fit is now produced by GeomAPI_PointsToBSpline (least-squares B-spline approximation),
// the migration target named in the p1 release notes. Semantic differences vs the old
// solver, kept so callers compile & run unchanged:
//   * nbControlPoints is ADVISORY — PointsToBSpline picks the pole count needed to meet
//     the tolerance within [DegMin, DegMax]; it is no longer an exact constraint.
//   * InterpolatePoint()/kink markers are no-ops (PointsToBSpline has no per-point exact
//     interpolation or C0-break control). The approximation still passes near the points.
//   * MaxError() is computed by projecting the input points back onto the fitted curve.
//   * The Gauss-solver / parametrization / closed-curve tuning setters are no-ops; the
//     convergence and projection tolerance setters drive the 3D fit tolerance.
struct OCCTBSplineApproxInterp {
    NCollection_Array1<gp_Pnt> pts;
    int degMin = 3;
    int degMax = 8;
    double tol3D = 1.0e-3;
    occ::handle<Geom_BSplineCurve> result;
    bool done = false;
    double maxErr = -1.0;
    explicit OCCTBSplineApproxInterp(int count) : pts(1, count) {}

    void run() {
        try {
            GeomAPI_PointsToBSpline fit(pts, degMin, degMax, GeomAbs_C2, tol3D);
            result = fit.Curve();
            done = !result.IsNull();
            maxErr = -1.0;
            if (done) {
                double mx = 0.0;
                for (NCollection_Array1<gp_Pnt>::Iterator it(pts); it.More(); it.Next()) {
                    GeomAPI_ProjectPointOnCurve proj(it.Value(), result);
                    if (proj.NbPoints() > 0) mx = std::max(mx, proj.LowerDistance());
                }
                maxErr = mx;
            }
        } catch (...) { done = false; result.Nullify(); maxErr = -1.0; }
    }
};

OCCTBSplineApproxInterpRef OCCTBSplineApproxInterpCreate(
    const double* points, int32_t count,
    int32_t nbControlPts, int32_t degree, bool continuousIfClosed) {
    if (!points || count < 2) return nullptr;
    (void)nbControlPts; (void)continuousIfClosed;   // advisory only — see section comment
    try {
        auto ref = new OCCTBSplineApproxInterp(count);
        for (int i = 0; i < count; i++)
            ref->pts(i + 1) = gp_Pnt(points[i*3], points[i*3+1], points[i*3+2]);
        if (degree >= 1 && degree <= 25) { ref->degMin = std::min(3, degree); ref->degMax = std::max(degree, 8); }
        return ref;
    } catch (...) { return nullptr; }
}

void OCCTBSplineApproxInterpRelease(OCCTBSplineApproxInterpRef ref) {
    delete ref;
}

void OCCTBSplineApproxInterpInterpolatePoint(OCCTBSplineApproxInterpRef ref,
                                              int32_t pointIndex, bool withKink) {
    (void)ref; (void)pointIndex; (void)withKink;    // no-op — PointsToBSpline has no exact-point control
}

void OCCTBSplineApproxInterpPerform(OCCTBSplineApproxInterpRef ref) {
    if (ref) ref->run();
}

void OCCTBSplineApproxInterpPerformOptimal(OCCTBSplineApproxInterpRef ref,
                                            int32_t maxIter) {
    (void)maxIter;
    if (ref) ref->run();
}

bool OCCTBSplineApproxInterpIsDone(OCCTBSplineApproxInterpRef ref) {
    return ref && ref->done;
}

OCCTCurve3DRef OCCTBSplineApproxInterpCurve(OCCTBSplineApproxInterpRef ref) {
    if (!ref || !ref->done || ref->result.IsNull()) return nullptr;
    try {
        auto cref = new OCCTCurve3D();
        cref->curve = ref->result;
        return cref;
    } catch (...) { return nullptr; }
}

double OCCTBSplineApproxInterpMaxError(OCCTBSplineApproxInterpRef ref) {
    return ref ? ref->maxErr : -1.0;
}

void OCCTBSplineApproxInterpSetAlpha(OCCTBSplineApproxInterpRef, double) {}   // no-op
void OCCTBSplineApproxInterpSetMinPivot(OCCTBSplineApproxInterpRef, double) {}   // no-op
void OCCTBSplineApproxInterpSetClosedTol(OCCTBSplineApproxInterpRef, double) {}   // no-op
void OCCTBSplineApproxInterpSetKnotTol(OCCTBSplineApproxInterpRef, double) {}   // no-op

void OCCTBSplineApproxInterpSetConvergenceTol(OCCTBSplineApproxInterpRef ref, double val) {
    if (ref && val > 0) ref->tol3D = val;   // drives the 3D fit tolerance
}

void OCCTBSplineApproxInterpSetProjectionTol(OCCTBSplineApproxInterpRef ref, double val) {
    if (ref && val > 0) ref->tol3D = std::min(ref->tol3D, val);
}

// --- GeomAdaptor_TransformedCurve ---

OCCTCurve3DRef OCCTGeomAdaptorTransformedCurveCreate(
    OCCTCurve3DRef curve,
    double tx, double ty, double tz) {
    if (!curve || curve->curve.IsNull()) return nullptr;
    try {
        gp_Trsf trsf;
        trsf.SetTranslation(gp_Vec(tx, ty, tz));
        // Create a trimmed copy of the original curve with the transform applied
        Handle(Geom_Curve) origCurve = curve->curve;
        Handle(Geom_Curve) copyCurve = Handle(Geom_Curve)::DownCast(origCurve->Copy());
        if (copyCurve.IsNull()) return nullptr;
        copyCurve->Transform(trsf);
        auto ref = new OCCTCurve3D();
        ref->curve = copyCurve;
        return ref;
    } catch (...) { return nullptr; }
}
// --- GeomEval_TBezierCurve ---

OCCTCurve3DRef OCCTGeomEvalTBezierCurveCreate(
    const double* poles, int32_t count, double alpha) {
    if (!poles || count < 3 || count % 2 == 0) return nullptr;
    try {
        NCollection_Array1<gp_Pnt> pts(1, count);
        for (int i = 0; i < count; i++)
            pts(i + 1) = gp_Pnt(poles[i*3], poles[i*3+1], poles[i*3+2]);
        auto tc = new GeomEval_TBezierCurve(pts, alpha);
        occ::handle<Geom_Curve> hCurve(tc);
        auto ref = new OCCTCurve3D();
        ref->curve = hCurve;
        return ref;
    } catch (...) { return nullptr; }
}

OCCTCurve3DRef OCCTGeomEvalTBezierCurveCreateRational(
    const double* poles, const double* weights,
    int32_t count, double alpha) {
    if (!poles || !weights || count < 3 || count % 2 == 0) return nullptr;
    try {
        NCollection_Array1<gp_Pnt> pts(1, count);
        NCollection_Array1<double> wts(1, count);
        for (int i = 0; i < count; i++) {
            pts(i + 1) = gp_Pnt(poles[i*3], poles[i*3+1], poles[i*3+2]);
            wts(i + 1) = weights[i];
        }
        auto tc = new GeomEval_TBezierCurve(pts, wts, alpha);
        occ::handle<Geom_Curve> hCurve(tc);
        auto ref = new OCCTCurve3D();
        ref->curve = hCurve;
        return ref;
    } catch (...) { return nullptr; }
}

// --- GeomEval_AHTBezierCurve ---

OCCTCurve3DRef OCCTGeomEvalAHTBezierCurveCreate(
    const double* poles, int32_t count,
    int32_t algDegree, double alpha, double beta) {
    if (!poles || count < 1) return nullptr;
    try {
        NCollection_Array1<gp_Pnt> pts(1, count);
        for (int i = 0; i < count; i++)
            pts(i + 1) = gp_Pnt(poles[i*3], poles[i*3+1], poles[i*3+2]);
        auto ac = new GeomEval_AHTBezierCurve(pts, algDegree, alpha, beta);
        occ::handle<Geom_Curve> hCurve(ac);
        auto ref = new OCCTCurve3D();
        ref->curve = hCurve;
        return ref;
    } catch (...) { return nullptr; }
}

OCCTCurve3DRef OCCTGeomEvalAHTBezierCurveCreateRational(
    const double* poles, const double* weights,
    int32_t count, int32_t algDegree, double alpha, double beta) {
    if (!poles || !weights || count < 1) return nullptr;
    try {
        NCollection_Array1<gp_Pnt> pts(1, count);
        NCollection_Array1<double> wts(1, count);
        for (int i = 0; i < count; i++) {
            pts(i + 1) = gp_Pnt(poles[i*3], poles[i*3+1], poles[i*3+2]);
            wts(i + 1) = weights[i];
        }
        auto ac = new GeomEval_AHTBezierCurve(pts, wts, algDegree, alpha, beta);
        occ::handle<Geom_Curve> hCurve(ac);
        auto ref = new OCCTCurve3D();
        ref->curve = hCurve;
        return ref;
    } catch (...) { return nullptr; }
}

// MARK: - CompCurve adaptor (#211): a multi-edge wire as one arc-length-parameterized curve
#include <BRepAdaptor_CompCurve.hxx>
#include <GCPnts_AbscissaPoint.hxx>

// Opaque handle: holds the adaptor by value (BRepAdaptor_CompCurve(const TopoDS_Wire&)).
struct OCCTCompCurve {
    BRepAdaptor_CompCurve adaptor;
    explicit OCCTCompCurve(const TopoDS_Wire& w) : adaptor(w) {}
};

OCCTCompCurveRef OCCTCompCurveCreate(OCCTWireRef wire) {
    if (!wire) return nullptr;
    try { return new OCCTCompCurve(wire->wire); }
    catch (...) { return nullptr; }
}

void OCCTCompCurveRelease(OCCTCompCurveRef ref) { delete ref; }

double OCCTCompCurveLength(OCCTCompCurveRef ref) {
    if (!ref) return -1.0;
    try { return GCPnts_AbscissaPoint::Length(ref->adaptor); }
    catch (...) { return -1.0; }
}

void OCCTCompCurveParamRange(OCCTCompCurveRef ref, double* first, double* last) {
    if (!ref) return;
    try {
        if (first) *first = ref->adaptor.FirstParameter();
        if (last)  *last  = ref->adaptor.LastParameter();
    } catch (...) {}
}

bool OCCTCompCurvePointAtParam(OCCTCompCurveRef ref, double u, double* x, double* y, double* z) {
    if (!ref) return false;
    try {
        gp_Pnt p = ref->adaptor.Value(u);
        if (x) *x = p.X(); if (y) *y = p.Y(); if (z) *z = p.Z();
        return true;
    } catch (...) { return false; }
}

bool OCCTCompCurveTangentAtParam(OCCTCompCurveRef ref, double u, double* x, double* y, double* z) {
    if (!ref) return false;
    try {
        gp_Pnt p; gp_Vec d1;
        ref->adaptor.D1(u, p, d1);
        if (d1.Magnitude() < 1e-12) return false;   // degenerate (e.g. cusp)
        gp_Dir dir(d1);
        if (x) *x = dir.X(); if (y) *y = dir.Y(); if (z) *z = dir.Z();
        return true;
    } catch (...) { return false; }
}

bool OCCTCompCurveParamAtAbscissa(OCCTCompCurveRef ref, double s, double* outParam) {
    if (!ref) return false;
    try {
        GCPnts_AbscissaPoint ap(ref->adaptor, s, ref->adaptor.FirstParameter());
        if (!ap.IsDone()) return false;
        if (outParam) *outParam = ap.Parameter();
        return true;
    } catch (...) { return false; }
}

// Shared: N points spaced equally by arc length along any 3D curve adaptor.
// outXYZ must hold count*3 doubles; returns the number of points actually written.
#include <Adaptor3d_Curve.hxx>
#include <GCPnts_UniformAbscissa.hxx>
static int32_t sampleAdaptorUniform(Adaptor3d_Curve& a, int32_t count, double* outXYZ) {
    if (count < 2 || !outXYZ) return 0;
    GCPnts_UniformAbscissa sampler(a, count);
    if (!sampler.IsDone()) return 0;
    int32_t n = sampler.NbPoints();
    for (int32_t i = 1; i <= n; ++i) {
        gp_Pnt p = a.Value(sampler.Parameter(i));
        outXYZ[(i - 1) * 3 + 0] = p.X();
        outXYZ[(i - 1) * 3 + 1] = p.Y();
        outXYZ[(i - 1) * 3 + 2] = p.Z();
    }
    return n;
}

int32_t OCCTCompCurveSampleUniform(OCCTCompCurveRef ref, int32_t count, double* outXYZ) {
    if (!ref) return 0;
    try { return sampleAdaptorUniform(ref->adaptor, count, outXYZ); }
    catch (...) { return 0; }
}

// MARK: - EdgeCurve adaptor (#211/#212): a single edge as an arc-length curve (BRepAdaptor_Curve)
#include <BRepAdaptor_Curve.hxx>

struct OCCTEdgeCurve {
    BRepAdaptor_Curve adaptor;
    explicit OCCTEdgeCurve(const TopoDS_Edge& e) : adaptor(e) {}
};

OCCTEdgeCurveRef OCCTEdgeCurveCreate(OCCTEdgeRef edge) {
    if (!edge) return nullptr;
    try { return new OCCTEdgeCurve(edge->edge); }
    catch (...) { return nullptr; }
}

void OCCTEdgeCurveRelease(OCCTEdgeCurveRef ref) { delete ref; }

double OCCTEdgeCurveLength(OCCTEdgeCurveRef ref) {
    if (!ref) return -1.0;
    try { return GCPnts_AbscissaPoint::Length(ref->adaptor); }
    catch (...) { return -1.0; }
}

void OCCTEdgeCurveParamRange(OCCTEdgeCurveRef ref, double* first, double* last) {
    if (!ref) return;
    try {
        if (first) *first = ref->adaptor.FirstParameter();
        if (last)  *last  = ref->adaptor.LastParameter();
    } catch (...) {}
}

bool OCCTEdgeCurvePointAtParam(OCCTEdgeCurveRef ref, double u, double* x, double* y, double* z) {
    if (!ref) return false;
    try {
        gp_Pnt p = ref->adaptor.Value(u);
        if (x) *x = p.X(); if (y) *y = p.Y(); if (z) *z = p.Z();
        return true;
    } catch (...) { return false; }
}

bool OCCTEdgeCurveTangentAtParam(OCCTEdgeCurveRef ref, double u, double* x, double* y, double* z) {
    if (!ref) return false;
    try {
        gp_Pnt p; gp_Vec d1;
        ref->adaptor.D1(u, p, d1);
        if (d1.Magnitude() < 1e-12) return false;
        gp_Dir dir(d1);
        if (x) *x = dir.X(); if (y) *y = dir.Y(); if (z) *z = dir.Z();
        return true;
    } catch (...) { return false; }
}

bool OCCTEdgeCurveParamAtAbscissa(OCCTEdgeCurveRef ref, double s, double* outParam) {
    if (!ref) return false;
    try {
        GCPnts_AbscissaPoint ap(ref->adaptor, s, ref->adaptor.FirstParameter());
        if (!ap.IsDone()) return false;
        if (outParam) *outParam = ap.Parameter();
        return true;
    } catch (...) { return false; }
}

int32_t OCCTEdgeCurveSampleUniform(OCCTEdgeCurveRef ref, int32_t count, double* outXYZ) {
    if (!ref) return 0;
    try { return sampleAdaptorUniform(ref->adaptor, count, outXYZ); }
    catch (...) { return 0; }
}
