// Epic #766, BezierSurfaceCompletionsTests.swift, BezierSurfaceCompletionsV129Tests.swift and
// BezierSurfaceWeightTests.swift: kernel parity for the nine pole/weight editing tests. The same
// Geom_BezierSurface edits the bridge makes (InsertPoleCol/RowAfter/Before, RemovePoleCol/Row,
// Increase, U/VReverse, SetPoleCol/Row with and without weights, SetWeightCol/Row), on the same
// inputs, printing the pole grid row-major (u rows, v columns) as OCCTSurfaceBezierGetPoles does.
#include <GeomFill_BezierCurves.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom_BezierSurface.hxx>
#include <Standard_OutOfRange.hxx>
#include <NCollection_Array1.hxx>
#include <NCollection_Array2.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColStd_Array2OfReal.hxx>
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

static void dump(const char* tag, const Handle(Geom_BezierSurface)& s)
{
  printf("  %s: %dx%d deg=(%d,%d) poles=", tag, s->NbUPoles(), s->NbVPoles(), s->UDegree(), s->VDegree());
  for (int i = 1; i <= s->NbUPoles(); i++)
    for (int j = 1; j <= s->NbVPoles(); j++)
    {
      gp_Pnt p = s->Pole(i, j);
      printf("(%g,%g,%g)", p.X(), p.Y(), p.Z());
    }
  if (s->IsURational() || s->IsVRational())
  {
    printf(" weights=");
    for (int i = 1; i <= s->NbUPoles(); i++)
      for (int j = 1; j <= s->NbVPoles(); j++)
        printf("%g ", s->Weight(i, j));
  }
  printf("\n");
}

static NCollection_Array1<gp_Pnt> arr(const std::vector<gp_Pnt>& v)
{
  NCollection_Array1<gp_Pnt> a(1, (int)v.size());
  for (size_t i = 0; i < v.size(); i++)
    a((int)i + 1) = v[i];
  return a;
}

static TColStd_Array1OfReal warr(const std::vector<double>& v)
{
  TColStd_Array1OfReal a(1, (int)v.size());
  for (size_t i = 0; i < v.size(); i++)
    a((int)i + 1) = v[i];
  return a;
}

static Handle(Geom_BezierSurface) fill2()
{
  NCollection_Array1<gp_Pnt> a(1, 2), b(1, 2);
  a(1) = gp_Pnt(0, 0, 0);
  a(2) = gp_Pnt(10, 0, 0);
  b(1) = gp_Pnt(0, 5, 0);
  b(2) = gp_Pnt(10, 5, 0);
  GeomFill_BezierCurves f(new Geom_BezierCurve(a), new Geom_BezierCurve(b), GeomFill_StretchStyle);
  return f.Surface();
}

