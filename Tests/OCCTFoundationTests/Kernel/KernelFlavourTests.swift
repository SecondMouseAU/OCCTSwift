import Foundation
import Testing

@testable import OCCTSwift

// The kernel probe (`Kernel`) and the `requiresKernelFix` test trait that reads it. The ledger the
// probe answers from is `Scripts/kernel-fixes.tsv`; the policy is `okf/policies/kernel-fix-ledger.md`.

extension Trait where Self == ConditionTrait {
    /// Run a test only on a kernel that holds the fix `id`, a row of `Scripts/kernel-fixes.tsv`.
    ///
    /// A test whose fault kills the process cannot be a known issue, so on a kernel without the fix it
    /// is skipped instead. Each test target is its own module, so a target that needs this trait defines
    /// its own copy.
    static func requiresKernelFix(_ id: String) -> Self {
        enabled(if: Kernel.hasFix(id) == true, "the kernel does not hold the fix \(id)")
    }
}

@Suite("Kernel flavour probe")
struct KernelFlavourProbeTests {
    @Test("an id the ledger has no row for is not answered, on any kernel")
    func unknownIdIsNil() {
        #expect(Kernel.hasFix("F9999") == nil)
        #expect(Kernel.hasFix("") == nil)
        #expect(Kernel.hasFix("not an id") == nil)
    }

    @Test("the flavour, the version and the fix answers agree with each other")
    func probeIsInternallyConsistent() {
        // F0080 is a carried patch's row and F0019 an upstream-absorbed one, so between them they
        // separate the three kinds of kernel: unlabelled answers neither, carry answers both true,
        // vanilla answers F0080 false and F0019 true.
        switch Kernel.flavour {
        case .unlabelled:
            #expect(Kernel.occtVersion == "unknown")
            #expect(Kernel.hasFix("F0080") == nil)
            #expect(Kernel.hasFix("F0019") == nil)
        case .carry:
            #expect(Kernel.occtVersion != "unknown")
            #expect(Kernel.hasFix("F0080") == true)
            #expect(Kernel.hasFix("F0019") == true)
        case .vanilla:
            #expect(Kernel.occtVersion != "unknown")
            #expect(Kernel.hasFix("F0080") == false)
            #expect(Kernel.hasFix("F0019") == true)
        }
    }

    @Test("every flavour the bridge can report is one the Swift type names")
    func flavourRoundTrips() {
        let names = Kernel.Flavour.allCases.map(\.rawValue).sorted()
        #expect(names == ["carry", "unlabelled", "vanilla"])
        #expect(Kernel.Flavour(rawValue: Kernel.flavour.rawValue) == Kernel.flavour)
    }

    @Test("a test that needs a fix the kernel holds runs there", .requiresKernelFix("F0080"))
    func requiresTraitRunsWhereTheFixIs() {
        // Reached only when the kernel holds F0080, so this asserts the trait's own contract.
        #expect(Kernel.hasFix("F0080") == true)
    }
}
