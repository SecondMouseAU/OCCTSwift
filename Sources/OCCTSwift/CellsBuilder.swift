import Foundation
import simd
import OCCTBridge

/// Builder for Boolean cell operations on shapes.
///
/// Partitions input shapes into cells (volumetric fragments), then lets you
/// select which cells to include in the result by material ID, and optionally
/// merge cells that share the same material.
public final class CellsBuilder: @unchecked Sendable {
    internal let handle: OCCTCellsBuilderRef

    /// Create a CellsBuilder from input shapes.
    ///
    /// The shapes are partitioned into cells during construction.
    ///
    /// - Parameter shapes: Input shapes to partition
    /// - Returns: CellsBuilder, or nil on failure
    public init?(shapes: [Shape]) {
        let ptrs = shapes.map { $0.handle as OCCTShapeRef? }
        guard let h = ptrs.withUnsafeBufferPointer({ buf in
            OCCTCellsBuilderCreate(buf.baseAddress, Int32(buf.count))
        }) else { return nil }
        self.handle = h
    }

    deinit {
        OCCTCellsBuilderRelease(handle)
    }

    /// Add all split cells to the result with a material ID.
    ///
    /// - Parameter material: Material ID to assign (default 0)
    public func addAllToResult(material: Int32 = 0) {
        OCCTCellsBuilderAddAllToResult(handle, material)
    }

    /// Remove all cells from the result.
    public func removeAllFromResult() {
        OCCTCellsBuilderRemoveAllFromResult(handle)
    }

    /// Remove internal boundaries between cells with the same material.
    ///
    /// Merges adjacent cells that share the same material ID.
    public func removeInternalBoundaries() {
        OCCTCellsBuilderRemoveInternalBoundaries(handle)
    }

    /// Get the current result shape.
    ///
    /// - Returns: Result shape, or nil if empty
    public func result() -> Shape? {
        guard let h = OCCTCellsBuilderGetResult(handle) else { return nil }
        return Shape(handle: h)
    }
}
