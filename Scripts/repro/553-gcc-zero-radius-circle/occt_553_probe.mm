// OCCTSwift #553 probe: what every 2D solver family does with a zero-radius circle argument.
//
// The question the issue poses: a zero-radius circle handed to a tangency / bisector / intersection
// solver is geometrically a point, and several of these solvers have a documented point overload.
// So does OCCT answer the point question when it is handed a degenerate circle, or does it answer
// nothing, or does it answer garbage? The decision (guard, or document "radius 0 means point") has
// to be per family, and it has to be measured.
//
// For every family this runs three cases:
//   control  a valid circle, so the family is known to work at all with these arguments
//   zero     the same circle with radius 0
//   point    OCCT's own point overload of the same query, same centre, where one exists
// and then checks the zero case's solutions against what the point reading would require.
//
// Build:
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/553-gcc-zero-radius-circle/occt_553_probe.mm -o /tmp/occt_553_probe
//   /tmp/occt_553_probe

#include <gp_Pnt2d.hxx>
#include <gp_Dir2d.hxx>
#include <gp_Lin2d.hxx>
#include <gp_Circ2d.hxx>
#include <gp_Ax2d.hxx>
#include <gp_Ax22d.hxx>
#include <gp_Elips2d.hxx>
#include <gp_Hypr2d.hxx>
#include <gp_Parab2d.hxx>

#include <GccAna_Circ2dBisec.hxx>
#include <GccAna_CircLin2dBisec.hxx>
#include <GccAna_CircPnt2dBisec.hxx>
#include <GccAna_Pnt2dBisec.hxx>
#include <GccAna_LinPnt2dBisec.hxx>
#include <GccAna_Lin2dTanPar.hxx>
#include <GccAna_Lin2dTanPer.hxx>
#include <GccAna_Lin2d2Tan.hxx>
#include <GccAna_Circ2d3Tan.hxx>
#include <GccAna_Circ2d2TanRad.hxx>
#include <GccAna_Circ2dTanOnRad.hxx>
#include <GccEnt_QualifiedCirc.hxx>
#include <GccEnt_QualifiedLin.hxx>
#include <GccInt_Bisec.hxx>
#include <GccInt_IType.hxx>

#include <IntAna2d_AnaIntersection.hxx>
#include <IntAna2d_IntPoint.hxx>
#include <Extrema_ExtElC2d.hxx>
#include <Extrema_ExtPElC2d.hxx>
#include <Extrema_POnCurv2d.hxx>

#include <GC_MakeCircle2d.hxx>
#include <BRepBuilderAPI_MakeEdge2d.hxx>
#include <BRep_Tool.hxx>
#include <TopoDS_Edge.hxx>
#include <TopExp.hxx>
#include <TopoDS_Vertex.hxx>
#include <Geom2d_Circle.hxx>
#include <GProp_GProps.hxx>

#include <cmath>
#include <cstdio>
#include <string>

static int gFailures = 0;

static void head(const char* title) {
    printf("\n============================================================\n%s\n"
           "============================================================\n", title);
}

static const char* bisecTypeName(GccInt_IType t) {
    switch (t) {
        case GccInt_Lin: return "Line";
        case GccInt_Cir: return "Circle";
        case GccInt_Ell: return "Ellipse";
        case GccInt_Par: return "Parabola";
        case GccInt_Hpr: return "Hyperbola";
        case GccInt_Pnt: return "Point";
    }
    return "?";
}

// A one-line description of a bisector solution, plus whether the bridge's own extractor
// (OCCTBridge_Geom2d.mm extractBisecSolution) can carry it. That extractor has a case for
// Lin/Cir/Ell/Hpr/Par and a default that zeroes everything, so GccInt_Pnt loses its coordinates.
static std::string describeBisec(const Handle(GccInt_Bisec)& b, bool* outBridgeLosesIt) {
    char buf[256];
    GccInt_IType t = b->ArcType();
    *outBridgeLosesIt = (t == GccInt_Pnt);
    switch (t) {
        case GccInt_Lin: {
            gp_Lin2d l = b->Line();
            snprintf(buf, sizeof buf, "Line      at (%.4f, %.4f) dir (%.4f, %.4f)",
                     l.Location().X(), l.Location().Y(), l.Direction().X(), l.Direction().Y());
            break;
        }
        case GccInt_Cir: {
            gp_Circ2d c = b->Circle();
            snprintf(buf, sizeof buf, "Circle    at (%.4f, %.4f) r %.4f",
                     c.Location().X(), c.Location().Y(), c.Radius());
            break;
        }
        case GccInt_Ell: {
            gp_Elips2d e = b->Ellipse();
            snprintf(buf, sizeof buf, "Ellipse   at (%.4f, %.4f) major %.4f minor %.4f",
                     e.Location().X(), e.Location().Y(), e.MajorRadius(), e.MinorRadius());
            break;
        }
        case GccInt_Hpr: {
            gp_Hypr2d h = b->Hyperbola();
            snprintf(buf, sizeof buf, "Hyperbola at (%.4f, %.4f) major %.4f minor %.4f",
                     h.Location().X(), h.Location().Y(), h.MajorRadius(), h.MinorRadius());
            break;
        }
        case GccInt_Par: {
            gp_Parab2d p = b->Parabola();
            snprintf(buf, sizeof buf, "Parabola  at (%.4f, %.4f) focal %.4f",
                     p.Location().X(), p.Location().Y(), p.Focal());
            break;
        }
        case GccInt_Pnt: {
            gp_Pnt2d p = b->Point();
            snprintf(buf, sizeof buf, "Point     at (%.4f, %.4f)", p.X(), p.Y());
            break;
        }
        default:
            snprintf(buf, sizeof buf, "unknown");
    }
    return std::string(buf);
}

