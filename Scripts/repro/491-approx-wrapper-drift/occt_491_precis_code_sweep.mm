// OCCTSwift#491. PrecisCode 0 vs 1 across BOUNDED surfaces and tolerances; the evidence for
// standardising both surface approximation entry points on 0. See this directory's README.md.
// Which value should the one shared GeomConvert_ApproxSurface wrapper pass? Decide on measured
// evidence: does either reach the requested tolerance where the other does not, and which
// produces the smaller residual error?

#include <Geom_BSplineSurface.hxx>
#include <Geom_SphericalSurface.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_ToroidalSurface.hxx>
#include <Geom_ConicalSurface.hxx>
#include <Geom_SurfaceOfRevolution.hxx>
#include <Geom_SurfaceOfLinearExtrusion.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <Geom_OffsetSurface.hxx>
#include <Geom_Ellipse.hxx>
#include <Geom_Circle.hxx>
#include <Geom_BezierSurface.hxx>
#include <GeomConvert_ApproxSurface.hxx>
#include <gp_Ax2.hxx>
#include <gp_Ax3.hxx>
#include <gp_Elips.hxx>
#include <gp_Circ.hxx>
#include <NCollection_Array2.hxx>

#include <cstdio>
#include <cmath>
#include <vector>
#include <string>

struct Run {
    bool   isDone = false;
    bool   hasResult = false;
    double maxError = 0;
    int    uPoles = 0, vPoles = 0, uKnots = 0, vKnots = 0, uDeg = 0, vDeg = 0;
    bool   threw = false;
};

static Run run(const Handle(Geom_Surface)& s, double tol, GeomAbs_Shape cont,
               int maxDeg, int maxSeg, int precis) {
    Run r;
    try {
        GeomConvert_ApproxSurface a(s, tol, cont, cont, maxDeg, maxDeg, maxSeg, precis);
        r.isDone = a.IsDone();
        r.hasResult = a.HasResult();
        r.maxError = a.MaxError();
        Handle(Geom_BSplineSurface) bs = a.Surface();
        if (!bs.IsNull()) {
            r.uPoles = bs->NbUPoles(); r.vPoles = bs->NbVPoles();
            r.uKnots = bs->NbUKnots(); r.vKnots = bs->NbVKnots();
            r.uDeg = bs->UDegree();    r.vDeg = bs->VDegree();
        }
    } catch (...) {
        r.threw = true;
    }
    return r;
}

static int betterFor0 = 0, betterFor1 = 0, sameError = 0;
static int doneOnly0 = 0, doneOnly1 = 0, shapeDiffers = 0, cases = 0;

static void compare(const char* label, const Handle(Geom_Surface)& s,
                    double tol, GeomAbs_Shape cont, int maxDeg, int maxSeg) {
    Run a = run(s, tol, cont, maxDeg, maxSeg, 0);
    Run b = run(s, tol, cont, maxDeg, maxSeg, 1);
    cases++;

    bool shape = (a.uPoles != b.uPoles || a.vPoles != b.vPoles ||
                  a.uKnots != b.uKnots || a.vKnots != b.vKnots ||
                  a.uDeg != b.uDeg || a.vDeg != b.vDeg);
    if (shape) shapeDiffers++;
    if (a.isDone && !b.isDone) doneOnly0++;
    if (b.isDone && !a.isDone) doneOnly1++;
    if (a.maxError < b.maxError) betterFor0++;
    else if (b.maxError < a.maxError) betterFor1++;
    else sameError++;

    printf("%-34s tol=%-8g deg=%-3d seg=%-4d | P0 done=%d res=%d err=%-13.6g %2dx%-2d k%2dx%-2d"
           " | P1 done=%d res=%d err=%-13.6g %2dx%-2d k%2dx%-2d%s%s\n",
           label, tol, maxDeg, maxSeg,
           (int)a.isDone, (int)a.hasResult, a.maxError, a.uPoles, a.vPoles, a.uKnots, a.vKnots,
           (int)b.isDone, (int)b.hasResult, b.maxError, b.uPoles, b.vPoles, b.uKnots, b.vKnots,
           shape ? "  SHAPE-DIFF" : "",
           (a.isDone != b.isDone) ? "  DONE-DIFF" : "");
}

