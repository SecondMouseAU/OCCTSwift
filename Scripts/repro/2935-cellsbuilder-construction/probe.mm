// #2935: BOPAlgoCellsBuilderTests.createCellsBuilder asserted only that a builder came back, which
// a BOPAlgo_CellsBuilder that constructed but never took its arguments also satisfies.
//
// What construction itself produces, before any AddToResult, is GetAllParts(): the cells the
// Perform() inside OCCTCellsBuilderCreate split the arguments into. The result shape is empty at
// that point, so GetAllParts is the only observable of the work construction did, and it is not
// covered by addRemoveAll or removeInternalBoundaries in the same file.
//
// Same fixture as Scripts/repro/766-modeling-bopalgo-cells-builder/: Shape.box(20, 20, 20) is
// centred, so the two boxes meet at the face x = 10 and do not overlap.
#include <BOPAlgo_CellsBuilder.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <cstdio>

static void report(const char* label, const TopoDS_Shape& s)
{
  if (s.IsNull())
  {
    printf("%s: null=1\n", label);
    return;
  }
  TopTools_IndexedMapOfShape solids, faces;
  TopExp::MapShapes(s, TopAbs_SOLID, solids);
  TopExp::MapShapes(s, TopAbs_FACE, faces);
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p);
  printf("%s: null=0 valid=%d solids=%d faces=%d volume=%.10g\n",
         label,
         BRepCheck_Analyzer(s).IsValid(),
         solids.Extent(),
         faces.Extent(),
         p.Mass());
}

int main()
{
  BOPAlgo_CellsBuilder cb;
  const TopoDS_Shape   box1 = BRepPrimAPI_MakeBox(gp_Pnt(-10, -10, -10), 20, 20, 20).Shape();
  const TopoDS_Shape   box2 = BRepPrimAPI_MakeBox(gp_Pnt(10, 0, 0), 20, 20, 20).Shape();
  cb.AddArgument(box1);
  cb.AddArgument(box2);
  cb.Perform();

  printf("createCellsBuilder: hasErrors=%d\n", cb.HasErrors());
  report("createCellsBuilder GetAllParts", cb.GetAllParts());
  report("createCellsBuilder Shape before any AddToResult", cb.Shape());
  return 0;
}
