import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.149 #83: Ordinate dimensioning

@Suite("v0.149 DrawingDimension.ordinate")
struct OrdinateDimensionTests {
    @Test("3-feature ordinate emits origin cross + X + Y extensions per feature")
    func threeFeatureEmits() {
        let writer = DXFWriter()
        writer.addDimension(
            .ordinate(
                .init(
                    origin: .zero,
                    features: [
                        .init(position: SIMD2(10, 0)),
                        .init(position: SIMD2(25, 5)),
                        .init(position: SIMD2(40, 15), label: "hole 3"),
                    ]
                )))
        // Origin cross = 2 lines.
        // Feature 1 (10, 0): dx only -> 2 lines (ext + tick), 1 text
        // Feature 2 (25, 5): dx + dy -> 4 lines, 2 texts
        // Feature 3 (40,15): dx + dy -> 4 lines, 2 texts
        // Total: 12 lines, 5 texts.
        #expect(writer.entityCounts.lines == 12)
        #expect(writer.entityCounts.texts == 5)
    }

    @Test("Empty features list emits only the origin cross")
    func emptyFeatures() {
        let writer = DXFWriter()
        writer.addDimension(.ordinate(.init(origin: SIMD2(5, 5), features: [])))
        #expect(writer.entityCounts.lines == 2)
        #expect(writer.entityCounts.texts == 0)
    }

    @Test("Ordinate applies tolerance to every feature label")
    func toleranceFlowsToFeatures() {
        let writer = DXFWriter()
        writer.addDimension(
            .ordinate(
                .init(
                    origin: .zero,
                    features: [.init(position: SIMD2(10, 0))],
                    tolerance: .symmetric(0.02)
                )))
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ord_tol.dxf")
        try? writer.write(to: url)
        let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        #expect(content.contains("±0.020"))
    }

    @Test("Ordinate transforms translate origin and every feature position")
    func transformedCase() {
        let d = DrawingDimension.ordinate(
            .init(
                origin: SIMD2(0, 0),
                features: [.init(position: SIMD2(10, 5))]
            ))
        let t = d.transformed(translate: SIMD2(100, 200), scale: 2)
        if case .ordinate(let ord) = t {
            #expect(ord.origin == SIMD2(100, 200))
            #expect(ord.features.first?.position == SIMD2(120, 210))
        } else {
            Issue.record("expected .ordinate case")
        }
    }

    @Test("Ordinate Codable round-trip")
    func codableRoundTrip() throws {
        let ord = DrawingDimension.Ordinate(
            origin: SIMD2(1, 2),
            features: [
                .init(position: SIMD2(10, 0), label: "x-only"),
                .init(position: SIMD2(25, 15), id: "f2"),
            ],
            tolerance: .bilateral(plus: 0.1, minus: 0.05),
            id: "ord-1"
        )
        let data = try JSONEncoder().encode(ord)
        let back = try JSONDecoder().decode(DrawingDimension.Ordinate.self, from: data)
        #expect(back == ord)
    }

    // MARK: - #1192: emitOrdinate's dx/dy blocks unified into one axis-generic helper
    //
    // Neither pre-existing fixture above isolates `dy != 0` with `dx == 0` (a feature directly
    // above/below the origin): `threeFeatureEmits`' own inline comment says so. That is exactly
    // the axis the refactor's `alongIsX: false` call site is responsible for, so a regression
    // confined to it (e.g. `alongIsX` flipped, or the `rotationDeg`/`stackOffset` pair swapped
    // between the two call sites in `emitOrdinate`) would pass every test above unnoticed.

    @Test("Y-only feature (dx == 0) draws only the Y leader/tick/text, isolated from the X block")
    func dyOnlyFeatureEmits() {
        let writer = DXFWriter()
        writer.addDimension(
            .ordinate(
                .init(
                    origin: SIMD2(100, 50),
                    features: [.init(position: SIMD2(100, 70))]
                )))
        // Origin cross = 2 lines. Feature (100, 70): dx == 0 (block skipped), dy == 20 ->
        // 2 lines (leader + tick), 1 text. Total: 4 lines, 1 text.
        #expect(writer.entityCounts.lines == 4)
        #expect(writer.entityCounts.texts == 1)
    }

    @Test("Feature exactly at the origin draws neither axis block")
    func featureAtOriginEmitsNeither() {
        let writer = DXFWriter()
        writer.addDimension(
            .ordinate(
                .init(
                    origin: SIMD2(10, 10),
                    features: [.init(position: SIMD2(10, 10))]
                )))
        #expect(writer.entityCounts.lines == 2)
        #expect(writer.entityCounts.texts == 0)
    }

    @Test("X and Y axis blocks draw exact, independently-verified geometry")
    func axisGeometryIsExact() throws {
        let writer = DXFWriter()
        // origin (100, 50), feature (130, 70) -> dx = 30, dy = 20, asymmetric on both axes so
        // a transposed coordinate (an `alongIsX` mixup) cannot coincidentally match.
        writer.addDimension(
            .ordinate(
                .init(
                    origin: SIMD2(100, 50),
                    features: [.init(position: SIMD2(130, 70))]
                )))
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ord_1192_axis_geometry.dxf")
        try writer.write(to: url)
        let content = try String(contentsOf: url, encoding: .utf8)

        func fmt(_ v: Double) -> String { String(format: "%.6f", v) }
        func linePair(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> String {
            "10\n\(fmt(a.x))\n20\n\(fmt(a.y))\n30\n0.000000\n"
                + "11\n\(fmt(b.x))\n21\n\(fmt(b.y))\n31\n0.000000\n"
        }
        func textPair(_ p: SIMD2<Double>, label: String, rotationDeg: Double) -> String {
            "10\n\(fmt(p.x))\n20\n\(fmt(p.y))\n30\n0.000000\n40\n3.500000\n"
                + "1\n\(label)\n50\n\(fmt(rotationDeg))\n"
        }

        // X block (dx = 30, alongIsX: true): leader (130, 50)->(130, 70); tick (130, 48)->
        // (130, 52); text "30.00" at (130, 45), rotated 90.
        #expect(content.contains(linePair(SIMD2(130, 50), SIMD2(130, 70))))
        #expect(content.contains(linePair(SIMD2(130, 48), SIMD2(130, 52))))
        #expect(content.contains(textPair(SIMD2(130, 45), label: "30.00", rotationDeg: 90)))

        // Y block (dy = 20, alongIsX: false): leader (100, 70)->(130, 70); tick (98, 70)->
        // (102, 70); text "20.00" at (95, 70), rotated 0.
        #expect(content.contains(linePair(SIMD2(100, 70), SIMD2(130, 70))))
        #expect(content.contains(linePair(SIMD2(98, 70), SIMD2(102, 70))))
        #expect(content.contains(textPair(SIMD2(95, 70), label: "20.00", rotationDeg: 0)))
    }
}
