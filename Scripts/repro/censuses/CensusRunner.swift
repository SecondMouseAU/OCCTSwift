// Registry for the shared Censuses target (#694). `swift run Censuses <cluster>` runs that
// cluster's census; with no argument or `list` it lists what is available instead of failing,
// and `all` runs every census in turn. Dispatch itself lives in RunnerCore's GenericRunner (#772
// review: this file used to duplicate that logic instead of sharing it with HarnessRunner.swift).
// Kept out of main.swift itself: a `let` at main.swift's top level runs main-actor isolated under
// Swift 6 language mode's top-level-code rule, which then cannot be read from an ordinary
// `nonisolated` function declared in another file. Giving the registry an ordinary (non-top-level)
// home avoids that entirely.
//
// Adding a cluster: give it a `<Name>.swift` file in this directory with an `enum <Name> { static
// func run() }`, and add one line to `censuses` below. The cluster's own `README.md` and any
// static cross-check script stay in its own `Scripts/repro/<cluster-dir>/`, unlisted in
// `Package.swift`, since neither is Swift source SwiftPM needs to see.

import RunnerCore

enum CensusRunner {
    static let censuses: [RunnableEntry] = [
        RunnableEntry(name: "cluster-a", summary: "sub-shape enumeration and orientation (#664)", run: ClusterA.run),
        RunnableEntry(name: "cluster-b", summary: "fillet and chamfer edge-set contract (#665)", run: ClusterB.run),
        RunnableEntry(name: "cluster-d", summary: "continuity handling across the kernel and bridge (#513/#667)", run: ClusterD.run),
    ]

    static func main() {
        GenericRunner.main(
            toolName: "Censuses",
            blurb: "Censuses: runnable measurement artifacts for docs/v2.0.0-plan.md's census-once rule.",
            entries: censuses)
    }
}
