// Registry for the shared Harnesses target, the timing/perf sibling of Censuses (#694's pattern:
// one shared executable target, not one per repro directory, so renaming a repro directory never
// touches Package.swift and there is no second exclude: list to maintain). `swift run Harnesses
// <name>` runs that harness; with no argument or `list` it lists what is available, and `all`
// runs every harness in turn. Dispatch itself lives in RunnerCore's GenericRunner, shared with
// CensusRunner.swift (#772 review: this file used to duplicate that logic instead).
//
// Adding a harness: give it a `<Name>.swift` file in this directory with an `enum <Name> {
// static func run() }`, and add one line to `harnesses` below. Keep helper types and functions
// `fileprivate`: everything in this directory is one compilation target, so an unqualified name
// is visible to every other harness's file too (see ClusterB.swift/ClusterD.swift's identically-
// named but independent `fmt` for the established precedent). The harness's own `README.md` and
// captured output stay in its own `Scripts/repro/<issue-dir>/`, unlisted in `Package.swift`.

import RunnerCore

enum HarnessRunner {
    static let harnesses: [RunnableEntry] = [
        RunnableEntry(name: "772-self-intersection",
                      summary: "analyze(tolerance:) vs isSelfIntersecting(timeout:) cost (#772)",
                      run: AnalyzeSelfIntersectionTiming.run),
    ]

    static func main() {
        GenericRunner.main(
            toolName: "Harnesses",
            blurb: "Harnesses: runnable measurement harnesses backing issue-specific decisions.",
            entries: harnesses)
    }
}
