import Foundation
import Testing
import simd

@testable import OCCTSwift

/// Regression cover for #965 on `Surface`, the third of the three parents whose `*Properties`
/// accessors handed back a value storing the parent's native handle without retaining it. The
/// defect and its measurement are identical to `Curve3D`'s; see
/// `Tests/OCCTCurveTests/Issue965Curve3DPropertyLifetimeTests.swift` and
/// `Scripts/repro/965-properties-use-after-free/`.
@Suite("Surface *Properties views keep their parent alive (#965)")
struct Issue965SurfacePropertyLifetimeTests {

    private static let radius = 11.0

    private func makeSphere() -> Surface? {
        Surface.sphere(center: .zero, radius: Self.radius)
    }

    /// Takes a view from a parent nothing else holds, lets the parent's scope end, and reports
    /// whether the parent is still alive with only the view referring to it.
    private func takeView<V>(_ take: (Surface) -> V) -> (view: V, parentAlive: Bool)? {
        weak var weakParent: Surface?
        var taken: V?
        do {
            guard let parent = makeSphere() else { return nil }
            weakParent = parent
            taken = take(parent)
        }
        guard let taken else { return nil }
        return (taken, weakParent != nil)
    }

    @Test("every Surface *Properties accessor keeps its parent alive")
    func everyAccessorKeepsItsParentAlive() {
        let accessors: [(name: String, take: (Surface) -> Any)] = [
            ("planeProperties", { $0.planeProperties }),
            ("sphereProperties", { $0.sphereProperties }),
            ("torusProperties", { $0.torusProperties }),
            ("cylinderProperties", { $0.cylinderProperties }),
            ("coneProperties", { $0.coneProperties }),
            ("sweptProperties", { $0.sweptProperties }),
            ("bezierProperties", { $0.bezierProperties }),
        ]
        #expect(accessors.count == 7, "Surface gained or lost a *Properties accessor")

        for accessor in accessors {
            guard let result = takeView(accessor.take) else {
                Issue.record("could not build the sphere fixture for \(accessor.name)")
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
        let result = try #require(takeView { $0.sphereProperties })
        #expect(result.parentAlive)
        #expect(result.view.radius == Self.radius)
        #expect(result.view.center == SIMD3(0, 0, 0))
    }

    @Test("a view outliving its parent survives 400 intervening allocations")
    func escapedViewSurvivesAllocatorChurn() throws {
        let result = try #require(takeView { $0.sphereProperties })
        var ballast: [Surface] = []
        for i in 1...400 {
            if let s = Surface.sphere(center: .zero, radius: Double(1000 + i)) { ballast.append(s) }
        }
        #expect(result.view.radius == Self.radius)
        withExtendedLifetime(ballast) {}
    }

    /// The fix reads the handle through the owner rather than storing a copy of it. A setter
    /// proves the two still name the same OCCT object.
    @Test("a setter called through a view is visible on the parent")
    func setterThroughAViewReachesTheParent() throws {
        let surface = try #require(makeSphere())
        #expect(surface.sphereProperties.setRadius(13))
        #expect(surface.sphereProperties.radius == 13)
    }
}
