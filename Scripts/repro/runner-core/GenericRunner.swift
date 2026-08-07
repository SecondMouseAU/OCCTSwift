// Shared dispatch logic for the repo's "one executable target, many named entries" shared
// targets (#694: Censuses; the same reasoning's Harnesses sibling). Review on #772/#773 found
// `HarnessRunner.swift` had reproduced `CensusRunner.swift`'s `main()`/`printUsage()` almost line
// for line instead of extracting it, exactly the per-target duplication #694 was meant to
// eliminate. This is that extraction: a small library target both executables depend on, so a
// future change to the dispatch/list/error-handling logic (a new flag, a wording change) is made
// once, here, rather than ported by hand into every runner.
//
// A tool-specific `<Tool>Runner.swift` (`CensusRunner.swift`, `HarnessRunner.swift`) stays in
// each executable target's own directory: it owns the registry (the list of named entries) and
// the tool's display name/blurb, and forwards to `GenericRunner.main` for everything else.

import Foundation

/// One named, runnable entry in a shared-target registry (a cluster census, a measurement
/// harness, ...).
public struct RunnableEntry: Sendable {
    public let name: String
    public let summary: String
    public let run: @Sendable () -> Void

    public init(name: String, summary: String, run: @escaping @Sendable () -> Void) {
        self.name = name
        self.summary = summary
        self.run = run
    }
}

public enum GenericRunner {
    /// `swift run <toolName> <name>` runs that entry; `all` runs every entry in turn; `list` (or
    /// no argument) prints the usage/listing below instead of failing; an unrecognised name
    /// prints the same listing to stderr and exits 1.
    public static func main(toolName: String, blurb: String, entries: [RunnableEntry]) {
        let arguments = Array(CommandLine.arguments.dropFirst())

        switch arguments.first {
        case nil, "list":
            printUsage(toolName: toolName, blurb: blurb, entries: entries)

        case "all":
            for (offset, entry) in entries.enumerated() {
                if offset > 0 { print() }
                print("=== \(entry.name): \(entry.summary) ===")
                entry.run()
            }

        case let requested?:
            guard let entry = entries.first(where: { $0.name == requested }) else {
                FileHandle.standardError.write(Data("\(toolName): no such entry \"\(requested)\"\n\n".utf8))
                printUsage(toolName: toolName, blurb: blurb, entries: entries)
                exit(1)
            }
            entry.run()
        }
    }

    private static func printUsage(toolName: String, blurb: String, entries: [RunnableEntry]) {
        print(blurb)
        print()
        print("Usage: swift run \(toolName) <name>")
        print("       swift run \(toolName) all      # run every entry in turn")
        print("       swift run \(toolName) list     # this listing (also the no-argument default)")
        print()
        print("Available:")
        let width = entries.map(\.name.count).max() ?? 0
        for entry in entries {
            let name = entry.name.count == width ? entry.name : entry.name + String(repeating: " ", count: width - entry.name.count)
            print("  \(name) \(entry.summary)")
        }
    }
}
