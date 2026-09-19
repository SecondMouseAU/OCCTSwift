import Foundation
import OCCTBridge
import simd

/// TObj application singleton for OCAF-based document management.
///
/// `@unchecked Sendable` reflects that `ref` is a plain bridge pointer; it does not mean
/// concurrent use is safe. `.shared` always returns a wrapper around the **same** process-wide
/// `TObj_Application::GetInstance()` singleton (a `TDocStd_Application` subclass, unrelated to
/// `XCAFApp_Application`, the class #344/#371 fixed and eliminated), so every `TObjApplication`
/// instance shares one underlying OCCT object. Its lazy-init itself is thread-safe (a C++11
/// function-local static, the same fix pattern #344 applied to `XCAFApp_Application`), but
/// `isVerbose`'s getter/setter and `createDocument()` (which sets `myIsError` before calling
/// `NewDocument`) mutate that shared instance's plain fields with no synchronization, a
/// previously-uncharacterized race distinct from any of #341/#344/#349/#353/#371/#374 (see #1404).
/// `createDocument()`'s downstream document-creation machinery (`CDF_Directory`, storage-driver
/// caching, `CDM_Application`'s metadata table, `Resource_Manager`/`Storage_Schema`) is covered by
/// those kernel fixes, all of which ship in the pinned kernel. Serialize calls to `.shared`'s
/// members with `OCCTSerial.withLock { }` until this gets its own bridge-side lock.
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
