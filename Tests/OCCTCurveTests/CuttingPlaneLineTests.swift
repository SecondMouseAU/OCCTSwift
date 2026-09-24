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
        guard case .cuttingPlaneLine(let cpl)? = ann else {
            Issue.record("no cutting-plane annotation returned")
            return
        }
        #expect(cpl.label == "A")
        // The trace spans the default 60 units, and the section arrow is a unit vector
        // perpendicular to it (the plane normal (1,0,0) is the view's in-plane X, the trace its
        // other axis). Swift-side geometry: no kernel counterpart (#766).
        let trace = cpl.traceEnd - cpl.traceStart
        #expect(abs(simd_length(trace) - 60) < 1e-9)
        #expect(abs(simd_length(cpl.arrowDirection) - 1) < 1e-12)
        #expect(abs(simd_dot(simd_normalize(trace), cpl.arrowDirection)) < 1e-12)
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

    // #1581: simd_normalize(.zero) produces a NaN vector, and under IEEE-754
    // NaN compares false against both `< 1e-9` and `> 1e-9`. That let a
    // zero-length cuttingPlaneNormal/viewDirection slip past the degenerate
    // guard (`simd_length(traceDir3D) < 1e-9`, itself NaN and so never true)
    // and fall through to the later `> 1e-9`-gated fallback-axis checks
    // (also never true for NaN), silently returning a non-nil annotation
    // built from arbitrary hardcoded axes instead of the documented nil.
    @Test("Zero-length cuttingPlaneNormal returns nil")
    func zeroCuttingPlaneNormalReturnsNil() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let front = Drawing.frontView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        let ann = front.addCuttingPlaneLine(
            label: "A",
            cuttingPlaneOrigin: .zero,
            cuttingPlaneNormal: .zero,
            sectionViewDirection: SIMD3(1, 0, 0),
            viewDirection: SIMD3(0, 1, 0))
        #expect(ann == nil)
    }

    @Test("Zero-length viewDirection returns nil")
    func zeroViewDirectionReturnsNil() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let front = Drawing.frontView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        let ann = front.addCuttingPlaneLine(
            label: "A",
            cuttingPlaneOrigin: .zero,
            cuttingPlaneNormal: SIMD3(1, 0, 0),
            sectionViewDirection: SIMD3(1, 0, 0),
            viewDirection: .zero)
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
        // The view's own edges are lines too, so `>= 9` was already met without the cutting-plane
        // line (#766). Count what the annotation adds: 3 chain segments + 2 arrows of 3 lines each,
        // and 2 labels.
        let before = DXFWriter()
        before.collectFromDrawing(front)
        front.addCuttingPlaneLine(
            label: "A",
            cuttingPlaneOrigin: SIMD3(50, 25, 15),
            cuttingPlaneNormal: SIMD3(1, 0, 0),
            sectionViewDirection: SIMD3(1, 0, 0),
            viewDirection: SIMD3(0, 1, 0))
        let writer = DXFWriter()
        writer.collectFromDrawing(front)
        let counts = writer.entityCounts
        #expect(counts.lines - before.entityCounts.lines == 9)  // 3 chain + 6 arrow
        #expect(counts.texts - before.entityCounts.texts == 2)
    }
}
