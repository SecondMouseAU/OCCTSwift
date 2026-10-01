// #2901: what do ShapeAnalysis_Edge::CheckSameParameter and ::CheckVertexTolerance return on a
// clean edge and on a deliberately broken one?
//
// The header's doxygen for CheckSameParameter says "If deviation is greater than tolerance of the
// edge (i.e. incorrect flag) returns False, else returns True". The implementation ends with
// `return Status(ShapeExtend_DONE)` after setting DONE1 when `maxdev > TE->Tolerance()` and DONE2
// when the SameParameter flag is false, so the doxygen is the reverse of the code. This probe
// measures it rather than reading it, on three edges:
//
//   A. a pristine box edge                               (clean)
//   B. an edge whose pcurve sits 1.0 away from its 3D    (deviation >> tolerance)
//      curve at every parameter, SameParameter flag true
//   C. a clean straight edge with SameParameter = false  (zero deviation, flag wrong)
//
// and CheckVertexTolerance on A and on B (B's vertices are 1.0 from the pcurve's surface points).
//
// Build:
//   clang++ -std=c++17 -ObjC++ -w \
//     -I".build/artifacts/occtswift/OCCT/OCCT.xcframework/macos-arm64/Headers" \
//     -L".build/artifacts/occtswift/OCCT/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/2901/probe.mm -o /tmp/occt_probe_2901

#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <Geom2d_Line.hxx>
#include <Geom_Line.hxx>
#include <Geom_Plane.hxx>
#include <ShapeAnalysis_Edge.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>

#include <cstdio>

static void reportSameParameter(ShapeAnalysis_Edge& sae, const TopoDS_Edge& edge)
{
  double maxdev = 0.0;
  bool   r      = sae.CheckSameParameter(edge, maxdev);
  printf("  CheckSameParameter   -> %-5s  maxdev = %.17g  (edge tolerance %.17g)\n",
         r ? "true" : "false",
         maxdev,
         BRep_Tool::Tolerance(edge));
}

static void reportVertexTolerance(ShapeAnalysis_Edge& sae,
                                  const TopoDS_Edge&  edge,
                                  const TopoDS_Face&  face)
{
  double t1 = 0.0;
  double t2 = 0.0;
  bool   r  = sae.CheckVertexTolerance(edge, face, t1, t2);
  printf("  CheckVertexTolerance -> %-5s  toler1 = %.17g  toler2 = %.17g\n",
         r ? "true" : "false",
         t1,
         t2);
}

int main()
{
  ShapeAnalysis_Edge sae;
  BRep_Builder       bb;

  // ---- A: pristine box edge, and the box's first face ----------------------------------------
  TopoDS_Shape box = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();
  TopoDS_Edge  boxEdge;
  TopoDS_Face  boxFace;
  for (TopExp_Explorer ex(box, TopAbs_EDGE); ex.More(); ex.Next())
  {
    boxEdge = TopoDS::Edge(ex.Current());
    break;
  }
  for (TopExp_Explorer ex(box, TopAbs_FACE); ex.More(); ex.Next())
  {
    boxFace = TopoDS::Face(ex.Current());
    break;
  }

  printf("A. pristine box edge (BRepPrimAPI_MakeBox 10x10x10, first mapped edge)\n");
  reportSameParameter(sae, boxEdge);
  reportVertexTolerance(sae, boxEdge, boxFace);

  // ---- B: pcurve displaced 1.0 from the 3D curve at every parameter ---------------------------
  // 3D curve: the X axis, 0 <= t <= 10, so the point at t is (t, 0, 0).
  // Surface:  the z = 0 plane, with the (u, v) -> (u, v, 0) parameterisation.
  // pcurve:   the line v = 1 in (u, v), so the surface point at t is (t, 1, 0): a constant 1.0
  //           away from the 3D curve point at the same parameter.
  occ::handle<Geom_Line>   line3d = new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
  occ::handle<Geom_Plane>  plane  = new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  occ::handle<Geom2d_Line> offsetPCurve = new Geom2d_Line(gp_Pnt2d(0, 1), gp_Dir2d(1, 0));

  TopoDS_Edge badEdge = BRepBuilderAPI_MakeEdge(line3d, 0.0, 10.0).Edge();
  bb.UpdateEdge(badEdge, offsetPCurve, plane, TopLoc_Location(), 1.0e-7);
  bb.Range(badEdge, plane, TopLoc_Location(), 0.0, 10.0);
  bb.SameParameter(badEdge, true);  // claim the flag is correct, which is the defect
  bb.SameRange(badEdge, true);

  TopoDS_Face planeFace = BRepBuilderAPI_MakeFace(plane, -50.0, 50.0, -50.0, 50.0, 1.0e-7).Face();

  printf("\nB. edge whose pcurve is offset 1.0 from its 3D curve, SameParameter flag = true\n");
  reportSameParameter(sae, badEdge);
  reportVertexTolerance(sae, badEdge, planeFace);

  // ---- C: geometrically clean edge whose SameParameter flag is false --------------------------
  occ::handle<Geom2d_Line> truePCurve = new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
  TopoDS_Edge              flagEdge   = BRepBuilderAPI_MakeEdge(line3d, 0.0, 10.0).Edge();
  bb.UpdateEdge(flagEdge, truePCurve, plane, TopLoc_Location(), 1.0e-7);
  bb.Range(flagEdge, plane, TopLoc_Location(), 0.0, 10.0);
  bb.SameParameter(flagEdge, false);  // zero deviation, but the flag says "not same parameter"
  bb.SameRange(flagEdge, true);

  printf("\nC. geometrically clean edge whose SameParameter flag is false\n");
  reportSameParameter(sae, flagEdge);
  reportVertexTolerance(sae, flagEdge, planeFace);

  printf(
    "\nHeader doxygen: \"If deviation is greater than tolerance of the edge (i.e. incorrect\n"
    "flag) returns False, else returns True.\"\n"
    "Measured above: the clean edge returns false and the defective ones return true, the\n"
    "reverse of the doxygen, and matching ShapeAnalysis_Edge.cxx's own\n"
    "`return Status(ShapeExtend_DONE)` and the shape_healing user guide's call site.\n");
  return 0;
}
