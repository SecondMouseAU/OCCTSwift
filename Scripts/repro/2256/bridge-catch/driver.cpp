#include <cstdio>

#include "OCCTBridge.h"

extern int g_bridgeCatchBodyRuns;

int main()
{
  void* result  = reinterpret_cast<void*>(1);
  bool  escaped = false;
  try
  {
    // A zero-length direction. OCCT's gp_Dir raises on it, inside the bridge's own try block.
    result = OCCTCurve3DCreateLine(0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
  }
  catch (...)
  {
    escaped = true;
  }
  std::printf("bridge returned null : %d\n", result == nullptr ? 1 : 0);
  std::printf("catch body ran       : %d\n", g_bridgeCatchBodyRuns);
  std::printf("escaped the bridge   : %d\n", escaped ? 1 : 0);
  if (result == nullptr && g_bridgeCatchBodyRuns == 1 && !escaped)
  {
    std::printf("VERDICT: caught at the bridge boundary\n");
    return 0;
  }
  std::printf("VERDICT: the bridge did NOT catch it\n");
  return 1;
}
