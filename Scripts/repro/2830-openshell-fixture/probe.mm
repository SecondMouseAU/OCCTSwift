// #2830: why MakeThickSolidBySimple refuses a closed solid, and what an "openShell" fixture has
// to be built from instead.
//
// #2739's probe (Scripts/repro/2739-shelled-single-argument-routing/) established THAT
// MakeThickSolidBySimple returns IsDone=0 for a closed box, cylinder and sphere at either sign.
// It did not establish WHY, and the reason is what decides how the Stress "openShell" fixture
// should be built. BRepOffsetAPI_MakeThickSolid does not expose the underlying error code, so this
// probe drives BRepOffset_MakeSimpleOffset directly, exactly as MakeThickSolidBySimple does
// (Initialize + Perform, with SetBuildSolidFlag(true), which the BRepOffsetAPI constructor sets).
//
// Compile per the ground-truth-probe skill:
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/2830-openshell-fixture/probe.mm -o /tmp/occt_probe_2830

#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBuilderAPI_MakeSolid.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepGProp.hxx>
#include <BRepOffsetAPI_MakeThickSolid.hxx>
#include <BRepOffset_MakeSimpleOffset.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepTools_Quilt.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <GProp_GProps.hxx>
#include <ShapeAnalysis_FreeBounds.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <TopoDS_Shape.hxx>
#include <TopoDS_Shell.hxx>

#include <cstdio>

static int countOf(const TopoDS_Shape& s, TopAbs_ShapeEnum t)
{
  int n = 0;
  for (TopExp_Explorer e(s, t); e.More(); e.Next())
    ++n;
  return n;
}

static double volumeOf(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p);
  return p.Mass();
}

static double areaOf(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::SurfaceProperties(s, p);
  return p.Mass();
}

static const char* errorName(BRepOffsetSimple_Status s)
{
  switch (s)
  {
    case BRepOffsetSimple_OK:
      return "OK";
    case BRepOffsetSimple_NullInputShape:
      return "NullInputShape";
    case BRepOffsetSimple_ErrorOffsetComputation:
      return "ErrorOffsetComputation";
    case BRepOffsetSimple_ErrorWallFaceComputation:
      return "ErrorWallFaceComputation";
    case BRepOffsetSimple_ErrorInvalidNbShells:
      return "ErrorInvalidNbShells";
    case BRepOffsetSimple_ErrorNonClosedShell:
      return "ErrorNonClosedShell";
  }
  return "?";
}

// The Stress fixture candidate: a 10-box with one face dropped, sewn back into one shell.
static TopoDS_Shape openShellOfBox(double side, int faceToDrop)
{
  TopoDS_Shape box = BRepPrimAPI_MakeBox(side, side, side).Shape();
  BRepBuilderAPI_Sewing sew(1.0e-6);
  int i = 0;
  for (TopExp_Explorer e(box, TopAbs_FACE); e.More(); e.Next(), ++i)
  {
    if (i == faceToDrop)
      continue;
    sew.Add(e.Current());
  }
  sew.Perform();
  return sew.SewedShape();
}

static void reportSimple(const char* label, const TopoDS_Shape& in, double offset)
{
  BRepOffset_MakeSimpleOffset algo;
  algo.SetBuildSolidFlag(true);
  algo.Initialize(in, offset);
  algo.Perform();
  printf("%-58s IsDone=%d error=%-22s msg=%s\n",
         label,
         algo.IsDone() ? 1 : 0,
         errorName(algo.GetError()),
         algo.GetErrorMessage().ToCString());
}

