// Continuity vocabularies.
//
// OCCTSwift had grown nine separate enums for "continuity level", each written against a
// different bridge call and each re-deriving its own raw-int meaning (#398). They collapse
// into exactly three contracts, which is why there are two shared enums here rather than one:
//
//   1. Geometric constraint order, 0/1/2 = G0/G1/G2. Handed to a plate solver as the order of
//      a point, curve or edge constraint. GeomPlate_CurveConstraint validates it directly and
//      rejects anything outside [-1, 2] with the message "The continuity is not G0 G1 or G2".
//      That is `SurfaceContinuity`.
//
//   2. Required parametric continuity, 0/1/2/3 = C0/C1/C2/C3. Answers "split, approximate or
//      restrict this geometry so every piece is at least Cn". Reaches OCCT either as a real
//      GeomAbs_Shape continuity class or as a literal derivative-order integer.
//      That is `ParametricContinuity`.
//
//   3. A GeomAbs_Shape ordinal reported back as a *result*, which is a different job from
//      either input vocabulary above and keeps its own type: `ContinuityClass`. Unlike the two
//      request vocabularies it is not a 0/1/2 order at all; it is GeomAbs_Shape's own declared
//      order, which interleaves the geometric classes with the parametric ones.
//
// The two are not interchangeable even though both count 0, 1, 2. G1 asks only for parallel
// tangent directions; C1 asks for equal derivative vectors. Feeding one enum's raw value to
// the other's bridge call is precisely the class of defect #398 was filed about, so they are
// deliberately distinct types that will not silently substitute for one another.

// MARK: - Geometric constraint order (G0/G1/G2)

/// Geometric continuity order for a surface constraint.
///
/// The single vocabulary behind every OCCTSwift call that constrains a generated surface
/// against a point, edge or wire: ``Shape/fill(boundaries:parameters:)``,
/// ``Shape/fill(constraints:parameters:)``, ``FillingSurface`` and
/// ``Shape/plateSurface(through:orders:degree:pointsOnCurves:iterations:tolerance:)``.
/// All of them hand the raw value to OCCT as a plate constraint order.
///
/// ```swift
/// // Tangent to the wall the rim came from
/// let skinned = solid.fill(
///     constraints: [FillConstraint(edge: rimEdge, support: wallFace, continuity: .g1)]
/// )
///
/// // Curvature-continuous patch across a hole
/// let smooth = solid.fill(
///     boundaries: [holeWire],
///     parameters: FillingParameters(continuity: .g2)
/// )
/// ```
///
/// - Note: Not every API accepts every order. A bare point cannot carry curvature, so
///   ``Shape/plateSurface(through:orders:degree:pointsOnCurves:iterations:tolerance:)`` and the
///   point half of ``Shape/plateSurface(pointConstraints:curveConstraints:degree:tolerance:)``
///   reject ``g2`` up front, before building any constraint (`GeomPlate_PointConstraint` throws
///   above order 1; see ``SurfaceContinuity/isUnsupportedForPointConstraint``, #437).
public enum SurfaceContinuity: Int32, Sendable, CaseIterable {
    /// Positional continuity (G0). The surface passes through the constraint.
    case g0 = 0
    /// Tangent continuity (G1). The surface is tangent along the constraint.
    case g1 = 1
    /// Curvature continuity (G2). The surface matches curvature along the constraint.
    case g2 = 2
}

