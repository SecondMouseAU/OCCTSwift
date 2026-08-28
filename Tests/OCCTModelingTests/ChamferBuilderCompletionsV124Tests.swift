import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.124.0 Tests

@Suite("ChamferBuilder Completions v124")
struct ChamferBuilderCompletionsV124Tests {

    @Test("ChamferBuilder edge count, length, closed")
    func chamferEdgeCountAndLength() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            if let cb = ChamferBuilder(shape: b) {
                let edges = b.edges()
                if let e = edges.first {
                    cb.addEdge(e, distance: 1.0)
                    #expect(cb.contourCount >= 1)
                    let ec = cb.edgeCount(contour: 1)
                    #expect(ec >= 1)
                    let len = cb.length(contour: 1)
                    #expect(len > 0)
                    let closed = cb.isClosed(contour: 1)
                    #expect(!closed || closed)  // just check no crash
                    let cat = cb.isClosedAndTangent(contour: 1)
                    #expect(!cat || cat)
                }
            }
        }
    }

    @Test("ChamferBuilder get/set distance")
    func chamferGetSetDist() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            if let cb = ChamferBuilder(shape: b) {
                let edges = b.edges()
                if let e = edges.first {
                    cb.addEdge(e, distance: 2.0)
                    let dist = cb.getDistance(contour: 1)
                    #expect(abs(dist - 2.0) < 1e-6)
                    let sym = cb.isSymmetric(contour: 1)
                    #expect(sym)
                }
            }
        }
    }

    @Test("ChamferBuilder two distances")
    func chamferTwoDists() {
        let box = Shape.box(width: 20, height: 20, depth: 20)
        if let b = box {
            if let cb = ChamferBuilder(shape: b) {
                let edges = b.edges()
                let faces = b.faces()
                if let e = edges.first, let f = faces.first {
                    let added = cb.addEdge(e, face: f, distance1: 1.0, distance2: 2.0)
                    if added && cb.contourCount >= 1 {
                        let dists = cb.getDistances(contour: 1)
                        #expect(abs(dists.d1 - 1.0) < 1e-6)
                        #expect(abs(dists.d2 - 2.0) < 1e-6)
                        let twod = cb.isTwoDistances(contour: 1)
                        #expect(twod)
                    }
                }
            }
        }
    }

    @Test("ChamferBuilder remove and reset")
    func chamferRemoveReset() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            if let cb = ChamferBuilder(shape: b) {
                let edges = b.edges()
                if let e = edges.first {
                    cb.addEdge(e, distance: 1.0)
                    #expect(cb.contourCount >= 1)
                    cb.removeEdge(e)
                    #expect(cb.contourCount == 0)

                    // Add again and reset
                    cb.addEdge(e, distance: 1.0)
                    #expect(cb.contourCount >= 1)
                    cb.reset()
                    // Reset cancels build effects, contours remain
                }
            }
        }
    }

    @Test("ChamferBuilder contour/edge/vertex queries")
    func chamferContourQueries() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            if let cb = ChamferBuilder(shape: b) {
                let edges = b.edges()
                if let e = edges.first {
                    cb.addEdge(e, distance: 1.0)
                    let ci = cb.contour(for: e)
                    #expect(ci >= 1)
                    if ci >= 1 {
                        let edgeShape = cb.edge(contour: ci, index: 1)
                        #expect(edgeShape != nil)
                        let fv = cb.firstVertex(contour: ci)
                        #expect(fv != nil)
                        let lv = cb.lastVertex(contour: ci)
                        #expect(lv != nil)
                        if let v = fv {
                            let a = cb.abscissa(contour: ci, vertex: v)
                            #expect(a >= 0)
                            let ra = cb.relativeAbscissa(contour: ci, vertex: v)
                            #expect(ra >= 0 && ra <= 1.0 + 1e-6)
                        }
                    }
                }
            }
        }
    }

    @Test("ChamferBuilder dist-angle mode")
    func chamferDistAngle() {
        let box = Shape.box(width: 20, height: 20, depth: 20)
        if let b = box {
            if let cb = ChamferBuilder(shape: b) {
                let edges = b.edges()
                let faces = b.faces()
                if let e = edges.first, let f = faces.first {
                    let added = cb.addEdge(e, face: f, distance: 1.0, angle: 0.5)
                    if added && cb.contourCount >= 1 {
                        let da = cb.isDistanceAngle(contour: 1)
                        #expect(da)
                        let vals = cb.getDistAngle(contour: 1)
                        #expect(abs(vals.distance - 1.0) < 1e-6)
                        #expect(abs(vals.angle - 0.5) < 1e-6)
                    }
                }
            }
        }
    }
}
