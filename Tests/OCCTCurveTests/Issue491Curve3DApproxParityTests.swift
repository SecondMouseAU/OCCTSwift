import Foundation
import Testing
import simd

@testable import OCCTSwift

/// `Curve3D` wraps `GeomConvert_ApproxCurve` twice: ``Curve3D/approximated(tolerance:continuity:maxSegments:maxDegree:)``
/// returns the fitted BSpline, and ``Curve3D/approxWithDetails(tolerance:continuity:maxSegments:maxDegree:)``
/// returns the same fit alongside the diagnostics OCCT already computed for it. Both go through
/// one shared bridge helper as of #491, so for identical inputs they must agree on whether the
/// approximation succeeded and hand back the same curve, the second differing from the first
/// only by carrying `maxError`/`isDone`/`hasResult`.
///
/// Before #491 the two bridge functions gated their result on different accessors:
/// `OCCTCurve3DApproximate` on `IsDone()`, `OCCTGeomConvertApproxCurve` on `HasResult()`. The
/// header documents those as different questions ("within required tolerance" vs "a result that
/// is not NECESSARILY within the required tolerance"), so on paper the pair could disagree for a
/// completed-but-over-tolerance fit.
///
/// Measured against the pinned kernel, they cannot: `GeomConvert_ApproxCurve` copies both flags
/// straight off `AdvApprox_ApproxAFunction`, whose only `HasResult && !IsDone` path is the
/// `ErrorCode = -1` assignment at `AdvApprox_ApproxAFunction.cxx:550`, commented out upstream
/// ("// for now ErrorCode=-1;"). With that line dead, `ErrorCode` is only ever 0 (both flags set)
/// or 1 (neither set), so the two accessors are equal for every input. The starved-fit cases
/// below confirm it empirically: a circle fitted with one segment at degree 3 against a 1e-9
/// tolerance reports `maxError` around 5.1 and still reports `isDone`.
///
/// So these tests pin a contract that the pre-#491 code happened to satisfy by accident. They are
/// the guard for the day that upstream line is re-enabled, at which point the shared `HasResult()`
/// gate keeps the pair together instead of splitting it.
@Suite("Curve3D approximation parity: approximated vs approxWithDetails (#491)")
struct Issue491Curve3DApproxParityTests {

    /// One approximation request, run through both entry points.
    private struct Request {
        let label: String
        let curve: Curve3D
        let tolerance: Double
        let continuity: ParametricContinuity
        let maxSegments: Int
        let maxDegree: Int
    }

