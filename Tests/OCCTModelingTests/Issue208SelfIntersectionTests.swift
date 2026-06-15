import Testing
import Foundation
import simd
@testable import OCCTSwift

// #208: a watchdog-bounded self-intersection check. isValidSolid (topology) misses global
// self-intersection (overlapping faces) — the defect that hung booleans in #206. This check
// (BOPAlgo_ArgumentAnalyzer self-interference) catches it, bounded so it cannot hang.
@Suite("Issue #208 — self-intersection check")
struct Issue208SelfIntersection {

    @Test("a clean solid reports not self-intersecting")
    func cleanSolidIsClean() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { #expect(Bool(false)); return }
        #expect(box.isSelfIntersecting() == false)
        guard let sph = Shape.sphere(radius: 5) else { #expect(Bool(false)); return }
        #expect(sph.isSelfIntersecting() == false)
    }

    @Test("two overlapping solids in one compound are detected as self-intersecting")
    func overlappingCompoundIsSelfIntersecting() {
        guard let a = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
              let b = Shape.box(origin: SIMD3(5, 0, 0), width: 10, height: 10, depth: 10),
              let compound = Shape.compound([a, b]) else { #expect(Bool(false)); return }
        // The two boxes' faces interfere → self-interference within the single argument.
        #expect(compound.isSelfIntersecting() == true)
    }

    @Test("indeterminate when the check cannot finish in time")
    func tinyTimeoutIsIndeterminateOrConclusive() {
        guard let a = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
              let b = Shape.box(origin: SIMD3(5, 0, 0), width: 10, height: 10, depth: 10),
              let compound = Shape.compound([a, b]) else { #expect(Bool(false)); return }
        // A near-zero deadline must not hang: either it found a fault first (true) or it
        // gave up (nil). It must never block, and must not falsely claim "clean".
        let r = compound.isSelfIntersecting(timeout: 1e-7)
        #expect(r == nil || r == true)
    }
}
