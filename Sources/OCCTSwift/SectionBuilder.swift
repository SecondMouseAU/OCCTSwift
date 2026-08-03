import Foundation
import simd
import OCCTBridge

/// A builder for computing sections (intersections) between shapes, planes, and surfaces.
/// Allows fine-grained control over approximation and PCurve computation.
public final class SectionBuilder: @unchecked Sendable {
    let handle: OCCTSectionBuilderRef

    /// Create an empty section builder. Use init1/init2 to set arguments.
    public init?() {
        guard let ref = OCCTSectionBuilderCreate() else { return nil }
        self.handle = ref
    }

    /// Create a section builder from two shapes.
    public init?(shape1: Shape, shape2: Shape) {
        guard let ref = OCCTSectionBuilderCreateFromShapes(shape1.handle, shape2.handle) else { return nil }
        self.handle = ref
    }

    deinit { OCCTSectionBuilderRelease(handle) }

    /// Set the first argument as a shape.
    public func init1(shape: Shape) {
        OCCTSectionBuilderInit1Shape(handle, shape.handle)
    }

    /// Set the first argument as a plane (ax + by + cz + d = 0).
    public func init1(plane a: Double, _ b: Double, _ c: Double, _ d: Double) {
        OCCTSectionBuilderInit1Plane(handle, a, b, c, d)
    }

    /// Set the first argument as a surface.
    public func init1(surface: Surface) {
        OCCTSectionBuilderInit1Surface(handle, surface.handle)
    }

    /// Set the second argument as a shape.
    public func init2(shape: Shape) {
        OCCTSectionBuilderInit2Shape(handle, shape.handle)
    }

    /// Set the second argument as a plane (ax + by + cz + d = 0).
    public func init2(plane a: Double, _ b: Double, _ c: Double, _ d: Double) {
        OCCTSectionBuilderInit2Plane(handle, a, b, c, d)
    }

    /// Set the second argument as a surface.
    public func init2(surface: Surface) {
        OCCTSectionBuilderInit2Surface(handle, surface.handle)
    }

    /// Toggle curve approximation (default: false).
    public func setApproximation(_ enabled: Bool) {
        OCCTSectionBuilderSetApproximation(handle, enabled)
    }

    /// Toggle computation of PCurves on the first shape.
    public func computePCurveOn1(_ enabled: Bool) {
        OCCTSectionBuilderComputePCurveOn1(handle, enabled)
    }

    /// Toggle computation of PCurves on the second shape.
    public func computePCurveOn2(_ enabled: Bool) {
        OCCTSectionBuilderComputePCurveOn2(handle, enabled)
    }

    /// Build the section. Returns the result shape, or nil on failure.
    public func build() -> Shape? {
        guard let ref = OCCTSectionBuilderBuild(handle) else { return nil }
        return Shape(handle: ref)
    }

    /// Get the ancestor face on the first shape for a section edge. Returns nil if none.
    public func ancestorFaceOn1(edge: Shape) -> Shape? {
        guard let ref = OCCTSectionBuilderAncestorFaceOn1(handle, edge.handle) else { return nil }
        return Shape(handle: ref)
    }

    /// Get the ancestor face on the second shape for a section edge. Returns nil if none.
    public func ancestorFaceOn2(edge: Shape) -> Shape? {
        guard let ref = OCCTSectionBuilderAncestorFaceOn2(handle, edge.handle) else { return nil }
        return Shape(handle: ref)
    }
}
