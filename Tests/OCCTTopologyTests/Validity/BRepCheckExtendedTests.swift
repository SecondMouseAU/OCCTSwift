import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("BRepCheck extended v0.112")
struct BRepCheckExtendedTests {

    @Test func faceStatus() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if faces.count > 0 {
                let status = box.checkFaceStatus(face: faces[0])
                #expect(status == 0)  // NoError
            }
        }
    }

    @Test func edgeStatus() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count > 0 {
                let status = box.checkEdgeStatus(edge: edges[0])
                #expect(status == 0)
            }
        }
    }

    @Test func vertexStatus() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let verts = box.subShapes(ofType: .vertex)
            if verts.count > 0 {
                let status = box.checkVertexStatus(vertex: verts[0])
                #expect(status == 0)
            }
        }
    }

    /// Before #1981 this asserted `0 < tol < 1`, which a doubled or otherwise wrong tolerance
    /// passes.
    ///
    /// A primitive box's vertices carry Precision::Confusion(), 1e-7, which is what
    /// ShapeAnalysis_ShapeTolerance reports (Scripts/repro/766-topology-brepcheck/).
    @Test func maxTolerance() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let tol = box.maxTolerance(type: 0)  // vertex
        #expect(abs(tol - 1e-7) < 1e-15, "max vertex tolerance \(tol)")
    }

    /// A compound of two 10 mm boxes, one left at `Precision::Confusion()` and one set to 0.01.
    ///
    /// Needed because min, avg and max all agree on a primitive box, where any one of the three
    /// bridge functions answers correctly for the other two. Here they differ, so each is pinned
    /// to a value only it can produce.
    ///
    /// `ShapeAnalysis_ShapeTolerance` averages over sub-shape *occurrences*, unweighted
    /// (`AddTol`/`GlobalTolerance` in `ShapeAnalysis_ShapeTolerance.cxx`). The two boxes are
    /// topologically identical, so each contributes the same occurrence count for every type and
    /// the average is exactly `(1e-7 + 0.01) / 2` whichever type is asked. The count equality is
    /// asserted rather than assumed, since the expected average depends on it.
    private func mixedToleranceCompound() throws -> Shape {
        let tight = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let loose = try #require(
            Shape.box(origin: SIMD3(50, 0, 0), width: 10, height: 10, depth: 10))
        #expect(loose.fixTolerance(0.01))
        for type: ShapeType in [.vertex, .edge, .face] {
            #expect(
                tight.subShapes(ofType: type).count == loose.subShapes(ofType: type).count,
                "the two halves must weigh the same for the expected average to hold")
        }
        return try #require(Shape.compound([tight, loose]))
    }

    /// Before #2904 this asserted `tol > 0` and `tol <= maxTolerance(type: 0)`, both relative to
    /// another measurement from the same subsystem: a bridge scaling min, avg and max by the same
    /// factor passed, and so did one answering `max` for `min`, since a box's two agree.
    ///
    /// Pinned to the value instead, and measured again on a fixture where min and max differ by
    /// five orders of magnitude (`Scripts/repro/2904/`).
    @Test func minTolerance() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(abs(box.minTolerance(type: 0) - 1e-7) < 1e-15, "min vertex tolerance")

        let mixed = try mixedToleranceCompound()
        #expect(abs(mixed.minTolerance(type: 0) - 1e-7) < 1e-15, "min reads the tight half")
        #expect(abs(mixed.maxTolerance(type: 0) - 0.01) < 1e-15, "max reads the loose half")
    }

    /// Before #2904 this asserted only `min <= avg <= max`, which is invariant under scaling all
    /// three and which a box satisfies with all three equal.
    ///
    /// Pinned to the value, and to the occurrence-weighted mean computed independently of the
    /// bridge from the two tolerances the fixture was built with.
    @Test func avgTolerance() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(abs(box.avgTolerance(type: 1) - 1e-7) < 1e-15, "avg edge tolerance")

        let mixed = try mixedToleranceCompound()
        let expected = (1e-7 + 0.01) / 2  // 0.00500005
        let avg = mixed.avgTolerance(type: 1)
        #expect(abs(avg - expected) < 1e-12, "avg edge tolerance \(avg)")
        #expect(avg > mixed.minTolerance(type: 1), "avg is not min")
        #expect(avg < mixed.maxTolerance(type: 1), "avg is not max")
    }

    /// Before #1981 this asserted only the returned `true`, which the bridge returns whenever
    /// nothing throws, so a fixer that set no tolerance at all passed.
    ///
    /// ShapeFix_ShapeTolerance::SetTolerance(0.01) leaves every vertex and edge at exactly 0.01.
    @Test func fixTolerance() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(box.fixTolerance(0.01))
        #expect(abs(box.maxTolerance(type: 0) - 0.01) < 1e-15, "vertex max after fix")
        #expect(abs(box.minTolerance(type: 0) - 0.01) < 1e-15, "vertex min after fix")
        #expect(abs(box.maxTolerance(type: 1) - 0.01) < 1e-15, "edge max after fix")
    }

    /// Before #1981 this asserted `ok || !ok`.
    ///
    /// The kernel's LimitTolerance reports whether it
    /// changed anything: on a fresh box (every tolerance 1e-7, under the 0.001 cap) it returns
    /// false and changes nothing; after raising everything to 0.01 it returns true and caps
    /// vertex and edge tolerances at 0.001.
    @Test func limitMaxTolerance() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(box.limitMaxTolerance(0.001) == false)
        #expect(abs(box.maxTolerance(type: 0) - 1e-7) < 1e-15)
        box.fixTolerance(0.01)
        #expect(box.limitMaxTolerance(0.001) == true)
        #expect(abs(box.maxTolerance(type: 0) - 0.001) < 1e-15, "vertex max after limit")
        #expect(abs(box.maxTolerance(type: 1) - 0.001) < 1e-15, "edge max after limit")
    }
}
