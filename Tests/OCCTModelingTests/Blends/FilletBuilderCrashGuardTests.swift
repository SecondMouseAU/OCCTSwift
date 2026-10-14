import Testing

@testable import OCCTSwift

/// #3367: two ways to reach an uncatchable SIGSEGV through the public `FilletBuilder`.
///
/// A contour whose radius list was cleared by `resetContour(_:)` made `Build()` fault (the #520
/// family, reached through the builder instead of `filletEvolving`), and a zero or negative
/// `tApp3d` made it fault as well (measured: 0 and -1 crash, 1e-15 and up build).
@Suite("FilletBuilder crash guards")
struct FilletBuilderCrashGuardTests {

    @Test("build after resetContour is refused, and a fresh radius makes it build again")
    func buildAfterResetContourIsRefused() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let fb = try #require(FilletBuilder(shape: box))
        let edge = try #require(box.edges().first)
        #expect(fb.addEdge(edge, radius: 2.0))
        fb.resetContour(1)
        #expect(fb.contourCount == 1)
        #expect(fb.build() == nil)

        // Control: the same builder with a radius given again builds.
        #expect(fb.setRadius(2.0, contour: 1, edge: edge))
        if let built = fb.build() {
            #expect(built.isValid)
        } else {
            Issue.record("a contour with a radius returned nil")
        }
    }

    @Test("A variable-radius contour still builds")
    func variableRadiusStillBuilds() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let fb = try #require(FilletBuilder(shape: box))
        let edge = try #require(box.edges().first)
        #expect(fb.addEdge(edge, radius1: 1.0, radius2: 3.0))
        if let built = fb.build() {
            #expect(built.isValid)
        } else {
            Issue.record("an evolving-radius contour returned nil")
        }
    }

    // Each value is tried on a fresh builder. Every one is left unapplied, so the build that
    // follows runs on the default tolerances and succeeds.
    @Test("setParams ignores a non-positive or non-finite tolerance instead of crashing build")
    func setParamsRefusesBadTolerances() throws {
        let bad: [Double] = [0, -1, .nan, .infinity]
        for slot in 0..<6 {
            for value in bad {
                var p: [Double] = [1e-4, 1e-3, 1e-5, 1e-4, 1e-5, 1e-3]
                p[slot] = value
                let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
                let fb = try #require(FilletBuilder(shape: box))
                let edge = try #require(box.edges().first)
                fb.setParams(
                    tang: p[0], tesp: p[1], t2d: p[2], tApp3d: p[3], tApp2d: p[4], fleche: p[5])
                #expect(fb.addEdge(edge, radius: 2.0))
                if let built = fb.build() {
                    #expect(built.isValid, "slot \(slot) value \(value)")
                } else {
                    Issue.record("slot \(slot) value \(value) returned nil")
                }
            }
        }
        // All-zero, the exact call from the report.
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let fb = try #require(FilletBuilder(shape: box))
        fb.setParams(tang: 0, tesp: 0, t2d: 0, tApp3d: 0, tApp2d: 0, fleche: 0)
        #expect(fb.addEdge(try #require(box.edges().first), radius: 2.0))
        #expect(fb.build() != nil)
    }
}
