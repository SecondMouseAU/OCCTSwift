// #494 follow-up probe: what do the centre-of-curvature / normal accessors actually produce in the
// band where Curvature() returns RealLast() (significant derivative order > 1)?
#include <Geom_BezierCurve.hxx>
#include <GeomLProp_CLProps.hxx>
#include <GeomLProp_SLProps.hxx>
#include <Geom_ConicalSurface.hxx>
#include <Precision.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <gp_Ax3.hxx>
#include <cstdio>
#include <cmath>

static const double TOLS[3] = {1e-10, Precision::Confusion(), 1e-6};
static const char*  NAMES[3] = {"1e-10", "Confusion", "1e-6"};

int main() {
    printf("=== cubic Bezier, |D1(0)|=3d, u=0: full accessor behaviour ===\n");
    const double ds[] = {0.0, 1e-12, 1e-10, 1e-9, 1e-8, 1e-7, 1e-6, 1e-3};
    for (double d : ds) {
        TColgp_Array1OfPnt poles(1, 4);
        poles.SetValue(1, gp_Pnt(0, 0, 0));
        poles.SetValue(2, gp_Pnt(d, 0, 0));
        poles.SetValue(3, gp_Pnt(1, 1, 0));
        poles.SetValue(4, gp_Pnt(2, 0, 0));
        Handle(Geom_BezierCurve) bez = new Geom_BezierCurve(poles);
        for (int t = 0; t < 3; ++t) {
            GeomLProp_CLProps p(bez, 0.0, 2, TOLS[t]);
            double curv = -1;
            bool curvThrew = false;
            try { curv = p.Curvature(); } catch (...) { curvThrew = true; }
            char cen[96] = "THROW";
            try {
                gp_Pnt c;
                p.CentreOfCurvature(c);
                snprintf(cen, sizeof cen, "(%.4g, %.4g, %.4g)", c.X(), c.Y(), c.Z());
            } catch (...) {}
            char nrm[64] = "THROW";
            try {
                gp_Dir n; p.Normal(n);
                snprintf(nrm, sizeof nrm, "(%.3g,%.3g,%.3g)", n.X(), n.Y(), n.Z());
            } catch (...) {}
            printf("  d=%-8.0e %-10s tan=%d curv=%-12.4g%s centre=%-30s normal=%s\n",
                   d, NAMES[t], p.IsTangentDefined() ? 1 : 0, curv,
                   curvThrew ? "(THREW)" : "       ", cen, nrm);
        }
        printf("\n");
    }

    printf("=== Is RealLast() curvature reachable from the *canonical* bridge gate? ===\n");
    printf("RealLast() = %.4g ; Confusion = %.4g\n", RealLast(), Precision::Confusion());
    printf("canonical gate 'curv < Confusion' rejects RealLast? %s\n",
           (RealLast() < Precision::Confusion()) ? "yes" : "NO -> it proceeds");
    printf("local gate 'curv > 1e-10' accepts RealLast? %s\n",
           (RealLast() > 1e-10) ? "YES -> it proceeds" : "no");

    // Surface: does an UNDEFINED curvature leave Max/Min/Mean/Gaussian readable at all?
    printf("\n=== SLProps accessors when IsCurvatureDefined() is false (cone v=1e-8) ===\n");
    Handle(Geom_ConicalSurface) cone =
        new Geom_ConicalSurface(gp_Ax3(gp_Pnt(0,0,0), gp_Dir(0,0,1)), M_PI/6.0, 0.0);
    for (int t = 0; t < 3; ++t) {
        GeomLProp_SLProps p(cone, 0.0, 1e-8, 2, TOLS[t]);
        bool def = p.IsCurvatureDefined();
        char vals[128] = "n/a";
        bool threw = false;
        try {
            snprintf(vals, sizeof vals, "K=%.4g H=%.4g max=%.4g min=%.4g",
                     p.GaussianCurvature(), p.MeanCurvature(), p.MaxCurvature(), p.MinCurvature());
        } catch (...) { threw = true; }
        printf("  %-10s defined=%d  %s%s\n", NAMES[t], def ? 1 : 0,
               threw ? "accessors THREW" : vals, threw ? "" : "");
    }
    printf("\nDONE\n");
    return 0;
}
