// Cluster D census (#513/#667): continuity handling across the kernel and the bridge. #513 is
// already written as prose -- 38 unaudited functions, four incompatible request encodings, two
// live defects -- and named #490/#480/#398/#619 as the standing constraints this census must not
// re-litigate: #490 already consolidated 19 continuity decoders down to 3
// (`occtGeomAbsFromSurfaceContinuity`, `occtGeomAbsFromParametricContinuity`,
// `occtGeomAbsFromAnalysisOrder`, all in `Sources/OCCTBridge/src/OCCTBridge_Internal.h`); #480
// ruled the knot-splitting family's argument is a literal derivative order, never a `GeomAbs_Shape`;
// #398 reduced nine continuity enums to two request vocabularies plus one result vocabulary
// (`Sources/OCCTSwift/Continuity.swift`); #619 retired `continuityOrder` outright (it is
// `@available(*, unavailable)` on this tree, not merely deprecated) rather than reinterpret it.
//
// This is the DYNAMIC half, following Cluster A/B's method: call each entry point against real
// fixtures and record what comes back, as the primary evidence.
// `classify_continuity_sites.py` (in this cluster's own
// Scripts/repro/cluster-d-continuity/) is the STATIC cross-check: it classifies each named bridge
// function's decoder by which of the three shared `occtGeomAbsFrom*` helpers its body calls (or
// none, for the knot-splitting and plate families, which pass the literal integer through). Any
// disagreement between the two would be reported in the README rather than reconciled away, per
// Cluster A/B's own finding that this is the most valuable output a static cross-check produces --
// this time there wasn't one, which the README also records rather than omits.
//
// Run with: swift run Censuses cluster-d
//
// This is the census only. It does not fix #437, #438, or BRepGraph.edgeMaxContinuity's stub.

import Foundation
import OCCTSwift
import simd

// MARK: - Report plumbing

fileprivate func pad(_ s: String, _ width: Int) -> String {
    s.count >= width ? s : s + String(repeating: " ", count: width - s.count)
}

fileprivate func printTable(_ title: String, _ header: [String], _ widths: [Int], _ rows: [[String]]) {
    print("--- \(title) ---")
    print(zip(header, widths).map { pad($0, $1) }.joined(separator: " | "))
    print(widths.map { String(repeating: "-", count: $0) }.joined(separator: "-|-"))
    for row in rows {
        print(zip(row, widths).map { pad($0, $1) }.joined(separator: " | "))
    }
    print("row count: \(rows.count)")
    print()
}

fileprivate func fmt(_ value: Double?) -> String {
    guard let value else { return "nil" }
    return String(format: "%.6f", value)
}

// MARK: - Shared knot-vector fixture (#480's own recipe, generalized across all four analyzers)
//
// `degree - multiplicity(knot) < ContinuityRange` is the rule GeomConvert_BSplineCurveKnotSplitting,
// Geom2dConvert_BSplineCurveKnotSplitting, GeomConvert_BSplineSurfaceKnotSplitting and
// Law_BSplineKnotSplitting all run, byte for byte identically (#480's own claim). Building the
// SAME knot/multiplicity vector for all four geometry types in one place, rather than reproducing
// each existing per-type test's private copy, is what lets this census show the claim rather than
// cite it.

fileprivate func knotVector(degree: Int, interiorKnots: Int, bumpAt: Int = 0, bumpMult: Int = 1)
    -> (knots: [Double], mults: [Int32], poleCount: Int)
{
    var knots: [Double] = [0]
    var mults: [Int32] = [Int32(degree + 1)]
    for i in 1...interiorKnots {
        knots.append(Double(i))
        mults.append(Int32(i == bumpAt ? bumpMult : 1))
    }
    knots.append(Double(interiorKnots + 1))
    mults.append(Int32(degree + 1))
    let poleCount = Int(mults.reduce(0, +)) - degree - 1
    return (knots, mults, poleCount)
}

// Neither measurement below touches a deprecated overload. `ContinuityClass` is `CaseIterable`
// over all seven `GeomAbs_Shape` ordinals (through `.cN` = 6), and `continuityWith(order:)` and
// `bsplineRestrictionAdvanced(continuity3d:continuity2d:)` both take it directly -- so `.c3`/`.cN`,
// which `occtGeomAbsFromAnalysisOrder` saturates down to `.c2`, are reachable through the TYPED
// entry point without needing the raw-Int siblings #490 deprecated. That was not obvious going in:
// the first draft of this file reached for the deprecated overloads before noticing the typed one
// already accepts every enum case, saturating ones included.

