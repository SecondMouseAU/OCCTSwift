import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GeomFill Sweep")
struct GeomFillSweepTests {
    @Test("Sweep circle along line")
    func sweepCircleAlongLine() {
        // Create a line path edge
        let pathEdge = Shape.edgeFromLine(
            origin: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1), p1: 0, p2: 20)
        // Create a circle section edge
        let sectionEdge = Shape.edgeFromCircle(
            center: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 3, p1: 0, p2: 2 * .pi)
        guard let path = pathEdge, let section = sectionEdge else { return }
        let result = Shape.geomFillSweep(path: path, section: section)
        #expect(result != nil)
    }

    @Test("Rejects a sweep that misses its own tolerance instead of reporting it as done (#597)")
    func sweepRejectsOutOfToleranceFit() throws {
        // GeomFill_Sweep::Build's general path (BuildAll) always fits the swept surface with an
        // internal Approx_SweepApproximation and records the achieved deviation in
        // ErrorOnSurface(). IsDone() alone says only that SOME surface was produced, not that
        // it met the tolerance this call builds at. This entry point used to accept whatever
        // Build() returned without ever reading that number. A rapidly oscillating spine (two
        // out-of-phase sine/cosine components, five and seven periods over the same span)
        // stresses the fixed degree<=10/segments<=50 C2 fit: measured via a standalone
        // GeomFill_Sweep harness, this exact path/circle(1) pair reports IsDone() true with
        // ErrorOnSurface() == 13.0, five orders of magnitude past the 1e-4 tolerance this
        // bridge function builds at.
        var points: [SIMD3<Double>] = []
        let n = 60
        for i in 0..<n {
            let t = Double(i) / Double(n - 1) * 20.0 * Double.pi
            points.append(SIMD3(t, 3.0 * sin(t * 5.0), 2.0 * cos(t * 7.0)))
        }
        let path = try #require(Curve3D.interpolate(points: points))
        let pathEdge = try #require(Shape.edgeFromCurve(path))
        let sectionEdge = try #require(
            Shape.edgeFromCircle(
                center: .zero, axis: SIMD3(0, 0, 1), radius: 1, p1: 0, p2: 2 * .pi))
        #expect(Shape.geomFillSweep(path: pathEdge, section: sectionEdge) == nil)
    }
}
