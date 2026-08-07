// Dispatch for the shared Harnesses target. Same shared-target shape as the Censuses target's
// own CensusRunner.swift (#694): one manifest entry covers every harness, so a harness's own
// repro directory (`Scripts/repro/<issue-dir>/`) holds only its README and captured output, not
// Swift source, and renaming that directory never touches Package.swift. `swift run Harnesses
// <name>` runs that harness; with no argument or `list` it lists what is available, and `all`
// runs every harness in turn.
//
// Adding a harness: give it a `<Name>.swift` file in this directory with an `enum <Name> {
// static func run() }`, and add one line to `harnesses` below. Keep helper types and functions
// `fileprivate`: everything in this directory is one compilation target, so an unqualified name
// is visible to every other harness's file too (see ClusterB.swift/ClusterD.swift's identically-
// named but independent `fmt` for the established precedent).

import Foundation

struct HarnessEntry: Sendable {
    let name: String
    let summary: String
    let run: @Sendable () -> Void
}

enum HarnessRunner {
    static let harnesses: [HarnessEntry] = [
        HarnessEntry(name: "772-self-intersection",
                     summary: "analyze(tolerance:) vs isSelfIntersecting(timeout:) cost (#772)",
                     run: AnalyzeSelfIntersectionTiming.run),
    ]

    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())

        switch arguments.first {
        case nil, "list":
            printUsage()

        case "all":
            for (offset, entry) in harnesses.enumerated() {
                if offset > 0 { print() }
                print("=== \(entry.name): \(entry.summary) ===")
                entry.run()
            }

        case let requested?:
            guard let entry = harnesses.first(where: { $0.name == requested }) else {
                FileHandle.standardError.write(Data("Harnesses: no such harness \"\(requested)\"\n\n".utf8))
                printUsage()
                exit(1)
            }
            entry.run()
        }
    }

    private static func printUsage() {
        print("Harnesses: runnable measurement harnesses backing issue-specific decisions.")
        print()
        print("Usage: swift run Harnesses <name>")
        print("       swift run Harnesses all      # run every harness in turn")
        print("       swift run Harnesses list     # this listing (also the no-argument default)")
        print()
        print("Available harnesses:")
        for entry in harnesses {
            let name = entry.name.count >= 24 ? entry.name : entry.name + String(repeating: " ", count: 24 - entry.name.count)
            print("  \(name) \(entry.summary)")
        }
    }
}