int main()
{
  TopoDS_Shape box = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();

  printf("--- 1. the error code behind #2739's IsDone=0, read off the algorithm itself ---\n");
  reportSimple("MakeSimpleOffset(closed box solid, -2.0)", box, -2.0);
  reportSimple("MakeSimpleOffset(closed box solid, +2.0)", box, +2.0);

  TopoDS_Shape boxShell;
  for (TopExp_Explorer e(box, TopAbs_SHELL); e.More(); e.Next())
    boxShell = e.Current();
  reportSimple("MakeSimpleOffset(that box's closed shell, -2.0)", boxShell, -2.0);

  TopoDS_Shape open = openShellOfBox(10.0, 0);
  reportSimple("MakeSimpleOffset(open shell, 5 of 6 faces, -2.0)", open, -2.0);

  printf("\n--- 2. the mechanism: BuildMissingWalls needs free boundary wires ---\n");
  // BRepOffset_MakeSimpleOffset::BuildMissingWalls builds the side walls of the result solid from
  // ShapeAnalysis_FreeBounds(input).GetClosedWires(). A closed input has no free boundary, so no
  // walls are built, and the original and offset shells stay disjoint.
  for (auto pair : {std::pair<const char*, TopoDS_Shape>{"closed box solid", box},
                    {"closed shell", boxShell},
                    {"open shell (5 faces)", open}})
  {
    ShapeAnalysis_FreeBounds fb(pair.second);
    printf("%-30s free closed wires=%d free open wires=%d BRep_Tool::IsClosed=%d\n",
           pair.first,
           countOf(fb.GetClosedWires(), TopAbs_WIRE),
           countOf(fb.GetOpenWires(), TopAbs_WIRE),
           BRep_Tool::IsClosed(pair.second) ? 1 : 0);
  }

  printf("\n--- 3. and so the quilt sees two shells, not one ---\n");
  // The same compound BuildMissingWalls assembles for a closed input: input faces plus offset
  // faces, no walls. Quilting it yields one shell per closed skin, which is the
  // ErrorInvalidNbShells above.
  {
    BRepOffset_MakeSimpleOffset shellOnly;
    shellOnly.SetBuildSolidFlag(false); // stop before BuildMissingWalls
    shellOnly.Initialize(box, -2.0);
    shellOnly.Perform();
    printf("BuildSolidFlag=false on the closed box: IsDone=%d error=%s\n",
           shellOnly.IsDone() ? 1 : 0,
           errorName(shellOnly.GetError()));
    if (shellOnly.IsDone())
    {
      TopoDS_Compound comp;
      BRep_Builder    bb;
      bb.MakeCompound(comp);
      for (TopExp_Explorer e(box, TopAbs_FACE); e.More(); e.Next())
        bb.Add(comp, e.Current());
      for (TopExp_Explorer e(shellOnly.GetResultShape(), TopAbs_FACE); e.More(); e.Next())
        bb.Add(comp, e.Current());
      BRepTools_Quilt q;
      q.Add(comp);
      printf("quilt of (input faces + offset faces, no walls) -> shells=%d\n",
             countOf(q.Shells(), TopAbs_SHELL));
    }
  }

  printf("\n--- 4. the fixture candidate itself, measured ---\n");
  printf("open shell of a 10-box: type=%d faces=%d shells=%d IsClosed=%d area=%.6f volume=%.6f\n",
         (int)open.ShapeType(),
         countOf(open, TopAbs_FACE),
         countOf(open, TopAbs_SHELL),
         BRep_Tool::IsClosed(open) ? 1 : 0,
         areaOf(open),
         volumeOf(open));
  printf("closed 10-box for comparison:  type=%d faces=%d shells=%d IsClosed=%d area=%.6f "
         "volume=%.6f\n",
         (int)box.ShapeType(),
         countOf(box, TopAbs_FACE),
         countOf(box, TopAbs_SHELL),
         BRep_Tool::IsClosed(box) ? 1 : 0,
         areaOf(box),
         volumeOf(box));

  printf("\n--- 5. control: is the sewn result one shell, or a compound of faces? ---\n");
  printf("SewedShape().ShapeType()=%d (3 = TopAbs_SHELL, 0 = TopAbs_COMPOUND)\n",
         (int)open.ShapeType());

  return 0;
}
