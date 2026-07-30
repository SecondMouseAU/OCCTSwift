import Testing
@testable import OCCTSwift

// #490: FilletBuilder.setContinuity was the one continuity argument the bridge did not decode at
// all — it cast the integer straight to GeomAbs_Shape, so `1` asked for G1 and `2` for C1 while the
// Swift entry point documented 0=C0, 1=C1, 2=C2. It now decodes as ParametricContinuity, matching
// both its own documentation and BRepFilletAPI_MakeFillet's ("an continuity Ci (i=0, 1 or 2)").

@Suite("Issue #490: fillet internal continuity decodes as ParametricContinuity")
struct Issue490FilletContinuityTests {

    private func filletedVolume(continuity: Int) -> Double? {
        guard let box = Shape.box(width: 20, height: 20, depth: 20),
              let builder = FilletBuilder(shape: box),
              let edge = box.edges().first
        else { return nil }
        builder.setContinuity(continuity, angularTolerance: 1e-4)
        guard builder.addEdge(edge, radius: 2.0), let result = builder.build() else { return nil }
        return result.volume
    }

    @Test("every value in the documented C0/C1/C2 domain builds a fillet", arguments: 0...2)
    func documentedDomainBuilds(continuity: Int) throws {
        let volume = try #require(filletedVolume(continuity: continuity),
                                  "continuity \(continuity) should still build a fillet")
        // A fillet on one edge of a 20-cube rounds material away.
        #expect(volume < 8000.0)
        #expect(volume > 7900.0)
    }
}
