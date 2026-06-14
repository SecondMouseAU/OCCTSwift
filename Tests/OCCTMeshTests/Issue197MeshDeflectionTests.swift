import Testing
import Foundation
import simd
@testable import OCCTSwift

// #197: mesh deflection was hardcoded to 0.1 in several auto-meshing utility functions
// (STL writers, coherent-triangulation builder, proximity, self-intersection). Each now
// exposes a `deflection:` parameter (default 0.1, non-breaking) so callers can trade
// triangulation fidelity for speed/size — the same class of knob exposed for poly HLR in #196.
//
// NB: BRepMesh_IncrementalMesh is incremental (refines, never coarsens), so each deflection
// must be exercised on its OWN fresh shape, or a prior finer mesh would mask the parameter.
@Suite("Issue #197 — mesh deflection is a caller-tunable parameter")
struct Issue197MeshDeflectionTests {

    private func sphere() -> Shape? { Shape.sphere(radius: 10) }

    @Test("binary STL: finer deflection yields a larger file (more triangles)")
    func stlBinaryDeflection() throws {
        guard let coarseShape = sphere(), let fineShape = sphere() else {
            Issue.record("no sphere"); return
        }
        let dir = FileManager.default.temporaryDirectory
        let coarseURL = dir.appendingPathComponent("occt197_coarse_\(UUID().uuidString).stl")
        let fineURL = dir.appendingPathComponent("occt197_fine_\(UUID().uuidString).stl")
        defer { try? FileManager.default.removeItem(at: coarseURL); try? FileManager.default.removeItem(at: fineURL) }

        #expect(coarseShape.writeSTLBinary(to: coarseURL.path, deflection: 1.0))
        #expect(fineShape.writeSTLBinary(to: fineURL.path, deflection: 0.05))

        let coarseSize = (try? FileManager.default.attributesOfItem(atPath: coarseURL.path))?[.size] as? Int ?? 0
        let fineSize = (try? FileManager.default.attributesOfItem(atPath: fineURL.path))?[.size] as? Int ?? 0
        // Binary STL size = 84 + 50·triangles, so size is a direct proxy for triangle count.
        #expect(coarseSize > 0)
        #expect(fineSize > coarseSize)
    }

    @Test("default deflection (0.1) still writes a valid STL")
    func stlDefaultUnchanged() {
        guard let s = sphere() else { Issue.record("no sphere"); return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("occt197_default_\(UUID().uuidString).stl")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(s.writeSTLBinary(to: url.path))   // default deflection
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int ?? 0
        #expect(size > 84)
    }

    @Test("coherent triangulation builds at the requested deflection")
    func coherentTriangulationDeflection() {
        guard let s = sphere() else { Issue.record("no sphere"); return }
        let tri = CoherentTriangulation.createFromMesh(s, deflection: 0.2)
        #expect(tri != nil)
    }
}
