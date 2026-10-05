import Testing
import simd

@testable import OCCTSwift

/// #2862, the surface half. `Standard_RangeError_Raise_if(N < 0, ...)` sits in a `.cxx` for every
/// class implementing `IsCNu`/`IsCNv` behind these wrappers, so the pinned Release kernel compiles it
/// out and `isCNu(-1)` returned `true`.
///
/// The refusal is `false`, which is what these wrappers already
/// return for a null handle; the in-range answer is asserted alongside it.
@Suite("#2862: negative continuity order on Surface")
struct Issue2862NegativeContinuityOrderSurfaceTests {

    /// Written as one test walking a list rather than @Test(arguments:), because an argument element
    /// pairing a reference-counted member with a 32-byte builtin vector cannot be written at all
    /// (swiftlang/swift#91639, see CLAUDE.md).
    private let negativeOrders = [-1, -2, -1000, Int(Int32.min)]

    @Test("isCNu and isCNv answer a valid order and refuse a negative one")
    func planeIsCN() {
        guard let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)) else {
            Issue.record("Surface.plane returned nil")
            return
        }
        #expect(plane.isCNu(0))
        #expect(plane.isCNu(3))
        #expect(plane.isCNv(3))
        for n in negativeOrders {
            #expect(!plane.isCNu(n), "isCNu(\(n)) returned true")
            #expect(!plane.isCNv(n), "isCNv(\(n)) returned true")
        }
    }

    @Test("bezierIsCNu and bezierIsCNv answer a valid order and refuse a negative one")
    func bezierIsCN() {
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(0, 5, 0), SIMD3(0, 10, 0)],
            [SIMD3(5, 0, 0), SIMD3(5, 5, 1), SIMD3(5, 10, 0)],
            [SIMD3(10, 0, 0), SIMD3(10, 5, 0), SIMD3(10, 10, 0)],
        ]
        guard let surf = Surface.bezier(poles: poles) else {
            Issue.record("Surface.bezier returned nil")
            return
        }
        #expect(surf.bezierIsCNu(2))
        #expect(surf.bezierIsCNv(2))
        for n in negativeOrders {
            #expect(!surf.bezierIsCNu(n), "bezierIsCNu(\(n)) returned true")
            #expect(!surf.bezierIsCNv(n), "bezierIsCNv(\(n)) returned true")
        }
    }
}
