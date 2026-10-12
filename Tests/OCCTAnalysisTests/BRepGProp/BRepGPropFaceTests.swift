import Foundation
import Testing

@testable import OCCTSwift

@Suite("BRepGProp Face Tests")
struct BRepGPropFaceTests {
    @Test("Natural bounds of box face")
    func naturalBounds() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let faces = box.faces()
        try #require(faces.count == 6)

        // A planar face's natural bounds span its own extent, so each face's (u span, v span)
        // is a pair of the box's side lengths. The u/v assignment per face is OCCT's, so pin the
        // spans per face by area and as a set: x caps 20x30, y caps 10x30, z caps 10x20.
        var spans: [[Double]] = []
        for (i, face) in faces.enumerated() {
            let b = try #require(face.naturalBounds, "face \(i) has natural bounds")
            let u = b.uMax - b.uMin
            let v = b.vMax - b.vMin
            #expect(u > 0 && v > 0)
            spans.append([u, v].sorted())
        }
        let sortedSpans = spans.sorted { ($0[0], $0[1]) < ($1[0], $1[1]) }
        let expected: [[Double]] = [
            [10, 20], [10, 20], [10, 30], [10, 30], [20, 30], [20, 30],
        ]
        for (got, want) in zip(sortedSpans, expected) {
            #expect(
                abs(got[0] - want[0]) < 1e-6 && abs(got[1] - want[1]) < 1e-6,
                "got \(got), want \(want)")
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
            let mag = vectorLength(eval.normal)
            #expect(mag > 0.01)
        }
    }

    @Test("Evaluate GProp normal on cylinder face")
    func evaluateCylinderFace() throws {
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        let faces = cyl.faces()
        try #require(faces.count == 3)

        // `Shape.cylinder` stands on z = 0. The GProp "normal" is dS/du x dS/dv, whose length is
        // the area element: r on the side wall (r du dv, with v the height), 1 on the caps.
        var sawSide = false
        var capZ: [Double] = []
        for face in faces {
            let b = try #require(face.naturalBounds)
            let eval = try #require(
                face.evaluateGProp(u: (b.uMin + b.uMax) / 2, v: (b.vMin + b.vMax) / 2))
            switch face.surfaceType {
            case .cylinder:
                sawSide = true
                #expect(abs(vectorLength(eval.normal) - 5.0) < 1e-9)
                #expect(abs(hypot(eval.point.x, eval.point.y) - 5.0) < 1e-9)
                #expect(abs(eval.point.z - 5.0) < 1e-9)
            case .plane:
                #expect(abs(vectorLength(eval.normal) - 1.0) < 1e-9)
                #expect(abs(eval.normal.z) > 0.999)
                capZ.append(eval.point.z)
            default:
                Issue.record("unexpected surface type \(face.surfaceType)")
            }
        }
        #expect(sawSide)
        #expect(capZ.sorted().count == 2)
        if capZ.count == 2 {
            let z = capZ.sorted()
            #expect(abs(z[0]) < 1e-9 && abs(z[1] - 10.0) < 1e-9, "caps at \(z)")
        }
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
            let mag1 = vectorLength(eval1.normal)
            let mag2 = vectorLength(eval2.normal)
            // For a planar face, magnitudes should be equal
            #expect(abs(mag1 - mag2) < 0.001)
        }
    }
}
