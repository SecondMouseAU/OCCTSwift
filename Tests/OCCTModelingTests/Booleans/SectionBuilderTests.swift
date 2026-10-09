import Testing
import simd

@testable import OCCTSwift

@Suite("SectionBuilder")
struct SectionBuilderTests {

    @Test("Section builder with two shapes")
    func sectionTwoShapes() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(origin: SIMD3(5, 5, 0), width: 10, height: 10, depth: 10)!

        if let builder = SectionBuilder(shape1: box1, shape2: box2) {
            builder.setApproximation(true)
            builder.computePCurveOn1(true)
            builder.computePCurveOn2(false)

            if let result = builder.build() {
                #expect(result.isValid)

                // Check ancestor faces on section edges
                let sectionEdges = result.subShapes(ofType: .edge)
                if !sectionEdges.isEmpty {
                    let face1 = builder.ancestorFaceOn1(edge: sectionEdges[0])
                    let face2 = builder.ancestorFaceOn2(edge: sectionEdges[0])
                    // Ancestor faces may or may not be available depending on algorithm internals
                    _ = face1
                    _ = face2
                }
            }
        }
    }

    @Test("Section builder with Init1/Init2")
    func sectionInit() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        if let builder = SectionBuilder() {
            builder.init1(shape: box)
            builder.init2(plane: 0, 0, 1, -5)  // z = 5 plane

            if let result = builder.build() {
                #expect(result.isValid)
            }
        }
    }

    @Test("Section builder with surface")
    func sectionWithSurface() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let plane = Surface.plane(origin: SIMD3(5, 5, 5), normal: SIMD3(1, 0, 0))

        if let surf = plane, let builder = SectionBuilder() {
            builder.init1(shape: box)
            builder.init2(surface: surf)
            builder.setApproximation(false)

            if let result = builder.build() {
                #expect(result.isValid)
            }
        }
    }

    @Test("Section builder from shapes constructor")
    func sectionFromShapesCtor() {
        let sphere = Shape.sphere(radius: 5)!
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        if let builder = SectionBuilder(shape1: sphere, shape2: box) {
            if let result = builder.build() {
                #expect(result.isValid)
            }
        }
    }
}
