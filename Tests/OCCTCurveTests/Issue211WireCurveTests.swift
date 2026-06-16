import Testing
import Foundation
import simd
@testable import OCCTSwift

// #211: WireCurve — treat a multi-edge wire as one arc-length-parameterized curve.
@Suite("Issue #211 — WireCurve arc-length adaptor")
struct Issue211WireCurve {

    // An L-shaped open wire: (0,0,0)→(10,0,0)→(10,10,0). Two edges, total length 20.
    private func lWire() -> Wire? {
        Wire.polygon3D([SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0)], closed: false)
    }

    @Test("length spans all edges")
    func length() {
        guard let w = lWire(), let wc = WireCurve(w) else { #expect(Bool(false)); return }
        #expect(abs(wc.length - 20.0) < 1e-6)
    }

    @Test("point(atAbscissa:) walks across the edge boundary")
    func pointAtAbscissa() {
        guard let w = lWire(), let wc = WireCurve(w) else { #expect(Bool(false)); return }
        func near(_ a: SIMD3<Double>?, _ b: SIMD3<Double>) -> Bool {
            guard let a else { return false }
            return simd_distance(a, b) < 1e-6
        }
        #expect(near(wc.point(atAbscissa: 0),  SIMD3(0, 0, 0)))    // start
        #expect(near(wc.point(atAbscissa: 5),  SIMD3(5, 0, 0)))    // mid first edge
        #expect(near(wc.point(atAbscissa: 10), SIMD3(10, 0, 0)))   // the corner
        #expect(near(wc.point(atAbscissa: 15), SIMD3(10, 5, 0)))   // mid second edge
        #expect(near(wc.point(atAbscissa: 20), SIMD3(10, 10, 0)))  // end
    }

    @Test("tangent flips direction across the corner")
    func tangentAcrossCorner() {
        guard let w = lWire(), let wc = WireCurve(w) else { #expect(Bool(false)); return }
        if let t1 = wc.tangent(atAbscissa: 5) { #expect(simd_distance(t1, SIMD3(1, 0, 0)) < 1e-6) }
        else { #expect(Bool(false), "tangent on first edge nil") }
        if let t2 = wc.tangent(atAbscissa: 15) { #expect(simd_distance(t2, SIMD3(0, 1, 0)) < 1e-6) }
        else { #expect(Bool(false), "tangent on second edge nil") }
    }

    @Test("even arc-length sampling yields the requested count")
    func evenSampling() {
        guard let w = lWire(), let wc = WireCurve(w) else { #expect(Bool(false)); return }
        let n = 20
        let pts = (0...n).compactMap { wc.point(atAbscissa: wc.length * Double($0) / Double(n)) }
        #expect(pts.count == n + 1)
    }

    @Test("points(count:) returns equally-spaced points incl. endpoints")
    func uniformPoints() {
        guard let w = lWire(), let wc = WireCurve(w) else { #expect(Bool(false)); return }
        let pts = wc.points(count: 5)   // abscissae 0,5,10,15,20 on a length-20 wire
        #expect(pts.count == 5)
        if pts.count == 5 {
            #expect(simd_distance(pts.first!, SIMD3(0, 0, 0)) < 1e-6)
            #expect(simd_distance(pts[2], SIMD3(10, 0, 0)) < 1e-6)   // the corner
            #expect(simd_distance(pts.last!, SIMD3(10, 10, 0)) < 1e-6)
        }
        #expect(wc.points(count: 1).isEmpty)   // need >= 2
    }
}

// #211/#212: EdgeCurve — single-edge arc-length adaptor.
@Suite("Issue #211/#212 — EdgeCurve arc-length adaptor")
struct Issue211EdgeCurve {
    private func anEdge() -> Edge? {
        Shape.box(width: 10, height: 10, depth: 10)?.edges(where: { _ in true }).first
    }

    @Test("length and endpoint sampling on a box edge")
    func lengthAndSampling() {
        guard let e = anEdge(), let ec = EdgeCurve(e) else { #expect(Bool(false)); return }
        #expect(abs(ec.length - 10.0) < 1e-6)               // box side
        let pts = ec.points(count: 3)
        #expect(pts.count == 3)
        // mid-abscissa point lies on the edge
        #expect(ec.point(atAbscissa: ec.length / 2) != nil)
        // unit tangent
        if let t = ec.tangent(atAbscissa: ec.length / 2) {
            #expect(abs(simd_length(t) - 1.0) < 1e-6)
        } else { #expect(Bool(false), "tangent nil") }
    }
}
