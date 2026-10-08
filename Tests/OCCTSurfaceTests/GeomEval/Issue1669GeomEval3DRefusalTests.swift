import Foundation
import Testing

@testable import OCCTSwift

// Issue #1669: the ten 3D GeomEval evaluators had the shape #1646 removed from their 2D
// counterparts. Each was a `void` bridge function writing out-parameters inside a `try`, so a
// caught throw left the caller's pre-zeroed buffer untouched and Swift received the zero vector.
// The origin is a point these curves and surfaces legitimately pass through, so that answer was
// indistinguishable from a real one.
//
// The fix follows #1668's shape rather than re-deriving it, including the part #1646 learned the
// expensive way: the success flag is read off the OUTPUTS, not off the throw. A throw is only one
// of three routes to a non-answer, and the other two were measured against the pinned kernel:
//
//   - a non-finite argument walks straight past OCCT's validation, because every check is written
//     `<= 0` and every comparison against NaN is false, so the constructor accepts NaN and
//     evaluates to a NaN point;
//   - finite arguments can still produce a non-finite point.
//
// A flag derived from the throw alone fails both. That is what these tests pin.
@Suite("Issue #1669, the 3D GeomEval evaluators distinguish a refusal from the origin")
struct Issue1669GeomEval3DRefusalTests {

    // MARK: A well-formed call still answers

    @Test("A helix at u = 0 answers with the point on the radius")
    func helixAnswers() throws {
        let p = try #require(GeomEval.circularHelixD0(radius: 5, pitch: 2, u: 0))
        #expect(abs(p.x - 5) < 1e-10)
        #expect(abs(p.y) < 1e-10)
        #expect(abs(p.z) < 1e-10)
    }

    @Test("An ellipsoid at (0,0) answers with the point on the a-axis")
    func ellipsoidAnswers() throws {
        let p = try #require(GeomEval.ellipsoidD0(a: 3, b: 4, c: 5, u: 0, v: 0))
        #expect(abs(p.x - 3) < 1e-10)
    }

    // MARK: The origin is a real answer, not a sentinel

    @Test("A sine wave through the origin answers the origin rather than refusing")
    func originIsAnAnswer() throws {
        // C(0) = (0, A*sin(phase), 0), and at phase 0 that is exactly the origin. Before #1669 a
        // caller could not tell this from a refusal; the whole point of the change is that this
        // case and the refusals below now differ.
        let p = try #require(GeomEval.sineWaveD0(amplitude: 2, omega: 3, phase: 0, u: 0))
        #expect(abs(p.x) < 1e-10)
        #expect(abs(p.y) < 1e-10)
        #expect(abs(p.z) < 1e-10)
    }

    // MARK: Route 2, a non-finite argument that OCCT's own validation does not catch

    @Test("NaN arguments are refused across all ten evaluators")
    func nanArgumentsRefused() {
        // Written as one test walking a list rather than @Test(arguments:), because a tuple
        // pairing a String with a builtin vector of 32 bytes or more corrupts the Swift task
        // allocator (#1057, swiftlang/swift#91639). The workaround otherwise reads as a style
        // choice somebody will later clean up.
        let nan = Double.nan
        #expect(GeomEval.circularHelixD0(radius: nan, pitch: 2, u: 0) == nil)
        #expect(GeomEval.circularHelixD1(radius: nan, pitch: 2, u: 0) == nil)
        #expect(GeomEval.circularHelixD2(radius: nan, pitch: 2, u: 0) == nil)
        #expect(GeomEval.sineWaveD0(amplitude: nan, omega: 3, phase: 0, u: 0) == nil)
        #expect(GeomEval.sineWaveD1(amplitude: nan, omega: 3, phase: 0, u: 0) == nil)
        #expect(GeomEval.ellipsoidD0(a: nan, b: 4, c: 5, u: 0, v: 0) == nil)
        #expect(GeomEval.hyperboloidD0(r1: nan, r2: 3, twoSheets: false, u: 0, v: 0) == nil)
        #expect(GeomEval.paraboloidD0(focal: nan, u: 0, v: 1) == nil)
        #expect(GeomEval.circularHelicoidD0(pitch: nan, u: 0, v: 1) == nil)
        #expect(GeomEval.hyperbolicParaboloidD0(a: nan, b: 3, u: 0, v: 0) == nil)
    }

    @Test("A NaN parameter is refused as well as a NaN construction argument")
    func nanParameterRefused() {
        // The parameter takes a different path from the constructor arguments: it never reaches a
        // validation check at all, it just flows into the evaluation. Both have to refuse.
        #expect(GeomEval.circularHelixD0(radius: 5, pitch: 2, u: .nan) == nil)
        #expect(GeomEval.ellipsoidD0(a: 3, b: 4, c: 5, u: .nan, v: 0) == nil)
        #expect(GeomEval.ellipsoidD0(a: 3, b: 4, c: 5, u: 0, v: .nan) == nil)
    }

    @Test("An infinite argument is refused")
    func infiniteArgumentRefused() {
        #expect(GeomEval.circularHelixD0(radius: .infinity, pitch: 2, u: 0) == nil)
        #expect(GeomEval.sineWaveD0(amplitude: .infinity, omega: 3, phase: 0, u: 0) == nil)
        #expect(GeomEval.paraboloidD0(focal: 1, u: .infinity, v: 0) == nil)
    }

    // MARK: Derivative forms answer with every component or none

    @Test("A refused D1 yields no point either, not a point with a zero derivative")
    func derivativeRefusalIsTotal() {
        // The failure this guards is a partial write: the point lands, the derivative does not,
        // and the caller reads a real position with a zero tangent. `nil` for the pair is the only
        // answer that cannot be misread.
        #expect(GeomEval.circularHelixD1(radius: .nan, pitch: 2, u: 0) == nil)
        #expect(GeomEval.sineWaveD1(amplitude: .nan, omega: 3, phase: 0, u: 0) == nil)
    }

    @Test("A well-formed D2 answers all three components")
    func d2AnswersAllThree() throws {
        let (p, d1, d2) = try #require(GeomEval.circularHelixD2(radius: 5, pitch: 2, u: 0))
        #expect(abs(p.x - 5) < 1e-10)
        #expect(d1 != SIMD3<Double>(0, 0, 0), "a helix has a non-zero tangent at u = 0")
        #expect(d2 != SIMD3<Double>(0, 0, 0), "a helix has a non-zero curvature vector at u = 0")
    }
}
