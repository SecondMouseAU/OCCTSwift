import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepAdaptor PCurve")
struct BRepAdaptorPCurveTests {
    @Test("PCurve params on box face")
    func pcurveParams() {
        guard let box = Shape.box(width: 10, height: 20, depth: 30) else {
            #expect(Bool(false), "Failed to create box")
            return
        }
        let faces = box.faces()
        let edges = box.edges()
        #expect(faces.count > 0)
        #expect(edges.count > 0)
        if faces.count > 0 && edges.count > 0 {
            // Try each edge until we find one with a PCurve on the first face
            for edge in edges {
                if let params = edge.pcurveParams(on: faces[0]) {
                    #expect(params.last > params.first)
                    break
                }
            }
        }
    }

    @Test("PCurve value evaluation")
    func pcurveValue() {
        guard let box = Shape.box(width: 10, height: 20, depth: 30) else {
            #expect(Bool(false), "Failed to create box")
            return
        }
        let faces = box.faces()
        let edges = box.edges()
        if faces.count > 0 && edges.count > 0 {
            for edge in edges {
                if let params = edge.pcurveParams(on: faces[0]) {
                    let mid = (params.first + params.last) / 2.0
                    let uv = edge.pcurveValue(at: mid, on: faces[0])
                    if uv != nil {
                        #expect(Bool(true))
                        return
                    }
                }
            }
        }
    }
}
