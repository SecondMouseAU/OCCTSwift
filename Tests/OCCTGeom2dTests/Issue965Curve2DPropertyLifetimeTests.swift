import Testing
import Foundation
import simd
@testable import OCCTSwift

/// Regression cover for #965 on `Curve2D`, the second of the three parents whose `*Properties`
/// accessors handed back a value storing the parent's native handle without retaining it. The
/// defect and its measurement are identical to `Curve3D`'s; see
/// `Tests/OCCTCurveTests/Issue965Curve3DPropertyLifetimeTests.swift` and
/// `Scripts/repro/965-properties-use-after-free/`.
@Suite("Curve2D *Properties views keep their parent alive (#965)")
struct Issue965Curve2DPropertyLifetimeTests {

    private static let radius = 7.0

    private func makeCircle() -> Curve2D? {
        Curve2D.circle(center: .zero, radius: Self.radius)
    }

    /// Takes a view from a parent nothing else holds, lets the parent's scope end, and reports
    /// whether the parent is still alive with only the view referring to it.
    private func takeView<V>(_ take: (Curve2D) -> V) -> (view: V, parentAlive: Bool)? {
        weak var weakParent: Curve2D?
        var taken: V?
        do {
            guard let parent = makeCircle() else { return nil }
            weakParent = parent
            taken = take(parent)
        }
        guard let taken else { return nil }
        return (taken, weakParent != nil)
    }

    @Test("every Curve2D *Properties accessor keeps its parent alive")
    func everyAccessorKeepsItsParentAlive() {
        let accessors: [(name: String, take: (Curve2D) -> Any)] = [
            ("circleProperties", { $0.circleProperties }),
            ("ellipseProperties", { $0.ellipseProperties }),
            ("hyperbolaProperties", { $0.hyperbolaProperties }),
            ("parabolaProperties", { $0.parabolaProperties }),
            ("lineProperties", { $0.lineProperties }),
            ("offsetProperties", { $0.offsetProperties }),
            ("bezierProperties", { $0.bezierProperties }),
        ]
        #expect(accessors.count == 7, "Curve2D gained or lost a *Properties accessor")

        for accessor in accessors {
            guard let result = takeView(accessor.take) else {
                Issue.record("could not build the circle fixture for \(accessor.name)")
                continue
            }
            withExtendedLifetime(result.view) {
                #expect(
                    result.parentAlive,
                    "\(accessor.name) did not keep its parent alive, so its handle is released")
            }
        }
    }

    @Test("a view outliving its parent still reads the right values")
    func escapedViewReadsCorrectValues() throws {
        let result = try #require(takeView { $0.circleProperties })
        #expect(result.parentAlive)
        #expect(result.view.radius == Self.radius)
        #expect(result.view.center == SIMD2(0, 0))
    }

    @Test("a view outliving its parent survives 400 intervening allocations")
    func escapedViewSurvivesAllocatorChurn() throws {
        let result = try #require(takeView { $0.circleProperties })
        var ballast: [Curve2D] = []
        for i in 1...400 {
            if let c = Curve2D.circle(center: .zero, radius: Double(1000 + i)) { ballast.append(c) }
        }
        #expect(result.view.radius == Self.radius)
        withExtendedLifetime(ballast) {}
    }

    /// The fix reads the handle through the owner rather than storing a copy of it. A setter
    /// proves the two still name the same OCCT object.
    @Test("a setter called through a view is visible on the parent")
    func setterThroughAViewReachesTheParent() throws {
        let curve = try #require(makeCircle())
        #expect(curve.circleProperties.setRadius(9))
        #expect(curve.circleProperties.radius == 9)
    }
}
