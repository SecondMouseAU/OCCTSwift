// Epic #766, BezierSurfaceCompletionTests.swift, BezierSurfaceFillTests.swift and
// BezierSurfaceResolutionTests.swift: kernel parity for the thirteen tests. Same inputs, straight
// to Geom_BezierSurface (UIso/VIso, IsU/VClosed, IsU/VPeriodic, Continuity, IsCNu/v, Poles,
// Weights, Bounds, MaxDegree) and GeomFill_BezierCurves (2 and 4 curves, the three styles), as the
// OCCTSurfaceBezier* and OCCTSurfaceBezierFill2/4 bridge functions call them.
#include <GC_MakeSegment.hxx>
#include <GeomFill_BezierCurves.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom_BezierSurface.hxx>
#include <Geom_Curve.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <NCollection_Array1.hxx>
#include <NCollection_Array2.hxx>
#include <Standard_Failure.hxx>
#include <cstdio>
#include <vector>

typedef std::vector<std::vector<gp_Pnt>> Grid;

static Handle(Geom_BezierSurface) make(const Grid& g)
{
  NCollection_Array2<gp_Pnt> p(1, (int)g.size(), 1, (int)g[0].size());
  for (size_t i = 0; i < g.size(); i++)
    for (size_t j = 0; j < g[0].size(); j++)
      p((int)i + 1, (int)j + 1) = g[i][j];
  return new Geom_BezierSurface(p);
}

static Handle(Geom_BezierCurve) bez(const std::vector<gp_Pnt>& v)
{
  NCollection_Array1<gp_Pnt> a(1, (int)v.size());
  for (size_t i = 0; i < v.size(); i++)
    a((int)i + 1) = v[i];
  return new Geom_BezierCurve(a);
}

static void pt(const char* tag, const gp_Pnt& p)
{
  printf("%s=(%.17g, %.17g, %.17g)", tag, p.X(), p.Y(), p.Z());
}

