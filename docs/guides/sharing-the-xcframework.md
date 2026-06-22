# Sharing the OCCT.xcframework across local repos

`OCCT.xcframework` is ~1.3 GB. On a machine where you develop several ecosystem
repos at once (OCCTSwiftTools, OCCTSwiftViewport, OCCTReconstruct, OCCTMCP, …),
the default setup makes **each repo download and extract its own copy** into
`.build/artifacts/` — easily 25–35 GB of duplicates. This guide explains how the
ecosystem shares a single copy, and the one **`Package.resolved` footgun** that
sharing introduces (issue #260).

## How sharing works (#259)

OCCTSwift's `Package.swift` auto-detects its binary target:

- **Local path** — `.binaryTarget(path: "Libraries/OCCT.xcframework")` when the
  in-place framework is found.
- **Remote URL** — `.binaryTarget(url:checksum:)` otherwise (CI / SPI / remote SPM).

Detection resolves against the **manifest's own directory** (`#filePath`), not the
process CWD. That's the key: when OCCTSwift is consumed as a **local path
dependency**, its manifest finds its in-place (gitignored) `Libraries/OCCT.xcframework`
and the consumer references that single copy — **no per-repo extraction**.

Consumers opt in with a small helper that prefers a local sibling, else the URL pin:

```swift
import Foundation

// Prefer ../<name> when present (shared binary), else the published URL (CI / fresh clones).
func occtDep(_ name: String, from version: String) -> Package.Dependency {
    let manifestDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
    if FileManager.default.fileExists(atPath: manifestDir + "/../\(name)/Package.swift") {
        return .package(path: "../\(name)")
    }
    return .package(url: "https://github.com/gsdali/\(name).git", from: Version(version)!)
}
```

```swift
dependencies: [ occtDep("OCCTSwift", from: "1.7.1") ]
```

A local-path **SPM mirror** (`swift package config set-mirror`) achieves the same
binary sharing without editing `Package.swift`, and has the **same** footgun below.

## ⚠️ The `Package.resolved` footgun (#260)

SPM **never pins local packages**. So the moment a consumer reaches OCCTSwift via a
path dependency (or a local-path mirror), the `occtswift` pin — **and every
transitive OCCT-family pin it brought** (occtswifttools, occtswiftio, …) — is
**silently removed** from that consumer's `Package.resolved`, and rewritten on every
`swift build` / `swift package resolve`.

```text
# OCCTMCP, before sharing — pins present:
"identity": "occtswift",     "version": "1.8.0"
"identity": "occtswiftais",  "version": "1.0.3"   …

# after one local `swift build` with sharing on:
Package.resolved: 1 file changed, 1 insertion(+), 64 deletions(-)   ← all OCCT pins gone
```

If that pin-stripped `Package.resolved` is committed, **CI and other machines get a
non-reproducible (or broken) resolve** — the one file that exists to guarantee
reproducibility is the one sharing quietly breaks.

### Why there's no "pinned AND shared" option in stock SPM

Sharing the binary requires the consumer to resolve OCCTSwift **locally** (so its
in-place `Libraries/` is visible). A URL/git dependency is pinned but is checked out
to a tag **without** the gitignored `Libraries/` → it falls back to the URL and
extracts its own 1.3 GB. A mirror pointed at a local *git clone* keeps the pin but,
again, checks out a tag without `Libraries/` → extracts. **Pinned ⇒ extracts;
shared ⇒ unpinned.** Pick per consumer.

## Recommended workflow

- **Library packages** (their product is a library others depend on, e.g.
  OCCTSwiftTools/IO/Mesh/AIS/CADKit): per SPM best practice, **don't commit
  `Package.resolved`** at all — add it to `.gitignore`. No footgun.
- **Apps / executables** that commit `Package.resolved` for reproducibility
  (OCCTReconstruct, OCCTMCP, OCCTStudio, swiftGCS, …): **let CI own
  `Package.resolved`.** The committed file must be the **URL-pinned** version, which
  the `occtDep` helper produces automatically when **no local sibling is present**
  (CI / a fresh clone). Locally, **do not stage the path-dep churn** — `git checkout
  -- Package.resolved` before committing, or regenerate it in a sibling-free checkout.
- If you don't need the disk savings in a given repo, just keep the plain URL dep
  there — it stays pinned (at the cost of its own 1.3 GB extraction).

## Reclaiming duplicate copies

```bash
# remove extracted per-repo copies (regenerated on next build / shared if path-dep)
find ~/Projects -type d -path "*/artifacts/occtswift" -exec rm -rf {} +
# prune old-version download zips from the global cache (keep the current pin)
ls -d ~/Library/Caches/org.swift.swiftpm/artifacts/*OCCT*xcframework_zip   # review, then rm the old ones
```
