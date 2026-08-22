import Foundation
import OCCTBridge
import simd

/// Length unit information from a document.
public struct LengthUnit: Sendable {
    /// Scale factor (e.g., 1.0 for mm, 25.4 for inch)
    public let scale: Double
    /// Unit name (e.g., "mm", "inch", "m")
    public let name: String
}
