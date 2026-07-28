import Foundation
import simd
import OCCTBridge

// MARK: - Dimension Geometry

/// Geometry extracted from a dimension measurement for Metal rendering
public struct DimensionGeometry: Sendable {
    /// First attachment point (on geometry)
    public let firstPoint: SIMD3<Double>
    /// Second attachment point (on geometry)
    public let secondPoint: SIMD3<Double>
    /// Angle vertex, or circle center for radius/diameter
    public let centerPoint: SIMD3<Double>
    /// Suggested text placement position
    public let textPosition: SIMD3<Double>
    /// Circle axis direction for radius/diameter dimensions
    public let circleNormal: SIMD3<Double>
    /// Circle radius for radius/diameter dimensions
    public let circleRadius: Double
    /// Measured value (distance in model units, angle in radians)
    public let value: Double
    /// Whether the geometry is valid
    public let isValid: Bool
}

// MARK: - Length Dimension

/// Measures distance between two points, along an edge, or between two faces
public final class LengthDimension: @unchecked Sendable {
    internal let handle: OCCTDimensionRef

    /// Create a length dimension between two 3D points
    public init?(from p1: SIMD3<Double>, to p2: SIMD3<Double>) {
        guard let h = OCCTDimensionCreateLengthFromPoints(
            p1.x, p1.y, p1.z, p2.x, p2.y, p2.z) else { return nil }
        self.handle = h
    }

    /// Create a length dimension measuring a linear edge
    public init?(edge: Shape) {
        guard let h = OCCTDimensionCreateLengthFromEdge(edge.handle) else { return nil }
        self.handle = h
    }

    /// Create a length dimension between two parallel faces
    public init?(face1: Shape, face2: Shape) {
        guard let h = OCCTDimensionCreateLengthFromFaces(face1.handle, face2.handle) else { return nil }
        self.handle = h
    }

    deinit { OCCTDimensionRelease(handle) }

    /// The measured distance
    public var value: Double { OCCTDimensionGetValue(handle) }

    /// Whether the dimension geometry is valid
    public var isValid: Bool { OCCTDimensionIsValid(handle) }

    /// Set a custom display value (overrides measured value)
    public func setCustomValue(_ value: Double) {
        OCCTDimensionSetCustomValue(handle, value)
    }

    /// Get dimension geometry for Metal rendering
    public var geometry: DimensionGeometry? {
        var g = OCCTDimensionGeometry()
        guard OCCTDimensionGetGeometry(handle, &g) else { return nil }
        return makeDimensionGeometry(g)
    }
}

// MARK: - Radius Dimension

/// Measures the radius of circular geometry (circle, arc, cylindrical face)
public final class RadiusDimension: @unchecked Sendable {
    internal let handle: OCCTDimensionRef

    /// Create a radius dimension from a shape with circular geometry
    public init?(shape: Shape) {
        guard let h = OCCTDimensionCreateRadiusFromShape(shape.handle) else { return nil }
        self.handle = h
    }

    deinit { OCCTDimensionRelease(handle) }

    /// The measured radius
    public var value: Double { OCCTDimensionGetValue(handle) }

    /// Whether the dimension geometry is valid
    public var isValid: Bool { OCCTDimensionIsValid(handle) }

    /// Set a custom display value
    public func setCustomValue(_ value: Double) {
        OCCTDimensionSetCustomValue(handle, value)
    }

    /// Get dimension geometry for Metal rendering
    public var geometry: DimensionGeometry? {
        var g = OCCTDimensionGeometry()
        guard OCCTDimensionGetGeometry(handle, &g) else { return nil }
        return makeDimensionGeometry(g)
    }
}

// MARK: - Angle Dimension

/// Measures angles between edges, faces, or three points
public final class AngleDimension: @unchecked Sendable {
    internal let handle: OCCTDimensionRef

    /// Create an angle dimension between two edges
    public init?(edge1: Shape, edge2: Shape) {
        guard let h = OCCTDimensionCreateAngleFromEdges(edge1.handle, edge2.handle) else { return nil }
        self.handle = h
    }

