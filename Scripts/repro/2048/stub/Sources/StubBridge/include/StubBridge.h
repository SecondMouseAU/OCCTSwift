// The stand-in for Sources/OCCTBridge/include: a flat C surface Swift can import, with the
// outermost `catch (...)` every OCCTBridge function has and the serialising `std::mutex` seven
// files under Sources/OCCTBridge/src hold.
#ifndef STUBBRIDGE_H
#define STUBBRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

// Returns 801, from the prebuilt archive. Proves the archive reached the link line.
int stubBridgeKernelVersion(void);

// Calls a kernel entry point that raises, under an outermost `catch (...)`.
// 22 means the catch fired, which is the bridge's contract.
// -1 means control reached the end of the function with no exception seen at all.
// Neither is returned if the raise propagates past the catch: the module traps instead, which is
// the silent failure this probe exists to show.
int stubBridgeCatchAll(void);

// Takes the serialising lock, which is what needs the threading shim.
int stubBridgeUnderLock(void);

// getpid(), which wasip1's libc declares and does not define. Needs -lwasi-emulated-getpid.
int stubBridgeProcessID(void);

#ifdef __cplusplus
}
#endif

#endif
