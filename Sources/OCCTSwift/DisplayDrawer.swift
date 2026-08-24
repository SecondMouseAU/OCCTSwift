import Foundation
import OCCTBridge

/// Display attribute controller for tessellation quality and wireframe rendering.
///
/// Wraps OCCT's `Prs3d_Drawer`, which controls how shapes are tessellated
/// and displayed. In a Metal renderer, these settings affect mesh generation
/// quality and which edge types are extracted.
public final class DisplayDrawer: @unchecked Sendable {
    internal let handle: OCCTDrawerRef

    /// Type of deflection control for tessellation.
    public enum DeflectionType: Int32, Sendable {
        /// Deviation is relative to the bounding box size.
        case relative = 0
        /// Deviation is an absolute distance value.
        case absolute = 1
    }

    public init() {
        handle = OCCTDrawerCreate()
    }

    deinit {
        OCCTDrawerDestroy(handle)
    }

    // MARK: - Tessellation Quality

    /// Chordal deviation coefficient (relative to bounding box diagonal).
    ///
    /// Lower values produce finer tessellation. Default is approximately 0.001.
    /// Only applies when ``deflectionType`` is `.relative`.
    public var deviationCoefficient: Double {
        get { OCCTDrawerGetDeviationCoefficient(handle) }
        set { OCCTDrawerSetDeviationCoefficient(handle, newValue) }
    }

    /// Angular deviation in radians.
    ///
    /// Controls how finely curved surfaces are approximated.
    /// Default is approximately 0.35 radians (20 degrees).
    public var deviationAngle: Double {
        get { OCCTDrawerGetDeviationAngle(handle) }
        set { OCCTDrawerSetDeviationAngle(handle, newValue) }
    }

    /// Maximal chordal deviation as an absolute distance.
    ///
    /// The maximum distance between the tessellation and the actual surface.
    /// Only applies when ``deflectionType`` is `.absolute`.
    public var maximalChordialDeviation: Double {
        get { OCCTDrawerGetMaximalChordialDeviation(handle) }
        set { OCCTDrawerSetMaximalChordialDeviation(handle, newValue) }
    }

    /// Type of deflection control.
    ///
    /// - `.relative`: Deviation is computed relative to the bounding box size.
    /// - `.absolute`: Deviation is a fixed distance value.
    public var deflectionType: DeflectionType {
        get { DeflectionType(rawValue: OCCTDrawerGetTypeOfDeflection(handle)) ?? .relative }
        set { OCCTDrawerSetTypeOfDeflection(handle, newValue.rawValue) }
    }

    /// Whether automatic triangulation is enabled.
    ///
    /// Default is `true`.
    public var autoTriangulation: Bool {
        get { OCCTDrawerGetAutoTriangulation(handle) }
        set { OCCTDrawerSetAutoTriangulation(handle, newValue) }
    }

    // MARK: - Isolines and Discretisation

    /// Whether iso-parameter lines are drawn on triangulated surfaces.
    public var isoOnTriangulation: Bool {
        get { OCCTDrawerGetIsoOnTriangulation(handle) }
        set { OCCTDrawerSetIsoOnTriangulation(handle, newValue) }
    }

    /// Number of discretisation points for curve approximation.
    ///
    /// Default is 30.
    public var discretisation: Int32 {
        get { OCCTDrawerGetDiscretisation(handle) }
        set { OCCTDrawerSetDiscretisation(handle, newValue) }
    }

    // MARK: - Edge Display

    /// Whether face boundary edges are drawn.
    ///
    /// Default is `false`.
    ///
    /// When enabled, edges at face boundaries (where two faces meet)
    /// are included in wireframe rendering.
    public var faceBoundaryDraw: Bool {
        get { OCCTDrawerGetFaceBoundaryDraw(handle) }
        set { OCCTDrawerSetFaceBoundaryDraw(handle, newValue) }
    }

    /// Whether wireframe edges are drawn.
    ///
    /// Default is `true`.
    public var wireDraw: Bool {
        get { OCCTDrawerGetWireDraw(handle) }
        set { OCCTDrawerSetWireDraw(handle, newValue) }
    }
}
