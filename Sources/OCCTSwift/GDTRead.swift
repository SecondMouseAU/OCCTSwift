import Foundation
import OCCTBridge

// MARK: - GD&T read surface (#996)
//
// One family, not two. v0.21.0 shipped `DimensionInfo`/`GeomToleranceInfo`/`DatumInfo` carrying a
// raw `Int32` type code; v0.140 added `Document.Dimension`/`GeomTolerance`/`Datum` behind
// `typedDimension(at:)` and friends without retiring the first set, so six public accessors read
// the same three bridge calls and rebuilt the same fields into two shapes. The typed structs won,
// under the untyped family's names, and the `typed*` spellings are gone.
//
// Both families also flattened OCCT's dimension kinds into one struct with zero-filled fields, so a
// 10..12 range read back as a plain 10 with no tolerance. `Dimension.Bounds` mirrors
// `XCAFDimTolObjects_DimensionObject`'s own predicates instead. See
// `Scripts/repro/996-gdt-read-surface/` for the measurement and `docs/reference/Annotation.md` for
// the model.
//
// The enums here are transcribed from the pinned kernel's own headers, and
// `Scripts/derive-gdt-enums.py --verify` is what keeps that transcription honest. Nothing did
// before, which is the half of #996 that merging the structs alone would not have fixed.

extension Document {
    /// STEP AP242 dimension sub-types, matching OCCT's `XCAFDimTolObjects_DimensionType`.
    ///
    /// ```swift
    /// let diameters = doc.dimensions.filter { $0.type == .sizeDiameter }
    /// ```
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

    /// ASME / ISO geometric tolerance classes, matching `XCAFDimTolObjects_GeomToleranceType`.
    ///
    /// ```swift
    /// let flatness = doc.geomTolerances.first { $0.type == .flatness }
    /// ```
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

    /// ISO 286 fundamental deviation, the "position letter", matching
    /// `XCAFDimTolObjects_DimensionFormVariance`.
    ///
    /// ```swift
    /// let holes = doc.dimensions.filter { $0.classOfTolerance?.formVariance == .h }
    /// ```
    public enum DimensionFormVariance: Int32, Sendable, CaseIterable {
        case none = 0
        case a = 1
        case b = 2
        case c = 3
        case cd = 4
        case d = 5
        case e = 6
        case ef = 7
        case f = 8
        case fg = 9
        case g = 10
        case h = 11
        case js = 12
        case j = 13
        case k = 14
        case m = 15
        case n = 16
        case p = 17
        case r = 18
        case s = 19
        case t = 20
        case u = 21
        case v = 22
        case x = 23
        case y = 24
        case z = 25
        case za = 26
        case zb = 27
        case zc = 28
    }

    /// ISO 286 accuracy grade, matching `XCAFDimTolObjects_DimensionGrade`.
    ///
    /// Raw values run finest to coarsest, so `it01` is 0 and `it18` is 19.
    ///
    /// ```swift
    /// let precise = doc.dimensions.filter {
    ///     ($0.classOfTolerance?.grade.rawValue ?? .max) <= Document.DimensionGrade.it8.rawValue
    /// }
    /// ```
    public enum DimensionGrade: Int32, Sendable, CaseIterable {
        case it01 = 0
        case it0 = 1
        case it1 = 2
        case it2 = 3
        case it3 = 4
        case it4 = 5
        case it5 = 6
        case it6 = 7
        case it7 = 8
        case it8 = 9
        case it9 = 10
        case it10 = 11
        case it11 = 12
        case it12 = 13
        case it13 = 14
        case it14 = 15
        case it15 = 16
        case it16 = 17
        case it17 = 18
        case it18 = 19
    }

