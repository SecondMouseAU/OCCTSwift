// ShapeHealingTestFixtures.swift
// Shared fixtures for OCCTShapeHealingTests.
// No @Suite or @Test: only factory functions and the assertion helpers that read their output.

import Foundation
import OCCTSwift
import Testing
import simd

// The one shared helper CLAUDE.md's Test Layout section documents across every per-domain target
// ("the only shared helper is SIMD3.normalized"). Moved here verbatim from the top of
// OCCTShapeHealingTests.swift when that file was split by @Suite (#1301); no suite in this
// directory currently calls it, the same as before the split, since it's declared for whichever
// suite in the module needs it next rather than for a specific caller today.
extension SIMD3 where Scalar == Double {
    var normalized: SIMD3<Double> {
        let len = sqrt(x * x + y * y + z * z)
        guard len > 0 else { return self }
        return SIMD3(x / len, y / len, z / len)
    }
}

// MARK: - Fixtures

// A fixture that cannot be built, or that is not what its name says, throws and names itself. A
// factory returning nil makes every caller either skip its assertions or die on the same line,
// and a fixture that quietly stops meaning its name leaves every assertion downstream reading
// something else (okf/policies/prove-the-test-fails.md). Each precondition below is measured with
// an instrument other than the operation the suites under test exercise.

/// Drops one face from `box` and sews the remaining five into an open shell.
///
/// The smallest recipe that reaches an open shell with exactly four free edges ringing the missing
/// face, whatever the box's own size or origin. Shared by `Issue442FixSolidMultiBody` and
/// `Issue702SolidDemotion`, both of which built this same "drop one face, sew the rest" logic
/// independently before the #717 review pointed out the duplication.
func sewnBoxMissingOneFace(_ box: Shape, tolerance: Double = 1e-6) throws -> Shape {
    let faces = box.subShapes(ofType: .face)
    try #require(faces.count == 6, "the box has \(faces.count) faces, not 6")
    let five = try #require(Shape.compound(Array(faces.dropFirst())), "could not gather 5 faces")
    let shell = try #require(five.sewn(tolerance: tolerance), "could not sew the 5 faces")
    // Open means: still a shell, five faces, and it encloses no volume (`volume` is nil for an
    // open shell, where a closed one answers).
    try #require(shell.shapeType == .shell, "sewing 5 faces gave a \(shell.shapeType)")
    try #require(shell.subShapeCount(ofType: .face) == 5, "the sewn shell lost a face")
    try #require(shell.volume == nil, "the 5 sewn faces enclose a volume, so the shell is closed")
    return shell
}

/// Two disjoint 10mm boxes, 2000mm³ total: the #442/#443 issues' own reproducer.
///
/// Box A spans x in 0...10 and box B spans x in 20...30, both 10 tall and deep, in that order.
func twoBoxes() throws -> Shape {
    let a = try #require(Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10))
    let b = try #require(Shape.box(origin: SIMD3(20, 0, 0), width: 10, height: 10, depth: 10))
    let pair = try #require(Shape.compound([a, b]), "could not compound the two boxes")
    try #require(pair.solids.count == 2, "the two-box compound holds \(pair.solids.count) solids")
    return pair
}

/// The two boxes of ``twoBoxes()``, A then B, as the bodies a correct result holds.
func twoBoxBodies() -> [(origin: SIMD3<Double>, size: Double)] {
    [(origin: SIMD3<Double>(0, 0, 0), size: 10.0), (origin: SIMD3<Double>(20, 0, 0), size: 10.0)]
}

/// The expected-body spelling `expectBoxBodies` takes, with every literal a `Double`.
func boxBody(
    _ x: Double, _ y: Double, _ z: Double, size: Double
) -> (origin: SIMD3<Double>, size: Double) {
    (origin: SIMD3<Double>(x, y, z), size: size)
}

/// A 20mm cube with a 10mm cavity fully inside it: one solid, two shells.
///
/// The outer shell bounds 8000 and the cavity 1000, so the solid is 7000. The cavity spans 5...15
/// on every axis.
func hollowBox() throws -> Shape {
    let outer = try #require(Shape.box(origin: SIMD3(0, 0, 0), width: 20, height: 20, depth: 20))
    let cavity = try #require(Shape.box(origin: SIMD3(5, 5, 5), width: 10, height: 10, depth: 10))
    let hollow = try #require(outer.subtracting(cavity), "could not hollow the box")
    // The subtraction must have done something: a box that was never hollowed is one shell.
    try #require(hollow.solids.count == 1, "the hollow box holds \(hollow.solids.count) solids")
    try #require(hollow.shells.count == 2, "the hollow box holds \(hollow.shells.count) shells")
    return hollow
}

