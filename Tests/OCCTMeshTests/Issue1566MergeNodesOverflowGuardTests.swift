import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

/// #1566: `OCCTPolyMergeNodes` (`Sources/OCCTBridge/src/OCCTBridge_Mesh.mm`) used to set
/// `*outTriangleCount`/return the merged node count unconditionally, even on the branch where the
/// actual write into `outVertices`/`outNormals`/`outIndices` was skipped because the caller's
/// buffer was too small (`nNodes > maxVertices` or `nTris * 3 > maxIndices`). A caller trusting
/// those counts to size its own read of the buffer would read stale/zeroed data, or -- for
/// `mergedMeshNodes(from:smoothAngle:mergeTolerance:)`'s own `unpackSIMD3` call on the vertex
/// side -- index straight past the end of its local Swift array, a hard trap.
///
/// This is exercised directly against the C bridge function with deliberately tiny
/// `maxVertices`/`maxIndices`, not by constructing a real >500K-node mesh (the issue's own
/// "500K+ nodes" trigger size is impractical to build in a test): any real merged triangulation
/// of an ordinary box already has more than one vertex and more than one triangle, so a buffer
/// capacity of 1 forces exactly the same "requested buffer too small" branch a huge mesh would,
/// with no dependence on how many vertices/triangles the box actually merges down to.
@Suite("Issue #1566: OCCTPolyMergeNodes refuses rather than mis-reports on buffer overflow")
struct Issue1566MergeNodesOverflowGuardTests {

