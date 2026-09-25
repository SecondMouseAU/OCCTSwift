import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are BRepBuilderAPI_Sewing's own answers on the same inputs, from
// Scripts/repro/766-healing-sewing/probe.mm (transcript.txt beside it).
// Before #766 these asserted `>= 0`, `#expect(true)`, or discarded their answers (`let _ =`),
// all nested in `if let`.
@Suite("v0.122.0, Sewing Extended")
struct SewingExtendedTests {
    @Test("Sewing deleted faces and queries")
    func sewingDeletedFacesAndQueries() throws {
        // Two coincident thin boxes at 1e-3: the kernel returns a compound of all 12 faces and
        // deletes none.
        let f1 = try #require(Shape.box(width: 10, height: 10, depth: 0.01))
        let f2 = try #require(Shape.box(width: 10, height: 10, depth: 0.01))
        let s = try #require(SewingBuilder(tolerance: 1e-3))
        s.add(f1)
        s.add(f2)
        s.perform()
        let result = try #require(s.result)
        #expect(result.faces().count == 12)
        #expect(s.nbDeletedFaces == 0)
    }

    @Test("Sewing is modified and modified shape")
    func sewingIsModified() throws {
        // Two faces of a box that already share their edge: nothing to modify (kernel: false).
        let b = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let faces = b.subShapes(ofType: .face)
        try #require(faces.count >= 2)
        let s = try #require(SewingBuilder(tolerance: 1e-3))
        s.add(faces[0])
        s.add(faces[1])
        s.perform()
        #expect(s.result != nil)
        #expect(s.isModified(faces[0]) == false)
    }

    @Test("Sewing is degenerated")
    func sewingIsDegenerated() throws {
        let b = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let s = try #require(SewingBuilder(tolerance: 1e-3))
        s.add(b)
        s.perform()
        #expect(!s.isDegenerated(b))
    }

    @Test("Sewing load and modes")
    func sewingLoadAndModes() throws {
        // Load(box) with the modes below: the kernel returns the 6-face shell and, in these
        // modes, reports all 12 edges free.
        let s = try #require(SewingBuilder(tolerance: 1e-3))
        let b = try #require(Shape.box(width: 10, height: 10, depth: 10))
        s.load(b)
        s.setNonManifoldMode(true)
        s.setFaceMode(true)
        s.setFloatingEdgesMode(false)
        s.setMinTolerance(1e-6)
        s.setMaxTolerance(1e-1)
        s.perform()
        let result = try #require(s.result)
        #expect(result.shapeType == .shell)
        #expect(result.faces().count == 6)
        #expect(s.nbFreeEdges == 12)
    }

    @Test("Sewing section bound and which face")
    func sewingSectionBoundAndWhichFace() throws {
        // Kernel: the box's first edge is not a section bound, and WhichFace has no face for it.
        let b = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let s = try #require(SewingBuilder(tolerance: 1e-3))
        s.add(b)
        s.perform()
        let edge = try #require(b.subShapes(ofType: .edge).first)
        #expect(s.isSectionBound(edge) == false)
        #expect(s.whichFace(edge) == nil)
    }
}
