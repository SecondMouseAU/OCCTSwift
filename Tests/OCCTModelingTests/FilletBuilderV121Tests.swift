import Testing
import simd

@testable import OCCTSwift

@Suite("FilletBuilder v121")
struct FilletBuilderV121Tests {

    @Test("Create fillet builder and add edges with constant radius")
    func filletBuilderConstantRadius() {
        let box = Shape.box(width: 20, height: 20, depth: 20)
        #expect(box != nil)
        if let box = box {
            if let builder = FilletBuilder(shape: box) {
                let edges = box.edges()
                #expect(edges.count > 0)
                if let firstEdge = edges.first {
                    let added = builder.addEdge(firstEdge, radius: 2.0)
                    #expect(added)
                    #expect(builder.contourCount == 1)
                    #expect(builder.isConstant(contour: 1))
                    #expect(abs(builder.radius(contour: 1) - 2.0) < 1e-10)

                    if let result = builder.build() {
                        #expect(result.isValid)
                    }
                }
            }
        }
    }

    @Test("Fillet builder with evolving radius")
    func filletBuilderEvolvingRadius() {
        let box = Shape.box(width: 20, height: 20, depth: 20)
        if let box = box {
            if let builder = FilletBuilder(shape: box) {
                let edges = box.edges()
                if let edge = edges.first {
                    let added = builder.addEdge(edge, radius1: 1.0, radius2: 3.0)
                    #expect(added)
                    #expect(builder.contourCount == 1)
                    #expect(!builder.isConstant(contour: 1))

                    if let result = builder.build() {
                        #expect(result.isValid)
                    }
                }
            }
        }
    }

    @Test("Fillet builder multiple edges")
    func filletBuilderMultipleEdges() {
        let box = Shape.box(width: 20, height: 20, depth: 20)
        if let box = box {
            if let builder = FilletBuilder(shape: box) {
                let edges = box.edges()
                var addedCount = 0
                for edge in edges.prefix(3) {
                    if builder.addEdge(edge, radius: 1.5) {
                        addedCount += 1
                    }
                }
                #expect(addedCount > 0)
                #expect(builder.contourCount > 0)

                if let result = builder.build() {
                    #expect(result.isValid)
                }
            }
        }
    }

    @Test("Fillet builder query and diagnostic properties")
    func filletBuilderDiagnostics() {
        let box = Shape.box(width: 20, height: 20, depth: 20)
        if let box = box {
            if let builder = FilletBuilder(shape: box) {
                let edges = box.edges()
                if let edge = edges.first {
                    builder.addEdge(edge, radius: 2.0)
                    #expect(builder.edgeCount(contour: 1) >= 1)
                    #expect(builder.length(contour: 1) > 0)
                    #expect(builder.faultyContourCount == 0)
                    #expect(builder.faultyVertexCount == 0)
                }
            }
        }
    }

    @Test("Fillet builder reset")
    func filletBuilderReset() {
        let box = Shape.box(width: 20, height: 20, depth: 20)
        if let box = box {
            if let builder = FilletBuilder(shape: box) {
                let edges = box.edges()
                if let edge = edges.first {
                    builder.addEdge(edge, radius: 2.0)
                    #expect(builder.contourCount == 1)
                    // Reset clears build state but contours remain, verify no crash
                    builder.reset()
                    // Can still build after reset
                    if let result = builder.build() {
                        #expect(result.isValid)
                    }
                }
            }
        }
    }

    @Test("Fillet builder remove edge")
    func filletBuilderRemoveEdge() {
        let box = Shape.box(width: 20, height: 20, depth: 20)
        if let box = box {
            if let builder = FilletBuilder(shape: box) {
                let edges = box.edges()
                if let edge = edges.first {
                    builder.addEdge(edge, radius: 2.0)
                    #expect(builder.contourCount == 1)
                    let removed = builder.removeEdge(edge)
                    #expect(removed)
                    #expect(builder.contourCount == 0)
                }
            }
        }
    }
}
