import Testing
import Foundation
import simd
@testable import OCCTSwift

/// Issue #446: `ShapeUpgrade_UnifySameDomain` rewrites sub-shapes of the shape it is handed, and
/// those rewrites reach the `TShape`s the caller's `Shape` still shares — so the caller's solid came
/// back different even when the merge result was discarded (reported downstream as a clean manifold
/// turning self-intersecting on a declined merge). Every unify entry point now works on a private
/// copy: `Shape.unified()`, `Shape.simplified()` and `UnifySameDomainBuilder`.
///
/// The fixture is two stacked coaxial cylinders. Their two cylindrical faces are same-domain but
/// differently parameterised, which drives the algorithm's `TransformPCurves` path — the one that
/// writes temporary pcurves onto the *input's* edges against a scratch reference face and only ever
/// removes them again if that face is later replaced. Before the fix the input's serialized BREP
/// grew from 1676 to 1778 bytes across the call.
@Suite("Issue #446 — unify does not mutate its input")
struct Issue446UnifyInputMutationTests {

    /// Two coaxial cylinders fused end to end: 4 faces, of which two cylindrical ones merge.
    private func stackedCylinders() -> Shape? {
        guard let lower = Shape.cylinder(radius: 5, height: 10),
              let upper = Shape.cylinder(radius: 5, height: 10)?.translated(by: SIMD3(0, 0, 10)) else {
            return nil
        }
        return lower.union(upper)
    }

    /// The serialized shape, which carries tolerances, pcurves and surfaces — so any rewrite of the
    /// input's sub-shapes shows up as a byte difference.
    private func serialized(_ shape: Shape) -> Data? {
        try? Exporter.brepData(shape: shape, withTriangles: false)
    }

    @Test("Shape.unified() leaves its input byte-identical")
    func unifiedDoesNotMutateInput() {
        guard let body = stackedCylinders(), let before = serialized(body) else {
            Issue.record("setup"); return
        }
        let volumeBefore = body.volume
        let merged = body.unified()
        #expect(serialized(body) == before)
        // The merge still happens — the copy is not a no-op path.
        #expect(merged?.subShapeCount(ofType: .face) == 3)
        #expect(body.subShapeCount(ofType: .face) == 4)
        if let v0 = volumeBefore, let v1 = body.volume { #expect(abs(v1 - v0) < 1e-9) }
    }

    @Test("UnifySameDomainBuilder leaves its input byte-identical")
    func builderDoesNotMutateInput() {
        guard let body = stackedCylinders(), let before = serialized(body) else {
            Issue.record("setup"); return
        }
        let builder = UnifySameDomainBuilder(shape: body, unifyEdges: true, unifyFaces: true)
        builder.setAngularTolerance(10.0 * .pi / 180)
        builder.build()
        let merged = builder.shape
        #expect(serialized(body) == before)
        #expect(merged?.subShapeCount(ofType: .face) == 3)
    }

    /// The builder's result being discarded is the exact path #446 was reported on: the consumer
    /// declines the merge and keeps its own shape, which must be the shape it started with.
    @Test("A declined merge leaves the caller's shape usable")
    func declinedMergeLeavesInputIntact() {
        guard let body = stackedCylinders() else { Issue.record("setup"); return }
        let selfIntersectingBefore = body.isSelfIntersecting(hardTimeout: 20)
        let validBefore = body.isValid
        let volumeBefore = body.volume
        let builder = UnifySameDomainBuilder(shape: body, unifyEdges: true, unifyFaces: true)
        builder.build()
        _ = builder.shape          // result deliberately discarded
        #expect(body.isSelfIntersecting(hardTimeout: 20) == selfIntersectingBefore)
        #expect(body.isValid == validBefore)
        if let v0 = volumeBefore, let v1 = body.volume { #expect(abs(v1 - v0) < 1e-9) }
    }

    @Test("Shape.simplified() leaves its input byte-identical")
    func simplifiedDoesNotMutateInput() {
        guard let body = stackedCylinders(), let before = serialized(body) else {
            Issue.record("setup"); return
        }
        let simplified = body.simplified()
        #expect(serialized(body) == before)
        #expect(simplified != nil)
    }

    /// `keepShape` names a sub-shape of the CALLER's shape, so working on a copy means it has to be
    /// mapped onto its counterpart there. Without that mapping every `keepShape` would silently keep
    /// nothing: here, keeping the seam edge between the two cylinders blocks the merge (4 faces,
    /// 5 edges) where the plain merge collapses it (3 faces, 3 edges).
    @Test("keepShape still blocks a merge through the copy")
    func keepShapeSurvivesTheCopy() {
        guard let body = stackedCylinders() else { Issue.record("setup"); return }
        var blockedCount = 0
        for i in 0..<body.subShapeCount(ofType: .edge) {
            guard let edge = body.subShape(type: .edge, index: i) else { continue }
            let builder = UnifySameDomainBuilder(shape: body, unifyEdges: true, unifyFaces: true)
            builder.keepShape(edge)
            builder.build()
            if builder.shape?.subShapeCount(ofType: .face) == 4 { blockedCount += 1 }
        }
        #expect(blockedCount > 0)
    }
}
