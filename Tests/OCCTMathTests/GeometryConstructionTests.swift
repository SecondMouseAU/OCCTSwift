import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Geometry Construction Tests (v0.11.0)

@Suite("Geometry Construction Tests")
struct GeometryConstructionTests {

    @Test("Create face from rectangular wire")
    func faceFromRectangle() {
        let rect = Wire.rectangle(width: 10, height: 5)!
        let face = Shape.face(from: rect)

        #expect(face != nil)
        #expect(face!.isValid)

        // Face should have surface area equal to rectangle area
        let area = face!.surfaceArea ?? 0
        #expect(abs(area - 50.0) < 0.01)  // 10 x 5 = 50
    }

    @Test("Create face from circular wire")
    func faceFromCircle() {
        let circle = Wire.circle(radius: 5)!
        let face = Shape.face(from: circle)

        #expect(face != nil)
        #expect(face!.isValid)

        // Face should have surface area equal to π * r²
        let area = face!.surfaceArea ?? 0
        let expectedArea = Double.pi * 5.0 * 5.0
        #expect(abs(area - expectedArea) < 0.1)
    }

    @Test("Create face with hole")
    func faceWithHole() {
        let outer = Wire.rectangle(width: 20, height: 20)!
        let hole = Wire.circle(radius: 5)!

        let face = Shape.face(outer: outer, holes: [hole])

        #expect(face != nil)
        #expect(face!.isValid)

        // Area should be outer minus hole
        let area = face!.surfaceArea ?? 0
        let expectedArea = 400.0 - (Double.pi * 25.0)  // 20x20 - π*5²
        #expect(abs(area - expectedArea) < 0.5)
    }

    @Test("Create face with multiple holes")
    func faceWithMultipleHoles() {
        let outer = Wire.rectangle(width: 30, height: 30)!
        // Use offset3D to position the holes
        let hole1 = Wire.circle(radius: 3)!.offset3D(distance: 8, direction: SIMD3(-1, 0, 0))!
        let hole2 = Wire.circle(radius: 3)!.offset3D(distance: 8, direction: SIMD3(1, 0, 0))!

        let face = Shape.face(outer: outer, holes: [hole1, hole2])

        #expect(face != nil)
        #expect(face!.isValid)

        // Area should be outer minus both holes
        let area = face!.surfaceArea ?? 0
        let expectedArea = 900.0 - 2 * (Double.pi * 9.0)  // 30x30 - 2*π*3²
        #expect(abs(area - expectedArea) < 0.5)
    }

    @Test("Extrude face to create solid")
    func extrudeFace() {
        let rect = Wire.rectangle(width: 10, height: 5)!
        let face = Shape.face(from: rect)!

        // Extrude the face to create a solid
        let solid = Shape.extrude(profile: rect, direction: SIMD3(0, 0, 1), length: 3)!

        #expect(solid.isValid)

        // Volume should be area * height
        let volume = solid.volume ?? 0
        #expect(abs(volume - 150.0) < 0.1)  // 10 * 5 * 3
    }
}

