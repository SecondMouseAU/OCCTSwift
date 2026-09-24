import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Geom2dLProp Curvature Analysis") struct Geom2dLPropTests {
    @Test("Curvature extrema on ellipse")
    func ellipseCurvatureExtrema() throws {
        let ellipse = Curve2D.ellipse(center: SIMD2(0, 0), majorRadius: 10, minorRadius: 5)
        // #1979: `count >= 1` inside `if let`. GeomLProp_CurAndInf2d gives four, alternating
        // minimum and maximum curvature at 0, pi/2, pi, 3pi/2 (Scripts/repro/766-geom2d-conic-props-sine-lprop/).
        let e = try #require(ellipse)
        let extrema = e.curvatureExtremaDetailed()
        try #require(extrema.count == 4)
        #expect(extrema.map(\.type) == [.curvatureMinimum, .curvatureMaximum, .curvatureMinimum, .curvatureMaximum])
        #expect(abs(extrema[1].parameter - .pi / 2) < 1e-9)
    }

    @Test("Inflection points on S-curve")
    func inflectionPointsDetailed() throws {
        // Create a BSpline with inflection by interpolating an S-shape
        let points: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(3, 10), SIMD2(7, -10), SIMD2(10, 0),
        ]
        let curve = Curve2D.interpolate(through: points)
        // #1979: `count >= 0` held for every result. This S-curve has exactly one inflection, at
        // u = 20.6383455361.
        let c = try #require(curve)
        let inflections = c.inflectionPointsDetailed()
        try #require(inflections.count == 1)
        #expect(inflections[0].type == .inflection)
        #expect(abs(inflections[0].parameter - 20.6383455361) < 1e-6)
    }

    // #402: curvatureExtremaDetailed()/inflectionPointsDetailed() ("Detailed" family) and
    // curvatureExtrema()/inflectionPoints() ("plain" family) both wrap GeomLProp_CurAndInf2d.
    // CurInfType and Curve2DSpecialPointType number the same 3 cases differently; these pin
    // the mapping between them and confirm both families agree on the same curve.

    @Test("CurInfType mirrors Curve2DSpecialPointType case-for-case")
    func curInfTypeMirrorsSpecialPointType() {
        #expect(CurInfType(.inflection) == .inflection)
        #expect(CurInfType(.minCurvature) == .curvatureMinimum)
        #expect(CurInfType(.maxCurvature) == .curvatureMaximum)
    }

    @Test("curvatureExtremaDetailed() agrees with curvatureExtrema() on the same curve")
    func curvatureExtremaFamiliesAgree() throws {
        let ellipse = Curve2D.ellipse(center: .zero, majorRadius: 10, minorRadius: 5)
        let e = try #require(ellipse)
        let plain = e.curvatureExtrema()
        let detailed = e.curvatureExtremaDetailed()
        #expect(plain.count == detailed.count)
        #expect(plain.count == 4)  // #1979: was `>= 2`
        for (p, d) in zip(plain, detailed) {
            #expect(abs(p.parameter - d.parameter) < 1e-9)
            #expect(CurInfType(p.type) == d.type)
        }
    }

    @Test("inflectionPointsDetailed() agrees with inflectionPoints() on the same curve")
    func inflectionPointFamiliesAgree() throws {
        let points: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(2, 5), SIMD2(5, -5), SIMD2(8, 0),
        ]
        let curve = Curve2D.interpolate(through: points)
        let c = try #require(curve)
        let plain = c.inflectionPoints()
        let detailed = c.inflectionPointsDetailed()
        #expect(plain.count == detailed.count)
        #expect(plain.count == 1)  // #1979: was `>= 1`; the one inflection is at u = 10.3042200457
        for (p, d) in zip(plain, detailed) {
            #expect(abs(p - d.parameter) < 1e-9)
            #expect(abs(p - 10.3042200457) < 1e-6)
            #expect(d.type == .inflection)
        }
    }
}
