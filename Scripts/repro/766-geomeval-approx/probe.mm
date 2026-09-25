// Epic #766, GeomConvertApproxSurfaceTests.swift and the seven GeomEval*Tests.swift files: kernel
// parity for the 26 tests. Same inputs, straight to GeomConvert_ApproxSurface (as
// occtApproxSurface calls it: C2/C2, degree 8, 100 segments, PrecisCode 0), the GeomEval_*
// surfaces and curves on the default axes the bridge uses (origin, +Z), and ExtremaPC_Curve's
// PerformWithEndpoints for the helix distance (OCCTExtremaPCMinDistance).
#include <ExtremaPC_Curve.hxx>
#include <GeomConvert_ApproxSurface.hxx>
#include <GeomEval_CircularHelicoidSurface.hxx>
#include <GeomEval_CircularHelixCurve.hxx>
#include <GeomEval_EllipsoidSurface.hxx>
#include <GeomEval_HypParaboloidSurface.hxx>
#include <GeomEval_HyperboloidSurface.hxx>
#include <GeomEval_ParaboloidSurface.hxx>
#include <GeomEval_SineWaveCurve.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_SphericalSurface.hxx>
#include <cmath>
#include <cstdio>

static void p3(const char* tag, const gp_Pnt& p)
{
  printf("%s=(%.17g, %.17g, %.17g)\n", tag, p.X(), p.Y(), p.Z());
}

int main()
{
  gp_Ax3 ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  gp_Ax2 ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  {
    Handle(Geom_SphericalSurface) s = new Geom_SphericalSurface(ax3, 10);
    GeomConvert_ApproxSurface     a(s, 1e-3, GeomAbs_C2, GeomAbs_C2, 8, 8, 100, 0);
    printf("approxSphere: IsDone=%d HasResult=%d MaxError=%.17g", a.IsDone(), a.HasResult(), a.MaxError());
    if (a.HasResult())
    {
      gp_Pnt q = a.Surface()->Value(1.0, 0.5);
      printf(" |S(1,0.5)|=%.17g", q.Distance(gp_Pnt(0, 0, 0)));
    }
    printf("\n");
  }
  {
    GeomEval_CircularHelicoidSurface h(ax3, 5.0);
    p3("circularHelicoidD0 (u=0,v=1)", h.Value(0.0, 1.0));
    p3("circularHelicoidSurfaceCreate S(pi/2, 2)", h.Value(M_PI / 2, 2.0));
  }
  {
    GeomEval_CircularHelixCurve h(ax2, 5.0, 10.0);
    p3("helixD0AtZero", h.Value(0.0));
    p3("helixD0AtPi", h.Value(M_PI));
    gp_Pnt p;
    gp_Vec d1, d2;
    h.D2(0.0, p, d1, d2);
    printf("helixD1/D2 at 0: P=(%.17g, %.17g, %.17g) D1=(%.17g, %.17g, %.17g) D2=(%.17g, %.17g, %.17g)\n", p.X(), p.Y(),
           p.Z(), d1.X(), d1.Y(), d1.Z(), d2.X(), d2.Y(), d2.Z());
    Handle(GeomEval_CircularHelixCurve) hc = new GeomEval_CircularHelixCurve(ax2, 5.0, 10.0);
    ExtremaPC_Curve                     e(hc);
    const auto&                         r = e.PerformWithEndpoints(gp_Pnt(10, 0, 0), 1e-9);
    printf("helixCurveMinDistance: IsDone=%d NbExt=%d min=%.17g\n", r.IsDone(), r.NbExt(), std::sqrt(r.MinSquareDistance()));
    printf("helixCurve domain=[%.17g, %.17g]\n", hc->FirstParameter(), hc->LastParameter());
    GeomEval_CircularHelixCurve h3(ax2, 3.0, 6.0);
    p3("helixCurveCreate (r=3, pitch=6) C(pi)", h3.Value(M_PI));
  }
  {
    GeomEval_EllipsoidSurface e(ax3, 3, 4, 5);
    p3("ellipsoidD0AtZeroZero", e.Value(0, 0));
    p3("ellipsoidD0AtPoles", e.Value(0, M_PI / 2));
    GeomEval_EllipsoidSurface e2(ax3, 2, 3, 4);
    p3("ellipsoidSurfaceCreate (2,3,4) S(0.3,0.4)", e2.Value(0.3, 0.4));
  }
  {
    GeomEval_HyperboloidSurface h1(ax3, 2, 3, GeomEval_HyperboloidSurface::SheetMode::OneSheet);
    GeomEval_HyperboloidSurface h2(ax3, 2, 3, GeomEval_HyperboloidSurface::SheetMode::TwoSheets);
    p3("hyperboloidOneSheetD0 (0,0)", h1.Value(0, 0));
    p3("hyperboloidTwoSheets D0 (0,0)", h2.Value(0, 0));
    p3("hyperboloidSurfaceCreate one sheet S(0.5,0.3)", h1.Value(0.5, 0.3));
    p3("hyperboloidTwoSheetsCreate S(0.5,0.3)", h2.Value(0.5, 0.3));
  }
  {
    GeomEval_HypParaboloidSurface h(ax3, 2, 3);
    p3("hypParaboloidD0AtOrigin", h.Value(0, 0));
    p3("hypParaboloidD0AwayFromOrigin (2,0)", h.Value(2, 0));
    p3("hypParaboloidSurfaceCreate S(1,2)", h.Value(1, 2));
  }
  {
    GeomEval_ParaboloidSurface p(ax3, 2.0);
    p3("paraboloidD0 (0,1)", p.Value(0, 1));
    p3("paraboloidSurfaceCreate S(0.5,2)", p.Value(0.5, 2));
  }
  {
    GeomEval_SineWaveCurve s(ax2, 2.0, 3.0, 0.0);
    p3("sineWaveD0AtZero", s.Value(0));
    p3("sineWaveD0AtPiOver2 (t=pi/6)", s.Value(M_PI / 6));
    gp_Pnt p;
    gp_Vec d1;
    s.D1(0, p, d1);
    printf("sineWaveD1 at 0: D1=(%.17g, %.17g, %.17g)\n", d1.X(), d1.Y(), d1.Z());
    GeomEval_SineWaveCurve s1(ax2, 1.0, 2.0, 0.0);
    p3("sineWaveCurveCreate (A=1, w=2) C(1)", s1.Value(1));
    GeomEval_SineWaveCurve s2(ax2, 1.0, 1.0, M_PI / 2);
    p3("sineWaveWithPhase (0)", s2.Value(0));
  }
  return 0;
}
