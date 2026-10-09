import Testing
import simd

@testable import OCCTSwift

@Suite("v0.114.0 - Boolean Tolerance")
struct BooleanToleranceTests {

    // #766: every fixture here used to be built from `Shape.box(width:height:depth:)`, which is
    // CENTRED on the origin, and then offset as if it were corner-based. The second cube of
    // fuseWithTolerance (x = 9.999) and fuseWithGlue (x = 10) therefore sat clear of the first, the
    // two commons met at a single corner and the cut returned its first cube unchanged, so neither
    // the fuzzy value nor the glue mode ever reached the result, and each test passed for a bridge
    // that dropped the argument. Every fixture below is corner-based and chosen so that the option
    // CHANGES the answer, and every test runs the same operation with the option off (tolerance 0,
    // glue .off) and asserts that answer too: a bridge that ignored the argument gives the control
    // result for the with-option call and fails the with-option assertions.
    //
    // A boolean raises the tolerance of its arguments' own sub-shapes in place, so the control and
    // the with-option call are never given the same boxes: a control run on boxes an earlier fuzzy
    // run had touched measured 999.99999999999977 where fresh boxes measure 999.9.
    // Kernel values: Scripts/repro/766-modeling-boolean-tolerance/probe-evidence-fix.mm.
    private func box(
        _ origin: SIMD3<Double>, size: SIMD3<Double> = SIMD3(repeating: 10)
    ) throws -> Shape {
        try #require(
            Shape.box(origin: origin, width: size.x, height: size.y, depth: size.z),
            "fixture box at \(origin) failed")
    }

    @Test func fuseWithTolerance() throws {
        // Two 10 mm cubes with a 0.001 gap between coincident-plane faces (x 0..10 and
        // 10.001..20.001): a real gap to OCCT's own tolerance, closer than the fuzzy value.
        let origin1 = SIMD3<Double>(0, 0, 0)
        let origin2 = SIMD3<Double>(10.001, 0, 0)

        // Control: no fuzzy value, so the gap stands and the fuse is two disjoint solids.
        let strictBox1 = try box(origin1)
        let strictBox2 = try box(origin2)
        let strict = try #require(strictBox1.fused(with: strictBox2, tolerance: 0))
        #expect(strict.subShapes(ofType: .solid).count == 2)

        // Fuzzy 0.01 is larger than the gap: the two faces are one face and the fuse is one solid.
        let box1 = try box(origin1)
        let box2 = try box(origin2)
        let fused = try #require(box1.fused(with: box2, tolerance: 0.01))
        #expect(fused.isValid)
        #expect(fused.subShapes(ofType: .solid).count == 1)
        #expect(fused.subShapes(ofType: .face).count == 10)
        let volume = try #require(fused.volume)
        #expect(abs(volume - 2000.0666666666662) < 1e-6)
    }

    @Test func cutWithTolerance() throws {
        // A 10 mm cube and a slab whose lower face is 0.001 below the cube's top face (z = 9.999).
        let cubeOrigin = SIMD3<Double>(0, 0, 0)
        let slabOrigin = SIMD3<Double>(-1, -1, 9.999)
        let slabSize = SIMD3<Double>(12, 12, 2)

        // Control: the slab really overlaps the cube by 0.001, so the cut takes
        // 0.001 x 10 x 10 = 0.1 off the top.
        let strictCube = try box(cubeOrigin)
        let strictSlab = try box(slabOrigin, size: slabSize)
        let strict = try #require(strictCube.subtracted(strictSlab, tolerance: 0))
        let strictVolume = try #require(strict.volume)
        #expect(abs(strictVolume - 999.9) < 1e-6)

        // Fuzzy 0.01 makes the slab's face and the cube's top the same face: nothing comes off.
        let cube = try box(cubeOrigin)
        let slab = try box(slabOrigin, size: slabSize)
        let cut = try #require(cube.subtracted(slab, tolerance: 0.01))
        #expect(cut.isValid)
        let volume = try #require(cut.volume)
        #expect(abs(volume - 1000) < 1e-6)
    }

    @Test func commonWithTolerance() throws {
        // Two 10 mm cubes overlapping by a 0.001 sliver (x 9.999..10).
        let origin1 = SIMD3<Double>(0, 0, 0)
        let origin2 = SIMD3<Double>(9.999, 0, 0)

        // Control: the sliver is a real solid of 0.001 x 10 x 10 = 0.1.
        let strictBox1 = try box(origin1)
        let strictBox2 = try box(origin2)
        let strict = try #require(strictBox1.intersected(with: strictBox2, tolerance: 0))
        #expect(strict.subShapes(ofType: .solid).count == 1)
        let strictVolume = try #require(strict.volume)
        #expect(abs(strictVolume - 0.1) < 1e-9)

        // Fuzzy 0.01 is thicker than the sliver: the cubes count as touching, and the common of
        // touching cubes has no solid. The result is still a valid, empty shape, not nil.
        let box1 = try box(origin1)
        let box2 = try box(origin2)
        let common = try #require(box1.intersected(with: box2, tolerance: 0.01))
        #expect(common.isValid)
        #expect(common.subShapes(ofType: .solid).isEmpty)
    }

    // Glue: `BOPAlgo_GlueShift` / `GlueFull` tell the boolean that the arguments touch only on
    // coincident faces, so it skips the face/face intersection. On arguments that really do touch
    // that way every glue mode returns the identical shape (measured while writing these), which
    // leaves nothing to assert about the argument. What is observable is what glue does to
    // arguments that INTERPENETRATE, where the skipped intersection makes the result wrong: that
    // wrong answer differs from the glue-off one, and it is the only signature that the glue mode
    // reached the kernel. The three tests below therefore use overlapping cubes on purpose and
    // pin the glue result to the kernel's, next to the correct glue-off result.

    @Test func fuseWithGlue() throws {
        // Two 10 mm cubes overlapping in a 5 x 5 x 5 corner.
        let origin1 = SIMD3<Double>(0, 0, 0)
        let origin2 = SIMD3<Double>(5, 5, 5)

        // Control, glue off: the true union, one solid of 2000 - 125.
        let offBox1 = try box(origin1)
        let offBox2 = try box(origin2)
        let off = try #require(offBox1.fused(with: offBox2, glue: .off))
        #expect(off.subShapes(ofType: .solid).count == 1)
        let offVolume = try #require(off.volume)
        #expect(abs(offVolume - 1875) < 1e-6)

        // GlueShift takes the cubes as disjoint: the fuse keeps both, overlap counted twice.
        let box1 = try box(origin1)
        let box2 = try box(origin2)
        let fused = try #require(box1.fused(with: box2, glue: .shift))
        #expect(fused.isValid)
        #expect(fused.subShapes(ofType: .solid).count == 2)
        let volume = try #require(fused.volume)
        #expect(abs(volume - 2000) < 1e-6)
    }

    @Test func cutWithGlue() throws {
        // A 20 mm cube (x, y, z -10..10, what Shape.box(width: 20, ...) builds) and a 10 mm cube at
        // (5,5,5), overlapping in a 5 x 5 x 5 corner.
        let cubeOrigin = SIMD3<Double>(-10, -10, -10)
        let cubeSize = SIMD3<Double>(repeating: 20)
        let toolOrigin = SIMD3<Double>(5, 5, 5)

        // Control, glue off: the true cut, 8000 - 125.
        let offCube = try box(cubeOrigin, size: cubeSize)
        let offTool = try box(toolOrigin)
        let off = try #require(offCube.subtracted(offTool, glue: .off))
        #expect(off.subShapes(ofType: .face).count == 9)
        let offVolume = try #require(off.volume)
        #expect(abs(offVolume - 7875) < 1e-6)

        // GlueFull takes the two as disjoint: the tool removes nothing.
        let cube = try box(cubeOrigin, size: cubeSize)
        let tool = try box(toolOrigin)
        let cut = try #require(cube.subtracted(tool, glue: .full))
        #expect(cut.isValid)
        #expect(cut.subShapes(ofType: .face).count == 6)
        let volume = try #require(cut.volume)
        #expect(abs(volume - 8000) < 1e-6)
    }

    @Test func commonWithGlue() throws {
        // Two 10 mm cubes overlapping in a 5 x 5 x 5 corner.
        let origin1 = SIMD3<Double>(0, 0, 0)
        let origin2 = SIMD3<Double>(5, 5, 5)

        // Control, glue off: the overlap, one solid of 125.
        let offBox1 = try box(origin1)
        let offBox2 = try box(origin2)
        let off = try #require(offBox1.intersected(with: offBox2, glue: .off))
        #expect(off.subShapes(ofType: .solid).count == 1)
        let offVolume = try #require(off.volume)
        #expect(abs(offVolume - 125) < 1e-6)

        // GlueShift takes the cubes as disjoint: there is no common, a valid empty shape.
        let box1 = try box(origin1)
        let box2 = try box(origin2)
        let common = try #require(box1.intersected(with: box2, glue: .shift))
        #expect(common.isValid)
        #expect(common.subShapes(ofType: .solid).isEmpty)
    }
}
