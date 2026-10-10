import Foundation
import Testing
import simd

@testable import OCCTSwift

/// #3200: a blend the builder reports done is not necessarily a blend `BRepCheck` accepts.
///
/// `BRepFilletAPI_MakeFillet` answers `IsDone() == true` for fillets whose radii overlap on a shared
/// face and for the #2881 model's vertex-snap window (#3209), and `Shape.filleted` used to hand the
/// result back as though it were a solid. Every fillet and chamfer entry point now answers `nil`
/// when the result is `BRepCheck`-invalid. Measured on the pinned kernel
/// (`Scripts/repro/fillet-exact-meeting/`, `Scripts/repro/fillet-reporter-window/`).
///
/// What these tests do not pin: the radius `r = w/2` itself. Patch 0059 (#3207) makes it build, so
/// every check at or next to a half-width is the invariant "nil, or a valid shape", never "nil".
@Suite("Fillet and chamfer results are BRepCheck-valid or nil (#3200)")
struct Issue3200FilletResultValidityTests {

    // MARK: - Fixtures

    /// The edge whose midpoint is nearest `rel` (fractions of the shape's bounding box).
    private func edge(_ shape: Shape, _ rel: (Double, Double, Double)) -> Edge? {
        guard let box = shape.bounds else { return nil }
        let target = SIMD3(
            box.min.x + rel.0 * (box.max.x - box.min.x),
            box.min.y + rel.1 * (box.max.y - box.min.y),
            box.min.z + rel.2 * (box.max.z - box.min.z))
        var best: (distance: Double, edge: Edge)?
        for candidate in shape.edges() {
            guard let b = candidate.bounds else { continue }
            let d = simd_length_squared((b.min + b.max) / 2 - target)
            if best == nil || d < best!.distance { best = (d, candidate) }
        }
        return best?.edge
    }

    /// The four edges round the top face, and the two opposite edges of it.
    private let topFrame: [(Double, Double, Double)] = [
        (0, 0.5, 1), (1, 0.5, 1), (0.5, 0, 1), (0.5, 1, 1),
    ]
    private let topPair: [(Double, Double, Double)] = [(0, 0.5, 1), (1, 0.5, 1)]

    private func edges(_ shape: Shape, _ rel: [(Double, Double, Double)]) -> [Edge] {
        rel.compactMap { edge(shape, $0) }
    }

