// OCCTSwift#549: the 2D pre-bounded arc-length adaptor, measured against the range-taking form.
//
// Curve2D.arcLength(from:to:) reaches OCCTCurve2DLength, which measures through a pre-bounded
// Geom2dAdaptor_Curve(curve, u1, u2); Curve2D.length(from:to:) reaches OCCTCurve2DGetLengthBetween,
// which passes the range to GCPnts_AbscissaPoint::Length(adaptor, u1, u2). #506 measured the 3D
// pair and found the pre-bounded form extrapolates past a BSpline's knots. This asks whether the
// 2D form does the same, which decides whether #549 is a consistency question or a correctness one.
//
// Build:
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/549-curve2d-arclength-range-order/occt_549_curve2d_arclength.mm -o /tmp/occt_549
//   /tmp/occt_549

#include <cmath>
#include <cstdio>

#include <GCPnts_AbscissaPoint.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom_Curve.hxx>
#include <Geom_Line.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <gp_Lin.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <Geom2dAPI_Interpolate.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <Geom2d_BezierCurve.hxx>
#include <Geom2d_Circle.hxx>
#include <Geom2d_Line.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <TColgp_HArray1OfPnt2d.hxx>
#include <TColgp_Array1OfPnt2d.hxx>
#include <Standard_Failure.hxx>
#include <gp_Ax2d.hxx>
#include <gp_Circ2d.hxx>
#include <gp_Lin2d.hxx>

// prebounded: what OCCTCurve2DLength does, and so what Curve2D.arcLength(from:to:) reports.
// ranged: what OCCTCurve2DGetLengthBetween does, and so what Curve2D.length(from:to:) reports.
static void probe(const char* label, const Handle(Geom2d_Curve)& c, double u1, double u2) {
    double a = -999, b = -999;
    const char* ea = "-"; const char* eb = "-";
    try { Geom2dAdaptor_Curve ac(c, u1, u2); a = GCPnts_AbscissaPoint::Length(ac); }
    catch (Standard_Failure const&) { ea = "Standard_Failure"; }
    catch (...) { ea = "other"; }
    try { Geom2dAdaptor_Curve ac(c); b = GCPnts_AbscissaPoint::Length(ac, u1, u2); }
    catch (Standard_Failure const&) { eb = "Standard_Failure"; }
    catch (...) { eb = "other"; }

    const bool same = (ea[0] == '-' && eb[0] == '-' && (a == b || (std::isnan(a) && std::isnan(b))));
    printf("%-38s u=[%g,%g]  prebounded=%.10g (%s)  ranged=%.10g (%s)  %s\n",
           label, u1, u2, a, ea, b, eb, same ? "SAME" : "DIFFER");
}

// What Swift reports for each form, once the bridge's catch and the >= 0 test are applied.
static void swiftView(const char* label, const Handle(Geom2d_Curve)& c, double u1, double u2) {
    double a = -1.0, b = -1.0;
    try { Geom2dAdaptor_Curve ac(c, u1, u2); a = GCPnts_AbscissaPoint::Length(ac); }
    catch (...) { a = -1.0; }
    try { Geom2dAdaptor_Curve ac(c); b = GCPnts_AbscissaPoint::Length(ac, u1, u2); }
    catch (...) { b = -1.0; }

    char av[64], bv[64];
    if (std::isnan(a) || a < 0) snprintf(av, sizeof av, "-1.0 (failure)"); else snprintf(av, sizeof av, "%.10g", a);
    if (std::isnan(b) || b < 0) snprintf(bv, sizeof bv, "nil (failure)"); else snprintf(bv, sizeof bv, "%.10g", b);
    printf("%-38s u=[%g,%g]  arcLength=%-20s length=%s\n", label, u1, u2, av, bv);
}

// The 3D pair, for part 8's cross-check of the contract this change adopts.
static void probe3d(const char* label, const Handle(Geom_Curve)& c, double u1, double u2) {
    double a = -999, b = -999;
    const char* ea = "-"; const char* eb = "-";
    try { GeomAdaptor_Curve ac(c, u1, u2); a = GCPnts_AbscissaPoint::Length(ac); }
    catch (Standard_Failure const&) { ea = "Standard_Failure"; }
    catch (...) { ea = "other"; }
    try { GeomAdaptor_Curve ac(c); b = GCPnts_AbscissaPoint::Length(ac, u1, u2); }
    catch (Standard_Failure const&) { eb = "Standard_Failure"; }
    catch (...) { eb = "other"; }

    const bool same = (ea[0] == '-' && eb[0] == '-' && (a == b || (std::isnan(a) && std::isnan(b))));
    printf("%-38s u=[%g,%g]  prebounded=%.10g (%s)  ranged=%.10g (%s)  %s\n",
           label, u1, u2, a, ea, b, eb, same ? "SAME" : "DIFFER");
}

