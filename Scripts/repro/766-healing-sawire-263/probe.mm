// #766 kernel parity: SAWireAnalysisTests, SelfIntersectingProfileGuard263.
// ShapeAnalysis_Wire on the box's first mapped face and its first mapped wire, precision 1e-6
// (the SAWireAnalysis default), each check run on a freshly Init'd analyser as each bridge
// function does; distances read after CheckGaps3d / CheckGaps2d as OCCTWire*Distance* do.
// #263: BRepCheck on the bowtie and square profiles as planar faces (occtHasSelfIntersectingWire).
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepCheck_Result.hxx>
#include <BRepCheck_ListOfStatus.hxx>
#include <ShapeAnalysis_Wire.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static TopoDS_Wire W;
static TopoDS_Face F;

static Handle(ShapeAnalysis_Wire) saw()
{
  Handle(ShapeAnalysis_Wire) s = new ShapeAnalysis_Wire();
  s->Init(W, F, 1e-6);
  return s;
}

int main()
{
  TopoDS_Shape               box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopTools_IndexedMapOfShape faces, wires;
  TopExp::MapShapes(box, TopAbs_FACE, faces);
  F = TopoDS::Face(faces(1));
  TopExp::MapShapes(F, TopAbs_WIRE, wires);
  W = TopoDS::Wire(wires(1));
  printf("IsReady=%d NbEdges=%d\n", (int)saw()->IsReady(), saw()->NbEdges());
  printf("CheckOrder=%d CheckConnected=%d CheckSmall=%d CheckDegenerated=%d CheckClosed=%d CheckGaps3d=%d CheckGaps2d=%d\n",
         (int)saw()->CheckOrder(), (int)saw()->CheckConnected(), (int)saw()->CheckSmall(1e-6),
         (int)saw()->CheckDegenerated(), (int)saw()->CheckClosed(), (int)saw()->CheckGaps3d(), (int)saw()->CheckGaps2d());
  printf("CheckSelfIntersection=%d CheckEdgeCurves=%d CheckLacking=%d\n", (int)saw()->CheckSelfIntersection(),
         (int)saw()->CheckEdgeCurves(), (int)saw()->CheckLacking());
  printf("edge 1: CheckConnected=%d CheckSmall=%d CheckDegenerated=%d CheckGap3d=%d\n", (int)saw()->CheckConnected(1),
         (int)saw()->CheckSmall(1), (int)saw()->CheckDegenerated(1), (int)saw()->CheckGap3d(1));
  {
    auto s = saw();
    s->CheckGaps3d();
    double mn3 = s->MinDistance3d(), mx3 = s->MaxDistance3d();
    auto   t = saw();
    t->CheckGaps2d();
    printf("MinDistance3d=%.3e MaxDistance3d=%.3e MinDistance2d=%.3e MaxDistance2d=%.3e\n", mn3, mx3,
           t->MinDistance2d(), t->MaxDistance2d());
  }
  printf("CheckOuterBound=%d\n", (int)saw()->CheckOuterBound());
  // Why the checks above fire on a healthy box: the mapped wire's own orientation.
  printf("mapped wire orientation=%d (FORWARD=0 REVERSED=1)\n", (int)W.Orientation());
  TopoDS_Wire keep = W;
  W                = TopoDS::Wire(keep.Oriented(TopAbs_FORWARD));
  printf("same wire oriented FORWARD: CheckOrder=%d CheckGaps3d=%d CheckEdgeCurves=%d\n", (int)saw()->CheckOrder(),
         (int)saw()->CheckGaps3d(), (int)saw()->CheckEdgeCurves());
  TopExp_Explorer fw(F, TopAbs_WIRE);
  W = TopoDS::Wire(fw.Current());
  printf("wire as explored inside the face (orientation %d): CheckOrder=%d CheckGaps3d=%d CheckEdgeCurves=%d\n",
         (int)W.Orientation(), (int)saw()->CheckOrder(), (int)saw()->CheckGaps3d(), (int)saw()->CheckEdgeCurves());
  W = keep;

  for (int k = 0; k < 2; k++)
  {
    BRepBuilderAPI_MakePolygon p =
      k == 0 ? BRepBuilderAPI_MakePolygon(gp_Pnt(0, 0, 0), gp_Pnt(1, 1, 0), gp_Pnt(1, 0, 0), gp_Pnt(0, 1, 0), true)
             : BRepBuilderAPI_MakePolygon(gp_Pnt(0, 0, 0), gp_Pnt(1, 0, 0), gp_Pnt(1, 1, 0), gp_Pnt(0, 1, 0), true);
    TopoDS_Face        f = BRepBuilderAPI_MakeFace(p.Wire(), true);
    BRepCheck_Analyzer a(f);
    bool               flag = false;
    for (TopExp_Explorer we(f, TopAbs_WIRE); we.More(); we.Next())
    {
      Handle(BRepCheck_Result) r = a.Result(we.Current());
      if (!r.IsNull())
        for (BRepCheck_ListIteratorOfListOfStatus it(r->Status()); it.More(); it.Next())
          if (it.Value() == BRepCheck_SelfIntersectingWire)
            flag = true;
    }
    printf("#263 %s profile as a planar face: valid=%d selfIntersectingWire=%d\n", k == 0 ? "bowtie" : "square",
           (int)a.IsValid(), (int)flag);
  }
  return 0;
}
