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

    /// Find indices of boxes that intersect a query box.
    public func compare(
        xmin: Double, ymin: Double, zmin: Double,
        xmax: Double, ymax: Double, zmax: Double
    ) -> [Int] {
        var indices = [Int32](repeating: 0, count: 1000)
        let count = indices.withUnsafeMutableBufferPointer { buf in
            OCCTBoundSortBoxCompare(
                handle, xmin, ymin, zmin, xmax, ymax, zmax, buf.baseAddress!, 1000)
        }
        return Array(indices.prefix(Int(count))).map { Int($0) }
    }
}
