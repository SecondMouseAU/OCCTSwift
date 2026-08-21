import Testing
import Foundation
@testable import OCCTSwift

/// #571, the six plate entry points drive `GeomPlate_MakeApprox` directly rather than through
/// `GeomConvert_ApproxSurface`, and five of them passed `Nbmax = 1` with `dmax = tolerance * 10`.
///
/// `Nbmax = 1` is the one value that disarms the algorithm: `AdvApp2Var_ApproxAFunc2Var` derives
/// its cut decision from the patch cap, and at 1 it decides "keep this patch" whether or not the
/// G0 criterion was satisfied, so the criterion is evaluated, violated, and ignored. `dmax` then
/// set the criterion's own threshold to `max(Tol3d, 10 * dmax)` = 100x the requested tolerance.
/// Together they made `tolerance` unenforceable: measured at 7.2x the value asked for.
///
/// These tests pin the contract at the public API, so a regression shows up as a surface that
/// misses its tolerance rather than as an argument that looks plausible at the call site.
@Suite("Issue 571, plate approximation honours its tolerance")
struct Issue571PlateApproxTests {

    /// A surface no single Bezier patch can fit: two full periods of a product of sines across a
    /// 16x16 span. A gentler fixture is reproduced exactly by one patch, which hides the defect,
    /// the previously-shipped plate tests all used 4-to-9-point near-planar sets for that reason.
    static var wavyPoints: [SIMD3<Double>] {
        var points: [SIMD3<Double>] = []
        for i in 0..<5 {
            for j in 0..<5 {
                points.append(SIMD3(Double(i) * 4.0,
                                    Double(j) * 4.0,
                                    4.0 * sin(Double(i) * 1.3) * cos(Double(j) * 1.1)))
            }
        }
        return points
    }

    /// Worst distance from any input point to the fitted surface.
    static func worstDeviation(of surface: Surface, from points: [SIMD3<Double>]) -> Double {
        var worst = 0.0
        for point in points {
            guard let projection = surface.projectPoint(point) else { continue }
            worst = max(worst, projection.distance)
        }
        return worst
    }

    @Test("A plate surface lands within the tolerance it was given")
    func toleranceIsHonoured() {
        let points = Self.wavyPoints
        let tolerance = 0.01
        guard let surface = Surface.plateThrough(points, degree: 3, tolerance: tolerance) else {
            Issue.record("plate build failed")
            return
        }
        // Pre-#571 this measured 0.0724, 7.2x the tolerance, reported as a success.
        let deviation = Self.worstDeviation(of: surface, from: points)
        #expect(deviation <= tolerance,
                "worst deviation \(deviation) exceeds requested tolerance \(tolerance)")
    }

    @Test("The approximation is allowed to use more than one Bezier patch")
    func subdivisionIsPermitted() {
        guard let surface = Surface.plateThrough(Self.wavyPoints, degree: 3, tolerance: 0.01) else {
            Issue.record("plate build failed")
            return
        }
        // One patch of degree d has exactly d+1 poles per direction, so <= 9 at the degree cap of
        // 8 means the fit never subdivided, which is what Nbmax = 1 forced regardless of error.
        #expect(surface.uPoleCount > 9,
                "uPoleCount \(surface.uPoleCount) means the fit stayed on a single Bezier patch")
    }

    @Test("Asking for a tighter tolerance actually produces a tighter fit")
    func toleranceChangesTheResult() {
        let points = Self.wavyPoints
        guard let loose = Surface.plateThrough(points, degree: 3, tolerance: 0.1),
              let tight = Surface.plateThrough(points, degree: 3, tolerance: 0.0005) else {
            Issue.record("plate build failed")
            return
        }
        let looseDeviation = Self.worstDeviation(of: loose, from: points)
        let tightDeviation = Self.worstDeviation(of: tight, from: points)
        // With dmax = tolerance * 10 the criterion threshold scaled with the tolerance instead of
        // being bounded by it, so both requests resolved to the same single-patch surface.
        #expect(tightDeviation < looseDeviation,
                "tolerance had no effect: loose \(looseDeviation) vs tight \(tightDeviation)")
        #expect(tight.uPoleCount >= loose.uPoleCount)
    }

    @Test("maxSegments below the algorithm's floor still honours the tolerance")
    func degenerateMaxSegmentsIsClamped() {
        let points = Self.wavyPoints
        // maxSegments: 1 reads like "use one patch", but it is the value that makes the tolerance
        // unenforceable rather than merely coarse, so the bridge lifts it to the floor of 2.
        guard let one = Shape.plateSurface(points: points, tolerance: 0.01, maxSegments: 1),
              let many = Shape.plateSurface(points: points, tolerance: 0.01, maxSegments: 20) else {
            Issue.record("plate build failed")
            return
        }
        #expect(one.isValid)
        let oneArea = one.surfaceArea ?? 0
        let manyArea = many.surfaceArea ?? 0
        #expect(oneArea > 0)
        #expect(abs(oneArea - manyArea) < 1e-6,
                "maxSegments 1 gave \(oneArea) but 20 gave \(manyArea)")
    }

    @Test("Both plate-through-points entry points agree on the same input")
    func bothEntryPointsAgree() {
        let points = Self.wavyPoints
        // Shape.plateSurface(through:) and Shape.plateSurface(points:) are overloads of one name
        // doing one job, but they reached GeomPlate_MakeApprox with different Nbmax and dmax,
        // 22x apart on accuracy for the same request until #571 gave them one contract.
        guard let through = Shape.plateSurface(through: points, tolerance: 0.01),
              let named = Shape.plateSurface(points: points, tolerance: 0.01) else {
            Issue.record("plate build failed")
            return
        }
        let throughArea = through.surfaceArea ?? 0
        let namedArea = named.surfaceArea ?? 0
        #expect(throughArea > 0)
        #expect(abs(throughArea - namedArea) < 1e-6,
                "plateSurface(through:) gave \(throughArea), plateSurface(points:) gave \(namedArea)")
    }

    @Test("Curve-constrained plates honour their tolerance too")
    func curveConstrainedPlateHonoursTolerance() {
        // OCCTShapePlateCurves shared the same defective arguments; it is exercised through its
        // own entry point so the shared helper cannot regress for one caller only. The boundary
        // is a warped octagon, a four-corner ring is reproduced by one patch and proves nothing.
        var corners: [SIMD3<Double>] = []
        for i in 0..<8 {
            let angle = Double(i) * .pi / 4
            corners.append(SIMD3(8 * cos(angle), 8 * sin(angle), 3 * sin(Double(i) * 2.1)))
        }
        guard let wire = Wire.polygon3D(corners, closed: true),
              let shape = Shape.plateSurface(constrainedBy: [wire], continuity: .g0,
                                             tolerance: 0.01),
              let face = shape.face(at: 0) else {
            Issue.record("curve-constrained plate build failed")
            return
        }
        #expect((shape.surfaceArea ?? 0) > 0)
        // The plate is built to pass through its boundary, so the fitted face must too.
        var worst = 0.0
        for corner in corners {
            guard let projection = face.project(point: corner) else { continue }
            worst = max(worst, projection.distance)
        }
        #expect(worst <= 0.01, "boundary deviation \(worst) exceeds the requested tolerance 0.01")
    }
}