    /// A plain, meshed box: `Poly_MergeNodesTool` at `smoothAngle: .pi / 4`, `mergeTolerance: 0.0`
    /// (measured directly, not assumed: 0 tolerance means "exact match required", and this tool
    /// keeps a face's own corner nodes distinct from its neighbour's rather than deduplicating
    /// coincident positions across faces) reports 24 nodes / 12 triangles for this box, comfortably
    /// more than the 1-element buffers below need to overflow, and comfortably less than any of the
    /// "generous" buffers used as controls.
    private static func meshedBox() -> Shape? {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return nil }
        _ = box.mesh(linearDeflection: 1.0)
        return box
    }

    // MARK: - Baseline: generous buffers succeed and report real, matching counts

    @Test("generous buffers: succeeds, reports the true counts, and every count matches the write")
    func generousBuffersSucceed() throws {
        let box = try #require(Self.meshedBox())
        let maxVerts: Int32 = 1024
        let maxIdx: Int32 = 1024 * 3
        var vertices = [Float](repeating: -1, count: Int(maxVerts) * 3)
        var normals = [Float](repeating: -1, count: Int(maxVerts) * 3)
        var indices = [UInt32](repeating: .max, count: Int(maxIdx))
        var triCount: Int32 = -1

        let nVerts = vertices.withUnsafeMutableBufferPointer { vBuf in
            normals.withUnsafeMutableBufferPointer { nBuf in
                indices.withUnsafeMutableBufferPointer { iBuf in
                    OCCTPolyMergeNodes(
                        box.handle, .pi / 4, 0.0,
                        vBuf.baseAddress, nBuf.baseAddress, iBuf.baseAddress,
                        maxVerts, maxIdx, &triCount)
                }
            }
        }

        #expect(nVerts > 0)
        #expect(triCount > 0)
        // Sanity: this is the fixture the overflow tests below rely on actually being small.
        #expect(nVerts < 100)
        #expect(triCount < 100)
    }

    // MARK: - Vertex-side overflow (nNodes > maxVertices)

    @Test("vertex buffer too small: refuses (returns 0), does not touch outTriangleCount")
    func vertexOverflowRefuses() throws {
        let box = try #require(Self.meshedBox())
        // maxVertices = 1: a merged box always has more than 1 node, so this always overflows,
        // independent of the exact merged count.
        let maxVerts: Int32 = 1
        let maxIdx: Int32 = 1024 * 3
        var vertices = [Float](repeating: -1, count: Int(maxVerts) * 3)
        var normals = [Float](repeating: -1, count: Int(maxVerts) * 3)
        var indices = [UInt32](repeating: .max, count: Int(maxIdx))
        var triCount: Int32 = -1  // sentinel: must stay untouched on refusal

        let nVerts = vertices.withUnsafeMutableBufferPointer { vBuf in
            normals.withUnsafeMutableBufferPointer { nBuf in
                indices.withUnsafeMutableBufferPointer { iBuf in
                    OCCTPolyMergeNodes(
                        box.handle, .pi / 4, 0.0,
                        vBuf.baseAddress, nBuf.baseAddress, iBuf.baseAddress,
                        maxVerts, maxIdx, &triCount)
                }
            }
        }

        #expect(nVerts == 0, "a too-small vertex buffer must fail the whole call, not report a count larger than 1 slot holds")
        #expect(triCount == -1, "outTriangleCount must be left untouched when the call refuses")
    }

    // MARK: - Index-side overflow (nTris * 3 > maxIndices) -- the realistic, dominant trigger

    @Test("index buffer too small: refuses (returns 0), does not touch outTriangleCount")
    func indexOverflowRefuses() throws {
        let box = try #require(Self.meshedBox())
        let maxVerts: Int32 = 1024
        // maxIndices = 1: a merged box always has more than 1 triangle (3+ indices needed), so
        // this always overflows too, independent of the exact merged triangle count. This is the
        // shape #1566 itself measured as the dominant real-world trigger (maxIdx sized for only
        // ~half of maxVerts's worth of triangles under normal 2-manifold geometry).
        let maxIdx: Int32 = 1
        var vertices = [Float](repeating: -1, count: Int(maxVerts) * 3)
        var normals = [Float](repeating: -1, count: Int(maxVerts) * 3)
        var indices = [UInt32](repeating: .max, count: Int(maxIdx))
        var triCount: Int32 = -1  // sentinel: must stay untouched on refusal

        let nVerts = vertices.withUnsafeMutableBufferPointer { vBuf in
            normals.withUnsafeMutableBufferPointer { nBuf in
                indices.withUnsafeMutableBufferPointer { iBuf in
                    OCCTPolyMergeNodes(
                        box.handle, .pi / 4, 0.0,
                        vBuf.baseAddress, nBuf.baseAddress, iBuf.baseAddress,
                        maxVerts, maxIdx, &triCount)
                }
            }
        }

        #expect(nVerts == 0, "a too-small index buffer must fail the whole call, not report the true (larger) triangle count while indices went unwritten")
        #expect(triCount == -1, "outTriangleCount must be left untouched when the call refuses")
    }

    // MARK: - A caller that doesn't ask for a given buffer isn't bound by its (irrelevant) capacity

    @Test("a null outIndices is not gated on maxIndices, even when maxIndices is 0")
    func nullIndicesBufferIgnoresMaxIndices() throws {
        let box = try #require(Self.meshedBox())
        let maxVerts: Int32 = 1024
        var vertices = [Float](repeating: -1, count: Int(maxVerts) * 3)
        var normals = [Float](repeating: -1, count: Int(maxVerts) * 3)
        var triCount: Int32 = -1

        let nVerts = vertices.withUnsafeMutableBufferPointer { vBuf in
            normals.withUnsafeMutableBufferPointer { nBuf in
                OCCTPolyMergeNodes(
                    box.handle, .pi / 4, 0.0,
                    vBuf.baseAddress, nBuf.baseAddress, nil,
                    maxVerts, 0, &triCount)
            }
        }

        #expect(nVerts > 0, "no outIndices buffer was requested, so a 0-capacity maxIndices must not fail the call")
        #expect(triCount > 0, "the true triangle count is still informational when the caller didn't ask for indices at all")
    }

    // MARK: - The Swift-level public API surfaces the same refusal as nil

    @Test("mergedMeshNodes still succeeds normally for an ordinary box (non-regression)")
    func mergedMeshNodesStillWorks() throws {
        let box = try #require(Self.meshedBox())
        let merged = try #require(mergedMeshNodes(from: box, smoothAngle: .pi / 4))
        #expect(merged.vertexCount > 0)
        #expect(merged.triangleCount > 0)
        #expect(merged.vertices.count == merged.vertexCount)
        #expect(merged.normals.count == merged.vertexCount)
        #expect(merged.indices.count == merged.triangleCount * 3)
    }
}
