import Foundation
import OCCTBridge

// MARK: - GD&T write path (v0.140, #67/#70 follow-up)
//
// Authors STEP AP242 dimensions, geometric tolerances and datums on a `Document` so downstream
// callers can round-trip GD&T through STEP. The read side, including the `DimensionType`,
// `GeomToleranceType`, `DimensionFormVariance` and `DimensionGrade` vocabulary these methods take,
// lives in `GDTRead.swift` (#996).
//
// #1004 widened this to the accessors that change what a GD&T value means: a dimension's two
// qualifiers, modifier sequence and drawn decimal places; a tolerance's value type, material
// requirement, zone modifier, maximum value and modifier sequence; a datum's frame position,
// modifiers and datum target. Each read accessor ships with the mutator that authors it, because a
// read nothing in this package can write has no way to be tested against a document of our own.
// The geometry and presentation surface of all three classes (paths, directions, connections,
// annotation planes, text anchors, presentation shapes, semantic names) stays unwrapped, and
// `docs/occtswift-wrapping-gaps.md` records why per accessor.

extension Document {
    /// Create a new dimension on the document, attached to the shape at `shapeLabel`.
    ///
    /// ```swift
    /// let label = doc.addShape(shaft, makeAssembly: false)
    /// doc.createDimension(on: label, type: .sizeDiameter, value: 20.0)
    /// ```
    ///
    /// - Returns: The new dimension's index, or `nil` on failure.
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

    /// Create a new geometric tolerance on the document, attached to the shape at `shapeLabel`.
    ///
    /// ```swift
    /// doc.createGeomTolerance(on: label, type: .flatness, value: 0.01)
    /// ```
    ///
    /// - Returns: The new tolerance's index, or `nil` on failure.
    @discardableResult
    public func createGeomTolerance(
        on shapeLabel: Int64,
        type: GeomToleranceType,
        value: Double
    ) -> Int? {
        let idx = OCCTDocumentCreateGeomTolerance(handle, shapeLabel, type.rawValue, value)
        return idx >= 0 ? Int(idx) : nil
    }

    /// Create a new datum on the document with the given identifier.
    ///
    /// ```swift
    /// doc.createDatum(name: "A")
    /// ```
    ///
    /// - Returns: The new datum's index, or `nil` on failure.
    @discardableResult
    public func createDatum(name: String) -> Int? {
        let idx = name.withCString { OCCTDocumentCreateDatum(handle, $0) }
        return idx >= 0 ? Int(idx) : nil
    }

    /// Set the signed tolerances of an existing dimension, making its `bounds` `.plusMinus`.
    ///
    /// ```swift
    /// doc.setDimensionTolerance(at: 0, lower: -0.3, upper: 0.7)
    /// ```
    ///
    /// - Returns: `false` if the index is out of range, or if the dimension is already `.range`,
    ///   which OCCT refuses to convert and leaves unchanged.
    @discardableResult
    public func setDimensionTolerance(
        at index: Int,
        lower: Double,
        upper: Double
    ) -> Bool {
        OCCTDocumentSetDimensionTolerance(handle, Int32(index), lower, upper)
    }

    /// Set the bounds of an existing dimension, making its `bounds` `.range`.
    ///
    /// ```swift
    /// doc.setDimensionBounds(at: 0, lower: 10.0, upper: 12.0)
    /// ```
    ///
    /// - Returns: `false` if the index is out of range.
    @discardableResult
    public func setDimensionBounds(
        at index: Int,
        lower: Double,
        upper: Double
    ) -> Bool {
        OCCTDocumentSetDimensionBounds(handle, Int32(index), lower, upper)
    }

    /// Set the ISO 286 tolerance class of an existing dimension, leaving its `bounds` alone.
    ///
    /// ```swift
    /// doc.setDimensionClassOfTolerance(at: 0, isHole: true, formVariance: .h, grade: .it7)
    /// ```
    ///
    /// - Returns: `false` if the index is out of range.
    @discardableResult
    public func setDimensionClassOfTolerance(
        at index: Int,
        isHole: Bool,
        formVariance: DimensionFormVariance,
        grade: DimensionGrade
    ) -> Bool {
        OCCTDocumentSetDimensionClassOfTolerance(
            handle, Int32(index), isHole, formVariance.rawValue, grade.rawValue)
    }

