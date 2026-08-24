import Foundation

// MARK: - ISO drawing style conventions (#78 G1, v0.144)

/// ISO 128-20 standard line widths (mm).
///
/// Thin and thick are applied in a 1:2 ratio per line type. Values are the ISO geometric series — each tier ~1.4×
/// the previous — and are the only widths recognised by ISO-compliant readers.
public enum DrawingLineWidth: Double, Sendable, Hashable, CaseIterable {
    case w013 = 0.13
    case w018 = 0.18
    case w025 = 0.25
    case w035 = 0.35
    case w050 = 0.50
    case w070 = 0.70
    case w100 = 1.00
    case w140 = 1.40
    case w200 = 2.00

    /// The ISO-standard thin weight for general drawing features.
    public static let thin: DrawingLineWidth = .w025
    /// The ISO-standard thick weight (2× thin).
    public static let thick: DrawingLineWidth = .w050
}

extension DrawingLineStyle {
    /// ISO 128-20 default width for each line style.
    ///
    /// Consumers can override per-entity by setting `width` explicitly on the dimension/annotation.
    public var defaultWidth: DrawingLineWidth {
        switch self {
        case .solid: return .thin  // continuous thin (visible edges, extension lines)
        case .dashed: return .thin  // hidden edges
        case .chain: return .thin  // centerlines, axes, pitch lines
        case .phantom: return .thin  // alternative / adjacent positions
        case .dotted: return .thin  // bend lines, construction
        }
    }

    /// The bold counterpart (0.50 mm) for cutting-plane lines, section
    /// identifiers, and the visible-edge thickening that ISO 128 recommends
    /// for certain sheet sizes.
    public var boldWidth: DrawingLineWidth { .thick }
}

/// ISO 3098 text height series in mm.
///
/// Picking the right height scales dimension text and title-block text to the sheet size. Each tier is ~1.4× the
/// previous.
public enum DrawingTextHeight: Double, Sendable, Hashable, CaseIterable {
    case h25 = 2.5
    case h35 = 3.5
    case h50 = 5.0
    case h70 = 7.0
    case h100 = 10.0
    case h140 = 14.0
    case h200 = 20.0

    /// Recommended dimension-text height for a given paper size (ISO 5457).
    public static func recommended(forPaper paper: String) -> DrawingTextHeight {
        switch paper.uppercased() {
        case "A0", "A1": return .h50
        case "A2": return .h35
        case "A3", "A4": return .h35
        default: return .h35
        }
    }

    /// Snap an arbitrary height to the nearest ISO 3098 tier.
    public static func snap(_ mm: Double) -> DrawingTextHeight {
        DrawingTextHeight.allCases.min(by: { abs($0.rawValue - mm) < abs($1.rawValue - mm) })
            ?? .h35
    }
}

/// ISO 128-21 arrow conventions.
///
/// Filled closed is the ISO default; open 90° and open 30° are permitted variants. Arrow length is typically 3× the line
/// width, and width is typically 1/3 of the length.
public enum DrawingArrowStyle: String, Sendable, Hashable, Codable {
    case filledClosed  // solid triangle — ISO default
    case openClosed90  // stroked triangle with 90° included angle
    case openClosed30  // stroked triangle with 30° included angle (narrow)
    case tick  // 45° tick (architectural; not ISO default but common)

    /// Recommended arrow length in mm, given the dimension line's width.
    public func length(forLineWidth width: DrawingLineWidth) -> Double {
        width.rawValue * 6  // ISO 129 suggests 3-5× thin width; 6× thin gives ~1.5 mm at thin 0.25
    }
}

// MARK: - ISO 5455 standard scales

/// ISO 5455 preferred drawing scales.
///
/// The `ratio` is the ratio of drawing-unit to real-world-unit — `1/ratio` real units drawn as 1 drawing unit.
///
/// Use `.reduction(2)` for 1:2, `.enlargement(5)` for 5:1.
public enum DrawingScale: Sendable, Hashable {
    case one  // 1:1
    case reduction(Int)  // 1:N
    case enlargement(Int)  // N:1
    case custom(Double)  // any ratio

    /// Drawing-to-model scale factor.
    ///
    /// For 1:2 this is 0.5 (half size); for 5:1 this is 5.0 (5× enlargement).
    public var factor: Double {
        switch self {
        case .one: return 1.0
        case .reduction(let n): return 1.0 / Double(n)
        case .enlargement(let n): return Double(n)
        case .custom(let f): return f
        }
    }

    /// Human-readable label like "1:1", "1:2", "5:1".
    public var label: String {
        switch self {
        case .one: return "1:1"
        case .reduction(let n): return "1:\(n)"
        case .enlargement(let n): return "\(n):1"
        case .custom(let f): return String(format: "%.3g:1", f)
        }
    }

    /// ISO 5455 preferred values: 1:1, 1:2, 1:5, 1:10, 1:20, 1:50, 1:100,
    /// 1:200, 1:500, 1:1000, plus enlargements 2:1, 5:1, 10:1, 20:1, 50:1.
    public static var preferred: [DrawingScale] {
        [
            .enlargement(50), .enlargement(20), .enlargement(10),
            .enlargement(5), .enlargement(2),
            .one,
            .reduction(2), .reduction(5), .reduction(10),
            .reduction(20), .reduction(50), .reduction(100),
            .reduction(200), .reduction(500), .reduction(1000),
        ]
    }
}
