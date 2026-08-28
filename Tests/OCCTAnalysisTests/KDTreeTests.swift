import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("KD-Tree Spatial Queries")
struct KDTreeTests {

    let testPoints: [SIMD3<Double>] = [
        SIMD3(0, 0, 0),  // 0
        SIMD3(1, 0, 0),  // 1
        SIMD3(0, 1, 0),  // 2
        SIMD3(0, 0, 1),  // 3
        SIMD3(1, 1, 1),  // 4
        SIMD3(5, 5, 5),  // 5
        SIMD3(10, 10, 10),  // 6
    ]

    @Test("Build KD-tree")
    func buildTree() {
        let tree = KDTree(points: testPoints)
        #expect(tree != nil)
    }

    @Test("Empty points returns nil")
    func emptyTree() {
        let tree = KDTree(points: [])
        #expect(tree == nil)
    }

    @Test("Nearest point - exact match")
    func nearestExact() {
        let tree = KDTree(points: testPoints)!
        let result = tree.nearest(to: SIMD3(0, 0, 0))
        #expect(result != nil)
        #expect(result!.index == 0)
        #expect(result!.distance < 1e-10)
    }

    @Test("Nearest point - closest to query")
    func nearestClosest() {
        let tree = KDTree(points: testPoints)!
        let result = tree.nearest(to: SIMD3(0.9, 0.1, 0.1))
        #expect(result != nil)
        #expect(result!.index == 1)  // Closest to (1,0,0)
    }

    @Test("K-nearest returns correct count")
    func kNearestCount() {
        let tree = KDTree(points: testPoints)!
        let results = tree.kNearest(to: SIMD3(0, 0, 0), k: 3)
        #expect(results.count == 3)
    }

    @Test("K-nearest includes self when exact")
    func kNearestSelf() {
        let tree = KDTree(points: testPoints)!
        let results = tree.kNearest(to: SIMD3(0, 0, 0), k: 1)
        #expect(results.count == 1)
        #expect(results[0].index == 0)
        #expect(results[0].squaredDistance < 1e-10)
    }

    @Test("K larger than point count returns all")
    func kNearestAll() {
        let tree = KDTree(points: testPoints)!
        let results = tree.kNearest(to: .zero, k: 100)
        #expect(results.count == testPoints.count)
    }

    @Test("Range search - finds nearby points")
    func rangeSearch() {
        let tree = KDTree(points: testPoints)!
        // Points within distance 1.1 of origin: (0,0,0), (1,0,0), (0,1,0), (0,0,1)
        let results = tree.rangeSearch(center: .zero, radius: 1.1)
        #expect(results.count == 4)
        #expect(results.contains(0))
        #expect(results.contains(1))
        #expect(results.contains(2))
        #expect(results.contains(3))
    }

    @Test("Range search - small radius finds only nearest")
    func rangeSearchSmall() {
        let tree = KDTree(points: testPoints)!
        let results = tree.rangeSearch(center: .zero, radius: 0.1)
        #expect(results.count == 1)
        #expect(results[0] == 0)
    }

    @Test("Box search - finds points in AABB")
    func boxSearch() {
        let tree = KDTree(points: testPoints)!
        let results = tree.boxSearch(
            min: SIMD3(-0.5, -0.5, -0.5),
            max: SIMD3(1.5, 1.5, 1.5)
        )
        // Should find: (0,0,0), (1,0,0), (0,1,0), (0,0,1), (1,1,1)
        #expect(results.count == 5)
        #expect(!results.contains(5))  // (5,5,5) outside
        #expect(!results.contains(6))  // (10,10,10) outside
    }

    @Test("Box search - entire space")
    func boxSearchAll() {
        let tree = KDTree(points: testPoints)!
        let results = tree.boxSearch(
            min: SIMD3(-100, -100, -100),
            max: SIMD3(100, 100, 100)
        )
        #expect(results.count == testPoints.count)
    }

    @Test("Large point set performance")
    func largePointSet() {
        var points: [SIMD3<Double>] = []
        for i in 0..<1000 {
            let x = Double(i % 10)
            let y = Double((i / 10) % 10)
            let z = Double(i / 100)
            points.append(SIMD3(x, y, z))
        }
        let tree = KDTree(points: points)
        #expect(tree != nil)

        let result = tree!.nearest(to: SIMD3(4.5, 4.5, 4.5))
        #expect(result != nil)
    }
}
