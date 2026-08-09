// Cluster B census (#665): for every entry point in the fillet/chamfer/blend edge-set family,
// what happens to a duplicate index, an out-of-range index, an index OCCT declines, and an empty
// list. #520, #568, #612, #633 and #639 are prior art on this exact contract and are cited inline
// rather than rederived; this file's job is to measure the CURRENT tree against all four axes at
// once, in one place, the way #664's Cluster A census did for sub-shape enumeration.
//
// This is the DYNAMIC half, following Cluster A's method: a runnable artifact that calls each
// entry point against real fixtures and records what comes back, as the primary evidence.
// `classify_fillet_sites.py` (in this cluster's own Scripts/repro/cluster-b-fillet-edge-contract/)
// is the static cross-check.
//
// Run with: swift run Censuses cluster-b
//
// This census only measures. It does not fix #633 or #639.

import Foundation
import OCCTSwift
import simd

// MARK: - Fixtures

fileprivate enum ClusterBFixture {
    /// A 10mm box with one face dropped and the rest sewn back together: an open shell whose free
    /// boundary edges `BRepFilletAPI_MakeFillet::Add` (and, this census also measures,
    /// `BRepFilletAPI_MakeChamfer::Add`) decline. Identical construction to
    /// `Tests/OCCTModelingTests/Issue612FilletContourSelectionTests.openShell()` -- reused rather
    /// than re-derived, since #665 explicitly warns not to rebuild prior art from scratch.
    static func openShell() -> Shape? {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return nil }
        let faces = box.faces().compactMap { Shape.fromFace($0) }
        guard faces.count == 6 else { return nil }
        return Shape.sew(shapes: Array(faces.dropFirst()))
    }

    /// A plain rectangular face, the fixture `Issue568IndexSkipTests` already uses for
    /// `fillet2D`/`chamfer2D`: 4 straight edges, 4 vertices, edges (0, 1) share a vertex.
    static func rectFace() -> Shape? {
        guard let wire = Wire.rectangle(width: 20, height: 20) else { return nil }
        return Shape.face(from: wire)
    }

    /// Midpoint of an edge, by sampled arc length -- `Issue613IndexContractTests`' own technique
    /// for identifying an edge geometrically instead of by an index that may not carry across
    /// shapes.
    static func midpoint(of edge: Edge) -> SIMD3<Double>? {
        let points = edge.points(count: 3)
        return points.count == 3 ? points[1] : nil
    }

    static func distance(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        let d = a - b
        return (d.x * d.x + d.y * d.y + d.z * d.z).squareRoot()
    }

    /// The index, in `shape.faces()`, of a face genuinely adjacent to `shape.edges()[edgeIndex]`.
    /// The Swift API has no direct edge-to-face adjacency query, so this matches edge midpoints
    /// geometrically between the target edge and every candidate face's own edge list. Only the
    /// first match is returned: `chamferedTwoDistances`/`chamferedDistAngle` are exercised here
    /// with dist1 == dist2, so which of an edge's (up to two) adjacent faces is named never
    /// changes the measured result, only a genuinely unrelated face would.
    static func adjacentFaceIndex(forEdge edgeIndex: Int, in shape: Shape) -> Int? {
        let edges = shape.edges()
        guard edges.indices.contains(edgeIndex), let target = midpoint(of: edges[edgeIndex]) else { return nil }
        for (faceIndex, face) in shape.faces().enumerated() {
            guard let faceShape = Shape.fromFace(face) else { continue }
            for candidate in faceShape.edges() {
                if let candidateMid = midpoint(of: candidate), distance(target, candidateMid) < 1e-6 {
                    return faceIndex
                }
            }
        }
        return nil
    }
}

// MARK: - Report plumbing

fileprivate struct ClusterBRow {
    let family: String
    let entryPoint: String
    let duplicateIndex: String
    let outOfRangeIndex: String
    let occtDeclined: String
    let emptyList: String
    let note: String
}

fileprivate func fmt(_ value: Double?) -> String {
    guard let value else { return "nil" }
    return String(format: "%.6f", value)
}

fileprivate func volumesAgree(_ a: Double?, _ b: Double?) -> Bool {
    guard let a, let b else { return false }
    return abs(a - b) < 1e-6
}

