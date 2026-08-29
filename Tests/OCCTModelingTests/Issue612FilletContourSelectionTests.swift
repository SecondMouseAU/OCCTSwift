import Foundation
import Testing

@testable import OCCTSwift

/// The fillet radius-law entry points wrote every law to `SetRadius(law, NbContours(), 1)`. Both
/// coordinates were wrong.
///
/// `NbContours()` is "the contour that exists after the most recent `Add`", which is the edge's own
/// contour only when every `Add` creates one, a tangent-continuous edge *extends* an existing
/// contour instead. And the third argument is the edge's index **within** the contour, selecting a
/// distinct per-edge slot; hardcoding it to `1` sent every edge of a tangent chain to the same slot,
/// so only the last survived.
///
/// The second half is what made two edges of one contour look like an unresolvable conflict. It is
/// not one: `Add(Radius, E)` (behind ``Shape/blendedEdges(_:)``) has always resolved that slot
/// itself, so it already honoured the very request `filletEvolving` could not. #612
@Suite("Fillet radius laws go to the edge's own slot in the edge's own contour (#612)")
struct Issue612FilletContourSelection {

    // MARK: - Fixture

    static let slotHalfLength = 10.0
    static let slotRadius = 8.0
    static let slotHeight = 20.0

    /// A rounded-slot prism: two straight sides joined by two semicircular ends, extruded in +Z.
    /// Every edge of the top rim is tangent-continuous with its neighbours, so the whole rim is a
    /// single fillet contour holding four edges; the bottom rim is a second, independent one.
    static func roundedSlot() -> Shape? {
        let l = slotHalfLength
        let r = slotRadius
        guard let bottom = Wire.line(from: SIMD3(-l, -r, 0), to: SIMD3(l, -r, 0)),
            let right = Wire.arc(
                start: SIMD3(l, -r, 0),
                midpoint: SIMD3(l + r, 0, 0),
                end: SIMD3(l, r, 0)),
            let top = Wire.line(from: SIMD3(l, r, 0), to: SIMD3(-l, r, 0)),
            let left = Wire.arc(
                start: SIMD3(-l, r, 0),
                midpoint: SIMD3(-l - r, 0, 0),
                end: SIMD3(-l, -r, 0)),
            let profile = Wire.join([bottom, right, top, left]),
            let face = Shape.face(from: profile)
        else { return nil }
        return face.extruded(by: SIMD3(0, 0, slotHeight))
    }

    /// Uses `FilletTestFixtures.openShell()` for the open-shell fixture with known declined edges.

    /// Edge indices on a rim at height `z`, split by curve kind.
    static func rimEdges(of shape: Shape, atHeight z: Double) -> (lines: [Int], arcs: [Int]) {
        var lines: [Int] = []
        var arcs: [Int] = []
        for (index, edge) in shape.edges().enumerated() {
            let (start, end) = edge.endpoints
            guard abs(start.z - z) < 1e-7, abs(end.z - z) < 1e-7 else { continue }
            if edge.isLine { lines.append(index) } else if edge.isCircle { arcs.append(index) }
        }
        return (lines, arcs)
    }

    static func constant(_ radius: Double) -> [(parameter: Double, radius: Double)] {
        [(0.0, radius), (1.0, radius)]
    }

    /// The top rim's straight side and one tangent arc: same contour, different slots.
    static func tangentPair(of slot: Shape)
        -> (line: Edge, arc: Edge, lineIndex: Int, arcIndex: Int)?
    {
        let top = rimEdges(of: slot, atHeight: slotHeight)
        let edges = slot.edges()
        guard let li = top.lines.first, let ai = top.arcs.first,
            edges.indices.contains(li), edges.indices.contains(ai)
        else { return nil }
        return (edges[li], edges[ai], li, ai)
    }

    // MARK: - The premise

