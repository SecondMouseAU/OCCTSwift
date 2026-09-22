// A translation unit deliberately compiled WITHOUT the wasm exception flags, standing in for what
// happens if OCCT's own CMake never receives them while the bridge that catches does.
//
// Two separate questions live here, and they have different answers:
//   1. can an exception raised below this frame propagate THROUGH it to a catch above, and does
//      this frame's stack cleanup run while it does
//   2. does a try/catch written INSIDE such a frame catch anything
//
// Measured: it propagates, the cleanup does not run, and that catch never fires. All three
// happen without a compiler diagnostic of any kind. See ../../README.md.
#ifndef PROBE_MIDDLE_NO_EH_H
#define PROBE_MIDDLE_NO_EH_H

#ifdef __cplusplus
extern "C" {
#endif

// Calls `fn` with a local object whose destructor bumps the kernel's live count back down.
// The exception is expected to escape; the caller reads probe_kernel_live_count() afterwards to
// see whether this frame's cleanup ran.
void probe_middle_passthrough(void (*fn)(void));

// Calls `fn` inside a try/catch (...) written in this non-exception-flagged TU.
// Returns 42 if the catch fired. If the exception escapes instead, the caller sees it.
int probe_middle_try_catch(void (*fn)(void));

#ifdef __cplusplus
}
#endif

#endif
