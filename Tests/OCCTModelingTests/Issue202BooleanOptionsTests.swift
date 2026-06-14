import Testing
import Foundation
import simd
@testable import OCCTSwift

// #202: BRepAlgoAPI boolean fuzzy value + glue options exposed on the boolean ops.
@Suite("Issue #202 — boolean fuzzy value + glue options")
struct Issue202BooleanOptions {

    /// Two unit cubes stacked along Z, sharing the coincident face at z = 10.
    private func stackedBoxes() -> (Shape, Shape)? {
        guard let lower = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
              let upper = Shape.box(origin: SIMD3(0, 0, 10), width: 10, height: 10, depth: 10) else {
            return nil
        }
        return (lower, upper)
    }

    @Test("default parameters preserve existing behavior")
    func defaultParity() {
        guard let (a, b) = stackedBoxes() else { #expect(Bool(false)); return }
        // No-arg call still resolves (defaults fuzzyValue: 0, glue: .off) and gives the union volume.
        if let u = a.union(b) { #expect(abs((u.volume ?? 0) - 2000.0) < 1.0) }
        else { #expect(Bool(false), "union(_:) returned nil") }

        guard let big = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
              let tool = Shape.box(origin: SIMD3(2, 2, 0), width: 6, height: 6, depth: 10) else {
            #expect(Bool(false)); return
        }
        if let cut = big.subtracting(tool) { #expect(abs((cut.volume ?? 0) - (1000.0 - 360.0)) < 1.0) }
        else { #expect(Bool(false), "subtracting(_:) returned nil") }
    }

    // Issue case 1: union of consecutive chunk solids that share a boundary cross-section.
    @Test("glued union of coincident-face solids is valid with correct volume")
    func gluedUnion() {
        guard let (a, b) = stackedBoxes() else { #expect(Bool(false)); return }
        for glue in [Shape.BooleanGlue.shift, .full] {
            guard let u = a.union(b, fuzzyValue: 0, glue: glue) else {
                #expect(Bool(false), "glued union (\(glue)) returned nil"); continue
            }
            #expect(u.isValid)
            #expect(u.shellCount == 1)                       // fused into a single shell
            #expect(abs((u.volume ?? 0) - 2000.0) < 1.0)     // no over/under-volume
        }
    }

    // Issue case 2: thin-wall subtract should remove exactly the inner solid's volume.
    @Test("fuzzy subtract of a thin wall removes the full inner volume")
    func fuzzyThinWallSubtract() {
        guard let outer = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
              // inner leaves a 1mm wall on X/Y, open through Z → removes 8*8*10 = 640
              let inner = Shape.box(origin: SIMD3(1, 1, 0), width: 8, height: 8, depth: 10) else {
            #expect(Bool(false)); return
        }
        guard let shell = outer.subtracting(inner, fuzzyValue: 1e-4, glue: .off) else {
            #expect(Bool(false), "fuzzy subtract returned nil"); return
        }
        #expect(shell.isValid)
        #expect(abs((shell.volume ?? 0) - (1000.0 - 640.0)) < 1.0)
    }

    @Test("fuzzy intersection returns the overlap volume")
    func fuzzyIntersection() {
        guard let a = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
              let b = Shape.box(origin: SIMD3(5, 0, 0), width: 10, height: 10, depth: 10) else {
            #expect(Bool(false)); return
        }
        guard let x = a.intersection(b, fuzzyValue: 1e-4) else {
            #expect(Bool(false), "fuzzy intersection returned nil"); return
        }
        #expect(abs((x.volume ?? 0) - 500.0) < 1.0)          // 5*10*10 overlap
    }

    @Test("negative fuzzy value is ignored, not fatal")
    func negativeFuzzyIgnored() {
        guard let (a, b) = stackedBoxes() else { #expect(Bool(false)); return }
        if let u = a.union(b, fuzzyValue: -5) { #expect(abs((u.volume ?? 0) - 2000.0) < 1.0) }
        else { #expect(Bool(false), "union with negative fuzzy returned nil") }
    }
}
