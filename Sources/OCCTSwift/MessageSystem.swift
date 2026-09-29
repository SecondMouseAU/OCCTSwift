import Foundation
import OCCTBridge
import simd

// The platform C library, named because this file uses it directly (free, sin, cos, sqrt and
// the like). `import Foundation` happens to re-export it on Apple platforms, so these were in
// scope by accident rather than by declaration; FoundationEssentials does not, which is how
// #2761 found them. Naming it here is correct independently of that work.
#if canImport(Darwin)
    import Darwin
#elseif canImport(WASILibc)
    import WASILibc
#elseif canImport(Glibc)
    import Glibc
#endif

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

    /// Load OCCT's Shape Healing (ShapeFix) diagnostic message set.
    ///
    /// Reliably succeeds: falls back to a message set compiled into OCCT itself if no
    /// `CSF_SHMessage` resource file is found.
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
