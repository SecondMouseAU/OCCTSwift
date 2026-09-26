// Flat C surface over a C++ implementation, the same shape Sources/OCCTBridge presents to Swift.
#ifndef WASM_PROBE_CXX_H
#define WASM_PROBE_CXX_H

#ifdef __cplusplus
extern "C" {
#endif

// Sums `count` doubles. A negative `count` makes the implementation throw a std::runtime_error and
// catch it, returning minus the length of the caught message, so a caller can tell a working
// throw/catch from a compute path that merely returned a number.
double wasm_probe_sum(const double *values, int count);

#ifdef __cplusplus
}
#endif

#endif
