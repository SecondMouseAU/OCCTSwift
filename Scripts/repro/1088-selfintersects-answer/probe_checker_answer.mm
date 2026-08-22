// #1088: what OCCTShapeSelfIntersects answers, against what BOPAlgo_CheckerSI actually found.
//
// The bridge function returns BOPAlgo_CheckerSI::HasErrors(), which is BOPAlgo_Options' "did this
// algorithm fail" flag. The result of the check lives in BOPDS_DS::Interferences(), which the
// bridge never reads. This probe runs the bridge's own call sequence and prints both, plus a
// second construction through BOPAlgo_ArgumentAnalyzer with only SelfInterMode enabled, which is
// the path Shape.isSelfIntersecting(timeout:) takes.
//
// Build (from the repo root, per CLAUDE.md's "Compile a Ground Truth C++ Test"):
//
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/1088-selfintersects-answer/probe_checker_answer.mm -o /tmp/probe_1088
//
// Run: /tmp/probe_1088 [fixture ...]   (no argument runs every fixture)

#include <BOPAlgo_ArgumentAnalyzer.hxx>
#include <BOPAlgo_CheckResult.hxx>
#include <BOPAlgo_CheckerSI.hxx>
#include <BOPDS_DS.hxx>
#include <BOPDS_Pair.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepTools.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <TopoDS_Shape.hxx>
#include <TopTools_ListOfShape.hxx>

#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

// ---------------------------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------------------------

// A plain 10x10x10 box. Clean, and the shape the one existing test in the suite uses.
static TopoDS_Shape fixtureBox()
{
  return BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();
}

// Two 10-unit boxes overlapping by 5, in one compound. Genuinely self-interfering: the two solids
// share volume, so faces of one cut faces of the other.
static TopoDS_Shape fixtureOverlapBoxes()
{
  TopoDS_Shape a = BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 0), 10.0, 10.0, 10.0).Shape();
  TopoDS_Shape b = BRepPrimAPI_MakeBox(gp_Pnt(5, 0, 0), 10.0, 10.0, 10.0).Shape();
  TopoDS_Compound c;
  BRep_Builder    bb;
  bb.MakeCompound(c);
  bb.Add(c, a);
  bb.Add(c, b);
  return c;
}

// The second construction of "genuinely self-intersecting": two overlapping spheres rather than
// two overlapping boxes. Different primitive, different surface type (spherical, not planar), so
// an answer that agrees here is not agreeing because of anything specific to planar face pairs.
static TopoDS_Shape fixtureOverlapSpheres()
{
  TopoDS_Shape a = BRepPrimAPI_MakeSphere(gp_Pnt(0, 0, 0), 10.0).Shape();
  TopoDS_Shape b = BRepPrimAPI_MakeSphere(gp_Pnt(12, 0, 0), 10.0).Shape();
  TopoDS_Compound c;
  BRep_Builder    bb;
  bb.MakeCompound(c);
  bb.Add(c, a);
  bb.Add(c, b);
  return c;
}

// The control for the compound fixtures: two boxes in a compound that do NOT overlap. Proves the
// compound wrapper is not itself what the checker reacts to.
static TopoDS_Shape fixtureDisjointBoxes()
{
  TopoDS_Shape a = BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 0), 10.0, 10.0, 10.0).Shape();
  TopoDS_Shape b = BRepPrimAPI_MakeBox(gp_Pnt(50, 0, 0), 10.0, 10.0, 10.0).Shape();
  TopoDS_Compound c;
  BRep_Builder    bb;
  bb.MakeCompound(c);
  bb.Add(c, a);
  bb.Add(c, b);
  return c;
}

// A single solid, not a compound, whose own two faces cross: a bowtie profile swept into a prism.
// The profile crosses itself, so the swept side walls cross each other.
static TopoDS_Shape fixtureBowtiePrism()
{
  BRepBuilderAPI_MakePolygon poly;
  poly.Add(gp_Pnt(0, 0, 0));
  poly.Add(gp_Pnt(10, 10, 0));
  poly.Add(gp_Pnt(10, 0, 0));
  poly.Add(gp_Pnt(0, 10, 0));
  poly.Close();
  if (!poly.IsDone())
    return TopoDS_Shape();
  return BRepPrimAPI_MakePrism(poly.Wire(), gp_Vec(0, 0, 10)).Shape();
}

