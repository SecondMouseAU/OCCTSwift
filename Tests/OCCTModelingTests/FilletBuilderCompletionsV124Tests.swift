import Testing
import simd

@testable import OCCTSwift

// #766: every test in this suite used to nest its assertions inside `if let` of the box, the
// builder and the first edge, and then inside `if ci >= 1` or `if result != nil`, the very values
// under test. A contour lookup that returned 0, or a build that failed, skipped every assertion and
// passed. Several of the remaining assertions could not fail either (`status >= 0`, `ncs >= 0`,
// `nfc >= 0`, `nfv >= 0` on quantities that are never negative on success). The fixtures now fail
// loudly and each assertion is pinned to the kernel's own answer for the same input
// (Scripts/repro/766-modeling-fillet-builder-completions-v124): one contour holding one edge, running
// (-5,-5,-5) to (-5,-5,5) with abscissa 0 and 10, open, two surfaces after build, stripe status
// ChFiDS_Ok, one computed surface, no faulty contour or vertex.

/// A fresh builder on a 10 mm box with radius 1 on its first edge, or nil if any fixture step fails.
private func firstEdgeFillet() -> (builder: FilletBuilder, edge: Edge)? {
    guard let box = Shape.box(width: 10, height: 10, depth: 10),
        let fb = FilletBuilder(shape: box),
        let e = box.edges().first
    else { return nil }
    guard fb.addEdge(e, radius: 1.0) else { return nil }
    return (fb, e)
}

@Suite("FilletBuilder Completions v124")
struct FilletBuilderCompletionsV124Tests {

    @Test("FilletBuilder contour access")
    func filletContourAccess() {
        guard let fx = firstEdgeFillet() else {
            Issue.record("fixture failed")
            return
        }
        let (fb, e) = fx
        #expect(fb.contour(for: e) == 1)
        #expect(fb.contourCount == 1)
        #expect(fb.edgeCount(contour: 1) == 1)
    }

    @Test("FilletBuilder edge and vertex queries")
    func filletEdgeVertexQueries() {
        guard let fx = firstEdgeFillet() else {
            Issue.record("fixture failed")
            return
        }
        let (fb, e) = fx
        let ci = fb.contour(for: e)
        #expect(ci == 1)
        #expect(fb.edge(contour: ci, index: 1) != nil)
        guard let fv = fb.firstVertex(contour: ci), let lv = fb.lastVertex(contour: ci) else {
            Issue.record("contour has no end vertices")
            return
        }
        #expect(abs(fb.abscissa(contour: ci, vertex: fv)) < 1e-9)
        #expect(abs(fb.relativeAbscissa(contour: ci, vertex: fv)) < 1e-9)
        #expect(abs(fb.abscissa(contour: ci, vertex: lv) - 10.0) < 1e-9)
        #expect(abs(fb.relativeAbscissa(contour: ci, vertex: lv) - 1.0) < 1e-9)
    }

    @Test("FilletBuilder closed and tangent")
    func filletClosedAndTangent() {
        guard let fx = firstEdgeFillet() else {
            Issue.record("fixture failed")
            return
        }
        let (fb, e) = fx
        let ci = fb.contour(for: e)
        #expect(ci == 1)
        #expect(!fb.isClosed(contour: ci))  // single-edge fillet contour is not closed (one edge)
        #expect(!fb.isClosedAndTangent(contour: ci))  // nor closed-and-tangent
    }

    @Test("FilletBuilder surfaces after build")
    func filletSurfaces() {
        guard let fb = firstEdgeFillet()?.builder else {
            Issue.record("fixture failed")
            return
        }
        #expect(fb.build() != nil)
        #expect(fb.surfaceCount == 2)
    }

    @Test("FilletBuilder set radius on edge and vertex")
    func filletSetRadius() {
        guard let fx = firstEdgeFillet() else {
            Issue.record("fixture failed")
            return
        }
        let (fb, e) = fx
        let ci = fb.contour(for: e)
        #expect(ci == 1)
        #expect(fb.setRadius(2.0, contour: ci, edge: e))
        #expect(fb.setTwoRadii(1.0, 3.0, contour: ci, edgeInContour: 1))
        #expect(fb.build() != nil)
    }

    @Test("FilletBuilder stripe status and faulty queries")
    func filletStripeAndFaulty() {
        guard let fx = firstEdgeFillet() else {
            Issue.record("fixture failed")
            return
        }
        let (fb, e) = fx
        #expect(fb.build() != nil)
        let ci = fb.contour(for: e)
        #expect(ci == 1)
        #expect(fb.stripeStatus(contour: ci) == 0)  // ChFiDS_Ok
        #expect(fb.computedSurfaceCount(contour: ci) == 1)
        #expect(fb.faultyContourCount == 0)
        #expect(fb.faultyVertexCount == 0)
    }
}
