// #2906: ShapeAnalysis_Wire's per-check methods have an ordering precondition that the Swift
// surface does not carry. OCCT's own caller (the shape_healing user guide) writes
//
//   ShapeAnalysis_Wire aCheckWire (theWire, theFace, aPrecision);
//   if (aCheckWire.CheckOrder()) { "Some edges ... need to be reordered"; return; }
//
// and runs no later check. Scripts/repro/766-healing-sawire-263 measured that a pristine box
// face's own wire answers CheckOrder() == true and then reports gaps of 10*sqrt(2), the face's
// diagonal.
//
// This probe measures the other half: what the same checks answer AFTER the precondition is
// satisfied by ShapeFix_Wire::FixReorder, which OCCTSwift already exposes as
// WireFixer.fixReorder(). If the diagonal gaps disappear, the gap values are an artefact of the
// ordering and the fix is documentation plus a pointer at the existing wrapper, not new API.
//
// Build:
//   clang++ -std=c++17 -ObjC++ -w \
//     -I<OCCT.xcframework>/macos-arm64/Headers \
//     -L<OCCT.xcframework>/macos-arm64 \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/2906/probe.mm -o /tmp/occt_probe_2906

#include <BRepPrimAPI_MakeBox.hxx>
#include <ShapeAnalysis_Wire.hxx>
#include <ShapeFix_Wire.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Wire.hxx>

#include <cstdio>

static void reportWire(const char* label, const TopoDS_Wire& wire, const TopoDS_Face& face)
{
  const double prec = 1.0e-6;

  ShapeAnalysis_Wire saw;
  saw.Init(wire, face, prec);
  printf("%s\n", label);
  if (!saw.IsReady())
  {
    printf("  analyzer not ready\n");
    return;
  }

  printf("  NbEdges              = %d\n", saw.NbEdges());
  printf("  CheckOrder           -> %s\n", saw.CheckOrder() ? "true" : "false");
  printf("  CheckConnected       -> %s\n", saw.CheckConnected() ? "true" : "false");
  printf("  CheckSmall           -> %s\n", saw.CheckSmall(prec) ? "true" : "false");
  printf("  CheckDegenerated     -> %s\n", saw.CheckDegenerated() ? "true" : "false");
  printf("  CheckClosed          -> %s\n", saw.CheckClosed() ? "true" : "false");
  printf("  CheckGaps3d          -> %s\n", saw.CheckGaps3d() ? "true" : "false");
  printf("  CheckGaps2d          -> %s\n", saw.CheckGaps2d() ? "true" : "false");
  printf("  CheckEdgeCurves      -> %s\n", saw.CheckEdgeCurves() ? "true" : "false");
  printf("  CheckLacking         -> %s\n", saw.CheckLacking() ? "true" : "false");
  printf("  CheckSelfIntersection-> %s\n", saw.CheckSelfIntersection() ? "true" : "false");
  // The distance accessors read the state the last CheckGaps* left behind, so re-run it first.
  saw.CheckGaps3d();
  printf("  MinDistance3d        = %.17g\n", saw.MinDistance3d());
  printf("  MaxDistance3d        = %.17g\n", saw.MaxDistance3d());
  saw.CheckGaps2d();
  printf("  MinDistance2d        = %.17g\n", saw.MinDistance2d());
  printf("  MaxDistance2d        = %.17g\n", saw.MaxDistance2d());
}

int main()
{
  TopoDS_Shape box = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();
  TopoDS_Face  face;
  for (TopExp_Explorer ex(box, TopAbs_FACE); ex.More(); ex.Next())
  {
    face = TopoDS::Face(ex.Current());
    break;
  }
  TopoDS_Wire wire;
  for (TopExp_Explorer ex(face, TopAbs_WIRE); ex.More(); ex.Next())
  {
    wire = TopoDS::Wire(ex.Current());
    break;
  }

  reportWire("BEFORE: the box face's own first wire, as explored", wire, face);

  occ::handle<ShapeFix_Wire> fixer = new ShapeFix_Wire(wire, face, 1.0e-6);
  bool                       fixed = fixer->FixReorder();
  printf("\nShapeFix_Wire::FixReorder() -> %s\n\n", fixed ? "true" : "false");

  reportWire("AFTER: the same wire, reordered by ShapeFix_Wire::FixReorder", fixer->Wire(), face);

  return 0;
}
