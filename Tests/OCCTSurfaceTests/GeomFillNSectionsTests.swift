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
        // #766: the surface was bound and discarded, so this asserted nothing. GeomFill_NSections
        // on the three circles gives a surface over [0, 1] x [0, 1] passing through the middle
        // circle at v = 0.5 and the last at v = 1, see Scripts/repro/766-geomfill-c/.
        let surf = Surface.nSections(curves: [c1, c2, c3], params: [0.0, 0.5, 1.0])
        #expect(surf != nil)
        if let surf {
            #expect(simd_length(surf.point(atU: 0, v: 0.5) - SIMD3(4, 0, 3)) < 1e-9)
            #expect(simd_length(surf.point(atU: 0, v: 1) - SIMD3(3, 0, 6)) < 1e-9)
        }
    }

    @Test func sectionInfo() {
        guard let c1 = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5.0),
            let c2 = Curve3D.circle(center: SIMD3(0, 0, 3), normal: SIMD3(0, 0, 1), radius: 4.0)
        else { return }
        // #766: `> 0` inside `if let`; pinned to GeomFill_NSections::SectionShape, 6 poles,
        // 2 knots, degree 6, see Scripts/repro/766-geomfill-c/.
        let info = Surface.nSectionsInfo(curves: [c1, c2], params: [0.0, 1.0])
        #expect(info != nil)
        if let info {
            #expect(info.poleCount == 6)
            #expect(info.knotCount == 2)
            #expect(info.degree == 6)
        }
    }
}
