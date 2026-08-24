import Foundation
import Testing
import simd

@testable import OCCTSwift

// #988: `ThreadProfile.square` and `.buttress` were literal six-vertex lists, next to
// `.whitworth55`, `.acme29` and `.trapezoidalMetric30`, which are all built by the `trapezoid`
// factory. Both are trapezoids, so both now come from that factory too, `.buttress` through a
// crest-centre argument that lets the two flanks differ.
//
// The claim the refactor makes is stronger than "still a valid profile": the vertices are
// bit-for-bit the ones the literal lists held. The expected values below are those literals,
// copied from the pre-#988 source, and compared with `==` on `Double` rather than a tolerance,
// which is the whole point. A tolerance would pass for an arithmetic rearrangement that quietly
// moved a flank by a micron.
@Suite("Issue #988: square and buttress come from the trapezoid factory unchanged")
struct Issue988ThreadProfileFactoryTests {

    /// `ThreadProfile.square`'s literal vertex list as it stood before #988.
    static let squareVertices: [(Double, Double)] = [
        (0, 1), (0.25, 1), (0.25, 0), (0.75, 0), (0.75, 1), (1, 1),
    ]

    /// `ThreadProfile.buttress`'s literal vertex list as it stood before #988 (DIN 513).
    static let buttressVertices: [(Double, Double)] = [
        (0, 1), (0.0968, 1), (0.1422, 0), (0.4022, 0), (0.9032, 1), (1, 1),
    ]

    static func check(
        _ profile: ThreadProfile, against expected: [(Double, Double)], _ name: String
    ) {
        #expect(profile.vertices.count == expected.count, "\(name): vertex count")
        guard profile.vertices.count == expected.count else { return }
        for (i, want) in expected.enumerated() {
            let got = profile.vertices[i]
            #expect(got.axial == want.0, "\(name) vertex \(i): axial \(got.axial) != \(want.0)")
            #expect(got.depth == want.1, "\(name) vertex \(i): depth \(got.depth) != \(want.1)")
        }
    }

    @Test("square is the limiting trapezoid, to the last bit")
    func squareIsUnchanged() {
        Self.check(ThreadProfile.square, against: Self.squareVertices, "square")
        // The two radial walls are what make it a square thread rather than a trapezoidal one, and
        // they exist only because the crest and root flats meet: 0.5 - 0.5/2 == 0.5/2 exactly.
        #expect(ThreadProfile.square.segments.filter { $0.kind == .wall }.count == 2)
        #expect(ThreadProfile.square.segments.filter { $0.kind == .flank }.isEmpty)
    }

    @Test("buttress keeps its asymmetric DIN 513 vertices, to the last bit")
    func buttressIsUnchanged() {
        Self.check(ThreadProfile.buttress, against: Self.buttressVertices, "buttress")
        // Asymmetry is the property the crest-centre argument exists for: the load flank's axial
        // run is a fraction of the clearance flank's.
        let flanks = ThreadProfile.buttress.segments.filter { $0.kind == .flank }
        #expect(flanks.count == 2)
        guard flanks.count == 2 else { return }
        let load = flanks[0].b.axial - flanks[0].a.axial
        let clearance = flanks[1].b.axial - flanks[1].a.axial
        #expect(clearance > 5 * load, "load \(load), clearance \(clearance)")
    }

    /// The symmetric forms go through the same factory and must not have moved either, since the
    /// crest centre it gained is a defaulted argument rather than a new step in the arithmetic.
    @Test("the symmetric forms are unmoved")
    func symmetricFormsAreUnchanged() {
        Self.check(
            ThreadProfile.acme29,
            against: [
                (0, 1), (0.3707 / 2, 1), (0.5 - 0.3707 / 2, 0), (0.5 + 0.3707 / 2, 0),
                (1 - 0.3707 / 2, 1), (1, 1),
            ], "acme29")
        Self.check(
            ThreadProfile.iso60V(),
            against: [
                (0, 1), (1.0 / 8, 1), (0.5 - 1.0 / 16, 0), (0.5 + 1.0 / 16, 0), (1 - 1.0 / 8, 1),
                (1, 1),
            ], "iso60V")
    }
}
