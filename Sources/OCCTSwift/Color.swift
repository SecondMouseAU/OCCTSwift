import Foundation
import OCCTBridge

#if canImport(CoreGraphics)
    import CoreGraphics
#endif

/// RGBA color for XDE document support.
public struct Color: Sendable, Equatable, Hashable {
    /// Red component (0.0-1.0).
    public var red: Double

    /// Green component (0.0-1.0).
    public var green: Double

    /// Blue component (0.0-1.0).
    public var blue: Double

    /// Alpha component (0.0-1.0, where 1.0 is fully opaque).
    public var alpha: Double

    /// Create a color with RGBA components.
    public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Create a color from RGB values (0-255 range).
    public init(red255: Int, green255: Int, blue255: Int, alpha255: Int = 255) {
        self.red = Double(red255) / 255.0
        self.green = Double(green255) / 255.0
        self.blue = Double(blue255) / 255.0
        self.alpha = Double(alpha255) / 255.0
    }

    #if canImport(CoreGraphics)
        /// Convert to CGColor.
        public var cgColor: CGColor {
            CGColor(red: red, green: green, blue: blue, alpha: alpha)
        }

        /// Create from CGColor.
        public init?(_ cgColor: CGColor) {
            guard let components = cgColor.components, components.count >= 3 else {
                return nil
            }
            self.red = Double(components[0])
            self.green = Double(components[1])
            self.blue = Double(components[2])
            self.alpha = components.count >= 4 ? Double(components[3]) : 1.0
        }
    #endif

    // MARK: - Predefined Colors

    /// Black color.
    public static let black = Color(red: 0, green: 0, blue: 0)

    /// White color.
    public static let white = Color(red: 1, green: 1, blue: 1)

    /// Red color.
    public static let red = Color(red: 1, green: 0, blue: 0)

    /// Green color.
    public static let green = Color(red: 0, green: 1, blue: 0)

    /// Blue color.
    public static let blue = Color(red: 0, green: 0, blue: 1)

    /// Gray color (50%).
    public static let gray = Color(red: 0.5, green: 0.5, blue: 0.5)

    /// Clear (fully transparent).
    public static let clear = Color(red: 0, green: 0, blue: 0, alpha: 0)

    // MARK: - OCCT Color Operations (Quantity_Color / Quantity_ColorRGBA)

    /// HLS (Hue-Lightness-Saturation) color components.
    public struct HLS: Sendable, Equatable {
        public var hue: Double
        public var lightness: Double
        public var saturation: Double
    }

    /// CIE Lab color components.
    public struct Lab: Sendable, Equatable {
        public var l: Double
        public var a: Double
        public var b: Double
    }

    /// Create a color from a named OCCT color (e.g., "RED", "BLUE", "GOLD").
    public static func fromName(_ name: String) -> Color? {
        var r: Double = 0
        var g: Double = 0
        var b: Double = 0
        guard OCCTColorFromName(name, &r, &g, &b) else { return nil }
        return Color(red: r, green: g, blue: b)
    }

    /// Create a color from a hex string (e.g., "#FF0000").
    public static func fromHex(_ hex: String) -> Color? {
        var r: Double = 0
        var g: Double = 0
        var b: Double = 0
        guard OCCTColorFromHex(hex, &r, &g, &b) else { return nil }
        return Color(red: r, green: g, blue: b)
    }

    /// Create an RGBA color from a hex string with alpha (e.g., "#FF000080").
    public static func fromHexRGBA(_ hex: String) -> Color? {
        var r: Double = 0
        var g: Double = 0
        var b: Double = 0
        var a: Double = 0
        guard OCCTColorRGBAFromHex(hex, &r, &g, &b, &a) else { return nil }
        return Color(red: r, green: g, blue: b, alpha: a)
    }

    /// Convert to a 6-digit hex string (e.g. `"#FF0000"`).
    ///
    /// OCCT's `Quantity_Color::ColorToHex` always gamma-encodes this color's linear RGB to sRGB
    /// before formatting; there is no linear-output mode. `includeHashPrefix` controls only
    /// whether the result is prefixed with `#`.
    ///
    /// ```swift
    /// let hex = Color.red.toHex()                          // "#FF0000"
    /// let noPrefix = Color.red.toHex(includeHashPrefix: false)  // "FF0000"
    /// ```
    public func toHex(includeHashPrefix: Bool = true) -> String? {
        guard let cStr = OCCTColorToHex(red, green, blue, includeHashPrefix) else { return nil }
        let result = String(cString: cStr)
        OCCTGeomToolsFreeString(UnsafeMutablePointer(mutating: cStr))
        return result
    }

