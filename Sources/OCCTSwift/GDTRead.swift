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
}

extension Document.DimensionType {
    /// Whether this type measures a distance between two features rather than one feature's size.
    ///
    /// Asked of OCCT's own `XCAFDimTolObjects_DimensionObject::IsDimensionalLocation` rather than
    /// re-derived from the case list, so a type OCCT reclassifies moves with it.
    ///
    /// ```swift
    /// let locations = doc.dimensions.filter(\.type.isDimensionalLocation)
    /// ```
    public var isDimensionalLocation: Bool {
        OCCTDimensionTypeIsDimensionalLocation(rawValue)
    }

    /// Whether this type measures one feature's own size rather than a distance between two.
    ///
    /// Asked of OCCT's own `XCAFDimTolObjects_DimensionObject::IsDimensionalSize`. Neither
    /// classifier holds for every type: `.commonLabel` and `.dimensionPresentation` are neither.
    ///
    /// ```swift
    /// let sizes = doc.dimensions.filter(\.type.isDimensionalSize)
    /// ```
    public var isDimensionalSize: Bool {
        OCCTDimensionTypeIsDimensionalSize(rawValue)
    }
}

extension Document {
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

    /// Whether a dimension's value is a minimum, a maximum or an average rather than a nominal,
    /// matching `XCAFDimTolObjects_DimensionQualifier`.
    ///
    /// `.none` is OCCT's own member for "no qualifier", so it means the value is nominal rather
    /// than standing in for an absent answer. `HasQualifier()` is exactly `!= .none`. Spell the
    /// type out when comparing through an optional chain, since a bare `.none` there resolves to
    /// `Optional.none` instead.
    ///
    /// ```swift
    /// let maxima = doc.dimensions.filter { $0.qualifier == .max }
    /// ```
    public enum DimensionQualifier: Int32, Sendable, CaseIterable {
        case none = 0
        case min = 1
        case max = 2
        case avg = 3
    }

    /// Whether an angular dimension names the small, the large or the equal angle, matching
    /// `XCAFDimTolObjects_AngularQualifier`.
    ///
    /// `.none` is OCCT's own member for "no qualifier", the same as `DimensionQualifier.none`,
    /// and it carries the same optional-chain caveat.
    ///
    /// ```swift
    /// let reflex = doc.dimensions.filter { $0.angularQualifier == .large }
    /// ```
    public enum AngularQualifier: Int32, Sendable, CaseIterable {
        case none = 0
        case small = 1
        case large = 2
        case equal = 3
    }

    /// A GD&T modifier attached to a dimension, matching `XCAFDimTolObjects_DimensionModif`.
    ///
    /// Unlike the qualifiers, this enum has no `none` member: a dimension carries a sequence of
    /// these, and the sequence being empty is what "no modifier" means.
    ///
    /// ```swift
    /// let statistical = doc.dimensions.filter { $0.modifiers.contains(.statisticalTolerance) }
    /// ```
    public enum DimensionModifier: Int32, Sendable, CaseIterable {
        case controlledRadius = 0
        case square = 1
        case statisticalTolerance = 2
        case continuousFeature = 3
        case twoPointSize = 4
        case localSizeDefinedBySphere = 5
        case leastSquaresAssociationCriterion = 6
        case maximumInscribedAssociation = 7
        case minimumCircumscribedAssociation = 8
        case circumferenceDiameter = 9
        case areaDiameter = 10
        case volumeDiameter = 11
        case maximumSize = 12
        case minimumSize = 13
        case averageSize = 14
        case medianSize = 15
        case midRangeSize = 16
        case rangeOfSizes = 17
        case anyRestrictedPortionOfFeature = 18
        case anyCrossSection = 19
        case specificFixedCrossSection = 20
        case commonTolerance = 21
        case freeStateCondition = 22
        case between = 23
    }

    /// What a geometric tolerance's zone value measures, matching
    /// `XCAFDimTolObjects_GeomToleranceTypeValue`.
    ///
    /// `.none` is a linear zone width. The other two make the same number a diameter, so reading
    /// the value without this is reading it at half or twice its meaning.
    ///
    /// ```swift
    /// let diametral = doc.geomTolerances.filter { $0.valueType == .diameter }
    /// ```
    public enum GeomToleranceValueType: Int32, Sendable, CaseIterable {
        case none = 0
        case diameter = 1
        case sphericalDiameter = 2
    }