// An emptied solid: a box's TShape with every sub-shape dropped. This is what Shape.emptied()
// produces, and #1054 measured it as the input BOPAlgo_ArgumentAnalyzer records BadType for.
static TopoDS_Shape fixtureEmptySolid()
{
  TopoDS_Shape box = fixtureBox();
  return box.EmptyCopied();
}

// A null TopoDS_Shape. Shape.nullified() returns a wrapper around one of these.
static TopoDS_Shape fixtureNullShape()
{
  return TopoDS_Shape();
}

// Two arguments in one call. BOPAlgo_CheckerSI records BOPAlgo_AlertMultipleArguments for this,
// which is an error with no bearing at all on whether anything self-intersects. Not reachable
// through the bridge (which appends exactly one shape) but it is the cleanest demonstration that
// HasErrors() and "self-intersects" are different questions.
static bool fixtureIsMultiArgument(const std::string& name)
{
  return name == "MULTI_ARG";
}

// ---------------------------------------------------------------------------------------------
// The two readings
// ---------------------------------------------------------------------------------------------

struct Reading
{
  bool hasErrors      = false;  // what OCCTShapeSelfIntersects returns today
  int  mapSize        = 0;      // BOPDS_DS::Interferences() after Perform()
  int  surviving      = 0;      // the same, with TestSelfInterferences' IsNewShape skip applied
  int  involvingNew   = 0;      // pairs the IsNewShape skip drops
  bool performThrew   = false;
};

// Exactly the call OCCTShapeSelfIntersects makes, plus a read of what it never reads.
static Reading readChecker(const TopoDS_Shape& shape, bool multiArgument)
{
  Reading r;
  try
  {
    BOPAlgo_CheckerSI    checker;
    TopTools_ListOfShape shapes;
    shapes.Append(shape);
    if (multiArgument)
      shapes.Append(shape);
    checker.SetArguments(shapes);
    checker.Perform();

    r.hasErrors = checker.HasErrors();

    const BOPDS_DS* pds = checker.PDS();
    if (pds)
    {
      const BOPDS_DS&                    ds   = *pds;
      const NCollection_Map<BOPDS_Pair>& mpk  = ds.Interferences();
      r.mapSize                               = mpk.Extent();
      NCollection_Map<BOPDS_Pair>::Iterator it(mpk);
      for (; it.More(); it.Next())
      {
        int n1 = 0, n2 = 0;
        it.Value().Indices(n1, n2);
        if (ds.IsNewShape(n1) || ds.IsNewShape(n2))
          r.involvingNew++;
        else
          r.surviving++;
      }
    }
  }
  catch (...)
  {
    r.performThrew = true;
  }
  return r;
}

// The second construction: BOPAlgo_ArgumentAnalyzer with only the self-interference mode enabled.
// This is the path Shape.isSelfIntersecting(timeout:) takes, and it reaches the same interference
// map through TestSelfInterferences rather than by reading it here.
static std::string readAnalyzer(const TopoDS_Shape& shape, int& outSelfIntersect, int& outOther)
{
  outSelfIntersect = 0;
  outOther         = 0;
  std::string statuses;
  try
  {
    BOPAlgo_ArgumentAnalyzer analyzer;
    analyzer.SetShape1(shape);
    analyzer.OperationType()   = BOPAlgo_UNKNOWN;
    analyzer.SelfInterMode()   = true;
    analyzer.ArgumentTypeMode() = false;
    analyzer.SmallEdgeMode()   = false;
    analyzer.RebuildFaceMode() = false;
    analyzer.TangentMode()     = false;
    analyzer.MergeVertexMode() = false;
    analyzer.MergeEdgeMode()   = false;
    analyzer.ContinuityMode()  = false;
    analyzer.CurveOnSurfaceMode() = false;
    analyzer.StopOnFirstFaulty()  = false;
    analyzer.Perform();

    const NCollection_List<BOPAlgo_CheckResult>&          res = analyzer.GetCheckResult();
    NCollection_List<BOPAlgo_CheckResult>::Iterator        it(res);
    for (; it.More(); it.Next())
    {
      BOPAlgo_CheckStatus st = it.Value().GetCheckStatus();
      if (!statuses.empty())
        statuses += ",";
      switch (st)
      {
        case BOPAlgo_SelfIntersect:    statuses += "SelfIntersect";    outSelfIntersect++; break;
        case BOPAlgo_OperationAborted: statuses += "OperationAborted"; outOther++;         break;
        case BOPAlgo_BadType:          statuses += "BadType";          outOther++;         break;
        case BOPAlgo_CheckUnknown:     statuses += "CheckUnknown";     outOther++;         break;
        default:                       statuses += "other";            outOther++;         break;
      }
    }
  }
  catch (...)
  {
    statuses = "threw";
  }
  if (statuses.empty())
    statuses = "(none)";
  return statuses;
}

