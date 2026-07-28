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
        // ...and merging through the copy does not move the geometry.
        if let v0 = volumeBefore, let mv = merged?.volume { #expect(abs(mv - v0) < 1e-9) }
    }

    /// The price of the copy, pinned so it is a decision rather than a surprise: the result shares
    /// no sub-shapes with the input, even where nothing was merged. Callers that mapped selections
    /// or attributes across by `isSame(as:)` have to key off geometry instead.
    @Test("The result no longer shares sub-shapes with the input")
    func resultDoesNotShareSubShapesWithInput() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),   // nothing to merge
              let merged = box.unified() else { Issue.record("setup"); return }
        #expect(merged.subShapeCount(ofType: .face) == box.subShapeCount(ofType: .face))
        #expect(merged.isSame(as: box) == false)
        var shared = 0
        for i in 0..<box.subShapeCount(ofType: .face) {
            guard let original = box.subShape(type: .face, index: i) else { continue }
            for j in 0..<merged.subShapeCount(ofType: .face) {
                guard let candidate = merged.subShape(type: .face, index: j) else { continue }
                if candidate.isSame(as: original) { shared += 1 }
            }
        }
        #expect(shared == 0)
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
    ///
    /// These are the caller-visible properties the reporter watched flip (a clean manifold turning
    /// self-intersecting on a *declined* merge). On a fixture this small they hold either way — it
    /// took a 735-face solid to move them — so the byte-identity tests above are what discriminates;
    /// this one pins the contract in the terms the issue was written in.
    @Test("A declined merge leaves the caller's shape usable")
    func declinedMergeLeavesInputIntact() {
        guard let body = stackedCylinders() else { Issue.record("setup"); return }
        let selfIntersectingBefore = body.isSelfIntersecting(hardTimeout: 5)
        let validBefore = body.isValid
        let volumeBefore = body.volume
        let builder = UnifySameDomainBuilder(shape: body, unifyEdges: true, unifyFaces: true)
        builder.build()
        _ = builder.shape          // result deliberately discarded
        #expect(body.isSelfIntersecting(hardTimeout: 5) == selfIntersectingBefore)
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
    /// nothing — and every case below would collapse to the 3-face plain merge.
    ///
    /// Which edge is kept decides the answer, so the assertion is per-edge rather than a count:
    /// keeping the junction circle (the seam the two cylindrical faces meet on, at z = 10) blocks
    /// the merge; keeping a cap circle (z = 0 or z = 20), which the merge never touches, does not.
    @Test("keepShape still blocks a merge through the copy")
    func keepShapeSurvivesTheCopy() {
        guard let body = stackedCylinders() else { Issue.record("setup"); return }

        func facesKeeping(_ edge: Shape) -> Int? {
            let builder = UnifySameDomainBuilder(shape: body, unifyEdges: true, unifyFaces: true)
            builder.keepShape(edge)
            builder.build()
            return builder.shape?.subShapeCount(ofType: .face)
        }

        var junctionTested = false, capTested = false
        for i in 0..<body.subShapeCount(ofType: .edge) {
            guard let edge = body.subShape(type: .edge, index: i),
                  let e = edge.edges(where: { $0.isCircle }).first,
                  let circle = e.circleProperties else { continue }
            if abs(circle.center.z - 10) < 1e-9 {
                #expect(facesKeeping(edge) == 4)   // junction seam kept -> the merge is blocked
                junctionTested = true
            } else {
                #expect(facesKeeping(edge) == 3)   // a cap circle is not what the merge needs
                capTested = true
            }
        }
        #expect(junctionTested && capTested)
    }
}