    /// Set whether an existing dimension's value is a minimum, a maximum or an average.
    ///
    /// ```swift
    /// doc.setDimensionQualifier(at: 0, .max)
    /// ```
    ///
    /// - Parameters:
    ///   - index: Zero-based index into the document's dimension sequence.
    ///   - qualifier: Pass `.none` to clear the qualifier, which is OCCT's own spelling for a
    ///     nominal value.
    /// - Returns: `false` if the index is out of range.
    @discardableResult
    public func setDimensionQualifier(at index: Int, _ qualifier: DimensionQualifier) -> Bool {
        OCCTDocumentSetDimensionQualifier(handle, Int32(index), qualifier.rawValue)
    }

    /// Set whether an existing angular dimension names the small, the large or the equal angle.
    ///
    /// ```swift
    /// doc.setDimensionAngularQualifier(at: 0, .large)
    /// ```
    ///
    /// - Parameters:
    ///   - index: Zero-based index into the document's dimension sequence.
    ///   - qualifier: Pass `.none` to clear the qualifier.
    /// - Returns: `false` if the index is out of range.
    @discardableResult
    public func setDimensionAngularQualifier(
        at index: Int,
        _ qualifier: AngularQualifier
    ) -> Bool {
        OCCTDocumentSetDimensionAngularQualifier(handle, Int32(index), qualifier.rawValue)
    }

    /// Set the number of decimal places an existing dimension is drawn to.
    ///
    /// ```swift
    /// doc.setDimensionDecimalPlaces(at: 0, left: 2, right: 3)
    /// ```
    ///
    /// - Parameters:
    ///   - index: Zero-based index into the document's dimension sequence.
    ///   - left: Places to the left of the decimal point.
    ///   - right: Places to the right.
    /// - Returns: `false` if the index is out of range or either count is negative. Passing `0`
    ///   for both clears the pair, so `dimension(at:)` reports `decimalPlaces` as `nil`.
    @discardableResult
    public func setDimensionDecimalPlaces(at index: Int, left: Int, right: Int) -> Bool {
        OCCTDocumentSetDimensionDecimalPlaces(handle, Int32(index), Int32(left), Int32(right))
    }

    /// Replace an existing dimension's GD&T modifier sequence.
    ///
    /// ```swift
    /// doc.setDimensionModifiers(at: 0, [.statisticalTolerance, .anyCrossSection])
    /// ```
    ///
    /// - Parameters:
    ///   - index: Zero-based index into the document's dimension sequence.
    ///   - modifiers: The new sequence, in the order OCCT should store it. An empty array clears
    ///     the sequence.
    /// - Returns: `false` if the index is out of range.
    @discardableResult
    public func setDimensionModifiers(at index: Int, _ modifiers: [DimensionModifier]) -> Bool {
        let raw = modifiers.map(\.rawValue)
        return raw.withUnsafeBufferPointer { buffer in
            OCCTDocumentSetDimensionModifiers(
                handle, Int32(index), buffer.baseAddress, Int32(buffer.count))
        }
    }

    /// Set what an existing geometric tolerance's value measures.
    ///
    /// ```swift
    /// doc.setGeomToleranceValueType(at: 0, .diameter)
    /// ```
    ///
    /// - Parameters:
    ///   - index: Zero-based index into the document's geometric tolerance sequence.
    ///   - valueType: Pass `.none` for a linear zone width.
    /// - Returns: `false` if the index is out of range.
    @discardableResult
    public func setGeomToleranceValueType(
        at index: Int,
        _ valueType: GeomToleranceValueType
    ) -> Bool {
        OCCTDocumentSetGeomToleranceTypeOfValue(handle, Int32(index), valueType.rawValue)
    }

