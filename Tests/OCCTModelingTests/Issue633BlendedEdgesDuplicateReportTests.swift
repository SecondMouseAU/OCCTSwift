import Foundation
import Testing

@testable import OCCTSwift

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

    /// A 10mm box with one face dropped and the rest sewn back together: an open shell whose free
    /// boundary edges `BRepFilletAPI_MakeFillet::Add` declines. Identical construction to
    /// `Issue639FilletDeclinedEdgeReport.openShell()` and the Cluster B census's own fixture.
    static func openShell() -> Shape? {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return nil }
        let faces = box.faces().compactMap { Shape.fromFace($0) }
        guard faces.count == 6 else { return nil }
        return Shape.sew(shapes: Array(faces.dropFirst()))
    }

    /// Measured by the Cluster B census on this exact fixture; reused here rather than re-derived.
    static let declinedIndices = [6, 9, 10, 11]

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
    func distinctIndicesReportNoOverwrites() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box fixture failed to build")
            return
        }
        guard let report = box.blendedEdgesWithReport([(0, 1.0), (1, 2.0), (2, 0.5)]) else {
            Issue.record("blendedEdgesWithReport unexpectedly returned nil")
            return
        }
        #expect(report.overwrittenDuplicateIndices.isEmpty)
        #expect(report.declinedEdgeIndices.isEmpty)
    }

    // MARK: - declinedEdgeIndices: blendedEdgesWithReport adopts #639's mechanism too

    @Test("blendedEdgesWithReport names the same declined set #639 measured for its siblings")
    func declinedEdgesAreNamedOnAnOpenShell() {
        guard let shell = Self.openShell() else {
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
        #expect(Set(report.declinedEdgeIndices) == Set(Self.declinedIndices))
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
        guard let shell = Self.openShell() else {
            Issue.record("open shell fixture failed to build")
            return
        }
        let edgeCount = shell.edges().count
        guard let accepted = (0..<edgeCount).first(where: { !Self.declinedIndices.contains($0) })
        else {
            Issue.record("fixture has no accepted edge")
            return
        }
        // Duplicate an accepted edge, and request every declined edge once.
        var request: [(edgeIndex: Int, radius: Double)] = [(accepted, 1.0), (accepted, 2.0)]
        request.append(contentsOf: Self.declinedIndices.map { ($0, 1.0) })

        guard let report = shell.blendedEdgesWithReport(request) else {
            Issue.record("blendedEdgesWithReport unexpectedly returned nil")
            return
        }
        #expect(report.overwrittenDuplicateIndices == [accepted])
        #expect(Set(report.declinedEdgeIndices) == Set(Self.declinedIndices))
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
    func emptyReportsOnAClosedSolid() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box fixture failed to build")
            return
        }
        let request = (0..<box.edges().count).map { ($0, 1.0) }
        guard let report = box.blendedEdgesWithReport(request) else {
            Issue.record("blendedEdgesWithReport unexpectedly returned nil on a closed box")
            return
        }
        #expect(report.declinedEdgeIndices.isEmpty)
        #expect(report.overwrittenDuplicateIndices.isEmpty)
    }
}
