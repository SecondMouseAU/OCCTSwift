// Does ApproxError() ever diverge from the caller-visible contract (max distance from the
// ORIGINAL CONSTRAINT POINTS to the final fitted BSpline surface -- what Surface.plateThrough's
// own doc comment promises, and what Issue571PlateApproxTests actually checks)? If ApproxError()
// can be large while the point-projection deviation stays small, ApproxError() is measuring
// something the public API never promised (fidelity of the final BSpline to an invisible
// intermediate GeomPlate_Surface, not to the caller's own input), and gating on it would reject
// results that are actually fine by the contract that matters.
#include <GeomPlate_BuildPlateSurface.hxx>
#include <GeomPlate_PointConstraint.hxx>
#include <GeomPlate_Surface.hxx>
#include <GeomPlate_MakeApprox.hxx>
#include <Geom_BSplineSurface.hxx>
#include <GeomAPI_ProjectPointOnSurf.hxx>
#include <gp_Pnt.hxx>
#include <cstdio>
#include <cmath>
#include <vector>

int main() {
    std::vector<gp_Pnt> pts;
    for (int i = 0; i < 5; i++)
        for (int j = 0; j < 5; j++)
            pts.push_back(gp_Pnt(i * 4.0, j * 4.0, 4.0 * std::sin(i * 1.3) * std::cos(j * 1.1)));

    GeomPlate_BuildPlateSurface b(3, 15, 2);
    for (auto& p : pts) b.Add(new GeomPlate_PointConstraint(p, 0));
    b.Perform();
    Handle(GeomPlate_Surface) plate = b.Surface();

    for (double tol : {0.01, 0.05, 0.1, 0.0005}) {
        int32_t nbMax = 20, dgMax = 8;
        double dmax = tol * 0.1;
        GeomPlate_MakeApprox approx(plate, tol, nbMax, dgMax, dmax, 0, GeomAbs_C1);
        Handle(Geom_BSplineSurface) s = approx.Surface();
        double approxErr = approx.ApproxError();

        double worst = 0;
        for (auto& p : pts) {
            GeomAPI_ProjectPointOnSurf proj(p, s);
            if (proj.NbPoints() > 0) worst = std::max(worst, proj.LowerDistance());
        }
        printf("tol=%-9g approxErr=%-12g worstPointDeviation=%-12g uP=%-4d %s (approxErr %s tol, worstDev %s tol)\n",
               tol, approxErr, worst, s->NbUPoles(),
               approxErr > tol ? "APPROXERR-EXCEEDS" : "approxErr-ok",
               approxErr > tol ? "EXCEEDS" : "<=", worst > tol ? "EXCEEDS" : "<=");
    }
    return 0;
}