/// #490: `bsplineRestrictionAdvanced`'s now-deprecated raw-Int overload used to read `2` as
/// `GeomAbs_C1` (one class below `bsplineRestriction`'s own `.c2`). Confirms convergence holds on
/// this tree by comparing the two current, typed call spellings against the same fixture at the
/// same requested continuity. (The deprecated raw-Int overload is not exercised here: its body
/// forwards to the identical C call with the identical converted `Int32`, so it is structurally
/// guaranteed to agree -- confirmed by reading `Sources/OCCTSwift/Shape+ShapeHealing.swift`'s two
/// `bsplineRestrictionAdvanced` overloads side by side, not by re-deriving it dynamically.)
fileprivate func clusterDRecordBSplineRestrictionConvergence() {
    var rows: [[String]] = []
    for continuity in ParametricContinuity.allCases {
        let b1 = SharedFixture.splitBoxCompound(order: .asSplit)
        let b2 = SharedFixture.splitBoxCompound(order: .asSplit)
        let viaPlain = b1.bsplineRestriction(continuity3d: continuity, continuity2d: continuity)
        let viaAdvancedTyped = Shape.bsplineRestrictionAdvanced(
            b2, continuity3d: continuity, continuity2d: continuity)
        let vPlain = viaPlain?.volume
        let vAdvTyped = viaAdvancedTyped?.volume
        let allNil = vPlain == nil && vAdvTyped == nil
        let allAgree = allNil || ([vPlain, vAdvTyped].compactMap { $0 }.count == 2
            && abs((vPlain ?? 0) - (vAdvTyped ?? -1)) < 1e-6)
        rows.append([
            "\(continuity)", fmt(vPlain), fmt(vAdvTyped),
            allAgree ? "AGREE (converged, #490)" : "DISAGREE",
        ])
    }
    printTable("2e. bsplineRestriction vs bsplineRestrictionAdvanced(typed) -- same compound, same continuity",
               ["continuity", "bsplineRestriction", "Advanced (typed)", "verdict"],
               [12, 20, 20, 26], rows)
}

/// `occtGeomAbsFromAnalysisOrder` saturates at `GeomAbs_C2` (raw 4): `.c3` and `.cN`, both real
/// `ContinuityClass` cases, decode to the same effective order as `.c2`. Measured via the typed
/// `continuityWith(order:)` overload across every `ContinuityClass` case, not just the five the
/// analyzer itself implements a branch for -- `ContinuityAnalysis.order` reports where the request
/// actually landed.
fileprivate func clusterDRecordAnalysisOrderSaturation() {
    guard let c1 = Curve3D.fit(points: [SIMD3(0, 0, 0), SIMD3(2.5, 1, 0), SIMD3(5, 0, 0)]),
          let c2 = Curve3D.fit(points: [SIMD3(5, 0, 0), SIMD3(7.5, -1, 0), SIMD3(10, 0, 0)]) else {
        print("Cluster D census: could not build the smooth-junction curve fixture.")
        return
    }
    var rows: [[String]] = []
    for requested in ContinuityClass.allCases {
        let analysis = c1.continuityWith(c2, u1: c1.domain.upperBound, u2: c2.domain.lowerBound, order: requested)
        rows.append(["\(requested)", analysis.map { "\($0.order)" } ?? "nil"])
    }
    printTable("4a. Curve3D.continuityWith(order: ContinuityClass) -- every case, effective order read back via ContinuityAnalysis.order",
               ["requested", "effective order"], [12, 30], rows)

    // Reading LocalAnalysis_SurfaceContinuity::SurfC2 directly (Libraries/occt-src, not shipped
    // in the pinned kernel's headers): it needs a nonzero SECOND derivative in BOTH parametric
    // directions on BOTH surfaces, or it reports LocalAnalysis_NullSecondDerivative and the whole
    // analysis returns nil. A plane fails this in both directions (`identicalPlanes`'s own doc
    // comment already says so). A cylinder was tried here first and ALSO failed it -- measured,
    // not assumed -- because a cylinder's height parametrization is a straight line, so D2V is
    // exactly zero even though D2U (around the curved direction) is not. A sphere has nonzero
    // curvature in both directions and is what actually reaches the C2 branch.
    guard let s1 = Surface.sphere(center: .zero, radius: 5.0),
          let s2 = Surface.sphere(center: .zero, radius: 5.0) else {
        print("Cluster D census: could not build the sphere fixture.")
        return
    }
    var surfRows: [[String]] = []
    for requested in ContinuityClass.allCases {
        let analysis = s1.continuityWith(s2, u1: 0.1, v1: 0.1, u2: 0.1, v2: 0.1, order: requested)
        surfRows.append(["\(requested)", analysis.map { "\($0.order)" } ?? "nil"])
    }
    printTable("4b. Surface.continuityWith(order: ContinuityClass) -- identical spheres (curvature in both directions), every case, effective order read back",
               ["requested", "effective order"], [12, 30], surfRows)
}

