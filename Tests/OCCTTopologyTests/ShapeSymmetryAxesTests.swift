import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.137 Shape.symmetryAxes")
struct ShapeSymmetryAxesTests {
    @Test("Cylinder reports one rotational symmetry axis")
    func cylinderSymmetry() {
        guard let cyl = Shape.cylinder(radius: 5, height: 20) else {
            Issue.record("cylinder nil")
            return
        }
        let axes = cyl.symmetryAxes()
        #expect(axes.count == 1)
        if let a = axes.first {
            #expect(a.kind == ShapeAxis.Kind.symmetry)
        }
    }

    @Test("Sphere reports three symmetry axes (spherical symmetry)")
    func sphereSymmetry() {
        guard let sphere = Shape.sphere(radius: 10) else {
            Issue.record("sphere nil")
            return
        }
        let axes = sphere.symmetryAxes()
        #expect(axes.count == 3)
    }

    @Test("Asymmetric box reports no symmetry axis")
    func asymmetricBoxNoSymmetry() {
        guard let box = Shape.box(width: 10, height: 7, depth: 3) else {
            Issue.record("box nil")
            return
        }
        #expect(box.symmetryAxes().isEmpty)
    }

    // #726/#763: same defect as `Shape.revolutionAxes`' extent (see the sibling test in
    // OCCTSurfaceTests.swift): extentMin/extentMax/hasExtent were hardcoded 0/0/false on every
    // call here too. The symmetry axis's own extent is measured over the WHOLE SHAPE's bounding
    // box (not one face), from the axis origin (the shape's centre of mass, per
    // `GProp_GProps::CentreOfMass`). A cylinder's centroid sits at half its height, so its axial
    // span should read as symmetric about 0: -10...10 for a height-20 cylinder, independent of
    // which sign OCCT reports the axis direction in.
    @Test("Cylinder's symmetry axis reports a real, non-nil extent centred on the centroid")
    func cylinderSymmetryAxisHasExtent() {
        guard let cyl = Shape.cylinder(radius: 5, height: 20) else {
            Issue.record("cylinder nil")
            return
        }
        let axes = cyl.symmetryAxes()
        #expect(axes.count == 1)
        guard let a = axes.first, let extent = a.extent else {
            Issue.record("expected a non-nil extent on the cylinder's symmetry axis")
            return
        }
        #expect(abs((extent.upperBound - extent.lowerBound) - 20) < 1e-6)
        #expect(abs(extent.lowerBound + 10) < 1e-6)
        #expect(abs(extent.upperBound - 10) < 1e-6)
    }
}