/// One solid holding two disjoint closed shells.
///
/// Pathological but real, and the case that rules out the naive "outer shell per solid" selection
/// rule, so it is the one most likely to regress unnoticed. The shells are the boxes of
/// ``twoBoxes()``, A first.
func multiconnexSolid() throws -> Shape {
    let a = try #require(Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10))
    let b = try #require(Shape.box(origin: SIMD3(20, 0, 0), width: 10, height: 10, depth: 10))
    let shellA = try #require(a.shells.first, "box A has no shell")
    let shellB = try #require(b.shells.first, "box B has no shell")
    let solid = try #require(Shape.solidFromShells([shellA, shellB]), "could not join the shells")
    try #require(solid.solids.count == 1, "expected one solid, found \(solid.solids.count)")
    try #require(solid.shells.count == 2, "expected two shells, found \(solid.shells.count)")
    return solid
}

/// A closed box shell pointing inward: the shell of a box, reversed.
///
/// It encloses a negative volume, so `volume` is nil and `signedVolume` is minus the box's volume,
/// which is what lets a test see an orientation fix happen.
func invertedBoxShell(at origin: SIMD3<Double>, size: Double = 10) throws -> Shape {
    let box = try #require(
        Shape.box(origin: origin, width: size, height: size, depth: size), "could not build a box")
    let shell = try #require(box.shells.first, "the box has no shell")
    let inverted = try #require(shell.reversed, "could not reverse the shell")
    let cube = size * size * size
    try #require(inverted.shapeType == .shell, "reversing a shell gave a \(inverted.shapeType)")
    try #require(inverted.volume == nil, "the reversed shell still reports a positive volume")
    try #require(
        abs(inverted.signedVolume + cube) < 1e-6,
        "the reversed shell encloses \(inverted.signedVolume), not \(-cube)")
    return inverted
}

/// A solid wrapping ``invertedBoxShell(at:size:)`` with no fixing at all.
///
/// `Shape.solidFromShells` builds it as is, so the solid is inside out: `volume` is nil and
/// `signedVolume` is negative, while `isValidSolid` reads true, so no validity check can see it.
func invertedBoxSolid(at origin: SIMD3<Double>, size: Double = 10) throws -> Shape {
    let shell = try invertedBoxShell(at: origin, size: size)
    let solid = try #require(Shape.solidFromShells([shell]), "could not wrap the reversed shell")
    let cube = size * size * size
    try #require(solid.shapeType == .solid, "wrapping a shell gave a \(solid.shapeType)")
    try #require(solid.volume == nil, "the inverted solid reports a positive volume")
    try #require(
        abs(solid.signedVolume + cube) < 1e-6,
        "the inverted solid encloses \(solid.signedVolume), not \(-cube)")
    return solid
}

// MARK: - Assertion helpers

/// How closely a bounding box must match a box: OCCT pads a bounding box by the shape's own
/// tolerance, measured at 1e-7 on a primitive box, where `min.x` of a box at the origin reads
/// -1e-7 and not 0.
let boundsTolerance = 1e-6

/// Whether two points agree on every axis to within `tolerance`.
func approximatelyEqual(
    _ a: SIMD3<Double>, _ b: SIMD3<Double>, tolerance: Double = boundsTolerance
) -> Bool {
    abs(a.x - b.x) < tolerance && abs(a.y - b.y) < tolerance && abs(a.z - b.z) < tolerance
}

/// Volume, asserted rather than optionally-bound.
///
/// A `nil` here means the solid came back inverted, which must fail the test rather than skip it.
/// `Shape.volume` is `v >= 0 ? v : nil`, so it returns `nil` precisely when a solid comes back
/// inverted. Shared by `Issue442FixSolidMultiBody` and `Issue443FirstOfN`.
func expectVolume(
    _ shape: Shape, _ expected: Double,
    _ what: String, sourceLocation: SourceLocation = #_sourceLocation
) {
    guard let volume = shape.volume else {
        Issue.record(
            "\(what): volume is nil, the solid came back inverted",
            sourceLocation: sourceLocation)
        return
    }
    #expect(
        abs(volume - expected) < 1e-6, "\(what): volume \(volume), expected \(expected)",
        sourceLocation: sourceLocation)
}

/// Asserts that `shape` spans exactly the axis-aligned box `lo...hi`.
///
/// Pins WHERE a result is, which a count and a volume cannot: two bodies that came back as the
/// same body twice have the right count and the right total volume and the wrong position.
func expectBounds(
    _ shape: Shape, from lo: SIMD3<Double>, to hi: SIMD3<Double>,
    _ what: String, sourceLocation: SourceLocation = #_sourceLocation
) throws {
    let box = try #require(
        shape.boundingBox, "\(what): no bounding box", sourceLocation: sourceLocation)
    #expect(
        approximatelyEqual(box.min, lo), "\(what): min \(box.min), expected \(lo)",
        sourceLocation: sourceLocation)
    #expect(
        approximatelyEqual(box.max, hi), "\(what): max \(box.max), expected \(hi)",
        sourceLocation: sourceLocation)
}

