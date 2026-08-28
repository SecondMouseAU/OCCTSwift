import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - BRepGraph UV Grid Sampling (v0.136.0)

@Suite("BRepGraph UV Grid")
struct BRepGraphUVGridTests {
    @Test func sampleBoxFace() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                let sample = graph.sampleFaceUVGrid(faceIndex: 0, uSamples: 5, vSamples: 5)
                #expect(sample != nil)
                if let sample {
                    #expect(sample.positions.count == 25)
                    #expect(sample.normals.count == 25)
                    #expect(sample.gaussianCurvatures.count == 25)
                    #expect(sample.meanCurvatures.count == 25)
                    #expect(sample.uSamples == 5)
                    #expect(sample.vSamples == 5)
                    // All normals should be non-zero (planar face)
                    for n in sample.normals {
                        let len = (n.x * n.x + n.y * n.y + n.z * n.z).squareRoot()
                        #expect(len > 0.99)
                    }
                    // Planar face: gaussian curvature should be ~0
                    for k in sample.gaussianCurvatures {
                        #expect(abs(k) < 1e-10)
                    }
                }
            }
        }
    }

    @Test func sampleSphereFace() {
        if let sphere = Shape.sphere(radius: 5) {
            if let graph = BRepGraph(shape: sphere) {
                if graph.faceCount > 0 {
                    let sample = graph.sampleFaceUVGrid(faceIndex: 0, uSamples: 4, vSamples: 4)
                    if let sample {
                        #expect(sample.positions.count == 16)
                        // Sphere: non-zero curvature at most points (some may be undefined at poles)
                        var nonZeroCount = 0
                        for k in sample.gaussianCurvatures {
                            if abs(k) > 1e-6 { nonZeroCount += 1 }
                        }
                        #expect(nonZeroCount > 0)
                    }
                }
            }
        }
    }

    @Test func sampleSinglePoint() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                let sample = graph.sampleFaceUVGrid(faceIndex: 0, uSamples: 1, vSamples: 1)
                #expect(sample != nil)
                if let sample {
                    #expect(sample.positions.count == 1)
                }
            }
        }
    }

    @Test func sampleInvalidFace() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                let sample = graph.sampleFaceUVGrid(faceIndex: 999, uSamples: 5, vSamples: 5)
                #expect(sample == nil)
            }
        }
    }

    @Test func sampleZeroCounts() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                let sample = graph.sampleFaceUVGrid(faceIndex: 0, uSamples: 0, vSamples: 5)
                #expect(sample == nil)
            }
        }
    }
}