    private func requests() -> [Request] {
        var result: [Request] = []

        if let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 10) {
            // The defaults both entry points declare.
            result.append(
                Request(
                    label: "circle r=10, shared defaults", curve: circle,
                    tolerance: 1e-3, continuity: .c2, maxSegments: 100, maxDegree: 8))
            // Starved: one segment at degree 3 cannot reach 1e-9 on a circle. This is the case
            // the IsDone/HasResult split was supposed to separate.
            result.append(
                Request(
                    label: "circle r=10, 1 segment degree 3, tol 1e-9", curve: circle,
                    tolerance: 1e-9, continuity: .c0, maxSegments: 1, maxDegree: 3))
            result.append(
                Request(
                    label: "circle r=10, 2 segments degree 3, tol 1e-9", curve: circle,
                    tolerance: 1e-9, continuity: .c0, maxSegments: 2, maxDegree: 3))
            // Unreachable tolerance with generous budget: fills the segment stack instead.
            result.append(
                Request(
                    label: "circle r=10, tol 1e-15", curve: circle,
                    tolerance: 1e-15, continuity: .c2, maxSegments: 100, maxDegree: 8))
        }
        if let ellipse = Curve3D.ellipse(
            center: .zero, normal: SIMD3(0, 0, 1),
            majorRadius: 50, minorRadius: 1)
        {
            result.append(
                Request(
                    label: "ellipse 50x1, shared defaults", curve: ellipse,
                    tolerance: 1e-3, continuity: .c2, maxSegments: 100, maxDegree: 8))
            result.append(
                Request(
                    label: "ellipse 50x1, 1 segment degree 3", curve: ellipse,
                    tolerance: 1e-9, continuity: .c0, maxSegments: 1, maxDegree: 3))
            result.append(
                Request(
                    label: "ellipse 50x1, degree 4 in 4 segments", curve: ellipse,
                    tolerance: 1e-12, continuity: .c2, maxSegments: 4, maxDegree: 4))
        }
        if let line = Curve3D.line(through: SIMD3(1, 2, 3), direction: SIMD3(1, 1, 0)),
            let segment = line.trimmed(from: 0, to: 10)
        {
            result.append(
                Request(
                    label: "line segment", curve: segment,
                    tolerance: 1e-6, continuity: .c1, maxSegments: 10, maxDegree: 3))
        }
        return result
    }

    /// `maxSegments` and `maxDegree` are two adjacent `int32_t` both entry points forward to the one
    /// shared helper. Unlike the surface pair they are declared in the same order on both sides, so
    /// no re-ordering happens here, but a request whose two values are interchangeable could not
    /// catch a swap either way, so this pins that they are order-sensitive and that both entry points
    /// read them the same way.
    ///
    /// It deliberately does not assert `degree <= maxDegree`: OCCT does not treat `MaxDegree` as a
    /// hard cap (`maxDegree: 4` on this ellipse comes back degree 5, `lesparam` keeps "a reserve
    /// coefficient"), and it does so identically through both entry points.
    @Test("maxSegments and maxDegree are order-sensitive, and both entry points agree on the order")
    func maxDegreeIsNotSwappedWithMaxSegments() {
        guard
            let ellipse = Curve3D.ellipse(
                center: .zero, normal: SIMD3(0, 0, 1),
                majorRadius: 50, minorRadius: 1)
        else {
            Issue.record("ellipse fixture failed")
            return
        }
        let asRequested = ellipse.approximated(
            tolerance: 1e-6, continuity: 2,
            maxSegments: 40, maxDegree: 5)
        let swapped = ellipse.approximated(
            tolerance: 1e-6, continuity: 2,
            maxSegments: 5, maxDegree: 40)
        #expect(asRequested != nil)
        #expect(swapped != nil)
        if let a = asRequested, let b = swapped {
            #expect(
                a.degree != b.degree || a.poleCount != b.poleCount,
                "maxSegments/maxDegree are interchangeable on this input, so no test here can detect a swap: \(a.degree)/\(a.poleCount ?? -1) vs \(b.degree)/\(b.poleCount ?? -1)"
            )
        }

        let detailed = ellipse.approxWithDetails(
            tolerance: 1e-6, continuity: .c2,
            maxSegments: 40, maxDegree: 5)
        if let a = asRequested, let withDetails = detailed.curve {
            #expect(a.degree == withDetails.degree)
            #expect(a.poleCount == withDetails.poleCount)
        } else {
            Issue.record("one entry point returned no curve for maxSegments 40 / maxDegree 5")
        }
    }

    private func sampled(_ curve: Curve3D, steps: Int = 12) -> [SIMD3<Double>] {
        let domain = curve.domain
        return (0...steps).map { i in
            curve.point(
                at: domain.lowerBound
                    + (domain.upperBound - domain.lowerBound) * Double(i) / Double(steps))
        }
    }

    @Test("Both entry points succeed, or neither does, on the same request")
    func successAgrees() {
        let all = requests()
        #expect(!all.isEmpty, "no request could be constructed, the fixtures themselves failed")

        for request in all {
            let plain = request.curve.approximated(
                tolerance: request.tolerance,
                continuity: Int(request.continuity.rawValue),
                maxSegments: request.maxSegments,
                maxDegree: request.maxDegree)
            let detailed = request.curve.approxWithDetails(
                tolerance: request.tolerance,
                continuity: request.continuity,
                maxSegments: request.maxSegments,
                maxDegree: request.maxDegree)
            #expect(
                (plain != nil) == (detailed.curve != nil),
                "\(request.label): approximated \(plain == nil ? "nil" : "curve") but approxWithDetails \(detailed.curve == nil ? "nil" : "curve")"
            )
            #expect(
                (plain != nil) == detailed.hasResult,
                "\(request.label): approximated \(plain == nil ? "nil" : "curve") but hasResult = \(detailed.hasResult)"
            )
        }
    }

    @Test("Both entry points return the same fitted curve")
    func geometryMatches() {
        for request in requests() {
            let plain = request.curve.approximated(
                tolerance: request.tolerance,
                continuity: Int(request.continuity.rawValue),
                maxSegments: request.maxSegments,
                maxDegree: request.maxDegree)
            let detailed = request.curve.approxWithDetails(
                tolerance: request.tolerance,
                continuity: request.continuity,
                maxSegments: request.maxSegments,
                maxDegree: request.maxDegree)
            guard let plain = plain, let withDetails = detailed.curve else { continue }

            #expect(plain.degree == withDetails.degree, "\(request.label): degree differs")
            #expect(
                plain.poleCount == withDetails.poleCount, "\(request.label): pole count differs")

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

    @Test("maxError describes the curve both entry points return")
    func maxErrorDescribesTheSharedFit() {
        for request in requests() {
            let detailed = request.curve.approxWithDetails(
                tolerance: request.tolerance,
                continuity: request.continuity,
                maxSegments: request.maxSegments,
                maxDegree: request.maxDegree)
            guard let fit = detailed.curve else { continue }

            // Sample deviation is a lower bound on the true maximum, so it must not exceed the
            // reported maxError by more than the slack a coarse sampling allows.
            let domain = request.curve.domain
            var deviation = 0.0
            for i in 0...40 {
                let t =
                    domain.lowerBound
                    + (domain.upperBound - domain.lowerBound) * Double(i) / 40.0
                deviation = max(
                    deviation, simd_length(request.curve.point(at: t) - fit.point(at: t)))
            }
            #expect(
                deviation <= detailed.maxError + 1e-6,
                "\(request.label): sampled deviation \(deviation) exceeds reported maxError \(detailed.maxError)"
            )
        }
    }

    /// The completion flags come from one `GeomConvert_ApproxCurve` run, so a `hasResult` without
    /// a curve (or the reverse) would mean the bridge dropped the fit on the floor.
    @Test("hasResult and the returned curve agree")
    func hasResultMatchesTheCurve() {
        for request in requests() {
            let detailed = request.curve.approxWithDetails(
                tolerance: request.tolerance,
                continuity: request.continuity,
                maxSegments: request.maxSegments,
                maxDegree: request.maxDegree)
            #expect(detailed.hasResult == (detailed.curve != nil), "\(request.label)")
            // isDone implies hasResult in either direction the kernel can report.
            if detailed.isDone { #expect(detailed.hasResult, "\(request.label)") }
        }
    }

    /// Documents the starved case that motivated the audit finding: OCCT reports the fit as done
    /// even though its error is nine orders of magnitude past the requested tolerance, which is
    /// why gating on `IsDone()` never actually rejected an over-tolerance curve.
    @Test("An over-tolerance fit is still returned, with its real error reported")
    func overToleranceFitIsReturnedNotDropped() {
        guard let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 10) else {
            Issue.record("circle fixture failed")
            return
        }
        let detailed = circle.approxWithDetails(
            tolerance: 1e-9, continuity: .c0,
            maxSegments: 1, maxDegree: 3)
        #expect(detailed.hasResult)
        #expect(detailed.curve != nil)
        #expect(detailed.maxError > 1e-9, "a one-segment cubic cannot fit a circle to 1e-9")

        #expect(
            circle.approximated(
                tolerance: 1e-9, continuity: 0,
                maxSegments: 1, maxDegree: 3) != nil,
            "approximated must return the same fit approxWithDetails reports")
    }
}
