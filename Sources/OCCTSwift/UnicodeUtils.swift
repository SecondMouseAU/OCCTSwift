import Foundation
import OCCTBridge
import simd

/// Unicode format for Resource_Unicode.
public enum UnicodeFormat: Int32, Sendable {
    case sjis = 0
    case euc = 1
    case gb = 2
    case ansi = 3
}

/// Resource_Unicode utilities.
public enum UnicodeUtils {
    /// Set the global Unicode format.
    public static func setFormat(_ format: UnicodeFormat) {
        OCCTUnicodeSetFormat(format.rawValue)
    }

    /// Get the current Unicode format.
    public static var format: UnicodeFormat {
        UnicodeFormat(rawValue: OCCTUnicodeGetFormat()) ?? .ansi
    }

    /// Convert a string to Unicode (UTF-8 output).
    public static func convertToUnicode(_ input: String) -> String? {
        guard let ptr = OCCTUnicodeConvertToUnicode(input) else { return nil }
        defer { free(ptr) }
        return String(cString: ptr)
    }

    /// Convert from UTF-8 to current format.
    ///
    /// - Parameters:
    ///   - utf8Input: The UTF-8 string to convert.
    ///   - maxSize: Output buffer *capacity* in bytes (default 4096), clamped into
    ///     `0...` ``Sampling/maximumSampleCount``; 0 or less returns `nil` (#622).
    /// - Returns: The converted string, or nil on failure.
    public static func convertFromUnicode(_ utf8Input: String, maxSize: Int = 4096) -> String? {
        let maxSize = Sampling.capacity(maxSize)
        guard maxSize > 0 else { return nil }
        var output = [CChar](repeating: 0, count: maxSize)
        guard OCCTUnicodeConvertFromUnicode(utf8Input, &output, Int32(maxSize)) else { return nil }
        let result = output.withUnsafeBufferPointer { buf in
            String(cString: buf.baseAddress!)
        }
        return result
    }
}
