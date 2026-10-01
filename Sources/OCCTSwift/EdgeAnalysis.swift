import OCCTBridge
import OCCTPlatform
import simd

/// Edge analysis utilities using ShapeAnalysis_Edge.
///
/// **Polarity.** For every `check` member here except two, `true` means *a problem was found*,
/// which is `ShapeAnalysis_Edge`'s own convention: those methods end in
/// `return Status(ShapeExtend_DONE)`, and `DONE` on a `ShapeAnalysis_*` class is "a defect was
/// detected". The two exceptions are ``checkOverlapping(_:_:tolerance:)``, which reports a fact
/// rather than a verdict, and ``checkPCurveRange(_:face:first:last:)``, whose `true` means the
/// range is valid. ``checkSameParameter(_:)`` is the one whose OCCT header states the reverse of
/// what the class does; its own documentation has the evidence (#2901).
public enum EdgeAnalysis {
    /// Check if an edge has a 3D curve.
    public static func hasCurve3d(_ edge: Shape) -> Bool {
        OCCTEdgeHasCurve3dSA(edge.handle)
    }

    /// Check if an edge is closed in 3D.
    public static func isClosed3d(_ edge: Shape) -> Bool {
        OCCTEdgeIsClosed3dSA(edge.handle)
    }

    /// Check if an edge has a PCurve on a face.
    public static func hasPCurve(_ edge: Shape, face: Shape) -> Bool {
        OCCTEdgeHasPCurveSA(edge.handle, face.handle)
    }

    /// Check if an edge is a seam edge on a face.
    public static func isSeam(_ edge: Shape, face: Shape) -> Bool {
        OCCTEdgeIsSeamSA(edge.handle, face.handle)
    }

    /// Check the edge's `SameParameter` flag against the real deviation between its 3D curve and
    /// its pcurves.
    ///
    /// - Parameter edge: The edge to check.
    /// - Returns: `problemFound` is `true` when a problem was detected, and `maxDeviation` is the
    ///   largest distance measured between the 3D curve and any pcurve at the same parameter.
    ///
    /// **`true` means a problem was found, which is the reverse of what the OCCT header says.**
    /// `ShapeAnalysis_Edge.hxx` claims "If deviation is greater than tolerance of the edge (i.e.
    /// incorrect flag) returns False, else returns True". The implementation does the opposite:
    /// `ShapeAnalysis_Edge.cxx` ends in `return Status(ShapeExtend_DONE)` having set `DONE1` when
    /// `maxdev > TE->Tolerance()` and `DONE2` when the flag is already false. OCCT's own caller
    /// agrees with the implementation rather than the header: the shape_healing user guide writes
    /// `if (aCheckEdge.CheckSameParameter(theEdge, aMaxDev)) { "Incorrect SameParameter flag";
    /// aFixEdge.FixSameParameter(theEdge); }`, so `true` is the branch that reports the defect and
    /// repairs it. Per `okf/policies/follow-occt-callers.md` the call site is the contract and the
    /// doxygen is not, so do not "correct" this back from the header (#2901).
    ///
    /// Measured in `Scripts/repro/2901/`: a pristine box edge answers `false` with
    /// `maxDeviation == 0`; an edge whose pcurve sits `1.0` from its 3D curve at every parameter
    /// answers `true` with `maxDeviation == 1.00001`.
    ///
    /// Two separate triggers set the flag, so `problemFound == true` with `maxDeviation == 0` is a
    /// real answer rather than a contradiction: it means the geometry agrees but the edge's stored
    /// `SameParameter` flag is already `false`.
    ///
    /// The tuple element was called `ok` until #2901, which read as the opposite of what it is.
    ///
    /// ```swift
    /// if let box = Shape.box(width: 10, height: 10, depth: 10),
    ///     let edge = box.subShapes(ofType: .edge).first
    /// {
    ///     let result = EdgeAnalysis.checkSameParameter(edge)
    ///     if result.problemFound {
    ///         print("incorrect SameParameter flag, deviation \(result.maxDeviation)")
    ///     }
    /// }
    /// ```
    public static func checkSameParameter(_ edge: Shape) -> (
        problemFound: Bool, maxDeviation: Double
    ) {
        var maxdev = 0.0
        let problemFound = OCCTEdgeCheckSameParameter(edge.handle, &maxdev)
        return (problemFound, maxdev)
    }

