// Epic #766 evidence correction for PR #2688. probe.mm printed the kernel side at %.10g with 0/1
// flags and a `volume` key the bridge side did not share. This probe repeats the same six booleans
// and prints every double at %.17g and every flag as true/false, one `label: key=value ...` line
// per test. `signedVolume` is the raw BRepGProp::VolumeProperties mass, which is what
// Shape.signedVolume reports: Shape.volume is nil for an empty result (the common cases), where
// the raw mass is 0.
// Epic #766, Tests/OCCTModelingTests/BooleanToleranceTests.swift: kernel parity for all six tests.
// fused/subtracted/intersected(tolerance:) and (glue:) reach OCCTShapeUnionEx / SubtractEx /
// IntersectEx, i.e. runBooleanEx: BRepAlgoAPI_Fuse/Cut/Common with SetArguments/SetTools,
// SetFuzzyValue when > 0, and SetGlue (GlueMode.shift -> BOPAlgo_GlueShift, .off -> GlueOff).
#include <BRepAlgoAPI_Common.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <cstdio>

static TopoDS_Shape centred(double s)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-s / 2, -s / 2, -s / 2), s, s, s).Shape();
}

static TopoDS_Shape at(double x, double y, double z, double s)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(x, y, z), s, s, s).Shape();
}

template <typename Op>
static void run(const char* label, const TopoDS_Shape& a, const TopoDS_Shape& b, double fuzzy, BOPAlgo_GlueEnum glue)
{
  Op                   op;
  TopTools_ListOfShape args, tools;
  args.Append(a);
  tools.Append(b);
  op.SetArguments(args);
  op.SetTools(tools);
  if (fuzzy > 0)
    op.SetFuzzyValue(fuzzy);
  op.SetGlue(glue);
  op.Build();
  printf("%s: done=%s", label, op.IsDone() ? "true" : "false");
  if (op.IsDone())
  {
    GProp_GProps p;
    BRepGProp::VolumeProperties(op.Shape(), p);
    TopTools_IndexedMapOfShape solids;
    TopExp::MapShapes(op.Shape(), TopAbs_SOLID, solids);
    printf(" valid=%s solids=%d signedVolume=%.17g", BRepCheck_Analyzer(op.Shape()).IsValid() ? "true" : "false",
           solids.Extent(), p.Mass());
  }
  printf("\n");
}

int main()
{
  run<BRepAlgoAPI_Fuse>("fuseWithTolerance", centred(10), at(9.999, 0, 0, 10), 0.01, BOPAlgo_GlueOff);
  run<BRepAlgoAPI_Cut>("cutWithTolerance", centred(10), at(5, 5, 5, 10), 0.001, BOPAlgo_GlueOff);
  run<BRepAlgoAPI_Common>("commonWithTolerance", centred(10), at(5, 5, 5, 10), 0.001, BOPAlgo_GlueOff);
  run<BRepAlgoAPI_Fuse>("fuseWithGlue", centred(10), at(10, 0, 0, 10), 0, BOPAlgo_GlueShift);
  run<BRepAlgoAPI_Cut>("cutWithGlue", centred(20), at(5, 5, 5, 10), 0, BOPAlgo_GlueOff);
  run<BRepAlgoAPI_Common>("commonWithGlue", centred(10), at(5, 5, 5, 10), 0, BOPAlgo_GlueOff);
  return 0;
}
