// Epic #766, BSplineSurfaceManipulationTests.swift, BSplineSurfaceRemoveUKnotTests.swift and
// BSplineSurfaceRemoveVKnotTests.swift: kernel parity for the fourteen tests.
//  - makeCylinderDerivedBSplineSurface(): as the fixture stood, GeomConvert::SurfaceToBSplineSurface
//    of the untrimmed radius-5 Geom_CylindricalSurface, which throws "infinite surface"; as it is
//    now, the same cylinder trimmed to [0, 2 pi] x [0, 10] with Geom_RectangularTrimmedSurface
//    (OCCTSurfaceTrim) first.
//  - makeSinCosGridBSplineSurface(): GeomAPI_PointsToBSplineSurface on the 4x4 grid
//    z = sin(u / 2) cos(v / 2), degree 3..3, C2, 1e-3 (fromPointGrid's capped defaults).
// Each edit is the Geom_BSplineSurface call the matching OCCTSurfaceBSpline* bridge makes.
#include <GeomAPI_PointsToBSplineSurface.hxx>
#include <GeomConvert.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <NCollection_Array1.hxx>
#include <Standard_Failure.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColgp_Array2OfPnt.hxx>
#include <cmath>
#include <cstdio>

static Handle(Geom_Surface) cylinder()
{
  return new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
}

static Handle(Geom_BSplineSurface) cyl()
{
  return GeomConvert::SurfaceToBSplineSurface(new Geom_RectangularTrimmedSurface(cylinder(), 0.0, 2 * M_PI, 0.0, 10.0));
}

static Handle(Geom_BSplineSurface) sincos()
{
  TColgp_Array2OfPnt pts(1, 4, 1, 4);
  for (int v = 0; v < 4; v++)
    for (int u = 0; u < 4; u++)
      pts.SetValue(u + 1, v + 1, gp_Pnt(u, v, std::sin(u * 0.5) * std::cos(v * 0.5)));
  return GeomAPI_PointsToBSplineSurface(pts, 3, 3, GeomAbs_C2, 1e-3).Surface();
}

static void desc(const char* tag, const Handle(Geom_BSplineSurface)& s)
{
  double u1, u2, v1, v2;
  s->Bounds(u1, u2, v1, v2);
  printf("%s: knots %dx%d poles %dx%d degree %dx%d rational %d/%d bounds [%.17g, %.17g]x[%.17g, %.17g]\n", tag, s->NbUKnots(),
         s->NbVKnots(), s->NbUPoles(), s->NbVPoles(), s->UDegree(), s->VDegree(), s->IsURational(), s->IsVRational(), u1, u2,
         v1, v2);
}