enum ClusterD {
    static func run() {
        var totalMeasured = 0

        // MARK: 1. Knot-splitting family: one contract across (at least) five public entry points
        //
        // #480: the argument is a literal derivative order, not a GeomAbs_Shape. Decoding it
        // first would be wrong -- GeomAbs_C3 is ordinal 5, and would split a cubic at every
        // interior knot where `.c3` (the literal value 3) must split at none. This section
        // measures, rather than cites, that all five entry points agree.

        do {
            let (knots, mults, poleCount) = knotVector(degree: 3, interiorKnots: 4)
            let curve3D = Curve3D.bspline(
                poles: (0..<poleCount).map { SIMD3(Double($0), Double($0 % 3) - 1, 0) },
                knots: knots, multiplicities: mults, degree: 3)
            let curve2D = Curve2D.bspline(
                poles: (0..<poleCount).map { SIMD2(Double($0), Double($0 % 3) - 1) },
                knots: knots, multiplicities: mults, degree: 3)
            let law = LawFunction.bspline(
                poles: (0..<poleCount).map { Double($0 % 4) * 1.5 },
                knots: knots, multiplicities: mults, degree: 3)
            let surface = Surface.bspline(
                poles: (0..<poleCount).map { u in
                    (0..<poleCount).map { v in SIMD3<Double>(Double(u), Double(v), Double((u + v) % 3) * 0.5) }
                },
                knotsU: knots, multiplicitiesU: mults,
                knotsV: knots, multiplicitiesV: mults,
                degreeU: 3, degreeV: 3)

            var rows: [[String]] = []
            for continuity in ParametricContinuity.allCases {
                let c3d = curve3D?.continuityBreaks(minContinuity: continuity)?.count
                let c2d = curve2D?.splitIndicesAtDiscontinuities(continuity: continuity)?.count
                let lawSplits = law?.knotSplitting(continuityOrder: continuity).count
                let lawParams = law?.knotSplitParameters(continuityOrder: continuity).count
                let surf = surface?.knotSplitting(uContinuity: continuity, vContinuity: continuity)
                rows.append([
                    "\(continuity)",
                    c3d.map(String.init) ?? "nil",
                    c2d.map(String.init) ?? "nil",
                    lawSplits.map(String.init) ?? "nil",
                    lawParams.map(String.init) ?? "nil",
                    surf.map { "\($0.uSplitCount)/\($0.vSplitCount)" } ?? "nil",
                ])
            }
            printTable(
                "1. Knot-splitting: literal derivative order, identical cubic (4 simple interior knots) across all four analyzers",
                ["continuity", "Curve3D.continuityBreaks", "Curve2D.splitIndicesAtDiscontinuities",
                 "LawFunction.knotSplitting", "LawFunction.knotSplitParameters", "Surface.knotSplitting (u/v)"],
                [12, 26, 38, 26, 29, 28],
                rows)
            totalMeasured += 5

            // The "genuine kink" variant (#480's own second fixture): multiplicity 3 on a cubic
            // leaves continuity 0 at that knot, so even .c0 already sees a real break there while
            // interior SIMPLE knots still need .c3. Prints once as corroboration, not a new row.
            let (kKnots, kMults, kPoles) = knotVector(degree: 3, interiorKnots: 4, bumpAt: 2, bumpMult: 3)
            let kinkLaw = LawFunction.bspline(
                poles: (0..<kPoles).map { Double($0 % 4) * 1.5 },
                knots: kKnots, multiplicities: kMults, degree: 3)
            print("genuine-kink fixture (mult 3 at knot 2 of a cubic): "
                  + "LawFunction.knotSplitParameters() default (.c1) = "
                  + "\(kinkLaw?.knotSplitParameters() ?? [])"
                  + " -- a real discontinuity the .c1 default is expected to find")
            print()
        }

        // MARK: 2. ParametricContinuity decoder: raw-int saturation, where the Swift layer still
        // permits an out-of-range value
        //
        // #398/#490 typed most of this family's callers against `ParametricContinuity`
        // (`CaseIterable`, four values), which makes an out-of-range raw int UNCONSTRUCTIBLE at
        // the Swift layer -- that is the intended effect of the typing work, not a gap in this
        // census. The handful of sites below still take a raw `Int` (some deliberately, for
        // backward compatibility; some because #490 left them untyped) and so are the only ones
        // this census can probe for the shared decoder's saturation rule directly.

        do {
            let (kKnots, kMults, kPoles) = knotVector(degree: 3, interiorKnots: 4, bumpAt: 2, bumpMult: 3)
            let poles3D = (0..<kPoles).map { SIMD3<Double>(Double($0) * 2, Double($0 % 2) * 3, 0) }
            let probes = [-1, 0, 1, 2, 3, 4, 5, 99]

            var rows: [[String]] = []
            for probe in probes {
                let curve = Curve3D.bspline(poles: poles3D, knots: kKnots, multiplicities: kMults, degree: 3)
                let pieceCount = curve?.splitByContinuity(criterion: probe).count
                rows.append(["\(probe)", pieceCount.map(String.init) ?? "nil"])
            }
            printTable("2a. Curve3D.splitByContinuity(criterion: Int) -- pieces on a cubic with one genuine kink (mult 3)",
                       ["probe", "piece count"], [8, 12], rows)
            totalMeasured += 1

            // 2b. The #438-shaped duplicate this census found beyond #513's own list:
            // Surface.splitByContinuity (OCCTSurfaceSplitByContinuity, struct-return) and
            // Surface.splitSurfaceByContinuity (OCCTSplitSurfaceContinuity, out-param return) both
            // wrap ShapeUpgrade_SplitSurfaceContinuity and both now read `criterion` as
            // ParametricContinuity's raw value (the doc comments on both say so, and both cite
            // #490 for having previously disagreed). Measured side by side to confirm agreement
            // holds today, not just that the doc comments assert it.
            let poles2D = (0..<kPoles).map { u in (0..<kPoles).map { v in SIMD3<Double>(Double(u), Double(v), Double((u + v) % 3)) } }
            var surfRows: [[String]] = []
            for probe in probes {
                let s1 = Surface.bspline(poles: poles2D, knotsU: kKnots, multiplicitiesU: kMults,
                                          knotsV: kKnots, multiplicitiesV: kMults, degreeU: 3, degreeV: 3)
                let s2 = Surface.bspline(poles: poles2D, knotsU: kKnots, multiplicitiesU: kMults,
                                          knotsV: kKnots, multiplicitiesV: kMults, degreeU: 3, degreeV: 3)
                let a = s1?.splitByContinuity(criterion: probe, tolerance: 1e-6)
                let b = s2?.splitSurfaceByContinuity(criterion: probe, tolerance: 1e-6)
                let agree = (a?.uSplitCount == b?.uSplitCount) && (a?.vSplitCount == b?.vSplitCount)
                surfRows.append([
                    "\(probe)",
                    a.map { "\($0.uSplitCount)/\($0.vSplitCount)" } ?? "nil",
                    b.map { "\($0.uSplitCount)/\($0.vSplitCount)" } ?? "nil",
                    agree ? "AGREE" : "DISAGREE",
                ])
            }
            printTable("2b. TWO public APIs over ONE OCCT class (ShapeUpgrade_SplitSurfaceContinuity) -- #438's shape, found again",
                       ["probe", "splitByContinuity (u/v)", "splitSurfaceByContinuity (u/v)", "verdict"],
                       [8, 26, 32, 10], surfRows)
            totalMeasured += 2

            // 2c. FilletBuilder.setContinuity / ThruSectionsBuilder.setContinuity: #513 named the
            // former a live one-class-low defect from a raw cast; the current source (read before
            // writing this census) already routes both through occtGeomAbsFromParametricContinuity
            // with a comment citing #513 by number. Measured here as "does it still build, and
            // does an out-of-range probe still saturate rather than crash", since the actual
            // routing is confirmed by classify_continuity_sites.py's static read, not by
            // re-deriving GeomAbs_Shape ordinals from a fillet's resulting volume.
            let box = SharedFixture.plainBox()
            var filletRows: [[String]] = []
            for probe in probes {
                guard let builder = FilletBuilder(shape: box) else { continue }
                let e0 = box.edges()[0]
                builder.addEdge(e0, radius: 2.0)
                builder.setContinuity(probe, angularTolerance: 1e-4)
                let volume = builder.build()?.volume
                filletRows.append(["\(probe)", volume.map { String(format: "%.4f", $0) } ?? "nil (build failed)"])
            }
            printTable("2c. FilletBuilder.setContinuity(_:angularTolerance:) -- resulting volume per probe (box, one edge filleted r=2)",
                       ["probe", "volume"], [8, 28], filletRows)
            totalMeasured += 1

            var loftRows: [[String]] = []
            for probe in probes {
                guard let w1 = Wire.circle(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5),
                      let w2 = Wire.circle(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 3),
                      let s1 = Shape.fromWire(w1), let s2 = Shape.fromWire(w2) else { continue }
                let loft = ThruSectionsBuilder(isSolid: true, isRuled: false)
                loft.addWire(s1)
                loft.addWire(s2)
                loft.setContinuity(probe)
                let ok = loft.build()
                loftRows.append(["\(probe)", ok ? "built (volume \(fmt(loft.shape?.volume)))" : "build FAILED"])
            }
            printTable("2d. ThruSectionsBuilder.setContinuity(_:) -- two-circle loft, per probe",
                       ["probe", "result"], [8, 40], loftRows)
            totalMeasured += 1

            // 2e. bsplineRestriction vs bsplineRestrictionAdvanced (typed): #490's headline claim
            // was that these two entry points drove the SAME OCCT operation off two DIFFERENT
            // numberings, and that passing the literal `2` silently meant C2 through one and C1
            // through the other. Re-measured here, on this tree, rather than trusted from the
            // issue text.
            clusterDRecordBSplineRestrictionConvergence()
            totalMeasured += 2

            // 2f. #438: FIXED. divided(at:) and dividedByContinuity(criterion:) used to be two
            // public entry points over the same ShapeUpgrade_ShapeDivideContinuity, setting
            // DIFFERENT criteria (divided(at:) set boundary+pcurve+surface together;
            // dividedByContinuity set only boundary, leaving pcurve/surface pinned at the class's
            // own C1 constructor default regardless of the requested continuity). Fixed by
            // widening divided(at:) to take ContinuityLevel plus a tolerance parameter and making
            // dividedByContinuity(criterion:tolerance:) a deprecated forward to it, so there is
            // now exactly one implementation. This section used to compare the two independently;
            // now that one forwards to the other, a comparison between them proves only that the
            // forward passes its arguments through, so it measures divided(at:) alone across its
            // full domain and separately pins the deprecated spelling's forwarding contract.
            //
            // Neither a plain box nor a cylinder works as a fixture here: both this tree's own
            // tests (`ShapeUpgradeDivideContinuityTests.divideBoxContinuity`, `AdvancedHealingTests.
            // divideCylinder`) tolerate nil ("may return nil/the same shape if no divisions
            // needed"), and measured here, divided(at:) returns nil on both at every continuity --
            // a planar box has no interior surface knots to divide at, and a cylinder's single
            // lateral face is one smooth periodic surface with none either. A face built directly
            // from a kinked BSpline surface (mult-3 knot, genuinely C0 at one interior knot) gives
            // it something real to divide.
            let (dKnots, dMults, dPoles) = knotVector(degree: 3, interiorKnots: 4, bumpAt: 2, bumpMult: 3)
            func kinkedSurfaceShape() -> Shape? {
                guard let surface = Surface.bspline(
                    poles: (0..<dPoles).map { u in (0..<dPoles).map { v in SIMD3<Double>(Double(u), Double(v), Double((u + v) % 3) * 0.5) } },
                    knotsU: dKnots, multiplicitiesU: dMults, knotsV: dKnots, multiplicitiesV: dMults,
                    degreeU: 3, degreeV: 3) else { return nil }
                let bounds = surface.domain
                return Shape.face(from: surface, uRange: bounds.uMin...bounds.uMax, vRange: bounds.vMin...bounds.vMax)
            }
            var divideRows: [[String]] = []
            for level in Shape.ContinuityLevel.allCases {
                let result = kinkedSurfaceShape()?.divided(at: level, tolerance: 1e-4)
                divideRows.append(["\(level)", result.map { "\($0.faceCount) faces" } ?? "nil"])
            }
            printTable("2f. #438 fixed: divided(at:tolerance:) across its full domain (was two disagreeing entry points)",
                       ["level", "divided(at:) result"], [8, 30], divideRows)
            totalMeasured += 1

            // 2g. dividedByContinuity(criterion:tolerance:), the #438 deprecation this row used to
            // measure the forwarding of, was removed at v2.0.0 (#784).
        }

        // MARK: 3. SurfaceContinuity family: filling (decodes through occtGeomAbsFromSurfaceContinuity)
        // vs plate (raw pass-through into GeomPlate_PointConstraint/CurveConstraint's own literal
        // order -- reading OCCTBridge_ProjLib_NLPlate.mm shows NO occtGeomAbsFrom* call in
        // OCCTShapePlateCurves/PointsAdvanced/Mixed at all, just an `if (order > 2) order = 2;`
        // clamp). #437's own claim -- a point constraint can never accept .g2 -- reproduced here
        // against the current tree rather than assumed from the issue text.

        do {
            guard let e0 = Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)),
                  let e1 = Wire.line(from: SIMD3(10, 0, 0), to: SIMD3(10, 10, 5)),
                  let e2 = Wire.line(from: SIMD3(10, 10, 5), to: SIMD3(0, 10, 3)),
                  let e3 = Wire.line(from: SIMD3(0, 10, 3), to: SIMD3(0, 0, 0)) else {
                print("Cluster D census: could not build the fill boundary fixture.")
                return
            }
            var fillRows: [[String]] = []
            for continuity in SurfaceContinuity.allCases {
                let face = Shape.fill(boundaries: [e0, e1, e2, e3], parameters: FillingParameters(continuity: continuity))
                fillRows.append(["\(continuity)", face != nil ? "built (area \(fmt(face?.surfaceArea)))" : "nil"])
            }
            printTable("3a. Shape.fill(boundaries:parameters:) -- SurfaceContinuity via occtGeomAbsFromSurfaceContinuity",
                       ["continuity", "result"], [12, 34], fillRows)
            totalMeasured += 1