/// Asserts that two shapes span the same axis-aligned box.
func expectSameBounds(
    _ a: Shape, _ b: Shape, _ what: String, sourceLocation: SourceLocation = #_sourceLocation
) throws {
    let boxA = try #require(a.boundingBox, "\(what): first has no box", sourceLocation: sourceLocation)
    let boxB = try #require(b.boundingBox, "\(what): second has no box", sourceLocation: sourceLocation)
    #expect(
        approximatelyEqual(boxA.min, boxB.min) && approximatelyEqual(boxA.max, boxB.max),
        "\(what): \(boxA) against \(boxB)", sourceLocation: sourceLocation)
}

/// Asserts that `body` is the closed, outward-facing box solid at `origin` with edge `size`.
///
/// Six faces, a positive volume of `size³` read two ways (`volume` and `signedVolume`, so an
/// inverted body cannot pass as either), the box's exact bounds, and a valid closed solid. Pinning
/// all of it is what makes "this body is the one I expected" a statement about one body.
func expectBoxBody(
    _ body: Shape, at origin: SIMD3<Double>, size: Double = 10,
    _ what: String, sourceLocation: SourceLocation = #_sourceLocation
) throws {
    let cube = size * size * size
    let far = SIMD3<Double>(origin.x + size, origin.y + size, origin.z + size)
    #expect(
        body.shapeType == .solid, "\(what): is a \(body.shapeType), not a solid",
        sourceLocation: sourceLocation)
    #expect(
        body.subShapeCount(ofType: .face) == 6, "\(what): has \(body.subShapeCount(ofType: .face)) faces",
        sourceLocation: sourceLocation)
    expectVolume(body, cube, what, sourceLocation: sourceLocation)
    #expect(
        abs(body.signedVolume - cube) < 1e-6,
        "\(what): signed volume \(body.signedVolume), expected \(cube)",
        sourceLocation: sourceLocation)
    try expectBounds(body, from: origin, to: far, what, sourceLocation: sourceLocation)
    #expect(body.isValidSolid, "\(what): not a valid solid", sourceLocation: sourceLocation)
}

/// Asserts that `result` holds exactly the box bodies in `expected`, and which is which.
///
/// With `inOrder` the i-th solid of the result is the i-th expected body, which is the contract
/// wherever the input's own order is known. Without it each expected body must be found among the
/// result's solids, once, which is the claim to make about a sewn input, since sewing chooses the
/// order the shells arrive in.
func expectBoxBodies(
    _ result: Shape, _ expected: [(origin: SIMD3<Double>, size: Double)],
    inOrder: Bool, _ what: String, sourceLocation: SourceLocation = #_sourceLocation
) throws {
    let bodies = result.solids
    try #require(
        bodies.count == expected.count,
        "\(what): \(bodies.count) bodies, expected \(expected.count)",
        sourceLocation: sourceLocation)
    if inOrder {
        for (i, want) in expected.enumerated() {
            try expectBoxBody(
                bodies[i], at: want.origin, size: want.size, "\(what) body \(i)",
                sourceLocation: sourceLocation)
        }
        return
    }
    var unused = Array(bodies.indices)
    for (i, want) in expected.enumerated() {
        let far = SIMD3<Double>(want.origin.x + want.size, want.origin.y + want.size, want.origin.z + want.size)
        let match = unused.first { index in
            guard let box = bodies[index].boundingBox else { return false }
            return approximatelyEqual(box.min, want.origin) && approximatelyEqual(box.max, far)
        }
        let index = try #require(
            match, "\(what): no body spans \(want.origin) to \(far)", sourceLocation: sourceLocation)
        unused.removeAll { $0 == index }
        try expectBoxBody(
            bodies[index], at: want.origin, size: want.size, "\(what) expected body \(i)",
            sourceLocation: sourceLocation)
    }
}

// MARK: - Shared with the outer-bound suites

/// A 10x10 planar panel with a 4x4 centred window.
///
/// The face carries two wires, one that is its outer bound and one that is not. Shared by
/// `Issue999OuterBoundTests` and `Issue1058OuterBoundRefusalTests`, which built it independently
/// before the #1058 review pointed out the duplication, the same way #717 did for
/// `sewnBoxMissingOneFace` above.
func panelWithCentredWindow() -> Shape? {
    guard
        let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)),
        let outer = Wire.polygon3D(
            [SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0), SIMD3(0, 10, 0)], closed: true),
        let hole = Wire.polygon3D(
            [SIMD3(3, 3, 0), SIMD3(7, 3, 0), SIMD3(7, 7, 0), SIMD3(3, 7, 0)], closed: true)
    else { return nil }
    return Shape.face(from: plane, outer: outer, innerWires: [hole])
}
