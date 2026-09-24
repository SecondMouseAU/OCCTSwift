// #766 kernel parity: FreeBoundsTests, GeometryConversionTests.
// ShapeAnalysis_FreeBounds (OCCTShapeFreeBounds, OCCTShapeFreeBoundsClosedCount/Closed/Open),
// ShapeFix_FreeBounds (OCCTShapeFixFreeBounds), ShapeCustom::ConvertToBSpline /
// ConvertToRevolution (OCCTShapeCustomConvertToBSpline / ToRevolution).
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <BRep_Builder.hxx>
#include <ShapeAnalysis_FreeBounds.hxx>
#include <ShapeFix_FreeBounds.hxx>
#include <ShapeCustom.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <cstdio>

static int count(const TopoDS_Shape& s, TopAbs_ShapeEnum t)
{
  if (s.IsNull())
    return -1;
  int n = 0;
  for (TopExp_Explorer e(s, t); e.More(); e.Next())
    n++;
  return n;
}

// Wire.rectangle(width:height:) is centred on the origin in the XY plane.
static TopoDS_Face rect(double w, double h, double dx, double dy)
{
  BRepBuilderAPI_MakePolygon p(gp_Pnt(-w / 2 + dx, -h / 2 + dy, 0), gp_Pnt(w / 2 + dx, -h / 2 + dy, 0),
                               gp_Pnt(w / 2 + dx, h / 2 + dy, 0), gp_Pnt(-w / 2 + dx, h / 2 + dy, 0),
                               Standard_True);
  return BRepBuilderAPI_MakeFace(p.Wire());
}

static void fb(const char* label, const TopoDS_Shape& s, double tol)
{
  ShapeAnalysis_FreeBounds a(s, tol);
  TopoDS_Compound          c = a.GetClosedWires(), o = a.GetOpenWires();
  printf("%s (tol %g): closedWires=%d closedEdges=%d openWires=%d\n", label, tol, count(c, TopAbs_WIRE),
         count(c, TopAbs_EDGE), count(o, TopAbs_WIRE));
}

static void report(const char* label, const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p);
  const char* n[] = {"plane", "cylinder", "cone", "sphere", "torus", "bezier",
                     "bspline", "revolution", "extrusion", "offset", "other"};
  int         k[11] = {0};
  for (TopExp_Explorer e(s, TopAbs_FACE); e.More(); e.Next())
    k[BRepAdaptor_Surface(TopoDS::Face(e.Current())).GetType()]++;
  printf("%s: valid=%d faces=%d volume=%.9f surfaces:", label, (int)BRepCheck_Analyzer(s).IsValid(),
         count(s, TopAbs_FACE), p.Mass());
  for (int i = 0; i < 11; i++)
    if (k[i])
      printf(" %s=%d", n[i], k[i]);
  printf("\n");
}

int main()
{
  TopoDS_Shape box    = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopoDS_Shape sphere = BRepPrimAPI_MakeSphere(5).Shape();
  fb("box", box, 1e-6);
  fb("sphere r5", sphere, 1e-6);

  BRep_Builder    b;
  TopoDS_Compound adj;
  b.MakeCompound(adj);
  b.Add(adj, rect(10, 10, 0, 0));
  b.Add(adj, rect(10, 10, 10, 0));
  fb("two adjacent 10x10 faces", adj, 1e-6);

  {
    ShapeFix_FreeBounds fx(rect(10, 10, 0, 0), 1e-6, 1e-4, Standard_True, Standard_True);
    printf("ShapeFix_FreeBounds(lone face): shapeFaces=%d closedWires=%d openWires=%d\n",
           count(fx.GetShape(), TopAbs_FACE), count(fx.GetClosedWires(), TopAbs_WIRE),
           count(fx.GetOpenWires(), TopAbs_WIRE));
  }
  TopoDS_Compound dis;
  b.MakeCompound(dis);
  b.Add(dis, rect(1, 1, 0, 0));
  b.Add(dis, rect(1, 1, 5, 5));
  fb("two disjoint 1x1 faces", dis, 0.01);

  TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(5, 10).Shape();
  report("cylinder", cyl);
  report("ConvertToBSpline(cyl, T,T,T,F)", ShapeCustom::ConvertToBSpline(cyl, true, true, true, false));
  report("ConvertToBSpline(cyl, T,T,T,T)", ShapeCustom::ConvertToBSpline(cyl, true, true, true, true));
  report("ConvertToRevolution(cyl)", ShapeCustom::ConvertToRevolution(cyl));
  return 0;
}
