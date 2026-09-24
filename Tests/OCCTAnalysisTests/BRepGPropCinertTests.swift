import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGProp Cinert Tests")
struct BRepGPropCinertTests {
    /// Edge 0 of the centred 10 x 20 x 30 box runs (-5, -10, -15) to (-5, -10, 15). Length and
    /// centre are `BRepGProp_Cinert`'s, read by `Scripts/repro/766-asymchamfer-cinert-vinert/`.
    @Test("edge curve inertia")
    func edgeCurveInertia() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let edge = try #require(box.edges().first)
        let inertia = edge.curveInertia
        #expect(abs(inertia.length - 30) < 1e-9, "length \(inertia.length)")
        let c = try #require(inertia.centerOfMass)
        #expect(simd_distance(c, SIMD3(-5, -10, 0)) < 1e-9, "centre \(c)")
    }
}
