import Testing
import Foundation
import simd
@testable import OCCTSwift

/// Regression cover for #965: every `*Properties` accessor handed back a value that stored the
/// parent's native handle without retaining it, so a view outliving its parent read memory
/// `deinit` had already released. Against the unfixed tree `chainedAccessOnATemporaryParent`
/// ends the whole test process with SIGSEGV, and `everyAccessorKeepsItsParentAlive` fails
/// deterministically without touching freed memory at all, which is why both are here: the
/// second one is the assertion that still reports when the first one cannot.
///
/// The reproducer and the AddressSanitizer report naming `Curve3D.deinit` as the free are in
/// `Scripts/repro/965-properties-use-after-free/`.
@Suite("Curve3D *Properties views keep their parent alive (#965)")
struct Issue965Curve3DPropertyLifetimeTests {

    private static let radius = 5.0

    private func makeCircle() -> Curve3D? {
        Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: Self.radius)
    }

    /// Takes a view from a parent nothing else holds, lets the parent's scope end, and reports
    /// whether the parent is still alive with only the view referring to it.
    private func takeView<V>(_ take: (Curve3D) -> V) -> (view: V, parentAlive: Bool)? {
        weak var weakParent: Curve3D?
        var taken: V?
        do {
            guard let parent = makeCircle() else { return nil }
            weakParent = parent
            taken = take(parent)
        }
        guard let taken else { return nil }
        return (taken, weakParent != nil)
    }

    // MARK: - The issue's own spelling

    /// `Edge.curve3D` builds a fresh `Curve3D` per read, so nothing holds the parent of this
    /// access. This is the form the issue reports, and the form `Edge.curve3D`'s own doc comment
    /// recommends.
    @Test("the chained access the issue reports reads the right radius")
    func chainedAccessOnATemporaryParent() throws {
        let wire = try #require(Wire.circle(radius: Self.radius))
        let edge = try #require(wire.edges().first)
        #expect(edge.curve3D?.circleProperties.radius == Self.radius)
    }

    // MARK: - Every accessor, not just the one in the report

    @Test("every Curve3D *Properties accessor keeps its parent alive")
    func everyAccessorKeepsItsParentAlive() {
        let accessors: [(name: String, take: (Curve3D) -> Any)] = [
            ("circleProperties", { $0.circleProperties }),
            ("ellipseProperties", { $0.ellipseProperties }),
            ("hyperbolaProperties", { $0.hyperbolaProperties }),
            ("parabolaProperties", { $0.parabolaProperties }),
            ("lineProperties", { $0.lineProperties }),
        ]
        #expect(accessors.count == 5, "Curve3D gained or lost a *Properties accessor")

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

    // MARK: - Reading through a view that outlived its parent

    @Test("a view outliving its parent still reads the right values")
    func escapedViewReadsCorrectValues() throws {
        let result = try #require(takeView { $0.circleProperties })
        #expect(result.parentAlive)
        #expect(result.view.radius == Self.radius)
        #expect(result.view.center == SIMD3(0, 0, 0))
    }

    /// Allocator churn between the parent's release and the read: before the fix this is where a
    /// use-after-free that happened to survive would stop being survivable.
    @Test("a view outliving its parent survives 400 intervening allocations")
    func escapedViewSurvivesAllocatorChurn() throws {
        let result = try #require(takeView { $0.circleProperties })
        var ballast: [Curve3D] = []
        for i in 1...400 {
            if let c = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: Double(1000 + i)) {
                ballast.append(c)
            }
        }
        #expect(result.view.radius == Self.radius)
        withExtendedLifetime(ballast) {}
    }

    // MARK: - Mutation through a view still reaches the parent

    /// The fix reads the handle through the owner rather than storing a copy of it. A setter
    /// proves the two still name the same OCCT object.
    @Test("a setter called through a view is visible on the parent")
    func setterThroughAViewReachesTheParent() throws {
        let curve = try #require(makeCircle())
        #expect(curve.circleProperties.setRadius(8))
        #expect(curve.circleProperties.radius == 8)
    }
}