template <class Solver>
static void dumpBisec(const char* label, Solver& s) {
    if (!s.IsDone()) { printf("  %-22s IsDone() false\n", label); return; }
    int n = s.NbSolutions();
    printf("  %-22s IsDone() true, %d solution(s)\n", label, n);
    for (int i = 1; i <= n; i++) {
        bool lost = false;
        std::string d = describeBisec(s.ThisSolution(i), &lost);
        printf("      [%d] %s%s\n", i, d.c_str(), lost ? "   <-- bridge writes (0,0)" : "");
    }
}

// ---------------------------------------------------------------------------
// 1. GccAna_Circ2dBisec  (bridge: OCCTGccAnaCirc2dBisec)
//    Point overloads in the same family: GccAna_CircPnt2dBisec, GccAna_Pnt2dBisec.
// ---------------------------------------------------------------------------
static void probeCirc2dBisec() {
    head("1. GccAna_Circ2dBisec - bisector of two circles");
    gp_Pnt2d c1(0, 0), c2(10, 0);
    gp_Circ2d big1(gp_Ax22d(c1, gp_Dir2d(1, 0)), 3.0);
    gp_Circ2d big2(gp_Ax22d(c2, gp_Dir2d(1, 0)), 2.0);
    gp_Circ2d zero1(gp_Ax22d(c1, gp_Dir2d(1, 0)), 0.0);
    gp_Circ2d zero2(gp_Ax22d(c2, gp_Dir2d(1, 0)), 0.0);

    GccAna_Circ2dBisec control(big1, big2);         dumpBisec("control r=3, r=2", control);
    GccAna_Circ2dBisec oneZero(zero1, big2);        dumpBisec("first r=0", oneZero);
    GccAna_Circ2dBisec bothZero(zero1, zero2);      dumpBisec("both r=0", bothZero);

    GccAna_CircPnt2dBisec pointOverload(big2, c1);  dumpBisec("point overload", pointOverload);
    GccAna_Pnt2dBisec twoPoints(c1, c2);
    printf("  %-22s IsDone() %s, HasSolution() %s\n", "two-point overload",
           twoPoints.IsDone() ? "true" : "false",
           twoPoints.IsDone() && twoPoints.HasSolution() ? "true" : "false");
    if (twoPoints.IsDone() && twoPoints.HasSolution()) {
        gp_Lin2d l = twoPoints.ThisSolution();
        printf("      [1] Line      at (%.4f, %.4f) dir (%.4f, %.4f)\n",
               l.Location().X(), l.Location().Y(), l.Direction().X(), l.Direction().Y());
    }
    printf("  NOTE the r=0 answer is a *conic* bisector, the point overload's is a hyperbola branch;\n"
           "       the two-point overload gives the perpendicular bisector line.\n");
}

