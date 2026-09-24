// Epic #766 (#1978), kernel parity for BSplineCurve3DManipulationTests.swift,
// BSplineCurveCompletionsTests.swift, BSplineKnotSplittingTests.swift and BSplineMutationsTests.swift.
// Same inputs as the Swift tests, and the same Geom_BSplineCurve / GeomConvert calls the
// OCCTCurve3DBSpline* bridge functions make.
#include <GeomAPI_Interpolate.hxx>
#include <GeomAPI_PointsToBSpline.hxx>
#include <GeomConvert.hxx>
#include <GeomConvert_BSplineCurveKnotSplitting.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_SphericalSurface.hxx>
#include <Standard_Failure.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColStd_Array2OfReal.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <cstdio>
#include <vector>

static Handle(Geom_BSplineCurve) interp(const std::vector<gp_Pnt>& p, bool closed = false)
{
  Handle(TColgp_HArray1OfPnt) a = new TColgp_HArray1OfPnt(1, (int)p.size());
  for (size_t i = 0; i < p.size(); i++)
    a->SetValue((int)i + 1, p[i]);
  GeomAPI_Interpolate ip(a, closed, 1e-6);
  ip.Perform();
  return ip.Curve();
}

static void dump(const char* tag, const Handle(Geom_BSplineCurve)& c)
{
  printf("  %s: degree=%d nbKnots=%d nbPoles=%d rational=%d periodic=%d domain=[%.17g, %.17g]\n", tag,
         c->Degree(), c->NbKnots(), c->NbPoles(), c->IsRational(), c->IsPeriodic(),
         c->FirstParameter(), c->LastParameter());
  printf("    knots:");
  for (int i = 1; i <= c->NbKnots(); i++)
    printf(" %.17g", c->Knot(i));
  printf("\n    mults:");
  for (int i = 1; i <= c->NbKnots(); i++)
    printf(" %d", c->Multiplicity(i));
  printf("\n    poles:");
  for (int i = 1; i <= c->NbPoles(); i++)
    printf(" (%.17g, %.17g, %.17g)", c->Pole(i).X(), c->Pole(i).Y(), c->Pole(i).Z());
  gp_Pnt s = c->StartPoint(), e = c->EndPoint();
  printf("\n    start=(%.17g, %.17g, %.17g) end=(%.17g, %.17g, %.17g)\n", s.X(), s.Y(), s.Z(), e.X(),
         e.Y(), e.Z());
}

