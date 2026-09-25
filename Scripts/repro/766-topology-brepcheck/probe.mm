// Epic #766, BRepCheckExtendedTests.swift and BRepCheckSubShapeTests.swift: kernel parity for all
// twelve tests. Same inputs as the Swift tests, straight to OCCT: the centred box
// OCCTShapeCreateBox builds, sub-shapes by TopExp::MapShapes (occtSubShapeAt), BRepCheck_Analyzer
// statuses (occtBRepCheckSubShapeStatus), ShapeAnalysis_ShapeTolerance (OCCTShapeMax/Min/Avg-
// Tolerance), ShapeFix_ShapeTolerance (OCCTShapeFixTolerance, OCCTShapeLimitMaxTolerance), and
// BRepCheck_Edge/Wire/Shell/Vertex::Minimum (checkSubShape).
#include <BRepCheck_Analyzer.hxx>
#include <BRepCheck_Edge.hxx>
#include <BRepCheck_ListOfStatus.hxx>
#include <BRepCheck_Result.hxx>
#include <BRepCheck_Shell.hxx>
#include <BRepCheck_Vertex.hxx>
#include <BRepCheck_Wire.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <ShapeAnalysis_ShapeTolerance.hxx>
#include <ShapeFix_ShapeTolerance.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static TopoDS_Shape centredBox(double w, double h, double d)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-w / 2, -h / 2, -d / 2), w, h, d).Shape();
}

static TopoDS_Shape first(const TopoDS_Shape& s, TopAbs_ShapeEnum t)
{
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(s, t, m);
  return m(1);
}

static int analyzerStatus(const TopoDS_Shape& s, const TopoDS_Shape& sub)
{
  BRepCheck_Analyzer       a(s, Standard_True);
  Handle(BRepCheck_Result) r = a.Result(sub);
  if (r.IsNull())
    return -1;
  return r->Status().IsEmpty() ? 0 : (int)r->Status().First();
}

static int minimumErrors(Handle(BRepCheck_Result) r)
{
  r->Minimum();
  int n = 0;
  for (auto it = r->Status().begin(); it != r->Status().end(); ++it)
    if (*it != BRepCheck_NoError)
      n++;
  return n;
}

int main()
{
  TopoDS_Shape box = centredBox(10, 10, 10);
  printf("faceStatus: %d\n", analyzerStatus(box, first(box, TopAbs_FACE)));
  printf("edgeStatus: %d\n", analyzerStatus(box, first(box, TopAbs_EDGE)));
  printf("vertexStatus: %d\n", analyzerStatus(box, first(box, TopAbs_VERTEX)));

  ShapeAnalysis_ShapeTolerance sat;
  printf("maxTolerance(vertex): %.17g\n", sat.Tolerance(box, 1, TopAbs_VERTEX));
  printf("minTolerance(vertex): %.17g\n", sat.Tolerance(box, -1, TopAbs_VERTEX));
  printf("edge tolerance min/avg/max: %.17g %.17g %.17g\n", sat.Tolerance(box, -1, TopAbs_EDGE),
         sat.Tolerance(box, 0, TopAbs_EDGE), sat.Tolerance(box, 1, TopAbs_EDGE));

  {
    TopoDS_Shape b = centredBox(10, 10, 10);
    ShapeFix_ShapeTolerance().SetTolerance(b, 0.01);
    printf("fixTolerance(0.01): vertex max %.17g min %.17g, edge max %.17g, face max %.17g\n",
           sat.Tolerance(b, 1, TopAbs_VERTEX), sat.Tolerance(b, -1, TopAbs_VERTEX),
           sat.Tolerance(b, 1, TopAbs_EDGE), sat.Tolerance(b, 1, TopAbs_FACE));
  }
  {
    TopoDS_Shape b       = centredBox(10, 10, 10);
    bool         limited = ShapeFix_ShapeTolerance().LimitTolerance(b, 0.0, 0.001);
    printf("limitMaxTolerance(0.001) on fresh box: %d, vertex max after %.17g\n", limited,
           sat.Tolerance(b, 1, TopAbs_VERTEX));
    ShapeFix_ShapeTolerance().SetTolerance(b, 0.01);
    limited = ShapeFix_ShapeTolerance().LimitTolerance(b, 0.0, 0.001);
    printf("limitMaxTolerance(0.001) after fix to 0.01: %d, vertex max %.17g, edge max %.17g\n",
           limited, sat.Tolerance(b, 1, TopAbs_VERTEX), sat.Tolerance(b, 1, TopAbs_EDGE));
  }

  printf("checkEdge(0) errors: %d\n",
         minimumErrors(new BRepCheck_Edge(TopoDS::Edge(first(box, TopAbs_EDGE)))));
  printf("checkWire(0) errors: %d\n",
         minimumErrors(new BRepCheck_Wire(TopoDS::Wire(first(box, TopAbs_WIRE)))));
  printf("checkShell(0) errors: %d\n",
         minimumErrors(new BRepCheck_Shell(TopoDS::Shell(first(box, TopAbs_SHELL)))));
  printf("checkVertex(0) errors: %d\n",
         minimumErrors(new BRepCheck_Vertex(TopoDS::Vertex(first(box, TopAbs_VERTEX)))));
  return 0;
}
