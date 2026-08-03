import Foundation
import simd
import OCCTBridge

/// Builder for lofted shapes through multiple wire sections.
public final class ThruSectionsBuilder: @unchecked Sendable {
    internal let ref: OCCTThruSectionsRef

    /// Create a ThruSections builder.
    /// - Parameters:
    ///   - isSolid: Whether to create a solid (true) or shell (false)
    ///   - isRuled: Whether to use ruled surfaces
    ///   - precision: 3D tolerance
    public init(isSolid: Bool = true, isRuled: Bool = false, precision: Double = 1e-6) {
        ref = OCCTThruSectionsCreate(isSolid, isRuled, precision)
    }

    deinit {
        OCCTThruSectionsRelease(ref)
    }

    /// Add a wire profile.
    public func addWire(_ wire: Shape) {
        OCCTThruSectionsAddWire(ref, wire.handle)
    }

    /// Add a vertex (point) as a degenerate section.
    public func addVertex(_ vertex: Shape) {
        OCCTThruSectionsAddVertex(ref, vertex.handle)
    }

    /// Enable/disable smoothing.
    public func setSmoothing(_ smoothing: Bool) {
        OCCTThruSectionsSetSmoothing(ref, smoothing)
    }

    /// Set the maximum BSpline degree.
    public func setMaxDegree(_ maxDeg: Int) {
        OCCTThruSectionsSetMaxDegree(ref, Int32(maxDeg))
    }

    /// Set the continuity criterion for the lofted surface.
    ///
    /// A ``ParametricContinuity`` raw value (0=C0, 1=C1, 2=C2, 3=C3; anything above asks for CN).
    /// `BRepOffsetAPI_ThruSections` accepts every value without failing. This used to read only
    /// 0 and 1, mapping everything else to C2 (#490).
    public func setContinuity(_ continuity: Int) {
        OCCTThruSectionsSetContinuity(ref, Int32(continuity))
    }

    /// Build the lofted shape.
    @discardableResult
    public func build() -> Bool {
        OCCTThruSectionsBuild(ref)
    }

    /// Get the result shape.
    public var shape: Shape? {
        guard let h = OCCTThruSectionsShape(ref) else { return nil }
        return Shape(handle: h)
    }
}
