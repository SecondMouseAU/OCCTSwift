// StressPCurveCircleRadiusTests.swift
//
// `BRepCheck_Analyzer` never returned on a shape whose face has a pcurve that is a `Geom2d_Circle`
// of radius 0. `BRepTools::Read` builds such a circle (`gp_Circ2d` allows a radius of 0) from a
// complete, well-formed BREP file, and `Shape.isValid` is the first thing a caller does with the
// shape it returns, so the call spun inside the kernel with nothing able to end it: OCCT's signal
// handler is inert in this build.
//
// The loop is in `IntCurve_IntConicConic::Perform`, reached through
// `BRepCheck_Wire::SelfIntersect` for a wire that holds a line and a circle. The domain of the
// circle is widened by its tolerance over its radius, which is infinite at radius 0, and the
// reduction of the result into one turn took a turn off, or added one, until it was in range: an
// infinity is never in range, and neither is a value so large that a turn is below its last digit
// (1e-300 does that without being 0). Carried patch `0079` reduces the angle in one step.
//
// The fixture is the one `Scripts/repro/3487` writes, ten faces of a box fused with a cylinder, in
// which two faces carry a wire of lines and circle arcs. The tests edit the radius token of the
// first circle record of its `Curve2ds` table: a box with a changed index (the `0077` tests'
// method) has no circle to change. The undamaged file is the control, so a check that answered
// false for everything would not pass.
//
// `0079` is in `v4.0.0-kernel.9`, the first asset to hold it. The damaged cases were gated on
// `OCCTSWIFT_LOCAL=1` until the repin that pinned it, because on `v4.0.0-kernel.8` they never
// return; a gate that outlives its fix leaves the test skipped, which is the one outcome a test
// cannot recover from.

import Foundation
import Testing

@testable import OCCTSwift

// `.timeLimit` is not applied on WASI: the runner's single-threaded timer reports "Time limit was
// exceeded" for a body that finished in milliseconds. A hang on wasm is caught by the suite's
// wall-clock cap in `Scripts/run-wasm-tests.sh`.
#if os(WASI)
    private let hangLimit: ConditionTrait = .enabled(if: true)
#else
    private let hangLimit: TimeLimitTrait = .timeLimit(.minutes(1))
#endif

@Suite("Stress: a pcurve circle of no radius does not stop BRepCheck_Analyzer", .serialized)
struct StressPCurveCircleRadiusTests {

    private static func fixtureText() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/line-and-circle-pcurve-wires.brep")
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// `text` with the radius of the first circle record of the `Curve2ds` table replaced.
    ///
    /// A `Geom2d_Circle` record is `2`, its centre, its axis and its radius: eight tokens on one
    /// line. The search stays inside the `Curve2ds` table because the 3D curve and surface tables
    /// start records with `2` too. Nil when the record is not there.
    private static func circleRadius(_ radius: String, in text: String) -> String? {
        guard let table = text.range(of: "\nCurve2ds "),
            let next = text.range(of: "\nCurves ", range: table.upperBound..<text.endIndex),
            let regex = try? NSRegularExpression(pattern: "(?m)^(2 (?:\\S+ ){6})\\S+$")
        else { return nil }
        let block = String(text[table.lowerBound..<next.lowerBound])
        let range = NSRange(block.startIndex..., in: block)
        guard let match = regex.firstMatch(in: block, range: range),
            let whole = Swift.Range(match.range, in: block),
            let head = Swift.Range(match.range(at: 1), in: block)
        else { return nil }
        // Spliced, not templated: a radius that starts with a digit would read as a longer group
        // number in a `$1<radius>` template.
        let edited = block[..<head.upperBound] + radius + block[whole.upperBound...]
        return String(text[..<table.lowerBound]) + edited + String(text[next.lowerBound...])
    }

    @Test("the undamaged fixture is valid")
    func theUndamagedFixtureIsValid() throws {
        let text = try Self.fixtureText()
        let shape = try #require(Shape.fromBREPString(text))
        #expect(shape.isValid)
        // The edit is a no-op when it writes the radius the file already has: the helper finds
        // the record, and the control shape stays valid.
        let same = try #require(Self.circleRadius("5", in: text))
        #expect(same == text)
    }

    /// Both radii made the reduction loop forever.
    ///
    /// Radius 0 makes the widening infinite; 1e-300 makes it finite and larger than a turn can
    /// move.
    @Test(
        "a pcurve circle of radius 0, or of one too small to measure, is invalid and returns",
        hangLimit,
        arguments: ["0", "1e-300"])
    func aCircleOfNoRadiusIsInvalidAndReturns(radius: String) throws {
        let text = try Self.fixtureText()
        let damaged = try #require(Self.circleRadius(radius, in: text))
        #expect(damaged != text)
        let shape = try #require(Shape.fromBREPString(damaged))
        #expect(!shape.isValid)
    }
}
