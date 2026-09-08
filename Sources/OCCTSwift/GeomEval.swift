import Foundation
import OCCTBridge
import simd

/// Standalone evaluators for analytical curves and surfaces.
///
/// These evaluate mathematical functions without creating persistent Curve3D/Surface objects.
public enum GeomEval {

    // MARK: 3D Curves

    /// Evaluate a circular helix at parameter u.
    /// C(t) = R*cos(t)*X + R*sin(t)*Y + (P*t/(2*Pi))*Z
    public static func circularHelixD0(radius: Double, pitch: Double, u: Double) -> SIMD3<Double> {
        var px = 0.0
        var py = 0.0
        var pz = 0.0
        OCCTGeomEvalCircularHelixD0(radius, pitch, u, &px, &py, &pz)
        return SIMD3(px, py, pz)
    }

    /// Evaluate circular helix point and first derivative at parameter u.
    public static func circularHelixD1(radius: Double, pitch: Double, u: Double) -> (
        point: SIMD3<Double>, d1: SIMD3<Double>
    ) {
        var px = 0.0
        var py = 0.0
        var pz = 0.0
        var vx = 0.0
        var vy = 0.0
        var vz = 0.0
        OCCTGeomEvalCircularHelixD1(radius, pitch, u, &px, &py, &pz, &vx, &vy, &vz)
        return (SIMD3(px, py, pz), SIMD3(vx, vy, vz))
    }

    /// Evaluate circular helix point, first and second derivatives.
    public static func circularHelixD2(radius: Double, pitch: Double, u: Double) -> (
        point: SIMD3<Double>, d1: SIMD3<Double>, d2: SIMD3<Double>
    ) {
        var px = 0.0
        var py = 0.0
        var pz = 0.0
        var d1x = 0.0
        var d1y = 0.0
        var d1z = 0.0
        var d2x = 0.0
        var d2y = 0.0
        var d2z = 0.0
        OCCTGeomEvalCircularHelixD2(
            radius, pitch, u, &px, &py, &pz, &d1x, &d1y, &d1z, &d2x, &d2y, &d2z)
        return (SIMD3(px, py, pz), SIMD3(d1x, d1y, d1z), SIMD3(d2x, d2y, d2z))
    }

    /// Evaluate a 3D sine wave at parameter u.
    /// C(t) = t*X + A*sin(omega*t + phi)*Y
    public static func sineWaveD0(amplitude: Double, omega: Double, phase: Double, u: Double)
        -> SIMD3<Double>
    {
        var px = 0.0
        var py = 0.0
        var pz = 0.0
        OCCTGeomEvalSineWaveD0(amplitude, omega, phase, u, &px, &py, &pz)
        return SIMD3(px, py, pz)
    }

    /// Evaluate 3D sine wave point and first derivative.
    public static func sineWaveD1(amplitude: Double, omega: Double, phase: Double, u: Double) -> (
        point: SIMD3<Double>, d1: SIMD3<Double>
    ) {
        var px = 0.0
        var py = 0.0
        var pz = 0.0
        var vx = 0.0
        var vy = 0.0
        var vz = 0.0
        OCCTGeomEvalSineWaveD1(amplitude, omega, phase, u, &px, &py, &pz, &vx, &vy, &vz)
        return (SIMD3(px, py, pz), SIMD3(vx, vy, vz))
    }

    // MARK: Surfaces

    /// Evaluate an ellipsoid at (u, v).
    /// P(u,v) = A*cos(v)*cos(u)*X + B*cos(v)*sin(u)*Y + C*sin(v)*Z
    public static func ellipsoidD0(a: Double, b: Double, c: Double, u: Double, v: Double) -> SIMD3<
        Double
    > {
        var px = 0.0
        var py = 0.0
        var pz = 0.0
        OCCTGeomEvalEllipsoidD0(a, b, c, u, v, &px, &py, &pz)
        return SIMD3(px, py, pz)
    }

    /// Evaluate a hyperboloid at (u, v). twoSheets: false = one-sheet, true = two-sheets.
    public static func hyperboloidD0(r1: Double, r2: Double, twoSheets: Bool, u: Double, v: Double)
        -> SIMD3<Double>
    {
        var px = 0.0
        var py = 0.0
        var pz = 0.0
        OCCTGeomEvalHyperboloidD0(r1, r2, twoSheets ? 1 : 0, u, v, &px, &py, &pz)
        return SIMD3(px, py, pz)
    }

    /// Evaluate a paraboloid at (u, v).
    public static func paraboloidD0(focal: Double, u: Double, v: Double) -> SIMD3<Double> {
        var px = 0.0
        var py = 0.0
        var pz = 0.0
        OCCTGeomEvalParaboloidD0(focal, u, v, &px, &py, &pz)
        return SIMD3(px, py, pz)
    }

