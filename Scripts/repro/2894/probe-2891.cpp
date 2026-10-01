// Probe for #2891, run from the same place as #2894's: does the bridge's OWN translation unit
// still expand gp_Dir's inline Standard_ConstructionError_Raise_if on wasm, and does the bridge's
// diagnostics recorder see what it catches?
//
// #2894's probe case E answers the target-level question (a plain C++ unit with the kernel's
// exception flags does raise, at -O2). This one links the REAL bridge sources, so what it
// measures is the bridge compile rather than a probe shaped like it.

#include <cstdio>

#include "OCCTBridge.h"

int main()
{
  double rpx = 0, rpy = 0, rpz = 0;
  OCCTDiagnosticsSetCaptureEnabled(true);
  OCCTDiagnosticsClear();
  // #2891's inputs exactly: origin (5,3,2), direction (0,0,1), xDirection (0,0,1), translate by
  // (1,2,3). The two directions are parallel, so gp_Ax3's constructor reaches gp_Dir::CrossCross
  // on a zero-norm result.
  OCCTAx3Translate(5, 3, 2, 0, 0, 1, 0, 0, 1, 1, 2, 3, &rpx, &rpy, &rpz);
  const int records = (int)OCCTDiagnosticsRecordCount();
  std::printf("PROBE2891 location (%g, %g, %g) records=%d\n", rpx, rpy, rpz, records);
  for (int i = 0; i < records; ++i)
  {
    const char* ctx = OCCTDiagnosticsRecordContext(i);
    const char* typ = OCCTDiagnosticsRecordExceptionType(i);
    const char* msg = OCCTDiagnosticsRecordMessage(i);
    std::printf("PROBE2891   record %d: %s: %s: %s\n", i, ctx ? ctx : "", typ ? typ : "",
                msg ? msg : "");
  }
  std::printf("PROBE2891 Apple answer: (5, 3, 2) records=1\n");
  OCCTDiagnosticsSetCaptureEnabled(false);
  std::fflush(stdout);
  return 0;
}
