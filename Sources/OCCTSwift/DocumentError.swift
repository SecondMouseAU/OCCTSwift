import Foundation
import OCCTBridge
import simd

/// Errors that can occur when working with XDE documents.
public enum DocumentError: Error, LocalizedError {
    case loadFailed(url: URL)
    case writeFailed(url: URL)
    /// OCCT's STEP reader or writer refused the file, and this is the reason it gave (#1644).
    ///
    /// Thrown instead of ``loadFailed(url:)`` / ``writeFailed(url:)`` by the document entry
    /// points that run a reader or a writer, so a caller can tell a missing or unwritable path
    /// from a malformed file from an empty model. `status` is ``IOStatus/notReached`` when the
    /// step never ran.
    case exchangeFailed(url: URL, status: IOStatus)

    public var errorDescription: String? {
        switch self {
        case .loadFailed(let url):
            return "Failed to load STEP file: \(url.lastPathComponent)"
        case .writeFailed(let url):
            return "Failed to write STEP file: \(url.lastPathComponent)"
        case .exchangeFailed(let url, let status):
            return "STEP exchange failed for \(url.lastPathComponent): \(status)"
        }
    }
}