    @Test("The top rim is one contour of four edges, so one contour is not one law")
    func fixtureHasATangentContinuousRim() {
        guard let slot = Self.roundedSlot(), let pair = Self.tangentPair(of: slot) else {
            Issue.record("rounded slot fixture failed to build")
            return
        }
        let top = Self.rimEdges(of: slot, atHeight: Self.slotHeight)
        let bottom = Self.rimEdges(of: slot, atHeight: 0)
        #expect(top.lines.count == 2)
        #expect(top.arcs.count == 2)
        #expect(bottom.lines.count == 2)
        #expect(bottom.arcs.count == 2)

        guard let builder = FilletBuilder(shape: slot) else {
            Issue.record("could not build the tangency probe")
            return
        }
        builder.addEdge(pair.line, radius: 2)
        // One contour, and it already holds the arc the caller never added.
        #expect(builder.contourCount == 1)
        #expect(builder.contour(for: pair.arc) == 1)
    }

    // MARK: - Two laws, one contour, both honoured

    @Test("Two tangent-continuous edges carry different radius laws, matching blendedEdges exactly")
    func bothLawsOnOneContourAreHonoured() {
        guard let slot = Self.roundedSlot(), let pair = Self.tangentPair(of: slot) else {
            Issue.record("rounded slot fixture failed to build")
            return
        }

        // The request #612 was filed against, in its simplest form: one contour, two laws.
        let evolving = slot.filletEvolving([
            EvolvingFilletEdge(edge: pair.line, radiusPoints: Self.constant(2)),
            EvolvingFilletEdge(edge: pair.arc, radiusPoints: Self.constant(5)),
        ])

        // blendedEdges reaches Add(Radius, E), which has always resolved the per-edge slot itself.
        // It is the independent oracle for what the request means.
        let blended = slot.blendedEdges([(pair.lineIndex, 2.0), (pair.arcIndex, 5.0)])

        guard let evolvingVolume = evolving?.volume, let blendedVolume = blended?.volume else {
            Issue.record("one of the two-law requests did not produce a measurable solid")
            return
        }

        // Byte-identical: both laws honoured, each in its own slot.
        #expect(abs(evolvingVolume - blendedVolume) < 1e-6)
        #expect(abs(evolvingVolume - 10139.793468) < 1e-3)

        // Not the last-writer-wins answer the old code produced, where both laws went to slot 1.
        #expect(abs(evolvingVolume - 9974.608333) > 1.0)
    }

    @Test("The issue's own request, a taper on one edge, a constant on its tangent neighbour")
    func taperAndConstantOnOneContourBuild() {
        guard let slot = Self.roundedSlot(), let pair = Self.tangentPair(of: slot) else {
            Issue.record("rounded slot fixture failed to build")
            return
        }

        // #612's failure scenario verbatim: a taper on one edge, a constant on the other. This used
        // to come back with the constant applied to both.
        let out = slot.filletEvolving([
            EvolvingFilletEdge(edge: pair.line, radiusPoints: [(0.0, 1.0), (1.0, 3.0)]),
            EvolvingFilletEdge(edge: pair.arc, radiusPoints: Self.constant(5)),
        ])

        guard let volume = out?.volume else {
            Issue.record("the taper-plus-constant request did not produce a measurable solid")
            return
        }
        #expect(abs(volume - 10171.225408) < 1e-3)

        // The taper is really a taper: replacing it with a constant moves the result.
        if let flat = slot.filletEvolving([
            EvolvingFilletEdge(edge: pair.line, radiusPoints: Self.constant(3)),
            EvolvingFilletEdge(edge: pair.arc, radiusPoints: Self.constant(5)),
        ])?.volume {
            #expect(abs(volume - flat) > 1.0)
        }
    }

    // MARK: - The wrong-contour half

