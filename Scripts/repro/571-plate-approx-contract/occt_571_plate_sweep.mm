// Ground truth for OCCTSwift#571: what GeomPlate_MakeApprox's Nbmax / dmax / CritOrder /
// Continuity arguments actually do at the six bridge call sites.
//
// Mirrors the bridge's own construction exactly (GeomPlate_BuildPlateSurface with point
// constraints, then GeomPlate_MakeApprox), then sweeps one argument at a time and reports
// a fingerprint of the resulting surface plus every error the API exposes.

#include <GeomPlate_BuildPlateSurface.hxx>
#include <GeomPlate_PointConstraint.hxx>
#include <GeomPlate_CurveConstraint.hxx>
#include <GeomPlate_Surface.hxx>
#include <GeomPlate_MakeApprox.hxx>
#include <Geom_BSplineSurface.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <TopoDS_Edge.hxx>
#include <gp_Pnt.hxx>
#include <NCollection_Sequence.hxx>
#include <Standard_Failure.hxx>

#include <cstdio>
#include <cmath>
#include <vector>
#include <string>

static const char* contName(GeomAbs_Shape s) {
    switch (s) {
        case GeomAbs_C0: return "C0";
        case GeomAbs_G1: return "G1";
        case GeomAbs_C1: return "C1";
        case GeomAbs_G2: return "G2";
        case GeomAbs_C2: return "C2";
        case GeomAbs_C3: return "C3";
        default: return "CN";
    }
}

// A stable, order-independent-ish digest of the control net, so "did the surface move?"
// is one number instead of an eyeball diff.
static double poleFingerprint(const Handle(Geom_BSplineSurface)& s) {
    if (s.IsNull()) return -1.0;
    double acc = 0.0;
    int nu = s->NbUPoles(), nv = s->NbVPoles();
    for (int i = 1; i <= nu; i++)
        for (int j = 1; j <= nv; j++) {
            gp_Pnt p = s->Pole(i, j);
            double w = double(i * 31 + j * 17);
            acc += w * (p.X() + 2.0 * p.Y() + 3.0 * p.Z());
        }
    return acc;
}

struct Dev { double gridMax; double ctrMax; };

// gridMax: worst |bspline - plate| over a sample grid of the plate's real bounds.
// ctrMax : worst |bspline - plate| at the plate's own order-0 constraint UVs, which is
//          precisely the quantity GeomPlate_PlateG0Criterion measures and bounds.
static Dev deviation(const Handle(Geom_BSplineSurface)& bs,
                     const Handle(GeomPlate_Surface)& plate) {
    Dev d{-1.0, -1.0};
    if (bs.IsNull() || plate.IsNull()) return d;
    double u0, u1, v0, v1;
    plate->RealBounds(u0, u1, v0, v1);

    double worst = 0.0;
    const int N = 24;
    for (int i = 0; i <= N; i++) {
        double u = u0 + (u1 - u0) * i / N;
        for (int j = 0; j <= N; j++) {
            double v = v0 + (v1 - v0) * j / N;
            gp_Pnt a, b;
            try { plate->D0(u, v, a); bs->D0(u, v, b); } catch (...) { continue; }
            worst = std::max(worst, a.Distance(b));
        }
    }
    d.gridMax = worst;

    NCollection_Sequence<gp_XY> seq;
    plate->Constraints(seq);
    double cworst = 0.0;
    for (int i = 1; i <= seq.Length(); i++) {
        gp_XY uv = seq.Value(i);
        gp_Pnt a, b;
        try { plate->D0(uv.X(), uv.Y(), a); bs->D0(uv.X(), uv.Y(), b); } catch (...) { continue; }
        cworst = std::max(cworst, a.Distance(b));
    }
    d.ctrMax = cworst;
    return d;
}

static Handle(GeomPlate_Surface) buildPlate(const std::vector<gp_Pnt>& pts,
                                            int degree, int nbPtsOnCur, int nbIter) {
    GeomPlate_BuildPlateSurface builder(degree, nbPtsOnCur, nbIter);
    for (const auto& p : pts)
        builder.Add(new GeomPlate_PointConstraint(p, 0));
    builder.Perform();
    if (!builder.IsDone()) return Handle(GeomPlate_Surface)();
    return builder.Surface();
}

static void runCase(const char* label,
                    const Handle(GeomPlate_Surface)& plate,
                    double tol, int nbmax, int dgmax, double dmax,
                    int critOrder, GeomAbs_Shape cont) {
    printf("  %-34s tol=%-8g Nbmax=%-3d dgmax=%d dmax=%-10g Crit=%-2d cont=%-2s | ",
           label, tol, nbmax, dgmax, dmax, critOrder, contName(cont));
    try {
        GeomPlate_MakeApprox approx(plate, tol, nbmax, dgmax, dmax, critOrder, cont);
        Handle(Geom_BSplineSurface) bs = approx.Surface();
        if (bs.IsNull()) { printf("NULL SURFACE\n"); return; }
        Dev d = deviation(bs, plate);
        printf("uDeg=%d vDeg=%d uP=%-3d vP=%-3d approxErr=%-12.6g critErr=%-12.6g "
               "gridDev=%-12.6g ctrDev=%-12.6g fp=%.10g\n",
               bs->UDegree(), bs->VDegree(), bs->NbUPoles(), bs->NbVPoles(),
               approx.ApproxError(), approx.CriterionError(),
               d.gridMax, d.ctrMax, poleFingerprint(bs));
    } catch (Standard_Failure const& f) {
        printf("THREW: %s\n", f.GetMessageString() ? f.GetMessageString() : "(no message)");
    } catch (...) {
        printf("THREW (unknown)\n");
    }
}

