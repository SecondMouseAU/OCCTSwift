/// A reference type that owns a native OCCT handle and releases it in `deinit`.
protocol NativeHandleOwner: AnyObject {
    associatedtype NativeHandle
    var handle: NativeHandle { get }
}

extension NativeHandleOwner {
    /// Runs `body` with this owner's native handle, keeping the owner alive until `body` returns.
    ///
    /// Reading `handle` yields a raw pointer that the compiler does not connect to its owner, so an
    /// optimised build is free to release the owner once the load is its last use, which is before
    /// the C call that receives the pointer runs (#3130). Measured on macOS `-c release`: an owner
    /// that is a collection element or a temporary (`edges[0].handle`, `makeEdges().first!.handle`)
    /// is released early and the call reads or writes freed memory, while an owner bound to its own
    /// `let` or `for` variable is not. Use this for the first kind. The call to this method is what
    /// holds the owner, because a method call keeps its receiver alive for the whole call.
    ///
    /// `Scripts/check-borrowed-handle-temporaries.py` fails the build on a `.handle` read straight
    /// off a subscript or call result.
    @inline(__always)
    func withHandle<Result>(_ body: (NativeHandle) throws -> Result) rethrows -> Result {
        try withExtendedLifetime(self) { try body(handle) }
    }
}

/// A value type that reads the handle owned by a ``NativeHandleOwner``, without owning it.
///
/// A conformer stores the owner, not the raw handle, and reads the handle through it. That is
/// what keeps the handle alive: a value view is free to outlive the expression that produced it,
/// and until #965 the 19 `*Properties` views stored the raw handle instead, so a view outliving
/// its parent read memory the parent's `deinit` had already released. See
/// `docs/architecture/overview.md`.
///
/// Conform rather than writing the retain by hand, and do not declare a stored `handle`: the
/// extension below supplies it, so a conformer that adds its own is reintroducing the defect.
/// `Scripts/check-borrowed-handles.py` fails the build on one that does.
///
/// A conformer can be plainly `Sendable` rather than `@unchecked Sendable`. Its only stored
/// property is the owner, and `Curve2D`/`Curve3D`/`Surface` already declare `@unchecked Sendable`
/// themselves, so the compiler checks the view and the view's claim rests entirely on the owner's,
/// which is where the OCCT thread-safety argument in `docs/thread-safety.md` actually lives. The
/// views' own `@unchecked` was asserting something narrower and unexamined: that a borrowed
/// handle with no owner was safe to send, which it was not, since it was not safe to read at all.
protocol NativeHandleView {
    associatedtype Owner: NativeHandleOwner
    var owner: Owner { get }
}

extension NativeHandleView {
    /// The owner's native handle, valid for as long as this value is.
    var handle: Owner.NativeHandle { owner.handle }
}

// The three parents whose nested `*Properties` views the #965 fix converted. Kept together here
// rather than one per file so the set is countable in one place.
extension Curve2D: NativeHandleOwner {}
extension Curve3D: NativeHandleOwner {}
extension Surface: NativeHandleOwner {}

// The four topology wrappers #3130 was measured on. `Edge`, `Wire` and `Face` hand out
// subscript-held elements (`shape.edges()[i]`), which is the shape that lost its owner early.
extension Shape: NativeHandleOwner {}
extension Edge: NativeHandleOwner {}
extension Wire: NativeHandleOwner {}
extension Face: NativeHandleOwner {}
