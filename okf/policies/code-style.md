---
type: policy
title: Code style
description: Swift naming/API shape follows the Swift API Design Guidelines, formatting follows Google's Swift Style Guide via swift-format, and the OCCTBridge C++ layer follows OCCT's own clang-format and terse comment style; docs/ is the single source of truth for design rationale, not a second copy of it. Rolled out gradually via an exemption manifest, not a big-bang sweep.
tags: [policy, style, swift, cpp, docs, agents]
timestamp: 2026-08-12
---

# Code style

**Naming and API shape** follow the
[Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) as-is,
already partially the case here (`docs/naming-conventions.md` cites it for the `-ed`/`-ing`
verb-tense convention).

**Swift formatting** follows [Google's Swift Style Guide](https://google.github.io/swift/),
enforced by `swift-format` (`.swift-format`: 100-column limit, 4-space indent, the ecosystem's
one deliberate divergence from Google's own 2-space default, chosen to avoid a repo-wide reformat
diff with no readability gain).

**The `OCCTBridge` C++ layer** (`Sources/OCCTBridge/*.h`/`*.mm`) follows OCCT's own
`.clang-format`, checked in at `Sources/OCCTBridge/.clang-format` (the vendored copy at
`Libraries/occt-src/.clang-format` is gitignored, not present in a fresh clone, so CI needs its own
copy). This is a change from [upstream-occt-style](upstream-occt-style.md)'s previous framing,
which described the bridge as keeping "our own conventions" and reserved OCCT's house style for
literal patches submitted upstream; that policy has been updated to reflect that the bridge now
targets OCCT's style too, since it's OCCT-adjacent C++ written in OCCT's own idiom. The **Swift
public API** is unaffected: it keeps the verbose doc comments [docs-current](docs-current.md)
expects, same as before.

**SwiftLint is scoped to `orphaned_doc_comment` only** (`.swiftlint.yml`, `only_rules`, not the
default set). SwiftLint's defaults duplicate `swift-format`'s formatting opinions (can disagree
with them on the same line) and separately add a large code-quality/complexity surface
(`identifier_name`, `cyclomatic_complexity`, `function_body_length`, `nesting`, ...) that overlaps
[code-structure](code-structure.md) rather than this policy; a file that needs a structural pass
runs one as its own scoped initiative, not as a side effect of a style-lint gate.
`orphaned_doc_comment` catches something `swift-format` has no equivalent for, and already found
two real bugs on rollout day: two doc comments separated from their declarations by an inserted
`// MARK:`, one of them documenting a function (`Surface.toBezierPatches()`) that currently has no
doc comment of its own. Tracked as [#877](https://github.com/SecondMouseAU/OCCTSwift/issues/877)
rather than fixed inline, since fixing either one would have obligated a full-file
`swift-format` sweep under this policy's own manifest rule (below), disproportionate for a
CI-infrastructure PR. Both files are named in `.swiftlint.yml`'s `excluded:` list until #877
lands.

**Doc comments stay terse.** A `///` comment is a single-sentence summary plus only the
`Parameter`/`Returns`/`Throws` tags that add something the summary doesn't already say. Design
rationale, extended examples, and issue cross-references belong in `docs/`, not duplicated in
source: `docs/` is the single source of truth for *why* and *how*, per
[GitLab's documentation style guide](https://docs.gitlab.com/development/documentation/styleguide/)
("share the link to the documentation instead of rephrasing the information").
`Scripts/comment-ratio-check.py` flags (never fails) a file whose comment lines outnumber its code
lines, as a signal for review, not an automatic failure.

**An internal or private function returning a tuple with baked-in labels should return an
unlabeled tuple instead.** Swift does not implicitly relabel a labeled source tuple into a
differently-labeled destination tuple, so a function that bakes in its own labels
(`origin`/`direction`, `min`/`max`, ...) forces every call site whose own labels differ into a
two-step bind-then-relabel instead of a direct return. The rule is general, not limited to
bridge-unwrapping helpers: any non-public function with this shape hits the identical wall the
moment a caller wants different labels, though a bridge-unwrapping helper is where it was first
found. Returning the bare, unlabeled tuple lets each call site's own declared return type supply
whatever labels it wants, with no relabeling step and no loss: the function's own labels were only
ever documentation, never load-bearing, so dropping them costs nothing a `- Returns:` tag can't
restate once, on the function itself. Established by
[#903](https://github.com/SecondMouseAU/OCCTSwift/issues/903)/[#904](https://github.com/SecondMouseAU/OCCTSwift/pull/904)
on `ShapeAxis.swift`'s `unwrapAxisComponents(_:)`.

## Gradual rollout: the exemption manifest, not a big-bang sweep

Unlike the ecosystem's pilot repo (`OCCTSwiftScripts`, small enough to sweep into full compliance
in one PR), this repo measured ~11,700 pre-existing `swift-format` diagnostics across
`Sources/OCCTSwift` and multi-thousand-line-per-file `clang-format` diffs across every one of
`Sources/OCCTBridge`'s 33 files on rollout day, a whole-tree gate would fail every PR against
work nobody has touched. Instead:

- `Scripts/style-manifest-swift.txt` and `Scripts/style-manifest-bridge.txt` list every file that
  existed at rollout. A listed file is exempt from `swift-format`/`clang-format` until touched.
- **If you touch a listed file, you fix it and remove it from the manifest in the same PR.**
  `Scripts/check-style-manifest.py` enforces this mechanically: a manifest file appearing in a
  PR's diff while still listed at `HEAD` fails the build. This is the CI-enforceable version of
  the rollout's own stated principle: fix what you touch, not the whole tree at once.
- The manifest only shrinks. A new file is never grandfathered onto it; new code complies from
  creation, checked by the same `swift-format`/`clang-format`/SwiftLint steps running unconditionally
  against anything not already listed.

Why: the ecosystem-wide proposal and evidence (comment:code ratios, a live doc-drift bug found in
`docs/reference/CurveAdaptors.md`) live in
[`ecosystem` docs/code-style-policy-proposal-2026-08.md](https://github.com/SecondMouseAU/ecosystem/blob/main/docs/code-style-policy-proposal-2026-08.md).
Rollout sequencing (`OCCTSwift` first, timed to land after `refactor/382-pass2a`, riding the
refactor rather than a separate sweep) is in that document's §4. Filed and tracked as
[OCCTSwift#876](https://github.com/SecondMouseAU/OCCTSwift/issues/876).

Ecosystem standard: see
[OKF-STANDARD.md](https://github.com/SecondMouseAU/ecosystem/blob/main/OKF-STANDARD.md).
