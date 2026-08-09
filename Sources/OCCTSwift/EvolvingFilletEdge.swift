import Foundation
import simd
import OCCTBridge

/// Describes an evolving radius along an edge for filleting.
///
/// The radius follows the `radiusPoints` law, whose parameters are *relative*: 0.0 is the start of
/// the edge and 1.0 its end, the same convention ``Shape/filletedVariable(edgeIndex:radiusProfile:)``
/// uses. Every radius must be positive, and the parameters must lie in `0...1` and strictly
/// increase, or ``Shape/filletEvolving(_:)`` returns `nil`.
///
/// ```swift
/// let box = Shape.box(width: 20, height: 20, depth: 20)!
/// let spec = EvolvingFilletEdge(edge: box.edges()[0],
///                               radiusPoints: [(0.0, 1.0), (1.0, 3.0)])
/// let tapered = box.filletEvolving([spec])
/// ```
///
/// > Note: OCCT stretches the law across the whole edge. With one or two points the parameters are
/// > ignored entirely (a single point is a constant radius); with three or more only the *relative*
/// > spacing of the interior points survives, because OCCT renormalises the first parameter to 0
/// > and the last to 1. A profile cannot fillet part of an edge and leave the rest alone.
public struct EvolvingFilletEdge: Sendable {
    /// 0-based index of the edge to fillet, as reported by ``Edge/index``.
    ///
    /// This was 1-based until #520, the one edge index in the fillet family that was. It now
    /// matches ``Edge/index``, ``Shape/filletedVariable(edgeIndex:radiusProfile:)`` and
    /// ``Shape/blendedEdges(_:)``.
    public var edgeIndex: Int
    /// Array of (parameter, radius) pairs defining the radius evolution along the edge.
    public var radiusPoints: [(parameter: Double, radius: Double)]

    /// Fillet `edge` with an evolving radius.
    ///
    /// - Parameters:
    ///   - edge: The edge to fillet; it must belong to the shape being filleted, since only its
    ///     ``Edge/index`` is carried across.
    ///   - radiusPoints: The radius law, as (relative parameter, radius) pairs.
    public init(edge: Edge, radiusPoints: [(parameter: Double, radius: Double)]) {
        self.edgeIndex = edge.index
        self.radiusPoints = radiusPoints
    }

    /// Unavailable: this initializer took a **1-based** edge index, and `edgeIndex` is now 0-based.
    ///
    /// Passing the same numbers to a 0-based API would fillet the neighbouring edge without any
    /// diagnostic, so the spelling was retired rather than reinterpreted. Build the spec from the
    /// `Edge` itself — `EvolvingFilletEdge(edge: shape.edges()[0], radiusPoints: …)` — or, if you
    /// only hold an index, construct from any edge and assign ``edgeIndex`` (0-based).
    @available(*, unavailable, message: """
        edgeIndex was 1-based and is now 0-based (#520). Use init(edge:radiusPoints:) with the Edge \
        itself, or assign the 0-based edgeIndex property, after re-checking the index you pass.
        """)
    public init(edgeIndex: Int, radiusPoints: [(parameter: Double, radius: Double)]) {
        self.edgeIndex = edgeIndex
        self.radiusPoints = radiusPoints
    }
}
