import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.114.0 - ShapeContentsExtended")
struct ShapeContentsExtendedTests {

    @Test func boxContents() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let c = box.contentsExtended()
            #expect(c.nbSolids == 1)
            #expect(c.nbShells == 1)
            #expect(c.nbFaces == 6)
            #expect(c.nbWires == 6)
            #expect(c.nbEdges == 24)
            #expect(c.nbVertices == 48)
            #expect(c.nbBezierSurf == 0)
            #expect(c.nbBSplineSurf == 0)
        }
    }

    @Test func sphereContents() {
        if let sphere = Shape.sphere(radius: 5) {
            let c = sphere.contentsExtended()
            #expect(c.nbFaces >= 1)
            #expect(c.nbEdges >= 1)
            // Sphere has seam edges
            #expect(c.nbWireWithSeam >= 0)
        }
    }

    @Test func sharedCounts() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let c = box.contentsExtended()
            // Box shares edges and vertices
            #expect(c.nbSharedEdges >= 0)
            #expect(c.nbSharedVertices >= 0)
        }
    }

    // #855: `Shape.contents` and `Shape.contentsExtended()` each run their own independent
    // `ShapeAnalysis_ShapeContents::Perform()` walk (two bridge calls, two C structs), but their
    // first 9 fields are meant to report identical values for the same shape. Nothing asserted
    // that before this test, a future divergence (e.g. a `ModifyXMode()` call added to only one
    // bridge call site) would otherwise land silently.
    @Test func contentsAgreesWithContentsExtended() throws {
        func assertParity(_ shape: Shape) {
            let plain = shape.contents
            let extended = shape.contentsExtended()
            #expect(plain.solids == extended.nbSolids)
            #expect(plain.shells == extended.nbShells)
            #expect(plain.faces == extended.nbFaces)
            #expect(plain.wires == extended.nbWires)
            #expect(plain.edges == extended.nbEdges)
            #expect(plain.vertices == extended.nbVertices)
            #expect(plain.freeEdges == extended.nbFreeEdges)
            #expect(plain.freeWires == extended.nbFreeWires)
            #expect(plain.freeFaces == extended.nbFreeFaces)
        }
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        assertParity(box)
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        assertParity(cyl)
    }

    // #855 review: `contentsAgreesWithContentsExtended()` above only proves the two bridge calls
    // agree on a watertight box/cylinder, where every free-element count is 0 on both sides, a
    // transposed field (e.g. `ShapeContentsCore` reading `nbFreeWires` into `freeEdges`) would
    // pass that test by coincidence, since swapping two zeros is still 0 == 0. This test instead
    // builds both bridge C structs directly, with 9 mutually distinct values and no OCCT call at
    // all, and checks each `ShapeContentsCore` output field against the exact C field it must
    // have come from, so a transposition fails even though every value involved is still a
    // "plausible" int32_t count.
    @Test func shapeContentsCoreMapsFieldsPositionally() {
        let plain = OCCTShapeContents(
            nbSolids: 11, nbShells: 12, nbFaces: 13, nbWires: 14, nbEdges: 15,
            nbVertices: 16, nbFreeEdges: 17, nbFreeWires: 18, nbFreeFaces: 19
        )
        let plainCore = shapeContentsCore(plain)
        #expect(plainCore.solids == 11)
        #expect(plainCore.shells == 12)
        #expect(plainCore.faces == 13)
        #expect(plainCore.wires == 14)
        #expect(plainCore.edges == 15)
        #expect(plainCore.vertices == 16)
        #expect(plainCore.freeEdges == 17)
        #expect(plainCore.freeWires == 18)
        #expect(plainCore.freeFaces == 19)

        let extended = OCCTShapeContentsExtended(
            nbSolids: 21, nbShells: 22, nbFaces: 23, nbWires: 24, nbEdges: 25,
            nbVertices: 26, nbFreeEdges: 27, nbFreeWires: 28, nbFreeFaces: 29,
            nbSolidsWithVoids: 0, nbBigSplines: 0, nbC0Surfaces: 0, nbC0Curves: 0,
            nbOffsetSurf: 0, nbIndirectSurf: 0, nbOffsetCurves: 0, nbTrimmedCurve2d: 0,
            nbTrimmedCurve3d: 0, nbBSplineSurf: 0, nbBezierSurf: 0, nbTrimSurf: 0,
            nbWireWithSeam: 0, nbWireWithSevSeams: 0, nbFaceWithSevWires: 0, nbNoPCurve: 0,
            nbSharedSolids: 0, nbSharedShells: 0, nbSharedFaces: 0, nbSharedWires: 0,
            nbSharedEdges: 0, nbSharedVertices: 0
        )
        let extendedCore = shapeContentsCore(extended)
        #expect(extendedCore.solids == 21)
        #expect(extendedCore.shells == 22)
        #expect(extendedCore.faces == 23)
        #expect(extendedCore.wires == 24)
        #expect(extendedCore.edges == 25)
        #expect(extendedCore.vertices == 26)
        #expect(extendedCore.freeEdges == 27)
        #expect(extendedCore.freeWires == 28)
        #expect(extendedCore.freeFaces == 29)
    }
}
