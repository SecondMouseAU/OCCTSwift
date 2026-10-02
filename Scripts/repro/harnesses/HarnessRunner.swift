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
    // Two of the three are `#if !os(WASI)`, and this list has to agree with them or the target does
    // not compile for wasm at all. Both are wall-clock timing harnesses; their own files say why
    // they are guarded rather than ported. Built up rather than written as one literal with `#if`s
    // inside it, so the entries stay readable and the platform difference is stated once.
    static let harnesses: [RunnableEntry] = {
        var entries: [RunnableEntry] = [
            RunnableEntry(
                name: "965-properties-lifetime",
                summary: "do the *Properties views keep their parent alive? (#965)",
                run: PropertiesLifetime.run),
            RunnableEntry(
                name: "2972-sheetmetal-volumes",
                summary: "SheetMetal volumes against a term-by-term prediction (#2972)",
                run: SheetMetalVolumes.run),
        ]
        #if !os(WASI)
            entries += [
                RunnableEntry(
                    name: "772-self-intersection",
                    summary: "analyze(tolerance:) vs isSelfIntersecting(timeout:) cost (#772)",
                    run: AnalyzeSelfIntersectionTiming.run),
                RunnableEntry(
                    name: "777-pocket-isopen",
                    summary: "PocketFeature.isOpen's enclosure test, four ways (#777)",
                    run: PocketEnclosureTiming.run),
            ]
        #endif
        // Sorted, so the listing printed with no argument does not depend on the order the
        // platform-conditional block appends in.
        return entries.sorted { $0.name < $1.name }
    }()

    static func main() {
        GenericRunner.main(
            toolName: "Harnesses",
            blurb: "Harnesses: runnable measurement harnesses backing issue-specific decisions.",
            entries: harnesses)
    }
}
