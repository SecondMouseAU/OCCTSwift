import Testing
import simd

@testable import OCCTSwift

@Suite("Boolean with History")
struct BooleanHistoryTests {
    // #766: both tests took their result through `#expect(result != nil)` and then `if let r`, and
    // fuseWithHistory read `r.shape.volume!` inside #expect (a force-unwrap the repo's test
    // conventions forbid) against `> 0`, which any positive volume satisfies. Fixtures and the
    // result go through try #require now, and each test asserts the measured values:
    // Scripts/repro/766-modeling-boolean-history/probe-evidence-fix.mm.
    private func cube(size: Double, movedBy shift: SIMD3<Double> = .zero) throws -> Shape {
        let box = try #require(Shape.box(width: size, height: size, depth: size))
        guard shift != .zero else { return box }
        return try #require(box.translated(by: shift), "translating the fixture box failed")
    }

    @Test("Fuse with history tracks modified faces")
    func fuseWithHistory() throws {
        let box1 = try cube(size: 10)
        let box2 = try cube(size: 10, movedBy: SIMD3(5, 0, 0))
        let r = try #require(box1.fuseWithHistory(box2))
        // Two 10 mm cubes offset 5 in x share a 5 x 10 x 10 block: one solid of 2000 - 500.
        #expect(r.shape.subShapes(ofType: .solid).count == 1)
        let volume = try #require(r.shape.volume)
        #expect(abs(volume - 1500) < 1e-6)
        // Should have some modified faces from the intersection: the kernel reports 8 of them
        // (BRepAlgoAPI_Fuse::Modified summed over the first cube's faces), all of them faces
        #expect(r.modifiedFaces.count == 8)
        #expect(r.modifiedFaces.allSatisfy { $0.shapeType == .face })
    }

    @Test("Fuse non-overlapping with history")
    func fuseNonOverlappingHistory() throws {
        let box1 = try cube(size: 5)
        let box2 = try cube(size: 5, movedBy: SIMD3(20, 0, 0))
        let r = try #require(box1.fuseWithHistory(box2))
        // Non-overlapping fuse should have no modified faces (faces are unchanged)
        #expect(r.modifiedFaces.count == 0)
        // The two 5 mm cubes stay two solids of 125 each. #766: the test asserted only the count.
        #expect(r.shape.subShapes(ofType: .solid).count == 2)
        let volume = try #require(r.shape.volume)
        #expect(abs(volume - 250) < 1e-6)
    }
}
