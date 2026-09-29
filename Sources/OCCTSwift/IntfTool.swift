import Foundation
import OCCTBridge
import simd

/// Line-box clipping using Intf_Tool.
public final class IntfTool: @unchecked Sendable {
    internal let handle: OCCTIntfToolRef

    public init() {
        self.handle = OCCTIntfToolCreate()
    }

    deinit { OCCTIntfToolRelease(handle) }

    /// Clip a line to a bounding box.
    ///
    /// Returns number of segments.
    ///
    /// ```swift
    /// let tool = IntfTool()
    /// let count = tool.clipLineToBox(
    ///     lineOrigin: SIMD3(-10, 0.5, 0.5), lineDirection: SIMD3(1, 0, 0),
    ///     boxMin: SIMD3(0, 0, 0), boxMax: SIMD3(1, 1, 1))
    /// // count == 1, and tool.segmentCount agrees
    /// ```
    @discardableResult
    public func clipLineToBox(
        lineOrigin: SIMD3<Double>, lineDirection: SIMD3<Double>,
        boxMin: SIMD3<Double>, boxMax: SIMD3<Double>
    ) -> Int {
        Int(
            OCCTIntfToolLinBox(
                handle,
                lineOrigin.x, lineOrigin.y, lineOrigin.z,
                lineDirection.x, lineDirection.y, lineDirection.z,
                boxMin.x, boxMin.y, boxMin.z,
                boxMax.x, boxMax.y, boxMax.z))
    }

    /// The number of clipped segments currently held, and therefore the upper bound on the
    /// 1-based index ``beginParam(segment:)`` and ``endParam(segment:)`` accept.
    ///
    /// `0` before any clip, and `0` for a line that misses the box. This wraps
    /// `Intf_Tool::NbSegments()`, which had no wrapper at all until #2857: the only way to learn the
    /// valid range was ``clipLineToBox(lineOrigin:lineDirection:boxMin:boxMax:)``'s
    /// `@discardableResult` return value, so a caller who discarded it, or who asked for a parameter
    /// before clipping anything, had no signal.
    ///
    /// ```swift
    /// let tool = IntfTool()
    /// tool.segmentCount   // 0, nothing clipped yet
    /// tool.clipLineToBox(
    ///     lineOrigin: SIMD3(-10, 0.5, 0.5), lineDirection: SIMD3(1, 0, 0),
    ///     boxMin: SIMD3(0, 0, 0), boxMax: SIMD3(1, 1, 1))
    /// tool.segmentCount   // 1
    /// ```
    public var segmentCount: Int { Int(OCCTIntfToolNbSegments(handle)) }

    /// The begin parameter of a segment, 1-based, or `nil` when `segment` is outside
    /// `1...segmentCount`.
    ///
    /// `nil` rather than a `Double`, because every value in range is a legitimate curve parameter
    /// and no number could mean "that segment does not exist". `Intf_Tool::BeginParam` indexes a raw
    /// `double[6]` member behind a `Standard_OutOfRange_Raise_if` that sits in `Intf_Tool.cxx` and is
    /// compiled out of the kernel this package ships, and a C array has no container underneath whose
    /// own check could survive, so until #2857 the index was unchecked at every level: on a clip with
    /// one segment, `segment: 7` returned `endOnCurve[0]`, the genuine **end** parameter of segment 1,
    /// as the **begin** parameter of a segment that does not exist, and a large index was a SIGBUS.
    ///
    /// ```swift
    /// let tool = IntfTool()
    /// tool.clipLineToBox(
    ///     lineOrigin: SIMD3(-10, 0.5, 0.5), lineDirection: SIMD3(1, 0, 0),
    ///     boxMin: SIMD3(0, 0, 0), boxMax: SIMD3(1, 1, 1))
    /// tool.beginParam(segment: 1)   // 10.0
    /// tool.beginParam(segment: 7)   // nil, and no longer 11.0
    /// ```
    public func beginParam(segment: Int) -> Double? {
        guard let index = Int32(exactly: segment) else { return nil }
        var out = 0.0
        guard OCCTIntfToolBeginParam(handle, index, &out) else { return nil }
        return out
    }

    /// The end parameter of a segment, 1-based, or `nil` when `segment` is outside
    /// `1...segmentCount`.
    ///
    /// The same unchecked `double[6]` index as ``beginParam(segment:)``, guarded the same way
    /// (#2857).
    ///
    /// ```swift
    /// let tool = IntfTool()
    /// tool.clipLineToBox(
    ///     lineOrigin: SIMD3(-10, 0.5, 0.5), lineDirection: SIMD3(1, 0, 0),
    ///     boxMin: SIMD3(0, 0, 0), boxMax: SIMD3(1, 1, 1))
    /// tool.endParam(segment: 1)   // 11.0
    /// tool.endParam(segment: 0)   // nil
    /// ```
    public func endParam(segment: Int) -> Double? {
        guard let index = Int32(exactly: segment) else { return nil }
        var out = 0.0
        guard OCCTIntfToolEndParam(handle, index, &out) else { return nil }
        return out
    }
}
