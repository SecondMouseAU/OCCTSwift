import Foundation
import simd
import OCCTBridge

/// Individual fix operations on a wire using ShapeFix_Wire.
public final class WireFixer: @unchecked Sendable {
    private let ref: OCCTWireFixerRef

    /// Create a wire fixer for a wire on a face with given precision.
    public init?(wire: Shape, face: Shape, precision: Double = 1e-6) {
        guard let r = OCCTWireFixerCreate(wire.handle, face.handle, precision) else { return nil }
        self.ref = r
    }

    deinit { OCCTWireFixerRelease(ref) }

    /// Fix the order of edges.
    @discardableResult public func fixReorder() -> Bool { OCCTWireFixerFixReorder(ref) }

    /// Fix connectivity of edges.
    @discardableResult public func fixConnected() -> Bool { OCCTWireFixerFixConnected(ref) }

    /// Fix small edges.
    @discardableResult public func fixSmall(precision: Double = 1e-6) -> Bool { OCCTWireFixerFixSmall(ref, precision) }

    /// Fix degenerated edges.
    @discardableResult public func fixDegenerated() -> Bool { OCCTWireFixerFixDegenerated(ref) }

    /// Fix self-intersection.
    @discardableResult public func fixSelfIntersection() -> Bool { OCCTWireFixerFixSelfIntersection(ref) }

    /// Fix lacking edges.
    @discardableResult public func fixLacking() -> Bool { OCCTWireFixerFixLacking(ref) }

    /// Fix closed wire.
    @discardableResult public func fixClosed() -> Bool { OCCTWireFixerFixClosed(ref) }

    /// Fix 3D gaps between edges.
    @discardableResult public func fixGaps3d() -> Bool { OCCTWireFixerFixGaps3d(ref) }

    /// Fix edge curves.
    @discardableResult public func fixEdgeCurves() -> Bool { OCCTWireFixerFixEdgeCurves(ref) }

    /// Get the resulting fixed wire.
    public var wire: Shape? {
        guard let r = OCCTWireFixerWire(ref) else { return nil }
        return Shape(handle: r)
    }
}

/// Individual fix operations on a face using ShapeFix_Face.
public final class FaceFixer: @unchecked Sendable {
    private let ref: OCCTFaceFixerRef

    /// Create a face fixer with given precision.
    public init?(face: Shape, precision: Double = 1e-6) {
        guard let r = OCCTFaceFixerCreate(face.handle, precision) else { return nil }
        self.ref = r
    }

    deinit { OCCTFaceFixerRelease(ref) }

    /// Perform all fixes.
    @discardableResult public func perform() -> Bool { OCCTFaceFixerPerform(ref) }

    /// Fix orientation of wires.
    @discardableResult public func fixOrientation() -> Bool { OCCTFaceFixerFixOrientation(ref) }

    /// Add natural bound if missing.
    @discardableResult public func fixAddNaturalBound() -> Bool { OCCTFaceFixerFixAddNaturalBound(ref) }

    /// Fix missing seam edge.
    @discardableResult public func fixMissingSeam() -> Bool { OCCTFaceFixerFixMissingSeam(ref) }

    /// Fix small area wires.
    @discardableResult public func fixSmallAreaWire() -> Bool { OCCTFaceFixerFixSmallAreaWire(ref) }

    /// Get the resulting fixed face.
    public var face: Shape? {
        guard let r = OCCTFaceFixerFace(ref) else { return nil }
        return Shape(handle: r)
    }

    // MARK: - Per-pass control (#266 follow-up)

    /// An individual `ShapeFix_Face` healing pass that can be toggled before ``perform()``.
    public enum Pass: Int32, Sendable {
        case wire = 0, orientation, addNaturalBound, missingSeam, smallAreaWire,
             removeSmallAreaFace, intersectingWires, loopWires, splitFace,
             autoCorrectPrecision, periodicDegenerated
    }

    /// Whether a pass runs: `.auto` (the default heuristic), `.off`, or `.on` (force).
    public enum Toggle: Int32, Sendable { case auto = -1, off = 0, on = 1 }

