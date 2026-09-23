// The stand-in for #1689's JavaScriptKit application: it consumes the stub as an ordinary
// versioned SwiftPM dependency and calls its Swift surface.
import StubOCCT

var failures = 0
for result in stubRunAll() {
    let verdict = result.passed ? "ok  " : "FAIL"
    print("\(verdict) \(result.name): \(result.value) (expected \(result.expected))")
    if !result.passed { failures += 1 }
}
print(failures == 0 ? "consumer: all cases passed" : "consumer: \(failures) case(s) failed")