    /// The ISO 2692 material condition a geometric tolerance applies at, matching
    /// `XCAFDimTolObjects_GeomToleranceMatReqModif`.
    ///
    /// The case names are the drawing symbols: `.m` is maximum material condition, circle-M, and
    /// `.l` is least material condition, circle-L. `.none` is regardless of feature size.
    ///
    /// ```swift
    /// let mmc = doc.geomTolerances.filter { $0.materialRequirement == .m }
    /// ```
    public enum MaterialRequirement: Int32, Sendable, CaseIterable {
        case none = 0
        case m = 1
        case l = 2
    }

    /// How a geometric tolerance's zone is qualified, matching
    /// `XCAFDimTolObjects_GeomToleranceZoneModif`.
    ///
    /// ```swift
    /// let projected = doc.geomTolerances.filter { $0.zoneModifier == .projected }
    /// ```
    public enum GeomToleranceZoneModifier: Int32, Sendable, CaseIterable {
        case none = 0
        case projected = 1
        case runout = 2
        case nonUniform = 3
    }

    /// A GD&T modifier attached to a geometric tolerance, matching
    /// `XCAFDimTolObjects_GeomToleranceModif`.
    ///
    /// No `none` member: a tolerance carries a sequence of these, and the sequence being empty is
    /// what "no modifier" means.
    ///
    /// ```swift
    /// let allAround = doc.geomTolerances.filter { $0.modifiers.contains(.allAround) }
    /// ```
    public enum GeomToleranceModifier: Int32, Sendable, CaseIterable {
        case anyCrossSection = 0
        case commonZone = 1
        case eachRadialElement = 2
        case freeState = 3
        case leastMaterialRequirement = 4
        case lineElement = 5
        case majorDiameter = 6
        case maximumMaterialRequirement = 7
        case minorDiameter = 8
        case notConvex = 9
        case pitchDiameter = 10
        case reciprocityRequirement = 11
        case separateRequirement = 12
        case statisticalTolerance = 13
        case tangentPlane = 14
        case allAround = 15
        case allOver = 16
    }

    /// A modifier attached to a datum, matching `XCAFDimTolObjects_DatumSingleModif`.
    ///
    /// No `none` member, for the same reason as `GeomToleranceModifier`.
    ///
    /// ```swift
    /// let basic = doc.datums.filter { $0.modifiers.contains(.basic) }
    /// ```
    public enum DatumModifier: Int32, Sendable, CaseIterable {
        case anyCrossSection = 0
        case anyLongitudinalSection = 1
        case basic = 2
        case contactingFeature = 3
        case degreeOfFreedomConstraintU = 4
        case degreeOfFreedomConstraintV = 5
        case degreeOfFreedomConstraintW = 6
        case degreeOfFreedomConstraintX = 7
        case degreeOfFreedomConstraintY = 8
        case degreeOfFreedomConstraintZ = 9
        case distanceVariable = 10
        case freeState = 11
        case leastMaterialRequirement = 12
        case line = 13
        case majorDiameter = 14
        case maximumMaterialRequirement = 15
        case minorDiameter = 16
        case orientation = 17
        case pitchDiameter = 18
        case plane = 19
        case point = 20
        case translation = 21
    }

    /// The one datum modifier that carries a number with it, matching
    /// `XCAFDimTolObjects_DatumModifWithValue`.
    ///
    /// OCCT stores at most one of these per datum, alongside its value, which is why it is separate
    /// from the `DatumModifier` sequence rather than a member of it.
    ///
    /// ```swift
    /// if let m = doc.datum(at: 0)?.modifierWithValue, m.modifier == .projected {
    ///     print("projected by \(m.value)")
    /// }
    /// ```
    public enum DatumModifierWithValue: Int32, Sendable, CaseIterable {
        case none = 0
        case circularOrCylindrical = 1
        case distance = 2
        case projected = 3
        case spherical = 4
    }

    /// The shape of a datum target, matching `XCAFDimTolObjects_DatumTargetType`.
    ///
    /// Unlike the other GD&T enums this one has no `none` member and starts at `.point`, so it
    /// means nothing unless the datum is a target at all. `Datum.target` carries it for exactly
    /// that reason.
    ///
    /// ```swift
    /// let areas = doc.datums.filter { $0.target?.type == .area }
    /// ```
    public enum DatumTargetType: Int32, Sendable, CaseIterable {
        case point = 0
        case line = 1
        case rectangle = 2
        case circle = 3
        case area = 4
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

        /// The number of decimal places a dimension is drawn to, present when OCCT stored a pair.
        ///
        /// OCCT keeps the pair only when one of the two is positive, so `DecimalPlaces(0, 0)` is
        /// not representable: that reading is reported as `nil` rather than as a measured zero.
        public struct DecimalPlaces: Sendable, Hashable {
            /// Places to the left of the decimal point.
            public let left: Int
            /// Places to the right of the decimal point.
            public let right: Int
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

