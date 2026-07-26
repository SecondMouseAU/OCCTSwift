---
type: policy
title: Search before building
description: Search this repo and its dependencies meticulously before writing new code, rather than recreating something that already exists.
tags: [policy, duplication, refactor, agents]
timestamp: 2026-07-26
---

# Search before building

Before writing a new function, type, tool, or helper, search meticulously for one that already does
the job, in this repo and in its dependencies, rather than re-deriving it. This applies ecosystem-wide,
not only the OCCT/OCCTSwift stack.

Search order, before writing new code:

1. **This repo's own code.** Grep for related identifiers, keywords, and recipes, not just exact
   name matches. Check `CLAUDE.md`, `SPEC.md`, and `okf/components/*.md` for a documented canonical
   primitive before adding a parallel one.
2. **This repo's own docs.** `okf/`, `README.md`, design docs, for a described pattern that already
   covers the need.
3. **Direct dependencies** (`ecosystem.yml`'s `depends_on`, or `Package.swift` for external ones).
   Check whether the capability already exists upstream via `context` first, then **context7** if
   it is not in the local `context` cache, then the dependency's own docs/`okf/` (see
   [context-first](context-first.md)), before reimplementing it locally.

If nothing existing fits after searching: build the new thing, but note in code or the commit why
the existing options did not cover the need, so the next search finds that reasoning, not just more
code to duplicate.

Why: [OCCTMCP#125](https://github.com/SecondMouseAU/OCCTMCP/issues/125) found the same 4-line
`MeshParameters` recipe independently copy-pasted across 10 files, duplication CLAUDE.md already
called "the standard recipe," that kept growing because nothing forced a search before the 11th
copy. OCCTReconstruct's accumulated duplication is the same failure mode at a much larger scale.

Ecosystem standard: see
[OKF-STANDARD.md](https://github.com/SecondMouseAU/ecosystem/blob/main/OKF-STANDARD.md).
