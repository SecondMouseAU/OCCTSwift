import Testing
import Foundation
import simd
@testable import OCCTSwift

// #622: the tail of #558's bound sweep. The same footgun, a caller-supplied number sizes a Swift
// allocation and is then cast to the `int32_t` the bridge takes its capacity in, on 21 entry
// points the sweep's stopping criterion never reached, because it scoped itself to *samplers* and
// these are result-buffer capacities on picking, searching, projection, intersection and listing.
//
// The review that filed #622 named four (`Shape.raycast`, two in `Document.swift`, one in
// `MedialAxis.swift`). Two of those four do not survive re-measurement: `MedialAxis.drawArc` was
// already bounded by #558 itself, and the two `Document.swift` line numbers land on unrelated
// code. So the named list was neither complete nor correct, exactly as #558's own lesson (census
// said 14, measurement said 28) predicted. Measurement is the only thing that settles it.
//
// Measured before the fix, one case per process (a trap takes the whole harness down, so each
// absurd input needs its own run) against `refactor/381-pass1b`. 18 of the 21 are cheap to drive
// from a standalone binary; all 18 failed at `Int32.max + 1`, 2 aborted immediately with "Fatal
// error: Not enough memory" and 16 ground past a 40-second timeout on an allocation nothing can
// serve. 12 of the 18 also aborted on `-1`, in `Array(repeating:count:)`, before any bound could
// be consulted. The remaining 3 (`Selector.pick`'s overloads) need a live selector and were
// converted on inspection; they are covered in-process below.
//
// These tests can run in-process precisely because the fix is what makes them able to: before it,
// every #expect below would have aborted the test harness rather than failing.
//
// Contract, unchanged from #558 rather than a fifth behaviour: all 21 of these are *capacities*
// (the algorithm decides how many results exist and the number only truncates), so they clamp into
// `0...Sampling.maximumSampleCount`, the caller gets the real answer, not an empty one. The one
// exception is `LogSample.sample(count:)`, whose bridge fills the buffer exactly; that is a
// *request*, so it rejects rather than silently returning a coarser sampling. Same split #558 drew
// between `Curve3D.drawAdaptive` and `MedialAxis.drawArc`.
//
// The emptiness assertions compare `.count == 0` rather than reading `.isEmpty`, for the reason
// #558 recorded: Swift Testing prints the captured sub-expression on failure, and a regression
// that returns 10 million results would print all 10 million of them.
@Suite("Issue #622: result-buffer capacities bound the count a caller can supply", .serialized)
struct Issue622AllocationBounds {

    // `Int32.max + 1`, the first count provably past the bridge's own count type.
    private static let pastInt32 = Int(Int32.max) + 1

