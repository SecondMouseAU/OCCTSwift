import Foundation
import Testing
import simd

@testable import OCCTSwift

// Pinned to GeomTools_CurveSet Write/Read on the same curves
// (Scripts/repro/766-curve-offset-curveset-trimmed/transcript.txt). The earlier versions nested
// every check in `if let`s, and the round trip checked only the count, not the geometry its name
// promises (#766).
@Suite("GeomTools_CurveSet Tests")
struct GeomToolsCurveSetTests {
    @Test func serializeDeserialize3D() {
        guard let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)),
            let circ = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5.0)
        else {
            Issue.record("fixtures not built")
            return
        }
        guard let data = Curve3D.serializeCurves([line, circ]) else {
            Issue.record("serializeCurves returned nil")
            return
        }
        #expect(!data.isEmpty)
        guard let curves = Curve3D.deserializeCurves(data) else {
            Issue.record("deserializeCurves returned nil")
            return
        }
        #expect(curves.count == 2)
        #expect(curves.last?.curveType == 1)  // Circle
    }

    @Test func roundtripPreservesGeometry() {
        guard let circ = Curve3D.circle(center: SIMD3(1, 2, 3), normal: SIMD3(0, 0, 1), radius: 7.0),
            let data = Curve3D.serializeCurves([circ]),
            let curves = Curve3D.deserializeCurves(data)
        else {
            Issue.record("round trip failed")
            return
        }
        #expect(curves.count == 1)
        #expect(simd_distance(curves.first?.point(at: 0) ?? .zero, SIMD3(8, 2, 3)) < 1e-12)
    }

    // #1512: GeomTools_CurveSet::Add dedups by underlying-object identity ("new or existing"
    // index), so two array elements sharing one underlying Geom_Curve used to be silently
    // collapsed to a single stored entry instead of refusing the batch, the same failure shape
    // as the null-handle guard right above it in the bridge. Passing the same instance twice is
    // the issue's own minimal fixture: both elements alias the identical Geom_Curve handle.
    @Test func duplicateHandleRefusesTheBatch() {
        guard let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) else {
            Issue.record("line not built")
            return
        }
        #expect(Curve3D.serializeCurves([line, line]) == nil)
    }
}
