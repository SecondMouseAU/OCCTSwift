import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.101.0 Tests

@Suite("Geom_TrimmedCurve Tests")
struct GeomTrimmedCurveTests {

    @Test func trimLineCreatesSubset() {
        if let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)),
            let trimmed = line.trimmed(u1: 2.0, u2: 8.0)
        {
            let sp = trimmed.startPoint
            let ep = trimmed.endPoint
            #expect(abs(sp.x - 2.0) < 1e-6)
            #expect(abs(ep.x - 8.0) < 1e-6)
        }
    }

    @Test func trimmedBasisReturnsOriginal() {
        if let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)),
            let trimmed = line.trimmed(u1: 0, u2: 10)
        {
            let basis = trimmed.trimmedBasis
            #expect(basis != nil)
        }
    }

    @Test func nonTrimmedHasNilBasis() {
        if let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) {
            #expect(line.trimmedBasis == nil)
        }
    }

    @Test func setTrimUpdatesRange() {
        if let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)),
            let trimmed = line.trimmed(u1: 0, u2: 10)
        {
            let ok = trimmed.setTrim(u1: 3.0, u2: 7.0)
            #expect(ok)
            let sp = trimmed.startPoint
            #expect(abs(sp.x - 3.0) < 1e-6)
        }
    }
}