    private func box() -> Shape { Shape.box(width: 10, height: 10, depth: 10)! }
    private func sphere() -> Shape { Shape.sphere(radius: 5)! }
    private func segment3D() -> Curve3D { Curve3D.segment(from: .zero, to: SIMD3(10, 0, 0))! }
    private func segment2D() -> Curve2D { Curve2D.segment(from: .zero, to: SIMD2(10, 0))! }
    private func plane() -> Surface { Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))! }
    private func tree() -> KDTree {
        KDTree(points: [SIMD3(0, 0, 0), SIMD3(1, 1, 1), SIMD3(2, 2, 2)])!
    }

    // MARK: - Shape.raycast, the entry point #622 was filed about

    @Test("Shape.raycast clamps maxHits instead of allocating ~880 GB and trapping")
    func raycastCapacity() {
        let b = box()
        let origin = SIMD3(0.0, 0, 20), direction = SIMD3(0.0, 0, -1)

        // A ray through a box crosses two faces however much room it is offered. That is the
        // point of clamping rather than rejecting: the absurd capacity returns the real answer.
        let baseline = b.raycast(origin: origin, direction: direction).count
        #expect(baseline > 0)
        #expect(b.raycast(origin: origin, direction: direction, maxHits: Self.pastInt32).count
                == baseline)

        // No capacity is not a small capacity: it returns the documented empty value.
        #expect(b.raycast(origin: origin, direction: direction, maxHits: 0).count == 0)
        #expect(b.raycast(origin: origin, direction: direction, maxHits: -1).count == 0)

        // raycastNearest hardcodes 100 and was never exposed, but must still work.
        #expect(b.raycastNearest(origin: origin, direction: direction) != nil)
    }

    // MARK: - Curve and surface capacities

    @Test("Curve3D extrema/intersection/split capacities clamp rather than trap")
    func curve3DCapacities() {
        let a = segment3D()
        // Deliberately skew rather than parallel. `GeomAPI_ExtremaCurveCurve` SIGSEGVs
        // (uncatchable) on two parallel lines at *any* capacity, measured here at maxCount 2, 20,
        // 100, 1e4, 1e6, 1e7 and Int32.max + 1, all EXIT -11, including the method's own default
        // of 20. That is the documented `BRepExtrema_ExtCC` parallel hazard on the
        // `GeomAPI_ExtremaCurveCurve` path, entirely independent of the count bound this suite is
        // about; a parallel fixture here would test the crash, not the bound.
        let b = Curve3D.segment(from: SIMD3(5, -5, 1), to: SIMD3(5, 5, 1))!
        #expect(a.extrema(with: b, maxCount: Self.pastInt32).count
                == a.extrema(with: b).count)
        #expect(a.extrema(with: b, maxCount: 0).count == 0)
        #expect(a.extrema(with: b, maxCount: -1).count == 0)

        let through = Curve3D.segment(from: SIMD3(0, 0, -20), to: SIMD3(0, 0, 20))!
        let p = plane()
        #expect(through.intersections(with: p, maxHits: Self.pastInt32).count
                == through.intersections(with: p).count)
        #expect(through.intersections(with: p, maxHits: 0).count == 0)
        #expect(through.intersections(with: p, maxHits: -1).count == 0)

        #expect(a.splitAtContinuity(maxSegments: Self.pastInt32).count
                == a.splitAtContinuity().count)
        #expect(a.splitAtContinuity(maxSegments: 0).count == 0)
        #expect(a.splitAtContinuity(maxSegments: -1).count == 0)
    }

    @Test("Curve2D.splitAtContinuity clamps maxSegments rather than trapping")
    func curve2DSplitCapacity() {
        let c = segment2D()
        #expect(c.splitAtContinuity(maxSegments: Self.pastInt32).count
                == c.splitAtContinuity().count)
        #expect(c.splitAtContinuity(maxSegments: 0).count == 0)
        #expect(c.splitAtContinuity(maxSegments: -1).count == 0)
    }

    @Test("Surface.intersections clamps maxCurves rather than trapping")
    func surfaceIntersectionCapacity() {
        let a = plane()
        let b = Surface.plane(origin: .zero, normal: SIMD3(0, 1, 0))!
        #expect(a.intersections(with: b, maxCurves: Self.pastInt32).count
                == a.intersections(with: b).count)
        #expect(a.intersections(with: b, maxCurves: 0).count == 0)
        #expect(a.intersections(with: b, maxCurves: -1).count == 0)
    }

    @Test("point projection capacities clamp rather than trap")
    func projectionCapacities() {
        let c = segment3D()
        let q = SIMD3(5.0, 5, 0)
        #expect(c.projectPointAll(q, maxResults: Self.pastInt32).count
                == c.projectPointAll(q).count)
        #expect(c.projectPointAll(q, maxResults: 0).count == 0)
        #expect(c.projectPointAll(q, maxResults: -1).count == 0)

        let s = plane()
        let r = SIMD3(1.0, 1, 5)
        #expect(s.projectPointAll(r, maxResults: Self.pastInt32).count
                == s.projectPointAll(r).count)
        #expect(s.projectPointAll(r, maxResults: 0).count == 0)
        #expect(s.projectPointAll(r, maxResults: -1).count == 0)
    }

    // MARK: - Shape capacities

    @Test("Shape.allDistanceSolutions clamps maxSolutions rather than trapping")
    func allDistanceSolutionsCapacity() {
        let b = box(), s = sphere()
        #expect(b.allDistanceSolutions(to: s, maxSolutions: Self.pastInt32)?.count
                == b.allDistanceSolutions(to: s)?.count)
        // Behaviour change, asserted deliberately rather than incidentally: no capacity now yields
        // an empty array, where before #622 the bridge's -1 for `maxSolutions <= 0` came back
        // through `guard count >= 0` as `nil`, "the measurement failed" for what is really "no
        // room was offered". `nil` is now reserved for an actual failure.
        #expect(b.allDistanceSolutions(to: s, maxSolutions: 0) != nil)
        #expect(b.allDistanceSolutions(to: s, maxSolutions: 0)?.count == 0)
        #expect(b.allDistanceSolutions(to: s, maxSolutions: -1) != nil)
        #expect(b.allDistanceSolutions(to: s, maxSolutions: -1)?.count == 0)
    }

    @Test("Shape.selfIntersectionPairs clamps maxPairs rather than trapping")
    func selfIntersectionPairsCapacity() {
        let b = box()
        #expect(b.selfIntersectionPairs(maxPairs: Self.pastInt32).count
                == b.selfIntersectionPairs().count)
        #expect(b.selfIntersectionPairs(maxPairs: 0).count == 0)
        #expect(b.selfIntersectionPairs(maxPairs: -1).count == 0)
    }

    // MARK: - Spatial search capacities

    @Test("KDTree search capacities clamp rather than trap")
    func kdTreeCapacities() {
        let t = tree()
        #expect(t.kNearest(to: .zero, k: 3).count == 3)
        #expect(t.kNearest(to: .zero, k: Self.pastInt32).count == 3)
        #expect(t.kNearest(to: .zero, k: 0).count == 0)
        #expect(t.kNearest(to: .zero, k: -1).count == 0)

        let base = t.rangeSearch(center: .zero, radius: 10).count
        #expect(t.rangeSearch(center: .zero, radius: 10, maxResults: Self.pastInt32).count == base)
        #expect(t.rangeSearch(center: .zero, radius: 10, maxResults: 0).count == 0)
        #expect(t.rangeSearch(center: .zero, radius: 10, maxResults: -1).count == 0)

        let lo = SIMD3(-9.0, -9, -9), hi = SIMD3(9.0, 9, 9)
        let boxBase = t.boxSearch(min: lo, max: hi).count
        #expect(t.boxSearch(min: lo, max: hi, maxResults: Self.pastInt32).count == boxBase)
        #expect(t.boxSearch(min: lo, max: hi, maxResults: 0).count == 0)
        #expect(t.boxSearch(min: lo, max: hi, maxResults: -1).count == 0)
    }

    @Test("all three Selector.pick overloads clamp maxResults rather than trapping")
    func selectorPickCapacities() {
        let selector = Selector()
        selector.add(shape: box(), id: 1)
        let camera = Camera()
        let viewSize = SIMD2(800.0, 600.0)
        let pixel = SIMD2(400.0, 300.0)
        let rect = (min: SIMD2(0.0, 0.0), max: SIMD2(800.0, 600.0))
        let poly: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(800, 0), SIMD2(800, 600), SIMD2(0, 600)]

        // The contract under test is that an absurd capacity returns rather than aborting the
        // process; whether this headless selector resolves a hit is not what is being asserted.
        let atBase = selector.pick(at: pixel, camera: camera, viewSize: viewSize).count
        #expect(selector.pick(at: pixel, camera: camera, viewSize: viewSize,
                              maxResults: Self.pastInt32).count == atBase)
        #expect(selector.pick(at: pixel, camera: camera, viewSize: viewSize, maxResults: 0).count == 0)
        #expect(selector.pick(at: pixel, camera: camera, viewSize: viewSize, maxResults: -1).count == 0)

        let rectBase = selector.pick(rect: rect, camera: camera, viewSize: viewSize).count
        #expect(selector.pick(rect: rect, camera: camera, viewSize: viewSize,
                              maxResults: Self.pastInt32).count == rectBase)
        #expect(selector.pick(rect: rect, camera: camera, viewSize: viewSize, maxResults: 0).count == 0)
        #expect(selector.pick(rect: rect, camera: camera, viewSize: viewSize, maxResults: -1).count == 0)

        let polyBase = selector.pick(polygon: poly, camera: camera, viewSize: viewSize).count
        #expect(selector.pick(polygon: poly, camera: camera, viewSize: viewSize,
                              maxResults: Self.pastInt32).count == polyBase)
        #expect(selector.pick(polygon: poly, camera: camera, viewSize: viewSize, maxResults: 0).count == 0)
        #expect(selector.pick(polygon: poly, camera: camera, viewSize: viewSize, maxResults: -1).count == 0)
    }

    // MARK: - Drawing / text / filesystem capacities

    @Test("HatchPattern.generate clamps maxSegments rather than trapping")
    func hatchCapacity() {
        let boundary: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10)]
        let d = SIMD2(1.0, 0.0)
        let base = HatchPattern.generate(boundary: boundary, direction: d, spacing: 1).count
        #expect(base > 0)
        #expect(HatchPattern.generate(boundary: boundary, direction: d, spacing: 1,
                                      maxSegments: Self.pastInt32).count == base)
        #expect(HatchPattern.generate(boundary: boundary, direction: d, spacing: 1,
                                      maxSegments: 0).count == 0)
        #expect(HatchPattern.generate(boundary: boundary, direction: d, spacing: 1,
                                      maxSegments: -1).count == 0)
    }

    @Test("UnicodeUtils.convertFromUnicode clamps its output buffer rather than trapping")
    func unicodeCapacity() {
        #expect(UnicodeUtils.convertFromUnicode("hello", maxSize: Self.pastInt32)
                == UnicodeUtils.convertFromUnicode("hello"))
        // A zero-byte output buffer cannot hold even the terminator, so it reports failure.
        #expect(UnicodeUtils.convertFromUnicode("hello", maxSize: 0) == nil)
        #expect(UnicodeUtils.convertFromUnicode("hello", maxSize: -1) == nil)
    }

    @Test("directory and file listing clamp maxCount rather than trapping")
    func listingCapacities() {
        // A directory this test does not own cannot be assumed to hold a fixed number of entries,
        // so the clamp is asserted against a baseline taken in the same call sequence rather than
        // against a literal. An earlier version compared only `>= aSmallCapacityCount`, which both
        // sides satisfy when the directory is empty, that asserted the absence of a trap and
        // nothing about the clamp.
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("occt622-listing-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        for i in 0..<7 {
            FileManager.default.createFile(atPath: dir.appendingPathComponent("f\(i).txt").path,
                                           contents: Data("x".utf8))
        }
        let path = dir.path

        // 7 files in a directory of our own: the clamped capacity returns all of them, exactly as
        // a generous-but-servable capacity does.
        let fileBaseline = FileIterator.list(path: path, maxCount: 1000).count
        #expect(fileBaseline == 7)
        #expect(FileIterator.list(path: path, maxCount: Self.pastInt32).count == fileBaseline)
        #expect(FileIterator.list(path: path, maxCount: 3).count == 3)      // a real capacity truncates
        #expect(FileIterator.list(path: path, maxCount: 0).count == 0)
        #expect(FileIterator.list(path: path, maxCount: -1).count == 0)

        let dirBaseline = DirectoryIterator.list(path: path, maxCount: 1000).count
        #expect(DirectoryIterator.list(path: path, maxCount: Self.pastInt32).count == dirBaseline)
        #expect(DirectoryIterator.list(path: path, maxCount: 0).count == 0)
        #expect(DirectoryIterator.list(path: path, maxCount: -1).count == 0)
    }

    // MARK: - The one request in the set

    @Test("LogSample.sample fills its buffer exactly, so its count is a request, not a capacity")
    func logSampleIsARequest() {
        // Exactly the requested count, which is what makes clamping the wrong answer here: a
        // clamped 10-billion request would hand back 10 million values and call it success.
        #expect(LogSample.sample(from: 1, to: 100, count: 16).count == 16)
        #expect(LogSample.sample(from: 1, to: 100, count: 1).count == 1)
        for n in [-1, 0, Sampling.maximumSampleCount + 1, Self.pastInt32, Int.max] {
            #expect(LogSample.sample(from: 1, to: 100, count: n).count == 0, "sample(\(n))")
        }
    }
}
