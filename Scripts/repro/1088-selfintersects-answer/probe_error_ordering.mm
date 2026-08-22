// #1088: why the fixed OCCTShapeSelfIntersects tests HasErrors() BEFORE reading the map.
//
// The obvious fix for #1088 is "read BOPDS_DS::Interferences() instead of HasErrors()". Read
// unconditionally, that is wrong in the other direction: the map and "the run finished" are
// independent, and a run that stopped early leaves pairs in the map that a completed run would
// have cleared. This probe measures that on a shape that is provably clean.
//
// The mechanism is BOPAlgo_CheckerSI::CheckFaceSelfIntersection, whose first two statements are
//
//   NCollection_Map<BOPDS_Pair>& aMPK = *((NCollection_Map<BOPDS_Pair>*)&myDS->Interferences());
//   aMPK.Clear();
//
// so everything BOPAlgo_PaveFiller accumulated is still in the map until that point, and PostTreat
// afterwards re-adds only pairs passing its own per-type gates (for a valid solid's face adjacency,
// none). #1054 measured the same transition from the other side.
//
// Scope, stated rather than implied: OCCTShapeSelfIntersects calls Perform() with a default
// Message_ProgressRange, so it installs no progress indicator and this user-break path is not
// reachable through the bridge. The break is used here because it is the one way to stop the run
// at a chosen point. What it establishes is the property the fix depends on, that a non-empty map
// does not mean "self-intersects" unless the run also finished, and a pave-filler failure
// (BOPAlgo_AlertIntersectionFailed, which IS reachable through the bridge) leaves the run
// unfinished in exactly the same way.
//
// Build (from the repo root, per CLAUDE.md's "Compile a Ground Truth C++ Test"):
//
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/1088-selfintersects-answer/probe_error_ordering.mm -o /tmp/order_1088
//
// Usage: order_1088 [maxBreakPoint]     (default 400; sweeps every break point from 1 to it)

#include <BOPAlgo_CheckerSI.hxx>
#include <BOPDS_DS.hxx>
#include <BOPDS_Pair.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <Message_ProgressIndicator.hxx>
#include <Message_ProgressScope.hxx>
#include <Message_ProgressRange.hxx>
#include <TopoDS_Shape.hxx>
#include <TopTools_ListOfShape.hxx>

#include <cstdio>
#include <cstdlib>

// Breaks at the Nth UserBreak poll. Sweeping N visits every abort point exactly once, where a
// wall clock only ever visits whichever one the machine happened to be at.
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

struct Row
{
  bool hasErrors = false;
  int  surviving = 0;
};

static Row runAt(const TopoDS_Shape& shape, long breakAt)
{
  Row r;
  try
  {
    occ::handle<CountBreaker> breaker = new CountBreaker(breakAt);
    Message_ProgressScope     scope(breaker->Start(), nullptr, 1);

    BOPAlgo_CheckerSI    checker;
    TopTools_ListOfShape shapes;
    shapes.Append(shape);
    checker.SetArguments(shapes);
    checker.Perform(scope.Next());

    r.hasErrors = checker.HasErrors();

    const BOPDS_DS* pds = checker.PDS();
    if (pds)
    {
      const BOPDS_DS&                      ds = *pds;
      NCollection_Map<BOPDS_Pair>::Iterator it(ds.Interferences());
      for (; it.More(); it.Next())
      {
        int n1 = 0, n2 = 0;
        it.Value().Indices(n1, n2);
        if (!ds.IsNewShape(n1) && !ds.IsNewShape(n2))
          r.surviving++;
      }
    }
  }
  catch (...)
  {
  }
  return r;
}

int main(int argc, char** argv)
{
  setvbuf(stdout, nullptr, _IONBF, 0);

  const long maxBreak = (argc > 1) ? atol(argv[1]) : 400;

  // A plain 10x10x10 box. It is clean, and the complete run below is the control that says so.
  const TopoDS_Shape box = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();

  const Row complete = runAt(box, 0);
  printf("complete run:  hasErrors=%d  surviving=%d\n", (int)complete.hasErrors, complete.surviving);

  long nonEmptyMap      = 0;   // break points where the map still holds pairs
  long wrongIfUnordered = 0;   // ... and so would answer "self-intersects" without the HasErrors test
  long wrongIfOrdered   = 0;   // ... and still would WITH it, which should be zero
  long firstNonEmpty    = -1;

  printf("\n%8s %10s %10s\n", "breakAt", "hasErrors", "surviving");
  for (long n = 1; n <= maxBreak; ++n)
  {
    const Row r = runAt(box, n);
    // Detail rows around the transition, so the aggregate below is readable rather than asserted.
    if ((r.surviving > 0 && nonEmptyMap < 3) || (n >= maxBreak - 4) || r.hasErrors)
      printf("%8ld %10d %10d\n", n, (int)r.hasErrors, r.surviving);
    if (r.surviving > 0)
    {
      nonEmptyMap++;
      if (firstNonEmpty < 0)
        firstNonEmpty = n;
      wrongIfUnordered++;                 // map read with no HasErrors() test: reports true
      if (!r.hasErrors)
        wrongIfOrdered++;                 // map read after a passing HasErrors() test
    }
  }

  printf("break points swept:                                  %ld\n", maxBreak);
  printf("  ... leaving a non-empty surviving map:             %ld  (first at %ld)\n",
         nonEmptyMap, firstNonEmpty);
  printf("  ... answering \"self-intersects\" WITHOUT the HasErrors test: %ld\n", wrongIfUnordered);
  printf("  ... answering \"self-intersects\" WITH the HasErrors test:    %ld\n", wrongIfOrdered);
  printf("\nEvery one of those is a clean box, so both counts are wrong answers.\n"
         "\n"
         "The third number is the finding, and it is not zero: HasErrors() is NOT a proxy for\n"
         "\"the run finished\" once a progress indicator exists. Only the two break points that land\n"
         "on BOPAlgo_CheckerSI::Perform's own UserBreak(aPS) record an alert; the rest are consumed\n"
         "by a Message_ProgressScope::More() inside a BOPAlgo_PaveFiller phase loop, and More() is\n"
         "just !UserBreak(), so the loop stops early and records nothing at all.\n"
         "\n"
         "None of this is reachable through OCCTShapeSelfIntersects, which passes a default\n"
         "Message_ProgressRange. Message_ProgressScope::UserBreak() is `myProgress && ...`, so with\n"
         "no indicator installed it is always false and no break can occur. That is what makes the\n"
         "HasErrors() test sufficient there, and this sweep is the standing warning that giving\n"
         "this call a timeout would take that away.\n");
  return 0;
}
