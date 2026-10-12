import Testing

@testable import OCCTSwift

@Suite("v0.126.0, FilletBuilder completions")
struct FilletBuilderCompletionsTests {
    // The tolerance set is not observable in the result of a plain box edge: the default set,
    // the documented small set and a deliberately huge `fleche`, `tang`, `tesp` or `tApp3d` all
    // build the identical shape (measured on the pinned kernel, v4.0.0-kernel.6). So this pins
    // what setting them must not do, which is change or break a correct fillet.
    @Test("SetParams doesn't crash")
    func setParams() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let fb = try #require(FilletBuilder(shape: box))
        let edge = try #require(box.edges().first)
        fb.setParams(
            tang: 1e-4, tesp: 1e-3, t2d: 1e-5, tApp3d: 1e-4, tApp2d: 1e-5, fleche: 1e-3)
        #expect(fb.addEdge(edge, radius: 2.0))
        let result = try #require(fb.build())
        #expect(result.isValid)
        // 8000 - (1 - pi/4) * 2^2 * 20 = 7982.8318530...
        let expected = 8000.0 - (1.0 - Double.pi / 4.0) * 4.0 * 20.0
        #expect(abs((result.volume ?? -1) - expected) < 1e-6)
        #expect(abs((result.volume ?? -1) - 7982.831853071794) < 1e-6)
    }

    @Test("SetContinuity and Get/SetFilletShape")
    func continuityAndFilletShape() {
        let box = Shape.box(width: 20, height: 20, depth: 20)
        if let box = box {
            let fb = FilletBuilder(shape: box)
            if let fb = fb {
                fb.setContinuity(1, angularTolerance: 0.001)  // C1
                fb.setFilletShape(1)  // QuasiAngular
                #expect(fb.filletShape == 1)
                fb.setFilletShape(0)  // Rational
                #expect(fb.filletShape == 0)
            }
        }
    }

    // `resetContour` clears the radius of a contour. Building after it is not exercised: a
    // contour without a radius makes `Build()` SIGSEGV (see #520).
    @Test("ResetContour and Simulate")
    func resetAndSimulate() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let fb = try #require(FilletBuilder(shape: box))
        let edge = try #require(box.edges().first)
        #expect(fb.addEdge(edge, radius: 2.0))
        #expect(fb.contourCount == 1)
        #expect(fb.radius(contour: 1) == 2.0)
        #expect(abs(fb.length(contour: 1) - 20.0) < 1e-9)

        // One fillet face on a one-edge contour.
        fb.simulate(contour: 1)
        #expect(fb.simulatedSurfaceCount(contour: 1) == 1)

        fb.resetContour(1)
        #expect(fb.radius(contour: 1) == 0.0)
        // The contour is still there, it only lost its radius.
        #expect(fb.contourCount == 1)
    }
}
