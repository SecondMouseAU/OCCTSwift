import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

/// #2901: `EdgeAnalysis.checkSameParameter` and `EdgeAnalysis.checkVertexTolerance` labelled their
/// `Bool` `ok` while `true` means a problem was found. `SAEdgeAnalysisTests` pins the clean half of
/// that on a pristine box edge; nothing pinned the other polarity, so nothing would have failed if
/// the two wrappers had been "corrected" to match the OCCT header's own doxygen, which states the
/// reverse of what the class does.
///
/// `ShapeAnalysis_Edge.hxx` says "If deviation is greater than tolerance of the edge (i.e.
/// incorrect flag) returns False, else returns True". `ShapeAnalysis_Edge.cxx` ends in
/// `return Status(ShapeExtend_DONE)` having set `DONE1` when `maxdev > TE->Tolerance()` and `DONE2`
/// when the stored `SameParameter` flag is false, and OCCT's own caller, the shape_healing user
/// guide, writes `if (aCheckEdge.CheckSameParameter(theEdge, aMaxDev)) { "Incorrect SameParameter
/// flag"; aFixEdge.FixSameParameter(theEdge); }`. Per okf/policies/follow-occt-callers.md the call
/// site is the contract.
///
/// Every value below is the kernel's own answer from `Scripts/repro/2901/probe.mm`, which builds
/// the same three edges in C++ directly against the pinned xcframework.
@Suite("Edge check polarity (#2901)")
struct Issue2901EdgeCheckPolarityTests {

    /// Builds an edge whose 3D curve and pcurve are parallel, one unit apart.
    ///
    /// The 3D curve is the segment `(0,0,0)-(10,0,0)` and the pcurve on the `z = 0` plane is the
    /// parallel segment at `v = 1`, both on parameter domain `[0, 1]`. The two therefore disagree
    /// by exactly `1.0` at every parameter, and the edge's vertices, which sit on the 3D curve,
    /// are `1.0` from the pcurve's surface points.
    ///
    /// Assembled the same way as `Issue1461ValidateEdgeSameParameterTests`'s fixture, which is the
    /// only Swift-reachable route to an edge carrying a pcurve that was never verified against its
    /// 3D curve: build the 3D-curve-only edge and the pcurve-only edge separately, then append the
    /// second's representation to the first.
    private func offsetPCurveEdge() -> (edge: Shape, face: Shape)? {
        guard let curve3d = Curve3D.bezier(poles: [SIMD3(0, 0, 0), SIMD3(10, 0, 0)]),
            let offsetPCurve = Curve2D.bezier(poles: [SIMD2(0, 1), SIMD2(10, 1)]),
            let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)),
            let planeFace = Shape.face(from: plane, uRange: -50...50, vRange: -50...50),
            let curveEdgeHandle = OCCTMakeEdgeFromCurveParams(curve3d.handle, 0, 1),
            let pcurveEdgeHandle = OCCTMakeEdgeOnSurfaceParams(
                offsetPCurve.handle, plane.handle, 0, 1)
        else { return nil }

        let edge = Shape(handle: curveEdgeHandle)
        let pcurveEdge = Shape(handle: pcurveEdgeHandle)
        // `edge` holds no representation on `plane` yet, so this appends rather than replaces: it
        // keeps its own straight 3D curve and gains the offset pcurve, both on domain [0, 1].
        OCCTShapeBuildEdgeCopyPCurves(edge.handle, pcurveEdge.handle)

        // Claim the flag is correct. That claim is the defect `checkSameParameter` reports, and
        // without it the result would be ambiguous between the two triggers.
        guard let edgeRef = OCCTEdgeFromShape(edge.handle) else { return nil }
        OCCTEdgeSetSameParameter(edgeRef, true)
        OCCTEdgeRelease(edgeRef)

        return (edge, planeFace)
    }

    @Test("a real deviation answers true, not false")
    func sameParameterReportsTrueOnADeviatingEdge() throws {
        let (edge, _) = try #require(offsetPCurveEdge())
        let result = EdgeAnalysis.checkSameParameter(edge)
        // Kernel (probe): true, maxdev 1.0000100000000001. The header's doxygen would make this
        // `false`, so this expectation is what stops the wrapper being "corrected" back to it.
        #expect(result.problemFound == true)
        #expect(abs(result.maxDeviation - 1.00001) < 1e-9)
    }

    @Test("a wrong SameParameter flag answers true with zero deviation")
    func sameParameterReportsTrueOnAWrongFlagAlone() throws {
        // DONE2 is the second, independent trigger: geometry that agrees, flag that says it does
        // not. `problemFound == true` with `maxDeviation == 0` is therefore a real answer rather
        // than a contradiction, which is the part the doc comment has to carry.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edge = try #require(box.subShapes(ofType: .edge).first)
        let edgeRef = try #require(OCCTEdgeFromShape(edge.handle))
        defer { OCCTEdgeRelease(edgeRef) }

        #expect(EdgeAnalysis.checkSameParameter(edge).problemFound == false)
        OCCTEdgeSetSameParameter(edgeRef, false)

        let result = EdgeAnalysis.checkSameParameter(edge)
        #expect(result.problemFound == true)
        #expect(result.maxDeviation == 0)
    }

    @Test("vertices that need a looser tolerance answer true")
    func vertexToleranceReportsTrueWhenAnIncreaseIsNeeded() throws {
        let (edge, face) = try #require(offsetPCurveEdge())
        let result = EdgeAnalysis.checkVertexTolerance(edge, face: face)
        // Kernel (probe): true, both tolerances 1.0000001000000001, against a stored vertex
        // tolerance of 1e-7. Needing the increase is the problem, so `true` is the defect report.
        #expect(result.needsIncrease == true)
        #expect(abs(result.toler1 - 1.0000001) < 1e-9)
        #expect(abs(result.toler2 - 1.0000001) < 1e-9)
    }

    @Test("checkPCurveRange is the one member whose true is the good answer")
    func pCurveRangePolarityIsTheOppositeOfItsSiblings() throws {
        // ShapeAnalysis_Edge::CheckPCurveRange returns a plain `isValid`, not the
        // `Status(ShapeExtend_DONE)` that gives the rest of the family its "a problem was found"
        // polarity. Pinned so the family sweep in #2901 cannot be "made consistent" by inverting
        // the odd one out: a valid range has to keep answering `true` here, where a valid edge
        // answers `false` everywhere else in the family. The `false` branch lives in
        // `SAEdgeAnalysisTests.edgePCurveRangeChecksPCurveDomainNotEdgeTrim`, which needs a
        // periodic pcurve to produce one; a box face edge's line pcurve has an unbounded domain,
        // so every range on it is valid.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let face = try #require(box.subShapes(ofType: .face).first)
        let edge = try #require(face.subShapes(ofType: .edge).first)
        #expect(EdgeAnalysis.checkPCurveRange(edge, face: face, first: 0, last: 10) == true)
    }
}
