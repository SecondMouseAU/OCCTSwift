import Foundation
import simd

// MARK: - ConstructionContext (#72 Phase 3)
//
// Document-level collection of named construction entities. Each entity gets a
// typed opaque ID on insertion; the context resolves entities on demand against
// any given BRepGraph. Entities are stored by value — storage is lightweight
// and thread-safe via an internal lock.
//
// Persistence: the XCAF `CONSTRUCTION` layer hosts any shapes tagged as
// construction. Since we deliberately keep construction-entity *recipes* in
// Swift value storage (not as TopoDS_Shapes on the XDE tree), STEP round-trip
// preserves only the "this shape is construction" layer tag — the recipe
// structure is lost. Documented limitation matching FreeCAD's behaviour.
//
// Storage for the three entity kinds (plane/axis/point) is one shared
// `EntityStore`, not three hand-written copies — see #886.

/// Shape common to `PlaneID`/`AxisID`/`PointID`: an opaque, UUID-backed identity minted fresh
/// on `init()`.
///
/// Lets `EntityStore` mint and describe an ID without knowing which concrete entity kind it
/// belongs to.
internal protocol ConstructionEntityID: Sendable, Hashable {
    var raw: UUID { get }
    init()
}

/// Generic insertion-ordered, named-value store keyed by an opaque ID.
///
/// Thread-safe via an internal lock. Backs `ConstructionContext`'s plane/axis/point storage
/// (#886): the three entity kinds used to be three independently hand-written copies of this
/// same add/lookup/name/remove/allX shape.
internal final class EntityStore<ID: ConstructionEntityID, Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [ID: (name: String?, value: Value)] = [:]
    private var order: [ID] = []

    @discardableResult
    func add(_ value: Value, name: String?) -> ID {
        lock.lock()
        defer { lock.unlock() }
        let id = ID()
        entries[id] = (name, value)
        order.append(id)
        return id
    }

    func value(_ id: ID) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        return entries[id]?.value
    }

    func name(_ id: ID) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return entries[id]?.name
    }

    /// Every entry in insertion order.
    ///
    /// A removed entry is skipped rather than returned as a gap.
    var all: [(id: ID, name: String?, value: Value)] {
        lock.lock()
        defer { lock.unlock() }
        return order.compactMap { id in
            entries[id].map { (id: id, name: $0.name, value: $0.value) }
        }
    }

    func remove(_ id: ID) {
        lock.lock()
        defer { lock.unlock() }
        entries.removeValue(forKey: id)
        order.removeAll { $0 == id }
    }

    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll()
        order.removeAll()
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return entries.count
    }
}

public final class ConstructionContext: @unchecked Sendable {
    public struct PlaneID: ConstructionEntityID {
        public let raw: UUID
        public init() { self.raw = UUID() }
    }
    public struct AxisID: ConstructionEntityID {
        public let raw: UUID
        public init() { self.raw = UUID() }
    }
    public struct PointID: ConstructionEntityID {
        public let raw: UUID
        public init() { self.raw = UUID() }
    }

    private let planes = EntityStore<PlaneID, ConstructionPlane>()
    private let axes = EntityStore<AxisID, ConstructionAxis>()
    private let points = EntityStore<PointID, ConstructionPoint>()

    public init() {}

    // MARK: - Insertion

    @discardableResult
    public func add(_ plane: ConstructionPlane, name: String? = nil) -> PlaneID {
        planes.add(plane, name: name)
    }

    @discardableResult
    public func add(_ axis: ConstructionAxis, name: String? = nil) -> AxisID {
        axes.add(axis, name: name)
    }

    @discardableResult
    public func add(_ point: ConstructionPoint, name: String? = nil) -> PointID {
        points.add(point, name: name)
    }

    // MARK: - Lookup

    public func plane(_ id: PlaneID) -> ConstructionPlane? {
        planes.value(id)
    }

    public func axis(_ id: AxisID) -> ConstructionAxis? {
        axes.value(id)
    }

    public func point(_ id: PointID) -> ConstructionPoint? {
        points.value(id)
    }

    public func name(_ id: PlaneID) -> String? {
        planes.name(id)
    }

    public func name(_ id: AxisID) -> String? {
        axes.name(id)
    }

    public func name(_ id: PointID) -> String? {
        points.name(id)
    }

    public var allPlanes: [(id: PlaneID, name: String?, plane: ConstructionPlane)] {
        planes.all.map { (id: $0.id, name: $0.name, plane: $0.value) }
    }

    public var allAxes: [(id: AxisID, name: String?, axis: ConstructionAxis)] {
        axes.all.map { (id: $0.id, name: $0.name, axis: $0.value) }
    }

    public var allPoints: [(id: PointID, name: String?, point: ConstructionPoint)] {
        points.all.map { (id: $0.id, name: $0.name, point: $0.value) }
    }

    // MARK: - Removal

    public func remove(plane id: PlaneID) {
        planes.remove(id)
    }

    public func remove(axis id: AxisID) {
        axes.remove(id)
    }

    public func remove(point id: PointID) {
        points.remove(id)
    }

    public func removeAll() {
        planes.removeAll()
        axes.removeAll()
        points.removeAll()
    }

    // MARK: - Resolution

