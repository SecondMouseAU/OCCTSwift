import Testing
import simd

@testable import OCCTSwift

@Suite("Surface Draw Methods")
struct SurfaceDrawTests {
    @Test("Draw grid returns iso lines")
    func drawGrid() {
        let sphere = Surface.sphere(center: .zero, radius: 5)!
        let grid = sphere.drawGrid(uLineCount: 5, vLineCount: 5, pointsPerLine: 20)
        #expect(grid.count == 10)  // 5 U-iso + 5 V-iso lines
        // #766: pin two points: u-iso 0 at v-step 10, and v-iso 2 (the equator) at u-step 5.
        if grid.count == 10, grid[0].count == 20, grid[7].count == 20 {
            #expect(simd_length(grid[0][10] - SIMD3(4.982922465033349, 0, 0.41289672736166172)) < 1e-12)
            #expect(simd_length(grid[7][5] - SIMD3(-0.41289672736166133, 4.982922465033349, 0)) < 1e-12)
        }
        for line in grid {
            #expect(line.count == 20)
            // All points should be on sphere
            for p in line {
                let dist = simd_length(p)
                #expect(abs(dist - 5.0) < 1e-9)  // #766: was 0.5; the kernel's worst is 8.9e-16
            }
        }
    }

    @Test("Draw mesh returns grid points")
    func drawMesh() {
        let sphere = Surface.sphere(center: .zero, radius: 5)!
        let mesh = sphere.drawMesh(uCount: 10, vCount: 10)
        #expect(mesh.uCount == 10)
        #expect(mesh.vCount == 10)
        let p = mesh.at(u: 0, v: 0)
        #expect(abs(simd_length(p) - 5.0) < 1e-6)
        // #766: any point at radius 5 passed; (uMin, vMin) is the south pole.
        #expect(simd_length(p - SIMD3(0, 0, -5)) < 1e-12)
    }

    @Test("Draw mesh on an asymmetric grid indexes .at(u:v:) correctly")
    func drawMeshAsymmetric() {
        let sphere = Surface.sphere(center: .zero, radius: 5)!
        let uCount = 6
        let vCount = 4
        let mesh = sphere.drawMesh(uCount: uCount, vCount: vCount)
        #expect(mesh.uCount == uCount)
        #expect(mesh.vCount == vCount)

        // Recompute the same clamped domain the bridge samples (OCCTSurfaceDrawMesh), and cross
        // check every grid point against the independent single-point evaluator. Before #404,
        // drawMesh's own test used a symmetric 10x10 grid, which cannot distinguish [u][v] from
        // [v][u] ordering, this asymmetric grid can.
        var (uMin, uMax, vMin, vMax) = sphere.domain
        if uMin < -1e6 { uMin = -100 }
        if uMax > 1e6 { uMax = 100 }
        if vMin < -1e6 { vMin = -100 }
        if vMax > 1e6 { vMax = 100 }

        for u in 0..<uCount {
            let uParam = uMin + (uMax - uMin) * Double(u) / Double(uCount - 1)
            for v in 0..<vCount {
                let vParam = vMin + (vMax - vMin) * Double(v) / Double(vCount - 1)
                let expected = sphere.point(atU: uParam, v: vParam)
                let actual = mesh.at(u: u, v: v)
                #expect(simd_length(actual - expected) < 1e-6)
            }
        }
    }
}
