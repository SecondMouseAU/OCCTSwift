// The flat C surface Swift calls, shaped like Sources/OCCTBridge: C linkage, scalar returns, a
// refusal value rather than an escaping exception. Every function here returns a sentinel that
// distinguishes "caught it" from "returned a plausible number".
#ifndef PROBE_BRIDGE_H
#define PROBE_BRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

// 20 if the raise was caught by reference to its own type, ProbeFailure, across the target
// boundary; 0 if a different handler took it first.
int probe_bridge_catch_derived(void);

// 21 if the raise was caught by reference to std::exception, the base of the kernel's failure type.
int probe_bridge_catch_base(void);

// 22 if catch (...) took it, which is the form every OCCTBridge function's outermost handler uses.
int probe_bridge_catch_ellipsis(void);

// A throw raised by libc++ itself, not by our code: 23 if std::out_of_range& caught it, 24 if only
// std::exception& did, 0 if nothing did. Anything other than 23 or 24 means the module aborted.
int probe_bridge_catch_stdlib(void);

// Propagation through a frame compiled without the wasm exception flags.
// Returns 10 * (1 if the catch above that frame fired) + (1 if that frame's destructor also ran).
// So 11 is "propagated and cleaned up", 10 is "propagated and leaked", 0 is "never arrived".
int probe_bridge_unwind_through_noeh(void);

// A try/catch written inside a frame compiled without the wasm exception flags.
// 42 if that catch fired, -1 if the exception sailed past it into ours, 0 if nothing was raised.
int probe_bridge_try_inside_noeh(void);

// setjmp/longjmp in a TU carrying the exception flags. 7 on a completed round trip.
int probe_bridge_setjmp_roundtrip(void);

// Kernel objects still alive after a raise that crossed only exception-flagged frames.
// 0 is the only correct answer: it is the same measurement the case above makes, run against a
// path where every frame carries the flags, so the two together isolate the flags as the cause.
int probe_bridge_leak_after_clean_unwind(void);

// Flushes stdout. A trap discards whatever is still buffered, and wasip1 stdout is fully buffered
// when it is not a terminal, so the driver flushes before it asserts.
void probe_bridge_flush(void);

// Raises without catching, so the caller can record what an escaping exception does to the module.
// Never returns normally.
int probe_bridge_raise_uncaught(void);

#ifdef __cplusplus
}
#endif

#endif