        /// Whether `value` is a minimum, a maximum, an average, or (`.none`) a nominal.
        public let qualifier: DimensionQualifier

        /// Whether an angular dimension names the small, the large or the equal angle.
        public let angularQualifier: AngularQualifier

        /// The drawn decimal-place pair, or `nil` when the dimension carries none.
        public let decimalPlaces: DecimalPlaces?

        /// The GD&T modifiers attached to this dimension, in OCCT's own order.
        ///
        /// Empty when the dimension carries none.
        public let modifiers: [DimensionModifier]

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
        /// What `value` measures: a linear width, or (`.diameter`) a diameter.
        public let valueType: GeomToleranceValueType
        /// The material condition the tolerance applies at.
        public let materialRequirement: MaterialRequirement
        /// How the zone is qualified.
        public let zoneModifier: GeomToleranceZoneModifier
        /// The value associated with `zoneModifier`, for example a projected zone's length.
        ///
        /// `nil` when OCCT stored none. It stores this only when positive, so a zero is not
        /// representable and would be indistinguishable from an unstored value.
        public let zoneModifierValue: Double?
        /// The maximal upper tolerance for a tolerance carrying modifiers.
        ///
        /// `nil` when OCCT stored none, gated the same way as `zoneModifierValue`.
        public let maxValueModifier: Double?
        /// The GD&T modifiers on this tolerance, in OCCT's own order.
        ///
        /// Empty when the tolerance carries none.
        public let modifiers: [GeomToleranceModifier]
        /// Position in the document's geometric tolerance sequence.
        public let index: Int
    }

    /// A datum reference read from, or created on, a `Document`.
    ///
    /// ```swift
    /// let names = doc.datums.map(\.name).sorted()
    /// ```
    public struct Datum: Sendable, Hashable {
        /// The one datum modifier that carries a number, present when OCCT stored one.
        public struct ModifierWithValue: Sendable, Hashable {
            /// Which modifier.
            ///
            /// Never `.none`: absence is the enclosing optional.
            public let modifier: DatumModifierWithValue
            /// The number it carries, for example a projected datum's distance.
            public let value: Double
        }

        /// A datum target, present when `IsDatumTarget()` holds.
        ///
        /// `length` and `width` follow OCCT's own storage conditions rather than being reported
        /// unconditionally: a length is kept for every type but `.point`, and a width only for
        /// `.rectangle`. An `.area` target keeps neither, because OCCT stores its own shape
        /// instead of a placement. Measured per type in `Scripts/repro/1004-gdt-accessors/`.
        public struct Target: Sendable, Hashable {
            /// The target's shape.
            public let type: DatumTargetType
            /// The target's number within its datum.
            public let number: Int
            /// The target's length along its placement X axis, or `nil` where OCCT keeps none.
            public let length: Double?
            /// The target's width along its placement Y axis, or `nil` where OCCT keeps none.
            public let width: Double?
        }

        /// Datum identifier, for example `"A"`.
        public let name: String

        /// The datum's place in its geometric tolerance's reference frame, 1-based.
        ///
        /// This is what makes `A|B|C` an ordered frame rather than a set. `nil` when the datum has
        /// no place in one: positions are 1-based, so 0 is absence rather than a first place.
        public let position: Int?

        /// The modifiers on this datum, in OCCT's own order.
        ///
        /// Empty when the datum carries none.
        public let modifiers: [DatumModifier]

        /// The single valued modifier, or `nil` when the datum carries none.
        public let modifierWithValue: ModifierWithValue?

        /// The datum target, or `nil` when this datum is not a target.
        public let target: Target?

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

    /// Number of datum labels in this document, which can exceed `datums.count`.
    ///
    /// This counts labels; `datums` counts the ones `datum(at:)` can read. A datum OCCT cannot
    /// read without crashing (#1030) is counted here and omitted there, so iterate `datums` rather
    /// than indexing `0..<datumCount` and force-unwrapping.
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

        var decimalPlaces: Dimension.DecimalPlaces?
        if info.hasDecimalPlaces {
            decimalPlaces = Dimension.DecimalPlaces(
                left: Int(info.decimalPlacesLeft), right: Int(info.decimalPlacesRight))
        }

        // A raw value OCCT declares but this enum does not is dropped rather than substituted, the
        // same rule `type` follows above. `Scripts/derive-gdt-enums.py --verify` is what keeps that
        // from happening silently.
        let modifiers = (0..<Int(info.modifierCount)).compactMap { position in
            DimensionModifier(
                rawValue: OCCTDocumentGetDimensionModifier(handle, Int32(index), Int32(position)))
        }

