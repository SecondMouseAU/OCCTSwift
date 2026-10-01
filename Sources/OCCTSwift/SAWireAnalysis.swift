import OCCTBridge
import OCCTPlatform
import simd

/// Wire analysis utilities using ShapeAnalysis_Wire (v0.106.0).
///
/// **Precondition: the wire's edges must be in connection order before any other member here
/// means anything.** `ShapeAnalysis_Wire` walks the wire as a sequence and compares each edge
/// against the next one *in that sequence*, so on an out-of-order wire the "next" edge is the
/// wrong one and every answer that depends on adjacency is a correct answer to the wrong
/// question. OCCT's own caller treats ``checkOrder(wire:face:precision:)`` as a stop condition
/// rather than one result among many; the shape_healing user guide writes
///
/// ```text
/// ShapeAnalysis_Wire aCheckWire (theWire, theFace, aPrecision);
/// if (aCheckWire.CheckOrder())
/// {
///   std::cout << "Some edges in the wire need to be reordered\n";
///   return;
/// }
/// if (aCheckWire.CheckSmall (aPrecision)) { ... }
/// ```
///
/// and runs no later check. Per `okf/policies/follow-occt-callers.md` that early return is the
/// contract, so ask `checkOrder` first and reorder before reading anything else (#2906).
///
/// This is reachable from the most ordinary shape in the library, not only from imported
/// geometry: a face of `Shape.box(width:height:depth:)` answers `checkOrder == true`, and
/// `Scripts/repro/2906/` measures what follows. Before reordering, that pristine 10x10 face
/// reports four problems (3D gaps, 2D gaps, edge curves, and the gap at edge 1) with all four
/// distances at `14.142135623730951`, which is `10 * sqrt(2)`, the face's diagonal rather than
/// any gap in it. After ``WireFixer/fixReorder()`` every one of those answers `false` and all
/// four distances are `0`.
///
/// ``WireFixer`` is how the precondition is satisfied; it wraps `ShapeFix_Wire`, whose
/// `FixReorder` is the counterpart of this type's `checkOrder`:
///
/// ```swift
/// if let box = Shape.box(width: 10, height: 10, depth: 10),
///     let face = box.subShapes(ofType: .face).first,
///     let rawWire = face.subShapes(ofType: .wire).first
/// {
///     var wire = rawWire
///     if SAWireAnalysis.checkOrder(wire: wire, face: face) {
///         if let fixer = WireFixer(wire: wire, face: face) {
///             fixer.fixReorder()
///             if let reordered = fixer.wire { wire = reordered }
///         }
///     }
///     // Only now is this a gap rather than the diagonal.
///     let gap = SAWireAnalysis.maxDistance3d(wire: wire, face: face)
///     print(gap)
/// }
/// ```
public enum SAWireAnalysis {
    /// Check wire edge ordering.
    ///
    /// Returns true if a problem is found, meaning the edges are not in connection order.
    ///
    /// This is the gate for every other member of this type, not one result among them: see
    /// ``SAWireAnalysis`` for OCCT's own early return and for what the other members answer on an
    /// out-of-order wire. Reorder with ``WireFixer/fixReorder()`` before reading them (#2906).
    public static func checkOrder(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool {
        OCCTWireCheckOrder(wire.handle, face.handle, precision)
    }

    /// Check wire connectivity.
    ///
    /// Returns true if a problem is found.
    ///
    /// - Precondition: the wire's edges are in connection order, that is
    ///   ``checkOrder(wire:face:precision:)`` answers `false`. See ``SAWireAnalysis`` for why,
    ///   and for what this answers when they are not (#2906).
    public static func checkConnected(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool {
        OCCTWireCheckConnected(wire.handle, face.handle, precision)
    }

    /// Check for small edges.
    ///
    /// Returns true if a problem is found.
    ///
    /// - Precondition: the wire's edges are in connection order, that is
    ///   ``checkOrder(wire:face:precision:)`` answers `false`. See ``SAWireAnalysis`` for why,
    ///   and for what this answers when they are not (#2906).
    public static func checkSmall(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool {
        OCCTWireCheckSmall(wire.handle, face.handle, precision)
    }

    /// Check for degenerated edges.
    ///
    /// Returns true if a problem is found.
    ///
    /// - Precondition: the wire's edges are in connection order, that is
    ///   ``checkOrder(wire:face:precision:)`` answers `false`. See ``SAWireAnalysis`` for why,
    ///   and for what this answers when they are not (#2906).
    public static func checkDegenerated(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool
    {
        OCCTWireCheckDegenerated(wire.handle, face.handle, precision)
    }

    /// Check wire closure.
    ///
    /// Returns true if a problem is found.
    ///
    /// - Precondition: the wire's edges are in connection order, that is
    ///   ``checkOrder(wire:face:precision:)`` answers `false`. See ``SAWireAnalysis`` for why,
    ///   and for what this answers when they are not (#2906).
    public static func checkClosed(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool {
        OCCTWireCheckClosed(wire.handle, face.handle, precision)
    }

    /// Check for self-intersection.
    ///
    /// Returns true if a problem is found.
    ///
    /// - Precondition: the wire's edges are in connection order, that is
    ///   ``checkOrder(wire:face:precision:)`` answers `false`. See ``SAWireAnalysis`` for why,
    ///   and for what this answers when they are not (#2906).
    public static func checkSelfIntersection(wire: Shape, face: Shape, precision: Double = 1e-6)
        -> Bool
    {
        OCCTWireCheckSelfIntersection(wire.handle, face.handle, precision)
    }

    /// Check for 3D gaps.
    ///
    /// Returns true if a problem is found.
    ///
    /// - Precondition: the wire's edges are in connection order, that is
    ///   ``checkOrder(wire:face:precision:)`` answers `false`. See ``SAWireAnalysis`` for why,
    ///   and for what this answers when they are not (#2906).
    public static func checkGaps3d(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool {
        OCCTWireCheckGaps3d(wire.handle, face.handle, precision)
    }

    /// Check for 2D gaps.
    ///
    /// Returns true if a problem is found.
    ///
    /// - Precondition: the wire's edges are in connection order, that is
    ///   ``checkOrder(wire:face:precision:)`` answers `false`. See ``SAWireAnalysis`` for why,
    ///   and for what this answers when they are not (#2906).
    public static func checkGaps2d(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool {
        OCCTWireCheckGaps2d(wire.handle, face.handle, precision)
    }

    /// Check edge curves consistency.
    ///
    /// Returns true if a problem is found.
    ///
    /// - Precondition: the wire's edges are in connection order, that is
    ///   ``checkOrder(wire:face:precision:)`` answers `false`. See ``SAWireAnalysis`` for why,
    ///   and for what this answers when they are not (#2906).
    public static func checkEdgeCurves(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool {
        OCCTWireCheckEdgeCurves(wire.handle, face.handle, precision)
    }

    /// Check for lacking edges.
    ///
    /// Returns true if a problem is found.
    ///
    /// - Precondition: the wire's edges are in connection order, that is
    ///   ``checkOrder(wire:face:precision:)`` answers `false`. See ``SAWireAnalysis`` for why,
    ///   and for what this answers when they are not (#2906).
    public static func checkLacking(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool {
        OCCTWireCheckLacking(wire.handle, face.handle, precision)
    }

    /// Get the number of edges in a wire on a face.
    public static func edgeCount(wire: Shape, face: Shape, precision: Double = 1e-6) -> Int {
        Int(OCCTWireEdgeCount(wire.handle, face.handle, precision))
    }

    /// Get the minimum 3D distance gap in a wire.
    ///
    /// - Precondition: the wire's edges are in connection order, that is
    ///   ``checkOrder(wire:face:precision:)`` answers `false`. See ``SAWireAnalysis`` for why,
    ///   and for what this answers when they are not (#2906).
    public static func minDistance3d(wire: Shape, face: Shape, precision: Double = 1e-6) -> Double {
        OCCTWireMinDistance3d(wire.handle, face.handle, precision)
    }

    /// Get the maximum 3D distance gap in a wire.
    ///
    /// - Precondition: the wire's edges are in connection order, that is
    ///   ``checkOrder(wire:face:precision:)`` answers `false`. See ``SAWireAnalysis`` for why,
    ///   and for what this answers when they are not (#2906).
    public static func maxDistance3d(wire: Shape, face: Shape, precision: Double = 1e-6) -> Double {
        OCCTWireMaxDistance3d(wire.handle, face.handle, precision)
    }

    /// Get the minimum 2D distance gap in a wire.
    ///
    /// - Precondition: the wire's edges are in connection order, that is
    ///   ``checkOrder(wire:face:precision:)`` answers `false`. See ``SAWireAnalysis`` for why,
    ///   and for what this answers when they are not (#2906).
    public static func minDistance2d(wire: Shape, face: Shape, precision: Double = 1e-6) -> Double {
        OCCTWireMinDistance2d(wire.handle, face.handle, precision)
    }

    /// Get the maximum 2D distance gap in a wire.
    ///
    /// - Precondition: the wire's edges are in connection order, that is
    ///   ``checkOrder(wire:face:precision:)`` answers `false`. See ``SAWireAnalysis`` for why,
    ///   and for what this answers when they are not (#2906).
    public static func maxDistance2d(wire: Shape, face: Shape, precision: Double = 1e-6) -> Double {
        OCCTWireMaxDistance2d(wire.handle, face.handle, precision)
    }

    /// Check connectivity of a specific edge by index (1-based).
    ///
    /// - Precondition: the wire's edges are in connection order, that is
    ///   ``checkOrder(wire:face:precision:)`` answers `false`. See ``SAWireAnalysis`` for why,
    ///   and for what this answers when they are not (#2906).
    public static func checkConnectedEdge(
        wire: Shape, face: Shape, precision: Double = 1e-6,
        edgeIndex: Int
    ) -> Bool {
        OCCTWireCheckConnectedEdge(wire.handle, face.handle, precision, Int32(edgeIndex))
    }

    /// Check if a specific edge is small (1-based).
    ///
    /// - Precondition: the wire's edges are in connection order, that is
    ///   ``checkOrder(wire:face:precision:)`` answers `false`. See ``SAWireAnalysis`` for why,
    ///   and for what this answers when they are not (#2906).
    public static func checkSmallEdge(
        wire: Shape, face: Shape, precision: Double = 1e-6,
        edgeIndex: Int
    ) -> Bool {
        OCCTWireCheckSmallEdge(wire.handle, face.handle, precision, Int32(edgeIndex))
    }

    /// Check if a specific edge is degenerated (1-based).
    ///
    /// - Precondition: the wire's edges are in connection order, that is
    ///   ``checkOrder(wire:face:precision:)`` answers `false`. See ``SAWireAnalysis`` for why,
    ///   and for what this answers when they are not (#2906).
    public static func checkDegeneratedEdge(
        wire: Shape, face: Shape, precision: Double = 1e-6,
        edgeIndex: Int
    ) -> Bool {
        OCCTWireCheckDegeneratedEdge(wire.handle, face.handle, precision, Int32(edgeIndex))
    }

    /// Check 3D gap at a specific edge (1-based).
    ///
    /// - Precondition: the wire's edges are in connection order, that is
    ///   ``checkOrder(wire:face:precision:)`` answers `false`. See ``SAWireAnalysis`` for why,
    ///   and for what this answers when they are not (#2906).
    public static func checkGap3dEdge(
        wire: Shape, face: Shape, precision: Double = 1e-6,
        edgeIndex: Int
    ) -> Bool {
        OCCTWireCheckGap3dEdge(wire.handle, face.handle, precision, Int32(edgeIndex))
    }

    /// Check whether a wire fails to define an outer bound on a face, or `nil` when the check
    /// could not be run at all.
    ///
    /// Returns true if a problem is found, false if none is, and `nil` for five inputs the check
    /// cannot evaluate: a `Shape` that is not a wire or not a face, **a null shape included**; a
    /// wire with no edges; a wire whose edges do not assemble (#1058); a wire where **any** edge
    /// lacks a pcurve on the face, since `ShapeAnalysis::TotCross2D` would then sign an area only
    /// the pcurved subset contributed to; and a wire whose signed area cancels to rounding,
    /// tested as `|TotCross2D|` under `1e-12` of the face's own UV area (#1073). The other fourteen **check** members of this enum answer a plain `Bool`, so a
    /// refused call and a clean verdict are the same value for them; `edgeCount` and the four
    /// distance members return `Int`/`Double` and have their own version of that collision.
    /// Unlike every sibling above, this takes no precision, because
    /// `ShapeAnalysis_Wire::CheckOuterBound` consults none.
    ///
    /// ```swift
    /// let outer = SAWireAnalysis.checkOuterBound(wire: outerWire, face: face)   // false
    /// let inner = SAWireAnalysis.checkOuterBound(wire: holeWire, face: face)    // true
    /// let alien = SAWireAnalysis.checkOuterBound(wire: outerWire, face: cylinderFace)  // nil
    /// ```
    ///
    /// - Precondition: the wire's edges are in connection order, that is
    ///   ``checkOrder(wire:face:precision:)`` answers `false`. See ``SAWireAnalysis`` for why,
    ///   and for what this answers when they are not (#2906).
    public static func checkOuterBound(wire: Shape, face: Shape) -> Bool? {
        // Third copy of the bridge's 1/0/-1 decoder; #1077 has the census that decides whether it
        // becomes a shared helper, and which int32_t returns are eligible for one.
        switch OCCTWireCheckOuterBound(wire.handle, face.handle) {
        case 1: return true
        case 0: return false
        default: return nil
        }
    }
}
