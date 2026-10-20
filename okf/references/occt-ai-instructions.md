---
type: reference
title: OCCT's AI development instructions
resource: https://github.com/Open-Cascade-SAS/OCCT/blob/IR/.github/copilot-instructions.md
tags: [reference, occt, upstream, contributing, agents, style]
description: The OCCT maintainers' own instructions for AI-assisted contributions, which they asked contributors to give their assistant (discussion 1645, 2026-10-19). Read the live file at the start of any task whose output lands in the OCCT tree; this page records where it binds us and the rules that differ from our habits or from our own policies.
timestamp: 2026-10-20
---

# OCCT's AI development instructions

OCCT's maintainers publish `.github/copilot-instructions.md` on the `IR` branch and, in
[discussion 1645](https://github.com/Open-Cascade-SAS/OCCT/discussions/1645) (2026-10-19, dpasukhi
for the OCCT3D team), ask anyone using an AI assistant to give it that file. They say it makes
assistants follow OCCT conventions and fix the root cause rather than add a workaround. Everything
we send upstream is AI-assisted, so it applies to us without exception.

**The file is canonical and this page is not a copy of it.** It changes: 305 lines at `IR`
`8f95c78c7`, last edited 2026-10-13 (#1628). Read the live file before starting upstream-bound work:

```bash
cd upstream/occt && git fetch upstream IR && git show upstream/IR:.github/copilot-instructions.md
```

## Where it binds

Anything that lands in the OCCT tree: the carried patches in `Scripts/patches/`, upstream PRs, the
GTests in them, and the text of the PR and its commits. A dispatch prompt for such work names the
file and says to read it; it does not paraphrase it.
The Swift API keeps [docs-current](../policies/docs-current.md); the bridge keeps
[code-style](../policies/code-style.md).

## What the discussion asks of contributors

- **Open a GitHub issue first** for a new contribution, with a detailed description, expected
  behavior and technical findings. They single out fixes found through AI-assisted analysis.
- **Keep external PRs small and focused**: one bug fix or one feature.
- They will make adjustments and minor fixes themselves instead of asking for rounds of changes,
  and will explain when a fix is not stable enough or does not fit the architecture.
- A signed CLA is required. It is now submitted through the OCCT3D contact form. Ours is ID 1139.

The first point reverses the "go straight to a PR" rule this project recorded in August; see
[upstream-occt-style](../policies/upstream-occt-style.md) requirement 4.

## Rules that differ from our habits, checked 2026-10-20 against #1648 to #1650

| Rule (section of the file) | What it means for our patches |
|---|---|
| ASCII only in code, comments, docs and reports (3) | No typographic quotes, arrows or symbols in anything upstream. |
| Banned words: "opaque", "probe", "materialization", "payload", "playground", "leverage", "seamless", "robust solution", "delve", "unlock", "orchestrate" (3) | Applies to new names and prose, including PR text. |
| Short sentences, B1 English (3) | Shorter than our PR bodies tend to be. |
| Comments are production comments, not change history; do not describe the fix or the old code (8) | The PR carries the story. The code states the constraint. |
| New definitions get a `//` plus 98 `=` separator and a blank line; no `function:` / `purpose:` banners (8) | Do not copy the banner style of the neighbouring old definitions. |
| Declarations carry the `//!` documentation, with `@param[in]` and `@return` (8) | For new or materially changed declarations only. |
| No STL owned containers or strings in new code: use `NCollection_*` and `TCollection_*` (5) | Streams force `std::string` at the interface; consume it, do not spread it into helpers. |
| Native types, not `Standard_Integer` and friends; `size_t` for sizes (7) | Check each new line. |
| Explicit types; `auto` only for lambdas, structured bindings, iterators and range loops (7) | |
| `Math*_*` facilities for new numerical code; `EvalD0`..`EvalDN` for evaluation (6) | |
| GTests: self-contained, no data files, deterministic; `ClassNameTest.Method_Scenario_Expected` for a new suite; follow the surrounding suite otherwise (9) | |
| `EXPECT_THROW` only where the throw is not compiled out by `No_Exception`; never swap it for `EXPECT_NO_THROW` (9) | Same fact as [occt-validation-is-compiled-out](../policies/occt-validation-is-compiled-out.md). |
| Check the requested result, not only `IsDone()` or the absence of an exception (9) | |
| The regression test fails for the original reason before the fix (1) | Same as [prove-the-test-fails](../policies/prove-the-test-fails.md). |
| Do not commit or create branches unless asked (2) | Our workflow asks for both. |

## Where it presses on our carried patches

- **"Fix the cause, not the symptom" (1).** Input validation is accepted "at a documented
  boundary", and a null check "must not silently turn an unexpected failure into an empty
  successful result". The file readers (0070 to 0074) validate untrusted file data at the reader,
  which is the boundary. The PR text must say so and name the first violated contract, not only the
  crash. A patch that skips an entity, forces success or catches everything will be refused.
- **"A temporary mitigation requires explicit user approval" (1).** This is the standing rule for
  our bridge guards (`occtReadBREPStream`, `occtOcafDeclaredSizesFit`, the null-handle guards):
  each one is a mitigation of an OCCT defect, so each needs a tracking issue and a retirement
  condition. See [known-occt-bugs](known-occt-bugs.md).
- **The contribution procedure (2).** Read callers and tests first, define acceptance criteria,
  make the smallest complete change, run the narrowest test first, report exactly what was run and
  what was not. It matches our dispatch reports; keep "not verified" lists.

## Related

[Upstream OCCT PRs: style and submission workflow](../policies/upstream-occt-style.md),
[Upstream OCCT patch process](../policies/upstream-occt-patch-process.md),
[Carried OCCT source patches](carried-occt-patches.md).
