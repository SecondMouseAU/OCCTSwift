import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - BRepGraph UV Grid Sampling (v0.136.0)

@Suite("BRepGraph UV Grid")
struct BRepGraphUVGridTests {
    @Test func sampleBoxFace() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        let sample = try #require(graph.sampleFaceUVGrid(faceIndex: 0, uSamples: 5, vSamples: 5))
        #expect(sample.positions.count == 25)
        #expect(sample.normals.count == 25)
        #expect(sample.gaussianCurvatures.count == 25)
        #expect(sample.meanCurvatures.count == 25)
        #expect(sample.uSamples == 5)
        #expect(sample.vSamples == 5)
        // Face 0 is the x = -5 wall. Kernel (GeomLProp_SLProps on its surface): every normal is
        // (1, 0, 0), both curvatures are 0, and sample 0 (u = uMin, v = vMin) is at (-5, 5, -5).
        // A unit-length check alone passed a flipped normal.
        for n in sample.normals {
            #expect(abs(n.x - 1) < 1e-9 && abs(n.y) < 1e-9 && abs(n.z) < 1e-9)
        }
        for k in sample.gaussianCurvatures {
            #expect(abs(k) < 1e-10)
        }
        for h in sample.meanCurvatures {
            #expect(abs(h) < 1e-10)
        }
        #expect(simd_distance(sample.positions[0], SIMD3(-5, 5, -5)) < 1e-9)
        #expect(simd_distance(sample.positions[24], SIMD3(-5, -5, 5)) < 1e-9)
    }

    @Test func sampleSphereFace() throws {
        let sphere = try #require(Shape.sphere(radius: 5))
        let graph = try #require(BRepGraph(shape: sphere))
        #expect(graph.faceCount == 1)
        let sample = try #require(graph.sampleFaceUVGrid(faceIndex: 0, uSamples: 4, vSamples: 4))
        #expect(sample.positions.count == 16)
        // Kernel: v spans [-pi/2, pi/2] in 4 steps, so iv = 0 and 3 are the poles, where
        // curvature is undefined and the bridge writes 0; iv = 1 and 2 are at +-30 degrees
        // latitude, where K = 1/r^2 = 0.04. "Some non-zero value" passed any wrong curvature.
        for iu in 0..<4 {
            for iv in 0..<4 {
                let k = sample.gaussianCurvatures[iu * 4 + iv]
                let expected = (iv == 1 || iv == 2) ? 0.04 : 0.0
                #expect(abs(k - expected) < 1e-9)
            }
        }
    }

    @Test func sampleSinglePoint() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        let sample = try #require(graph.sampleFaceUVGrid(faceIndex: 0, uSamples: 1, vSamples: 1))
        #expect(sample.positions.count == 1)
        // Kernel: one sample sits at (uMin, vMin), the corner (-5, 5, -5).
        #expect(simd_distance(sample.positions[0], SIMD3(-5, 5, -5)) < 1e-9)
    }

    @Test func sampleInvalidFace() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        let sample = graph.sampleFaceUVGrid(faceIndex: 999, uSamples: 5, vSamples: 5)
        #expect(sample == nil)
    }

    @Test func sampleZeroCounts() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        let sample = graph.sampleFaceUVGrid(faceIndex: 0, uSamples: 0, vSamples: 5)
        #expect(sample == nil)
    }
}