    /// Evaluate a circular helicoid at (u, v).
    public static func circularHelicoidD0(pitch: Double, u: Double, v: Double) -> SIMD3<Double> {
        var px = 0.0
        var py = 0.0
        var pz = 0.0
        OCCTGeomEvalCircularHelicoidD0(pitch, u, v, &px, &py, &pz)
        return SIMD3(px, py, pz)
    }

    /// Evaluate a hyperbolic paraboloid at (u, v).
    public static func hyperbolicParaboloidD0(a: Double, b: Double, u: Double, v: Double) -> SIMD3<
        Double
    > {
        var px = 0.0
        var py = 0.0
        var pz = 0.0
        OCCTGeomEvalHypParaboloidD0(a, b, u, v, &px, &py, &pz)
        return SIMD3(px, py, pz)
    }
}

/// Standalone evaluators for analytical 2D curves.
///
/// Every method here returns an optional, and `nil` means the call was refused rather than
/// answered (#1646). Three things produce a refusal, and none of them is distinguishable from a
/// real answer in a non-optional return, because the origin is a point these curves legitimately
/// pass through:
///
/// - An argument the underlying OCCT constructor rejects. `Geom2dEval_SineWaveCurve` requires
///   amplitude and omega above zero, `Geom2dEval_CircleInvoluteCurve` a radius above zero,
///   `Geom2dEval_ArchimedeanSpiralCurve` a growth rate above zero and a non-negative initial
///   radius, `Geom2dEval_LogarithmicSpiralCurve` a scale and growth exponent above zero.
/// - A non-finite argument. OCCT's own checks are written as `<= 0`, and every comparison against
///   NaN is false, so a NaN reaches the evaluation and comes back as a NaN point.
/// - A finite argument whose evaluation overflows, such as the logarithmic spiral's `exp(b*t)` at
///   a large `t`.
///
/// ```swift
/// // A well-formed call answers.
/// if let p = Geom2dEval.sineWaveD0(amplitude: 1, omega: 2 * .pi, phase: 0, u: 0.25) {
///     print(p)  // SIMD2(0.25, 1.0)
/// }
///
/// // A zero amplitude is refused, not answered with the origin.
/// let refused = Geom2dEval.sineWaveD0(amplitude: 0, omega: 1, phase: 0, u: 0.5)
/// #expect(refused == nil)
/// ```
public enum Geom2dEval {

    /// Evaluate an Archimedean spiral at parameter u.
    ///
    /// C(t) = (a + b*t)*cos(t)*X + (a + b*t)*sin(t)*Y
    ///
    /// - Parameters:
    ///   - initialRadius: The radius at t = 0. Must be >= 0.
    ///   - growthRate: Radius gained per radian. Must be > 0.
    ///   - u: The parameter value.
    /// - Returns: The evaluated point, or `nil` if the arguments were refused or the evaluation
    ///   was not finite.
    ///
    /// ```swift
    /// if let p = Geom2dEval.archimedeanSpiralD0(initialRadius: 1, growthRate: 0.1, u: 2 * .pi) {
    ///     print(p)
    /// }
    /// ```
    public static func archimedeanSpiralD0(initialRadius: Double, growthRate: Double, u: Double)
        -> SIMD2<Double>?
    {
        var px = 0.0
        var py = 0.0
        guard OCCTGeom2dEvalArchimedeanSpiralD0(initialRadius, growthRate, u, &px, &py) else {
            return nil
        }
        return SIMD2(px, py)
    }

    /// Evaluate Archimedean spiral point and first derivative.
    ///
    /// - Parameters:
    ///   - initialRadius: The radius at t = 0. Must be >= 0.
    ///   - growthRate: Radius gained per radian. Must be > 0.
    ///   - u: The parameter value.
    /// - Returns: The point and its first derivative, or `nil` if the arguments were refused or
    ///   the evaluation was not finite.
    ///
    /// ```swift
    /// if let (p, d1) = Geom2dEval.archimedeanSpiralD1(
    ///     initialRadius: 1, growthRate: 0.1, u: .pi)
    /// {
    ///     print(p, d1)
    /// }
    /// ```
    public static func archimedeanSpiralD1(initialRadius: Double, growthRate: Double, u: Double)
        -> (point: SIMD2<Double>, d1: SIMD2<Double>)?
    {
        var px = 0.0
        var py = 0.0
        var vx = 0.0
        var vy = 0.0
        guard
            OCCTGeom2dEvalArchimedeanSpiralD1(initialRadius, growthRate, u, &px, &py, &vx, &vy)
        else { return nil }
        return (SIMD2(px, py), SIMD2(vx, vy))
    }