int main()
{
  Grid g3 = {{gp_Pnt(0, 0, 0), gp_Pnt(0, 1, 0), gp_Pnt(0, 2, 0)},
             {gp_Pnt(1, 0, 1), gp_Pnt(1, 1, 1), gp_Pnt(1, 2, 1)},
             {gp_Pnt(2, 0, 0), gp_Pnt(2, 1, 0), gp_Pnt(2, 2, 0)}};
  auto s3 = make(g3);
  {
    Handle(Geom_Curve) ui = s3->UIso(0.5), vi = s3->VIso(0.5);
    printf("isoCurves: ");
    pt("UIso(0.5)(0.3)", ui->Value(0.3));
    pt(" S(0.5,0.3)", s3->Value(0.5, 0.3));
    pt(" VIso(0.5)(0.3)", vi->Value(0.3));
    pt(" S(0.3,0.5)", s3->Value(0.3, 0.5));
    printf("\n");
  }
  Grid g2   = {{gp_Pnt(0, 0, 0), gp_Pnt(0, 1, 0)}, {gp_Pnt(1, 0, 1), gp_Pnt(1, 1, 1)}};
  auto s2   = make(g2);
  auto uclo = make({{gp_Pnt(0, 0, 0), gp_Pnt(0, 1, 0)}, {gp_Pnt(1, 0, 1), gp_Pnt(1, 1, 1)}, {gp_Pnt(0, 0, 0), gp_Pnt(0, 1, 0)}});
  auto vclo = make({{gp_Pnt(0, 0, 0), gp_Pnt(0, 1, 1), gp_Pnt(0, 0, 0)}, {gp_Pnt(1, 0, 0), gp_Pnt(1, 1, 1), gp_Pnt(1, 0, 0)}});
  printf("closedQueries: open IsUClosed=%d IsVClosed=%d; first row == last row IsUClosed=%d IsVClosed=%d; first col == last col IsUClosed=%d IsVClosed=%d\n",
         s2->IsUClosed(), s2->IsVClosed(), uclo->IsUClosed(), uclo->IsVClosed(), vclo->IsUClosed(), vclo->IsVClosed());
  printf("periodicQueries: IsUPeriodic=%d IsVPeriodic=%d\n", s2->IsUPeriodic(), s2->IsVPeriodic());
  printf("continuity: Continuity=%d (GeomAbs_CN=%d)\n", (int)s2->Continuity(), (int)GeomAbs_CN);
  printf("isCN: IsCNu(0)=%d IsCNu(10)=%d IsCNv(0)=%d IsCNv(10)=%d\n", s2->IsCNu(0), s2->IsCNu(10), s2->IsCNv(0), s2->IsCNv(10));
  printf("poles: %dx%d row-major=", s2->NbUPoles(), s2->NbVPoles());
  for (int i = 1; i <= 2; i++)
    for (int j = 1; j <= 2; j++)
      printf("(%g,%g,%g)", s2->Pole(i, j).X(), s2->Pole(i, j).Y(), s2->Pole(i, j).Z());
  printf("\n");
  printf("weightsNonRational: Weights()=%s\n", s2->Weights() ? "array" : "null");
  double u1, u2, v1, v2;
  s2->Bounds(u1, u2, v1, v2);
  printf("bounds: [%g, %g]x[%g, %g]\n", u1, u2, v1, v2);
  printf("resolution: Geom_BezierSurface::MaxDegree()=%d\n", Geom_BezierSurface::MaxDegree());

  // Fill
  auto c1 = bez({gp_Pnt(0, 0, 0), gp_Pnt(5, 1, 0), gp_Pnt(10, 0, 0)});
  auto c2 = bez({gp_Pnt(10, 0, 0), gp_Pnt(11, 5, 0), gp_Pnt(10, 10, 0)});
  auto c3 = bez({gp_Pnt(10, 10, 0), gp_Pnt(5, 11, 0), gp_Pnt(0, 10, 0)});
  auto c4 = bez({gp_Pnt(0, 10, 0), gp_Pnt(-1, 5, 0), gp_Pnt(0, 0, 0)});
  const char* names[3] = {"stretch", "coons", "curved"};
  GeomFill_FillingStyle styles[3] = {GeomFill_StretchStyle, GeomFill_CoonsStyle, GeomFill_CurvedStyle};
  for (int k = 0; k < 3; k++)
  {
    try
    {
      GeomFill_BezierCurves f(c1, c2, c3, c4, styles[k]);
      Handle(Geom_BezierSurface) s = f.Surface();
      printf("fill4Curves %s: %s", names[k], s.IsNull() ? "null" : "surface");
      if (!s.IsNull())
      {
        printf(" %dx%d ", s->NbUPoles(), s->NbVPoles());
        pt("S(0.3,0.6)", s->Value(0.3, 0.6));
        pt(" S(0,0)", s->Value(0, 0));
        pt(" S(0.5,0)", s->Value(0.5, 0));
      }
      printf("\n");
    }
    catch (Standard_Failure& e)
    {
      printf("fill4Curves %s: threw %s\n", names[k], e.GetMessageString());
    }
  }
  auto d1 = bez({gp_Pnt(0, 0, 0), gp_Pnt(5, 2, 0), gp_Pnt(10, 0, 0)});
  auto d2 = bez({gp_Pnt(0, 10, 0), gp_Pnt(5, 8, 0), gp_Pnt(10, 10, 0)});
  for (int k = 0; k < 3; k++)
  {
    try
    {
      GeomFill_BezierCurves f(d1, d2, styles[k]);
      Handle(Geom_BezierSurface) s = f.Surface();
      printf("fill2Curves %s: %s", names[k], s.IsNull() ? "null" : "surface");
      if (!s.IsNull())
      {
        printf(" %dx%d ", s->NbUPoles(), s->NbVPoles());
        pt("S(0.3,0.6)", s->Value(0.3, 0.6));
        pt(" S(0.5,0)", s->Value(0.5, 0));
        pt(" S(0.5,1)", s->Value(0.5, 1));
      }
      printf("\n");
    }
    catch (Standard_Failure& e)
    {
      printf("fill2Curves %s: threw %s\n", names[k], e.GetMessageString());
    }
  }
  Handle(Geom_TrimmedCurve) seg = GC_MakeSegment(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)).Value();
  printf("nonBezierFails: segment is %s, DownCast to Geom_BezierCurve is %s\n", seg->DynamicType()->Name(),
         Handle(Geom_BezierCurve)::DownCast(seg).IsNull() ? "null" : "non-null");
  return 0;
}
