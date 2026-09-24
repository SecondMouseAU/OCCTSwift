import Testing
import simd

@testable import OCCTSwift

@Suite("GeomFill Frenet Trihedron Tests")
struct GeomFillFrenetTests {
    @Test func frenetOnEdge() {
        // #766: this looped over edges until one answered and checked only T . N ~ 0, which a
        // swapped tangent and normal also satisfy; its guards returned silently. Edge 0 is the
        // top circle; GeomFill_Frenet at 0 gives T (0, 1, 0), N (-1, 0, 0) toward the centre,
        // B (0, 0, 1), see Scripts/repro/766-geomfill-b/.
        let cyl = Shape.cylinder(radius: 10, height: 5)
        #expect(cyl != nil)
        guard let edge = cyl?.subShapes(ofType: .edge).first else { return }
        let frame = edge.frenetTrihedron(at: 0)
        #expect(frame != nil)
        if let frame {
            #expect(abs(simd_dot(frame.tangent, frame.normal)) < 1e-4)
            #expect(simd_length(frame.tangent - SIMD3(0, 1, 0)) < 1e-9)
            #expect(simd_length(frame.normal - SIMD3(-1, 0, 0)) < 1e-9)
            #expect(simd_length(frame.binormal - SIMD3(0, 0, 1)) < 1e-9)
        }
    }

    @Test func constantBiNormal() {
        // #766: looped until an edge answered and its guards returned silently. Pinned to
        // GeomFill_ConstantBiNormal(+Z) at 0 on edge 0: T (0, 1, 0), N (-1, 0, 0), B (0, 0, 1),
        // see Scripts/repro/766-geomfill-b/.
        let cyl = Shape.cylinder(radius: 10, height: 5)
        #expect(cyl != nil)
        guard let edge = cyl?.subShapes(ofType: .edge).first else { return }
        let frame = edge.constantBiNormalTrihedron(at: 0, biNormal: SIMD3(0, 0, 1))
        #expect(frame != nil)
        if let frame {
            #expect(abs(frame.binormal.z) > 0.9)
            #expect(simd_length(frame.tangent - SIMD3(0, 1, 0)) < 1e-9)
            #expect(simd_length(frame.normal - SIMD3(-1, 0, 0)) < 1e-9)
            #expect(simd_length(frame.binormal - SIMD3(0, 0, 1)) < 1e-9)
        }
    }

    @Test func fixedTrihedron() {
        let frame = Shape.fixedTrihedron(tangent: SIMD3(1, 0, 0), normal: SIMD3(0, 1, 0))
        #expect(abs(frame.tangent.x - 1.0) < 1e-6)
        #expect(abs(frame.normal.y - 1.0) < 1e-6)
        #expect(abs(frame.binormal.z - 1.0) < 1e-6)
    }
}
