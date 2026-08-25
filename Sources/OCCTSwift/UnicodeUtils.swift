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
    /// Convert from UTF-8 to current format.
    ///
    /// - Parameters:
    ///   - utf8Input: The UTF-8 string to convert.
    ///   - maxSize: Output buffer *capacity* in bytes (default 4096). If the converted string
    ///     exceeds this capacity, it will be truncated. Use a larger value or call without
    ///     maxSize to automatically allocate the full required buffer.
    /// - Returns: The converted string, or nil on failure.
    public static func convertFromUnicode(_ utf8Input: String, maxSize: Int = 4096) -> String? {
        guard maxSize > 0 else { return nil }
        let len = OCCTUnicodeConvertFromUnicode(utf8Input, nil, 0)
        guard len >= 0 else { return nil }
        let bufSize = Swift.min(Int(len) + 1, maxSize)
        var output = [CChar](repeating: 0, count: bufSize)
        let actualLen = OCCTUnicodeConvertFromUnicode(utf8Input, &output, Int32(bufSize))
        guard actualLen >= 0 else { return nil }
        // Ensure null-termination as a safeguard
        output[Int(len) < bufSize ? Int(len) : bufSize - 1] = 0
        return String(cString: output)
    }
}
