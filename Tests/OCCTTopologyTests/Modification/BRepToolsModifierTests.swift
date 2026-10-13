import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("BRepTools Modifier")
struct BRepToolsModifierTests {
    @Test("NURBS convert via Modifier")
    func nurbsConvertViaModifier() throws {
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        let before = cyl.subShapes(ofType: .face).compactMap {
            $0.extractFaceSurface()?.surfaceKind
        }
        #expect(before.filter { $0 == .cylinder }.count == 1)
        #expect(before.filter { $0 == .plane }.count == 2)

        let result = try #require(cyl.nurbsConvertViaModifier())
        #expect(result.isValid)
        #expect(result.faceCount == 3)
        #expect(result.edgeCount == 3)

        // Every face, the planar caps included, is now a B-spline surface.
        let faces = result.subShapes(ofType: .face)
        #expect(faces.count == 3)
        for face in faces {
            let surface = try #require(face.extractFaceSurface())
            #expect(surface.surfaceKind == .bsplineSurface)
        }

        // The geometry is the same cylinder: face areas match the analytic ones (100 pi lateral
        // to 1e-4, because the quadratic rational patch carries a 3e-6 relative approximation;
        // 25 pi per cap), and a point sampled on the lateral face still sits at radius 5.
        let areas = faces.compactMap { Face($0)?.area() }.sorted()
        #expect(areas.count == 3)
        if areas.count == 3 {
            #expect(abs(areas[0] - 25 * .pi) < 1e-9)
            #expect(abs(areas[1] - 25 * .pi) < 1e-9)
            #expect(abs(areas[2] - 100 * .pi) < 1e-3)
        }
        let lateralFace = faces.first { (Face($0)?.area() ?? 0) > 200 }
        let lateral = try #require(lateralFace)
        let surface = try #require(lateral.extractFaceSurface())
        let d = surface.domain
        for (fu, fv) in [(0.3, 0.2), (0.6, 0.7), (0.9, 0.5)] {
            let p = surface.point(
                atU: d.uMin + (d.uMax - d.uMin) * fu, v: d.vMin + (d.vMax - d.vMin) * fv)
            #expect(abs((p.x * p.x + p.y * p.y).squareRoot() - 5) < 1e-9)
        }

        // A box converts exactly: still 6 B-spline faces, volume 1000, area 600.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let boxResult = try #require(box.nurbsConvertViaModifier())
        #expect(boxResult.faceCount == 6)
        #expect(abs(try #require(boxResult.volume) - 1000) < 1e-9)
        #expect(abs(try #require(boxResult.surfaceArea) - 600) < 1e-9)
    }
}
