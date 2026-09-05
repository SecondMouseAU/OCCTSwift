import Foundation
import OCCTBridge

/// A thin plate spline solver for surface deformation.
///
/// `PlateSolver` provides direct access to the OCCT `Plate_Plate` variational
/// solver. It computes a smooth displacement field that passes through a set
/// of pinpoint constraints (position and/or derivative) while minimizing bending energy.
///
/// Unlike the higher-level NLPlate methods on `Surface`, `PlateSolver` works
/// directly in the UV parameter space and returns raw XYZ displacements.
///
/// Usage:
/// ```swift
/// let solver = PlateSolver()
/// solver.loadPinpoint(u: 0, v: 0, position: .zero)
/// solver.loadPinpoint(u: 1, v: 0, position: SIMD3(1, 0, 0))
/// solver.loadPinpoint(u: 0.5, v: 0.5, position: SIMD3(0.5, 0.5, 1.0))
/// if solver.solve() {
///     let point = solver.evaluate(u: 0.5, v: 0.5)
/// }
/// ```
public final class PlateSolver: @unchecked Sendable {
    internal let handle: OCCTPlateRef

    /// Create a new Plate solver.
    public init() {
        self.handle = OCCTPlateCreate()!
    }

    deinit {
        OCCTPlateRelease(handle)
    }

    // MARK: - Loading Constraints

    /// Load a pinpoint constraint (position at a UV point).
    ///
    /// - Parameters:
    ///   - u: U parameter
    ///   - v: V parameter
    ///   - position: Target 3D position
    public func loadPinpoint(u: Double, v: Double, position: SIMD3<Double>) {
        OCCTPlateLoadPinpoint(handle, u, v, position.x, position.y, position.z, 0, 0)
    }

    /// Load a derivative constraint at a UV point.
    ///
    /// - Parameters:
    ///   - u: U parameter
    ///   - v: V parameter
    ///   - value: Target derivative value
    ///   - derivativeOrderU: U derivative order (0 for position, 1+ for derivatives)
    ///   - derivativeOrderV: V derivative order
    public func loadDerivativeConstraint(
        u: Double, v: Double, value: SIMD3<Double>,
        derivativeOrderU: Int, derivativeOrderV: Int
    ) {
        OCCTPlateLoadPinpoint(
            handle, u, v, value.x, value.y, value.z,
            Int32(derivativeOrderU), Int32(derivativeOrderV))
    }

    /// Load a geometric-to-continuity (GtoC) constraint at G1 level.
    ///
    /// Constrains the surface derivatives to transition from one tangent frame
    /// to another at a given UV point.
    ///
    /// - Parameters:
    ///   - u: U parameter
    ///   - v: V parameter
    ///   - sourceD1: Source surface first derivatives (tangentU, tangentV) as flat 6 doubles
    ///   - targetD1: Target surface first derivatives
    public func loadGtoC(
        u: Double, v: Double,
        sourceD1: (tangentU: SIMD3<Double>, tangentV: SIMD3<Double>),
        targetD1: (tangentU: SIMD3<Double>, tangentV: SIMD3<Double>)
    ) {
        var d1s: [Double] = [
            sourceD1.tangentU.x, sourceD1.tangentU.y, sourceD1.tangentU.z,
            sourceD1.tangentV.x, sourceD1.tangentV.y, sourceD1.tangentV.z,
        ]
        var d1t: [Double] = [
            targetD1.tangentU.x, targetD1.tangentU.y, targetD1.tangentU.z,
            targetD1.tangentV.x, targetD1.tangentV.y, targetD1.tangentV.z,
        ]
        OCCTPlateLoadGtoC(handle, u, v, &d1s, &d1t)
    }

    // MARK: - Solving

    /// Solve the plate system.
    ///
    /// - Parameters:
    ///   - order: Solution polynomial order (default 4)
    ///   - anisotropy: Anisotropy parameter (default 1.0)
    /// - Returns: true if solve succeeded
    @discardableResult
    public func solve(order: Int = 4, anisotropy: Double = 1.0) -> Bool {
        OCCTPlateSolve(handle, Int32(order), anisotropy)
    }

