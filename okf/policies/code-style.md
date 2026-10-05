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

**Do not hand-format the bridge; run `Scripts/format-bridge.sh`.** It rewrites every enforced file
in place, and `--check` is the report-only form CI and the pre-commit hook both invoke, so all three
run one copy of the file selection and the check loop rather than three that can drift.
`AlignConsecutiveDeclarations`/`AlignConsecutiveAssignments` make this non-negotiable in practice:
two ordinary consecutive locals are a violation unless the tool wrote them, and the alignment run is
broken by things that are not obvious by eye (a `_Nonnull` in a parameter list is enough), so
imitating the style by hand produces something that looks formatted and is not.

**The clang-format version is pinned** in `Scripts/clang-format-version.txt`, read by CI, by the
script, and through the script by the hook. clang-format's output changes between major versions:
21.1.8 and 22.1.8 were measured to disagree on 10 of the bridge files enforced that day, so an
unpinned `brew install clang-format` can turn a green `main` red on a Homebrew bump with no code
change. CI installs exactly the pinned version from PyPI (a ~2 MB wheel, byte-identical output to
the Homebrew bottle of the same version) and asserts it; the script refuses a different major
locally rather than letting you produce a diff CI will reject. OCCT's own CI pins for the same reason.
`Scripts/install-clang-format.py` installs the pinned binary using nothing but the Python standard
library, for images with no working pip or venv;
[`docs/guides/clang-format-setup.md`](../../docs/guides/clang-format-setup.md) covers every route
and how to verify one.

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
`swift-format` sweep under the manifest rule the policy had then, disproportionate for a
CI-infrastructure PR. #877 has since closed and both files were brought into line, so neither is
excluded.

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

## Rollout: finished, and the exemption manifests are retired

This repo did not sweep into compliance in one PR. It measured ~11,700 pre-existing `swift-format`
diagnostics across `Sources/OCCTSwift` and multi-thousand-line-per-file `clang-format` diffs across
every file of `Sources/OCCTBridge` on rollout day, and a whole-tree gate would have failed every PR
against work nobody had touched. So it adopted the policy gradually: checked-in manifests listed
every file that existed at rollout, a listed file was exempt until touched, and
`Scripts/check-style-manifest.py` made touching one mean fixing it and deleting its line.

**That is over.** The manifests drained to nothing, and then were deleted with the checker and its
two CI steps:

- `Sources/OCCTBridge` finished first: all 93
  `Sources/OCCTBridge` files are enforced by `clang-format`, and the version is pinned for the
  reason `code-style.yml` gives. That 93 is the live population, derived from the tree by
  `check-inventory-prose.py` and held to this sentence on every PR; `CLAUDE.md` used to carry a
  second copy of it, said 33 for as long as the #1378/#1380 split had been in the tree, and no
  longer states it at all (#2910, #2954).
- `Sources/OCCTSwift` finished next, and the widening of #2852 then added a second manifest of the
  files the wider population newly reached (`Tests/`, `Scripts/`, `Sources/OCCTPlatform` and the
  rest). That one was the last to go: the final 244 files were run through `swift-format format -i`,
  which cleared about 750 of 1,340 findings, and the rest were `BeginDocumentationCommentWithOneLineSummary`
  (562, which wants a sentence boundary written down, not a line rewrapped) and a few dozen
  one-offs, fixed by hand or by a script that refused to guess.
- **Nothing is exempt now.** Every tracked `.swift` file passes `swift-format lint --strict` and
  SwiftLint `--strict`, with no list to consult and none to grow back.

**A deliberate exception is written where it occurs**, with swift-format's own
`// swift-format-ignore: <Rule>` on the declaration, and the reason beside it. It is used for
single-letter mathematical constants in tests (`let A = ...` for a matrix, `R` for a major radius),
which `AlwaysUseLowerCamelCase` would have renamed away from the notation the test is about.
`git grep swift-format-ignore` is the complete list. Do not add a manifest to hold exceptions: a
list beside the code is how this repo ended up with 418 files exempt and nothing in the files saying so.

Why the gradual route was taken, and what it taught: the ecosystem-wide proposal and evidence
(comment:code ratios, a live doc-drift bug found in `docs/reference/CurveAdaptors.md`) live in
[`ecosystem` docs/code-style-policy-proposal-2026-08.md](https://github.com/SecondMouseAU/ecosystem/blob/main/docs/code-style-policy-proposal-2026-08.md).
Rollout sequencing is in that document's §4. Filed and tracked as
[OCCTSwift#876](https://github.com/SecondMouseAU/OCCTSwift/issues/876).

## What the gate reads

**An exemption list can only exempt a file the gate's population already reaches, and until #2852
the population was one directory.** `code-style.yml`'s `swift-format` step ran
`find Sources/OCCTSwift -name '*.swift'`: 230 of the repo's 1,730 tracked Swift files. `Tests/`
(1,459), `Scripts/` (35), `Sources/OCCTPlatform`, `Sources/OCCTTest`, `Sources/WASICompat` and
`Package.swift` were outside it, the step was green, and nothing in the manifest said so, because
an exemption list reads as a complete statement of what is unchecked and this one could not be.
#2839 is what it cost: `Sources/OCCTPlatform`, the target holding every platform conditional in
the package, arrived unlinted for no reason anyone chose.

`Scripts/check-swift-format.py` owns the population now, and the population is
`git ls-files '*.swift'`, all of it. A new target, directory or top-level file is linted from
creation, with no path for anyone to remember to widen. Its `--list` prints the population; its
real run asserts that **the selection equals every tracked `.swift` file**, so a future narrowing
is a red gate rather than a quieter one, and it plants a canary violation in every `swift-format`
invocation so a tool that reports nothing aborts the run instead of passing it. Both devices are
[static-gates](static-gates.md)'s, for its reason: a `--self-test` proves the detector catches what
its author thought of, and cannot prove it looked at the real input.

**SwiftLint had the same gap and it was cheaper.** `.swiftlint.yml`'s `excluded:` held `Tests` and
`Scripts`, so `swiftlint --strict` read 234 files, not the repository. Widening it cost exactly one
fix: `orphaned_doc_comment` found a single finding across the 1,494 files it newly reached, a `///`
block detached from its declaration by an inserted `// MARK:`. Two more files stayed excluded after
that, `Sources/OCCTSwift/Surface.swift` and `Shape+Modeling.swift`, behind a note saying to remove
them once [#877](https://github.com/SecondMouseAU/OCCTSwift/issues/877) landed. #877 closed and the
note stayed; both files linted clean when the exclusion was lifted, and it is gone. `excluded:` now
holds only build output (`.build`, `Libraries`), which is not source.

**The count that used to be kept nowhere is gone, not hidden** (#2954). The manifest's length was
stated in `CLAUDE.md`, shared by every open PR and invalidated by every merged one, and went 267 to
262 in a day and took three unrelated PRs red at merge time. With no manifest there is no figure.

Ecosystem standard: see
[OKF-STANDARD.md](https://github.com/SecondMouseAU/ecosystem/blob/main/OKF-STANDARD.md).
