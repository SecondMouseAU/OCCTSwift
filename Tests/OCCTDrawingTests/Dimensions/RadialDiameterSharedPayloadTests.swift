import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - #1185: DrawingDimension.Radial/.Diameter share one `Circular` payload struct

/// Covers all six switch sites #1185 flagged as hand-duplicated `.radial`/`.diameter`
/// arms (`id`, `label`, `value`, `transformed`, `keyPoints`, `Drawing.add*Dimension`),
/// plus the two the audit found with zero direct coverage at all (`keyPoints`, and
/// `transformed` for `.diameter` specifically -- only `.radial` had a test, in
/// `DrawingTransformUnificationTests` above).
@Suite("#1185 DrawingDimension.Radial/.Diameter share Circular")
struct RadialDiameterSharedPayloadTests {
    @Test("DrawingDimension.value: .radial reports radius, .diameter reports 2*radius")
    func valueFormulaDivergesPerCase() {
        let radial = DrawingDimension.radial(.init(centre: .zero, radius: 7))
        let diameter = DrawingDimension.diameter(.init(centre: .zero, radius: 7))
        #expect(radial.value == 7)
        #expect(diameter.value == 14)
    }

    @Test("DrawingDimension.id/.label read through for both .radial and .diameter")
    func idAndLabelReadThroughForBothCases() {
        let radial = DrawingDimension.radial(
            .init(centre: .zero, radius: 3, label: "Rlabel", id: "rid"))
        let diameter = DrawingDimension.diameter(
            .init(centre: .zero, radius: 3, label: "Dlabel", id: "did"))
        #expect(radial.id == "rid")
        #expect(radial.label == "Rlabel")
        #expect(diameter.id == "did")
        #expect(diameter.label == "Dlabel")
    }

    @Test("DrawingDimension.transformed applies scale*p+translate for .diameter")
    func diameterDimensionTransform() {
        // .radial's own equivalent (`radialDimensionTransform`) lives in
        // DrawingTransformUnificationTests above (#1183); .diameter had no direct
        // test at all before #1185.
        let d = DrawingDimension.diameter(.init(centre: SIMD2(5, 5), radius: 2))
        let t = d.transformed(translate: SIMD2(1, 1), scale: 4)
        if case .diameter(let dia) = t {
            #expect(dia.centre == SIMD2(21, 21))
            #expect(dia.radius == 8)
        } else {
            Issue.record("expected .diameter case")
        }
    }

    @Test("DrawingDimension.keyPoints for .radial and .diameter (previously untested)")
    func keyPointsForBothCircularCases() {
        let radial = DrawingDimension.radial(.init(centre: SIMD2(10, 20), radius: 5))
        let diameter = DrawingDimension.diameter(.init(centre: SIMD2(10, 20), radius: 5))
        let expected = [SIMD2(10.0, 20.0), SIMD2(15.0, 20.0), SIMD2(5.0, 20.0)]
        #expect(radial.keyPoints == expected)
        #expect(diameter.keyPoints == expected)
    }

    @Test("Drawing.addRadialDimension/addDiameterDimension route through Circular correctly")
    func addRadialAndDiameterDimensionFieldParity() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let drawing = Drawing.topView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        let radial = drawing.addRadialDimension(
            centre: SIMD2(1, 2), radius: 4, leaderAngle: .pi / 6,
            label: "Rlbl", id: "rid")
        let diameter = drawing.addDiameterDimension(
            centre: SIMD2(3, 4), radius: 6, leaderAngle: .pi / 3,
            label: "Dlbl", id: "did")

        guard case .radial(let r) = radial, case .diameter(let d) = diameter else {
            Issue.record("addRadialDimension/addDiameterDimension returned the wrong case")
            return
        }
        #expect(r.centre == SIMD2(1, 2))
        #expect(r.radius == 4)
        #expect(r.leaderAngle == .pi / 6)
        #expect(r.label == "Rlbl")
        #expect(r.id == "rid")
        #expect(radial.value == 4)

        #expect(d.centre == SIMD2(3, 4))
        #expect(d.radius == 6)
        #expect(d.leaderAngle == .pi / 3)
        #expect(d.label == "Dlbl")
        #expect(d.id == "did")
        #expect(diameter.value == 12)

        #expect(drawing.dimensions.count == 2)
    }
}