static Handle(Geom_Curve) multiSpanBSpline3d() {
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

// A 2D interpolation with sharply varying speed: the shape #477/#506 used to expose extrapolation.
static Handle(Geom2d_Curve) multiSpanBSpline2d() {
    Handle(TColgp_HArray1OfPnt2d) pts = new TColgp_HArray1OfPnt2d(1, 5);
    pts->SetValue(1, gp_Pnt2d(0, 0));
    pts->SetValue(2, gp_Pnt2d(10, 40));
    pts->SetValue(3, gp_Pnt2d(20, 0));
    pts->SetValue(4, gp_Pnt2d(200, 5));
    pts->SetValue(5, gp_Pnt2d(210, 60));
    Geom2dAPI_Interpolate interp(pts, Standard_False, 1e-7);
    interp.Perform();
    return interp.Curve();
}

int main() {
    Handle(Geom2d_Curve) bsp = multiSpanBSpline2d();
    const double f = bsp->FirstParameter(), l = bsp->LastParameter();

    Handle(Geom2d_Curve) circ = new Geom2d_Circle(gp_Circ2d(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5.0));
    Handle(Geom2d_Curve) line = new Geom2d_Line(gp_Lin2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)));
    Handle(Geom2d_Curve) seg = new Geom2d_TrimmedCurve(line, 0.0, 10.0);

    TColgp_Array1OfPnt2d poles(1, 3);
    poles.SetValue(1, gp_Pnt2d(0, 0));
    poles.SetValue(2, gp_Pnt2d(5, 5));
    poles.SetValue(3, gp_Pnt2d(10, 0));
    Handle(Geom2d_Curve) bez = new Geom2d_BezierCurve(poles);

    printf("2D BSpline domain = [%g, %g], full length = ", f, l);
    { Geom2dAdaptor_Curve ac(bsp); printf("%.10g\n", GCPnts_AbscissaPoint::Length(ac)); }

    printf("\n== part 1: in-domain ranges, where nothing should differ ==\n");
    probe("bspline in-domain", bsp, f + 0.1 * (l - f), f + 0.6 * (l - f));
    probe("bspline full domain", bsp, f, l);
    probe("circle quarter", circ, 0.0, 1.5707963267948966);
    probe("bezier in-domain", bez, 0.2, 0.8);
    probe("segment in-domain", seg, 2.0, 8.0);

    printf("\n== part 2: reversed range, the divergence #549 was filed for ==\n");
    probe("bspline reversed", bsp, f + 0.6 * (l - f), f + 0.1 * (l - f));
    probe("circle reversed", circ, 2.0, 1.0);
    probe("line reversed", line, 10.0, -10.0);
    probe("bezier reversed", bez, 0.8, 0.2);

    printf("\n== part 3: equal parameters, a genuine zero ==\n");
    probe("bspline equal", bsp, f + 0.3 * (l - f), f + 0.3 * (l - f));
    probe("bezier equal", bez, 0.3, 0.3);

    printf("\n== part 4: out of domain, the #506 extrapolation question ==\n");
    probe("bspline overshoot both ends", bsp, f - (l - f), l + (l - f));
    probe("bspline overshoot upper only", bsp, f, l + (l - f));
    probe("bspline wholly outside", bsp, l + 1.0, l + 2.0);
    probe("bezier overshoot both ends", bez, -1.0, 2.0);
    probe("segment overshoot both ends", seg, -10.0, 20.0);
    probe("segment wholly outside", seg, 20.0, 30.0);

    printf("\n== part 5: periodic seam and unbounded ==\n");
    probe("circle across seam", circ, 5.0, 7.0);
    probe("circle full period", circ, 0.0, 6.283185307179586);
    probe("circle beyond one period", circ, 0.0, 12.566370614359172);
    probe("unbounded line sub-range", line, -10.0, 10.0);

    printf("\n== part 6: NaN bounds (the #548 question, asked in 2D) ==\n");
    probe("bspline NaN upper", bsp, f, NAN);
    probe("bspline NaN lower", bsp, NAN, l);
    probe("segment NaN upper", seg, 0.0, NAN);
    probe("circle NaN upper", circ, 0.0, NAN);
    probe("bezier NaN upper", bez, 0.0, NAN);

    printf("\n== part 7: what Swift reports today, per entry point ==\n");
    swiftView("bspline reversed", bsp, f + 0.6 * (l - f), f + 0.1 * (l - f));
    swiftView("bspline overshoot both ends", bsp, f - (l - f), l + (l - f));
    swiftView("bspline wholly outside", bsp, l + 1.0, l + 2.0);
    swiftView("bezier reversed", bez, 0.8, 0.2);
    swiftView("bezier overshoot both ends", bez, -1.0, 2.0);

    // Curve3D.length(from:to:) documents the range-taking form as clamping to the curve's domain.
    // Part 4 says that holds for a 2D BSpline and not for a 2D Bezier or a trimmed line, so ask
    // the same question of the 3D form this change adopts, rather than assuming the doc is general.
    printf("\n== part 8: is the range-taking form's clamping curve-type dependent, in 3D too? ==\n");
    Handle(Geom_Curve) bsp3 = multiSpanBSpline3d();
    const double f3 = bsp3->FirstParameter(), l3 = bsp3->LastParameter();
    Handle(Geom_Curve) line3 = new Geom_Line(gp_Lin(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)));
    Handle(Geom_Curve) seg3 = new Geom_TrimmedCurve(line3, 0.0, 10.0);
    TColgp_Array1OfPnt poles3(1, 3);
    poles3.SetValue(1, gp_Pnt(0, 0, 0));
    poles3.SetValue(2, gp_Pnt(5, 5, 0));
    poles3.SetValue(3, gp_Pnt(10, 0, 0));
    Handle(Geom_Curve) bez3 = new Geom_BezierCurve(poles3);
    probe3d("bspline3d overshoot both ends", bsp3, f3 - (l3 - f3), l3 + (l3 - f3));
    probe3d("bspline3d wholly outside", bsp3, l3 + 1.0, l3 + 2.0);
    probe3d("bezier3d overshoot both ends", bez3, -1.0, 2.0);
    probe3d("bezier3d wholly outside", bez3, 2.0, 3.0);
    probe3d("segment3d overshoot both ends", seg3, -10.0, 20.0);
    probe3d("segment3d wholly outside", seg3, 20.0, 30.0);
    return 0;
}
