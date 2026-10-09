import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.150 #86: SVGWriter

@Suite("v0.150 SVGWriter")
struct SVGWriterTests {
    @Test("Empty SVG writes valid <svg> with viewBox")
    func emptySVG() throws {
        let writer = SVGWriter()
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("empty.svg")
        try writer.write(to: url)
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.hasPrefix("<?xml"))
        #expect(content.contains("<svg"))
        #expect(content.contains("viewBox="))
        #expect(content.contains("</svg>"))
    }

    @Test("Box front view SVG contains line elements")
    func boxFrontSVG() throws {
        guard let box = Shape.box(width: 10, height: 5, depth: 3),
            let front = Drawing.frontView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        let writer = SVGWriter()
        writer.collectFromDrawing(front)
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("box_front.svg")
        try writer.write(to: url)
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(
            content.contains("<line") || content.contains("<polyline")
                || content.contains("<polygon"))
    }

    @Test("Hidden layer carries stroke-dasharray attribute")
    func hiddenDashArray() throws {
        let writer = SVGWriter()
        writer.addLine(from: SIMD2(0, 0), to: SIMD2(10, 0), layer: "HIDDEN")
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("hidden.svg")
        try writer.write(to: url)
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("stroke-dasharray=\"3,2\""))
    }

    @Test("Arc emits native SVG A path command")
    func arcEmitsPath() throws {
        let writer = SVGWriter()
        writer.addArc(centre: .zero, radius: 5, startAngleDeg: 0, endAngleDeg: 90)
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("arc.svg")
        try writer.write(to: url)
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("<path"))
        #expect(content.contains(" A "))
    }

    @Test("Circle emits native <circle> element")
    func circleEmits() throws {
        let writer = SVGWriter()
        writer.addCircle(centre: SIMD2(10, 20), radius: 5)
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("circle.svg")
        try writer.write(to: url)
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("<circle"))
        #expect(content.contains("r=\"5"))
    }

    @Test("ViewBox respects caller override when supplied")
    func explicitViewBox() throws {
        let writer = SVGWriter(viewBox: (min: SIMD2(0, 0), size: SIMD2(420, 297)))
        writer.addLine(from: SIMD2(10, 10), to: SIMD2(20, 10))
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("vb.svg")
        try writer.write(to: url)
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("420"))
        #expect(content.contains("297"))
    }

    // MARK: - #1570: Y-flip transform must reflect about the viewBox's own midline

    /// Returns the raw text between `marker` and the next `"`, i.e. an XML attribute's
    /// quoted value, given the file already contains `marker` immediately after the
    /// opening quote (e.g. `marker == "viewBox=\""`).
    private static func quotedValue(after marker: String, in s: String) -> String? {
        guard let markerRange = s.range(of: marker) else { return nil }
        let rest = s[markerRange.upperBound...]
        guard let endQuote = rest.firstIndex(of: "\"") else { return nil }
        return String(rest[rest.startIndex..<endQuote])
    }

    /// Parses a leading numeric run (digits, `.`, `-`) starting right after `marker`.
    private static func firstDouble(after marker: String, in s: String) -> Double? {
        guard let markerRange = s.range(of: marker) else { return nil }
        let rest = s[markerRange.upperBound...]
        var numStr = ""
        for ch in rest {
            if ch.isNumber || ch == "." || ch == "-" {
                numStr.append(ch)
            } else {
                break
            }
        }
        return Double(numStr)
    }

    @Test(
        "Y-flip transform reflects about the viewBox's own midline, keeping content inside a non-zero-origin computed viewBox (#1570)"
    )
    func yFlipKeepsContentInsideComputedViewBox() throws {
        // No explicit viewBox -- exercises the computedViewBox() path, whose vb.min.y is
        // non-zero for content not centered at the origin (unlike the explicit-viewBox
        // overload, which always passes min: .zero and so could never surface this bug).
        // Numbers match the issue's own worked example: math-Y span [990, 1010], pad 5
        // -> viewBox y-range [985, 1015].
        let writer = SVGWriter()
        writer.addLine(from: SIMD2(0, 990), to: SIMD2(0, 1010), layer: "VISIBLE")
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("yflip_nonzero_origin.svg")
        try writer.write(to: url)
        let content = try String(contentsOf: url, encoding: .utf8)

        guard let vbStr = Self.quotedValue(after: "viewBox=\"", in: content) else {
            Issue.record("no viewBox attribute found in emitted SVG")
            return
        }
        let vbParts = vbStr.split(separator: " ").compactMap { Double($0) }
        guard vbParts.count == 4 else {
            Issue.record("viewBox attribute did not parse to 4 numbers: \(vbStr)")
            return
        }
        let vbMinY = vbParts[1]
        let vbSizeY = vbParts[3]
        #expect(abs(vbMinY - 985.0) < 1e-6)
        #expect(abs(vbSizeY - 30.0) < 1e-6)

        guard let transformStr = Self.quotedValue(after: "transform=\"", in: content),
            let ty = Self.firstDouble(after: "translate(0,", in: transformStr)
        else {
            Issue.record("no group transform found in emitted SVG")
            return
        }
        // The correct reflection is about the viewBox's own midline, ty = 2*vb.min.y +
        // vb.size.y, not merely vb.min.y + vb.size.y (#1570's missing term).
        let expectedTy = 2 * vbMinY + vbSizeY
        #expect(abs(ty - expectedTy) < 1e-6)

        guard let y1Str = Self.quotedValue(after: "y1=\"", in: content),
            let y2Str = Self.quotedValue(after: "y2=\"", in: content),
            let y1 = Double(y1Str), let y2 = Double(y2Str)
        else {
            Issue.record("no <line> y1/y2 found in emitted SVG")
            return
        }

        // Apply the SAME transform an SVG renderer applies -- parsed from the file, not
        // re-derived -- and confirm the transformed content actually lands inside the
        // declared viewBox, rather than trusting string containment.
        let transformedY1 = ty - y1
        let transformedY2 = ty - y2
        #expect(transformedY1 >= vbMinY && transformedY1 <= vbMinY + vbSizeY)
        #expect(transformedY2 >= vbMinY && transformedY2 <= vbMinY + vbSizeY)
    }
}
