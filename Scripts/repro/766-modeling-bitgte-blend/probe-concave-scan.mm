// Epic #766, PR #2666: which edges of an L-shaped solid does BiTgte_Blend change?
// blendBoxEdge and blendMultipleEdges blend convex box edges and get the box back (a SHELL of its own
// faces and volume), so blendConcaveEdge was added on a solid with a concave edge. This probe blends
// EVERY edge of that solid, one at a time, with the bridge's own call (OCCTBiTgteBlend:
// BiTgte_Blend(shape, r, 1e-3, false), SetEdge, Perform(true)) at r = 3, and prints the faces and
// volume of each result. The solid is the one blendConcaveEdge builds: a 40 x 40 x 10 slab fused with
// a 40 x 10 x 30 wall (BRepAlgoAPI_Fuse with SetArguments/SetTools and Build, as Shape.union runs it),
// 14 faces and 24000 mm3. Edge indices are 0-based positions in the TopExp::MapShapes enumeration, as
// Shape.biTgteBlend(edgeIndices:) takes them.
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BiTgte_Blend.hxx>
#include <GProp_GProps.hxx>
#include <TopAbs.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

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

int main()
{
  TopoDS_Shape         slab = BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 0), 40, 40, 10).Shape();
  TopoDS_Shape         wall = BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 0), 40, 10, 30).Shape();
  BRepAlgoAPI_Fuse     fuse;
  TopTools_ListOfShape args, tools;
  args.Append(slab);
  tools.Append(wall);
  fuse.SetArguments(args);
  fuse.SetTools(tools);
  fuse.Build();
  TopoDS_Shape l = fuse.Shape();

  TopTools_IndexedMapOfShape edges;
  TopExp::MapShapes(l, TopAbs_EDGE, edges);
  const int    inFaces = distinctFaces(l);
  const double inVol   = volumeOf(l);
  printf("input: faces=%d volume=%.17g edges=%d\n", inFaces, inVol, edges.Extent());
  int changed = 0, changedIndex = -1;
  for (int i = 1; i <= edges.Extent(); i++)
  {
    BiTgte_Blend b(l, 3.0, 1e-3, false);
    b.SetEdge(TopoDS::Edge(edges(i)));
    b.Perform(true);
    const bool done = b.IsDone() && !b.Shape().IsNull();
    const int  f    = done ? distinctFaces(b.Shape()) : -1;
    const double v  = done ? volumeOf(b.Shape()) : 0.0;
    const bool same = done && f == inFaces && v > inVol - 1e-6 && v < inVol + 1e-6;
    printf("edge %d: done=%s faces=%d volume=%.17g %s\n", i - 1, done ? "true" : "false", f, v,
           same ? "unchanged" : "CHANGED");
    if (!same)
    {
      changed++;
      changedIndex = i - 1;
    }
  }
  printf("summary: %d of %d edges change the shape, the last at index %d\n", changed, edges.Extent(), changedIndex);
  return 0;
}
