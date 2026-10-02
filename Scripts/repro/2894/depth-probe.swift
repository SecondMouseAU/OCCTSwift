import Testing
import simd

@testable import OCCTSwift

/// #2894: is the uncatchable throw a property of the exception's origin, or of the unwind path?
///
/// Three cases, ordered so that a `std::terminate` tells you which one caused it, because a
/// terminate ends the wasm module and nothing after it reports.
///
///   A  `Shape.box(0, 0, 0)`               Standard_DomainError, already known to be CAUGHT on wasm.
///   B  `Curve3D.trimmed(from: u, to: u)`  Standard_ConstructionError raised by `Geom_TrimmedCurve`'s
///                                         constructor ONE frame below the bridge's `catch (...)`.
///   C  `Shape.evolved(spine:profile:)`    the SAME exception, from the SAME OCCT class, but raised
///                                         several frames down inside `BRepFill_Evolved`.
///
/// IT ASSERTS NOTHING, DELIBERATELY, and that is why it lives under `Scripts/repro/` rather than in a
/// test target. A `std::terminate` ends the wasm module, so a case that fails takes the report with
/// it: what carries the information is which `print` lines appear and in what order, not an
/// expectation that never gets a chance to be recorded. Reading it as a test suite would be reading
/// it wrong.
///
/// B is the discriminator. If B is caught and C is not, the exception's class and its translation
/// unit are both fine and what breaks is the unwind through the intervening frames. If B also
/// terminates, then anything thrown by `Geom_TrimmedCurve` is uncatchable here and the origin is
/// what matters, not the depth.
@Suite("ZZProbe2894Depth", .serialized)
struct ZZProbe2894Depth {
    @Test func aShallowDomainError() {
        let (shape, d) = OCCTDiagnostics.capturing { Shape.box(width: 0, height: 0, depth: 0) }
        print(
            "DEPTH-A box(0,0,0) -> \(shape == nil ? "nil" : "shape") records=\(d.count) \(d.map(\.exceptionType))"
        )
    }

    @Test func bShallowConstructionErrorFromTrimmedCurve() {
        guard let line = Curve3D.line(through: .zero, direction: SIMD3(1, 0, 0)) else {
            print("DEPTH-B line fixture failed")
            return
        }
        print("DEPTH-B ATTEMPTING trimmed(from: 1, to: 1); no following line means it escaped")
        let (trimmed, d) = OCCTDiagnostics.capturing { line.trimmed(from: 1.0, to: 1.0) }
        print(
            "DEPTH-B trimmed -> \(trimmed == nil ? "nil" : "curve") records=\(d.count) \(d.map(\.exceptionType))"
        )
        for r in d { print("DEPTH-B record: \(r)") }
    }

    @Test func cDeepConstructionErrorFromTheSameClass() {
        guard let spine = Wire.arc(center: .zero, radius: 20, startAngle: 0, endAngle: .pi / 2),
            let profile = Wire.rectangle(width: 2, height: 2)
        else {
            print("DEPTH-C fixture failed")
            return
        }
        print("DEPTH-C ATTEMPTING evolved; no following line means it escaped")
        let (evolved, d) = OCCTDiagnostics.capturing {
            Shape.evolved(spine: spine, profile: profile)
        }
        print(
            "DEPTH-C evolved -> \(evolved == nil ? "nil" : "shape") records=\(d.count) \(d.map(\.exceptionType))"
        )
    }
}
