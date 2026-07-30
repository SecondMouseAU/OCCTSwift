// #494: when does GeomLProp_SLProps::IsUmbilic() actually report true?
// It tests |maxCurv - minCurv| < Epsilon(maxCurv) -- one ULP, not a geometric tolerance.
#include <Geom_SphericalSurface.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_Plane.hxx>
#include <Geom_ToroidalSurface.hxx>
#include <GeomLProp_SLProps.hxx>
#include <Precision.hxx>
#include <gp_Ax3.hxx>
#include <cstdio>
#include <cmath>

static void report(const char* what, const Handle(Geom_Surface)& s, double u, double v) {
    GeomLProp_SLProps p(s, u, v, 2, Precision::Confusion());
    if (!p.IsCurvatureDefined()) { printf("  %-34s (u=%.3g v=%.3g) curvature UNDEFINED\n", what, u, v); return; }
    double mx = p.MaxCurvature(), mn = p.MinCurvature();
    bool umb = false;
    try { umb = p.IsUmbilic(); } catch (...) { printf("  %-34s IsUmbilic threw\n", what); return; }
    printf("  %-34s (u=%.3g v=%.3g) max=%.17g min=%.17g |diff|=%.3g Epsilon=%.3g umbilic=%d\n",
           what, u, v, mx, mn, std::abs(mx - mn), std::abs(Epsilon(mx)), umb ? 1 : 0);
}

int main() {
    Handle(Geom_SphericalSurface) sph = new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0,0,0), gp_Dir(0,0,1)), 3.0);
    Handle(Geom_CylindricalSurface) cyl = new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(0,0,0), gp_Dir(0,0,1)), 5.0);
    Handle(Geom_Plane) pln = new Geom_Plane(gp_Pnt(0,0,0), gp_Dir(0,0,1));
    Handle(Geom_ToroidalSurface) tor = new Geom_ToroidalSurface(gp_Ax3(gp_Pnt(0,0,0), gp_Dir(0,0,1)), 10.0, 3.0);

    printf("Sphere R=3 (analytically umbilic EVERYWHERE):\n");
    for (double v : {0.0, 0.3, 0.5, 1.0, -0.7}) report("sphere", sph, 0.0, v);
    for (double u : {0.5, 1.3, 2.7}) report("sphere off-meridian", sph, u, 0.3);

    printf("\nPlane (both principal curvatures exactly 0):\n");
    for (double u : {0.0, 1.0, -4.0}) report("plane", pln, u, 2.0);

    printf("\nCylinder R=5 (never umbilic):\n");
    for (double v : {0.0, 1.0}) report("cylinder", cyl, 0.3, v);

    printf("\nTorus (never umbilic):\n");
    report("torus", tor, 0.3, 0.7);

    printf("\nDONE\n");
    return 0;
}