            let box = SharedFixture.plainBox()
            var fsRows: [[String]] = []
            for continuity in SurfaceContinuity.allCases {
                let filling = FillingSurface()
                for edge in box.edges().prefix(4) {
                    filling.add(edge: edge, continuity: continuity)
                }
                let built = filling.build()
                fsRows.append([
                    "\(continuity)",
                    built != nil ? "built" : "nil",
                    fmt(filling.g0Error), fmt(filling.g1Error), fmt(filling.g2Error),
                ])
            }
            printTable("3b. FillingSurface.add(edge:continuity:) -- first 4 box edges as boundary",
                       ["continuity", "result", "g0Error", "g1Error", "g2Error"], [12, 10, 12, 12, 12], fsRows)
            totalMeasured += 1

            // #437 reproduction: point constraints reject order > 1 (.g2 = 2), curve constraints
            // accept it. Both go through the SAME raw pass-through, not occtGeomAbsFromSurfaceContinuity.
            let points: [SIMD3<Double>] = [
                SIMD3(0, 0, 0), SIMD3(10, 0, 1), SIMD3(10, 10, 2), SIMD3(0, 10, 1), SIMD3(5, 5, 3),
            ]
            var plateRows: [[String]] = []
            for continuity in SurfaceContinuity.allCases {
                let uniformOrders = Array(repeating: continuity, count: points.count)
                let pointResult = Shape.plateSurface(through: points, orders: uniformOrders)
                plateRows.append(["point (plateSurface(through:orders:))", "\(continuity)",
                                   pointResult != nil ? "built" : "nil -- #437"])
            }
            for continuity in SurfaceContinuity.allCases {
                guard let curveWire = Wire.circle(origin: .zero, normal: SIMD3(0, 0, 1), radius: 8) else { continue }
                let curveResult = Shape.plateSurface(constrainedBy: [curveWire], continuity: continuity)
                plateRows.append(["curve (plateSurface(constrainedBy:continuity:))", "\(continuity)",
                                   curveResult != nil ? "built" : "nil"])
            }
            printTable("3c. #437: plate point constraint vs curve constraint, same continuity domain, raw pass-through (no GeomAbs decode)",
                       ["constraint kind", "continuity", "result"], [46, 12, 24], plateRows)
            totalMeasured += 2

