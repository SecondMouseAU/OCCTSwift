import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.147 #81: cuttingPlaneLine

@Suite("v0.147 DrawingAnnotation.cuttingPlaneLine")
struct CuttingPlaneLineTests {
    @Test("addCuttingPlaneLine stores a cutting-plane annotation")
    func addStoresAnnotation() {
        guard let box = Shape.box(width: 100, height: 50, depth: 30),
            let front = Drawing.frontView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        let ann = front.addCuttingPlaneLine(
            label: "A",
            cuttingPlaneOrigin: SIMD3(50, 25, 15),
            cuttingPlaneNormal: SIMD3(1, 0, 0),
            sectionViewDirection: SIMD3(1, 0, 0),
            viewDirection: SIMD3(0, 1, 0))
        #expect(ann != nil)
        if case .cuttingPlaneLine(let cpl)? = ann {
            #expect(cpl.label == "A")
        }
    }

    @Test("Cutting plane parallel to view plane returns nil")
    func parallelToViewReturnsNil() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let top = Drawing.topView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        let ann = top.addCuttingPlaneLine(
            label: "A",
            cuttingPlaneOrigin: .zero,
            cuttingPlaneNormal: SIMD3(0, 0, 1),  // parallel to top-view direction
            sectionViewDirection: SIMD3(0, 0, -1),
            viewDirection: SIMD3(0, 0, 1))
        #expect(ann == nil)
    }

    @Test("DXFWriter emits cutting plane line geometry")
    func dxfEmitsGeometry() {
        guard let box = Shape.box(width: 100, height: 50, depth: 30),
            let front = Drawing.frontView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        front.addCuttingPlaneLine(
            label: "A",
            cuttingPlaneOrigin: SIMD3(50, 25, 15),
            cuttingPlaneNormal: SIMD3(1, 0, 0),
            sectionViewDirection: SIMD3(1, 0, 0),
            viewDirection: SIMD3(0, 1, 0))
        let writer = DXFWriter()
        writer.collectFromDrawing(front)
        // Expect at least: 3 chain segments + 2 arrows (3 lines each) + 2 text labels
        let counts = writer.entityCounts
        #expect(counts.lines >= 9)  // 3 chain + 6 arrow
        #expect(counts.texts >= 2)
    }
}
