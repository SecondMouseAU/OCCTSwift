---
type: policy
title: Upstream OCCT PRs — style and submission workflow
description: PRs offered to OpenCASCADE must be clang-formatted with OCCT's own .clang-format, use OCCT's concise comment style not OCCTSwift's, and include a GTest by default; when a fix is ready, go straight to a PR — don't file a separate issue first.
tags: [policy, occt, upstream, contributing, formatting, workflow, gtest]
timestamp: 2026-08-11
---

# Upstream OCCT PRs — style and submission workflow

We contribute fixes upstream, not just issues — the [carried OCCT patches](../references/carried-occt-patches.md)
are written to be offered to OpenCASCADE, and each is retired once an upstream release contains it.
A patch only lands upstream if it reads like OCCT's own code, and reaches them the way they've
asked to receive it. Three requirements before opening (or attaching a patch to) an OCCT PR:

1. **Format with OCCT's `.clang-format`, not ours.** Run `clang-format` against the `.clang-format`
   file at the root of the OCCT source tree the patch applies to — over only the lines you changed.
   Do not reformat surrounding code, and do not fall back to OCCTSwift's or your editor's default
   style: OCCT's braces, indentation, and column limits differ from ours, and a diff that reformats
   untouched lines will be rejected on sight.

2. **Match OCCT's concise comment house style.** OCCT comments are terse — a brief `//!` Doxygen
   header on a declaration, a short `//` note only where the logic isn't self-evident, no narration.
   Do **not** carry OCCTSwift's expansive doc-comment voice (the multi-sentence "why", runnable
   examples, issue back-references) into upstream C++. State the mechanism and stop. Keep our own
   rationale — issue numbers, the reproducer, workaround history — in the PR description / commit
   message, never in the source comments.

3. **Include a GTest by default, in the same commit.** Measured, not assumed: of our 11 open upstream
   PRs as of 2026-08-10, maintainer dpasukhi asked for one on every single PR that didn't already have
   one (5 for 5 — #1410, #1432, #1435, #1445, #1447), always the same phrasing ("please add GTest to
   cover your changes, you can follow the logic of all exited GTests"). The one PR that already
   shipped a GTest (#1386, `Intf_TangentZone_Test.cxx` / `Intf_Interference_Test.cxx`) was never asked.
   Five other open PRs hadn't been reached by that review pass yet at measurement time and are likely
   to get the identical ask once he gets to them — this reads as a blanket expectation, not
   case-by-case discretion. Put the new test under
   `src/<Toolkit>/<Package-or-toolkit-level>/GTests/<Class>_Test.cxx` (GTests directories are organized
   per **toolkit**, e.g. `TKShHealing`, `TKGeomAlgo`, not per individual package — check whether one
   already exists before creating a new folder), register it in that directory's `FILES.cmake`
   (alphabetical), and follow `TEST(<Class>Test, <CaseName>)` naming (no underscore before `Test`) —
   copy the nearest existing test in the same GTests folder for exact style (`ASSERT_*` for
   preconditions, `EXPECT_*` for the actual check, minimal comments matching rule 2 above). Compile
   and link it against `Libraries/OCCT.xcframework` + a local `gtest`/`gtest_main` (`brew install
   googletest`) before pushing — don't just eyeball it. Follow this repo's own
   [`prove-the-test-fails`](prove-the-test-fails.md) policy on it too: override-link a copy of the
   touched `.cxx` with the fix reverted, link it ahead of the real archive, and confirm the new test
   actually fails (crashes, or the assertion trips) before confirming it passes against the real fix.

4. **Go straight to a PR when a fix is ready — don't file a separate issue first.** Our older
   pattern (see the pre-2026-07-30 rows in [carried-occt-patches.md](../references/carried-occt-patches.md))
   was always repro-issue-then-fix-PR, two separate items. An OCCT maintainer has since said
   directly that the issue step isn't wanted when a PR is already in hand:
   > Thank you for your contribution. In case if you preparing PR, no needs to create Issue.
   > Issue is recommended to create when you are not working on PR ;)
   — [Open-Cascade-SAS/OCCT#1409 (comment)](https://github.com/Open-Cascade-SAS/OCCT/issues/1409#issuecomment-5124395058)

   So: if we're submitting a fix, open the PR directly — the PR description carries the repro and
   root cause, same as an issue would have. Only open a standalone issue when we don't yet have a
   fix ready to attach (a report without a PR), matching what the maintainer actually asked for.

This is a **context switch, not our default**: inside OCCTSwift (the `.mm` bridge and the Swift API)
we keep our own conventions, including the verbose doc comments the [docs-current](docs-current.md)
policy expects. OCCT's house style applies only to code destined for the OCCT tree.

See OCCT's own coding rules and contribution workflow (dev.opencascade.org) for the authoritative
detail; this policy just makes the non-negotiables explicit so a patch isn't bounced on style, and
doesn't create process friction upstream maintainers have explicitly said they don't want.
