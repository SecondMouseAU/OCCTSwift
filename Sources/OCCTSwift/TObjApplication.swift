import Foundation
import OCCTBridge
import simd

/// TObj application singleton for OCAF-based document management.
///
/// `.shared` always returns a wrapper around the **same** process-wide
/// `TObj_Application::GetInstance()` singleton (a `TDocStd_Application` subclass, unrelated to
/// `XCAFApp_Application`, the class #344/#371 fixed and eliminated), so every `TObjApplication`
/// instance shares one underlying OCCT object.
///
/// `@unchecked Sendable` is sound here rather than aspirational: `ref` is a plain bridge pointer,
/// and every member that reaches the shared singleton's own mutable state is serialized on the
/// bridge side by `tobjApplicationMutex()` (#1404). `isVerbose`'s getter and setter reach
/// `myIsVerbose`, a plain unguarded `bool`, and `createDocument()` reaches `myIsError`, which
/// `CreateNewDocument` writes before calling `NewDocument` and reads back as its return value, so
/// two unserialized concurrent calls could each clear the other's in-flight error signal. The lock
/// is held across the whole `CreateNewDocument` call, not just the field writes.
///
/// That race was distinct from #341/#344/#349/#353/#371/#374, none of which touched this class.
/// `createDocument()`'s downstream machinery (`CDF_Directory`, storage-driver caching,
/// `CDM_Application`'s metadata table, `Resource_Manager`/`Storage_Schema`) is covered by those
/// kernel fixes, all of which ship in the pinned kernel; this lock covers the layer above them.
///
/// ```swift
/// // Safe to call concurrently; the bridge serializes the shared singleton's own state.
/// await withTaskGroup(of: Document?.self) { group in
///     for _ in 0..<8 {
///         group.addTask { TObjApplication.shared?.createDocument() }
///     }
/// }
/// ```
public final class TObjApplication: @unchecked Sendable {
    private let ref: OCCTTObjAppRef

    private init(ref: OCCTTObjAppRef) {
        self.ref = ref
    }

    deinit {
        OCCTTObjApplicationRelease(ref)
    }

    /// Get the singleton TObj_Application instance.
    public static var shared: TObjApplication? {
        guard let ref = OCCTTObjApplicationGetInstance() else { return nil }
        return TObjApplication(ref: ref)
    }

    /// Whether verbose logging is enabled.
    public var isVerbose: Bool {
        get { OCCTTObjApplicationIsVerbose(ref) }
        set { OCCTTObjApplicationSetVerbose(ref, newValue) }
    }

    /// Create a new document via TObj_Application.
    public func createDocument() -> Document? {
        guard let docRef = OCCTTObjApplicationCreateDocument(ref) else { return nil }
        return Document(handle: docRef)
    }
}
