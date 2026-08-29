import Foundation
import Testing

@testable import OCCTSwift

/// `BRepFilletAPI_MakeFillet::Add` silently does nothing for an edge it cannot fillet (most
/// commonly a free-boundary edge of an open shell, which has only one adjacent face where a
/// fillet needs two), so `filleted(edges:radius:)` and its siblings build successfully and skip
/// the edge with no way for a caller to learn which one, or how many. #639.
///
/// The Cluster B census (`Scripts/repro/cluster-b-fillet-edge-contract/`) measured the declined
/// set on this exact fixture: 4 of 12 edges declined (`[6, 9, 10, 11]`), the rest (`[0, 1, 2, 3,
/// 4, 5, 7, 8]`) accepted. Reused here rather than re-derived.
///
/// Three genuinely new entry points were added: `filletedWithReport(edges:radius:)`,
/// `filletedWithReport(edges:startRadius:endRadius:)` and `filletEvolvingWithReport(_:)`. Two
/// more members named in the issue (`filletedWithFullHistory(radius:edges:)` and the
/// `FilletBuilder` class API) already carry the mechanism to answer this: `ShapeHistoryRecord`'s
/// `generated`/`isDeleted` pair, and `FilletBuilder.contour(for:)` respectively, measured here
/// too, so a regression in either recipe is caught even though neither got new bridge code.
@Suite("Fillet family reports declined edges (#639)")
struct Issue639FilletDeclinedEdgeReport {

    /// Uses `FilletTestFixtures.openShell()` and `FilletTestFixtures.declinedIndices` for the
    /// open-shell fixture with known declined edges.
    static let acceptedIndices = [0, 1, 2, 3, 4, 5, 7, 8]

    // MARK: - filletedWithReport(edges:radius:)

    @Test("filletedWithReport(edges:radius:) names exactly the census's declined set")
    func filletedWithReportNamesDeclinedEdges() {
        guard let shell = FilletTestFixtures.openShell() else {
            Issue.record("open shell fixture failed to build")
            return
        }
        let edges = shell.edges()
        #expect(edges.count == 12)

        guard let report = shell.filletedWithReport(edges: edges, radius: 1.0) else {
            Issue.record("filletedWithReport unexpectedly returned nil")
            return
        }
        #expect(Set(report.declinedEdgeIndices) == Set(FilletTestFixtures.declinedIndices))
        // Reporting must not change the built geometry: same skip-not-reject answer as the
        // non-reporting sibling.
        guard let plain = shell.filleted(edges: edges, radius: 1.0) else {
            Issue.record("filleted(edges:radius:) unexpectedly returned nil")
            return
        }
        #expect(abs((report.shape.surfaceArea ?? -1) - (plain.surfaceArea ?? -2)) < 1e-9)
    }