            // Mixed constraint call: one point at .g2 alongside one curve at .g2, isolating which
            // constraint kind fails the WHOLE call (#437's own second example).
            if let curveWire = Wire.circle(origin: SIMD3(20, 0, 0), normal: SIMD3(0, 0, 1), radius: 5) {
                let mixedPointG2 = Shape.plateSurface(
                    pointConstraints: [(point: SIMD3(0, 0, 0), order: .g2)],
                    curveConstraints: [(wire: curveWire, order: .g0)])
                let mixedCurveG2 = Shape.plateSurface(
                    pointConstraints: [(point: SIMD3(0, 0, 0), order: .g0)],
                    curveConstraints: [(wire: curveWire, order: .g2)])
                print("3d. plateSurface(pointConstraints:curveConstraints:) mixed call:")
                print("    one .g2 POINT among otherwise-.g0 constraints -> \(mixedPointG2 != nil ? "built" : "nil -- the whole call fails on the point alone")")
                print("    one .g2 CURVE among otherwise-.g0 constraints -> \(mixedCurveG2 != nil ? "built" : "nil")")
                print()
                totalMeasured += 1
            }
        }

        // MARK: 4. AnalysisOrder decoder (occtGeomAbsFromAnalysisOrder): saturates at C2 (raw 4).
        // `ContinuityAnalysis.order` reports the class the bridge actually settled on, which is
        // what makes this decoder directly observable through the typed API alone (see the
        // function's own doc comment for why no deprecated overload is needed here).

        clusterDRecordAnalysisOrderSaturation()
        totalMeasured += 2

        // MARK: 5. Result side: two different OCCT calls answer "what continuity across this edge",
        // only one of which was migrated to ContinuityClass (#485/#495). Measured on the same
        // (edge, face1, face2) triples so any disagreement is visible directly.

        do {
            func sharedEdgeTriples(in shape: Shape) -> [(Shape, Shape, Shape)] {
                let faces = shape.subShapes(ofType: .face)
                return shape.subShapes(ofType: .edge).compactMap { edge in
                    let adjacent = shape.adjacentFaces(forEdge: edge)
                    guard adjacent.count == 2,
                          let a = adjacent.first, let b = adjacent.last,
                          a >= 0, a < faces.count, b >= 0, b < faces.count
                    else { return nil }
                    return (edge, faces[a], faces[b])
                }
            }

            let box = SharedFixture.plainBox()
            let filletedBox = Shape.box(width: 20, height: 20, depth: 20)?.filleted(radius: 3)
            let cylinder = Shape.cylinder(radius: 5, height: 10)

            var rows: [[String]] = []
            if let firstBoxTriple = sharedEdgeTriples(in: box).first {
                let (e, f1, f2) = firstBoxTriple
                rows.append([
                    "box sharp edge",
                    "\(Shape.continuity(edge: e, face1: f1, face2: f2))",
                    "\(Shape.continuityClassOfFaces(edge: e, face1: f1, face2: f2).map(String.init(describing:)) ?? "nil")",
                ])
            }
            if let filletedBox, let g1Triple = sharedEdgeTriples(in: filletedBox).first(where: {
                Shape.continuityClassOfFaces(edge: $0.0, face1: $0.1, face2: $0.2) == .g1
            }) {
                let (e, f1, f2) = g1Triple
                rows.append([
                    "filleted box, G1 join",
                    "\(Shape.continuity(edge: e, face1: f1, face2: f2))",
                    "\(Shape.continuityClassOfFaces(edge: e, face1: f1, face2: f2).map(String.init(describing:)) ?? "nil")",
                ])
            }
            if let cylinder {
                outer: for face in cylinder.subShapes(ofType: .face) {
                    for edge in face.subShapes(ofType: .edge) {
                        if Shape.continuityClassOfFaces(edge: edge, face1: face, face2: face) == .cN {
                            rows.append([
                                "cylinder seam (self-pair)",
                                "\(Shape.continuity(edge: edge, face1: face, face2: face))",
                                "\(ContinuityClass.cN)",
                            ])
                            break outer
                        }
                    }
                }
            }
            printTable("5a. Shape.continuity(edge:face1:face2:) [BRep_Tool, raw Int, NOT migrated] vs continuityClassOfFaces [BRepLib, ContinuityClass, migrated #495]",
                       ["fixture", "Shape.continuity (raw)", "continuityClassOfFaces"], [26, 24, 24], rows)
            totalMeasured += 2

            // The cylinder row above disagrees (0 vs cN). The first hypothesis tried -- BRep_Tool::
            // Continuity reads a flag BRepLib::EncodeRegularity has to write first, and a raw
            // Shape.cylinder() never ran it -- does NOT hold, measured directly: encoding
            // regularity first and re-measuring the SAME self-paired seam edge still reports 0.
            // Reading Issue495FaceContinuityTests' own comment again narrows it instead:
            // BRepLib::ContinuityOfFaces "short-circuits to GeomAbs_CN when the two faces are the
            // same face and the surface is elementary" -- a special case in THAT function's own
            // algorithm, not a generic cached-vs-computed distinction. BRep_Tool::Continuity has no
            // such shortcut and a seam seemingly never gets an explicit stored value either way.
            // Left as a reported disagreement with a narrowed but unconfirmed mechanism, not a
            // guess dressed as a finding -- the source for BRep_Tool::Continuity's storage lookup
            // itself is not shipped in this release's headers to trace further.
            if let cylinder, let encoded = cylinder.encodingRegularity() {
                outer: for face in encoded.subShapes(ofType: .face) {
                    for edge in face.subShapes(ofType: .edge) {
                        if Shape.continuityClassOfFaces(edge: edge, face1: face, face2: face) == .cN {
                            print("5a (continued). SAME cylinder AFTER Shape.encodingRegularity(): "
                                  + "Shape.continuity(edge:face1:face2:) = \(Shape.continuity(edge: edge, face1: face, face2: face)) "
                                  + "-- STILL disagrees with continuityClassOfFaces' cN; encoding regularity did not close the gap")
                            print()
                            break outer
                        }
                    }
                }
                totalMeasured += 1
            }

            if let firstBoxTriple = sharedEdgeTriples(in: box).first {
                let (e, _, _) = firstBoxTriple
                print("5b. Shape.maxContinuity(edge:) on the same box edge -> \(Shape.maxContinuity(edge: e))")
                totalMeasured += 1
            }

            var resultRows: [[String]] = []
            if let line = Curve3D.line(through: .zero, direction: SIMD3(1, 0, 0)) {
                resultRows.append(["Curve3D (analytic line)", "\(line.continuity)", "\(line.continuityClass)"])
            }
            // The exact fixture Continuity.swift's own doc comment for `continuityClass` uses
            // (mult 4/2/4 leaves one derivative short of C2 at the middle knot): 6 poles.
            if let c1Spline = Curve3D.bspline(
                poles: (0..<6).map { SIMD3(Double($0), Double($0 % 2), 0) },
                knots: [0, 0.5, 1], multiplicities: [4, 2, 4], degree: 3) {
                resultRows.append(["Curve3D (mult-2 interior knot)", "\(c1Spline.continuity)", "\(c1Spline.continuityClass)"])
            }
            if let line2D = Curve2D.line(through: .zero, direction: SIMD2(1, 0)) {
                resultRows.append(["Curve2D (analytic line)", "\(line2D.continuity)", "\(line2D.continuityClass)"])
            }
            if let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)) {
                resultRows.append(["Surface (analytic plane)", "\(plane.continuity)", "\(plane.continuityClass)"])
            }
            if let bezierCurve = Curve3D.bezier(poles: [SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(2, -2, 0), SIMD3(3, 0, 0)]) {
                resultRows.append(["Curve3D.bezierContinuity (Bezier curve)", "\(bezierCurve.bezierContinuity)", "n/a"])
            }
            printTable("5c. Result-side raw-cast family: continuity / continuityClass / bezierContinuity, per fixture",
                       ["fixture", "continuity (raw)", "continuityClass"], [40, 18, 18], resultRows)
            totalMeasured += 4
        }

        // MARK: 6. BRepGraph.edgeMaxContinuity: the live stub #513 flagged, still unfixed.
        //
        // OCCTBRepGraphEdgeMaxContinuity (OCCTBridge_BRepGraph.mm) is `int32_t OCCTBRepGraphEdgeMaxContinuity(OCCTBRepGraphRef, int32_t) { return 0; }`
        // -- a hardcoded stub, source-read before writing this section. 0 is also GeomAbs_C0, an
        // ordinary answer, so nothing about a single call site proves it is a stub rather than a
        // real (if boring) measurement. What proves it: EVERY edge on a shape whose seam is
        // genuinely CN reports 0 through the graph, while the shape-based sibling that reads the
        // same BRep_Tool::MaxContinuity the graph's own comment says to use instead reports the
        // real class on at least one edge of the identical shape.

        do {
            guard let cylinder = Shape.cylinder(radius: 5, height: 10),
                  let graph = BRepGraph(shape: cylinder) else {
                print("Cluster D census: could not build the BRepGraph fixture.")
                return
            }
            let allZero = (0..<graph.edgeCount).allSatisfy { graph.edgeMaxContinuity($0) == 0 }
            print("6. BRepGraph.edgeMaxContinuity(_:), cylinder, all \(graph.edgeCount) edges: "
                  + "\(allZero ? "ALL report 0 (the stub)" : "NOT all zero -- would contradict the source read")")

            var maxContinuities: [Int] = []
            for edge in cylinder.subShapes(ofType: .edge) {
                maxContinuities.append(Shape.maxContinuity(edge: edge))
            }
            let sawNonzero = maxContinuities.contains { $0 != 0 }
            print("   Shape.maxContinuity(edge:) (BRep_Tool, the documented replacement), same cylinder, "
                  + "per-edge values: \(maxContinuities) -- \(sawNonzero ? "at least one nonzero, confirming the graph path is the one losing information" : "all zero on this fixture too")")
            print()
            totalMeasured += 1
        }

        // MARK: 7. Summary

        print("=== Cluster D summary ===")
        print("distinct entry points measured: \(totalMeasured)")
        print("See Scripts/repro/cluster-d-continuity/README.md for the encodings as measured, the")
        print("static cross-check (classify_continuity_sites.py) and its guard-removal matrix, and")
        print("the verdict on #437/#438/#513.")
    }
}
