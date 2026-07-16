import Foundation
import simd

// MARK: - ConstructionContext (#72 Phase 3)
//
// Document-level collection of named construction entities. Each entity gets a
// typed opaque ID on insertion; the context resolves entities on demand against
// any given TopologyGraph. Entities are stored by value — storage is lightweight
// and thread-safe via an internal lock.
//
// Persistence: the XCAF `CONSTRUCTION` layer hosts any shapes tagged as
// construction. Since we deliberately keep construction-entity *recipes* in
// Swift value storage (not as TopoDS_Shapes on the XDE tree), STEP round-trip
// preserves only the "this shape is construction" layer tag — the recipe
// structure is lost. Documented limitation matching FreeCAD's behaviour.

public final class ConstructionContext: @unchecked Sendable {
    public struct PlaneID: Sendable, Hashable {
        public let raw: UUID
        public init() { self.raw = UUID() }
    }
    public struct AxisID: Sendable, Hashable {
        public let raw: UUID
        public init() { self.raw = UUID() }
    }
    public struct PointID: Sendable, Hashable {
        public let raw: UUID
        public init() { self.raw = UUID() }
    }

    private let lock = NSLock()
    private var _planes: [PlaneID: (name: String?, entity: ConstructionPlane)] = [:]
    private var _axes: [AxisID: (name: String?, entity: ConstructionAxis)] = [:]
    private var _points: [PointID: (name: String?, entity: ConstructionPoint)] = [:]
    private var _orderedPlanes: [PlaneID] = []
    private var _orderedAxes: [AxisID] = []
    private var _orderedPoints: [PointID] = []

    public init() {}

    // MARK: - Insertion

    @discardableResult
    public func add(_ plane: ConstructionPlane, name: String? = nil) -> PlaneID {
        lock.lock(); defer { lock.unlock() }
        let id = PlaneID()
        _planes[id] = (name, plane)
        _orderedPlanes.append(id)
        return id
    }

    @discardableResult
    public func add(_ axis: ConstructionAxis, name: String? = nil) -> AxisID {
        lock.lock(); defer { lock.unlock() }
        let id = AxisID()
        _axes[id] = (name, axis)
        _orderedAxes.append(id)
        return id
    }

    @discardableResult
    public func add(_ point: ConstructionPoint, name: String? = nil) -> PointID {
        lock.lock(); defer { lock.unlock() }
        let id = PointID()
        _points[id] = (name, point)
        _orderedPoints.append(id)
        return id
    }

    // MARK: - Lookup

    public func plane(_ id: PlaneID) -> ConstructionPlane? {
        lock.lock(); defer { lock.unlock() }
        return _planes[id]?.entity
    }

    public func axis(_ id: AxisID) -> ConstructionAxis? {
        lock.lock(); defer { lock.unlock() }
        return _axes[id]?.entity
    }

    public func point(_ id: PointID) -> ConstructionPoint? {
        lock.lock(); defer { lock.unlock() }
        return _points[id]?.entity
    }

    public func name(_ id: PlaneID) -> String? {
        lock.lock(); defer { lock.unlock() }
        return _planes[id]?.name
    }

    public func name(_ id: AxisID) -> String? {
        lock.lock(); defer { lock.unlock() }
        return _axes[id]?.name
    }

    public func name(_ id: PointID) -> String? {
        lock.lock(); defer { lock.unlock() }
        return _points[id]?.name
    }

    public var allPlanes: [(id: PlaneID, name: String?, plane: ConstructionPlane)] {
        lock.lock(); defer { lock.unlock() }
        return _orderedPlanes.compactMap { id in
            _planes[id].map { (id: id, name: $0.name, plane: $0.entity) }
        }
    }

    public var allAxes: [(id: AxisID, name: String?, axis: ConstructionAxis)] {
        lock.lock(); defer { lock.unlock() }
        return _orderedAxes.compactMap { id in
            _axes[id].map { (id: id, name: $0.name, axis: $0.entity) }
        }
    }

    public var allPoints: [(id: PointID, name: String?, point: ConstructionPoint)] {
        lock.lock(); defer { lock.unlock() }
        return _orderedPoints.compactMap { id in
            _points[id].map { (id: id, name: $0.name, point: $0.entity) }
        }
    }

    // MARK: - Removal

    public func remove(plane id: PlaneID) {
        lock.lock(); defer { lock.unlock() }
        _planes.removeValue(forKey: id)
        _orderedPlanes.removeAll { $0 == id }
    }

    public func remove(axis id: AxisID) {
        lock.lock(); defer { lock.unlock() }
        _axes.removeValue(forKey: id)
        _orderedAxes.removeAll { $0 == id }
    }

    public func remove(point id: PointID) {
        lock.lock(); defer { lock.unlock() }
        _points.removeValue(forKey: id)
        _orderedPoints.removeAll { $0 == id }
    }

    public func removeAll() {
        lock.lock(); defer { lock.unlock() }
        _planes.removeAll()
        _axes.removeAll()
        _points.removeAll()
        _orderedPlanes.removeAll()
        _orderedAxes.removeAll()
        _orderedPoints.removeAll()
    }

    // MARK: - Resolution

