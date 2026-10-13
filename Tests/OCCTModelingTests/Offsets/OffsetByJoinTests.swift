import Testing

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
    func offsetIntersection() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let offset = try #require(box.offset(by: 1.0, joinType: .intersection))
        #expect(offset.isValid)
        // The intersection join keeps the sharp corners: a 12 cube, six faces, 864 of area,
        // against the arc join's rounded 26-face shape.
        #expect(abs((offset.volume ?? -1) - 1728.0) < 1e-6)
        #expect(abs((offset.surfaceArea ?? -1) - 864.0) < 1e-6)
        #expect(offset.faces().count == 6)
    }

    @Test("Offset cylinder")
    func offsetCylinder() throws {
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        let offset = try #require(cyl.offset(by: 1.0, joinType: .arc))
        #expect(offset.isValid)
        // Radius 6 and 12 tall would be pi * 36 * 12 = 1357.17 with sharp rims; the arc join
        // rounds the two rims and gives back the corner material:
        // measured 1341.5898 on kernel.6, five faces.
        #expect(abs((offset.volume ?? -1) - 1341.589800182048) < 1e-4)
        #expect(offset.faces().count == 5)
        let sharp = try #require(cyl.offset(by: 1.0, joinType: .intersection))
        #expect(abs((sharp.volume ?? -1) - Double.pi * 36.0 * 12.0) < 1e-6)
        #expect((offset.volume ?? 0) < (sharp.volume ?? 0))
    }
}
