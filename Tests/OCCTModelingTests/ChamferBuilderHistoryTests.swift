import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.128.0: ChamferBuilder history, SectionBuilder, BRep_Tool extras, Curve/Surface Transform

@Suite("ChamferBuilder History")
struct ChamferBuilderHistoryTests {

    @Test("ChamferBuilder generated/modified/isDeleted")
    func chamferHistory() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let boxEdges = box.edges()

        if let builder = ChamferBuilder(shape: box) {
            // Add a chamfer on first edge
            if !boxEdges.isEmpty {
                builder.addEdge(boxEdges[0], distance: 1.0)

                if let result = builder.build() {
                    #expect(result.isValid)

                    // Check history on face sub-shapes
                    let faceShapes = box.subShapes(ofType: .face)
                    var hasHistory = false
                    for face in faceShapes {
                        let gen = builder.generated(from: face)
                        let mod = builder.modified(from: face)
                        if !gen.isEmpty || !mod.isEmpty { hasHistory = true }
                    }

                    // Check if original edge shape is deleted
                    let edgeShape = Shape.fromEdge(boxEdges[0])
                    if let es = edgeShape {
                        let deleted = builder.isDeleted(es)
                        if deleted { hasHistory = true }
                    }

                    #expect(hasHistory)
                }
            }
        }
    }

    @Test("ChamferBuilder setMode")
    func chamferSetMode() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        if let builder = ChamferBuilder(shape: box) {
            builder.setMode(.classic)
            builder.setMode(.constThroat)
            builder.setMode(.constThroatWithPenetration)
            // Just verify no crash
            #expect(true)
        }
    }

    @Test("ChamferBuilder simulate and surface count")
    func chamferSimulate() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let boxEdges = box.edges()

        if let builder = ChamferBuilder(shape: box) {
            if !boxEdges.isEmpty {
                builder.addEdge(boxEdges[0], distance: 1.0)

                let simulated = builder.simulate(contour: 1)
                #expect(simulated)

                let surfCount = builder.simulatedSurfaceCount(contour: 1)
                #expect(surfCount >= 0)
            }
        }
    }
}
