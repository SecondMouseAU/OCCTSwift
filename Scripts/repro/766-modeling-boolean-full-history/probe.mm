// Epic #766, Tests/OCCTModelingTests/BooleanFullHistoryTests.swift: kernel parity for all five tests.
// Same inputs as the Swift tests, straight to the builders the bridge retains for history:
// BRepAlgoAPI_Fuse (OCCTBooleanUnionWithHistory), BRepAlgoAPI_Cut (OCCTBooleanSubtractWithHistory),
// BRepAlgoAPI_Common (OCCTBooleanIntersectWithHistory), BRepAlgoAPI_Splitter
// (OCCTBooleanSplitWithHistory); per input face, Modified / Generated / IsDeleted
// (OCCTBooleanHistoryModified / ...Generated / ...IsDeleted).
#include <BRepAlgoAPI_Common.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepAlgoAPI_Splitter.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopoDS_Iterator.hxx>
#include <cstdio>

// Shape.box(width:height:depth:) centred at the origin, then .translated(by:).
static TopoDS_Shape box(double w, double h, double d, double tx = 0, double ty = 0, double tz = 0)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-w / 2 + tx, -h / 2 + ty, -d / 2 + tz), w, h, d).Shape();
}

static double volume(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p);
  return p.Mass();
}

static void faces(const char* label, BRepAlgoAPI_BuilderAlgo& op, const TopoDS_Shape& input)
{
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(input, TopAbs_FACE, m);
  printf("%s faces (modified,generated,deleted):", label);
  for (int i = 1; i <= m.Extent(); i++)
    printf(" [%d]=(%d,%d,%d)", i - 1, op.Modified(m(i)).Extent(), op.Generated(m(i)).Extent(),
           op.IsDeleted(m(i)));
  printf("\n");
}

int main()
{
  {
    TopoDS_Shape     a = box(10, 10, 10), b = box(10, 10, 10, 15, 0, 0);
    BRepAlgoAPI_Fuse op(a, b);
    printf("unionWithFullHistory: done=%d volume=%.10g\n", op.IsDone(), volume(op.Shape()));
    faces("unionWithFullHistory box1", op, a);
  }
  {
    TopoDS_Shape    big = box(20, 20, 5), tool = box(30, 4, 20, -5, 8, -5);
    BRepAlgoAPI_Cut op(big, tool);
    printf("subtractedWithFullHistorySplitsFace: done=%d volume=%.10g bigVolume=%.10g\n", op.IsDone(),
           volume(op.Shape()), volume(big));
    faces("subtractedWithFullHistorySplitsFace big", op, big);
  }
  {
    TopoDS_Shape       a = box(10, 10, 10), b = box(10, 10, 10, 5, 5, 5);
    BRepAlgoAPI_Common op(a, b);
    printf("intersectionWithFullHistory: done=%d volume=%.10g box1Volume=%.10g\n", op.IsDone(),
           volume(op.Shape()), volume(a));
    faces("intersectionWithFullHistory box1", op, a);
  }
  {
    TopoDS_Shape         a = box(10, 10, 10), t = box(30, 1, 20, -10, 4.5, -5);
    BRepAlgoAPI_Splitter op;
    TopTools_ListOfShape args, tools;
    args.Append(a);
    tools.Append(t);
    op.SetArguments(args);
    op.SetTools(tools);
    op.Build();
    int pieces = 0;
    for (TopoDS_Iterator it(op.Shape()); it.More(); it.Next())
      pieces++;
    printf("splitWithFullHistory: done=%d pieces=%d\n", op.IsDone(), pieces);
    faces("splitWithFullHistory box", op, a);
  }
  {
    TopoDS_Shape     a = box(10, 10, 10), b = box(10, 10, 10, 5, 5, 5);
    BRepAlgoAPI_Fuse op(a, b);
    printf("historyHandleSurvives: done=%d\n", op.IsDone());
    faces("historyHandleSurvives box1 (first read)", op, a);
    faces("historyHandleSurvives box1 (second read)", op, a);
  }
  return 0;
}
