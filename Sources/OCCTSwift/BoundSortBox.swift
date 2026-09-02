import Foundation
import OCCTBridge
import simd

/// Spatial bounding box sort for fast intersection queries.
public final class BoundSortBox: @unchecked Sendable {
    let handle: OCCTBoundSortBoxRef

    /// Create from an array of bounding boxes (each: [xmin,ymin,zmin,xmax,ymax,zmax]).
    public init(boxes: [[Double]]) {
        let flat = boxes.flatMap { $0 }
        handle = flat.withUnsafeBufferPointer { buf in
            OCCTBoundSortBoxCreate(buf.baseAddress!, Int32(boxes.count))
        }
    }

    deinit { OCCTBoundSortBoxRelease(handle) }

    /// Find indices of boxes (0-based, into the array passed to ``init(boxes:)``) that intersect
    /// a query box.
    ///
    /// Count-then-fill: an unbounded, size-then-allocate call, so no truncation is possible
    /// regardless of how many boxes intersect (#1462).
    ///
    /// ```swift
    /// let sorter = BoundSortBox(boxes: [
    ///     [0, 0, 0, 10, 10, 10],
    ///     [50, 50, 50, 60, 60, 60],
    ///     [5, 5, 5, 15, 15, 15],
    /// ])
    /// let hits = sorter.compare(xmin: 8, ymin: 8, zmin: 8, xmax: 12, ymax: 12, zmax: 12)
    /// print(hits.sorted())  // [0, 2]
    /// ```
    public func compare(
        xmin: Double, ymin: Double, zmin: Double,
        xmax: Double, ymax: Double, zmax: Double
    ) -> [Int] {
        let total = OCCTBoundSortBoxCompare(handle, xmin, ymin, zmin, xmax, ymax, zmax, nil, 0)
        guard total > 0 else { return [] }
        var indices = [Int32](repeating: 0, count: Int(total))
        let actual = indices.withUnsafeMutableBufferPointer { buf in
            OCCTBoundSortBoxCompare(
                handle, xmin, ymin, zmin, xmax, ymax, zmax, buf.baseAddress!, total)
        }
        return indices.prefix(Int(actual)).map { Int($0) }
    }
}
