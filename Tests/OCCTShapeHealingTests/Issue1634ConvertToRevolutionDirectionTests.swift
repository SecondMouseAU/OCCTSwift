import Foundation
import Testing

@testable import OCCTSwift

/// #1634: `ShapeCustom::ConvertToRevolution` converts elementary periodic surfaces **into**
/// surfaces of revolution. `Shape.revolutionToElementary()` claimed the opposite direction while
/// calling exactly the same static as the correctly named `withSurfacesAsRevolution()`, and no
/// test asserted the direction, so nothing could have caught it.
///
/// The assertion that catches it is a count of `Geom_SurfaceOfRevolution` faces before and after,
/// not "the call returned non-nil": both directions return a valid shape with three faces.
///
/// `Face.surfaceType` cannot be used here. It is `BRepAdaptor_Surface::GetType()`, which
/// canonicalises a surface of revolution built on a line back to `GeomAbs_Cylinder`, so a
/// converted cylinder still reports `.cylinder`. The Geom subclass is what changed, and
/// `Shape.extractFaceSurface()?.typeName` is what reports it.
@Suite("Issue #1634: ConvertToRevolution runs elementary -> revolution")
struct Issue1634ConvertToRevolutionDirectionTests {

    /// Number of faces whose underlying geometry really is a `Geom_SurfaceOfRevolution`.
    private func revolutionFaceCount(_ shape: Shape) -> Int {
        shape.subShapes(ofType: .face).filter {
            $0.extractFaceSurface()?.typeName == "Geom_SurfaceOfRevolution"
        }.count
    }

    @Test("a cylinder gains one surface of revolution, it does not lose one")
    func directionIsElementaryToRevolution() throws {
        let cylinder = try #require(Shape.cylinder(radius: 5, height: 10))
        #expect(cylinder.subShapes(ofType: .face).count == 3)
        #expect(revolutionFaceCount(cylinder) == 0, "a freshly built cylinder has none")

        let converted = try #require(cylinder.withSurfacesAsRevolution())
        #expect(converted.subShapes(ofType: .face).count == 3)
        #expect(
            revolutionFaceCount(converted) == 1,
            "the lateral face becomes a Geom_SurfaceOfRevolution; the two planar caps do not")
    }

    @Test("sweptToElementary is the inverse and puts the elementary form back")
    func sweptToElementaryReversesIt() throws {
        let cylinder = try #require(Shape.cylinder(radius: 5, height: 10))
        let converted = try #require(cylinder.withSurfacesAsRevolution())
        #expect(revolutionFaceCount(converted) == 1)

        let back = try #require(converted.sweptToElementary())
        #expect(
            revolutionFaceCount(back) == 0,
            "ShapeCustom::SweptToElementary is the direction revolutionToElementary's name claimed")
        #expect(back.subShapes(ofType: .face).count == 3)
    }

    @Test("the conversion preserves the solid, it does not just relabel a surface")
    func volumeIsPreserved() throws {
        let cylinder = try #require(Shape.cylinder(radius: 5, height: 10))
        let before = try #require(cylinder.volume)
        let converted = try #require(cylinder.withSurfacesAsRevolution())
        let after = try #require(converted.volume)
        #expect(abs(after - before) / before < 1e-6)
        #expect(converted.isValid)
    }
}
