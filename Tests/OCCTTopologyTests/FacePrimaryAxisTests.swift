import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.137 Ch1: Surface axis extraction (#65)

@Suite("v0.137 Face.primaryAxis")
struct FacePrimaryAxisTests {
    @Test("Cylinder face has cylinder-kind primary axis along Z")
    func cylinderFacePrimaryAxis() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10) else {
            Issue.record("cylinder nil")
            return
        }
        var foundCyl = false
        for face in cyl.faces() where face.surfaceType == Face.SurfaceType.cylinder {
            if let axis = face.primaryAxis {
                #expect(axis.kind == ShapeAxis.Kind.cylinder)
                #expect(abs(axis.direction.z - 1.0) < 1e-6 || abs(axis.direction.z + 1.0) < 1e-6)
                foundCyl = true
            }
        }
        #expect(foundCyl)
    }

    @Test("Torus face exposes axis")
    func torusFacePrimaryAxis() {
        guard let torus = Shape.torus(majorRadius: 20, minorRadius: 5) else {
            Issue.record("torus nil")
            return
        }
        var found = false
        for face in torus.faces() where face.surfaceType == Face.SurfaceType.torus {
            if let axis = face.primaryAxis {
                #expect(axis.kind == ShapeAxis.Kind.torus)
                found = true
            }
        }
        #expect(found)
    }

    @Test("Plane face has no primary axis")
    func planeFaceNoAxis() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box nil")
            return
        }
        for face in box.faces() where face.surfaceType == Face.SurfaceType.plane {
            #expect(face.primaryAxis == nil)
        }
    }
}
