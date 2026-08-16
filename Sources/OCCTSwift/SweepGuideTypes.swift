import Foundation
import OCCTBridge
import simd

/// Shared marshaling for `GuideTrihedronAC.evaluate`/`GuideTrihedronPlan.evaluate`: both call a
/// bridge `D0` function of the same `(ref, param, 9x double*) -> Bool` shape and pack the same
/// tangent/normal/binormal triple, differing only in which bridge function they call (#796).
///
/// Returns a bare, unlabeled tuple, not `(tangent:, normal:, binormal:)`, so both callers' own
/// declared return types supply whatever labels they want directly, the same reasoning
/// `unwrapAxisComponents(_:)` (`ShapeAxis.swift`) was given in #903/#904 (#908): a labeled source
/// tuple does not implicitly convert into a differently-labeled destination, even when every
/// caller today happens to agree on the same labels.
private func evaluateGuideTrihedronD0<Ref>(
    _ ref: Ref, param: Double,
    using d0: (
        Ref, Double,
        UnsafeMutablePointer<Double>, UnsafeMutablePointer<Double>, UnsafeMutablePointer<Double>,
        UnsafeMutablePointer<Double>, UnsafeMutablePointer<Double>, UnsafeMutablePointer<Double>,
        UnsafeMutablePointer<Double>, UnsafeMutablePointer<Double>, UnsafeMutablePointer<Double>
    ) -> Bool
) -> (SIMD3<Double>, SIMD3<Double>, SIMD3<Double>)? {
    var tx = 0.0
    var ty = 0.0
    var tz = 0.0
    var nx = 0.0
    var ny = 0.0
    var nz = 0.0
    var bx = 0.0
    var by = 0.0
    var bz = 0.0
    guard d0(ref, param, &tx, &ty, &tz, &nx, &ny, &nz, &bx, &by, &bz) else { return nil }
    return (SIMD3(tx, ty, tz), SIMD3(nx, ny, nz), SIMD3(bx, by, bz))
}

/// Draft angle location law for sweep operations.
public final class LocationDraft: @unchecked Sendable {
    let handle: OCCTLocationDraftRef

    init(handle: OCCTLocationDraftRef) {
        self.handle = handle
    }

    deinit {
        OCCTGeomFillLocationDraftRelease(handle)
    }

    /// Create a location draft with given direction and angle (radians).
    public static func create(direction: SIMD3<Double>, angle: Double) -> LocationDraft {
        let ref = OCCTGeomFillLocationDraftCreate(direction.x, direction.y, direction.z, angle)!
        return LocationDraft(handle: ref)
    }

    /// Set the sweep path curve.
    ///
    /// Returns true on success.
    @discardableResult
    public func setCurve(_ curve: Curve3D) -> Bool {
        OCCTGeomFillLocationDraftSetCurve(handle, curve.handle)
    }

    /// Evaluate the frame at a parameter.
    ///
    /// Returns (matrix3x3, translation) or nil.
    public func evaluate(at param: Double) -> (matrix: [Double], translation: SIMD3<Double>)? {
        var mat = [Double](repeating: 0, count: 9)
        var vx = 0.0
        var vy = 0.0
        var vz = 0.0
        guard OCCTGeomFillLocationDraftD0(handle, param, &mat, &vx, &vy, &vz) else { return nil }
        return (mat, SIMD3(vx, vy, vz))
    }

    /// Set the draft angle (radians).
    public func setAngle(_ angle: Double) {
        OCCTGeomFillLocationDraftSetAngle(handle, angle)
    }

    /// Get the draft direction.
    public var direction: SIMD3<Double> {
        var x = 0.0
        var y = 0.0
        var z = 0.0
        OCCTGeomFillLocationDraftDirection(handle, &x, &y, &z)
        return SIMD3(x, y, z)
    }
}

/// Arc-length corrected guide trihedron for sweep operations.
public final class GuideTrihedronAC: @unchecked Sendable {
    let handle: OCCTGuideTrihedronACRef

    init(handle: OCCTGuideTrihedronACRef) {
        self.handle = handle
    }

    deinit {
        OCCTGeomFillGuideTrihedronACRelease(handle)
    }

    /// Create from a guide curve.
    public static func create(guideCurve: Curve3D) -> GuideTrihedronAC {
        let ref = OCCTGeomFillGuideTrihedronACCreate(guideCurve.handle)!
        return GuideTrihedronAC(handle: ref)
    }

    /// Set the sweep path curve.
    ///
    /// Returns true on success.
    @discardableResult
    public func setCurve(_ curve: Curve3D) -> Bool {
        OCCTGeomFillGuideTrihedronACSetCurve(handle, curve.handle)
    }

    /// Evaluate the trihedron frame at a parameter.
    public func evaluate(at param: Double) -> (
        tangent: SIMD3<Double>, normal: SIMD3<Double>, binormal: SIMD3<Double>
    )? {
        evaluateGuideTrihedronD0(handle, param: param, using: OCCTGeomFillGuideTrihedronACD0)
    }
}

/// Planar guide trihedron for sweep operations.
public final class GuideTrihedronPlan: @unchecked Sendable {
    let handle: OCCTGuideTrihedronPlanRef

    init(handle: OCCTGuideTrihedronPlanRef) {
        self.handle = handle
    }

    deinit {
        OCCTGeomFillGuideTrihedronPlanRelease(handle)
    }

    /// Create from a guide curve.
    public static func create(guideCurve: Curve3D) -> GuideTrihedronPlan {
        let ref = OCCTGeomFillGuideTrihedronPlanCreate(guideCurve.handle)!
        return GuideTrihedronPlan(handle: ref)
    }

    /// Set the sweep path curve.
    ///
    /// Returns true on success.
    @discardableResult
    public func setCurve(_ curve: Curve3D) -> Bool {
        OCCTGeomFillGuideTrihedronPlanSetCurve(handle, curve.handle)
    }

    /// Evaluate the trihedron frame at a parameter.
    public func evaluate(at param: Double) -> (
        tangent: SIMD3<Double>, normal: SIMD3<Double>, binormal: SIMD3<Double>
    )? {
        evaluateGuideTrihedronD0(handle, param: param, using: OCCTGeomFillGuideTrihedronPlanD0)
    }
}

/// N-section law for sweep/loft operations with multiple wire cross-sections.
public final class NSections: @unchecked Sendable {
    let handle: OCCTNSectionsRef

    init(handle: OCCTNSectionsRef) {
        self.handle = handle
    }

    deinit {
        OCCTBRepFillNSectionsRelease(handle)
    }

    /// Create from an array of wire shapes.
    public static func create(wires: [Shape]) -> NSections? {
        let refs = wires.map { $0.handle as OCCTShapeRef }
        return refs.withUnsafeBufferPointer { buf in
            guard let ref = OCCTBRepFillNSectionsCreate(buf.baseAddress!, Int32(wires.count)) else {
                return nil
            }
            return NSections(handle: ref)
        }
    }

    /// Number of section laws.
    public var lawCount: Int { Int(OCCTBRepFillNSectionsNbLaw(handle)) }

    /// Whether the section is constant along the path.
    public var isConstant: Bool { OCCTBRepFillNSectionsIsConstant(handle) }

    /// Whether the section degenerates to a vertex.
    public var isVertex: Bool { OCCTBRepFillNSectionsIsVertex(handle) }
}
