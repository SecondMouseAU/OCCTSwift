import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are ShapeUpgrade_UnifySameDomain's own answers on the same input, from
// Scripts/repro/766-healing-small-files/probe.mm (transcript.txt beside it). Before #766 every test
// unified a single box, which has nothing to merge, asserted only `result != nil` inside `if let`,
// and so could not tell a build that ran from one that did not. The fixture is now two boxes
// fused side by side: 10 faces (four sides split in two), which unification merges back to 6.
@Suite("v0.123.0, UnifySameDomain builder")
struct UnifySameDomainBuilderTests {
    private func fusedBoxes() throws -> Shape {
        let a = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let b = try #require(Shape.box(width: 10, height: 10, depth: 10)?.translated(by: SIMD3(10, 0, 0)))
        let fused = try #require(a.union(b))
        try #require(fused.subShapes(ofType: .face).count == 10)
        return fused
    }

    private func expectMerged(_ usd: UnifySameDomainBuilder) throws {
        let result = try #require(usd.shape)
        #expect(result.isValid)
        #expect(result.subShapes(ofType: .face).count == 6)
        #expect(result.subShapes(ofType: .edge).count == 12)
        #expect(abs((result.volume ?? 0) - 2000) < 1e-6)
    }

    @Test("Basic unification with builder")
    func basicUnification() throws {
        let usd = UnifySameDomainBuilder(shape: try fusedBoxes())
        usd.build()
        try expectMerged(usd)
    }

    @Test("AllowInternalEdges")
    func allowInternalEdges() throws {
        // Kernel: allowing internal edges still merges the coplanar pairs to 6 faces here.
        let usd = UnifySameDomainBuilder(shape: try fusedBoxes())
        usd.allowInternalEdges(true)
        usd.build()
        try expectMerged(usd)
    }

    @Test("KeepShape")
    func keepShape() throws {
        // Keep the seam between the two top faces (x = 5, z = 5): the kernel then leaves that
        // pair unmerged, 7 faces and 15 edges instead of 6 and 12.
        let fused = try fusedBoxes()
        let seam = try #require(
            fused.subShapes(ofType: .edge).first { edge in
                guard let b = edge.bounds else { return false }
                return abs(b.min.x - 5) < 1e-3 && abs(b.max.x - 5) < 1e-3 && abs(b.min.z - 5) < 1e-3
                    && abs(b.max.z - 5) < 1e-3
            })
        let usd = UnifySameDomainBuilder(shape: fused)
        usd.keepShape(seam)
        usd.build()
        let result = try #require(usd.shape)
        #expect(result.isValid)
        #expect(result.subShapes(ofType: .face).count == 7)
        #expect(result.subShapes(ofType: .edge).count == 15)
    }

    @Test("SetSafeInputMode")
    func safeInputMode() throws {
        let fused = try fusedBoxes()
        let usd = UnifySameDomainBuilder(shape: fused)
        usd.setSafeInputMode(true)
        usd.build()
        try expectMerged(usd)
        #expect(fused.subShapes(ofType: .face).count == 10)  // the input is left as it was
    }

    @Test("SetLinearTolerance and SetAngularTolerance")
    func tolerances() throws {
        let usd = UnifySameDomainBuilder(shape: try fusedBoxes())
        usd.setLinearTolerance(1e-6)
        usd.setAngularTolerance(1e-3)
        usd.build()
        try expectMerged(usd)
    }
}
