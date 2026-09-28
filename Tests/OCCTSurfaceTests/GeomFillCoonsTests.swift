import Testing
import simd

@testable import OCCTSwift

@Suite("GeomFill Coons")
struct GeomFillCoonsTests {
    @Test("Coons filling from boundaries")
    func coonsFilling() throws {
        let n = 5
        var b1 = [SIMD3<Double>]()
        var b2 = [SIMD3<Double>]()
        var b3 = [SIMD3<Double>]()
        var b4 = [SIMD3<Double>]()
        for i in 0..<n {
            let t = Double(i) / Double(n - 1)
            b1.append(SIMD3(t * 10, 0, 0))
            b2.append(SIMD3(t * 10, 10, 0))
            b3.append(SIMD3(0, t * 10, 0))
            b4.append(SIMD3(10, t * 10, 0))
        }
        let result = try #require(
            Shape.coonsFilling(boundary1: b1, boundary2: b2, boundary3: b3, boundary4: b4))
        // #766: `> 0` passed any grid. GeomFill_Coons on the same four rows gives 5 x 5 poles.
        // These are the kernel's own values for these inputs and they are NOT a flat square's.
        // GeomFill_Coons::Init reads P1/P3 as the two boundaries indexed along U and P2/P4 as the
        // two indexed along V, with the corners required to agree; this fixture passes
        // (bottom, top, left, right), so b2 arrives where the left column belongs and its first
        // point overwrites the square's (0, 0, 0) corner with (0, 10, 0). Filed as #2795: read
        // poles[8] below as the kernel's answer to a mis-ordered call, not as square geometry.
        // The same transcript carries the corrected arrangement (b1, b3, b2, b4) for comparison,
        // which is the flat square's own uniform grid. Transcript: Scripts/repro/766-geomfill-a/.
        #expect(result.nbU == 5)
        #expect(result.nbV == 5)
        try #require(result.poles.count == 25)
        #expect(simd_length(result.poles[0] - SIMD3(0, 10, 0)) < 1e-9)
        #expect(simd_length(result.poles[8] - SIMD3(-2.5, 2.5, 0)) < 1e-9)
        #expect(simd_length(result.poles[24] - SIMD3(10, 10, 0)) < 1e-9)
    }
}
