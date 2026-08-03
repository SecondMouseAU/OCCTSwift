import Foundation
import simd
import OCCTBridge

/// Value-type wrapper for XCAFPrs_Style — visual presentation style.
public struct PresentationStyle: Sendable {
    /// Surface color (RGB).
    public var surfaceColor: (red: Double, green: Double, blue: Double)?
    /// Surface alpha.
    public var surfaceAlpha: Float
    /// Curve color (RGB).
    public var curveColor: (red: Double, green: Double, blue: Double)?
    /// Whether the style is visible.
    public var isVisible: Bool

    /// Create an empty style.
    public init() {
        self.surfaceColor = nil
        self.surfaceAlpha = 1.0
        self.curveColor = nil
        self.isVisible = true
    }

    /// Create a style with a surface color.
    public init(surfaceRed: Double, surfaceGreen: Double, surfaceBlue: Double, surfaceAlpha: Float = 1.0) {
        self.surfaceColor = (surfaceRed, surfaceGreen, surfaceBlue)
        self.surfaceAlpha = surfaceAlpha
        self.curveColor = nil
        self.isVisible = true
    }

    /// Whether the style is empty (no colors set, visible).
    public var isEmpty: Bool {
        let s = toOCCT()
        return s.isEmpty
    }

    /// Check equality with another style.
    public func isEqual(to other: PresentationStyle) -> Bool {
        var s1 = toOCCT()
        var s2 = other.toOCCT()
        return OCCTXCAFPrsStyleIsEqual(&s1, &s2)
    }

    private func toOCCT() -> OCCTXCAFPrsStyle {
        if let sc = surfaceColor, let cc = curveColor {
            return OCCTXCAFPrsStyleCreateFull(sc.red, sc.green, sc.blue, surfaceAlpha,
                                               cc.red, cc.green, cc.blue, isVisible)
        } else if let sc = surfaceColor {
            var s = OCCTXCAFPrsStyleCreateWithSurfColor(sc.red, sc.green, sc.blue, surfaceAlpha)
            s.isVisible = isVisible
            return s
        } else {
            var s = OCCTXCAFPrsStyleCreate()
            s.isVisible = isVisible
            return s
        }
    }
}