// ---------------------------------------------------------------------------
// 2. GccAna_CircLin2dBisec  (bridge: OCCTGccAnaCircLin2dBisec)
//    Point overload: GccAna_LinPnt2dBisec.
// ---------------------------------------------------------------------------
static void probeCircLin2dBisec() {
    head("2. GccAna_CircLin2dBisec - bisector of a circle and a line");
    gp_Pnt2d c(0, 5);
    gp_Lin2d line(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
    gp_Circ2d big(gp_Ax22d(c, gp_Dir2d(1, 0)), 2.0);
    gp_Circ2d zero(gp_Ax22d(c, gp_Dir2d(1, 0)), 0.0);

    GccAna_CircLin2dBisec control(big, line);   dumpBisec("control r=2", control);
    GccAna_CircLin2dBisec degen(zero, line);    dumpBisec("r=0", degen);

    GccAna_LinPnt2dBisec pointOverload(line, c);
    printf("  %-22s IsDone() %s (one solution)\n", "point overload",
           pointOverload.IsDone() ? "true" : "false");
    if (pointOverload.IsDone()) {
        bool lost = false;
        printf("      [1] %s\n", describeBisec(pointOverload.ThisSolution(), &lost).c_str());
    }
    printf("  NOTE a point/line bisector is one parabola. Compare with the r=0 answer above.\n");
}

// ---------------------------------------------------------------------------
// 3. GccAna_CircPnt2dBisec  (bridge: OCCTGccAnaCircPnt2dBisec)
//    Point overload: GccAna_Pnt2dBisec.
// ---------------------------------------------------------------------------
static void probeCircPnt2dBisec() {
    head("3. GccAna_CircPnt2dBisec - bisector of a circle and a point");
    gp_Pnt2d c(0, 0), p(6, 0);
    gp_Circ2d big(gp_Ax22d(c, gp_Dir2d(1, 0)), 2.0);
    gp_Circ2d zero(gp_Ax22d(c, gp_Dir2d(1, 0)), 0.0);

    GccAna_CircPnt2dBisec control(big, p);  dumpBisec("control r=2", control);
    GccAna_CircPnt2dBisec degen(zero, p);   dumpBisec("r=0", degen);

    GccAna_Pnt2dBisec pointOverload(c, p);
    printf("  %-22s IsDone() %s, HasSolution() %s\n", "point overload",
           pointOverload.IsDone() ? "true" : "false",
           pointOverload.IsDone() && pointOverload.HasSolution() ? "true" : "false");
    if (pointOverload.IsDone() && pointOverload.HasSolution()) {
        gp_Lin2d l = pointOverload.ThisSolution();
        printf("      [1] Line      at (%.4f, %.4f) dir (%.4f, %.4f)\n",
               l.Location().X(), l.Location().Y(), l.Direction().X(), l.Direction().Y());
    }
    printf("  NOTE the point/point answer is the perpendicular bisector at x = 3.\n");
}

// ---------------------------------------------------------------------------
// 4/5. GccAna_Lin2dTanPar / GccAna_Lin2dTanPer with a qualified circle
//      (bridge: OCCTGccAnaLin2dTanParCirc, OCCTGccAnaLin2dTanPerCircLin)
//      Both have a gp_Pnt2d overload taking the point directly.
// ---------------------------------------------------------------------------
static double distPointToLine(const gp_Pnt2d& p, const gp_Lin2d& l) {
    gp_Pnt2d o = l.Location();
    gp_Dir2d d = l.Direction();
    double vx = p.X() - o.X(), vy = p.Y() - o.Y();
    return std::fabs(vx * d.Y() - vy * d.X());
}

static void probeLin2dTanPar() {
    head("4. GccAna_Lin2dTanPar - line tangent to a circle, parallel to a line");
    gp_Pnt2d c(0, 0);
    gp_Lin2d ref(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
    gp_Circ2d big(gp_Ax22d(c, gp_Dir2d(1, 0)), 4.0);
    gp_Circ2d zero(gp_Ax22d(c, gp_Dir2d(1, 0)), 0.0);

    GccAna_Lin2dTanPar control(GccEnt_QualifiedCirc(big, GccEnt_unqualified), ref);
    printf("  control r=4          IsDone() %s, %d solution(s)\n",
           control.IsDone() ? "true" : "false", control.IsDone() ? control.NbSolutions() : 0);
    for (int i = 1; control.IsDone() && i <= control.NbSolutions(); i++) {
        gp_Lin2d s = control.ThisSolution(i);
        printf("      [%d] at (%.4f, %.4f) dir (%.4f, %.4f)  dist to centre %.6f (want 4)\n",
               i, s.Location().X(), s.Location().Y(), s.Direction().X(), s.Direction().Y(),
               distPointToLine(c, s));
    }

    GccAna_Lin2dTanPar degen(GccEnt_QualifiedCirc(zero, GccEnt_unqualified), ref);
    printf("  r=0                  IsDone() %s, %d solution(s)\n",
           degen.IsDone() ? "true" : "false", degen.IsDone() ? degen.NbSolutions() : 0);
    for (int i = 1; degen.IsDone() && i <= degen.NbSolutions(); i++) {
        gp_Lin2d s = degen.ThisSolution(i);
        double d = distPointToLine(c, s);
        printf("      [%d] at (%.4f, %.4f) dir (%.4f, %.4f)  dist to centre %.6f (point reading wants 0)%s\n",
               i, s.Location().X(), s.Location().Y(), s.Direction().X(), s.Direction().Y(), d,
               d < 1e-9 ? "" : "   <-- NOT through the centre");
    }

    GccAna_Lin2dTanPar pointOverload(c, ref);
    printf("  point overload       IsDone() %s, %d solution(s)\n",
           pointOverload.IsDone() ? "true" : "false",
           pointOverload.IsDone() ? pointOverload.NbSolutions() : 0);
    for (int i = 1; pointOverload.IsDone() && i <= pointOverload.NbSolutions(); i++) {
        gp_Lin2d s = pointOverload.ThisSolution(i);
        printf("      [%d] at (%.4f, %.4f) dir (%.4f, %.4f)  dist to point %.6f\n",
               i, s.Location().X(), s.Location().Y(), s.Direction().X(), s.Direction().Y(),
               distPointToLine(c, s));
    }
}

static void probeLin2dTanPer() {
    head("5. GccAna_Lin2dTanPer - line tangent to a circle, perpendicular to a line");
    gp_Pnt2d c(0, 0);
    gp_Lin2d ref(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
    gp_Circ2d big(gp_Ax22d(c, gp_Dir2d(1, 0)), 4.0);
    gp_Circ2d zero(gp_Ax22d(c, gp_Dir2d(1, 0)), 0.0);

    GccAna_Lin2dTanPer control(GccEnt_QualifiedCirc(big, GccEnt_unqualified), ref);
    printf("  control r=4          IsDone() %s, %d solution(s)\n",
           control.IsDone() ? "true" : "false", control.IsDone() ? control.NbSolutions() : 0);
    for (int i = 1; control.IsDone() && i <= control.NbSolutions(); i++) {
        gp_Lin2d s = control.ThisSolution(i);
        printf("      [%d] at (%.4f, %.4f) dir (%.4f, %.4f)  dist to centre %.6f (want 4)\n",
               i, s.Location().X(), s.Location().Y(), s.Direction().X(), s.Direction().Y(),
               distPointToLine(c, s));
    }

    GccAna_Lin2dTanPer degen(GccEnt_QualifiedCirc(zero, GccEnt_unqualified), ref);
    printf("  r=0                  IsDone() %s, %d solution(s)\n",
           degen.IsDone() ? "true" : "false", degen.IsDone() ? degen.NbSolutions() : 0);
    for (int i = 1; degen.IsDone() && i <= degen.NbSolutions(); i++) {
        gp_Lin2d s = degen.ThisSolution(i);
        double d = distPointToLine(c, s);
        printf("      [%d] at (%.4f, %.4f) dir (%.4f, %.4f)  dist to centre %.6f (point reading wants 0)%s\n",
               i, s.Location().X(), s.Location().Y(), s.Direction().X(), s.Direction().Y(), d,
               d < 1e-9 ? "" : "   <-- NOT through the centre");
    }

    GccAna_Lin2dTanPer pointOverload(c, ref);
    printf("  point overload       IsDone() %s, %d solution(s)\n",
           pointOverload.IsDone() ? "true" : "false",
           pointOverload.IsDone() ? pointOverload.NbSolutions() : 0);
    for (int i = 1; pointOverload.IsDone() && i <= pointOverload.NbSolutions(); i++) {
        gp_Lin2d s = pointOverload.ThisSolution(i);
        printf("      [%d] at (%.4f, %.4f) dir (%.4f, %.4f)  dist to point %.6f\n",
               i, s.Location().X(), s.Location().Y(), s.Direction().X(), s.Direction().Y(),
               distPointToLine(c, s));
    }
}

// ---------------------------------------------------------------------------
// 6. GccAna_Circ2d3Tan - circle tangent to three circles / two circles + point / circle + 2 points
//    (bridge: OCCTGccAnaCirc2d3TanCircles, OCCTGccAnaCirc2d2CirclesPoint,
//             OCCTGccAnaCirc2dCircle2Points)
//    OCCT ships every mixed overload, including the all-points one.
// ---------------------------------------------------------------------------
static void reportCirc3Tan(const char* label, GccAna_Circ2d3Tan& s,
                           const gp_Pnt2d* checkCentre, double checkRadius) {
    printf("  %-24s IsDone() %s, %d solution(s)\n", label,
           s.IsDone() ? "true" : "false", s.IsDone() ? s.NbSolutions() : 0);
    for (int i = 1; s.IsDone() && i <= s.NbSolutions(); i++) {
        gp_Circ2d sol = s.ThisSolution(i);
        printf("      [%d] centre (%.6f, %.6f) r %.6f", i,
               sol.Location().X(), sol.Location().Y(), sol.Radius());
        if (checkCentre) {
            // Tangency to a circle of radius R: |d - r| == R (outer) or d + R == r (enclosing).
            // At R = 0 both collapse to "the solution passes through the point": |d - r| == 0.
            double dx = sol.Location().X() - checkCentre->X();
            double dy = sol.Location().Y() - checkCentre->Y();
            double d = std::sqrt(dx * dx + dy * dy);
            double err = std::fabs(std::fabs(d - sol.Radius()) - checkRadius);
            printf("   tangency residual %.3e%s", err, err < 1e-7 ? "" : "   <-- NOT tangent");
        }
        printf("\n");
    }
}

static void probeCirc2d3Tan() {
    head("6. GccAna_Circ2d3Tan - circle tangent to three circles");
    gp_Pnt2d a(0, 0), b(10, 0), c(5, 8);
    gp_Circ2d ca(gp_Ax2d(a, gp_Dir2d(1, 0)), 2.0);
    gp_Circ2d cb(gp_Ax2d(b, gp_Dir2d(1, 0)), 2.0);
    gp_Circ2d cc(gp_Ax2d(c, gp_Dir2d(1, 0)), 2.0);
    gp_Circ2d za(gp_Ax2d(a, gp_Dir2d(1, 0)), 0.0);

    GccAna_Circ2d3Tan control(GccEnt_QualifiedCirc(ca, GccEnt_unqualified),
                              GccEnt_QualifiedCirc(cb, GccEnt_unqualified),
                              GccEnt_QualifiedCirc(cc, GccEnt_unqualified), 1e-7);
    reportCirc3Tan("control r=2,2,2", control, &a, 2.0);

    GccAna_Circ2d3Tan oneZero(GccEnt_QualifiedCirc(za, GccEnt_unqualified),
                              GccEnt_QualifiedCirc(cb, GccEnt_unqualified),
                              GccEnt_QualifiedCirc(cc, GccEnt_unqualified), 1e-7);
    reportCirc3Tan("first r=0 (vs point a)", oneZero, &a, 0.0);

    GccAna_Circ2d3Tan pointOverload(GccEnt_QualifiedCirc(cb, GccEnt_unqualified),
                                    GccEnt_QualifiedCirc(cc, GccEnt_unqualified),
                                    a, 1e-7);
    reportCirc3Tan("point overload", pointOverload, &a, 0.0);

    printf("\n  --- two circles + a point (bridge OCCTGccAnaCirc2d2CirclesPoint) ---\n");
    GccAna_Circ2d3Tan twoZero(GccEnt_QualifiedCirc(za, GccEnt_unqualified),
                              GccEnt_QualifiedCirc(cb, GccEnt_unqualified),
                              c, 1e-7);
    reportCirc3Tan("first r=0", twoZero, &a, 0.0);

    printf("\n  --- one circle + two points (bridge OCCTGccAnaCirc2dCircle2Points) ---\n");
    GccAna_Circ2d3Tan oneZeroTwoPts(GccEnt_QualifiedCirc(za, GccEnt_unqualified), b, c, 1e-7);
    reportCirc3Tan("r=0", oneZeroTwoPts, &a, 0.0);
    GccAna_Circ2d3Tan allPoints(a, b, c, 1e-7);
    reportCirc3Tan("all-points overload", allPoints, &a, 0.0);
}

// ---------------------------------------------------------------------------
// 7. GccAna_Lin2d2Tan - line tangent to a circle and through a point
//    (bridge: OCCTGccAnaLin2d2TanCircPnt). Point overload: (pnt1, pnt2, tol).
// ---------------------------------------------------------------------------
static void probeLin2d2Tan() {
    head("7. GccAna_Lin2d2Tan - line tangent to a circle, through a point");
    gp_Pnt2d c(0, 0), p(10, 0);
    gp_Circ2d big(gp_Ax2d(c, gp_Dir2d(1, 0)), 3.0);
    gp_Circ2d zero(gp_Ax2d(c, gp_Dir2d(1, 0)), 0.0);

    GccAna_Lin2d2Tan control(GccEnt_QualifiedCirc(big, GccEnt_unqualified), p, 1e-7);
    printf("  control r=3          IsDone() %s, %d solution(s)\n",
           control.IsDone() ? "true" : "false", control.IsDone() ? control.NbSolutions() : 0);
    for (int i = 1; control.IsDone() && i <= control.NbSolutions(); i++) {
        gp_Lin2d s = control.ThisSolution(i);
        printf("      [%d] at (%.4f, %.4f) dir (%.4f, %.4f)  dist to centre %.6f (want 3)\n",
               i, s.Location().X(), s.Location().Y(), s.Direction().X(), s.Direction().Y(),
               distPointToLine(c, s));
    }

    GccAna_Lin2d2Tan degen(GccEnt_QualifiedCirc(zero, GccEnt_unqualified), p, 1e-7);
    printf("  r=0                  IsDone() %s, %d solution(s)\n",
           degen.IsDone() ? "true" : "false", degen.IsDone() ? degen.NbSolutions() : 0);
    for (int i = 1; degen.IsDone() && i <= degen.NbSolutions(); i++) {
        gp_Lin2d s = degen.ThisSolution(i);
        double d = distPointToLine(c, s);
        printf("      [%d] at (%.4f, %.4f) dir (%.4f, %.4f)  dist to centre %.6f%s\n",
               i, s.Location().X(), s.Location().Y(), s.Direction().X(), s.Direction().Y(), d,
               d < 1e-9 ? "   (through the centre, matches the point reading)" : "   <-- NOT through the centre");
    }

    GccAna_Lin2d2Tan pointOverload(c, p, 1e-7);
    printf("  point overload       IsDone() %s, %d solution(s)\n",
           pointOverload.IsDone() ? "true" : "false",
           pointOverload.IsDone() ? pointOverload.NbSolutions() : 0);
    for (int i = 1; pointOverload.IsDone() && i <= pointOverload.NbSolutions(); i++) {
        gp_Lin2d s = pointOverload.ThisSolution(i);
        printf("      [%d] at (%.4f, %.4f) dir (%.4f, %.4f)\n",
               i, s.Location().X(), s.Location().Y(), s.Direction().X(), s.Direction().Y());
    }
}

// ---------------------------------------------------------------------------
// 8. IntAna2d_AnaIntersection - line/circle and circle/circle
//    (bridge: OCCTIntAna2dLinCirc, OCCTIntAna2dCircCirc). No point overload exists:
//    "does this point lie on that curve" is not an intersection query OCCT offers here.
// ---------------------------------------------------------------------------
static void reportIntAna(const char* label, IntAna2d_AnaIntersection& inter) {
    printf("  %-30s IsDone() %s, IsEmpty() %s", label,
           inter.IsDone() ? "true" : "false",
           inter.IsDone() && inter.IsEmpty() ? "true" : "false");
    if (!inter.IsDone()) { printf("\n"); return; }
    if (inter.IsEmpty()) { printf(", 0 point(s)\n"); return; }
    printf(", %d point(s), IdenticalElements() %s\n", inter.NbPoints(),
           inter.IdenticalElements() ? "true" : "false");
    for (int i = 1; i <= inter.NbPoints(); i++) {
        const IntAna2d_IntPoint& pt = inter.Point(i);
        printf("      [%d] (%.6f, %.6f) param1 %.6f param2 %.6f\n", i,
               pt.Value().X(), pt.Value().Y(), pt.ParamOnFirst(),
               pt.SecondIsImplicit() ? 0.0 : pt.ParamOnSecond());
    }
}

static void probeIntAna2d() {
    head("8. IntAna2d_AnaIntersection - line/circle and circle/circle");
    gp_Lin2d onCentre(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));     // passes through (0,0)
    gp_Lin2d offCentre(gp_Pnt2d(0, 1), gp_Dir2d(1, 0));    // misses (0,0)
    gp_Circ2d big(gp_Ax22d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 3.0);
    gp_Circ2d zero(gp_Ax22d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 0.0);
    gp_Circ2d other(gp_Ax22d(gp_Pnt2d(3, 0), gp_Dir2d(1, 0)), 3.0);  // passes through (0,0)
    gp_Circ2d far(gp_Ax22d(gp_Pnt2d(20, 0), gp_Dir2d(1, 0)), 3.0);   // does not

    IntAna2d_AnaIntersection a(onCentre, big);      reportIntAna("control line x circle r=3", a);
    IntAna2d_AnaIntersection b(onCentre, zero);     reportIntAna("line THROUGH the r=0 centre", b);
    IntAna2d_AnaIntersection c(offCentre, zero);    reportIntAna("line MISSING the r=0 centre", c);
    IntAna2d_AnaIntersection d(zero, other);        reportIntAna("r=0 x circle THROUGH centre", d);
    IntAna2d_AnaIntersection e(zero, far);          reportIntAna("r=0 x circle missing centre", e);
    IntAna2d_AnaIntersection f(zero, zero);         reportIntAna("r=0 x the same r=0", f);
    printf("  NOTE the point reading wants exactly one intersection when the point lies on the other\n"
           "       element and none when it does not.\n");
}

// ---------------------------------------------------------------------------
// 9. Extrema_ExtElC2d / Extrema_ExtPElC2d against a zero-radius circle
//    (bridge: OCCTExtremaExtElC2dLinCirc, OCCTExtremaExtPElC2dCirc)
// ---------------------------------------------------------------------------
static void probeExtrema() {
    head("9. Extrema_ExtElC2d (line/circle) and Extrema_ExtPElC2d (point/circle)");
    gp_Lin2d line(gp_Pnt2d(0, 10), gp_Dir2d(1, 0));
    gp_Circ2d big(gp_Ax22d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 3.0);
    gp_Circ2d zero(gp_Ax22d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 0.0);

    {
        Extrema_ExtElC2d ext(line, big, 1e-7);
        printf("  line x circle r=3    IsDone() %s, %d extremum/a\n",
               ext.IsDone() ? "true" : "false", ext.IsDone() ? ext.NbExt() : 0);
        for (int i = 1; ext.IsDone() && i <= ext.NbExt(); i++)
            printf("      [%d] sqDist %.6f (want 49 and 169)\n", i, ext.SquareDistance(i));
    }
    {
        bool threw = false;
        try {
            Extrema_ExtElC2d ext(line, zero, 1e-7);
            printf("  line x circle r=0    IsDone() %s, %d extremum/a\n",
                   ext.IsDone() ? "true" : "false", ext.IsDone() ? ext.NbExt() : 0);
            for (int i = 1; ext.IsDone() && i <= ext.NbExt(); i++) {
                double sq = ext.SquareDistance(i);
                printf("      [%d] sqDist %.6f%s (point reading wants 100)\n", i, sq,
                       std::isnan(sq) ? "   <-- NaN" : "");
            }
        } catch (...) { threw = true; }
        if (threw) printf("  line x circle r=0    threw\n");
    }
    {
        Extrema_ExtPElC2d ext(gp_Pnt2d(0, 10), big, 1e-7, 0, 2 * M_PI);
        printf("  point x circle r=3   IsDone() %s, %d extremum/a\n",
               ext.IsDone() ? "true" : "false", ext.IsDone() ? ext.NbExt() : 0);
        for (int i = 1; ext.IsDone() && i <= ext.NbExt(); i++)
            printf("      [%d] sqDist %.6f (want 49 and 169)\n", i, ext.SquareDistance(i));
    }
    {
        bool threw = false;
        try {
            Extrema_ExtPElC2d ext(gp_Pnt2d(0, 10), zero, 1e-7, 0, 2 * M_PI);
            printf("  point x circle r=0   IsDone() %s, %d extremum/a\n",
                   ext.IsDone() ? "true" : "false", ext.IsDone() ? ext.NbExt() : 0);
            for (int i = 1; ext.IsDone() && i <= ext.NbExt(); i++) {
                double sq = ext.SquareDistance(i);
                printf("      [%d] sqDist %.6f%s (point reading wants 100)\n", i, sq,
                       std::isnan(sq) ? "   <-- NaN" : "");
            }
        } catch (...) { threw = true; }
        if (threw) printf("  point x circle r=0   threw\n");
    }
}

// ---------------------------------------------------------------------------
// 10. The producers: a zero-radius circle turned into an edge or a curve.
//     (bridge: OCCTMakeEdge2dFromCircle, OCCTCurve2DMakeCircleParallel,
//              OCCTCurve2DMakeCircleAxis, OCCTCurve2DMakeCircleCenterRadius)
//     These return geometry, so #514's decision already applies; the question is only
//     whether OCCT itself refuses them.
// ---------------------------------------------------------------------------
static void probeProducers() {
    head("10. Producers - a zero-radius circle asked for as geometry");
    gp_Ax2d ax(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));

    {
        gp_Circ2d zero(ax, 0.0);
        BRepBuilderAPI_MakeEdge2d me(zero, 0, M_PI);
        printf("  MakeEdge2d arc r=0        IsDone() %s\n", me.IsDone() ? "true" : "false");
        if (me.IsDone()) {
            TopoDS_Edge e = me.Edge();
            TopoDS_Vertex v1, v2;
            TopExp::Vertices(e, v1, v2);
            gp_Pnt p1 = BRep_Tool::Pnt(v1), p2 = BRep_Tool::Pnt(v2);
            printf("      vertices (%.4f, %.4f, %.4f) and (%.4f, %.4f, %.4f) - %s\n",
                   p1.X(), p1.Y(), p1.Z(), p2.X(), p2.Y(), p2.Z(),
                   p1.Distance(p2) < 1e-12 ? "coincident, a zero-length edge" : "distinct");
        }
    }
    {
        GC_MakeCircle2d mc(ax, 0.0);
        printf("  GC_MakeCircle2d(ax, 0)    IsDone() %s, status %d\n",
               mc.IsDone() ? "true" : "false", (int)mc.Status());
        if (mc.IsDone()) printf("      radius %.6f\n", mc.Value()->Radius());
    }
    {
        GC_MakeCircle2d mc(ax, -1.0);
        printf("  GC_MakeCircle2d(ax, -1)   IsDone() %s, status %d (2 == NegativeRadius)\n",
               mc.IsDone() ? "true" : "false", (int)mc.Status());
        if (mc.IsDone()) printf("      radius %.6f   <-- a negative radius was accepted\n",
                                mc.Value()->Radius());
    }
    {
        gp_Circ2d base(ax, 5.0);
        GC_MakeCircle2d mc(base, -5.0);   // parallel at distance -5: collapses to radius 0
        printf("  GC_MakeCircle2d(r=5, -5)  IsDone() %s, status %d\n",
               mc.IsDone() ? "true" : "false", (int)mc.Status());
        if (mc.IsDone()) printf("      radius %.6f   <-- the offset collapsed the circle\n",
                                mc.Value()->Radius());
    }
    {
        gp_Circ2d base(ax, 5.0);
        GC_MakeCircle2d mc(base, -6.0);   // parallel past the centre
        printf("  GC_MakeCircle2d(r=5, -6)  IsDone() %s, status %d (2 == NegativeRadius)\n",
               mc.IsDone() ? "true" : "false", (int)mc.Status());
        if (mc.IsDone()) printf("      radius %.6f\n", mc.Value()->Radius());
    }
    {
        gp_Circ2d zero(ax, 0.0);
        GC_MakeCircle2d mc(zero, 3.0);    // parallel to a degenerate circle
        printf("  GC_MakeCircle2d(r=0, +3)  IsDone() %s, status %d\n",
               mc.IsDone() ? "true" : "false", (int)mc.Status());
        if (mc.IsDone()) printf("      radius %.6f\n", mc.Value()->Radius());
    }
}

// ---------------------------------------------------------------------------
// 11. Negative radius: does gp_Circ2d's own precondition run in this translation unit?
//     #514 measured that gp_Elips2d's does, because the constructor is constexpr in the
//     header rather than compiled inside OCCT under No_Exception. gp_Circ2d should behave
//     the same, which would mean the only gap is exactly zero.
// ---------------------------------------------------------------------------
static void probeNegative() {
    head("11. gp_Circ2d(-1) - does the header's own precondition run here?");
    bool threw = false;
    double r = -999;
    try {
        gp_Circ2d bad(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), -1.0);
        r = bad.Radius();
    } catch (...) { threw = true; }
    if (threw) {
        printf("  gp_Circ2d(ax, -1)         threw  <-- negative is already rejected, gap is only zero\n");
    } else {
        printf("  gp_Circ2d(ax, -1)         accepted, Radius() %.4f   <-- negative also needs guarding\n", r);
        gFailures++;
    }
    threw = false;
    try {
        gp_Circ2d zero(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 0.0);
        r = zero.Radius();
    } catch (...) { threw = true; }
    printf("  gp_Circ2d(ax, 0)          %s\n",
           threw ? "threw" : "accepted, this is the gap");
}

