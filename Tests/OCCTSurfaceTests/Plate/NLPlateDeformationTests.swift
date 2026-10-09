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
    // Three cases used to miss their targets (#3133, #3135): with several G0 targets, or with a G1
    // target, the kernel's solve met every target but the surface the bridge fitted to it did not
    // (by up to 5.4, the 3D distance at (-5, -5) on the three-target G0 case), and the two-target
    // G1 case came back nil although the kernel solves it. They are plain expectations now, and
    // each was run against the unfixed bridge and failed there.
    private func near(_ s: Surface, _ uv: SIMD2<Double>, _ target: SIMD3<Double>, _ tol: Double)
        -> Bool
    {
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
            #expect(near(d, SIMD2(-5, -5), SIMD3(-5, -5, 1), 0.1))
            #expect(near(d, SIMD2(5, 5), SIMD3(5, 5, 2), 0.1))
            #expect(near(d, SIMD2(0, 0), SIMD3(0, 0, 5), 0.1))
        }
    }

    // Root cause of #3133/#3134/#3135: the targets must be met wherever they sit, not only when
    // they land on the sampling lattice. These (u, v) are deliberately off any uniform lattice of
    // the working domain, and the tolerance is tight enough that a fit bound could not excuse a
    // miss. G0, G1 and G2 all go through the same sample-and-interpolate tail.
    @Test("NLPlate targets are met off the sampling lattice, for G0, G1 and G2")
    func nlPlateTargetsOffLattice() {
        guard let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)) else {
            Issue.record("plane fixture failed")
            return
        }
        let uvA = SIMD2(0.37, -1.23)
        let uvB = SIMD2(-2.91, 3.07)
        let tA = SIMD3(0.37, -1.23, 2.5)
        let tB = SIMD3(-2.91, 3.07, -1.5)

        let g0 = plane.nlPlateDeformed(
            constraints: [(uv: uvA, target: tA), (uv: uvB, target: tB)],
            resolutionOrder: 4, tolerance: 1e-6)
        #expect(g0 != nil)
        if let d = g0 {
            // 1e-4, not 1e-6: the kernel's own G0 solve leaves a residual of about 5e-6 at a
            // target (Scripts/repro/766-nlplate-deformation/transcript.txt), which is not ours.
            #expect(near(d, uvA, tA, 1e-4))
            #expect(near(d, uvB, tB, 1e-4))
        }

        let g1 = plane.nlPlateDeformedG1(
            constraints: [
                (uv: uvA, target: tA, tangentU: SIMD3(1, 0, 0.1), tangentV: SIMD3(0, 1, 0.1)),
                (uv: uvB, target: tB, tangentU: SIMD3(1, 0, -0.1), tangentV: SIMD3(0, 1, 0)),
            ],
            resolutionOrder: 4, tolerance: 1e-6)
        #expect(g1 != nil)
        if let d = g1 {
            #expect(near(d, uvA, tA, 1e-6))
            #expect(near(d, uvB, tB, 1e-6))
        }

        let g2 = plane.nlPlateDeformedG2(constraints: [
            (
                uv: uvA, target: tA, tangentU: SIMD3(1, 0, 0), tangentV: SIMD3(0, 1, 0),
                curvatureUU: SIMD3(0, 0, 0.1), curvatureUV: .zero, curvatureVV: SIMD3(0, 0, 0.1)
            )
        ])
        #expect(g2 != nil)
        if let d = g2 {
            #expect(near(d, uvA, tA, 1e-6))
        }
    }

    // A base surface that does not pass through the origin, so a constraint's (x, y) is not
    // trivially its (u, v) and a parametrisation that drifted (the chord-length rescale of
    // #3133) would show as an x/y miss as well as a z one.
    @Test("NLPlate G0 targets are met on an offset plane with a tight tolerance")
    func nlPlateG0OffsetPlane() {
        guard let plane = Surface.plane(origin: SIMD3(100, 0, 0), normal: SIMD3(0, 0, 1)) else {
            Issue.record("plane fixture failed")
            return
        }
        // The fixture plane is parametrised as (100 + u, v, 0) (see #1049's suite).
        let cs: [(uv: SIMD2<Double>, target: SIMD3<Double>)] = [
            (uv: SIMD2(-4, -3), target: SIMD3(96, -3, 1)),
            (uv: SIMD2(4, 3), target: SIMD3(104, 3, 6)),
            (uv: SIMD2(0, 0), target: SIMD3(100, 0, -2)),
        ]
        let deformed = plane.nlPlateDeformed(constraints: cs, resolutionOrder: 4, tolerance: 1e-4)
        #expect(deformed != nil)
        if let d = deformed {
            for c in cs { #expect(near(d, c.uv, c.target, 1e-4)) }
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
            #expect(near(d, SIMD2(0, 0), SIMD3(0, 0, 5), 0.1))
        }
    }

    @Test("NLPlate G1 with multiple position + tangent constraints")
    func nlPlateG1MultipleConstraints() {
        let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        guard let surface = plane else { return }

        // Closer constraints and a higher resolution order (the plate's order, not an iteration
        // count) so the kernel's solve converges; the loose tolerance of 1.0 deliberately gives the
        // coarsest lattice (12 nodes per direction), which the constraint nodes must still survive.
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
        #expect(deformed != nil)
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
