import Testing
import Foundation
@testable import OCCTSwift

// Issue #367: OCCTShapeFuseMulti (Shape.fuseAll(_:)) set builder.SetRunParallel(true)
// unconditionally. Concurrent top-level BRepAlgoAPI_BuilderAlgo::Build() calls each requesting
// internal parallelism submit work to the same process-wide OSD_ThreadPool::DefaultPool(), and
// worker threads end up processing data belonging to the wrong caller's operation -- not a rare
// race, but 100% reproducible data corruption under a pure-C++ TSan stress harness (400/400
// concurrent operations produced 27 faces instead of the correct 13; 237 TSan race reports
// across TopoDS_Builder::Add, TopExp_Explorer, BRep_Tool::Range, BOPTools_AlgoTools::MakeSplitEdge).
// Fixed by dropping SetRunParallel(true) entirely -- OCCT's safe serial default.
//
// Same honesty caveat as this project's other thread-safety regression suites: a missing-lock /
// wrong-parallelism-flag bug doesn't reliably reproduce as an observable Swift-level failure at
// modest concurrency without sanitizer instrumentation. The authoritative reproducer is
// Scripts/repro/342-boolean-ops/occt_342_boolean_stress.cpp (fuse_multi_parallel scenario),
// which DID reliably reproduce it (100% of runs) before the fix. This suite is a basic exerciser
// confirming the fixed code path still produces correct, consistent results under concurrency.
@Suite("Issue #367, Shape.fuseAll concurrent calls produce correct results (SetRunParallel removed)")
struct Issue367FuseMultiThreadSafetyTests {

    @Test("Concurrent fuseAll calls all match the single-threaded baseline face count")
    func concurrentFuseAllMatchesBaseline() async throws {
        let baselineBox = Shape.box(width: 10, height: 10, depth: 10)!
        let baselineSphere = Shape.sphere(center: SIMD3(5, 5, 5), radius: 6)!
        let baseline = try #require(Shape.fuseAll([baselineBox, baselineSphere]))
        let baselineFaceCount = baseline.subShapeCount(ofType: .face)

        struct Outcome: Sendable {
            var failures = 0
            var wrongFaceCounts = 0
        }

        let agg = await withTaskGroup(of: Outcome.self) { group -> Outcome in
            for _ in 0..<8 {
                group.addTask {
                    var o = Outcome()
                    for _ in 0..<50 {
                        let box = Shape.box(width: 10, height: 10, depth: 10)!
                        let sphere = Shape.sphere(center: SIMD3(5, 5, 5), radius: 6)!
                        guard let result = Shape.fuseAll([box, sphere]) else {
                            o.failures += 1
                            continue
                        }
                        if result.subShapeCount(ofType: .face) != baselineFaceCount {
                            o.wrongFaceCounts += 1
                        }
                    }
                    return o
                }
            }
            var total = Outcome()
            for await o in group {
                total.failures += o.failures
                total.wrongFaceCounts += o.wrongFaceCounts
            }
            return total
        }

        #expect(agg.failures == 0, "concurrent fuseAll calls failed (expected 0 of 400)")
        #expect(agg.wrongFaceCounts == 0,
                "concurrent fuseAll produced a face count diverging from the single-threaded baseline (\(baselineFaceCount)), the #367 corruption")
    }
}
