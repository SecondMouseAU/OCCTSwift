import Foundation
import Testing
import simd

@testable import OCCTSwift

// Counts are ShapeUpgrade_ShapeConvertToBezier's on the same primitives with every mode on
// (Scripts/repro/766-curve-batch-bezier/transcript.txt). The earlier versions asserted only
// `faceCount > 0` / `edgeCount > 0`, or the box's unchanged 6 and 12, so a bridge returning the
// input unconverted passed all four (#766). GeomAbs_BezierSurface = 5, GeomAbs_BezierCurve = 5.
@Suite("Bezier Conversion Tests")
struct BezierConversionTests {

    private static func faceTypes(_ s: Shape) -> [Int32] {
        s.subShapes(ofType: .face).map { $0.faceAdaptorSurfaceType }
    }

    @Test("Cylinder converts to Bezier")
    func cylinderToBezier() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10), let bezier = cyl.convertedToBezier
        else {
            Issue.record("cylinder did not convert")
            return
        }
        // The two caps become Bezier patches; the lateral face stays a cylinder. Its circles are
        // split into Bezier segments: 3 edges become 17.
        #expect(bezier.subShapeCount(ofType: .face) == 3)
        #expect(bezier.subShapeCount(ofType: .edge) == 17)
        #expect(Self.faceTypes(bezier).filter { $0 == 5 }.count == 2)
    }

    @Test("Sphere converts to Bezier")
    func sphereToBezier() {
        guard let sphere = Shape.sphere(radius: 10), let bezier = sphere.convertedToBezier else {
            Issue.record("sphere did not convert")
            return
        }
        // One face, still spherical; its 3 edges become 6.
        #expect(bezier.subShapeCount(ofType: .face) == 1)
        #expect(bezier.subShapeCount(ofType: .edge) == 6)
    }

    @Test("Box converts to Bezier")
    func boxToBezier() {
        guard let box = Shape.box(width: 10, height: 20, depth: 30),
            let bezier = box.convertedToBezier
        else {
            Issue.record("box did not convert")
            return
        }
        #expect(bezier.subShapeCount(ofType: .face) == 6)
        #expect(bezier.subShapeCount(ofType: .edge) == 12)
        // Every planar face is now a Bezier patch, every straight edge a Bezier curve.
        #expect(Self.faceTypes(bezier) == Array(repeating: 5, count: 6))
        #expect(bezier.subShapes(ofType: .edge).allSatisfy { $0.edgeAdaptorCurveType == 5 })
    }

    @Test("Cone converts to Bezier")
    func coneToBezier() {
        guard let cone = Shape.cone(bottomRadius: 10, topRadius: 5, height: 15),
            let bezier = cone.convertedToBezier
        else {
            Issue.record("cone did not convert")
            return
        }
        // As the cylinder: two Bezier caps, the conical face kept, 3 edges become 17.
        #expect(bezier.subShapeCount(ofType: .face) == 3)
        #expect(bezier.subShapeCount(ofType: .edge) == 17)
        #expect(Self.faceTypes(bezier).filter { $0 == 5 }.count == 2)
    }
}
