// Epic #766, Tests/OCCTModelingTests/AAGTests.swift: kernel parity for all six tests.
// Same inputs as the Swift tests, straight to OCCT. Adjacency is TopExp face-pair edge sharing
// (what OCCTFaceGetSharedEdgeSummary counts); convexity is ChFi3d::DefineConnectType with
// SinTol 0.01 and CorrectPoint=true (what OCCTEdgeGetConvexity calls); the fillet is
// BRepFilletAPI_MakeFillet on every edge (OCCTShapeFillet).
#include <BRepAdaptor_Surface.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepGProp.hxx>
#include <BRepLProp_SLProps.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRep_Tool.hxx>
#include <ChFi3d.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>
#include <vector>

static TopoDS_Shape box(double x, double y, double z, double w, double h, double d)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(x, y, z), w, h, d).Shape();
}

static double volume(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p);
  return p.Mass();
}

// Face-pair adjacency the way AAG.buildGraph() walks it: every unordered pair of faces, the
// number of edges they share by IsSame, and the connect type of the first shared edge.
static void graph(const char* label, const TopoDS_Shape& s)
{
  std::vector<TopoDS_Face> faces;
  for (TopExp_Explorer ex(s, TopAbs_FACE); ex.More(); ex.Next())
    faces.push_back(TopoDS::Face(ex.Current()));
  int nEdges = 0, convex = 0, concave = 0, smooth = 0, other = 0;
  std::vector<int> degree(faces.size(), 0);
  for (size_t i = 0; i < faces.size(); i++)
    for (size_t j = i + 1; j < faces.size(); j++)
    {
      TopTools_IndexedMapOfShape e1, e2;
      TopExp::MapShapes(faces[i], TopAbs_EDGE, e1);
      TopExp::MapShapes(faces[j], TopAbs_EDGE, e2);
      int         shared = 0;
      TopoDS_Edge first;
      for (int a = 1; a <= e1.Extent(); a++)
        for (int b = 1; b <= e2.Extent(); b++)
          if (e1(a).IsSame(e2(b)))
          {
            if (shared == 0)
              first = TopoDS::Edge(e1(a));
            shared++;
            break;
          }
      if (shared == 0)
        continue;
      nEdges++;
      degree[i]++;
      degree[j]++;
      switch (ChFi3d::DefineConnectType(first, faces[i], faces[j], 0.01, true))
      {
        case ChFiDS_Convex: convex++; break;
        case ChFiDS_Concave: concave++; break;
        case ChFiDS_Tangential: smooth++; break;
        default: other++; break;
      }
    }
  printf("%s: faces=%zu adjacentPairs=%d convex=%d concave=%d smooth=%d other=%d degrees=[",
         label, faces.size(), nEdges, convex, concave, smooth, other);
  for (size_t i = 0; i < degree.size(); i++)
    printf("%s%d", i ? "," : "", degree[i]);
  printf("]\n");
}

int main()
{
  // boxAAG, aagNeighbors, aagEdgeBetween: Shape.box(10,10,10) is centred at the origin.
  TopoDS_Shape b10 = box(-5, -5, -5, 10, 10, 10);
  graph("box10", b10);

  // aagNodeNormals: every face planar, normal defined at the UV centre.
  int idx = 0;
  for (TopExp_Explorer ex(b10, TopAbs_FACE); ex.More(); ex.Next(), idx++)
  {
    TopoDS_Face         f = TopoDS::Face(ex.Current());
    BRepAdaptor_Surface s(f);
    double u = (s.FirstUParameter() + s.LastUParameter()) / 2;
    double v = (s.FirstVParameter() + s.LastVParameter()) / 2;
    BRepLProp_SLProps   p(s, u, v, 1, 1e-6);
    gp_Dir              n = p.Normal();
    if (f.Orientation() == TopAbs_REVERSED)
      n.Reverse();
    printf("box10 face %d: planar=%d normalDefined=%d normal=(%g, %g, %g)\n", idx,
           s.GetType() == GeomAbs_Plane, p.IsNormalDefined(), n.X(), n.Y(), n.Z());
  }

  // detectPocket: 20 box minus a 10x10x15 tool from z=0 through the top.
  TopoDS_Shape    b20 = box(-10, -10, -10, 20, 20, 20);
  BRepAlgoAPI_Cut cut(b20, box(-5, -5, 0, 10, 10, 15));
  printf("pocket: done=%d boxVolume=%.10g resultVolume=%.10g\n", cut.IsDone(), volume(b20),
         volume(cut.Shape()));
  graph("pocket", cut.Shape());

  // convexConcaveNeighbors: every edge of the 10 box filleted at r=1.
  BRepFilletAPI_MakeFillet mf(b10);
  for (TopExp_Explorer ex(b10, TopAbs_EDGE); ex.More(); ex.Next())
    mf.Add(1.0, TopoDS::Edge(ex.Current()));
  mf.Build();
  printf("fillet: done=%d\n", mf.IsDone());
  if (mf.IsDone())
    graph("filleted", mf.Shape());
  return 0;
}
