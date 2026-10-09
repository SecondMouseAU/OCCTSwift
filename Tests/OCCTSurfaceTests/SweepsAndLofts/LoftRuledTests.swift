import Testing

@testable import OCCTSwift

@Suite("Loft Ruled Mode")
struct LoftRuledTests {

    // #766: both profiles used to be `Wire.rectangle`, which lies at z = 0, so every loft here was
    // between two coplanar squares: the kernel returned a zero-volume "solid" and the tests
    // asserted only non-nil (and `isValid`, which BRepCheck grants that degenerate solid). The
    // sections now stand at different heights, and each test pins the kernel's result from
    // BRepOffsetAPI_ThruSections with the same flags (Scripts/repro/766-join-local-loft/).
    // `smoothVsRuled` also needed a third section: with exactly two, OCCT builds the smooth loft
    // with CreateRuled as well, so the two can never differ.
    private func square(_ width: Double, z: Double) -> Wire? {
        let h = width / 2
        return Wire.path(
            [SIMD3(-h, -h, z), SIMD3(h, -h, z), SIMD3(h, h, z), SIMD3(-h, h, z)], closed: true)
    }

    @Test("Ruled loft produces flat surfaces")
    func ruledLoft() {
        guard let w1 = square(10, z: 0), let w2 = square(5, z: 10) else {
            Issue.record("section wires")
            return
        }
        let ruled = Shape.loft(profiles: [w1, w2], solid: true, ruled: true)
        #expect(ruled != nil)
        if let r = ruled {
            #expect(r.isValid)
            // A square frustum: h/3 (A1 + A2 + sqrt(A1 A2)) = 10/3 (100 + 25 + 50).
            #expect(abs((r.volume ?? 0) - 583.33333333333337) < 1e-6)
            #expect(r.faceCount == 6)
        }
    }

    @Test("Smooth loft differs from ruled")
    func smoothVsRuled() {
        guard let w1 = square(10, z: 0), let w2 = square(5, z: 5), let w3 = square(10, z: 10) else {
            Issue.record("section wires")
            return
        }
        let ruled = Shape.loft(profiles: [w1, w2, w3], solid: true, ruled: true)
        let smooth = Shape.loft(profiles: [w1, w2, w3], solid: true, ruled: false)
        #expect(ruled != nil)
        #expect(smooth != nil)
        if let ruled, let smooth {
            // Ruled: two frusta, ten faces. Smooth: one waisted surface per side, six faces.
            #expect(abs((ruled.volume ?? 0) - 583.33333333333348) < 1e-6)
            #expect(ruled.faceCount == 10)
            #expect(abs((smooth.volume ?? 0) - 466.66666666666686) < 1e-6)
            #expect(smooth.faceCount == 6)
        }
    }

    @Test("Shell loft (non-solid)")
    func shellLoft() {
        guard let w1 = square(10, z: 0), let w2 = square(5, z: 10) else {
            Issue.record("section wires")
            return
        }
        let shell = Shape.loft(profiles: [w1, w2], solid: false, ruled: true)
        #expect(shell != nil)
        if let shell {
            // Four ruled sides, no caps: area 309.23 against the solid's 434.23.
            #expect(shell.shapeType == .shell)
            #expect(shell.faceCount == 4)
            #expect(abs((shell.surfaceArea ?? 0) - 309.23292192132453) < 1e-6)
        }
    }
}
