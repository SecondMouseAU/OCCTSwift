// #766 kernel parity: SewingBuilderTests, SewingExtendedTests, SewingExtrasTests, SewingTests.
// BRepBuilderAPI_Sewing driven the way SewingBuilder (OCCTSewing*) and Shape.sew
// (OCCTShapeSew / OCCTShapeSewTwo) drive it, on the same inputs.
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <GC_MakeCircle.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static int unique(const TopoDS_Shape& s, TopAbs_ShapeEnum t)
{
  if (s.IsNull())
    return -1;
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(s, t, m);
  return m.Extent();
}

static void stats(const char* label, BRepBuilderAPI_Sewing& sw)
{
  TopoDS_Shape r = sw.SewedShape();
  printf("%s: null=%d type=%d faces=%d valid=%d free=%d contig=%d degen=%d multiple=%d deletedFaces=%d\n", label,
         (int)r.IsNull(), r.IsNull() ? -1 : (int)r.ShapeType(), unique(r, TopAbs_FACE),
         r.IsNull() ? -1 : (int)BRepCheck_Analyzer(r).IsValid(), sw.NbFreeEdges(), sw.NbContigousEdges(),
         sw.NbDegeneratedShapes(), sw.NbMultipleEdges(), sw.NbDeletedFaces());
}

static TopoDS_Face rect(double w, double h)
{
  BRepBuilderAPI_MakePolygon p(gp_Pnt(-w / 2, -h / 2, 0), gp_Pnt(w / 2, -h / 2, 0), gp_Pnt(w / 2, h / 2, 0),
                               gp_Pnt(-w / 2, h / 2, 0), true);
  return BRepBuilderAPI_MakeFace(p.Wire());
}

static TopoDS_Face disc(double r)
{
  Handle(Geom_Circle) c = GC_MakeCircle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), r).Value();
  return BRepBuilderAPI_MakeFace(BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(c).Edge()).Wire());
}

int main()
{
  TopoDS_Shape               box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopTools_IndexedMapOfShape faces, edges;
  TopExp::MapShapes(box, TopAbs_FACE, faces);
  TopExp::MapShapes(box, TopAbs_EDGE, edges);
  {
    BRepBuilderAPI_Sewing sw(1e-6);
    printf("before Perform: SewedShape null=%d\n", (int)sw.SewedShape().IsNull());
    for (int i = 1; i <= 6; i++)
      sw.Add(faces(i));
    sw.Perform();
    stats("six box faces, 1e-6", sw);
  }
  {
    BRepBuilderAPI_Sewing sw(1e-6);
    for (int i = 1; i <= 5; i++)
      sw.Add(faces(i));
    sw.Perform();
    stats("five box faces, 1e-6", sw);
  }
  {
    TopoDS_Shape          t = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -0.005), 10, 10, 0.01).Shape();
    BRepBuilderAPI_Sewing sw(1e-3);
    sw.Add(t);
    sw.Add(BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -0.005), 10, 10, 0.01).Shape());
    sw.Perform();
    stats("two coincident thin boxes, 1e-3", sw);
  }
  {
    BRepBuilderAPI_Sewing sw(1e-3);
    sw.Add(faces(1));
    sw.Add(faces(2));
    sw.Perform();
    stats("box faces 1 and 2, 1e-3", sw);
    printf("  IsModified(face1)=%d IsModified(face2)=%d\n", (int)sw.IsModified(faces(1)), (int)sw.IsModified(faces(2)));
  }
  {
    BRepBuilderAPI_Sewing sw(1e-3);
    sw.Add(box);
    sw.Perform();
    stats("whole box, 1e-3", sw);
    printf("  IsDegenerated(box)=%d IsSectionBound(edge1)=%d WhichFace(edge1) null=%d\n", (int)sw.IsDegenerated(box),
           (int)sw.IsSectionBound(TopoDS::Edge(edges(1))), (int)sw.WhichFace(TopoDS::Edge(edges(1))).IsNull());
  }
  {
    BRepBuilderAPI_Sewing sw(1e-3);
    sw.Load(box);
    sw.SetNonManifoldMode(true);
    sw.SetFaceMode(true);
    sw.SetFloatingEdgesMode(false);
    sw.SetMinTolerance(1e-6);
    sw.SetMaxTolerance(1e-1);
    sw.Perform();
    stats("Load(box) + modes", sw);
  }
  {
    BRepBuilderAPI_Sewing sw(1e-6);
    sw.Add(box);
    sw.Perform();
    stats("whole box, 1e-6", sw);
  }
  // Shape.sew: rect 10x10 + disc r5; rect 10 + disc 5 + rect 8
  {
    BRepBuilderAPI_Sewing sw(1e-6);
    sw.Add(rect(10, 10));
    sw.Add(disc(5));
    sw.Perform();
    stats("rect10 + disc5", sw);
  }
  {
    BRepBuilderAPI_Sewing sw(1e-6);
    sw.Add(rect(10, 10));
    sw.Add(disc(5));
    sw.Add(rect(8, 8));
    sw.Perform();
    stats("rect10 + disc5 + rect8", sw);
  }
  // non-manifold T: three faces sharing the edge (0,0,0)-(10,0,0)
  {
    auto quad = [](gp_Pnt a, gp_Pnt b, gp_Pnt c, gp_Pnt d) {
      return BRepBuilderAPI_MakeFace(BRepBuilderAPI_MakePolygon(a, b, c, d, true).Wire()).Face();
    };
    BRepBuilderAPI_Sewing sw(1e-6);
    sw.SetNonManifoldMode(true);
    sw.Add(quad(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10, 10, 0), gp_Pnt(0, 10, 0)));
    sw.Add(quad(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10, -10, 0), gp_Pnt(0, -10, 0)));
    sw.Add(quad(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10, 0, 10), gp_Pnt(0, 0, 10)));
    sw.Perform();
    stats("three faces on one edge, non-manifold", sw);
  }
  return 0;
}