    /// Create an angle dimension from three points (first, vertex, second)
    public init?(first: SIMD3<Double>, vertex: SIMD3<Double>, second: SIMD3<Double>) {
        guard let h = OCCTDimensionCreateAngleFromPoints(
            first.x, first.y, first.z,
            vertex.x, vertex.y, vertex.z,
            second.x, second.y, second.z) else { return nil }
        self.handle = h
    }

    /// Create an angle dimension between two planar faces
    public init?(face1: Shape, face2: Shape) {
        guard let h = OCCTDimensionCreateAngleFromFaces(face1.handle, face2.handle) else { return nil }
        self.handle = h
    }

    deinit { OCCTDimensionRelease(handle) }

    /// The measured angle in radians
    public var value: Double { OCCTDimensionGetValue(handle) }

    /// The measured angle in degrees
    public var degrees: Double { value * 180.0 / .pi }

    /// Whether the dimension geometry is valid
    public var isValid: Bool { OCCTDimensionIsValid(handle) }

    /// Set a custom display value (in radians)
    public func setCustomValue(_ value: Double) {
        OCCTDimensionSetCustomValue(handle, value)
    }

    /// Get dimension geometry for Metal rendering
    public var geometry: DimensionGeometry? {
        var g = OCCTDimensionGeometry()
        guard OCCTDimensionGetGeometry(handle, &g) else { return nil }
        return makeDimensionGeometry(g)
    }
}

// MARK: - Diameter Dimension

/// Measures the diameter of circular geometry
public final class DiameterDimension: @unchecked Sendable {
    internal let handle: OCCTDimensionRef

    /// Create a diameter dimension from a shape with circular geometry
    public init?(shape: Shape) {
        guard let h = OCCTDimensionCreateDiameterFromShape(shape.handle) else { return nil }
        self.handle = h
    }

    deinit { OCCTDimensionRelease(handle) }

    /// The measured diameter
    public var value: Double { OCCTDimensionGetValue(handle) }

    /// Whether the dimension geometry is valid
    public var isValid: Bool { OCCTDimensionIsValid(handle) }

    /// Set a custom display value
    public func setCustomValue(_ value: Double) {
        OCCTDimensionSetCustomValue(handle, value)
    }

    /// Get dimension geometry for Metal rendering
    public var geometry: DimensionGeometry? {
        var g = OCCTDimensionGeometry()
        guard OCCTDimensionGetGeometry(handle, &g) else { return nil }
        return makeDimensionGeometry(g)
    }
}

// MARK: - Text Label

/// A positioned 3D text label
public final class TextLabel: @unchecked Sendable {
    internal let handle: OCCTTextLabelRef

    /// Create a text label at a 3D position
    public init?(text: String, position: SIMD3<Double>) {
        guard let h = OCCTTextLabelCreate(text, position.x, position.y, position.z) else { return nil }
        self.handle = h
    }

    deinit { OCCTTextLabelRelease(handle) }

    /// Get the label text
    public var text: String {
        get {
            var info = OCCTTextLabelInfo()
            guard OCCTTextLabelGetInfo(handle, &info) else { return "" }
            return withUnsafeBytes(of: &info.text) { rawBuffer in
                guard let baseAddress = rawBuffer.baseAddress else { return "" }
                let charPtr = baseAddress.assumingMemoryBound(to: CChar.self)
                return String(cString: charPtr)
            }
        }
        set { OCCTTextLabelSetText(handle, newValue) }
    }

    /// Get or set the label position
    public var position: SIMD3<Double> {
        get {
            var info = OCCTTextLabelInfo()
            guard OCCTTextLabelGetInfo(handle, &info) else { return .zero }
            return SIMD3(info.position.0, info.position.1, info.position.2)
        }
        set { OCCTTextLabelSetPosition(handle, newValue.x, newValue.y, newValue.z) }
    }

