import Foundation
import Testing
import simd

@testable import OCCTSwift

// Pinned to Geom_OffsetCurve on the same line (Scripts/repro/766-curve-offset-curveset-trimmed/).
// The earlier versions returned silently when the line or the offset was nil, and offsetDirection
// nested its check in a second `if let` (#766).
@Suite("Geom_OffsetCurve Tests")
struct GeomOffsetCurveTests {
    private static func offsetLine() -> Curve3D? {
        guard let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)),
            let offset = Curve3D.offset(basis: line, offset: 5.0, dirX: 0, dirY: 0, dirZ: 1)
        else {
            Issue.record("offset curve not built")
            return nil
        }
        return offset
    }

    @Test func createFromLine() {
        guard let offset = Self.offsetLine() else { return }
        #expect(abs(offset.offsetValue - 5.0) < 1e-10)
        // (T x V) with T = +X and V = +Z is -Y: the offset line runs through (0, -5, 0).
        #expect(simd_distance(offset.point(at: 0), SIMD3(0, -5, 0)) < 1e-12)
    }

    @Test func offsetDirection() {
        guard let offset = Self.offsetLine() else { return }
        guard let dir = offset.offsetDirection else {
            Issue.record("offsetDirection nil for an offset curve")
            return
        }
        #expect(simd_distance(SIMD3(dir.x, dir.y, dir.z), SIMD3(0, 0, 1)) < 1e-10)
    }
}