    /// Check if the last solve succeeded.
    public var isDone: Bool {
        OCCTPlateIsDone(handle)
    }

    // MARK: - Evaluation

    /// Evaluate the plate at a UV point.
    ///
    /// Returns the 3D displacement/position computed by the solver.
    /// Must call `solve()` first.
    public func evaluate(u: Double, v: Double) -> SIMD3<Double> {
        var x: Double = 0
        var y: Double = 0
        var z: Double = 0
        OCCTPlateEvaluate(handle, u, v, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Evaluate a derivative at a UV point.
    ///
    /// - Parameters:
    ///   - u: U parameter
    ///   - v: V parameter
    ///   - derivativeOrderU: U derivative order
    ///   - derivativeOrderV: V derivative order
    /// - Returns: The derivative vector at the given UV parameters.
    public func evaluateDerivative(
        u: Double, v: Double,
        derivativeOrderU: Int, derivativeOrderV: Int
    ) -> SIMD3<Double> {
        var x: Double = 0
        var y: Double = 0
        var z: Double = 0
        OCCTPlateEvaluateDerivative(
            handle, u, v, Int32(derivativeOrderU), Int32(derivativeOrderV),
            &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// UV bounding box of the constraint points.
    public var uvBox: (umin: Double, umax: Double, vmin: Double, vmax: Double) {
        var umin: Double = 0
        var umax: Double = 0
        var vmin: Double = 0
        var vmax: Double = 0
        OCCTPlateUVBox(handle, &umin, &umax, &vmin, &vmax)
        return (umin, umax, vmin, vmax)
    }

    /// Continuity order of the plate solution.
    public var continuity: Int {
        Int(OCCTPlateContinuity(handle))
    }
}

extension PlateSolver {
    /// Load a plane constraint at UV point.
    @discardableResult
    public func loadPlaneConstraint(
        u: Double, v: Double, planePoint: SIMD3<Double>, planeNormal: SIMD3<Double>
    ) -> Bool {
        OCCTPlateLoadPlaneConstraint(
            handle, u, v,
            planePoint.x, planePoint.y, planePoint.z,
            planeNormal.x, planeNormal.y, planeNormal.z)
    }

    /// Load a line constraint at UV point.
    @discardableResult
    public func loadLineConstraint(
        u: Double, v: Double, linePoint: SIMD3<Double>, lineDirection: SIMD3<Double>
    ) -> Bool {
        OCCTPlateLoadLineConstraint(
            handle, u, v,
            linePoint.x, linePoint.y, linePoint.z,
            lineDirection.x, lineDirection.y, lineDirection.z)
    }

    /// Load a free G1 continuity constraint at UV point.
    @discardableResult
    public func loadFreeG1Constraint(u: Double, v: Double, du: SIMD3<Double>, dv: SIMD3<Double>)
        -> Bool
    {
        OCCTPlateLoadFreeG1Constraint(handle, u, v, du.x, du.y, du.z, dv.x, dv.y, dv.z)
    }
}

extension PlateSolver {

    /// Load a global translation constraint.
    ///
    /// All sample points are constrained to translate by the same unknown displacement.
    @discardableResult
    public func loadGlobalTranslation(uvPoints: [SIMD2<Double>]) -> Bool {
        let uvs = uvPoints.flatMap { [$0.x, $0.y] }
        return OCCTPlateLoadGlobalTranslation(handle, uvs, Int32(uvPoints.count))
    }

    /// Load a linear XYZ constraint.
    ///
    /// `targets` and `coefficients` must each have exactly as many elements as `uvPoints`; a
    /// mismatch is rejected (returns `false`) rather than read past the shorter array's end (#1583).
    @discardableResult
    public func loadLinearXYZ(
        uvPoints: [SIMD2<Double>],
        targets: [SIMD3<Double>],
        coefficients: [Double]
    ) -> Bool {
        guard targets.count == uvPoints.count, coefficients.count == uvPoints.count else {
            return false
        }
        let uvs = uvPoints.flatMap { [$0.x, $0.y] }
        let tgts = targets.flatMap { [$0.x, $0.y, $0.z] }
        return OCCTPlateLoadLinearXYZ(handle, uvs, tgts, coefficients, Int32(uvPoints.count))
    }
}