    /// Set the material condition an existing geometric tolerance applies at.
    ///
    /// ```swift
    /// doc.setGeomToleranceMaterialRequirement(at: 0, .m)
    /// ```
    ///
    /// - Parameters:
    ///   - index: Zero-based index into the document's geometric tolerance sequence.
    ///   - requirement: Pass `.none` for regardless of feature size.
    /// - Returns: `false` if the index is out of range.
    @discardableResult
    public func setGeomToleranceMaterialRequirement(
        at index: Int,
        _ requirement: MaterialRequirement
    ) -> Bool {
        OCCTDocumentSetGeomToleranceMaterialRequirement(
            handle, Int32(index), requirement.rawValue)
    }

    /// Set an existing geometric tolerance's zone modifier and its associated value.
    ///
    /// ```swift
    /// doc.setGeomToleranceZoneModifier(at: 0, .projected, value: 15.0)
    /// ```
    ///
    /// - Parameters:
    ///   - index: Zero-based index into the document's geometric tolerance sequence.
    ///   - modifier: Pass `.none` to clear the modifier.
    ///   - value: The associated value, for example a projected zone's length. Zero or less clears
    ///     it, so `geomTolerance(at:)` reports `zoneModifierValue` as `nil`.
    /// - Returns: `false` if the index is out of range.
    @discardableResult
    public func setGeomToleranceZoneModifier(
        at index: Int,
        _ modifier: GeomToleranceZoneModifier,
        value: Double = 0
    ) -> Bool {
        OCCTDocumentSetGeomToleranceZoneModifier(
            handle, Int32(index), modifier.rawValue, value)
    }

    /// Set the maximal upper tolerance of an existing geometric tolerance with modifiers.
    ///
    /// ```swift
    /// doc.setGeomToleranceMaxValueModifier(at: 0, 0.25)
    /// ```
    ///
    /// - Parameters:
    ///   - index: Zero-based index into the document's geometric tolerance sequence.
    ///   - value: Zero or less clears it, so `geomTolerance(at:)` reports `maxValueModifier` as
    ///     `nil`.
    /// - Returns: `false` if the index is out of range.
    @discardableResult
    public func setGeomToleranceMaxValueModifier(at index: Int, _ value: Double) -> Bool {
        OCCTDocumentSetGeomToleranceMaxValueModifier(handle, Int32(index), value)
    }

    /// Replace an existing geometric tolerance's modifier sequence.
    ///
    /// ```swift
    /// doc.setGeomToleranceModifiers(at: 0, [.allAround, .freeState])
    /// ```
    ///
    /// - Parameters:
    ///   - index: Zero-based index into the document's geometric tolerance sequence.
    ///   - modifiers: The new sequence, in the order OCCT should store it. An empty array clears
    ///     the sequence.
    /// - Returns: `false` if the index is out of range.
    @discardableResult
    public func setGeomToleranceModifiers(
        at index: Int,
        _ modifiers: [GeomToleranceModifier]
    ) -> Bool {
        let raw = modifiers.map(\.rawValue)
        return raw.withUnsafeBufferPointer { buffer in
            OCCTDocumentSetGeomToleranceModifiers(
                handle, Int32(index), buffer.baseAddress, Int32(buffer.count))
        }
    }

    /// Set an existing datum's place in its geometric tolerance's reference frame.
    ///
    /// ```swift
    /// doc.setDatumPosition(at: 0, 1)   // the primary datum of A|B|C
    /// ```
    ///
    /// - Parameters:
    ///   - index: Zero-based index into the document's datum sequence.
    ///   - position: 1-based. Zero or less clears it, so `datum(at:)` reports `position` as `nil`.
    /// - Returns: `false` if the index is out of range.
    @discardableResult
    public func setDatumPosition(at index: Int, _ position: Int) -> Bool {
        OCCTDocumentSetDatumPosition(handle, Int32(index), Int32(position))
    }

    /// Replace an existing datum's modifier sequence.
    ///
    /// ```swift
    /// doc.setDatumModifiers(at: 0, [.basic, .contactingFeature])
    /// ```
    ///
    /// - Parameters:
    ///   - index: Zero-based index into the document's datum sequence.
    ///   - modifiers: The new sequence, in the order OCCT should store it. An empty array clears
    ///     the sequence.
    /// - Returns: `false` if the index is out of range.
    @discardableResult
    public func setDatumModifiers(at index: Int, _ modifiers: [DatumModifier]) -> Bool {
        let raw = modifiers.map(\.rawValue)
        return raw.withUnsafeBufferPointer { buffer in
            OCCTDocumentSetDatumModifiers(
                handle, Int32(index), buffer.baseAddress, Int32(buffer.count))
        }
    }

