import Foundation
import simd
import OCCTBridge

/// Recognized canonical geometric form.
public struct CanonicalForm: Sendable {
    /// Type of the recognized form.
    public enum FormType: Int32, Sendable {
        case unknown = 0
        case plane = 1
        case cylinder = 2
        case cone = 3
        case sphere = 4
        case line = 5
        case circle = 6
        case ellipse = 7
    }

    public let type: FormType
    public let origin: SIMD3<Double>
    public let direction: SIMD3<Double>
    public let radius: Double
    public let radius2: Double
    public let gap: Double
}
