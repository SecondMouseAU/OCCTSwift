import Testing
import simd

@testable import OCCTSwift

/// #2862: `Standard_RangeError_Raise_if(N < 0, ...)` sits in a `.cxx` for all eight classes that
/// implement `IsCN` behind our wrappers, so the pinned Release kernel compiles it out of every one of
/// them and `isCN(-1)` returned `true`, answered by `Geom_BSplineCurve_1.cxx`'s own `N <= 0` test
/// rather than by the class agreeing. No fault, no fabricated number, just a `true` that is not a
/// statement about the geometry.
///
/// The refusal is `false`, which is what these wrappers already return for a null handle. The
/// in-range answer is asserted alongside it, so a guard that refuses everything fails too.
@Suite("#2862: negative continuity order")
struct Issue2862NegativeContinuityOrderTests {

    /// Written as one test walking a list rather than @Test(arguments:), because an argument element
    /// pairing a reference-counted member with a 32-byte builtin vector cannot be written at all
    /// (swiftlang/swift#91639, see CLAUDE.md).
    private let negativeOrders = [-1, -2, -1000, Int(Int32.min)]

    @Test("Curve3D.isCN answers a valid order and refuses a negative one")
    func curve3DIsCN() {
        guard let seg = Curve3D.segment(from: .zero, to: SIMD3(10, 0, 0)) else {
            Issue.record("Curve3D.segment returned nil")
            return
        }
        #expect(seg.isCN(0))
        #expect(seg.isCN(3))
        for n in negativeOrders {
            #expect(!seg.isCN(n), "Curve3D.isCN(\(n)) returned true")
        }
    }

    @Test("Curve3D.bezierIsCN answers a valid order and refuses a negative one")
    func curve3DBezierIsCN() {
        guard let bez = Curve3D.bezier(poles: [SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(3, 0, 0)])
        else {
            Issue.record("Curve3D.bezier returned nil")
            return
        }
        #expect(bez.bezierIsCN(2))
        for n in negativeOrders {
            #expect(!bez.bezierIsCN(n), "Curve3D.bezierIsCN(\(n)) returned true")
        }
    }

    @Test("Curve2D.isCN and bsplineIsCN answer a valid order and refuse a negative one")
    func curve2DIsCN() {
        guard let seg = Curve2D.segment(from: .zero, to: SIMD2(10, 0)) else {
            Issue.record("Curve2D.segment returned nil")
            return
        }
        #expect(seg.isCN(0))
        #expect(seg.isCN(3))
        for n in negativeOrders {
            #expect(!seg.isCN(n), "Curve2D.isCN(\(n)) returned true")
        }
        guard
            let bsp = Curve2D.interpolate(through: [
                SIMD2(0, 0), SIMD2(1, 2), SIMD2(3, 2), SIMD2(4, 0),
            ])
        else { return }
        #expect(bsp.bsplineIsCN(0))
        for n in negativeOrders {
            #expect(!bsp.bsplineIsCN(n), "Curve2D.bsplineIsCN(\(n)) returned true")
        }
    }
}
