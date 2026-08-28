import Testing
import simd

@testable import OCCTSwift

// MARK: - Missing Core Shape Operations

@Suite("Shape, Torus, Chamfer, Offset, Scale, Mirror")
struct MissingShapeOpsTests {
    @Test("Torus creation")
    func torusCreation() {
        let torus = Shape.torus(majorRadius: 10, minorRadius: 3)
        #expect(torus != nil)
        #expect(torus!.isValid)
        let vol = torus!.volume ?? 0
        // Volume of torus = 2 * pi^2 * R * r^2
        let expected = 2.0 * Double.pi * Double.pi * 10.0 * 9.0
        #expect(abs(vol - expected) / expected < 0.01)
    }

    @Test("Chamfer on box")
    func chamferBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let chamfered = box.chamfered(distance: 1)
        #expect(chamfered != nil)
        #expect(chamfered!.isValid)
        // Chamfered box has more faces than original 6
        #expect(chamfered!.faces().count > 6)
    }

    @Test("Offset solid")
    func offsetSolid() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let offset = box.offset(by: 1.0)
        #expect(offset != nil)
        #expect(offset!.isValid)
        // Offset box should be larger
        let originalVol = box.volume ?? 0
        let offsetVol = offset!.volume ?? 0
        #expect(offsetVol > originalVol)
    }

    @Test("Scale shape")
    func scaleShape() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let scaled = box.scaled(by: 2.0)
        #expect(scaled != nil)
        #expect(scaled!.isValid)
        let scaledSize = scaled!.size!
        #expect(abs(scaledSize.x - 20) < 0.01)
        #expect(abs(scaledSize.y - 20) < 0.01)
        #expect(abs(scaledSize.z - 20) < 0.01)
    }

    @Test("Mirror shape")
    func mirrorShape() {
        let box = Shape.box(origin: SIMD3(5, 0, 0), width: 10, height: 10, depth: 10)!
        let mirrored = box.mirrored(planeNormal: SIMD3(1, 0, 0))
        #expect(mirrored != nil)
        #expect(mirrored!.isValid)
        // Original center is at (10, 5, 5), mirrored should be at (-10, 5, 5)
        let mirroredCenter = mirrored!.center!
        #expect(mirroredCenter.x < 0)
    }

    @Test("SliceAtZ produces valid cross-section")
    func sliceAtZ() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let slice = box.sliceAtZ(5)
        #expect(slice != nil)
        #expect(slice!.isValid)
    }

    @Test("SectionWiresAtZ extracts wires")
    func sectionWiresAtZ() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let wires = box.sectionWiresAtZ(5)
        #expect(!wires.isEmpty)
    }
}
