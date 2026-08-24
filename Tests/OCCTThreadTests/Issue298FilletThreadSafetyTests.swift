import Foundation
import Testing
import simd

@testable import OCCTSwift

// Issue #298: filleting a boolean result is thread-unsafe in OCCT's TKFillet.
//
// BRepFilletAPI_MakeFillet's constant/evolutive-radius blend solvers keep their
// geometric work variables in function-local `static`s, so two threads filleting
// at once corrupt each other's intermediate surfaces. The result is not a crash
// and not an empty shape, it is a wrong-but-plausible solid (one solid, positive
// volume) that fails BRepCheck. Reproduced in pure OCCT with no wrapper (#298).
//
// SheetMetal.Builder.build chains extrude → fuse → fillet, so a multi-flange part
// hits exactly this path. Before the fix, ~60% of concurrent U-channel builds came
// back invalid with volumes scattered across a dozen distinct wrong values; the
// correct part is a single volume. The bridge now serialises 3D fillet/chamfer
// builds (occtFilletMutex), so every concurrent build must match the single value
// a lone build produces.
//
// This suite is deliberately concurrency-heavy; if the lock regresses it fails
// loudly rather than flaking, because the corruption rate at this width is high.
@Suite("Issue #298, fillet-of-boolean is thread-safe (SheetMetal build)")
struct Issue298FilletThreadSafetyTests {

    private static func uChannel() -> (flanges: [SheetMetal.Flange], bends: [SheetMetal.Bend]) {
        let bottom = SheetMetal.Flange(
            id: "bottom",
            profile: [SIMD2(0, 0), SIMD2(40, 0), SIMD2(40, 20), SIMD2(0, 20)],
            origin: SIMD3<Double>(0, 0, 0),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        let left = SheetMetal.Flange(
            id: "left",
            profile: [SIMD2(0, 0), SIMD2(20, 0), SIMD2(20, 15), SIMD2(0, 15)],
            origin: SIMD3<Double>(0, 0, 0),
            normal: SIMD3<Double>(-1, 0, 0),
            uAxis: SIMD3<Double>(0, 1, 0),
            vAxis: SIMD3<Double>(0, 0, 1))
        let right = SheetMetal.Flange(
            id: "right",
            profile: [SIMD2(0, 0), SIMD2(20, 0), SIMD2(20, 15), SIMD2(0, 15)],
            origin: SIMD3<Double>(40, 0, 0),
            normal: SIMD3<Double>(1, 0, 0),
            uAxis: SIMD3<Double>(0, 1, 0),
            vAxis: SIMD3<Double>(0, 0, 1))
        return (
            [bottom, left, right],
            [
                SheetMetal.Bend(from: "bottom", to: "left", radius: 1.5),
                SheetMetal.Bend(from: "bottom", to: "right", radius: 1.5),
            ]
        )
    }

    /// The reference volume from a single, uncontended build. Any concurrent build
    /// that disagrees by more than a rounding tolerance got corrupted geometry.
    private static func referenceVolume() throws -> Double {
        let (flanges, bends) = uChannel()
        let s = try SheetMetal.Builder(thickness: 2).build(flanges: flanges, bends: bends)
        let v = try #require(s.volume)
        #expect(s.isValid)
        #expect(s.subShapes(ofType: .solid).count == 1)
        return v
    }

    @Test("Concurrent U-channel builds all match the single-build result")
    func concurrentUChannelBuildsAreConsistent() async throws {
        let reference = try Self.referenceVolume()
        let tolerance = max(1e-3, reference * 1e-6)

        struct Outcome: Sendable {
            var threw = 0, invalid = 0, wrongSolidCount = 0, wrongVolume = 0
            var sampleVolumes: [Double] = []
        }

        let agg = await withTaskGroup(of: Outcome.self) { group -> Outcome in
            for _ in 0..<8 {
                group.addTask {
                    var o = Outcome()
                    let builder = SheetMetal.Builder(thickness: 2)
                    for _ in 0..<25 {
                        let (flanges, bends) = Self.uChannel()
                        guard let s = try? builder.build(flanges: flanges, bends: bends) else {
                            o.threw += 1
                            continue
                        }
                        if !s.isValid { o.invalid += 1 }
                        if s.subShapes(ofType: .solid).count != 1 { o.wrongSolidCount += 1 }
                        let v = s.volume ?? 0
                        if abs(v - reference) > tolerance {
                            o.wrongVolume += 1
                            if o.sampleVolumes.count < 5 { o.sampleVolumes.append(v) }
                        }
                    }
                    return o
                }
            }
            var total = Outcome()
            for await o in group {
                total.threw += o.threw
                total.invalid += o.invalid
                total.wrongSolidCount += o.wrongSolidCount
                total.wrongVolume += o.wrongVolume
                if total.sampleVolumes.count < 5 {
                    total.sampleVolumes.append(contentsOf: o.sampleVolumes)
                }
            }
            return total
        }

        #expect(agg.threw == 0, "some concurrent builds threw (expected 0 of 200)")
        #expect(
            agg.invalid == 0,
            "concurrent builds returned BRepCheck-invalid solids (expected 0 of 200)")
        #expect(
            agg.wrongSolidCount == 0,
            "concurrent builds returned != 1 solid (expected 0 of 200)")
        #expect(
            agg.wrongVolume == 0,
            "concurrent builds diverged from reference volume \(reference); sample corrupted volumes \(agg.sampleVolumes), the #298 race"
        )
    }
}
