// Epic #766 kernel-parity probe for Tests/OCCTMathTests/GeomLibCheckBSplineTests.swift.
// Same curves as the tests, same calls as OCCTGeomLibCheckBSpline3D/2D (NeedTangentFix, no
// IsDone gate) and OCCTGeomLibFixBSpline3D/2D (FixedTangent), default tolerances 0.01 / 0.1.
#include <Geom2d_BSplineCurve.hxx>
#include <Geom_BSplineCurve.hxx>
#include <GeomLib_Check2dBSplineCurve.hxx>
#include <GeomLib_CheckBSplineCurve.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TColgp_Array1OfPnt2d.hxx>
#include <cstdio>

static Handle(Geom_BSplineCurve) c3(const double (*p)[2])
{
  TColgp_Array1OfPnt P(1, 4);
  for (int i = 0; i < 4; i++)
    P.SetValue(i + 1, gp_Pnt(p[i][0], p[i][1], 0));
  TColStd_Array1OfReal    K(1, 2);
  TColStd_Array1OfInteger M(1, 2);
  K(1) = 0;
  K(2) = 1;
  M(1) = 4;
  M(2) = 4;
  return new Geom_BSplineCurve(P, K, M, 3);
}

static Handle(Geom2d_BSplineCurve) c2(const double (*p)[2])
{
  TColgp_Array1OfPnt2d P(1, 4);
  TColStd_Array1OfReal W(1, 4);
  for (int i = 0; i < 4; i++)
  {
    P.SetValue(i + 1, gp_Pnt2d(p[i][0], p[i][1]));
    W(i + 1) = 1.0;
  }
  TColStd_Array1OfReal    K(1, 2);
  TColStd_Array1OfInteger M(1, 2);
  K(1) = 0;
  K(2) = 1;
  M(1) = 4;
  M(2) = 4;
  return new Geom2d_BSplineCurve(P, W, K, M, 3);
}

static const double ord[4][2]  = {{0, 0}, {1, 2}, {3, 1}, {4, 0}};
static const double revF[4][2] = {{2, 0}, {0, 0}, {4, 0}, {8, 0}};
static const double revL[4][2] = {{8, 0}, {4, 0}, {0, 0}, {2, 0}};

static void check3(const char* n, const Handle(Geom_BSplineCurve)& c)
{
  GeomLib_CheckBSplineCurve k(c, 0.01, 0.1);
  bool                      f = false, l = false;
  k.NeedTangentFix(f, l);
  printf("%s: fixFirst=%d fixLast=%d isDone=%d\n", n, f, l, k.IsDone() ? 1 : 0);
}

static void check2(const char* n, const Handle(Geom2d_BSplineCurve)& c)
{
  GeomLib_Check2dBSplineCurve k(c, 0.01, 0.1);
  bool                        f = false, l = false;
  k.NeedTangentFix(f, l);
  printf("%s: fixFirst=%d fixLast=%d isDone=%d\n", n, f, l, k.IsDone() ? 1 : 0);
}

int main()
{
  check3("check3DOrdinaryCurve", c3(ord));
  check3("check3DReversedFirstTangent", c3(revF));
  check3("check3DReversedLastTangent", c3(revL));
  {
    GeomLib_CheckBSplineCurve k(c3(revF), 0.01, 0.1);
    Handle(Geom_BSplineCurve) fx = k.FixedTangent(true, false);
    printf("fix3D: FixedTangent(revF, true, false) null=%d", fx.IsNull() ? 1 : 0);
    if (!fx.IsNull())
    {
      printf(" poles=%d", fx->NbPoles());
      for (int i = 1; i <= fx->NbPoles(); i++)
        printf(" (%.10g,%.10g,%.10g)", fx->Pole(i).X(), fx->Pole(i).Y(), fx->Pole(i).Z());
      printf("\n");
      check3("fix3D recheck of fixed curve", fx);
    }
    else
      printf("\n");
  }
  check2("check2DOrdinaryCurve", c2(ord));
  check2("check2DReversedFirstTangent", c2(revF));
  check2("check2DReversedLastTangent", c2(revL));
  {
    GeomLib_Check2dBSplineCurve k(c2(revF), 0.01, 0.1);
    Handle(Geom2d_BSplineCurve) fx = k.FixedTangent(true, false);
    printf("fix2D: FixedTangent(revF, true, false) null=%d", fx.IsNull() ? 1 : 0);
    if (!fx.IsNull())
    {
      printf(" poles=%d", fx->NbPoles());
      for (int i = 1; i <= fx->NbPoles(); i++)
        printf(" (%.10g,%.10g)", fx->Pole(i).X(), fx->Pole(i).Y());
      printf("\n");
      check2("fix2D recheck of fixed curve", fx);
    }
    else
      printf("\n");
  }
  return 0;
}
