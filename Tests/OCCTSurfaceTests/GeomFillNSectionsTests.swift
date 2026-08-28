import Testing
import simd

@testable import OCCTSwift

@Suite("GeomFill NSections Tests")
struct GeomFillNSectionsTests {
    @Test func surfaceFromCircleSections() {
        // Create circles at different heights
        guard let c1 = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5.0),
            let c2 = Curve3D.circle(center: SIMD3(0, 0, 3), normal: SIMD3(0, 0, 1), radius: 4.0),
            let c3 = Curve3D.circle(center: SIMD3(0, 0, 6), normal: SIMD3(0, 0, 1), radius: 3.0)
        else { return }
        if let surf = Surface.nSections(curves: [c1, c2, c3], params: [0.0, 0.5, 1.0]) {
            _ = surf
        }
    }

    @Test func sectionInfo() {
        guard let c1 = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5.0),
            let c2 = Curve3D.circle(center: SIMD3(0, 0, 3), normal: SIMD3(0, 0, 1), radius: 4.0)
        else { return }
        if let info = Surface.nSectionsInfo(curves: [c1, c2], params: [0.0, 1.0]) {
            #expect(info.poleCount > 0)
            #expect(info.knotCount > 0)
            #expect(info.degree > 0)
        }
    }
}
