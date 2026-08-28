import Testing
import simd

@testable import OCCTSwift

@Suite("GeomFill Frenet Trihedron Tests")
struct GeomFillFrenetTests {
    @Test func frenetOnEdge() {
        guard let cyl = Shape.cylinder(radius: 10, height: 5) else { return }
        let edges = cyl.subShapes(ofType: .edge)
        guard !edges.isEmpty else { return }
        for edge in edges {
            if let frame = edge.frenetTrihedron(at: 0) {
                let dot = simd_dot(frame.tangent, frame.normal)
                #expect(abs(dot) < 1e-4)
                return
            }
        }
    }

    @Test func constantBiNormal() {
        guard let cyl = Shape.cylinder(radius: 10, height: 5) else { return }
        let edges = cyl.subShapes(ofType: .edge)
        guard !edges.isEmpty else { return }
        for edge in edges {
            if let frame = edge.constantBiNormalTrihedron(at: 0, biNormal: SIMD3(0, 0, 1)) {
                #expect(abs(frame.binormal.z) > 0.9)
                return
            }
        }
    }

    @Test func fixedTrihedron() {
        let frame = Shape.fixedTrihedron(tangent: SIMD3(1, 0, 0), normal: SIMD3(0, 1, 0))
        #expect(abs(frame.tangent.x - 1.0) < 1e-6)
        #expect(abs(frame.normal.y - 1.0) < 1e-6)
        #expect(abs(frame.binormal.z - 1.0) < 1e-6)
    }
}
