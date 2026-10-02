import Testing
import simd

@testable import OCCTSwift

// MARK: - Missing Core Shape Operations

@Suite("Shape, Torus, Chamfer, Offset, Scale, Mirror")
struct MissingShapeOpsTests {
    @Test("Torus creation")
    func torusCreation() throws {
        let torus = try #require(Shape.torus(majorRadius: 10, minorRadius: 3))
        #expect(torus.isValid)
        let vol = torus.volume ?? 0
        // Volume of torus = 2 * pi^2 * R * r^2
        let expected = 2.0 * Double.pi * Double.pi * 10.0 * 9.0
        #expect(abs(vol - expected) / expected < 0.01)
    }

    @Test("Chamfer on box")
    func chamferBox() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let chamfered = try #require(box.chamfered(distance: 1))
        #expect(chamfered.isValid)
        // Chamfered box has more faces than original 6
        #expect(chamfered.faces().count > 6)
        // #766: `> 6` holds for a box that was not chamfered at all, plus one face. Pinned to the
        // kernel (Scripts/repro/766-modeling-missing-shape-ops, transcript-evidence-fix.txt):
        // chamfering all 12 edges of the 10 mm box by 1 gives 6 + 12 edge faces + 8 corner faces,
        // 26 faces, and a volume of 945.333.
        #expect(chamfered.faces().count == 26)
        let volume = try #require(chamfered.volume)
        #expect(abs(volume - 945.333333333333) < 1e-6)
    }

    @Test("Offset solid")
    func offsetSolid() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let offset = try #require(box.offset(by: 1.0))
        #expect(offset.isValid)
        // Offset box should be larger
        let originalVol = box.volume ?? 0
        let offsetVol = offset.volume ?? 0
        #expect(offsetVol > originalVol)
        // #766: `>` holds for any growth. Pinned to the kernel
        // (Scripts/repro/766-modeling-missing-shape-ops): BRepOffsetAPI_MakeOffsetShape
        // PerformBySimple with 1.0 on this box has volume 1200, not the 1728 a 12 mm cube would
        // have, and the bridge returns exactly that.
        #expect(abs(originalVol - 1000) < 1e-6)
        #expect(abs(offsetVol - 1200) < 1e-6)
    }

    @Test("Scale shape")
    func scaleShape() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let scaled = try #require(box.scaled(by: 2.0))
        #expect(scaled.isValid)
        let scaledSize = try #require(scaled.size)
        #expect(abs(scaledSize.x - 20) < 0.01)
        #expect(abs(scaledSize.y - 20) < 0.01)
        #expect(abs(scaledSize.z - 20) < 0.01)
    }

    @Test("Mirror shape")
    func mirrorShape() throws {
        let box = try #require(Shape.box(origin: SIMD3(5, 0, 0), width: 10, height: 10, depth: 10))
        let mirrored = try #require(box.mirrored(planeNormal: SIMD3(1, 0, 0)))
        #expect(mirrored.isValid)
        // Original center is at (10, 5, 5), mirrored should be at (-10, 5, 5)
        let mirroredCenter = try #require(mirrored.center)
        #expect(mirroredCenter.x < 0)
        // #766: `x < 0` holds for a mirror across any other plane, or a translation. Pinned to
        // the kernel (Scripts/repro/766-modeling-missing-shape-ops): the mirrored centre is
        // exactly (-10, 5, 5).
        #expect(simd_distance(mirroredCenter, SIMD3(-10, 5, 5)) < 1e-6)
    }

    @Test("SliceAtZ produces valid cross-section")
    func sliceAtZ() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        // #766: this asserted only `slice != nil` and `slice!.isValid`, which an EMPTY section
        // also satisfies: probed (Scripts/repro/766-modeling-missing-shape-ops),
        // BRepAlgoAPI_Section at z = 6, off this centred box, is done, valid, and has no edges.
        // Pinned to the kernel's section at z = 5 (the top face's plane): 4 edges, all at z = 5.
        let slice = try #require(box.sliceAtZ(5))
        #expect(slice.isValid)
        #expect(slice.subShapes(ofType: .edge).count == 4)
        #expect(slice.center.map { abs($0.z - 5) < 1e-6 } ?? false)
    }

    @Test("SectionWiresAtZ extracts wires")
    func sectionWiresAtZ() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let wires = box.sectionWiresAtZ(5)
        #expect(!wires.isEmpty)
        // #766: `!isEmpty` holds for any wire, open or closed, of any length, and for several.
        // Pinned to the kernel (Scripts/repro/766-modeling-missing-shape-ops,
        // transcript-evidence-fix.txt): the z = 5 section of the box is a single wire of 4 edges,
        // closed, the top face's outline.
        #expect(wires.count == 1)
        let wire = try #require(wires.first)
        let wireShape = try #require(Shape.fromWire(wire))
        #expect(wireShape.isClosedShape)
        #expect(wire.edges().count == 4)
    }
}
