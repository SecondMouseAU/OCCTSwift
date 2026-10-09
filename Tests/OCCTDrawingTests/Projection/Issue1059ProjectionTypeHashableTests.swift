import Testing

@testable import OCCTSwift

// #1059: `Drawing.ProjectionType` was `UInt32`-backed with two payload-free cases, so it had
// `RawRepresentable` from the raw type and `Equatable` and `Hashable` for free, since a payload-free
// enum has both whether or not it says so. #999 gave `.perspective` a focal distance, which removed
// the raw type (an enum cannot have both) and also removed the free pair, and the replacement
// declared `Sendable, Equatable` only. `Hashable` was the one not re-declared, for no recorded
// reason, and it costs nothing to restore: the sole associated value is a `Double`.
//
// Every test here fails to COMPILE against the pre-fix declaration rather than failing an
// assertion, which is what a missing conformance does. Measured: reverting the declaration to
// `Sendable, Equatable` produces 12 errors, spread across all three tests. `RawRepresentable` is
// not restored and no test here asks for it: an enum cannot declare a raw type alongside an
// associated value.
//
// SO READ THE GREEN CHECKMARKS NARROWLY. Once the file compiles, all ten `#expect`s are
// tautologies **against the synthesised conformance**: with `Equatable` and `Hashable` derived from
// `(case, Double)`, three keys that differ in case or payload cannot collide, and two identical
// values cannot hash apart inside one process. So the suite's assertion against a re-removal of
// `Hashable` is the build, not the checkmarks.
//
// They are not tautologies against a *hand-written* conformance, which is the other way this can
// break. Measured: a hand-written `==`/`hash(into:)` pair that drops the `focus` payload fails four
// of the ten, `cache.count` reading 2 and `set.contains(.perspective(focus: 52))` reading true. The
// one shape the suite still cannot catch is a `hash(into:)` that drops the payload while `==` keeps
// it, since `Set` and `Dictionary` fall back on `==` after a collision.
//
// Note also that `gate-scripts` is the only required status check on `main` and it never compiles
// Swift, so the compile half of this suite's signal reaches a non-required job only (#1059 review).
@Suite("Drawing.ProjectionType is Hashable (#1059)")
struct Issue1059ProjectionTypeHashableTests {

    @Test("A ProjectionType keys a dictionary")
    func keysADictionary() {
        var cache: [Drawing.ProjectionType: String] = [:]
        cache[.orthographic] = "ortho"
        cache[.perspective(focus: 50)] = "persp50"
        cache[.perspective(focus: 120)] = "persp120"
        #expect(cache.count == 3)
        #expect(cache[.perspective(focus: 50)] == "persp50")
        #expect(cache[.perspective(focus: 120)] == "persp120")
        #expect(cache[.orthographic] == "ortho")
    }

    @Test("A set collapses equal cases and keeps distinct ones")
    func setCollapsesEqualCases() {
        let set: Set<Drawing.ProjectionType> = [
            .orthographic,
            .orthographic,
            .perspective(focus: 50),
            .perspective(focus: 50),
            .perspective(focus: 51),
        ]
        #expect(set.count == 3)
        #expect(set.contains(.perspective(focus: 50)))
        #expect(set.contains(.perspective(focus: 52)) == false)
    }

    @Test("Equal values hash equal, which Hashable requires and Equatable alone cannot give")
    func equalValuesHashEqual() {
        #expect(
            Drawing.ProjectionType.perspective(focus: 50).hashValue
                == Drawing.ProjectionType.perspective(focus: 50).hashValue)
        // Equatable is retained, since Hashable refines it.
        #expect(Drawing.ProjectionType.orthographic == Drawing.ProjectionType.orthographic)
        #expect(Drawing.ProjectionType.orthographic != Drawing.ProjectionType.perspective(focus: 1))
    }
}
