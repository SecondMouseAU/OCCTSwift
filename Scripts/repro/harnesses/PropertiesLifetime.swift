// Reproducer for #965: the 19 `*Properties` value views borrowed their parent's native handle
// without retaining it, so a view outliving its parent read freed memory. The writeup, and the
// captured output of runs against the unfixed and fixed trees, live in
// Scripts/repro/965-properties-use-after-free/.
//
// Run: OCCTSWIFT_LOCAL=1 swift run Harnesses 965-properties-lifetime
//
// Phase 1 reports the mechanism and never touches freed memory, so it always completes. Phase 2
// performs the dangling reads and against the unfixed tree ends the process with SIGSEGV, which
// is why each read announces itself first. Set OCCT965_READ to one of `chained`, `escaped`,
// `churned` or `control` to run a single phase 2 read, so the ones after the first crash can be
// characterised too.

import Foundation
import OCCTSwift

enum PropertiesLifetime {

    // MARK: - Reporting

    /// Prints immediately and flushes, so a crash leaves the log naming the read that caused it.
    fileprivate static func say(_ text: String) {
        print(text)
        fflush(stdout)
    }

    /// Which phase 2 reads to run, from `OCCT965_READ`; all of them when the variable is unset.
    fileprivate static func wants(_ read: String) -> Bool {
        guard let only = ProcessInfo.processInfo.environment["OCCT965_READ"] else { return true }
        return only == read
    }

    // MARK: - Escaping the parent

    // Each of these takes the view the way a caller would, lets the parent go out of scope, and
    // hands back both the view and a probe for whether the parent survived. Before the fix the
    // probe answers false and the view is left pointing at a released handle.

    fileprivate static func escapedCircle3D() -> (Curve3D.CircleProperties?, () -> Bool) {
        weak var parent: Curve3D?
        var view: Curve3D.CircleProperties?
        do {
            guard let curve = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)
            else { return (nil, { false }) }
            parent = curve
            view = curve.circleProperties
        }
        return (view, { parent != nil })
    }

    fileprivate static func escapedCircle2D() -> (Curve2D.CircleProperties?, () -> Bool) {
        weak var parent: Curve2D?
        var view: Curve2D.CircleProperties?
        do {
            guard let curve = Curve2D.circle(center: .zero, radius: 7) else {
                return (nil, { false })
            }
            parent = curve
            view = curve.circleProperties
        }
        return (view, { parent != nil })
    }

    fileprivate static func escapedSphere() -> (Surface.SphereProperties?, () -> Bool) {
        weak var parent: Surface?
        var view: Surface.SphereProperties?
        do {
            guard let surface = Surface.sphere(center: .zero, radius: 11) else {
                return (nil, { false })
            }
            parent = surface
            view = surface.sphereProperties
        }
        return (view, { parent != nil })
    }

    // MARK: - Phase 1: the mechanism, without reading freed memory

    fileprivate static func reportLifetimes() {
        say("Phase 1: does taking a view keep the parent alive? (no dangling read here)")

        let (curve3DView, curve3DParentAlive) = escapedCircle3D()
        let (curve2DView, curve2DParentAlive) = escapedCircle2D()
        let (surfaceView, surfaceParentAlive) = escapedSphere()

        say("  Curve3D.circleProperties  parent alive: \(curve3DParentAlive())")
        say("  Curve2D.circleProperties  parent alive: \(curve2DParentAlive())")
        say("  Surface.sphereProperties  parent alive: \(surfaceParentAlive())")

        withExtendedLifetime((curve3DView, curve2DView, surfaceView)) {}
    }

    // MARK: - Phase 2: the reads

    fileprivate static func chainedRead() {
        say("  chained  edge.curve3D?.circleProperties.radius, expecting 5.0")
        guard let wire = Wire.circle(radius: 5), let edge = wire.edges().first else { return }
        let radius = edge.curve3D?.circleProperties.radius
        say("  chained  = \(String(describing: radius))")
    }

    fileprivate static func escapedReads() {
        let (view3D, _) = escapedCircle3D()
        say("  escaped  Curve3D circle radius, expecting 5.0")
        say("  escaped  = \(String(describing: view3D?.radius))")

        let (view2D, _) = escapedCircle2D()
        say("  escaped  Curve2D circle radius, expecting 7.0")
        say("  escaped  = \(String(describing: view2D?.radius))")

        let (viewSurface, _) = escapedSphere()
        say("  escaped  Surface sphere radius, expecting 11.0")
        say("  escaped  = \(String(describing: viewSurface?.radius))")
    }

    fileprivate static func churnedReads() {
        // Allocator churn between the release and the read, to encourage reuse of the freed block.
        let (view3D, _) = escapedCircle3D()
        var ballast: [Curve3D] = []
        for i in 1...400 {
            if let c = Curve3D.circle(
                center: .zero, normal: SIMD3(0, 0, 1), radius: Double(1000 + i))
            {
                ballast.append(c)
            }
        }
        say("  churned  Curve3D circle radius after 400 allocations, expecting 5.0")
        say("  churned  = \(String(describing: view3D?.radius))")
        withExtendedLifetime(ballast) {}
    }

    fileprivate static func controlReads() {
        // The workaround the issue documents: bind the parent to a local so it outlives the read.
        if let curve = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5) {
            say("  control  Curve3D circle radius = \(curve.circleProperties.radius), expecting 5.0")
        }
        if let curve = Curve2D.circle(center: .zero, radius: 7) {
            say("  control  Curve2D circle radius = \(curve.circleProperties.radius), expecting 7.0")
        }
        if let surface = Surface.sphere(center: .zero, radius: 11) {
            say(
                "  control  Surface sphere radius = \(surface.sphereProperties.radius), "
                    + "expecting 11.0")
        }
    }

    // MARK: - Entry point

    static func run() {
        say("#965: do the *Properties value views keep their parent alive?")
        say("")
        reportLifetimes()
        say("")
        say("Phase 2: reading through the view. Before the fix these read a released handle.")
        if wants("control") { controlReads() }
        if wants("chained") { chainedRead() }
        if wants("escaped") { escapedReads() }
        if wants("churned") { churnedReads() }
        say("")
        say("Done. A `parent alive: false` in phase 1 is the defect on its own: the view outlived")
        say("the object whose deinit released the handle it reads, so whatever phase 2 printed")
        say("under it came from freed memory, correct-looking or not.")
    }
}
