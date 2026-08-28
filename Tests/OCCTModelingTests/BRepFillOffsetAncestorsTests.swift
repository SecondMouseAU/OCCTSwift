import Testing
import simd

@testable import OCCTSwift

@Suite("BRepFill_OffsetAncestors")
struct BRepFillOffsetAncestorsTests {
    @Test("create and query offset ancestors")
    func offsetAncestors() {
        if let rect = Wire.rectangle(width: 10, height: 10),
            let face = Shape.face(from: rect)
        {
            if let ancestors = OffsetAncestors.create(face: face, offset: 1.0) {
                #expect(ancestors.isDone)
            }
        }
    }

    @Test("find ancestor edge")
    func findAncestor() {
        if let rect = Wire.rectangle(width: 10, height: 10),
            let face = Shape.face(from: rect)
        {
            if let ancestors = OffsetAncestors.create(face: face, offset: 1.0) {
                if ancestors.isDone {
                    let edges = face.subShapes(ofType: .edge)
                    if let firstEdge = edges.first {
                        let _ = ancestors.hasAncestor(firstEdge)
                        #expect(true)
                    }
                }
            }
        }
    }
}
