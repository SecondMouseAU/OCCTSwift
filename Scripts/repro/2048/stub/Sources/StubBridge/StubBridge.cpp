#include "include/StubBridge.h"

// The threading shim, by plain guarded #include rather than by a force-include flag. This is the
// alternative #2048 names for gap 1, and the reason it is worth measuring is that a plain
// #include needs no build setting of any kind, so it survives being consumed as a versioned
// SwiftPM dependency without help from a toolset.
//
// STUB_SHIM_VIA_INCLUDE is set by a plain `.define` in the stub's manifest, which is a SAFE
// setting. Building without it is case 2a: the same file with the shim absent.
#if defined(__wasi__) && defined(STUB_SHIM_VIA_INCLUDE)
#include "wasi-std-threading.hpp"
#endif

#include <mutex>
#include <unistd.h>

#include "stubkernel.hpp"

namespace
{
// Stands in for the bridge's own serialising lock.
std::mutex gStubLock;
} // namespace

extern "C" int stubBridgeKernelVersion(void)
{
  return stubKernelVersion();
}

extern "C" int stubBridgeCatchAll(void)
{
  try
  {
    StubFailure::Raise("stub kernel refused");
  }
  catch (...)
  {
    return 22;
  }
  return -1;
}

extern "C" int stubBridgeUnderLock(void)
{
  std::lock_guard<std::mutex> aGuard(gStubLock);
  return stubKernelVersion();
}

extern "C" int stubBridgeProcessID(void)
{
  return static_cast<int>(getpid());
}