    @Test("A third edge extending contour 1 does not overwrite contour 2's radius law")
    func lawLandsOnTheEdgesOwnContour() {
        guard let slot = Self.roundedSlot(), let pair = Self.tangentPair(of: slot) else {
            Issue.record("rounded slot fixture failed to build")
            return
        }
        let bottom = Self.rimEdges(of: slot, atHeight: 0)
        let edges = slot.edges()
        guard let bottomIndex = bottom.lines.first, edges.indices.contains(bottomIndex) else {
            Issue.record("could not identify the bottom rim")
            return
        }
        let bottomLine = edges[bottomIndex]
        let topRadius = 2.0
        let bottomRadius = 5.0

        // Reference: top rim at 2, bottom rim at 5, one edge per contour, needs no shared-contour
        // resolution, so it was already correct before this fix.
        let intended = slot.filletEvolving([
            EvolvingFilletEdge(edge: pair.line, radiusPoints: Self.constant(topRadius)),
            EvolvingFilletEdge(edge: bottomLine, radiusPoints: Self.constant(bottomRadius)),
        ])

        // What the defect produced: the third edge's law overwrote contour 2, so the bottom rim
        // came out at the top rim's radius instead of its own.
        let clobbered = slot.filletEvolving([
            EvolvingFilletEdge(edge: pair.line, radiusPoints: Self.constant(topRadius)),
            EvolvingFilletEdge(edge: bottomLine, radiusPoints: Self.constant(topRadius)),
        ])

        // The request under test: a third edge, in contour 1, added after contour 2 exists.
        let actual = slot.filletEvolving([
            EvolvingFilletEdge(edge: pair.line, radiusPoints: Self.constant(topRadius)),
            EvolvingFilletEdge(edge: bottomLine, radiusPoints: Self.constant(bottomRadius)),
            EvolvingFilletEdge(edge: pair.arc, radiusPoints: Self.constant(topRadius)),
        ])

        guard let intendedVolume = intended?.volume,
            let clobberedVolume = clobbered?.volume,
            let actualVolume = actual?.volume
        else {
            Issue.record("one of the fillet requests did not produce a measurable solid")
            return
        }

        // The two references must differ, or the assertions below prove nothing.
        #expect(abs(intendedVolume - clobberedVolume) > 1.0)
        // The third edge only repeats its own contour's law, so the geometry is the intended one.
        #expect(abs(actualVolume - intendedVolume) < 1e-6)
        // The bottom rim keeps the 5mm it was asked for, rather than the top rim's 2mm.
        #expect(abs(actualVolume - clobberedVolume) > 1.0)
    }

    // MARK: - The sibling site, which the first attempt wrongly called unobservable

    @Test("filletLinear places each edge's law in that edge's own slot")
    func linearFilletPlacesEachEdgesLaw() {
        guard let slot = Self.roundedSlot(), let pair = Self.tangentPair(of: slot) else {
            Issue.record("rounded slot fixture failed to build")
            return
        }

        // A NON-constant law is what makes the slot visible. With startRadius == endRadius every
        // slot carries the same number and the defect hides, which is why this site was first,
        // wrongly, called "never observably wrong".
        let pairResult = slot.filleted(edges: [pair.line, pair.arc], startRadius: 1, endRadius: 4)
        let lineOnly = slot.filleted(edges: [pair.line], startRadius: 1, endRadius: 4)

        guard let pairVolume = pairResult?.volume, let lineVolume = lineOnly?.volume else {
            Issue.record("linear fillet did not produce a measurable solid")
            return
        }

        // Each law in its own slot.
        #expect(abs(pairVolume - 10297.711861) < 1e-3)
        // The old idiom wrote both to slot 1, which measures exactly as filleting the line alone.
        #expect(abs(lineVolume - 10273.238348) < 1e-3)
        #expect(abs(pairVolume - lineVolume) > 1.0)
    }

    // MARK: - Edges OCCT declines to add

