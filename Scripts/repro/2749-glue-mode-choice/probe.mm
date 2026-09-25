//
//  probe.mm
//  Ground-truth measurement for #2749.
//
//  OCCTShapeGlue (Sources/OCCTBridge/src/OCCTBridge_Modeling_Boolean.mm) hardcodes
//  BOPAlgo_GlueShift. OCCT's own BOPAlgo_GlueEnum.hxx documents BOPAlgo_GlueShift as the option
//  for shapes with PARTIAL coincidence (faces overlap but are not fully coincident, and get
//  split) and BOPAlgo_GlueFull for shapes with FULL coincidence (no partial overlap, faces are
//  not split at all), which is the case Shape.glue's own doc comment says it exists for
//  ("Glue two shapes together at coincident faces"). Neither #2735 nor #2740 measured GlueFull;
//  this probe does, across the same two fixtures #2740's probe.mm built (reused verbatim, not
//  edited, per the task: a third PR should not collide with #2740's own probe directory) plus a
//  third fixture where the faces are not coincident at all.
//
//  Per okf/policies/measure-dont-assume.md, this does not assume which mode is faster or more
//  correct; it measures GlueOff/GlueShift/GlueFull on every fixture and reports every number,
//  including wall time averaged over repeated runs since the boxes are cheap enough that a
//  single run is noise-dominated.
//
//  Compile (see the ground-truth-probe skill and Scripts/repro/2735-shape-glue-mode/README.md
//  for why the xcframework path is resolved this way rather than from a checked-out Libraries/):
//    swift build   # resolves the pinned OCCT.xcframework into .build/artifacts/<scheme>/OCCT
//    XCF=".build/artifacts/$(ls .build/artifacts)/OCCT/OCCT.xcframework/macos-arm64"
//    clang++ -std=c++17 -ObjC++ -w -I"$XCF/Headers" -L"$XCF" \
//      -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//      Scripts/repro/2749-glue-mode-choice/probe.mm -o /tmp/occt_probe_2749
//    /tmp/occt_probe_2749
//

#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepGProp.hxx>
#include <BRep_Builder.hxx>
#include <GProp_GProps.hxx>
#include <TopAbs_ShapeEnum.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopoDS_Compound.hxx>
#include <TopoDS_Shape.hxx>
#include <gp_Pnt.hxx>

#include <chrono>
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

// Runs the argument+tool BRepAlgoAPI_Fuse (the #2735/#2740-fixed shape) theRepeats times with
// theGlue and theFuzzy, reports the LAST run's topology/volume (all runs are on the same inputs,
// so they agree) and the average wall time per run in microseconds.
void reportGlue(const std::string& theLabel, const TopoDS_Shape& theArg, const TopoDS_Shape& theTool,
                 BOPAlgo_GlueEnum theGlue, double theFuzzy, int theRepeats)
{
  bool     aLastDone   = false;
  bool     aLastErrors = false;
  int      aSolids = -1, aFaces = -1;
  double   aVolume = -1.0;
  long long aTotalUs = 0;

  for (int i = 0; i < theRepeats; ++i)
  {
    auto aStart = std::chrono::steady_clock::now();

    BRepAlgoAPI_Fuse aFuse;
    if (theGlue != BOPAlgo_GlueOff)
      aFuse.SetGlue(theGlue);
    if (theFuzzy > 0.0)
      aFuse.SetFuzzyValue(theFuzzy);
    TopTools_ListOfShape anArgs;
    anArgs.Append(theArg);
    TopTools_ListOfShape aTools;
    aTools.Append(theTool);
    aFuse.SetArguments(anArgs);
    aFuse.SetTools(aTools);
    aFuse.Build();

    auto anEnd = std::chrono::steady_clock::now();
    aTotalUs += std::chrono::duration_cast<std::chrono::microseconds>(anEnd - aStart).count();

    aLastDone   = aFuse.IsDone();
    aLastErrors = aFuse.HasErrors();
    if (aLastDone)
    {
      const TopoDS_Shape& aResult = aFuse.Shape();
      aSolids = countShapes(aResult, TopAbs_SOLID);
      aFaces  = countShapes(aResult, TopAbs_FACE);
      aVolume = volumeOf(aResult);
    }
    else
    {
      aSolids = -1;
      aFaces  = -1;
      aVolume = -1.0;
    }
  }

  std::cout << theLabel << ": IsDone=" << (aLastDone ? "true" : "false")
            << " HasErrors=" << (aLastErrors ? "true" : "false");
  if (aLastDone)
  {
    std::cout << " solids=" << aSolids << " faces=" << aFaces << " volume=" << aVolume;
  }
  std::cout << " avgUs=" << (aTotalUs / theRepeats) << " (n=" << theRepeats << ")" << std::endl;
}

} // namespace

