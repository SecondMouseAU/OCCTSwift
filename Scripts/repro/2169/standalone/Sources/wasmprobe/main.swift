import WasmProbeCxx

let values: [Double] = [1.5, 2.25, 3.0]
let sum = values.withUnsafeBufferPointer { wasm_probe_sum($0.baseAddress, Int32($0.count)) }
print("libc++ compute path: \(sum)")
guard sum == 6.75 else { fatalError("expected 6.75 from the compute path, got \(sum)") }

// "wasm probe: negative count" is 26 characters, so a working throw/catch returns -26.
let caught = wasm_probe_sum(nil, -1)
print("C++ throw/catch path: \(caught)")
guard caught == -26.0 else { fatalError("expected -26.0 from the throw path, got \(caught)") }

print("hello from wasm32-unknown-wasip1")
