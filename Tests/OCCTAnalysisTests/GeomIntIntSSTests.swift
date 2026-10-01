import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GeomInt IntSS")
struct GeomIntIntSSTests {
    /// Every cylinder face against every box face, on the faces' underlying (untrimmed) surfaces.
    ///
    /// The cylinder (r 10, z 0...20) has a lateral face and two caps; the box (30 x 30 x 1, centred)
    /// has six planar faces. `GeomInt_IntSS` reports ten lines in all: the lateral surface meets
    /// the box's z = -0.5 and z = +0.5 planes in two circles of radius 10, and each cap plane
    /// meets the four side planes x = ±15, y = ±15 in a straight line (eight). Parallel planes
    /// and the side planes against the lateral cylinder (all 15 away from an axis of radius 10)
    /// report nothing.
    ///
    /// This used to stop at the first pair with a curve and check only that `curve(1)` was not
    /// nil, so an intersector that reported no curves at all passed without asserting anything.
    @Test("Plane-cylinder intersection")
    func planeCylinderIntersection() throws {
        let cyl = try #require(Shape.cylinder(radius: 10, height: 20))
        let box = try #require(Shape.box(width: 30, height: 30, depth: 1))
        let cylFaces = cyl.subShapes(ofType: .face)
        let boxFaces = box.subShapes(ofType: .face)
        try #require(cylFaces.count == 3)
        try #require(boxFaces.count == 6)
        var lines = 0
        var circles = 0
        for cf in cylFaces {
            for bf in boxFaces {
                guard let result = Shape.surfaceSurfaceIntersection(face1: cf, face2: bf) else {
                    continue
                }
                for k in stride(from: 1, through: result.curveCount, by: 1) {
                    guard let curve = result.curve(k) else {
                        Issue.record("curve \(k) of \(result.curveCount) is missing")
                        continue
                    }
                    lines += 1
                    let props = curve.curveLocalProps(at: 0)
                    if abs(props.curvature - 0.1) < 1e-9 {
                        circles += 1
                        let r = (props.point.x * props.point.x + props.point.y * props.point.y)
                            .squareRoot()
                        #expect(abs(r - 10) < 1e-9, "a circle of radius 10, got \(r)")
                        #expect(abs(abs(props.point.z) - 0.5) < 1e-9, "on z = ±0.5")
                    }
                }
            }
        }
        #expect(lines == 10)
        #expect(circles == 2)
    }
}
