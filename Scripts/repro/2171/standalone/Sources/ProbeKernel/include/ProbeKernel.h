// The shape OCCT's error contract has, with none of OCCT in it.
//
// Standard_Failure derives from Standard_Transient, carries a message, is raised through a static
// Raise entry point rather than a bare throw expression, and is caught at the bridge by reference
// to a base class. Everything here mirrors that and nothing else: the point is to put the same
// demands on the wasm unwinder that OCCT will, in a package that builds in three seconds.
#ifndef PROBE_KERNEL_H
#define PROBE_KERNEL_H

#ifdef __cplusplus
#include <exception>
#include <string>

/// Stands in for Standard_Transient: a refcounted base whose live count the test can read back.
/// A throw that skips its destructor shows up as a non-zero count after the catch.
class ProbeTransient
{
public:
  ProbeTransient();
  ProbeTransient(const ProbeTransient &other);
  virtual ~ProbeTransient();

  static int LiveCount();
  static void ResetLiveCount();
};

/// Stands in for Standard_Failure: raised by a static entry point, caught by base reference.
class ProbeFailure : public ProbeTransient, public std::exception
{
public:
  explicit ProbeFailure(const char *message);

  const char *what() const noexcept override;

  /// The shape of Standard_Failure::Raise: the throw expression lives in the kernel, never at the
  /// call site, so every raise in the whole library is one function's worth of unwinder contact.
  static void Raise(const char *message);

private:
  std::string myMessage;
};

/// Stands in for a stack-allocated Handle in an OCCT frame between the raise and the catch.
/// Its destructor runs only if the frame it sits in was compiled with unwind support.
class ProbeGuard
{
public:
  ProbeGuard();
  ~ProbeGuard();
};

extern "C" {
#endif

// Flat C entry points, so a frame compiled without exception support can call back into the kernel
// through a function pointer without needing the C++ declarations above.
void probe_kernel_raise(void);

// Makes the C++ standard library itself raise, rather than raising from our own code. The Swift
// SDK's prebuilt libc++.a is a no-exceptions build whose __throw_out_of_range aborts; an
// exception-enabled TU emits its own weak definition that throws. Which one the linker keeps is
// the measurement.
void probe_kernel_stdlib_raise(void);
int  probe_kernel_live_count(void);
void probe_kernel_reset_live_count(void);

#ifdef __cplusplus
}
#endif

#endif