    @Test("An edge Add() refuses is skipped, not turned into a nil result")
    func refusedEdgesAreSkippedNotRejected() {
        guard let shell = FilletTestFixtures.openShell() else {
            Issue.record("open shell fixture failed to build")
            return
        }
        let edges = shell.edges()
        #expect(edges.count == 12)
        let allIndices = Array(edges.indices)

        // The entry points that reach Add(Radius, E) have always skipped the free-boundary edges
        // this shell has; the law-taking ones must agree rather than returning nil.
        let constantRadius = shell.filleted(edges: edges, radius: 1)
        let blended = shell.blendedEdges(allIndices.map { ($0, 1.0) })
        let linear = shell.filleted(edges: edges, startRadius: 1, endRadius: 1)
        let evolving = shell.filletEvolving(
            edges.map {
                EvolvingFilletEdge(edge: $0, radiusPoints: Self.constant(1))
            })
        let withHistory = shell.filletedWithFullHistory(radius: 1, edges: allIndices)?.result

        // Measured by surface AREA, not volume: an open shell is not a solid, so `volume` is nil
        // for every one of these results whether the fillet succeeded or not, and asking OCCT
        // directly gets a fabricated number that is not even a property of the shape (#605/#609).
        // Reported per entry point, so a failure names the one that regressed rather than the batch.
        let measured: [(String, Double?)] = [
            ("filleted(edges:radius:)", constantRadius?.surfaceArea),
            ("blendedEdges(_:)", blended?.surfaceArea),
            ("filleted(edges:startRadius:endRadius:)", linear?.surfaceArea),
            ("filletEvolving(_:)", evolving?.surfaceArea),
            ("filletedWithFullHistory(radius:edges:)", withHistory?.surfaceArea),
        ]
        for (name, area) in measured where area == nil {
            Issue.record(
                "\(name) returned nil over an open shell instead of skipping the edges OCCT declined"
            )
        }

        guard let plainArea = shell.surfaceArea else {
            Issue.record("the open shell fixture itself has no measurable surface area")
            return
        }
        guard let constantArea = constantRadius?.surfaceArea else { return }
        for (name, area) in measured {
            guard let area else { continue }
            #expect(abs(area - constantArea) < 1e-6, "\(name) disagrees with the family")
        }
        // The agreed answer, measured against the kernel directly.
        #expect(abs(constantArea - 465.09733552923257) < 1e-6)
        // And the fillet did happen, rounding the accepted edges changed the surface.
        #expect(abs(constantArea - plainArea) > 1.0)
    }

    @Test("A variable fillet on an edge Add() refuses fails, where it used to SIGSEGV")
    func variableFilletOnARefusedEdgeDoesNotCrash() {
        guard let shell = FilletTestFixtures.openShell() else {
            Issue.record("open shell fixture failed to build")
            return
        }

        // Reaching the end of this loop at all is the assertion: SetRadius(law, 0, 1) on a refused
        // edge is the unchecked low side of OCCT's contour index, and it used to take the whole
        // test process down with SIGSEGV, uncatchable, so no catch(...) on the bridge side helps.
        var refusedCount = 0
        for index in shell.edges().indices {
            if shell.filletedVariable(
                edgeIndex: index,
                radiusProfile: [(0.0, 1.0), (1.0, 2.0)]) == nil
            {
                refusedCount += 1
            }
        }
        // At least one edge of this shell is one OCCT declines, and it now fails cleanly.
        #expect(refusedCount > 0)
    }

    // MARK: - Preconditions still reject

    @Test("A malformed profile still rejects the whole call")
    func malformedProfilesStillReject() {
        guard let slot = Self.roundedSlot(), let pair = Self.tangentPair(of: slot) else {
            Issue.record("rounded slot fixture failed to build")
            return
        }
        // Skipping an edge OCCT declines must not have loosened the profile contract (#520).
        #expect(
            slot.filletEvolving([
                EvolvingFilletEdge(edge: pair.line, radiusPoints: Self.constant(2)),
                EvolvingFilletEdge(edge: pair.arc, radiusPoints: [(0.0, -3.0), (1.0, 2.0)]),
            ]) == nil)
        #expect(
            slot.filletEvolving([
                EvolvingFilletEdge(edge: pair.line, radiusPoints: [(1.0, 2.0), (0.0, 3.0)])
            ]) == nil)
        #expect(
            slot.filletEvolving([
                EvolvingFilletEdge(edge: pair.line, radiusPoints: [])
            ]) == nil)
    }
}
