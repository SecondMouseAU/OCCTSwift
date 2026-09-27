#include "include/ProbeBridge.h"

#include <ProbeKernel.h>
#include <ProbeMiddleNoEH.h>
#include <ProbeSetjmp.h>

#include <cstdio>
#include <exception>
#include <stdexcept>

extern "C" int probe_bridge_catch_derived(void)
{
  probe_kernel_reset_live_count();
  try
  {
    ProbeFailure::Raise("probe bridge: derived");
  }
  catch (const ProbeFailure &)
  {
    return 20;
  }
  catch (...)
  {
    return 0;
  }
  return 0;
}

extern "C" int probe_bridge_catch_base(void)
{
  probe_kernel_reset_live_count();
  try
  {
    ProbeFailure::Raise("probe bridge: base");
  }
  catch (const std::exception &)
  {
    return 21;
  }
  catch (...)
  {
    return 0;
  }
  return 0;
}

extern "C" int probe_bridge_catch_ellipsis(void)
{
  probe_kernel_reset_live_count();
  try
  {
    probe_kernel_raise();
  }
  catch (...)
  {
    return 22;
  }
  return 0;
}

extern "C" int probe_bridge_catch_stdlib(void)
{
  try
  {
    probe_kernel_stdlib_raise();
  }
  catch (const std::out_of_range &)
  {
    return 23;
  }
  catch (const std::exception &)
  {
    return 24;
  }
  catch (...)
  {
    return 0;
  }
  return 0;
}

extern "C" int probe_bridge_unwind_through_noeh(void)
{
  probe_kernel_reset_live_count();
  int aCaught = 0;
  try
  {
    // probe_kernel_raise holds a ProbeGuard too, so a clean unwind returns the count to zero only
    // if BOTH frames released theirs. The exception object itself is gone by the time we read it.
    probe_middle_passthrough(&probe_kernel_raise);
  }
  catch (...)
  {
    aCaught = 1;
  }
  return 10 * aCaught + (probe_kernel_live_count() == 0 ? 1 : 0);
}

extern "C" int probe_bridge_try_inside_noeh(void)
{
  probe_kernel_reset_live_count();
  try
  {
    return probe_middle_try_catch(&probe_kernel_raise);
  }
  catch (...)
  {
    return -1;
  }
}

extern "C" int probe_bridge_setjmp_roundtrip(void)
{
  return probe_setjmp_roundtrip();
}

extern "C" int probe_bridge_leak_after_clean_unwind(void)
{
  probe_kernel_reset_live_count();
  try
  {
    probe_kernel_raise();
  }
  catch (...)
  {
  }
  // Read after the handler has ended, so the exception object itself is already destroyed.
  return probe_kernel_live_count();
}

extern "C" void probe_bridge_flush(void)
{
  std::fflush(nullptr);
}

extern "C" int probe_bridge_raise_uncaught(void)
{
  ProbeFailure::Raise("probe bridge: nobody is catching this");
  return 0;
}
