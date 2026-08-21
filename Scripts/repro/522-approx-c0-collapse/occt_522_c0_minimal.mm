// OCCTSwift#522, minimal case: GeomConvert_ApproxSurface at GeomAbs_C0 returns a degree-1
// collapse of a sphere (2 poles across its full longitude, deviating by the sphere's own diameter)
// while reporting IsDone and a maxError of 1e-4. C1 and C2 on the same surface are correct.
// See this directory's README.md.
#include <Geom_BSplineSurface.hxx>
#include <Geom_SphericalSurface.hxx>
#include <GeomConvert_ApproxSurface.hxx>
#include <gp_Ax3.hxx>
#include <cstdio>
#include <cmath>

static void probe(GeomAbs_Shape cont, const char* name, int precis) {
    gp_Ax3 ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    Handle(Geom_SphericalSurface) sphere = new Geom_SphericalSurface(ax3, 10.0);
    GeomConvert_ApproxSurface a(sphere, 1e-3, cont, cont, 8, 8, 100, precis);
    Handle(Geom_BSplineSurface) bs = a.Surface();
    printf("cont=%-3s precis=%d isDone=%d hasResult=%d maxError=%-14g", name, precis,
           (int)a.IsDone(), (int)a.HasResult(), a.MaxError());
    if (bs.IsNull()) { printf(" surface=NULL\n"); return; }
    printf(" uDeg=%d vDeg=%d uPoles=%d vPoles=%d", bs->UDegree(), bs->VDegree(),
           bs->NbUPoles(), bs->NbVPoles());
    double u0, u1, v0, v1, su0, su1, sv0, sv1;
    bs->Bounds(u0, u1, v0, v1);
    sphere->Bounds(su0, su1, sv0, sv1);
    printf("\n    fit domain U[%g %g] V[%g %g]   source U[%g %g] V[%g %g]\n",
           u0, u1, v0, v1, su0, su1, sv0, sv1);

    double worst = 0; double wu = 0, wv = 0;
    for (int i = 0; i <= 20; i++) {
        for (int j = 0; j <= 20; j++) {
            double u = su0 + (su1 - su0) * i / 20.0;
            double v = sv0 + (sv1 - sv0) * j / 20.0;
            gp_Pnt p = sphere->Value(u, v);
            gp_Pnt q = bs->Value(u, v);
            double d = p.Distance(q);
            if (d > worst) { worst = d; wu = u; wv = v; }
        }
    }
    printf("    real max deviation over the source domain: %g  (at u=%g v=%g)\n", worst, wu, wv);
}

int main() {
    probe(GeomAbs_C0, "C0", 0);
    probe(GeomAbs_C0, "C0", 1);
    probe(GeomAbs_C1, "C1", 0);
    probe(GeomAbs_C2, "C2", 0);
    return 0;
}