extension SurfaceContinuity {
    /// Whether this order can never be honoured by a bare *point* constraint (#437).
    ///
    /// `GeomPlate_PointConstraint`'s point constructor throws above order 1
    /// (`GeomPlate_PointConstraint.cxx`, pinned `V8_0_1`):
    ///
    /// ```cpp
    /// if ((myOrder > 1) || (myOrder < -1)) {
    ///   throw Standard_Failure("GeomPlate_PointConstraint : the constraint must 0 or -1 with a point");
    /// }
    /// ```
    ///
    /// A bare point carries no curvature to match, so ``g2`` is genuinely out of domain for a
    /// point constraint: this is not an OCCT defect. `GeomPlate_CurveConstraint` has no such
    /// restriction (it accepts order up to 2 directly), so this only ever applies to a *point*.
    ///
    /// `Shape.plateSurface(through:orders:...)` and the point half of
    /// `Shape.plateSurface(pointConstraints:curveConstraints:...)` check this before building any
    /// `GeomPlate_PointConstraint`, so a `.g2` point order fails immediately with the reason on
    /// record here rather than reaching `GeomPlate_BuildPlateSurface`, throwing, and being
    /// swallowed by the bridge's `catch (...)`, which produced the same `nil`, but for a reason
    /// nothing on the Swift side asserted, and only because OCCT happens to throw there today.
    var isUnsupportedForPointConstraint: Bool {
        self == .g2
    }
}

extension SurfaceContinuity {
    /// Positional continuity. Former spelling of ``g0``.
    ///
    /// The G-prefixed spellings are canonical: these orders are geometric continuity, which is
    /// what OCCT itself calls them.
    @available(*, deprecated, renamed: "g0")
    public static var c0: SurfaceContinuity { .g0 }

    /// Tangent continuity. Former spelling of ``g1``, from `FillingContinuity`.
    @available(*, deprecated, renamed: "g1")
    public static var c1: SurfaceContinuity { .g1 }

    /// Curvature continuity. Former spelling of ``g2``, from `FillingContinuity`.
    @available(*, deprecated, renamed: "g2")
    public static var c2: SurfaceContinuity { .g2 }
}

/// Former name for ``SurfaceContinuity`` used by ``FillingSurface``.
@available(*, deprecated, renamed: "SurfaceContinuity")
public typealias FillingContinuity = SurfaceContinuity

/// Former name for ``SurfaceContinuity`` used by the plate-surface constraint APIs.
@available(*, deprecated, renamed: "SurfaceContinuity")
public typealias PlateConstraintOrder = SurfaceContinuity

// MARK: - Required parametric continuity (C0/C1/C2/C3)

/// Minimum parametric continuity to require of a piece of geometry.
///
/// Used wherever an operation splits, approximates or simplifies geometry against a continuity
/// floor: ``Shape/bsplineRestriction(tol3d:tol2d:maxDegree:maxSegments:continuity3d:continuity2d:degreePriority:rational:)``,
/// ``Curve3D/approxWithDetails(tolerance:continuity:maxSegments:maxDegree:)``,
/// ``Surface/approxWithDetails(tolerance:uContinuity:vContinuity:maxSegments:maxDegree:)``, and
/// the whole BSpline knot-splitting family: ``Curve3D/continuityBreaks(minContinuity:)``,
/// ``Curve2D/splitIndicesAtDiscontinuities(continuity:)``,
/// ``Surface/knotSplitting(uContinuity:vContinuity:)``,
/// ``LawFunction/knotSplitting(continuityOrder:)`` and
/// ``LawFunction/knotSplitParameters(continuityOrder:)``.
///
/// `Shape/divided(at:tolerance:)` used to be one of these, but #438 widened it to the strict
/// superset ``Shape/ContinuityLevel``, which also folded in the narrower, now-deprecated
/// `Shape/dividedByContinuity(criterion:tolerance:)`.
///
/// ```swift
/// // Knots where a BSpline fails to be C3. A cubic interpolated curve is C2 at its
/// // interior knots, so .c3 is the order that actually reports them.
/// let breaks = bspline.continuityBreaks(minContinuity: .c3)
/// ```
///
/// - Note: This is *parametric* continuity (equal derivative vectors), not the geometric
///   G0/G1/G2 constraint order of ``SurfaceContinuity`` (parallel tangent directions). The
///   two count the same way but mean different things and are not interchangeable.
///
/// - Note: What the strict end of the ladder can express depends on the consumer. The
///   knot-splitting family reads the value as a literal derivative order against the geometry's
///   own degree, so ``c3`` is exact for a cubic but is the strictest question askable of a
///   degree-4-or-higher BSpline; the approximation family rejects anything above ``c2``
///   outright. Each API's own doc states its measured domain (#480, #490).
public enum ParametricContinuity: Int32, Sendable, CaseIterable {
    /// Positional continuity (C0).
    case c0 = 0
    /// First-derivative continuity (C1).
    case c1 = 1
    /// Second-derivative continuity (C2).
    case c2 = 2
    /// Third-derivative continuity (C3).
    case c3 = 3
}