        return Dimension(
            type: type,
            value: bounds == .unset ? nil : info.value,
            bounds: bounds,
            classOfTolerance: classOfTolerance,
            qualifier: DimensionQualifier(rawValue: info.qualifier) ?? .none,
            angularQualifier: AngularQualifier(rawValue: info.angularQualifier) ?? .none,
            decimalPlaces: decimalPlaces,
            modifiers: modifiers,
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

        // A raw value OCCT declares but these enums do not is dropped rather than substituted, the
        // same rule `type` follows. `Scripts/derive-gdt-enums.py --verify` keeps that from
        // happening silently.
        let modifiers = (0..<Int(info.modifierCount)).compactMap { position in
            GeomToleranceModifier(
                rawValue: OCCTDocumentGetGeomToleranceModifier(
                    handle, Int32(index), Int32(position)))
        }

        return GeomTolerance(
            type: type,
            value: info.value,
            valueType: GeomToleranceValueType(rawValue: info.typeOfValue) ?? .none,
            materialRequirement: MaterialRequirement(rawValue: info.materialRequirement) ?? .none,
            zoneModifier: GeomToleranceZoneModifier(rawValue: info.zoneModifier) ?? .none,
            zoneModifierValue: info.hasZoneModifierValue ? info.zoneModifierValue : nil,
            maxValueModifier: info.hasMaxValueModifier ? info.maxValueModifier : nil,
            modifiers: modifiers,
            index: index)
    }

    /// The datum's identifier, whole, however long it is.
    ///
    /// The bridge reports the length it needs rather than truncating to a fixed buffer, so this
    /// sizes a buffer from that report instead of guessing. The first call uses a 64-element buffer
    /// that covers every conventional identifier (`A`, `B`, `A1`); only a longer one pays for a
    /// second call (#1055).
    ///
    /// The cost of correctness here is one more walk of `GetDatumLabels()` per datum than the
    /// removed `OCCTDatumInfo.name` field needed, and two more for a name of 64 bytes or longer.
    /// `datum(at:)` already pays one such walk per modifier, so this is the same order of work
    /// rather than a new one, and it is what buys a name that is never silently a prefix.
    private func datumName(at index: Int) -> String? {
        var short = [CChar](repeating: 0, count: 64)
        let length = OCCTDocumentGetDatumName(handle, Int32(index), &short, Int32(short.count))
        guard length >= 0 else { return nil }
        if Int(length) < short.count { return Self.string(fromCString: short) }

        var exact = [CChar](repeating: 0, count: Int(length) + 1)
        let again = OCCTDocumentGetDatumName(handle, Int32(index), &exact, Int32(exact.count))
        // The second length is checked as well as the first. A name that grew between the two calls
        // would put this back where #1055 started, handing back a prefix and calling it the name,
        // at the one site the whole contract rests on. Nothing can grow one today, since there is no
        // rename and no removal on this surface, so this is hardening rather than a live path.
        guard again >= 0, Int(again) < exact.count else { return nil }
        return Self.string(fromCString: exact)
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
    /// - Returns: The datum, or `nil` if the index is out of range, or for a datum carrying an
    ///   annotation point with no annotation plane, which OCCT cannot read without crashing
    ///   (#1030); see `docs/reference/Annotation.md`.
    public func datum(at index: Int) -> Datum? {
        let info = OCCTDocumentGetDatumInfo(handle, Int32(index))
        guard info.isValid else { return nil }
        guard let name = datumName(at: index) else { return nil }
        var modifierWithValue: Datum.ModifierWithValue?
        if let modifier = DatumModifierWithValue(rawValue: info.modifierWithValue),
            modifier != .none
        {
            modifierWithValue = Datum.ModifierWithValue(
                modifier: modifier, value: info.modifierValue)
        }

        var target: Datum.Target?
        if info.isDatumTarget, let type = DatumTargetType(rawValue: info.targetType) {
            target = Datum.Target(
                type: type,
                number: Int(info.targetNumber),
                length: info.hasTargetLength ? info.targetLength : nil,
                width: info.hasTargetWidth ? info.targetWidth : nil)
        }

        let modifiers = (0..<Int(info.modifierCount)).compactMap { position in
            DatumModifier(
                rawValue: OCCTDocumentGetDatumModifier(handle, Int32(index), Int32(position)))
        }

        return Datum(
            name: name,
            position: info.hasPosition ? Int(info.position) : nil,
            modifiers: modifiers,
            modifierWithValue: modifierWithValue,
            target: target,
            index: index)
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
    ///
    /// - Returns: Every datum `datum(at:)` succeeds on, so one OCCT cannot read (#1030) is
    ///   omitted rather than crashing the enumeration.
    public var datums: [Datum] {
        (0..<datumCount).compactMap { datum(at: $0) }
    }
}
