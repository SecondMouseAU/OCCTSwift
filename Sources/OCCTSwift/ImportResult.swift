import Foundation
import OCCTBridge
import simd

public enum ImportError: Error, LocalizedError {
    case importFailed(String)
    /// The import was cancelled cooperatively via `ImportProgress.shouldCancel()`.
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .importFailed(let message):
            return message
        case .cancelled:
            return "Import cancelled"
        }
    }
}

/// Result of a robust STEP import with diagnostic information
public struct ImportResult: Sendable {
    /// The imported and processed shape
    public let shape: Shape

    /// Original shape type as read from STEP file
    public let originalType: ShapeType

    /// Final shape type after processing
    public let resultType: ShapeType

    /// Whether sewing was applied to connect disconnected faces
    public let sewingApplied: Bool

    /// Whether a solid was created from a shell
    public let solidCreated: Bool

    /// Whether shape healing was applied
    public let healingApplied: Bool

    /// How many shells were turned into solids.
    ///
    /// `> 1` means the file held several bodies and ``shape`` is a compound of that many solids.
    /// Before v1.11.3 every body after the first was silently discarded, so this count is the fact
    /// that was quietly wrong — a truncated import still returned a perfectly valid solid (#302).
    public let solidsCreated: Int

    /// Human-readable summary of the import processing
    public var summary: String {
        var steps: [String] = []
        if sewingApplied { steps.append("sewing") }
        if solidCreated {
            steps.append(
                solidsCreated > 1 ? "solid creation (\(solidsCreated) bodies)" : "solid creation")
        }
        if healingApplied { steps.append("healing") }
        let processing = steps.isEmpty ? "none" : steps.joined(separator: ", ")
        return "\(originalType) → \(resultType) (processing: \(processing))"
    }
}
