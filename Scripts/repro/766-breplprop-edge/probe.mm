// Kernel parity probe for Tests/OCCTAnalysisTests/BRepLPropEdgeTests.swift (#766).
//
// Same calls as OCCTEdgeLPropValue / Tangent / Curvature / D1 (OCCTBridge_Properties.mm):
// BRepLProp_CLProps(BRepAdaptor_Curve(edge), param, order, Precision::Confusion()), with the edge
// taken as the first TopAbs_EDGE of TopExp::MapShapes, which is what subShapes(ofType: .edge)[0]
// returns (OCCTShapeGetSubShapes). Inputs: Shape.box(10, 10, 10), centred, so
// BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10); and Shape.cylinder(radius: 5, height: 10),
// BRepPrimAPI_MakeCylinder(5, 10), whose first circular edge gives a non-zero curvature.
#include <BRepAdaptor_Curve.hxx>
#include <BRepLProp_CLProps.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <GeomAbs_CurveType.hxx>
#include <Precision.hxx>
#include <TopExp.hxx>
#include <TopoDS.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <cstdio>

static void edgeReport(const char* label, const TopoDS_Edge& e, double param)
{
  BRepAdaptor_Curve ac(e);
  printf("%s type=%d range=[%.17g, %.17g]\n", label, (int)ac.GetType(), ac.FirstParameter(), ac.LastParameter());
  BRepLProp_CLProps p2(ac, param, 2, Precision::Confusion());
  gp_Pnt            v = p2.Value();
  printf("%s value(%.17g)=(%.17g, %.17g, %.17g)\n", label, param, v.X(), v.Y(), v.Z());
  if (p2.IsTangentDefined())
  {
    gp_Dir t;
    p2.Tangent(t);
    printf("%s tangent=(%.17g, %.17g, %.17g)\n", label, t.X(), t.Y(), t.Z());
    printf("%s curvature=%.17g\n", label, p2.Curvature());
  }
  else
  {
    printf("%s tangent undefined\n", label);
  }
  BRepLProp_CLProps p1(ac, param, 1, Precision::Confusion());
  const gp_Vec&     d1 = p1.D1();
  printf("%s d1=(%.17g, %.17g, %.17g)\n", label, d1.X(), d1.Y(), d1.Z());
}

int main()
{
  {
    BRepPrimAPI_MakeBox        mk(gp_Pnt(-5, -5, -5), 10, 10, 10);
    TopTools_IndexedMapOfShape m;
    TopExp::MapShapes(mk.Shape(), TopAbs_EDGE, m);
    printf("box10 edges=%d\n", m.Extent());
    edgeReport("box10.edge[0]", TopoDS::Edge(m(1)), 0.5);
  }
  {
    BRepPrimAPI_MakeCylinder   mk(5, 10);
    TopTools_IndexedMapOfShape m;
    TopExp::MapShapes(mk.Shape(), TopAbs_EDGE, m);
    printf("cyl5x10 edges=%d\n", m.Extent());
    for (int i = 1; i <= m.Extent(); i++)
    {
      char label[64];
      snprintf(label, sizeof label, "cyl5x10.edge[%d]", i - 1);
      edgeReport(label, TopoDS::Edge(m(i)), 0.5);
    }
  }
  return 0;
}