    /// Set an existing datum's single valued modifier.
    ///
    /// ```swift
    /// doc.setDatumModifierWithValue(at: 0, .projected, value: 12.5)
    /// ```
    ///
    /// - Parameters:
    ///   - index: Zero-based index into the document's datum sequence.
    ///   - modifier: Pass `.none` to clear the pair, which also clears the value.
    ///   - value: The number the modifier carries.
    /// - Returns: `false` if the index is out of range.
    @discardableResult
    public func setDatumModifierWithValue(
        at index: Int,
        _ modifier: DatumModifierWithValue,
        value: Double = 0
    ) -> Bool {
        OCCTDocumentSetDatumModifierWithValue(handle, Int32(index), modifier.rawValue, value)
    }

    /// Mark an existing datum as a datum target, or clear that mark.
    ///
    /// ```swift
    /// doc.setDatumTarget(at: 0, type: .rectangle, number: 1)
    /// ```
    ///
    /// - Parameters:
    ///   - index: Zero-based index into the document's datum sequence.
    ///   - type: The target's shape.
    ///   - number: The target's number within its datum.
    /// - Returns: `false` if the index is out of range or `number` is negative.
    @discardableResult
    public func setDatumTarget(at index: Int, type: DatumTargetType, number: Int) -> Bool {
        OCCTDocumentSetDatumTarget(handle, Int32(index), true, type.rawValue, Int32(number))
    }

    /// Clear an existing datum's datum target mark, so `datum(at:)` reports `target` as `nil`.
    ///
    /// ```swift
    /// doc.clearDatumTarget(at: 0)
    /// ```
    ///
    /// - Parameter index: Zero-based index into the document's datum sequence.
    /// - Returns: `false` if the index is out of range.
    @discardableResult
    public func clearDatumTarget(at index: Int) -> Bool {
        OCCTDocumentSetDatumTarget(handle, Int32(index), false, 0, 0)
    }

    /// Set an existing datum target's placement, length and width together.
    ///
    /// ```swift
    /// doc.setDatumTargetPlacement(
    ///     at: 0, location: SIMD3(1, 2, 3), normal: SIMD3(0, 0, 1), reference: SIMD3(1, 0, 0),
    ///     length: 30, width: 18)
    /// ```
    ///
    /// All three are one call because each of OCCT's three setters raises the same
    /// `HasDatumTargetParams()` flag, so writing one alone reports the other two as present while
    /// leaving them unassigned. Which of `length` and `width` survives depends on the target type;
    /// see `Datum.Target`.
    ///
    /// - Parameters:
    ///   - index: Zero-based index into the document's datum sequence.
    ///   - location: The placement origin.
    ///   - normal: The placement Z axis, pointing away from the material.
    ///   - reference: The placement X axis, which `length` runs along.
    ///   - length: The target's length.
    ///   - width: The target's width.
    /// - Returns: `false` if the index is out of range, or if `normal` or `reference` is degenerate.
    @discardableResult
    public func setDatumTargetPlacement(
        at index: Int,
        location: SIMD3<Double>,
        normal: SIMD3<Double>,
        reference: SIMD3<Double>,
        length: Double,
        width: Double
    ) -> Bool {
        let loc = [location.x, location.y, location.z]
        let nrm = [normal.x, normal.y, normal.z]
        let ref = [reference.x, reference.y, reference.z]
        return loc.withUnsafeBufferPointer { locBuf in
            nrm.withUnsafeBufferPointer { nrmBuf in
                ref.withUnsafeBufferPointer { refBuf in
                    guard let l = locBuf.baseAddress, let n = nrmBuf.baseAddress,
                        let r = refBuf.baseAddress
                    else { return false }
                    return OCCTDocumentSetDatumTargetPlacement(
                        handle, Int32(index), l, n, r, length, width)
                }
            }
        }
    }
}
