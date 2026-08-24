import Foundation
import OCCTBridge
import simd

/// Material information from a document.
public struct MaterialInfo: Sendable {
    /// Material name.
    public let name: String
    /// Material description.
    public let description: String
    /// Material density.
    public let density: Double
}
