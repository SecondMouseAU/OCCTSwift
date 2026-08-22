import Foundation
import OCCTBridge
import simd

/// A 3D solid shape backed by OpenCASCADE B-Rep geometry.
public final class Shape: @unchecked Sendable {
    internal let handle: OCCTShapeRef

    internal init(handle: OCCTShapeRef) {
        self.handle = handle
    }

    deinit {
        OCCTShapeRelease(handle)
    }

    // MARK: - Primitive Creation

    /// Create a box centered at origin.
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 5, depth: 3)   // -> Shape? (nil on bad input)
    /// ```
    public static func box(width: Double, height: Double, depth: Double) -> Shape? {
        guard let handle = OCCTShapeCreateBox(width, height, depth) else { return nil }
        return Shape(handle: handle)
    }

    /// Create a box at a specific position.
    public static func box(
        origin: SIMD3<Double>,
        width: Double,
        height: Double,
        depth: Double
    ) -> Shape? {
        guard
            let handle = OCCTShapeCreateBoxAt(
                origin.x, origin.y, origin.z,
                width, height, depth
            )
        else { return nil }
        return Shape(handle: handle)
    }

    /// Create a box at an arbitrary origin along an arbitrary direction.
    ///
    /// - Parameters:
    ///   - origin: Corner point of the box.
    ///   - direction: Axis direction for the box height (will be normalized).
    ///   - width: Box width (X extent in local frame).
    ///   - height: Box height (Y extent in local frame).
    ///   - depth: Box depth (Z extent along direction).
    /// - Returns: The box solid, or nil if OCCT declined to build it.
    public static func box(
        at origin: SIMD3<Double>,
        direction: SIMD3<Double>,
        width: Double,
        height: Double,
        depth: Double
    ) -> Shape? {
        guard
            let handle = OCCTShapeCreateBoxOriented(
                origin.x, origin.y, origin.z,
                direction.x, direction.y, direction.z,
                width, height, depth
            )
        else { return nil }
        return Shape(handle: handle)
    }

    /// Create a cylinder along the Z axis (base at the origin).
    ///
    /// ```swift
    /// let cyl = Shape.cylinder(radius: 2, height: 10)
    /// ```
    public static func cylinder(radius: Double, height: Double) -> Shape? {
        guard let handle = OCCTShapeCreateCylinder(radius, height) else { return nil }
        return Shape(handle: handle)
    }

    /// Create a cylinder at a specific XY position with bottom at specified Z.
    public static func cylinder(
        at position: SIMD2<Double>,
        bottomZ: Double,
        radius: Double,
        height: Double
    ) -> Shape? {
        guard
            let handle = OCCTShapeCreateCylinderAt(position.x, position.y, bottomZ, radius, height)
        else { return nil }
        return Shape(handle: handle)
    }

    /// Create a cylinder at an arbitrary origin along an arbitrary direction.
    ///
    /// - Parameters:
    ///   - origin: Center of the base circle.
    ///   - direction: Axis direction (will be normalized).
    ///   - radius: Cylinder radius.
    ///   - height: Cylinder height along the direction.
    /// - Returns: The cylinder solid, or nil if OCCT declined to build it.
    public static func cylinder(
        at origin: SIMD3<Double>,
        direction: SIMD3<Double>,
        radius: Double,
        height: Double
    ) -> Shape? {
        guard
            let handle = OCCTShapeCreateCylinderOriented(
                origin.x, origin.y, origin.z,
                direction.x, direction.y, direction.z,
                radius, height
            )
        else { return nil }
        return Shape(handle: handle)
    }

    /// Create a partial cylinder (angular segment) along Z axis.
    ///
    /// - Parameters:
    ///   - radius: Cylinder radius.
    ///   - height: Cylinder height.
    ///   - angle: Angular extent in radians (0 < angle <= 2*pi).
    /// - Returns: The cylinder solid, or nil if OCCT declined to build it.
    public static func cylinder(radius: Double, height: Double, angle: Double) -> Shape? {
        guard let handle = OCCTShapeCreateCylinderPartial(radius, height, angle) else { return nil }
        return Shape(handle: handle)
    }

    /// Create a partial cylinder (angular segment) at an arbitrary origin along an arbitrary direction.
    ///
    /// - Parameters:
    ///   - origin: Center of the base circle.
    ///   - direction: Axis direction (will be normalized).
    ///   - radius: Cylinder radius.
    ///   - height: Cylinder height along the direction.
    ///   - angle: Angular extent in radians (0 < angle <= 2*pi).
    /// - Returns: The cylinder solid, or nil if OCCT declined to build it.
    public static func cylinder(
        at origin: SIMD3<Double>,
        direction: SIMD3<Double>,
        radius: Double,
        height: Double,
        angle: Double
    ) -> Shape? {
        guard
            let handle = OCCTShapeCreateCylinderOrientedPartial(
                origin.x, origin.y, origin.z,
                direction.x, direction.y, direction.z,
                radius, height, angle
            )
        else { return nil }
        return Shape(handle: handle)
    }

    /// Create a tool sweep solid - the volume swept by a cylindrical tool moving between two points
    /// Used for CAM simulation to calculate material removal.
    public static func toolSweep(
        radius: Double,
        height: Double,
        from start: SIMD3<Double>,
        to end: SIMD3<Double>
    ) -> Shape? {
        guard
            let handle = OCCTShapeCreateToolSweep(
                radius, height,
                start.x, start.y, start.z,
                end.x, end.y, end.z
            )
        else { return nil }
        return Shape(handle: handle)
    }

    /// Create a sphere centered at origin.
    ///
    /// ```swift
    /// let ball = Shape.sphere(radius: 5)
    /// ```
    public static func sphere(radius: Double) -> Shape? {
        guard let handle = OCCTShapeCreateSphere(radius) else { return nil }
        return Shape(handle: handle)
    }

    /// Create a sphere at a specific center point.
    ///
    /// - Parameters:
    ///   - center: Center of the sphere.
    ///   - radius: Sphere radius.
    /// - Returns: The sphere solid, or nil if OCCT declined to build it.
    public static func sphere(center: SIMD3<Double>, radius: Double) -> Shape? {
        guard
            let handle = OCCTShapeCreateSphereAtCenter(
                center.x, center.y, center.z, radius
            )
        else { return nil }
        return Shape(handle: handle)
    }

    /// Create an oriented sphere at an arbitrary origin along an arbitrary direction.
    ///
    /// - Parameters:
    ///   - origin: Center of the sphere.
    ///   - direction: Axis direction (affects parameterization).
    ///   - radius: Sphere radius.
    /// - Returns: The sphere solid, or nil if OCCT declined to build it.
    public static func sphere(
        at origin: SIMD3<Double>,
        direction: SIMD3<Double>,
        radius: Double
    ) -> Shape? {
        guard
            let handle = OCCTShapeCreateSphereOriented(
                origin.x, origin.y, origin.z,
                direction.x, direction.y, direction.z,
                radius
            )
        else { return nil }
        return Shape(handle: handle)
    }

    /// Create a partial sphere (angular segment).
    ///
    /// - Parameters:
    ///   - radius: Sphere radius.
    ///   - angle: Angular extent in radians (0 < angle <= 2*pi).
    /// - Returns: The sphere solid, or nil if OCCT declined to build it.
    public static func sphere(radius: Double, angle: Double) -> Shape? {
        guard let handle = OCCTShapeCreateSpherePartial(radius, angle) else { return nil }
        return Shape(handle: handle)
    }

    /// Create a partial sphere (angular segment) at an arbitrary origin along an arbitrary direction.
    ///
    /// - Parameters:
    ///   - origin: Center of the sphere.
    ///   - direction: Axis direction (affects parameterization).
    ///   - radius: Sphere radius.
    ///   - angle: Angular extent in radians (0 < angle <= 2*pi).
    /// - Returns: The sphere solid, or nil if OCCT declined to build it.
    public static func sphere(
        at origin: SIMD3<Double>,
        direction: SIMD3<Double>,
        radius: Double,
        angle: Double
    ) -> Shape? {
        guard
            let handle = OCCTShapeCreateSphereOrientedPartial(
                origin.x, origin.y, origin.z,
                direction.x, direction.y, direction.z,
                radius, angle
            )
        else { return nil }
        return Shape(handle: handle)
    }

    /// Create a sphere latitude segment at an arbitrary origin along an arbitrary direction.
    ///
    /// - Parameters:
    ///   - origin: Center of the sphere.
    ///   - direction: Axis direction (affects parameterization).
    ///   - radius: Sphere radius.
    ///   - angle1: Lower latitude bound in radians (-pi/2 to pi/2).
    ///   - angle2: Upper latitude bound in radians (-pi/2 to pi/2).
    /// - Returns: The sphere solid, or nil if OCCT declined to build it.
    public static func sphere(
        at origin: SIMD3<Double>,
        direction: SIMD3<Double>,
        radius: Double,
        angle1: Double,
        angle2: Double
    ) -> Shape? {
        guard
            let handle = OCCTShapeCreateSphereOrientedSegment(
                origin.x, origin.y, origin.z,
                direction.x, direction.y, direction.z,
                radius, angle1, angle2
            )
        else { return nil }
        return Shape(handle: handle)
    }

    /// Create a cone along Z axis.
    public static func cone(bottomRadius: Double, topRadius: Double, height: Double) -> Shape? {
        guard let handle = OCCTShapeCreateCone(bottomRadius, topRadius, height) else { return nil }
        return Shape(handle: handle)
    }

    /// Create a cone at an arbitrary origin along an arbitrary direction.
    ///
    /// - Parameters:
    ///   - origin: Center of the base circle.
    ///   - direction: Axis direction (will be normalized).
    ///   - bottomRadius: Radius at the base.
    ///   - topRadius: Radius at the top.
    ///   - height: Cone height along the direction.
    /// - Returns: The cone solid, or nil if OCCT declined to build it.
    public static func cone(
        at origin: SIMD3<Double>,
        direction: SIMD3<Double>,
        bottomRadius: Double,
        topRadius: Double,
        height: Double
    ) -> Shape? {
        guard
            let handle = OCCTShapeCreateConeOriented(
                origin.x, origin.y, origin.z,
                direction.x, direction.y, direction.z,
                bottomRadius, topRadius, height
            )
        else { return nil }
        return Shape(handle: handle)
    }

    /// Create a partial cone (angular segment) at an arbitrary origin along an arbitrary direction.
    ///
    /// - Parameters:
    ///   - origin: Center of the base circle.
    ///   - direction: Axis direction (will be normalized).
    ///   - bottomRadius: Radius at the base.
    ///   - topRadius: Radius at the top.
    ///   - height: Cone height along the direction.
    ///   - angle: Angular extent in radians (0 < angle <= 2*pi).
    /// - Returns: The cone solid, or nil if OCCT declined to build it.
    public static func cone(
        at origin: SIMD3<Double>,
        direction: SIMD3<Double>,
        bottomRadius: Double,
        topRadius: Double,
        height: Double,
        angle: Double
    ) -> Shape? {
        guard
            let handle = OCCTShapeCreateConeOrientedPartial(
                origin.x, origin.y, origin.z,
                direction.x, direction.y, direction.z,
                bottomRadius, topRadius, height, angle
            )
        else { return nil }
        return Shape(handle: handle)
    }

    /// Create a torus in XY plane.
    public static func torus(majorRadius: Double, minorRadius: Double) -> Shape? {
        guard let handle = OCCTShapeCreateTorus(majorRadius, minorRadius) else { return nil }
        return Shape(handle: handle)
    }

    /// Create a torus at an arbitrary origin along an arbitrary direction.
    ///
    /// - Parameters:
    ///   - origin: Center of the torus.
    ///   - direction: Axis direction (normal to the torus plane).
    ///   - majorRadius: Distance from center to tube center.
    ///   - minorRadius: Tube radius.
    /// - Returns: The torus solid, or nil if OCCT declined to build it.
    public static func torus(
        at origin: SIMD3<Double>,
        direction: SIMD3<Double>,
        majorRadius: Double,
        minorRadius: Double
    ) -> Shape? {
        guard
            let handle = OCCTShapeCreateTorusOriented(
                origin.x, origin.y, origin.z,
                direction.x, direction.y, direction.z,
                majorRadius, minorRadius
            )
        else { return nil }
        return Shape(handle: handle)
    }

    /// Create a partial torus (angular segment) at an arbitrary origin along an arbitrary direction.
    ///
    /// - Parameters:
    ///   - origin: Center of the torus.
    ///   - direction: Axis direction (normal to the torus plane).
    ///   - majorRadius: Distance from center to tube center.
    ///   - minorRadius: Tube radius.
    ///   - angle: Angular extent in radians (0 < angle <= 2*pi).
    /// - Returns: The torus solid, or nil if OCCT declined to build it.
    public static func torus(
        at origin: SIMD3<Double>,
        direction: SIMD3<Double>,
        majorRadius: Double,
        minorRadius: Double,
        angle: Double
    ) -> Shape? {
        guard
            let handle = OCCTShapeCreateTorusOrientedPartial(
                origin.x, origin.y, origin.z,
                direction.x, direction.y, direction.z,
                majorRadius, minorRadius, angle
            )
        else { return nil }
        return Shape(handle: handle)
    }

    /// Create a torus tube segment at an arbitrary origin along an arbitrary direction.
    ///
    /// - Parameters:
    ///   - origin: Center of the torus.
    ///   - direction: Axis direction (normal to the torus plane).
    ///   - majorRadius: Distance from center to tube center.
    ///   - minorRadius: Tube radius.
    ///   - angle1: Start angle of the tube section in radians.
    ///   - angle2: End angle of the tube section in radians.
    /// - Returns: The torus solid, or nil if OCCT declined to build it.
    public static func torus(
        at origin: SIMD3<Double>,
        direction: SIMD3<Double>,
        majorRadius: Double,
        minorRadius: Double,
        angle1: Double,
        angle2: Double
    ) -> Shape? {
        guard
            let handle = OCCTShapeCreateTorusOrientedSegment(
                origin.x, origin.y, origin.z,
                direction.x, direction.y, direction.z,
                majorRadius, minorRadius, angle1, angle2
            )
        else { return nil }
        return Shape(handle: handle)
    }

    // MARK: - Sweep Operations

    /// Sweep a 2D profile along a path to create a solid.
    ///
    /// The resulting solid is orientation-normalised so its faces point outward
    /// (positive volume) regardless of the profile wire's sense relative to the
    /// path tangent. `BRepOffsetAPI_MakePipe` itself yields an inward-oriented
    /// (negative-volume) solid whenever the section's normal runs against the path
    /// tangent, a latent hazard for downstream booleans and `volume > 0` checks,
    /// so callers no longer need the "point the section normal against the tangent"
    /// incantation. See ``orientedForward()`` for the same fix applied explicitly.
    public static func sweep(profile: Wire, along path: Wire) -> Shape? {
        guard let handle = OCCTShapeCreatePipeSweep(profile.handle, path.handle) else { return nil }
        let swept = Shape(handle: handle)
        return swept.orientedForward()
    }

    /// Extrude a 2D profile in a direction.
    public static func extrude(profile: Wire, direction: SIMD3<Double>, length: Double) -> Shape? {
        guard
            let handle = OCCTShapeCreateExtrusion(
                profile.handle,
                direction.x, direction.y, direction.z,
                length
            )
        else { return nil }
        return Shape(handle: handle)
    }

    /// Revolve a 2D profile around an axis.
    public static func revolve(
        profile: Wire,
        axisOrigin: SIMD3<Double>,
        axisDirection: SIMD3<Double>,
        angle: Double = .pi * 2
    ) -> Shape? {
        guard
            let handle = OCCTShapeCreateRevolution(
                profile.handle,
                axisOrigin.x, axisOrigin.y, axisOrigin.z,
                axisDirection.x, axisDirection.y, axisDirection.z,
                angle
            )
        else { return nil }
        return Shape(handle: handle)
    }

    /// Extrude any shape along a vector.
    public func extruded(by vector: SIMD3<Double>) -> Shape? {
        guard let h = OCCTShapeCreateExtrusionShape(handle, vector.x, vector.y, vector.z) else {
            return nil
        }
        return Shape(handle: h)
    }

    /// Extrude any shape to infinity (or semi-infinity) along a direction.
    public func extrudedInfinite(direction: SIMD3<Double>, infinite: Bool = true) -> Shape? {
        guard
            let h = OCCTShapeCreateExtrusionInfinite(
                handle, direction.x, direction.y, direction.z, infinite)
        else { return nil }
        return Shape(handle: h)
    }

    /// Revolve any shape around an axis (full 360 degrees).
    public func revolved(
        axisOrigin: SIMD3<Double>,
        axisDirection: SIMD3<Double>
    ) -> Shape? {
        guard
            let h = OCCTShapeCreateRevolutionFull(
                handle,
                axisOrigin.x, axisOrigin.y, axisOrigin.z,
                axisDirection.x, axisDirection.y, axisDirection.z)
        else { return nil }
        return Shape(handle: h)
    }

    /// Revolve any shape around an axis by a partial angle.
    public func revolved(
        axisOrigin: SIMD3<Double>,
        axisDirection: SIMD3<Double>,
        angle: Double
    ) -> Shape? {
        guard
            let h = OCCTShapeCreateRevolutionPartial(
                handle,
                axisOrigin.x, axisOrigin.y, axisOrigin.z,
                axisDirection.x, axisDirection.y, axisDirection.z,
                angle)
        else { return nil }
        return Shape(handle: h)
    }

    /// Loft through multiple profile wires.
    public static func loft(profiles: [Wire], solid: Bool = true) -> Shape? {
        let handles: [OCCTWireRef?] = profiles.map { $0.handle }
        guard
            let handle = handles.withUnsafeBufferPointer({ buffer in
                OCCTShapeCreateLoft(buffer.baseAddress, Int32(profiles.count), solid)
            })
        else { return nil }
        return Shape(handle: handle)
    }

    /// Loft through profile wires with advanced options.
    ///
    /// - Parameters:
    ///   - profiles: Wire profiles to loft through
    ///   - solid: Whether to create a solid (true) or shell (false)
    ///   - ruled: Whether to use ruled surfaces (true) or smooth B-spline (false)
    ///   - firstVertex: Optional starting vertex (for cone/taper tips)
    ///   - lastVertex: Optional ending vertex (for cone/taper tips)
    /// - Returns: Lofted shape, or nil on failure
    public static func loft(
        profiles: [Wire], solid: Bool = true, ruled: Bool,
        firstVertex: SIMD3<Double>? = nil,
        lastVertex: SIMD3<Double>? = nil
    ) -> Shape? {
        let handles: [OCCTWireRef?] = profiles.map { $0.handle }
        let fv = firstVertex ?? SIMD3<Double>(Double.nan, Double.nan, Double.nan)
        let lv = lastVertex ?? SIMD3<Double>(Double.nan, Double.nan, Double.nan)
        guard
            let handle = handles.withUnsafeBufferPointer({ buffer in
                OCCTShapeCreateLoftAdvanced(
                    buffer.baseAddress, Int32(profiles.count),
                    solid, ruled,
                    fv.x, fv.y, fv.z,
                    lv.x, lv.y, lv.z)
            })
        else { return nil }
        return Shape(handle: handle)
    }

    // MARK: - Boolean Operations

    /// Glue mode for boolean operations (`BOPAlgo_GlueEnum`).
    ///
    /// Gluing speeds up and hardens booleans when the arguments share **coincident
    /// faces**, by telling the algorithm those faces touch instead of intersecting them.
    /// Only use it when the touching faces really are coincident, gluing two solids that
    /// genuinely interpenetrate produces a wrong result.
    public enum BooleanGlue: Int32, Sendable {
        /// No gluing (OCCT default, full intersection).
        case off = 0
        /// `BOPAlgo_GlueShift`, arguments may share coincident faces but are otherwise disjoint.
        case shift = 1
        /// `BOPAlgo_GlueFull`, all arguments are known to share coincident faces (fastest, strictest).
        case full = 2
    }

    /// Default wall-clock bound (seconds) for the boolean ops.
    ///
    /// A self-intersecting / inside-out operand (e.g. from `loft(ruled: false)`) can make
    /// `BRepAlgoAPI_Cut` spin indefinitely; the boolean ops abort and return `nil` once this
    /// elapses rather than hanging a pipeline. Override per call; pass `0` (or negative) to
    /// disable. (#206)
    public static let defaultBooleanTimeout: Double = 120

    /// What a boolean did, separating a genuine failure from the `timeout:` watchdog firing.
    ///
    /// ``union(_:fuzzyValue:glue:timeout:)``, ``subtracting(_:fuzzyValue:glue:timeout:)`` and
    /// ``intersection(_:fuzzyValue:glue:timeout:)`` collapse ``failed`` and ``timedOut`` into one
    /// `nil`, so a caller cannot tell a bad operand from a busy machine (#1067). Returned by
    /// ``unionOutcome(_:fuzzyValue:glue:timeout:)``,
    /// ``subtractionOutcome(_:fuzzyValue:glue:timeout:)`` and
    /// ``intersectionOutcome(_:fuzzyValue:glue:timeout:)``.
    public enum BooleanOutcome: Sendable {
        /// The operation completed and produced this shape.
        case success(Shape)
        /// The operation ran to a conclusion and declined, for example on an invalid operand.
        /// Raising `timeout:` will not change this.
        case failed
        /// The wall-clock watchdog interrupted the build, so no result was produced. This is a
        /// property of the deadline and the machine, not of the geometry (**indeterminate**,
        /// treat as "unknown", not "cannot be built"). Retrying with a larger `timeout:` may
        /// succeed.
        case timedOut

        /// The result shape, or `nil` for either non-success case.
        ///
        /// The three named boolean methods return exactly this, which is why they cannot tell
        /// ``failed`` from ``timedOut``.
        public var shape: Shape? {
            if case .success(let shape) = self { return shape }
            return nil
        }
    }

    /// Decode one bridge boolean call into a ``BooleanOutcome``.
    ///
    /// The three public outcome methods differ only in which bridge function they hand over, so
    /// the pointer handling and the `nil`-plus-flag decode live here once rather than three times.
    private func booleanOutcome(
        _ run: (UnsafeMutablePointer<Int32>) -> OCCTShapeRef?
    ) -> BooleanOutcome {
        var timedOut: Int32 = 0
        let handle = withUnsafeMutablePointer(to: &timedOut) { run($0) }
        guard let handle else { return timedOut != 0 ? .timedOut : .failed }
        return .success(Shape(handle: handle))
    }

    /// ``union(_:fuzzyValue:glue:timeout:)``, reporting **why** it produced no shape.
    ///
    /// Same operation, same options and same watchdog; `union` is a thin wrapper over this that
    /// returns ``BooleanOutcome/shape``. The difference is that `union` answers `nil` for both a
    /// failed boolean and an expired `timeout:`, and only this separates them (#1067).
    ///
    /// - Important: `timeout` is **cooperative, not a hard deadline** (#293), exactly as on
    ///   `union`. It is a `Message_ProgressIndicator` OCCT polls at its own internal checkpoints,
    ///   so the call returns at the first checkpoint after `timeout`, not at `timeout` itself.
    ///   ``BooleanOutcome/timedOut`` therefore means "the watchdog fired", which is
    ///   indeterminate rather than negative, the reading ``isSelfIntersecting(timeout:)`` gives
    ///   its `nil`. The two are not the same signal: `.timedOut` is the watchdog and only the
    ///   watchdog, while that `nil` also covers an argument the analyzer refused and an analysis
    ///   that errored (#1054).
    ///
    /// - Parameters:
    ///   - other: The shape to fuse with `self`.
    ///   - fuzzyValue: As ``union(_:fuzzyValue:glue:timeout:)``.
    ///   - glue: As ``union(_:fuzzyValue:glue:timeout:)``.
    ///   - timeout: As ``union(_:fuzzyValue:glue:timeout:)``. `0`/negative = unbounded, which
    ///     makes ``BooleanOutcome/timedOut`` unreachable.
    /// - Returns: The outcome, carrying the fused shape on success.
    ///
    /// ```swift
    /// switch box.unionOutcome(cyl) {
    /// case .success(let merged): print(merged.volume as Any)
    /// case .timedOut:            print("the machine, not the geometry: try a larger timeout")
    /// case .failed:              print("the boolean declined these operands")
    /// }
    /// ```
    public func unionOutcome(
        _ other: Shape, fuzzyValue: Double = 0, glue: BooleanGlue = .off,
        timeout: Double = Shape.defaultBooleanTimeout
    ) -> BooleanOutcome {
        booleanOutcome {
            OCCTShapeUnionEx(self.handle, other.handle, fuzzyValue, glue.rawValue, timeout, $0)
        }
    }

    /// ``subtracting(_:fuzzyValue:glue:timeout:)``, reporting **why** it produced no shape.
    ///
    /// See ``unionOutcome(_:fuzzyValue:glue:timeout:)`` for the contract, which is identical
    /// apart from the operation (#1067).
    ///
    /// - Parameters:
    ///   - other: The tool shape to remove from `self`.
    ///   - fuzzyValue: As ``subtracting(_:fuzzyValue:glue:timeout:)``.
    ///   - glue: As ``subtracting(_:fuzzyValue:glue:timeout:)``.
    ///   - timeout: As ``subtracting(_:fuzzyValue:glue:timeout:)``. `0`/negative = unbounded.
    /// - Returns: The outcome, carrying the cut shape on success.
    ///
    /// ```swift
    /// // A 36-tooth gear whose cut is legitimately long: retry the deadline, not the geometry.
    /// var outcome = blank.subtractionOutcome(tools)
    /// if case .timedOut = outcome {
    ///     outcome = blank.subtractionOutcome(tools, timeout: 600)
    /// }
    /// guard let gear = outcome.shape else { return }
    /// ```
    public func subtractionOutcome(
        _ other: Shape, fuzzyValue: Double = 0, glue: BooleanGlue = .off,
        timeout: Double = Shape.defaultBooleanTimeout
    ) -> BooleanOutcome {
        booleanOutcome {
            OCCTShapeSubtractEx(self.handle, other.handle, fuzzyValue, glue.rawValue, timeout, $0)
        }
    }

    /// ``intersection(_:fuzzyValue:glue:timeout:)``, reporting **why** it produced no shape.
    ///
    /// See ``unionOutcome(_:fuzzyValue:glue:timeout:)`` for the contract, which is identical
    /// apart from the operation (#1067).
    ///
    /// - Parameters:
    ///   - other: The shape to intersect with `self`.
    ///   - fuzzyValue: As ``intersection(_:fuzzyValue:glue:timeout:)``.
    ///   - glue: As ``intersection(_:fuzzyValue:glue:timeout:)``.
    ///   - timeout: As ``intersection(_:fuzzyValue:glue:timeout:)``. `0`/negative = unbounded.
    /// - Returns: The outcome, carrying the common shape on success.
    ///
    /// ```swift
    /// let outcome = box.intersectionOutcome(cyl)
    /// print(outcome.shape?.volume as Any)   // nil for both failed and timedOut
    /// ```
    public func intersectionOutcome(
        _ other: Shape, fuzzyValue: Double = 0, glue: BooleanGlue = .off,
        timeout: Double = Shape.defaultBooleanTimeout
    ) -> BooleanOutcome {
        booleanOutcome {
            OCCTShapeIntersectEx(self.handle, other.handle, fuzzyValue, glue.rawValue, timeout, $0)
        }
    }

    /// Union (add) two shapes together.
    ///
    /// - Parameters:
    ///   - other: The shape to fuse with `self`.
    ///   - fuzzyValue: Tolerance-based fuzzy value (`SetFuzzyValue`). `0` (default) keeps OCCT's
    ///     default tolerance; a small positive value (e.g. `1e-4`) helps near-tangent / nearly
    ///     coincident faces fuse cleanly. Negative values are ignored.
    ///   - glue: Glue mode for coincident-face arguments (default `.off`). See ``BooleanGlue``.
    ///   - timeout: Wall-clock bound in seconds (default ``defaultBooleanTimeout``, 120s). Returns
    ///     `nil` if the operation doesn't finish in time instead of hanging. `0`/negative = unbounded.
    ///
    /// ```swift
    /// let merged = box.union(cyl)                      // or: box + cyl
    /// let clean  = outer.union(inner, fuzzyValue: 1e-4) // near-tangent walls fuse cleanly
    /// ```
    /// - Returns: The fused shape, or nil if the boolean failed **or** `timeout` elapsed.
    ///   ``unionOutcome(_:fuzzyValue:glue:timeout:)`` tells those two apart (#1067).
    public func union(
        _ other: Shape, fuzzyValue: Double = 0, glue: BooleanGlue = .off,
        timeout: Double = Shape.defaultBooleanTimeout
    ) -> Shape? {
        unionOutcome(other, fuzzyValue: fuzzyValue, glue: glue, timeout: timeout).shape
    }

    /// Subtract another shape from this one.
    ///
    /// - Parameters:
    ///   - other: The tool shape to remove from `self`.
    ///   - fuzzyValue: Tolerance-based fuzzy value (`SetFuzzyValue`). `0` (default) keeps OCCT's
    ///     default tolerance; raise it slightly when a thin-wall cut under-subtracts. Negative
    ///     values are ignored.
    ///   - glue: Glue mode for coincident-face arguments (default `.off`). See ``BooleanGlue``.
    ///   - timeout: Wall-clock bound in seconds (default ``defaultBooleanTimeout``, 120s). Returns
    ///     `nil` if the operation doesn't finish in time instead of hanging. `0`/negative = unbounded.
    ///
    /// ```swift
    /// let drilled = box.subtracting(cyl)   // or: box - cyl, a box with a through-hole
    /// ```
    /// - Returns: The cut shape, or nil if the boolean failed **or** `timeout` elapsed.
    ///   ``subtractionOutcome(_:fuzzyValue:glue:timeout:)`` tells those two apart (#1067).
    public func subtracting(
        _ other: Shape, fuzzyValue: Double = 0, glue: BooleanGlue = .off,
        timeout: Double = Shape.defaultBooleanTimeout
    ) -> Shape? {
        subtractionOutcome(other, fuzzyValue: fuzzyValue, glue: glue, timeout: timeout).shape
    }

    /// Intersection of two shapes.
    ///
    /// - Parameters:
    ///   - other: The shape to intersect with `self`.
    ///   - fuzzyValue: Tolerance-based fuzzy value (`SetFuzzyValue`). `0` (default) keeps OCCT's
    ///     default tolerance. Negative values are ignored.
    ///   - glue: Glue mode for coincident-face arguments (default `.off`). See ``BooleanGlue``.
    ///   - timeout: Wall-clock bound in seconds (default ``defaultBooleanTimeout``, 120s). Returns
    ///     `nil` if the operation doesn't finish in time instead of hanging. `0`/negative = unbounded.
    ///
    /// ```swift
    /// let common = box.intersection(cyl)   // or: box & cyl, the overlapping volume
    /// ```
    /// - Returns: The common shape, or nil if the boolean failed **or** `timeout` elapsed.
    ///   ``intersectionOutcome(_:fuzzyValue:glue:timeout:)`` tells those two apart (#1067).
    public func intersection(
        _ other: Shape, fuzzyValue: Double = 0, glue: BooleanGlue = .off,
        timeout: Double = Shape.defaultBooleanTimeout
    ) -> Shape? {
        intersectionOutcome(other, fuzzyValue: fuzzyValue, glue: glue, timeout: timeout).shape
    }

    // MARK: - Modifications

    /// Fillet (round) all edges with given radius.
    public func filleted(radius: Double) -> Shape? {
        guard let handle = OCCTShapeFillet(self.handle, radius) else { return nil }
        return Shape(handle: handle)
    }

    /// Chamfer all edges with given distance.
    public func chamfered(distance: Double) -> Shape? {
        guard let handle = OCCTShapeChamfer(self.handle, distance) else { return nil }
        return Shape(handle: handle)
    }

    /// Chamfer specific edges with two different distances (asymmetric).
    ///
    /// Each entry specifies an edge, a reference face adjacent to that edge,
    /// and two distances. `dist1` is measured on the reference face side,
    /// `dist2` on the opposite side.
    ///
    /// - Parameter edges: Array of (edgeIndex, faceIndex, dist1, dist2) tuples
    /// - Returns: Chamfered shape, or nil on failure
    public func chamferedTwoDistances(
        _ edges: [(edgeIndex: Int, faceIndex: Int, dist1: Double, dist2: Double)]
    ) -> Shape? {
        let ei = edges.map { Int32($0.edgeIndex) }
        let fi = edges.map { Int32($0.faceIndex) }
        let d1 = edges.map { $0.dist1 }
        let d2 = edges.map { $0.dist2 }
        guard let h = OCCTShapeChamferTwoDistances(handle, ei, fi, d1, d2, Int32(edges.count))
        else { return nil }
        return Shape(handle: h)
    }

    /// Chamfer specific edges with distance + angle.
    ///
    /// Each entry specifies an edge, a reference face adjacent to that edge,
    /// a distance measured on the reference face, and a chamfer angle in degrees
    /// (must be between 0 and 90, exclusive).
    ///
    /// - Parameter edges: Array of (edgeIndex, faceIndex, distance, angleDegrees) tuples
    /// - Returns: Chamfered shape, or nil on failure
    public func chamferedDistAngle(
        _ edges: [(edgeIndex: Int, faceIndex: Int, distance: Double, angleDegrees: Double)]
    ) -> Shape? {
        let ei = edges.map { Int32($0.edgeIndex) }
        let fi = edges.map { Int32($0.faceIndex) }
        let d = edges.map { $0.distance }
        let a = edges.map { $0.angleDegrees }
        guard let h = OCCTShapeChamferDistAngle(handle, ei, fi, d, a, Int32(edges.count)) else {
            return nil
        }
        return Shape(handle: h)
    }

    /// Create a hollow shell by removing material from inside.
    public func shelled(thickness: Double) -> Shape? {
        guard let handle = OCCTShapeShell(self.handle, thickness) else { return nil }
        return Shape(handle: handle)
    }

    /// Offset all faces by a distance (positive = outward).
    public func offset(by distance: Double) -> Shape? {
        guard let handle = OCCTShapeOffset(self.handle, distance) else { return nil }
        return Shape(handle: handle)
    }

    /// Offset all faces using the proper join algorithm.
    ///
    /// This uses `PerformByJoin` which is more robust than the simple offset.
    /// It handles gap filling between parallel faces using the specified join type.
    ///
    /// - Parameters:
    ///   - distance: Offset distance (positive = outward, negative = inward)
    ///   - tolerance: Coincidence tolerance (default: 1e-7)
    ///   - joinType: How to fill gaps between offset faces
    ///   - removeInternalEdges: Whether to clean up internal edges
    /// - Returns: Offset shape, or nil on failure
    public func offset(
        by distance: Double, tolerance: Double = 1e-7,
        joinType: OffsetJoinType = .arc,
        removeInternalEdges: Bool = false
    ) -> Shape? {
        guard
            let h = OCCTShapeOffsetByJoin(
                handle, distance, tolerance,
                joinType.rawValue, removeInternalEdges)
        else { return nil }
        return Shape(handle: h)
    }

    // MARK: - Transformations

    /// Translate the shape.
    public func translated(by offset: SIMD3<Double>) -> Shape? {
        guard let handle = OCCTShapeTranslate(self.handle, offset.x, offset.y, offset.z) else {
            return nil
        }
        return Shape(handle: handle)
    }

    /// Rotate around an axis through origin.
    public func rotated(axis: SIMD3<Double>, angle: Double) -> Shape? {
        guard let handle = OCCTShapeRotate(self.handle, axis.x, axis.y, axis.z, angle) else {
            return nil
        }
        return Shape(handle: handle)
    }

    /// Scale uniformly from origin.
    public func scaled(by factor: Double) -> Shape? {
        guard let handle = OCCTShapeScale(self.handle, factor) else { return nil }
        return Shape(handle: handle)
    }

    /// Mirror across a plane.
    public func mirrored(planeNormal: SIMD3<Double>, planeOrigin: SIMD3<Double> = .zero) -> Shape? {
        guard
            let handle = OCCTShapeMirror(
                self.handle,
                planeOrigin.x, planeOrigin.y, planeOrigin.z,
                planeNormal.x, planeNormal.y, planeNormal.z
            )
        else { return nil }
        return Shape(handle: handle)
    }

    // MARK: - Compound Operations

    /// Combine multiple shapes into a compound (no boolean, just grouping).
    public static func compound(_ shapes: [Shape]) -> Shape? {
        let handles: [OCCTShapeRef?] = shapes.map { $0.handle }
        guard
            let handle = handles.withUnsafeBufferPointer({ buffer in
                OCCTShapeCreateCompound(buffer.baseAddress, Int32(shapes.count))
            })
        else { return nil }
        return Shape(handle: handle)
    }

    // MARK: - Conversion

    /// Wrap a Wire as a Shape to access edge extraction and other Shape methods.
    ///
    /// Since `TopoDS_Wire` inherits from `TopoDS_Shape` in OCCT, this is a
    /// lightweight conversion that enables using Shape methods like
    /// `allEdgePolylines()` on wire geometry without creating solid geometry.
    ///
    /// - Parameter wire: The wire to wrap.
    /// - Returns: A Shape wrapping the wire, or `nil` on failure.
    public static func fromWire(_ wire: Wire) -> Shape? {
        guard let handle = OCCTShapeFromWire(wire.handle) else { return nil }
        return Shape(handle: handle)
    }

    /// Wrap an Edge as a Shape to use it with Shape-based APIs.
    ///
    /// Since `TopoDS_Edge` inherits from `TopoDS_Shape` in OCCT, this is a
    /// lightweight conversion.
    ///
    /// - Parameter edge: The edge to wrap.
    /// - Returns: A Shape wrapping the edge, or `nil` on failure.
    public static func fromEdge(_ edge: Edge) -> Shape? {
        guard let handle = OCCTShapeFromEdge(edge.handle) else { return nil }
        return Shape(handle: handle)
    }

    /// Wrap a Face as a Shape to use it with Shape-based APIs.
    ///
    /// Since `TopoDS_Face` inherits from `TopoDS_Shape` in OCCT, this is a
    /// lightweight conversion.
    ///
    /// - Parameter face: The face to wrap.
    /// - Returns: A Shape wrapping the face, or `nil` on failure.
    public static func fromFace(_ face: Face) -> Shape? {
        guard let handle = OCCTShapeFromFace(face.handle) else { return nil }
        return Shape(handle: handle)
    }

    // MARK: - Validation

    /// Check if shape is valid (`BRepCheck_Analyzer`).
    ///
    /// - Note: This checks whatever `shapeType` the receiver already has, and a well-formed
    ///   **open** shell reports `true` here just as readily as a closed one, since a shell has
    ///   no closure requirement of its own. It does not detect 3D self-intersection either. So
    ///   `isValid == true` never implies "this is a solid" or "this does not overlap itself"; use
    ///   ``isValidSolid`` for the former and ``isSelfIntersecting(timeout:)`` for the latter
    ///   (#702).
    ///
    /// ```swift
    /// // A box missing one face, wrapped as a "solid" with no fixing, then healed: the open
    /// // shell cannot be closed, so it comes back demoted to a shell.
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let faces = box.subShapes(ofType: .face)
    /// let openShell = Shape.compound(Array(faces.dropFirst()))!.sewn()!
    /// let demoted = Shape.solidFromShells([openShell])!.healed()!
    ///
    /// print(demoted.shapeType)    // .shell: could not close, demoted from the "solid" input
    /// print(demoted.isValid)      // true: a well-formed shell has no closure requirement
    /// print(demoted.isValidSolid) // false: this is the check that actually catches it
    /// ```
    public var isValid: Bool {
        OCCTShapeIsValid(handle)
    }

    /// Attempt to repair/heal the shape, using `ShapeFix_Shape`.
    ///
    /// - Warning: For solid input, this can return a **shell** instead of a repaired solid.
    ///   `ShapeFix_Shape` delegates to `ShapeFix_Solid` for every solid it finds, and
    ///   `ShapeFix_Solid` hands back the shell unpromoted whenever it cannot close it, the same
    ///   mechanism ``Shape/fixSolid()`` documents at length, since it wraps `ShapeFix_Solid`
    ///   directly. The demoted shell is not flagged by ``isValid`` or ``volume``: a shell has no
    ///   closure requirement of its own, so it can report `isValid == true` and a correct
    ///   `volume` even though the input used to be a solid and no longer is (#702). Check
    ///   ``isValidSolid`` (single body) or `shapeType`/`subShapeCount(ofType: .solid)`
    ///   (multi-body) if the caller depends on getting a solid back, rather than inferring it
    ///   from `isValid` or `volume`.
    ///
    /// ```swift
    /// // An open shell (a box missing one face) wrapped as a "solid" with no fixing at all,
    /// // then healed: ShapeFix_Solid cannot close it, so healed() demotes it to a shell.
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let faces = box.subShapes(ofType: .face)
    /// let openShell = Shape.compound(Array(faces.dropFirst()))!.sewn()!
    /// let fakeSolid = Shape.solidFromShells([openShell])!
    ///
    /// let healed = fakeSolid.healed()!
    /// print(healed.shapeType)    // .shell: demoted, not a repaired solid
    /// print(healed.isValid)      // true: the demotion is invisible here
    /// print(healed.isValidSolid) // false: check this instead when a solid is required
    /// ```
    public func healed() -> Shape? {
        guard let handle = OCCTShapeHeal(self.handle) else { return nil }
        return Shape(handle: handle)
    }

    // MARK: - Meshing

    /// Generate a triangulated mesh for visualization.
    ///
    /// - Warning: **This call can take minutes on a degenerate offset surface**, the geometry
    ///   `shelled(thickness:)` / `offset(by:)` produce (`Geom_OffsetSurface`). It is not a hang:
    ///   measured on the fitted-then-offset B-spline panel from
    ///   [#286](https://github.com/SecondMouseAU/OCCTSwift/issues/286), one face took **249 s** and
    ///   emitted **1.4 M triangles** at a *coarse* deflection (1/638 of the shape's bbox diagonal).
    ///   It terminates; earlier reports of an unbounded hang were timeouts set below that.
    ///
    ///   **Cause**, the offset surface is *self-intersecting*, and the mesher's angular criterion
    ///   cannot converge on it. Offsetting a surface by more than its local radius of curvature
    ///   produces cusps. On the #286 panel the basis fit's minimum principal curvature radius is
    ///   `2.6e-05` against an offset of `1.27`, so **23.8 %** of the domain is cusped and the
    ///   surface normal swings by up to `π` across one. `BRepMesh` splits any triangle link whose
    ///   end normals differ by more than `AngleInterior` (= `2 × angularDeflection`), but at a
    ///   normal *discontinuity* splitting never helps, halving a link that straddles a cusp just
    ///   moves the cusp into one half. So `BRepMesh_DelaunayDeflectionControlMeshAlgo::optimizeMesh`
    ///   runs all 11 of its passes demanding ~80 k splits each, long after linear deflection is
    ///   satisfied (it reached 1.82 against a 2.48 target by pass 6). `MinSize`
    ///   (= `linearDeflection / 10`) is the only backstop. This is invalid input, not an OCCT
    ///   defect: a well-formed offset surface meshes normally.
    ///
    ///   **Mitigations**, in order of preference:
    ///   1. **Don't mesh geometry you haven't sanity-checked.** `bounds` is a cheap `Bnd_Box`
    ///      query with no tessellation, comparing a thickened solid's bbox against its source's
    ///      is enough to reject the ballooned offsets that trigger this, and is what the
    ///      downstream caller in #286 adopted. Note `isValid` will *not* catch it: the measured
    ///      offending solid reports `isValid == true`, because a self-intersecting offset surface
    ///      is still a topologically valid face.
    ///   2. **Bound it with a deadline.** ``meshWithProgress(linearDeflection:angularDeflection:progress:)``
    ///      interrupts this reliably, a 10 s deadline returns in 10.1 s on the #286 face. (Before
    ///      v1.11.1 the bridge meshed inside a constructor that never polled the progress range, so
    ///      cancellation appeared not to work; that was our bug, now fixed.)
    ///   3. **Raise `angularDeflection`,** which raises the `AngleInterior` threshold that is doing
    ///      all the splitting here, or raise `MinSize` via ``mesh(parameters:)`` to make the
    ///      backstop bite sooner.
    ///   4. ``withSurfacesAsBSpline(extrusion:revolution:offset:plane:)`` with `offset: true`
    ///      approximates the `Geom_OffsetSurface` with a plain B-spline, which smooths the cusps
    ///      the angular check is choking on. Measured on the #286 solid: 125 s / 526 k vertices,
    ///      faster, but it resamples the geometry, so treat it as a rescue path, not a default.
    ///
    /// - Note: **Triangle winding always reflects the shape's true topological orientation, not
    ///   a naive read of a caller-applied transform.** This method reads each face's
    ///   `TopoDS_Face::Orientation()` faithfully (reversing the triangulation's node order when
    ///   `REVERSED`), so it's never "wrong", but for a **valid, closed solid**, that orientation
    ///   is *always* consistently outward, even after a mirror (negative-determinant transform):
    ///   ``mirrored(planeNormal:planeOrigin:)`` doesn't naively re-tessellate flipped geometry,
    ///   OCCT's `BRepBuilderAPI_Transform` compensates by flipping each face's orientation flag,
    ///   preserving the invariant that a valid solid's faces classify consistently outward.
    ///   Confirmed empirically (#375): a box and its mirror both mesh 12/12 triangles outward,
    ///   with the identical FORWARD/REVERSED face split before and after. There is currently no
    ///   way, via a valid `Shape`, to obtain a mesh whose winding reflects an applied mirror, a
    ///   caller who needs deliberately caller-controlled (including "wrong-way") winding, e.g. to
    ///   test orientation-sensitive downstream code, should build a ``Mesh`` directly via
    ///   ``Mesh/init(vertices:normals:indices:)`` instead of going through a `Shape`.
    public func mesh(
        linearDeflection: Double = 0.1,
        angularDeflection: Double = 0.5
    ) -> Mesh? {
        guard let meshHandle = OCCTShapeCreateMesh(handle, linearDeflection, angularDeflection)
        else { return nil }
        return Mesh(handle: meshHandle)
    }

    /// Generate a triangulated mesh with progress + cancellation support.
    ///
    /// Wraps `BRepMesh_IncrementalMesh::Perform(Message_ProgressRange&)` so callers can
    /// observe meshing progress on large or finely-tessellated assemblies and cooperatively
    /// cancel via `progress.shouldCancel()`. After meshing completes, the shape's faces
    /// have triangulations attached and `mesh()` (no progress) can extract them.
    ///
    /// This is the supported way to bound meshing of untrusted geometry: OCCT polls the range
    /// densely (before each face in `BRepMesh_FaceDiscret`, at each deflection-control pass, and
    /// per vertex in `BRepMesh_Delaun`), so a wall-clock deadline in `shouldCancel()` interrupts
    /// even the pathological offset surfaces of
    /// [#286](https://github.com/SecondMouseAU/OCCTSwift/issues/286). Measured on the #286 face,
    /// which takes 249 s to mesh in full: a 10 s deadline throws ``ImportError/cancelled`` after
    /// 10.1 s, having polled 154,898 times.
    ///
    /// ```swift
    /// final class Deadline: ImportProgress, @unchecked Sendable {
    ///     private let start = Date()
    ///     func progress(fraction: Double, step: String) {}
    ///     func shouldCancel() -> Bool { Date().timeIntervalSince(start) > 10 }
    /// }
    ///
    /// do {
    ///     _ = try shape.meshWithProgress(linearDeflection: 0.1, progress: Deadline())
    /// } catch ImportError.cancelled {
    ///     // Gave up after 10s, the geometry is probably degenerate; see `bounds` pre-checks.
    /// }
    /// ```
    ///
    /// - Note: Before v1.11.1 this could not cancel at all. The bridge used the
    ///   `BRepMesh_IncrementalMesh(shape, linDefl, isRelative, angDefl)` constructor, which calls
    ///   `Perform()` internally with a *null* progress range, the whole mesh was built
    ///   uninterruptibly before the range was polled, and the shape was then meshed a second time.
    ///   Cancellation still *threw*, because `UserBreak()` was checked afterwards, which is what
    ///   made the defect look like an OCCT limitation in v1.10.2's docs.
    ///
    /// - Throws: `ImportError.cancelled` if the meshing was cancelled cooperatively.
    /// - Returns: The same shape (with triangulations attached) on success, or nil on
    ///   internal failure (no exception thrown for non-cancellation failures, matching
    ///   the existing `mesh()` API).
    @discardableResult
    public func meshWithProgress(
        linearDeflection: Double = 0.1,
        angularDeflection: Double = 0.5,
        progress: ImportProgress? = nil
    ) throws -> Shape {
        var cancelled: Bool = false
        let result: OCCTShapeRef? = withImportProgress(progress) { ctx in
            OCCTShapeIncrementalMeshProgress(
                handle, linearDeflection, angularDeflection, ctx, &cancelled)
        }
        if cancelled { throw ImportError.cancelled }
        // Triangulations are attached to self; the returned handle wraps the same
        // TopoDS_Shape. Release the new wrapper if we don't need it as a separate object.
        if let result {
            OCCTShapeRelease(result)
        }
        return self
    }

    /// Generate a triangulated mesh with enhanced parameters.
    ///
    /// This method provides fine-grained control over tessellation quality,
    /// useful for CAM toolpath generation or high-quality visualization.
    ///
    /// ```swift
    /// var params = MeshParameters.default
    /// params.deflection = 0.02  // Very fine mesh
    /// params.inParallel = true  // Multi-threaded
    /// let mesh = shape.mesh(parameters: params)
    /// ```
    ///
    /// - Parameter parameters: Enhanced mesh parameters
    /// - Returns: A `Mesh` with the specified quality settings
    /// - Note: Same orientation guarantee as ``mesh(linearDeflection:angularDeflection:)``, see
    ///   its doc for details on why a valid solid's mesh is always consistently outward.
    public func mesh(parameters: MeshParameters) -> Mesh? {
        let bridgeParams = parameters.toBridge()
        guard let meshHandle = OCCTShapeCreateMeshWithParams(handle, bridgeParams) else {
            return nil
        }
        return Mesh(handle: meshHandle)
    }

    // MARK: - Edge Discretization

    /// Get a discretized edge as a polyline.
    ///
    /// This method adaptively samples points along a B-Rep edge using
    /// curvature-based deflection control. Useful for:
    /// - Contour toolpath generation
    /// - Edge visualization
    /// - G-code generation from curve edges
    ///
    /// - Parameters:
    ///   - index: Edge index (0-based)
    ///   - deflection: Maximum chord deviation
    ///   - maxPoints: Output *capacity*, clamped into `0`...``Sampling/maximumSampleCount``;
    ///     a capacity of 0 or less returns nil (#558). The deflection decides the actual point count.
    /// - Returns: Array of 3D points along the edge, or nil if edge not found
    public func edgePolyline(
        at index: Int,
        deflection: Double = 0.1,
        maxPoints: Int = 1000
    ) -> [SIMD3<Double>]? {
        let capacity = Sampling.capacity(maxPoints)
        guard capacity > 0 else { return nil }
        var points = [Double](repeating: 0, count: capacity * 3)
        let numPoints = points.withUnsafeMutableBufferPointer { buffer in
            OCCTShapeGetEdgePolyline(
                handle, Int32(index), deflection, buffer.baseAddress, Int32(capacity))
        }

        guard numPoints > 0 else { return nil }

        var result: [SIMD3<Double>] = []
        result.reserveCapacity(Int(numPoints))

        for i in 0..<Int(numPoints) {
            result.append(
                SIMD3(
                    points[i * 3],
                    points[i * 3 + 1],
                    points[i * 3 + 2]
                ))
        }

        return result
    }

    /// Get all edges as discretized polylines.
    ///
    /// Discretizes every edge in a single bridge pass. Edges that fail discretization
    /// (including degenerate ones) are skipped.
    ///
    /// The result is dense, when an edge is skipped, later polylines shift down, so a
    /// polyline's position does NOT reliably equal its edge index. Consumers that map
    /// polylines back to topology (`edge(at:)`, pick identity) should use
    /// ``allEdgePolylinesIndexed(deflection:maxPointsPerEdge:)`` instead.
    ///
    /// - Parameters:
    ///   - deflection: Maximum chord deviation
    ///   - maxPointsPerEdge: Maximum points per edge
    /// - Returns: Array of polylines, one per successfully discretized edge
    public func allEdgePolylines(
        deflection: Double = 0.1,
        maxPointsPerEdge: Int = 1000
    ) -> [[SIMD3<Double>]] {
        allEdgePolylinesIndexed(deflection: deflection, maxPointsPerEdge: maxPointsPerEdge)
            .map(\.points)
    }

    /// As ``allEdgePolylines(deflection:maxPointsPerEdge:)``, but each polyline carries
    /// its ORIGINAL edge index, the same index space as ``edgePolyline(at:deflection:maxPoints:)``
    /// and ``edge(at:)``.
    ///
    /// Edges that fail discretization (including degenerate ones, e.g. sphere pole
    /// seams) are skipped, and with the dense variant that skip silently shifts every
    /// later polyline's position. Consumers that need to round-trip a polyline back to
    /// topology (per-segment edge pick indices, wireframe → `TopoDS_Edge` mapping) need
    /// the explicit index this variant preserves. Same single bulk bridge pass,
    /// O(edges), issue #275.
    ///
    /// - Parameters:
    ///   - deflection: Maximum chord deviation
    ///   - maxPointsPerEdge: Per-edge output *capacity*, honoured within `2...`
    ///     ``Sampling/maximumSampleCount``; outside that range the result is empty (#558). This
    ///     one keeps its existing lower bound of 2 rather than clamping to 0, since it is also
    ///     passed straight to the bridge's bulk pass.
    /// - Returns: `(edgeIndex, points)` pairs, ascending by `edgeIndex`, one per
    ///   successfully discretized edge
    public func allEdgePolylinesIndexed(
        deflection: Double = 0.1,
        maxPointsPerEdge: Int = 1000
    ) -> [(edgeIndex: Int, points: [SIMD3<Double>])] {
        // Build 3D curves for all edges upfront. Lofted/swept shapes may only
        // have pcurves; this ensures explicit 3D curves exist before discretization.
        // The tolerance is spelled out because this used to call BRepLib::BuildCurves3d's
        // no-tolerance overload, which is `BuildCurves3d(S, 1.0e-5)` and nothing else (#498).
        // A false result means some edge has no buildable 3D curve; that edge is skipped below.
        buildCurves3d(tolerance: 1e-5)

        // One bulk pass: the bridge builds the edge map once. Looping `edgePolyline(at:)`
        // instead rebuilds it per call, making this O(edges²), 20 s for a 12k-edge shell,
        // and unusable on mesh-scale shapes (issue #275).
        guard let maxPointsPerEdge = Sampling.requested(maxPointsPerEdge),
            let polys = OCCTShapeComputeAllEdgePolylines(
                handle, deflection, Int32(maxPointsPerEdge))
        else { return [] }
        defer { OCCTEdgePolylinesRelease(polys) }

        let count = Int(OCCTEdgePolylinesGetEdgeCount(polys))
        var result: [(edgeIndex: Int, points: [SIMD3<Double>])] = []
        result.reserveCapacity(count)

        var scratch = [Double](repeating: 0, count: maxPointsPerEdge * 3)
        for i in 0..<count {
            let written = scratch.withUnsafeMutableBufferPointer { buffer in
                Int(
                    OCCTEdgePolylinesCopyPoints(
                        polys, Int32(i), buffer.baseAddress, Int32(maxPointsPerEdge)))
            }
            guard written > 0 else { continue }  // degenerate / failed, skipped, as before

            var polyline: [SIMD3<Double>] = []
            polyline.reserveCapacity(written)
            for j in 0..<written {
                polyline.append(
                    SIMD3(
                        scratch[j * 3],
                        scratch[j * 3 + 1],
                        scratch[j * 3 + 2]
                    ))
            }
            result.append((edgeIndex: i, points: polyline))
        }

        return result
    }

    // MARK: - Import

    /// Load a shape from a STEP file.
    ///
    /// - Parameters:
    ///   - url: URL to the STEP file.
    ///   - progress: Optional progress + cancellation channel.
    /// - Throws: Whatever ``loadSTEP(fromPath:progress:)`` throws: a read, parse or cancellation error.
    /// - Returns: The imported shape.
    public static func load(from url: URL, progress: ImportProgress? = nil) throws -> Shape {
        try loadSTEP(fromPath: url.path, progress: progress)
    }

    /// Load a shape from a STEP file path.
    public static func load(fromPath path: String, progress: ImportProgress? = nil) throws -> Shape
    {
        try loadSTEP(fromPath: path, progress: progress)
    }

    /// Load a shape from a STEP file (alias for ``load(from:progress:)`` with explicit naming).
    public static func loadSTEP(from url: URL, progress: ImportProgress? = nil) throws -> Shape {
        try loadSTEP(fromPath: url.path, progress: progress)
    }

    /// Load a shape from a STEP file path with optional progress.
    public static func loadSTEP(fromPath path: String, progress: ImportProgress? = nil) throws
        -> Shape
    {
        var cancelled: Bool = false
        let handle: OCCTShapeRef? = withImportProgress(progress) { ctx in
            OCCTImportSTEPProgress(path, ctx, &cancelled)
        }
        if cancelled { throw ImportError.cancelled }
        guard let handle else {
            throw ImportError.importFailed("Failed to import STEP file: \(path)")
        }
        return Shape(handle: handle)
    }

    // MARK: - STEP Reader Control (v0.58.0)

    /// Get the number of transferable roots in a STEP file.
    ///
    /// Use this to inspect a STEP file before importing specific roots.
    ///
    /// - Parameter url: URL to the STEP file
    /// - Returns: Number of roots (0 if file can't be read)
    public static func stepRootCount(url: URL) -> Int {
        Int(OCCTSTEPReaderNbRoots(url.path))
    }

    /// Get the number of transferable roots in a STEP file.
    public static func stepRootCount(path: String) -> Int {
        Int(OCCTSTEPReaderNbRoots(path))
    }

    /// Import a specific root from a STEP file.
    ///
    /// - Parameters:
    ///   - url: URL to the STEP file
    ///   - rootIndex: 1-based root index
    /// - Returns: The imported shape
    /// - Throws: ImportError if import fails
    public static func loadSTEPRoot(from url: URL, rootIndex: Int) throws -> Shape {
        guard let handle = OCCTImportSTEPRoot(url.path, Int32(rootIndex)) else {
            throw ImportError.importFailed(
                "Failed to import root \(rootIndex) from: \(url.lastPathComponent)")
        }
        return Shape(handle: handle)
    }

    /// Import a specific root from a STEP file.
    public static func loadSTEPRoot(fromPath path: String, rootIndex: Int) throws -> Shape {
        guard let handle = OCCTImportSTEPRoot(path, Int32(rootIndex)) else {
            throw ImportError.importFailed("Failed to import root \(rootIndex) from: \(path)")
        }
        return Shape(handle: handle)
    }

    /// Import a STEP file with a specific system length unit.
    ///
    /// - Parameters:
    ///   - url: URL to the STEP file
    ///   - unitInMeters: System length unit in meters (e.g. 0.001 for mm, 0.0254 for inch)
    ///   - progress: Optional progress + cancellation channel
    /// - Returns: The imported shape in the specified unit system
    /// - Throws: ImportError if import fails
    public static func loadSTEP(
        from url: URL, unitInMeters: Double, progress: ImportProgress? = nil
    ) throws -> Shape {
        try loadSTEP(fromPath: url.path, unitInMeters: unitInMeters, progress: progress)
    }

    /// Import a STEP file with a specific system length unit.
    public static func loadSTEP(
        fromPath path: String, unitInMeters: Double, progress: ImportProgress? = nil
    ) throws -> Shape {
        var cancelled: Bool = false
        let handle: OCCTShapeRef? = withImportProgress(progress) { ctx in
            OCCTImportSTEPWithUnitProgress(path, unitInMeters, ctx, &cancelled)
        }
        if cancelled { throw ImportError.cancelled }
        guard let handle else {
            throw ImportError.importFailed("Failed to import with unit from: \(path)")
        }
        return Shape(handle: handle)
    }

    /// Get the number of shapes in a STEP file after full transfer.
    ///
    /// - Parameter url: URL to the STEP file
    /// - Returns: Number of shapes (0 if file can't be read)
    public static func stepShapeCount(url: URL) -> Int {
        Int(OCCTSTEPReaderNbShapes(url.path))
    }

    /// Get the number of shapes in a STEP file after full transfer.
    public static func stepShapeCount(path: String) -> Int {
        Int(OCCTSTEPReaderNbShapes(path))
    }

    // MARK: - Robust STEP Import

    /// Load a STEP file with robust handling: sewing, solid creation, and shape healing.
    ///
    /// This method is recommended for STEP files that may contain:
    /// - Disconnected faces that need sewing
    /// - Shells that need conversion to solids
    /// - Geometry issues that require healing
    ///
    /// ## Progress and cancellation
    ///
    /// `progress` observes the import and cancels it cooperatively. Every phase is bounded by it:
    /// the transfer takes `fraction` 0…0.5 and the repair (sewing, then healing) 0.5…1.0, matching
    /// their measured cost, repair is 38–50% of the work, not a coda to the transfer. A wall-clock
    /// deadline in `shouldCancel()` therefore bounds the whole call, and cancelling mid-repair
    /// throws rather than returning the partially-repaired shape.
    ///
    /// Cancelling *anywhere* throws ``ImportError/cancelled``, including during the transfer, which
    /// used to report `ImportError.importFailed` instead (#525).
    ///
    /// ```swift
    /// final class Deadline: ImportProgress, @unchecked Sendable {
    ///     private let start = Date()
    ///     func progress(fraction: Double, step: String) { print("\(Int(fraction * 100))%") }
    ///     func shouldCancel() -> Bool { Date().timeIntervalSince(start) > 10 }
    /// }
    ///
    /// do {
    ///     let shape = try Shape.loadRobust(from: stepURL, progress: Deadline())
    ///     print(shape.isValid)
    /// } catch ImportError.cancelled {
    ///     // Gave up after 10s, repairing untrusted geometry can be pathological.
    /// }
    /// ```
    ///
    /// - Note: **Parsing is not covered.** OCCT's `STEPControl_Reader::ReadFile` takes no
    ///   `Message_ProgressRange`, so the file is parsed *before* the progress indicator exists.
    ///   Reading a large STEP file reports nothing and cannot be cancelled; `fraction` and the
    ///   deadline only bound the transfer and repair that follow.
    ///
    /// - Parameters:
    ///   - url: URL to the STEP file
    ///   - progress: Optional progress + cancellation channel.
    /// - Returns: Processed shape suitable for CAM operations
    /// - Throws: `ImportError.cancelled` if cancelled, `ImportError.importFailed` on failure.
    public static func loadRobust(from url: URL, progress: ImportProgress? = nil) throws -> Shape {
        try loadRobust(fromPath: url.path, progress: progress)
    }

    /// Load a STEP file with robust handling: sewing, solid creation, and shape healing.
    ///
    /// See ``loadRobust(from:progress:)`` for the progress/cancellation contract and its limits.
    ///
    /// ```swift
    /// let shape = try Shape.loadRobust(fromPath: "/tmp/part.step")
    /// ```
    ///
    /// - Parameters:
    ///   - path: Path to the STEP file
    ///   - progress: Optional progress + cancellation channel.
    /// - Returns: Processed shape suitable for CAM operations
    /// - Throws: `ImportError.cancelled` if cancelled, `ImportError.importFailed` on failure.
    public static func loadRobust(fromPath path: String, progress: ImportProgress? = nil) throws
        -> Shape
    {
        var cancelled: Bool = false
        let handle: OCCTShapeRef? = withImportProgress(progress) { ctx in
            OCCTImportSTEPRobustProgress(path, ctx, &cancelled)
        }
        if cancelled { throw ImportError.cancelled }
        guard let handle else {
            throw ImportError.importFailed("Failed to import: \(path)")
        }
        return Shape(handle: handle)
    }

    /// Load a STEP file with diagnostic information about processing steps.
    ///
    /// Use this when you need to understand what processing was applied to the imported geometry.
    ///
    /// - Parameter url: URL to the STEP file
    /// - Returns: Import result containing the shape and processing information
    /// - Throws: ImportError if import fails
    ///
    /// ## Example
    ///
    /// ```swift
    /// let result = try Shape.loadWithDiagnostics(from: stepFile)
    /// print(result.summary)  // "Shell → Solid (processing: sewing, solid creation, healing)"
    /// let shape = result.shape
    /// ```
    public static func loadWithDiagnostics(from url: URL) throws -> ImportResult {
        let result = OCCTImportSTEPWithDiagnostics(url.path)
        guard let handle = result.shape else {
            throw ImportError.importFailed("Failed to import: \(url.lastPathComponent)")
        }
        return ImportResult(
            shape: Shape(handle: handle),
            originalType: ShapeType(rawValue: Int(result.originalType)) ?? .unknown,
            resultType: ShapeType(rawValue: Int(result.resultType)) ?? .unknown,
            sewingApplied: result.sewingApplied,
            solidCreated: result.solidCreated,
            healingApplied: result.healingApplied,
            solidsCreated: Int(result.solidsCreated)
        )
    }

    // MARK: - IGES Import (v0.10.0)

    /// Load a shape from an IGES file.
    ///
    /// IGES (Initial Graphics Exchange Specification) is a legacy CAD format
    /// still commonly used in manufacturing and older CAD systems.
    ///
    /// - Parameters:
    ///   - url: URL to the IGES file (.igs or .iges)
    ///   - progress: Optional progress + cancellation channel
    /// - Returns: Imported shape
    /// - Throws: ImportError if import fails
    public static func loadIGES(from url: URL, progress: ImportProgress? = nil) throws -> Shape {
        try loadIGES(fromPath: url.path, progress: progress)
    }

    /// Load a shape from an IGES file path.
    public static func loadIGES(fromPath path: String, progress: ImportProgress? = nil) throws
        -> Shape
    {
        var cancelled: Bool = false
        let handle: OCCTShapeRef? = withImportProgress(progress) { ctx in
            OCCTImportIGESProgress(path, ctx, &cancelled)
        }
        if cancelled { throw ImportError.cancelled }
        guard let handle else {
            throw ImportError.importFailed("Failed to import IGES file: \(path)")
        }
        return Shape(handle: handle)
    }

    /// Load an IGES file, healing the transferred geometry (`ShapeFix_Shape`).
    ///
    /// Recommended for IGES files whose geometry needs repair before use. Note this heals but does
    /// **not** sew, unlike ``loadRobust(from:)``, which sews STEP shells into solids.
    ///
    /// ## Progress and cancellation
    ///
    /// `progress` observes the import and cancels it cooperatively. The two phases each take half
    /// the reported `fraction`, transfer spans 0…0.5, healing 0.5…1.0, which matches their
    /// measured cost (healing is 38–50% of the work). `shouldCancel()` interrupts **either** phase:
    /// a deadline bounds the whole call, and cancelling mid-heal throws rather than returning the
    /// partially-healed shape.
    ///
    /// ```swift
    /// final class Deadline: ImportProgress, @unchecked Sendable {
    ///     private let start = Date()
    ///     func progress(fraction: Double, step: String) { print("\(Int(fraction * 100))%") }
    ///     func shouldCancel() -> Bool { Date().timeIntervalSince(start) > 10 }
    /// }
    ///
    /// do {
    ///     let shape = try Shape.loadIGESRobust(from: igesURL, progress: Deadline())
    ///     print(shape.isValid)
    /// } catch ImportError.cancelled {
    ///     // Gave up after 10s, healing untrusted geometry can be pathological.
    /// }
    /// ```
    ///
    /// - Note: **Parsing is not covered.** OCCT's `IGESControl_Reader::ReadFile` takes no
    ///   `Message_ProgressRange`, so the file is parsed *before* the progress indicator exists.
    ///   Reading a large IGES file reports nothing and cannot be cancelled; `fraction` and the
    ///   deadline only bound the transfer and healing that follow.
    ///
    /// - Parameters:
    ///   - url: URL to the IGES file
    ///   - progress: Optional progress + cancellation channel.
    /// - Returns: Transferred shape with healing applied
    /// - Throws: `ImportError.cancelled` if cancelled, `ImportError.importFailed` on failure.
    public static func loadIGESRobust(from url: URL, progress: ImportProgress? = nil) throws
        -> Shape
    {
        try loadIGESRobust(fromPath: url.path, progress: progress)
    }

    /// Load an IGES file from a path, healing the transferred geometry.
    ///
    /// See ``loadIGESRobust(from:progress:)`` for the progress/cancellation contract and its limits.
    ///
    /// ```swift
    /// let shape = try Shape.loadIGESRobust(fromPath: "/tmp/part.igs")
    /// ```
    public static func loadIGESRobust(fromPath path: String, progress: ImportProgress? = nil) throws
        -> Shape
    {
        var cancelled: Bool = false
        let handle: OCCTShapeRef? = withImportProgress(progress) { ctx in
            OCCTImportIGESRobustProgress(path, ctx, &cancelled)
        }
        if cancelled { throw ImportError.cancelled }
        guard let handle else {
            throw ImportError.importFailed("Failed to import IGES file: \(path)")
        }
        return Shape(handle: handle)
    }

    // MARK: - IGES Reader Control (v0.59.0)

    /// Get the number of transferable roots in an IGES file.
    public static func igesRootCount(url: URL) -> Int {
        Int(OCCTIGESReaderNbRoots(url.path))
    }

    /// Get the number of transferable roots in an IGES file.
    public static func igesRootCount(path: String) -> Int {
        Int(OCCTIGESReaderNbRoots(path))
    }

    /// Import a specific root from an IGES file (1-based index).
    public static func loadIGESRoot(from url: URL, rootIndex: Int) throws -> Shape {
        guard let handle = OCCTImportIGESRoot(url.path, Int32(rootIndex)) else {
            throw ImportError.importFailed(
                "Failed to import IGES root \(rootIndex) from: \(url.lastPathComponent)")
        }
        return Shape(handle: handle)
    }

    /// Import a specific root from an IGES file (1-based index).
    public static func loadIGESRoot(fromPath path: String, rootIndex: Int) throws -> Shape {
        guard let handle = OCCTImportIGESRoot(path, Int32(rootIndex)) else {
            throw ImportError.importFailed("Failed to import IGES root \(rootIndex) from: \(path)")
        }
        return Shape(handle: handle)
    }

    /// Get the number of shapes in an IGES file after full transfer.
    public static func igesShapeCount(url: URL) -> Int {
        Int(OCCTIGESReaderNbShapes(url.path))
    }

    /// Get the number of shapes in an IGES file after full transfer.
    public static func igesShapeCount(path: String) -> Int {
        Int(OCCTIGESReaderNbShapes(path))
    }

    /// Import only visible entities from an IGES file.
    public static func loadIGESVisible(from url: URL) throws -> Shape {
        guard let handle = OCCTImportIGESVisible(url.path) else {
            throw ImportError.importFailed(
                "Failed to import visible IGES entities from: \(url.lastPathComponent)")
        }
        return Shape(handle: handle)
    }

    /// Import only visible entities from an IGES file.
    public static func loadIGESVisible(fromPath path: String) throws -> Shape {
        guard let handle = OCCTImportIGESVisible(path) else {
            throw ImportError.importFailed("Failed to import visible IGES entities from: \(path)")
        }
        return Shape(handle: handle)
    }

    // MARK: - BREP Import (v0.10.0)

    /// Load a shape from OCCT's native BREP format.
    ///
    /// BREP is OCCT's native format for exact B-Rep geometry. It preserves
    /// the full precision of the geometry and is useful for:
    /// - Fast caching of intermediate results
    /// - Debugging geometry issues
    /// - Archiving exact geometry
    ///
    /// - Parameter url: URL to the BREP file (.brep)
    /// - Returns: Imported shape
    /// - Throws: ImportError if import fails
    public static func loadBREP(from url: URL) throws -> Shape {
        guard let handle = OCCTImportBREP(url.path) else {
            throw ImportError.importFailed("Failed to import BREP file: \(url.lastPathComponent)")
        }
        return Shape(handle: handle)
    }

    /// Load a shape from a BREP file path.
    public static func loadBREP(fromPath path: String) throws -> Shape {
        guard let handle = OCCTImportBREP(path) else {
            throw ImportError.importFailed("Failed to import BREP file: \(path)")
        }
        return Shape(handle: handle)
    }

    // MARK: - STL Import (v0.17.0)

    /// Load a shape from an STL file.
    ///
    /// Builds one planar `TopoDS_Face` per STL facet via OCCT's `StlAPI_Reader`
    /// (`BRepBuilderAPI_MakeShapeOnMesh`); faces are unsewn, call ``sewn(tolerance:)`` or use
    /// ``loadSTLRobust(from:sewingTolerance:)`` if you need a connected shell/solid.
    ///
    /// - Parameter url: URL to the STL file (.stl)
    /// - Returns: Imported shape
    /// - Throws: ImportError if import fails
    /// - Note: Each facet's vertex winding is preserved exactly, including a globally-reversed
    ///   (but self-consistent) file, confirmed empirically (#375) by round-tripping a uniformly
    ///   reversed-winding box through `loadSTL` + ``mesh(linearDeflection:angularDeflection:)``
    ///   and finding all 12 triangles consistently inward, with zero shared-edge orientation
    ///   conflicts. If a round-tripped mesh comes back with *locally* inconsistent winding (some
    ///   faces inward, some outward), the input STL itself is locally inconsistent, this method
    ///   doesn't introduce that defect, it faithfully reproduces one already in the file.
    public static func loadSTL(from url: URL) throws -> Shape {
        guard let handle = OCCTImportSTL(url.path) else {
            throw ImportError.importFailed("Failed to import STL file: \(url.lastPathComponent)")
        }
        return Shape(handle: handle)
    }

    /// Load a shape from an STL file path.
    ///
    /// - Note: Same winding-fidelity guarantee as ``loadSTL(from:)``, see its doc for details.
    public static func loadSTL(fromPath path: String) throws -> Shape {
        guard let handle = OCCTImportSTL(path) else {
            throw ImportError.importFailed("Failed to import STL file: \(path)")
        }
        return Shape(handle: handle)
    }

    /// Load an STL file with robust healing (sew + solid creation + heal).
    ///
    /// - Parameters:
    ///   - url: URL to the STL file
    ///   - sewingTolerance: Tolerance for sewing disconnected faces (default: 1e-6)
    /// - Returns: Processed shape suitable for solid operations
    /// - Throws: ImportError if import fails
    public static func loadSTLRobust(from url: URL, sewingTolerance: Double = 1e-6) throws -> Shape
    {
        guard let handle = OCCTImportSTLRobust(url.path, sewingTolerance) else {
            throw ImportError.importFailed("Failed to import STL file: \(url.lastPathComponent)")
        }
        return Shape(handle: handle)
    }

    /// Load an STL file with robust healing from a path.
    public static func loadSTLRobust(fromPath path: String, sewingTolerance: Double = 1e-6) throws
        -> Shape
    {
        guard let handle = OCCTImportSTLRobust(path, sewingTolerance) else {
            throw ImportError.importFailed("Failed to import STL file: \(path)")
        }
        return Shape(handle: handle)
    }

    // MARK: - OBJ Import (v0.17.0)

    /// Load a shape from an OBJ file.
    ///
    /// - Parameter url: URL to the OBJ file (.obj)
    /// - Returns: Imported shape
    /// - Throws: ImportError if import fails
    public static func loadOBJ(from url: URL) throws -> Shape {
        guard let handle = OCCTImportOBJ(url.path) else {
            throw ImportError.importFailed("Failed to import OBJ file: \(url.lastPathComponent)")
        }
        return Shape(handle: handle)
    }

    /// Load a shape from an OBJ file path.
    public static func loadOBJ(fromPath path: String) throws -> Shape {
        guard let handle = OCCTImportOBJ(path) else {
            throw ImportError.importFailed("Failed to import OBJ file: \(path)")
        }
        return Shape(handle: handle)
    }

    // MARK: - Geometry Construction (v0.11.0)

    /// Create a planar face from a closed wire.
    ///
    /// - Parameters:
    ///   - wire: A closed wire defining the face boundary
    ///   - planar: If true, requires the wire to be planar (default: true)
    ///
    /// - Returns: A face shape, or nil if creation fails
    ///
    /// ## Example
    ///
    /// ```swift
    /// let rect = Wire.rectangle(width: 10, height: 5)!
    /// let face = Shape.face(from: rect)!
    /// let box = face.extruded(direction: [0, 0, 1], length: 3)
    /// ```
    public static func face(from wire: Wire, planar: Bool = true) -> Shape? {
        guard let handle = OCCTShapeCreateFaceFromWire(wire.handle, planar) else {
            return nil
        }
        return Shape(handle: handle)
    }

    /// Create a face with holes from outer and inner wires.
    ///
    /// ## Winding contract
    ///
    /// Each hole wire ends up wound **opposite** to the outer boundary (measured in the
    /// face plane), as OCCT requires for the hole to subtract area. The winding you pass
    /// does **not** matter: the function measures each hole's signed area against the outer
    /// and reverses a hole only when its winding currently matches the outer's. A hole you
    /// pass already wound opposite (the geometrically correct sense) is left untouched, and
    /// a hole wound the same way as the outer is reversed for you. Either input yields the
    /// same valid face with the hole correctly subtracted.
    ///
    /// - Parameters:
    ///   - outer: The outer boundary wire (closed)
    ///   - holes: Array of inner boundary wires defining holes; any winding is accepted
    ///
    /// - Returns: A face with holes, or nil if creation fails
    ///
    /// ## Example
    ///
    /// ```swift
    /// let outer = Wire.rectangle(width: 20, height: 20)!
    /// let hole1 = Wire.circle(radius: 3)!.translated(x: -5, y: 0, z: 0)
    /// let hole2 = Wire.circle(radius: 3)!.translated(x: 5, y: 0, z: 0)
    /// let face = Shape.face(outer: outer, holes: [hole1, hole2])!
    /// ```
    public static func face(outer: Wire, holes: [Wire]) -> Shape? {
        var holeHandles = holes.map { $0.handle as OCCTWireRef? }
        guard
            let handle = holeHandles.withUnsafeMutableBufferPointer({ buffer in
                OCCTShapeCreateFaceWithHoles(outer.handle, buffer.baseAddress, Int32(holes.count))
            })
        else {
            return nil
        }
        return Shape(handle: handle)
    }

    /// Create a solid from a closed shell.
    ///
    /// Converts a shell (set of connected faces) into a solid. The shell
    /// must be closed (no gaps) for this to succeed.
    ///
    /// One solid is built per *body-bounding* shell, not just the first shell found: every
    /// shell that an **even** number of the other shells in its group enclose, where a group
    /// is one solid's own shells, or all the shells belonging to no solid (the usual shape
    /// of sewing output). A single body comes back as a solid, several as a compound in
    /// exploration order. This matches ``Shape/solidFromShellFixed()``, which asks the same
    /// question of the same input.
    ///
    /// *Cavity* shells are deliberately skipped: a hole is not a body, and building it as a
    /// positive solid would yield a compound whose volume double-counts the part. A body
    /// nested inside another body's cavity is enclosed twice, so it is still read as a body.
    /// To rebuild a solid that keeps its cavities, use ``Shape/solidFromShells(_:)`` with
    /// the outer shell first.
    ///
    /// - Parameter shell: A shell shape (typically from sewing operations)
    /// - Returns: A solid, a compound of solids for multi-body input, or nil if the shape
    ///   holds no shell at all
    ///
    /// ## Example
    ///
    /// ```swift
    /// let sewn = Shape.sew(faces: faces, tolerance: 1e-6)!
    /// let solid = Shape.solid(from: sewn)!
    ///
    /// // Sewing two disjoint bodies yields two shells, so this yields two solids.
    /// let both = Shape.solid(from: Shape.sew(shapes: [bodyA, bodyB], tolerance: 1e-6)!)!
    /// print(both.solids.count)   // 2
    /// ```
    public static func solid(from shell: Shape) -> Shape? {
        guard let handle = OCCTShapeCreateSolidFromShell(shell.handle) else {
            return nil
        }
        return Shape(handle: handle)
    }

    /// Sew multiple shapes into a connected shell or solid.
    ///
    /// Sewing connects faces that share edges within the tolerance. This is
    /// useful for repairing imported geometry or combining separately created faces.
    ///
    /// - Parameters:
    ///   - shapes: Array of shapes (faces, shells) to sew together
    ///   - tolerance: Maximum gap size to close (default: 1e-6)
    ///
    /// - Returns: Sewn shape (shell or solid if closed), or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Create faces manually and sew into solid
    /// let faces = [topFace, bottomFace, frontFace, backFace, leftFace, rightFace]
    /// let solid = Shape.sew(shapes: faces, tolerance: 0.01)!
    /// ```
    public static func sew(shapes: [Shape], tolerance: Double = 1e-6) -> Shape? {
        guard !shapes.isEmpty else { return nil }

        var shapeHandles = shapes.map { $0.handle as OCCTShapeRef? }
        guard
            let handle = shapeHandles.withUnsafeMutableBufferPointer({ buffer in
                OCCTShapeSew(buffer.baseAddress, Int32(shapes.count), tolerance)
            })
        else {
            return nil
        }
        return Shape(handle: handle)
    }

    /// Sew two shapes together.
    ///
    /// - Parameters:
    ///   - shape: First shape to sew
    ///   - other: Second shape to sew
    ///   - tolerance: Maximum gap size to close (default: 1e-6)
    ///
    /// - Returns: Sewn shape, or nil on failure
    public static func sew(_ shape: Shape, with other: Shape, tolerance: Double = 1e-6) -> Shape? {
        guard let handle = OCCTShapeSewTwo(shape.handle, other.handle, tolerance) else {
            return nil
        }
        return Shape(handle: handle)
    }

    /// Sew this shape with another.
    ///
    /// - Parameters:
    ///   - other: Shape to sew with
    ///   - tolerance: Maximum gap size to close (default: 1e-6)
    ///
    /// - Returns: Sewn shape, or nil on failure
    public func sewn(with other: Shape, tolerance: Double = 1e-6) -> Shape? {
        Shape.sew(self, with: other, tolerance: tolerance)
    }

    // MARK: - Feature-Based Modeling (v0.12.0)

    /// Add a prismatic boss or pocket to the shape.
    ///
    /// - Parameters:
    ///   - profile: Wire profile to extrude (should be on a face of this shape)
    ///   - direction: Extrusion direction
    ///   - height: Extrusion height
    ///   - fuse: If true, adds material (boss); if false, removes material (pocket)
    ///
    /// - Returns: Modified shape, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// let box = Shape.box(width: 50, height: 50, depth: 10)
    /// let bossProfile = Wire.circle(radius: 5)!.offset3D(distance: 25, direction: SIMD3(0, 0, 1))!
    /// let withBoss = box.withPrism(profile: bossProfile, direction: SIMD3(0, 0, 1), height: 5, fuse: true)
    /// ```
    public func withPrism(profile: Wire, direction: SIMD3<Double>, height: Double, fuse: Bool)
        -> Shape?
    {
        guard
            let handle = OCCTShapePrism(
                self.handle, profile.handle,
                direction.x, direction.y, direction.z,
                height, fuse)
        else {
            return nil
        }
        return Shape(handle: handle)
    }

    /// Add a boss (raised feature) to the shape.
    ///
    /// - Parameters:
    ///   - profile: Wire profile to extrude
    ///   - direction: Extrusion direction
    ///   - height: Boss height
    ///
    /// - Returns: Shape with added boss, or nil on failure
    public func withBoss(profile: Wire, direction: SIMD3<Double>, height: Double) -> Shape? {
        withPrism(profile: profile, direction: direction, height: height, fuse: true)
    }

    /// Create a pocket (depression) in the shape.
    ///
    /// - Parameters:
    ///   - profile: Wire profile defining the pocket boundary
    ///   - direction: Pocket direction (into the shape)
    ///   - depth: Pocket depth
    ///
    /// - Returns: Shape with pocket, or nil on failure
    public func withPocket(profile: Wire, direction: SIMD3<Double>, depth: Double) -> Shape? {
        withPrism(profile: profile, direction: direction, height: depth, fuse: false)
    }

    /// Drill a cylindrical hole into the shape, by subtracting a cylinder from it.
    ///
    /// The bore is cut **along `direction`**, any axis, not just Z. The direction is
    /// normalized internally; a zero-length direction returns `nil`.
    ///
    /// The tool is a finite cylinder that **starts at `position`** and runs `depth` along
    /// `direction`; `depth <= 0` substitutes a length derived from the shape's bounding box, long
    /// enough to leave the far side. So a `depth` that overshoots the stock costs nothing, an entry
    /// point inside the shape drills only forward from there, and the input can be a shell or a face
    /// as readily as a solid.
    ///
    /// ## Or the feature drill
    ///
    /// ``cylindricalHole(axisOrigin:axisDirection:radius:extent:)`` wraps
    /// `BRepFeat_MakeCylindricalHole`, OCCT's dedicated feature-drilling operator. It is not a
    /// better version of this method, it answers a different question, and #496 measured six
    /// requests where the two disagree. Reach for it when you want the **solid's own faces** to
    /// bound the hole (``CylindricalHoleExtent/untilEnd``, ``CylindricalHoleExtent/thruNext``) or a
    /// diagnosis of *why* a drill is impossible (``cylindricalHoleStatus(axisOrigin:axisDirection:radius:extent:)``).
    /// Stay here when the hole starts where you say it starts, when the input is not a solid, or
    /// when an over-long depth should simply drill through.
    ///
    /// - Parameters:
    ///   - position: Position of hole center on the entry surface
    ///   - direction: Drill direction (into the shape); any non-zero axis
    ///   - radius: Hole radius; must exceed `Precision::Confusion` (1e-7), below which OCCT cuts
    ///     nothing and reports success
    ///   - depth: Hole depth (0 or less for a through-hole)
    ///
    /// - Returns: Shape with drilled hole, or nil on failure (including a zero-length direction or
    ///   a degenerate radius)
    ///
    /// ## Example
    ///
    /// ```swift
    /// let plate = Shape.box(width: 50, height: 50, depth: 10)
    /// // Through-hole down the Z axis:
    /// let drilled = plate.drilled(at: SIMD3(25, 25, 10), direction: SIMD3(0, 0, -1), radius: 5, depth: 0)
    ///
    /// // A hole bored across the width (+X), e.g. a bolt hole through a bar:
    /// let bar = Shape.box(width: 200, height: 60, depth: 16)
    /// let cross = bar?.drilled(at: SIMD3(-101, 0, 0), direction: SIMD3(1, 0, 0), radius: 6.5, depth: 0)
    /// ```
    public func drilled(
        at position: SIMD3<Double>, direction: SIMD3<Double>, radius: Double, depth: Double = 0
    ) -> Shape? {
        guard
            let handle = OCCTShapeDrillHole(
                self.handle,
                position.x, position.y, position.z,
                direction.x, direction.y, direction.z,
                radius, depth)
        else {
            return nil
        }
        return Shape(handle: handle)
    }

    /// Split the shape using a cutting tool.
    ///
    /// - Parameter tool: Shape to use as cutting tool
    /// - Returns: Array of resulting shapes after split, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// let box = Shape.box(width: 20, height: 20, depth: 20)
    /// let cuttingPlane = Shape.face(from: Wire.rectangle(width: 40, height: 40)!)!
    /// let halves = box.split(by: cuttingPlane.translated(by: SIMD3(0, 0, 10)))
    /// ```
    public func split(by tool: Shape) -> [Shape]? {
        var count: Int32 = 0
        guard let shapesPtr = OCCTShapeSplit(self.handle, tool.handle, &count),
            count > 0
        else {
            return nil
        }

        var shapes: [Shape] = []
        for i in 0..<Int(count) {
            if let shapeHandle = shapesPtr[i] {
                shapes.append(Shape(handle: shapeHandle))
            }
        }

        // Free only the array, not the shapes (we've taken ownership)
        OCCTFreeShapeArrayOnly(shapesPtr)

        return shapes.isEmpty ? nil : shapes
    }

    /// Split the shape by a plane.
    ///
    /// - Parameters:
    ///   - point: A point on the cutting plane
    ///   - normal: Normal vector of the cutting plane
    ///
    /// - Returns: Array of resulting shapes after split, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// let cube = Shape.box(width: 20, height: 20, depth: 20)
    /// // Split horizontally at Z=10
    /// let halves = cube.split(atPlane: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1))
    /// ```
    public func split(atPlane point: SIMD3<Double>, normal: SIMD3<Double>) -> [Shape]? {
        var count: Int32 = 0
        guard
            let shapesPtr = OCCTShapeSplitByPlane(
                self.handle,
                point.x, point.y, point.z,
                normal.x, normal.y, normal.z,
                &count),
            count > 0
        else {
            return nil
        }

        var shapes: [Shape] = []
        for i in 0..<Int(count) {
            if let shapeHandle = shapesPtr[i] {
                shapes.append(Shape(handle: shapeHandle))
            }
        }

        OCCTFreeShapeArrayOnly(shapesPtr)

        return shapes.isEmpty ? nil : shapes
    }

    /// Glue two shapes together at coincident faces.
    ///
    /// More efficient than boolean union when shapes have faces that perfectly align.
    ///
    /// - Parameters:
    ///   - shape1: First shape
    ///   - shape2: Second shape with coincident faces
    ///   - tolerance: Tolerance for face matching (default: 1e-6)
    ///
    /// - Returns: Glued shape, or nil on failure
    public static func glue(_ shape1: Shape, _ shape2: Shape, tolerance: Double = 1e-6) -> Shape? {
        guard let handle = OCCTShapeGlue(shape1.handle, shape2.handle, tolerance) else {
            return nil
        }
        return Shape(handle: handle)
    }

    /// Create an evolved shape (profile swept along spine with rotation).
    ///
    /// The profile is swept along the spine, with its orientation evolving
    /// to stay perpendicular to the spine.
    ///
    /// - Parameters:
    ///   - spine: Path wire to sweep along
    ///   - profile: Profile wire to sweep
    ///
    /// - Returns: Evolved shape, or nil on failure
    public static func evolved(spine: Wire, profile: Wire) -> Shape? {
        guard let handle = OCCTShapeCreateEvolved(spine.handle, profile.handle) else {
            return nil
        }
        return Shape(handle: handle)
    }

    /// Create an evolved shape with full parameter control.
    ///
    /// Extends the basic `evolved` method with control over join type, coordinate
    /// system, solid/volume mode, and tolerance.
    ///
    /// - Parameters:
    ///   - spine: Path wire to sweep along
    ///   - profile: Profile wire to sweep
    ///   - joinType: How to join offset edges (default: .arc)
    ///   - axeProf: If true, profile is in global coordinates; if false, local to spine
    ///   - solid: If true, produce a solid result
    ///   - volume: If true, use volume mode (removes self-intersections)
    ///   - tolerance: Tolerance for evolved shape creation
    /// - Returns: Evolved shape, or nil on failure
    public static func evolvedAdvanced(
        spine: Shape, profile: Wire,
        joinType: OffsetJoinType = .arc,
        axeProf: Bool = true,
        solid: Bool = true,
        volume: Bool = false,
        tolerance: Double = 1e-4
    ) -> Shape? {
        guard
            let h = OCCTShapeCreateEvolvedAdvanced(
                spine.handle, profile.handle,
                joinType.rawValue, axeProf,
                solid, volume, tolerance)
        else { return nil }
        return Shape(handle: h)
    }

    /// Create a linear pattern of the shape.
    ///
    /// - Parameters:
    ///   - direction: Direction of the pattern
    ///   - spacing: Distance between copies
    ///   - count: Number of copies (including original)
    ///
    /// - Returns: Compound containing all copies, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// let hole = Shape.cylinder(radius: 3, height: 10)
    /// let rowOfHoles = hole.linearPattern(direction: SIMD3(20, 0, 0), spacing: 20, count: 5)
    /// ```
    public func linearPattern(direction: SIMD3<Double>, spacing: Double, count: Int) -> Shape? {
        guard
            let handle = OCCTShapeLinearPattern(
                self.handle,
                direction.x, direction.y, direction.z,
                spacing, Int32(count))
        else {
            return nil
        }
        return Shape(handle: handle)
    }

    /// Create a circular pattern of the shape.
    ///
    /// This duplicates **the whole body** `count` times around the axis and returns
    /// a compound of the copies. It does **not** pattern features. If `self` is a
    /// solid that already has a hole/pocket cut into it, the result is `count`
    /// overlapping copies of that solid, the holes get filled by neighbouring
    /// copies, not replicated. For the bolt-circle use case ("drill one hole, then
    /// repeat it around the axis") pattern the *tool* shape and subtract it, or use
    /// ``circularPatternCut(tool:axisPoint:axisDirection:count:angle:timeout:)`` which does
    /// exactly that in one call.
    ///
    /// - Parameters:
    ///   - axisPoint: Point on the rotation axis
    ///   - axisDirection: Direction of the rotation axis
    ///   - count: Number of copies (including original)
    ///   - angle: Total angle to span in radians (0 for full circle)
    ///
    /// - Returns: Compound containing all copies, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// let hole = Shape.cylinder(radius: 3, height: 10).translated(by: SIMD3(20, 0, 0))
    /// // Create 6 hole *tools* in a circle around the Z axis, then subtract them
    /// let tools = hole.circularPattern(
    ///     axisPoint: .zero,
    ///     axisDirection: SIMD3(0, 0, 1),
    ///     count: 6,
    ///     angle: 0  // Full circle
    /// )
    /// let drilled = flange.subtracting(tools!)
    /// ```
    public func circularPattern(
        axisPoint: SIMD3<Double>, axisDirection: SIMD3<Double>, count: Int, angle: Double = 0
    ) -> Shape? {
        guard
            let handle = OCCTShapeCircularPattern(
                self.handle,
                axisPoint.x, axisPoint.y, axisPoint.z,
                axisDirection.x, axisDirection.y, axisDirection.z,
                Int32(count), angle)
        else {
            return nil
        }
        return Shape(handle: handle)
    }

    /// Replicate a feature (a cut/tool shape) around an axis and subtract all
    /// copies from this body in one operation.
    ///
    /// This is the feature-aware companion to
    /// ``circularPattern(axisPoint:axisDirection:count:angle:)``. Where the plain pattern
    /// duplicates the *body*, this one duplicates the *tool* `count` times around the axis and
    /// subtracts the resulting compound from `self`. It is the natural primitive for a bolt circle:
    /// build one hole tool, then pattern it.
    ///
    /// - Parameters:
    ///   - tool: The cutting feature to replicate (e.g. a cylinder positioned at
    ///     the first hole). Patterned about the same axis, then subtracted.
    ///   - axisPoint: Point on the rotation axis
    ///   - axisDirection: Direction of the rotation axis
    ///   - count: Number of tool copies (including the original `tool`)
    ///   - angle: Total angle to span in radians (0 for a full circle)
    ///   - timeout: Wall-clock bound in seconds for the subtraction this ends with (default
    ///     ``defaultBooleanTimeout``, 120s). `0`/negative = unbounded. Before #1067 the bound
    ///     applied but was not reachable from this signature, so a caller who knew their cut was
    ///     legitimately long had no way to raise it.
    /// - Returns: This body with all `count` features cut out, or nil on failure
    ///
    /// - Note: The three `nil` returns here are not distinguishable from each other:
    ///   `count <= 0`, the pattern failing, and the subtraction failing or exceeding `timeout`.
    ///   A caller who needs to tell them apart runs the two steps directly, which is all this
    ///   method does:
    ///   ```swift
    ///   guard let tools = tool.circularPattern(
    ///       axisPoint: .zero, axisDirection: SIMD3(0, 0, 1), count: 36) else { /* pattern */ }
    ///   switch blank.subtractionOutcome(tools, timeout: 600) {
    ///   case .success(let cut): /* use cut */ break
    ///   case .timedOut:         /* the machine, not the geometry */ break
    ///   case .failed:           /* the geometry */ break
    ///   }
    ///   ```
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Drill one hole, then repeat it 8× around the Z axis for a bolt circle
    /// let bcr = 40.0
    /// let hole = Shape.cylinder(radius: 3, height: 20)
    ///     .translated(by: SIMD3(bcr, 0, 0))
    /// let flange = blank.circularPatternCut(
    ///     tool: hole,
    ///     axisPoint: .zero,
    ///     axisDirection: SIMD3(0, 0, 1),
    ///     count: 8
    /// )
    ///
    /// // A legitimately long cut: raise the bound rather than getting nil at 120s
    /// let gear = blank.circularPatternCut(
    ///     tool: toothSpace, axisPoint: .zero, axisDirection: SIMD3(0, 0, 1),
    ///     count: 36, timeout: 600)
    /// ```
    public func circularPatternCut(
        tool: Shape, axisPoint: SIMD3<Double>, axisDirection: SIMD3<Double>, count: Int,
        angle: Double = 0, timeout: Double = Shape.defaultBooleanTimeout
    ) -> Shape? {
        guard count > 0 else { return nil }
        guard
            let tools = tool.circularPattern(
                axisPoint: axisPoint,
                axisDirection: axisDirection,
                count: count, angle: angle)
        else {
            return nil
        }
        return subtracting(tools, timeout: timeout)
    }

    // MARK: - Shape Type

    /// The topological type of the shape.
    public var shapeType: ShapeType {
        ShapeType(rawValue: Int(OCCTShapeGetType(handle))) ?? .unknown
    }

    /// Whether the shape is a valid closed solid suitable for CAM operations.
    ///
    /// This is a **topology / per-element** validity check (`BRepCheck_Analyzer`): it does
    /// **not** detect *global self-intersection* (overlapping faces of a single solid). A
    /// self-intersecting B-spline solid, e.g. from `loft(ruled: false)` on imperfectly
    /// corresponding profiles, can report `isValidSolid == true` yet poison downstream
    /// booleans (it made `subtracting` hang indefinitely before #206 bounded it). To screen
    /// for that, use ``isSelfIntersecting(timeout:)``. See also ``signedVolume`` /
    /// ``orientedForward()`` for the separate reversed-orientation hazard.
    ///
    /// This is also the reliable way to notice a ``healed()``/``fixSolid()`` demotion: both
    /// check `shapeType` first and return `false` immediately when it is anything but `.solid`,
    /// so a shell they could not close reads `false` here even though it reads `true` for
    /// plain ``isValid`` (#702). It answers a single body directly; for a multi-body result
    /// (a compound of solids), check each child, or `subShapeCount(ofType: .solid)` against the
    /// input body count, since the compound itself is never typed `.solid`.
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// print(box.isValidSolid)   // true: a genuine closed solid
    ///
    /// // A box missing one face, wrapped as a "solid" with no fixing, then healed: the open
    /// // shell cannot be closed, so healed() demotes it, and only isValidSolid catches it.
    /// let faces = box.subShapes(ofType: .face)
    /// let openShell = Shape.compound(Array(faces.dropFirst()))!.sewn()!
    /// let demoted = Shape.solidFromShells([openShell])!.healed()!
    /// print(demoted.isValid)      // true: a well-formed shell, no closure requirement
    /// print(demoted.isValidSolid) // false: catches the demotion isValid misses
    /// ```
    public var isValidSolid: Bool {
        OCCTShapeIsValidSolid(handle)
    }

    /// Whether this shape **self-intersects**, overlapping or interfering sub-faces, the
    /// defect that ``isValidSolid`` (a topology check) misses but that can make booleans
    /// hang or return garbage (#206/#208).
    ///
    /// Backed by `BOPAlgo_ArgumentAnalyzer`'s self-interference test, which is authoritative
    /// but **expensive** (seconds on B-spline solids) and can otherwise run unbounded.
    ///
    /// - Important: `timeout` is **cooperative, not a hard deadline** (#293). It is implemented
    ///   as a `Message_ProgressIndicator` that OCCT polls at its own internal checkpoints, the
    ///   calling thread is blocked inside this call and can only return once the next checkpoint
    ///   after `timeout` is reached, not at `timeout` itself. The self-interference phase has at
    ///   least one long checkpoint-free stretch (inside `Intf_Interference::Insert`); on
    ///   pathological B-spline solids that phase alone has been observed running 20+ minutes past
    ///   a 30s `timeout`. There is no preemptive or background bound here, the only hard bound
    ///   is process-level isolation (run this in a subprocess/worker you can kill on your own
    ///   deadline if a true wall-clock guarantee matters).
    ///
    /// - Important: `true` is reported **only** for a completed analysis that recorded at least
    ///   one `BOPAlgo_SelfIntersect` result and no other status (#1054). An empty result list on a
    ///   **completed** analysis is `false`: that is the clean case. An empty list is not enough on
    ///   its own, because a watchdog that trips before anything is recorded leaves the list empty
    ///   too, and that case is `nil`; the watchdog is read first, so it never reaches this test.
    ///   Everything else the analyzer can record used to read as `true` and is now `nil`: an
    ///   aborted analysis, an argument it refuses, and an analysis that failed
    ///   (`BOPAlgo_CheckUnknown`, or a `BOPAlgo_OperationAborted` recorded for a
    ///   `BOPAlgo_CheckerSI` error that was not a watchdog break, which is why `timeout: 0` does
    ///   not exempt a caller from this). An analysis the `timeout` aborted is `nil` even when it
    ///   recorded results first: the interference map a valid solid's face adjacency fills is
    ///   cleared partway through the check and then selectively refilled, so an analysis
    ///   interrupted before that point is read against the raw map and a clean box reports up to
    ///   three self-interferences of its own. Separately, a shape
    ///   `BOPAlgo_ArgumentAnalyzer` rejects outright, such as ``emptied``'s result, records
    ///   `BOPAlgo_BadType`, which says nothing about self-intersection and involves no timeout
    ///   at all.
    ///
    /// - Parameter timeout: Seconds before the check *asks* OCCT to give up (default 30), the
    ///   actual return can be much later if an un-polled phase is reached. `0`/negative = unbounded.
    /// - Returns: `true` if a self-interference was found, `false` if the shape is clean, or
    ///   `nil` if the check could not complete within `timeout`, or could not answer the question
    ///   at all (**indeterminate**, treat as "unknown", not "clean").
    ///
    /// Validate-at-the-source recipe for a loft result before using it in a boolean:
    /// ```swift
    /// guard let solid = Shape.loft(profiles: ps, ruled: false)?.orientedForward(),
    ///       solid.isSelfIntersecting() == false else { /* reject */ }
    /// ```
    public func isSelfIntersecting(timeout: Double = 30) -> Bool? {
        switch OCCTShapeSelfIntersectsBounded(handle, timeout) {
        case 1: return true
        case 0: return false
        default: return nil  // -1: indeterminate (timed out, refused, or errored)
        }
    }

    /// Whether this shape self-intersects, with a **true hard wall-clock deadline** (#319),
    /// unlike ``isSelfIntersecting(timeout:)``, this returns at `hardTimeout` even if OCCT never
    /// reaches a checkpoint to poll.
    ///
    /// Runs the check on a detached background thread against a `deepCopy()` of this shape
    /// and waits on the calling thread with a real deadline. If the deadline passes first, this
    /// returns `nil` immediately and the background computation is **abandoned, not cancelled**,
    /// it keeps running orphaned on its own thread until it eventually completes. That is a
    /// deliberate trade (burned CPU for a caller-side wall-clock guarantee), the same one the
    /// #286 mesher-hang caller accepted.
    ///
    /// - Warning: **Latent thread-safety risk, flagged but not fixed here (#831).** The
    ///   no-argument instance `deepCopy()` used above gives independent *topology* only, it
    ///   shares `Geom_Surface`/`Geom_Curve` handles (via `TNaming_CopyShape::CopyTool`) with
    ///   `self`, not the independent geometry `docs/thread-safety.md` used to (incorrectly)
    ///   describe it as providing. The orphaned background computation on `probe` and the caller
    ///   continuing to use `self` after a timeout are therefore two `TopoDS_Shape`s with distinct
    ///   `TShape` identity but the *same* underlying geometry objects, evaluated concurrently,
    ///   exactly the shared-adaptor-cache race `docs/thread-safety.md` item 1 warns about. This
    ///   was verified by reading the OCCT source chain, not reproduced under ThreadSanitizer, so
    ///   treat it as a well-evidenced risk rather than a confirmed race. Fixing it (e.g. switching
    ///   to `copy(copyGeometry: true)`, which does clone geometry) is left as a follow-up rather
    ///   than changed in the PR that found this, to keep that PR's behavior change scoped to docs.
    ///
    /// - Important: `BOPAlgo_ArgumentAnalyzer`'s safety when run on a background thread
    ///   concurrently with unrelated OCCT calls on other threads was verified with a
    ///   ThreadSanitizer stress test (60 bursts × 8 threads, half running self-intersection
    ///   checks on independent self-intersecting shapes, half running unrelated fuse+mesh work,
    ///   480 operations total): zero TSan race reports, zero wrong-but-plausible results. That
    ///   covers one stress shape and one access pattern, not an exhaustive audit of every
    ///   `BOPAlgo_ArgumentAnalyzer`/`Intf_Interference` code path, prefer
    ///   ``isSelfIntersecting(timeout:)`` unless a caller genuinely needs a hard in-process
    ///   wall-clock guarantee (e.g. no process/subprocess isolation available).
    ///
    /// - Parameter hardTimeout: Seconds to wait before giving up and returning `nil`.
    /// - Returns: `true`/`false` if the check completed in time, `nil` if the deadline passed
    ///   first (indeterminate, the background check may still be running) or if the analysis
    ///   could not answer the question, per ``isSelfIntersecting(timeout:)``. The inner call
    ///   passes `0`, so no watchdog can abort it, but `BOPAlgo_OperationAborted` is recorded for
    ///   any `BOPAlgo_CheckerSI` error and not only a watchdog break, so that case reaches this
    ///   entry point too.
    ///
    /// ```swift
    /// // Bound total wall-clock time even on a pathological B-spline solid with no
    /// // OCCT checkpoints in its self-interference phase.
    /// switch solid.isSelfIntersecting(hardTimeout: 5) {
    /// case .some(true):  print("self-intersects")
    /// case .some(false): print("clean")
    /// case .none:        print("deadline hit, treat as unknown, not clean")
    /// }
    /// ```
    public func isSelfIntersecting(hardTimeout: Double) -> Bool? {
        final class SelfIntersectResultBox: @unchecked Sendable {
            var rawResult: Int32 = -1
        }
        let probe = deepCopy() ?? self
        let box = SelfIntersectResultBox()
        // The `0` below is load-bearing beyond "the caller's deadline is the only bound", and a
        // test depends on it: passing 0 means no watchdog exists, so this call can never lose a
        // conclusive answer to an aborted analysis the way a cooperative `timeout:` can (#1054).
        // Issue598PipeShellFrenetModeTests uses this entry point for exactly that property.
        // Threading a cooperative bound in here would reintroduce that fragility silently.
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async {
            box.rawResult = OCCTShapeSelfIntersectsBounded(probe.handle, 0)
            semaphore.signal()
        }
        guard semaphore.wait(timeout: .now() + hardTimeout) == .success else {
            return nil
        }
        switch box.rawResult {
        case 1: return true
        case 0: return false
        default: return nil
        }
    }

    /// Detailed self-intersection check with progress information (BOPAlgo-based).
    ///
    /// Unlike ``isSelfIntersecting(timeout:)``, this returns a ``SelfIntersectionDetailedResult``
    /// that distinguishes between different reasons for an indeterminate result:
    /// - ``SelfIntersectionDetailedResult/indeterminateBreakerNotTripped``: the analysis made no measurable
    ///   progress before the timeout (the OCCT progress breaker was never tripped)
    /// - ``SelfIntersectionDetailedResult/indeterminateBreakerTripped``: the analysis was running but didn't
    ///   complete before the timeout (the breaker was tripped)
    /// - ``SelfIntersectionDetailedResult/error``: an exception occurred during analysis
    ///
    /// This allows callers to distinguish "needs longer timeout" from "will never finish",
    /// which is especially valuable for B-spline solids where the self-interference phase
    /// may not reach checkpoints frequently enough.
    ///
    /// - Parameters:
    ///   - timeout: Maximum time in seconds to wait for the check to complete.
    /// - Returns: ``SelfIntersectionDetailedResult`` with status and progress information.
    ///
    /// ```swift
    /// let result = solid.isSelfIntersectingDetailed(timeout: 10)
    /// switch result.status {
    /// case .intersects:                  print("Self-intersects - reject")
    /// case .clean:                       print("Clean - safe to use")
    /// case .indeterminateBreakerTripped:
    ///     print("Breaker tripped - try longer timeout")
    /// case .indeterminateBreakerNotTripped:
    ///     print("Breaker not tripped - shape may be too complex for this check")
    /// case .error:                       print("Analysis error - treat as unknown")
    /// }
    /// ```
    public func isSelfIntersectingDetailed(timeout: Double = 30) -> SelfIntersectionDetailedResult {
        var facesChecked: Int32 = 0
        var totalPairs: Int32 = 0
        var timeSpent: Double = 0.0
        let code = OCCTShapeSelfIntersectsDetailed(handle, timeout, &facesChecked, &totalPairs, &timeSpent)
        return SelfIntersectionDetailedResult(code: code,
                                      facesChecked: Int(facesChecked),
                                      totalFacePairs: Int(totalPairs),
                                      timeSpent: timeSpent)
    }

    /// Quick pre-screen to estimate self-intersection check complexity (BOPAlgo-based).
    ///
    /// Returns a ``SelfIntersectionCostEstimate`` with face counts by surface type
    /// and a relative cost estimate. This is fast (no actual intersection analysis)
    /// and helps callers decide whether to attempt the full check with a given timeout.
    ///
    /// Cost model (relative):
    /// - B-spline faces: 10x (most expensive, require numerical intersection)
    /// - Other analytical surfaces (cylinder, cone, sphere, torus): 3x
    /// - Planar faces: 1x (baseline, fast analytical intersection)
    ///
    /// - Returns: ``SelfIntersectionCostEstimate`` or `nil` on error.
    ///
    /// ```swift
    /// if let estimate = solid.selfIntersectionCostEstimate() {
    ///     if estimate.estimatedCost > 1000 {
    ///         print("High cost (\(estimate.estimatedCost)) - consider skipping or using longer timeout")
    ///     }
    /// }
    /// ```
    public func selfIntersectionCostEstimate() -> SelfIntersectionCostEstimate? {
        var numFaces: Int32 = 0
        var numBSplineFaces: Int32 = 0
        var numPlaneFaces: Int32 = 0
        var estimatedCost: Double = 0.0
        let code = OCCTShapeSelfIntersectEstimateCost(handle, &numFaces, &numBSplineFaces, &numPlaneFaces, &estimatedCost)
        guard code == 0 else { return nil }
        return SelfIntersectionCostEstimate(numFaces: Int(numFaces),
                                            numBSplineFaces: Int(numBSplineFaces),
                                            numPlaneFaces: Int(numPlaneFaces),
                                            estimatedCost: estimatedCost)
    }

    // MARK: - Sub-Shape Extraction

    /// The number of **distinct** sub-shapes of a given topological type.
    ///
    /// This is the one sub-shape enumeration: ``solids``, ``shells``, ``wires``, ``faceCount``,
    /// ``edgeCount`` and ``vertexCount`` all read the same one, so their answers agree with this
    /// one by construction (#502).
    ///
    /// "Distinct" is `TopExp::MapShapes` over `TopoDS_Shape::IsSame`: same underlying geometry
    /// *and* same placement, orientation ignored. Two consequences worth knowing:
    ///
    /// - A sub-shape reachable from more than one parent counts **once**. A box's 12 edges are
    ///   each shared by two faces, so the count is 12, not the 24 edge-in-face occurrences a raw
    ///   `TopExp_Explorer` walk yields.
    /// - Two *placements* of one body count **twice**, because the location is part of the
    ///   comparison. Instanced assemblies are not collapsed.
    ///
    /// A shape is its own sub-shape when it is of the requested type, so a solid reports one solid.
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// print(box.subShapeCount(ofType: .face))    // 6
    /// print(box.subShapeCount(ofType: .edge))    // 12
    /// print(box.subShapeCount(ofType: .vertex))  // 8
    /// print(box.subShapeCount(ofType: .solid))   // 1, the box itself
    ///
    /// // One body compounded with itself is one solid; two placements of it are two.
    /// print(Shape.compound([box, box])!.subShapeCount(ofType: .solid))                       // 1
    /// print(Shape.compound([box, box.translated(by: SIMD3(50, 0, 0))!])!
    ///     .subShapeCount(ofType: .solid))                                                    // 2
    /// ```
    ///
    /// - Parameter type: The topological type to count (e.g., `.face`, `.edge`, `.vertex`)
    /// - Returns: Number of distinct sub-shapes of that type; 0 for `.unknown`
    public func subShapeCount(ofType type: ShapeType) -> Int {
        Int(OCCTShapeGetSubShapeCount(handle, Int32(type.rawValue)))
    }

    /// A sub-shape by type and 0-based index, in the order ``subShapes(ofType:)`` returns.
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// print(box.subShape(type: .face, index: 0)?.shapeType ?? .unknown)  // Face
    /// print(box.subShape(type: .face, index: 6) == nil)                  // true, only 6 faces
    /// ```
    ///
    /// - Parameters:
    ///   - type: The topological type (e.g., `.face`, `.edge`, `.vertex`)
    ///   - index: 0-based index into the sub-shapes of that type
    /// - Returns: The sub-shape as a Shape, or nil if index is out of range
    public func subShape(type: ShapeType, index: Int) -> Shape? {
        guard let ref = OCCTShapeGetSubShapeByTypeIndex(handle, Int32(type.rawValue), Int32(index))
        else {
            return nil
        }
        return Shape(handle: ref)
    }

    /// All **distinct** sub-shapes of a given topological type, in enumeration order.
    ///
    /// One walk to size the buffer and one to fill it, so this is much cheaper than reading
    /// ``subShape(type:index:)`` in a loop, which re-walks the shape once per element. See
    /// ``subShapeCount(ofType:)`` for what "distinct" excludes.
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// print(box.subShapes(ofType: .face).count)   // 6
    /// print(box.subShapes(ofType: .edge).count)   // 12
    /// ```
    ///
    /// Unlike ``Face`` and ``Edge``, a returned ``Shape`` carries no ordinal of its own, so the
    /// array position is the only thing naming which sub-shape an element is.
    ///
    /// - Parameter type: The topological type (e.g., `.face`, `.edge`, `.vertex`)
    /// - Returns: Every distinct sub-shape, so `subShapes(ofType: t)[k]` is
    ///   `subShape(type: t, index: k)`, or an empty array if any could not be built. Never a short
    ///   array, which would shift every later ordinal (#979).
    public func subShapes(ofType type: ShapeType) -> [Shape] {
        let count = Int32(subShapeCount(ofType: type))
        guard count > 0 else { return [] }
        var handles = [OCCTShapeRef?](repeating: nil, count: Int(count))
        let written = OCCTShapeGetSubShapes(handle, Int32(type.rawValue), &handles, count)
        guard written == count else {
            // A short write means the walk failed part-way, and the bridge can have written
            // handles it no longer reports, so scan the whole buffer rather than the prefix.
            for stray in handles {
                if let stray { OCCTShapeRelease(stray) }
            }
            return []
        }
        return wrapSubShapeEnumeration(
            handles,
            wrap: { ref, _ in Shape(handle: ref) },
            release: OCCTShapeRelease)
    }

    // MARK: - Bounds

    /// Get the axis-aligned bounding box of the shape.
    ///
    /// - Important: This is OCCT's **default** `Bnd_Box`, which for B-spline / faceted surfaces is
    ///   the *control-point hull*, it can **over-report** the true extent (e.g. by ~one thread lead
    ///   for a threaded shaft, OCCTSwift #232 / #213). For a tight extent use ``boundingBoxOptimal()``
    ///   (`Bnd_Box::AddOptimal`), or, the unambiguous ground truth, the min/max of ``mesh(linearDeflection:angularDeflection:)``
    ///   vertices. A `threadedShaft` / `threadedHole` solid is bounded *exactly* to its `length` / `depth`;
    ///   `bounds` reporting past that is the hull artifact, not real geometry.
    ///
    /// - Returns: The box as `(min, max)` corners, or `nil` when the shape contributes no
    ///   geometry to it. `nil` comes from OCCT's own `Bnd_Box::IsVoid()`, reported across the
    ///   bridge as a `Bool`, so a genuinely zero-size shape at the world origin returns a real
    ///   all-zero box rather than `nil` (#943). ``boundingBox`` computes the identical box through
    ///   the same shared helper and answers `nil` on exactly the same inputs.
    public var bounds: (min: SIMD3<Double>, max: SIMD3<Double>)? {
        var minX: Double = 0
        var minY: Double = 0
        var minZ: Double = 0
        var maxX: Double = 0
        var maxY: Double = 0
        var maxZ: Double = 0
        guard OCCTShapeGetBounds(handle, &minX, &minY, &minZ, &maxX, &maxY, &maxZ) else {
            return nil
        }
        return (min: SIMD3(minX, minY, minZ), max: SIMD3(maxX, maxY, maxZ))
    }

    /// Size of the bounding box.
    ///
    /// - Returns: `max - min`, or `nil` when ``bounds`` is `nil`. A zero-size shape reports
    ///   `.zero` here as a measurement; only a shape with no box at all reports `nil` (#943).
    public var size: SIMD3<Double>? {
        guard let b = bounds else { return nil }
        return b.max - b.min
    }

    /// Center of the bounding box.
    ///
    /// - Returns: `(min + max) / 2`, or `nil` when ``bounds`` is `nil`. A point-like shape at the
    ///   world origin reports `.zero` here as a measurement, not as a failure (#943).
    public var center: SIMD3<Double>? {
        guard let b = bounds else { return nil }
        return (b.min + b.max) / 2
    }

    // MARK: - Slicing

    /// Slice the shape at a given Z height, returning the cross-section as edges.
    public func sliceAtZ(_ z: Double) -> Shape? {
        guard let handle = OCCTShapeSliceAtZ(self.handle, z) else {
            return nil
        }
        return Shape(handle: handle)
    }

    /// Get wires from a section at a Z level, chained where the section closes.
    ///
    /// This is useful for CAM operations where you need to work with closed contours
    /// that can be offset for tool compensation.
    ///
    /// - Parameters:
    ///   - z: The Z level to section at
    ///   - tolerance: Tolerance for connecting edges into wires. Use larger values
    ///                (e.g., 1e-4) for imprecise geometry. Default is 1e-6.
    /// - Returns: Array of wires representing contours at that Z level, closed where the section
    ///            forms a loop and open otherwise (e.g. a section edge with nothing to close onto).
    ///            Returns empty array if no contours exist at that level.
    ///
    /// Unlike `sliceAtZ(_:)` which returns a shape with loose edges, this method
    /// chains the edges into wires (closed where possible) that can be used with `Wire.offset(by:)`.
    ///
    /// - Note: Edges whose orientation is `.internal` or `.external` (see
    ///   `Shape.Orientation`/`Shape.setOrientation(_:)`) are silently excluded from the result
    ///   wires (OCCT 8.0.1, upstream OCCT#1408). This only matters if the input `Shape` was
    ///   assembled with such edges through `Shape.compound(_:)`/`Shape.setOrientation(_:)` and one
    ///   of them happens to lie exactly in the cutting plane; in every case measured, an ordinary
    ///   transverse section of a solid does not produce `.internal`/`.external` edges on its own,
    ///   since Boolean sectioning only preserves an edge's own orientation when the cut is
    ///   coincident with that edge, not when it computes a fresh intersection curve. See #655.
    ///
    /// ## Example: CAM Safety Boundary
    ///
    /// ```swift
    /// let model = try Shape.load(from: stepFile)
    ///
    /// // Get model contour at Z = 5.0
    /// let wires = model.sectionWiresAtZ(5.0)
    ///
    /// for contour in wires {
    ///     // Offset outward by tool radius + stock allowance
    ///     if let safetyBoundary = contour.offset(by: toolRadius + stockAllowance) {
    ///         // Tool center must stay outside this boundary
    ///     }
    /// }
    /// ```
    public func sectionWiresAtZ(_ z: Double, tolerance: Double = 1e-6) -> [Wire] {
        var count: Int32 = 0
        guard let wireArray = OCCTShapeSectionWiresAtZ(handle, z, tolerance, &count) else {
            return []
        }
        // Use OCCTFreeWireArrayOnly - Swift Wire objects now own the wire handles
        // and will release them in their deinit. We only need to free the array container.
        defer { OCCTFreeWireArrayOnly(wireArray) }

        var wires: [Wire] = []
        for i in 0..<Int(count) {
            if let wireHandle = wireArray[i] {
                wires.append(Wire(handle: wireHandle))
            }
        }
        return wires
    }

    /// Get points along an edge at the given index.
    ///
    /// Points are sampled uniformly along the edge curve from start to end.
    /// - Parameters:
    ///   - index: The edge index (0 to edgeCount-1)
    ///   - maxPoints: Output *capacity* (capped at 20 internally for performance), clamped
    ///     into `0`...``Sampling/maximumSampleCount``; 0 or less returns empty (#558)
    /// - Returns: Array of 3D points along the edge curve
    public func edgePoints(at index: Int, maxPoints: Int = 20) -> [SIMD3<Double>] {
        let capacity = Sampling.capacity(maxPoints)
        guard capacity > 0 else { return [] }
        var buffer = [Double](repeating: 0, count: capacity * 3)
        let count = OCCTShapeGetEdgePoints(handle, Int32(index), &buffer, Int32(capacity))
        var points: [SIMD3<Double>] = []
        for i in 0..<Int(count) {
            points.append(SIMD3(buffer[i * 3], buffer[i * 3 + 1], buffer[i * 3 + 2]))
        }
        return points
    }

    /// Get all contour points from the shape's edges.
    ///
    /// Note: This returns edge START vertices only, not intermediate curve points.
    /// For curved edges, use `edgePoints(at:maxPoints:)` to get curve samples.
    /// This is suitable for simple polygon contours from Z-plane slices.
    ///
    /// - Parameter maxPoints: Output *capacity*, clamped into `0...`
    ///   ``Sampling/maximumSampleCount``; 0 or less returns empty (#558)
    /// - Returns: Array of 3D points (one per edge start vertex)
    public func contourPoints(maxPoints: Int = 1000) -> [SIMD3<Double>] {
        let capacity = Sampling.capacity(maxPoints)
        guard capacity > 0 else { return [] }
        var buffer = [Double](repeating: 0, count: capacity * 3)
        let count = OCCTShapeGetContourPoints(handle, &buffer, Int32(capacity))
        var points: [SIMD3<Double>] = []
        for i in 0..<Int(count) {
            points.append(SIMD3(buffer[i * 3], buffer[i * 3 + 1], buffer[i * 3 + 2]))
        }
        return points
    }
}
