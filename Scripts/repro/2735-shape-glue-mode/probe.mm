//
//  probe.mm
//  Ground-truth reproduction for #2735.
//
//  OCCTShapeGlue (Sources/OCCTBridge/src/OCCTBridge_Modeling_Boolean.mm) puts both shapes into
//  BRepAlgoAPI_Fuse::SetArguments and sets no tools. This probe reproduces the issue's claim
//  independently:
//
//    (a) both shapes as arguments, no tools, SetGlue(BOPAlgo_GlueShift) -> HasErrors()/IsDone()
//    (b) shape1 as argument, shape2 as tool, SetGlue(BOPAlgo_GlueShift) -> succeeds
//
//  and then looks for a discriminating measurement between glue mode and a plain fuse, on the
//  SAME correctly-configured (argument + tool) setup, across two fixtures: boxes with an EXACTLY
//  coincident shared face, and boxes with a shared face offset by a gap that is inside the
//  `tolerance` the caller passes but outside OCCT's default confusion precision (the case
//  Shape.glue(_:_:tolerance:) exists to handle). Per okf/policies/measure-dont-assume.md, this
//  does not assume which fixture discriminates; it measures both and reports every number.
//
//  Compile (see the ground-truth-probe skill and this directory's README.md). With no
//  Libraries/OCCT.xcframework checked out, `swift build` resolves the pinned remote asset into
//  .build/artifacts/<scheme>/OCCT/OCCT.xcframework instead:
//    XCF=".build/artifacts/$(ls .build/artifacts)/OCCT/OCCT.xcframework/macos-arm64"
//    clang++ -std=c++17 -ObjC++ -w -I"$XCF/Headers" -L"$XCF" \
//      -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//      Scripts/repro/2735-shape-glue-mode/probe.mm -o /tmp/occt_probe_2735
//    /tmp/occt_probe_2735
//

#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <TopAbs_ShapeEnum.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopoDS_Shape.hxx>
#include <gp_Pnt.hxx>

#include <iostream>
#include <string>

namespace
{

int countShapes(const TopoDS_Shape& theShape, TopAbs_ShapeEnum theType)
{
  int aCount = 0;
  for (TopExp_Explorer anExp(theShape, theType); anExp.More(); anExp.Next())
    ++aCount;
  return aCount;
}

double volumeOf(const TopoDS_Shape& theShape)
{
  GProp_GProps aProps;
  BRepGProp::VolumeProperties(theShape, aProps);
  return aProps.Mass();
}

void report(const std::string& theLabel, BRepAlgoAPI_Fuse& theFuse)
{
  std::cout << theLabel << ": IsDone=" << (theFuse.IsDone() ? "true" : "false")
            << " HasErrors=" << (theFuse.HasErrors() ? "true" : "false");
  if (theFuse.IsDone())
  {
    const TopoDS_Shape& aResult = theFuse.Shape();
    std::cout << " solids=" << countShapes(aResult, TopAbs_SOLID)
               << " faces=" << countShapes(aResult, TopAbs_FACE)
               << " volume=" << volumeOf(aResult);
  }
  std::cout << std::endl;
}

} // namespace

