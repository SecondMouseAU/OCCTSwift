// Harnesses: one executable target for ad hoc measurement harnesses backing an issue-specific
// decision (as opposed to Censuses, the sibling target for docs/v2.0.0-plan.md's cluster
// census-once work). See HarnessRunner.swift for the dispatch logic; this file only exists
// because SwiftPM requires exactly one main.swift per executable target to hold the entry
// point's top-level statement.

HarnessRunner.main()
