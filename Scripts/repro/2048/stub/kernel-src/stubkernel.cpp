#include "stubkernel.hpp"

void StubFailure::Raise(const char* theMessage)
{
  throw StubFailure(theMessage);
}

int stubKernelVersion()
{
  return 801;
}
