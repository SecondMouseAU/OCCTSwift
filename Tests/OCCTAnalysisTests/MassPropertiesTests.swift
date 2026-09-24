import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1729-#1732: each test used to sit inside `if let`, so a nil fixture passed, and three of the four
// asserted only a sign (`> 0`) or a unit length, which any nonzero moment or any unit vector
// satisfies. Every expected value below is the one BRepGProp reports for the same fixture, measured
// in Scripts/repro/766-mass-properties/transcript.txt.

@Suite("v0.114.0 - Mass Properties")
struct MassPropertiesTests {

    @Test func linearProperties() throws {
        let rect = try #require(Wire.rectangle(width: 10, height: 10))
        let wireShape = try #require(Shape.fromWire(rect))
        let lp = try #require(wireShape.linearProperties())
        #expect(abs(lp.length - 40.0) < 1e-9)  // perimeter of 10x10 rect
        // The rectangle is centred on the origin, so its centre of mass is too.
        #expect(simd_length(lp.centerOfMass) < 1e-9)
    }

    @Test func momentOfInertia() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let moi = try #require(box.momentOfInertia())
        // A 10x10x10 cube of unit density about its own centre: m (b^2 + c^2) / 12 = 1000 * 200 / 12.
        let expected = 1000.0 * 200.0 / 12.0
        #expect(abs(moi.ixx - expected) < 1e-6)
        #expect(abs(moi.iyy - expected) < 1e-6)
        #expect(abs(moi.izz - expected) < 1e-6)
        #expect(abs(moi.ixy) < 1e-6)
        #expect(abs(moi.ixz) < 1e-6)
        #expect(abs(moi.iyz) < 1e-6)
    }

    @Test func principalAxes() throws {
        // Not the cube: a cube's inertia is isotropic, so every orthonormal frame is a principal
        // frame and the axes are whatever math_Jacobi settles on. 10x20x30 has three distinct
        // moments (650000, 500000, 250000) and so exactly one principal frame, the box's own axes.
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let pa = try #require(box.principalAxes())
        #expect(abs(abs(pa.axis1.x) - 1.0) < 1e-9)
        #expect(abs(abs(pa.axis2.y) - 1.0) < 1e-9)
        #expect(abs(abs(pa.axis3.z) - 1.0) < 1e-9)
        #expect(abs(simd_dot(pa.axis1, pa.axis2)) < 1e-9)
        #expect(abs(simd_dot(pa.axis2, pa.axis3)) < 1e-9)
    }

    @Test func radiusOfGyration() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let rog = try #require(
            box.radiusOfGyration(axisOrigin: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1)))
        // sqrt(Izz / m) = sqrt((1000 * 200 / 12) / 1000) = sqrt(50 / 3)
        #expect(abs(rog - (50.0 / 3.0).squareRoot()) < 1e-9)
    }
}
