---
type: policy
title: Documentation lookup — `context` first
description: Look docs up via context (ecosystem), context7 (external), then other repos' docs — never training-data recall.
tags: [policy, docs, context, context7, agents]
timestamp: 2026-06-27
---

# Documentation lookup — `context` first

When answering or writing code that touches **OCCT** or the **OCCTSwift** API, you **MUST** look the
documentation up rather than relying on training-data recall of OCCT/OCCTSwift signatures — it is
stale and wrong for this fast-moving stack.

**Lookup order:**

1. **`context` MCP** (`mcp__context__get_docs`) — the primary source for all ecosystem docs:
   `occt` (the OpenCASCADE kernel, V8_0_0_p1 overview), `occtswift` (the Swift wrapper), this repo's
   own package, and the other OCCTSwift-family packages indexed there.
2. **context7** — for **external** / third-party libraries that aren't in the local `context` cache.
3. **Docs in the other ecosystem repos** (their `okf/`, `docs/`, READMEs) — the fallback when a topic
   isn't indexed in either.

The OCCT reference manual (per-class Doxygen API) is not indexed: read the bundled
`OCCT.xcframework/.../Headers/*.hxx`, or WebFetch `dev.opencascade.org/doc/refman/html/class_*.html`
for a specific class.

Ecosystem standard — see
[OKF-STANDARD.md](https://github.com/SecondMouseAU/ecosystem/blob/main/OKF-STANDARD.md).
