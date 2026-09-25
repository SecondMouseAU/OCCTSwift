import Testing
import simd

@testable import OCCTSwift

// #766: every test here nested its assertions inside `if let` of the box and the builder, and
// read the build result only through `if let result = builder.build() { #expect(result.isValid) }`,
// so a build that failed skipped the validity check and passed; `filletBuilderReset` asserted
// nothing at all about the state after `reset()`. The fixtures are now required, the build is
// asserted, and each value is pinned to the kernel's answer for the same input
// (Scripts/repro/766-modeling-fillet-builder-v121): one contour of one 20 mm edge, radius 2,
// three contours for three edges, a contour that survives `Reset()`, none after `Remove`.

@Suite("FilletBuilder v121")
struct FilletBuilderV121Tests {

    @Test("Create fillet builder and add edges with constant radius")
    func filletBuilderConstantRadius() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let builder = try #require(FilletBuilder(shape: box))
        let edges = box.edges()
        #expect(edges.count == 12)
        let firstEdge = try #require(edges.first)
        #expect(builder.addEdge(firstEdge, radius: 2.0))
        #expect(builder.contourCount == 1)
        #expect(builder.isConstant(contour: 1))
        #expect(abs(builder.radius(contour: 1) - 2.0) < 1e-10)
        #expect(builder.build()?.isValid == true)
    }

    @Test("Fillet builder with evolving radius")
    func filletBuilderEvolvingRadius() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let builder = try #require(FilletBuilder(shape: box))
        let edge = try #require(box.edges().first)
        #expect(builder.addEdge(edge, radius1: 1.0, radius2: 3.0))
        #expect(builder.contourCount == 1)
        #expect(!builder.isConstant(contour: 1))
        #expect(builder.build()?.isValid == true)
    }

    @Test("Fillet builder multiple edges")
    func filletBuilderMultipleEdges() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let builder = try #require(FilletBuilder(shape: box))
        var addedCount = 0
        for edge in box.edges().prefix(3) where builder.addEdge(edge, radius: 1.5) {
            addedCount += 1
        }
        #expect(addedCount == 3)
        #expect(builder.contourCount == 3)  // three edges meeting at corners, no tangency: 3 contours
        #expect(builder.build()?.isValid == true)
    }

    @Test("Fillet builder query and diagnostic properties")
    func filletBuilderDiagnostics() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let builder = try #require(FilletBuilder(shape: box))
        let edge = try #require(box.edges().first)
        #expect(builder.addEdge(edge, radius: 2.0))
        #expect(builder.edgeCount(contour: 1) == 1)
        #expect(abs(builder.length(contour: 1) - 20.0) < 1e-9)
        #expect(builder.faultyContourCount == 0)
        #expect(builder.faultyVertexCount == 0)
    }

    @Test("Fillet builder reset")
    func filletBuilderReset() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let builder = try #require(FilletBuilder(shape: box))
        let edge = try #require(box.edges().first)
        #expect(builder.addEdge(edge, radius: 2.0))
        #expect(builder.contourCount == 1)
        // Reset clears build state, not the contours: the kernel still reports one contour and
        // builds a valid solid after it.
        builder.reset()
        #expect(builder.contourCount == 1)
        #expect(builder.build()?.isValid == true)
    }

    @Test("Fillet builder remove edge")
    func filletBuilderRemoveEdge() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let builder = try #require(FilletBuilder(shape: box))
        let edge = try #require(box.edges().first)
        #expect(builder.addEdge(edge, radius: 2.0))
        #expect(builder.contourCount == 1)
        #expect(builder.removeEdge(edge))
        #expect(builder.contourCount == 0)
    }
}
