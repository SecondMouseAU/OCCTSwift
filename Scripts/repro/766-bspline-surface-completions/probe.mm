// Epic #766, BSplineSurfaceCompletionsV121Tests.swift and BSplineSurfaceCompletionsV129Tests.swift:
// kernel parity for the twelve tests. The V121 fixture is makeExplicitPoleBSplineSurface() (a
// hand-written 4x4 cubic, knots {0, 1} x4 each way); the V129 surface is
// GeomConvert::SurfaceToBSplineSurface of a radius-5 Geom_SphericalSurface (OCCTSurfaceToBSpline).
// Each edit is the Geom_BSplineSurface call the matching OCCTSurfaceBSpline* bridge function makes.
#include <GeomConvert.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_SphericalSurface.hxx>
#include <NCollection_Array1.hxx>
#include <NCollection_Array2.hxx>
#include <Standard_Failure.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <cstdio>

static Handle(Geom_BSplineSurface) fixture()
{
  double P[4][4][3] = {{{0, 0, 0}, {3, 0, 0}, {7, 0, 0}, {10, 0, 0}},
                       {{0, 3, 1}, {3, 3, 2}, {7, 3, 2}, {10, 3, 1}},
                       {{0, 7, 1}, {3, 7, 2}, {7, 7, 2}, {10, 7, 1}},
                       {{0, 10, 0}, {3, 10, 0}, {7, 10, 0}, {10, 10, 0}}};
  NCollection_Array2<gp_Pnt> poles(1, 4, 1, 4);
  for (int i = 0; i < 4; i++)
    for (int j = 0; j < 4; j++)
      poles(i + 1, j + 1) = gp_Pnt(P[i][j][0], P[i][j][1], P[i][j][2]);
  TColStd_Array1OfReal    k(1, 2);
  NCollection_Array1<int> m(1, 2);
  k(1) = 0;
  k(2) = 1;
  m(1) = 4;
  m(2) = 4;
  return new Geom_BSplineSurface(poles, k, k, m, m, 3, 3);
}

static Handle(Geom_BSplineSurface) sphere()
{
  return GeomConvert::SurfaceToBSplineSurface(new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp::DZ()), 5));
}

static void mults(const char* tag, const Handle(Geom_BSplineSurface)& s)
{
  printf("  %s: U knots=", tag);
  for (int i = 1; i <= s->NbUKnots(); i++)
    printf("%g(x%d) ", s->UKnot(i), s->UMultiplicity(i));
  printf("V knots=");
  for (int i = 1; i <= s->NbVKnots(); i++)
    printf("%g(x%d) ", s->VKnot(i), s->VMultiplicity(i));
  printf("\n");
}

