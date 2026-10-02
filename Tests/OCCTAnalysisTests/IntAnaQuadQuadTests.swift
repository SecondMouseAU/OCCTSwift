import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("IntAna_IntQuadQuad Tests")
struct IntAnaQuadQuadTests {

    @Test func cylinderSphereIntersection() throws {
        let count = try #require(
            QuadricIntersection.cylinderSphere(
                cylinderRadius: 3,
                sphereCenter: .zero, sphereRadius: 5))
        #expect(count == 2)
    }

    @Test func cylinderSphereNotIdentical() {
        let identical = QuadricIntersection.cylinderSphereIdentical(
            cylinderRadius: 3,
            sphereCenter: .zero, sphereRadius: 5)
        #expect(!identical)
    }
}