/// Former name for ``ParametricContinuity`` used by ``Shape/divided(at:)``.
///
/// The old name was a misnomer: the value maps to `GeomAbs_C0` through `GeomAbs_C3`, which is
/// parametric continuity, not geometric. The geometric vocabulary is ``SurfaceContinuity``.
@available(*, deprecated, renamed: "ParametricContinuity")
public typealias GeometricContinuity = ParametricContinuity

/// Former name for ``ParametricContinuity`` used by the approximation APIs.
@available(*, deprecated, renamed: "ParametricContinuity")
public typealias ApproxContinuity = ParametricContinuity

extension Shape {
    /// Former name for ``ParametricContinuity`` used by BSpline restriction.
    @available(*, deprecated, renamed: "ParametricContinuity")
    public typealias BSplineContinuity = ParametricContinuity
}

extension Curve3D {
    /// Former name for ``ParametricContinuity`` used by knot-splitting analysis.
    ///
    /// The old enum stopped at `c2`, which made every value it offered a no-op on an ordinary
    /// cubic BSpline: such a curve is already C2 at its interior knots, so nothing below C3
    /// reports a break. ``ParametricContinuity/c3`` is reachable and fixes that.
    @available(*, deprecated, renamed: "ParametricContinuity")
    public typealias ContinuityOrder = ParametricContinuity
}

// MARK: - Measured continuity class (a GeomAbs_Shape result)

/// The continuity OCCT *measured* on an existing curve or surface.
///
/// This is the one continuity vocabulary that reports rather than requests, and the only one
/// whose raw values are not a 0/1/2 order. They are `GeomAbs_Shape`'s own ordinals, which
/// interleave the geometric classes with the parametric ones:
///
/// | case | raw | meaning |
/// |------|-----|---------|
/// | ``c0`` | 0 | positional only |
/// | ``g1`` | 1 | tangent directions match, derivative magnitudes need not |
/// | ``c1`` | 2 | first derivatives match |
/// | ``g2`` | 3 | curvature matches |
/// | ``c2`` | 4 | second derivatives match |
/// | ``c3`` | 5 | third derivatives match |
/// | ``cN`` | 6 | infinitely differentiable |
///
/// ```swift
/// // A cubic BSpline with an interior knot at multiplicity 2 loses one derivative.
/// let bspline = Curve3D.bspline(poles: poles, knots: [0, 0.5, 1],
///                              multiplicities: [4, 2, 4], degree: 3)
/// print(bspline?.continuityClass)          // .c1
///
/// // Analytic geometry is infinitely smooth.
/// print(Curve3D.line(origin: .zero, direction: SIMD3(1, 0, 0))?.continuityClass)  // .cN
/// ```
///
/// - Note: Do not compare a raw value against ``ParametricContinuity`` or ``SurfaceContinuity``.
///   Those are request orders counting 0, 1, 2; these are `GeomAbs_Shape` ordinals where C1 is
///   2 and C2 is 4. Use ``satisfies(_:)`` for a continuity-floor check instead of comparing
///   raw values, which is the defect #485 was filed about.
public enum ContinuityClass: Int32, Sendable, CaseIterable {
    /// Positional continuity only (`GeomAbs_C0`).
    case c0 = 0
    /// Tangent continuity (`GeomAbs_G1`): tangent *directions* agree, magnitudes need not.
    case g1 = 1
    /// First-derivative continuity (`GeomAbs_C1`).
    case c1 = 2
    /// Curvature continuity (`GeomAbs_G2`).
    case g2 = 3
    /// Second-derivative continuity (`GeomAbs_C2`).
    case c2 = 4
    /// Third-derivative continuity (`GeomAbs_C3`).
    case c3 = 5
    /// Infinite continuity (`GeomAbs_CN`): every derivative exists. Analytic geometry.
    case cN = 6
}