    /// Check vertices with 3D curve positions.
    ///
    /// - Parameters:
    ///   - edge: The edge whose vertices to check.
    ///   - precision: Distance threshold for a vertex to be considered consistent with the
    ///     curve. Defaults to `-1.0`, matching `ShapeAnalysis_Edge::CheckVerticesWithCurve3d`'s own
    ///     sentinel default: a negative value checks each vertex against its own stored tolerance
    ///     instead of a fixed distance. Prior to #1577 this defaulted to a fixed `1e-6`, which made
    ///     the check stricter than OCCT's own default for any vertex whose own tolerance is looser
    ///     than `1e-6` (common on healed/mesh-derived geometry).
    /// - Returns: `true` if a vertex/curve mismatch was found (matching OCCT's own
    ///   `CheckVerticesWithCurve3d` contract: `true` means a problem was detected, not that the
    ///   check passed).
    public static func checkVerticesWithCurve3d(_ edge: Shape, precision: Double = -1.0) -> Bool {
        OCCTEdgeCheckVerticesWithCurve3d(edge.handle, precision)
    }

    /// Check vertices with PCurve positions on a face.
    ///
    /// - Parameters:
    ///   - edge: The edge whose vertices to check.
    ///   - face: The face carrying the pcurve to check against.
    ///   - precision: Distance threshold for a vertex to be considered consistent with the
    ///     pcurve. Defaults to `-1.0`, matching `ShapeAnalysis_Edge::CheckVerticesWithPCurve`'s own
    ///     sentinel default: a negative value checks each vertex against its own stored tolerance
    ///     instead of a fixed distance. Prior to #1577 this defaulted to a fixed `1e-6`, which made
    ///     the check stricter than OCCT's own default for any vertex whose own tolerance is looser
    ///     than `1e-6` (common on healed/mesh-derived geometry).
    /// - Returns: `true` if a vertex/pcurve mismatch was found (matching OCCT's own
    ///   `CheckVerticesWithPCurve` contract: `true` means a problem was detected, not that the
    ///   check passed).
    public static func checkVerticesWithPCurve(
        _ edge: Shape, face: Shape,
        precision: Double = -1.0
    ) -> Bool {
        OCCTEdgeCheckVerticesWithPCurve(edge.handle, face.handle, precision)
    }

    /// Check the mutual orientation of the edge's 3D curve and its pcurve on a face.
    ///
    /// - Returns: `true` if a mismatch was found, matching OCCT's own `CheckCurve3dWithPCurve`
    ///   contract: `true` means a problem was detected, not that the check passed. The method
    ///   delegates to `ShapeAnalysis_Edge::CheckPoints`, which returns `false` only when both
    ///   curve ends agree within their vertices' tolerances (#2901).
    public static func checkCurve3dWithPCurve(_ edge: Shape, face: Shape) -> Bool {
        OCCTEdgeCheckCurve3dWithPCurve(edge.handle, face.handle)
    }

