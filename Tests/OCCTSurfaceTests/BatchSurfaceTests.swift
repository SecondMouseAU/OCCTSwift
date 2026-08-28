import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Batch Surface Evaluation")
struct BatchSurfaceTests {
    @Test("Evaluate grid on plane")
    func evalGridPlane() {
        let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))!
        let uParams = [0.0, 1.0, 2.0]
        let vParams = [0.0, 1.0]
        let grid = plane.evaluateGrid(uParameters: uParams, vParameters: vParams)
        #expect(grid.uCount == 3)
        #expect(grid.vCount == 2)
        // All z should be 0 on the XY plane
        for u in 0..<grid.uCount {
            for v in 0..<grid.vCount {
                #expect(abs(grid.at(u: u, v: v).z) < 1e-10)
            }
        }
    }

    @Test("Evaluate grid on sphere")
    func evalGridSphere() {
        let sphere = Surface.sphere(center: .zero, radius: 5)!
        let uParams = stride(from: 0.0, to: 2 * Double.pi, by: Double.pi / 4).map { $0 }
        let vParams = stride(from: -Double.pi / 2, to: Double.pi / 2, by: Double.pi / 4).map { $0 }
        let grid = sphere.evaluateGrid(uParameters: uParams, vParameters: vParams)
        #expect(grid.uCount == uParams.count)
        #expect(grid.vCount == vParams.count)
        // All points should be at distance 5 from origin
        for u in 0..<grid.uCount {
            for v in 0..<grid.vCount {
                let pt = grid.at(u: u, v: v)
                let dist = sqrt(pt.x * pt.x + pt.y * pt.y + pt.z * pt.z)
                #expect(abs(dist - 5.0) < 1e-6)
            }
        }
    }

    @Test("evaluateGrid indexes each (u, v) at its own parameter, not transposed")
    func evalGridAsymmetricMatchesDirectEvaluation() {
        // #404: evaluateGrid used to return [vIndex][uIndex] while drawMesh returned
        // [uIndex][vIndex], a symmetric grid can't tell the two conventions apart, so use an
        // asymmetric one and cross-check every sample against the independent point(atU:v:)
        // evaluator.
        let sphere = Surface.sphere(center: .zero, radius: 5)!
        let uParams = [0.0, 0.4, 1.1, 2.0, 3.5]
        let vParams = [-1.2, 0.0, 1.2]
        let grid = sphere.evaluateGrid(uParameters: uParams, vParameters: vParams)
        #expect(grid.uCount == uParams.count)
        #expect(grid.vCount == vParams.count)

        for u in 0..<uParams.count {
            for v in 0..<vParams.count {
                let expected = sphere.point(atU: uParams[u], v: vParams[v])
                let actual = grid.at(u: u, v: v)
                #expect(simd_length(actual - expected) < 1e-6)
            }
        }
    }

    @Test("drawMesh and evaluateGrid agree at matching parameters")
    func drawMeshAndEvaluateGridAgree() {
        // #404: the two methods used opposite index conventions internally, but nothing at the
        // type level distinguished them, a caller mixing them up would silently read transposed
        // data. Now both return SurfaceGrid, sampled here at the same asymmetric (u, v) grid, so
        // they must agree point-for-point under the same .at(u:v:) indexing.
        let sphere = Surface.sphere(center: .zero, radius: 5)!
        let uCount = 5
        let vCount = 3
        let meshGrid = sphere.drawMesh(uCount: uCount, vCount: vCount)

        var (uMin, uMax, vMin, vMax) = sphere.domain
        if uMin < -1e6 { uMin = -100 }
        if uMax > 1e6 { uMax = 100 }
        if vMin < -1e6 { vMin = -100 }
        if vMax > 1e6 { vMax = 100 }
        let uParams = (0..<uCount).map { uMin + (uMax - uMin) * Double($0) / Double(uCount - 1) }
        let vParams = (0..<vCount).map { vMin + (vMax - vMin) * Double($0) / Double(vCount - 1) }
        let evalGrid = sphere.evaluateGrid(uParameters: uParams, vParameters: vParams)

        #expect(meshGrid.uCount == evalGrid.uCount)
        #expect(meshGrid.vCount == evalGrid.vCount)
        for u in 0..<uCount {
            for v in 0..<vCount {
                let fromMesh = meshGrid.at(u: u, v: v)
                let fromEval = evalGrid.at(u: u, v: v)
                #expect(simd_length(fromMesh - fromEval) < 1e-6)
            }
        }
    }
}
