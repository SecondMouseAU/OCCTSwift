---
type: policy
title: Upstream OCCT PRs follow OCCT's house style
description: PRs offered to OpenCASCADE must be clang-formatted with OCCT's own .clang-format and use OCCT's concise comment style — not OCCTSwift's.
tags: [policy, occt, upstream, contributing, formatting]
timestamp: 2026-07-19
---

# Upstream OCCT PRs follow OCCT's house style

We contribute fixes upstream, not just issues — the [carried OCCT patches](../references/carried-occt-patches.md)
are written to be offered to OpenCASCADE, and each is retired once an upstream release contains it.
A patch only lands upstream if it reads like OCCT's own code. Two hard requirements before opening
(or attaching a patch to) an OCCT PR:

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

This is a **context switch, not our default**: inside OCCTSwift (the `.mm` bridge and the Swift API)
we keep our own conventions, including the verbose doc comments the [docs-current](docs-current.md)
policy expects. OCCT's house style applies only to code destined for the OCCT tree.

See OCCT's own coding rules and contribution workflow (dev.opencascade.org) for the authoritative
detail; this policy just makes the two non-negotiables explicit so a patch isn't bounced on style.
