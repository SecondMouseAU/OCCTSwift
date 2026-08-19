import Foundation
import simd
import OCCTBridge

/// Errors that can occur when working with XDE documents
public enum DocumentError: Error, LocalizedError {
    case loadFailed(url: URL)
    case writeFailed(url: URL)
    case cycleDetected

    public var errorDescription: String? {
        switch self {
        case .loadFailed(let url):
            return "Failed to load STEP file: \(url.lastPathComponent)"
        case .writeFailed(let url):
            return "Failed to write STEP file: \(url.lastPathComponent)"
        case .cycleDetected:
            return "Cycle detected in assembly tree during item count"
        }
    }
}