    /// Set the text height
    public func setHeight(_ height: Double) {
        OCCTTextLabelSetHeight(handle, height)
    }
}

// MARK: - Point Cloud

/// A colored point set for visualization
public final class PointCloud: @unchecked Sendable {
    internal let handle: OCCTPointCloudRef

    /// Create a point cloud from an array of 3D points
    public init?(points: [SIMD3<Double>]) {
        var coords = [Double](repeating: 0, count: points.count * 3)
        for (i, p) in points.enumerated() {
            coords[i * 3] = p.x
            coords[i * 3 + 1] = p.y
            coords[i * 3 + 2] = p.z
        }
        guard let h = OCCTPointCloudCreate(coords, Int32(points.count)) else { return nil }
        self.handle = h
    }

    /// Create a colored point cloud
    /// - Parameters:
    ///   - points: Array of 3D positions
    ///   - colors: Array of RGB colors (same count as points, components in [0,1])
    public init?(points: [SIMD3<Double>], colors: [SIMD3<Float>]) {
        guard points.count == colors.count else { return nil }
        var coords = [Double](repeating: 0, count: points.count * 3)
        var cols = [Float](repeating: 0, count: colors.count * 3)
        for (i, p) in points.enumerated() {
            coords[i * 3] = p.x; coords[i * 3 + 1] = p.y; coords[i * 3 + 2] = p.z
        }
        for (i, c) in colors.enumerated() {
            cols[i * 3] = c.x; cols[i * 3 + 1] = c.y; cols[i * 3 + 2] = c.z
        }
        guard let h = OCCTPointCloudCreateColored(coords, cols, Int32(points.count)) else { return nil }
        self.handle = h
    }

    deinit { OCCTPointCloudRelease(handle) }

    /// Number of points in the cloud
    public var count: Int { Int(OCCTPointCloudGetCount(handle)) }

    /// Axis-aligned bounding box as (min, max)
    public var bounds: (min: SIMD3<Double>, max: SIMD3<Double>)? {
        var minXYZ = [Double](repeating: 0, count: 3)
        var maxXYZ = [Double](repeating: 0, count: 3)
        guard OCCTPointCloudGetBounds(handle, &minXYZ, &maxXYZ) else { return nil }
        return (SIMD3(minXYZ[0], minXYZ[1], minXYZ[2]),
                SIMD3(maxXYZ[0], maxXYZ[1], maxXYZ[2]))
    }

    /// Get all point positions
    public var points: [SIMD3<Double>] {
        let n = count
        guard n > 0 else { return [] }
        var coords = [Double](repeating: 0, count: n * 3)
        let copied = OCCTPointCloudGetPoints(handle, &coords, Int32(n))
        return unpackSIMD3(coords, count: Int(copied))
    }

    /// Get all point colors (empty if uncolored)
    public var colors: [SIMD3<Float>] {
        let n = count
        guard n > 0 else { return [] }
        var cols = [Float](repeating: 0, count: n * 3)
        let copied = OCCTPointCloudGetColors(handle, &cols, Int32(n))
        guard copied > 0 else { return [] }
        return unpackSIMD3(cols, count: Int(copied))
    }
}

// MARK: - Internal helpers

private func makeDimensionGeometry(_ g: OCCTDimensionGeometry) -> DimensionGeometry {
    DimensionGeometry(
        firstPoint: SIMD3(g.firstPoint.0, g.firstPoint.1, g.firstPoint.2),
        secondPoint: SIMD3(g.secondPoint.0, g.secondPoint.1, g.secondPoint.2),
        centerPoint: SIMD3(g.centerPoint.0, g.centerPoint.1, g.centerPoint.2),
        textPosition: SIMD3(g.textPosition.0, g.textPosition.1, g.textPosition.2),
        circleNormal: SIMD3(g.circleNormal.0, g.circleNormal.1, g.circleNormal.2),
        circleRadius: g.circleRadius,
        value: g.value,
        isValid: g.isValid
    )
}
