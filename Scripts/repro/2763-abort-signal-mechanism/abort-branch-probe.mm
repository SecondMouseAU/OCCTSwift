// #2763: which branch of `Standard_ErrorHandler::Abort` does the PINNED kernel take?
//
// `Standard_ErrorHandler.hxx` defines Abort as a template with two bodies:
//
//   #ifndef OCC_CONVERT_SIGNALS      throw theError;
//   #else                            FindHandler(); ... longjmp, or cerr + exit(1) if none
//
// The branch is chosen in the translation unit that INSTANTIATES the template, and the only
// one that does is OCCT's own `OSD/OSD_signal.cxx`, which OCCT's CMake compiles with
// `-DOCC_CONVERT_SIGNALS` on every non-Windows target. #2750 recorded the opposite ("a plain
// `throw` with OCC_CONVERT_SIGNALS undefined"), #2188 recorded this, and #2763 is the two
// meeting. Reading either source settles which prose is right about the FILES; it does not
// settle what the SHIPPED BINARY does, and the binary is what a consumer runs.
//
// So this probe asks the pinned asset directly. It does not need #2746's fixture, or any OCCT
// geometry at all: the question is only what OCCT's installed SIGSEGV handler does, so the
// probe raises an ordinary SIGSEGV of its own by reading through a null pointer.
//
// Three cases, one process each because two of them are expected to end the process:
//
//   bare-segv     no OSD::SetSignal. The fault reaches the default disposition and the process
//                 dies. The control: it proves the fault is real and that OCCT's handler, not
//                 something else, is what changes the outcome in the other two.
//   no-handler    OSD::SetSignal(Standard_False) first, then the same fault inside a plain
//                 try/catch (Standard_Failure const&) with no Standard_ErrorHandler registered
//                 anywhere on the stack. This is the discriminating case:
//                   * plain-throw branch  -> the catch runs (or std::terminate)
//                   * longjmp branch      -> FindHandler() returns null, so OCCT prints
//                                            "*** Abort *** an exception was raised, but no
//                                            catch was found." and calls exit(1)
//   with-handler  the same, with OCC_CATCH_SIGNALS registering a handler inside the try. Only
//                 compiles to anything when THIS translation unit is built with
//                 -DOCC_CONVERT_SIGNALS, which `run.sh` does for a second binary, so the case
//                 reports SKIPPED rather than a false pass in the first one. A catch here is
//                 the longjmp branch working as designed.
//
// Usage: abort-branch-probe <bare-segv|no-handler|with-handler>

#include <OSD.hxx>
#include <Standard_ErrorHandler.hxx>
#include <Standard_Failure.hxx>

#include <csignal>
#include <cstdio>
#include <cstring>
#include <unistd.h>

namespace
{

void reportDefaultDisposition(int theSignal)
{
  const char* aMessage = "\n*** SIGSEGV reached the default disposition: the process dies ***\n";
  write(STDERR_FILENO, aMessage, std::strlen(aMessage));
  std::signal(theSignal, SIG_DFL);
  raise(theSignal);
}

// Out of line and through a volatile pointer so -O0 keeps the load. Returning at all is a
// probe failure, not a result: every case below treats that as "examined nothing" and exits 4,
// on okf/policies/static-gates.md's rule that a detector must fail rather than report clean
// when its own view is implausible.
int faultingRead()
{
  volatile int* aNull = reinterpret_cast<volatile int*>(0);
  return *aNull;
}

} // namespace

int main(int argc, char** argv)
{
  if (argc < 2)
  {
    std::printf("usage: abort-branch-probe <bare-segv|no-handler|with-handler>\n");
    return 2;
  }

#if defined(OCC_CONVERT_SIGNALS)
  const bool aThisTUConverts = true;
#else
  const bool aThisTUConverts = false;
#endif
  std::printf("=== case: %s (this TU %s OCC_CONVERT_SIGNALS) ===\n",
              argv[1],
              aThisTUConverts ? "defines" : "does NOT define");

  if (std::strcmp(argv[1], "bare-segv") == 0)
  {
    std::signal(SIGSEGV, reportDefaultDisposition);
    std::fflush(stdout);
    faultingRead();
    std::printf("  FAIL: the read did not fault, so this probe measured nothing\n");
    return 4;
  }

  if (std::strcmp(argv[1], "no-handler") == 0)
  {
    // Exactly what the bridge's occtEnsureSignals() does, once per process.
    OSD::SetSignal(Standard_False);
    std::fflush(stdout);
    try
    {
      faultingRead();
      std::printf("  FAIL: the read did not fault, so this probe measured nothing\n");
      return 4;
    }
    catch (Standard_Failure const& theFailure)
    {
      std::printf("  caught a Standard_Failure: %s\n",
                  theFailure.GetMessageString() ? theFailure.GetMessageString() : "(no message)");
      std::printf("  => Abort took the `throw` branch\n");
      return 0;
    }
    catch (...)
    {
      std::printf("  caught a non-Standard_Failure exception\n");
      return 0;
    }
  }

  if (std::strcmp(argv[1], "with-handler") == 0)
  {
    if (!aThisTUConverts)
    {
      std::printf("  SKIPPED: OCC_CATCH_SIGNALS expands to nothing in a TU without\n");
      std::printf("           OCC_CONVERT_SIGNALS, so this case would register no handler and\n");
      std::printf("           repeat no-handler. run.sh builds a second binary with the define.\n");
      return 3;
    }
    OSD::SetSignal(Standard_False);
    std::fflush(stdout);
    try
    {
      OCC_CATCH_SIGNALS
      faultingRead();
      std::printf("  FAIL: the read did not fault, so this probe measured nothing\n");
      return 4;
    }
    catch (Standard_Failure const& theFailure)
    {
      std::printf("  caught a Standard_Failure: %s\n",
                  theFailure.GetMessageString() ? theFailure.GetMessageString() : "(no message)");
      std::printf("  => the registered handler was found and control returned to it\n");
      return 0;
    }
    catch (...)
    {
      std::printf("  caught a non-Standard_Failure exception\n");
      return 0;
    }
  }

  std::printf("unknown case: %s\n", argv[1]);
  return 2;
}
