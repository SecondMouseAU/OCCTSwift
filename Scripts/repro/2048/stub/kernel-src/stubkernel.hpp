// The stand-in for an OCCT public header: it names a failure type and a raising entry point, and
// it is compiled into the consumer's translation unit exactly as Standard_Failure.hxx is.
#ifndef STUBKERNEL_HPP
#define STUBKERNEL_HPP

#include <stdexcept>

// Shaped like Standard_Failure: raised through a static entry point, caught by base reference.
class StubFailure : public std::runtime_error
{
public:
  explicit StubFailure(const char* theMessage) : std::runtime_error(theMessage) {}
  static void Raise(const char* theMessage);
};

// A call that cannot fail, to prove the archive is on the link line at all.
int stubKernelVersion();

#endif
