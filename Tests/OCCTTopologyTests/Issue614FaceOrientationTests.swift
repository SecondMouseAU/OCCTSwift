import Foundation
import Testing

@testable import OCCTSwift

// #614: `Shape.faces()` dropped a face's second orientation.
//
// #541/#502 converged every face accessor onto one enumeration, `TopExp::MapShapes`. That map
// compares with `TopoDS_Shape::IsSame`, "same TShape with the same Locations. Orientations may
// differ" (TopoDS_Shape.hxx:265-271), so a face occurring in one shape both FORWARD and REVERSED
// collapses to a single entry. `NCollection_IndexedMap::addImpl` returns the existing index and
// leaves the stored key untouched on a repeat (NCollection_IndexedMap.hxx:684-710), so the entry
// keeps whichever orientation was reached FIRST.
//
// That is right for an index and wrong for a normal: `OCCTFaceGetNormalAtUV` reverses the surface
// normal exactly when the face reads REVERSED, so a wall shared by two solids came back pointing
// out of one body and INTO the other.
//
// Measured on the pinned kernel (BRepAlgoAPI_Splitter, 10mm box cut by the z=4 plane):
// 12 face occurrences over 11 distinct faces. The shared wall is stored FORWARD, normal (0,0,1),
// dot +2.0 against the lower solid (outward) and −3.0 against the upper one (inward).
//
// The fix follows the split OCCT itself draws rather than inventing one:
//
//   * INDEX  → orientation-insensitive. `TopExp::MapShapes(S, T, M)` publishes no oriented
//     overload (TopExp.hxx:57-60), and BREP file persistence indexes sub-shapes through the same
//     IsSame map (TopTools_ShapeSet.hxx:192). `faces()` stays on it, so no index moves.
//   * NORMAL → orientation-sensitive, read off the TRAVERSAL. `BRepGProp::VolumeProperties`, where
//     a face's orientation sets the sign of the volume integral, takes it from `ex.Current()`
//     (BRepGProp.cxx:322-325) and, when deduplicating, keeps one IsSame map PER orientation
//     (`aFwdFMap`/`aRvsFMap`, BRepGProp.cxx:318-338) so a shared wall's two sides both survive.
//     `orientedFaces()` is that explorer walk.

@Suite("faces() keeps the index, orientedFaces() keeps the normal (#614)")
struct Issue614FaceOrientationTests {

    // MARK: - Fixture

    /// Two solids sharing one cut face, from one ordinary modelling operation.
    ///
    /// `split(by:)` hands the pieces back separately; re-compounding preserves the sharing,
    /// because both came out of the same BOP and reference the same cut face. Returns nil rather
    /// than recording an issue so callers can skip cleanly if the kernel stops sharing.
    static func splitBoxCompound() -> Shape? {
        guard let block = Shape.box(origin: .zero, width: 20, height: 10, depth: 10),
            let plate = Shape.face(from: Wire.rectangle(width: 60, height: 60)!),
            let upright = plate.rotated(axis: SIMD3(0, 1, 0), angle: .pi / 2),
            let knife = upright.translated(by: SIMD3(10, 0, 0)),
            let pieces = block.split(by: knife),
            pieces.count == 2,
            let compound = Shape.compound(pieces)
        else { return nil }
        return compound
    }

    // MARK: - Helpers

    /// The point and outward-reported normal at the middle of a face's trimmed UV range.
    ///
    /// `uvBounds` is `BRepTools::UVBounds`, so the midpoint lies on the face rather than at some
    /// untrimmed surface origin. `normal(atU:v:)` is what reverses on REVERSED, the whole point.
    static func centreAndNormal(_ face: Face) -> (point: SIMD3<Double>, normal: SIMD3<Double>)? {
        guard let uv = face.uvBounds else { return nil }
        let u = (uv.uMin + uv.uMax) / 2
        let v = (uv.vMin + uv.vMax) / 2
        guard let p = face.point(atU: u, v: v), let n = face.normal(atU: u, v: v) else {
            return nil
        }
        return (p, n)
    }

