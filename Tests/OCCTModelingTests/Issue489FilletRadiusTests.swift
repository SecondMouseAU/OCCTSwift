import Testing
import Foundation
@testable import OCCTSwift

/// #489: the three `BRepFilletAPI_MakeFillet` edge-list entry points share one skeleton, so they
/// share one radius precondition.
///
/// `Shape.blendedEdges(_:)` used to be the outlier: `filleted(edges:radius:)` and
/// `filleted(edges:startRadius:endRadius:)` reject a non-positive radius before OCCT is called,
/// while the per-edge variant checked only that the array was non-empty. Ground truth for the
/// pinned kernel (`Scripts/repro/489-fillet-radius-validation/`): `BRepFilletAPI_MakeFillet::Add`
/// neither throws nor produces a wrong shape for a radius of 0, a negative radius or NaN. It
/// fails `IsDone()`, so a bad radius that reached OCCT already surfaced as `nil`. The gap was the
/// pairing of a bad radius with an out-of-range edge index: the bounds check dropped that pair and
/// the batch built successfully, filleting fewer edges than the caller asked for.
@Suite("Fillet Edge-List Radius Validation (#489)")
struct Issue489FilletRadiusTests {

    // MARK: - Per-edge radii (Shape.blendedEdges)

    @Test("Blend rejects a zero radius")
    func blendZeroRadiusRejected() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        #expect(box.blendedEdges([(0, 0.0)]) == nil)
    }

    @Test("Blend rejects a negative radius")
    func blendNegativeRadiusRejected() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        #expect(box.blendedEdges([(0, -5.0)]) == nil)
    }

    @Test("Blend rejects a NaN radius")
    func blendNaNRadiusRejected() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        #expect(box.blendedEdges([(0, Double.nan)]) == nil)
    }

    @Test("One bad radius rejects the whole blend batch")
    func blendMixedRadiiRejected() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        #expect(box.blendedEdges([(0, 2.0), (1, 0.0)]) == nil)
        #expect(box.blendedEdges([(0, 2.0), (1, -3.0)]) == nil)
    }

    /// The one case where the missing guard was observable rather than merely redundant: the
    /// bounds check skipped the (out-of-range index, bad radius) pair, so the batch built from the
    /// remaining edge and reported success for a request that was never fully honoured.
    @Test("A bad radius on an out-of-range index still rejects the batch")
    func blendBadRadiusOnOutOfRangeIndexRejected() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        #expect(box.edges().count < 99_999)
        #expect(box.blendedEdges([(0, 2.0), (99_999, -5.0)]) == nil)
    }

    /// #489 left the bounds check itself alone, so an out-of-range index paired with a *valid*
    /// radius was still skipped and the batch still built from whatever edges resolved. #520
    /// settled that question the other way for all five entry points in this family: a partial
    /// fillet reported as a complete one is the defect, not the convenience. Pinned in
    /// `Issue520FilletContractTests`; kept here so the pair of #489 cases still reads as a pair.
    @Test("An out-of-range index rejects the batch whatever its radius")
    func blendOutOfRangeIndexRejected() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        #expect(box.blendedEdges([(0, 2.0), (99_999, 2.0)]) == nil)
    }

    // MARK: - Uniform radius (Shape.filleted(edges:radius:))

    /// The sibling guard the per-edge variant was missing. It existed in source on both sides of
    /// the FFI boundary but had no test, so nothing pinned it.
    @Test("Uniform fillet rejects a non-positive radius")
    func uniformNonPositiveRadiusRejected() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        let edges = Array(box.edges().prefix(2))
        #expect(edges.count == 2)
        #expect(box.filleted(edges: edges, radius: 0.0) == nil)
        #expect(box.filleted(edges: edges, radius: -2.0) == nil)
        #expect(box.filleted(edges: edges, radius: Double.nan) == nil)
    }

    // MARK: - Linear radius (Shape.filleted(edges:startRadius:endRadius:))

    @Test("Linear fillet rejects a non-positive radius at either end")
    func linearNonPositiveRadiusRejected() {
        let box = Shape.box(width: 30, height: 10, depth: 10)!
        guard let edge = box.edge(at: 0) else {
            Issue.record("Could not get edge 0")
            return
        }
        #expect(box.filleted(edges: [edge], startRadius: 0.0, endRadius: 3.0) == nil)
        #expect(box.filleted(edges: [edge], startRadius: 1.0, endRadius: 0.0) == nil)
        #expect(box.filleted(edges: [edge], startRadius: -1.0, endRadius: 3.0) == nil)
        #expect(box.filleted(edges: [edge], startRadius: 1.0, endRadius: -3.0) == nil)
    }

    // MARK: - History-retaining siblings (same loop, same precondition)

    @Test("History fillet rejects a non-positive radius")
    func historyUniformNonPositiveRadiusRejected() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        #expect(box.filletedWithFullHistory(radius: 0.0, edges: [0]) == nil)
        #expect(box.filletedWithFullHistory(radius: -2.0, edges: [0]) == nil)
        #expect(box.filletedWithFullHistory(radius: Double.nan, edges: [0]) == nil)
    }

    @Test("History variable fillet rejects a non-positive radius at either end")
    func historyLinearNonPositiveRadiusRejected() {
        let box = Shape.box(width: 30, height: 10, depth: 10)!
        #expect(box.filletedWithFullHistory(edge: 0, startRadius: 0.0, endRadius: 3.0) == nil)
        #expect(box.filletedWithFullHistory(edge: 0, startRadius: 1.0, endRadius: 0.0) == nil)
        #expect(box.filletedWithFullHistory(edge: 0, startRadius: -1.0, endRadius: 3.0) == nil)
    }

    /// The history entry point moved onto the shared edge loop, so a valid request must still build
    /// and still report the input edge in its history.
    @Test("History fillet still builds and still records the input edge")
    func historyFilletStillBuilds() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        let edges = box.subShapes(ofType: .edge)
        #expect(!edges.isEmpty)

        var built: (result: Shape, history: ShapeHistoryRef)?
        var builtIndex = -1
        for i in 0..<min(edges.count, 6) {
            if let r = box.filletedWithFullHistory(radius: 1.0, edges: [i]) {
                built = r
                builtIndex = i
                break
            }
        }
        guard let r = built, builtIndex >= 0 else {
            Issue.record("no edge accepted a uniform 1.0 fillet")
            return
        }
        #expect(r.result.isValid)
        if let volume = r.result.volume { #expect(volume < 8000.0) }

        let rec = r.history.record(of: edges[builtIndex])
        #expect(rec.modified.count + rec.generated.count > 0 || rec.isDeleted)
    }

    // MARK: - Geometry unchanged by the shared skeleton

    /// Both entry points now run the same loop over the same edge map, so a per-edge radius list
    /// where every radius is equal must produce exactly the shape the uniform entry point does.
    @Test("Uniform radii through the per-edge path match the uniform path")
    func perEdgeUniformRadiiMatchUniformPath() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        let edges = Array(box.edges().prefix(3))
        #expect(edges.count == 3)

        let uniform = box.filleted(edges: edges, radius: 2.0)
        let perEdge = box.blendedEdges(edges.map { (edgeIndex: $0.index, radius: 2.0) })

        #expect(uniform != nil)
        #expect(perEdge != nil)
        if let uniform, let perEdge,
           let uniformVolume = uniform.volume, let perEdgeVolume = perEdge.volume {
            #expect(abs(uniformVolume - perEdgeVolume) < 1e-6)
            #expect(uniformVolume < 8000.0)  // material actually removed
        }
    }

    /// Distinct radii still reach OCCT individually rather than collapsing onto one value.
    @Test("Distinct per-edge radii remove more material than the smallest one alone")
    func distinctPerEdgeRadiiHonoured() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        let edges = Array(box.edges().prefix(3))
        #expect(edges.count == 3)

        let allSmall = box.blendedEdges(edges.map { (edgeIndex: $0.index, radius: 1.0) })
        let mixed = box.blendedEdges([
            (edgeIndex: edges[0].index, radius: 1.0),
            (edgeIndex: edges[1].index, radius: 3.0),
            (edgeIndex: edges[2].index, radius: 2.0),
        ])

        #expect(allSmall != nil)
        #expect(mixed != nil)
        if let allSmall, let mixed,
           let smallVolume = allSmall.volume, let mixedVolume = mixed.volume {
            #expect(mixedVolume < smallVolume)
        }
    }
}