    /// A dimension read from, or created on, a `Document`.
    ///
    /// ```swift
    /// if let dim = doc.dimension(at: 0) {
    ///     switch dim.bounds {
    ///     case .range(let lower, let upper): print("ranges \(lower) to \(upper)")
    ///     case .plusMinus(let lo, let hi): print("\(dim.value ?? 0) \(lo)/\(hi)")
    ///     case .simple: print("\(dim.value ?? 0)")
    ///     case .unset: print("no value")
    ///     }
    /// }
    /// ```
    public struct Dimension: Sendable, Hashable {
        /// How a dimension's magnitude is encoded, mirroring the values-array predicates on
        /// `XCAFDimTolObjects_DimensionObject`.
        public enum Bounds: Sendable, Hashable {
            /// No values array at all.
            case unset
            /// A nominal value on its own, values array length 1.
            case simple
            /// Lower and upper bound, values array length 2 (`IsDimWithRange()`).
            case range(lower: Double, upper: Double)
            /// Signed tolerances around the nominal value, values array length 3
            /// (`IsDimWithPlusMinusTolerance()`).
            case plusMinus(lowerTolerance: Double, upperTolerance: Double)
        }

        /// An ISO 286 tolerance class, present when `IsDimWithClassOfTolerance()` holds.
        ///
        /// Independent of `bounds`: OCCT stores the class outside the values array, so a range or
        /// plus/minus dimension can carry one too.
        public struct ClassOfTolerance: Sendable, Hashable {
            /// `true` when the class applies to an internal feature, a hole.
            public let isHole: Bool
            /// The fundamental deviation, or "position letter".
            public let formVariance: DimensionFormVariance
            /// The accuracy grade.
            public let grade: DimensionGrade
        }

        /// The STEP AP242 dimension sub-type.
        public let type: DimensionType

        /// The nominal value as OCCT's `GetValue()` reports it: a range's midpoint, the single
        /// value otherwise, and `nil` when `bounds` is `.unset`.
        public let value: Double?

        /// How this dimension's magnitude is encoded.
        public let bounds: Bounds

        /// The ISO 286 tolerance class, or `nil` if the dimension carries none.
        public let classOfTolerance: ClassOfTolerance?

        /// Position in the document's dimension sequence.
        public let index: Int

        /// The lower bound, or `nil` unless `bounds` is `.range`.
        public var lowerBound: Double? {
            guard case .range(let lower, _) = bounds else { return nil }
            return lower
        }

        /// The upper bound, or `nil` unless `bounds` is `.range`.
        public var upperBound: Double? {
            guard case .range(_, let upper) = bounds else { return nil }
            return upper
        }

        /// The lower tolerance, or `nil` unless `bounds` is `.plusMinus`.
        public var lowerTolerance: Double? {
            guard case .plusMinus(let lower, _) = bounds else { return nil }
            return lower
        }

        /// The upper tolerance, or `nil` unless `bounds` is `.plusMinus`.
        public var upperTolerance: Double? {
            guard case .plusMinus(_, let upper) = bounds else { return nil }
            return upper
        }
    }

    /// A geometric tolerance read from, or created on, a `Document`.
    ///
    /// ```swift
    /// let zones = doc.geomTolerances.map { "\($0.type): \($0.value)" }
    /// ```
    public struct GeomTolerance: Sendable, Hashable {
        /// The ASME / ISO tolerance class.
        public let type: GeomToleranceType
        /// Tolerance zone value, in model units.
        public let value: Double
        /// Position in the document's geometric tolerance sequence.
        public let index: Int
    }

    /// A datum reference read from, or created on, a `Document`.
    ///
    /// ```swift
    /// let names = doc.datums.map(\.name).sorted()
    /// ```
    public struct Datum: Sendable, Hashable {
        /// Datum identifier, for example `"A"`.
        public let name: String
        /// Position in the document's datum sequence.
        public let index: Int
    }

    // MARK: - Counts

    /// Number of dimensions defined in this document.
    public var dimensionCount: Int {
        Int(OCCTDocumentGetDimensionCount(handle))
    }

    /// Number of geometric tolerances defined in this document.
    public var geomToleranceCount: Int {
        Int(OCCTDocumentGetGeomToleranceCount(handle))
    }

    /// Number of datums defined in this document.
    public var datumCount: Int {
        Int(OCCTDocumentGetDatumCount(handle))
    }

    // MARK: - Read path

