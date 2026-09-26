// setjmp/longjmp in a TU that also carries the wasm exception flags.
//
// Issue #2047 claimed OSD_ThreadPool.cxx's setjmp/longjmp needs -fwasm-exceptions, and nothing
// ever verified it. OCCT uses setjmp in OSD_signal and OSD_ThreadPool, so whether the two
// mechanisms coexist in one translation unit is a question #2172 will hit on its first file.
#ifndef PROBE_SETJMP_H
#define PROBE_SETJMP_H

#ifdef __cplusplus
extern "C" {
#endif

// Returns 7 if the longjmp arrived back at the setjmp, 0 if control never left the straight line.
int probe_setjmp_roundtrip(void);

#ifdef __cplusplus
}
#endif

#endif
