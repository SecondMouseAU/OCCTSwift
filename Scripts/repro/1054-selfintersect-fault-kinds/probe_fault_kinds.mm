// Ground-truth probe for OCCTSwift#1054 and #1068.
//
// Runs the exact BOPAlgo_ArgumentAnalyzer call OCCTShapeSelfIntersectsBounded makes, then
// prints the full BOPAlgo_CheckStatus list instead of just HasFaulty(), so an abort or a
// rejected argument can be told apart from a real self-intersection. Also prints what the
// bridge returned before #1054 and what it returns after, for the same run.
//
// Build (from the repo root, see CLAUDE.md's "Compile a Ground Truth C++ Test"):
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/1054-selfintersect-fault-kinds/probe_fault_kinds.mm -o /tmp/probe_1054
//
// Usage: probe_1054 <BOX|EMPTY_SOLID|EMPTY_COMPOUND|OVERLAP|path.brep> <argumentTypeMode 0|1> <timeout>...
//   PROBE_VERBOSE=1 additionally traces every progress poll and every scope close, which is
//   how the checkpoint-free stretches were located.
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

#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <string>

class WatchdogBreaker : public Message_ProgressIndicator
{
public:
  explicit WatchdogBreaker(double seconds)
      : myDeadline(std::chrono::steady_clock::now()
                   + std::chrono::duration_cast<std::chrono::steady_clock::duration>(
                     std::chrono::duration<double>(seconds)))
  {
  }

  Standard_Boolean UserBreak() override
  {
    ++myCalls;
    if (myVerbose)
    {
      std::printf("    [poll %ld at %.3fs]\n", myCalls, elapsed());
      std::fflush(stdout);
    }
    if (std::chrono::steady_clock::now() >= myDeadline)
    {
      if (!myTripped)
      {
        myTripped     = true;
        myFirstTripAt = elapsed();
      }
      ++myTrips;
      return Standard_True;
    }
    return Standard_False;
  }

  void Show(const Message_ProgressScope& theScope, const Standard_Boolean) override
  {
    if (myVerbose)
    {
      std::printf("    [close %-42s pos=%.3f at %.3fs]\n",
                  theScope.Name() ? theScope.Name() : "(unnamed)",
                  GetPosition(),
                  elapsed());
      std::fflush(stdout);
    }
  }

  void   setVerbose(bool theVerbose) { myVerbose = theVerbose; }
  bool   tripped() const { return myTripped; }
  long   calls() const { return myCalls; }
  long   trips() const { return myTrips; }
  double firstTripAt() const { return myFirstTripAt; }

  DEFINE_STANDARD_RTTI_INLINE(WatchdogBreaker, Message_ProgressIndicator)

private:
  double elapsed() const
  {
    return std::chrono::duration<double>(std::chrono::steady_clock::now() - myStart).count();
  }

  std::chrono::steady_clock::time_point myStart = std::chrono::steady_clock::now();
  std::chrono::steady_clock::time_point myDeadline;
  bool                                  myTripped     = false;
  bool                                  myVerbose     = false;
  long                                  myCalls       = 0;
  long                                  myTrips       = 0;
  double                                myFirstTripAt = -1.0;
};
DEFINE_STANDARD_HANDLE(WatchdogBreaker, Message_ProgressIndicator)

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

