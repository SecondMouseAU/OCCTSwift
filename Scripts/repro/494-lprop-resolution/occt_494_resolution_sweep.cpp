// #494 ground truth: does the GeomLProp Resolution argument (1e-10 vs Precision::Confusion()
// vs 1e-6) actually change what the Local* / canonical curvature entry points report?
#include <Geom_ConicalSurface.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_SphericalSurface.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Line.hxx>
#include <GeomLProp_SLProps.hxx>
#include <GeomLProp_CLProps.hxx>
#include <Precision.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <gp_Ax3.hxx>
#include <Standard_Failure.hxx>
#include <cstdio>
#include <cmath>

static const double TOLS[3] = {1e-10, Precision::Confusion(), 1e-6};
static const char*  NAMES[3] = {"1e-10 (Local)", "Confusion", "1e-6 (LProp*)"};

// --- Surface side: cone, sampled at V distances that straddle the tolerance band ---
static void surfaceSweep() {
    printf("\n=== SLProps: cone (semi-angle 30 deg, apex radius 0), u=0, varying v ===\n");
    printf("%-12s | %-28s | %-28s | %-28s\n", "v", NAMES[0], NAMES[1], NAMES[2]);
    Handle(Geom_ConicalSurface) cone =
        new Geom_ConicalSurface(gp_Ax3(gp_Pnt(0,0,0), gp_Dir(0,0,1)), M_PI/6.0, 0.0);

    const double vs[] = {0.0, 1e-12, 1e-10, 1e-9, 1e-8, 1e-7, 1e-6, 1e-5, 1e-4, 1e-2, 1.0};
    for (double v : vs) {
        printf("%-12.0e |", v);
        for (int t = 0; t < 3; ++t) {
            char cell[64];
            try {
                GeomLProp_SLProps p(cone, 0.0, v, 2, TOLS[t]);
                if (p.IsCurvatureDefined()) {
                    snprintf(cell, sizeof cell, "def K=%-9.3g H=%-9.3g", p.GaussianCurvature(), p.MeanCurvature());
                } else {
                    snprintf(cell, sizeof cell, "UNDEFINED");
                }
            } catch (Standard_Failure const& f) {
                snprintf(cell, sizeof cell, "throw %s", f.GetMessageString());
            } catch (...) { snprintf(cell, sizeof cell, "throw ..."); }
            printf(" %-28s |", cell);
        }
        printf("\n");
    }
}

// A "shrinking-lobe" Bezier: pole 1 sits distance d from pole 0, so |D1(0)| = 3d.
static void curveSweep() {
    printf("\n=== CLProps: cubic Bezier, |D1(0)| = 3*d, at u=0 ===\n");
    printf("%-12s | %-34s | %-34s | %-34s\n", "d", NAMES[0], NAMES[1], NAMES[2]);
    const double ds[] = {0.0, 1e-12, 1e-10, 1e-9, 1e-8, 1e-7, 1e-6, 1e-5, 1e-3, 1.0};
    for (double d : ds) {
        TColgp_Array1OfPnt poles(1, 4);
        poles.SetValue(1, gp_Pnt(0, 0, 0));
        poles.SetValue(2, gp_Pnt(d, 0, 0));
        poles.SetValue(3, gp_Pnt(1, 1, 0));
        poles.SetValue(4, gp_Pnt(2, 0, 0));
        Handle(Geom_BezierCurve) bez = new Geom_BezierCurve(poles);
        printf("%-12.0e |", d);
        for (int t = 0; t < 3; ++t) {
            char cell[80];
            try {
                GeomLProp_CLProps p(bez, 0.0, 2, TOLS[t]);
                bool tanDef = p.IsTangentDefined();
                // mirror OCCTCurve3DLocalCurvature: Curvature() with NO IsTangentDefined guard
                char curv[32] = "-";
                try { snprintf(curv, sizeof curv, "%.4g", p.Curvature()); }
                catch (...) { snprintf(curv, sizeof curv, "THROW"); }
                char cen[24] = "-";
                try { gp_Pnt c; p.CentreOfCurvature(c); snprintf(cen, sizeof cen, "ok"); }
                catch (...) { snprintf(cen, sizeof cen, "THROW"); }
                snprintf(cell, sizeof cell, "tan=%d curv=%-10s centre=%s", tanDef ? 1 : 0, curv, cen);
            } catch (...) { snprintf(cell, sizeof cell, "ctor threw"); }
            printf(" %-34s |", cell);
        }
        printf("\n");
    }
}

