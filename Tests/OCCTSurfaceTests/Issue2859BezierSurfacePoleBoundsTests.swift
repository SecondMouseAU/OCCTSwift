import Testing
import simd

@testable import OCCTSwift

/// #2859: `Geom_BezierSurface`'s *setters* state their index bounds as literal `throw`s, which
/// survive this build, but its `Pole(UIndex, VIndex)` getter states the same bound as a
/// `Standard_OutOfRange_Raise_if`, which the pinned Release kernel compiles to nothing. Nothing in
/// either signature or header comment distinguishes them.
///
/// The assertion is on the refusal value, not on the absence of a crash.
@Suite("#2859 — Bezier surface pole index bounds")
struct Issue2859BezierSurfacePoleBoundsTests {

    /// A 3x4 grid with no pole at the origin, so a fabricated `SIMD3(0, 0, 0)` cannot be mistaken
    /// for a real one.
    private func grid() -> Surface? {
        let poles: [[SIMD3<Double>]] = (1...3).map { i in
            (1...4).map { j in SIMD3(Double(i), Double(j), Double(i * j)) }
        }
        return Surface.bezier(poles: poles)
    }

    @Test("pole(uIndex:vIndex:) returns the pole in range and SIMD3(0, 0, 0) out of it")
    func poleBounds() {
        guard let s = grid() else {
            Issue.record("Surface.bezier returned nil")
            return
        }
        let bp = s.bezierProperties
        #expect(bp.nbUPoles == 3)
        #expect(bp.nbVPoles == 4)
        #expect(bp.pole(uIndex: 1, vIndex: 1) == SIMD3(1, 1, 1))
        #expect(bp.pole(uIndex: 3, vIndex: 4) == SIMD3(3, 4, 12))
        // Written as one test walking a list rather than @Test(arguments:), because an argument
        // element pairing a reference-counted member with a 32-byte builtin vector cannot be written
        // at all (swiftlang/swift#91639, see CLAUDE.md). Pole(1000000, 1) SIGSEGVed before the
        // guard, and Pole(0, 0) returned (1.98e-323, 2.13e-314, 2.47e-323).
        let outOfRange: [(Int, Int)] = [
            (0, 0), (0, 1), (1, 0), (4, 1), (1, 5), (5, 7), (-2, 1), (1, -2), (1_000_000, 1),
        ]
        for (u, v) in outOfRange {
            #expect(
                bp.pole(uIndex: u, vIndex: v) == SIMD3(0, 0, 0),
                "pole(uIndex: \(u), vIndex: \(v)) fabricated a value")
        }
    }
}
