import Foundation
import OCCTBridge
import simd

/// Evolution type for topological naming history.
public enum NamingEvolution: Int32, Sendable {
    /// Shape created from scratch (no predecessor).
    case primitive = 0
    /// Shape generated from another shape (e.g. face from edge extrusion).
    case generated = 1
    /// Shape modified (e.g. filleted edge).
    case modify = 2
    /// Shape deleted.
    case delete = 3
    /// Named selection for persistent identification.
    case selected = 4
}

/// A single entry in the naming history of a label.
public struct NamingHistoryEntry: Sendable {
    /// The type of evolution this entry represents.
    public let evolution: NamingEvolution
    /// Whether this entry has an old (input) shape.
    public let hasOldShape: Bool
    /// Whether this entry has a new (result) shape.
    public let hasNewShape: Bool
    /// Whether this is a modification operation.
    public let isModification: Bool
}
