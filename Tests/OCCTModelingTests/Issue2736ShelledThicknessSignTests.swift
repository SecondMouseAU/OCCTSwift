import Testing
import simd

@testable import OCCTSwift

/// Pins the sign convention for `Shape.shelled(thickness:openFaces:)` and its siblings that route
/// through the same `BRepOffsetAPI_MakeThickSolid` call (`hollowed(removingFaces:thickness:...)`,
/// `shelledWithFullHistory(facesToRemove:thickness:...)`): a positive thickness shells OUTWARD
/// (grows the solid, matching `offset(by:)`), a negative one shells INWARD (removes material).
///
/// #2736 found the doc comment for `shelled(thickness:openFaces:)` had this backwards ("positive
/// = inward"); the measured behaviour, and OCCT's own `BRepOffsetAPI_MakeThickSolid` convention,
/// is the opposite. Nothing in the existing suite (`AdvancedModelingTests`,
/// `Issue568IndexSkipTests`) measured the direction by volume, only that a shelled result exists
/// and is valid, so a "fix" that instead negated the thickness in the wrapper (the alternative the
/// issue considered, and the user explicitly rejected in favour of the doc-only fix) would have
/// passed every existing test unnoticed.
@Suite("Issue 2736: shelled thickness sign convention")
struct Issue2736ShelledThicknessSignTests {

    // A 20mm cube has volume 8000. Shelling a face open with 2mm walls:
    //   - outward (walls added outside the original faces, rounded outer corners): ~4519.41
    //   - inward (walls carved from inside): 8000 - 16*16*18 = 3392 exactly
    // Matches the issue's own reported numbers, and independently confirmed against the pinned
    // kernel via Scripts/repro/2736-shelled-thickness-sign/probe.mm (raw
    // BRepOffsetAPI_MakeThickSolid::MakeThickSolidByJoin, no Swift/bridge layer involved).
    private static let outwardVolume = 4519.409985301006
    private static let inwardVolume = 3392.0
    private static let tolerance = 1e-3

    private static func openBox() throws -> (box: Shape, topFaces: [Face]) {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let topFaces = box.upwardFaces()
        #expect(topFaces.count == 1)
        return (box, topFaces)
    }

    private static func topFaceIndex(of box: Shape) throws -> Int {
        try #require(box.faces().firstIndex { $0.isUpwardFacing() })
    }

    @Test func shelledOpenFacesPositiveThicknessShellsOutward() throws {
        let (box, topFaces) = try Self.openBox()
        let shelled = box.shelled(thickness: 2.0, openFaces: topFaces)
        if let volume = shelled?.volume {
            #expect(abs(volume - Self.outwardVolume) < Self.tolerance)
        } else {
            #expect(Bool(false), "shelled(thickness: 2.0, openFaces:) should succeed")
        }
    }

    @Test func shelledOpenFacesNegativeThicknessShellsInward() throws {
        let (box, topFaces) = try Self.openBox()
        let shelled = box.shelled(thickness: -2.0, openFaces: topFaces)
        if let volume = shelled?.volume {
            #expect(abs(volume - Self.inwardVolume) < Self.tolerance)
        } else {
            #expect(Bool(false), "shelled(thickness: -2.0, openFaces:) should succeed")
        }
    }

    @Test func hollowedPositiveThicknessShellsOutward() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let topIndex = try Self.topFaceIndex(of: box)
        let hollow = box.hollowed(removingFaces: [topIndex], thickness: 2.0)
        if let volume = hollow?.volume {
            #expect(abs(volume - Self.outwardVolume) < Self.tolerance)
        } else {
            #expect(Bool(false), "hollowed(removingFaces:thickness: 2.0) should succeed")
        }
    }

    @Test func hollowedNegativeThicknessShellsInward() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let topIndex = try Self.topFaceIndex(of: box)
        let hollow = box.hollowed(removingFaces: [topIndex], thickness: -2.0)
        if let volume = hollow?.volume {
            #expect(abs(volume - Self.inwardVolume) < Self.tolerance)
        } else {
            #expect(Bool(false), "hollowed(removingFaces:thickness: -2.0) should succeed")
        }
    }

    @Test func shelledWithFullHistoryPositiveThicknessShellsOutward() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let topIndex = try Self.topFaceIndex(of: box)
        let outcome = box.shelledWithFullHistory(facesToRemove: [topIndex], thickness: 2.0)
        if let volume = outcome?.result.volume {
            #expect(abs(volume - Self.outwardVolume) < Self.tolerance)
        } else {
            #expect(Bool(false), "shelledWithFullHistory(facesToRemove:thickness: 2.0) should succeed")
        }
    }

    @Test func shelledWithFullHistoryNegativeThicknessShellsInward() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let topIndex = try Self.topFaceIndex(of: box)
        let outcome = box.shelledWithFullHistory(facesToRemove: [topIndex], thickness: -2.0)
        if let volume = outcome?.result.volume {
            #expect(abs(volume - Self.inwardVolume) < Self.tolerance)
        } else {
            #expect(Bool(false), "shelledWithFullHistory(facesToRemove:thickness: -2.0) should succeed")
        }
    }
}
