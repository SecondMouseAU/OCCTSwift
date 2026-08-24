import Foundation
import OCCTBridge

/// System font manager wrapping OCCT Font_FontMgr.
///
/// Provides access to system fonts registered by OCCT.
public enum FontManager: Sendable {
    /// Font aspect (style).
    public enum FontAspect: Int32, Sendable {
        case regular = 0
        case bold = 1
        case italic = 2
        case boldItalic = 3

        /// String representation.
        public var name: String {
            String(cString: OCCTFontMgrAspectToString(rawValue))
        }
    }

    /// Initialize the system font database.
    ///
    /// Call this before querying fonts.
    public static func initDatabase() {
        OCCTFontMgrInitDatabase()
    }

    /// Number of available system fonts.
    public static var fontCount: Int {
        Int(OCCTFontMgrFontCount())
    }

    /// Get font name by 0-based index.
    ///
    /// - Parameter index: The 0-based font index.
    /// - Returns: The font name, or `nil` if the index is out of range.
    public static func fontName(at index: Int) -> String? {
        guard let cStr = OCCTFontMgrFontName(Int32(index)) else { return nil }
        let result = String(cString: cStr)
        OCCTGeomToolsFreeString(UnsafeMutablePointer(mutating: cStr))
        return result
    }

    /// Get font file path for a given font index and aspect.
    ///
    /// - Parameters:
    ///   - index: The 0-based font index.
    ///   - aspect: The font aspect (style). Defaults to `.regular`.
    /// - Returns: The font file path, or `nil` if the index is out of range.
    public static func fontPath(at index: Int, aspect: FontAspect = .regular) -> String? {
        guard let cStr = OCCTFontMgrFontPath(Int32(index), aspect.rawValue) else { return nil }
        let result = String(cString: cStr)
        OCCTGeomToolsFreeString(UnsafeMutablePointer(mutating: cStr))
        return result
    }

    /// Check if font at index has a specific aspect.
    ///
    /// - Parameters:
    ///   - index: The 0-based font index.
    ///   - aspect: The font aspect to check.
    /// - Returns: `true` if the font has the specified aspect, `false` otherwise.
    public static func fontHasAspect(at index: Int, aspect: FontAspect) -> Bool {
        OCCTFontMgrFontHasAspect(Int32(index), aspect.rawValue)
    }

    /// Get all available font names.
    ///
    /// - Returns: An array of all font names.
    public static var allFontNames: [String] {
        let count = fontCount
        var names: [String] = []
        names.reserveCapacity(count)
        for i in 0..<count {
            if let name = fontName(at: i) {
                names.append(name)
            }
        }
        return names
    }
}
