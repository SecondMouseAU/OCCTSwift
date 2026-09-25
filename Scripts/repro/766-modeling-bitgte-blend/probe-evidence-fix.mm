// Epic #766 evidence correction for PR #2666 (Tests/OCCTModelingTests/BiTgteBlendTests.swift).
// probe.mm printed the kernel side at %.10g; the parity records now carry the same keys on both
// sides, so this probe repeats the same OCCT calls and prints every flag as true/false, the shape
// type by its OCCT name and every double at %.17g, one `label: key=value ...` line per test.
// OCCTBiTgteBlend is BiTgte_Blend(shape, radius, tol=1e-3, nubs=false), SetEdge per index into
// the TopExp::MapShapes edge enumeration, Perform(true). Same inputs as the Swift tests.
//
// #766 addition, blendConcaveEdge: blendBoxEdge and blendMultipleEdges blend CONVEX box edges, where
// BiTgte_Blend hands back the box's own faces and volume, so they do not exercise a blend. The L-shaped
// solid (a 40 x 40 x 10 slab fused with a 40 x 10 x 30 wall, BRepAlgoAPI_Fuse with SetArguments /
// SetTools and Build as Shape.union runs it: 14 faces, 24000) has one concave edge, the inner corner
// along X at y = 10, z = 10, found here by its vertices; a ball of radius 3 rolled along it adds three
// blend surfaces (17 faces) and 76.8 mm3. Measured edge by edge (probe-concave-scan.mm and
// transcript-concave-scan.txt, committed beside this file), it is the only one of the 28 edges of that
// solid on which the blend changes anything. `halfRadius*` is the same blend at radius 1.5, which the
// proof uses as the wrong-radius control: 17 faces and 24019.261, so the volume names the radius.
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRep_Tool.hxx>
#include <TopTools_ListOfShape.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BiTgte_Blend.hxx>
#include <GProp_GProps.hxx>
#include <TopAbs.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static const char* tf(bool b) { return b ? "true" : "false"; }

static void blend(const char* label, double w, double h, double d, std::initializer_list<int> idx, double r)
{
  TopoDS_Shape               box = BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 0), w, h, d).Shape();
  TopTools_IndexedMapOfShape edges;
  TopExp::MapShapes(box, TopAbs_EDGE, edges);
  BiTgte_Blend b(box, r, 1e-3, false);
  for (int i : idx)
    b.SetEdge(TopoDS::Edge(edges(i + 1)));
  b.Perform(true);
  bool done = b.IsDone() && !b.Shape().IsNull();
  printf("%s: done=%s", label, tf(done));
  if (done)
  {
    GProp_GProps p;
    BRepGProp::VolumeProperties(b.Shape(), p);
    int faces = 0;
    for (TopExp_Explorer ex(b.Shape(), TopAbs_FACE); ex.More(); ex.Next())
      faces++;
    printf(" type=\"%s\" faces=%d valid=%s volume=%.17g", TopAbs::ShapeTypeToString(b.Shape().ShapeType()), faces,
           tf(BRepCheck_Analyzer(b.Shape()).IsValid()), p.Mass());
  }
  printf("\n");
}

static int distinctFaces(const TopoDS_Shape& s)
{
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(s, TopAbs_FACE, m);
  return m.Extent();
}

static double volumeOf(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p);
  return p.Mass();
}

// #766: one blend of the L-shaped solid's concave edge at the given radius.
static TopoDS_Shape blendCorner(const TopoDS_Shape& l, const TopoDS_Edge& e, double r, bool& done)
{
  BiTgte_Blend b(l, r, 1e-3, false);
  b.SetEdge(e);
  b.Perform(true);
  done = b.IsDone() && !b.Shape().IsNull();
  return done ? b.Shape() : TopoDS_Shape();
}

static void blendConcave()
{
  TopoDS_Shape        slab = BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 0), 40, 40, 10).Shape();
  TopoDS_Shape        wall = BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 0), 40, 10, 30).Shape();
  BRepAlgoAPI_Fuse    fuse;
  TopTools_ListOfShape args, tools;
  args.Append(slab);
  tools.Append(wall);
  fuse.SetArguments(args);
  fuse.SetTools(tools);
  fuse.Build();
  TopoDS_Shape l = fuse.Shape();

  // The concave edge, by its vertices: both inside x -1..41, y 9.5..10.5, z 9.5..10.5.
  TopTools_IndexedMapOfShape edges;
  TopExp::MapShapes(l, TopAbs_EDGE, edges);
  auto inside = [](const gp_Pnt& p) {
    return p.X() > -1 && p.X() < 41 && p.Y() > 9.5 && p.Y() < 10.5 && p.Z() > 9.5 && p.Z() < 10.5;
  };
  int corners = 0, index = -1;
  for (int i = 1; i <= edges.Extent(); i++)
  {
    const TopoDS_Edge& e = TopoDS::Edge(edges(i));
    if (inside(BRep_Tool::Pnt(TopExp::FirstVertex(e))) && inside(BRep_Tool::Pnt(TopExp::LastVertex(e))))
    {
      corners++;
      index = i - 1;
    }
  }
  bool         done = false, halfDone = false;
  TopoDS_Shape r3   = blendCorner(l, TopoDS::Edge(edges(index + 1)), 3.0, done);
  TopoDS_Shape r15  = blendCorner(l, TopoDS::Edge(edges(index + 1)), 1.5, halfDone);
  printf("blendConcaveEdge: cornerEdges=%d edgeIndex=%d inputFaces=%d inputVolume=%.17g done=%s", corners, index,
         distinctFaces(l), volumeOf(l), tf(done));
  if (done)
    printf(" type=\"%s\" faces=%d valid=%s volume=%.17g halfRadiusFaces=%d halfRadiusVolume=%.17g",
           TopAbs::ShapeTypeToString(r3.ShapeType()), distinctFaces(r3), tf(BRepCheck_Analyzer(r3).IsValid()),
           volumeOf(r3), halfDone ? distinctFaces(r15) : 0, halfDone ? volumeOf(r15) : 0.0);
  printf("\n");
}

int main()
{
  blend("blendBoxEdge", 100, 80, 60, {0}, 5);
  blend("blendMultipleEdges", 50, 50, 50, {0, 1}, 3);
  blendConcave();
  return 0;
}
