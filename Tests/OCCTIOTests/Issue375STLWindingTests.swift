import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Issue #375: loadSTL winding fidelity

// #375: reported that `Shape.loadSTL()` might not reliably preserve a globally-reversed (but
// self-consistent) STL's winding, that a round trip could come back locally inconsistent
// instead of cleanly globally inverted. Empirically confirmed NOT to be a bug (ground-truth
// C++ test against `StlAPI_Reader` + `BRepMesh_IncrementalMesh` directly): winding is preserved
// exactly, including a full uniform reversal. The "locally inconsistent" observation that
// prompted the issue traced to a defect in the *reporting* test fixture's own STL-generation
// helper (a copy-pasted, unmirrored top-face vertex order), not to OCCTSwift.
@Suite("Issue #375, Shape.loadSTL() preserves facet winding, including a global reversal")
struct Issue375STLWindingTests {

    /// A hand-written, watertight, unit-half-extent box STL: 6 quads (2 triangles each), every
    /// face's own outward normal independently right-hand-rule-verified. `reversedGlobally`
    /// flips every facet's vertex order uniformly (a self-consistent, globally-inverted file).
    private func boxSTL(halfExtent e: Double, reversedGlobally: Bool) -> String {
        typealias V = SIMD3<Double>
        func quad(_ a: V, _ b: V, _ c: V, _ d: V) -> [(V, V, V)] {
            let order = reversedGlobally ? [a, d, c, b] : [a, b, c, d]
            return [(order[0], order[1], order[2]), (order[0], order[2], order[3])]
        }
        var tris: [(V, V, V)] = []
        tris += quad(V(-e, -e, -e), V(-e, e, -e), V(e, e, -e), V(e, -e, -e))  // -Z
        tris += quad(V(-e, -e, e), V(e, -e, e), V(e, e, e), V(-e, e, e))  // +Z
        tris += quad(V(e, -e, -e), V(e, e, -e), V(e, e, e), V(e, -e, e))  // +X
        tris += quad(V(-e, -e, -e), V(-e, -e, e), V(-e, e, e), V(-e, e, -e))  // -X
        tris += quad(V(-e, e, -e), V(-e, e, e), V(e, e, e), V(e, e, -e))  // +Y
        tris += quad(V(-e, -e, -e), V(e, -e, -e), V(e, -e, e), V(-e, -e, e))  // -Y

        var out = "solid box\n"
        for (a, b, c) in tris {
            let n = simd_normalize(simd_cross(b - a, c - a))
            out += "  facet normal \(n.x) \(n.y) \(n.z)\n    outer loop\n"
            out += "      vertex \(a.x) \(a.y) \(a.z)\n"
            out += "      vertex \(b.x) \(b.y) \(b.z)\n"
            out += "      vertex \(c.x) \(c.y) \(c.z)\n"
            out += "    endloop\n  endfacet\n"
        }
        out += "endsolid box\n"
        return out
    }

    /// Fraction of `mesh`'s triangles whose (v1,v2,v3) winding faces away from `center` --
    /// cross(v2-v1, v3-v1) points away from the center, the expected convention for a convex
    /// solid's outward-facing mesh. 1.0 = fully outward, 0.0 = fully inward (a clean global
    /// inversion), anything strictly between = locally inconsistent.
    private func outwardFraction(of mesh: Mesh, center: SIMD3<Float>) -> Double {
        let verts = mesh.vertices
        let idx = mesh.indices
        var outward = 0
        var total = 0
        var i = 0
        while i + 2 < idx.count {
            let p1 = verts[Int(idx[i])]
            let p2 = verts[Int(idx[i + 1])]
            let p3 = verts[Int(idx[i + 2])]
            let normal = simd_cross(p2 - p1, p3 - p1)
            if simd_dot(normal, p1 - center) > 0 { outward += 1 }
            total += 1
            i += 3
        }
        return Double(outward) / Double(total)
    }

    private func writeAndLoad(_ stl: String) throws -> Shape {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("stl")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try stl.write(to: tempURL, atomically: true, encoding: .utf8)
        return try Shape.loadSTL(from: tempURL)
    }

    @Test("a normally-wound STL round-trips fully outward")
    func normalWindingRoundTripsOutward() throws {
        let shape = try writeAndLoad(boxSTL(halfExtent: 5, reversedGlobally: false))
        let mesh = try #require(shape.mesh(linearDeflection: 0.5, angularDeflection: 0.5))
        #expect(
            mesh.indices.count == 36,
            "expected exactly 12 triangles (6 faces x 2), got \(mesh.indices.count / 3)")
        #expect(outwardFraction(of: mesh, center: .zero) == 1.0)
    }

    @Test(
        "a globally reversed (but self-consistent) STL round-trips as a CLEAN global inversion, not local inconsistency"
    )
    func globallyReversedWindingRoundTripsInward() throws {
        let shape = try writeAndLoad(boxSTL(halfExtent: 5, reversedGlobally: true))
        let mesh = try #require(shape.mesh(linearDeflection: 0.5, angularDeflection: 0.5))
        #expect(
            mesh.indices.count == 36,
            "expected exactly 12 triangles (6 faces x 2), got \(mesh.indices.count / 3)")

        // "Locally inconsistent" (the #375 concern) would show up here as a fraction strictly
        // between 0 and 1 -- some faces one way, some the other. A clean global inversion reads
        // exactly 0.0 (fully inward, i.e. zero triangles facing outward).
        let fraction = outwardFraction(of: mesh, center: .zero)
        #expect(
            fraction == 0.0,
            "expected a clean global inversion (0.0 outward), got \(fraction) -- a value strictly between 0 and 1 would mean the round trip introduced local inconsistency"
        )
    }
}
