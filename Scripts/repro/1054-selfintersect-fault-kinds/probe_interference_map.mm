// Where a clean box's self-interferences come from, and what actually removes them.
//
// The sweep next door shows a clean 10x10x10 box reporting one to three BOPAlgo_SelfIntersect
// results when its analysis is cut short. This probe asks why, by running BOPAlgo_CheckerSI
// directly (what BOPAlgo_ArgumentAnalyzer::TestSelfInterferences does) at a chosen break point
// and printing the state TestSelfInterferences reads afterwards.
//
// The columns are chosen to separate the candidate explanations rather than to illustrate one:
//   newShapes   shapes the pave filler created, which is what BOPDS_DS::IsNewShape reports
//   mapSize     BOPDS_DS::Interferences(), the map TestSelfInterferences walks
//   involvingNew  how many of those pairs IsNewShape would drop
//   surviving   how many TestSelfInterferences would therefore report as SelfIntersect
//   ffRaw       BOPDS_DS::InterfFF(), the raw list PostTreat draws the FF branch from
//   hasErrors   BOPAlgo_Options::HasErrors(), which UserBreak sets via BOPAlgo_AlertUserBreak
//
// `involvingNew` is the load-bearing one: if the IsNewShape filter were what empties the map on
// a complete run, it would be nonzero somewhere. It is not.
//
// Build (from the repo root, see CLAUDE.md's "Compile a Ground Truth C++ Test"):
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/1054-selfintersect-fault-kinds/probe_interference_map.mm -o /tmp/map_1054
//
// Usage: map_1054 <breakAt>...   (0 = never break, i.e. the complete run)
#include <BOPAlgo_CheckerSI.hxx>
#include <BOPDS_DS.hxx>
#include <BOPDS_Pair.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <Message_ProgressIndicator.hxx>
#include <Message_ProgressScope.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopoDS_Shape.hxx>

#include <cstdio>
#include <cstdlib>

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

int main(int argc, char** argv)
{
  const TopoDS_Shape aBox = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();

  for (int anArg = 1; anArg < argc; ++anArg)
  {
    const long           aBreakAt = atol(argv[anArg]);
    TopTools_ListOfShape anArgs;
    anArgs.Append(aBox);
    BOPAlgo_CheckerSI aChecker;
    aChecker.SetArguments(anArgs);
    aChecker.SetNonDestructive(true);
    aChecker.SetRunParallel(Standard_False);

    Handle(CountBreaker)  aBreaker = new CountBreaker(aBreakAt);
    Message_ProgressRange aRange   = aBreaker->Start();
    aChecker.Perform(aRange);

    int aSource = 0, aNewShapes = 0, aMapSize = 0, anInvolvingNew = 0, aSurviving = 0, aFFRaw = 0;
    if (aChecker.PDS() != nullptr)
    {
      const BOPDS_DS& aDS = *aChecker.PDS();
      aSource             = aDS.NbSourceShapes();
      for (int aShape = 0; aShape < aDS.NbShapes(); ++aShape)
      {
        if (aDS.IsNewShape(aShape))
          ++aNewShapes;
      }
      aFFRaw = const_cast<BOPDS_DS&>(aDS).InterfFF().Length();
      for (NCollection_Map<BOPDS_Pair>::Iterator anIt(aDS.Interferences()); anIt.More();
           anIt.Next())
      {
        int n1, n2;
        anIt.Value().Indices(n1, n2);
        ++aMapSize;
        if (aDS.IsNewShape(n1) || aDS.IsNewShape(n2))
          ++anInvolvingNew;
        else
          ++aSurviving;
      }
    }

    std::printf("breakAt=%-6ld polls=%-6ld tripped=%d hasErrors=%d sourceShapes=%-4d "
                "newShapes=%-4d ffRaw=%-4d mapSize=%-4d involvingNew=%-4d surviving=%d\n",
                aBreakAt,
                aBreaker->calls(),
                aBreaker->tripped() ? 1 : 0,
                aChecker.HasErrors() ? 1 : 0,
                aSource,
                aNewShapes,
                aFFRaw,
                aMapSize,
                anInvolvingNew,
                aSurviving);
    std::fflush(stdout);
  }
  return 0;
}
