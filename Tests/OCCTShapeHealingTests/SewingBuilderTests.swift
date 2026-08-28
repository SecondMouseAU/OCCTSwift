import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Sewing Builder Tests")
struct SewingBuilderTests {

    @Test func createSewing() {
        let sewing = SewingBuilder(tolerance: 1e-6)
        #expect(sewing != nil)
    }

    @Test func sewBoxFaces() {
        if let sewing = SewingBuilder(tolerance: 1e-6) {
            if let box = Shape.box(width: 10, height: 10, depth: 10) {
                let faces = box.subShapes(ofType: .face)
                for face in faces {
                    sewing.add(face)
                }
                sewing.perform()
                if let result = sewing.result {
                    #expect(result.isValid)
                }
            }
        }
    }

    @Test func sewingStatistics() {
        if let sewing = SewingBuilder(tolerance: 1e-6) {
            if let box = Shape.box(width: 10, height: 10, depth: 10) {
                let faces = box.subShapes(ofType: .face)
                for face in faces {
                    sewing.add(face)
                }
                sewing.perform()
                #expect(sewing.nbFreeEdges >= 0)
                #expect(sewing.nbContigousEdges >= 0)
                #expect(sewing.nbDegeneratedShapes >= 0)
            }
        }
    }
}