    /// Get the first vertex position of an edge.
    public static func firstVertex(_ edge: Shape) -> SIMD3<Double> {
        var x = 0.0
        var y = 0.0
        var z = 0.0
        OCCTEdgeFirstVertexSA(edge.handle, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Get the last vertex position of an edge.
    public static func lastVertex(_ edge: Shape) -> SIMD3<Double> {
        var x = 0.0
        var y = 0.0
        var z = 0.0
        OCCTEdgeLastVertexSA(edge.handle, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Check whether the edge's vertex tolerances need increasing to reach the ends of its 3D
    /// curve and of its pcurve on `face`.
    ///
    /// - Parameters:
    ///   - edge: The edge whose vertices to check.
    ///   - face: The face whose pcurve the vertices are also measured against.
    /// - Returns: `needsIncrease` is `true` when either vertex's stored tolerance is too small,
    ///   and `toler1`/`toler2` are the tolerances the first and last vertex would need.
    ///
    /// **`true` means a problem was found**, matching `ShapeAnalysis_Edge`'s own description
    /// ("Checks if it is necessary to increase tolerances of the edge vertices ... toler1 returns
    /// necessary tolerance for first vertex") and its implementation, which ends in
    /// `return Status(ShapeExtend_DONE)` having set `DONE1`/`DONE2` whenever the needed tolerance
    /// exceeds the stored one. Needing an increase is the problem, so the element was renamed from
    /// `ok` in #2901, where it read as the opposite.
    ///
    /// Measured in `Scripts/repro/2901/`: a pristine box edge answers `false` with both tolerances
    /// at the vertex default `1e-7`; an edge whose vertices sit `1.0` from its pcurve's surface
    /// points answers `true` with both at `1.0000001`.
    ///
    /// `toler1` and `toler2` are filled in either way, so a `false` answer still reports the
    /// tolerance each vertex needs; it is simply no larger than the one already stored.
    ///
    /// ```swift
    /// if let box = Shape.box(width: 10, height: 10, depth: 10),
    ///     let edge = box.subShapes(ofType: .edge).first,
    ///     let face = box.subShapes(ofType: .face).first
    /// {
    ///     let result = EdgeAnalysis.checkVertexTolerance(edge, face: face)
    ///     if result.needsIncrease {
    ///         print("raise vertex tolerances to \(result.toler1) and \(result.toler2)")
    ///     }
    /// }
    /// ```
    public static func checkVertexTolerance(_ edge: Shape, face: Shape) -> (
        needsIncrease: Bool, toler1: Double, toler2: Double
    ) {
        var t1 = 0.0
        var t2 = 0.0
        let needsIncrease = OCCTEdgeCheckVertexTolerance(edge.handle, face.handle, &t1, &t2)
        return (needsIncrease, t1, t2)
    }

    /// Check if two edges overlap.
    ///
    /// - Parameters:
    ///   - edge1: The first edge.
    ///   - edge2: The second edge.
    ///   - tolerance: The overlap distance threshold. Defaults to `Precision::Confusion()`
    ///     (`1e-7`). Prior to #1438 this was fixed at `0.0` internally, which made the underlying
    ///     OCCT comparison always fail, so `checkOverlapping` always returned `false`.
    /// - Returns: (overlapping, tolerance) -- `tolerance` echoes back the threshold used.
    public static func checkOverlapping(_ edge1: Shape, _ edge2: Shape, tolerance: Double = 1e-7)
        -> (overlapping: Bool, tolerance: Double)
    {
        var tol = tolerance
        let ok = OCCTEdgeCheckOverlapping(edge1.handle, edge2.handle, tolerance, &tol)
        return (ok, tol)
    }

    /// Get UV bounds of an edge on a face.
    public static func boundUV(_ edge: Shape, face: Shape) -> (
        uFirst: Double, vFirst: Double, uLast: Double, vLast: Double
    )? {
        var uf = 0.0
        var vf = 0.0
        var ul = 0.0
        var vl = 0.0
        let ok = OCCTEdgeBoundUV(edge.handle, face.handle, &uf, &vf, &ul, &vl)
        if !ok { return nil }
        return (uf, vf, ul, vl)
    }

    /// Get end tangent in 2D for an edge on a face.
    public static func endTangent2d(
        _ edge: Shape, face: Shape,
        atEnd: Bool
    ) -> (point: SIMD2<Double>, tangent: SIMD2<Double>)? {
        var px = 0.0
        var py = 0.0
        var tx = 0.0
        var ty = 0.0
        let ok = OCCTEdgeGetEndTangent2d(edge.handle, face.handle, atEnd, &px, &py, &tx, &ty)
        if !ok { return nil }
        return (SIMD2(px, py), SIMD2(tx, ty))
    }

    /// Check whether `[first, last]` is a valid parameter range for the edge's pcurve on `face`.
    ///
    /// The check is against the pcurve's own underlying geometric domain (its full period, for a
    /// periodic pcurve), not against the edge's current stored trim range: a range can be valid
    /// here even when it extends beyond where the edge itself happens to be trimmed, as long as it
    /// stays within the pcurve's own domain (#1438).
    ///
    /// - Returns: `true` when the range **is** valid. This is the one `check` member of this type
    ///   whose `true` is the good answer: `ShapeAnalysis_Edge::CheckPCurveRange` returns a plain
    ///   `isValid` rather than the `Status(ShapeExtend_DONE)` that gives every other member here
    ///   its "a problem was found" polarity, and the swept family is recorded in #2901.
    public static func checkPCurveRange(
        _ edge: Shape, face: Shape,
        first: Double, last: Double
    ) -> Bool {
        OCCTEdgeCheckPCurveRange(edge.handle, face.handle, first, last)
    }
}
