// Epic #766 (#1978), kernel parity for GCPntsExpansionTests.swift, GCPntsQuasiUniformTests.swift,
// GCPntsTangentialDeflectionTests.swift, GeomConvertApproxCurveTests.swift and
// GeomConvertUtilTests.swift. Same inputs as the tests: BRepAdaptor_Curve on edge 0 of the centred
// 10 box and on the first edge of the r = 10 sphere, GCPnts_AbscissaPoint,
// GCPnts_QuasiUniformAbscissa, GCPnts_TangentialDeflection, Approx_Curve3d (as occtApproxCurve
// runs it: C2 by default, 100 segments, degree 8).
#include <Approx_Curve3d.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRep_Tool.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <GCPnts_QuasiUniformAbscissa.hxx>
#include <GCPnts_TangentialDeflection.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Line.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static void approx(const char* name, const Handle(Geom_Curve)& c, double tol, GeomAbs_Shape cont)
{
  Approx_Curve3d a(new GeomAdaptor_Curve(c), tol, cont, 100, 8);
  printf("%s: done=%d hasResult=%d maxError=%.17g\n", name, a.IsDone(), a.HasResult(), a.MaxError());
}

int main()
{
  TopoDS_Shape               box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopTools_IndexedMapOfShape em;
  TopExp::MapShapes(box, TopAbs_EDGE, em);
  BRepAdaptor_Curve a(TopoDS::Edge(em(1)));
  double            f = a.FirstParameter(), l = a.LastParameter();
  printf("box edge[0]: domain=[%g, %g] length=%.17g length[f, mid]=%.17g\n", f, l,
         GCPnts_AbscissaPoint::Length(a), GCPnts_AbscissaPoint::Length(a, f, (f + l) / 2));
  printf("  parameter at half length from first = %.17g\n", GCPnts_AbscissaPoint(a, 5.0, f).Parameter());
  GCPnts_QuasiUniformAbscissa q(a, 10);
  printf("  quasi-uniform 10:");
  for (int i = 1; i <= q.NbPoints(); i++)
    printf(" %.17g", q.Parameter(i));
  printf("\n");

  TopoDS_Shape               sph = BRepPrimAPI_MakeSphere(10).Shape();
  TopTools_IndexedMapOfShape sm;
  TopExp::MapShapes(sph, TopAbs_EDGE, sm);
  BRepAdaptor_Curve s(TopoDS::Edge(sm(1)));
  printf("sphere edge[0]: degenerated=%d type=%d domain=[%.17g, %.17g]\n",
         BRep_Tool::Degenerated(TopoDS::Edge(sm(1))), (int)s.GetType(), s.FirstParameter(), s.LastParameter());
  for (auto p : {std::make_pair(0.1, 0.1), std::make_pair(0.5, 1.0), std::make_pair(0.05, 0.01)})
  {
    GCPnts_TangentialDeflection t(s, p.first, p.second, 2);
    printf("  tangential deflection (%g, %g): %d points\n", p.first, p.second, t.NbPoints());
  }

  for (int k = 1; k <= sm.Extent(); k++)
    if (!BRep_Tool::Degenerated(TopoDS::Edge(sm(k))))
    {
      BRepAdaptor_Curve seam(TopoDS::Edge(sm(k)));
      printf("sphere seam edge[%d]: type=%d domain=[%.17g, %.17g]\n", k - 1, (int)seam.GetType(), seam.FirstParameter(), seam.LastParameter());
      for (auto p : {std::make_pair(0.1, 0.1), std::make_pair(0.5, 1.0), std::make_pair(0.05, 0.01)})
        printf("  seam tangential deflection (%g, %g): %d points\n", p.first, p.second, GCPnts_TangentialDeflection(seam, p.first, p.second, 2).NbPoints());
    }
  approx("circle r=10 tol 1e-3 C2", new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 10), 1e-3, GeomAbs_C2);
  approx("line (1,1,0) trimmed [0, 10] tol 1e-6 C1",
         new Geom_TrimmedCurve(new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 1, 0)), 0, 10), 1e-6, GeomAbs_C1);
  return 0;
}
