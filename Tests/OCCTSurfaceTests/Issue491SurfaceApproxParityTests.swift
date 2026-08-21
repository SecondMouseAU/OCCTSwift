import Testing
import Foundation
import simd
@testable import OCCTSwift

/// `Surface` wraps `GeomConvert_ApproxSurface` twice: ``Surface/approximated(tolerance:continuity:maxSegments:maxDegree:)``
/// returns the fitted BSpline surface, and ``Surface/approxWithDetails(tolerance:uContinuity:vContinuity:maxDegree:maxSegments:)``
/// returns the same fit alongside the diagnostics OCCT already computed for it. Both go through
/// one shared bridge helper as of #491, so for identical inputs they must produce the same
/// surface, the second differing from the first only by carrying `maxError`/`isDone`/`hasResult`.
///
/// Before #491 they produced *different* surfaces, for two independent reasons:
///
///  1. `OCCTSurfaceApproximate` passed `PrecisCode = 0` as `GeomConvert_ApproxSurface`'s eighth
///     constructor argument; `OCCTGeomConvertApproxSurface` passed `1`. That argument is a real
///     algorithm knob, not a reserved value: it reaches `AdvApp2Var_Context`'s `iprecis`, which
///     `lesparam` (`AdvApp2Var_Context.cxx:22`) turns into the Jacobi degree and the initial
///     per-axis sample-point count seeding the iterative fit. Measured over 72 bounded cases
///     (8 surface families x 6 tolerances, plus C0/C1 and maxDegree 10 variants), the two codes
///     never disagreed on `IsDone` and produced the same knot/pole layout in 71 of 72, but a
///     different `maxError` in all 72, and in the one layout-differing case (an offset sphere at
///     tolerance 1e-5) `0` met the tolerance with 27x15 poles where `1` used 27x23.
///  2. The two Swift entry points defaulted to different continuity: `.approximated` to C2,
///     `.approxWithDetails` to C1 in both directions. So the no-continuity-argument calls fitted
///     to different smoothness requirements.
///
/// Neither divergence had any test coverage in either direction before this suite.
@Suite("Surface approximation parity: approximated vs approxWithDetails (#491)")
struct Issue491SurfaceApproxParityTests {

    /// One approximation request, run through both entry points.
    private struct Request {
        let label: String
        let surface: Surface
        let tolerance: Double
        let continuity: ParametricContinuity
        let maxSegments: Int
        let maxDegree: Int
    }

    /// Bounded in both parameters, so the fit can be sampled over its own domain. An infinite
    /// surface has to be trimmed before approximation anyway (both entry points document that).
    private func requests() -> [Request] {
        var result: [Request] = []

        if let sphere = Surface.sphere(center: .zero, radius: 10) {
            result.append(Request(label: "sphere r=10, shared defaults", surface: sphere,
                                  tolerance: 1e-3, continuity: .c2, maxSegments: 100, maxDegree: 8))
            result.append(Request(label: "sphere r=10, tol 1e-5", surface: sphere,
                                  tolerance: 1e-5, continuity: .c2, maxSegments: 100, maxDegree: 8))
            // Past what maxDegree 8 can reach: IsDone false, HasResult true.
            result.append(Request(label: "sphere r=10, tol 1e-9", surface: sphere,
                                  tolerance: 1e-9, continuity: .c2, maxSegments: 100, maxDegree: 8))
            result.append(Request(label: "sphere r=10, C0", surface: sphere,
                                  tolerance: 1e-3, continuity: .c0, maxSegments: 100, maxDegree: 8))
            result.append(Request(label: "sphere r=10, C1", surface: sphere,
                                  tolerance: 1e-3, continuity: .c1, maxSegments: 100, maxDegree: 8))
            // The offset of a primitive is the case where PrecisCode 0 and 1 chose different
            // knot layouts, so it is the sharpest check that both now run the same fit.
            if let offsetSphere = sphere.offset(distance: 1.5) {
                result.append(Request(label: "offset sphere +1.5, tol 1e-5", surface: offsetSphere,
                                      tolerance: 1e-5, continuity: .c2,
                                      maxSegments: 100, maxDegree: 8))
                result.append(Request(label: "offset sphere +1.5, shared defaults",
                                      surface: offsetSphere, tolerance: 1e-3, continuity: .c2,
                                      maxSegments: 100, maxDegree: 8))
            }
        }
        if let torus = Surface.torus(origin: .zero, axis: SIMD3(0, 0, 1),
                                     majorRadius: 20, minorRadius: 5) {
            result.append(Request(label: "torus 20/5, shared defaults", surface: torus,
                                  tolerance: 1e-3, continuity: .c2, maxSegments: 100, maxDegree: 8))
            result.append(Request(label: "torus 20/5, tol 1e-9", surface: torus,
                                  tolerance: 1e-9, continuity: .c2, maxSegments: 100, maxDegree: 8))
        }
        if let cylinder = Surface.trimmedCylinder(origin: .zero, direction: SIMD3(0, 0, 1),
                                                  radius: 5, height: 20) {
            result.append(Request(label: "trimmed cylinder r=5", surface: cylinder,
                                  tolerance: 1e-3, continuity: .c2, maxSegments: 100, maxDegree: 8))
        }
        if let cone = Surface.trimmedCone(point1: SIMD3(0, 0, 0), point2: SIMD3(0, 0, 12),
                                          r1: 5, r2: 2) {
            result.append(Request(label: "trimmed cone", surface: cone,
                                  tolerance: 1e-3, continuity: .c2, maxSegments: 100, maxDegree: 8))
            // maxSegments and maxDegree far apart and not interchangeable. The two entry points
            // declare them in opposite orders (`maxSegments:maxDegree:` on .approximated,
            // `maxDegree:maxSegments:` on .approxWithDetails) and the bridge has to re-order them
            // for the shared helper, so a request where the two values are equal, as every other
            // one here is, would not notice a swap.
            result.append(Request(label: "trimmed cone, degree 4 in 20 segments", surface: cone,
                                  tolerance: 1e-3, continuity: .c2, maxSegments: 20, maxDegree: 4))
        }
        return result
    }

