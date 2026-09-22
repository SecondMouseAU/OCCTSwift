#include "include/ProbeMiddleNoEH.h"

#include <ProbeKernel.h>

extern "C" void probe_middle_passthrough(void (*fn)(void))
{
  ProbeGuard aGuard;
  fn();
}

extern "C" int probe_middle_try_catch(void (*fn)(void))
{
  try
  {
    fn();
  }
  catch (...)
  {
    return 42;
  }
  return 0;
}
