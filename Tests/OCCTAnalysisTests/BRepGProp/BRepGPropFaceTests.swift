import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGProp Face Tests")
struct BRepGPropFaceTests {
    @Test("Natural bounds of box face")
    func naturalBounds() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let faces = box.faces()
        #expect(!faces.isEmpty)

        let face = faces[0]
        let bounds = face.naturalBounds
        #expect(bounds != nil)
        if let bounds {
            #expect(bounds.uMax > bounds.uMin)
            #expect(bounds.vMax > bounds.vMin)
        }
    }

    @Test("Evaluate GProp normal on box face")
    func evaluateBoxFace() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let faces = box.faces()
        let face = faces[0]

        guard let bounds = face.naturalBounds else {
            #expect(Bool(false), "bounds should exist")
            return
        }

        let uMid = (bounds.uMin + bounds.uMax) / 2
        let vMid = (bounds.vMin + bounds.vMax) / 2

        let eval = face.evaluateGProp(u: uMid, v: vMid)
        #expect(eval != nil)
        if let eval {
            // Normal should be non-zero for a box face
            let mag = simd_length(eval.normal)
            #expect(mag > 0.01)
        }
    }

    @Test("Evaluate GProp normal on cylinder face")
    func evaluateCylinderFace() throws {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let faces = cyl.faces()
        #expect(faces.count >= 1)

        // Find a face with non-zero normal
        var found = false
        for face in faces {
            guard let bounds = face.naturalBounds else { continue }
            let uMid = (bounds.uMin + bounds.uMax) / 2
            let vMid = (bounds.vMin + bounds.vMax) / 2

            if let eval = face.evaluateGProp(u: uMid, v: vMid) {
                let mag = simd_length(eval.normal)
                if mag > 0.01 {
                    found = true
                    break
                }
            }
        }
        #expect(found)
    }

    @Test("GProp normal magnitude is area element")
    func normalMagnitudeIsAreaElement() throws {
        // For a planar face, the normal magnitude should be constant
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let face = box.faces()[0]

        guard let bounds = face.naturalBounds else {
            #expect(Bool(false), "bounds should exist")
            return
        }

        let eval1 = face.evaluateGProp(u: bounds.uMin + 0.1, v: bounds.vMin + 0.1)
        let eval2 = face.evaluateGProp(u: bounds.uMax - 0.1, v: bounds.vMax - 0.1)

        #expect(eval1 != nil)
        #expect(eval2 != nil)

        if let eval1, let eval2 {
            let mag1 = simd_length(eval1.normal)
            let mag2 = simd_length(eval2.normal)
            // For a planar face, magnitudes should be equal
            #expect(abs(mag1 - mag2) < 0.001)
        }
    }
}