int main()
{
  gp_Pnt O(0, 0, 0);
  {
    printf("insertRemoveCol:\n");
    auto s = make({{gp_Pnt(0, 0, 0), gp_Pnt(0, 1, 0), gp_Pnt(0, 2, 0)}, {gp_Pnt(1, 0, 0), gp_Pnt(1, 1, 1), gp_Pnt(1, 2, 0)}});
    dump("initial", s);
    s->InsertPoleColAfter(1, arr({gp_Pnt(0, 0.5, 0.5), gp_Pnt(1, 0.5, 0.5)}));
    dump("InsertPoleColAfter(1)", s);
    s->RemovePoleCol(2);
    dump("RemovePoleCol(2)", s);
  }
  {
    printf("insertRemoveRow:\n");
    auto s = make({{gp_Pnt(0, 0, 0), gp_Pnt(0, 1, 0)}, {gp_Pnt(1, 0, 0), gp_Pnt(1, 1, 1)}, {gp_Pnt(2, 0, 0), gp_Pnt(2, 1, 0)}});
    dump("initial", s);
    s->InsertPoleRowAfter(1, arr({gp_Pnt(0.5, 0, 0.5), gp_Pnt(0.5, 1, 0.5)}));
    dump("InsertPoleRowAfter(1)", s);
    s->RemovePoleRow(2);
    dump("RemovePoleRow(2)", s);
  }
  {
    printf("increaseDegree:\n");
    auto   s  = make({{gp_Pnt(0, 0, 0), gp_Pnt(0, 1, 0)}, {gp_Pnt(1, 0, 0), gp_Pnt(1, 1, 1)}});
    gp_Pnt p0 = s->Value(0.3, 0.7);
    s->Increase(2, 2);
    gp_Pnt p1 = s->Value(0.3, 0.7);
    dump("Increase(2,2)", s);
    printf("  point(0.3,0.7) before=(%.17g,%.17g,%.17g) after=(%.17g,%.17g,%.17g) moved=%.3g\n", p0.X(), p0.Y(), p0.Z(),
           p1.X(), p1.Y(), p1.Z(), p0.Distance(p1));
  }
  {
    printf("reverse:\n");
    auto s = make({{gp_Pnt(0, 0, 0), gp_Pnt(0, 1, 0)}, {gp_Pnt(1, 0, 0), gp_Pnt(1, 1, 1)}});
    s->UReverse();
    dump("UReverse", s);
    s->VReverse();
    dump("VReverse", s);
  }
  {
    printf("insertBefore (bezierFill of two degree-1 Bezier curves, stretch):\n");
    auto s = fill2();
    dump("initial", s);
    int nbU = s->NbUPoles();
    std::vector<gp_Pnt> col;
    for (int i = 0; i < nbU; i++)
      col.push_back(gp_Pnt(i, 2.5, 1.0));
    try
    {
      s->InsertPoleColBefore(1, arr(col));
      dump("InsertPoleColBefore(1)", s);
    }
    catch (Standard_OutOfRange&)
    {
      printf("  InsertPoleColBefore(1): threw Standard_OutOfRange\n");
    }
    s->InsertPoleColBefore(2, arr(col));
    dump("InsertPoleColBefore(2)", s);
    std::vector<gp_Pnt> row;
    for (int i = 0; i < s->NbVPoles(); i++)
      row.push_back(gp_Pnt(-1.0, i, 0.5));
    try
    {
      s->InsertPoleRowBefore(1, arr(row));
      dump("InsertPoleRowBefore(1)", s);
    }
    catch (Standard_OutOfRange&)
    {
      printf("  InsertPoleRowBefore(1): threw Standard_OutOfRange\n");
    }
    s->InsertPoleRowBefore(2, arr(row));
    dump("InsertPoleRowBefore(2)", s);
  }
  {
    printf("setPoleColRow:\n");
    auto s = fill2();
    std::vector<gp_Pnt> col, row;
    for (int i = 0; i < s->NbUPoles(); i++)
      col.push_back(gp_Pnt(i * 2.0, 0, 0));
    for (int i = 0; i < s->NbVPoles(); i++)
      row.push_back(gp_Pnt(0, i * 3.0, 0));
    s->SetPoleCol(1, arr(col));
    dump("SetPoleCol(1)", s);
    s->SetPoleRow(1, arr(row));
    dump("SetPoleRow(1)", s);
  }
  {
    printf("setWeightColRow:\n");
    auto s = fill2();
    std::vector<gp_Pnt> col;
    for (int i = 0; i < s->NbUPoles(); i++)
      col.push_back(gp_Pnt(i, 0, 0));
    s->SetPoleCol(1, arr(col), warr(std::vector<double>(s->NbUPoles(), 2.0)));
    dump("SetPoleCol(1, weights 2)", s);
    s->SetWeightCol(1, warr(std::vector<double>(s->NbUPoles(), 1.5)));
    dump("SetWeightCol(1, 1.5)", s);
    s->SetWeightRow(1, warr(std::vector<double>(s->NbVPoles(), 1.2)));
    dump("SetWeightRow(1, 1.2)", s);
  }
  Grid g = {{gp_Pnt(0, 0, 0), gp_Pnt(0, 5, 0), gp_Pnt(0, 10, 0)},
            {gp_Pnt(5, 0, 0), gp_Pnt(5, 5, 1), gp_Pnt(5, 10, 0)},
            {gp_Pnt(10, 0, 0), gp_Pnt(10, 5, 0), gp_Pnt(10, 10, 0)}};
  TColStd_Array2OfReal w(1, 3, 1, 3);
  w.Init(1.0);
  w(2, 2) = 2.0;
  {
    printf("setPoleColWeights:\n");
    NCollection_Array2<gp_Pnt> p(1, 3, 1, 3);
    for (int i = 0; i < 3; i++)
      for (int j = 0; j < 3; j++)
        p(i + 1, j + 1) = g[i][j];
    Handle(Geom_BezierSurface) s = new Geom_BezierSurface(p, w);
    s->SetPoleCol(2, arr({gp_Pnt(0, 5, 2), gp_Pnt(5, 5, 3), gp_Pnt(10, 5, 2)}), warr({3, 3, 3}));
    dump("SetPoleCol(2, weights 3)", s);
  }
  {
    printf("setPoleRowWeights:\n");
    NCollection_Array2<gp_Pnt> p(1, 3, 1, 3);
    for (int i = 0; i < 3; i++)
      for (int j = 0; j < 3; j++)
        p(i + 1, j + 1) = g[i][j];
    Handle(Geom_BezierSurface) s = new Geom_BezierSurface(p, w);
    s->SetPoleRow(2, arr({gp_Pnt(5, 0, 2), gp_Pnt(5, 5, 3), gp_Pnt(5, 10, 2)}), warr({4, 4, 4}));
    dump("SetPoleRow(2, weights 4)", s);
  }
  return 0;
}
