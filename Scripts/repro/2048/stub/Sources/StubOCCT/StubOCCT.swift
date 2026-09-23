// The stand-in for Sources/OCCTSwift: the Swift surface a JavaScriptKit application imports.
import StubBridge

// Present only when the stub was built with STUB_SJLJ=1, which is how setjmp gets a case of its
// own instead of failing every case before it.
#if canImport(StubSjLj)
import StubSjLj
#endif

/// One measurement from the stub, named the way the probe's output reads.
public struct StubProbeResult: Sendable {
    public let name: String
    public let value: Int32
    public let expected: Int32

    public var passed: Bool { value == expected }
}

/// Runs every case the stub can run, in the order the probe reports them.
public func stubRunAll() -> [StubProbeResult] {
    var results = [
        StubProbeResult(name: "kernel archive on the link line", value: stubBridgeKernelVersion(), expected: 801),
        StubProbeResult(name: "serialising lock compiles and locks", value: stubBridgeUnderLock(), expected: 801),
        StubProbeResult(name: "outermost catch (...) fires", value: stubBridgeCatchAll(), expected: 22),
        // getpid() is not a fixed value, so the case checks only that it linked and returned
        // something plausible. Without -lwasi-emulated-getpid the link fails and nothing runs.
        StubProbeResult(name: "getpid linked", value: stubBridgeProcessID() > 0 ? 1 : 0, expected: 1),
    ]
    #if canImport(StubSjLj)
    results.append(
        StubProbeResult(name: "setjmp/longjmp round trip", value: Int32(stubSjLjRoundTrip()), expected: 7)
    )
    #endif
    return results
}
