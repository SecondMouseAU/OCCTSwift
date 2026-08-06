// Dispatch for the shared Censuses target (#694). `swift run Censuses <cluster>` runs that
// cluster's census; with no argument or `list` it lists what is available instead of failing,
// and `all` runs every census in turn. Kept out of main.swift itself: a `let` at main.swift's
// top level runs main-actor isolated under Swift 6 language mode's top-level-code rule, which
// then cannot be read from an ordinary `nonisolated` function declared in another file. Giving
// the registry and the dispatch logic an ordinary (non-top-level) home avoids that entirely.
//
// Adding a cluster: give it a `<Name>.swift` file in this directory with an `enum <Name> { static
// func run() }`, and add one line to `censuses` below. The cluster's own `README.md` and any
// static cross-check script stay in its own `Scripts/repro/<cluster-dir>/`, unlisted in
// `Package.swift`, since neither is Swift source SwiftPM needs to see.

import Foundation

struct CensusEntry: Sendable {
    let name: String
    let summary: String
    let run: @Sendable () -> Void
}

enum CensusRunner {
    static let censuses: [CensusEntry] = [
        CensusEntry(name: "cluster-a", summary: "sub-shape enumeration and orientation (#664)", run: ClusterA.run),
        CensusEntry(name: "cluster-b", summary: "fillet and chamfer edge-set contract (#665)", run: ClusterB.run),
        CensusEntry(name: "cluster-d", summary: "continuity handling across the kernel and bridge (#513/#667)", run: ClusterD.run),
    ]

    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())

        switch arguments.first {
        case nil, "list":
            printUsage()

        case "all":
            for (offset, entry) in censuses.enumerated() {
                if offset > 0 { print() }
                print("=== \(entry.name): \(entry.summary) ===")
                entry.run()
            }

        case let requested?:
            guard let entry = censuses.first(where: { $0.name == requested }) else {
                FileHandle.standardError.write(Data("Censuses: no such census \"\(requested)\"\n\n".utf8))
                printUsage()
                exit(1)
            }
            entry.run()
        }
    }

    private static func printUsage() {
        print("Censuses: runnable measurement artifacts for docs/v2.0.0-plan.md's census-once rule.")
        print()
        print("Usage: swift run Censuses <cluster>")
        print("       swift run Censuses all      # run every census in turn")
        print("       swift run Censuses list     # this listing (also the no-argument default)")
        print()
        print("Available censuses:")
        for entry in censuses {
            let name = entry.name.count >= 12 ? entry.name : entry.name + String(repeating: " ", count: 12 - entry.name.count)
            print("  \(name) \(entry.summary)")
        }
    }
}
