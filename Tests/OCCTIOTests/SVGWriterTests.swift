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
}
