// Push harder: can the bridge's OWN DEFAULT tolerance (1e-4) be exceeded by a genuinely-difficult
// but not-absurd boundary (a saddle with larger amplitude / higher curvature), still with
// MaxSegments capped at the bridge's default of 9?
#include <BRepOffsetAPI_MakeFilling.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <Geom_BSplineCurve.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TopoDS_Edge.hxx>
#include <gp_Pnt.hxx>
#include <cstdio>
#include <cmath>
#include <vector>

// A wavy BSpline edge with several oscillations -- harder for a degree<=8, <=9-segment fit.
static TopoDS_Edge wavyEdge(gp_Pnt start, gp_Pnt end, gp_Vec perp, double amp, int waves, int npts) {
    TColgp_Array1OfPnt pts(1, npts);
    for (int i = 0; i < npts; i++) {
        double t = double(i) / (npts - 1);
        gp_Pnt base(start.X() + t * (end.X() - start.X()),
                    start.Y() + t * (end.Y() - start.Y()),
                    start.Z() + t * (end.Z() - start.Z()));
        double s = amp * std::sin(t * waves * 2 * M_PI);
        pts.SetValue(i + 1, gp_Pnt(base.X() + s * perp.X(), base.Y() + s * perp.Y(), base.Z() + s * perp.Z()));
    }
    // Interpolate with a simple approximation: build a BSpline through points via a basic
    // uniform-knot cubic fit is overkill here -- use degree-1 polyline via BSpline with npts poles
    // (a piecewise-linear "curve", still G0-continuous and plenty wavy for this purpose is not
    // ideal). Instead, hand-build a clamped cubic-ish BSpline by just using the points as poles
    // over a uniform non-rational BSpline (visually wavy, not exactly interpolating, which is fine
    // for a "hard to approximate" boundary probe).
    int nPoles = npts;
    int degree = 3;
    int nKnots = nPoles - degree + 1 > 1 ? nPoles - degree + 1 : 2;
    TColStd_Array1OfReal knots(1, nKnots);
    for (int i = 0; i < nKnots; i++) knots.SetValue(i + 1, double(i) / (nKnots - 1));
    TColStd_Array1OfInteger mults(1, nKnots);
    mults.SetValue(1, degree + 1);
    mults.SetValue(nKnots, degree + 1);
    for (int i = 2; i < nKnots; i++) mults.SetValue(i, 1);
    int totalMult = 0; for (int i = 1; i <= nKnots; i++) totalMult += mults.Value(i);
    // totalMult must equal nPoles + degree + 1; adjust nPoles-derived poles array to match by
    // trimming/padding is fiddly -- simplify: just use a Bezier-like single-span cubic through
    // control points directly (poles = pts), degree = npts-1, single span (clamped).
    TColgp_Array1OfPnt poles(1, npts);
    for (int i = 1; i <= npts; i++) poles.SetValue(i, pts.Value(i));
    TColStd_Array1OfReal k2(1,2); k2.SetValue(1,0.0); k2.SetValue(2,1.0);
    TColStd_Array1OfInteger m2(1,2); m2.SetValue(1, npts); m2.SetValue(2, npts);
    Handle(Geom_BSplineCurve) curve = new Geom_BSplineCurve(poles, k2, m2, npts - 1);
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
            printf("tol3d=%-10g isDone=%-5s G0Error=%-12g %s\n",
                   tol3d, done ? "true" : "false", g0,
                   (done && g0 > tol3d) ? "EXCEEDS TOLERANCE, ACCEPTED ANYWAY" : "within tol");
        } catch (std::exception& ex) {
            printf("tol3d=%-10g THREW: %s\n", tol3d, ex.what());
        } catch (...) {
            printf("tol3d=%-10g THREW\n", tol3d);
        }
    }
    return 0;
}
