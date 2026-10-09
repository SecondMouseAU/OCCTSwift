import Testing
import simd

@testable import OCCTSwift

@Suite("Offset by Join")
struct OffsetByJoinTests {
    @Test("Offset box outward with arc join")
    func offsetArc() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let offset = box.offset(by: 1.0, joinType: .arc)
        #expect(offset != nil)
        if let o = offset {
            #expect(o.isValid)
            #expect(o.volume! > box.volume!)
        }
    }

    @Test("Offset box inward")
    func offsetInward() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let offset = box.offset(by: -1.0, joinType: .arc)
        #expect(offset != nil)
        if let o = offset {
            #expect(o.isValid)
            #expect(o.volume! < box.volume!)
        }
    }

    @Test("Offset with intersection join")
    func offsetIntersection() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let offset = box.offset(by: 1.0, joinType: .intersection)
        #expect(offset != nil)
        if let o = offset {
            #expect(o.isValid)
        }
    }

    @Test("Offset cylinder")
    func offsetCylinder() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let offset = cyl.offset(by: 1.0, joinType: .arc)
        #expect(offset != nil)
    }
}
