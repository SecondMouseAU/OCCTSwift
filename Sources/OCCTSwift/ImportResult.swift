import Foundation
import OCCTBridge
import simd

public enum ImportError: Error, LocalizedError {
    case importFailed(String)
    /// The import was cancelled cooperatively via `ImportProgress.shouldCancel()`.
    case cancelled
    /// OCCT's reader rejected the file, and this is the reason it gave (#1644).
    ///
    /// Thrown instead of ``importFailed(_:)`` by every STEP and IGES loader that runs a reader,
    /// so a caller can tell "check the path" from "this CAD file is broken" from "the file
    /// parsed and holds nothing". `status` is ``IOStatus/notReached`` when the read never
    /// happened, which is what an unreadable path or a caught exception looks like.
    ///
    /// ```swift
    /// catch ImportError.readFailed(let path, .error) { /* not a STEP file */ }
    /// ```
    case readFailed(path: String, status: IOStatus)

    public var errorDescription: String? {
        switch self {
        case .importFailed(let message):
            return message
        case .cancelled:
            return "Import cancelled"
        case .readFailed(let path, let status):
            return "Failed to read \(path): \(status)"
        }
    }
}

/// Result of a robust STEP import with diagnostic information.
public struct ImportResult: Sendable {
    /// The imported and processed shape.
    public let shape: Shape

    /// Original shape type as read from STEP file.
    public let originalType: ShapeType

    /// Final shape type after processing.
    public let resultType: ShapeType

    /// Whether sewing was applied to connect disconnected faces.
    public let sewingApplied: Bool

    /// Whether a solid was created from a shell.
    public let solidCreated: Bool

    /// Whether shape healing was applied.
    public let healingApplied: Bool

    /// How many shells were turned into solids.
    ///
    /// `> 1` means the file held several bodies and ``shape`` is a compound of that many solids.
    /// Before v1.11.3 every body after the first was silently discarded, so this count is the fact
    /// that was quietly wrong — a truncated import still returned a perfectly valid solid (#302).
    public let solidsCreated: Int

    /// Human-readable summary of the import processing.
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