    /// A point strictly inside a solid: the average of its own face centres.
    ///
    /// Exact for the box halves this fixture makes, and needs no bounding-box API.
    static func interiorPoint(of solid: Shape) -> SIMD3<Double>? {
        var sum = SIMD3<Double>.zero
        var n = 0
        for face in solid.faces() {
            guard let c = centreAndNormal(face) else { continue }
            sum += c.point
            n += 1
        }
        guard n > 0 else { return nil }
        return sum / Double(n)
    }

    static func dot(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        a.x * b.x + a.y * b.y + a.z * b.z
    }

    // MARK: - The headline

    /// The two enumerations differ exactly by the shared wall's second occurrence.
    @Test("a split compound has one more face occurrence than it has distinct faces")
    func occurrenceCountExceedsDistinctCount() {
        guard let compound = Self.splitBoxCompound() else {
            Issue.record("could not build the split-box compound")
            return
        }

        let distinct = compound.faces()
        let occurrences = compound.orientedFaces()

        // 11 distinct faces: 5 outer walls per half, plus the one they share.
        #expect(distinct.count == 11)
        #expect(occurrences.count == 12)

        // faces() is still the indexing enumeration faceCount counts, #541 intact.
        #expect(distinct.count == compound.faceCount)

        // Every occurrence carries a face index that faces() can address.
        for face in occurrences {
            #expect(face.index >= 0)
            #expect(face.index < distinct.count)
        }
    }

