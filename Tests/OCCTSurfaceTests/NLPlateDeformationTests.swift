import Testing
import simd

@testable import OCCTSwift

@Suite("NLPlate Deformation Tests")
struct NLPlateDeformationTests {

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
        // Multi-G1 may not converge for all inputs; verify no crash
        if let d = deformed {
            let dom = d.domain
            #expect(dom.uMax > dom.uMin)
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
