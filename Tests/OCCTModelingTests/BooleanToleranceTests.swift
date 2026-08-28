import Testing
import simd

@testable import OCCTSwift

@Suite("v0.114.0 - Boolean Tolerance")
struct BooleanToleranceTests {

    @Test func fuseWithTolerance() {
        if let box1 = Shape.box(width: 10, height: 10, depth: 10),
            let box2 = Shape.box(origin: SIMD3(9.999, 0, 0), width: 10, height: 10, depth: 10)
        {
            // With fuzzy tolerance, near-touching shapes can fuse
            let fused = box1.fused(with: box2, tolerance: 0.01)
            #expect(fused != nil)
            if let f = fused {
                #expect(f.isValid)
            }
        }
    }

    @Test func cutWithTolerance() {
        if let box1 = Shape.box(width: 10, height: 10, depth: 10),
            let box2 = Shape.box(origin: SIMD3(5, 5, 5), width: 10, height: 10, depth: 10)
        {
            let cut = box1.subtracted(box2, tolerance: 0.001)
            #expect(cut != nil)
            if let c = cut {
                #expect(c.isValid)
            }
        }
    }

    @Test func commonWithTolerance() {
        if let box1 = Shape.box(width: 10, height: 10, depth: 10),
            let box2 = Shape.box(origin: SIMD3(5, 5, 5), width: 10, height: 10, depth: 10)
        {
            let common = box1.intersected(with: box2, tolerance: 0.001)
            #expect(common != nil)
            if let c = common {
                #expect(c.isValid)
            }
        }
    }

    @Test func fuseWithGlue() {
        if let box1 = Shape.box(width: 10, height: 10, depth: 10),
            let box2 = Shape.box(origin: SIMD3(10, 0, 0), width: 10, height: 10, depth: 10)
        {
            let fused = box1.fused(with: box2, glue: .shift)
            #expect(fused != nil)
            if let f = fused {
                #expect(f.isValid)
            }
        }
    }

    @Test func cutWithGlue() {
        if let box1 = Shape.box(width: 20, height: 20, depth: 20),
            let box2 = Shape.box(origin: SIMD3(5, 5, 5), width: 10, height: 10, depth: 10)
        {
            let cut = box1.subtracted(box2, glue: .off)
            #expect(cut != nil)
        }
    }

    @Test func commonWithGlue() {
        if let box1 = Shape.box(width: 10, height: 10, depth: 10),
            let box2 = Shape.box(origin: SIMD3(5, 5, 5), width: 10, height: 10, depth: 10)
        {
            let common = box1.intersected(with: box2, glue: .off)
            #expect(common != nil)
        }
    }
}
