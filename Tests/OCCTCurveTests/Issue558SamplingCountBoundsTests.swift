import Testing
import Foundation
import simd
@testable import OCCTSwift

// #558: the sampling entry points #479 did not reach. A caller-supplied count sizes a Swift
// allocation and is then cast to the `int32_t` the bridge takes its count in, so both ends abort
// the process rather than failing: `[Double](repeating:count:)` traps on a negative and
// `Int32(_:)` traps past `Int32.max`.
//
// Measured before the fix, one case per process (a trap takes the whole harness down, so each
// absurd input needs its own run) against `refactor/381-pass1b`. 28 public entry points, not the
// 14 the issue's own census named: `Edge.quasiUniformParameters`, `Curve3D.samplePoints`,
// `Surface.drawGrid`, four more on `Shape`, `Wire.orderedEdgePoints`, both `MedialAxis` drawers
// and `QuadricIntersection.coneSpherePoints` have the same shape and were missed. Every one of
// the 28 trapped (or ground on an unservable allocation past 30 s) at `Int32.max + 1`, and 20 of
// them trapped on a negative.
//
// These tests can run in-process precisely because the fix is what makes them able to: before it,
// every #expect below would have aborted the test harness rather than failing.
//
// Two measurement notes that changed the fix:
//
//  - The issue recorded `Surface.drawMesh` as returning `.empty` for a negative count. It does,
//    but only when the negative goes to *both* factors: `(-1) * (-1)` is a plausible positive
//    total. `drawMesh(uCount: -1, vCount: 3)` aborted the process. Hence each factor is checked
//    on its own, not just the product.
//  - `MedialAxis.drawArc`'s parameter is named `maxPoints` but the bridge does `numPoints =
//    maxPoints` and fills the buffer exactly, so it is a *request*, not a capacity. Clamping it
//    would have handed back a coarser sampling than asked for; it rejects instead.
// The emptiness assertions below compare `.count == 0` rather than reading `.isEmpty`. Swift
// Testing prints the captured sub-expression on failure, and the sub-expression here is a sampling
// call: a regression that returns 10 million points would print all 10 million of them. Measured
// while injecting a deliberate bug to check these tests catch it, the run wrote over 5 GB before
// it was killed. Comparing the count keeps a future failure to one integer. (#479 hit the same
// hazard at 880 MB.)
@Suite("Issue #558: every sampling entry point bounds the count a caller can supply", .serialized)
struct Issue558SamplingCountBounds {

    // `Int32.max + 1`, the first count provably past the bridge's own count type. Not the
    // interesting threshold, anything above ~1e8 is unallocatable, just the cheapest to prove.
    private static let pastInt32 = Int(Int32.max) + 1
    private static let pastCeiling = Sampling.maximumSampleCount + 1

