// Epic #766 evidence correction for PR #2653 (Tests/OCCTModelingTests/AAGTests.swift).
// probe.mm measured the kernel side under names that differed from what the Swift tests observe.
// This probe repeats the same OCCT calls and prints exactly the quantities the parity records
// now carry on BOTH sides, at %.17g where a value is a double:
//   adjacency  = TopExp face-pair edge sharing by IsSame (what OCCTFaceGetSharedEdgeSummary counts)
//   convexity  = ChFi3d::DefineConnectType, SinTol 0.01, CorrectPoint=true (OCCTEdgeGetConvexity)
//   fillet     = BRepFilletAPI_MakeFillet on every edge at r=1 (OCCTShapeFillet)
//   normal     = BRepLProp_SLProps at the parametric midpoint, reversed for a REVERSED face
//                (OCCTFaceGetNormal)
#include <BRepAdaptor_Surface.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepGProp.hxx>
#include <BRepLProp_SLProps.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
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

struct Graph
{
  int              faces = 0, pairs = 0, convex = 0, concave = 0, smooth = 0, other = 0;
  std::vector<int> degree;
  std::vector<int> sharedPerPair;
};

// Every unordered face pair in explorer order, the number of edges the pair shares by IsSame,
// and the connect type of the first shared edge: the loop AAG.buildGraph() runs.
static Graph graph(const TopoDS_Shape& s)
{
  std::vector<TopoDS_Face> faces;
  for (TopExp_Explorer ex(s, TopAbs_FACE); ex.More(); ex.Next())
    faces.push_back(TopoDS::Face(ex.Current()));
  Graph g;
  g.faces = (int)faces.size();
  g.degree.assign(faces.size(), 0);
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
      g.pairs++;
      g.degree[i]++;
      g.degree[j]++;
      g.sharedPerPair.push_back(shared);
      switch (ChFi3d::DefineConnectType(first, faces[i], faces[j], 0.01, true))
      {
        case ChFiDS_Convex: g.convex++; break;
        case ChFiDS_Concave: g.concave++; break;
        case ChFiDS_Tangential: g.smooth++; break;
        default: g.other++; break;
      }
    }
  return g;
}

static void printList(const char* key, const std::vector<int>& v)
{
  printf(" %s=[", key);
  for (size_t i = 0; i < v.size(); i++)
    printf("%s%d", i ? "," : "", v[i]);
  printf("]");
}

int main()
{
  // boxAAG, aagNeighbors, aagEdgeBetween: Shape.box(10,10,10) is centred at the origin.
  TopoDS_Shape b10 = box(-5, -5, -5, 10, 10, 10);
  Graph        g10 = graph(b10);

  printf("boxAAG: faces=%d adjacentPairs=%d\n", g10.faces, g10.pairs);

  // aagNodeNormals: every face planar, normal defined at the parametric midpoint.
  int planar = 0, defined = 0;
  std::vector<double> normals;
  for (TopExp_Explorer ex(b10, TopAbs_FACE); ex.More(); ex.Next())
  {
    TopoDS_Face         f = TopoDS::Face(ex.Current());
    BRepAdaptor_Surface s(f);
    double u = (s.FirstUParameter() + s.LastUParameter()) / 2;
    double v = (s.FirstVParameter() + s.LastVParameter()) / 2;
    BRepLProp_SLProps   p(s, u, v, 1, 1e-6);
    planar += (s.GetType() == GeomAbs_Plane);
    defined += p.IsNormalDefined();
    gp_Dir n = p.Normal();
    if (f.Orientation() == TopAbs_REVERSED)
      n.Reverse();
    normals.push_back(n.X() + 0.0);
    normals.push_back(n.Y() + 0.0);
    normals.push_back(n.Z() + 0.0);
  }
  printf("aagNodeNormals: faces=%d normalDefined=%d planar=%d normals=[", g10.faces, defined, planar);
  for (size_t i = 0; i < normals.size(); i += 3)
    printf("%s[%.17g,%.17g,%.17g]", i ? "," : "", normals[i], normals[i + 1], normals[i + 2]);
  printf("]\n");

  printf("aagNeighbors:");
  printList("degrees", g10.degree);
  printf("\n");

  printf("aagEdgeBetween: adjacentPairs=%d", g10.pairs);
  printList("sharedEdgesPerAdjacentPair", g10.sharedPerPair);
  printf("\n");

  // detectPocket: 20 box minus a 10x10x15 tool from z=0 through the top.
  TopoDS_Shape    b20 = box(-10, -10, -10, 20, 20, 20);
  BRepAlgoAPI_Cut cut(b20, box(-5, -5, 0, 10, 10, 15));
  Graph           gp = graph(cut.Shape());
  printf("detectPocket: done=%d boxVolume=%.17g resultVolume=%.17g faces=%d concavePairs=%d convexPairs=%d\n",
         cut.IsDone(), volume(b20), volume(cut.Shape()), gp.faces, gp.concave, gp.convex);

  // convexConcaveNeighbors: every edge of the 10 box filleted at r=1.
  BRepFilletAPI_MakeFillet mf(b10);
  for (TopExp_Explorer ex(b10, TopAbs_EDGE); ex.More(); ex.Next())
    mf.Add(1.0, TopoDS::Edge(ex.Current()));
  mf.Build();
  Graph gf = graph(mf.Shape());
  printf("convexConcaveNeighbors: fillet.done=%d plainConvex=%d filletedFaces=%d filletedAdjacentPairs=%d "
         "filletedConvex=%d filletedConcave=%d filletedSmooth=%d\n",
         mf.IsDone(), g10.convex, gf.faces, gf.pairs, gf.convex, gf.concave, gf.smooth);
  return 0;
}
