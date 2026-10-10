// StressUnifySameDomainNullPCurveTests.swift
//
// Lifted out of `StressNullInvalidTests.swift` by #2928, because it is the only test in that file of
// 60 that reads a `.brep` fixture out of the source tree by `#filePath`, and the wasm suites cannot
// see the source tree unless `Scripts/wasm-test-node-runner.mjs` preopens it: it does, for the
// `Fixtures` directories only, at the same absolute host path `#filePath` bakes in (#3026), so this
// file runs on wasm like the other 59 tests in `StressNullInvalidTests.swift`.

import Foundation
import OCCTSwift
import Testing

@Suite("Stress: UnifySameDomainBuilder Null PCurve")
struct StressUnifySameDomainNullPCurveTests {

    // #348: ShapeUpgrade_UnifySameDomain::IntUnifyFaces (and its SplitWire helper) called
    // BRep_Tool::CurveOnSurface(...)->D1()/->Value() to disambiguate between multiple
    // candidate next-edges without checking whether the returned pcurve handle was null,
    // an edge with no pcurve on the current reference face (the common case for a raw
    // mesh-sewn solid) SIGSEGVs deterministically. Fixed in the kernel: carried as patch 0013,
    // retired at the OCCT 8.0.1 re-pin once it shipped upstream as OCCT#1392.
    @Test func unifySameDomainOnMeshSewnSolidWithMissingPCurve() throws {
        let fixtureURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/unify-crash-mmd-kiha10-body5.brep")
        let shape = try Shape.loadBREP(from: fixtureURL)
        let unifier = UnifySameDomainBuilder(shape: shape, unifyEdges: true, unifyFaces: true)
        unifier.setAngularTolerance(1.0 * .pi / 180)
        unifier.build()
        // Epic #766: the result used to be discarded. ShapeUpgrade_UnifySameDomain with the same
        // settings merges the fixture's 662 faces / 1072 edges into 228 / 627.
        let unified = try #require(unifier.shape)
        #expect(unified.subShapeCount(ofType: .face) == 228)
        #expect(unified.subShapeCount(ofType: .edge) == 627)
    }
}