enum ClusterB {
    static func run() {
        var rows: [ClusterBRow] = []

        func record(_ family: String, _ entryPoint: String, duplicate: String, outOfRange: String,
                    declined: String, empty: String, note: String = "") {
            rows.append(ClusterBRow(family: family, entryPoint: entryPoint, duplicateIndex: duplicate,
                                     outOfRangeIndex: outOfRange, occtDeclined: declined,
                                     emptyList: empty, note: note))
        }

        // MARK: - Fixtures under measurement

        // #694's concrete shared-fixture win: the same split-box compound Cluster A's own census
        // builds, reused here rather than copied, as a second well-formed multi-solid shape to
        // corroborate a couple of representative entry points below don't silently depend on
        // "exactly one solid".
        let box = SharedFixture.plainBox()
        let compound = SharedFixture.splitBoxCompound(order: .asSplit)

        guard let shell = ClusterBFixture.openShell() else {
            print("Cluster B census: could not build the open-shell fixture.")
            return
        }
        guard let rectFace = ClusterBFixture.rectFace() else {
            print("Cluster B census: could not build the rectangular-face fixture.")
            return
        }

        // Which of the shell's 12 edges OCCT declines, MEASURED rather than assumed: probe every
        // edge individually through the narrowest entry point that names exactly one edge and
        // fails cleanly rather than throwing (filletedVariable, #520/#612). A nil result names a
        // declined edge and nothing else -- the same probe
        // Issue612FilletContourSelectionTests.variableFilletOnARefusedEdgeDoesNotCrash uses.
        let shellEdgeIndices = Array(shell.edges().indices)
        let declinedShellEdges = shellEdgeIndices.filter {
            shell.filletedVariable(edgeIndex: $0, radiusProfile: [(0.0, 1.0), (1.0, 1.0)]) == nil
        }
        let acceptedShellEdges = shellEdgeIndices.filter { !declinedShellEdges.contains($0) }
        let shellPlainArea = shell.surfaceArea

        // MARK: - filleted(edges:radius:)  [uniform radius across the whole list]
        //
        // Unlike every sibling below, this one takes [Edge] rather than [Int]: the Swift wrapper
        // extracts each edge's own .index and passes that array of indices to the bridge. There is
        // no way to construct an "out-of-range Edge" for `box` directly -- box.edges() only ever
        // returns edges box itself has. The genuine equivalent, and what the method's own doc
        // comment calls out explicitly ("an edge that is not this shape's"), is an Edge from a
        // DIFFERENT shape: Cluster A's shared split-box compound has 20 edges, so its edges()[15]
        // carries .index == 15, which names nothing on a 12-edge box. This is #694's concrete
        // shared-fixture win in practice, not just a build-target convenience.

        do {
            let e0 = box.edges()[0]
            let dup = box.filleted(edges: [e0, e0], radius: 2.0)?.volume
            let single = box.filleted(edges: [e0], radius: 2.0)?.volume
            let foreignEdge = compound.edges()[15]
            let outOfRange = box.filleted(edges: [e0, foreignEdge], radius: 2.0)
            let declined = shell.filleted(edges: shell.edges(), radius: 1.0)
            record("fillet-edges", "filleted(edges:radius:)",
                   duplicate: volumesAgree(dup, single) ? "N/A: uniform radius (dup vol \(fmt(dup)) == single \(fmt(single)))" : "differs (dup \(fmt(dup)) vs single \(fmt(single)))",
                   outOfRange: outOfRange == nil ? "REJECT (nil)" : "measured non-nil",
                   declined: declined != nil ? "SKIP (non-nil, area \(fmt(declined?.surfaceArea)) vs unfilleted \(fmt(shellPlainArea))) -- #639 fixed: filletedWithReport(edges:radius:) sibling reports declinedEdgeIndices" : "REJECT (nil)",
                   empty: box.filleted(edges: [], radius: 2.0) == nil ? "REJECT (nil)" : "non-nil",
                   note: "out-of-range probe: compound.edges()[15] (.index 15) passed to box (12 edges) -- Cluster A's shared fixture reused, #694")
        }

        // MARK: - filleted(edges:startRadius:endRadius:)  [uniform start/end radius]

        do {
            let e0 = box.edges()[0]
            let dup = box.filleted(edges: [e0, e0], startRadius: 1.0, endRadius: 3.0)?.volume
            let single = box.filleted(edges: [e0], startRadius: 1.0, endRadius: 3.0)?.volume
            let foreignEdge = compound.edges()[15]
            let outOfRange = box.filleted(edges: [e0, foreignEdge], startRadius: 1.0, endRadius: 3.0)
            let declined = shell.filleted(edges: shell.edges(), startRadius: 1.0, endRadius: 1.0)
            record("fillet-linear", "filleted(edges:startRadius:endRadius:)",
                   duplicate: volumesAgree(dup, single) ? "N/A: uniform law (dup vol \(fmt(dup)) == single \(fmt(single)))" : "differs (dup \(fmt(dup)) vs single \(fmt(single)))",
                   outOfRange: outOfRange == nil ? "REJECT (nil)" : "measured non-nil",
                   declined: declined != nil ? "SKIP (non-nil, area \(fmt(declined?.surfaceArea)) vs unfilleted \(fmt(shellPlainArea))) -- #639 fixed: filletedWithReport(edges:startRadius:endRadius:) sibling reports declinedEdgeIndices" : "REJECT (nil)",
                   empty: box.filleted(edges: [], startRadius: 1.0, endRadius: 3.0) == nil ? "REJECT (nil)" : "non-nil")
        }

        // MARK: - blendedEdges(_:)  [per-edge radius array] -- #633's own site

        do {
            let dupVolume = box.blendedEdges([(0, 2.0), (0, 5.0)])?.volume
            let lastOnlyVolume = box.blendedEdges([(0, 5.0)])?.volume
            let firstOnlyVolume = box.blendedEdges([(0, 2.0)])?.volume
            let dupVerdict: String
            if volumesAgree(dupVolume, lastOnlyVolume) && !volumesAgree(dupVolume, firstOnlyVolume) {
                dupVerdict = "OVERWRITE: last radius wins (dup \(fmt(dupVolume)) == last-only \(fmt(lastOnlyVolume)), != first-only \(fmt(firstOnlyVolume))) -- #633 fixed: blendedEdgesWithReport(_:) sibling reports overwrittenDuplicateIndices"
            } else if volumesAgree(dupVolume, firstOnlyVolume) {
                dupVerdict = "OVERWRITE: first radius wins (dup \(fmt(dupVolume)) == first-only \(fmt(firstOnlyVolume)))"
            } else {
                dupVerdict = "neither overwrite pattern matched: dup \(fmt(dupVolume)), first \(fmt(firstOnlyVolume)), last \(fmt(lastOnlyVolume))"
            }
            let outOfRange = box.blendedEdges([(0, 2.0), (99_999, 2.0)])
            let compoundOutOfRange: Shape? = {
                var pairs = (0..<compound.edgeCount).map { ($0, 1.0) }
                pairs.append((99_999, 1.0))
                return compound.blendedEdges(pairs)
            }()
            let declined = shell.blendedEdges(shellEdgeIndices.map { ($0, 1.0) })
            record("fillet-edges (per-edge radius)", "blendedEdges(_:)",
                   duplicate: dupVerdict,
                   outOfRange: outOfRange == nil ? "REJECT (nil)" : "measured non-nil",
                   declined: declined != nil ? "SKIP (non-nil, area \(fmt(declined?.surfaceArea)) vs unfilleted \(fmt(shellPlainArea))) -- #633 fixed: blendedEdgesWithReport(_:) sibling also reports declinedEdgeIndices, adopting #639's mechanism" : "REJECT (nil)",
                   empty: box.blendedEdges([]) == nil ? "REJECT (nil)" : "non-nil",
                   note: "compound out-of-range: \(compoundOutOfRange == nil ? "REJECT (nil), matches single-solid" : "non-nil")")
        }

        // MARK: - filletedVariable(edgeIndex:radiusProfile:)  [single edge]

        do {
            let outOfRange = box.filletedVariable(edgeIndex: 99_999, radiusProfile: [(0.0, 1.0), (1.0, 2.0)])
            let emptyProfile = box.filletedVariable(edgeIndex: 0, radiusProfile: [])
            let onePointProfile = box.filletedVariable(edgeIndex: 0, radiusProfile: [(0.0, 1.0)])
            let declinedIndex = declinedShellEdges.first
            let declinedResult = declinedIndex.flatMap { shell.filletedVariable(edgeIndex: $0, radiusProfile: [(0.0, 1.0), (1.0, 2.0)]) }
            record("fillet-variable", "filletedVariable(edgeIndex:radiusProfile:)",
                   duplicate: "N/A: scalar edgeIndex, no list to duplicate",
                   outOfRange: outOfRange == nil ? "REJECT (nil)" : "measured non-nil",
                   declined: declinedIndex == nil ? "no declined edge found to probe" : (declinedResult == nil ? "REJECT (nil): single edge, no partial fillet possible" : "measured non-nil"),
                   empty: "N/A: no list; radiusProfile itself needs >=2 points (empty: \(emptyProfile == nil ? "REJECT" : "non-nil"), 1 point: \(onePointProfile == nil ? "REJECT" : "non-nil") -- stricter than filletEvolving's >=1)")
        }

        // MARK: - filletEvolving(_:)  [multi-edge, per-edge law] -- #612/#639's own site

        do {
            let e0 = box.edges()[0]
            let dupVolume = box.filletEvolving([
                EvolvingFilletEdge(edge: e0, radiusPoints: [(0.0, 2.0), (1.0, 2.0)]),
                EvolvingFilletEdge(edge: e0, radiusPoints: [(0.0, 5.0), (1.0, 5.0)]),
            ])?.volume
            let lastOnlyVolume = box.filletEvolving([
                EvolvingFilletEdge(edge: e0, radiusPoints: [(0.0, 5.0), (1.0, 5.0)]),
            ])?.volume
            let firstOnlyVolume = box.filletEvolving([
                EvolvingFilletEdge(edge: e0, radiusPoints: [(0.0, 2.0), (1.0, 2.0)]),
            ])?.volume
            let dupVerdict: String
            if volumesAgree(dupVolume, lastOnlyVolume) && !volumesAgree(dupVolume, firstOnlyVolume) {
                dupVerdict = "OVERWRITE: last law wins (dup \(fmt(dupVolume)) == last-only \(fmt(lastOnlyVolume))), documented on EvolvingFilletEdge; same mechanism as #633"
            } else {
                dupVerdict = "dup \(fmt(dupVolume)), first-only \(fmt(firstOnlyVolume)), last-only \(fmt(lastOnlyVolume))"
            }
            var outOfRangeSpec = EvolvingFilletEdge(edge: e0, radiusPoints: [(0.0, 1.0), (1.0, 2.0)])
            outOfRangeSpec.edgeIndex = 99_999
            let outOfRange = box.filletEvolving([outOfRangeSpec])
            let declined = shell.filletEvolving(shell.edges().map {
                EvolvingFilletEdge(edge: $0, radiusPoints: [(0.0, 1.0), (1.0, 1.0)])
            })
            record("fillet-evolving", "filletEvolving(_:)",
                   duplicate: dupVerdict,
                   outOfRange: outOfRange == nil ? "REJECT (nil)" : "measured non-nil",
                   declined: declined != nil ? "SKIP (non-nil, area \(fmt(declined?.surfaceArea)) vs unfilleted \(fmt(shellPlainArea))) -- #639 fixed: filletEvolvingWithReport(_:) now reports declinedEdgeIndices" : "REJECT (nil)",
                   empty: box.filletEvolving([]) == nil ? "REJECT (nil)" : "non-nil")
        }

        // MARK: - filletedWithFullHistory(radius:edges:)  [uniform radius + history]

        do {
            let both = box.filletedWithFullHistory(radius: 1.0, edges: [0, 1])?.result.volume
            let one = box.filletedWithFullHistory(radius: 1.0, edges: [0])?.result.volume
            let dup = box.filletedWithFullHistory(radius: 1.0, edges: [0, 0])?.result.volume
            let outOfRange = box.filletedWithFullHistory(radius: 1.0, edges: [0, 99_999])
            let declined = shell.filletedWithFullHistory(radius: 1.0, edges: shellEdgeIndices)?.result
            record("fillet-edges (with history)", "filletedWithFullHistory(radius:edges:)",
                   duplicate: volumesAgree(dup, one) ? "N/A: uniform radius (dup \(fmt(dup)) == single-edge \(fmt(one)), both bigger than two-distinct-edges \(fmt(both)) -- fewer edges removed means less material gone)" : "differs (dup \(fmt(dup)) vs single \(fmt(one)))",
                   outOfRange: outOfRange == nil ? "REJECT (nil)" : "measured non-nil",
                   declined: declined != nil ? "SKIP (non-nil, area \(fmt(declined?.surfaceArea)) vs unfilleted \(fmt(shellPlainArea))) -- #639: needed no new API, history.record(of:)'s !isDeleted && generated.isEmpty already names the declined set" : "REJECT (nil)",
                   empty: box.filletedWithFullHistory(radius: 1.0, edges: []) == nil ? "REJECT (nil)" : "non-nil")
        }

        // MARK: - filletedWithFullHistory(edge:startRadius:endRadius:)  [single edge + history]

        do {
            let outOfRange = box.filletedWithFullHistory(edge: 99_999, startRadius: 1.0, endRadius: 2.0)
            let declinedIndex = declinedShellEdges.first
            let declinedResult = declinedIndex.flatMap { shell.filletedWithFullHistory(edge: $0, startRadius: 1.0, endRadius: 1.0) }
            record("fillet-variable (with history)", "filletedWithFullHistory(edge:startRadius:endRadius:)",
                   duplicate: "N/A: scalar edge index, no list to duplicate",
                   outOfRange: outOfRange == nil ? "REJECT (nil)" : "measured non-nil",
                   declined: declinedIndex == nil ? "no declined edge found to probe" : (declinedResult == nil ? "REJECT (nil): single edge, no partial fillet possible" : "measured non-nil"),
                   empty: "N/A: no list")
        }

        // MARK: - biTgteBlend(edgeIndices:radius:)  [multi-edge, uniform radius, BiTgte_Blend]

        do {
            let single = box.biTgteBlend(edgeIndices: [0], radius: 1.0)?.volume
            let dup = box.biTgteBlend(edgeIndices: [0, 0], radius: 1.0)?.volume
            let outOfRange = box.biTgteBlend(edgeIndices: [0, 99_999], radius: 1.0)
            let baseline = box.volume
            let convexResult = box.biTgteBlend(edgeIndices: [0], radius: 1.0)
            // A plain box's edges are all convex; BiTgte_Blend structurally cannot decline one for
            // "no adjacent solid material" the way a free-boundary edge declines a regular fillet,
            // so there is no direct open-shell analogue here. What IS measured: a convex edge is
            // accepted (non-nil) but changes nothing, which is BiTgte_Blend's own way of silently
            // doing nothing to an edge it has no concave feature to key off -- structurally
            // parallel to "declined", not identical to it. See Issue613IndexContractTests for the
            // concave-edge fixture (lBracket) that DOES change volume when targeted.
            let noOpMeasured = convexResult?.volume.map { abs($0 - (baseline ?? -1)) < 1e-6 } ?? false
            record("blend (BiTgte_Blend)", "biTgteBlend(edgeIndices:radius:)",
                   duplicate: volumesAgree(dup, single) ? "N/A: uniform radius over a set (BiTgte_Blend keys edges into an IndexedMap; dup vol \(fmt(dup)) == single \(fmt(single)))" : "differs (dup \(fmt(dup)) vs single \(fmt(single)))",
                   outOfRange: outOfRange == nil ? "REJECT (nil), fixed by #613" : "measured non-nil",
                   declined: noOpMeasured ? "NO-OP on a convex edge (non-nil, volume unchanged: \(fmt(convexResult?.volume)) == baseline \(fmt(baseline))); not a skip-from-a-batch, a per-edge no-op -- see note" : "convex-edge probe did not reproduce the no-op; see Issue613 lBracket fixture instead",
                   empty: box.biTgteBlend(edgeIndices: [], radius: 1.0) == nil ? "REJECT (nil)" : "non-nil",
                   note: "no free-boundary analogue on a solid box; concave-edge behavior already covered by Issue613IndexContractTests.biTgteBlendTargetsTheEnumeratedEdge")
        }

        // MARK: - chamferedTwoDistances(_:)  [edge+face pairs, per-entry dist1/dist2]

        chamferTwoDistances: do {
            guard let face0 = ClusterBFixture.adjacentFaceIndex(forEdge: 0, in: box) else {
                print("Cluster B census: could not find a face adjacent to box edge 0, "
                      + "skipping the chamfer (two distances) row.")
                break chamferTwoDistances
            }
            let dup = box.chamferedTwoDistances([
                (edgeIndex: 0, faceIndex: face0, dist1: 1.0, dist2: 1.0),
                (edgeIndex: 0, faceIndex: face0, dist1: 2.0, dist2: 2.0),
            ])?.volume
            let lastOnly = box.chamferedTwoDistances([(edgeIndex: 0, faceIndex: face0, dist1: 2.0, dist2: 2.0)])?.volume
            let firstOnly = box.chamferedTwoDistances([(edgeIndex: 0, faceIndex: face0, dist1: 1.0, dist2: 1.0)])?.volume
            let dupVerdict: String
            if volumesAgree(dup, lastOnly) && !volumesAgree(dup, firstOnly) {
                dupVerdict = "OVERWRITE: last distance wins (dup \(fmt(dup)) == last-only \(fmt(lastOnly))) -- same mechanism as #633"
            } else if volumesAgree(dup, firstOnly) && !volumesAgree(dup, lastOnly) {
                dupVerdict = "FIRST WINS (dup \(fmt(dup)) == first-only \(fmt(firstOnly)), != last-only \(fmt(lastOnly))) -- the OPPOSITE of #633's last-wins overwrite; a different untested sibling, not the same mechanism"
            } else {
                dupVerdict = "neither first- nor last-wins matched: dup \(fmt(dup)), first-only \(fmt(firstOnly)), last-only \(fmt(lastOnly))"
            }
            let outOfRange = box.chamferedTwoDistances([(edgeIndex: 0, faceIndex: face0, dist1: 1.0, dist2: 1.0),
                                                          (edgeIndex: 99_999, faceIndex: face0, dist1: 1.0, dist2: 1.0)])
            let declinedIndex = declinedShellEdges.first
            let declinedFace = declinedIndex.flatMap { ClusterBFixture.adjacentFaceIndex(forEdge: $0, in: shell) }
            let declinedResult: Shape? = {
                guard let edgeIdx = declinedIndex, let faceIdx = declinedFace else { return nil }
                return shell.chamferedTwoDistances([(edgeIndex: edgeIdx, faceIndex: faceIdx, dist1: 0.3, dist2: 0.3)])
            }()
            let noValueValidation = box.chamferedTwoDistances([(edgeIndex: 0, faceIndex: face0, dist1: -5.0, dist2: -5.0)])
            record("chamfer (two distances)", "chamferedTwoDistances(_:)",
                   duplicate: dupVerdict,
                   outOfRange: outOfRange == nil ? "REJECT (nil)" : "measured non-nil",
                   declined: declinedIndex == nil ? "no declined edge found to probe"
                       : (declinedFace == nil ? "could not resolve an adjacent face for the declined edge"
                          : (declinedResult == nil ? "REJECT (nil): single-edge batch, whole call fails" : "SKIP (non-nil)")),
                   empty: box.chamferedTwoDistances([]) == nil ? "REJECT (nil)" : "non-nil",
                   note: "no per-element distance validation: dist1=dist2=-5.0 \(noValueValidation == nil ? "REJECTED anyway (OCCT's own Build() failed)" : "ACCEPTED (non-nil) -- unlike the fillet family's occtValidFilletRadius, nothing here checks sign")")
        }

        // MARK: - chamferedDistAngle(_:)  [edge+face pairs, per-entry distance/angle]

        chamferDistAngle: do {
            guard let face0 = ClusterBFixture.adjacentFaceIndex(forEdge: 0, in: box) else {
                print("Cluster B census: could not find a face adjacent to box edge 0, "
                      + "skipping the chamfer (distance-angle) row.")
                break chamferDistAngle
            }
            let dup = box.chamferedDistAngle([
                (edgeIndex: 0, faceIndex: face0, distance: 1.0, angleDegrees: 30.0),
                (edgeIndex: 0, faceIndex: face0, distance: 1.0, angleDegrees: 60.0),
            ])?.volume
            let lastOnly = box.chamferedDistAngle([(edgeIndex: 0, faceIndex: face0, distance: 1.0, angleDegrees: 60.0)])?.volume
            let firstOnly = box.chamferedDistAngle([(edgeIndex: 0, faceIndex: face0, distance: 1.0, angleDegrees: 30.0)])?.volume
            let dupVerdict: String
            if volumesAgree(dup, lastOnly) && !volumesAgree(dup, firstOnly) {
                dupVerdict = "OVERWRITE: last angle wins (dup \(fmt(dup)) == last-only \(fmt(lastOnly))) -- same mechanism as #633"
            } else if volumesAgree(dup, firstOnly) && !volumesAgree(dup, lastOnly) {
                dupVerdict = "FIRST WINS (dup \(fmt(dup)) == first-only \(fmt(firstOnly)), != last-only \(fmt(lastOnly))) -- matches chamferedTwoDistances' first-wins, the OPPOSITE of #633"
            } else {
                dupVerdict = "neither first- nor last-wins matched: dup \(fmt(dup)), first-only \(fmt(firstOnly)), last-only \(fmt(lastOnly))"
            }
            let outOfRange = box.chamferedDistAngle([(edgeIndex: 0, faceIndex: face0, distance: 1.0, angleDegrees: 45.0),
                                                       (edgeIndex: 99_999, faceIndex: face0, distance: 1.0, angleDegrees: 45.0)])
            let declinedIndex = declinedShellEdges.first
            let declinedFace = declinedIndex.flatMap { ClusterBFixture.adjacentFaceIndex(forEdge: $0, in: shell) }
            let declinedResult: Shape? = {
                guard let edgeIdx = declinedIndex, let faceIdx = declinedFace else { return nil }
                return shell.chamferedDistAngle([(edgeIndex: edgeIdx, faceIndex: faceIdx, distance: 0.3, angleDegrees: 45.0)])
            }()
            record("chamfer (distance-angle)", "chamferedDistAngle(_:)",
                   duplicate: dupVerdict,
                   outOfRange: outOfRange == nil ? "REJECT (nil)" : "measured non-nil",
                   declined: declinedIndex == nil ? "no declined edge found to probe"
                       : (declinedFace == nil ? "could not resolve an adjacent face for the declined edge"
                          : (declinedResult == nil ? "REJECT (nil): single-edge batch, whole call fails" : "SKIP (non-nil)")),
                   empty: box.chamferedDistAngle([]) == nil ? "REJECT (nil)" : "non-nil")
        }

        // MARK: - chamferedWithFullHistory(distance:edges:)  [uniform distance + history]

        do {
            let both = box.chamferedWithFullHistory(distance: 1.0, edges: [0, 1])?.result.volume
            let one = box.chamferedWithFullHistory(distance: 1.0, edges: [0])?.result.volume
            let dup = box.chamferedWithFullHistory(distance: 1.0, edges: [0, 0])?.result.volume
            let outOfRange = box.chamferedWithFullHistory(distance: 1.0, edges: [0, 99_999])
            let declined = shell.chamferedWithFullHistory(distance: 0.5, edges: shellEdgeIndices)?.result
            record("chamfer (with history)", "chamferedWithFullHistory(distance:edges:)",
                   duplicate: volumesAgree(dup, one) ? "N/A: uniform distance (dup \(fmt(dup)) == single-edge \(fmt(one)), both bigger than two-distinct-edges \(fmt(both)))" : "differs (dup \(fmt(dup)) vs single \(fmt(one)))",
                   outOfRange: outOfRange == nil ? "REJECT (nil)" : "measured non-nil",
                   declined: declined != nil ? "SKIP (non-nil, area \(fmt(declined?.surfaceArea)) vs unfilleted \(fmt(shellPlainArea)))" : "REJECT (nil)",
                   empty: box.chamferedWithFullHistory(distance: 1.0, edges: []) == nil ? "REJECT (nil)" : "non-nil")
        }

        // MARK: - offsetPerFace(defaultOffset:faceOffsets:)  [face family, #568's idiom outside fillet]

        do {
            // A Dictionary key is unique by construction: [Int: Double] cannot express "the same
            // face index twice with two different offsets" the way every edge-list sibling's Array
            // can. The duplicate axis is not skipped here for lack of measurement, but because the
            // Swift type system already forecloses it.
            let outOfRange = box.offsetPerFace(defaultOffset: 0.5, faceOffsets: [99_999: 1.0])
            let emptyDict = box.offsetPerFace(defaultOffset: 0.5, faceOffsets: [:])
            record("offset-per-face", "offsetPerFace(defaultOffset:faceOffsets:)",
                   duplicate: "N/A: faceOffsets is a Dictionary, a duplicate key cannot be constructed",
                   outOfRange: outOfRange == nil ? "REJECT (nil), fixed by #541 per the bridge's own comment (was: skip, offset by default everywhere) -- #568's own table lists this site as still skipping, so #541 must have landed after #568 was filed; see README" : "measured non-nil",
                   declined: "N/A: BRepOffset_MakeOffset has no per-face decline analogous to Add() on a free-boundary edge; not measured further",
                   empty: emptyDict != nil ? "ACCEPTS (non-nil): applies defaultOffset uniformly, a legitimate no-override request" : "REJECT (nil)")
        }

        // MARK: - fillet2D(vertexIndices:radii:)  [2D, face-level, batch]

        do {
            let dup = rectFace.fillet2D(vertexIndices: [0, 0], radii: [1.0, 2.0])?.volume
            let lastOnly = rectFace.fillet2D(vertexIndices: [0], radii: [2.0])?.volume
            let firstOnly = rectFace.fillet2D(vertexIndices: [0], radii: [1.0])?.volume
            let dupVerdict: String
            if volumesAgree(dup, lastOnly) && !volumesAgree(dup, firstOnly) {
                dupVerdict = "OVERWRITE: last radius wins (dup \(fmt(dup)) == last-only \(fmt(lastOnly)))"
            } else if dup == nil {
                dupVerdict = "REJECT (nil) on a duplicated vertex index"
            } else {
                dupVerdict = "dup \(fmt(dup)), first-only \(fmt(firstOnly)), last-only \(fmt(lastOnly))"
            }
            let outOfRange = rectFace.fillet2D(vertexIndices: [0, 99_999], radii: [1.0, 1.0])
            record("2D fillet (face)", "fillet2D(vertexIndices:radii:)",
                   duplicate: dupVerdict,
                   outOfRange: outOfRange == nil ? "REJECT (nil), fixed by #568" : "measured non-nil",
                   declined: "UNMEASURED: no open/degenerate planar-face fixture built for this census; ChFi2d_Builder's own decline conditions are a separate investigation",
                   empty: rectFace.fillet2D(vertexIndices: [], radii: []) == nil ? "REJECT (nil), Swift-side guard before the bridge is reached" : "non-nil")
        }

        // MARK: - chamfer2D(edgePairs:distances:)  [2D, face-level, batch]

        do {
            // #705: this used to be UNSAFE to call live. A duplicated edge pair, e.g.
            // [(0,1),(0,1)], SIGSEGV'd (uncatchable -- an OS signal) inside the repeat call's own
            // BRepFilletAPI_MakeFillet2d::AddChamfer, which rebuilds the face incrementally, so a
            // second call naming the same pair resolved against edge handles the first call had
            // already made stale. Fixed in OCCTFace2DChamfer (OCCTBridge_Modeling.mm) by rejecting
            // the whole call when any two entries name the same pair, in either order, before
            // AddChamfer ever sees the second one -- matching fillet2D's own contract for a
            // duplicated vertex on this same builder (#568). Reusing ONE edge across two
            // DIFFERENT pairs (chamfering adjacent corners of a polygon) is unaffected and still
            // measured non-nil below; only the identical pair repeated is refused. Now run live.
            let dup = rectFace.chamfer2D(edgePairs: [(0, 1), (0, 1)], distances: [1.0, 2.0])
            let reversedDup = rectFace.chamfer2D(edgePairs: [(0, 1), (1, 0)], distances: [1.0, 2.0])
            let sharedEdgeDifferentPairs = rectFace.chamfer2D(
                edgePairs: [(0, 1), (1, 2)], distances: [1.0, 1.0])
            let dupVerdict: String
            if dup == nil && reversedDup == nil && sharedEdgeDifferentPairs != nil {
                dupVerdict = "REJECT (nil) on a duplicated edge pair, order-independent (fixed by #705, was CRASH: SIGSEGV, uncatchable); one edge across two DIFFERENT pairs stays non-nil"
            } else {
                dupVerdict = "unexpected: dup \(dup == nil ? "nil" : "non-nil"), reversedDup \(reversedDup == nil ? "nil" : "non-nil"), sharedEdgeDifferentPairs \(sharedEdgeDifferentPairs == nil ? "nil" : "non-nil")"
            }
            let outOfRange = rectFace.chamfer2D(edgePairs: [(0, 1), (2, 99_999)], distances: [1.0, 1.0])
            record("2D chamfer (face)", "chamfer2D(edgePairs:distances:)",
                   duplicate: dupVerdict,
                   outOfRange: outOfRange == nil ? "REJECT (nil), fixed by #568" : "measured non-nil",
                   declined: "UNMEASURED: same reason as fillet2D above",
                   empty: rectFace.chamfer2D(edgePairs: [], distances: []) == nil ? "REJECT (nil), Swift-side guard before the bridge is reached" : "non-nil")
        }

        // MARK: - FilletBuilder class API  [takes Edge objects directly, not indices]

        filletClassAPI: do {
            guard let builderDup = FilletBuilder(shape: box), let builderLast = FilletBuilder(shape: box),
                  let builderFirst = FilletBuilder(shape: box),
                  let builderForeign = FilletBuilder(shape: box), let builderEmpty = FilletBuilder(shape: box),
                  let foreignShape = Shape.box(width: 20, height: 20, depth: 20) else {
                print("Cluster B census: could not build the FilletBuilder fixtures, "
                      + "skipping the fillet (class API) row.")
                break filletClassAPI
            }
            let e0 = box.edges()[0]
            builderDup.addEdge(e0, radius: 2.0)
            builderDup.addEdge(e0, radius: 5.0)
            let dupVolume = builderDup.build()?.volume
            builderLast.addEdge(e0, radius: 5.0)
            let lastVolume = builderLast.build()?.volume
            builderFirst.addEdge(e0, radius: 2.0)
            let firstVolume = builderFirst.build()?.volume
            let dupVerdict: String
            if volumesAgree(dupVolume, lastVolume) && !volumesAgree(dupVolume, firstVolume) {
                dupVerdict = "OVERWRITE: last radius wins (dup \(fmt(dupVolume)) == last-only \(fmt(lastVolume))), same mechanism as #633, unaudited by #489/#520/#568"
            } else if volumesAgree(dupVolume, firstVolume) && !volumesAgree(dupVolume, lastVolume) {
                dupVerdict = "FIRST WINS (dup \(fmt(dupVolume)) == first-only \(fmt(firstVolume)), != last-only \(fmt(lastVolume)))"
            } else {
                dupVerdict = "neither first- nor last-wins matched: dup \(fmt(dupVolume)), first-only \(fmt(firstVolume)), last-only \(fmt(lastVolume))"
            }

            let foreignEdge = foreignShape.edges()[0]
            let foreignAdded = builderForeign.addEdge(foreignEdge, radius: 2.0)
            // #639 correction: contour(for:) -- present in this class before #639, unrelated to
            // it -- already answers "did this added edge make it into a contour" for exactly this
            // foreign-edge case, the same Contour(E) == 0 signal it gives a same-shape edge OCCT
            // declines on geometric grounds. The original census note here ("no per-edge signal
            // beyond addEdge's own Bool return") never tried this query and was wrong.
            let foreignContour = builderForeign.contour(for: foreignEdge)
            let foreignBuiltVolume = builderForeign.build()?.volume
            let foreignNoOp = foreignBuiltVolume.map { abs($0 - (box.volume ?? -1)) < 1e-6 } ?? false

            let emptyResult = builderEmpty.build()

            record("fillet (class API)", "FilletBuilder.addEdge(_:radius:)",
                   duplicate: dupVerdict,
                   outOfRange: "N/A: takes an Edge object, not an index -- no out-of-range index to name",
                   declined: "foreign edge (belongs to a different Shape entirely): addEdge returned \(foreignAdded), contour(for:) == \(foreignContour), build() \(foreignBuiltVolume == nil ? "REJECT (nil)" : (foreignNoOp ? "NO-OP (non-nil, volume unchanged)" : "non-nil, volume changed"))",
                   empty: "build() with zero addEdge calls: \(emptyResult == nil ? "REJECT (nil)" : "non-nil")",
                   note: "no index resolution at all in this path: no occtUseSubShapesByIndex, no occtValidFilletRadius -- but contour(for:) == 0 already reports the decline per edge (#639 correction), readable right after addEdge with no build() required")
        }

        // MARK: - ChamferBuilder class API  [takes Edge objects directly, not indices]

        chamferClassAPI: do {
            guard let builderDup = ChamferBuilder(shape: box), let builderLast = ChamferBuilder(shape: box),
                  let builderFirst = ChamferBuilder(shape: box),
                  let builderForeign = ChamferBuilder(shape: box), let builderEmpty = ChamferBuilder(shape: box),
                  let foreignShape = Shape.box(width: 20, height: 20, depth: 20) else {
                print("Cluster B census: could not build the ChamferBuilder fixtures, "
                      + "skipping the chamfer (class API) row.")
                break chamferClassAPI
            }
            let e0 = box.edges()[0]
            builderDup.addEdge(e0, distance: 1.0)
            builderDup.addEdge(e0, distance: 2.0)
            let dupVolume = builderDup.build()?.volume
            builderLast.addEdge(e0, distance: 2.0)
            let lastVolume = builderLast.build()?.volume
            builderFirst.addEdge(e0, distance: 1.0)
            let firstVolume = builderFirst.build()?.volume
            let dupVerdict: String
            if volumesAgree(dupVolume, lastVolume) && !volumesAgree(dupVolume, firstVolume) {
                dupVerdict = "OVERWRITE: last distance wins (dup \(fmt(dupVolume)) == last-only \(fmt(lastVolume)))"
            } else if volumesAgree(dupVolume, firstVolume) && !volumesAgree(dupVolume, lastVolume) {
                dupVerdict = "FIRST WINS (dup \(fmt(dupVolume)) == first-only \(fmt(firstVolume)), != last-only \(fmt(lastVolume))), matches chamferedTwoDistances' first-wins above -- addEdge itself, not just the hand-rolled bridge loop, prefers the first call"
            } else {
                dupVerdict = "neither first- nor last-wins matched: dup \(fmt(dupVolume)), first-only \(fmt(firstVolume)), last-only \(fmt(lastVolume))"
            }

            let foreignEdge = foreignShape.edges()[0]
            let foreignAdded = builderForeign.addEdge(foreignEdge, distance: 1.0)
            let foreignBuiltVolume = builderForeign.build()?.volume
            let foreignNoOp = foreignBuiltVolume.map { abs($0 - (box.volume ?? -1)) < 1e-6 } ?? false

            let emptyResult = builderEmpty.build()

            record("chamfer (class API)", "ChamferBuilder.addEdge(_:distance:)",
                   duplicate: dupVerdict,
                   outOfRange: "N/A: takes an Edge object, not an index",
                   declined: "foreign edge: addEdge returned \(foreignAdded), build() \(foreignBuiltVolume == nil ? "REJECT (nil)" : (foreignNoOp ? "NO-OP (non-nil, volume unchanged)" : "non-nil, volume changed"))",
                   empty: "build() with zero addEdge calls: \(emptyResult == nil ? "REJECT (nil)" : "non-nil")")
        }

        // MARK: - Print the grid

        let header = ["family", "entry point", "duplicate index", "out-of-range index", "OCCT-declined index", "empty list", "note"]
        let widths = [28, 46, 60, 34, 60, 26, 70]

        func pad(_ s: String, _ width: Int) -> String {
            s.count >= width ? s : s + String(repeating: " ", count: width - s.count)
        }

        print(zip(header, widths).map { pad($0, $1) }.joined(separator: " | "))
        print(widths.map { String(repeating: "-", count: $0) }.joined(separator: "-|-"))
        for row in rows {
            let cells = [row.family, row.entryPoint, row.duplicateIndex, row.outOfRangeIndex,
                         row.occtDeclined, row.emptyList, row.note]
            print(zip(cells, widths).map { pad($0, $1) }.joined(separator: " | "))
        }

        print()
        print("fixtures:")
        print("  box:        Shape.box(width: 10, height: 10, depth: 10) -- 12 edges, 6 faces, all edges accepted")
        print("  compound:   SharedFixture.splitBoxCompound(order: .asSplit) -- reused from Cluster A, two solids")
        print("  shell:      box with one face dropped, sewn -- \(declinedShellEdges.count) of \(shellEdgeIndices.count) edges declined: \(declinedShellEdges), accepted: \(acceptedShellEdges)")
        print("  rectFace:   Shape.face(from: Wire.rectangle(width: 20, height: 20)) -- 4 vertices, 4 edges")
        print()
        print("row count: \(rows.count)")
    }
}