    public func resolve(_ id: PlaneID, in graph: TopologyGraph) -> Result<Placement, ConstructionResolutionError> {
        guard let plane = self.plane(id) else {
            return .failure(.notApplicable("plane id \(id.raw) not registered"))
        }
        return graph.resolve(plane)
    }

    public func resolve(_ id: AxisID, in graph: TopologyGraph) -> Result<(origin: SIMD3<Double>, direction: SIMD3<Double>), ConstructionResolutionError> {
        guard let axis = self.axis(id) else {
            return .failure(.notApplicable("axis id \(id.raw) not registered"))
        }
        return graph.resolve(axis)
    }

    public func resolve(_ id: PointID, in graph: TopologyGraph) -> Result<SIMD3<Double>, ConstructionResolutionError> {
        guard let point = self.point(id) else {
            return .failure(.notApplicable("point id \(id.raw) not registered"))
        }
        return graph.resolve(point)
    }

    // MARK: - Diagnostics

    public struct BrokenEntities: Sendable {
        public let planes: [(id: PlaneID, error: ConstructionResolutionError)]
        public let axes: [(id: AxisID, error: ConstructionResolutionError)]
        public let points: [(id: PointID, error: ConstructionResolutionError)]

        public var isEmpty: Bool { planes.isEmpty && axes.isEmpty && points.isEmpty }
        public var totalCount: Int { planes.count + axes.count + points.count }
    }

    /// Inspect every registered entity against the given graph, return those that
    /// fail resolution. Useful for agent workflows to detect broken references
    /// after a model edit.
    public func allBroken(in graph: TopologyGraph) -> BrokenEntities {
        var brokenPlanes: [(id: PlaneID, error: ConstructionResolutionError)] = []
        var brokenAxes: [(id: AxisID, error: ConstructionResolutionError)] = []
        var brokenPoints: [(id: PointID, error: ConstructionResolutionError)] = []
        for entry in allPlanes {
            if case .failure(let e) = graph.resolve(entry.plane) {
                brokenPlanes.append((id: entry.id, error: e))
            }
        }
        for entry in allAxes {
            if case .failure(let e) = graph.resolve(entry.axis) {
                brokenAxes.append((id: entry.id, error: e))
            }
        }
        for entry in allPoints {
            if case .failure(let e) = graph.resolve(entry.point) {
                brokenPoints.append((id: entry.id, error: e))
            }
        }
        return BrokenEntities(planes: brokenPlanes, axes: brokenAxes, points: brokenPoints)
    }

    public var count: (planes: Int, axes: Int, points: Int) {
        lock.lock(); defer { lock.unlock() }
        return (_planes.count, _axes.count, _points.count)
    }
}

// MARK: - Document integration

extension Document {
    /// Per-document construction context. Lazy-associated; created on first access.
    ///
    /// Construction entities added to the context live alongside the document's
    /// shapes but are not part of the XDE shape tree — they're pure Swift-side
    /// recipes. For persistence guidance see ConstructionContext doc comments.
    public var constructionContext: ConstructionContext {
        if let existing = Self.constructionContextStorage.value(for: self) {
            return existing
        }
        let new = ConstructionContext()
        Self.constructionContextStorage.set(new, for: self)
        return new
    }

    /// Drop this document's associated construction context. Called from `Document.deinit`.
    ///
    /// This is not optional bookkeeping: the association is keyed on `ObjectIdentifier`, which is
    /// the instance pointer and is therefore only unique among *live* objects. If the entry
    /// outlives the document, the next `Document` allocated at the recycled address resolves to
    /// this one's context and silently inherits its entities (#277).
    internal func releaseConstructionContext() {
        Self.constructionContextStorage.clear(for: self)
    }

    // Associated storage for construction contexts, since Document is a final class we can't
    // extend with stored properties. Strongly keyed on ObjectIdentifier (the instance pointer);
    // entries are removed in `Document.deinit` via `releaseConstructionContext()` — see #277 for
    // why that cleanup is load-bearing rather than mere tidiness.
    fileprivate static let constructionContextStorage = DocumentAssociatedStorage<ConstructionContext>()
}

/// Side-table associating a value with an object, for final classes that can't take stored
/// properties via an extension.
///
/// - Important: keys are `ObjectIdentifier`, i.e. the raw instance pointer, which is unique only
///   among **live** objects. Owners MUST call ``clear(for:)`` from their `deinit`. An entry that
///   outlives its owner is not merely a leak — the allocator readily hands the same address to the
///   next instance, which then resolves to the dead owner's value and inherits its state. This is
///   not theoretical: it shipped, and in a tight create/destroy loop *every* new instance inherited
///   its predecessor's context (#277).
internal final class DocumentAssociatedStorage<T: AnyObject>: @unchecked Sendable {
    private let lock = NSLock()
    private var table: [ObjectIdentifier: T] = [:]

    func value(for owner: AnyObject) -> T? {
        lock.lock(); defer { lock.unlock() }
        return table[ObjectIdentifier(owner)]
    }

    func set(_ value: T, for owner: AnyObject) {
        lock.lock(); defer { lock.unlock() }
        table[ObjectIdentifier(owner)] = value
    }

    func clear(for owner: AnyObject) {
        lock.lock(); defer { lock.unlock() }
        table.removeValue(forKey: ObjectIdentifier(owner))
    }
}
