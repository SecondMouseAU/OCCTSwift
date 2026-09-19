import Foundation
import Testing

@testable import OCCTSwift

/// #1638: `OCCTShapeFixComposeShell` built a 1 x 1 `ShapeExtend_CompositeSurface` and handed it to
/// `ShapeFix_ComposeShell`, which splits a face along the joints **between** patches. A one-patch
/// grid has no joints, so one face went in and one came out, whatever precision was passed, and
/// `Perform()` returned true every time.
///
/// The assertion that catches that is the output face count. `composeShellPlanar`, the only test
/// this call had, asserted `result.isValid`, which the unsplit result satisfies.
@Suite("Issue #1638: composeShell splits along a real patch grid")
struct Issue1638ComposeShellGridTests {

    private func planarFace() throws -> Shape {
        let rect = try #require(Wire.rectangle(width: 10, height: 10))
        return try #require(Shape.face(from: rect))
    }

    private func cylinderWall() throws -> Shape {
        let cylinder = try #require(Shape.cylinder(radius: 5, height: 10))
        let wall = cylinder.subShapes(ofType: .face).first {
            $0.extractFaceSurface()?.typeName == "Geom_CylindricalSurface"
        }
        return try #require(wall)
    }

    @Test("a planar face splits into exactly uPatches x vPatches faces")
    func planarFaceSplitsIntoTheRequestedGrid() throws {
        let face = try planarFace()
        #expect(face.subShapes(ofType: .face).count == 1)

        for (u, v) in [(2, 1), (1, 2), (3, 2), (4, 4)] {
            let composed = try #require(face.composeShell(uPatches: u, vPatches: v))
            #expect(
                composed.subShapes(ofType: .face).count == u * v,
                "\(u) x \(v) grid: \(u * v) patches means \(u * v) faces")
        }
    }

    @Test("the default 1 x 1 grid still splits nothing, which is the pre-#1638 behaviour")
    func defaultGridIsStillAWireRebuild() throws {
        let face = try planarFace()
        let composed = try #require(face.composeShell())
        #expect(composed.subShapes(ofType: .face).count == 1)
        #expect(composed.isValid)
    }

    @Test("the pieces tile the original face, they are not a smaller copy of it")
    func piecesTileTheOriginalArea() throws {
        let face = try planarFace()
        let whole = try #require(face.faces().first).area()
        #expect(abs(whole - 100.0) < 1e-9)

        let composed = try #require(face.composeShell(uPatches: 2, vPatches: 2))
        let areas = composed.faces().map { $0.area() }
        #expect(areas.count == 4)
        for area in areas {
            #expect(abs(area - 25.0) < 1e-6, "each patch is a quarter of the 10 x 10 face")
        }
        #expect(abs(areas.reduce(0, +) - whole) < 1e-6)
    }

    @Test("a cylinder's periodic lateral face splits on either axis")
    func cylinderWallSplits() throws {
        let wall = try cylinderWall()
        #expect(wall.subShapes(ofType: .face).count == 1)

        let alongU = try #require(wall.composeShell(uPatches: 4))
        #expect(alongU.subShapes(ofType: .face).count == 4, "quarter cylinders")

        let alongV = try #require(wall.composeShell(vPatches: 2))
        #expect(alongV.subShapes(ofType: .face).count == 2, "two rings")

        let totalArea = alongU.faces().map { $0.area() }.reduce(0, +)
        let wallArea = try #require(wall.faces().first).area()
        #expect(abs(totalArea - wallArea) / wallArea < 1e-6)
    }

    @Test("a patch count below one is refused")
    func patchCountsBelowOneAreRefused() throws {
        let face = try planarFace()
        #expect(face.composeShell(uPatches: 0) == nil)
        #expect(face.composeShell(vPatches: 0) == nil)
        #expect(face.composeShell(uPatches: -2, vPatches: 3) == nil)
    }

    @Test("anything that is not a face is still refused")
    func nonFaceInputIsRefused() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(box.composeShell(uPatches: 2) == nil)
    }
}
