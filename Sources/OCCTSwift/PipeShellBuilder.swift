import Foundation
import simd
import OCCTBridge

/// Transition mode for pipe shell construction.
public enum PipeShellTransition: Int32, Sendable {
    case modified = 0
    case right = 1
    case round = 2
}

/// Builder for sweeping a profile along a spine wire with advanced control.
public final class PipeShellBuilder: @unchecked Sendable {
    private let ref: OCCTPipeShellRef

    /// Create a pipe shell builder from a spine wire.
    public init?(spine: Shape) {
        guard let r = OCCTPipeShellCreate(spine.handle) else { return nil }
        ref = r
    }

    deinit { OCCTPipeShellRelease(ref) }

    /// Set Frenet trihedron mode.
    public func setFrenet(_ frenet: Bool = true) {
        OCCTPipeShellSetFrenet(ref, frenet)
    }

    /// Set discrete trihedron mode.
    public func setDiscrete() {
        OCCTPipeShellSetDiscrete(ref)
    }

    /// Set fixed binormal direction.
    public func setFixed(binormal: SIMD3<Double>) {
        OCCTPipeShellSetFixed(ref, binormal.x, binormal.y, binormal.z)
    }

    /// Add a profile (wire or vertex) at the current location.
    public func add(profile: Shape) {
        OCCTPipeShellAdd(ref, profile.handle)
    }

    /// Add a profile at a specific vertex on the spine.
    public func add(profile: Shape, atVertex vertex: Shape) {
        OCCTPipeShellAddAtVertex(ref, profile.handle, vertex.handle)
    }

    /// Set a profile with a scaling law.
    public func setLaw(profile: Shape, law: LawFunction) {
        OCCTPipeShellSetLaw(ref, profile.handle, law.handle)
    }

    /// Set tolerances.
    public func setTolerance(tol3d: Double, boundTol: Double, tolAngular: Double) {
        OCCTPipeShellSetTolerance(ref, tol3d, boundTol, tolAngular)
    }

    /// Set transition mode.
    public func setTransition(_ mode: PipeShellTransition) {
        OCCTPipeShellSetTransition(ref, mode.rawValue)
    }

    /// Build the pipe shell.
    @discardableResult
    public func build() -> Bool {
        OCCTPipeShellBuild(ref)
    }

    /// Get the resulting shape.
    public var shape: Shape? {
        guard let h = OCCTPipeShellShape(ref) else { return nil }
        return Shape(handle: h)
    }

    /// Make the result into a solid.
    @discardableResult
    public func makeSolid() -> Bool {
        OCCTPipeShellMakeSolid(ref)
    }

    /// Get the approximation error.
    public var error: Double {
        OCCTPipeShellError(ref)
    }

    /// Check if the pipe shell is ready to build.
    public var isReady: Bool {
        OCCTPipeShellIsReady(ref)
    }
}

extension PipeShellBuilder {
    /// Set maximum degree for pipe shell approximation.
    public func setMaxDegree(_ maxDeg: Int) {
        OCCTPipeShellSetMaxDegree(ref, Int32(maxDeg))
    }

    /// Set maximum number of segments for pipe shell approximation.
    public func setMaxSegments(_ maxSeg: Int) {
        OCCTPipeShellSetMaxSegments(ref, Int32(maxSeg))
    }

    /// Force C1 approximation on pipe shell.
    public func setForceApproxC1(_ force: Bool) {
        OCCTPipeShellSetForceApproxC1(ref, force)
    }

    /// Enable or disable build history tracking.
    ///
    /// History is disabled by default to avoid a segfault on closed spine+profile
    /// geometries (OCCT bug in `BRepFill_PipeShell::BuildHistory`). Enable only
    /// if you need `generated`/`modified`/`isDeleted` queries on the result.
    public func setBuildHistory(_ enabled: Bool) {
        OCCTPipeShellSetBuildHistory(ref, enabled)
    }

    /// Get the error on the generated surface.
    public var errorOnSurface: Double {
        OCCTPipeShellErrorOnSurface(ref)
    }

    /// Get the first shape of the pipe shell (start cap).
    public var firstShape: Shape? {
        guard let h = OCCTPipeShellFirstShape(ref) else { return nil }
        return Shape(handle: h)
    }

    /// Get the last shape of the pipe shell (end cap).
    public var lastShape: Shape? {
        guard let h = OCCTPipeShellLastShape(ref) else { return nil }
        return Shape(handle: h)
    }
}

/// Status of a pipe shell build operation.
public enum PipeShellStatus: Int32, Sendable {
    case ok = 0
    case notOk = 1
    case planeNotIntersectGuide = 2
    case impossibleContact = 3
}

extension PipeShellBuilder {
    /// Get the current build status.
    public var status: PipeShellStatus {
        PipeShellStatus(rawValue: OCCTPipeShellGetStatus(ref)) ?? .notOk
    }

    /// Simulate the pipe shell with a given number of sections.
    /// Returns an array of simulated section shapes (wire cross-sections along the spine).
    public func simulate(numberOfSections: Int) -> [Shape] {
        var count: Int32 = 0
        guard let shapes = OCCTPipeShellSimulate(ref, Int32(numberOfSections), &count) else { return [] }
        // Transfer ownership of each shape to Swift Shape objects, then free only the array
        var result: [Shape] = []
        for i in 0..<Int(count) {
            if let s = shapes[i] {
                result.append(Shape(handle: s))
            }
        }
        free(shapes) // Free only the pointer array, not the shapes themselves
        return result
    }
}