    /// The dimension at the given index.
    ///
    /// ```swift
    /// if let dim = doc.dimension(at: 0) {
    ///     print(dim.type, dim.value ?? 0, dim.bounds)
    /// }
    /// ```
    ///
    /// - Parameter index: Zero-based index into the document's dimension sequence.
    /// - Returns: The dimension, or `nil` if the index is out of range or its type code has no
    ///   matching `DimensionType` case.
    public func dimension(at index: Int) -> Dimension? {
        let info = OCCTDocumentGetDimensionInfo(handle, Int32(index))
        guard info.isValid, let type = DimensionType(rawValue: info.type) else { return nil }

        let bounds: Dimension.Bounds
        switch info.boundsKind {
        case Int32(OCCTDimensionBoundsSimple.rawValue):
            bounds = .simple
        case Int32(OCCTDimensionBoundsRange.rawValue):
            bounds = .range(lower: info.lowerBound, upper: info.upperBound)
        case Int32(OCCTDimensionBoundsPlusMinus.rawValue):
            bounds = .plusMinus(lowerTolerance: info.lowerTol, upperTolerance: info.upperTol)
        default:
            bounds = .unset
        }

        var classOfTolerance: Dimension.ClassOfTolerance?
        if info.hasClassOfTolerance,
            let formVariance = DimensionFormVariance(rawValue: info.formVariance),
            let grade = DimensionGrade(rawValue: info.grade)
        {
            classOfTolerance = Dimension.ClassOfTolerance(
                isHole: info.classOfToleranceIsHole,
                formVariance: formVariance,
                grade: grade)
        }

        return Dimension(
            type: type,
            value: bounds == .unset ? nil : info.value,
            bounds: bounds,
            classOfTolerance: classOfTolerance,
            index: index)
    }

    /// The geometric tolerance at the given index.
    ///
    /// ```swift
    /// if let tol = doc.geomTolerance(at: 0) {
    ///     print(tol.type, tol.value)
    /// }
    /// ```
    ///
    /// - Parameter index: Zero-based index into the document's geometric tolerance sequence.
    /// - Returns: The tolerance, or `nil` if the index is out of range or its type code has no
    ///   matching `GeomToleranceType` case.
    public func geomTolerance(at index: Int) -> GeomTolerance? {
        let info = OCCTDocumentGetGeomToleranceInfo(handle, Int32(index))
        guard info.isValid, let type = GeomToleranceType(rawValue: info.type) else { return nil }
        return GeomTolerance(type: type, value: info.value, index: index)
    }

    /// The datum at the given index.
    ///
    /// ```swift
    /// if let datum = doc.datum(at: 0) {
    ///     print(datum.name)
    /// }
    /// ```
    ///
    /// - Parameter index: Zero-based index into the document's datum sequence.
    /// - Returns: The datum, or `nil` if the index is out of range.
    public func datum(at index: Int) -> Datum? {
        var info = OCCTDocumentGetDatumInfo(handle, Int32(index))
        guard info.isValid else { return nil }
        let name = withUnsafeBytes(of: &info.name) { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return "" }
            let charPtr = baseAddress.assumingMemoryBound(to: CChar.self)
            return String(cString: charPtr)
        }
        return Datum(name: name, index: index)
    }

    /// All dimensions in this document.
    ///
    /// ```swift
    /// let diameters = doc.dimensions.filter { $0.type == .sizeDiameter }
    /// ```
    public var dimensions: [Dimension] {
        (0..<dimensionCount).compactMap { dimension(at: $0) }
    }

    /// All geometric tolerances in this document.
    ///
    /// ```swift
    /// let perpendicular = doc.geomTolerances.filter { $0.type == .perpendicularity }
    /// ```
    public var geomTolerances: [GeomTolerance] {
        (0..<geomToleranceCount).compactMap { geomTolerance(at: $0) }
    }

    /// All datums in this document.
    ///
    /// ```swift
    /// for datum in doc.datums { print("Datum:", datum.name) }
    /// ```
    public var datums: [Datum] {
        (0..<datumCount).compactMap { datum(at: $0) }
    }
}