    /// Enable / disable an individual healing pass before calling ``perform()``.
    ///
    /// ```swift
    /// // Heal a face but DON'T add the surface's natural bound (which can balloon a trimmed face):
    /// let fixer = FaceFixer(face: f)
    /// fixer?.setMode(.addNaturalBound, .off)
    /// fixer?.perform()
    /// ```
    public func setMode(_ pass: Pass, _ toggle: Toggle) {
        OCCTFaceFixerSetMode(ref, pass.rawValue, toggle.rawValue)
    }

    /// Fix self-intersecting wires on the face.
    @discardableResult public func fixIntersectingWires() -> Bool { OCCTFaceFixerFixIntersectingWires(ref) }

    /// Reconstruct a degenerate edge at a pole on a periodic surface.
    @discardableResult public func fixPeriodicDegenerated() -> Bool { OCCTFaceFixerFixPeriodicDegenerated(ref) }

    /// Remove coincident-edge pairs from the face's wires.
    @discardableResult public func fixWiresTwoCoincEdges() -> Bool { OCCTFaceFixerFixWiresTwoCoincEdges(ref) }

    /// Split a wire that loops back on itself.
    @discardableResult public func fixLoopWire() -> Bool { OCCTFaceFixerFixLoopWire(ref) }

    /// The result of the fix — usually a face, but a **shell** when ``fixMissingSeam()`` split the
    /// face into several. Unlike ``face`` (always a face), this returns the true multi-face result.
    public var result: Shape? {
        guard let r = OCCTFaceFixerResult(ref) else { return nil }
        return Shape(handle: r)
    }

    /// A status flag recorded by the fixer (which passes fired / failed) — query after ``perform()``.
    public enum Status: Int32, Sendable {
        case ok = 0
        case done1 = 1, done2, done3, done4, done5, done6, done7, done8
        case fail1 = 9, fail2, fail3, fail4, fail5, fail6, fail7, fail8
        /// Any DONEi flag set (a fix fired).
        case done = 17
        /// Any FAILi flag set (a fix failed).
        case fail = 18
    }

    /// Whether the given status flag is set after ``perform()`` (e.g. `.done` = something was fixed,
    /// `.fail` = a pass failed).
    public func status(_ status: Status) -> Bool { OCCTFaceFixerStatus(ref, status.rawValue) }

    /// Clamp the maximum tolerance the fixer may assign to the healed face. Call before ``perform()``.
    public func setMaxTolerance(_ maxTolerance: Double) { OCCTFaceFixerSetMaxTolerance(ref, maxTolerance) }

    /// Clamp the minimum tolerance the fixer may assign to the healed face. Call before ``perform()``.
    public func setMinTolerance(_ minTolerance: Double) { OCCTFaceFixerSetMinTolerance(ref, minTolerance) }
}

extension WireFixer {
    /// Fix 2D gaps between edges.
    @discardableResult public func fixGaps2d() -> Bool { OCCTWireFixerFixGaps2d(ref) }

    /// Fix seam edge at the given index (1-based).
    @discardableResult public func fixSeam(edgeIndex: Int) -> Bool { OCCTWireFixerFixSeam(ref, Int32(edgeIndex)) }

    /// Fix shifted pcurves.
    @discardableResult public func fixShifted() -> Bool { OCCTWireFixerFixShifted(ref) }

    /// Fix notched edges.
    @discardableResult public func fixNotchedEdges() -> Bool { OCCTWireFixerFixNotchedEdges(ref) }

    /// Fix tail edges.
    @discardableResult public func fixTails() -> Bool { OCCTWireFixerFixTails(ref) }

    /// Set the maximum tail angle (radians).
    public func setMaxTailAngle(_ angle: Double) { OCCTWireFixerSetMaxTailAngle(ref, angle) }

    /// Set the maximum tail width.
    public func setMaxTailWidth(_ width: Double) { OCCTWireFixerSetMaxTailWidth(ref, width) }
}