    private func box() -> Shape { Shape.box(width: 10, height: 10, depth: 10)! }
    private func segment3D() -> Curve3D { Curve3D.segment(from: .zero, to: SIMD3(10, 0, 0))! }
    private func segment2D() -> Curve2D { Curve2D.segment(from: .zero, to: SIMD2(10, 0))! }
    private func plane() -> Surface {
        Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))!.trimmed(u1: 0, u2: 10, v1: 0, v2: 10)!
    }

    // MARK: - The shared ceiling

    @Test("the ceiling is declared once and the #479 spelling still resolves to it")
    func ceilingIsShared() {
        #expect(Sampling.maximumSampleCount == 10_000_000)
        #expect(EdgeCurve.maximumSampleCount == Sampling.maximumSampleCount)
        #expect(WireCurve.maximumSampleCount == Sampling.maximumSampleCount)
    }

    @Test("a request is honoured exactly or not at all")
    func requestedContract() {
        #expect(Sampling.requested(2) == 2)
        #expect(Sampling.requested(Sampling.maximumSampleCount) == Sampling.maximumSampleCount)
        #expect(Sampling.requested(1) == nil)                       // below the default minimum
        #expect(Sampling.requested(1, atLeast: 1) == 1)             // ... unless the site allows it
        #expect(Sampling.requested(0) == nil)
        #expect(Sampling.requested(-1) == nil)
        #expect(Sampling.requested(Self.pastCeiling) == nil)        // no clamping: rejected
        #expect(Sampling.requested(Self.pastInt32) == nil)
        #expect(Sampling.requested(Int.max) == nil)
    }

    @Test("a capacity is clamped into 0...ceiling rather than rejected")
    func capacityContract() {
        #expect(Sampling.capacity(4096) == 4096)
        #expect(Sampling.capacity(Sampling.maximumSampleCount) == Sampling.maximumSampleCount)
        #expect(Sampling.capacity(Self.pastCeiling) == Sampling.maximumSampleCount)
        #expect(Sampling.capacity(Self.pastInt32) == Sampling.maximumSampleCount)
        #expect(Sampling.capacity(Int.max) == Sampling.maximumSampleCount)
        #expect(Sampling.capacity(0) == 0)
        #expect(Sampling.capacity(-1) == 0)                         // no capacity, not a small one
        #expect(Sampling.capacity(Int.min) == 0)
    }

    @Test("a grid bounds the product and each factor, and cannot overflow into one")
    func gridTotalContract() {
        #expect(Sampling.gridTotal(20, 20) == 400)
        #expect(Sampling.gridTotal(1000, 10_000) == 10_000_000)     // exactly the ceiling
        #expect(Sampling.gridTotal(1000, 10_001) == nil)            // one past it
        // The measured hole: two negatives multiply to a plausible positive total.
        #expect(Sampling.gridTotal(-1, -1) == nil)
        #expect(Sampling.gridTotal(-1, 3) == nil)
        #expect(Sampling.gridTotal(3, -1) == nil)
        // Overflow is reported, not trapped on.
        #expect(Sampling.gridTotal(Int.max, Int.max) == nil)
        #expect(Sampling.gridTotal(Self.pastInt32, Self.pastInt32) == nil)
        // `atLeast: 0` admits an empty grid without admitting a negative one.
        #expect(Sampling.gridTotal(0, 50, atLeast: 0) == 0)
        #expect(Sampling.gridTotal(-1, 50, atLeast: 0) == nil)
    }

    // MARK: - Requests: empty/nil outside 2...ceiling, exact inside it

    @Test("Curve3D request samplers reject a count they cannot serve")
    func curve3DRequests() {
        let c = segment3D()
        #expect(c.drawUniform(pointCount: 11).count == 11)
        #expect(c.quasiUniformParameters(count: 8).count == 8)
        for n in [-1, 0, 1, Self.pastCeiling, Self.pastInt32, Int.max] {
            #expect(c.drawUniform(pointCount: n).count == 0, "drawUniform(\(n))")
            #expect(c.quasiUniformParameters(count: n).count == 0, "quasiUniformParameters(\(n))")
        }
    }

    @Test("Curve2D.drawUniform rejects a count it cannot serve")
    func curve2DRequests() {
        let c = segment2D()
        #expect(c.drawUniform(pointCount: 11).count == 11)
        for n in [-1, 0, 1, Self.pastCeiling, Self.pastInt32, Int.max] {
            #expect(c.drawUniform(pointCount: n).count == 0, "drawUniform(\(n))")
        }
    }

    @Test("Edge request samplers reject a count they cannot serve")
    func edgeRequests() {
        guard let e = box().edges().first else { #expect(Bool(false)); return }
        #expect(e.points(count: 7).count == 7)
        #expect(e.quasiUniformParameters(count: 9).count == 9)
        for n in [-1, 0, 1, Self.pastCeiling, Self.pastInt32, Int.max] {
            #expect(e.points(count: n).count == 0, "points(\(n))")
            #expect(e.quasiUniformParameters(count: n).count == 0, "quasiUniformParameters(\(n))")
        }
        // The automatic default still produces its ~0.5mm-spaced samples.
        #expect(e.points().count > 2)
    }

    @Test("Shape.uniformAbscissa rejects a count it cannot serve, both overloads")
    func uniformAbscissaRequests() {
        guard let edge = box().subShapes(ofType: .edge).first else { #expect(Bool(false)); return }
        #expect(edge.uniformAbscissa(pointCount: 5)?.count == 5)
        for n in [-1, 0, 1, Self.pastCeiling, Self.pastInt32, Int.max] {
            #expect(edge.uniformAbscissa(pointCount: n) == nil, "uniformAbscissa(\(n))")
            #expect(edge.uniformAbscissa(pointCount: n, u1: 0, u2: 1) == nil,
                    "uniformAbscissa(\(n), u1:u2:)")
        }
    }

    @Test("Shape iso-curve evaluators reject a count they cannot serve")
    func isoCurveRequests() {
        guard let face = box().subShapes(ofType: .face).first else { #expect(Bool(false)); return }
        #expect(face.uIsoCurvePoints(u: 0.5, count: 12).count == 12)
        #expect(face.vIsoCurvePoints(v: 0.5, count: 12).count == 12)
        for n in [-1, 0, Self.pastCeiling, Self.pastInt32, Int.max] {
            #expect(face.uIsoCurvePoints(u: 0.5, count: n).count == 0, "uIsoCurvePoints(\(n))")
            #expect(face.vIsoCurvePoints(v: 0.5, count: n).count == 0, "vIsoCurvePoints(\(n))")
        }
    }

    @Test("BRepGraph.sampleEdgeCurve rejects a count it cannot serve")
    func graphEdgeSampleRequest() {
        guard let graph = BRepGraph(shape: box()) else { #expect(Bool(false)); return }
        #expect(graph.sampleEdgeCurve(edgeIndex: 0, count: 6).count == 6)
        for n in [-1, 0, Self.pastCeiling, Self.pastInt32, Int.max] {
            #expect(graph.sampleEdgeCurve(edgeIndex: 0, count: n).count == 0, "sampleEdgeCurve(\(n))")
        }
    }

    @Test("Shape.allEdgePolylines keeps its own lower bound and gains the ceiling")
    func allEdgePolylinesRequest() {
        let b = box()
        #expect(!b.allEdgePolylines(maxPointsPerEdge: 10).isEmpty)
        for n in [-1, 0, 1, Self.pastCeiling, Self.pastInt32, Int.max] {
            #expect(b.allEdgePolylines(maxPointsPerEdge: n).count == 0, "allEdgePolylines(\(n))")
        }
    }

    @Test("MedialAxis fills its buffer exactly, so its maxPoints is a request, not a capacity")
    func medialAxisRequests() {
        guard let wire = Wire.rectangle(width: 10, height: 10),
              let face = Shape.face(from: wire),
              let ma = MedialAxis(of: face)
        else { #expect(Bool(false)); return }
        // Exactly the requested count, which is what makes clamping the wrong answer here.
        #expect(ma.drawArc(at: 1, maxPoints: 32).count == 32)
        #expect(ma.drawArc(at: 1, maxPoints: 64).count == 64)
        for n in [-1, 0, 1, Self.pastCeiling, Self.pastInt32, Int.max] {
            #expect(ma.drawArc(at: 1, maxPoints: n).count == 0, "drawArc(\(n))")
            #expect(ma.drawAll(maxPointsPerArc: n).count == 0, "drawAll(\(n))")
        }
    }

    @Test("QuadricIntersection.coneSpherePoints rejects a count it cannot serve")
    func coneSphereRequest() {
        for n in [-1, 0, Self.pastCeiling, Self.pastInt32, Int.max] {
            let pts = QuadricIntersection.coneSpherePoints(
                semiAngle: 0.5, refRadius: 5, sphereCenter: SIMD3(0, 0, 5), sphereRadius: 3,
                curveIndex: 0, sampleCount: n)
            #expect(pts.count == 0, "coneSpherePoints(\(n))")
        }
    }

    // MARK: - Capacities: clamped, so an absurd capacity still returns the real answer

    @Test("an adaptive sampler's capacity is clamped, not rejected: the answer is unchanged")
    func adaptiveCapacitiesAreClamped() {
        let c3 = segment3D(), c2 = segment2D()
        // A straight segment is two points however much room it is offered. The point of clamping
        // rather than rejecting: the caller gets the correct sampling, not an empty array.
        let baseline3D = c3.drawAdaptive(maxPoints: 4096).count
        #expect(baseline3D == c3.drawAdaptive(maxPoints: Self.pastInt32).count)
        #expect(baseline3D == c3.drawDeflection(maxPoints: Self.pastInt32).count)
        #expect(c3.samplePoints(first: 0, last: 10, maxPoints: 1000).count
                == c3.samplePoints(first: 0, last: 10, maxPoints: Self.pastInt32).count)
        #expect(!c3.quasiUniformDeflectionPoints(deflection: 0.1, maxPoints: Self.pastInt32).isEmpty)

        let baseline2D = c2.drawAdaptive(maxPoints: 4096).count
        #expect(baseline2D == c2.drawAdaptive(maxPoints: Self.pastInt32).count)
        #expect(baseline2D == c2.drawDeflection(maxPoints: Self.pastInt32).count)
    }

    @Test("a capacity of zero or less yields the entry point's own empty value")
    func nonPositiveCapacitiesAreEmpty() {
        let c3 = segment3D(), c2 = segment2D(), b = box()
        for n in [-1, 0, Int.min] {
            #expect(c3.drawAdaptive(maxPoints: n).count == 0, "3D drawAdaptive(\(n))")
            #expect(c3.drawDeflection(maxPoints: n).count == 0, "3D drawDeflection(\(n))")
            #expect(c3.samplePoints(first: 0, last: 10, maxPoints: n).count == 0, "samplePoints(\(n))")
            #expect(c3.quasiUniformDeflectionPoints(deflection: 0.1, maxPoints: n).count == 0,
                    "quasiUniformDeflectionPoints(\(n))")
            #expect(c2.drawAdaptive(maxPoints: n).count == 0, "2D drawAdaptive(\(n))")
            #expect(c2.drawDeflection(maxPoints: n).count == 0, "2D drawDeflection(\(n))")
            #expect(b.edgePolyline(at: 0, maxPoints: n) == nil, "edgePolyline(\(n))")
            #expect(b.edgePoints(at: 0, maxPoints: n).count == 0, "edgePoints(\(n))")
            #expect(b.contourPoints(maxPoints: n).count == 0, "contourPoints(\(n))")
        }
    }

    @Test("Shape's own capacity samplers clamp and still answer")
    func shapeCapacitiesAreClamped() {
        let b = box()
        #expect(b.edgePolyline(at: 0, maxPoints: Self.pastInt32) != nil)
        // Both of these are bounded by the shape, not by the capacity: the bridge caps edgePoints
        // at 20 internally, and contourPoints emits one point per edge.
        #expect(b.edgePoints(at: 0, maxPoints: Self.pastInt32).count
                == b.edgePoints(at: 0, maxPoints: 20).count)
        #expect(b.contourPoints(maxPoints: Self.pastInt32).count
                == b.contourPoints(maxPoints: 1000).count)
    }

    @Test("Wire.orderedEdgePoints keeps nil for zero and gains it for the ceiling")
    func orderedEdgePointsCapacity() {
        guard let w = Wire.rectangle(width: 10, height: 10) else { #expect(Bool(false)); return }
        #expect(w.orderedEdgePoints(at: 0, maxPoints: 5) != nil)
        #expect(w.orderedEdgePoints(at: 0) != nil)              // the derived, no-capacity path
        for n in [-1, 0, Self.pastCeiling, Self.pastInt32, Int.max] {
            #expect(w.orderedEdgePoints(at: 0, maxPoints: n) == nil, "orderedEdgePoints(\(n))")
        }
    }

    // MARK: - Grids: the bound is on the product, and on each factor

    @Test("Surface.drawMesh bounds the product, and each factor on its own")
    func drawMeshGrid() {
        let s = plane()
        #expect(!s.drawMesh(uCount: 20, vCount: 20).isEmpty)
        // Exactly the ceiling is refused only past it, not at it, but 1e7 points is 45 s of
        // sampling, so the boundary itself is checked on `Sampling.gridTotal` above, not here.
        #expect(s.drawMesh(uCount: 5000, vCount: 2001).uCount == 0)     // 10,005,000: past the ceiling
        // The measured hole: two negatives used to multiply to a plausible positive total, so
        // this pair looked well-behaved while the mixed-sign pairs below aborted the process.
        #expect(s.drawMesh(uCount: -1, vCount: -1).uCount == 0)
        #expect(s.drawMesh(uCount: -1, vCount: 3).uCount == 0)
        #expect(s.drawMesh(uCount: 3, vCount: -1).uCount == 0)
        #expect(s.drawMesh(uCount: 0, vCount: 3).uCount == 0)
        #expect(s.drawMesh(uCount: Self.pastInt32, vCount: 3).uCount == 0)
        #expect(s.drawMesh(uCount: Int.max, vCount: Int.max).uCount == 0)
    }

    @Test("Surface.drawGrid bounds the total, and each line count on its own")
    func drawGridTotal() {
        let s = plane()
        #expect(!s.drawGrid(uLineCount: 4, vLineCount: 4, pointsPerLine: 10).isEmpty)
        #expect(s.drawGrid(uLineCount: 4, vLineCount: 4, pointsPerLine: 2_000_000).count == 0)
        #expect(s.drawGrid(uLineCount: -1, vLineCount: -1, pointsPerLine: 10).count == 0)
        #expect(s.drawGrid(uLineCount: -1, vLineCount: 4, pointsPerLine: 10).count == 0)
        #expect(s.drawGrid(uLineCount: 4, vLineCount: 4, pointsPerLine: -1).count == 0)
        // Both line counts near Int.max used to overflow the addition itself, before any ceiling.
        #expect(s.drawGrid(uLineCount: Int.max, vLineCount: Int.max, pointsPerLine: 10).count == 0)
        #expect(s.drawGrid(uLineCount: Self.pastInt32, vLineCount: 0, pointsPerLine: 10).count == 0)
    }

    @Test("BRepGraph.sampleFaceUVGrid bounds the product, and each factor on its own")
    func faceUVGrid() {
        guard let graph = BRepGraph(shape: box()) else { #expect(Bool(false)); return }
        #expect(graph.sampleFaceUVGrid(faceIndex: 0, uSamples: 5, vSamples: 4) != nil)
        #expect(graph.sampleFaceUVGrid(faceIndex: 0, uSamples: 5000, vSamples: 2001) == nil)
        #expect(graph.sampleFaceUVGrid(faceIndex: 0, uSamples: -1, vSamples: -1) == nil)
        #expect(graph.sampleFaceUVGrid(faceIndex: 0, uSamples: -1, vSamples: 3) == nil)
        #expect(graph.sampleFaceUVGrid(faceIndex: 0, uSamples: 0, vSamples: 3) == nil)
        #expect(graph.sampleFaceUVGrid(faceIndex: 0, uSamples: Self.pastInt32, vSamples: 3) == nil)
        #expect(graph.sampleFaceUVGrid(faceIndex: 0, uSamples: Int.max, vSamples: Int.max) == nil)
    }

    @Test("Shape.coonsAlgPatch bounds the product, and each factor on its own")
    func coonsPatchGrid() {
        guard let e = box().subShapes(ofType: .edge).first else { #expect(Bool(false)); return }
        // Four copies of one edge is a degenerate patch, so the result is nil either way; what is
        // under test is that an absurd grid returns rather than aborting the process.
        #expect(Shape.coonsAlgPatch(edge1: e, edge2: e, edge3: e, edge4: e,
                                    evalU: -1, evalV: -1) == nil)
        #expect(Shape.coonsAlgPatch(edge1: e, edge2: e, edge3: e, edge4: e,
                                    evalU: -1, evalV: 3) == nil)
        #expect(Shape.coonsAlgPatch(edge1: e, edge2: e, edge3: e, edge4: e,
                                    evalU: 5000, evalV: 2001) == nil)
        #expect(Shape.coonsAlgPatch(edge1: e, edge2: e, edge3: e, edge4: e,
                                    evalU: Int.max, evalV: Int.max) == nil)
    }
}
