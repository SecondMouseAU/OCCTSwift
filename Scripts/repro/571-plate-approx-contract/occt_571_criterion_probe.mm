// OCCTSwift#571 probe 2: which GeomAbs_Shape values does GeomPlate_MakeApprox actually accept,
// and does the criterion ever act at Nbmax=1 even when it is violated?

#include <GeomPlate_BuildPlateSurface.hxx>
#include <GeomPlate_PointConstraint.hxx>
#include <GeomPlate_Surface.hxx>
#include <GeomPlate_MakeApprox.hxx>
#include <Geom_BSplineSurface.hxx>
#include <gp_Pnt.hxx>
#include <Standard_Failure.hxx>
#include <cstdio>
#include <cmath>
#include <vector>

static const char* nm(GeomAbs_Shape s) {
    switch (s) {
        case GeomAbs_C0: return "C0"; case GeomAbs_G1: return "G1"; case GeomAbs_C1: return "C1";
        case GeomAbs_G2: return "G2"; case GeomAbs_C2: return "C2"; case GeomAbs_C3: return "C3";
        default: return "CN";
    }
}

int main() {
    std::vector<gp_Pnt> pts;
    for (int i = 0; i < 5; i++)
        for (int j = 0; j < 5; j++)
            pts.push_back(gp_Pnt(i * 4.0, j * 4.0, 4.0 * std::sin(i * 1.3) * std::cos(j * 1.1)));

    GeomPlate_BuildPlateSurface b(3, 15, 2);
    for (auto& p : pts) b.Add(new GeomPlate_PointConstraint(p, 0));
    b.Perform();
    Handle(GeomPlate_Surface) plate = b.Surface();

    printf("=== which Continuity values does GeomPlate_MakeApprox accept? ===\n");
    for (GeomAbs_Shape c : {GeomAbs_C0, GeomAbs_G1, GeomAbs_C1, GeomAbs_G2, GeomAbs_C2, GeomAbs_C3, GeomAbs_CN}) {
        printf("  cont=%-2s -> ", nm(c));
        try {
            GeomPlate_MakeApprox a(plate, 0.01, 20, 8, 0.001, 0, c);
            Handle(Geom_BSplineSurface) s = a.Surface();
            if (s.IsNull()) printf("NULL surface\n");
            else printf("OK  uDeg=%d vDeg=%d uP=%d vP=%d approxErr=%g\n",
                        s->UDegree(), s->VDegree(), s->NbUPoles(), s->NbVPoles(), a.ApproxError());
        } catch (Standard_Failure const& f) {
            printf("THREW: %s\n", f.GetMessageString() ? f.GetMessageString() : "(no message)");
        } catch (...) { printf("THREW (unknown)\n"); }
    }

    printf("\n=== at Nbmax=1, is the criterion VIOLATED yet still ignored? ===\n");
    printf("(seuil = max(Tol3d, 10*dmax); criterion is satisfied iff critErr < seuil)\n");
    for (double dmax : {1e-9, 1e-6, 1e-3}) {
        double tol = 0.01, seuil = std::max(tol, 10 * dmax);
        try {
            GeomPlate_MakeApprox a(plate, tol, 1, 8, dmax, 0, GeomAbs_C1);
            Handle(Geom_BSplineSurface) s = a.Surface();
            printf("  Nbmax=1 dmax=%-8g seuil=%-8g critErr=%-12g violated=%-3s | uP=%d vP=%d\n",
                   dmax, seuil, a.CriterionError(),
                   (a.CriterionError() >= seuil) ? "YES" : "no",
                   s->NbUPoles(), s->NbVPoles());
        } catch (...) { printf("  THREW\n"); }
    }
    printf("  (same for Nbmax=2, where subdivision IS permitted)\n");
    for (double dmax : {1e-9, 1e-6, 1e-3}) {
        double tol = 0.01, seuil = std::max(tol, 10 * dmax);
        try {
            GeomPlate_MakeApprox a(plate, tol, 2, 8, dmax, 0, GeomAbs_C1);
            Handle(Geom_BSplineSurface) s = a.Surface();
            printf("  Nbmax=2 dmax=%-8g seuil=%-8g critErr=%-12g violated=%-3s | uP=%d vP=%d\n",
                   dmax, seuil, a.CriterionError(),
                   (a.CriterionError() >= seuil) ? "YES" : "no",
                   s->NbUPoles(), s->NbVPoles());
        } catch (...) { printf("  THREW\n"); }
    }

    printf("\n=== does raising Nbmax keep helping, and where does it stop? ===\n");
    for (int nb : {1, 2, 3, 5, 10, 20, 50, 100}) {
        try {
            GeomPlate_MakeApprox a(plate, 0.01, nb, 8, 0.001, 0, GeomAbs_C1);
            Handle(Geom_BSplineSurface) s = a.Surface();
            printf("  Nbmax=%-4d uP=%-4d vP=%-4d approxErr=%-12g critErr=%-12g\n",
                   nb, s->NbUPoles(), s->NbVPoles(), a.ApproxError(), a.CriterionError());
        } catch (...) { printf("  Nbmax=%-4d THREW\n", nb); }
    }
    return 0;
}
