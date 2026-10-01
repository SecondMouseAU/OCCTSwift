// Epic #766, Tests/OCCTModelingTests/BOPAlgoCellsBuilderTests.swift: kernel parity for all three tests.
// CellsBuilder is BOPAlgo_CellsBuilder: AddArgument per shape + Perform (OCCTCellsBuilderCreate),
// AddAllToResult(material, true), RemoveAllFromResult, RemoveInternalBoundaries, Shape().
// AddAllToResult is always called with update = true by the bridge, which merges same-material
// cells at once, so the last block also runs the selective form with update = false.
#include <BOPAlgo_CellsBuilder.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <cstdio>

static void report(const char* label, const TopoDS_Shape& s)
{
  TopTools_IndexedMapOfShape solids;
  TopExp::MapShapes(s, TopAbs_SOLID, solids);
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p);
  printf("%s: null=%d valid=%d solids=%d volume=%.10g\n", label, s.IsNull(), s.IsNull() ? 0 : BRepCheck_Analyzer(s).IsValid(),
         solids.Extent(), p.Mass());
}

static TopoDS_Shape gBox1, gBox2;

static void make(BOPAlgo_CellsBuilder& cb)
{
  gBox1 = BRepPrimAPI_MakeBox(gp_Pnt(-10, -10, -10), 20, 20, 20).Shape(); // Shape.box(20,20,20), centred
  gBox2 = BRepPrimAPI_MakeBox(gp_Pnt(10, 0, 0), 20, 20, 20).Shape();      // Shape.box(origin: (10,0,0))
  cb.AddArgument(gBox1);
  cb.AddArgument(gBox2);
  cb.Perform();
}

int main()
{
  {
    BOPAlgo_CellsBuilder cb;
    make(cb);
    printf("createCellsBuilder: hasErrors=%d\n", cb.HasErrors());
  }
  {
    BOPAlgo_CellsBuilder cb;
    make(cb);
    cb.AddAllToResult(0, true);
    report("addRemoveAll after AddAllToResult(0)", cb.Shape());
    cb.RemoveAllFromResult();
    report("addRemoveAll after RemoveAllFromResult", cb.Shape());
  }
  {
    BOPAlgo_CellsBuilder cb;
    make(cb);
    cb.AddAllToResult(1, true);
    report("removeInternalBoundaries before", cb.Shape());
    cb.RemoveInternalBoundaries();
    report("removeInternalBoundaries after", cb.Shape());
  }
  {
    // The same request through AddToResult(take, avoid, material, update = false), one call per
    // box (OCCTCellsBuilderAddToResultSelective): the merge is left to RemoveInternalBoundaries.
    BOPAlgo_CellsBuilder cb;
    make(cb);
    TopTools_ListOfShape t1, t2, none;
    t1.Append(gBox1);
    t2.Append(gBox2);
    cb.AddToResult(t1, none, 1, false);
    cb.AddToResult(t2, none, 1, false);
    report("selective material 1 before RemoveInternalBoundaries", cb.Shape());
    cb.RemoveInternalBoundaries();
    report("selective material 1 after RemoveInternalBoundaries", cb.Shape());
  }
  return 0;
}
