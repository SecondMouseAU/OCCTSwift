import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Wire 2D Fillet Tests")
struct Wire2DFilletTests {

    @Test("Fillet single vertex of rectangle")
    func filletSingleVertex() {
        guard let rect = Wire.rectangle(width: 10, height: 5) else {
            Issue.record("Failed to create rectangle wire")
            return
        }

        let filleted = rect.filleted2D(vertexIndex: 0, radius: 1.0)

        #expect(filleted != nil)
    }

    @Test("Fillet all vertices of rectangle")
    func filletAllVertices() {
        guard let rect = Wire.rectangle(width: 10, height: 5) else {
            Issue.record("Failed to create rectangle wire")
            return
        }

        let filleted = rect.filletedAll2D(radius: 1.0)

        #expect(filleted != nil)
    }

    @Test("Fillet polygon wire")
    func filletPolygonWire() {
        guard
            let polygon = Wire.polygon(
                [
                    SIMD2(0, 0),
                    SIMD2(10, 0),
                    SIMD2(10, 10),
                    SIMD2(5, 15),
                    SIMD2(0, 10),
                ], closed: true)
        else {
            Issue.record("Failed to create polygon wire")
            return
        }

        let filleted = polygon.filleted2D(vertexIndex: 2, radius: 1.5)

        #expect(filleted != nil)
    }

    // MARK: - #1478 Finding 1: mid-loop AddFillet failure must not be masked

    /// Regression for issue #1478, Finding 1. `OCCTWireFilletAll2D` used to read
    /// `ChFi2d_Builder::Status()` only once, AFTER the whole per-vertex `AddFillet` loop.
    /// `Status()` is a single field the builder overwrites on every call, so that one
    /// post-loop read reflects only the LAST vertex, not the whole batch: a failure on an
    /// earlier vertex, masked by a later success, silently produced a partial fillet
    /// result while the doc comment promises "original wire if some failed".
    ///
    /// This fixture (an irregular pentagon with a very short edge near its third point) is
    /// pinned to fail specifically at the SECOND vertex -- not the last -- while every other
    /// vertex, including the last, succeeds, which is exactly the shape that defeats a
    /// single post-loop `Status()` read. Verified directly against the real `ChFi2d_Builder`
    /// algorithm (`Scripts/repro/1478-healing-blends-defects/find_fillet_fixture.mm`): with
    /// the pre-fix logic this exact fixture returns a 9-edge partial result (4 of 5 corners
    /// filleted); with the fix it correctly falls back to the unmodified 5-edge wire.
    @Test("filletedAll2D falls back to the original wire on a mid-loop failure, not just a last-vertex one")
    func filletAllFallsBackOnMidLoopFailure() throws {
        let points: [SIMD2<Double>] = [
            SIMD2(0, 0),
            SIMD2(10, 0),
            SIMD2(10.2, 0.3),
            SIMD2(10, 10),
            SIMD2(0, 10),
        ]
        let polygon = try #require(Wire.polygon(points, closed: true))
        #expect(polygon.edges().count == 5)

        let filleted = try #require(polygon.filletedAll2D(radius: 1.0))

        // The correct fallback hands back the ORIGINAL wire unchanged (same edge count as
        // the input). A partially-filleted result -- what the pre-fix code returned here --
        // would have a different edge count, since some straight corners get replaced by
        // new fillet-arc edges while others stay sharp.
        #expect(filleted.edges().count == polygon.edges().count)
    }
}
