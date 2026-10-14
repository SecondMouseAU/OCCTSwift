import Testing

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
    func chamferBuilderMultiple() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let builder = try #require(ChamferBuilder(shape: box))
        var addedCount = 0
        for edge in box.edges().prefix(4) {
            if builder.addEdge(edge, distance: 1.0) {
                addedCount += 1
            }
        }
        // Every one of the four edges is accepted and is its own contour.
        #expect(addedCount == 4)
        #expect(builder.contourCount == 4)
        for contour in 1...4 {
            #expect(abs(builder.length(contour: contour) - 20.0) < 1e-9)
        }

        // Four 20 mm edges at d = 1 remove 4 * 0.5 * 20 = 40 from the 8000 cube; the corners
        // shared between edges give back 1.33, measured 7961.333... on the pinned kernel
        // (v4.0.0-kernel.6).
        let result = try #require(builder.build())
        #expect(result.isValid)
        #expect(abs((result.volume ?? -1) - 7961.333333333333) < 1e-6)
        #expect(result.faces().count == 10)
    }
}
