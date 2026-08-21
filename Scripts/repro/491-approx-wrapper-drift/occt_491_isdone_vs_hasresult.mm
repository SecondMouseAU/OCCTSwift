// OCCTSwift#491, are the two documented wrapper divergences observable? See this directory's
// README.md for the conclusions.
//
//  (1) GeomConvert_ApproxCurve: is there an input where HasResult() is true but IsDone() is
//      false? That is the exact case where OCCTCurve3DApproximate (gates !IsDone -> nullptr)
//      and OCCTGeomConvertApproxCurve (gates HasResult -> returns the fit) disagree.
//  (2) GeomConvert_ApproxSurface: does PrecisCode 0 vs 1 actually change the resulting
//      BSpline (knots/poles/degree/maxError) for identical other arguments?

#include <Geom_Circle.hxx>
#include <Geom_Ellipse.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_SphericalSurface.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_ToroidalSurface.hxx>
#include <Geom_ConicalSurface.hxx>
#include <Geom_OffsetCurve.hxx>
#include <GeomConvert_ApproxCurve.hxx>
#include <GeomConvert_ApproxSurface.hxx>
#include <gp_Ax2.hxx>
#include <gp_Ax3.hxx>
#include <gp_Circ.hxx>
#include <gp_Elips.hxx>
#include <gp_Sphere.hxx>
#include <gp_Cylinder.hxx>
#include <gp_Torus.hxx>
#include <gp_Cone.hxx>

#include <cstdio>
#include <string>

static void probeCurve(const char* label, const Handle(Geom_Curve)& c,
                       double tol, GeomAbs_Shape order, int maxSeg, int maxDeg) {
    printf("  %-42s tol=%-9g seg=%-3d deg=%-3d ", label, tol, maxSeg, maxDeg);
    try {
        GeomConvert_ApproxCurve approx(c, tol, order, maxSeg, maxDeg);
        Handle(Geom_BSplineCurve) bs = approx.Curve();
        printf("IsDone=%d HasResult=%d maxError=%-12g curve=%s",
               (int)approx.IsDone(), (int)approx.HasResult(), approx.MaxError(),
               bs.IsNull() ? "NULL" : "ok");
        if (!bs.IsNull()) {
            printf(" (deg=%d poles=%d knots=%d)", bs->Degree(), bs->NbPoles(), bs->NbKnots());
        }
        if (approx.HasResult() && !approx.IsDone()) printf("   <<< DIVERGES");
        printf("\n");
    } catch (Standard_Failure const& f) {
        printf("threw: %s\n", f.GetMessageString() ? f.GetMessageString() : "?");
    } catch (...) {
        printf("threw: unknown\n");
    }
}

static void probeSurface(const char* label, const Handle(Geom_Surface)& s,
                         double tol, GeomAbs_Shape cont, int maxDeg, int maxSeg) {
    printf("  %-28s tol=%-9g cont=%d deg=%-3d seg=%-4d\n", label, tol, (int)cont, maxDeg, maxSeg);
    for (int precis = 0; precis <= 1; precis++) {
        printf("      PrecisCode=%d  ", precis);
        try {
            GeomConvert_ApproxSurface approx(s, tol, cont, cont, maxDeg, maxDeg, maxSeg, precis);
            Handle(Geom_BSplineSurface) bs = approx.Surface();
            printf("IsDone=%d HasResult=%d maxError=%-14.9g ",
                   (int)approx.IsDone(), (int)approx.HasResult(), approx.MaxError());
            if (bs.IsNull()) {
                printf("surface=NULL\n");
            } else {
                printf("uDeg=%d vDeg=%d uPoles=%d vPoles=%d uKnots=%d vKnots=%d\n",
                       bs->UDegree(), bs->VDegree(), bs->NbUPoles(), bs->NbVPoles(),
                       bs->NbUKnots(), bs->NbVKnots());
            }
        } catch (Standard_Failure const& f) {
            printf("threw: %s\n", f.GetMessageString() ? f.GetMessageString() : "?");
        } catch (...) {
            printf("threw: unknown\n");
        }
    }
}

