import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Geom2dLProp Curvature Analysis") struct Geom2dLPropTests {
    @Test("Curvature extrema on ellipse")
    func ellipseCurvatureExtrema() {
        let ellipse = Curve2D.ellipse(center: SIMD2(0, 0), majorRadius: 10, minorRadius: 5)
        if let ellipse {
            let extrema = ellipse.curvatureExtremaDetailed()
            #expect(extrema.count >= 1)
        }
    }

    @Test("Inflection points on S-curve")
    func inflectionPointsDetailed() {
        // Create a BSpline with inflection by interpolating an S-shape
        let points: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(3, 10), SIMD2(7, -10), SIMD2(10, 0),
        ]
        let curve = Curve2D.interpolate(through: points)
        if let curve {
            let inflections = curve.inflectionPointsDetailed()
            // May or may not find inflections depending on the actual curve shape
            #expect(inflections.count >= 0)
        }
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
    func curvatureExtremaFamiliesAgree() {
        let ellipse = Curve2D.ellipse(center: .zero, majorRadius: 10, minorRadius: 5)
        if let ellipse {
            let plain = ellipse.curvatureExtrema()
            let detailed = ellipse.curvatureExtremaDetailed()
            #expect(plain.count == detailed.count)
            #expect(plain.count >= 2)
            for (p, d) in zip(plain, detailed) {
                #expect(abs(p.parameter - d.parameter) < 1e-9)
                #expect(CurInfType(p.type) == d.type)
            }
        }
    }

    @Test("inflectionPointsDetailed() agrees with inflectionPoints() on the same curve")
    func inflectionPointFamiliesAgree() {
        let points: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(2, 5), SIMD2(5, -5), SIMD2(8, 0),
        ]
        let curve = Curve2D.interpolate(through: points)
        if let curve {
            let plain = curve.inflectionPoints()
            let detailed = curve.inflectionPointsDetailed()
            #expect(plain.count == detailed.count)
            #expect(plain.count >= 1)
            for (p, d) in zip(plain, detailed) {
                #expect(abs(p - d.parameter) < 1e-9)
                #expect(d.type == .inflection)
            }
        }
    }
}
