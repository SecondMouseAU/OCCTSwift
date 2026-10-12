import Foundation
import Testing

@testable import OCCTSwift

/// A duplicated edge index is last-wins in `blendedEdges(_:)`, and nothing said so.
///
/// `BRepFilletAPI_MakeFillet::Add(radius, edge)` resolves the edge's own slot within its fillet
/// contour and writes there, so a second `Add` call naming the same edge index silently overwrites
/// the first radius rather than combining the two or erroring. `blendedEdges(_:)` never deduplicates
/// its `edgeRadii` list, so a caller who names one edge twice (by accident, or by building the list
/// from a selection with a repeat) gets a shape built from only the *last* radius, with no signal
/// that the earlier one was ever discarded. #633.
///
/// Measured directly (`swift run Censuses cluster-b`), not assumed from the issue's own numbers:
/// on a plain 10mm box, `blendedEdges([(0, 2.0), (0, 5.0)])` gives the identical volume to
/// `blendedEdges([(0, 5.0)])` (946.349541) and differs from `blendedEdges([(0, 2.0)])` (991.415927)
/// -- last-wins, confirmed on this tree rather than trusted from the census's own writeup.
///
/// `blendedEdgesWithReport(_:)` is the new entry point (#709's recommendation for this issue,
/// taken as given): it changes nothing about the shape `blendedEdges(_:)` already returns, and adds
/// a `Shape.FilletResult` naming both axes this family can silently discard on -- the declined-edge
/// axis #639 already reports for its three siblings, and the duplicate-overwrite axis this issue is
/// about -- rather than inventing a second, parallel reporting type for the same idea (#490's lesson).
@Suite("blendedEdges reports overwritten duplicates (#633)")
struct Issue633BlendedEdgesDuplicateReport {

    // Uses `FilletTestFixtures.openShell()` and `FilletTestFixtures.declinedIndices` for the
    // open-shell fixture with known declined edges.

    // MARK: - overwrittenDuplicateIndices: a single duplicated edge

