import Foundation
import Testing
import simd

@testable import OCCTSwift

/// Volumes are the pinned kernel's, read by `Scripts/repro/766-asymchamfer-cinert-vinert/` through
/// the same `BRepFilletAPI_MakeChamfer::Add(d1, d2, edge, face)` call `OCCTShapeChamferTwoDistances`
/// makes. A chamfer that ignored `dist2` (a symmetric chamfer at `dist1`) is a valid solid too, so
/// validity alone cannot tell the two apart: only the volume removed does.
@Suite("Asymmetric Chamfer (Two Distances)")
struct AsymmetricChamferTests {
    @Test("Two-distance chamfer on box edge")
    func twoDistChamfer() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        // Chamfer edge 0 with dist1=1.0 on face 0, dist2=2.0 on other face
        let r = try #require(
            box.chamferedTwoDistances([
                (edgeIndex: 0, faceIndex: 0, dist1: 1.0, dist2: 2.0)
            ]))
        #expect(r.isValid)
        // 1000 minus a 1 x 2 right-triangle prism 10 long. At dist2 = dist1 it would be 995.
        #expect(abs((r.volume ?? 0) - 990.0) < 1e-6, "volume \(String(describing: r.volume))")
    }

    @Test("Multiple edges with different asymmetric chamfers")
    func multiEdgeChamfer() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let r = try #require(
            box.chamferedTwoDistances([
                (edgeIndex: 0, faceIndex: 0, dist1: 0.5, dist2: 1.0),
                (edgeIndex: 1, faceIndex: 0, dist1: 0.8, dist2: 0.6),
            ]))
        #expect(r.isValid)
        // Kernel: 995.196. With each dist2 replaced by its dist1 it is 995.62916666666661.
        #expect(abs((r.volume ?? 0) - 995.196) < 1e-6, "volume \(String(describing: r.volume))")
    }
}