int main() {
    gp_Ax3 ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    gp_Ax2 ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));

    Handle(Geom_SphericalSurface) sphere = new Geom_SphericalSurface(ax3, 10.0);
    Handle(Geom_ToroidalSurface) torus = new Geom_ToroidalSurface(ax3, 20.0, 5.0);
    // Infinite surfaces trimmed first, per the project's own rule.
    Handle(Geom_Surface) cyl =
        new Geom_RectangularTrimmedSurface(new Geom_CylindricalSurface(ax3, 5.0),
                                           0.0, 2 * M_PI, -10.0, 10.0);
    Handle(Geom_Surface) cone =
        new Geom_RectangularTrimmedSurface(new Geom_ConicalSurface(ax3, 0.4, 3.0),
                                           0.0, 2 * M_PI, 0.0, 12.0);
    // Revolution of an ellipse: not exactly representable, so the fit has to work.
    Handle(Geom_Ellipse) profile =
        new Geom_Ellipse(gp_Elips(gp_Ax2(gp_Pnt(20, 0, 0), gp_Dir(0, 1, 0)), 6.0, 2.0));
    Handle(Geom_Surface) revol = new Geom_SurfaceOfRevolution(profile, gp_Ax1(gp_Pnt(0, 0, 0),
                                                                             gp_Dir(0, 0, 1)));
    Handle(Geom_Surface) offSphere = new Geom_OffsetSurface(sphere, 1.5);
    Handle(Geom_Surface) offTorus = new Geom_OffsetSurface(torus, 0.75);
    // A Bezier patch, already polynomial: the easy case.
    NCollection_Array2<gp_Pnt> poles(1, 4, 1, 4);
    for (int i = 1; i <= 4; i++)
        for (int j = 1; j <= 4; j++)
            poles.SetValue(i, j, gp_Pnt(i * 3.0, j * 3.0, (i * j) % 5));
    Handle(Geom_Surface) bez = new Geom_BezierSurface(poles);

    struct Case { const char* label; Handle(Geom_Surface) surf; };
    std::vector<Case> surfaces = {
        {"sphere r=10", sphere},
        {"torus 20/5", torus},
        {"trimmed cylinder r=5", cyl},
        {"trimmed cone", cone},
        {"revolved ellipse 6x2", revol},
        {"offset sphere +1.5", offSphere},
        {"offset torus +0.75", offTorus},
        {"bezier 4x4", bez},
    };
    // Surface.approximated's defaults are tolerance 1e-3 / maxDegree 8 / maxSegments 100.
    std::vector<double> tolerances = {1e-1, 1e-2, 1e-3, 1e-5, 1e-7, 1e-9};

    printf("== PrecisCode 0 vs 1, continuity C2, maxDegree 8, maxSegments 100 ==\n");
    for (const Case& c : surfaces) {
        for (double tol : tolerances) {
            compare(c.label, c.surf, tol, GeomAbs_C2, 8, 100);
        }
        printf("\n");
    }

    printf("== same, continuity C0 / C1 and the pre-#406 maxDegree 10 ==\n");
    for (const Case& c : surfaces) {
        compare(c.label, c.surf, 1e-3, GeomAbs_C0, 8, 100);
        compare(c.label, c.surf, 1e-3, GeomAbs_C1, 8, 100);
        compare(c.label, c.surf, 1e-2, GeomAbs_C2, 10, 100);
    }

    printf("\n== tally over %d cases ==\n", cases);
    printf("  result shape (poles/knots/degree) differs : %d\n", shapeDiffers);
    printf("  IsDone differs between the two codes      : %d  (only P0 done: %d, only P1 done: %d)\n",
           doneOnly0 + doneOnly1, doneOnly0, doneOnly1);
    printf("  smaller maxError with PrecisCode=0        : %d\n", betterFor0);
    printf("  smaller maxError with PrecisCode=1        : %d\n", betterFor1);
    printf("  identical maxError                        : %d\n", sameError);
    return 0;
}
