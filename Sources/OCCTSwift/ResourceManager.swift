import Foundation
import simd
import OCCTBridge

/// Configuration key-value store using OCCT Resource_Manager.
public final class ResourceManager: @unchecked Sendable {
    private let ref: OCCTResourceManagerRef

    public init() {
        ref = OCCTResourceManagerCreate()
    }

    deinit {
        OCCTResourceManagerRelease(ref)
    }

    public func setString(_ key: String, value: String) {
        OCCTResourceManagerSetString(ref, key, value)
    }

    public func setInt(_ key: String, value: Int) {
        OCCTResourceManagerSetInt(ref, key, Int32(value))
    }

    public func setReal(_ key: String, value: Double) {
        OCCTResourceManagerSetReal(ref, key, value)
    }

    public func find(_ key: String) -> Bool {
        OCCTResourceManagerFind(ref, key)
    }

    public func string(_ key: String) -> String? {
        guard let ptr = OCCTResourceManagerGetString(ref, key) else { return nil }
        defer { free(UnsafeMutablePointer(mutating: ptr)) }
        return String(cString: ptr)
    }

    public func integer(_ key: String) -> Int {
        Int(OCCTResourceManagerGetInt(ref, key))
    }

    public func real(_ key: String) -> Double {
        OCCTResourceManagerGetReal(ref, key)
    }
}