    /// 4 x 10 x 6: the box of #3200.
    private func slab() throws -> Shape { try #require(Shape.box(width: 4, height: 10, depth: 6)) }
    private func cube() throws -> Shape { try #require(Shape.box(width: 4, height: 4, depth: 4)) }

    /// Whatever came back must be valid: the contract, independent of where a kernel patch moves
    /// the point at which a fillet starts to build.
    private func expectNilOrValid(_ result: Shape?, _ context: String) {
        if let result {
            #expect(result.isValid, "\(context): returned a BRepCheck-invalid shape")
        }
    }

    // MARK: - The measured cases of #3200, through Shape.filleted

    /// 4-edge frame on the 4 mm wide face, radii at and above half the width, then 1.5x.
    @Test("A 4-edge frame of overlapping fillets never answers an invalid shape")
    func frameOnSlab() throws {
        let box = try slab()
        let frame = edges(box, topFrame)
        #expect(frame.count == 4)
        for r in [2.0 + 1e-8, 2.0001, 2.001, 3.0, 3.0 + 1e-8, 2.9999, 3.001] {
            expectNilOrValid(box.filleted(edges: frame, radius: r), "slab frame r=\(r)")
        }
        // The two worst measured: done, invalid, and as far from a result as 4.5.
        #expect(box.filleted(edges: frame, radius: 2.0 + 1e-8) == nil)
        #expect(box.filleted(edges: frame, radius: 3.0 + 1e-8) == nil)
    }

    @Test("The same frame on a 4 mm cube")
    func frameOnCube() throws {
        let box = try cube()
        let frame = edges(box, topFrame)
        #expect(frame.count == 4)
        for r in [2.0 + 1e-8, 2.001, 3.0] {
            expectNilOrValid(box.filleted(edges: frame, radius: r), "cube frame r=\(r)")
        }
        #expect(box.filleted(edges: frame, radius: 3.0) == nil)
    }

    @Test("All twelve edges above half the face width answer nil, through every entry point")
    func allTwelveEdges() throws {
        let box = try slab()
        let all = box.edges()
        for r in [2.0001, 2.001, 2.9999, 3.0001] {
            #expect(box.filleted(radius: r) == nil, "filleted(radius: \(r))")
            #expect(box.filleted(edges: all, radius: r) == nil, "filleted(edges:) r=\(r)")
            #expect(box.filletedWithReport(edges: all, radius: r) == nil, "WithReport r=\(r)")
            #expect(box.filleted(edges: all, startRadius: r, endRadius: r) == nil, "linear r=\(r)")
        }
        let c = try cube()
        for r in [2.0001, 3.0001] {
            #expect(c.filleted(radius: r) == nil, "cube filleted(radius: \(r))")
        }
        // The example in the filleted(radius:) docs.
        let ten = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(ten.filleted(radius: 1)?.isValid == true)
        #expect(ten.filleted(radius: 6) == nil)
    }

    // MARK: - The builders and the history variant

    @Test("FilletBuilder.build answers nil for an invalid frame, and reports the build as it was")
    func filletBuilderFrame() throws {
        let box = try cube()
        let frame = edges(box, topFrame)
        let builder = try #require(FilletBuilder(shape: box))
        for e in frame { builder.addEdge(e, radius: 3.0) }
        #expect(builder.build() == nil)
        // The builder's own diagnostics are untouched: the guard replaces the returned shape only.
        #expect(builder.contourCount > 0)
    }

    @Test("A builder with valid radii still builds")
    func filletBuilderValid() throws {
        let box = try slab()
        let pair = edges(box, topPair)
        let builder = try #require(FilletBuilder(shape: box))
        for e in pair { builder.addEdge(e, radius: 1.0) }
        let result = try #require(builder.build())
        #expect(result.isValid)
    }

    @Test("ChamferBuilder.build never answers an invalid shape for a frame of overlapping chamfers")
    func chamferBuilderFrame() throws {
        let box = try cube()
        let frame = edges(box, topFrame)
        for d in [2.0 + 1e-4, 3.0, 4.5] {
            let builder = try #require(ChamferBuilder(shape: box))
            for e in frame { builder.addEdge(e, distance: d) }
            expectNilOrValid(builder.build(), "chamfer frame d=\(d)")
        }
    }

    @Test("The with-history variants share the guard")
    func historyVariants() throws {
        let box = try slab()
        let frame = edges(box, topFrame)
        let indices = frame.map(\.index)
        if let r = box.filletedWithFullHistory(radius: 3.0 + 1e-8, edges: indices) {
            #expect(r.result.isValid)
        }
        #expect(box.filletedWithFullHistory(radius: 3.0 + 1e-8, edges: indices) == nil)
    }

    // MARK: - Valid results are unchanged

    /// Two opposite 4 mm-face edges, one fillet radius r each: the removed area per edge is
    /// (1 - pi/4) r^2 over the edge length, so the volume is exact.
    private func pairVolume(radius r: Double) -> Double {
        240 - 2 * (1 - Double.pi / 4) * r * r * 10
    }

    @Test("A valid pair of fillets keeps its analytic volume")
    func validPairVolume() throws {
        let box = try slab()
        let pair = edges(box, topPair)
        #expect(pair.count == 2)
        // 1.999 is the largest radius the pair accepts on a 4 mm face short of 1e-9 from half-width.
        for r in [0.5, 1.0, 1.999, 1.9999, 1.99999999] {
            let result = try #require(box.filleted(edges: pair, radius: r), "r=\(r)")
            #expect(result.isValid)
            let volume = try #require(result.volume)
            #expect(abs(volume - pairVolume(radius: r)) < 1e-6, "r=\(r): \(volume)")
        }
    }

    /// Volumes measured on the unguarded build, ten cases, all of which must come through identical.
    @Test("Valid fillets and chamfers keep the volumes measured before the guard")
    func validBattery() throws {
        let box = try slab()
        let cb = try cube()
        let frameBox = edges(box, topFrame)
        let frameCube = edges(cb, topFrame)
        let cases: [(String, Shape?, Double)] = [
            ("slab frame r=1", box.filleted(edges: frameBox, radius: 1.0), 234.374629926),
            ("slab frame r=1.999", box.filleted(edges: frameBox, radius: 1.999), 219.051875066),
            ("slab frame r=1.9999", box.filleted(edges: frameBox, radius: 1.9999), 219.034388459),
            ("cube frame r=1", cb.filleted(edges: frameCube, radius: 1.0), 60.9498519682),
            ("cube frame r=1.999", cb.filleted(edges: frameCube, radius: 1.999), 53.3424649164),
            ("slab all12 r=1", box.filleted(radius: 1.0), 224.171087355),
            ("slab all12 r=1.5", box.filleted(radius: 1.5), 205.891585118),
            ("cube all12 r=1", cb.filleted(radius: 1.0), 55.0383461263),
            ("slab chamfer all12 d=1.5", box.chamfered(distance: 1.5), 168.0),
            ("slab chamfer all12 d=1", box.chamfered(distance: 1.0), 205.333333333),
        ]
        // The slab r=1.999 volume differs by 2.3e-8 (1e-10 relative) on wasm32, where WASILibc's
        // transcendentals feed the numerical integration. Apple keeps the 1e-8 bound.
        #if arch(wasm32)
            let tolerance = 1e-6
        #else
            let tolerance = 1e-8
        #endif
        for (name, shape, expected) in cases {
            let result = try #require(shape, Comment(rawValue: name))
            #expect(result.isValid, Comment(rawValue: name))
            let volume = try #require(result.volume, Comment(rawValue: name))
            #expect(abs(volume - expected) < tolerance, Comment(rawValue: "\(name): \(volume)"))
        }
    }
}
