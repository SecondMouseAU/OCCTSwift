import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.123.0, UnifySameDomain builder")
struct UnifySameDomainBuilderTests {

    @Test("Basic unification with builder")
    func basicUnification() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let usd = UnifySameDomainBuilder(shape: b)
            usd.build()
            let result = usd.shape
            #expect(result != nil)
        }
    }

    @Test("AllowInternalEdges")
    func allowInternalEdges() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let usd = UnifySameDomainBuilder(shape: b)
            usd.allowInternalEdges(true)
            usd.build()
            let result = usd.shape
            #expect(result != nil)
        }
    }

    @Test("KeepShape")
    func keepShape() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let faces = b.subShapes(ofType: .face)
            if faces.count > 0 {
                let usd = UnifySameDomainBuilder(shape: b)
                usd.keepShape(faces[0])
                usd.build()
                let result = usd.shape
                #expect(result != nil)
            }
        }
    }

    @Test("SetSafeInputMode")
    func safeInputMode() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let usd = UnifySameDomainBuilder(shape: b)
            usd.setSafeInputMode(true)
            usd.build()
            let result = usd.shape
            #expect(result != nil)
        }
    }

    @Test("SetLinearTolerance and SetAngularTolerance")
    func tolerances() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let usd = UnifySameDomainBuilder(shape: b)
            usd.setLinearTolerance(1e-6)
            usd.setAngularTolerance(1e-3)
            usd.build()
            let result = usd.shape
            #expect(result != nil)
        }
    }
}
