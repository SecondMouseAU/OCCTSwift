import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.144 #75: Drawing.transformed + bounds

@Suite("v0.144 Drawing transform + bounds")
struct DrawingCompositionTests {
    @Test("Drawing.bounds returns finite box for a projected box")
    func drawingBounds() {
        guard let box = Shape.box(width: 100, height: 50, depth: 25),
            let front = Drawing.frontView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        let bounds = front.bounds()
        #expect(bounds != nil)
        if let b = bounds {
            #expect(b.min.x.isFinite && b.max.x.isFinite)
            #expect(b.max.x > b.min.x)
            // Finite and ordered held for any box, including one with x and y swapped. The
            // centred 100 x 50 x 25 box seen down +Y projects to x in [-12.5, 12.5] and
            // y in [-50, 50] in the projector's frame. Kernel values (HLRBRep_Algo on the same
            // box and projector) from Scripts/repro/766-math-drawing-eigen-solvers/transcript.txt.
            #expect(abs(b.min.x + 12.5) < 1e-6)
            #expect(abs(b.max.x - 12.5) < 1e-6)
            #expect(abs(b.min.y + 50) < 1e-6)
            #expect(abs(b.max.y - 50) < 1e-6)
        }
    }

    @Test("transformed(translate:scale:) returns non-nil wrapper")
    func transformedSmoke() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let top = Drawing.topView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        let transformed = top.transformed(translate: SIMD2(50, 30), scale: 0.5)
        #expect(transformed.translate == SIMD2(50, 30))
        #expect(transformed.scale == 0.5)
    }

    @Test("DXFWriter.collectFromDrawing accepts TransformedDrawing")
    func dxfFromTransformed() throws {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let top = Drawing.topView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        let t = top.transformed(translate: SIMD2(100, 100), scale: 2.0)
        let writer = DXFWriter()
        writer.collectFromDrawing(t)
        // At least some lines or polylines should have been emitted.
        let counts = writer.entityCounts
        #expect(counts.lines + counts.polylines > 0)
        // A count held with the transform dropped, so check where the geometry landed. The
        // centred 10 mm cube's top view spans [-5, 5] on both axes (kernel value from
        // Scripts/repro/766-math-drawing-eigen-solvers/transcript.txt); scale 2 then +100 puts it
        // at [90, 110]. Read the X coordinates (group codes 10 and 11) back out of the DXF.
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dxf-transformed-\(UUID().uuidString).dxf")
        defer { try? FileManager.default.removeItem(at: url) }
        try writer.write(to: url)
        let lines = try String(contentsOf: url, encoding: .utf8)
            .split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
        // Only the ENTITIES section: the header's extents also use group code 10.
        let start = lines.firstIndex(of: "ENTITIES") ?? lines.count
        var xs: [Double] = []
        for i in start..<max(start, lines.count - 1) where lines[i] == "10" || lines[i] == "11" {
            if let v = Double(lines[i + 1]) { xs.append(v) }
        }
        #expect(!xs.isEmpty)
        if let lo = xs.min(), let hi = xs.max() {
            #expect(abs(lo - 90) < 1e-6, "min x \(lo)")
            #expect(abs(hi - 110) < 1e-6, "max x \(hi)")
        }
    }
}