extension ContinuityClass: Comparable {
    /// Ranks two *measured* classes by their place in `GeomAbs_Shape`'s ladder.
    ///
    /// `GeomAbs_Shape` declares its cases in ascending order of *how much smoothness is being
    /// claimed* (C0 < G1 < C1 < G2 < C2 < C3 < CN), so the raw values compare correctly and
    /// "is this measurement at least as strong a claim as that one" needs no lookup table.
    /// That is a property of the enum worth pinning rather than assuming.
    ///
    /// Read it as ranking claims, not as an implication chain. The ladder interleaves the
    /// geometric classes with the parametric ones, and a geometric class is a claim about a
    /// *reparametrisable* curve rather than about the parametrisation in hand, so outranking a
    /// class does not entail it: ``g2`` sorts above ``c1`` yet does not satisfy `.c1`, because
    /// curvature continuity says nothing about the first-derivative vectors.
    ///
    /// So `<`/`>=` compares two `ContinuityClass` values, and ``satisfies(_:)`` checks a
    /// ``ParametricContinuity`` floor — a different question, answered differently at that one
    /// pair. Never compare raw values across the two types, whose encodings differ
    /// (#485, #623).
    public static func < (lhs: ContinuityClass, rhs: ContinuityClass) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

extension ContinuityClass {
    /// Whether this class guarantees *parametric* continuity (a C-class), not merely geometric.
    ///
    /// ``g1`` and ``g2`` are false: they constrain tangent direction and curvature but not the
    /// derivative vectors themselves.
    ///
    /// ```swift
    /// ContinuityClass.c1.isParametric   // true
    /// ContinuityClass.g2.isParametric   // false — curvature matches, C2 does not follow
    /// ```
    ///
    /// - Important: `false` means "not a C-class", not "meets no floor at all" — the same
    ///   distinction ``derivativeOrder`` carries. A geometric class still meets the C0 floor,
    ///   so `guard measured.isParametric else { return false }` ahead of a `.c0` check reports
    ///   a tangent-continuous curve as not even connected, which is #623 exactly. Gate on
    ///   ``satisfies(_:)``; use this property to *describe* a class, not to gate on one.
    public var isParametric: Bool {
        switch self {
        case .c0, .c1, .c2, .c3, .cN: return true
        case .g1, .g2: return false
        }
    }

    /// The highest continuously-differentiable derivative order this class guarantees, if it
    /// guarantees a parametric one at all.
    ///
    /// `nil` for ``g1``/``g2``, which promise nothing about derivative *vectors*.
    /// ``cN`` reports `Int.max`.
    ///
    /// ```swift
    /// ContinuityClass.c2.derivativeOrder   // 2
    /// ContinuityClass.g2.derivativeOrder   // nil — curvature matches, C2 does not follow
    /// ```
    ///
    /// - Important: `nil` means "no *parametric* order", not "meets no floor at all". A
    ///   geometric class still meets the C0 floor, because OCCT's own modelling guide has
    ///   C0 "the same as G0" and G1/G2 entail G0. Prefer ``satisfies(_:)``, which encodes
    ///   that; a hand-rolled `guard let order = derivativeOrder else { return false }` reads
    ///   naturally and reproduces #623 exactly, reporting a tangent-continuous curve as not
    ///   even connected. Use this property to *report* an order, not to gate on one.
    public var derivativeOrder: Int? {
        switch self {
        case .c0: return 0
        case .c1: return 1
        case .c2: return 2
        case .c3: return 3
        case .cN: return Int.max
        case .g1, .g2: return nil
        }
    }

