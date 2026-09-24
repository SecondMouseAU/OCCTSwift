// Epic #766 (#1978), kernel parity for BSplineCurve3DCompletionsV121Tests.swift and
// BSplineCurve3DLocalDTests.swift. Same Geom_BSplineCurve inputs as the Swift tests, and the same
// Geom_BSplineCurve methods the OCCTCurve3DBSpline* bridge functions call.
#include <GeomAPI_Interpolate.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Standard_Failure.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <cstdio>

static Handle(Geom_BSplineCurve) cubic()
{
  TColgp_Array1OfPnt p(1, 4);
  p(1) = gp_Pnt(0, 0, 0);
  p(2) = gp_Pnt(3, 5, 0);
  p(3) = gp_Pnt(7, 5, 0);
  p(4) = gp_Pnt(10, 0, 0);
  TColStd_Array1OfReal    k(1, 2);
  TColStd_Array1OfInteger m(1, 2);
  k(1) = 0;
  k(2) = 1;
  m(1) = m(2) = 4;
  return new Geom_BSplineCurve(p, k, m, 3);
}

static void dump(const char* tag, const Handle(Geom_BSplineCurve)& c)
{
  printf("  %s: periodic=%d degree=%d poles=%d domain=[%.17g, %.17g] knotSeq:", tag,
         c->IsPeriodic(), c->Degree(), c->NbPoles(), c->FirstParameter(), c->LastParameter());
  for (int i = 1; i <= c->KnotSequence().Length(); i++)
    printf(" %.17g", c->KnotSequence()(i));
  gp_Pnt s = c->StartPoint(), e = c->EndPoint();
  printf("\n    start=(%.17g, %.17g, %.17g) end=(%.17g, %.17g, %.17g)\n", s.X(), s.Y(), s.Z(),
         e.X(), e.Y(), e.Z());
}

