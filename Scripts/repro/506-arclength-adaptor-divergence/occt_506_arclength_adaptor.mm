// OCCTSwift#506 probe: pre-bounded GeomAdaptor_Curve(c, u1, u2) vs GCPnts_AbscissaPoint::Length(c, u1, u2)
//
// #506 deleted three orphaned Curve3D arc-length bridge functions. One of them,
// OCCTCurve3DLength, measured through a pre-bounded adaptor rather than passing the range to
// GCPnts_AbscissaPoint::Length. This asks whether the two forms ever disagree, and where.
//
// Part 2 asks a question raised by part 1's NaN row: is the live form's NaN handling the same for
// every curve type? (It is not. Filed as #548.)
//
// Build and run from the repository root:
//
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/506-arclength-adaptor-divergence/occt_506_arclength_adaptor.mm -o /tmp/occt_506
//   /tmp/occt_506

#include <GCPnts_AbscissaPoint.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Line.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <Geom2d_Line.hxx>
#include <Geom2d_Circle.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <gp_Ax2.hxx>
#include <gp_Circ.hxx>
#include <gp_Lin.hxx>
#include <gp_Ax2d.hxx>
#include <gp_Circ2d.hxx>
#include <gp_Lin2d.hxx>
#include <Standard_Failure.hxx>
#include <stdio.h>

// prebounded: what the deleted OCCTCurve3DLength did.
// ranged: what the surviving OCCTCurve3DGetLengthBetween does.
static void probe3d(const char* label, const Handle(Geom_Curve)& c, double u1, double u2) {
    double a = -999, b = -999;
    const char* ea = "-"; const char* eb = "-";
    try { GeomAdaptor_Curve ac(c, u1, u2); a = GCPnts_AbscissaPoint::Length(ac); }
    catch (Standard_Failure const&) { ea = "Standard_Failure"; }
    catch (...) { ea = "other"; }
    try { GeomAdaptor_Curve ac(c); b = GCPnts_AbscissaPoint::Length(ac, u1, u2); }
    catch (Standard_Failure const&) { eb = "Standard_Failure"; }
    catch (...) { eb = "other"; }
    printf("%-46s u=[%g,%g]  prebounded=%.10g (%s)  ranged=%.10g (%s)  %s\n",
           label, u1, u2, a, ea, b, eb,
           (ea[0] == '-' && eb[0] == '-' && a == b) ? "SAME" : "DIFFER");
}

// The 2D pair, which #506 left alone: OCCTCurve2DLength is still the pre-bounded form and is
// still reachable from Curve2D.arcLength(from:to:). Filed as #549.
static void probe2d(const char* label, const Handle(Geom2d_Curve)& c, double u1, double u2) {
    double a = -999, b = -999;
    const char* ea = "-"; const char* eb = "-";
    try { Geom2dAdaptor_Curve ac(c, u1, u2); a = GCPnts_AbscissaPoint::Length(ac); }
    catch (Standard_Failure const&) { ea = "Standard_Failure"; }
    catch (...) { ea = "other"; }
    try { Geom2dAdaptor_Curve ac(c); b = GCPnts_AbscissaPoint::Length(ac, u1, u2); }
    catch (Standard_Failure const&) { eb = "Standard_Failure"; }
    catch (...) { eb = "other"; }
    printf("%-46s u=[%g,%g]  prebounded=%.10g (%s)  ranged=%.10g (%s)  %s\n",
           label, u1, u2, a, ea, b, eb,
           (ea[0] == '-' && eb[0] == '-' && a == b) ? "SAME" : "DIFFER");
}

static void ranged(const char* label, const Handle(Geom_Curve)& c, double u1, double u2) {
    double v = -999; const char* e = "-";
    try { GeomAdaptor_Curve ac(c); v = GCPnts_AbscissaPoint::Length(ac, u1, u2); }
    catch (Standard_Failure const&) { e = "Standard_Failure"; } catch (...) { e = "other"; }
    printf("%-34s ranged=%-16.10g (%s)  Swift sees=%s\n", label, v, e,
           (e[0] != '-') ? "n/a" : (v >= 0 ? "a value" : "nil"));
}