    /// Whether the measured continuity meets a required parametric floor.
    ///
    /// Use this instead of comparing raw values against ``ParametricContinuity``. The two
    /// encodings differ (`ContinuityClass.c1` is 2, `ParametricContinuity.c1` is 1), so a
    /// direct `>=` between the two types silently misreports.
    ///
    /// This asks a *parametric* question — "are the derivative vectors continuous up to order
    /// n?" — which is not the question ``<`` answers. `<` ranks two measured classes by their
    /// place in `GeomAbs_Shape`'s ladder; outranking a class in that ladder is not the same as
    /// entailing it, because the ladder interleaves the geometric classes with the parametric
    /// ones. The two answers differ at exactly one pair: ``g2`` sorts above ``c1`` (raw 3 > 2)
    /// yet guarantees nothing about first-derivative vectors, so `.g2.satisfies(.c1)` is
    /// `false` while `.g2 >= .c1` is `true`.
    ///
    /// Everywhere else they agree, ``ParametricContinuity/c0`` included: a geometric class
    /// *does* meet the C0 floor. G1 entails G0, and OCCT's own modelling guide states the rest
    /// outright — "C0 (*GeomAbs_C0*) - parametric continuity. It is the same as G0 (geometric
    /// continuity), so the last one is not represented by separate variable." There is no
    /// parametrisation subtlety at order zero: a curve is either connected or it is not.
    /// Reporting a tangent-continuous surface as failing `.c0` was the defect #623 was filed
    /// about.
    ///
    /// The same guide is why the G2/C1 exception above is a real distinction rather than an
    /// oversight: "Geometric continuity (G1, G2) means that the curve **can be reparametrized**
    /// to have parametric (C1, C2) continuity." The existence of such a reparametrisation is
    /// not a promise about the curve as it is actually parametrised, which is what a `.c1`
    /// floor asks. (Both quotations: `dox/user_guides/modeling_data/modeling_data.md`, lines
    /// 1281 and 1289 of the pinned OCCT source.)
    ///
    /// ```swift
    /// let measured = surface.continuityClass
    ///
    /// if measured.satisfies(.c2) {
    ///     // safe to ask for second derivatives across the whole surface
    /// }
    ///
    /// // A tangent-continuous surface is positionally continuous ...
    /// ContinuityClass.g1.satisfies(.c0)   // true
    /// // ... but promises nothing about the derivative vectors themselves.
    /// ContinuityClass.g1.satisfies(.c1)   // false
    /// ContinuityClass.g2.satisfies(.c1)   // false — even though .g2 > .c1 in the ladder
    /// ```
    public func satisfies(_ required: ParametricContinuity) -> Bool {
        // A geometric class has no `derivativeOrder`, but that is a floor of 0 rather than a
        // blanket failure: it promises nothing about derivative *vectors*, and promises
        // position, which is order 0. Anything above C0 is still correctly refused. (#623)
        (derivativeOrder ?? 0) >= Int(required.rawValue)
    }
}

extension ContinuityClass {
    /// The bit this class occupies in the bridge's junction-analysis bitmasks.
    ///
    /// The bridge numbers those bits by `GeomAbs_Shape` ordinal — bit 0 is C0, bit 1 is G1, and
    /// so on — which is this enum's own raw value, so the two need no lookup table between them.
    /// ``c3`` and ``cN`` have bits here for completeness; `LocalAnalysis_*` never sets them.
    var analysisFlagBit: Int { 1 << Int(rawValue) }

    /// Decode one of those bitmasks back into the classes it names.
    static func set(fromAnalysisMask mask: Int32) -> Set<ContinuityClass> {
        Set(allCases.filter { Int(mask) & $0.analysisFlagBit != 0 })
    }
}
