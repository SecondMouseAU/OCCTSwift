import simd

// Deterministic perpendicular-to-a-direction basis, matching OCCT's own `gp_Ax2(gp_Pnt, gp_Dir)`
// canonical algorithm. Module-wide: shared by `Placement.init(origin:normal:)` and
// `ConstructionPlane.throughAxis` (`ConstructionEntity.swift`), `Shape.sectionPlaneBasis`
// (`Section2D.swift`), and `Drawing`'s axis/point projection helpers
// (`DrawingAutoCenterlines.swift`) — three of those five call sites are not drawing code, which is
// why this lives in its own file rather than the drawing-specific one it used to (#914 review,
// second round, finding on `DrawingAutoCenterlines.swift`; the same misplacement finding 11
// fixed for `unwrapAxisComponents`/`unwrapVectorComponents`/`unwrapVectorComponentsIfSuccessful`,
// moved to `SIMD3Unpacking.swift` in that round — this one gets its own file rather than joining
// them there, since it isn't a bridge-unpack helper).

/// Deterministic perpendicular basis for `direction`, matching OCCT's own `gp_Ax2(gp_Pnt,
/// gp_Dir)` algorithm: no magnitude threshold, no fallback branch (#881).
///
/// Picks whichever of `direction`'s components has the smallest magnitude and derives the
/// perpendicular algebraically from it, so it never needs a fallback the way a
/// `cross(worldUp, direction)` construction does. Shared by every OCCTSwift site that needs a
/// stable basis perpendicular to one direction.
///
/// - Returns: `(right, up)`, unit vectors with `direction` forming a right-handed
///   basis: `up == cross(direction, right)`. Unlabeled — every call site already destructures
///   positionally (`let (a, b) = perpendicularBasis(to:)`), and an internal function returning a
///   tuple with baked-in labels forces a call site whose own labels differ into a two-step
///   bind-then-relabel instead of a direct return (`okf/policies/code-style.md`; #914 review,
///   second round).
internal func perpendicularBasis(to direction: SIMD3<Double>) -> (
    SIMD3<Double>, SIMD3<Double>
) {
    let v = simd_normalize(direction)
    let aAbs = abs(v.x)
    let bAbs = abs(v.y)
    let cAbs = abs(v.z)
    let raw: SIMD3<Double>
    if bAbs <= aAbs && bAbs <= cAbs {
        raw = aAbs > cAbs ? SIMD3(-v.z, 0, v.x) : SIMD3(v.z, 0, -v.x)
    } else if aAbs <= bAbs && aAbs <= cAbs {
        raw = bAbs > cAbs ? SIMD3(0, -v.z, v.y) : SIMD3(0, v.z, -v.y)
    } else {
        raw = aAbs > bAbs ? SIMD3(-v.y, v.x, 0) : SIMD3(v.y, -v.x, 0)
    }
    let right = simd_normalize(raw)
    let up = simd_normalize(simd_cross(v, right))
    return (right, up)
}
