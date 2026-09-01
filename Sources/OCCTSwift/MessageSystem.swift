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

    /// Load OCCT's Shape Healing (ShapeFix) diagnostic message set. Reliably succeeds: falls back
    /// to a message set compiled into OCCT itself if no `CSF_SHMessage` resource file is found.
    ///
    /// ```swift
    /// MessageSystem.loadDefault()
    /// let hasSmallSolidMessage = MessageSystem.hasMessage(forKey: "ShapeFix.FixSmallSolid.MSG0")
    /// // hasSmallSolidMessage == true
    /// ```
    @discardableResult
    public static func loadDefault() -> Bool {
        OCCTMessageMsgFileLoadDefault()
    }

    /// Check if a message key is registered.
    public static func hasMessage(forKey key: String) -> Bool {
        OCCTMessageMsgHasMsg(key)
    }
}
