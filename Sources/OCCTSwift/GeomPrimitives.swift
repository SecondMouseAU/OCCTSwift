import Foundation
import OCCTBridge
import simd

/// A 3D geometric point with Handle-based memory management.
public final class GeomPoint3D: @unchecked Sendable {
    public let handle: OCCTGeomPoint3DRef

    public init(x: Double, y: Double, z: Double) {
        handle = OCCTGeomPoint3DCreate(x, y, z)
    }

    public init(simd: SIMD3<Double>) {
        handle = OCCTGeomPoint3DCreate(simd.x, simd.y, simd.z)
    }

    deinit { OCCTGeomPoint3DRelease(handle) }

    public var x: Double { OCCTGeomPoint3DX(handle) }
    public var y: Double { OCCTGeomPoint3DY(handle) }
    public var z: Double { OCCTGeomPoint3DZ(handle) }

    public var coordinates: SIMD3<Double> { SIMD3(x, y, z) }

    public func setCoordinates(x: Double, y: Double, z: Double) {
        OCCTGeomPoint3DSetCoord(handle, x, y, z)
    }

    public func distance(to other: GeomPoint3D) -> Double {
        OCCTGeomPoint3DDistance(handle, other.handle)
    }

    public func squareDistance(to other: GeomPoint3D) -> Double {
        OCCTGeomPoint3DSquareDistance(handle, other.handle)
    }

    public func translate(dx: Double, dy: Double, dz: Double) {
        OCCTGeomPoint3DTranslate(handle, dx, dy, dz)
    }
}

/// A 3D unit vector (always normalized).
public final class GeomDirection: @unchecked Sendable {
    public let handle: OCCTGeomDirectionRef

    public init(x: Double, y: Double, z: Double) {
        handle = OCCTGeomDirectionCreate(x, y, z)
    }

    public init(simd: SIMD3<Double>) {
        handle = OCCTGeomDirectionCreate(simd.x, simd.y, simd.z)
    }

    internal init(handle: OCCTGeomDirectionRef) {
        self.handle = handle
    }

    deinit { OCCTGeomDirectionRelease(handle) }