int main()
{
  try
  {
    GeomConvert::SurfaceToBSplineSurface(cylinder());
    printf("untrimmed cylinder fixture: converted\n");
  }
  catch (Standard_Failure& e)
  {
    printf("untrimmed cylinder fixture: SurfaceToBSplineSurface threw %s\n", e.GetMessageString());
  }
  Handle(Geom_BSplineSurface) c;
  try
  {
    c = cyl();
  }
  catch (Standard_Failure& e)
  {
    printf("cylinder fixture: SurfaceToBSplineSurface threw %s\n", e.GetMessageString());
  }
  if (!c.IsNull())
  {
    desc("cylinder fixture", c);
    gp_Pnt p = c->Pole(1, 1);
    printf("getPole: Pole(1,1)=(%.17g, %.17g, %.17g) Weight(1,1)=%.17g\n", p.X(), p.Y(), p.Z(), c->Weight(1, 1));
    {
      auto s = cyl();
      s->SetPole(1, 1, gp_Pnt(10, 10, 10));
      gp_Pnt q = s->Pole(1, 1);
      printf("setPole: Pole(1,1) after=(%g, %g, %g)\n", q.X(), q.Y(), q.Z());
    }
    {
      auto s = cyl();
      s->ExchangeUV();
      desc("exchangeUV", s);
    }
    double u1, u2, v1, v2;
    c->Bounds(u1, u2, v1, v2);
    {
      auto s = cyl();
      s->InsertUKnot((u1 + u2) / 2, 1, 1e-6);
      printf("insertUKnot: u=%.17g NbUKnots after=%d mults=", (u1 + u2) / 2, s->NbUKnots());
      for (int i = 1; i <= s->NbUKnots(); i++)
        printf("%d ", s->UMultiplicity(i));
      printf("\n");
    }
    {
      auto s = cyl();
      s->InsertVKnot((v1 + v2) / 2, 1, 1e-6);
      printf("insertVKnot: v=%.17g NbVKnots after=%d mults=", (v1 + v2) / 2, s->NbVKnots());
      for (int i = 1; i <= s->NbVKnots(); i++)
        printf("%d ", s->VMultiplicity(i));
      printf("\n");
    }
    {
      auto   s  = cyl();
      double a1 = u1 + (u2 - u1) * 0.25, a2 = u1 + (u2 - u1) * 0.75, b1 = v1 + (v2 - v1) * 0.25, b2 = v1 + (v2 - v1) * 0.75;
      s->Segment(a1, a2, b1, b2);
      desc("segment", s);
    }
    {
      auto s = cyl();
      int  ud = s->UDegree(), vd = s->VDegree();
      gp_Pnt before = s->Value(1.0, 0.5);
      s->IncreaseDegree(ud + 1, vd + 1);
      gp_Pnt after = s->Value(1.0, 0.5);
      desc("increaseDegree", s);
      printf("  S(1.0, 0.5) moved by %.3g\n", before.Distance(after));
    }
    {
      auto s = cyl();
      s->SetWeight(1, 1, 2.0);
      printf("setWeight: Weight(1,1) after=%.17g rational %d/%d\n", s->Weight(1, 1), s->IsURational(), s->IsVRational());
    }
  }
  {
    auto s = sincos();
    desc("sincos fixture", s);
    printf("removeUKnot: knots U=");
    for (int i = 1; i <= s->NbUKnots(); i++)
      printf("%g(x%d) ", s->UKnot(i), s->UMultiplicity(i));
    printf("\n");
    bool r1 = false;
    try
    {
      r1 = s->RemoveUKnot(1, 0, 1.0);
      printf("  RemoveUKnot(1, 0, 1.0)=%d\n", r1);
    }
    catch (Standard_Failure& e)
    {
      printf("  RemoveUKnot(1, 0, 1.0) threw %s\n", e.GetMessageString());
    }
    TColStd_Array1OfReal    k(1, 1);
    NCollection_Array1<int> m(1, 1);
    k(1) = 0.5;
    m(1) = 1;
    s->InsertUKnots(k, m, 0.0);
    printf("  after InsertUKnots(0.5): NbUKnots=%d\n", s->NbUKnots());
    gp_Pnt before = s->Value(0.3, 0.6);
    bool   r2     = s->RemoveUKnot(2, 0, 1.0);
    printf("  RemoveUKnot(2, 0, 1.0)=%d NbUKnots=%d S(0.3,0.6) moved by %.3g\n", r2, s->NbUKnots(), before.Distance(s->Value(0.3, 0.6)));
  }
  {
    auto s = sincos();
    try
    {
      bool r = s->RemoveVKnot(1, 0, 1.0);
      printf("removeVKnot: RemoveVKnot(1, 0, 1.0)=%d NbVKnots=%d\n", r, s->NbVKnots());
    }
    catch (Standard_Failure& e)
    {
      printf("removeVKnot: RemoveVKnot(1, 0, 1.0) threw %s\n", e.GetMessageString());
    }
    TColStd_Array1OfReal    k(1, 1);
    NCollection_Array1<int> m(1, 1);
    k(1) = 0.5;
    m(1) = 1;
    s->InsertVKnots(k, m, 0.0);
    bool r2 = s->RemoveVKnot(2, 0, 1.0);
    printf("  after InsertVKnots(0.5): RemoveVKnot(2, 0, 1.0)=%d NbVKnots=%d\n", r2, s->NbVKnots());
  }
  return 0;
}
