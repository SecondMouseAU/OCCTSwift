import Testing
import simd

@testable import OCCTSwift

@Suite("ChamferBuilder v121")
struct ChamferBuilderV121Tests {

    @Test("Create chamfer builder with symmetric distance")
    func chamferBuilderSymmetric() {
        let box = Shape.box(width: 20, height: 20, depth: 20)
        if let box = box {
            if let builder = ChamferBuilder(shape: box) {
                let edges = box.edges()
                if let edge = edges.first {
                    let added = builder.addEdge(edge, distance: 2.0)
                    #expect(added)
                    #expect(builder.contourCount == 1)

                    if let result = builder.build() {
                        #expect(result.isValid)
                    }
                }
            }
        }
    }

    @Test("Chamfer builder with two distances")
    func chamferBuilderTwoDists() {
        let box = Shape.box(width: 20, height: 20, depth: 20)
        if let box = box {
            if let builder = ChamferBuilder(shape: box) {
                let edges = box.edges()
                let faces = box.faces()
                // Find an edge and a face sharing that edge
                if let edge = edges.first, let face = faces.first {
                    let added = builder.addEdge(edge, face: face, distance1: 2.0, distance2: 3.0)
                    #expect(added)
                    if added {
                        #expect(builder.contourCount == 1)
                        if let result = builder.build() {
                            #expect(result.isValid)
                        }
                    }
                }
            }
        }
    }

    @Test("Chamfer builder with distance and angle")
    func chamferBuilderDistAngle() {
        let box = Shape.box(width: 20, height: 20, depth: 20)
        if let box = box {
            if let builder = ChamferBuilder(shape: box) {
                let edges = box.edges()
                let faces = box.faces()
                if let edge = edges.first, let face = faces.first {
                    let angle = Double.pi / 4.0  // 45 degrees
                    let added = builder.addEdge(edge, face: face, distance: 2.0, angle: angle)
                    #expect(added)
                    if added {
                        #expect(builder.contourCount == 1)
                        #expect(builder.isDistanceAngle(contour: 1))
                        if let result = builder.build() {
                            #expect(result.isValid)
                        }
                    }
                }
            }
        }
    }

    @Test("Chamfer builder multiple edges")
    func chamferBuilderMultiple() {
        let box = Shape.box(width: 20, height: 20, depth: 20)
        if let box = box {
            if let builder = ChamferBuilder(shape: box) {
                let edges = box.edges()
                var addedCount = 0
                for edge in edges.prefix(4) {
                    if builder.addEdge(edge, distance: 1.0) {
                        addedCount += 1
                    }
                }
                #expect(addedCount > 0)
                if let result = builder.build() {
                    #expect(result.isValid)
                }
            }
        }
    }
}
