import Foundation
import Testing

@testable import OCCTSwift

// MARK: - v0.42.0: Point Cloud Analysis

@Suite("Point Cloud Analysis")
struct PointCloudAnalysisTests {
    @Test("Coincident points detected as point")
    func coincidentPoints() {
        let result = Shape.analyzePointCloud([
            SIMD3(5, 5, 5), SIMD3(5, 5, 5), SIMD3(5, 5, 5),
        ])
        #expect(result != nil)
        if case .point(let pt) = result {
            #expect(abs(pt.x - 5.0) < 0.1)
            #expect(abs(pt.y - 5.0) < 0.1)
            #expect(abs(pt.z - 5.0) < 0.1)
        } else {
            #expect(Bool(false), "Expected .point")
        }
    }

    @Test("Collinear points detected as linear")
    func collinearPoints() {
        let result = Shape.analyzePointCloud([
            SIMD3(0, 0, 0), SIMD3(5, 0, 0), SIMD3(10, 0, 0),
        ])
        #expect(result != nil)
        if case .linear(let origin, let dir) = result {
            // Direction should be along X axis
            #expect(abs(abs(dir.x) - 1.0) < 0.01)
            #expect(abs(dir.y) < 0.01)
            #expect(abs(dir.z) < 0.01)
            _ = origin  // used
        } else {
            #expect(Bool(false), "Expected .linear")
        }
    }

    @Test("Coplanar points detected as planar")
    func coplanarPoints() {
        let result = Shape.analyzePointCloud([
            SIMD3(0, 0, 0), SIMD3(10, 0, 0),
            SIMD3(10, 10, 0), SIMD3(0, 10, 0),
        ])
        #expect(result != nil)
        if case .planar(_, let normal) = result {
            // Normal should be along Z axis
            #expect(abs(abs(normal.z) - 1.0) < 0.01)
        } else {
            #expect(Bool(false), "Expected .planar")
        }
    }

    @Test("3D dispersed points detected as space")
    func spacePoints() {
        let result = Shape.analyzePointCloud([
            SIMD3(0, 0, 0), SIMD3(10, 0, 0),
            SIMD3(0, 10, 0), SIMD3(0, 0, 10),
        ])
        // The origin and the three axis points are not coplanar: the fourth leaves the plane
        // through the other three.
        guard case .space = result else {
            Issue.record("Expected .space, got \(String(describing: result))")
            return
        }

        // The same four points with the last one moved into the z = 0 plane become planar, so
        // `.space` is a real answer and not the default.
        let flat = Shape.analyzePointCloud([
            SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(0, 10, 0), SIMD3(10, 10, 0),
        ])
        if case .planar(_, let normal) = flat {
            #expect(abs(abs(normal.z) - 1.0) < 1e-9)
        } else {
            Issue.record("Expected .planar, got \(String(describing: flat))")
        }
    }

    @Test("Empty points returns nil")
    func emptyReturnsNil() {
        let result = Shape.analyzePointCloud([])
        #expect(result == nil)
    }

    @Test("Single point detected as point")
    func singlePoint() {
        let result = Shape.analyzePointCloud([SIMD3(3, 4, 5)])
        #expect(result != nil)
        if case .point(let pt) = result {
            #expect(abs(pt.x - 3.0) < 0.1)
        } else {
            #expect(Bool(false), "Expected .point")
        }
    }
}