// ---------------------------------------------------------------------------
// 12. The other radius in this file: the radius of the circle the solver is asked to
//     CONSTRUCT, not one it is given. GccAna_Circ2d2TanRad and GccAna_Circ2dTanOnRad take it.
//     Three bridge entry points already reject radius <= 0 outright (OCCTGccCircle2d2TanRad,
//     OCCTGccCircle2dTanPtRad, OCCTGccCircle2d2PtRad); four siblings do not
//     (OCCTGccAnaCirc2dTanOnRadLin, OCCTGeom2dGccCirc2dTanOnRad,
//     OCCTGccAnaCirc2d2TanRadLineLin, OCCTGccAnaCirc2d2TanRadPntPnt).
// ---------------------------------------------------------------------------
static void probeRequestedRadius() {
    head("12. A requested SOLUTION radius of 0 - GccAna_Circ2d2TanRad / Circ2dTanOnRad");
    gp_Lin2d l1(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
    gp_Lin2d l2(gp_Pnt2d(0, 0), gp_Dir2d(0, 1));
    gp_Lin2d onLine(gp_Pnt2d(0, 0), gp_Dir2d(1, 1));

    for (double r : {2.0, 0.0, -1.0}) {
        bool threw = false;
        try {
            GccAna_Circ2d2TanRad s(GccEnt_QualifiedLin(l1, GccEnt_unqualified),
                                   GccEnt_QualifiedLin(l2, GccEnt_unqualified), r, 1e-7);
            printf("  2TanRad(lin, lin, r=%-5.1f) IsDone() %s, %d solution(s)", r,
                   s.IsDone() ? "true" : "false", s.IsDone() ? s.NbSolutions() : 0);
            if (s.IsDone() && s.NbSolutions() > 0)
                printf(", first r %.6f%s", s.ThisSolution(1).Radius(),
                       s.ThisSolution(1).Radius() > 0 ? "" : "   <-- a degenerate solution circle");
            printf("\n");
        } catch (...) { threw = true; }
        if (threw) printf("  2TanRad(lin, lin, r=%-5.1f) threw\n", r);
    }
    for (double r : {2.0, 0.0, -1.0}) {
        bool threw = false;
        try {
            GccAna_Circ2d2TanRad s(gp_Pnt2d(0, 0), gp_Pnt2d(4, 0), r, 1e-7);
            printf("  2TanRad(pnt, pnt, r=%-5.1f) IsDone() %s, %d solution(s)", r,
                   s.IsDone() ? "true" : "false", s.IsDone() ? s.NbSolutions() : 0);
            if (s.IsDone() && s.NbSolutions() > 0)
                printf(", first r %.6f", s.ThisSolution(1).Radius());
            printf("\n");
        } catch (...) { threw = true; }
        if (threw) printf("  2TanRad(pnt, pnt, r=%-5.1f) threw\n", r);
    }
    for (double r : {2.0, 0.0, -1.0}) {
        bool threw = false;
        try {
            GccAna_Circ2dTanOnRad s(GccEnt_QualifiedLin(l1, GccEnt_unqualified), onLine, r, 1e-7);
            printf("  TanOnRad(lin, on, r=%-5.1f) IsDone() %s, %d solution(s)", r,
                   s.IsDone() ? "true" : "false", s.IsDone() ? s.NbSolutions() : 0);
            if (s.IsDone() && s.NbSolutions() > 0)
                printf(", first r %.6f%s", s.ThisSolution(1).Radius(),
                       s.ThisSolution(1).Radius() > 0 ? "" : "   <-- a degenerate solution circle");
            printf("\n");
        } catch (...) { threw = true; }
        if (threw) printf("  TanOnRad(lin, on, r=%-5.1f) threw\n", r);
    }
}

// ---------------------------------------------------------------------------
// 13. Is a GccInt_Pnt bisector solution reachable from VALID circles? The bridge's
//     extractBisecSolution has no case for it and its default branch writes (0, 0), so if a
//     point solution can come out of a well-formed pair the coordinates are lost with no
//     zero-radius circle involved anywhere.
// ---------------------------------------------------------------------------
static void probePointBisec() {
    head("13. GccInt_Pnt from valid circles - is the dropped case reachable?");
    struct Case { const char* what; gp_Circ2d a, b; };
    gp_Dir2d x(1, 0);
    Case cases[] = {
        {"identical circles",   gp_Circ2d(gp_Ax22d(gp_Pnt2d(0, 0), x), 3.0),
                                gp_Circ2d(gp_Ax22d(gp_Pnt2d(0, 0), x), 3.0)},
        {"concentric r=3, r=1", gp_Circ2d(gp_Ax22d(gp_Pnt2d(0, 0), x), 3.0),
                                gp_Circ2d(gp_Ax22d(gp_Pnt2d(0, 0), x), 1.0)},
        {"externally tangent",  gp_Circ2d(gp_Ax22d(gp_Pnt2d(0, 0), x), 2.0),
                                gp_Circ2d(gp_Ax22d(gp_Pnt2d(5, 0), x), 3.0)},
        {"internally tangent",  gp_Circ2d(gp_Ax22d(gp_Pnt2d(0, 0), x), 5.0),
                                gp_Circ2d(gp_Ax22d(gp_Pnt2d(2, 0), x), 3.0)},
        {"crossing",            gp_Circ2d(gp_Ax22d(gp_Pnt2d(0, 0), x), 3.0),
                                gp_Circ2d(gp_Ax22d(gp_Pnt2d(4, 0), x), 3.0)},
    };
    for (const Case& c : cases) {
        GccAna_Circ2dBisec s(c.a, c.b);
        printf("  %-22s IsDone() %s, %d solution(s)\n", c.what,
               s.IsDone() ? "true" : "false", s.IsDone() ? s.NbSolutions() : 0);
        for (int i = 1; s.IsDone() && i <= s.NbSolutions(); i++) {
            bool lost = false;
            std::string d = describeBisec(s.ThisSolution(i), &lost);
            printf("      [%d] %s%s\n", i, d.c_str(), lost ? "   <-- bridge writes (0,0)" : "");
        }
    }
    // The circle/point and circle/line families can produce one too.
    GccAna_CircPnt2dBisec onCircle(gp_Circ2d(gp_Ax22d(gp_Pnt2d(0, 0), x), 3.0), gp_Pnt2d(3, 0));
    printf("  %-22s IsDone() %s, %d solution(s)\n", "point ON the circle",
           onCircle.IsDone() ? "true" : "false", onCircle.IsDone() ? onCircle.NbSolutions() : 0);
    for (int i = 1; onCircle.IsDone() && i <= onCircle.NbSolutions(); i++) {
        bool lost = false;
        std::string d = describeBisec(onCircle.ThisSolution(i), &lost);
        printf("      [%d] %s%s\n", i, d.c_str(), lost ? "   <-- bridge writes (0,0)" : "");
    }
    GccAna_CircPnt2dBisec atCentre(gp_Circ2d(gp_Ax22d(gp_Pnt2d(0, 0), x), 3.0), gp_Pnt2d(0, 0));
    printf("  %-22s IsDone() %s, %d solution(s)\n", "point AT the centre",
           atCentre.IsDone() ? "true" : "false", atCentre.IsDone() ? atCentre.NbSolutions() : 0);
    for (int i = 1; atCentre.IsDone() && i <= atCentre.NbSolutions(); i++) {
        bool lost = false;
        std::string d = describeBisec(atCentre.ThisSolution(i), &lost);
        printf("      [%d] %s%s\n", i, d.c_str(), lost ? "   <-- bridge writes (0,0)" : "");
    }
}

int main() {
    printf("OCCTSwift #553 - zero-radius circle arguments to the 2D solver families\n");
    probeNegative();
    probeCirc2dBisec();
    probeCircLin2dBisec();
    probeCircPnt2dBisec();
    probeLin2dTanPar();
    probeLin2dTanPer();
    probeCirc2d3Tan();
    probeLin2d2Tan();
    probeIntAna2d();
    probeExtrema();
    probeProducers();
    probeRequestedRadius();
    probePointBisec();
    printf("\ndone\n");
    return 0;
}
