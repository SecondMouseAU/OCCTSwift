// OCCTSwift#522 — how wide is it? GeomConvert_ApproxSurface at GeomAbs_C0 returns a degree-1,
// 2-pole-in-U fit of a sphere that deviates by 20 while reporting IsDone and maxError 1e-4.
// Sweep 7 surface families x all 9 (uCont, vCont) combinations of C0/C1/C2, plus C0/C0 across five
// tolerances, to see which requests are affected. See this directory's README.md.

#include <Geom_BSplineSurface.hxx>
#include <Geom_SphericalSurface.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_ToroidalSurface.hxx>
#include <Geom_ConicalSurface.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <Geom_SurfaceOfRevolution.hxx>
#include <Geom_BezierSurface.hxx>
#include <Geom_Ellipse.hxx>
#include <GeomConvert_ApproxSurface.hxx>
#include <gp_Ax2.hxx>
#include <gp_Ax3.hxx>
#include <gp_Elips.hxx>
#include <NCollection_Array2.hxx>
#include <cstdio>
#include <cmath>
#include <vector>

static const char* contName(GeomAbs_Shape s) {
    switch (s) {
        case GeomAbs_C0: return "C0";
        case GeomAbs_C1: return "C1";
        case GeomAbs_C2: return "C2";
        case GeomAbs_C3: return "C3";
        default: return "??";
    }
}

static int misreports = 0, checked = 0;

static void probe(const char* label, const Handle(Geom_Surface)& s,
                  GeomAbs_Shape uc, GeomAbs_Shape vc, double tol) {
    GeomConvert_ApproxSurface a(s, tol, uc, vc, 8, 8, 100, 0);
    Handle(Geom_BSplineSurface) bs = a.Surface();
    checked++;
    printf("  %-24s u=%s v=%s tol=%-7g isDone=%d maxError=%-13g ", label, contName(uc),
           contName(vc), tol, (int)a.IsDone(), a.MaxError());
    if (bs.IsNull()) { printf("surface=NULL\n"); return; }
    double su0, su1, sv0, sv1;
    s->Bounds(su0, su1, sv0, sv1);
    double worst = 0;
    for (int i = 0; i <= 20; i++) {
        for (int j = 0; j <= 20; j++) {
            double u = su0 + (su1 - su0) * i / 20.0;
            double v = sv0 + (sv1 - sv0) * j / 20.0;
            worst = std::max(worst, s->Value(u, v).Distance(bs->Value(u, v)));
        }
    }
    bool bad = worst > a.MaxError() * 10 + 1e-9;
    if (bad) misreports++;
    printf("uDeg=%d vDeg=%d poles=%dx%d realDev=%-13g%s\n", bs->UDegree(), bs->VDegree(),
           bs->NbUPoles(), bs->NbVPoles(), worst, bad ? "   <<< MISREPORT" : "");
}

int main() {
    gp_Ax3 ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));

    Handle(Geom_Surface) sphere = new Geom_SphericalSurface(ax3, 10.0);
    Handle(Geom_Surface) torus = new Geom_ToroidalSurface(ax3, 20.0, 5.0);
    Handle(Geom_Surface) cyl =
        new Geom_RectangularTrimmedSurface(new Geom_CylindricalSurface(ax3, 5.0),
                                           0.0, 2 * M_PI, -10.0, 10.0);
    Handle(Geom_Surface) cone =
        new Geom_RectangularTrimmedSurface(new Geom_ConicalSurface(ax3, 0.4, 3.0),
                                           0.0, 2 * M_PI, 0.0, 12.0);
    Handle(Geom_Ellipse) profile =
        new Geom_Ellipse(gp_Elips(gp_Ax2(gp_Pnt(20, 0, 0), gp_Dir(0, 1, 0)), 6.0, 2.0));
    Handle(Geom_Surface) revol =
        new Geom_SurfaceOfRevolution(profile, gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)));
    // Half a sphere in U: same surface type, non-periodic U range.
    Handle(Geom_Surface) halfSphere =
        new Geom_RectangularTrimmedSurface(new Geom_SphericalSurface(ax3, 10.0),
                                           0.0, M_PI, -1.0, 1.0);
    NCollection_Array2<gp_Pnt> poles(1, 4, 1, 4);
    for (int i = 1; i <= 4; i++)
        for (int j = 1; j <= 4; j++)
            poles.SetValue(i, j, gp_Pnt(i * 3.0, j * 3.0, (i * j) % 5));
    Handle(Geom_Surface) bez = new Geom_BezierSurface(poles);

    struct Case { const char* label; Handle(Geom_Surface) surf; };
    std::vector<Case> all = {
        {"sphere r=10", sphere},           {"half sphere (U trimmed)", halfSphere},
        {"torus 20/5", torus},             {"trimmed cylinder r=5", cyl},
        {"trimmed cone", cone},            {"revolved ellipse", revol},
        {"bezier 4x4", bez},
    };

    printf("== every (uCont, vCont) combination over C0/C1/C2, tolerance 1e-3 ==\n");
    GeomAbs_Shape conts[3] = {GeomAbs_C0, GeomAbs_C1, GeomAbs_C2};
    for (const Case& c : all) {
        for (GeomAbs_Shape uc : conts)
            for (GeomAbs_Shape vc : conts)
                probe(c.label, c.surf, uc, vc, 1e-3);
        printf("\n");
    }

    printf("== C0/C0 across tolerances ==\n");
    for (const Case& c : all) {
        for (double tol : {1e-1, 1e-2, 1e-3, 1e-5, 1e-7})
            probe(c.label, c.surf, GeomAbs_C0, GeomAbs_C0, tol);
        printf("\n");
    }

    printf("misreported (real deviation more than 10x the reported maxError): %d of %d\n",
           misreports, checked);
    return 0;
}
