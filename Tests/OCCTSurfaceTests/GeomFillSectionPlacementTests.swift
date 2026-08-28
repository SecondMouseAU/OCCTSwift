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
        }
    }

    @Test("query placement parameters")
    func queryPlacementParams() {
        if let path = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)),
            let pathTrimmed = path.trimmed(from: 0, to: 10),
            let section = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(1, 0, 0), radius: 2)
        {
            let result = pathTrimmed.sectionPlacement(section: section)
            if result.isDone {
                #expect(result.parameterOnPath >= 0)
                #expect(result.parameterOnPath <= 10)
            }
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
