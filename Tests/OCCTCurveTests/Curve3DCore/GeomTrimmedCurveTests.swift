import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.101.0 Tests

// Pinned to Geom_TrimmedCurve on the X axis (Scripts/repro/766-curve-offset-curveset-trimmed/).
// The earlier versions sat inside `if let`, trimmedBasisReturnsOriginal checked only `!= nil`,
// and setTrimUpdatesRange checked only the start (#766).
@Suite("Geom_TrimmedCurve Tests")
struct GeomTrimmedCurveTests {
    private static func xAxis() -> Curve3D? {
        let c = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0))
        if c == nil { Issue.record("line not built") }
        return c
    }

    @Test func trimLineCreatesSubset() {
        guard let line = Self.xAxis(), let trimmed = line.trimmed(u1: 2.0, u2: 8.0) else { return }
        #expect(simd_distance(trimmed.startPoint, SIMD3(2, 0, 0)) < 1e-12)
        #expect(simd_distance(trimmed.endPoint, SIMD3(8, 0, 0)) < 1e-12)
    }

    @Test func trimmedBasisReturnsOriginal() {
        guard let line = Self.xAxis(), let trimmed = line.trimmed(u1: 0, u2: 10) else { return }
        guard let basis = trimmed.trimmedBasis else {
            Issue.record("trimmedBasis nil for a trimmed curve")
            return
        }
        // The untrimmed Geom_Line, not the trimmed curve handed back.
        #expect(basis.curveType == 0)
        #expect(basis.domain == -2e100...2e100)
    }

    @Test func nonTrimmedHasNilBasis() {
        guard let line = Self.xAxis() else { return }
        #expect(line.trimmedBasis == nil)
    }

    @Test func setTrimUpdatesRange() {
        guard let line = Self.xAxis(), let trimmed = line.trimmed(u1: 0, u2: 10) else { return }
        #expect(trimmed.setTrim(u1: 3.0, u2: 7.0))
        #expect(simd_distance(trimmed.startPoint, SIMD3(3, 0, 0)) < 1e-12)
        #expect(simd_distance(trimmed.endPoint, SIMD3(7, 0, 0)) < 1e-12)
    }
}
