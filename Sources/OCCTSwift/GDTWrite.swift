import Foundation
import OCCTBridge

// MARK: - GD&T write path (v0.140, #67/#70 follow-up)
//
// Authors STEP AP242 dimensions, geometric tolerances and datums on a `Document` so downstream
// callers can round-trip GD&T through STEP. The read side, including the `DimensionType`,
// `GeomToleranceType`, `DimensionFormVariance` and `DimensionGrade` vocabulary these methods take,
// lives in `GDTRead.swift` (#996).
//
// #1004 widened this to the dimension accessors that change what a dimension's number means: the
// two qualifiers, the modifier sequence and the drawn decimal places. Each read accessor ships with
// the mutator that authors it, because a read nothing in this package can write has no way to be
// tested against a document of our own. The rest of `XCAFDimTolObjects_DimensionObject`'s surface
// (path, direction, connections, descriptions, presentation, semantic name) stays unwrapped, and
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
}