    public func resolve(_ id: PlaneID, in graph: BRepGraph)
        -> Result<Placement, ConstructionResolutionError>
    {
        resolveEntity(id, in: planes, kind: "plane", graph: graph) {
            (graph: BRepGraph, plane: ConstructionPlane) in graph.resolve(plane)
        }
    }

    public func resolve(_ id: AxisID, in graph: BRepGraph)
        -> Result<(origin: SIMD3<Double>, direction: SIMD3<Double>), ConstructionResolutionError>
    {
        resolveEntity(id, in: axes, kind: "axis", graph: graph) {
            (graph: BRepGraph, axis: ConstructionAxis) in graph.resolve(axis)
        }
    }

    public func resolve(_ id: PointID, in graph: BRepGraph)
        -> Result<SIMD3<Double>, ConstructionResolutionError>
    {
        resolveEntity(id, in: points, kind: "point", graph: graph) {
            (graph: BRepGraph, point: ConstructionPoint) in graph.resolve(point)
        }
    }

    /// Shared shape for the three `resolve(_:in:)` overloads above: look the entity up by ID,
    /// resolve it against the graph, or report a not-registered failure — same message format
    /// every kind used before #886 unified them.
    private func resolveEntity<ID: ConstructionEntityID, Entity, Resolved>(
        _ id: ID,
        in store: EntityStore<ID, Entity>,
        kind: String,
        graph: BRepGraph,
        resolver: (BRepGraph, Entity) -> Result<Resolved, ConstructionResolutionError>
    ) -> Result<Resolved, ConstructionResolutionError> {
        guard let entity = store.value(id) else {
            return .failure(.notApplicable("\(kind) id \(id.raw) not registered"))
        }
        return resolver(graph, entity)
    }

    // MARK: - Diagnostics

    public struct BrokenEntities: Sendable {
        public let planes: [(id: PlaneID, error: ConstructionResolutionError)]
        public let axes: [(id: AxisID, error: ConstructionResolutionError)]
        public let points: [(id: PointID, error: ConstructionResolutionError)]

        public var isEmpty: Bool { planes.isEmpty && axes.isEmpty && points.isEmpty }
        public var totalCount: Int { planes.count + axes.count + points.count }
    }

    /// Inspect every registered entity against the given graph, return those that fail
    /// resolution.
    ///
    /// Useful for agent workflows to detect broken references after a model edit.
    public func allBroken(in graph: BRepGraph) -> BrokenEntities {
        BrokenEntities(
            planes: broken(planes.all, graph: graph) {
                (graph: BRepGraph, plane: ConstructionPlane) in graph.resolve(plane)
            },
            axes: broken(axes.all, graph: graph) {
                (graph: BRepGraph, axis: ConstructionAxis) in graph.resolve(axis)
            },
            points: broken(points.all, graph: graph) {
                (graph: BRepGraph, point: ConstructionPoint) in graph.resolve(point)
            }
        )
    }

    /// Shared shape for the three per-kind scans in `allBroken(in:)`, above.
    private func broken<ID: ConstructionEntityID, Entity, Resolved>(
        _ entries: [(id: ID, name: String?, value: Entity)],
        graph: BRepGraph,
        resolver: (BRepGraph, Entity) -> Result<Resolved, ConstructionResolutionError>
    ) -> [(id: ID, error: ConstructionResolutionError)] {
        entries.compactMap { entry in
            guard case .failure(let error) = resolver(graph, entry.value) else { return nil }
            return (id: entry.id, error: error)
        }
    }

    public var count: (planes: Int, axes: Int, points: Int) {
        (planes.count, axes.count, points.count)
    }
}

// MARK: - Document integration

extension Document {
    /// Per-document construction context.
    ///
    /// Lazy-associated; created on first access. Construction entities added to the context live
    /// alongside the document's shapes but are not part of the XDE shape tree — they're pure
    /// Swift-side recipes. For persistence guidance see ConstructionContext doc comments.
    public var constructionContext: ConstructionContext {
        if let existing = Self.constructionContextStorage.value(for: self) {
            return existing
        }
        let new = ConstructionContext()
        Self.constructionContextStorage.set(new, for: self)
        return new
    }

    /// Drop this document's associated construction context.
    ///
    /// Called from `Document.deinit`. This is not optional bookkeeping: the association is keyed
    /// on `ObjectIdentifier`, which is the instance pointer and is therefore only unique among
    /// *live* objects. If the entry outlives the document, the next `Document` allocated at the
    /// recycled address resolves to this one's context and silently inherits its entities (#277).
    internal func releaseConstructionContext() {
        Self.constructionContextStorage.clear(for: self)
    }

    // Associated storage for construction contexts, since Document is a final class we can't
    // extend with stored properties. Strongly keyed on ObjectIdentifier (the instance pointer);
    // entries are removed in `Document.deinit` via `releaseConstructionContext()` — see #277 for
    // why that cleanup is load-bearing rather than mere tidiness.
    fileprivate static let constructionContextStorage = DocumentAssociatedStorage<
        ConstructionContext
    >()
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
        lock.lock()
        defer { lock.unlock() }
        return table[ObjectIdentifier(owner)]
    }

    func set(_ value: T, for owner: AnyObject) {
        lock.lock()
        defer { lock.unlock() }
        table[ObjectIdentifier(owner)] = value
    }

    func clear(for owner: AnyObject) {
        lock.lock()
        defer { lock.unlock() }
        table.removeValue(forKey: ObjectIdentifier(owner))
    }
}