    /// Evaluate a logarithmic spiral at parameter u.
    ///
    /// C(t) = a*exp(b*t)*cos(t)*X + a*exp(b*t)*sin(t)*Y
    ///
    /// - Parameters:
    ///   - scale: The radius at t = 0. Must be > 0.
    ///   - growthExponent: The exponent b. Must be > 0.
    ///   - u: The parameter value.
    /// - Returns: The evaluated point, or `nil` if the arguments were refused or the evaluation
    ///   was not finite. `exp(b*t)` overflows for a large enough `u`, and that overflow is a
    ///   refusal here rather than an infinity handed back as a coordinate.
    ///
    /// ```swift
    /// if let p = Geom2dEval.logarithmicSpiralD0(scale: 1, growthExponent: 0.2, u: 2 * .pi) {
    ///     print(p)
    /// }
    /// ```
    public static func logarithmicSpiralD0(scale: Double, growthExponent: Double, u: Double)
        -> SIMD2<Double>?
    {
        var px = 0.0
        var py = 0.0
        guard OCCTGeom2dEvalLogSpiralD0(scale, growthExponent, u, &px, &py) else { return nil }
        return SIMD2(px, py)
    }

    /// Evaluate logarithmic spiral point and first derivative.
    ///
    /// - Parameters:
    ///   - scale: The radius at t = 0. Must be > 0.
    ///   - growthExponent: The exponent b. Must be > 0.
    ///   - u: The parameter value.
    /// - Returns: The point and its first derivative, or `nil` if the arguments were refused or
    ///   the evaluation was not finite.
    ///
    /// ```swift
    /// if let (p, d1) = Geom2dEval.logarithmicSpiralD1(
    ///     scale: 1, growthExponent: 0.2, u: .pi)
    /// {
    ///     print(p, d1)
    /// }
    /// ```
    public static func logarithmicSpiralD1(scale: Double, growthExponent: Double, u: Double)
        -> (point: SIMD2<Double>, d1: SIMD2<Double>)?
    {
        var px = 0.0
        var py = 0.0
        var vx = 0.0
        var vy = 0.0
        guard OCCTGeom2dEvalLogSpiralD1(scale, growthExponent, u, &px, &py, &vx, &vy) else {
            return nil
        }
        return (SIMD2(px, py), SIMD2(vx, vy))
    }

    /// Evaluate a circle involute at parameter u.
    ///
    /// C(t) = R*(cos(t) + t*sin(t))*X + R*(sin(t) - t*cos(t))*Y
    ///
    /// - Parameters:
    ///   - radius: The base circle radius. Must be > 0.
    ///   - u: The parameter value.
    /// - Returns: The evaluated point, or `nil` if the arguments were refused or the evaluation
    ///   was not finite.
    ///
    /// ```swift
    /// if let p = Geom2dEval.circleInvoluteD0(radius: 5, u: 1.0) {
    ///     print(p)
    /// }
    /// ```
    public static func circleInvoluteD0(radius: Double, u: Double) -> SIMD2<Double>? {
        var px = 0.0
        var py = 0.0
        guard OCCTGeom2dEvalCircleInvoluteD0(radius, u, &px, &py) else { return nil }
        return SIMD2(px, py)
    }

    /// Evaluate circle involute point and first derivative.
    ///
    /// - Parameters:
    ///   - radius: The base circle radius. Must be > 0.
    ///   - u: The parameter value.
    /// - Returns: The point and its first derivative, or `nil` if the arguments were refused or
    ///   the evaluation was not finite.
    ///
    /// ```swift
    /// if let (p, d1) = Geom2dEval.circleInvoluteD1(radius: 5, u: 1.0) {
    ///     print(p, d1)
    /// }
    /// ```
    public static func circleInvoluteD1(radius: Double, u: Double)
        -> (point: SIMD2<Double>, d1: SIMD2<Double>)?
    {
        var px = 0.0
        var py = 0.0
        var vx = 0.0
        var vy = 0.0
        guard OCCTGeom2dEvalCircleInvoluteD1(radius, u, &px, &py, &vx, &vy) else { return nil }
        return (SIMD2(px, py), SIMD2(vx, vy))
    }

