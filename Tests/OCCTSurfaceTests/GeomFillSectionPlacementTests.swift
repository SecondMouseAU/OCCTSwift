import Testing
import simd

@testable import OCCTSwift

@Suite("GeomFill_SectionPlacement")
struct GeomFillSectionPlacementTests {
    @Test("place section on path")
    func placeSectionOnPath() {
        if let path = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)),
            let pathTrimmed = path.trimmed(from: 0, to: 10),
            let section = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(1, 0, 0), radius: 2)
        {
            let result = pathTrimmed.sectionPlacement(section: section)
            #expect(result.isDone)
            #expect(result.distance >= 0)
            // #766: `distance >= 0` passed any distance. GeomFill_SectionPlacement reports the
            // radius-2 circle 2 from the path, at path parameter 0 with angle pi/2, see
            // Scripts/repro/766-geomfill-d/.
            #expect(abs(result.distance - 2) < 1e-9)
            #expect(abs(result.angle - .pi / 2) < 1e-9)
        } else {
            Issue.record("failed to build probe path/section")
        }
    }

    @Test("query placement parameters")
    func queryPlacementParams() {
        if let path = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)),
            let pathTrimmed = path.trimmed(from: 0, to: 10),
            let section = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(1, 0, 0), radius: 2)
        {
            let result = pathTrimmed.sectionPlacement(section: section)
            // #766: `if isDone` let a failed placement pass, and [0, 10] passed any parameter on
            // the path. The kernel places the section at path parameter 0 and section parameter
            // 0, see Scripts/repro/766-geomfill-d/.
            #expect(result.isDone)
            #expect(abs(result.parameterOnPath) < 1e-9)
            #expect(abs(result.parameterOnSection) < 1e-9)
        } else {
            Issue.record("failed to build probe path/section")
        }
    }

    // #710: OCCTGeomFillSectionPlacement's `sectionCurve` argument reaches its Handle through the
    // same invisible-to-the-checker alias form, and the GeomFill_SectionPlacement constructor
    // dereferences it unconditionally (`Section->IsInstance(...)`) -- an uncatchable SIGSEGV on a
    // null Handle(Geom_Curve). As with the Profiler guard above, no public factory can currently
    // produce a null-handle Curve3D to drive the crashing input through, so this proves the guard
    // does not regress the ordinary path instead. `Issue.record`, not a decorative `if let`, so a
    // regression that makes the guard reject a valid section fails loudly rather than silently
    // skipping the assertions.
    @Test("null-handle guard does not block a valid section (#710 regression)")
    func nullHandleGuardAllowsValidSection() {
        guard let path = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)),
            let pathTrimmed = path.trimmed(from: 0, to: 10),
            let section = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(1, 0, 0), radius: 2)
        else {
            Issue.record("failed to build probe path/section")
            return
        }
        let result = pathTrimmed.sectionPlacement(section: section)
        guard result.isDone else {
            Issue.record(
                "sectionPlacement did not report isDone for a valid path and section -- the null-handle guard rejected a valid section"
            )
            return
        }
        #expect(result.distance >= 0)
    }
}
