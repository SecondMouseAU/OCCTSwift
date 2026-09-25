// PR #2487 evidence fix: probe.mm with (1) the four wire distances printed at %.17g instead of %.3e, and
// (2) a #263 section that makes the calls the bridge makes for the three SelfIntersectingProfileGuard263
// tests, rather than only the BRepCheck reading of the profile faces:
//   Shape.extrude(profile:)  OCCTShapeCreateExtrusion: BRepBuilderAPI_MakeFace(wire), then the
//                            occtHasSelfIntersectingWire guard (BRepCheck_Analyzer on the face, scanning the
//                            wire results for BRepCheck_SelfIntersectingWire), then BRepPrimAPI_MakePrism
//   Shape.healed()           OCCTShapeHeal: the same guard, then ShapeFix_Shape::Perform
//   Shape.face(from:planar:) BRepBuilderAPI_MakeFace(wire, OnlyPlane = true)
//   Shape.isValidSolid       OCCTShapeIsValidSolid: the shape is a SOLID and BRepCheck_Analyzer is valid
// The kernel itself does not refuse a bowtie profile; extruding and healing it corrupts the heap (#263,
// upstream), which cannot be run in-process. What the kernel supplies, and what is printed here, is the
// condition the bridge refuses on: BRepCheck_SelfIntersectingWire on the profile's face.
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
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <GProp_GProps.hxx>
#include <ShapeFix_Shape.hxx>
#include <ShapeAnalysis_Wire.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>


// occtHasSelfIntersectingWire for a shape that carries a face (its first branch).
static bool guardFlags(const TopoDS_Shape& s)
{
  BRepCheck_Analyzer a(s);
  if (a.IsValid())
    return false;
  for (TopExp_Explorer we(s, TopAbs_WIRE); we.More(); we.Next())
  {
    Handle(BRepCheck_Result) r = a.Result(we.Current());
    if (r.IsNull())
      continue;
    for (BRepCheck_ListIteratorOfListOfStatus it(r->Status()); it.More(); it.Next())
      if (it.Value() == BRepCheck_SelfIntersectingWire)
        return true;
  }
  return false;
}

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
    printf("MinDistance3d=%.17g MaxDistance3d=%.17g MinDistance2d=%.17g MaxDistance2d=%.17g\n", mn3, mx3,
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
  // #263 as the bridge runs it, for the bowtie and the square profile
  for (int k = 0; k < 2; k++)
  {
    const char* name = k == 0 ? "bowtie" : "square";
    BRepBuilderAPI_MakePolygon p =
      k == 0 ? BRepBuilderAPI_MakePolygon(gp_Pnt(0, 0, 0), gp_Pnt(1, 1, 0), gp_Pnt(1, 0, 0), gp_Pnt(0, 1, 0), true)
             : BRepBuilderAPI_MakePolygon(gp_Pnt(0, 0, 0), gp_Pnt(1, 0, 0), gp_Pnt(1, 1, 0), gp_Pnt(0, 1, 0), true);
    // extrude(profile: wire, direction: +Z, length: 1)
    TopoDS_Face extrudeFace = BRepBuilderAPI_MakeFace(p.Wire());
    bool        flagged     = guardFlags(extrudeFace);
    printf("#263 %s extrude: guardFlagged=%d (extrude returns nil when 1)", name, (int)flagged);
    if (!flagged)
    {
      BRepPrimAPI_MakePrism prism(extrudeFace, gp_Vec(0, 0, 1));
      prism.Build();
      TopoDS_Shape solid = prism.Shape();
      GProp_GProps props;
      BRepGProp::VolumeProperties(solid, props);
      bool valid = solid.ShapeType() == TopAbs_SOLID && BRepCheck_Analyzer(solid).IsValid();
      bool solidGuard = guardFlags(solid);
      Handle(ShapeFix_Shape) fx = new ShapeFix_Shape(solid);
      fx->Perform();
      printf(" isValidSolid=%d volume=%.17g healedGuardFlagged=%d healedNonNull=%d", (int)valid, props.Mass(), (int)solidGuard,
             (int)!fx->Shape().IsNull());
    }
    printf("\n");
    // Shape.face(from: wire, planar: true).healed()
    TopoDS_Face planarFace = BRepBuilderAPI_MakeFace(p.Wire(), true);
    bool        healFlag   = guardFlags(planarFace);
    printf("#263 %s heal of the planar face: guardFlagged=%d (healed returns nil when 1)\n", name, (int)healFlag);
  }
  return 0;
}
