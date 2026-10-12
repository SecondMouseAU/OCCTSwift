import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("MakeFace Extras Tests")
struct MakeFaceExtrasTests {

    @Test func faceFromSphere() throws {
        let face = try #require(
            Shape.faceFromSphere(radius: 5.0, uMin: 0, uMax: .pi, vMin: -.pi / 4, vMax: .pi / 4))
        #expect(face.isValid)
        // r^2 (u2 - u1)(sin v2 - sin v1) = 25 pi sqrt 2
        #expect(abs((face.surfaceArea ?? 0) - 25 * Double.pi * 2.0.squareRoot()) < 1e-6)
    }

    @Test func faceFromTorus() throws {
        let face = try #require(
            Shape.faceFromTorus(
                majorRadius: 10, minorRadius: 2, uMin: 0, uMax: .pi, vMin: 0, vMax: .pi))
        #expect(face.isValid)
        // r (u2 - u1)(R (v2 - v1) + r (sin v2 - sin v1)) with r = 2, R = 10 and u, v over [0, pi]
        // = 2 * pi * (10 * pi) = 20 pi^2
        #expect(abs((face.surfaceArea ?? 0) - 20 * Double.pi * Double.pi) < 1e-6)
    }

    @Test func faceFromCone() throws {
        let face = try #require(
            Shape.faceFromCone(
                semiAngle: .pi / 6, radius: 5, uMin: 0, uMax: .pi, vMin: 0, vMax: 10))
        #expect(face.isValid)
        // (u2 - u1)(R v + v^2 sin(a) / 2) over v in [0, 10], where R is the `radius` argument
        // (5, the radius at v = 0) and a the semi-angle (pi / 6, sin a = 1/2)
        // = pi * (5 * 10 + 100 * 0.5 / 2) = pi * (50 + 25)
        #expect(abs((face.surfaceArea ?? 0) - 75 * Double.pi) < 1e-6)
    }

    @Test func faceFromSurfaceWire() throws {
        // Take the outer wire of a planar face and put it on the same plane again.
        let plane = try #require(Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)))
        let wire = try #require(Wire.rectangle(width: 10, height: 10))
        let planarFace = try #require(Shape.face(from: wire))
        let wireShape = try #require(planarFace.subShapes(ofType: .wire).first)
        let face = try #require(Shape.faceFromSurface(plane, wire: wireShape))
        #expect(face.isValid)
        #expect(face.shapeType == .face)
        #expect(face.edges().count == 4)
        #expect(abs((face.surfaceArea ?? 0) - 100) < 1e-6)
    }

    /// `faceCopy` answers nil for every face it is given (#3358).
    ///
    /// Measured on kernel.6 for a box face, a planar face and the three cylinder faces.
    /// `OCCTMakeFaceCopy` guards on `BRepBuilderAPI_MakeFace(face).IsDone()`, which that
    /// constructor never sets.
    @Test func faceCopy() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let face = try #require(box.subShapes(ofType: .face).first)
        #expect(abs((face.surfaceArea ?? 0) - 100) < 1e-6)
        let copy = Shape.faceCopy(face)
        withKnownIssue("faceCopy returns nil for every face (#3358)") {
            #expect(copy != nil)
            #expect(abs((copy?.surfaceArea ?? 0) - 100) < 1e-6)
            #expect(copy?.isValid == true)
        }
    }

    @Test func faceAddHole() throws {
        let outer = try #require(Wire.rectangle(width: 10, height: 10))
        let face = try #require(Shape.face(from: outer))
        #expect(abs((face.surfaceArea ?? 0) - 100) < 1e-6)

        // A 4 x 4 window inside the face: area 100 - 16, and the hole's four edges join the face.
        let holeWire = try #require(Wire.rectangle(width: 4, height: 4))
        let hole = try #require(Shape.fromWire(holeWire))
        let withHole = try #require(Shape.faceAddHole(face: face, wire: hole))
        #expect(withHole.isValid)
        #expect(withHole.faces().count == 1)
        #expect(withHole.edges().count == 8)
        #expect(abs((withHole.surfaceArea ?? 0) - 84) < 1e-6)

        // A wire that is not inside the face is declined (the old fixture, a wire of the box).
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let boxFace = try #require(box.subShapes(ofType: .face).first)
        let boxWire = box.subShapes(ofType: .wire)[1]
        #expect(Shape.faceAddHole(face: boxFace, wire: boxWire) == nil)
    }
}
