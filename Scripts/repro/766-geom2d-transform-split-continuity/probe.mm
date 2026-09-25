// #1979 kernel parity for Issue478Curve2DTransform{Parity,Geometry}Tests,
// Issue480Curve2DKnotSplitContinuityTests and Issue485Curve2DContinuityTests: gp_Trsf2d applied to
// the same segment, Geom2dConvert_BSplineCurveKnotSplitting on the same B-splines, and
// Geom2d_Curve::Continuity() on the same fixtures. (Issue486's empty-grid case never reaches OCCT:
// Curve2D.evaluateGrid returns before the bridge call.)
#include <GCE2d_MakeSegment.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <Geom2d_OffsetCurve.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <Geom2dConvert_BSplineCurveKnotSplitting.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColgp_Array1OfPnt2d.hxx>
#include <gp_Ax2d.hxx>
#include <gp_Trsf2d.hxx>
#include <cmath>
#include <cstdio>
#include <vector>

static void ends(const char* tag, const gp_Trsf2d& t)
{
  Handle(Geom2d_TrimmedCurve) s = GCE2d_MakeSegment(gp_Pnt2d(3, -1), gp_Pnt2d(11, 4)).Value();
  s->Transform(t);
  gp_Pnt2d a = s->Value(s->FirstParameter()), b = s->Value(s->LastParameter());
  printf("segment (3,-1)-(11,4) %s: start=(%.12g, %.12g) end=(%.12g, %.12g)\n", tag, a.X(), a.Y(), b.X(), b.Y());
}

static Handle(Geom2d_BSplineCurve) knotted(int degree, int interior, int bumpAt, int bumpMult)
{
  std::vector<double> k{0};
  std::vector<int>    m{degree + 1};
  for (int i = 1; i <= interior; i++)
  {
    k.push_back(i);
    m.push_back(i == bumpAt ? bumpMult : 1);
  }
  k.push_back(interior + 1);
  m.push_back(degree + 1);
  int sum = 0;
  for (int v : m)
    sum += v;
  int                  n = sum - degree - 1;
  TColgp_Array1OfPnt2d p(1, n);
  for (int i = 0; i < n; i++)
    p.SetValue(i + 1, gp_Pnt2d(i, i % 3));
  TColStd_Array1OfReal    K(1, (int)k.size());
  TColStd_Array1OfInteger M(1, (int)m.size());
  for (size_t i = 0; i < k.size(); i++)
  {
    K.SetValue((int)i + 1, k[i]);
    M.SetValue((int)i + 1, m[i]);
  }
  return new Geom2d_BSplineCurve(p, K, M, degree);
}

static void split(const char* tag, const Handle(Geom2d_BSplineCurve)& c, int cont)
{
  Geom2dConvert_BSplineCurveKnotSplitting s(c, cont);
  printf("%s split at C%d: indices", tag, cont);
  for (int i = 1; i <= s.NbSplits(); i++)
    printf(" %d(knot %g)", s.SplitValue(i), c->Knot(s.SplitValue(i)));
  printf("\n");
}

static Handle(Geom2d_BSplineCurve) cubic(int mult)
{
  int                  n = 4 + mult;
  TColgp_Array1OfPnt2d p(1, n);
  for (int i = 1; i <= n; i++)
    p.SetValue(i, gp_Pnt2d(i, (i % 2) * 2.0));
  TColStd_Array1OfReal    K(1, 3);
  TColStd_Array1OfInteger M(1, 3);
  K.SetValue(1, 0);
  K.SetValue(2, 0.5);
  K.SetValue(3, 1);
  M.SetValue(1, 4);
  M.SetValue(2, mult);
  M.SetValue(3, 4);
  return new Geom2d_BSplineCurve(p, K, M, 3);
}

int main()
{
  gp_Trsf2d t;
  t.SetTranslation(gp_Vec2d(3, -2.5));
  ends("translate (3,-2.5)", t);
  t.SetRotation(gp_Pnt2d(7, 5), M_PI / 3);
  ends("rotate about (7,5) by pi/3", t);
  t.SetScale(gp_Pnt2d(12.5, -6.25), 2.5);
  ends("scale about (12.5,-6.25) by 2.5", t);
  t.SetScale(gp_Pnt2d(12.5, -6.25), -1);
  ends("scale about (12.5,-6.25) by -1", t);
  t.SetMirror(gp_Pnt2d(4, 4));
  ends("mirror through (4,4)", t);
  t.SetMirror(gp_Ax2d(gp_Pnt2d(0, 2), gp_Dir2d(1, 2)));
  ends("mirror across (0,2)+(1,2)", t);

  Handle(Geom2d_BSplineCurve) simple = knotted(3, 4, 0, 1);
  for (int c = 0; c <= 3; c++)
    split("cubic, 4 simple interior knots", simple, c);
  Handle(Geom2d_BSplineCurve) kink = knotted(3, 4, 2, 3);
  split("cubic, knot 2 at multiplicity 3", kink, 1);
  split("cubic, knot 2 at multiplicity 3", kink, 0);

  const char* names[] = {"C0", "G1", "C1", "G2", "C2", "C3", "CN"};
  for (int m = 1; m <= 3; m++)
    printf("cubic, interior multiplicity %d: Continuity=%s (%d)\n", m, names[cubic(m)->Continuity()],
           (int)cubic(m)->Continuity());
  Handle(Geom2d_TrimmedCurve) seg = GCE2d_MakeSegment(gp_Pnt2d(0, 0), gp_Pnt2d(10, 0)).Value();
  printf("segment: Continuity=%s (%d)\n", names[seg->Continuity()], (int)seg->Continuity());
  TColgp_Array1OfPnt2d g(1, 7);
  gp_Pnt2d             gp[] = {{0, 0}, {1, 1}, {2, 0}, {3, 0}, {5, 0}, {6, 1}, {7, 0}};
  for (int i = 0; i < 7; i++)
    g.SetValue(i + 1, gp[i]);
  TColStd_Array1OfReal    K(1, 3);
  TColStd_Array1OfInteger M(1, 3);
  K.SetValue(1, 0);
  K.SetValue(2, 0.5);
  K.SetValue(3, 1);
  M.SetValue(1, 4);
  M.SetValue(2, 3);
  M.SetValue(3, 4);
  Handle(Geom2d_OffsetCurve) off = new Geom2d_OffsetCurve(new Geom2d_BSplineCurve(g, K, M, 3), 1.0);
  printf("offset 1.0 of the G1 basis: Continuity=%s (%d)\n", names[off->Continuity()], (int)off->Continuity());
  return 0;
}
