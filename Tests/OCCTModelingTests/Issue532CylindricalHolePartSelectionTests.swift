import Testing
import Foundation
@testable import OCCTSwift

/// #532, `BRepFeat_MakeCylindricalHole` selected parts of the **cut result**, not parts of the tool.
///
/// Every mode that chooses which piece of the drilling tool to keep, `PerformThruNext`,
/// `PerformUntilEnd`, the ranged `Perform(Radius, PFrom, PTo)` and `PerformBlind`, drove
/// `BRepFeat_Builder` with `SetOperation(Fuse)`, i.e. `BOPAlgo_CUT`, before calling `PartsOfTool()`.
/// That method collects the solids of the builder's shape, which only holds the tool split by the
/// object after the **COMMON** pass; after a CUT it is the finished workpiece. So the selection loops
/// compared barycentres of bored plates and then registered those plates as "kept parts of the
/// tool". `PerformResult()` took the kept-parts path with a keep set containing no tool part at all,
/// and the caller got the input back with the cylinder's faces imprinted on it, reported as
/// `BRepFeat_NoError` throughout.
///
/// `BRepFeat_Form` and `BRepFeat_RibSlot`, the kernel's other two users of the same builder, both
/// call the two-argument `SetOperation(myFuse, bFlag)` with `bFlag` true. Carried patch
/// `Scripts/patches/0020-BRepFeat_MakeCylindricalHole-select-tool-parts-532.patch` makes the four
/// part-selecting modes do the same. `Perform(Radius)` selects no parts and was never affected,
/// which is why it was the one extent that already drilled a stack correctly.
///
/// Measurements and the before/after tables: `Scripts/repro/532-cylindrical-hole-part-selection/`.
@Suite("Issue532 cylindrical hole part selection")
struct Issue532CylindricalHolePartSelectionTests {

    private static let origin = SIMD3<Double>(0, 0, 15)
    private static let axis = SIMD3<Double>(0, 0, -1)
    private static let radius = 5.0

    /// One r=5 bore through 20mm of stock.
    private static let bore = Double.pi * 25 * 20

    /// Plates 50 x 50 x 20 stacked on the drill axis with a gap. From origin (0,0,15) along -Z the
    /// first sits at axis parameters 5...25, the second at 45...65, the third at 85...105.
    private func stack(_ count: Int) -> Shape? {
        var plates: [Shape] = []
        for i in 0..<count {
            guard let p = Shape.box(width: 50, height: 50, depth: 20)?
                    .translated(by: SIMD3(0, 0, -40 * Double(i))) else { return nil }
            plates.append(p)
        }
        return Shape.compound(plates)
    }

    // MARK: - The defect

    /// The two extents #532 named. Both bound the hole by the stock's own faces, so both must drill
    /// every body between the entry and exit face, which is what the boolean drill and
    /// `.throughAll` always did.
    @Test("untilEnd and a stack-spanning range drill every body on the axis")
    func untilEndAndRangeDrillEveryBody() {
        guard let stack = stack(2), let v0 = stack.volume else { #expect(Bool(false), "stack"); return }

        for extent: Shape.CylindricalHoleExtent in [.untilEnd, .range(from: 0, to: 70)] {
            guard let d = stack.cylindricalHole(axisOrigin: Self.origin, axisDirection: Self.axis,
                                                radius: Self.radius, extent: extent),
                  let v = d.volume else {
                #expect(Bool(false), "\(extent) failed outright"); continue
            }
            #expect(abs((v0 - v) - 2 * Self.bore) < 1.0,
                    "\(extent) removed \(v0 - v), expected \(2 * Self.bore)")
            #expect(d.isValid)
            // Both plates still one solid each: the tool was subtracted, not merely imprinted.
            #expect(d.subShapes(ofType: .solid).count == 2)
        }
    }