int main() {
    // A saddle: five points that no single low-degree patch fits exactly. Deliberately
    // NOT planar and not a pure quadric, so degree and subdivision both matter.
    std::vector<gp_Pnt> saddle = {
        gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 3), gp_Pnt(10, 10, 0),
        gp_Pnt(0, 10, 3), gp_Pnt(5, 5, -4)
    };
    // A denser, wavier set: forces the criterion to have something to complain about.
    std::vector<gp_Pnt> wavy;
    for (int i = 0; i < 5; i++)
        for (int j = 0; j < 5; j++)
            wavy.push_back(gp_Pnt(i * 4.0, j * 4.0,
                                  4.0 * std::sin(i * 1.3) * std::cos(j * 1.1)));

    struct Fixture { const char* name; std::vector<gp_Pnt> pts; int degree; };
    std::vector<Fixture> fixtures = {
        {"saddle-5pt", saddle, 3},
        {"wavy-25pt",  wavy,   3},
    };

    for (auto& fx : fixtures) {
        printf("\n================ fixture %s (%zu pts) ================\n",
               fx.name, fx.pts.size());
        Handle(GeomPlate_Surface) plate = buildPlate(fx.pts, fx.degree, 15, 2);
        if (plate.IsNull()) { printf("  plate build FAILED\n"); continue; }
        double u0, u1, v0, v1;
        plate->RealBounds(u0, u1, v0, v1);
        NCollection_Sequence<gp_XY> seq; plate->Constraints(seq);
        printf("  plate realBounds U[%g %g] V[%g %g], %d order-0 constraint pts\n",
               u0, u1, v0, v1, seq.Length());
        // How many constraint UVs land strictly inside the enlarged patch domain the
        // criterion actually tests against (EnlargeCoeff = 1.1 scales each bound).
        double e = 1.1, EU0 = e*u0, EU1 = e*u1, EV0 = e*v0, EV1 = e*v1;
        int inside = 0;
        for (int i = 1; i <= seq.Length(); i++) {
            gp_XY p = seq.Value(i);
            if (EU0 < p.X() && p.X() < EU1 && EV0 < p.Y() && p.Y() < EV1) inside++;
        }
        printf("  enlarged patch domain U[%g %g] V[%g %g]; %d/%d constraint pts strictly inside\n",
               EU0, EU1, EV0, EV1, inside, seq.Length());

        const double tol = 0.01;

        printf("\n  -- Q2a: exactly what the bridge does today (Nbmax=1, dmax=tol*10) --\n");
        runCase("bridge sites 1-5", plate, tol, 1, 8, tol * 10, 0, GeomAbs_C1);
        runCase("bridge site 6 (GeomPlateSurface)", plate, tol, 20, 8, tol * 0.1, 0, GeomAbs_C1);

        printf("\n  -- Q2b: at Nbmax=1, does dmax change ANYTHING? --\n");
        for (double dm : {tol * 0.001, tol * 0.1, tol * 10, tol * 1e6})
            runCase("Nbmax=1 dmax sweep", plate, tol, 1, 8, dm, 0, GeomAbs_C1);

        printf("\n  -- Q2c: at Nbmax=1, does CritOrder change anything? --\n");
        for (int co : {-1, 0, 1})
            runCase("Nbmax=1 CritOrder sweep", plate, tol, 1, 8, tol * 10, co, GeomAbs_C1);

        printf("\n  -- Q2d: same sweeps with Nbmax=20 (criterion has room to subdivide) --\n");
        for (double dm : {tol * 0.001, tol * 0.1, tol * 10, tol * 1e6})
            runCase("Nbmax=20 dmax sweep", plate, tol, 20, 8, dm, 0, GeomAbs_C1);
        for (int co : {-1, 0, 1})
            runCase("Nbmax=20 CritOrder sweep", plate, tol, 20, 8, tol * 0.1, co, GeomAbs_C1);

        printf("\n  -- Q3: does the implicit Continuity default matter? --\n");
        for (GeomAbs_Shape c : {GeomAbs_C0, GeomAbs_C1, GeomAbs_C2})
            runCase("Nbmax=1 continuity sweep", plate, tol, 1, 8, tol * 10, 0, c);
        for (GeomAbs_Shape c : {GeomAbs_C0, GeomAbs_C1, GeomAbs_C2})
            runCase("Nbmax=20 continuity sweep", plate, tol, 20, 8, tol * 0.1, 0, c);

        printf("\n  -- does Nbmax alone move the surface? (dmax/Crit/cont fixed) --\n");
        for (int nb : {1, 2, 4, 9, 20})
            runCase("Nbmax sweep", plate, tol, nb, 8, tol * 0.1, 0, GeomAbs_C1);
    }
    printf("\ndone\n");
    return 0;
}
