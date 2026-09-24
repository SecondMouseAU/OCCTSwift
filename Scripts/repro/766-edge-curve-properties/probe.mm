// Kernel parity probe for Tests/OCCTAnalysisTests/EdgeCurvePropertiesTests.swift (#1820-#1828).
// Same inputs as the tests: Shape.box(10,10,10) is BRepPrimAPI_MakeBox from (-5,-5,-5), and
// Shape.cylinder(5,10) is BRepPrimAPI_MakeCylinder(5,10). Edges are enumerated the way
// Shape.edges() does (TopExp::MapShapes, index k -> map(k + 1)). Each quantity is read the way the
// bridge reads it: BRep_Tool::Curve + GeomLProp_CLProps at resolution Precision::Confusion().
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRep_Tool.hxx>
#include <GeomLProp_CLProps.hxx>
#include <Geom_Curve.hxx>
#include <Precision.hxx>
#include <TopExp.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Vertex.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <cstdio>

static void report(const char* label, const TopoDS_Edge& e)
{
  Standard_Real      f, l;
  Handle(Geom_Curve) c = BRep_Tool::Curve(e, f, l);
  BRepAdaptor_Curve  ad(e);
  printf("%s: type=%d first=%.6f last=%.6f\n", label, (int)ad.GetType(), f, l);
  double            mid = (f + l) / 2.0;
  GeomLProp_CLProps p(c, mid, 2, Precision::Confusion());
  printf("  curvature(mid)=%.12g\n", p.Curvature());
  gp_Dir t;
  p.Tangent(t);
  printf("  tangent(mid)=(%.6f, %.6f, %.6f)\n", t.X(), t.Y(), t.Z());
  gp_Pnt pm = c->Value(mid);
  printf("  point(mid)=(%.6f, %.6f, %.6f)\n", pm.X(), pm.Y(), pm.Z());
  if (p.Curvature() > Precision::Confusion())
  {
    gp_Dir n;
    p.Normal(n);
    gp_Pnt cc;
    p.CentreOfCurvature(cc);
    printf("  normal(mid)=(%.6f, %.6f, %.6f)\n", n.X(), n.Y(), n.Z());
    printf("  centreOfCurvature(mid)=(%.6f, %.6f, %.6f)\n", cc.X(), cc.Y(), cc.Z());
  }
  gp_Pnt pnt;
  gp_Vec d1, d2, d3;
  c->D3(mid, pnt, d1, d2, d3);
  gp_Vec x  = d1.Crossed(d2);
  double m2 = x.SquareMagnitude();
  printf("  torsion(mid)=%.12g\n", m2 < Precision::Confusion() ? 0.0 : x.Dot(d3) / m2);
  gp_Pnt        ps = c->Value(f), pe = c->Value(l);
  TopoDS_Vertex v1, v2;
  TopExp::Vertices(e, v1, v2);
  gp_Pnt s = BRep_Tool::Pnt(v1), en = BRep_Tool::Pnt(v2);
  printf("  point(first)=(%.6f, %.6f, %.6f) point(last)=(%.6f, %.6f, %.6f)\n",
         ps.X(), ps.Y(), ps.Z(), pe.X(), pe.Y(), pe.Z());
  printf("  endpoints start=(%.6f, %.6f, %.6f) end=(%.6f, %.6f, %.6f)\n",
         s.X(), s.Y(), s.Z(), en.X(), en.Y(), en.Z());
}

int main()
{
  TopoDS_Shape               box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopTools_IndexedMapOfShape boxEdges;
  TopExp::MapShapes(box, TopAbs_EDGE, boxEdges);
  printf("box edge count=%d\n", boxEdges.Extent());
  report("box edges()[0]", TopoDS::Edge(boxEdges(1)));

  TopoDS_Shape               cyl = BRepPrimAPI_MakeCylinder(5, 10).Shape();
  TopTools_IndexedMapOfShape cylEdges;
  TopExp::MapShapes(cyl, TopAbs_EDGE, cylEdges);
  printf("cylinder edge count=%d\n", cylEdges.Extent());
  for (int i = 1; i <= cylEdges.Extent(); ++i)
  {
    BRepAdaptor_Curve ad(TopoDS::Edge(cylEdges(i)));
    if (ad.GetType() == GeomAbs_Circle)
    {
      printf("first circle edge is edges()[%d]\n", i - 1);
      report("cylinder first circle edge", TopoDS::Edge(cylEdges(i)));
      break;
    }
  }
  return 0;
}