    public var coordinates: SIMD3<Double> {
        var x: Double = 0
        var y: Double = 0
        var z: Double = 0
        OCCTGeomDirectionCoords(handle, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    public func setCoordinates(x: Double, y: Double, z: Double) {
        OCCTGeomDirectionSetCoord(handle, x, y, z)
    }

    /// Cross product with another direction.
    ///
    /// Returns nil if parallel.
    public func crossed(with other: GeomDirection) -> GeomDirection? {
        guard let ref = OCCTGeomDirectionCrossed(handle, other.handle) else { return nil }
        return GeomDirection(handle: ref)
    }
}

/// A 3D vector with magnitude (can have zero length).
public final class GeomVector3D: @unchecked Sendable {
    public let handle: OCCTGeomVector3DRef

    public init(x: Double, y: Double, z: Double) {
        handle = OCCTGeomVector3DCreate(x, y, z)
    }

    public init(simd: SIMD3<Double>) {
        handle = OCCTGeomVector3DCreate(simd.x, simd.y, simd.z)
    }

    public init(from p1: SIMD3<Double>, to p2: SIMD3<Double>) {
        handle = OCCTGeomVector3DFromPoints(p1.x, p1.y, p1.z, p2.x, p2.y, p2.z)
    }

    internal init(handle: OCCTGeomVector3DRef) {
        self.handle = handle
    }

    deinit { OCCTGeomVector3DRelease(handle) }

    public var coordinates: SIMD3<Double> {
        var x: Double = 0
        var y: Double = 0
        var z: Double = 0
        OCCTGeomVector3DCoords(handle, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    public var magnitude: Double { OCCTGeomVector3DMagnitude(handle) }

    public func dot(_ other: GeomVector3D) -> Double {
        OCCTGeomVector3DDot(handle, other.handle)
    }

    public func added(_ other: GeomVector3D) -> GeomVector3D {
        GeomVector3D(handle: OCCTGeomVector3DAdded(handle, other.handle))
    }

    public func multiplied(by scalar: Double) -> GeomVector3D {
        GeomVector3D(handle: OCCTGeomVector3DMultiplied(handle, scalar))
    }

    /// Returns normalized copy.
    //
    // Nil if magnitude is near zero.
    public func normalized() -> GeomVector3D? {
        guard let ref = OCCTGeomVector3DNormalized(handle) else { return nil }
        return GeomVector3D(handle: ref)
    }

    public func crossed(_ other: GeomVector3D) -> GeomVector3D {
        GeomVector3D(handle: OCCTGeomVector3DCrossed(handle, other.handle))
    }
}

/// A 3D axis defined by an origin point and a direction.
public final class Axis1Placement: @unchecked Sendable {
    public let handle: OCCTAxis1PlacementRef

    public init(origin: SIMD3<Double>, direction: SIMD3<Double>) {
        handle = OCCTAxis1PlacementCreate(
            origin.x, origin.y, origin.z,
            direction.x, direction.y, direction.z)
    }

    internal init(handle: OCCTAxis1PlacementRef) {
        self.handle = handle
    }

    deinit { OCCTAxis1PlacementRelease(handle) }

    public var location: SIMD3<Double> {
        var x: Double = 0
        var y: Double = 0
        var z: Double = 0
        OCCTAxis1PlacementLocation(handle, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    public var direction: SIMD3<Double> {
        var x: Double = 0
        var y: Double = 0
        var z: Double = 0
        OCCTAxis1PlacementDirection(handle, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Reverse the direction in place.
    public func reverse() {
        OCCTAxis1PlacementReverse(handle)
    }

    /// Return a new axis with reversed direction.
    public func reversed() -> Axis1Placement {
        Axis1Placement(handle: OCCTAxis1PlacementReversed(handle))
    }

    public func setDirection(_ dir: SIMD3<Double>) {
        OCCTAxis1PlacementSetDirection(handle, dir.x, dir.y, dir.z)
    }

    public func setLocation(_ loc: SIMD3<Double>) {
        OCCTAxis1PlacementSetLocation(handle, loc.x, loc.y, loc.z)
    }
}

/// A 3D right-handed coordinate system (origin, main direction, X direction).
public final class Axis2Placement: @unchecked Sendable {
    public let handle: OCCTAxis2PlacementRef

    public init(origin: SIMD3<Double>, normal: SIMD3<Double>, xDirection: SIMD3<Double>) {
        handle = OCCTAxis2PlacementCreate(
            origin.x, origin.y, origin.z,
            normal.x, normal.y, normal.z,
            xDirection.x, xDirection.y, xDirection.z)
    }

    deinit { OCCTAxis2PlacementRelease(handle) }

    public var location: SIMD3<Double> {
        var x: Double = 0
        var y: Double = 0
        var z: Double = 0
        OCCTAxis2PlacementLocation(handle, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    public var mainDirection: SIMD3<Double> {
        var x: Double = 0
        var y: Double = 0
        var z: Double = 0
        OCCTAxis2PlacementDirection(handle, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    public var xDirection: SIMD3<Double> {
        var x: Double = 0
        var y: Double = 0
        var z: Double = 0
        OCCTAxis2PlacementXDirection(handle, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    public var yDirection: SIMD3<Double> {
        var x: Double = 0
        var y: Double = 0
        var z: Double = 0
        OCCTAxis2PlacementYDirection(handle, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    public func setDirection(_ dir: SIMD3<Double>) {
        OCCTAxis2PlacementSetDirection(handle, dir.x, dir.y, dir.z)
    }

    public func setXDirection(_ dir: SIMD3<Double>) {
        OCCTAxis2PlacementSetXDirection(handle, dir.x, dir.y, dir.z)
    }
}
