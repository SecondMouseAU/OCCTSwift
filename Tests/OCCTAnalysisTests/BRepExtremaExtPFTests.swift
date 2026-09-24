import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepExtrema ExtPF Tests")
struct BRepExtremaExtPFTests {
    /// The box is centred on the origin, so (5, 5, 15) sits 10 above the top face's corner.
    /// `BRepExtrema_ExtPF` finds a perpendicular foot only on the two faces normal to z: the top
    /// at distance 10 and the bottom at 20, both at that same (x, y). The four side faces are
    /// parallel to the line of sight and report no extremum. Probed per face in
    /// `Scripts/repro/766-brepextrema-extpf/transcript.txt`.
    ///
    /// The earlier form looped until the first face that answered, then asserted only
    /// `distance >= 0` and `solutionCount >= 1`, and passed without asserting anything when no
    /// face answered at all (#766).
    @Test("Point-face distance")
    func pointFaceDistance() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let point = SIMD3<Double>(5, 5, 15)

        var answered: [PointFaceExtremaSummary] = []
        for faceIdx in 0..<6 {
            if let result = box.pointFaceExtrema(point: point, faceIndex: faceIdx) {
                #expect(result.solutionCount == 1, "face \(faceIdx)")
                answered.append(
                    PointFaceExtremaSummary(distance: result.distance, point: result.pointOnFace))
            }
        }
        #expect(answered.count == 2, "only the top and bottom faces have a perpendicular foot")

        let sorted = answered.sorted { $0.distance < $1.distance }
        guard sorted.count == 2 else { return }
        #expect(abs(sorted[0].distance - 10) < 1e-9)
        #expect(simd_distance(sorted[0].point, SIMD3(5, 5, 5)) < 1e-9)
        #expect(abs(sorted[1].distance - 20) < 1e-9)
        #expect(simd_distance(sorted[1].point, SIMD3(5, 5, -5)) < 1e-9)
    }
}

private struct PointFaceExtremaSummary {
    let distance: Double
    let point: SIMD3<Double>
}
