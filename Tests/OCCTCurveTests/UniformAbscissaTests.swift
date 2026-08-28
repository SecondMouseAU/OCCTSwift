import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GCPnts_UniformAbscissa Tests")
struct UniformAbscissaTests {

    @Test func uniformByCount() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                let params = edge.uniformAbscissa(pointCount: 5)
                #expect(params != nil)
                if let params = params {
                    #expect(params.count == 5)
                }
            }
        }
    }

    @Test func uniformByDistance() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                let params = edge.uniformAbscissa(distance: 3.0)
                #expect(params != nil)
                if let params = params {
                    #expect(params.count >= 2)
                }
            }
        }
    }

    @Test func uniformByCountRange() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                let params = edge.uniformAbscissa(pointCount: 3, u1: 0, u2: 1)
                #expect(params != nil)
                if let params = params {
                    #expect(params.count == 3)
                }
            }
        }
    }
}
