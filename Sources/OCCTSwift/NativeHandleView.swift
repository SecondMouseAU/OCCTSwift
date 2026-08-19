/// A reference type that owns a native OCCT handle and releases it in `deinit`.
protocol NativeHandleOwner: AnyObject {
    associatedtype NativeHandle
    var handle: NativeHandle { get }
}

/// A value type that reads a ``NativeHandleOwner``'s handle without owning it.
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
