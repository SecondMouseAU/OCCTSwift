import Testing
import simd

@testable import OCCTSwift

@Suite("Loft polar-method SIGSEGV regression (#176)")
struct LoftPolarMethodCrashTests {
    /// Exact profile set from issue #176 (Kiha 40 body 1068): 8 mismatched convex polygons
    /// (alternating 5- and 4-vertex, with a 2.5-unit gap near z=0). On an UNPATCHED OCCT this
    /// deterministically SIGSEGVs single-threaded inside
    /// BRepFill_CompatibleWires:SameNumberByPolarMethod, the correspondence-list iterators
    /// over-advance and dereference a null list node ("Address 8"). The bridge's catch(...) cannot
    /// save it (it is an OS signal, not a C++ exception). Fixed UPSTREAM in OCCT 8.0.0p1
    /// (Open-Cascade-SAS/OCCT#1298, OCCTSwift #178), the guard is now native to the pinned
    /// xcframework, so Build() fails gracefully (this returns nil) instead of crashing. (Previously
    /// carried as Scripts/patches/0001-*, dropped once p1 shipped.) If this test ever crashes the
    /// runner, the upstream guard has been lost from the xcframework.
    @Test("Mismatched polar-method profiles return without crashing")
    func mismatchedPolarProfilesDoNotCrash() {
        // local (x, y) per station; z is the third tuple element
        let stations: [(z: Double, pts: [(Double, Double)])] = [
            (
                -3.7500,
                [
                    (-0.0502, 2.1681), (-0.0162, 0.2239), (0.0463, 0.2250), (0.0357, 0.8300),
                    (0.0123, 2.1692),
                ]
            ),
            (
                -2.9167,
                [
                    (-0.0162, 0.2239), (0.0007, -0.7416), (0.0632, -0.7405), (0.0556, -0.3053),
                    (0.0463, 0.2250),
                ]
            ),
            (
                -2.0833,
                [
                    (-0.0451, -1.2651), (0.0174, -1.2640), (0.0689, -1.0639), (0.0632, -0.7405),
                    (0.0007, -0.7416),
                ]
            ),
            (
                -1.2500,
                [(-0.1048, -1.3334), (-0.0423, -1.3323), (0.0174, -1.2640), (-0.0451, -1.2651)]
            ),
            (
                1.2500,
                [(-0.1048, -1.3334), (-0.0423, -1.3323), (0.0174, -1.2640), (-0.0451, -1.2651)]
            ),
            (
                2.0833,
                [
                    (-0.0451, -1.2651), (0.0174, -1.2640), (0.0689, -1.0639), (0.0632, -0.7405),
                    (0.0007, -0.7416),
                ]
            ),
            (
                2.9167,
                [
                    (-0.0162, 0.2239), (0.0007, -0.7416), (0.0632, -0.7405), (0.0556, -0.3053),
                    (0.0463, 0.2250),
                ]
            ),
            (
                3.7500,
                [
                    (-0.0502, 2.1681), (-0.0162, 0.2239), (0.0463, 0.2250), (0.0357, 0.8300),
                    (0.0123, 2.1692),
                ]
            ),
        ]
        let profiles = stations.compactMap { station in
            Wire.polygon3D(station.pts.map { SIMD3($0.0, $0.1, station.z) }, closed: true)
        }
        #expect(profiles.count == stations.count)
        // The call must return (nil or a shape) without aborting the process.
        _ = Shape.loft(profiles: profiles, solid: true)
        #expect(true)  // reaching here means the polar-method crash did not fire
    }
}