    @Test("a duplicated edge index reports one overwritten entry, and the shape is unchanged")
    func duplicatedEdgeReportsOneOverwrittenEntry() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box fixture failed to build")
            return
        }
        guard let report = box.blendedEdgesWithReport([(0, 2.0), (0, 5.0)]) else {
            Issue.record("blendedEdgesWithReport unexpectedly returned nil")
            return
        }
        #expect(report.overwrittenDuplicateIndices == [0])
        #expect(report.declinedEdgeIndices.isEmpty)

        // Reporting must not change the built geometry: last-wins, exactly like the non-reporting
        // sibling, and exactly like naming edge 0 with only the winning radius.
        guard let plain = box.blendedEdges([(0, 2.0), (0, 5.0)]),
            let lastOnly = box.blendedEdges([(0, 5.0)])
        else {
            Issue.record("blendedEdges unexpectedly returned nil")
            return
        }
        #expect(abs((report.shape.volume ?? -1) - (plain.volume ?? -2)) < 1e-9)
        #expect(abs((report.shape.volume ?? -1) - (lastOnly.volume ?? -2)) < 1e-9)
    }

    // MARK: - overwrittenDuplicateIndices mirrors the request list, like declinedEdgeIndices

    @Test("an edge named three times reports two overwritten entries, not one")
    func tripleDuplicateReportsTwoOverwrittenEntries() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box fixture failed to build")
            return
        }
        guard let report = box.blendedEdgesWithReport([(0, 2.0), (0, 3.0), (0, 5.0)]) else {
            Issue.record("blendedEdgesWithReport unexpectedly returned nil")
            return
        }
        // Two entries lost (the 2.0 and the 3.0), one (the 5.0) won: the count matches how many
        // entries of the caller's list were discarded, the same convention #639 established for
        // declinedEdgeIndices. Deduplicating to the distinct edge index would report [0], which is
        // the defect this test exists to catch.
        #expect(report.overwrittenDuplicateIndices == [0, 0])

        guard let lastOnly = box.blendedEdges([(0, 5.0)]) else {
            Issue.record("blendedEdges unexpectedly returned nil")
            return
        }
        #expect(abs((report.shape.volume ?? -1) - (lastOnly.volume ?? -2)) < 1e-9)
    }

    // MARK: - No duplicates: empty report

    @Test("distinct edge indices report no overwritten entries")
    func distinctIndicesReportNoOverwrites() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let report = try #require(box.blendedEdgesWithReport([(0, 1.0), (1, 2.0), (2, 0.5)]))
        #expect(report.overwrittenDuplicateIndices.isEmpty)
        #expect(report.declinedEdgeIndices.isEmpty)

        // Nothing was overwritten, so all three radii took effect: the shape is the three-edge
        // blend (989.0624884..., kernel.6), smaller than any single-edge one, and the same shape
        // the non-reporting sibling builds.
        let volume = try #require(report.shape.volume)
        #expect(abs(volume - 989.0624884756555) < 1e-6)
        #expect(report.shape.isValid)
        let plain = try #require(box.blendedEdges([(0, 1.0), (1, 2.0), (2, 0.5)]))
        #expect(abs(volume - (plain.volume ?? -1)) < 1e-9)
        for (index, radius) in [(0, 1.0), (1, 2.0), (2, 0.5)] {
            let alone = try #require(box.blendedEdges([(index, radius)])?.volume)
            #expect(volume < alone)
        }
    }

    // MARK: - declinedEdgeIndices: blendedEdgesWithReport adopts #639's mechanism too

    @Test("blendedEdgesWithReport names the same declined set #639 measured for its siblings")
    func declinedEdgesAreNamedOnAnOpenShell() {
        guard let shell = FilletTestFixtures.openShell() else {
            Issue.record("open shell fixture failed to build")
            return
        }
        let edgeCount = shell.edges().count
        #expect(edgeCount == 12)
        let request = (0..<edgeCount).map { ($0, 1.0) }

        guard let report = shell.blendedEdgesWithReport(request) else {
            Issue.record("blendedEdgesWithReport unexpectedly returned nil")
            return
        }
        #expect(Set(report.declinedEdgeIndices) == Set(FilletTestFixtures.declinedIndices))
        #expect(report.overwrittenDuplicateIndices.isEmpty)

        // Reporting must not change the built geometry: same skip-not-reject answer as the
        // non-reporting sibling (#633 does not touch this axis, only #639 already fixed it for
        // the three other entry points; this method adopts that fix rather than re-deriving it).
        guard let plain = shell.blendedEdges(request) else {
            Issue.record("blendedEdges unexpectedly returned nil")
            return
        }
        #expect(abs((report.shape.surfaceArea ?? -1) - (plain.surfaceArea ?? -2)) < 1e-9)
    }

    // MARK: - Both axes at once are independent

    @Test("a duplicated accepted edge and a declined edge are reported independently")
    func duplicateAndDeclineAreReportedIndependently() {
        guard let shell = FilletTestFixtures.openShell() else {
            Issue.record("open shell fixture failed to build")
            return
        }
        let edgeCount = shell.edges().count
        guard
            let accepted = (0..<edgeCount).first(where: {
                !FilletTestFixtures.declinedIndices.contains($0)
            })
        else {
            Issue.record("fixture has no accepted edge")
            return
        }
        // Duplicate an accepted edge, and request every declined edge once.
        var request: [(edgeIndex: Int, radius: Double)] = [(accepted, 1.0), (accepted, 2.0)]
        request.append(contentsOf: FilletTestFixtures.declinedIndices.map { ($0, 1.0) })

        guard let report = shell.blendedEdgesWithReport(request) else {
            Issue.record("blendedEdgesWithReport unexpectedly returned nil")
            return
        }
        #expect(report.overwrittenDuplicateIndices == [accepted])
        #expect(Set(report.declinedEdgeIndices) == Set(FilletTestFixtures.declinedIndices))
    }

    // MARK: - The all-or-nothing contracts blendedEdges already has are unaffected

    @Test("blendedEdgesWithReport rejects an out-of-range index, an empty list, and a bad radius")
    func rejectsTheSameInputsBlendedEdgesRejects() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box fixture failed to build")
            return
        }
        #expect(box.blendedEdgesWithReport([]) == nil)
        #expect(box.blendedEdgesWithReport([(0, 1.0), (99_999, 2.0)]) == nil)
        #expect(box.blendedEdgesWithReport([(0, 1.0), (1, 0.0)]) == nil)
    }

    @Test(
        "blendedEdgesWithReport reports no declines or overwrites on a closed solid's own edge list"
    )
    func emptyReportsOnAClosedSolid() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let request = (0..<box.edges().count).map { ($0, 1.0) }
        let report = try #require(box.blendedEdgesWithReport(request))
        #expect(report.declinedEdgeIndices.isEmpty)
        #expect(report.overwrittenDuplicateIndices.isEmpty)

        // The report is empty because every edge took, and the shape says so: all twelve edges of
        // a 10 mm cube at r = 1 is the rounded box (a - 2r)^3 + 6 (a - 2r)^2 r + 3 pi r^2 (a - 2r)
        // + 4/3 pi r^3 = 975.587..., 26 faces.
        let expected = 512.0 + 384.0 + 3.0 * Double.pi * 8.0 + 4.0 / 3.0 * Double.pi
        #expect(abs((report.shape.volume ?? -1) - expected) < 1e-6)
        #expect(report.shape.faces().count == 26)
        #expect(report.shape.isValid)
    }
}