int main()
{
  std::vector<gp_Pnt> five = {gp_Pnt(0, 0, 0), gp_Pnt(2, 3, 0), gp_Pnt(5, 5, 0), gp_Pnt(8, 3, 0),
                              gp_Pnt(10, 0, 0)};
  printf("Manipulation fixture: GeomAPI_Interpolate through 5 points\n");
  auto c = interp(five);
  dump("as built", c);
  printf("  Weight(1)=%.17g\n", c->Weight(1));
  double res;
  c->Resolution(0.001, res);
  printf("  Resolution(0.001)=%.17g\n", res);
  {
    auto b = interp(five);
    b->SetPole(3, gp_Pnt(5, 7, 0));
    printf("  SetPole(3,(5,7,0)): Pole(3)=(%.17g, %.17g, %.17g)\n", b->Pole(3).X(), b->Pole(3).Y(),
           b->Pole(3).Z());
  }
  double mid = (c->Knot(1) + c->Knot(c->NbKnots())) / 2;
  {
    auto b = interp(five);
    b->InsertKnot(mid, 1, 1e-6);
    dump("InsertKnot(mid)", b);
    bool r = b->RemoveKnot(2, 0, 1.0);
    printf("  then RemoveKnot(2, 0, 1.0) = %d\n", r);
    dump("after RemoveKnot", b);
  }
  {
    auto   b  = interp(five);
    double d0 = b->FirstParameter(), d1 = b->LastParameter();
    double u1 = d0 + (d1 - d0) * 0.25, u2 = d0 + (d1 - d0) * 0.75;
    gp_Pnt a1 = b->Value(u1), a2 = b->Value(u2);
    b->Segment(u1, u2);
    dump("Segment(25%, 75%)", b);
    printf("    original C(u1)=(%.17g, %.17g) C(u2)=(%.17g, %.17g)\n", a1.X(), a1.Y(), a2.X(), a2.Y());
  }
  {
    auto b = interp(five);
    b->IncreaseDegree(4);
    dump("IncreaseDegree(4)", b);
  }
  {
    auto b = interp(five);
    b->SetNotPeriodic();
    dump("SetNotPeriodic", b);
  }

  printf("Completions: periodic interpolation of (1,0,0) (0,1,0) (-1,0,0) (0,-1,0)\n");
  auto p = interp({gp_Pnt(1, 0, 0), gp_Pnt(0, 1, 0), gp_Pnt(-1, 0, 0), gp_Pnt(0, -1, 0)}, true);
  dump("periodic", p);
  double u = 100.0;
  p->PeriodicNormalization(u);
  printf("  PeriodicNormalization(100)=%.17g\n", u);
  auto np = interp({gp_Pnt(0, 0, 0), gp_Pnt(1, 1, 0), gp_Pnt(2, 0, 0)});
  printf("  non-periodic 3-point curve: IsPeriodic=%d (bridge returns false before normalizing)\n",
         np->IsPeriodic());
  auto g1 = interp({gp_Pnt(0, 0, 0), gp_Pnt(1, 1, 0), gp_Pnt(2, 1, 0), gp_Pnt(3, 0, 0)});
  printf("  IsG1(first, last, 0.01)=%d\n", g1->IsG1(g1->FirstParameter(), g1->LastParameter(), 0.01));

  printf("KnotSplitting: 8-point interpolation, toBSpline (GeomConvert::CurveToBSplineCurve)\n");
  auto k8 = interp({gp_Pnt(0, 0, 0), gp_Pnt(10, 5, 0), gp_Pnt(20, -5, 0), gp_Pnt(30, 10, 0),
                    gp_Pnt(40, -10, 0), gp_Pnt(50, 3, 0), gp_Pnt(60, -3, 0), gp_Pnt(70, 0, 0)});
  Handle(Geom_BSplineCurve) k8b = GeomConvert::CurveToBSplineCurve(k8);
  for (int order : {0, 3})
  {
    GeomConvert_BSplineCurveKnotSplitting sp(k8b, order);
    printf("  continuity order %d: NbSplits=%d values:", order, sp.NbSplits());
    for (int i = 1; i <= sp.NbSplits(); i++)
      printf(" %.17g", k8b->Knot(sp.SplitValue(i)));
    printf("\n");
  }

  printf("Mutations: GeomAPI_PointsToBSpline(3, 8, C2, 1e-3) through (0,0,0) (1,1,0) (2,0,0) (3,1,0)\n");
  TColgp_Array1OfPnt fp(1, 4);
  fp(1) = gp_Pnt(0, 0, 0);
  fp(2) = gp_Pnt(1, 1, 0);
  fp(3) = gp_Pnt(2, 0, 0);
  fp(4) = gp_Pnt(3, 1, 0);
  Handle(Geom_BSplineCurve) fit = GeomAPI_PointsToBSpline(fp, 3, 8, GeomAbs_C2, 1e-3).Curve();
  dump("fit", fit);
  printf("    knotSequence:");
  for (int i = 1; i <= fit->KnotSequence().Length(); i++)
    printf(" %.17g", fit->KnotSequence()(i));
  printf("\n    weights:");
  for (int i = 1; i <= fit->NbPoles(); i++)
    printf(" %.17g", fit->Weight(i));
  int i1 = 0, i2 = 0, k = 0;
  fit->LocateU(0.5, 1e-10, i1, i2);
  fit->LocateU(0.5, 1e-10, k, k);
  printf("\n  LocateU(0.5): I1=%d I2=%d, aliased (bridge)=%d\n", i1, i2, k);
  printf("  Geom_BSplineCurve::MaxDegree()=%d\n", Geom_BSplineCurve::MaxDegree());

  Handle(Geom_SphericalSurface) sph = new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp::DZ()), 5);
  Handle(Geom_BSplineSurface)   sb  = GeomConvert::SurfaceToBSplineSurface(sph);
  printf("  sphere r=5 -> BSpline: NbUKnots=%d NbVKnots=%d NbUPoles=%d NbVPoles=%d rational=%d\n",
         sb->NbUKnots(), sb->NbVKnots(), sb->NbUPoles(), sb->NbVPoles(), sb->IsURational());
  printf("    uKnots:");
  for (int i = 1; i <= sb->NbUKnots(); i++)
    printf(" %.17g", sb->UKnot(i));
  printf("\n    vKnots:");
  for (int i = 1; i <= sb->NbVKnots(); i++)
    printf(" %.17g", sb->VKnot(i));
  printf("\n    weight(1,1)=%.17g weight(2,2)=%.17g\n", sb->Weight(1, 1), sb->Weight(2, 2));
  return 0;
}
