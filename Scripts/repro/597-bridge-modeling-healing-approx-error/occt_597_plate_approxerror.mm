// Reproduce OCCTSurfacePlateThrough's EXACT two-stage pipeline (GeomPlate_BuildPlateSurface(3,15,2)
// then occtPlateApproxSurface's current logic: maxDegree=8, maxSegments=20, dmax=tolerance*0.1,
// CritOrder=0, C1) on the #571 test fixture (wavyPoints, 5x5=25 points), and report ApproxError()
// at both the tight (0.01) and loose (0.1) tolerances the Issue571PlateApproxTests suite uses.
#include <GeomPlate_BuildPlateSurface.hxx>
#include <GeomPlate_PointConstraint.hxx>
#include <GeomPlate_Surface.hxx>
#include <GeomPlate_MakeApprox.hxx>
#include <Geom_BSplineSurface.hxx>
#include <gp_Pnt.hxx>
#include <cstdio>
#include <cmath>
#include <vector>

int main() {
    std::vector<gp_Pnt> pts;
    for (int i = 0; i < 5; i++)
        for (int j = 0; j < 5; j++)
            pts.push_back(gp_Pnt(i * 4.0, j * 4.0, 4.0 * std::sin(i * 1.3) * std::cos(j * 1.1)));

    GeomPlate_BuildPlateSurface b(3, 15, 2);   // degree=3 (Surface.plateThrough's default), 15, 2
    for (auto& p : pts) b.Add(new GeomPlate_PointConstraint(p, 0));
    b.Perform();
    if (!b.IsDone()) { printf("BuildPlateSurface not done\n"); return 1; }
    Handle(GeomPlate_Surface) plate = b.Surface();

    for (double tol : {0.01, 0.05, 0.1, 0.0005}) {
        int32_t nbMax = 20, dgMax = 8;
        double dmax = tol * 0.1;
        try {
            GeomPlate_MakeApprox approx(plate, tol, nbMax, dgMax, dmax, 0, GeomAbs_C1);
            Handle(Geom_BSplineSurface) s = approx.Surface();
            double err = approx.ApproxError();
            printf("tol=%-9g approxErr=%-12g critErr=%-12g uP=%-4d vP=%-4d %s\n",
                   tol, err, approx.CriterionError(),
                   s.IsNull() ? -1 : s->NbUPoles(), s.IsNull() ? -1 : s->NbVPoles(),
                   err > tol ? "EXCEEDS" : "within");
        } catch (...) {
            printf("tol=%-9g THREW\n", tol);
        }
    }
    return 0;
}