int main()
{
  printf("V121 fixture: poles (0,0,0) (3,5,0) (7,5,0) (10,0,0), knots [0,1] mult [4,4], degree 3\n");
  {
    auto c = cubic();
    c->SetNotPeriodic();
    dump("SetNotPeriodic", c);
    auto d = cubic();
    try
    {
      d->SetPeriodic();
      dump("SetPeriodic (for contrast)", d);
    }
    catch (Standard_Failure& f)
    {
      printf("  SetPeriodic threw: %s\n", f.what());
    }
  }
  {
    auto                    c = cubic();
    TColStd_Array1OfReal    k(1, 1);
    TColStd_Array1OfInteger m(1, 1);
    k(1) = 0.5;
    m(1) = 1;
    c->InsertKnots(k, m, 1e-10);
    dump("InsertKnots([0.5],[1])", c);
    c->IncreaseMultiplicity(2, 2);
    dump("then IncreaseMultiplicity(2, 2)", c);
  }
  {
    auto                    c = cubic();
    TColStd_Array1OfReal    k(1, 2);
    TColStd_Array1OfInteger m(1, 2);
    k(1) = 0.3;
    k(2) = 0.7;
    m(1) = m(2) = 1;
    c->InsertKnots(k, m, 1e-10);
    dump("InsertKnots([0.3,0.7],[1,1])", c);
    c->IncrementMultiplicity(2, 3, 1);
    dump("then IncrementMultiplicity(2, 3, 1)", c);
  }
  {
    auto c = cubic();
    c->Reverse();
    dump("Reverse", c);
  }
  {
    auto                 c = cubic();
    TColStd_Array1OfReal k(1, 2);
    k(1) = 0;
    k(2) = 2;
    c->SetKnots(k);
    dump("SetKnots([0, 2])", c);
  }
  {
    auto c = cubic();
    c->SetKnot(1, -1.0);
    c->SetKnot(2, 3.0);
    dump("SetKnot(1,-1) SetKnot(2,3)", c);
  }
  {
    auto c = cubic();
    try
    {
      c->SetOrigin(1);
      printf("  SetOrigin(1): no throw\n");
    }
    catch (Standard_Failure& f)
    {
      printf("  SetOrigin(1) threw: %s\n", f.what());
    }
  }
  for (int endCond : {1, -1})
  {
    auto             c   = cubic();
    Standard_Integer err = 0;
    c->MovePointAndTangent(0.5, gp_Pnt(5, 10, 0), gp_Vec(1, 0, 0), 1e-6, 1, endCond, err);
    gp_Pnt p;
    gp_Vec v;
    c->D1(0.5, p, v);
    printf("  MovePointAndTangent(0.5, (5,10,0), (1,0,0), 1e-6, 1, %d): errorStatus=%d C(0.5)=(%.17g, "
           "%.17g, %.17g) C'(0.5)=(%.17g, %.17g, %.17g)\n",
           endCond, err, p.X(), p.Y(), p.Z(), v.X(), v.Y(), v.Z());
  }

  printf("LocalD fixture: GeomAPI_Interpolate through (0,0,0) (1,2,0) (3,1,0) (5,3,0), tol 1e-6\n");
  Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, 4);
  pts->SetValue(1, gp_Pnt(0, 0, 0));
  pts->SetValue(2, gp_Pnt(1, 2, 0));
  pts->SetValue(3, gp_Pnt(3, 1, 0));
  pts->SetValue(4, gp_Pnt(5, 3, 0));
  GeomAPI_Interpolate ip(pts, false, 1e-6);
  ip.Perform();
  Handle(Geom_BSplineCurve) c = ip.Curve();
  dump("interpolated", c);
  int i1 = 0, i2 = 0;
  c->LocateU(0.5, 1e-10, i1, i2);
  int k = 0;
  c->LocateU(0.5, 1e-10, k, k);
  printf("  LocateU(0.5, 1e-10): I1=%d I2=%d; with I1 and I2 the same variable (as the bridge "
         "passes them): %d\n",
         i1, i2, k);
  gp_Pnt lv = c->LocalValue(0.5, k, k + 1);
  gp_Pnt p0;
  c->LocalD0(0.5, k, k + 1, p0);
  gp_Pnt p1;
  gp_Vec v1;
  c->LocalD1(0.5, k, k + 1, p1, v1);
  gp_Pnt p2;
  gp_Vec a2, b2;
  c->LocalD2(0.5, k, k + 1, p2, a2, b2);
  gp_Pnt p3;
  gp_Vec a3, b3, c3;
  c->LocalD3(0.5, k, k + 1, p3, a3, b3, c3);
  gp_Vec dn1 = c->LocalDN(0.5, k, k + 1, 1);
  gp_Pnt g;
  gp_Vec g1, g2, g3;
  c->D3(0.5, g, g1, g2, g3);
  printf("  LocalValue(0.5, %d, %d)=(%.17g, %.17g, %.17g)\n", k, k + 1, lv.X(), lv.Y(), lv.Z());
  printf("  LocalD0=(%.17g, %.17g, %.17g)\n", p0.X(), p0.Y(), p0.Z());
  printf("  LocalD1 P=(%.17g, %.17g, %.17g) V1=(%.17g, %.17g, %.17g)\n", p1.X(), p1.Y(), p1.Z(),
         v1.X(), v1.Y(), v1.Z());
  printf("  LocalD2 V2=(%.17g, %.17g, %.17g)\n", b2.X(), b2.Y(), b2.Z());
  printf("  LocalD3 P=(%.17g, %.17g, %.17g) V1=(%.17g, %.17g, %.17g) V3=(%.17g, %.17g, %.17g)\n",
         p3.X(), p3.Y(), p3.Z(), a3.X(), a3.Y(), a3.Z(), c3.X(), c3.Y(), c3.Z());
  printf("  LocalDN(n=1)=(%.17g, %.17g, %.17g)\n", dn1.X(), dn1.Y(), dn1.Z());
  printf("  global D3 at 0.5: P=(%.17g, %.17g, %.17g) V1=(%.17g, %.17g, %.17g) V2=(%.17g, %.17g, "
         "%.17g) V3=(%.17g, %.17g, %.17g)\n",
         g.X(), g.Y(), g.Z(), g1.X(), g1.Y(), g1.Z(), g2.X(), g2.Y(), g2.Z(), g3.X(), g3.Y(),
         g3.Z());
  return 0;
}
