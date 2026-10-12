import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("BRepLib ValidateEdge Tests")
struct ValidateEdgeTests {
    @Test("validate edge on face")
    func validateEdge() throws {
        // A cylinder: lateral face, two caps, edges top rim, seam and bottom rim. An edge
        // validates against a face that carries it with a 3D-to-pcurve deviation of 0, and
        // against one that does not by the distance to that face (10.0001 here, the 10-unit
        // height plus the 1e-4 the kernel adds).
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        let faces = cyl.faces()
        let edges = cyl.edges()
        #expect(faces.count == 3)
        #expect(edges.count == 3)

        var carried = 0
        var foreign = 0
        for face in faces {
            let lateral = face.area() > 200
            let level = face.zLevel
            for edge in edges {
                let r = edge.validate(on: face)
                #expect(r.isDone)
                // The lateral face carries all three edges; a cap carries only its own rim.
                var onFace = lateral
                if !lateral, let level {
                    onFace = edge.isClosed3D && abs(edge.endpoints.start.z - level) < 1e-9
                }
                #expect(r.isWithinTolerance == onFace)
                if onFace {
                    carried += 1
                    #expect(r.maxDistance < 1e-9)
                } else {
                    foreign += 1
                    #expect(abs(r.maxDistance - 10.0001) < 1e-6)
                }
            }
        }
        // 3 on the lateral face + 1 per cap = 5 carried, 4 foreign.
        #expect(carried == 5)
        #expect(foreign == 4)
    }

    @Test("check tolerance")
    func checkTolerance() throws {
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        let faces = cyl.faces()
        let edges = cyl.edges()
        #expect(faces.count == 3)

        // The tolerance argument is what the deviation is judged against, and is echoed back.
        // The measured deviations are 0 (carried) or 10.0001 (not carried), so:
        //   tolerance 1.0   judges the carried ones within and the foreign ones not,
        //   tolerance 20.0  judges every pair within.
        var judgedWithin1 = 0
        var judgedWithin20 = 0
        for face in faces {
            for edge in edges {
                let tight = edge.validate(on: face, tolerance: 1.0)
                let loose = edge.validate(on: face, tolerance: 20.0)
                #expect(tight.isDone)
                #expect(loose.isDone)
                #expect(tight.tolerance == 1.0)
                #expect(loose.tolerance == 20.0)
                #expect(tight.isWithinTolerance == (tight.maxDistance < 1.0))
                #expect(loose.isWithinTolerance)
                if tight.isWithinTolerance { judgedWithin1 += 1 }
                if loose.isWithinTolerance { judgedWithin20 += 1 }
            }
        }
        #expect(judgedWithin1 == 5)
        #expect(judgedWithin20 == 9)
    }
}
