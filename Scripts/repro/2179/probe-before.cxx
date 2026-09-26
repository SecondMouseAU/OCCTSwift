// Reduced from OSD_Chronometer.cxx as `wasi-osd-chronometer.patch` leaves it.
// Reproduces #2179: the include at :27 and the patch's times() stub.
#include <time.h>
#include <sys/times.h> // OSD_Chronometer.cxx:27, unguarded

#ifndef CLK_TCK
  #define CLK_TCK CLOCKS_PER_SEC

  #ifdef __wasi__
// WASI doesn't have times() or struct tms
static clock_t times(struct tms* buf)
{
  return 0;
}
  #endif
#endif

void GetProcessCPU(double& theUserSeconds, double& theSystemSeconds)
{
  static const long aCLK_TCK = CLK_TCK;
  (void)aCLK_TCK;

#ifdef __wasi__
  theUserSeconds = theSystemSeconds = 0.0;
#else
  tms aCurrentTMS{};
  times(&aCurrentTMS);

  theUserSeconds   = (double)aCurrentTMS.tms_utime / aCLK_TCK;
  theSystemSeconds = (double)aCurrentTMS.tms_stime / aCLK_TCK;
#endif
}