// An orthogonal property of each fixture, taken so a fixture that has silently stopped meaning its
// name is visible rather than assumed: face count, and the maximum vertex tolerance. The tolerance
// is here for a second reason, below.
static void shapeSummary(const TopoDS_Shape& s, int& outFaces, double& outMaxTol)
{
  outFaces  = 0;
  outMaxTol = 0.0;
  if (s.IsNull())
    return;
  for (TopExp_Explorer ex(s, TopAbs_FACE); ex.More(); ex.Next())
    outFaces++;
  for (TopExp_Explorer ex(s, TopAbs_VERTEX); ex.More(); ex.Next())
  {
    double t = BRep_Tool::Tolerance(TopoDS::Vertex(ex.Current()));
    if (t > outMaxTol)
      outMaxTol = t;
  }
}

int main(int argc, char** argv)
{
  struct Entry
  {
    const char* name;
    TopoDS_Shape (*build)();
  };
  const Entry kEntries[] = {
    {"BOX", fixtureBox},
    {"DISJOINT_BOXES", fixtureDisjointBoxes},
    {"OVERLAP_BOXES", fixtureOverlapBoxes},
    {"OVERLAP_SPHERES", fixtureOverlapSpheres},
    {"BOWTIE_PRISM", fixtureBowtiePrism},
    {"EMPTY_SOLID", fixtureEmptySolid},
    {"NULL_SHAPE", fixtureNullShape},
    {"MULTI_ARG", fixtureBox},
  };

  // Unbuffered: a fixture that takes the process down with a signal would otherwise lose every
  // row printed before it, which is exactly the run worth reading.
  setvbuf(stdout, nullptr, _IONBF, 0);

  std::vector<std::string> wanted;
  for (int i = 1; i < argc; i++)
    wanted.push_back(argv[i]);

  printf("%-16s %6s %8s %8s %8s %8s %8s   %-8s %-8s   %s\n",
         "fixture", "faces", "hasErr", "mapSize", "surviv", "involNew", "tolMoved",
         "bridge", "correct", "analyzer statuses");

  for (const Entry& e : kEntries)
  {
    if (!wanted.empty())
    {
      bool found = false;
      for (const std::string& w : wanted)
        if (w == e.name)
          found = true;
      if (!found)
        continue;
    }

    TopoDS_Shape s = e.build();

    int    facesBefore = 0;
    double tolBefore   = 0.0;
    shapeSummary(s, facesBefore, tolBefore);

    Reading r = readChecker(s, fixtureIsMultiArgument(e.name));

    // The bridge does not call SetNonDestructive, so the checker is permitted to modify the input
    // shape's tolerances in place. Measured rather than assumed.
    int    facesAfter = 0;
    double tolAfter   = 0.0;
    shapeSummary(s, facesAfter, tolAfter);
    bool tolMoved = (tolAfter != tolBefore);

    int         selfInt = 0, other = 0;
    std::string statuses = readAnalyzer(s, selfInt, other);

    // What the bridge returns today, and what reading the interference map gives instead.
    bool bridgeAnswer  = r.hasErrors;
    bool correctAnswer = (r.surviving > 0);

    printf("%-16s %6d %8s %8d %8d %8d %8s   %-8s %-8s   %s\n",
           e.name,
           facesBefore,
           r.performThrew ? "threw" : (r.hasErrors ? "1" : "0"),
           r.mapSize,
           r.surviving,
           r.involvingNew,
           tolMoved ? "YES" : "no",
           bridgeAnswer ? "true" : "false",
           correctAnswer ? "true" : "false",
           statuses.c_str());
  }

  return 0;
}
