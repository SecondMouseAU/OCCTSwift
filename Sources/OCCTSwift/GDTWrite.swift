import Foundation
import OCCTBridge

// MARK: - GD&T typed enums + write path (v0.140, #67/#70 follow-up)
//
// v0.21.0 shipped read-only accessors returning raw Int32 type codes. This file
// adds typed Swift enums matching OCCT's XCAFDimTolObjects type codes and the
// write path (`Document.createDimension`, `createGeomTolerance`, `createDatum`)
// that lets downstream callers author GD&T and round-trip through STEP AP242.
//
// Current scope is intentionally narrow — create + basic modify. Full modifier
// sequences (qualifier, grade, form variance, GeomToleranceModifiersSequence)
// remain partial wrapping; add them as concrete consumers surface.

extension Document {
    /// Matches OCCT's `XCAFDimTolObjects_DimensionType` — the 31 + location/size
    /// variants that STEP AP242 dimensions can take.
    public enum DimensionType: Int32, Sendable, CaseIterable {
        case locationNone = 0
        case locationCurvedDistance = 1
        case locationLinearDistance = 2
        case locationLinearDistanceFromCenterToOuter = 3
        case locationLinearDistanceFromCenterToInner = 4
        case locationLinearDistanceFromOuterToCenter = 5
        case locationLinearDistanceFromOuterToOuter = 6
        case locationLinearDistanceFromOuterToInner = 7
        case locationLinearDistanceFromInnerToCenter = 8
        case locationLinearDistanceFromInnerToOuter = 9
        case locationLinearDistanceFromInnerToInner = 10
        case locationAngular = 11
        case locationOriented = 12
        case locationWithPath = 13
        case sizeCurveLength = 14
        case sizeDiameter = 15
        case sizeSphericalDiameter = 16
        case sizeRadius = 17
        case sizeSphericalRadius = 18
        case sizeToroidalMinorDiameter = 19
        case sizeToroidalMajorDiameter = 20
        case sizeToroidalMinorRadius = 21
        case sizeToroidalMajorRadius = 22
        case sizeToroidalHighMajorDiameter = 23
        case sizeToroidalLowMajorDiameter = 24
        case sizeToroidalHighMajorRadius = 25
        case sizeToroidalLowMajorRadius = 26
        case sizeThickness = 27
        case sizeAngular = 28
        case sizeWithPath = 29
        case commonLabel = 30
        case dimensionPresentation = 31
    }

    /// Matches OCCT's `XCAFDimTolObjects_GeomToleranceType` — the 16 ASME / ISO
    /// geometric tolerance classes.
    public enum GeomToleranceType: Int32, Sendable, CaseIterable {
        case none = 0
        case angularity = 1
        case circularRunout = 2
        case circularityOrRoundness = 3
        case coaxiality = 4
        case concentricity = 5
        case cylindricity = 6
        case flatness = 7
        case parallelism = 8
        case perpendicularity = 9
        case position = 10
        case profileOfLine = 11
        case profileOfSurface = 12
        case straightness = 13
        case symmetry = 14
        case totalRunout = 15
    }

    /// Typed dimension detail (enum + values + tolerance bounds).
    public struct Dimension: Sendable, Hashable {
        public let type: DimensionType
        public let value: Double
        public let lowerTolerance: Double
        public let upperTolerance: Double
        public let index: Int
    }

    public struct GeomTolerance: Sendable, Hashable {
        public let type: GeomToleranceType
        public let value: Double
        public let index: Int
    }

    public struct Datum: Sendable, Hashable {
        public let name: String
        public let index: Int
    }

    // MARK: - Typed read path

    /// Typed dimension at an index, matching the existing Int32-returning `dimension(at:)`.
    public func typedDimension(at index: Int) -> Dimension? {
        let info = OCCTDocumentGetDimensionInfo(handle, Int32(index))
        guard info.isValid,
            let type = DimensionType(rawValue: info.type)
        else { return nil }
        return Dimension(
            type: type, value: info.value,
            lowerTolerance: info.lowerTol,
            upperTolerance: info.upperTol,
            index: index)
    }

    public func typedGeomTolerance(at index: Int) -> GeomTolerance? {
        let info = OCCTDocumentGetGeomToleranceInfo(handle, Int32(index))
        guard info.isValid,
            let type = GeomToleranceType(rawValue: info.type)
        else { return nil }
        return GeomTolerance(type: type, value: info.value, index: index)
    }

    public func typedDatum(at index: Int) -> Datum? {
        guard let base = datum(at: index) else { return nil }
        return Datum(name: base.name, index: index)
    }

    public var typedDimensions: [Dimension] {
        (0..<dimensionCount).compactMap { typedDimension(at: $0) }
    }

    public var typedGeomTolerances: [GeomTolerance] {
        (0..<geomToleranceCount).compactMap { typedGeomTolerance(at: $0) }
    }

    public var typedDatums: [Datum] {
        (0..<datumCount).compactMap { typedDatum(at: $0) }
    }

    // MARK: - Write path

    /// Create a new dimension on the document, attached to the shape at `shapeLabel`.
    /// - Returns: the new dimension's index, or nil on failure.
    @discardableResult
    public func createDimension(
        on shapeLabel: Int64,
        type: DimensionType,
        value: Double,
        lowerTolerance: Double = 0,
        upperTolerance: Double = 0
    ) -> Int? {
        let idx = OCCTDocumentCreateDimension(handle, shapeLabel, type.rawValue, value)
        guard idx >= 0 else { return nil }
        if lowerTolerance != 0 || upperTolerance != 0 {
            _ = OCCTDocumentSetDimensionTolerance(handle, idx, lowerTolerance, upperTolerance)
        }
        return Int(idx)
    }

    @discardableResult
    public func createGeomTolerance(
        on shapeLabel: Int64,
        type: GeomToleranceType,
        value: Double
    ) -> Int? {
        let idx = OCCTDocumentCreateGeomTolerance(handle, shapeLabel, type.rawValue, value)
        return idx >= 0 ? Int(idx) : nil
    }

    @discardableResult
    public func createDatum(name: String) -> Int? {
        let idx = name.withCString { OCCTDocumentCreateDatum(handle, $0) }
        return idx >= 0 ? Int(idx) : nil
    }

    @discardableResult
    public func setDimensionTolerance(
        at index: Int,
        lower: Double,
        upper: Double
    ) -> Bool {
        OCCTDocumentSetDimensionTolerance(handle, Int32(index), lower, upper)
    }
}
