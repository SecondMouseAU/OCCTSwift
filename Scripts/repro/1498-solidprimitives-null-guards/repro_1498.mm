// #1498 ground truth: OCCTShapeCreateRevolution (the Wire-based revolution entry point) is the
// one of the issue's five sites with no confirmed one-line Swift repro (no public `Wire.nullified`
// equivalent -- `OCCTWireFromShape` already refuses a null `TopoDS_Shape`, and every bridge site
// that constructs an `OCCTWire` wrapper fills `->wire` before returning it, so nothing in the
// public Swift surface can hand this function a non-null wrapper pointer around a null
// `TopoDS_Wire`). This probe drives the REAL bridge function directly -- not a hand-rolled
// reimplementation of what it does -- by compiling the actual translation unit that defines it
// (`OCCTBridge_Modeling_SolidPrimitives.mm`) together with the one other file it needs
// (`OCCTBridge.mm`, for `occtEnsureSignals`/`occtHasSelfIntersectingWire`) and this driver, then
// calling `OCCTShapeCreateRevolution` with a hand-constructed `OCCTWire` wrapper (accessible only
// because this driver includes the private `OCCTBridge_Internal.h`, never reachable from Swift or
// from any public bridge consumer) whose `wire` field is left at its default (null) value.
//
// Each probe runs in a forked child (same harness shape as
// Scripts/repro/556-null-handle-guard-sweep/repro_556.mm and
// Scripts/repro/cluster-c-null-handle-shapes/probe_cluster_c.mm) so a SIGSEGV is reported rather
// than ending the whole run.
//
// Compile and run twice, per CLAUDE.md's ground-truth recipe, once against this file pre-fix
// (checked out from the merge-base commit, before #1498's guard swap) and once post-fix:
//
//   clang++ -std=c++17 -ObjC++ -w -DOCCT_AVAILABLE=1 -DOCCT_NO_DEPRECATED \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -I"Sources/OCCTBridge/include" -I"Sources/OCCTBridge/src" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Sources/OCCTBridge/src/OCCTBridge.mm \
//     Sources/OCCTBridge/src/OCCTBridge_Modeling_SolidPrimitives.mm \
//     Scripts/repro/1498-solidprimitives-null-guards/repro_1498.mm \
//     -o /tmp/repro_1498
//   /tmp/repro_1498
//
// Pre-fix: SIGSEGV (uncatchable). Post-fix: "refused (nullptr), no crash".

#import "OCCTBridge.h"
#import "OCCTBridge_Internal.h"

#include <cstdio>
#include <functional>
#include <sys/wait.h>
#include <unistd.h>

static void probe(const char* what, const std::function<void()>& body)
{
  fflush(stdout);
  pid_t pid = fork();
  if (pid < 0)
  {
    printf("  %-60s %s\n", what, "fork() failed - no verdict");
    return;
  }
  if (pid == 0)
  {
    body();
    fflush(stdout);
    _exit(0);
  }
  int st = 0;
  waitpid(pid, &st, 0);
  const char* verdict;
  if (WIFSIGNALED(st))
  {
    verdict = (WTERMSIG(st) == SIGSEGV) ? "SIGSEGV (uncatchable)" : "SIGNAL (uncatchable)";
  }
  else if (WEXITSTATUS(st) == 0)
  {
    verdict = "returned normally";
  }
  else
  {
    verdict = "other abnormal exit";
  }
  printf("  %-60s %s\n", what, verdict);
}

int main()
{
  printf("#1498: OCCTShapeCreateRevolution(profile) with a non-null wrapper around a null "
         "TopoDS_Wire\n\n");

  probe("OCCTShapeCreateRevolution(nullWireWrapper, ...)", [] {
    OCCTWire nullWire;  // default-constructed: ->wire is a default (null) TopoDS_Wire
    OCCTWireRef profile = &nullWire;
    OCCTShapeRef result =
        OCCTShapeCreateRevolution(profile, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 2.0 * M_PI);
    printf("      result = %p %s\n", (void*)result, result ? "" : "(refused, no crash)");
  });

  return 0;
}
