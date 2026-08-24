import Foundation
import OCCTBridge
import simd

/// A KD-tree for fast spatial queries on 3D point sets.
///
/// `KDTree` wraps OCCT's `NCollection_KDTree` to provide efficient
/// nearest-neighbor, k-nearest, range, and box queries.
///
/// ## Example
///
/// ```swift
/// let points: [SIMD3<Double>] = [
///     SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(0, 1, 0),
///     SIMD3(1, 1, 0), SIMD3(0.5, 0.5, 0)
/// ]
/// let tree = KDTree(points: points)!
///
/// // Find nearest point to a query
/// let (index, distance) = tree.nearest(to: SIMD3(0.4, 0.4, 0))!
///
/// // Find 3 nearest points
/// let neighbors = tree.kNearest(to: SIMD3(0.5, 0.5, 0), k: 3)
///
/// // Find all points within radius 1.0
/// let nearby = tree.rangeSearch(center: .zero, radius: 1.0)
/// ```
public final class KDTree: @unchecked Sendable {
    internal let handle: OCCTKDTreeRef

    /// Build a KD-tree from an array of 3D points.
    ///
    /// - Parameter points: The points to index
    public init?(points: [SIMD3<Double>]) {
        guard !points.isEmpty else { return nil }
        let coords = points.flatMap { [$0.x, $0.y, $0.z] }
        guard let h = OCCTKDTreeBuild(coords, Int32(points.count)) else { return nil }
        self.handle = h
    }

    deinit {
        OCCTKDTreeRelease(handle)
    }

    // MARK: - Queries

    /// Find the nearest point to a query location.
    ///
    /// - Parameter point: The query point
    /// - Returns: A tuple of (0-based index, distance) or nil on error
    public func nearest(to point: SIMD3<Double>) -> (index: Int, distance: Double)? {
        var distance: Double = 0
        let idx = OCCTKDTreeNearestPoint(handle, point.x, point.y, point.z, &distance)
        guard idx >= 0 else { return nil }
        return (Int(idx), distance)
    }

    /// Find the K nearest points to a query location.
    ///
    /// - Parameters:
    ///   - point: The query point
    ///   - k: Output *capacity*, clamped into `0...` ``Sampling/maximumSampleCount``; 0 or less
    ///     returns empty (#622). Fewer than `k` come back when the tree holds fewer points.
    /// - Returns: Array of (0-based index, squared distance) tuples, sorted by distance
    public func kNearest(to point: SIMD3<Double>, k: Int) -> [(index: Int, squaredDistance: Double)]
    {
        let k = Sampling.capacity(k)
        guard k > 0 else { return [] }
        var indices = [Int32](repeating: 0, count: k)
        var sqDists = [Double](repeating: 0, count: k)
        let n = Int(
            OCCTKDTreeKNearest(
                handle, point.x, point.y, point.z,
                Int32(k), &indices, &sqDists))
        return (0..<n).map { (Int(indices[$0]), sqDists[$0]) }
    }

    /// Find all points within a sphere.
    ///
    /// - Parameters:
    ///   - center: Center of the search sphere
    ///   - radius: Radius of the search sphere
    ///   - maxResults: Output *capacity* (default: 1000), clamped into `0...`
    ///     ``Sampling/maximumSampleCount``; 0 or less returns empty (#622).
    /// - Returns: Array of 0-based indices of points within the sphere
    public func rangeSearch(center: SIMD3<Double>, radius: Double, maxResults: Int = 1000) -> [Int]
    {
        let maxResults = Sampling.capacity(maxResults)
        guard radius > 0, maxResults > 0 else { return [] }
        var indices = [Int32](repeating: 0, count: maxResults)
        let n = Int(
            OCCTKDTreeRangeSearch(
                handle, center.x, center.y, center.z,
                radius, &indices, Int32(maxResults)))
        return (0..<n).map { Int(indices[$0]) }
    }

    /// Find all points within an axis-aligned bounding box.
    ///
    /// - Parameters:
    ///   - min: Minimum corner of the box
    ///   - max: Maximum corner of the box
    ///   - maxResults: Output *capacity* (default: 1000), clamped into `0...`
    ///     ``Sampling/maximumSampleCount``; 0 or less returns empty (#622).
    /// - Returns: Array of 0-based indices of points within the box
    public func boxSearch(min: SIMD3<Double>, max: SIMD3<Double>, maxResults: Int = 1000) -> [Int] {
        let maxResults = Sampling.capacity(maxResults)
        guard maxResults > 0 else { return [] }
        var indices = [Int32](repeating: 0, count: maxResults)
        let n = Int(
            OCCTKDTreeBoxSearch(
                handle, min.x, min.y, min.z,
                max.x, max.y, max.z,
                &indices, Int32(maxResults)))
        return (0..<n).map { Int(indices[$0]) }
    }
}
