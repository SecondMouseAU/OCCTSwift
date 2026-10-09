import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.149 #83: DrawingTolerance

@Suite("v0.149 DrawingTolerance")
struct ToleranceTests {
    @Test("Symmetric tolerance rendered inline on the nominal label")
    func symmetricInline() {
        let writer = DXFWriter()
        writer.addDimension(
            .linear(
                .init(
                    from: SIMD2(0, 0), to: SIMD2(10, 0),
                    tolerance: .symmetric(0.05))))
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tol_sym.dxf")
        try? writer.write(to: url)
        let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        #expect(content.contains("±0.050"))
        #expect(writer.entityCounts.texts == 1)
    }

    @Test("Bilateral tolerance produces stacked upper + lower TEXT entries")
    func bilateralStacked() {
        let baseline = DXFWriter()
        baseline.addDimension(.linear(.init(from: SIMD2(0, 0), to: SIMD2(10, 0))))
        let baselineTexts = baseline.entityCounts.texts

        let withTol = DXFWriter()
        withTol.addDimension(
            .linear(
                .init(
                    from: SIMD2(0, 0), to: SIMD2(10, 0),
                    tolerance: .bilateral(plus: 0.1, minus: 0.05))))
        #expect(withTol.entityCounts.texts == baselineTexts + 2)
    }

    @Test("Unilateral tolerance stacks signed value against a 0")
    func unilateralStacked() {
        let writer = DXFWriter()
        writer.addDimension(
            .diameter(
                .init(
                    centre: .zero, radius: 5,
                    tolerance: .unilateral(0.1))))
        #expect(writer.entityCounts.texts == 3)
    }

    @Test("Fit class appended inline with space")
    func fitClassInline() {
        let writer = DXFWriter()
        writer.addDimension(
            .linear(
                .init(
                    from: SIMD2(0, 0), to: SIMD2(10, 0),
                    tolerance: .fitClass("H7"))))
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tol_fit.dxf")
        try? writer.write(to: url)
        let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        #expect(content.contains(" H7"))
        #expect(writer.entityCounts.texts == 1)
    }

    @Test("Limits tolerance stacks upper over lower")
    func limitsStacked() {
        let writer = DXFWriter()
        writer.addDimension(
            .linear(
                .init(
                    from: SIMD2(0, 0), to: SIMD2(10, 0),
                    tolerance: .limits(lower: 9.95, upper: 10.05))))
        #expect(writer.entityCounts.texts == 3)
    }

    @Test("DrawingTolerance Codable round-trip")
    func codableRoundTrip() throws {
        let cases: [DrawingTolerance] = [
            .none,
            .symmetric(0.05),
            .bilateral(plus: 0.1, minus: 0.05),
            .unilateral(-0.1),
            .fitClass("g6"),
            .limits(lower: 9.95, upper: 10.05),
        ]
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for t in cases {
            let data = try encoder.encode(t)
            let back = try decoder.decode(DrawingTolerance.self, from: data)
            #expect(back == t)
        }
    }
}
