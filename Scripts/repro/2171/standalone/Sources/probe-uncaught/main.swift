// A raise with nothing catching it, so the transcript records what an escaping C++ exception does
// to a wasm module. This is the wasm answer to the question #345 asked natively.
import ProbeBridge

print("raising with no handler anywhere above...")
let unreachable = probe_bridge_raise_uncaught()
print("returned normally with \(unreachable), which should be impossible")
