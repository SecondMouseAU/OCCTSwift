import Foundation
import OCCTBridge
import simd

// The platform C library, named because this file uses it directly (free, sin, cos, sqrt and
// the like). `import Foundation` happens to re-export it on Apple platforms, so these were in
// scope by accident rather than by declaration; FoundationEssentials does not, which is how
// #2761 found them. Naming it here is correct independently of that work.
#if canImport(Darwin)
    import Darwin
#elseif canImport(WASILibc)
    import WASILibc
#elseif canImport(Glibc)
    import Glibc
#endif

/// Directory iteration utilities using OSD_DirectoryIterator.
public enum DirectoryIterator {
    /// Count directories matching a mask in a path.
    public static func count(path: String, mask: String = "*") -> Int {
        Int(OCCTDirectoryIteratorCount(path, mask))
    }

    /// Get directory name at index from directory listing.
    public static func name(path: String, mask: String = "*", index: Int) -> String? {
        guard let cStr = OCCTDirectoryIteratorName(path, mask, Int32(index)) else { return nil }
        let result = String(cString: cStr)
        free(cStr)
        return result
    }

    /// List directory names matching mask.
    ///
    /// - Parameters:
    ///   - path: The directory path to list.
    ///   - mask: File mask pattern (default "*").
    ///   - maxCount: Output *capacity* (default 1000), clamped into `0...`
    ///     ``Sampling/maximumSampleCount``; 0 or less returns empty (#622).
    /// - Returns: Array of directory names.
    public static func list(path: String, mask: String = "*", maxCount: Int = 1000) -> [String] {
        let maxCount = Sampling.capacity(maxCount)
        guard maxCount > 0 else { return [] }
        var names = [UnsafeMutablePointer<CChar>?](repeating: nil, count: maxCount)
        let count = Int(OCCTDirectoryList(path, mask, &names, Int32(maxCount)))
        var result: [String] = []
        for i in 0..<count {
            if let cStr = names[i] {
                result.append(String(cString: cStr))
                free(cStr)
            }
        }
        return result
    }
}

/// File iteration utilities using OSD_FileIterator.
public enum FileIterator {
    /// Count files matching a mask in a path.
    public static func count(path: String, mask: String = "*") -> Int {
        Int(OCCTFileIteratorCount(path, mask))
    }

    /// Get file name at index from file listing.
    public static func name(path: String, mask: String = "*", index: Int) -> String? {
        guard let cStr = OCCTFileIteratorName(path, mask, Int32(index)) else { return nil }
        let result = String(cString: cStr)
        free(cStr)
        return result
    }

    /// List file names matching mask.
    ///
    /// - Parameters:
    ///   - path: The directory path to list.
    ///   - mask: File mask pattern (default "*").
    ///   - maxCount: Output *capacity* (default 1000), clamped into `0...`
    ///     ``Sampling/maximumSampleCount``; 0 or less returns empty (#622).
    /// - Returns: Array of file names.
    public static func list(path: String, mask: String = "*", maxCount: Int = 1000) -> [String] {
        let maxCount = Sampling.capacity(maxCount)
        guard maxCount > 0 else { return [] }
        var names = [UnsafeMutablePointer<CChar>?](repeating: nil, count: maxCount)
        let count = Int(OCCTFileList(path, mask, &names, Int32(maxCount)))
        var result: [String] = []
        for i in 0..<count {
            if let cStr = names[i] {
                result.append(String(cString: cStr))
                free(cStr)
            }
        }
        return result
    }
}
