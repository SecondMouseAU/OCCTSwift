// Censuses (#694): one executable target for every cluster census docs/v2.0.0-plan.md's
// census-once rule asks for. See CensusRunner.swift for the dispatch logic; this file only
// exists because SwiftPM requires exactly one `main.swift` per executable target to hold the
// entry point's top-level statement.

CensusRunner.main()
