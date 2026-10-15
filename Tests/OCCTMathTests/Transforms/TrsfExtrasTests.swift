import Foundation
import Testing

@testable import OCCTSwift

@Suite("gp_Trsf_Extras")
struct TrsfExtrasTests {
    /// Bounds of a shape against six expected extents, to 1e-6 (every face is widened by the
    /// 1e-7 vertex tolerance; probed on the pinned kernel).
    private func expectBounds(
        _ shape: Shape, min lo: SIMD3<Double>, max hi: SIMD3<Double>,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let bb = try #require(shape.boundingBox, sourceLocation: sourceLocation)
        for (got, want) in zip([bb.min.x, bb.min.y, bb.min.z], [lo.x, lo.y, lo.z]) {
            #expect(abs(got - want) < 1e-6, sourceLocation: sourceLocation)
        }
        for (got, want) in zip([bb.max.x, bb.max.y, bb.max.z], [hi.x, hi.y, hi.z]) {
            #expect(abs(got - want) < 1e-6, sourceLocation: sourceLocation)
        }
    }

    @Test func transformFromMatrix() throws {
        // Translation by (5, 10, 15) of the centred unit cube (-0.5..0.5 on each axis).
        let b = try #require(Shape.box(width: 1, height: 1, depth: 1))
        let matrix = try #require(
            TransformMatrix3D([
                1, 0, 0, 5,
                0, 1, 0, 10,
                0, 0, 1, 15,
            ]))
        let r = try #require(b.transformed(byMatrix: matrix))
        try expectBounds(r, min: SIMD3(4.5, 9.5, 14.5), max: SIMD3(5.5, 10.5, 15.5))
    }

    @Test func transformIsNegative() throws {
        let b = try #require(Shape.box(width: 10, height: 10, depth: 10))
        // A freshly created box has identity location
        #expect(b.isTransformNegative == false)
        // Control requiring the opposite answer: a location whose matrix is a mirror (x -> -x,
        // determinant -1) reports negative. Probed true on the pinned kernel.
        let mirrored = try #require(b.located(matrix: [-1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0]))
        #expect(mirrored.isTransformNegative == true)
        // And a proper rotation/translation location is not negative.
        let moved = try #require(b.located(matrix: [1, 0, 0, 5, 0, 1, 0, 0, 0, 0, 1, 0]))
        #expect(moved.isTransformNegative == false)
    }

    @Test func mirrorTransformProducesResult() throws {
        // Use origin-based box (corner at 5,0,0) so mirror moves it clearly
        let b = try #require(Shape.box(origin: SIMD3(5, 0, 0), width: 10, height: 10, depth: 10))
        // Mirror through YZ plane: X -> -X
        let matrix = try #require(
            TransformMatrix3D([
                -1, 0, 0, 0,
                0, 1, 0, 0,
                0, 0, 1, 0,
            ]))
        let m = try #require(b.transformed(byMatrix: matrix))
        // Original was x in [5, 15], mirrored is [-15, -5]; y and z are unchanged at [0, 10].
        try expectBounds(m, min: SIMD3(-15, 0, 0), max: SIMD3(-5, 10, 10))
    }

    @Test func displacement() {
        let m = TransformUtils.displacement(
            from: (point: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1)),
            to: (point: SIMD3(10, 0, 0), direction: SIMD3(0, 0, 1)))
        #expect(m.values.count == 12)
        // Translation of 10 in X should appear in a14
        #expect(abs(m.values[3] - 10.0) < 1e-10)
    }

    @Test func transformation() {
        let m = TransformUtils.transformation(
            from: (point: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1)),
            to: (point: SIMD3(5, 5, 5), direction: SIMD3(0, 0, 1)))
        #expect(m.values.count == 12)
        // Probed on the pinned kernel: gp_Trsf::SetTransformation maps coordinates from the
        // global frame into the target frame, so a target at (5, 5, 5) gives translation
        // -5 on each axis (the opposite sign to `displacement`), identity rotation.
        let expected: [Double] = [1, 0, 0, -5, 0, 1, 0, -5, 0, 0, 1, -5]
        for (got, want) in zip(m.values, expected) {
            #expect(abs(got - want) < 1e-10)
        }
    }

    /// Exercises the deprecated `[Double]`-taking overload directly (an array literal here
    /// infers `[Double]`, not `TransformMatrix3D`), see
    /// `TransformExpansionTests.deprecatedArrayOverloadsStillWork` for the same coverage across
    /// all three methods.
    // Pins the deprecated overloads' behaviour, so it must keep calling them; the test is itself
    // deprecated so the call sites sit in a deprecated context and raise no diagnostic (#3470).
    @available(*, deprecated)
    @Test func invalidMatrixSize() throws {
        let b = try #require(Shape.box(width: 10, height: 10, depth: 10))
        // Wrong size arrays return nil, short and long.
        #expect(b.transformed(byMatrix: [1, 0, 0]) == nil)
        #expect(b.transformed(byMatrix: [Double](repeating: 0, count: 13)) == nil)
        // Control: a correctly sized identity array is accepted, so the nil above is the size
        // check and not a blanket refusal.
        let identity: [Double] = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0]
        let ok = try #require(b.transformed(byMatrix: identity))
        try expectBounds(ok, min: SIMD3(-5, -5, -5), max: SIMD3(5, 5, 5))
    }

    /// #835 regression: `transformed(byMatrix:)` uses an INTERLEAVED row-major layout
    /// (`[a11..a14, a21..a24, a31..a34]` = `[r00,r01,r02,tx, r10,r11,r12,ty, r20,r21,r22,tz]`),
    /// NOT the GROUPED layout `transformed(matrix:)` uses (rotation entries first, translation
    /// last). Locks in the documented convention against real bounding-box geometry, so a
    /// future edit that accidentally aligns this method's array shape with
    /// `transformed(matrix:)`'s GROUPED layout is caught here.
    @Test func transformFromMatrixInterleavedLayoutTranslatesAsDocumented() throws {
        let box = try #require(Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10))
        // Identity rotation, translate by (5, 10, 15). INTERLEAVED: each row's own tx/ty/tz.
        let matrix = try #require(
            TransformMatrix3D([
                1, 0, 0, 5,
                0, 1, 0, 10,
                0, 0, 1, 15,
            ]))
        let r = try #require(box.transformed(byMatrix: matrix))
        try expectBounds(r, min: SIMD3(5, 10, 15), max: SIMD3(15, 20, 25))
    }
}