static void runOne(const TopoDS_Shape& theShape, double theTimeout, bool theArgumentTypeMode)
{
  auto                     aT0 = std::chrono::steady_clock::now();
  BOPAlgo_ArgumentAnalyzer anAnalyzer;
  anAnalyzer.SetShape1(theShape);
  anAnalyzer.ArgumentTypeMode()  = theArgumentTypeMode;
  anAnalyzer.SelfInterMode()     = true;
  anAnalyzer.StopOnFirstFaulty() = true;
  anAnalyzer.SetRunParallel(Standard_False);

  Handle(WatchdogBreaker) aBreaker;
  bool                    aThrew = false;
  try
  {
    if (theTimeout > 0.0)
    {
      aBreaker = new WatchdogBreaker(theTimeout);
      aBreaker->setVerbose(getenv("PROBE_VERBOSE") != nullptr);
      Message_ProgressRange aRange = aBreaker->Start();
      anAnalyzer.Perform(aRange);
    }
    else
    {
      anAnalyzer.Perform();
    }
  }
  catch (...)
  {
    aThrew = true;
  }
  double anElapsed = std::chrono::duration<double>(std::chrono::steady_clock::now() - aT0).count();

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
      aSelfIntersect = true;
    else
      anOtherFault = true;
  }
  const bool aTripped = !aBreaker.IsNull() && aBreaker->tripped();

  // What the bridge returned before #1054: HasFaulty() first, watchdog second.
  const int aBefore =
    aThrew ? -1 : (anAnalyzer.HasFaulty() ? 1 : (aTripped ? -1 : 0));
  // What it returns after: watchdog first, then the statuses by kind, with any non
  // BOPAlgo_SelfIntersect status winning, since BOPAlgo_OperationAborted is appended
  // after whatever the aborted pass had already recorded.
  const int anAfter =
    aThrew ? -1 : (aTripped ? -1 : (anOtherFault ? -1 : (aSelfIntersect ? 1 : 0)));

  std::printf("timeout=%-8.4f elapsed=%-8.3f firstTrip=%-8.3f polls=%-8ld trips=%-8ld threw=%d "
              "HasFaulty=%d statuses=[%s] before=%d after=%d\n",
              theTimeout,
              anElapsed,
              aBreaker.IsNull() ? -1.0 : aBreaker->firstTripAt(),
              aBreaker.IsNull() ? 0 : aBreaker->calls(),
              aBreaker.IsNull() ? 0 : aBreaker->trips(),
              aThrew ? 1 : 0,
              anAnalyzer.HasFaulty() ? 1 : 0,
              aStatuses.c_str(),
              aBefore,
              anAfter);
  std::fflush(stdout);
}

int main(int argc, char** argv)
{
  const std::string aKind            = argc > 1 ? argv[1] : "BOX";
  const bool        anArgumentTypeMode = argc > 2 ? (atoi(argv[2]) != 0) : true;

  TopoDS_Shape aShape;
  if (aKind == "BOX")
  {
    aShape = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();
    std::printf("shape: a 10x10x10 box\n");
  }
  else if (aKind == "EMPTY_COMPOUND")
  {
    TopoDS_Compound aCompound;
    BRep_Builder    aBuilder;
    aBuilder.MakeCompound(aCompound);
    aShape = aCompound;
    std::printf("shape: an empty compound\n");
  }
  else if (aKind == "EMPTY_SOLID")
  {
    // TopoDS_Shape::EmptyCopied(), which is what Shape.emptied gives: the type without the
    // sub-shapes. Shape.compound([]) cannot stand in, OCCTShapeCreateCompound refuses count < 1.
    aShape = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape().EmptyCopied();
    std::printf("shape: an emptied solid (EmptyCopied of a box)\n");
  }
  else if (aKind == "OVERLAP")
  {
    // Two boxes sharing volume, compounded rather than fused: a genuine self-intersection.
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
    std::printf("shape: two overlapping boxes in one compound\n");
  }
  else
  {
    BRep_Builder aBuilder;
    if (!BRepTools::Read(aShape, aKind.c_str(), aBuilder))
    {
      std::printf("FAIL: could not read %s\n", aKind.c_str());
      return 2;
    }
    std::printf("shape: %s\n", aKind.c_str());
  }
  std::printf("ArgumentTypeMode=%d\n", anArgumentTypeMode ? 1 : 0);

  for (int anArg = 3; anArg < argc; ++anArg)
  {
    runOne(aShape, atof(argv[anArg]), anArgumentTypeMode);
  }
  return 0;
}