    /// `PerformBlind` shares the same broken selection and was not named in #532, it was reported
    /// against the two extents #496 had newly wrapped. On the stack it removed nothing; a blind
    /// depth of 20 from the origin reaches 15mm into the first plate (which starts at parameter 5).
    @Test("blind drills its depth into the first body of a stack")
    func blindDrillsIntoAStack() {
        guard let stack = stack(2), let v0 = stack.volume else { #expect(Bool(false), "stack"); return }
        let expected = Double.pi * 25 * 15   // 20mm of depth, 5mm of it above the plate

        guard let d = stack.cylindricalHole(axisOrigin: Self.origin, axisDirection: Self.axis,
                                            radius: Self.radius, extent: .blind(depth: 20)),
              let v = d.volume else {
            #expect(Bool(false), "blind failed outright"); return
        }
        #expect(abs((v0 - v) - expected) < 1.0, "blind removed \(v0 - v), expected \(expected)")
        #expect(d.isValid)
    }

    /// Three bodies, so the fix cannot be "keep two parts instead of one". `untilEnd` bounds itself
    /// by the stock's first and last faces and drills all three; a range naming only the first two
    /// face pairs drills exactly those two.
    @Test("A three-plate stack drills as many bodies as the extent names")
    func threePlateStack() {
        guard let stack = stack(3), let v0 = stack.volume else { #expect(Bool(false), "stack"); return }

        guard let all = stack.cylindricalHole(axisOrigin: Self.origin, axisDirection: Self.axis,
                                              radius: Self.radius, extent: .untilEnd),
              let va = all.volume else {
            #expect(Bool(false), "untilEnd failed"); return
        }
        #expect(abs((v0 - va) - 3 * Self.bore) < 1.0)

        guard let two = stack.cylindricalHole(axisOrigin: Self.origin, axisDirection: Self.axis,
                                              radius: Self.radius, extent: .range(from: 0, to: 70)),
              let vt = two.volume else {
            #expect(Bool(false), "range failed"); return
        }
        #expect(abs((v0 - vt) - 2 * Self.bore) < 1.0)
    }

    /// #532 read as a multi-body defect, but the trigger is "the cut result has two solids", and a
    /// **single** solid reaches it. An 8mm-wide bar drilled at r=5 is severed by its own bore, so
    /// the cut result is two pieces of one workpiece, no compound in sight.
    ///
    /// Removed volume is the r=5 disc clipped to |x| <= 4, extruded 20mm: two circular segments come
    /// off the full bore.
    @Test("A single solid the bore severs is drilled, not merely imprinted")
    func singleSolidSeveredByItsOwnBore() {
        guard let bar = Shape.box(width: 8, height: 50, depth: 20), let v0 = bar.volume else {
            #expect(Bool(false), "bar"); return
        }
        let segment = 25 * acos(0.8) - 4 * 3.0        // r²·acos(d/r) - d·√(r²-d²), d = 4, r = 5
        let expected = (Double.pi * 25 - 2 * segment) * 20

        for extent: Shape.CylindricalHoleExtent in [.untilEnd, .thruNext, .range(from: 0, to: 30)] {
            guard let d = bar.cylindricalHole(axisOrigin: Self.origin, axisDirection: Self.axis,
                                              radius: Self.radius, extent: extent),
                  let v = d.volume else {
                #expect(Bool(false), "\(extent) failed outright"); continue
            }
            #expect(abs((v0 - v) - expected) < 1.0,
                    "\(extent) removed \(v0 - v), expected \(expected)")
            #expect(d.subShapes(ofType: .solid).count == 2, "\(extent) did not sever the bar")
        }
    }

    // MARK: - The cases the fix must not disturb

    /// A single plate never reached the selection branch, the cut result was one solid, so every
    /// extent must answer exactly as it did before.
    @Test("A single plate is unaffected by the part-selection fix")
    func singlePlateUnchanged() {
        guard let plate = Shape.box(width: 50, height: 50, depth: 20),
              let v0 = plate.volume else { #expect(Bool(false), "plate"); return }

        let expected: [(Shape.CylindricalHoleExtent, Double)] = [
            (.throughAll, Self.bore),
            (.untilEnd, Self.bore),
            (.thruNext, Self.bore),
            (.range(from: 0, to: 30), Self.bore),
            (.range(from: 10, to: 20), Self.bore),   // a window inside one body still bores all of it
            (.blind(depth: 20), Double.pi * 25 * 15),
        ]
        for (extent, want) in expected {
            guard let d = plate.cylindricalHole(axisOrigin: Self.origin, axisDirection: Self.axis,
                                                radius: Self.radius, extent: extent),
                  let v = d.volume else {
                #expect(Bool(false), "\(extent) failed outright"); continue
            }
            #expect(abs((v0 - v) - want) < 1.0, "\(extent) removed \(v0 - v), expected \(want)")
            #expect(d.subShapes(ofType: .solid).count == 1)
        }
    }

    /// A hollow box: one solid, four axis crossings, drilled from above so both walls lie at
    /// positive axis parameters. Before the fix the selection branch never ran here (the cut result
    /// was one solid); after it, the branch selects two real tool parts and keeps both. Same answer,
    /// reached by the machinery that is supposed to produce it.
    @Test("A hollow box drills both walls, before and after the fix")
    func hollowBoxDrillsBothWalls() {
        guard let outer = Shape.box(width: 50, height: 50, depth: 50),
              let inner = Shape.box(width: 40, height: 40, depth: 40),
              let box = outer.subtracting(inner), let v0 = box.volume else {
            #expect(Bool(false), "hollow box"); return
        }
        let origin = SIMD3<Double>(0, 0, 30)          // above the box: walls at 5...10 and 50...55
        let expected = 2 * Double.pi * 25 * 5         // two 5mm walls

        for extent: Shape.CylindricalHoleExtent in [.throughAll, .untilEnd, .range(from: 0, to: 60)] {
            guard let d = box.cylindricalHole(axisOrigin: origin, axisDirection: Self.axis,
                                              radius: Self.radius, extent: extent),
                  let v = d.volume else {
                #expect(Bool(false), "\(extent) failed outright"); continue
            }
            #expect(abs((v0 - v) - expected) < 1.0,
                    "\(extent) removed \(v0 - v), expected \(expected)")
            #expect(d.isValid)
        }
    }

    /// A range window still selects a face pair rather than trimming, and one that names no pair is
    /// still refused, the fix changes which tool parts are kept, not which parameters are legal.
    @Test("A range naming no face pair is still invalidPlacement")
    func rangeOverTheGapIsStillRefused() {
        guard let stack = stack(2) else { #expect(Bool(false), "stack"); return }

        #expect(stack.cylindricalHoleStatus(axisOrigin: Self.origin, axisDirection: Self.axis,
                                            radius: Self.radius,
                                            extent: .range(from: 26, to: 44)) == .invalidPlacement)
        #expect(stack.cylindricalHole(axisOrigin: Self.origin, axisDirection: Self.axis,
                                      radius: Self.radius, extent: .range(from: 26, to: 44)) == nil)
    }
}