    /// Evaluate a circle involute at parameter u with explicit placement.
    ///
    /// C(t) = O + R*(cos(t) + t*sin(t))*XDir + R*(sin(t) - t*cos(t))*YDir
    ///
    /// - Parameters:
    ///   - origin: The origin point O of the involute's coordinate system.
    ///   - direction: The X direction vector (YDir is computed as perpendicular). Must be non-zero.
    ///   - radius: The base circle radius (must be > 0).
    ///   - u: The parameter value.
    /// - Returns: The evaluated point, or `nil` if the arguments were refused, which includes a
    ///   radius <= 0, a direction of no length, and any non-finite argument.
    ///
    /// ```swift
    /// if let p = Geom2dEval.circleInvoluteD0(
    ///     origin: SIMD2(1, 2), direction: SIMD2(0, 1), radius: 5, u: 1.0)
    /// {
    ///     print(p)
    /// }
    /// ```
    public static func circleInvoluteD0(
        origin: SIMD2<Double>, direction: SIMD2<Double>, radius: Double, u: Double
    ) -> SIMD2<Double>? {
        let dirLen = hypot(direction.x, direction.y)
        guard dirLen > 1e-12 else { return nil }
        let normDir = SIMD2(direction.x / dirLen, direction.y / dirLen)
        var px = 0.0
        var py = 0.0
        guard
            OCCTGeom2dEvalCircleInvoluteD0WithPlacement(
                origin.x, origin.y, normDir.x, normDir.y, radius, u, &px, &py)
        else { return nil }
        return SIMD2(px, py)
    }

    /// Evaluate circle involute point and first derivative with explicit placement.
    ///
    /// - Parameters:
    ///   - origin: The origin point O of the involute's coordinate system.
    ///   - direction: The X direction vector (YDir is computed as perpendicular). Must be non-zero.
    ///   - radius: The base circle radius (must be > 0).
    ///   - u: The parameter value.
    /// - Returns: The point and its first derivative, or `nil` if the arguments were refused,
    ///   which includes a radius <= 0, a direction of no length, and any non-finite argument.
    ///
    /// ```swift
    /// if let (p, d1) = Geom2dEval.circleInvoluteD1(
    ///     origin: SIMD2(1, 2), direction: SIMD2(0, 1), radius: 5, u: 1.0)
    /// {
    ///     print(p, d1)
    /// }
    /// ```
    public static func circleInvoluteD1(
        origin: SIMD2<Double>, direction: SIMD2<Double>, radius: Double, u: Double
    ) -> (point: SIMD2<Double>, d1: SIMD2<Double>)? {
        let dirLen = hypot(direction.x, direction.y)
        guard dirLen > 1e-12 else { return nil }
        let normDir = SIMD2(direction.x / dirLen, direction.y / dirLen)
        var px = 0.0
        var py = 0.0
        var vx = 0.0
        var vy = 0.0
        guard
            OCCTGeom2dEvalCircleInvoluteD1WithPlacement(
                origin.x, origin.y, normDir.x, normDir.y, radius, u, &px, &py, &vx, &vy)
        else { return nil }
        return (SIMD2(px, py), SIMD2(vx, vy))
    }

    /// Evaluate a 2D sine wave at parameter u.
    ///
    /// C(t) = t*X + A*sin(omega*t + phi)*Y
    ///
    /// - Parameters:
    ///   - amplitude: The wave amplitude A. Must be > 0.
    ///   - omega: The angular frequency. Must be > 0.
    ///   - phase: The phase shift phi.
    ///   - u: The parameter value.
    /// - Returns: The evaluated point, or `nil` if the arguments were refused or the evaluation
    ///   was not finite.
    ///
    /// ```swift
    /// if let p = Geom2dEval.sineWaveD0(amplitude: 1, omega: 2 * .pi, phase: 0, u: 0.25) {
    ///     print(p)
    /// }
    /// ```
    public static func sineWaveD0(amplitude: Double, omega: Double, phase: Double, u: Double)
        -> SIMD2<Double>?
    {
        var px = 0.0
        var py = 0.0
        guard OCCTGeom2dEvalSineWaveD0(amplitude, omega, phase, u, &px, &py) else { return nil }
        return SIMD2(px, py)
    }

    /// Evaluate 2D sine wave point and first derivative.
    ///
    /// - Parameters:
    ///   - amplitude: The wave amplitude A. Must be > 0.
    ///   - omega: The angular frequency. Must be > 0.
    ///   - phase: The phase shift phi.
    ///   - u: The parameter value.
    /// - Returns: The point and its first derivative, or `nil` if the arguments were refused or
    ///   the evaluation was not finite.
    ///
    /// ```swift
    /// if let (p, d1) = Geom2dEval.sineWaveD1(
    ///     amplitude: 1, omega: 2 * .pi, phase: 0, u: 0.25)
    /// {
    ///     print(p, d1)
    /// }
    /// ```
    public static func sineWaveD1(amplitude: Double, omega: Double, phase: Double, u: Double)
        -> (point: SIMD2<Double>, d1: SIMD2<Double>)?
    {
        var px = 0.0
        var py = 0.0
        var vx = 0.0
        var vy = 0.0
        guard OCCTGeom2dEvalSineWaveD1(amplitude, omega, phase, u, &px, &py, &vx, &vy) else {
            return nil
        }
        return (SIMD2(px, py), SIMD2(vx, vy))
    }
}
