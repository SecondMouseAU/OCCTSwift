// Deterministic break-point sweep for OCCTSwift#1054.
//
// A wall-clock watchdog can only visit whichever abort point the machine happens to be at
// when the deadline passes, which makes "can a timed-out check report a self-intersection
// on a clean solid" a question about luck. This breaks at the Nth progress poll instead and
// sweeps N over the whole analysis, so every abort point is visited exactly once and the
// answer is a count rather than a sighting.
//
// Build (from the repo root):
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/1054-selfintersect-fault-kinds/probe_break_point_sweep.mm -o /tmp/sweep_1054
//
// Usage: sweep_1054 <BOX|OVERLAP|path.brep> <maxBreakPoint>
//   PROBE_ROWS=1 prints one row per break point instead of only the histogram.
#include <BOPAlgo_ArgumentAnalyzer.hxx>
#include <BOPAlgo_CheckResult.hxx>
#include <BOPAlgo_CheckStatus.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepTools.hxx>
#include <BRep_Builder.hxx>
#include <Message_ProgressIndicator.hxx>
#include <Message_ProgressScope.hxx>
#include <NCollection_List.hxx>
#include <TopoDS_Compound.hxx>
#include <TopoDS_Shape.hxx>
#include <gp_Trsf.hxx>

#include <cstdio>
#include <cstdlib>
#include <map>
#include <string>

class CountBreaker : public Message_ProgressIndicator
{
public:
  explicit CountBreaker(long theBreakAt)
      : myBreakAt(theBreakAt)
  {
  }

  Standard_Boolean UserBreak() override
  {
    ++myCalls;
    if (myBreakAt > 0 && myCalls >= myBreakAt)
    {
      myTripped = true;
      return Standard_True;
    }
    return Standard_False;
  }

  void Show(const Message_ProgressScope&, const Standard_Boolean) override {}
  bool tripped() const { return myTripped; }
  long calls() const { return myCalls; }

  DEFINE_STANDARD_RTTI_INLINE(CountBreaker, Message_ProgressIndicator)

private:
  long myBreakAt;
  long myCalls   = 0;
  bool myTripped = false;
};
DEFINE_STANDARD_HANDLE(CountBreaker, Message_ProgressIndicator)

static const char* statusName(BOPAlgo_CheckStatus theStatus)
{
  switch (theStatus)
  {
    case BOPAlgo_CheckUnknown: return "CheckUnknown";
    case BOPAlgo_BadType: return "BadType";
    case BOPAlgo_SelfIntersect: return "SelfIntersect";
    case BOPAlgo_TooSmallEdge: return "TooSmallEdge";
    case BOPAlgo_NonRecoverableFace: return "NonRecoverableFace";
    case BOPAlgo_IncompatibilityOfVertex: return "IncompatibilityOfVertex";
    case BOPAlgo_IncompatibilityOfEdge: return "IncompatibilityOfEdge";
    case BOPAlgo_IncompatibilityOfFace: return "IncompatibilityOfFace";
    case BOPAlgo_OperationAborted: return "OperationAborted";
    case BOPAlgo_GeomAbs_C0: return "GeomAbs_C0";
    case BOPAlgo_InvalidCurveOnSurface: return "InvalidCurveOnSurface";
    case BOPAlgo_NotValid: return "NotValid";
  }
  return "?";
}

