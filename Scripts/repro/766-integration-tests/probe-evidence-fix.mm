// Epic #766, PR #2284 evidence fix: the selfUnion parity record compared {volume, faces, solids, valid}
// on the bridge side against {volume, faces, valid} on the kernel side, because probe.mm never counted
// solids. IntegrationDegenerateResilienceTests.selfUnion asserts isValid, volume 1000, one solid and six
// faces, so this probe makes the same OCCTShapeUnionEx call as probe.mm (BRepAlgoAPI_Fuse with the box as
// both argument and tool, glue off) and prints all four quantities.
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBndLib.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <cstdio>

static int countOf(const TopoDS_Shape& s, TopAbs_ShapeEnum t)
{
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(s, t, m);
  return m.Extent();
}

int main()
{
  TopoDS_Shape         b = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  BRepAlgoAPI_Fuse     op;
  TopTools_ListOfShape args, tools;
  args.Append(b);
  tools.Append(b);
  op.SetArguments(args);
  op.SetTools(tools);
  op.SetGlue(BOPAlgo_GlueOff);
  op.Build();
  if (!op.IsDone())
  {
    printf("selfUnion nil\n");
    return 0;
  }
  const TopoDS_Shape& r = op.Shape();
  GProp_GProps        p;
  BRepGProp::VolumeProperties(r, p, true);
  printf("selfUnion vol=%.17g valid=%d solids=%d faces=%d\n",
         p.Mass(),
         BRepCheck_Analyzer(r).IsValid() ? 1 : 0,
         countOf(r, TopAbs_SOLID),
         countOf(r, TopAbs_FACE));
  return 0;
}
