import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

// MARK: - v0.122.0: WireFixer extended, ShapeFix_Edge, BRepTools/BRepLib statics, History extended, Sewing extended

@Suite("v0.122.0, WireFixer Extended")
struct WireFixerExtendedTests {
    // Helper: get a face and its wire from a box
    private func faceAndWire() -> (face: Shape, wire: Shape)? {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return nil }
        let faces = box.subShapes(ofType: .face)
        guard faces.count > 0 else { return nil }
        let face = faces[0]
        let wires = face.subShapes(ofType: .wire)
        guard wires.count > 0 else { return nil }
        return (face, wires[0])
    }

    /// The fixer's wire is still the box face's 10 x 10 outline: four edges of length 10, valid.
    ///
    /// Shared by the five tests below so that each pins the same thing about the result and
    /// differs only in which pass it ran.
    private func expectOutlineUntouched(_ fixer: WireFixer) throws {
        let wire = try #require(fixer.wire)
        #expect(wire.shapeType == .wire)
        #expect(wire.isValid)
        let edges = wire.edges()
        #expect(edges.count == 4)
        for edge in edges { #expect(abs(edge.length - 10) < 1e-9) }
    }

    @Test("Fix gaps 2D")
    func fixGaps2d() throws {
        let (face, wire) = try #require(faceAndWire())
        let fix = try #require(WireFixer(wire: wire, face: face, precision: 1e-6))
        // ShapeFix_Wire::FixGaps2d reports true on this healthy wire (measured on kernel.6).
        // It rewrites the pcurves and leaves the edges' SameParameter flags unset, so the
        // wire reads invalid until the pipeline's own FixEdgeCurves pass re-establishes them
        // (ShapeFix_Wire.cxx, FixEdgeCurves calls FixSameParameter); the outline itself, four
        // edges of length 10, is the same throughout.
        #expect(fix.fixGaps2d())
        let afterGaps = try #require(fix.wire)
        #expect(!afterGaps.isValid)
        let gapEdges = afterGaps.edges()
        #expect(gapEdges.count == 4)
        for edge in gapEdges { #expect(abs(edge.length - 10) < 1e-9) }

        _ = fix.fixEdgeCurves()
        try expectOutlineUntouched(fix)
    }

    @Test("Fix seam")
    func fixSeam() throws {
        // The cylinder's lateral face has a seam; its wire is the seam twice plus the two rim
        // circles, and a correct seam needs no fixing at any of the three indices.
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        let faces = cyl.subShapes(ofType: .face)
        #expect(faces.count == 3)
        let face = faces[0]
        let wire = try #require(face.subShapes(ofType: .wire).first)
        let fix = try #require(WireFixer(wire: wire, face: face, precision: 1e-6))
        for index in 1...3 {
            #expect(!fix.fixSeam(edgeIndex: index))
        }
        let result = try #require(fix.wire)
        #expect(result.isValid)
        #expect(result.edgeCount == 3)
    }

    @Test("Fix shifted")
    func fixShifted() throws {
        let (face, wire) = try #require(faceAndWire())
        let fix = try #require(WireFixer(wire: wire, face: face, precision: 1e-6))
        // Nothing is shifted on a box face's own wire.
        #expect(!fix.fixShifted())
        try expectOutlineUntouched(fix)
    }

    @Test("Fix notched edges")
    func fixNotchedEdges() throws {
        let (face, wire) = try #require(faceAndWire())
        let fix = try #require(WireFixer(wire: wire, face: face, precision: 1e-6))
        // No notch on a rectangle.
        #expect(!fix.fixNotchedEdges())
        try expectOutlineUntouched(fix)
    }

    @Test("Fix tails with configuration")
    func fixTailsWithConfig() throws {
        let (face, wire) = try #require(faceAndWire())
        let fix = try #require(WireFixer(wire: wire, face: face, precision: 1e-6))
        fix.setMaxTailAngle(0.5)
        fix.setMaxTailWidth(0.01)
        // A rectangle has no tail, with or without the limits set.
        #expect(!fix.fixTails())
        try expectOutlineUntouched(fix)
    }
}
