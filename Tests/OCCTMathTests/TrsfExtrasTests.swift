import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("gp_Trsf_Extras")
struct TrsfExtrasTests {
    @Test func transformFromMatrix() {
        // Translation by (5, 10, 15)
        let box = Shape.box(width: 1, height: 1, depth: 1)
        if let b = box {
            let result = b.transformed(
                byMatrix: TransformMatrix3D([
                    1, 0, 0, 5,
                    0, 1, 0, 10,
                    0, 0, 1, 15,
                ])!)
            #expect(result != nil)
            if let r = result {
                let bb = r.boundingBox
                #expect(bb != nil)
                if let bb = bb {
                    // Should be translated
                    #expect(bb.min.x > 4.0)
                    #expect(bb.min.y > 9.0)
                    #expect(bb.min.z > 14.0)
                }
            }
        }
    }

    @Test func transformIsNegative() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            // A freshly created box has identity location
            #expect(b.isTransformNegative == false)
        }
    }

    @Test func mirrorTransformProducesResult() {
        // Use origin-based box (corner at 5,0,0) so mirror moves it clearly
        let box = Shape.box(origin: SIMD3(5, 0, 0), width: 10, height: 10, depth: 10)
        if let b = box {
            // Mirror through YZ plane: X -> -X
            let mirrored = b.transformed(
                byMatrix: TransformMatrix3D([
                    -1, 0, 0, 0,
                    0, 1, 0, 0,
                    0, 0, 1, 0,
                ])!)
            #expect(mirrored != nil)
            if let m = mirrored {
                let bb = m.boundingBox
                #expect(bb != nil)
                if let bb = bb {
                    // Original was [5,15], mirrored should be [-15,-5]
                    #expect(bb.max.x < -4.0)
                }
            }
        }
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
    }

    /// Exercises the deprecated `[Double]`-taking overload directly (an array literal here
    /// infers `[Double]`, not `TransformMatrix3D`), see
    /// `TransformExpansionTests.deprecatedArrayOverloadsStillWork` for the same coverage across
    /// all three methods.
    @Test func invalidMatrixSize() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            // Wrong size array should return nil
            let result = b.transformed(byMatrix: [1, 0, 0])
            #expect(result == nil)
        }
    }

    /// #835 regression: `transformed(byMatrix:)` uses an INTERLEAVED row-major layout
    /// (`[a11..a14, a21..a24, a31..a34]` = `[r00,r01,r02,tx, r10,r11,r12,ty, r20,r21,r22,tz]`),
    /// NOT the GROUPED layout `transformed(matrix:)` uses (rotation entries first, translation
    /// last). Locks in the documented convention against real bounding-box geometry, so a
    /// future edit that accidentally aligns this method's array shape with
    /// `transformed(matrix:)`'s GROUPED layout is caught here.
    @Test func transformFromMatrixInterleavedLayoutTranslatesAsDocumented() {
        if let box = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10) {
            // Identity rotation, translate by (5, 10, 15). INTERLEAVED: each row's own tx/ty/tz.
            let matrix = TransformMatrix3D([
                1, 0, 0, 5,
                0, 1, 0, 10,
                0, 0, 1, 15,
            ])!
            let result = box.transformed(byMatrix: matrix)
            #expect(result != nil)
            if let r = result, let bb = r.boundingBox {
                #expect(abs(bb.min.x - 5.0) < 1e-6)
                #expect(abs(bb.min.y - 10.0) < 1e-6)
                #expect(abs(bb.min.z - 15.0) < 1e-6)
                #expect(abs(bb.max.x - 15.0) < 1e-6)
                #expect(abs(bb.max.y - 20.0) < 1e-6)
                #expect(abs(bb.max.z - 25.0) < 1e-6)
            }
        }
    }
}

