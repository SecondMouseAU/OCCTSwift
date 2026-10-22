---
type: policy
title: Upstream OCCT PRs, style and submission workflow
description: PRs offered to OpenCASCADE must be clang-formatted with OCCT's own .clang-format, follow OCCT's own AI development instructions, use OCCT's concise comment style not OCCTSwift's, and include a GTest by default; since 2026-10-19 open an issue first for a new contribution and keep the PR small. Formatting and GTest mechanics live in the patch-process doc, not here.
tags: [policy, occt, upstream, contributing, formatting, workflow, gtest]
timestamp: 2026-10-20
---

# Upstream OCCT PRs, style and submission workflow

We contribute fixes upstream, not just issues, the [carried OCCT patches](../references/carried-occt-patches.md)
are written to be offered to OpenCASCADE, and each is retired once an upstream release contains it.
A patch only lands upstream if it reads like OCCT's own code, and reaches them the way they've
asked to receive it. Five requirements before opening (or attaching a patch to) an OCCT PR:

1. **Format with OCCT's `.clang-format`, not ours, and don't trust a clean local run as proof.** Run
   `clang-format -style=file` against the `.clang-format` file at the root of the OCCT source tree the
   patch applies to, and do not fall back to OCCTSwift's or your editor's default style: OCCT's
   braces, indentation, and column limits differ from ours, and a diff that reformats untouched code
   will be rejected on sight. But a clean local pass is a first filter, not proof of anything, your
   local `clang-format` binary can be a different version from the one CI actually runs, and the two
   can genuinely disagree on multi-line alignment for the identical input. See
   [§4 Format](upstream-occt-patch-process.md#4-format) in the patch-process doc for the mechanics,
   the version-skew evidence, and what to do (pull CI's own `format.patch` artifact) when its check
   still fails after a clean local run.

2. **Match OCCT's concise comment house style.** OCCT comments are terse, a brief `//!` Doxygen
   header on a declaration, a short `//` note only where the logic isn't self-evident, no narration.
   Do **not** carry OCCTSwift's expansive doc-comment voice (the multi-sentence "why", runnable
   examples, issue back-references) into upstream C++. State the mechanism and stop. Keep our own
   rationale, issue numbers, the reproducer, workaround history, in the PR description / commit
   message, never in the source comments. OCCT's own AI instructions say the same (§8: production
   comments, not change history) and add rules on ASCII, banned words and container types; read
   [OCCT's AI development instructions](../references/occt-ai-instructions.md) before writing any
   upstream-bound code, comment or test.

3. **Include a GTest, in the same commit, not optional even for a fix that looks too small to need
   one.** Measured, not assumed: of 11 open upstream PRs as of 2026-08-10, maintainer dpasukhi asked
   for one on every single PR that didn't already have one (5 for 5), always the same phrasing. See
   [§2 Add a GTest](upstream-occt-patch-process.md#2-add-a-gtest-in-the-same-commit) in the
   patch-process doc for the full evidence, where the test file goes, naming, and how to prove it
   actually catches the defect before pushing.

4. **Open an issue first for a new contribution, then a small PR that links it.** The maintainers
   asked for this on 2026-10-19 ([discussion 1645](https://github.com/Open-Cascade-SAS/OCCT/discussions/1645)):
   a GitHub issue with the problem, expected behavior and technical findings, particularly when the
   fix came from AI-assisted analysis, and PRs "small, focused, and limited to a specific bug fix or
   feature". Where an upstream issue already describes the defect (check first), link it with
   `Closes` or `Refs` and do not file another. The PR description still carries the reproducer and
   root cause.

   This replaces the earlier rule, which was to skip the issue when a PR is in hand. That came from
   an exchange on [OCCT#1409](https://github.com/Open-Cascade-SAS/OCCT/issues/1409#issuecomment-5124395058)
   ("In case if you preparing PR, no needs to create Issue"). The newer, general announcement
   wins; the exchange was one maintainer on one PR. The PRs sent on 2026-10-20 (#1648 to #1650)
   went out before the announcement was read and have no issue.

   One PR per defect: a change that touches several subsystems is split so each part can land on
   its own, as 0073 and 0074 are.

   **Target `IR`, not `master`** (maintainer dpasukhi, 2026-10-07: `IR` is always the
   integration branch and `master` is never merged into directly; a PR against `master` is tolerated
   for older PRs, since he changes the base himself). Upstream CI also runs a license check and
   include cleanup, and an observed clang-format 18.1.8 matched its format check on all five PRs of
   2026-10-07/08; see [§10](upstream-occt-patch-process.md#10-upstream-ci-facts) for the CI facts.

5. **The CLA is signed (ID 1139).** Fill the template's CLA section with it. The maintainers now
   take new CLAs through the OCCT3D contact form.

This is a **context switch from the Swift API**, not from the bridge: the Swift public API keeps
its own conventions, including the verbose doc comments the [docs-current](docs-current.md) policy
expects. The `.mm`/`.h` bridge layer is different: since [code-style](code-style.md), it targets
OCCT's own `.clang-format` and terse comment style too (it's OCCT-adjacent C++, written in OCCT's
own idiom), phased in via that policy's exemption manifest rather than applied immediately. So a
patch destined for the OCCT tree and a change to `Sources/OCCTBridge/` end up close in style, for
the same reason in both cases: the code sits next to, or inside, OCCT's own house style.

See OCCT's own coding rules and contribution workflow (dev.opencascade.org) for the authoritative
detail; this policy just makes the non-negotiables explicit so a patch isn't bounced on style, and
doesn't create process friction upstream maintainers have explicitly said they don't want.

## Related

[OCCT's AI development instructions](../references/occt-ai-instructions.md) is the maintainers'
own rule file for AI-assisted work, with the rules that differ from our habits.
[Upstream OCCT patch process, start to finish](upstream-occt-patch-process.md) covers the rest of the
lifecycle this policy doesn't: the full GTest and formatting mechanics behind requirements 1 and 3
above, proving a fix actually changes behavior, the git mechanics of pushing to a live PR branch
without silently closing it, and working a review round once comments arrive.