int main()
{
  const int kRepeats = 200;

  // --- Fixture 1: exactly coincident shared face (box2 sits flush on box1, z = 10). ---
  // Identical to Scripts/repro/2735-shape-glue-mode/probe.mm's fixture 1, reused rather than
  // redefined so this probe measures the same geometry #2740 already measured GlueOff/GlueShift
  // on, adding only GlueFull.
  {
    TopoDS_Shape aBox1 = BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 0), 10, 10, 10).Shape();
    TopoDS_Shape aBox2 = BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 10), 10, 10, 10).Shape();
    const double aFuzzy = 1.0e-6;

    std::cout << "=== Fixture 1: exactly coincident shared face (fuzzy=" << aFuzzy << ") ==="
              << std::endl;
    reportGlue("(1-off)  GlueOff ", aBox1, aBox2, BOPAlgo_GlueOff, aFuzzy, kRepeats);
    reportGlue("(1-shift)GlueShift", aBox1, aBox2, BOPAlgo_GlueShift, aFuzzy, kRepeats);
    reportGlue("(1-full) GlueFull", aBox1, aBox2, BOPAlgo_GlueFull, aFuzzy, kRepeats);
  }

  // --- Fixture 2: gap inside the caller's tolerance, outside OCCT's default confusion
  //     precision. Identical to #2740's probe.mm fixture 2. ---
  {
    const double  aGap  = 5.0e-5;
    const double  aTol  = 1.0e-3;
    TopoDS_Shape aBox1    = BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 0), 10, 10, 10).Shape();
    TopoDS_Shape aBox2Gap = BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 10 + aGap), 10, 10, 10).Shape();

    std::cout << "=== Fixture 2: gap=" << aGap << " tolerance=" << aTol << " ===" << std::endl;
    reportGlue("(2-off)  GlueOff ", aBox1, aBox2Gap, BOPAlgo_GlueOff, aTol, kRepeats);
    reportGlue("(2-shift)GlueShift", aBox1, aBox2Gap, BOPAlgo_GlueShift, aTol, kRepeats);
    reportGlue("(2-full) GlueFull", aBox1, aBox2Gap, BOPAlgo_GlueFull, aTol, kRepeats);
  }

  // --- Fixture 3 (new for #2749): NOT coincident at all. Box2 sits 1.0 unit above box1, a gap
  //     three orders of magnitude past the 1e-3 tolerance passed as the fuzzy value, so the two
  //     solids neither touch nor come within the operation's own fuzzy bound. This is the input
  //     the issue asks for: what each mode does when the geometry is not what gluing assumes,
  //     since BOPAlgo_GlueEnum.hxx warns "Setting inappropriate option for the operation is
  //     likely to lead to incorrect result" and neither mode checks the precondition itself. ---
  {
    const double aGap = 1.0;
    const double aTol = 1.0e-3;
    TopoDS_Shape aBox1        = BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 0), 10, 10, 10).Shape();
    TopoDS_Shape aBox2NoTouch = BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 10 + aGap), 10, 10, 10).Shape();

    std::cout << "=== Fixture 3: gap=" << aGap << " tolerance=" << aTol
              << " (not coincident at all) ===" << std::endl;
    reportGlue("(3-off)  GlueOff ", aBox1, aBox2NoTouch, BOPAlgo_GlueOff, aTol, kRepeats);
    reportGlue("(3-shift)GlueShift", aBox1, aBox2NoTouch, BOPAlgo_GlueShift, aTol, kRepeats);
    reportGlue("(3-full) GlueFull", aBox1, aBox2NoTouch, BOPAlgo_GlueFull, aTol, kRepeats);
  }

  // --- Fixture 4 (supplementary, not one of the three the issue asks for): fixtures 1-3 are a
  //     single box pair, cheap enough that avgUs above is noise-dominated (repeated runs of the
  //     same fixture disagree on which mode is faster by more than the reported gap). OCCT's own
  //     dev guide states the glue speedup "can go up to 90%", which needs enough FACE/FACE
  //     candidate pairs to show up as anything but scheduler noise. Two NxN grids of unit boxes,
  //     stacked as two compounds sharing N*N coincident unit-square faces, give the algorithm
  //     many coincident face pairs to skip intersecting under gluing, still through the same
  //     single-argument/single-tool BRepAlgoAPI_Fuse shape Shape.glue uses. ---
  {
    const int    aGrid = 12; // 144 coincident unit faces between the two compounds
    BRep_Builder aBuilder;
    TopoDS_Compound aBottom, aTop;
    aBuilder.MakeCompound(aBottom);
    aBuilder.MakeCompound(aTop);
    for (int x = 0; x < aGrid; ++x)
    {
      for (int y = 0; y < aGrid; ++y)
      {
        aBuilder.Add(aBottom, BRepPrimAPI_MakeBox(gp_Pnt(x, y, 0), 1, 1, 1).Shape());
        aBuilder.Add(aTop, BRepPrimAPI_MakeBox(gp_Pnt(x, y, 1), 1, 1, 1).Shape());
      }
    }
    const double aFuzzy = 1.0e-6;

    std::cout << "=== Fixture 4 (supplementary): " << aGrid << "x" << aGrid
              << " coincident-face grid, fuzzy=" << aFuzzy << " ===" << std::endl;
    reportGlue("(4-off)  GlueOff ", aBottom, aTop, BOPAlgo_GlueOff, aFuzzy, 20);
    reportGlue("(4-shift)GlueShift", aBottom, aTop, BOPAlgo_GlueShift, aFuzzy, 20);
    reportGlue("(4-full) GlueFull", aBottom, aTop, BOPAlgo_GlueFull, aFuzzy, 20);
  }

  // --- Fixture 5 (supplementary, not one of the three the issue asks for): genuine PARTIAL face
  //     coincidence, not one of Shape.glue's target cases but the exact geometry
  //     BOPAlgo_GlueEnum.hxx's own warning is about: "Setting inappropriate option for the
  //     operation is likely to lead to incorrect result." Box2 is shifted 3 units in X, so only
  //     7 of the top face's 10 units overlap the bottom face below it: neither face is a subset
  //     of the other, so a correct fuse must SPLIT both faces along the overlap boundary, which
  //     is exactly what GlueFull's own doc comment says it skips ("no partial overlap of the
  //     faces, thus... the faces will not be split"). This measures what changing Shape.glue's
  //     default costs a caller whose faces are merely close, not fully coincident. ---
  {
    TopoDS_Shape aBox1        = BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 0), 10, 10, 10).Shape();
    TopoDS_Shape aBox2Partial = BRepPrimAPI_MakeBox(gp_Pnt(3, 0, 10), 10, 10, 10).Shape();
    const double aFuzzy2 = 1.0e-6;

    std::cout << "=== Fixture 5 (supplementary): partial face overlap (shift=3 of 10), fuzzy="
              << aFuzzy2 << " ===" << std::endl;
    reportGlue("(5-off)  GlueOff ", aBox1, aBox2Partial, BOPAlgo_GlueOff, aFuzzy2, kRepeats);
    reportGlue("(5-shift)GlueShift", aBox1, aBox2Partial, BOPAlgo_GlueShift, aFuzzy2, kRepeats);
    reportGlue("(5-full) GlueFull", aBox1, aBox2Partial, BOPAlgo_GlueFull, aFuzzy2, kRepeats);
  }

  return 0;
}
