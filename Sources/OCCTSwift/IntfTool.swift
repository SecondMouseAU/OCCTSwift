import Foundation
import simd
import OCCTBridge

/// Line-box clipping using Intf_Tool.
public final class IntfTool: @unchecked Sendable {
    internal let handle: OCCTIntfToolRef

    public init() {
        self.handle = OCCTIntfToolCreate()
    }

    deinit { OCCTIntfToolRelease(handle) }

    /// Clip a line to a bounding box. Returns number of segments.
    @discardableResult
    public func clipLineToBox(
        lineOrigin: SIMD3<Double>, lineDirection: SIMD3<Double>,
        boxMin: SIMD3<Double>, boxMax: SIMD3<Double>
    ) -> Int {
        Int(OCCTIntfToolLinBox(handle,
                               lineOrigin.x, lineOrigin.y, lineOrigin.z,
                               lineDirection.x, lineDirection.y, lineDirection.z,
                               boxMin.x, boxMin.y, boxMin.z,
                               boxMax.x, boxMax.y, boxMax.z))
    }

    /// Get the begin parameter of a segment (1-based index).
    public func beginParam(segment: Int) -> Double {
        OCCTIntfToolBeginParam(handle, Int32(segment))
    }

    /// Get the end parameter of a segment (1-based index).
    public func endParam(segment: Int) -> Double {
        OCCTIntfToolEndParam(handle, Int32(segment))
    }
}
