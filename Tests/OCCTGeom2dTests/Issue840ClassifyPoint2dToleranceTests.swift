import Testing
import simd

@testable import OCCTSwift

/// #840: three wrapped classifiers answer the same "is this UV point inside/on/outside the face
/// boundary" question with inconsistent default tolerances -- `Shape.classifyPoint2d(u:v:)`
/// (`IntTools_FClass2d`) defaulted to `1e-7`, while `Face.classify(u:v:)` and
/// `Shape.classifyPoint2D(faceIndex:u:v:)` (both `BRepClass_FaceClassifier`/`BRepClass_FClassifier`)
/// default to `1e-6`. A point between the two tolerances of the boundary classified differently
/// depending which of the three interchangeable-looking APIs was called. Fixed by aligning
/// `classifyPoint2d`'s default to `1e-6`.
@Suite("Issue #840: classifyPoint2d default tolerance alignment")
struct Issue840ClassifyPoint2dToleranceTests {

    private func rectFace() throws -> (shape: Shape, face: Face) {
        let plane = try #require(Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)))
        let shape = try #require(Shape.face(from: plane, uRange: 0...10, vRange: 0...10))
        let face = try #require(Face(shape))
        return (shape, face)
    }

    /// The exact scenario #840 reports: a UV point 5e-7 outside the u=0 boundary -- farther than
    /// the OLD `classifyPoint2d` default (`1e-7`, would classify `.outside`) but within the
    /// aligned default (`1e-6`) and within `Face.classify`/`classifyPoint2D`'s own long-standing
    /// `1e-6` default, both of which classify it `.onBoundary`.
    @Test("classifyPoint2d agrees with Face.classify and classifyPoint2D on a borderline point")
    func defaultsAgreeOnBorderlinePoint() throws {
        let (shape, face) = try rectFace()
        let u = -5e-7
        let v = 5.0

        let viaClassifyPoint2d = shape.classifyPoint2d(u: u, v: v)
        let viaFaceClassify = face.classify(u: u, v: v)
        let viaClassifyPoint2D = shape.classifyPoint2D(faceIndex: 0, u: u, v: v)

        #expect(
            viaClassifyPoint2d == .onBoundary,
            "classifyPoint2d's aligned 1e-6 default should treat a 5e-7-off point as on the boundary"
        )
        #expect(viaFaceClassify == .onBoundary)
        #expect(viaClassifyPoint2D == .on)

        // All three now agree, where before #840 classifyPoint2d alone disagreed.
        #expect(viaFaceClassify == .onBoundary && viaClassifyPoint2d == .onBoundary)
    }

    /// A point well inside the face is unaffected by the tolerance alignment.
    @Test("well-inside point is unaffected by the tolerance change")
    func wellInsideUnaffected() throws {
        let (shape, face) = try rectFace()
        #expect(shape.classifyPoint2d(u: 5, v: 5) == .inside)
        #expect(face.classify(u: 5, v: 5) == .inside)
    }

    /// A point well outside every tolerance under discussion is unaffected either.
    @Test("well-outside point is unaffected by the tolerance change")
    func wellOutsideUnaffected() throws {
        let (shape, face) = try rectFace()
        #expect(shape.classifyPoint2d(u: 15, v: 15) == .outside)
        #expect(face.classify(u: 15, v: 15) == .outside)
    }
}