int main(int argc, char** argv)
{
  const std::string aKind    = argc > 1 ? argv[1] : "BOX";
  const long        aMaxPoll = argc > 2 ? atol(argv[2]) : 400;

  TopoDS_Shape aShape;
  if (aKind == "BOX")
  {
    aShape = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();
  }
  else if (aKind == "OVERLAP")
  {
    TopoDS_Shape aBox1 = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();
    gp_Trsf      aTrsf;
    aTrsf.SetTranslation(gp_Vec(5.0, 0.0, 0.0));
    TopoDS_Shape    aBox2 = BRepBuilderAPI_Transform(aBox1, aTrsf, true).Shape();
    TopoDS_Compound aCompound;
    BRep_Builder    aBuilder;
    aBuilder.MakeCompound(aCompound);
    aBuilder.Add(aCompound, aBox1);
    aBuilder.Add(aCompound, aBox2);
    aShape = aCompound;
  }
  else
  {
    BRep_Builder aBuilder;
    if (!BRepTools::Read(aShape, aKind.c_str(), aBuilder))
    {
      std::printf("FAIL: could not read %s\n", aKind.c_str());
      return 2;
    }
  }

  std::map<std::string, long> aHistogram;
  long aFirstAborted = -1, aFirstSelfIntersect = -1, aFirstUnknown = -1, aFirstBadType = -1;
  long aWrongBefore = 0, aWrongAfter = 0, aTotalPolls = 0;

  for (long aBreakAt = 0; aBreakAt <= aMaxPoll; ++aBreakAt)
  {
    BOPAlgo_ArgumentAnalyzer anAnalyzer;
    anAnalyzer.SetShape1(aShape);
    anAnalyzer.ArgumentTypeMode()  = true;
    anAnalyzer.SelfInterMode()     = true;
    anAnalyzer.StopOnFirstFaulty() = true;
    anAnalyzer.SetRunParallel(Standard_False);

    Handle(CountBreaker)  aBreaker = new CountBreaker(aBreakAt);
    Message_ProgressRange aRange   = aBreaker->Start();
    bool                  aThrew   = false;
    try
    {
      anAnalyzer.Perform(aRange);
    }
    catch (...)
    {
      aThrew = true;
    }

    bool        aSelfIntersect = false, anOtherFault = false;
    std::string aStatuses;
    for (NCollection_List<BOPAlgo_CheckResult>::Iterator anIt(anAnalyzer.GetCheckResult());
         anIt.More();
         anIt.Next())
    {
      const BOPAlgo_CheckStatus aStatus = anIt.Value().GetCheckStatus();
      if (!aStatuses.empty())
        aStatuses += ",";
      aStatuses += statusName(aStatus);
      if (aStatus == BOPAlgo_SelfIntersect)
      {
        aSelfIntersect = true;
        if (aFirstSelfIntersect < 0)
          aFirstSelfIntersect = aBreakAt;
      }
      else
      {
        anOtherFault = true;
      }
      if (aStatus == BOPAlgo_OperationAborted && aFirstAborted < 0)
        aFirstAborted = aBreakAt;
      if (aStatus == BOPAlgo_CheckUnknown && aFirstUnknown < 0)
        aFirstUnknown = aBreakAt;
      if (aStatus == BOPAlgo_BadType && aFirstBadType < 0)
        aFirstBadType = aBreakAt;
    }
    const bool aTripped = aBreaker->tripped();
    const int  aBefore  = aThrew ? -1 : (anAnalyzer.HasFaulty() ? 1 : (aTripped ? -1 : 0));
    const int  anAfter =
      aThrew ? -1 : (aTripped ? -1 : (aSelfIntersect ? 1 : (anOtherFault ? -1 : 0)));
    if (aBefore == 1)
      ++aWrongBefore;
    if (anAfter == 1)
      ++aWrongAfter;

    if (aThrew)
      aStatuses += "|threw";
    if (aStatuses.empty())
      aStatuses = "(none)";
    aHistogram[aStatuses]++;
    if (aBreakAt == 0)
      aTotalPolls = aBreaker->calls();

    if (getenv("PROBE_ROWS") != nullptr)
    {
      std::printf("  n=%-6ld polls=%-6ld tripped=%d HasFaulty=%d before=%d after=%d statuses=[%s]\n",
                  aBreakAt,
                  aBreaker->calls(),
                  aTripped ? 1 : 0,
                  anAnalyzer.HasFaulty() ? 1 : 0,
                  aBefore,
                  anAfter,
                  aStatuses.c_str());
    }
  }

  std::printf("shape=%s  polls in an uninterrupted run=%ld  break points swept=%ld\n",
              aKind.c_str(),
              aTotalPolls,
              aMaxPoll);
  for (const auto& anEntry : aHistogram)
  {
    std::printf("  %-56s x%ld\n", anEntry.first.c_str(), anEntry.second);
  }
  std::printf("  first break point yielding OperationAborted: %ld\n", aFirstAborted);
  std::printf("  first break point yielding SelfIntersect:    %ld\n", aFirstSelfIntersect);
  std::printf("  first break point yielding CheckUnknown:     %ld\n", aFirstUnknown);
  std::printf("  first break point yielding BadType:          %ld\n", aFirstBadType);
  std::printf("  break points answering 1 before the fix:     %ld\n", aWrongBefore);
  std::printf("  break points answering 1 after the fix:      %ld\n", aWrongAfter);
  return 0;
}