int main()
{
  // --- Fixture 1: exactly coincident shared face (box2 sits flush on box1, z = 10). ---
  TopoDS_Shape aBox1 = BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 0), 10, 10, 10).Shape();
  TopoDS_Shape aBox2 = BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 10), 10, 10, 10).Shape();

  std::cout << "=== Fixture 1: exactly coincident shared face ===" << std::endl;

  // (a) The CURRENT buggy setup: both shapes as arguments, no tools.
  {
    BRepAlgoAPI_Fuse aFuse;
    aFuse.SetGlue(BOPAlgo_GlueShift);
    aFuse.SetFuzzyValue(1.0e-6);
    TopTools_ListOfShape anArgs;
    anArgs.Append(aBox1);
    anArgs.Append(aBox2);
    aFuse.SetArguments(anArgs);
    // No SetTools() call -- this is the bug.
    aFuse.Build();
    report("(a) both-as-arguments, no tools, glue on", aFuse);
  }

  // (b) The FIXED setup: shape1 as argument, shape2 as tool, glue mode on.
  {
    BRepAlgoAPI_Fuse aFuse;
    aFuse.SetGlue(BOPAlgo_GlueShift);
    aFuse.SetFuzzyValue(1.0e-6);
    TopTools_ListOfShape anArgs;
    anArgs.Append(aBox1);
    TopTools_ListOfShape aTools;
    aTools.Append(aBox2);
    aFuse.SetArguments(anArgs);
    aFuse.SetTools(aTools);
    aFuse.Build();
    report("(b) argument+tool, glue on", aFuse);
  }

  // (c) Same correct argument/tool split, glue OFF -- the "plain fuse" comparator.
  {
    BRepAlgoAPI_Fuse aFuse;
    aFuse.SetFuzzyValue(1.0e-6);
    TopTools_ListOfShape anArgs;
    anArgs.Append(aBox1);
    TopTools_ListOfShape aTools;
    aTools.Append(aBox2);
    aFuse.SetArguments(anArgs);
    aFuse.SetTools(aTools);
    aFuse.Build();
    report("(c) argument+tool, glue off (plain fuse)", aFuse);
  }

  // (d) The CURRENT buggy fallback exactly as coded today: BRepAlgoAPI_Fuse(s1, s2), no fuzzy
  //     value, no glue -- this is what every caller of Shape.glue actually gets right now.
  {
    BRepAlgoAPI_Fuse aFuse(aBox1, aBox2);
    aFuse.Build();
    report("(d) legacy two-arg ctor fallback, no fuzzy/glue", aFuse);
  }

  // --- Fixture 2: shared face offset by a gap inside `tolerance` but outside OCCT's default
  //     confusion precision (~1e-7) -- the case Shape.glue's tolerance parameter exists for. ---
  const double aGap = 5.0e-5;
  const double aTol = 1.0e-3;
  TopoDS_Shape  aBox2Gap = BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 10 + aGap), 10, 10, 10).Shape();

  std::cout << "=== Fixture 2: gap=" << aGap << " tolerance=" << aTol << " ===" << std::endl;

  // (e) FIXED setup on the gap fixture: argument+tool, glue on, fuzzy value = caller's tolerance.
  {
    BRepAlgoAPI_Fuse aFuse;
    aFuse.SetGlue(BOPAlgo_GlueShift);
    aFuse.SetFuzzyValue(aTol);
    TopTools_ListOfShape anArgs;
    anArgs.Append(aBox1);
    TopTools_ListOfShape aTools;
    aTools.Append(aBox2Gap);
    aFuse.SetArguments(anArgs);
    aFuse.SetTools(aTools);
    aFuse.Build();
    report("(e) gap fixture, argument+tool, glue+fuzzy(tolerance)", aFuse);
  }

  // (f) Same argument/tool split, glue OFF, same fuzzy value -- plain-fuse comparator.
  {
    BRepAlgoAPI_Fuse aFuse;
    aFuse.SetFuzzyValue(aTol);
    TopTools_ListOfShape anArgs;
    anArgs.Append(aBox1);
    TopTools_ListOfShape aTools;
    aTools.Append(aBox2Gap);
    aFuse.SetArguments(anArgs);
    aFuse.SetTools(aTools);
    aFuse.Build();
    report("(f) gap fixture, argument+tool, glue off, fuzzy(tolerance)", aFuse);
  }

  // (g) The CURRENT buggy fallback exactly as coded on the gap fixture: no fuzzy value at all.
  {
    BRepAlgoAPI_Fuse aFuse(aBox1, aBox2Gap);
    aFuse.Build();
    report("(g) gap fixture, legacy two-arg ctor fallback, no fuzzy/glue", aFuse);
  }

  return 0;
}
