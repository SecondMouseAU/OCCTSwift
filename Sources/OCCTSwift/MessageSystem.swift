import Foundation
import OCCTBridge
import simd

/// OCCT message system utilities.
public enum MessageSystem {

    /// Get the message text for a given key.
    public static func message(forKey key: String) -> String? {
        guard let cstr = OCCTMessageMsgGet(key) else { return nil }
        let result = String(cString: cstr)
        free(cstr)
        return result
    }

    /// Load message definitions from a file.
    @discardableResult
    public static func loadFile(_ path: String) -> Bool {
        OCCTMessageMsgFileLoad(path)
    }

    /// Load the default OCCT message file.
    @discardableResult
    public static func loadDefault() -> Bool {
        OCCTMessageMsgFileLoadDefault()
    }

    /// Check if a message key is registered.
    public static func hasMessage(forKey key: String) -> Bool {
        OCCTMessageMsgHasMsg(key)
    }
}
