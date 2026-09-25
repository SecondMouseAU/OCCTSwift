// #766 / #1989: kernel-parity probe for Tests/OCCTMiscTests/BridgeExceptionDiagnosticsTests.swift.
//
// The suite tests the bridge's caught-exception channel (#1161). What the kernel decides, and what
// this probe measures directly, is the exception each fixture raises: its OCCT type name, its
// message, whether a stack trace is attached at depth 0 and at depth 16, and what
// Standard_Failure::DefaultStackTraceLength reports after a negative depth is set. The buffer,
// nesting, clear and logging-switch behaviour is bridge-side state with no kernel counterpart.
//
// Build (from the repo root, against the SwiftPM-resolved pinned kernel):
//   X=.build/artifacts/<checkout>/OCCT/OCCT.xcframework/macos-arm64
//   clang++ -std=c++17 -ObjC++ -w -I"$X/Headers" -L"$X" -lOCCT-macos \
//     -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/766-bridge-exception-diagnostics/probe.mm -o /tmp/probe_766_bed

#include <Standard_Failure.hxx>
#include <gp_Dir.hxx>
#include <gp_Ax1.hxx>
#include <gp_Pnt.hxx>
#include <IntTools_Tools.hxx>
#include <cstdio>
#include <string>

static void report(const char* theLabel)
{
  try
  {
    throw;
  }
  catch (const Standard_Failure& anEx)
  {
    std::string aStack = anEx.GetStackString() != nullptr ? anEx.GetStackString() : "";
    std::printf("%s: kind=Standard_Failure type=%s message=\"%s\" stackEmpty=%s\n",
                theLabel,
                anEx.ExceptionType(),
                anEx.what(),
                aStack.empty() ? "true" : "false");
  }
  catch (const std::exception& anEx)
  {
    std::printf("%s: kind=std::exception message=\"%s\"\n", theLabel, anEx.what());
  }
  catch (...)
  {
    std::printf("%s: kind=unknown\n", theLabel);
  }
}

int main()
{
  // callThatThrowsInsideTheBridge(): OCCTIntToolsIsDirsCoinside(0,0,0, 0,0,1).
  try
  {
    bool r = IntTools_Tools::IsDirsCoinside(gp_Dir(0, 0, 0), gp_Dir(0, 0, 1));
    std::printf("IsDirsCoinside((0,0,0),(0,0,1)) returned %d (no throw)\n", r);
  }
  catch (...)
  {
    report("IsDirsCoinside((0,0,0),(0,0,1))");
  }

  // recordsNothingOnSuccess: the same call with two equal unit directions.
  try
  {
    bool r = IntTools_Tools::IsDirsCoinside(gp_Dir(0, 0, 1), gp_Dir(0, 0, 1));
    std::printf("IsDirsCoinside((0,0,1),(0,0,1)) returned %s, no throw\n", r ? "true" : "false");
  }
  catch (...)
  {
    report("IsDirsCoinside((0,0,1),(0,0,1))");
  }

  // explainsANilReturnFromAPublicAPI: OCCTShapeHistoryFromRotate builds gp_Ax1 from gp_Dir(axis).
  try
  {
    gp_Ax1 anAxis(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 0));
    (void)anAxis;
    std::printf("gp_Ax1 with zero axis: no throw\n");
  }
  catch (...)
  {
    report("gp_Ax1(origin, gp_Dir(0,0,0))");
  }

  // capturesAStackTraceOnRequest: default depth, then 16.
  std::printf("DefaultStackTraceLength at start = %d\n",
              Standard_Failure::DefaultStackTraceLength());
  Standard_Failure::SetDefaultStackTraceLength(16);
  std::printf("after SetDefaultStackTraceLength(16) = %d\n",
              Standard_Failure::DefaultStackTraceLength());
  try
  {
    gp_Dir aDir(0, 0, 0);
    (void)aDir;
  }
  catch (...)
  {
    report("gp_Dir(0,0,0) at depth 16");
  }

  // clampsANegativeStackTraceDepth: what the kernel does with -5 when nothing clamps it.
  Standard_Failure::SetDefaultStackTraceLength(-5);
  std::printf("after SetDefaultStackTraceLength(-5) = %d\n",
              Standard_Failure::DefaultStackTraceLength());
  Standard_Failure::SetDefaultStackTraceLength(0);
  return 0;
}
