import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("Shape Check Tests")
struct ShapeCheckTests {
    /// A closed planar "bowtie" quad whose edges cross in the middle, made into a face.
    ///
    /// It is the control for every "valid shape passes" test in this suite: a check that answers
    /// valid for everything passes the box, sphere and cylinder and fails here.
    private static func bowtieFace() throws -> Shape {
        let wire = try #require(
            Wire.polygon3D(
                [SIMD3(0, 0, 0), SIMD3(10, 10, 0), SIMD3(10, 0, 0), SIMD3(0, 10, 0)],
                closed: true))
        return try #require(Shape.face(from: wire))
    }

    @Test("Valid box passes check")
    func validBoxPasses() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(box.isValid)
        let result = box.checkResult
        #expect(result.isValid)
        #expect(result.errorCount == 0)
    }

    @Test("Valid sphere passes check")
    func validSpherePasses() throws {
        let sphere = try #require(Shape.sphere(radius: 5))
        #expect(sphere.isValid)
        let result = sphere.checkResult
        #expect(result.isValid)
        #expect(result.errorCount == 0)
        #expect(result.firstError == nil)
        #expect(sphere.detailedCheckStatuses.isEmpty)

        // Control: the same properties read the other way on a shape that is broken.
        let bowtie = try Self.bowtieFace()
        #expect(!bowtie.isValid)
        #expect(!bowtie.checkResult.isValid)
    }

    @Test("Valid cylinder passes check")
    func validCylinderPasses() throws {
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        #expect(cyl.isValid)
        let result = cyl.checkResult
        #expect(result.isValid)
        #expect(result.errorCount == 0)
        #expect(result.firstError == nil)
        // All three faces and the solid pass their own checks.
        for face in cyl.faces() { #expect(face.faceCheckResult.isValid) }
        #expect(cyl.checkSolid().isValid)
        #expect(cyl.faces().count == 3)

        let bowtie = try Self.bowtieFace()
        #expect(!bowtie.isValid)
    }

    @Test("Check result has no first error for valid shape")
    func checkResultNoError() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let result = box.checkResult
        #expect(result.firstError == nil)
    }

    @Test("Detailed check on valid shape returns empty")
    func detailedCheckEmpty() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(box.detailedCheckStatuses.isEmpty)

        // Control: the bowtie face reports exactly its two defects, in the kernel's order. An
        // implementation that returns an empty list for every shape fails here.
        let bowtie = try Self.bowtieFace()
        #expect(bowtie.detailedCheckStatuses == [.selfIntersectingWire, .unorientableShape])
        let summary = bowtie.checkResult
        #expect(!summary.isValid)
        #expect(summary.errorCount == 1)
        #expect(summary.firstError == .unorientableShape)
    }

    @Test("All box faces pass face check")
    func boxFaceCheck() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(box.faceCount == 6)
        for i in 0..<box.faceCount {
            let face = try #require(box.face(at: i))
            let result = face.faceCheckResult
            #expect(result.isValid, "Face \(i) should be valid")
            #expect(result.errorCount == 0, "Face \(i) should report no errors")
        }

        // The same holds for the cylinder's three faces. This is BRepCheck_Face's minimum
        // analysis (a face with no surface, a null face), which is all `faceCheckResult` runs:
        // the bowtie face above is invalid to the whole-shape check and valid here, because
        // self-intersection of a wire is a wire-level finding. So there is no face-level
        // control that reads invalid, only the other tests in this suite that read it so.
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        for face in cyl.faces() {
            #expect(face.faceCheckResult.isValid)
            #expect(face.faceCheckResult.errorCount == 0)
        }
        #expect(box.face(at: 6) == nil)
    }

    @Test("Solid check passes for box")
    func solidCheckBox() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(box.isValid)
        // The solid-level check itself, not only the whole-shape one.
        let solid = box.checkSolid()
        #expect(solid.isValid)
        #expect(solid.errorCount == 0)
        #expect(solid.firstError == nil)

        // Control: the same solid with one face removed is no longer a closed solid, and the
        // whole-shape check says so. (checkSolid() is BRepCheck_Solid's minimum analysis and
        // does not see a missing face, so it is the whole-shape check that carries the control.)
        let face = try #require(box.subShapes(ofType: .face).first)
        let holed = try #require(box.removingSubShape(face))
        #expect(holed.faceCount == 5)
        #expect(!holed.isValid)
    }

    @Test("Boolean result passes validity")
    func booleanResultValid() throws {
        // [-5,5]^3 against [0,10]^3: they overlap in a 5-cube, so the fuse is one solid of
        // 1000 + 1000 - 125 = 1875 with 12 faces. (The earlier fixture, origin (5,5,5), met the
        // first box at a single corner and fused to two separate solids.)
        let box1 = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let box2 = try #require(Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10))
        let fused = try #require(box1.union(box2))
        #expect(fused.isValid)
        #expect(fused.solidCount == 1)
        #expect(fused.faceCount == 12)
        #expect(abs(try #require(fused.volume) - 1875) < 1e-6)

        // The corner-touching pair stays two solids, and the result is valid.
        let corner = try #require(
            Shape.box(origin: SIMD3(5, 5, 5), width: 10, height: 10, depth: 10))
        let touching = try #require(box1.union(corner))
        #expect(touching.isValid)
        #expect(touching.solidCount == 2)
        #expect(abs(try #require(touching.volume) - 2000) < 1e-6)
    }
}
