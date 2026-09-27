#include "include/ProbeKernel.h"

#include <vector>

namespace
{
int theLiveCount = 0;
}

ProbeTransient::ProbeTransient()
{
  ++theLiveCount;
}

ProbeTransient::ProbeTransient(const ProbeTransient &)
{
  ++theLiveCount;
}

ProbeTransient::~ProbeTransient()
{
  --theLiveCount;
}

int ProbeTransient::LiveCount()
{
  return theLiveCount;
}

void ProbeTransient::ResetLiveCount()
{
  theLiveCount = 0;
}

ProbeFailure::ProbeFailure(const char *message)
    : myMessage(message)
{
}

const char *ProbeFailure::what() const noexcept
{
  return myMessage.c_str();
}

void ProbeFailure::Raise(const char *message)
{
  throw ProbeFailure(message);
}

ProbeGuard::ProbeGuard()
{
  ++theLiveCount;
}

ProbeGuard::~ProbeGuard()
{
  --theLiveCount;
}

extern "C" void probe_kernel_raise(void)
{
  // A live guard between the raise and any catch, exactly where an OCCT frame would hold a Handle.
  ProbeGuard aGuard;
  ProbeFailure::Raise("probe kernel: raised");
}

extern "C" void probe_kernel_stdlib_raise(void)
{
  std::vector<int> aValues;
  aValues.push_back(1);
  // at() out of range is std::out_of_range, raised inside libc++ rather than by anything here.
  (void)aValues.at(7);
}

extern "C" int probe_kernel_live_count(void)
{
  return ProbeTransient::LiveCount();
}

extern "C" void probe_kernel_reset_live_count(void)
{
  ProbeTransient::ResetLiveCount();
}
