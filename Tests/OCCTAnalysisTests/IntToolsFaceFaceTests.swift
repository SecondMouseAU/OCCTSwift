import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("IntTools_FaceFace Tests")
struct IntToolsFaceFaceTests {
    @Test("Perpendicular box faces produce intersection line")
    func faceFaceIntersection() {
        // Create a box and test intersection of two of its faces
        let plane1 = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))
        let plane2 = Surface.plane(origin: .zero, normal: SIMD3(0, 1, 0))
        if let s1 = plane1, let s2 = plane2 {
            let f1 = Shape.face(from: s1, uRange: -5...5, vRange: -5...5)
            let f2 = Shape.face(from: s2, uRange: -5...5, vRange: -5...5)
            if let face1 = f1, let face2 = f2 {
                let result = face1.faceFaceIntersection(with: face2)
                #expect(result != nil)
                if let r = result {
                    #expect(r.curves.count >= 1)
                    #expect(!r.isTangent)
                }
            }
        }
    }

    @Test("Coincident planes are tangent")
    func faceFaceTangent() {
        let plane1 = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))
        let plane2 = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))
        if let s1 = plane1, let s2 = plane2 {
            let f1 = Shape.face(from: s1, uRange: -5...5, vRange: -5...5)
            let f2 = Shape.face(from: s2, uRange: -5...5, vRange: -5...5)
            if let face1 = f1, let face2 = f2 {
                let result = face1.faceFaceIntersection(with: face2)
                if let r = result {
                    #expect(r.isTangent)
                }
            }
        }
    }
}
