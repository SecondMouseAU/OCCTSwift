import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("Shape Check Tests")
struct ShapeCheckTests {
    @Test("Valid box passes check")
    func validBoxPasses() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        #expect(box.isValid)
        let result = box.checkResult
        #expect(result.isValid)
        #expect(result.errorCount == 0)
    }

    @Test("Valid sphere passes check")
    func validSpherePasses() throws {
        let sphere = Shape.sphere(radius: 5)!
        #expect(sphere.isValid)
    }

    @Test("Valid cylinder passes check")
    func validCylinderPasses() throws {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        #expect(cyl.isValid)
    }

    @Test("Check result has no first error for valid shape")
    func checkResultNoError() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.checkResult
        #expect(result.firstError == nil)
    }

    @Test("Detailed check on valid shape returns empty")
    func detailedCheckEmpty() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let statuses = box.detailedCheckStatuses
        #expect(statuses.isEmpty)
    }

    @Test("All box faces pass face check")
    func boxFaceCheck() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        for i in 0..<box.faceCount {
            let face = box.face(at: i)!
            let result = face.faceCheckResult
            #expect(result.isValid, "Face \(i) should be valid")
        }
    }

    @Test("Solid check passes for box")
    func solidCheckBox() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        // Use the general shape check which includes solid check
        #expect(box.isValid)
    }

    @Test("Boolean result passes validity")
    func booleanResultValid() throws {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(origin: SIMD3(5, 5, 5), width: 10, height: 10, depth: 10)!
        if let fused = box1.union(box2) {
            #expect(fused.isValid)
        }
    }
}
