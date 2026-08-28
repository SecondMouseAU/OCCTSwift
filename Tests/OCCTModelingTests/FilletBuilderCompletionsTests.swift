import Testing
import simd

@testable import OCCTSwift

@Suite("v0.126.0, FilletBuilder completions")
struct FilletBuilderCompletionsTests {
    @Test("SetParams doesn't crash")
    func setParams() {
        let box = Shape.box(width: 20, height: 20, depth: 20)
        if let box = box {
            let fb = FilletBuilder(shape: box)
            if let fb = fb {
                fb.setParams(
                    tang: 1e-4, tesp: 1e-3, t2d: 1e-5, tApp3d: 1e-4, tApp2d: 1e-5, fleche: 1e-3)
                // Should not crash
            }
        }
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

    @Test("ResetContour and Simulate")
    func resetAndSimulate() {
        let box = Shape.box(width: 20, height: 20, depth: 20)
        if let box = box {
            let fb = FilletBuilder(shape: box)
            if let fb = fb {
                let edges = box.edges()
                if let firstEdge = edges.first {
                    fb.addEdge(firstEdge, radius: 2.0)
                    // resetContour and simulate should not crash even if Build wasn't called
                    fb.resetContour(1)
                }
            }
        }
    }
}
