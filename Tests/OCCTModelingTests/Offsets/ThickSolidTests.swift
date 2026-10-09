import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.37.0. OCCT Test Suite Audit Round 6

@Suite("Thick Solid / Hollowing")
struct ThickSolidTests {
    @Test("Hollow a box by removing top face")
    func hollowBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        // Find the top face index (Z=10 face)
        let faces = box.faces()
        // Try hollowing with the first face as opening
        let result = box.hollowed(removingFaces: [0], thickness: -1.0, tolerance: 1e-3)
        #expect(result != nil)
        if let r = result {
            #expect(r.volume! > 0)
            // Hollow box should have less volume than solid box
            #expect(r.volume! < 1000.0)
        }
    }

    @Test("Hollow cylinder")
    func hollowCylinder() {
        let cyl = Shape.cylinder(radius: 10, height: 20)!
        // Cylinder has 3 faces: [0]=cylinder, [1]=bottom cap (plane), [2]=top cap (plane)
        // Remove a planar cap face (index 1 = bottom cap, 0-based)
        let result = cyl.hollowed(removingFaces: [1], thickness: -1.0, tolerance: 1e-3)
        #expect(result != nil)
        if let r = result {
            #expect(r.isValid)
            #expect(r.volume! < cyl.volume!)
        }
    }

    @Test("Hollow with invalid face index returns nil")
    func hollowInvalidFace() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.hollowed(removingFaces: [999], thickness: -1.0)
        #expect(result == nil)
    }
}