    /// The defect itself: the shared wall must be able to face out of BOTH owners.
    @Test("the shared wall's normal points out of each owning solid")
    func sharedWallFacesOutOfBothSolids() {
        guard let compound = Self.splitBoxCompound() else {
            Issue.record("could not build the split-box compound")
            return
        }

        let occurrences = compound.orientedFaces()
        let byIndex = Dictionary(grouping: occurrences, by: \.index)

        // Exactly one face is shared, and it is shared by exactly two owners.
        let shared = byIndex.filter { $0.value.count > 1 }
        #expect(shared.count == 1)
        guard let sharedOccurrences = shared.first?.value else {
            Issue.record("no shared face in the split compound, fixture stopped sharing")
            return
        }
        #expect(sharedOccurrences.count == 2)

        // The two sides are opposite. Collapsed into one entry, this is what was lost.
        let orientations = Set(sharedOccurrences.map(\.orientation))
        #expect(orientations == Set([.forward, .reversed]))

        let solids = compound.solids
        #expect(solids.count == 2)

        // For each solid, some occurrence of the shared wall must point AWAY from that solid's
        // interior. Under the deduplicated walk only one entry survives, so one solid gets an
        // inward wall and this fails.
        for (i, solid) in solids.enumerated() {
            guard let inside = Self.interiorPoint(of: solid) else {
                Issue.record("no interior point for solid \(i)")
                continue
            }
            let outwardHits = sharedOccurrences.compactMap { face -> Double? in
                guard let c = Self.centreAndNormal(face) else { return nil }
                return Self.dot(c.normal, c.point - inside)
            }
            #expect(
                outwardHits.contains { $0 > 0 },
                "solid \(i): no occurrence of the shared wall faces outward (dots \(outwardHits))")
        }
    }

    /// The same assertion again, reaching the wall by GEOMETRY rather than by grouping on
    /// `Face.index`.
    ///
    /// The test above detects the collapse through the duplicate disappearing, which is a true
    /// symptom but an indirect one. This one locates the shared wall as the face both solids
    /// carry, a fact no enumeration choice can erase, and then asserts the thing #614 is
    /// actually about: that the compound-level walk offers, for each solid, a copy of that wall
    /// whose normal points out of it. Under the deduplicated walk the single surviving entry
    /// points out of one solid and into the other, so this fails on the normal itself.
    @Test("the shared wall, located geometrically, faces out of each solid")
    func sharedWallFacesOutwardLocatedByGeometry() {
        guard let compound = Self.splitBoxCompound() else {
            Issue.record("could not build the split-box compound")
            return
        }

        let solids = compound.solids
        guard solids.count == 2 else {
            Issue.record("expected two solids, got \(solids.count)")
            return
        }

        // The wall is the face centre both solids have in common.
        let centresA = solids[0].faces().compactMap { Self.centreAndNormal($0)?.point }
        let centresB = solids[1].faces().compactMap { Self.centreAndNormal($0)?.point }
        guard
            let wallCentre = centresA.first(where: { a in
                centresB.contains { b in Self.dot(a - b, a - b) < 1e-12 }
            })
        else {
            Issue.record("the two solids share no face centre, fixture stopped sharing")
            return
        }

        // Every compound-level occurrence sitting at that centre.
        let atWall = compound.orientedFaces().filter { face in
            guard let c = Self.centreAndNormal(face) else { return false }
            return Self.dot(c.point - wallCentre, c.point - wallCentre) < 1e-12
        }
        #expect(!atWall.isEmpty)

        for (i, solid) in solids.enumerated() {
            guard let inside = Self.interiorPoint(of: solid) else {
                Issue.record("no interior point for solid \(i)")
                continue
            }
            let dots = atWall.compactMap { face -> Double? in
                guard let c = Self.centreAndNormal(face) else { return nil }
                return Self.dot(c.normal, c.point - inside)
            }
            #expect(
                dots.contains { $0 > 0 },
                "solid \(i): no outward-facing copy of the shared wall (dots \(dots))")
        }
    }

    /// The same wall, enumerated from each solid on its own, already pointed outward, which is
    /// why this went unnoticed. Pins that so the compound-level fix cannot regress it.
    @Test("enumerated per solid, every face already points outward")
    func perSolidEnumerationIsOutward() {
        guard let compound = Self.splitBoxCompound() else {
            Issue.record("could not build the split-box compound")
            return
        }

        var checked = 0
        for (i, solid) in compound.solids.enumerated() {
            guard let inside = Self.interiorPoint(of: solid) else {
                Issue.record("no interior point for solid \(i)")
                continue
            }
            for face in solid.orientedFaces() {
                guard let c = Self.centreAndNormal(face) else { continue }
                #expect(
                    Self.dot(c.normal, c.point - inside) > 0,
                    "solid \(i) face \(face.index) points inward")
                checked += 1
            }
        }
        // Without this the loop passes vacuously if every centreAndNormal returns nil.
        #expect(checked == 12)
    }

    // MARK: - The unshared case is untouched

    /// On any shape that shares no face the two enumerations must agree entry for entry, so
    /// nothing about the ordinary case changed.
    @Test("with no shared face the two enumerations are identical")
    func enumerationsAgreeWhenNothingIsShared() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("could not build the box")
            return
        }

        let distinct = box.faces()
        let occurrences = box.orientedFaces()

        #expect(distinct.count == 6)
        #expect(occurrences.count == distinct.count)
        #expect(occurrences.map(\.index) == distinct.map(\.index))
        #expect(occurrences.map(\.orientation) == distinct.map(\.orientation))
    }

    /// A plain box's faces all point outward under both enumerations, the everyday contract the
    /// CAM helpers (`upwardFaces`, `horizontalFaces`) depend on.
    @Test("a plain box faces outward under both enumerations")
    func plainBoxFacesOutward() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let inside = Self.interiorPoint(of: box)
        else {
            Issue.record("could not build the box")
            return
        }

        var checked = 0
        for face in box.faces() {
            guard let c = Self.centreAndNormal(face) else { continue }
            #expect(Self.dot(c.normal, c.point - inside) > 0, "faces(): face \(face.index) inward")
            checked += 1
        }
        for face in box.orientedFaces() {
            guard let c = Self.centreAndNormal(face) else { continue }
            #expect(
                Self.dot(c.normal, c.point - inside) > 0,
                "orientedFaces(): face \(face.index) inward")
            checked += 1
        }
        // Without this the loops pass vacuously if every centreAndNormal returns nil.
        #expect(checked == 12)
    }

    // MARK: - #614's stated failure scenario, through the public CAM helpers

    /// The failure the issue actually describes: "any per-face area or normal accumulation
    /// silently loses a facet."
    ///
    /// `horizontalFaces()` selects on the face normal, so it is a geometry consumer. Filtering
    /// `faces()` found the shared wall only from the side that happened to be stored, so the upper
    /// solid's floor was simply absent: 3 entries where the geometry has 4 horizontal occurrences.
    @Test("horizontalFaces() keeps both sides of a shared horizontal wall")
    func horizontalFacesKeepsBothSidesOfSharedWall() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let halves = box.split(atPlane: SIMD3(0, 0, 4), normal: SIMD3(0, 0, 1)),
            let compound = Shape.compound(halves)
        else {
            Issue.record("could not build the z=4 split compound")
            return
        }

        let horizontal = compound.horizontalFaces()

        // Outer top, outer bottom, and the shared wall once per owning solid.
        #expect(horizontal.count == 4)

        // Exactly one face index appears twice: the shared wall, once per side.
        let counts = Dictionary(grouping: horizontal, by: \.index).mapValues(\.count)
        #expect(counts.values.filter { $0 > 1 }.count == 1)
        guard let sharedIndex = counts.first(where: { $0.value == 2 })?.key else {
            Issue.record("no horizontal face appears twice, the shared wall was dropped")
            return
        }
        let sides = horizontal.filter { $0.index == sharedIndex }
        #expect(Set(sides.map(\.orientation)) == Set([.forward, .reversed]))

        // And each side faces out of a different solid.
        var solidsCovered = 0
        for solid in compound.solids {
            guard let inside = Self.interiorPoint(of: solid) else { continue }
            let outward = sides.contains { face in
                guard let c = Self.centreAndNormal(face) else { return false }
                return Self.dot(c.normal, c.point - inside) > 0
            }
            #expect(outward, "no side of the shared wall faces out of this solid")
            solidsCovered += 1
        }
        #expect(solidsCovered == 2)
    }

    /// `facesByZLevel()` is documented "for CAM pocket detection", and inherits the same walk.
    @Test("facesByZLevel() reports the shared level once per owning solid")
    func facesByZLevelCountsBothSides() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let halves = box.split(atPlane: SIMD3(0, 0, 4), normal: SIMD3(0, 0, 1)),
            let compound = Shape.compound(halves)
        else {
            Issue.record("could not build the z=4 split compound")
            return
        }

        let levels = compound.facesByZLevel()
        guard let atCut = levels.first(where: { abs($0.key - 4.0) < 1e-6 })?.value else {
            Issue.record("no horizontal faces at the z=4 cut; levels \(levels.keys.sorted())")
            return
        }
        // Both the lower solid's ceiling and the upper solid's floor.
        #expect(atCut.count == 2)
        #expect(Set(atCut.map(\.orientation)) == Set([.forward, .reversed]))
    }

    /// On a shared *wall*, two solids whose parents impose opposite orientations, at most one
    /// side can face up, because the two normals are opposed.
    ///
    /// This is a property of opposed normals, NOT a guarantee of `upwardFaces()`. The two tests
    /// below pin the cases where it does not hold; an earlier draft of this PR documented the
    /// "can never repeat an index" reading as an absolute, and it is false.
    @Test("across a shared wall, only one side faces up")
    func upwardFacesOnSharedWallTakesOneSide() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let halves = box.split(atPlane: SIMD3(0, 0, 4), normal: SIMD3(0, 0, 1)),
            let compound = Shape.compound(halves)
        else {
            Issue.record("could not build the z=4 split compound")
            return
        }

        let upward = compound.upwardFaces()
        #expect(upward.count == Set(upward.map(\.index)).count)
        // The outer top, plus the shared wall as the lower solid's ceiling.
        #expect(upward.count == 2)
        #expect(upward.allSatisfy { $0.orientation == .forward })

        // horizontalFaces() sees the same wall from both sides, so it DOES repeat an index.
        let horizontal = compound.horizontalFaces()
        #expect(horizontal.count > Set(horizontal.map(\.index)).count)
    }

    /// Counterexample 1: repeats reached through parents imposing the SAME orientation.
    ///
    /// A shape compounded with itself reaches every face twice, both times forward, so nothing is
    /// opposed and every predicate admits both entries. `upwardFaces()` repeats an index here.
    @Test("a shape compounded with itself repeats an index in upwardFaces()")
    func upwardFacesRepeatsWhenOrientationsAgree() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let doubled = Shape.compound([box, box])
        else {
            Issue.record("could not build the doubled compound")
            return
        }

        // Six distinct faces, twelve occurrences, each pair sharing an orientation.
        #expect(doubled.faces().count == 6)
        let occurrences = doubled.orientedFaces()
        #expect(occurrences.count == 12)
        for (_, group) in Dictionary(grouping: occurrences, by: \.index) {
            #expect(group.count == 2)
            #expect(Set(group.map(\.orientation)).count == 1)
        }

        // So the "opposed normals" reasoning does not apply, and the index repeats.
        let upward = doubled.upwardFaces()
        #expect(upward.count == 2)
        #expect(Set(upward.map(\.index)).count == 1)
    }

    /// Counterexample 2: `isUpwardFacing` is `n.z > cos(tolerance)`, so a tolerance of π/2 or more
    /// makes the threshold non-positive and admits faces that do not point up at all, including
    /// both sides of a *vertical* shared wall, whose normals have `n.z == 0`.
    @Test("a tolerance past pi/2 admits both sides of a vertical shared wall")
    func upwardFacesRepeatsAtDegenerateTolerance() {
        guard let compound = Self.splitBoxCompound() else {
            Issue.record("could not build the split-box compound")
            return
        }

        // The fixture's shared wall is vertical, so at the default tolerance it is not upward.
        let strict = compound.upwardFaces()
        #expect(strict.count == Set(strict.map(\.index)).count)

        // cos(1.6) is negative, so every face with n.z > -0.0292 qualifies.
        #expect(cos(1.6) < 0)
        let loose = compound.upwardFaces(tolerance: 1.6)
        #expect(loose.count == 10)
        #expect(Set(loose.map(\.index)).count == 9)
        #expect(loose.count > Set(loose.map(\.index)).count)
    }

    // MARK: - Orientation is reportable

    /// `Face.orientation` is the flag the normal reverses on, so a caller can tell the two sides
    /// of a shared wall apart without re-deriving them.
    @Test("Face.orientation reports the flag the normal reverses on")
    func orientationMatchesNormalFlip() {
        guard let compound = Self.splitBoxCompound() else {
            Issue.record("could not build the split-box compound")
            return
        }

        let shared = Dictionary(grouping: compound.orientedFaces(), by: \.index)
            .filter { $0.value.count > 1 }
        guard let sides = shared.first?.value, sides.count == 2 else {
            Issue.record("expected exactly one face shared by two owners")
            return
        }

        guard let a = Self.centreAndNormal(sides[0]), let b = Self.centreAndNormal(sides[1]) else {
            Issue.record("could not evaluate the shared wall's normals")
            return
        }

        // Same face, so the same point; opposite orientation, so opposed normals.
        #expect(sides[0].orientation != sides[1].orientation)
        #expect(Self.dot(a.normal, b.normal) < -0.99)
    }
}