int main() {
    gp_Ax2 ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    gp_Ax3 ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));

    printf("== (1) GeomConvert_ApproxCurve: IsDone vs HasResult ==\n");
    Handle(Geom_Circle) circle = new Geom_Circle(gp_Circ(ax, 10.0));
    Handle(Geom_Ellipse) ellipse = new Geom_Ellipse(gp_Elips(ax, 50.0, 1.0));

    // The bridge's own default-ish arguments first (Curve3D.approximated defaults: 1e-3, C2, 100, 8).
    probeCurve("circle r=10, defaults", circle, 1e-3, GeomAbs_C2, 100, 8);
    // Starve the approximation: too few segments and/or too low a degree for the tolerance.
    probeCurve("circle r=10, 1 segment deg 3", circle, 1e-9, GeomAbs_C0, 1, 3);
    probeCurve("circle r=10, 1 segment deg 3 tol 1e-6", circle, 1e-6, GeomAbs_C0, 1, 3);
    probeCurve("circle r=10, 1 segment deg 3 tol 1e-4", circle, 1e-4, GeomAbs_C0, 1, 3);
    probeCurve("circle r=10, 2 segments deg 3", circle, 1e-9, GeomAbs_C0, 2, 3);
    probeCurve("circle r=10, tol 1e-15 deg 8", circle, 1e-15, GeomAbs_C2, 100, 8);
    probeCurve("ellipse 50x1, 1 segment deg 3", ellipse, 1e-9, GeomAbs_C0, 1, 3);
    probeCurve("ellipse 50x1, tol 1e-12 deg 4", ellipse, 1e-12, GeomAbs_C2, 4, 4);
    // Offset of a highly eccentric ellipse: no exact BSpline exists.
    Handle(Geom_OffsetCurve) offs = new Geom_OffsetCurve(ellipse, 0.5, gp_Dir(0, 0, 1));
    probeCurve("offset(ellipse 50x1) d=0.5 tol 1e-12", offs, 1e-12, GeomAbs_C2, 100, 8);
    probeCurve("offset(ellipse 50x1) 1 seg deg 3", offs, 1e-9, GeomAbs_C0, 1, 3);

    printf("\n== (2) GeomConvert_ApproxSurface: PrecisCode 0 vs 1 ==\n");
    Handle(Geom_SphericalSurface) sphere = new Geom_SphericalSurface(ax3, 10.0);
    Handle(Geom_CylindricalSurface) cyl = new Geom_CylindricalSurface(ax3, 5.0);
    Handle(Geom_ToroidalSurface) torus = new Geom_ToroidalSurface(ax3, 20.0, 5.0);
    Handle(Geom_ConicalSurface) cone = new Geom_ConicalSurface(ax3, 0.4, 3.0);

    // Surface.approximated's post-#406 defaults: tol 1e-3, C2, maxDegree 8, maxSegments 100.
    probeSurface("sphere r=10", sphere, 1e-3, GeomAbs_C2, 8, 100);
    probeSurface("sphere r=10 (tight)", sphere, 1e-7, GeomAbs_C2, 8, 100);
    probeSurface("sphere r=10 (old tol/deg)", sphere, 1e-2, GeomAbs_C2, 10, 100);
    probeSurface("cylinder r=5", cyl, 1e-3, GeomAbs_C2, 8, 100);
    probeSurface("torus 20/5", torus, 1e-3, GeomAbs_C2, 8, 100);
    probeSurface("torus 20/5 (tight)", torus, 1e-9, GeomAbs_C2, 8, 100);
    probeSurface("cone", cone, 1e-3, GeomAbs_C2, 8, 100);
    probeSurface("sphere, starved seg=1 deg=3", sphere, 1e-9, GeomAbs_C0, 3, 1);

    printf("\ndone\n");
    return 0;
}