// Does the *value* of curvature change with Resolution on well-conditioned geometry?
static void wellConditioned() {
    printf("\n=== Well-conditioned sanity: values must be identical across all 3 tolerances ===\n");
    Handle(Geom_Circle) circ = new Geom_Circle(gp_Ax2(gp_Pnt(0,0,0), gp_Dir(0,0,1)), 5.0);
    Handle(Geom_SphericalSurface) sph =
        new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0,0,0), gp_Dir(0,0,1)), 3.0);
    Handle(Geom_CylindricalSurface) cyl =
        new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(0,0,0), gp_Dir(0,0,1)), 2.0);
    for (int t = 0; t < 3; ++t) {
        GeomLProp_CLProps pc(circ, 0.7, 2, TOLS[t]);
        GeomLProp_SLProps ps(sph, 0.3, 0.4, 2, TOLS[t]);
        GeomLProp_SLProps pcy(cyl, 0.3, 1.0, 2, TOLS[t]);
        printf("  %-14s circle k=%.17g | sphere K=%.17g | cyl H=%.17g umbilic=%d\n",
               NAMES[t], pc.Curvature(), ps.GaussianCurvature(), pcy.MeanCurvature(),
               pcy.IsUmbilic() ? 1 : 0);
    }
    // A straight line: curvature 0, centre undefined at every tolerance
    Handle(Geom_Line) line = new Geom_Line(gp_Pnt(0,0,0), gp_Dir(1,0,0));
    for (int t = 0; t < 3; ++t) {
        GeomLProp_CLProps p(line, 1.0, 2, TOLS[t]);
        bool centreThrew = false;
        try { gp_Pnt c; p.CentreOfCurvature(c); } catch (...) { centreThrew = true; }
        bool normalThrew = false;
        try { gp_Dir n; p.Normal(n); } catch (...) { normalThrew = true; }
        printf("  %-14s line   tan=%d curv=%.17g centreThrew=%d normalThrew=%d\n",
               NAMES[t], p.IsTangentDefined() ? 1 : 0, p.Curvature(), centreThrew, normalThrew);
    }
}

// Cone apex exactly (what SurfaceCurvatureParityTests uses) + a sphere pole.
static void degenerateSpots() {
    printf("\n=== Classic degeneracies ===\n");
    Handle(Geom_ConicalSurface) cone =
        new Geom_ConicalSurface(gp_Ax3(gp_Pnt(0,0,0), gp_Dir(0,0,1)), M_PI/6.0, 5.0);
    // apex is at v = -R/sin(angle) = -10
    Handle(Geom_SphericalSurface) sph =
        new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0,0,0), gp_Dir(0,0,1)), 3.0);
    struct { const char* what; Handle(Geom_Surface) s; double u, v; } cases[] = {
        {"cone apex (v=-10)", cone, 0.0, -10.0},
        {"cone near apex (v=-10+1e-9)", cone, 0.0, -10.0 + 1e-9},
        {"cone near apex (v=-10+1e-8)", cone, 0.0, -10.0 + 1e-8},
        {"sphere north pole (v=pi/2)", sph, 0.0, M_PI/2.0},
        {"sphere v=pi/2-1e-9", sph, 0.0, M_PI/2.0 - 1e-9},
    };
    for (auto& c : cases) {
        printf("  %-30s |", c.what);
        for (int t = 0; t < 3; ++t) {
            char cell[48];
            try {
                GeomLProp_SLProps p(c.s, c.u, c.v, 2, TOLS[t]);
                if (p.IsCurvatureDefined())
                    snprintf(cell, sizeof cell, "def K=%.3g", p.GaussianCurvature());
                else
                    snprintf(cell, sizeof cell, "UNDEF");
            } catch (...) { snprintf(cell, sizeof cell, "throw"); }
            printf(" %-18s |", cell);
        }
        printf("\n");
    }
}

int main() {
    printf("Precision::Confusion() = %.17g\n", Precision::Confusion());
#ifdef No_Exception
    printf("No_Exception: DEFINED in this TU (LProp_NotDefined_Raise_if compiles out)\n");
#else
    printf("No_Exception: not defined in this TU (LProp_NotDefined_Raise_if is live)\n");
#endif
    surfaceSweep();
    curveSweep();
    wellConditioned();
    degenerateSpots();
    printf("\nDONE\n");
    return 0;
}