    private func sampled(_ surface: Surface, steps: Int = 6) -> [SIMD3<Double>] {
        let d = surface.domain
        var result: [SIMD3<Double>] = []
        for i in 0...steps {
            for j in 0...steps {
                let u = d.uMin + (d.uMax - d.uMin) * Double(i) / Double(steps)
                let v = d.vMin + (d.vMax - d.vMin) * Double(j) / Double(steps)
                result.append(surface.point(atU: u, v: v))
            }
        }
        return result
    }

    @Test("Both entry points succeed, or neither does, on the same request")
    func successAgrees() {
        let all = requests()
        #expect(!all.isEmpty, "no request could be constructed, the fixtures themselves failed")

        for request in all {
            let plain = request.surface.approximated(tolerance: request.tolerance,
                                                     continuity: Int(request.continuity.rawValue),
                                                     maxSegments: request.maxSegments,
                                                     maxDegree: request.maxDegree)
            let detailed = request.surface.approxWithDetails(tolerance: request.tolerance,
                                                            uContinuity: request.continuity,
                                                            vContinuity: request.continuity,
                                                            maxDegree: request.maxDegree,
                                                            maxSegments: request.maxSegments)
            #expect((plain != nil) == (detailed.surface != nil),
                    "\(request.label): approximated \(plain == nil ? "nil" : "surface") but approxWithDetails \(detailed.surface == nil ? "nil" : "surface")")
            #expect((plain != nil) == detailed.hasResult,
                    "\(request.label): approximated \(plain == nil ? "nil" : "surface") but hasResult = \(detailed.hasResult)")
        }
    }

    /// The PrecisCode drift: same tolerance, continuity, degree and segment budget through both
    /// entry points had to give the same BSpline, and did not.
    @Test("Both entry points return the same fitted surface")
    func geometryMatches() {
        for request in requests() {
            let plain = request.surface.approximated(tolerance: request.tolerance,
                                                     continuity: Int(request.continuity.rawValue),
                                                     maxSegments: request.maxSegments,
                                                     maxDegree: request.maxDegree)
            let detailed = request.surface.approxWithDetails(tolerance: request.tolerance,
                                                            uContinuity: request.continuity,
                                                            vContinuity: request.continuity,
                                                            maxDegree: request.maxDegree,
                                                            maxSegments: request.maxSegments)
            guard let plain = plain, let withDetails = detailed.surface else { continue }

            #expect(plain.uDegree == withDetails.uDegree, "\(request.label): uDegree differs")
            #expect(plain.vDegree == withDetails.vDegree, "\(request.label): vDegree differs")
            #expect(plain.uPoleCount == withDetails.uPoleCount,
                    "\(request.label): uPoleCount \(plain.uPoleCount) vs \(withDetails.uPoleCount)")
            #expect(plain.vPoleCount == withDetails.vPoleCount,
                    "\(request.label): vPoleCount \(plain.vPoleCount) vs \(withDetails.vPoleCount)")

            let a = sampled(plain)
            let b = sampled(withDetails)
            #expect(a.count == b.count)
            if a.count == b.count {
                var maxGap = 0.0
                for (pa, pb) in zip(a, b) { maxGap = max(maxGap, simd_length(pa - pb)) }
                #expect(maxGap < 1e-12, "\(request.label): sampled points differ by \(maxGap)")
            }
        }
    }

    /// The default-continuity drift: `.approximated` defaulted to C2 and `.approxWithDetails` to
    /// C1, so the two no-continuity-argument calls fitted to different smoothness.
    @Test("The two entry points share their default continuity")
    func defaultContinuityMatches() {
        guard let sphere = Surface.sphere(center: .zero, radius: 10) else {
            Issue.record("sphere fixture failed")
            return
        }
        let plain = sphere.approximated(tolerance: 1e-3)
        let detailed = sphere.approxWithDetails(tolerance: 1e-3)
        #expect(plain != nil)
        #expect(detailed.surface != nil)
        guard let plain = plain, let withDetails = detailed.surface else { return }

        #expect(plain.uDegree == withDetails.uDegree)
        #expect(plain.vDegree == withDetails.vDegree)
        #expect(plain.uPoleCount == withDetails.uPoleCount,
                "default-continuity call: uPoleCount \(plain.uPoleCount) vs \(withDetails.uPoleCount)")
        #expect(plain.vPoleCount == withDetails.vPoleCount,
                "default-continuity call: vPoleCount \(plain.vPoleCount) vs \(withDetails.vPoleCount)")

        // And the explicit C2 call, the shared default, must reproduce it exactly.
        let explicit = sphere.approxWithDetails(tolerance: 1e-3, uContinuity: .c2, vContinuity: .c2)
        if let explicitSurface = explicit.surface {
            #expect(explicitSurface.uPoleCount == withDetails.uPoleCount)
            #expect(explicitSurface.vPoleCount == withDetails.vPoleCount)
            #expect(abs(explicit.maxError - detailed.maxError) < 1e-15)
        }
    }

    /// `.c0` requests used to be excluded here: `GeomConvert_ApproxSurface` at `GeomAbs_C0` could
    /// collapse a direction to degree 1 and still report a `maxError` five orders of magnitude
    /// below the surface it returned (a full sphere at C0 came back as a straight line across its
    /// own longitude, deviating by 19.9999, reported as 1.07e-4 with `isDone` true). That was an
    /// upstream defect, #522, it predated #491, both entry points hit it identically, and unifying
    /// them neither caused nor fixed it. Fixed in kernel patch `0019`: `mma2ce1_` wrote the U
    /// Jacobi maxima to the V workspace slot, leaving the U ones zero, which made every U
    /// truncation error evaluate to 0. The exclusion is gone and every request is checked.
    @Test("maxError describes the surface both entry points return")
    func maxErrorDescribesTheSharedFit() {
        for request in requests() {
            let detailed = request.surface.approxWithDetails(tolerance: request.tolerance,
                                                            uContinuity: request.continuity,
                                                            vContinuity: request.continuity,
                                                            maxDegree: request.maxDegree,
                                                            maxSegments: request.maxSegments)
            guard let fit = detailed.surface else { continue }

            // Sample deviation is a lower bound on the true maximum, so it must not exceed the
            // reported maxError by more than the slack a coarse sampling allows.
            let d = request.surface.domain
            var deviation = 0.0
            for i in 0...10 {
                for j in 0...10 {
                    let u = d.uMin + (d.uMax - d.uMin) * Double(i) / 10.0
                    let v = d.vMin + (d.vMax - d.vMin) * Double(j) / 10.0
                    deviation = max(deviation,
                                    simd_length(request.surface.point(atU: u, v: v)
                                                - fit.point(atU: u, v: v)))
                }
            }
            #expect(deviation <= detailed.maxError + 1e-6,
                    "\(request.label): sampled deviation \(deviation) exceeds reported maxError \(detailed.maxError)")
        }
    }

    /// Both surface entry points have always gated on `HasResult()`, which OCCT documents as true
    /// even for a fit that is not within the requested tolerance. That leniency is the contract,
    /// and it is why `approxWithDetails` exists: `isDone` is how a caller finds out.
    @Test("An over-tolerance fit is returned by both, with isDone false")
    func overToleranceFitIsReturnedNotDropped() {
        guard let torus = Surface.torus(origin: .zero, axis: SIMD3(0, 0, 1),
                                        majorRadius: 20, minorRadius: 5) else {
            Issue.record("torus fixture failed")
            return
        }
        let detailed = torus.approxWithDetails(tolerance: 1e-9, uContinuity: .c2, vContinuity: .c2,
                                               maxDegree: 8, maxSegments: 100)
        #expect(detailed.hasResult)
        #expect(!detailed.isDone, "maxDegree 8 cannot fit a torus to 1e-9")
        #expect(detailed.maxError > 1e-9)
        #expect(detailed.surface != nil)

        #expect(torus.approximated(tolerance: 1e-9, continuity: 2,
                                   maxSegments: 100, maxDegree: 8) != nil,
                "approximated must return the same fit approxWithDetails reports")
    }

    /// `maxDegree` and `maxSegments` are two adjacent `int32_t` the bridge has to **re-order**: the
    /// two entry points declare them in opposite orders (`maxSegments:maxDegree:` on `.approximated`,
    /// `maxDegree:maxSegments:` on `.approxWithDetails`) and the shared helper takes one order. A
    /// silent swap in either path is the obvious way for this refactor to go wrong.
    ///
    /// `geometryMatches` above covers it for the `degree 4 in 20 segments` request, but only if the
    /// two values are actually distinguishable, swapping interchangeable arguments proves nothing.
    /// So this asserts the pair is order-sensitive first, then that both entry points landed on the
    /// same side of it.
    ///
    /// It deliberately does not assert `uDegree <= maxDegree`: OCCT does not treat `MaxDegU`/`MaxDegV`
    /// as a hard cap. Measured on this cone, `maxDegree: 4` comes back degree 5 (`lesparam` keeps
    /// "a reserve coefficient"), through both entry points alike.
    @Test("maxDegree and maxSegments are order-sensitive, and both entry points agree on the order")
    func maxDegreeIsNotSwappedWithMaxSegments() {
        guard let cone = Surface.trimmedCone(point1: SIMD3(0, 0, 0), point2: SIMD3(0, 0, 12),
                                             r1: 5, r2: 2) else {
            Issue.record("cone fixture failed")
            return
        }
        // Exchanging the two must change the result, otherwise the parity check below is vacuous.
        let asRequested = cone.approximated(tolerance: 1e-3, continuity: 2,
                                            maxSegments: 20, maxDegree: 4)
        let swapped = cone.approximated(tolerance: 1e-3, continuity: 2,
                                        maxSegments: 4, maxDegree: 20)
        #expect(asRequested != nil)
        #expect(swapped != nil)
        if let a = asRequested, let b = swapped {
            #expect(a.uDegree != b.uDegree || a.uPoleCount != b.uPoleCount,
                    "maxSegments/maxDegree are interchangeable on this input, so no test here can detect a swap: \(a.uDegree)/\(a.uPoleCount) vs \(b.uDegree)/\(b.uPoleCount)")
        }

        // Both entry points must land on the unswapped reading.
        let detailed = cone.approxWithDetails(tolerance: 1e-3, uContinuity: .c2, vContinuity: .c2,
                                              maxDegree: 4, maxSegments: 20)
        if let a = asRequested, let withDetails = detailed.surface {
            #expect(a.uDegree == withDetails.uDegree)
            #expect(a.vDegree == withDetails.vDegree)
            #expect(a.uPoleCount == withDetails.uPoleCount)
            #expect(a.vPoleCount == withDetails.vPoleCount)
        } else {
            Issue.record("one entry point returned no surface for maxDegree 4 / maxSegments 20")
        }
    }

    @Test("hasResult and the returned surface agree")
    func hasResultMatchesTheSurface() {
        for request in requests() {
            let detailed = request.surface.approxWithDetails(tolerance: request.tolerance,
                                                            uContinuity: request.continuity,
                                                            vContinuity: request.continuity,
                                                            maxDegree: request.maxDegree,
                                                            maxSegments: request.maxSegments)
            #expect(detailed.hasResult == (detailed.surface != nil), "\(request.label)")
            if detailed.isDone { #expect(detailed.hasResult, "\(request.label)") }
        }
    }
}
