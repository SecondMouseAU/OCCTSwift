---
type: policy
title: Code structure
description: New code defaults to one type (or tight family) per file, organized by the repo's own existing domain vocabulary; a repo that already has blob files remediates them as a scoped, dedicated initiative rather than folding the cleanup into routine issues.
tags: [policy, structure, refactor, duplication]
timestamp: 2026-08-14
---

# Code structure

**Default for new code: one type, or one tight family of types, per file.** Group files by the
repo's own existing domain vocabulary rather than inventing a new one: this repo's own
per-domain test-target layout (`OCCT<Domain>Tests`) is exactly that vocabulary, so a new
`<Type>+<Domain>.swift` file uses those same domain names, keeping the taxonomy single-sourced
instead of drifting between how code is organized and how it's tested. When extending a type that
already lives in a large file, prefer adding a `<Type>+<Domain>.swift` split over appending to the
existing file further.

**This repo is the reference case for the remediation half of this policy.** The segmented
duplication audit ([#377](https://github.com/SecondMouseAU/OCCTSwift/issues/377), passes tracked
under `refactor/377-segmented-audit` / `refactor/381-pass1b`) is what the method below is drawn
from; see that initiative's own project board for current status before starting related work,
rather than assuming a file this policy would flag hasn't already been scoped.

1. **Segment before auditing.** Don't run one duplication/size lens over structurally different
   code in the same pass: hand-written bridge boilerplate (`OCCTBridge`) and hand-written Swift
   app logic (`OCCTSwift`) accumulate size and duplication for different reasons and need different
   judgment; #377 segments by exactly this layer boundary. Segment further within a layer by
   internal dependency or structural kind before auditing each segment on its own terms.
2. **Tell a mechanical split from a design-decision split before starting, and do the mechanical
   ones first.** A mechanical split is a pure lookup, "which file already defines this
   declaration" (the basis of #395's `OCCTBridge.h` → 16 domain headers split), with no judgment
   call in it; a design-decision split (#393/#394's `Document.swift`/`Shape.swift` breakouts)
   requires deciding where something *should* live. Do the mechanical split with a one-shot,
   throwaway migration script that reproduces the original content byte-for-byte (verify this
   mechanically, a sorted-symbol diff or equivalent, and put the result in the PR body), never by
   hand. Land it as one atomic PR: when an umbrella file and its new siblings must compile together,
   splitting that work across several agents or PRs by sub-domain leaves the tree non-compiling
   until the last one lands. Only take on the judgment-call splits once the mechanical pattern is
   proven; #395 went first for exactly this reason.
3. **For a bloated file named after one type: evict before you split.** First move out whatever
   doesn't actually belong to that type (standalone types, extensions on other types) to the file
   that actually owns them, one file per type or tight family. Only split what's left, and only if
   it's still too big. #393 found only 14% of `Document.swift` was actually `extension Document`;
   evicting the standalone types and foreign extensions first is what made the remaining split
   tractable. A file that turns out to already be a legitimate single concern after eviction stays
   one file; that's a legitimate outcome, not a failure to split further.
4. **Zero behavior change.** Bodies move verbatim: identical public API (signatures, doc comments,
   availability, access level), full `swift test` green, history that survives a `git mv`-style
   rename, and no new `SEMVER.md` break-register entries. If a split seems to need an actual
   behavior or API break, that's a sign something's being rewritten, not moved; pull it out as its
   own separately-reviewed change instead of hiding it inside a structural PR.
5. **Measure fresh, not from the plan.** File sizes and occurrence counts quoted in an issue or
   `docs/v2.0.0-plan.md` go stale as unrelated work lands elsewhere; measure again at the start of
   each pass rather than trusting the number already written down. Where the same family gets
   counted or measured more than once, build that count as a committed, executable script under
   `Scripts/repro/<cluster>/` that enumerates and measures against the real code, not a grep
   repeated by hand or a number typed into an issue body: repeated hand-recounts on this project
   have already been caught wrong more than once (#558 said 14 sites, measured 28; #583 said 5,
   measured 6).

**Enforcement: a report-only nudge, not a blocking gate.** The five steps above are a judgment
call a linter cannot safely apply on its own, so this policy stays a written default plus tracked
remediation rather than a mechanical threshold that fails a build. This repo carries the reference
implementation ([#906](https://github.com/SecondMouseAU/OCCTSwift/issues/906)):
`Scripts/file-size-check.py` flags any `Sources/OCCTSwift/*.swift` file at or above 900 lines (the
top of this policy's own stated normal range above, not a new number invented for the check) and
always exits 0, the same report-only shape as `comment-ratio-check.py`; wired as its own
`.github/workflows/code-structure.yml`, deliberately separate from `code-style.yml` since the two
are distinct policies. Measured on rollout day: 17 files already at or above 900 lines, from
`Surface.swift` (4,716) down to `SheetMetal.swift` (902), the live backlog this check now surfaces
release over release rather than a number that goes stale.

Why: `Sources/OCCTSwift` reached ~56,000 lines across 71 files before #377, dominated by two Swift
files and one bridge header that together ran to roughly 55,000 lines on their own, about 2.6x
OCCTMCP's entire codebase in three files. Nothing forced new code toward small, well-scoped files,
so it kept landing in whichever huge file already existed for that type.

Ecosystem standard: see
[OKF-STANDARD.md](https://github.com/SecondMouseAU/ecosystem/blob/main/OKF-STANDARD.md).