    @Test("filletedWithReport(edges:radius:) reports no declines on a closed solid")
    func filletedWithReportEmptyOnClosedSolid() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box fixture failed to build")
            return
        }
        guard let report = box.filletedWithReport(edges: box.edges(), radius: 1.0) else {
            Issue.record("filletedWithReport unexpectedly returned nil on a closed box")
            return
        }
        #expect(report.declinedEdgeIndices.isEmpty)
    }

    // MARK: - filletedWithReport(edges:startRadius:endRadius:)

    @Test("filletedWithReport(edges:startRadius:endRadius:) names the same declined set")
    func filletedLinearWithReportNamesDeclinedEdges() {
        guard let shell = FilletTestFixtures.openShell() else {
            Issue.record("open shell fixture failed to build")
            return
        }
        let edges = shell.edges()
        guard let report = shell.filletedWithReport(edges: edges, startRadius: 1.0, endRadius: 1.0)
        else {
            Issue.record("filletedWithReport(startRadius:endRadius:) unexpectedly returned nil")
            return
        }
        #expect(Set(report.declinedEdgeIndices) == Set(FilletTestFixtures.declinedIndices))
    }

    // MARK: - filletEvolvingWithReport(_:)

    @Test("filletEvolvingWithReport(_:) names the same declined set -- the #639 gap named directly")
    func filletEvolvingWithReportNamesDeclinedEdges() {
        guard let shell = FilletTestFixtures.openShell() else {
            Issue.record("open shell fixture failed to build")
            return
        }
        let edges = shell.edges()
        let laws = edges.map {
            EvolvingFilletEdge(edge: $0, radiusPoints: [(0.0, 1.0), (1.0, 1.0)])
        }
        guard let report = shell.filletEvolvingWithReport(laws) else {
            Issue.record("filletEvolvingWithReport unexpectedly returned nil")
            return
        }
        #expect(Set(report.declinedEdgeIndices) == Set(FilletTestFixtures.declinedIndices))
    }

    @Test("filletEvolvingWithReport(_:) reports no declines on a closed solid")
    func filletEvolvingWithReportEmptyOnClosedSolid() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box fixture failed to build")
            return
        }
        let laws = box.edges().map {
            EvolvingFilletEdge(edge: $0, radiusPoints: [(0.0, 1.0), (1.0, 1.0)])
        }
        guard let report = box.filletEvolvingWithReport(laws) else {
            Issue.record("filletEvolvingWithReport unexpectedly returned nil on a closed box")
            return
        }
        #expect(report.declinedEdgeIndices.isEmpty)
    }

    // MARK: - FilletBuilder.contour(for:) already answers this (documented, not new code)

    @Test("FilletBuilder.contour(for:) == 0 already names the declined set")
    func filletBuilderContourNamesDeclinedEdges() {
        guard let shell = FilletTestFixtures.openShell() else {
            Issue.record("open shell fixture failed to build")
            return
        }
        guard let builder = FilletBuilder(shape: shell) else {
            Issue.record("FilletBuilder(shape:) unexpectedly returned nil")
            return
        }
        let edges = shell.edges()
        for edge in edges { builder.addEdge(edge, radius: 1.0) }

        // Contour(E) is populated by Add(), not Build(): readable before build() is called.
        let declinedBeforeBuild = edges.filter { builder.contour(for: $0) == 0 }.map(\.index)
        #expect(Set(declinedBeforeBuild) == Set(FilletTestFixtures.declinedIndices))

        #expect(builder.build() != nil)
        let declinedAfterBuild = edges.filter { builder.contour(for: $0) == 0 }.map(\.index)
        #expect(Set(declinedAfterBuild) == Set(FilletTestFixtures.declinedIndices))
    }

    // MARK: - ShapeHistoryRecord already answers this (documented, not new code)

    @Test(
        "filletedWithFullHistory's ShapeHistoryRecord names the declined set via generated/isDeleted"
    )
    func historyRecordNamesDeclinedEdges() {
        guard let shell = FilletTestFixtures.openShell() else {
            Issue.record("open shell fixture failed to build")
            return
        }
        let edgeShapes = shell.subShapes(ofType: .edge)
        #expect(edgeShapes.count == 12)

        guard
            let (_, history) = shell.filletedWithFullHistory(
                radius: 1.0, edges: Array(0..<edgeShapes.count))
        else {
            Issue.record("filletedWithFullHistory unexpectedly returned nil")
            return
        }

        let declined = edgeShapes.indices.filter {
            let record = history.record(of: edgeShapes[$0])
            return !record.isDeleted && record.generated.isEmpty
        }
        #expect(Set(declined) == Set(FilletTestFixtures.declinedIndices))

        // The reliable signal is generated/isDeleted, not modified.isEmpty: a declined edge can
        // still carry one `modified` entry when an accepted neighbour's fillet trims its shared
        // endpoint. At least one declined edge in this fixture demonstrates that -- if none did,
        // the note above would be untested, not merely unnecessary.
        let declinedWithNonEmptyModified = FilletTestFixtures.declinedIndices.filter {
            !history.record(of: edgeShapes[$0]).modified.isEmpty
        }
        #expect(
            !declinedWithNonEmptyModified.isEmpty,
            "expected at least one declined edge to show a non-empty `modified` from neighbour trimming"
        )

        // And every accepted edge is deleted with something generated -- the opposite pattern.
        for index in Self.acceptedIndices {
            let record = history.record(of: edgeShapes[index])
            #expect(record.isDeleted)
            #expect(!record.generated.isEmpty)
        }
    }

    /// The review noted no case drove a **duplicate** requested edge through a `WithReport` method,
    /// which is also the semantics nit 1 documents: `declinedEdgeIndices` mirrors the request list
    /// rather than deduplicating it, so a declined edge named twice is reported twice.
    ///
    /// Pinning it matters because the alternative, silently deduplicating, is the more "obvious"
    /// implementation and would make the count stop matching how many entries of the caller's list
    /// were refused.
    @Test("A declined edge named twice is reported twice, matching the request list")
    func declinedEdgeNamedTwiceIsReportedTwice() {
        guard let shell = FilletTestFixtures.openShell() else {
            Issue.record("could not build the open-shell fixture")
            return
        }
        let edges = shell.edges()
        guard let declined = FilletTestFixtures.declinedIndices.first, declined < edges.count else {
            Issue.record("fixture has no declined edge to duplicate")
            return
        }
        // An accepted edge has to be in the list too. Requesting only declined edges leaves
        // nothing to fillet, so Build() fails and the call returns nil with no report to read,
        // which is a different behaviour and not the one under test here.
        guard let accepted = (0..<edges.count).first(where: { !FilletTestFixtures.declinedIndices.contains($0) })
        else {
            Issue.record("fixture has no accepted edge")
            return
        }
        let doubled = [edges[declined], edges[declined], edges[accepted]]
        guard let report = shell.filletedWithReport(edges: doubled, radius: 0.5) else {
            Issue.record("filletedWithReport returned nil for the duplicated declined edge")
            return
        }
        #expect(
            report.declinedEdgeIndices.count == 2,
            "expected the decline reported once per request entry, got \(report.declinedEdgeIndices)"
        )
        #expect(Set(report.declinedEdgeIndices) == [declined])
    }
}
