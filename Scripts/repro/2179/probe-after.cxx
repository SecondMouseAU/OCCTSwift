// Reduced from OSD_Chronometer.cxx as `wasi-osd-chronometer.patch` leaves it AFTER #2179.
// The include is guarded, the times() stub is gone, and the call site is guarded with the
// same test as the include.
#include <time.h>

#ifndef __wasi__
  #include <sys/times.h>
#endif

#ifndef CLK_TCK
  #define CLK_TCK CLOCKS_PER_SEC
#endif

void GetProcessCPU(double& theUserSeconds, double& theSystemSeconds)
{
  theUserSeconds = theSystemSeconds = 0.0;
  // WASI has no process-associated clocks, so CPU time is reported as zero
#ifndef __wasi__
  static const long aCLK_TCK = CLK_TCK;

  tms aCurrentTMS{};
  times(&aCurrentTMS);

  theUserSeconds   = (double)aCurrentTMS.tms_utime / aCLK_TCK;
  theSystemSeconds = (double)aCurrentTMS.tms_stime / aCLK_TCK;
#endif
}