static Handle(Geom_Curve) multiSpanBSpline() {
    Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, 5);
    pts->SetValue(1, gp_Pnt(0, 0, 0));
    pts->SetValue(2, gp_Pnt(10, 40, 0));
    pts->SetValue(3, gp_Pnt(20, 0, 0));
    pts->SetValue(4, gp_Pnt(200, 5, 0));
    pts->SetValue(5, gp_Pnt(210, 60, 30));
    GeomAPI_Interpolate interp(pts, Standard_False, 1e-7);
    interp.Perform();
    return interp.Curve();
}

int main() {
    Handle(Geom_Curve) bsp = multiSpanBSpline();
    const double f = bsp->FirstParameter(), l = bsp->LastParameter();
    printf("BSpline domain = [%g, %g]\n", f, l);

    Handle(Geom_Curve) circ = new Geom_Circle(gp_Circ(gp_Ax2(gp_Pnt(0,0,0), gp_Dir(0,0,1)), 5.0));
    Handle(Geom_Curve) line = new Geom_Line(gp_Lin(gp_Pnt(0,0,0), gp_Dir(1,0,0)));
    Handle(Geom_Curve) seg = new Geom_TrimmedCurve(line, 0.0, 10.0);

    printf("\n== part 1a: 3D, in-domain sub-range ==\n");
    probe3d("bspline in-domain", bsp, f + 0.1 * (l - f), f + 0.6 * (l - f));
    probe3d("bspline full domain", bsp, f, l);
    printf("\n== part 1b: 3D, reversed range ==\n");
    probe3d("bspline reversed", bsp, f + 0.6 * (l - f), f + 0.1 * (l - f));
    probe3d("circle reversed", circ, 2.0, 1.0);
    printf("\n== part 1c: 3D, equal parameters ==\n");
    probe3d("bspline equal", bsp, f + 0.3 * (l - f), f + 0.3 * (l - f));
    printf("\n== part 1d: 3D, out of domain ==\n");
    probe3d("bspline overshoot both ends", bsp, f - (l - f), l + (l - f));
    probe3d("bspline wholly outside", bsp, l + 1.0, l + 2.0);
    printf("\n== part 1e: 3D, periodic seam and unbounded ==\n");
    probe3d("circle across seam", circ, 5.0, 7.0);
    probe3d("circle full period", circ, 0.0, 6.283185307179586);
    probe3d("unbounded line sub-range", line, -10.0, 10.0);
    printf("\n== part 1f: 3D, NaN bound ==\n");
    probe3d("bspline NaN upper", bsp, f, NAN);

    Handle(Geom2d_Curve) c2 = new Geom2d_Circle(gp_Circ2d(gp_Ax2d(gp_Pnt2d(0,0), gp_Dir2d(1,0)), 5.0));
    Handle(Geom2d_Curve) l2 = new Geom2d_Line(gp_Lin2d(gp_Pnt2d(0,0), gp_Dir2d(1,0)));
    printf("\n== part 1g: the 2D pair, still both live (#549) ==\n");
    probe2d("circle2d in-domain", c2, 1.0, 2.0);
    probe2d("circle2d reversed", c2, 2.0, 1.0);
    probe2d("line2d reversed", l2, 10.0, -10.0);

    printf("\n== part 2: is the live form's NaN handling curve-type dependent? (#548) ==\n");
    printf("NaN upper bound:\n");
    ranged("segment (trimmed line)", seg, 0.0, NAN);
    ranged("unbounded line", line, 0.0, NAN);
    ranged("bspline", bsp, f, NAN);
    ranged("circle", circ, 0.0, NAN);
    printf("NaN lower bound:\n");
    ranged("segment", seg, NAN, 10.0);
    ranged("bspline", bsp, NAN, l);
    return 0;
}
