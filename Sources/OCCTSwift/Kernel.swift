//
//  Kernel.swift
//  OCCTSwift
//
//  Which OCCT kernel this build links against, and which defects it holds a fix for (#3543).
//

import OCCTBridge

/// Which OCCT kernel this build links against, and which defects it holds a fix for.
///
/// OCCTSwift ships its kernel in two flavours. **Carry**, the default, is OCCT plus the patches in
/// `Scripts/patches`: it refuses damaged input, serialises the shared state those patches fix, and
/// answers the questions the wrong-answer patches repair. **Vanilla**, the opt-in LTS kernel, is
/// OCCT exactly as Open Cascade tagged it, so any defect is upstream's. The two differ in what they
/// promise, and this type is how a program, or a test, finds out which it has.
///
/// ```swift
/// print(Kernel.flavour, Kernel.occtVersion)     // carry 8.0.2
/// if Kernel.hasFix("F0080") == false {
///     // this kernel lacks the F0080 fix (IntTools_FaceFace::Perform on a face with no surface)
/// }
/// ```
///
/// A kernel built before the kernel-fix ledger states nothing about itself: its ``flavour`` is
/// ``Flavour/unlabelled`` and ``hasFix(_:)`` answers `nil` for every id.
public enum Kernel {
    /// Which kernel this is.
    public enum Flavour: String, Sendable, CaseIterable {
        /// OCCT plus the carried patches: the hardened, default kernel.
        case carry
        /// OCCT exactly as tagged, with no carried patch: the LTS kernel.
        case vanilla
        /// A kernel built before the kernel-fix ledger, which does not say what it holds.
        case unlabelled
    }

    /// Which kernel this build links against.
    public static var flavour: Flavour {
        Flavour(rawValue: String(cString: OCCTKernelFlavour())) ?? .unlabelled
    }

    /// The OCCT version the kernel was built from, such as `"8.0.2"`, or `"unknown"` for an
    /// unlabelled kernel.
    public static var occtVersion: String {
        String(cString: OCCTKernelOCCTVersion())
    }

    /// Whether the kernel holds the fix for the ledger row `id` (such as `"F0080"`).
    ///
    /// - Returns: `true` when it does, `false` when it is known to lack it, and `nil` when the kernel
    ///   cannot say: an id its ledger has no row for, or any id asked of an unlabelled kernel.
    public static func hasFix(_ id: String) -> Bool? {
        switch OCCTKernelHasFix(id) {
        case 1: return true
        case 0: return false
        default: return nil
        }
    }
}
