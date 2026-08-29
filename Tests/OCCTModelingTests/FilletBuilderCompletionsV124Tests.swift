import Testing
import simd

@testable import OCCTSwift

@Suite("FilletBuilder Completions v124")
struct FilletBuilderCompletionsV124Tests {

    @Test("FilletBuilder contour access")
    func filletContourAccess() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            if let fb = FilletBuilder(shape: b) {
                let edges = b.edges()
                if let e = edges.first {
                    fb.addEdge(e, radius: 1.0)
                    let ci = fb.contour(for: e)
                    #expect(ci >= 1)
                }
            }
        }
    }

    @Test("FilletBuilder edge and vertex queries")
    func filletEdgeVertexQueries() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            if let fb = FilletBuilder(shape: b) {
                let edges = b.edges()
                if let e = edges.first {
                    fb.addEdge(e, radius: 1.0)
                    let ci = fb.contour(for: e)
                    if ci >= 1 {
                        let edgeShape = fb.edge(contour: ci, index: 1)
                        #expect(edgeShape != nil)
                        let fv = fb.firstVertex(contour: ci)
                        #expect(fv != nil)
                        let lv = fb.lastVertex(contour: ci)
                        #expect(lv != nil)
                        if let v = fv {
                            let a = fb.abscissa(contour: ci, vertex: v)
                            #expect(a >= 0)
                            let ra = fb.relativeAbscissa(contour: ci, vertex: v)
                            #expect(ra >= 0 && ra <= 1.0 + 1e-6)
                        }
                    }
                }
            }
        }
    }

    @Test("FilletBuilder closed and tangent")
    func filletClosedAndTangent() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            if let fb = FilletBuilder(shape: b) {
                let edges = b.edges()
                if let e = edges.first {
                    fb.addEdge(e, radius: 1.0)
                    let ci = fb.contour(for: e)
                    if ci >= 1 {
                        let closed = fb.isClosed(contour: ci)
                        #expect(!closed)  // single-edge fillet contour is not closed (one edge)
                        let cat = fb.isClosedAndTangent(contour: ci)
                        #expect(!cat)  // single-edge contour is not closed-and-tangent
                    }
                }
            }
        }
    }

    @Test("FilletBuilder surfaces after build")
    func filletSurfaces() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            if let fb = FilletBuilder(shape: b) {
                let edges = b.edges()
                if let e = edges.first {
                    fb.addEdge(e, radius: 1.0)
                    let result = fb.build()
                    if result != nil {
                        let ns = fb.surfaceCount
                        #expect(ns >= 1)
                    }
                }
            }
        }
    }

    @Test("FilletBuilder set radius on edge and vertex")
    func filletSetRadius() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            if let fb = FilletBuilder(shape: b) {
                let edges = b.edges()
                if let e = edges.first {
                    fb.addEdge(e, radius: 1.0)
                    let ci = fb.contour(for: e)
                    if ci >= 1 {
                        let ok = fb.setRadius(2.0, contour: ci, edge: e)
                        #expect(ok)
                        let ok2 = fb.setTwoRadii(1.0, 3.0, contour: ci, edgeInContour: 1)
                        #expect(ok2)
                    }
                }
            }
        }
    }

    @Test("FilletBuilder stripe status and faulty queries")
    func filletStripeAndFaulty() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            if let fb = FilletBuilder(shape: b) {
                let edges = b.edges()
                if let e = edges.first {
                    fb.addEdge(e, radius: 1.0)
                    _ = fb.build()
                    let ci = fb.contour(for: e)
                    if ci >= 1 {
                        let status = fb.stripeStatus(contour: ci)
                        #expect(status >= 0)
                        let ncs = fb.computedSurfaceCount(contour: ci)
                        #expect(ncs >= 0)
                    }
                    let nfc = fb.faultyContourCount
                    #expect(nfc >= 0)
                    let nfv = fb.faultyVertexCount
                    #expect(nfv >= 0)
                }
            }
        }
    }
}
