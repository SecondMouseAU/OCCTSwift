// #2750: does the bridge's own process survive the #2746 fault, and why?
//
// Removing the guard and running the Swift regression suite did not kill the test runner: it
// returned BRepCheck_CheckFail and the expectations failed instead. That is not what the
// standalone #2746 probe does, which dies with SIGSEGV inside BRepCheck_Edge::InContext, so the
// difference had to be measured rather than argued about.
//
// The difference is OSD::SetSignal. The bridge calls it once per process through
// occtEnsureSignals() (OCCTBridge.mm), from fourteen entry points, and a process-wide handler
// outlives the call that installed it. OCCT's Unix handler raises an OSD_Signal, a Standard_Failure
// subclass, from inside the signal handler, and BRepCheck_ParallelAnalyzer::operator() wraps every
// InContext call in catch (Standard_Failure const&), so the fault lands as SetFailStatus rather
// than as a dead process.
//
// Two cases, identical but for that one call:
//
//   without-setsignal   BRepCheck_Analyzer on the fixture shape, no OSD::SetSignal
//   with-setsignal      OSD::SetSignal(Standard_False) first, then the same analyzer
//
// Run one per process, because the first is expected to take its process with it.
//
// Usage: signal-probe <case> <fixture.brep>

#include <BRepCheck_Analyzer.hxx>
#include <BRepTools.hxx>
#include <BRep_Builder.hxx>
#include <OSD.hxx>
#include <Standard_Failure.hxx>
#include <TopoDS_Shape.hxx>

#include <csignal>
#include <cstdio>
#include <cstring>
#include <execinfo.h>
#include <unistd.h>

namespace
{

void segvHandler(int theSignal)
{
  const char* aMessage = "\n*** SIGSEGV: the process died ***\n";
  write(STDERR_FILENO, aMessage, std::strlen(aMessage));
  void* aFrames[32];
  int   aCount = backtrace(aFrames, 32);
  backtrace_symbols_fd(aFrames, aCount, STDERR_FILENO);
  std::signal(theSignal, SIG_DFL);
  raise(theSignal);
}

} // namespace

int main(int argc, char** argv)
{
  if (argc < 3)
  {
    std::printf("usage: signal-probe <without-setsignal|with-setsignal> <fixture.brep>\n");
    return 2;
  }
  const bool aUseSetSignal = std::strcmp(argv[1], "with-setsignal") == 0;

  TopoDS_Shape aShape;
  BRep_Builder aBuilder;
  if (!BRepTools::Read(aShape, argv[2], aBuilder) || aShape.IsNull())
  {
    std::printf("could not read %s\n", argv[2]);
    return 2;
  }

  if (aUseSetSignal)
  {
    // Exactly what occtEnsureSignals() does, once per process.
    OSD::SetSignal(Standard_False);
    std::printf("=== case: with-setsignal ===\n");
  }
  else
  {
    // Only so a death is reported with a frame rather than silently. This handler does not
    // convert anything: it re-raises with the default disposition.
    std::signal(SIGSEGV, segvHandler);
    std::printf("=== case: without-setsignal ===\n");
  }

  try
  {
    BRepCheck_Analyzer anAnalyzer(aShape);
    std::printf("  IsValid() = %s\n", anAnalyzer.IsValid() ? "true" : "false");
    std::printf("  survived, no exception\n");
  }
  catch (Standard_Failure const& theFailure)
  {
    std::printf("  survived, caught a Standard_Failure: %s\n",
                theFailure.GetMessageString() ? theFailure.GetMessageString() : "(no message)");
  }
  catch (...)
  {
    std::printf("  survived, caught a non-Standard_Failure exception\n");
  }
  return 0;
}
