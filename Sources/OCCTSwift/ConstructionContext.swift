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
///
/// `@unchecked Sendable` covers the lock-guarded storage itself, not what `Value` is — an
/// unconstrained `Value` would let the compiler wave through a future non-`Sendable` payload
/// crossing concurrency boundaries through `value(_:)`/`all` with no check at all, since
/// `@unchecked` disables Sendable checking entirely rather than narrowing it to the mutable
/// state the lock actually protects. `Value: Sendable` restores that check at zero cost to
/// today's three instantiations (`ConstructionPlane`/`ConstructionAxis`/`ConstructionPoint`,
/// all already `Sendable`) (#914 review, finding 13).
internal final class EntityStore<ID: ConstructionEntityID, Value: Sendable>: @unchecked Sendable {
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
    ///
    /// - Returns: `(id, name, value)`, unlabeled — an internal function returning a tuple with
    ///   baked-in labels forces every call site whose own labels differ into a two-step
    ///   bind-then-relabel instead of a direct return (`okf/policies/code-style.md`; #914 review,
    ///   second round). Every consumer of this either passes the array through opaquely or
    ///   destructures positionally into its own labels.
    var all: [(ID, String?, Value)] {
        lock.lock()
        defer { lock.unlock() }
        return order.compactMap { id in
            entries[id].map { (id, $0.name, $0.value) }
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

    /// Guards `add`, `remove`, `removeAll`, `count` and the atomic cross-store snapshot
    /// (`allEntitiesSnapshot`, used by `allBroken(in:)` and `ConstructionLayer.materialize`)
    /// against each other so each behaves as one atomic step across all three stores.
    ///
    /// **Not** every operation this type exposes: `plane(_:)`/`axis(_:)`/`point(_:)`, `name(_:)`,
    /// and `allPlanes`/`allAxes`/`allPoints` read a single store and take only that store's own
    /// `EntityStore` lock, not this one. That's a deliberate narrowing from the pre-#886
    /// implementation's single class-wide lock (which serialized every operation, cross-store
    /// reads and single-store ones alike) rather than a regression: nothing about a single-store
    /// read is made incorrect by another store mutating concurrently, and a caller reading two
    /// different kinds back to back was already two separate, non-atomic lock acquisitions before
    /// #886 too (#914 review, second round — a doc comment ambiguity, not a behavior bug).
    ///
    /// Each `EntityStore` keeps its own internal lock (a distinct `NSLock`) for its own
    /// single-store operations (`value`, `name`, `all`); nesting this lock around a call into a
    /// store's already-locked method is safe because the two locks are always acquired in the
    /// same order (this one first) and are never the same object, so there's no double-locking
    /// or deadlock risk.
    ///
    /// `remove(plane:)`/`remove(axis:)`/`remove(point:)` take this lock too (PR #898 review,
    /// finding 5) — even though a *single* `remove()` racing a *single* `removeAll()` was, and
    /// still is, idempotent by itself (the ID ends up absent either way, so that specific pairing
    /// was never the problem the earlier version of this comment reasoned about). The motivating
    /// concern was that an unlocked `remove()` could run its critical section while `removeAll()`'s
    /// or `count()`'s was in progress; locking it removes that possibility outright, for the same
    /// reason `add()` is locked. **Investigated, not just fixed**: with `removeAll()`/`count()`
    /// already atomic under this lock, that specific interleaving turns out not to be observable
    /// through `count()`/`allBroken(in:)`/`materialize(in:graph:options:)` even without this
    /// change — `ConstructionContextConcurrencyTests.removeAllStaysAtomicUnderConcurrentRemove`'s
    /// own doc comment has the measurements (9, then 500, concurrent single removes; a full
    /// single-kind drain). This lock is still the right thing to hold here: it keeps `remove()`
    /// consistent with every other mutator's contract with `removeAll()`/`count()`, and closes the
    /// gap for good against a future change (e.g. a second step added to `EntityStore.remove()`)
    /// that could make it observable. What it does **not**, and cannot, do: make an external
    /// caller's *own* loop of many separate `remove()` calls atomic as a whole (nothing here
    /// promises `ctx.allAxes.forEach { ctx.remove(axis: $0.id) }` is one atomic step; each call in
    /// it still is, and a concurrent `count()` will legitimately see that loop's progress).
    private let crossStoreLock = NSLock()

    /// Atomic snapshot of every plane/axis/point currently registered, taken under one
    /// `crossStoreLock` critical section — the same cross-store atomicity `count`/`removeAll`
    /// already have.
    ///
    /// Used by `allBroken(in:)` below and by `ConstructionLayer.materialize(in:graph:options:)`
    /// (PR #898 review, finding 1) so neither observes a torn cross-store read: some kinds
    /// already reflecting a concurrent `removeAll()`/`remove()` while others don't. Both callers
    /// take the snapshot once, up front, then do their (potentially slow — graph resolution,
    /// OCCT shape building, document mutation) per-entity work against the local copy, entirely
    /// outside this lock. Neither `BRepGraph.resolve` nor `Document.addConstructionShape` nor any
    /// `ConstructionLayer` shape builder calls back into `ConstructionContext`, so there's no
    /// reentrancy or lock-ordering risk from holding the snapshot's result past the critical
    /// section that produced it.
    /// - Returns: `(planes, axes, points)`, unlabeled — an internal property returning a tuple
    ///   with baked-in labels forces every call site whose own labels differ into a two-step
    ///   bind-then-relabel instead of a direct return (`okf/policies/code-style.md`; #914 review,
    ///   second round). The inner per-entity element tuples keep their `(id:, name:, value:)`
    ///   labels — those genuinely are read by name at both call sites, `broken(_:)`'s parameter
    ///   type and `ConstructionLayer.materialize`'s `entry.id`/`entry.value` — only the outer
    ///   `(planes:, axes:, points:)` grouping is unlabeled.
    internal var allEntitiesSnapshot:
        (
            [(id: PlaneID, name: String?, value: ConstructionPlane)],
            [(id: AxisID, name: String?, value: ConstructionAxis)],
            [(id: PointID, name: String?, value: ConstructionPoint)]
        )
    {
        crossStoreLock.lock()
        defer { crossStoreLock.unlock() }
        return (
            planes.all.map { (id: $0.0, name: $0.1, value: $0.2) },
            axes.all.map { (id: $0.0, name: $0.1, value: $0.2) },
            points.all.map { (id: $0.0, name: $0.1, value: $0.2) }
        )
    }

    public init() {}

    // MARK: - Insertion

    @discardableResult
    public func add(_ plane: ConstructionPlane, name: String? = nil) -> PlaneID {
        crossStoreLock.lock()
        defer { crossStoreLock.unlock() }
        return planes.add(plane, name: name)
    }

    @discardableResult
    public func add(_ axis: ConstructionAxis, name: String? = nil) -> AxisID {
        crossStoreLock.lock()
        defer { crossStoreLock.unlock() }
        return axes.add(axis, name: name)
    }

    @discardableResult
    public func add(_ point: ConstructionPoint, name: String? = nil) -> PointID {
        crossStoreLock.lock()
        defer { crossStoreLock.unlock() }
        return points.add(point, name: name)
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
        planes.all.map { id, name, value in (id: id, name: name, plane: value) }
    }

    public var allAxes: [(id: AxisID, name: String?, axis: ConstructionAxis)] {
        axes.all.map { id, name, value in (id: id, name: name, axis: value) }
    }

    public var allPoints: [(id: PointID, name: String?, point: ConstructionPoint)] {
        points.all.map { id, name, value in (id: id, name: name, point: value) }
    }

    // MARK: - Removal

    public func remove(plane id: PlaneID) {
        crossStoreLock.lock()
        defer { crossStoreLock.unlock() }
        planes.remove(id)
    }

    public func remove(axis id: AxisID) {
        crossStoreLock.lock()
        defer { crossStoreLock.unlock() }
        axes.remove(id)
    }

    public func remove(point id: PointID) {
        crossStoreLock.lock()
        defer { crossStoreLock.unlock() }
        points.remove(id)
    }

    public func removeAll() {
        crossStoreLock.lock()
        defer { crossStoreLock.unlock() }
        planes.removeAll()
        axes.removeAll()
        points.removeAll()
    }

    // MARK: - Resolution

    public func resolve(_ id: PlaneID, in graph: BRepGraph)
        -> Result<Placement, ConstructionResolutionError>
    {
        resolveEntity(id, in: planes, kind: "plane") { graph.resolve($0) }
    }

    public func resolve(_ id: AxisID, in graph: BRepGraph)
        -> Result<(origin: SIMD3<Double>, direction: SIMD3<Double>), ConstructionResolutionError>
    {
        resolveEntity(id, in: axes, kind: "axis") { graph.resolve($0) }
    }

    public func resolve(_ id: PointID, in graph: BRepGraph)
        -> Result<SIMD3<Double>, ConstructionResolutionError>
    {
        resolveEntity(id, in: points, kind: "point") { graph.resolve($0) }
    }

    /// Shared shape for the three `resolve(_:in:)` overloads above: look the entity up by ID,
    /// resolve it against the graph, or report a not-registered failure — same message format
    /// every kind used before #886 unified them.
    ///
    /// `resolver` captures its `BRepGraph` from the enclosing call site rather than taking one as
    /// a parameter — every caller already has exactly one `graph` in scope, so re-threading it
    /// through the closure signature was a no-op indirection (PR #898 review).
    private func resolveEntity<ID: ConstructionEntityID, Entity, Resolved>(
        _ id: ID,
        in store: EntityStore<ID, Entity>,
        kind: String,
        resolver: (Entity) -> Result<Resolved, ConstructionResolutionError>
    ) -> Result<Resolved, ConstructionResolutionError> {
        guard let entity = store.value(id) else {
            return .failure(.notApplicable("\(kind) id \(id.raw) not registered"))
        }
        return resolver(entity)
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
    /// Useful for agent workflows to detect broken references after a model edit. Reads all
    /// three stores as one atomic snapshot (`allEntitiesSnapshot`, PR #898 review finding 1) so a
    /// concurrent `removeAll()`/`remove()` can't be observed mid-flight — some kinds already
    /// cleared, others not — the same torn-cross-store-read bug class `count()` was fixed for.
    public func allBroken(in graph: BRepGraph) -> BrokenEntities {
        let (planes, axes, points) = allEntitiesSnapshot
        return BrokenEntities(
            planes: broken(planes) { graph.resolve($0) },
            axes: broken(axes) { graph.resolve($0) },
            points: broken(points) { graph.resolve($0) }
        )
    }

    /// Shared shape for the three per-kind scans in `allBroken(in:)`, above.
    ///
    /// `resolver` captures `graph` from the enclosing `allBroken(in:)` call rather than taking
    /// one as a parameter — same reasoning as `resolveEntity` above (PR #898 review).
    private func broken<ID: ConstructionEntityID, Entity, Resolved>(
        _ entries: [(id: ID, name: String?, value: Entity)],
        resolver: (Entity) -> Result<Resolved, ConstructionResolutionError>
    ) -> [(id: ID, error: ConstructionResolutionError)] {
        entries.compactMap { entry in
            guard case .failure(let error) = resolver(entry.value) else { return nil }
            return (id: entry.id, error: error)
        }
    }

    public var count: (planes: Int, axes: Int, points: Int) {
        crossStoreLock.lock()
        defer { crossStoreLock.unlock() }
        return (planes.count, axes.count, points.count)
    }
}

// MARK: - Document integration

extension Document {
    /// Per-document construction context.
    ///
    /// Lazy-associated; created on first access. Construction entities added to the context live
    /// alongside the document's shapes but are not part of the XDE shape tree — they're pure
    /// Swift-side recipes. For persistence guidance see ConstructionContext doc comments.
    ///
    /// `valueOrInsert(for:make:)` looks up and (on a miss) constructs+inserts under one lock
    /// acquisition — a separate `value(for:)` then `set(_:for:)` pair would be a check-then-set
    /// race: two threads' first access could both miss, both construct a `ConstructionContext`,
    /// and the loser's instance would be silently unreachable from this document the moment the
    /// winner's `set` ran, even though it was already handed back to its own caller (#914 review,
    /// second round).
    public var constructionContext: ConstructionContext {
        Self.constructionContextStorage.valueOrInsert(for: self) { ConstructionContext() }
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

    /// Look up an existing value, or construct and insert one, as a single atomic step.
    ///
    /// `value(for:)` immediately followed by `set(_:for:)` on a miss is a check-then-set race:
    /// two callers can both miss the lookup, both construct, and the loser's instance — handed
    /// back to its own caller as if it were live — is immediately orphaned by the winner's
    /// `set(_:for:)` overwriting the table entry. `make()` runs while the lock is held, so no
    /// second caller can observe a miss for the same owner while the first is still constructing
    /// (#914 review, second round, finding on `Document.constructionContext`).
    func valueOrInsert(for owner: AnyObject, make: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        let key = ObjectIdentifier(owner)
        if let existing = table[key] {
            return existing
        }
        let value = make()
        table[key] = value
        return value
    }

    func clear(for owner: AnyObject) {
        lock.lock()
        defer { lock.unlock() }
        table.removeValue(forKey: ObjectIdentifier(owner))
    }
}
