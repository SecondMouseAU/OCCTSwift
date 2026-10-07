import Foundation
import Testing
import simd

@testable import OCCTSwift

// Issue #3097: a direct concurrent `Shape.filleted` test.
//
// `Issue298FilletThreadSafetyTests` reached the fillet only through
// `SheetMetal.Builder.build`; once concave bends stopped calling `Shape.filleted`
// (#3096) that suite no longer exercised the fillet path at all. This suite calls
// `Shape.filleted(radius:)` directly on the result of a boolean, which is the
// input that reaches OCCT's legacy `TopOpeBRepBuild` solid reconstruction
// (`ChFi3d_Builder::Compute` -> `SplitSolid` -> `FillSolid`) and the blend
// solver scratch, the state #298 found to be process-global.
//
// What guards that state is not a bridge lock. `occtFilletMutex` was removed in
// v1.12.3; the protection is `thread_local` on `STATIC_SOLIDINDEX` and the other
// fillet-path statics in the pinned kernel. A regression there is a wrong-but-
// plausible solid (one solid, positive volume, fails BRepCheck), so the checks
// are validity, solid count, topology counts and volume against a serial run,
// not "did not crash".
@Suite("Issue #3097, Shape.filleted is thread-safe on boolean results")
struct Issue3097FilletDirectThreadSafetyTests {

    /// One fillet input: a boolean result and the radius to round all its edges by.
    ///
    /// Written as a list walked by one test, not `@Test(arguments:)`, because an
    /// argument element pairing a reference-counted member with a wide vector hits
    /// a toolchain defect (#1057).
    private struct Case {
        let name: String
        let radius: Double
        let make: @Sendable () -> Shape?
    }

    private static let cases: [Case] = [
        // Two overlapping boxes: an L-shaped solid with a concave seam.
        Case(name: "L of two boxes", radius: 0.5) {
            guard let a = Shape.box(origin: .zero, width: 20, height: 10, depth: 10),
                let b = Shape.box(origin: .zero, width: 10, height: 10, depth: 20)
            else { return nil }
            return a.union(b)
        },
        // Three prisms meeting at one corner, the #298 pure-C++ reproducer shape.
        Case(name: "three boxes", radius: 0.4) {
            guard let a = Shape.box(origin: .zero, width: 20, height: 8, depth: 8),
                let b = Shape.box(origin: .zero, width: 8, height: 20, depth: 8),
                let c = Shape.box(origin: .zero, width: 8, height: 8, depth: 20),
                let ab = a.union(b)
            else { return nil }
            return ab.union(c)
        },
        // Box and sphere, the shape the pure-C++ gate scenario uses: a curved seam,
        // so the numerical blend solver runs.
        Case(name: "box and sphere", radius: 0.5) {
            guard let box = Shape.box(width: 10, height: 10, depth: 10),
                let sph = Shape.sphere(center: SIMD3<Double>(5, 5, 5), radius: 6)
            else { return nil }
            return box.union(sph)
        },
    ]

    /// What a single fillet produced, reduced to values that compare across threads.
    private struct Signature: Equatable, Sendable {
        var valid: Bool
        var solids: Int
        var faces: Int
        var edges: Int
        var volume: Double
    }

    private static func filletSignature(_ c: Case) -> Signature? {
        guard let input = c.make(), let out = input.filleted(radius: c.radius) else { return nil }
        return Signature(
            valid: out.isValid,
            solids: out.subShapes(ofType: .solid).count,
            faces: out.subShapes(ofType: .face).count,
            edges: out.subShapes(ofType: .edge).count,
            volume: out.volume ?? 0)
    }

    private struct Tally: Sendable {
        var total = 0
        var nilResult = 0
        var invalid = 0
        var topologyMismatch = 0
        var volumeMismatch = 0
        var sampleVolumes: [Double] = []

        mutating func merge(_ o: Tally) {
            total += o.total
            nilResult += o.nilResult
            invalid += o.invalid
            topologyMismatch += o.topologyMismatch
            volumeMismatch += o.volumeMismatch
            if sampleVolumes.count < 6 { sampleVolumes.append(contentsOf: o.sampleVolumes) }
        }
    }

    @Test("Concurrent Shape.filleted on boolean results matches a serial run")
    func concurrentFilletMatchesSerial() async throws {
        // Serial references, one per case, from uncontended builds.
        var references: [Signature] = []
        for c in Self.cases {
            let ref = try #require(Self.filletSignature(c), "serial fillet of \(c.name) failed")
            #expect(ref.valid, "serial fillet of \(c.name) is invalid")
            #expect(ref.solids == 1, "serial fillet of \(c.name) is not one solid")
            references.append(ref)
        }

        let threads = 8
        let iterations = 30
        let refs = references

        let agg = await withTaskGroup(of: Tally.self) { group -> Tally in
            for t in 0..<threads {
                group.addTask {
                    var tally = Tally()
                    for i in 0..<iterations {
                        // Rotate the case per thread and iteration so threads sit in
                        // different fillet phases against each other.
                        let k = (t + i) % Self.cases.count
                        tally.total += 1
                        guard let sig = Self.filletSignature(Self.cases[k]) else {
                            tally.nilResult += 1
                            continue
                        }
                        let ref = refs[k]
                        if !sig.valid { tally.invalid += 1 }
                        if sig.solids != ref.solids || sig.faces != ref.faces
                            || sig.edges != ref.edges
                        {
                            tally.topologyMismatch += 1
                        }
                        if abs(sig.volume - ref.volume) > max(1e-3, ref.volume * 1e-6) {
                            tally.volumeMismatch += 1
                            if tally.sampleVolumes.count < 3 {
                                tally.sampleVolumes.append(sig.volume)
                            }
                        }
                    }
                    return tally
                }
            }
            var total = Tally()
            for await t in group { total.merge(t) }
            return total
        }

        #expect(agg.total == threads * iterations)
        #expect(
            agg.nilResult == 0, "\(agg.nilResult) of \(agg.total) concurrent fillets returned nil")
        #expect(
            agg.invalid == 0,
            "\(agg.invalid) of \(agg.total) concurrent fillets were BRepCheck-invalid")
        #expect(
            agg.topologyMismatch == 0,
            "\(agg.topologyMismatch) of \(agg.total) concurrent fillets differ from serial in solid/face/edge counts"
        )
        #expect(
            agg.volumeMismatch == 0,
            "\(agg.volumeMismatch) of \(agg.total) concurrent fillets differ from serial volume; samples \(agg.sampleVolumes), reference \(refs.map(\.volume)), the #298 race"
        )
    }
}
