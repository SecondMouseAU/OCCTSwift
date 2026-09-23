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
  printf("%s: done=%d", label, op.IsDone());
  if (op.IsDone())
  {
    GProp_GProps p;
    BRepGProp::VolumeProperties(op.Shape(), p);
    TopTools_IndexedMapOfShape solids;
    TopExp::MapShapes(op.Shape(), TopAbs_SOLID, solids);
    printf(" valid=%d solids=%d volume=%.10g", BRepCheck_Analyzer(op.Shape()).IsValid(), solids.Extent(), p.Mass());
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