int main()
{
  {
    auto   s  = fixture();
    gp_Pnt p0 = s->Value(0.3, 0.7);
    s->SetUNotPeriodic();
    s->SetVNotPeriodic();
    gp_Pnt p1 = s->Value(0.3, 0.7);
    printf("setNotPeriodic: S(0.3,0.7) before=(%.17g,%.17g,%.17g) after=(%.17g,%.17g,%.17g) IsUPeriodic=%d IsVPeriodic=%d\n",
           p0.X(), p0.Y(), p0.Z(), p1.X(), p1.Y(), p1.Z(), s->IsUPeriodic(), s->IsVPeriodic());
  }
  {
    auto                    s = fixture();
    TColStd_Array1OfReal    k(1, 1);
    NCollection_Array1<int> m(1, 1);
    k(1) = 0.5;
    m(1) = 1;
    printf("increaseMultiplicity:\n");
    s->InsertUKnots(k, m, 0.0);
    mults("InsertUKnots([0.5],[1])", s);
    s->IncreaseUMultiplicity(2, 2);
    mults("IncreaseUMultiplicity(2, 2)", s);
    auto t = fixture();
    printf("increaseVMultiplicity:\n");
    t->InsertVKnots(k, m, 0.0);
    t->IncreaseVMultiplicity(2, 2);
    mults("InsertVKnots + IncreaseVMultiplicity(2, 2)", t);
  }
  {
    auto s = fixture();
    s->SetUKnot(1, -1.0);
    s->SetVKnot(1, -1.0);
    printf("setKnot: first U knot=%g first V knot=%g\n", s->UKnot(1), s->VKnot(1));
  }
  {
    auto                    s = fixture();
    TColStd_Array1OfReal    k(1, 2);
    NCollection_Array1<int> m(1, 2);
    k(1) = 0.25;
    k(2) = 0.75;
    m(1) = 1;
    m(2) = 1;
    s->InsertUKnots(k, m, 0.0);
    TColStd_Array1OfReal    k2(1, 1);
    NCollection_Array1<int> m2(1, 1);
    k2(1) = 0.5;
    m2(1) = 1;
    s->InsertVKnots(k2, m2, 0.0);
    printf("insertKnotsBatch: NbUKnots=%d NbVKnots=%d\n", s->NbUKnots(), s->NbVKnots());
    mults("after", s);
  }
  {
    auto s = fixture();
    int  a, b, c, d;
    s->MovePoint(0.5, 0.5, gp_Pnt(5, 5, 10), 1, 4, 1, 4, a, b, c, d);
    gp_Pnt p = s->Value(0.5, 0.5), q = s->Value(0.2, 0.2);
    printf("movePoint: S(0.5,0.5)=(%.17g,%.17g,%.17g) S(0.2,0.2)=(%.17g,%.17g,%.17g) moved pole range u[%d,%d] v[%d,%d]\n",
           p.X(), p.Y(), p.Z(), q.X(), q.Y(), q.Z(), a, b, c, d);
  }
  {
    auto                       s = fixture();
    NCollection_Array1<gp_Pnt> col(1, 4), row(1, 4);
    col(1) = gp_Pnt(0, 0, 5);
    col(2) = gp_Pnt(0, 3, 5);
    col(3) = gp_Pnt(0, 7, 5);
    col(4) = gp_Pnt(0, 10, 5);
    row(1) = gp_Pnt(0, 0, 3);
    row(2) = gp_Pnt(3, 0, 3);
    row(3) = gp_Pnt(7, 0, 3);
    row(4) = gp_Pnt(10, 0, 3);
    s->SetPoleCol(1, col);
    s->SetPoleRow(1, row);
    printf("setPoleColRow: pole(1..4, 1)=");
    for (int i = 1; i <= 4; i++)
      printf("(%g,%g,%g)", s->Pole(i, 1).X(), s->Pole(i, 1).Y(), s->Pole(i, 1).Z());
    printf(" pole(1, 1..4)=");
    for (int j = 1; j <= 4; j++)
      printf("(%g,%g,%g)", s->Pole(1, j).X(), s->Pole(1, j).Y(), s->Pole(1, j).Z());
    printf("\n");
  }
  {
    auto s = fixture();
    try
    {
      s->SetUOrigin(1);
      printf("setOriginNonPeriodic: SetUOrigin(1) returned\n");
    }
    catch (Standard_Failure& e)
    {
      printf("setOriginNonPeriodic: SetUOrigin(1) threw %s\n", e.GetMessageString());
    }
    try
    {
      s->SetVOrigin(1);
      printf("  SetVOrigin(1) returned\n");
    }
    catch (Standard_Failure& e)
    {
      printf("  SetVOrigin(1) threw %s\n", e.GetMessageString());
    }
  }
  {
    auto s = sphere();
    printf("sphere BSpline: %dx%d poles, rational U=%d V=%d, bounds ", s->NbUPoles(), s->NbVPoles(), s->IsURational(),
           s->IsVRational());
    double u1, u2, v1, v2;
    s->Bounds(u1, u2, v1, v2);
    printf("[%.17g, %.17g]x[%.17g, %.17g]\n", u1, u2, v1, v2);
    mults("sphere", s);
    printf("  weights col 1 before: ");
    for (int i = 1; i <= s->NbUPoles(); i++)
      printf("%.17g ", s->Weight(i, 1));
    printf("\n  weights row 1 before: ");
    for (int j = 1; j <= s->NbVPoles(); j++)
      printf("%.17g ", s->Weight(1, j));
    printf("\n");
    TColStd_Array1OfReal cw(1, s->NbUPoles()), rw(1, s->NbVPoles());
    cw.Init(1.0);
    rw.Init(1.0);
    s->SetWeightCol(1, cw);
    s->SetWeightRow(1, rw);
    printf("setWeightColRow: weights col 1 after: ");
    for (int i = 1; i <= s->NbUPoles(); i++)
      printf("%g ", s->Weight(i, 1));
    printf(" row 1 after: ");
    for (int j = 1; j <= s->NbVPoles(); j++)
      printf("%g ", s->Weight(1, j));
    printf(" weight(2,2)=%.17g\n", s->Weight(2, 2));
  }
  {
    auto s = sphere();
    s->IncrementUMultiplicity(1, s->NbUKnots(), 1);
    s->IncrementVMultiplicity(1, s->NbVKnots(), 1);
    printf("incrementMultiplicity:\n");
    mults("after IncrementU/VMultiplicity(1, n, 1)", s);
  }
  {
    auto s = sphere();
    printf("knotIndices: FirstUKnotIndex=%d LastUKnotIndex=%d FirstVKnotIndex=%d LastVKnotIndex=%d\n", s->FirstUKnotIndex(),
           s->LastUKnotIndex(), s->FirstVKnotIndex(), s->LastVKnotIndex());
  }
  {
    auto s = sphere();
    try
    {
      s->CheckAndSegment(0.0, 1.0, 0.0, 1.0, 1e-10, 1e-10);
      double u1, u2, v1, v2;
      s->Bounds(u1, u2, v1, v2);
      printf("checkAndSegment: bounds after=[%.17g, %.17g]x[%.17g, %.17g]\n", u1, u2, v1, v2);
    }
    catch (Standard_Failure& e)
    {
      printf("checkAndSegment: threw %s\n", e.GetMessageString());
    }
  }
  return 0;
}
