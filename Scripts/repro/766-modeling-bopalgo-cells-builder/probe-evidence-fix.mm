// Epic #766 evidence fix, Tests/OCCTModelingTests/BOPAlgoCellsBuilderTests.swift.
// probe.mm printed the volumes at %.10g. This probe repeats the same bridge calls (OCCTCellsBuilderCreate:
// BOPAlgo_CellsBuilder, AddArgument per shape, Perform, nothing on HasErrors(); AddAllToResult(material, true);
// RemoveAllFromResult; AddToResult(take, avoid, material, false); RemoveInternalBoundaries; Shape()) at %.17g.
// The volume is the raw BRepGProp mass (Shape.signedVolume): Shape.volume is nil for a compound with no closed
// shell, which is what RemoveAllFromResult leaves, and BRepGProp reports 0 there.
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
  printf("%s: null=%d valid=%d solids=%d volume=%.17g\n", label, s.IsNull(), s.IsNull() ? 0 : BRepCheck_Analyzer(s).IsValid(),
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
    printf("createCellsBuilder: produced=%d\n", !cb.HasErrors());
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
    // The selective form the test uses: one AddToResult per box with update = false, the merge left to
    // RemoveInternalBoundaries.
    BOPAlgo_CellsBuilder cb;
    make(cb);
    TopTools_ListOfShape t1, t2, none;
    t1.Append(gBox1);
    t2.Append(gBox2);
    cb.AddToResult(t1, none, 1, false);
    cb.AddToResult(t2, none, 1, false);
    report("removeInternalBoundaries before", cb.Shape());
    cb.RemoveInternalBoundaries();
    report("removeInternalBoundaries after", cb.Shape());
  }
  return 0;
}
