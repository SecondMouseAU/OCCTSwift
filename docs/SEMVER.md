---
title: Versioning (SemVer)
nav_order: 11
---

# SemVer Policy — OCCTSwift Ecosystem

This document defines how every package in the [OCCTSwift ecosystem](ecosystem.md) versions its releases. It applies to OCCTSwift itself, OCCTSwiftIO, OCCTSwiftMesh, OCCTSwiftViewport, OCCTSwiftTools, OCCTSwiftAIS, OCCTSwiftScripts, and OCCTMCP — and to any future sibling that joins the cohort.

The policy is calibrated to the [SemVer 2.0.0](https://semver.org/) spec with one extension: because OCCTSwift is a wrapper, the bundled OCCT version is part of the consumer-visible contract. An OCCT major version bump is treated as a major event for the wrapper, even if the public Swift API technically didn't break.

## Quick reference

| Bump | Trigger | Examples |
|------|---------|----------|
| **MAJOR** (`x.0.0`) | Upstream OCCT major version bump (e.g. 8.x → 9.x) | OCCTSwift v1.0.0 (pinned to OCCT 8.0 GA, after the v0.x line tracked OCCT 7.8 → 8.0 RCs) |
| **MINOR** (`x.y.0`) | xcframework rebuild against a new OCCT release **OR** additive new public Swift API | A new wrapped operation, a new type, a new bridge function exposed to Swift |
| **PATCH** (`x.y.z`) | Bug fix, internal refactor, doc-only — **no public API surface change** | A `nil`-returning regression repaired, a wrong sort-order fixed, a dependency floor bump |

The load-bearing guarantee is the SemVer guarantee: **no breaking change without a major bump**. Within a major line, all minor and patch updates are safe to take blindly.

## Rules

### MAJOR — `x.0.0`

A major bump is reserved for two events, either of which alone is sufficient:

1. **OCCT major version bump.** A new OCCT major (e.g. 9.0) almost always reshapes the C++ API surface enough to force breaking changes in our Swift wrappers (renamed types, deleted classes, redesigned enums). Even when an OCCT major release coincidentally leaves our wrappers unchanged, we still bump major because the bundled binary is part of the contract — consumers are entitled to know the OCCT version changed. The whole cohort majors together.

2. **Breaking change to the public Swift API.** A removed type, a renamed method, a changed return type, a tightened parameter type, a raised platform floor — anything a consumer might have to fix on their side after pinning forward. This is rare within a major line because we promise stability there; if it happens, it triggers a major bump of the affected package (and possibly the cohort, if the change ripples downstream).

The cohort moved to v1.0.0 on 2026-05-07 alongside [OCCT 8.0.0 GA](https://github.com/Open-Cascade-SAS/OCCT/releases/tag/V8_0_0). The next major bump is reserved for OCCT 9.0 (no announced date).

### MINOR — `x.y.0`

A minor bump is for additive change. Two routes:

1. **xcframework rebuild against a new OCCT minor / patch / RC.** OCCT ships a stability patch, a bug-fix release, an RC, or a beta — we rebuild the xcframework, the binary URL+checksum in `Package.swift` updates, consumers re-download. This is treated as MINOR because the binary swap is a meaningful "new functionality" event even when the Swift API surface is identical.

2. **Additive new public Swift API.** A new `Shape.foo()` method, a new `Wire.bar` static factory, a new `TopologyGraph.baz` field, a new `FeatureSpec` case — anything that adds to the surface without removing or changing what's there. Existing callers are unaffected; new callers can opt in.

Either case bumps minor. A release that does both (e.g. rebuilds against new OCCT *and* adds a new wrapped operation that the rebuild made available) is one minor bump, not two.

### PATCH — `x.y.z`

A patch bump is for fix-only change with **no public API surface change**:

- A method that returned `nil` when it shouldn't, now returns the right value
- A constant whose value was wrong, now correct
- A switch case that was missing (`NodeKind.product` was missing the raw value 10 — this was OCCTSwift v1.0.1)
- An internal refactor that doesn't change any public behavior
- A dependency floor bump in `Package.swift` (e.g. raising `OCCTSwiftViewport from: "0.55.2"` to `from: "1.0.1"`) — even when the bump unblocks new features downstream, the bump itself is a fix, not new functionality
- Documentation-only releases (CHANGELOG entries, README updates, doc-comment tightening)

The shape of the public Swift API is unchanged before and after a patch.

## Cohort coordination

The OCCTSwift ecosystem is a layered family. Coordination rules:

### Lockstep on MAJOR

When OCCTSwift bumps major (next event: OCCT 9.x), every package in the cohort bumps to the matching major in coordinated fashion. Pre-1.0 history showed this: ~170 OCCTSwift point releases tracked the OCCT 7.8 → 8.0 RC sequence, and the whole public cohort graduated to v1.0.0 on the same day OCCT GA tagged.

The mechanism: a single tracker issue on OCCTSwift (e.g. [#96](https://github.com/gsdali/OCCTSwift/issues/96) was the v1.0.0 inbound), referenced by per-repo tracker issues, all closed on the cohort cut day.

### Independent within a major

Within a major line, each package versions on its own cadence. OCCTSwiftTools can ship v1.0.5 the same day OCCTSwift ships v1.4.2 — there's no rule that minor / patch numbers align across packages. They share a major; that's it.

In practice this means:
- Sibling features (e.g. `PointConverter` in Tools) bump that sibling's minor without touching OCCTSwift's version.
- Bug fixes in one package don't ripple version numbers elsewhere unless those fixes change a public API the dependent reads.

### Floors in `Package.swift` and `ecosystem.md`

When a sibling ships a feature a downstream consumer needs, bump the declared dep floor in `Package.swift` of the consumer **even if SPM would resolve forward automatically under SemVer**. The bumped floor signals intent: "the consumer needs at least this version."

Same for the [compatibility matrix in `ecosystem.md`](ecosystem.md#compatibility-matrix-v100-cohort-may-2026) — keep the floors there at the latest patch each consumer should be using. A floor bump is a PATCH-level change in the consuming package (it doesn't change *its* public API).

## Examples

Drawn from the v1.0 cohort's actual history:

| Release | Bump | Why |
|---------|------|-----|
| OCCTSwift v1.0.0 | MAJOR | OCCT 8.0.0 GA pin (cohort bump from v0.x) |
| OCCTSwift v1.0.1 | PATCH | `NodeKind.product` raw-value fix — `rootNodes` had been silently returning `[]` for assembly graphs. No API change. |
| OCCTSwift v1.0.2 | (would have been MINOR going forward) | Added `unionWithFullHistory` / `subtractedWithFullHistory` / `intersectionWithFullHistory` / `splitWithFullHistory` + `ShapeHistoryRef` class + `ShapeHistoryRecord` struct. **Additive — should have bumped minor under this policy.** Tagged as patch before this policy was formalized. |
| OCCTSwift v1.0.3 | (would have been MINOR going forward) | Tier 2 modification ops + `BuildResult.histories` field. **Additive — should have bumped minor.** |
| OCCTSwift v1.0.4 | (borderline; PATCH was acceptable) | Wired `applyFillet` / `applyChamfer` through `*WithFullHistory`; `BuildResult.histories[id]` now populates for fillet / chamfer specs. The public surface didn't change — only the *behavior* of an existing field changed (more ids show up in the map than before). PATCH was defensible; under a strict reading, MINOR would have been more honest. |
| OCCTSwiftTools v1.0.1 | (would have been MINOR going forward) | Added `PointConverter.pointsToBody` — a new public type and method. Tagged as patch. |
| OCCTSwiftTools v1.0.2 | PATCH | Bumped `OCCTSwiftViewport` floor `0.55.0` → `1.0.1` and `OCCTSwift` floor `1.0.1` → `1.0.3`. Pure dep-floor bump. |
| OCCTMCP v1.1.1 | PATCH | Fixed a hard-stale Viewport pin (`from: "0.55.2"` couldn't resolve to 1.0.x). |

### Retroactive note

Releases prior to this policy (v1.0.2, v1.0.3, OCCTSwiftTools v1.0.1) under-counted minor bumps for additive Swift APIs — they shipped as patches. We don't renumber history. **Effective from this document's commit, additive public-Swift-API releases bump minor.** The next OCCTSwift release that adds new wrapped operations will be **v1.1.0**, not v1.0.5.

## Decision flow

```
        ┌─────────────────────────────────┐
        │  What changed in this release?  │
        └────────────┬────────────────────┘
                     │
         ┌───────────┼───────────┬────────────────┐
         ▼           ▼           ▼                ▼
   OCCT major     OCCT minor /  Public Swift     Bug fix
   bump           patch / RC    API: added      only / dep
   (e.g. 9.0)     rebuild       a method,       floor bump
                                type, etc.
         │           │           │                │
         ▼           ▼           ▼                ▼
       MAJOR       MINOR       MINOR            PATCH
       (cohort)
```

If a release combines several categories (e.g. an OCCT rebuild *and* new Swift API), pick the highest applicable bump — one release, one version increment.

If a release is ambiguous (the v1.0.4 case — behavior change with no surface change), default to PATCH and call out the behavioral delta in the changelog. If consumers might miss it without reading carefully, MINOR is more defensible.

## Tooling expectations

- `Package.swift` `from: "1.0.0"` resolves to the range `[1.0.0, 2.0.0)`. Take any minor / patch update blindly within a major line; pin `exact:` only if you have a specific reason.
- Swift Package Index updates per-package pages from each repo's tags; the policy above keeps badges accurate without manual intervention.
- The xcframework asset is attached to OCCTSwift releases that include a binary rebuild (every MAJOR and most MINORs). PATCHes typically reuse the previous binary URL — no asset attached, `Package.swift` URL/checksum unchanged.

## When in doubt

- "Will this break a consumer's build if they take it blindly?" — yes → MAJOR.
- "Is there new functionality consumers can opt into?" — yes → MINOR.
- "Is this purely a fix or floor bump?" — yes → PATCH.

Document the choice in the changelog. The point of SemVer is communication — the version number is a contract with consumers about what they'll have to do (or not do) when they update.
