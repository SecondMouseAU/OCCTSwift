// Push harder: can the bridge's OWN DEFAULT tolerance (1e-4) be exceeded by a genuinely-difficult
// but not-absurd boundary (a saddle with larger amplitude / higher curvature), still with
// MaxSegments capped at the bridge's default of 9?
//
// Answer, once wavyEdge() actually interpolates its sample points instead of using them as a
// single-span Bezier's control poles (see the PR #751 discussion for #597): yes, dramatically.
// G0Error exceeds even the loosest tested tolerance (the bridge's own 1e-4 default) by ~2000x,
// and the accepted surface's poles land ~500 units from the ~10-unit-scale boundary. IsDone()
// is true, and G0Error() understates how far the fit actually diverges.
#include <BRepOffsetAPI_MakeFilling.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBndLib.hxx>
#include <BRep_Tool.hxx>
#include <Bnd_Box.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_Surface.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Shape.hxx>
#include <gp_Pnt.hxx>
#include <cstdio>
#include <cmath>
#include <vector>

// A wavy BSpline edge with several oscillations, harder for a degree<=8, <=9-segment fit.
// GeomAPI_Interpolate builds a curve that actually passes through the sine-sampled points
// (unlike the single-span, full-multiplicity Bezier this used to build from the same points as
// control poles, which damps a high-frequency control polygon severely: 62.8% of amplitude
// gone on this function's own parameters, measured in the PR discussion for #751). This matches
// the repo's own naming precedent: OCCTCurve3DInterpolate (OCCTBridge_Curve3D.mm) is built on
// GeomAPI_Interpolate for "pass through these points"; GeomAPI_PointsToBSpline is this repo's
// "FitPoints" (approximate, not interpolate) and is the wrong tool here.
static TopoDS_Edge wavyEdge(gp_Pnt start, gp_Pnt end, gp_Vec perp, double amp, int waves, int npts) {
    Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, npts);
    for (int i = 0; i < npts; i++) {
        double t = double(i) / (npts - 1);
        gp_Pnt base(start.X() + t * (end.X() - start.X()),
                    start.Y() + t * (end.Y() - start.Y()),
                    start.Z() + t * (end.Z() - start.Z()));
        double s = amp * std::sin(t * waves * 2 * M_PI);
        pts->SetValue(i + 1, gp_Pnt(base.X() + s * perp.X(), base.Y() + s * perp.Y(), base.Z() + s * perp.Z()));
    }
    GeomAPI_Interpolate interp(pts, Standard_False, 1e-7);
    interp.Perform();
    if (!interp.IsDone()) {
        printf("wavyEdge: GeomAPI_Interpolate FAILED\n");
    }
    Handle(Geom_BSplineCurve) curve = interp.Curve();
    return BRepBuilderAPI_MakeEdge(curve);
}

int main() {
    double amp = 4.0;
    TopoDS_Edge e1 = wavyEdge(gp_Pnt(0,0,0), gp_Pnt(10,0,0), gp_Vec(0,0,1), amp, 3, 14);
    TopoDS_Edge e2 = wavyEdge(gp_Pnt(10,0,0), gp_Pnt(10,10,0), gp_Vec(0,0,1), -amp, 3, 14);
    TopoDS_Edge e3 = wavyEdge(gp_Pnt(10,10,0), gp_Pnt(0,10,0), gp_Vec(0,0,1), amp, 3, 14);
    TopoDS_Edge e4 = wavyEdge(gp_Pnt(0,10,0), gp_Pnt(0,0,0), gp_Vec(0,0,1), -amp, 3, 14);

    for (double tol3d : {1e-4, 1e-5, 1e-6}) {
        BRepOffsetAPI_MakeFilling filling(3, 15, 2, false, tol3d * 0.1, tol3d, 0.01, 0.1, 8, 9);
        for (TopoDS_Edge e : {e1, e2, e3, e4}) filling.Add(e, GeomAbs_C0, true);
        try {
            filling.Build();
            bool done = filling.IsDone();
            double g0 = done ? filling.G0Error() : -1;
            double diag = -1;
            if (done) {
                Bnd_Box box;
                BRepBndLib::Add(filling.Shape(), box);
                double xmin, ymin, zmin, xmax, ymax, zmax;
                box.Get(xmin, ymin, zmin, xmax, ymax, zmax);
                diag = std::sqrt((xmax-xmin)*(xmax-xmin) + (ymax-ymin)*(ymax-ymin) + (zmax-zmin)*(zmax-zmin));
            }
            printf("tol3d=%-10g isDone=%-5s G0Error=%-12g bboxDiag=%-10g %s\n",
                   tol3d, done ? "true" : "false", g0, diag,
                   (done && g0 > tol3d) ? "EXCEEDS TOLERANCE, ACCEPTED ANYWAY" : "within tol");
            if (done) {
                for (TopExp_Explorer fe(filling.Shape(), TopAbs_FACE); fe.More(); fe.Next()) {
                    TopoDS_Face f = TopoDS::Face(fe.Current());
                    Handle(Geom_Surface) surf = BRep_Tool::Surface(f);
                    Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surf);
                    if (!bs.IsNull()) {
                        printf("  face surface: BSpline degU=%d degV=%d nPolesU=%d nPolesV=%d\n",
                               bs->UDegree(), bs->VDegree(), bs->NbUPoles(), bs->NbVPoles());
                        double maxPoleR = 0;
                        for (int i = 1; i <= bs->NbUPoles(); i++)
                            for (int j = 1; j <= bs->NbVPoles(); j++) {
                                gp_Pnt p = bs->Pole(i, j);
                                double r = p.Distance(gp_Pnt(5,5,0));
                                if (r > maxPoleR) maxPoleR = r;
                            }
                        printf("  max pole distance from boundary centre (5,5,0): %g\n", maxPoleR);
                    } else {
                        printf("  face surface: not a BSpline (%s)\n", surf->DynamicType()->Name());
                    }
                }
            }
        } catch (std::exception& ex) {
            printf("tol3d=%-10g THREW: %s\n", tol3d, ex.what());
        } catch (...) {
            printf("tol3d=%-10g THREW\n", tol3d);
        }
    }
    return 0;
}
