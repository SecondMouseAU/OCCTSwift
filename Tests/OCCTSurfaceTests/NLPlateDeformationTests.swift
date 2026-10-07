import Testing
import simd

@testable import OCCTSwift

@Suite("NLPlate Deformation Tests")
struct NLPlateDeformationTests {

    // #766: the deformation tests asserted only non-nil, a finite coordinate or `uMax > uMin`,
    // so a deformation that ignored its targets passed; one (`nlPlateG1MultipleConstraints`)
    // asserted nothing at all when the solve failed. Each now requires the deformed surface to
    // pass through its targets at their (u, v) within the fit tolerance it asked for. The
    // targets are what NLPlate_NLPlate::Evaluate returns at those (u, v) after the same
    // Solve2(order, 1), see Scripts/repro/766-nlplate-deformation/.
    //
    // Three cases do NOT hold today and are pinned as known issues rather than loosened: with
    // several G0 targets, or with a G1 target, the kernel's solve meets every target but the
    // surface the bridge fits to it misses them (by up to 4.5 on the three-target G0 case), and
    // the two-target G1 case comes back nil although the kernel solves it. `withKnownIssue` fails
    // the moment the targets start being met, so these cannot silently stay wrong once fixed.
    private func near(_ s: Surface, _ uv: SIMD2<Double>, _ target: SIMD3<Double>, _ tol: Double) -> Bool {
        let p = s.point(atU: uv.x, v: uv.y)
        let d = p - target
        return (d.x * d.x + d.y * d.y + d.z * d.z).squareRoot() < tol
    }

    @Test("NLPlate G0 deformation of flat plane")
    func nlPlateG0FlatPlane() {
        let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        #expect(plane != nil)
        guard let surface = plane else { return }

        let deformed = surface.nlPlateDeformed(
            constraints: [(uv: SIMD2(0, 0), target: SIMD3(0, 0, 5))],
            resolutionOrder: 4,
            tolerance: 0.1
        )
        #expect(deformed != nil)
        if let d = deformed {
            let domain = d.domain
            let midU = (domain.uMin + domain.uMax) / 2
            let midV = (domain.vMin + domain.vMax) / 2
            let pt = d.point(atU: midU, v: midV)
            #expect(pt.z.isFinite)
            #expect(near(d, SIMD2(0, 0), SIMD3(0, 0, 5), 0.1))
        }
    }

    @Test("NLPlate G0 with multiple constraints")
    func nlPlateG0MultipleConstraints() {
        let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        guard let surface = plane else {
            #expect(Bool(false), "Failed to create plane")
            return
        }

        let deformed = surface.nlPlateDeformed(
            constraints: [
                (uv: SIMD2(-5, -5), target: SIMD3(-5, -5, 1)),
                (uv: SIMD2(5, 5), target: SIMD3(5, 5, 2)),
                (uv: SIMD2(0, 0), target: SIMD3(0, 0, 5)),
            ],
            resolutionOrder: 4,
            tolerance: 0.1
        )
        #expect(deformed != nil)
        if let d = deformed {
            withKnownIssue("#766 parity MISMATCH: NLPlate_NLPlate solves these targets exactly (probe), but the bridge's fitted surface misses them; see Scripts/repro/766-nlplate-deformation/") {
                #expect(near(d, SIMD2(-5, -5), SIMD3(-5, -5, 1), 0.1))
                #expect(near(d, SIMD2(5, 5), SIMD3(5, 5, 2), 0.1))
                #expect(near(d, SIMD2(0, 0), SIMD3(0, 0, 5), 0.1))
            }
        }
    }

    @Test("NLPlate G0 deformation produces evaluable surface")
    func nlPlateG0Evaluable() {
        let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        guard let surface = plane else { return }

        let deformed = surface.nlPlateDeformed(
            constraints: [(uv: SIMD2(0, 0), target: SIMD3(0, 0, 3))],
            resolutionOrder: 4,
            tolerance: 0.1
        )
        #expect(deformed != nil)
        if let d = deformed {
            let dom = d.domain
            #expect(dom.uMax > dom.uMin)
            #expect(near(d, SIMD2(0, 0), SIMD3(0, 0, 3), 0.1))
        }
    }

    @Test("NLPlate G0 with empty constraints returns nil")
    func nlPlateG0EmptyConstraints() {
        let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        guard let surface = plane else { return }
        let deformed = surface.nlPlateDeformed(
            constraints: [],
            resolutionOrder: 4,
            tolerance: 0.1
        )
        #expect(deformed == nil)
    }

    @Test("NLPlate G1 deformation with position + tangent constraints")
    func nlPlateG1Deformation() {
        let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        guard let surface = plane else { return }

        // G0+G1: target position + desired tangent vectors
        let deformed = surface.nlPlateDeformedG1(
            constraints: [
                (
                    uv: SIMD2(0, 0), target: SIMD3(0, 0, 5),
                    tangentU: SIMD3(1, 0, 0.5), tangentV: SIMD3(0, 1, 0.5)
                )
            ],
            resolutionOrder: 4,
            tolerance: 0.1
        )
        #expect(deformed != nil)
        if let d = deformed {
            let dom = d.domain
            #expect(dom.uMax > dom.uMin)
            withKnownIssue("#766 parity MISMATCH: NLPlate_NLPlate solves these targets exactly (probe), but the bridge's fitted surface misses them; see Scripts/repro/766-nlplate-deformation/") {
                #expect(near(d, SIMD2(0, 0), SIMD3(0, 0, 5), 0.1))
            }
        }
    }

    @Test("NLPlate G1 with multiple position + tangent constraints")
    func nlPlateG1MultipleConstraints() {
        let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        guard let surface = plane else { return }

        // Use closer constraints with more iterations for convergence
        let deformed = surface.nlPlateDeformedG1(
            constraints: [
                (
                    uv: SIMD2(-2, 0), target: SIMD3(-2, 0, 1),
                    tangentU: SIMD3(1, 0, 0.2), tangentV: SIMD3(0, 1, 0)
                ),
                (
                    uv: SIMD2(2, 0), target: SIMD3(2, 0, 1),
                    tangentU: SIMD3(1, 0, -0.2), tangentV: SIMD3(0, 1, 0)
                ),
            ],
            resolutionOrder: 8,
            tolerance: 1.0
        )
        // The kernel's solve converges on this input (probe), so the result should exist.
        withKnownIssue("#766 parity MISMATCH: NLPlate_NLPlate solves these targets exactly (probe), but the bridge's fitted surface misses them; see Scripts/repro/766-nlplate-deformation/") {
            #expect(deformed != nil)
        }
        if let d = deformed {
            let dom = d.domain
            #expect(dom.uMax > dom.uMin)
            #expect(near(d, SIMD2(-2, 0), SIMD3(-2, 0, 1), 1.0))
            #expect(near(d, SIMD2(2, 0), SIMD3(2, 0, 1), 1.0))
        }
    }

    @Test("NLPlate G1 with empty constraints returns nil")
    func nlPlateG1EmptyConstraints() {
        let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        guard let surface = plane else { return }
        let deformed = surface.nlPlateDeformedG1(
            constraints: [],
            resolutionOrder: 4,
            tolerance: 0.1
        )
        #expect(deformed == nil)
    }
}
