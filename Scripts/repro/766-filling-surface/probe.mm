// Epic #766, FillingSurfaceTests.swift: kernel parity for the six tests. FillingSurface() with its
// defaults builds BRepOffsetAPI_MakeFilling(3, 15, 2, false, 1e-5, 1e-4, 0.01, 0.1, 8, 9)
// (occtFillingMakeBuilder), and a .g0 edge goes in as Add(edge, GeomAbs_C0, isBound)
// (occtFillingAddConstraint's C0 path). The edges are the first four of the centred 10-box in
// TopExp::MapShapes order, as Shape.edges() enumerates them.
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepExtrema_DistShapeShape.hxx>
#include <BRepGProp.hxx>
#include <BRepOffsetAPI_MakeFilling.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRep_Tool.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <cstdio>

static TopTools_IndexedMapOfShape edges()
{
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape(), TopAbs_EDGE, m);
  return m;
}

static void report(const char* name, BRepOffsetAPI_MakeFilling& f)
{
  f.Build();
  printf("%s: IsDone=%d", name, f.IsDone());
  if (f.IsDone())
  {
    GProp_GProps g;
    BRepGProp::SurfaceProperties(f.Shape(), g);
    printf(" area=%.17g G0Error=%.17g G1Error=%.17g G2Error=%.17g", g.Mass(), f.G0Error(), f.G1Error(), f.G2Error());
    BRepExtrema_DistShapeShape d(BRepBuilderAPI_MakeVertex(gp_Pnt(5, 5, 3)).Vertex(), f.Shape());
    printf(" dist((5,5,3))=%.17g", d.Value());
  }
  printf("\n");
}

int main()
{
  TopTools_IndexedMapOfShape m = edges();
  for (int i = 1; i <= 4; i++)
  {
    TopoDS_Edge e = TopoDS::Edge(m(i));
    gp_Pnt      a = BRep_Tool::Pnt(TopExp::FirstVertex(e)), b = BRep_Tool::Pnt(TopExp::LastVertex(e));
    printf("edge[%d]: (%g,%g,%g)-(%g,%g,%g)\n", i - 1, a.X(), a.Y(), a.Z(), b.X(), b.Y(), b.Z());
  }
  {
    BRepOffsetAPI_MakeFilling f(3, 15, 2, false, 1e-5, 1e-4, 0.01, 0.1, 8, 9);
    for (int i = 1; i <= 4; i++)
      f.Add(TopoDS::Edge(m(i)), GeomAbs_C0, true);
    report("basicFilling / g0Error / g1g2Errors", f);
  }
  {
    BRepOffsetAPI_MakeFilling f(3, 15, 2, false, 1e-5, 1e-4, 0.01, 0.1, 8, 9);
    for (int i = 1; i <= 4; i++)
      f.Add(TopoDS::Edge(m(i)), GeomAbs_C0, true);
    f.Add(gp_Pnt(5, 5, 3));
    report("fillingWithPoint", f);
  }
  {
    BRepOffsetAPI_MakeFilling f(3, 15, 2, false, 1e-5, 1e-4, 0.01, 0.1, 8, 9);
    for (int i = 1; i <= 3; i++)
      f.Add(TopoDS::Edge(m(i)), GeomAbs_C0, true);
    f.Add(TopoDS::Edge(m(4)), GeomAbs_C0, false);
    report("freeEdgeConstraint", f);
  }
  {
    BRepOffsetAPI_MakeFilling f(3, 15, 2, false, 1e-5, 1e-4, 0.01, 0.1, 8, 9);
    printf("notDoneBeforeBuild: IsDone=%d\n", f.IsDone());
  }
  return 0;
}
