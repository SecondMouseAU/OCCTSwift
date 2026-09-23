// Epic #766 (#1978), kernel parity for Issue211WireCurveTests.swift: the L wire through
// BRepAdaptor_CompCurve and a 10-unit box edge through BRepAdaptor_Curve, with arc length and
// abscissa points from GCPnts_AbscissaPoint, the classes WireCurve and EdgeCurve wrap.
#include <BRepAdaptor_CompCurve.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <GCPnts_UniformAbscissa.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <cstdio>

template <class C> static void report(const char* name, const C& c, std::initializer_list<double> abs)
{
  double L = GCPnts_AbscissaPoint::Length(c);
  printf("%s: length %.17g range [%.17g, %.17g]\n", name, L, c.FirstParameter(), c.LastParameter());
  for (double s : abs)
  {
    GCPnts_AbscissaPoint ap(c, s, c.FirstParameter());
    gp_Pnt               p;
    gp_Vec               v;
    c.D1(ap.Parameter(), p, v);
    v.Normalize();
    printf("  s=%g u=%.17g p=(%.9g, %.9g, %.9g) t=(%.3g, %.3g, %.3g)\n", s, ap.Parameter(), p.X(),
           p.Y(), p.Z(), v.X(), v.Y(), v.Z());
  }
}

int main()
{
  BRepBuilderAPI_MakePolygon poly(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10, 10, 0));
  BRepAdaptor_CompCurve      cc(poly.Wire());
  report("L wire", cc, {0, 5, 10, 15, 20});
  GCPnts_UniformAbscissa u5(cc, 5);
  printf("L wire uniform abscissa 5 points: %d\n", u5.NbPoints());

  TopoDS_Shape    box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopExp_Explorer ex(box, TopAbs_EDGE);
  BRepAdaptor_Curve e(TopoDS::Edge(ex.Current()));
  report("box edge", e, {0, 5, 10});
  return 0;
}
