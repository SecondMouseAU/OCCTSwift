import Testing
import Foundation
@testable import OCCTSwift

/// #496, the two hole-drilling families and where their contracts actually part.
///
/// The audit read `Shape.drilled(at:direction:radius:depth:)` (a `BRepAlgoAPI_Cut` against a
/// `BRepPrimAPI_MakeCylinder` tool) as a cruder reimplementation of the `BRepFeat_MakeCylindricalHole`
/// family, and proposed folding the first into the second. Probing both against the pinned kernel
/// (`Scripts/repro/496-drill-hole-contracts/`) shows that would not be a refactor: the two answer
/// different questions, and six of thirteen probed cases change answer.
///
/// These tests pin the divergences that a future "just delegate one to the other" would break, and
/// the misreports inside the feature family that #496's fix repairs.
@Suite("Issue496 cylindrical hole contracts")
struct Issue496CylindricalHoleTests {

    // 50 x 50 x 20, centred on the origin: X[-25,25] Y[-25,25] Z[-10,10].
    private func plate() -> Shape? { Shape.box(width: 50, height: 50, depth: 20) }

    private static let holeVolume = Double.pi * 25 * 20   // r=5 through 20mm of stock

    // MARK: - Divergences that block a delegation

    /// A blind depth longer than the stock is a through hole to the boolean path and a hard
    /// failure to `PerformBlind`, which is the only OCCT mode that reports `HoleTooLong`.
    ///
    /// This is the single most likely caller idiom to break under a delegation: "pass a depth
    /// comfortably past the far face" is how people drill through without computing the thickness.
    @Test("A blind depth past the far face drills through, but PerformBlind rejects it")
    func blindDepthBeyondTheStock() {
        guard let box = plate() else { #expect(Bool(false), "box"); return }
        let origin = SIMD3<Double>(0, 0, 11)
        let axis = SIMD3<Double>(0, 0, -1)

        // Boolean path: the cylinder simply overshoots, and the cut is a clean through hole.
        let drilled = box.drilled(at: origin, direction: axis, radius: 5, depth: 100)
        #expect(drilled != nil)
        if let d = drilled, let v = d.volume, let v0 = box.volume {
            #expect(abs((v0 - v) - Self.holeVolume) < 1.0)
        }

        // Feature path: BRepFeat_HoleTooLong, surfaced as nil.
        #expect(box.cylindricalHoleBlind(axisOrigin: origin, axisDirection: axis,
                                         radius: 5, depth: 100) == nil)
    }

    /// `Perform` cuts an *infinite* cylinder, the axis origin is an anchor, not a starting point.
    /// The boolean path's cylinder starts at the position it was given. With the entry point inside
    /// the stock the two disagree by exactly the material behind the origin.
    @Test("Through-all ignores the axis origin; the boolean drill starts there")
    func throughAllIgnoresTheAxisOrigin() {
        guard let box = plate(), let v0 = box.volume else { #expect(Bool(false), "box"); return }
        let origin = SIMD3<Double>(0, 0, 0)      // the plate's own midplane
        let axis = SIMD3<Double>(0, 0, -1)

        // Boolean: removes only the 10mm below the origin.
        if let d = box.drilled(at: origin, direction: axis, radius: 5, depth: 0), let v = d.volume {
            #expect(abs((v0 - v) - Self.holeVolume / 2) < 1.0)
        } else {
            #expect(Bool(false), "boolean drill failed")
        }

        // Feature: removes all 20mm, in both directions from the origin.
        if let d = box.cylindricalHole(axisOrigin: origin, axisDirection: axis, radius: 5),
           let v = d.volume {
            #expect(abs((v0 - v) - Self.holeVolume) < 1.0)
        } else {
            #expect(Bool(false), "cylindricalHole failed")
        }
    }

    /// `BRepFeat_MakeCylindricalHole` is a local operation on a solid. The boolean path has no such
    /// requirement, and drilling a shell is a real thing callers do to sheet stock.
    @Test("A shell can be drilled by the boolean path, not by the thru-next feature")
    func shellInputIsBooleanOnly() {
        guard let box = plate() else { #expect(Bool(false), "box"); return }
        guard let shell = box.subShapes(ofType: .shell).first else {
            #expect(Bool(false), "no shell"); return
        }
        let origin = SIMD3<Double>(0, 0, 15)
        let axis = SIMD3<Double>(0, 0, -1)

        #expect(box.drilled(at: origin, direction: axis, radius: 5, depth: 0) != nil)
        #expect(shell.drilled(at: origin, direction: axis, radius: 5, depth: 0) != nil)
        #expect(shell.cylindricalHoleThruNext(axisOrigin: origin, axisDirection: axis,
                                              radius: 5) == nil)
    }

    // MARK: - Misreports inside the feature family

    /// A radius that swallows the whole solid is one answer for the whole family: the bore consumes
    /// the stock and the result is empty.
    ///
    /// This used to be the #496 divergence "through-all status is a false green for the thru-next
    /// drill", `Perform` tolerated the request while `PerformThruNext` called it
    /// `InvalidPlacement`. That refusal was an artefact of the #532 defect, not a contract:
    /// under `BOPAlgo_CUT` an oversized tool emptied the builder's shape, so `nbparts` was 0 and the
    /// "the tool meets nothing" guard fired. Driving the builder correctly (carried patch `0020`)
    /// makes `nbparts` 1, the tool meets the whole solid, and the two extents now return the empty
    /// result `.throughAll` and ``Shape/drilled(at:direction:radius:depth:)`` always returned.
    @Test("A radius that swallows the solid empties it, for every spelling")
    func oversizedRadiusEmptiesTheSolid() {
        guard let box = plate() else { #expect(Bool(false), "box"); return }
        let origin = SIMD3<Double>(0, 0, 15)
        let axis = SIMD3<Double>(0, 0, -1)
        let radius = 100.0   // wider than the 50mm plate

        // The boolean drill has always answered this way.
        if let d = box.drilled(at: origin, direction: axis, radius: radius, depth: 0) {
            #expect(d.subShapes(ofType: .solid).isEmpty)
        } else { #expect(Bool(false), "boolean drill failed") }

        for extent: Shape.CylindricalHoleExtent in [.throughAll, .untilEnd, .thruNext] {
            #expect(box.cylindricalHoleStatus(axisOrigin: origin, axisDirection: axis,
                                              radius: radius, extent: extent) == .noError,
                    "\(extent) refused an oversized radius")
            if let d = box.cylindricalHole(axisOrigin: origin, axisDirection: axis,
                                           radius: radius, extent: extent) {
                #expect(d.subShapes(ofType: .solid).isEmpty, "\(extent) left material behind")
            } else {
                #expect(Bool(false), "\(extent) failed outright")
            }
        }
    }

    /// `BRepFeat_HoleTooLong` is written in exactly two places in the kernel
    /// (`BRepFeat_MakeCylindricalHole.cxx:526` and `:667`), both reachable only through
    /// `PerformBlind`. The status query wraps `Perform`, so `.holeTooLong` could not be observed
    /// through any public spelling, the case existed in the Swift enum and nothing could produce it.
    @Test("The blind-hole extent is the only way to observe .holeTooLong")
    func holeTooLongIsReachable() {
        guard let box = plate() else { #expect(Bool(false), "box"); return }
        let origin = SIMD3<Double>(0, 0, 11)
        let axis = SIMD3<Double>(0, 0, -1)

        // The through-all query cannot see it, and says so cheerfully.
        #expect(box.cylindricalHoleStatus(axisOrigin: origin, axisDirection: axis,
                                          radius: 5) == .noError)

        // Asked about the extent actually being drilled, it reports the real reason.
        #expect(box.cylindricalHoleStatus(axisOrigin: origin, axisDirection: axis,
                                          radius: 5, extent: .blind(depth: 100)) == .holeTooLong)
        #expect(box.cylindricalHoleStatus(axisOrigin: origin, axisDirection: axis,
                                          radius: 5, extent: .blind(depth: 11)) == .noError)
    }

    /// A status that disagrees with the drill it describes is the defect above. Every extent must
    /// now agree with its own drill on the same request.
    @Test("Every extent's status agrees with that extent's drill")
    func statusAgreesWithItsOwnDrill() {
        guard let box = plate() else { #expect(Bool(false), "box"); return }
        let axis = SIMD3<Double>(0, 0, -1)

        let requests: [(String, SIMD3<Double>, Double, Shape.CylindricalHoleExtent)] = [
            ("through-all, fits",   SIMD3(0, 0, 15),     5,   .throughAll),
            ("until-end, fits",     SIMD3(0, 0, 15),     5,   .untilEnd),
            ("thru-next, fits",     SIMD3(0, 0, 15),     5,   .thruNext),
            ("blind, fits",         SIMD3(0, 0, 11),     5,   .blind(depth: 11)),
            ("blind, too long",     SIMD3(0, 0, 11),     5,   .blind(depth: 100)),
            ("range, fits",         SIMD3(0, 0, 15),     5,   .range(from: 0, to: 100)),
            ("misses the solid",    SIMD3(100, 100, 15), 5,   .untilEnd),
            ("radius swallows all", SIMD3(0, 0, 15),     100, .untilEnd),
        ]

        for (label, origin, radius, extent) in requests {
            let status = box.cylindricalHoleStatus(axisOrigin: origin, axisDirection: axis,
                                                   radius: radius, extent: extent)
            let drilled = box.cylindricalHole(axisOrigin: origin, axisDirection: axis,
                                              radius: radius, extent: extent)
            #expect((status == .noError) == (drilled != nil),
                    "\(label): status \(status) but drill \(drilled == nil ? "failed" : "succeeded")")
        }
    }

    /// `statusAgreesWithItsOwnDrill` above only checks "comfortably fits" and "comfortably too
    /// long" `.blind` depths. The two `HoleTooLong` checks are independent computations,
    /// `PerformBlind`'s own a priori check (`BRepFeat_MakeCylindricalHole.cxx:526`) compares
    /// `LocOpe_CurveShapeIntersector`'s parametric intersection distance against the requested
    /// depth, *before* any cut is made; `Validate()`'s post-hoc check (`:667`) inspects whether the
    /// tool's own top face survives as a face of the actual `BOPAlgo_BOP`-produced result,
    /// *after* the cut. The status query (`occtBRepFeatCylindricalHole` with `outShape == nullptr`)
    /// returns before `Build()` ever runs, so it can only ever observe the first of the two, if
    /// they disagreed right at the exit face, `cylindricalHoleStatus` could report `.noError` for a
    /// depth that `cylindricalHole(...)` then refuses, breaking the "if and only if" its own doc
    /// comment promises.
    ///
    /// The plate's exit face along this axis sits at exactly `depth == 21` (origin z=11, bottom
    /// face z=-10), so this sweeps depths tight around that single point, the only place such a
    /// disagreement could show up.
    @Test("Status and drill agree at the exact HoleTooLong boundary")
    func statusAgreesWithDrillAtTheHoleTooLongBoundary() {
        guard let box = plate() else { #expect(Bool(false), "box"); return }
        let origin = SIMD3<Double>(0, 0, 11)
        let axis = SIMD3<Double>(0, 0, -1)
        let exitDepth = 21.0   // origin z=11, bottom face z=-10: exactly the exit face

        for depth in [exitDepth - 1e-3, exitDepth - 1e-6, exitDepth - 1e-9,
                      exitDepth, exitDepth + 1e-9, exitDepth + 1e-6, exitDepth + 1e-3] {
            let extent = Shape.CylindricalHoleExtent.blind(depth: depth)
            let status = box.cylindricalHoleStatus(axisOrigin: origin, axisDirection: axis,
                                                    radius: 5, extent: extent)
            let drilled = box.cylindricalHole(axisOrigin: origin, axisDirection: axis,
                                              radius: 5, extent: extent)
            #expect((status == .noError) == (drilled != nil),
                    "depth \(depth): status \(status) but drill \(drilled == nil ? "failed" : "succeeded")")
        }
    }

    // MARK: - The shared direction precondition

    /// Both families reject a zero-length direction. The boolean path always did, by an explicit
    /// guard; the feature family used to reach `gp_Dir`, throw `Standard_ConstructionError`, and
    /// swallow it in its own `catch (...)`. Same answer, reached by an accident that a future
    /// narrowing of that catch would have removed. Both now share one precondition.
    @Test("A zero-length direction is rejected by every drilling spelling")
    func zeroDirectionRejectedEverywhere() {
        guard let box = plate() else { #expect(Bool(false), "box"); return }
        let origin = SIMD3<Double>(0, 0, 15)
        let zero = SIMD3<Double>(0, 0, 0)

        #expect(box.drilled(at: origin, direction: zero, radius: 5, depth: 0) == nil)
        #expect(box.cylindricalHole(axisOrigin: origin, axisDirection: zero, radius: 5) == nil)
        #expect(box.cylindricalHoleBlind(axisOrigin: origin, axisDirection: zero,
                                         radius: 5, depth: 5) == nil)
        #expect(box.cylindricalHoleThruNext(axisOrigin: origin, axisDirection: zero,
                                            radius: 5) == nil)
        for extent: Shape.CylindricalHoleExtent in [.throughAll, .untilEnd, .thruNext,
                                              .blind(depth: 5), .range(from: 0, to: 10)] {
            #expect(box.cylindricalHole(axisOrigin: origin, axisDirection: zero,
                                        radius: 5, extent: extent) == nil)
            #expect(box.cylindricalHoleStatus(axisOrigin: origin, axisDirection: zero,
                                              radius: 5, extent: extent) == .invalidPlacement)
        }
    }

    /// A radius OCCT cannot build a cylinder from is not a drillable request. The kernel is a
    /// Release build, so its own `*_Raise_if` preconditions are compiled out (see #487) and nothing
    /// below the bridge rejects this for us.
    ///
    /// The sub-`Precision::Confusion` cases are the ones that used to escape. `radius > 0` let them
    /// through, and every `BRepFeat_MakeCylindricalHole` mode then returned `BRepFeat_NoError` and a
    /// shape identical to the input, same volume, same six faces, no material removed. A drill that
    /// reports success and removes nothing is worse than one that fails.
    @Test("A radius at or below Precision.Confusion is rejected by every drilling spelling")
    func degenerateRadiusRejectedEverywhere() {
        guard let box = plate(), let v0 = box.volume else { #expect(Bool(false), "box"); return }
        let origin = SIMD3<Double>(0, 0, 15)
        let axis = SIMD3<Double>(0, 0, -1)

        for radius in [-5.0, 0.0, 1e-14, 1e-8, 1e-7] {
            #expect(box.drilled(at: origin, direction: axis, radius: radius, depth: 0) == nil,
                    "drilled accepted radius \(radius)")
            #expect(box.cylindricalHoleStatus(axisOrigin: origin, axisDirection: axis,
                                              radius: radius) == .invalidPlacement,
                    "status accepted radius \(radius)")
            for extent: Shape.CylindricalHoleExtent in [.throughAll, .untilEnd, .thruNext,
                                                        .blind(depth: 5)] {
                #expect(box.cylindricalHole(axisOrigin: origin, axisDirection: axis,
                                            radius: radius, extent: extent) == nil,
                        "\(extent) accepted radius \(radius)")
            }
        }

        // Just above the threshold still drills, and removes a real (if tiny) amount.
        let r = 1e-6
        if let d = box.cylindricalHole(axisOrigin: origin, axisDirection: axis,
                                       radius: r, extent: .untilEnd), let v = d.volume {
            #expect(abs((v0 - v) - Double.pi * r * r * 20) < 1e-9)
        } else {
            #expect(Bool(false), "a radius just above Confusion should still drill")
        }
    }

    // MARK: - The two newly wrapped extents

    /// `PerformUntilEnd` was the mode the audit assumed `Perform` was, bounded by the stock rather
    /// than infinite. It was not wrapped, so the family had no forward-bounded through spelling.
    @Test("untilEnd drills the stock, bounded by the entry and exit faces")
    func untilEndDrillsTheStock() {
        guard let box = plate(), let v0 = box.volume else { #expect(Bool(false), "box"); return }
        guard let d = box.cylindricalHole(axisOrigin: SIMD3(0, 0, 15),
                                          axisDirection: SIMD3(0, 0, -1),
                                          radius: 5, extent: .untilEnd),
              let v = d.volume else {
            #expect(Bool(false), "untilEnd failed"); return
        }
        #expect(abs((v0 - v) - Self.holeVolume) < 1.0)
        #expect(d.isValid)
    }

    /// Two plates stacked on the drill axis, separated by a gap. Origin (0,0,15) along -Z puts
    /// plate A at axis parameters 5...25 and plate B at 45...65.
    private func stack() -> Shape? {
        guard let a = Shape.box(width: 50, height: 50, depth: 20),
              let b = Shape.box(width: 50, height: 50, depth: 20)?.translated(by: SIMD3(0, 0, -40))
        else { return nil }
        return Shape.compound([a, b])
    }

    /// The ranged `Perform(Radius, PFrom, PTo)` overload does not cut *between* its two parameters.
    /// Measured: the window selects which entry/exit **face pair** along the axis bounds the hole,
    /// and the hole then spans that whole pair. A window wholly inside one plate still drills all of
    /// it; a window covering only the gap between two plates is `InvalidPlacement`.
    ///
    /// This is what makes the extent worth having: on a stack it is the only spelling that picks
    /// *which* body to drill.
    @Test("range selects a face pair on the axis, not a cut window")
    func rangeSelectsAFacePair() {
        guard let stack = stack(), let v0 = stack.volume else { #expect(Bool(false), "stack"); return }
        let origin = SIMD3<Double>(0, 0, 15)
        let axis = SIMD3<Double>(0, 0, -1)

        func removed(from: Double, to: Double) -> Double? {
            guard let d = stack.cylindricalHole(axisOrigin: origin, axisDirection: axis,
                                                radius: 5, extent: .range(from: from, to: to)),
                  let v = d.volume else { return nil }
            return v0 - v
        }

        // A window over the first plate drills exactly that plate.
        if let r = removed(from: 0, to: 30) { #expect(abs(r - Self.holeVolume) < 1.0) }
        else { #expect(Bool(false), "range over plate A failed") }

        // A window over the second plate drills exactly that plate, the same bore, elsewhere.
        if let r = removed(from: 30, to: 70) { #expect(abs(r - Self.holeVolume) < 1.0) }
        else { #expect(Bool(false), "range over plate B failed") }

        // A window strictly inside plate A still drills all of plate A: the parameters chose the
        // face pair, they did not trim the cut.
        if let r = removed(from: 10, to: 20) { #expect(abs(r - Self.holeVolume) < 1.0) }
        else { #expect(Bool(false), "range inside plate A failed") }

        // A window covering only the gap names no face pair at all.
        #expect(stack.cylindricalHoleStatus(axisOrigin: origin, axisDirection: axis, radius: 5,
                                            extent: .range(from: 26, to: 44)) == .invalidPlacement)
    }

    /// Every spelling that claims to bound the hole by the stock's own faces removes the same
    /// material from a stack as the boolean drill does. This was #532: `PerformUntilEnd`, the ranged
    /// `Perform` and `PerformBlind` selected from the *cut result* rather than the split tool, kept
    /// pieces that were not tool parts at all, and returned the input with the cylinder's faces
    /// imprinted on it while reporting `BRepFeat_NoError`. Fixed by carried patch `0020`; see
    /// `Issue532CylindricalHolePartSelectionTests` for the full contract.
    @Test("Every stack-spanning extent removes what the boolean drill removes")
    func multiBodyExtentsDrillEveryBody() {
        guard let stack = stack(), let v0 = stack.volume else { #expect(Bool(false), "stack"); return }
        let origin = SIMD3<Double>(0, 0, 15)
        let axis = SIMD3<Double>(0, 0, -1)

        for extent: Shape.CylindricalHoleExtent in [.throughAll, .untilEnd, .range(from: 0, to: 70)] {
            #expect(stack.cylindricalHoleStatus(axisOrigin: origin, axisDirection: axis,
                                                radius: 5, extent: extent) == .noError)
            if let d = stack.cylindricalHole(axisOrigin: origin, axisDirection: axis,
                                             radius: 5, extent: extent), let v = d.volume {
                #expect(abs((v0 - v) - 2 * Self.holeVolume) < 1.0,
                        "\(extent) removed \(v0 - v), expected \(2 * Self.holeVolume)")
                #expect(d.isValid)
            } else {
                #expect(Bool(false), "\(extent) failed outright")
            }
        }

        if let d = stack.drilled(at: origin, direction: axis, radius: 5, depth: 0),
           let v = d.volume {
            #expect(abs((v0 - v) - 2 * Self.holeVolume) < 1.0)
        } else { #expect(Bool(false), "boolean drill failed") }
    }

    // MARK: - The convenience spellings still mean what they meant

    /// The four v0.71.0 methods are now three-line forwards onto the extent-carrying spelling.
    /// Each must still produce exactly the shape it produced before.
    @Test("The v0.71.0 spellings agree with their extents")
    func legacySpellingsAgreeWithTheirExtents() {
        guard let box = plate() else { #expect(Bool(false), "box"); return }
        let origin = SIMD3<Double>(0, 0, 15)
        let axis = SIMD3<Double>(0, 0, -1)

        let pairs: [(Shape?, Shape?)] = [
            (box.cylindricalHole(axisOrigin: origin, axisDirection: axis, radius: 5),
             box.cylindricalHole(axisOrigin: origin, axisDirection: axis, radius: 5,
                                 extent: .throughAll)),
            (box.cylindricalHoleThruNext(axisOrigin: origin, axisDirection: axis, radius: 5),
             box.cylindricalHole(axisOrigin: origin, axisDirection: axis, radius: 5,
                                 extent: .thruNext)),
            (box.cylindricalHoleBlind(axisOrigin: origin, axisDirection: axis, radius: 5, depth: 20),
             box.cylindricalHole(axisOrigin: origin, axisDirection: axis, radius: 5,
                                 extent: .blind(depth: 20))),
        ]

        for (legacy, unified) in pairs {
            #expect(legacy != nil)
            #expect(unified != nil)
            if let l = legacy, let u = unified, let lv = l.volume, let uv = u.volume {
                #expect(abs(lv - uv) < 1e-6)
            }
        }

        #expect(box.cylindricalHoleStatus(axisOrigin: origin, axisDirection: axis, radius: 5)
                == box.cylindricalHoleStatus(axisOrigin: origin, axisDirection: axis, radius: 5,
                                             extent: .throughAll))
    }
}
