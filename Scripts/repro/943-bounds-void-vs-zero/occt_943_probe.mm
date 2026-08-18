// #943 ground truth: is a legitimately zero-size Bnd_Box reachable through BRepBndLib::Add,
// the call every bounds entry point in the bridge uses?
//
// The Swift-side heuristic under review infers "void" from all-six-outputs-zero. That is only
// safe if no real shape can measure to exactly zero through Add(). Measure it rather than
// reasoning about it.
//
// Build:
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/943-bounds-void-vs-zero/occt_943_probe.mm -o /tmp/occt_943_probe

#include <Bnd_Box.hxx>
#include <BRepAlgoAPI_Common.hxx>
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRep_Tool.hxx>
#include <Precision.hxx>
#include <ShapeFix_ShapeTolerance.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Shape.hxx>
#include <TopoDS_Vertex.hxx>
#include <gp_Pnt.hxx>
#include <gp_Trsf.hxx>
#include <BRepBuilderAPI_Transform.hxx>

#include <cstdio>

static void report(const char* label, const TopoDS_Shape& s, bool useTriangulation = true)
{
  Bnd_Box box;
  try
  {
    BRepBndLib::Add(s, box, useTriangulation);
  }
  catch (...)
  {
    printf("%-46s THREW\n", label);
    return;
  }
  if (box.IsVoid())
  {
    printf("%-46s IsVoid=1\n", label);
    return;
  }
  double xmin, ymin, zmin, xmax, ymax, zmax;
  box.Get(xmin, ymin, zmin, xmax, ymax, zmax);
  const bool allZero = (xmin == 0 && ymin == 0 && zmin == 0 && xmax == 0 && ymax == 0 && zmax == 0);
  printf("%-46s IsVoid=0 gap=%.3g box=(%.17g %.17g %.17g)-(%.17g %.17g %.17g) allZero=%d\n",
         label,
         box.GetGap(),
         xmin,
         ymin,
         zmin,
         xmax,
         ymax,
         zmax,
         allZero ? 1 : 0);
}

int main()
{
  printf("Precision::Confusion() = %.17g\n\n", Precision::Confusion());

  // 1. A plain point-vertex at the origin. BRepBuilderAPI_MakeVertex floors the vertex tolerance
  //    at Precision::Confusion(), and BRepBndLib::Add enlarges by that tolerance.
  TopoDS_Vertex v = BRepBuilderAPI_MakeVertex(gp_Pnt(0, 0, 0));
  printf("vertex tolerance (default)          = %.17g\n", BRep_Tool::Tolerance(v));
  report("1. vertex at origin, default tolerance", v);

  // 2. The same vertex after ShapeFix_ShapeTolerance::LimitTolerance(0, 0), which is
  //    Shape.limitTolerance(min:max:) in Swift. SetTolerance(0) is a documented no-op
  //    (`preci <= 0` returns early), LimitTolerance is not.
  ShapeFix_ShapeTolerance fixer;
  const bool              changed = fixer.LimitTolerance(v, 0.0, 0.0);
  printf("\nLimitTolerance(0,0) changed anything = %d\n", changed ? 1 : 0);
  printf("vertex tolerance (after limit)      = %.17g\n", BRep_Tool::Tolerance(v));
  report("2. vertex at origin, tolerance 0", v);

  // 3. A genuinely void shape: a far-disjoint intersection. Shape.compound([]) cannot be built
  //    (OCCTShapeCreateCompound requires count >= 1), so this is the reachable void fixture.
  BRepPrimAPI_MakeBox b1(gp_Pnt(0, 0, 0), 10, 10, 10);
  BRepPrimAPI_MakeBox b2(gp_Pnt(1000, 1000, 1000), 10, 10, 10);
  BRepAlgoAPI_Common  common(b1.Shape(), b2.Shape());
  common.Build();
  printf("\ndisjoint common IsDone=%d\n", common.IsDone() ? 1 : 0);
  report("3. disjoint intersection (void shape)", common.Shape());

  // 4. A sphere's polar degenerate edge, moved so the pole sits at the origin. This is the
  //    closest thing to a "zero-length edge at the origin" the public API can reach.
  BRepPrimAPI_MakeSphere sph(5.0);
  gp_Trsf                t;
  t.SetTranslation(gp_Vec(0, 0, 5));
  TopoDS_Shape sphere = BRepBuilderAPI_Transform(sph.Shape(), t, true).Shape();
  int          idx    = 0;
  for (TopExp_Explorer ex(sphere, TopAbs_EDGE); ex.More(); ex.Next(), ++idx)
  {
    const TopoDS_Edge& e = TopoDS::Edge(ex.Current());
    if (!BRep_Tool::Degenerated(e))
      continue;
    char label[96];
    snprintf(label, sizeof(label), "4. sphere degenerate edge %d (default tol)", idx);
    report(label, e);
    ShapeFix_ShapeTolerance efixer;
    efixer.LimitTolerance(e, 0.0, 0.0);
    snprintf(label, sizeof(label), "5. sphere degenerate edge %d (tol 0)", idx);
    report(label, e);
    printf("   edge tolerance after limit = %.17g\n", BRep_Tool::Tolerance(e));
  }

  // 6. A whole shape carrying only that degenerate edge is not constructible through the public
  //    Swift API, so measure the Shape-level equivalent instead: the zero-tolerance vertex
  //    inside a compound, which is what Shape.bounds actually sees.
  report("6. vertex(tol 0) through Add(useTri=false)", v, false);

  // 7. The sibling call one flag away. BRepBndLib::AddOptimal defaults useShapeTolerance to
  //    false, so it does NOT enlarge by the shape tolerance and CAN land on exactly zero. This
  //    is #900's live repro, re-measured here rather than quoted: it is the evidence that an
  //    all-zero-means-void sentinel is a real hazard in this family, and that Add() escapes it
  //    only because of a kernel-side tolerance floor nothing in OCCTSwift controls.
  {
    Bnd_Box opt;
    BRepBndLib::AddOptimal(v, opt, true, false);
    double xmin, ymin, zmin, xmax, ymax, zmax;
    if (opt.IsVoid())
    {
      printf("\n7. vertex at origin, AddOptimal            IsVoid=1\n");
    }
    else
    {
      opt.Get(xmin, ymin, zmin, xmax, ymax, zmax);
      const bool allZero =
        (xmin == 0 && ymin == 0 && zmin == 0 && xmax == 0 && ymax == 0 && zmax == 0);
      printf("\n7. vertex at origin, AddOptimal            IsVoid=0 gap=%.3g allZero=%d\n",
             opt.GetGap(),
             allZero ? 1 : 0);
    }
  }

  return 0;
}
