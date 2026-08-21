import Testing
@testable import OCCTSwift

// #490: the bridge decoded "continuity" as an integer in nineteen places, and the copies
// disagreed. Two pairs of entry points wrapped the *same* OCCT operation off two different
// numberings, which no test caught because each suite only ever exercised its own convention.
// These tests are the cross-checks that were missing: they drive both members of each pair with
// the same integer and require the same answer.

@Suite("Issue #490: one continuity vocabulary per operation (healing)")
struct Issue490ContinuityDecoderTests {

    // A BSpline surface that is genuinely only C0 in U: the interior knot's multiplicity equals
    // the degree, so the two halves meet with a tangent break. Continuity criteria are only
    // observable against geometry that actually fails one of them.
    private func c0InUSurface() -> Surface? {
        var poles = [[SIMD3<Double>]]()
        for i in 0..<7 {
            var row = [SIMD3<Double>]()
            let x = Double(i)
            // A kink at the midpoint of U.
            let z = i <= 3 ? 0.3 * x : 0.3 * (8.0 - x)
            for j in 0..<4 {
                row.append(SIMD3(x, Double(j), z))
            }
            poles.append(row)
        }
        return Surface.bspline(poles: poles,
                               knotsU: [0.0, 0.5, 1.0], multiplicitiesU: [4, 3, 4],
                               knotsV: [0.0, 1.0], multiplicitiesV: [4, 4],
                               degreeU: 3, degreeV: 3)
    }

    // MARK: - ShapeCustom_BSplineRestriction: two entry points, one operation

    @Test("bsplineRestriction and bsplineRestrictionAdvanced read the same continuity",
          arguments: [ParametricContinuity.c0, .c1, .c2])
    func restrictionEntryPointsAgree(continuity: ParametricContinuity) throws {
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))

        // ShapeCustom::BSplineRestriction is itself a ShapeCustom_BSplineRestriction driven
        // through BRepTools_Modifier, exactly what the advanced entry point builds by hand, so
        // matching arguments must produce identical geometry.
        let plain = cyl.bsplineRestriction(tol3d: 0.01, tol2d: 0.01,
                                           maxDegree: 6, maxSegments: 20,
                                           continuity3d: continuity, continuity2d: continuity,
                                           degreePriority: true, rational: true)
        let advanced = Shape.bsplineRestrictionAdvanced(cyl,
                                                        tol3d: 0.01, tol2d: 0.01,
                                                        continuity3d: continuity,
                                                        continuity2d: continuity,
                                                        maxDegree: 6, maxSegments: 20,
                                                        priorityDegree: true,
                                                        convertRational: true)

        let plainVolume = try #require(plain?.volume)
        let advancedVolume = try #require(advanced?.volume)
        // Before #490 the advanced entry point read this same integer as a GeomAbs_Shape ordinal,
        // so .c1 (1) asked for G1 and .c2 (2) asked for C1, a different result, or none at all.
        #expect(abs(plainVolume - advancedVolume) < 1e-9)
    }

    @Test("both restriction entry points refuse C3 the same way")
    func restrictionRejectsC3() throws {
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))

        // Measured against the pinned kernel: ShapeCustom_BSplineRestriction yields a null shape
        // for anything above C2, whichever entry point asks. Documented on both, not silently
        // downgraded, the decoder passes the request through rather than substituting C2.
        #expect(cyl.bsplineRestriction(continuity3d: .c3, continuity2d: .c3) == nil)
        #expect(Shape.bsplineRestrictionAdvanced(cyl, continuity3d: .c3, continuity2d: .c3) == nil)
    }

    @Test("C2 restriction is a different result from C0, so the argument is observable")
    func restrictionContinuityIsObservable() throws {
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        let atC0 = try #require(cyl.bsplineRestriction(tol3d: 0.01, tol2d: 0.01,
                                                       maxDegree: 6, maxSegments: 20,
                                                       continuity3d: .c0, continuity2d: .c0,
                                                       rational: true)?.volume)
        let atC2 = try #require(cyl.bsplineRestriction(tol3d: 0.01, tol2d: 0.01,
                                                       maxDegree: 6, maxSegments: 20,
                                                       continuity3d: .c2, continuity2d: .c2,
                                                       rational: true)?.volume)
        #expect(abs(atC0 - atC2) > 1e-9)
    }

    // MARK: - ShapeUpgrade_SplitSurfaceContinuity: two entry points, one operation

    @Test("both surface-split entry points read the same criterion", arguments: 0...3)
    func surfaceSplitEntryPointsAgree(criterion: Int) throws {
        let surface = try #require(c0InUSurface())

        let viaSurface = surface.splitByContinuity(criterion: criterion, tolerance: 1e-6)
        let viaShapeUpgrade = try #require(surface.splitSurfaceByContinuity(criterion: criterion,
                                                                           tolerance: 1e-6))

        // Both wrap ShapeUpgrade_SplitSurfaceContinuity. Before #490, criterion 2 asked one for
        // C2 and the other for C1.
        #expect(viaSurface.uSplitCount == viaShapeUpgrade.uSplitCount)
        #expect(viaSurface.vSplitCount == viaShapeUpgrade.vSplitCount)
    }

    @Test("the surface-split criterion is observable across the C1/C2 boundary")
    func surfaceSplitCriterionIsObservable() throws {
        let surface = try #require(c0InUSurface())

        // The surface is C0 at its interior U knot: asking for C1 finds nothing to do (the two
        // returned values are just the ends of the U range), asking for C2 splits there.
        let atC1 = surface.splitByContinuity(criterion: 1, tolerance: 1e-6)
        let atC2 = surface.splitByContinuity(criterion: 2, tolerance: 1e-6)
        #expect(atC1.uSplitCount == 2)
        #expect(atC2.uSplitCount == 3)

        // Which is the same answer through the other entry point, now that they share a decoder.
        let upgradeAtC2 = try #require(surface.splitSurfaceByContinuity(criterion: 2, tolerance: 1e-6))
        #expect(upgradeAtC2.uSplitCount == 3)
    }

    // MARK: - The shared out-of-range rule

    @Test("an out-of-range criterion saturates at CN rather than dropping to a weaker class")
    func outOfRangeCriterionSaturates() throws {
        let surface = try #require(c0InUSurface())

        // One rule now, in one place: values above the vocabulary ask for CN, the top of the same
        // ladder. Previously the copies disagreed. GeomAbs_CN here, GeomAbs_C2 there,
        // GeomAbs_C1 elsewhere, so the same invalid integer meant different things depending
        // only on which entry point received it. Never *weaker* than the largest valid value.
        let atC3 = surface.splitByContinuity(criterion: 3, tolerance: 1e-6)
        let outOfRange = surface.splitByContinuity(criterion: 99, tolerance: 1e-6)
        #expect(outOfRange.uSplitCount >= atC3.uSplitCount)
        #expect(outOfRange.vSplitCount >= atC3.vSplitCount)
    }
}