    /// Convert to an 8-digit RGBA hex string (e.g. `"#FF00007F"`).
    ///
    /// OCCT's `Quantity_ColorRGBA::ColorToHex` always gamma-encodes this color's linear RGB to
    /// sRGB before formatting; there is no linear-output mode. `includeHashPrefix` controls only
    /// whether the result is prefixed with `#`.
    ///
    /// ```swift
    /// let semi = Color(red: 1, green: 0, blue: 0, alpha: 0.5)
    /// let hex = semi.toHexRGBA()  // "#FF00007F"
    /// ```
    public func toHexRGBA(includeHashPrefix: Bool = true) -> String? {
        guard let cStr = OCCTColorRGBAToHex(red, green, blue, alpha, includeHashPrefix) else {
            return nil
        }
        let result = String(cString: cStr)
        OCCTGeomToolsFreeString(UnsafeMutablePointer(mutating: cStr))
        return result
    }

    /// Euclidean distance to another color in linear RGB space.
    public func distance(to other: Color) -> Double {
        OCCTColorDistance(red, green, blue, other.red, other.green, other.blue)
    }

    /// Square distance to another color in linear RGB space.
    public func squareDistance(to other: Color) -> Double {
        OCCTColorSquareDistance(red, green, blue, other.red, other.green, other.blue)
    }

    /// CIE DeltaE2000 perceptual color difference.
    public func deltaE2000(to other: Color) -> Double {
        OCCTColorDeltaE2000(red, green, blue, other.red, other.green, other.blue)
    }

    /// Get HLS (Hue-Lightness-Saturation) representation.
    public var hls: HLS {
        let result = OCCTColorToHLS(red, green, blue)
        return HLS(hue: result.hue, lightness: result.lightness, saturation: result.saturation)
    }

    /// Create a color from HLS values.
    public static func fromHLS(hue: Double, lightness: Double, saturation: Double) -> Color {
        var r: Double = 0
        var g: Double = 0
        var b: Double = 0
        OCCTColorFromHLS(hue, lightness, saturation, &r, &g, &b)
        return Color(red: r, green: g, blue: b)
    }

    /// Return a new color with modified intensity (lightness delta).
    public func withIntensityChanged(by delta: Double) -> Color {
        var r = red
        var g = green
        var b = blue
        OCCTColorChangeIntensity(&r, &g, &b, delta)
        return Color(red: r, green: g, blue: b, alpha: alpha)
    }

    /// Return a new color with modified contrast (saturation percentage delta).
    public func withContrastChanged(by delta: Double) -> Color {
        var r = red
        var g = green
        var b = blue
        OCCTColorChangeContrast(&r, &g, &b, delta)
        return Color(red: r, green: g, blue: b, alpha: alpha)
    }

    /// Convert linear RGB to sRGB.
    public var sRGB: Color {
        var outR: Float = 0
        var outG: Float = 0
        var outB: Float = 0
        OCCTColorLinearToSRGB(Float(red), Float(green), Float(blue), &outR, &outG, &outB)
        return Color(red: Double(outR), green: Double(outG), blue: Double(outB), alpha: alpha)
    }

    /// Convert sRGB to linear RGB.
    public var linearRGB: Color {
        var outR: Float = 0
        var outG: Float = 0
        var outB: Float = 0
        OCCTColorSRGBToLinear(Float(red), Float(green), Float(blue), &outR, &outG, &outB)
        return Color(red: Double(outR), green: Double(outG), blue: Double(outB), alpha: alpha)
    }

    /// Convert to CIE Lab color space.
    public var lab: Lab {
        let result = OCCTColorToLab(red, green, blue)
        return Lab(l: result.l, a: result.a, b: result.b)
    }

    /// Get name of a named color by index (0-based).
    ///
    /// Returns nil if the index is out of range.
    public static func namedColorName(at index: Int) -> String? {
        guard let cStr = OCCTColorStringName(Int32(index)) else { return nil }
        let result = String(cString: cStr)
        OCCTGeomToolsFreeString(UnsafeMutablePointer(mutating: cStr))
        return result
    }

    /// Color comparison epsilon.
    public static var epsilon: Double {
        OCCTColorEpsilon()
    }
}

extension Color {

    /// The total number of named colors available in OCCT.
    public static var namedColorCount: Int { Int(OCCTNamedColorCount()) }
}
