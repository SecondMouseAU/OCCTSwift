---
type: policy
title: Query `context` first for OCCT / OCCTSwift docs
description: Agents must consult the context MCP for OCCT/OCCTSwift APIs before relying on training data.
tags: [policy, docs, context, agents]
timestamp: 2026-06-27
---

# Query `context` first

When answering or writing code that touches **OCCT** or the **OCCTSwift** API, you **MUST** consult the
`context` MCP before relying on training-data recall of OCCT/OCCTSwift signatures — it is stale and
wrong for this fast-moving stack.

Use `mcp__context__get_docs(library=…, topic=…)` with:

- **`occt`** — the underlying OpenCASCADE kernel (V8_0_0_p1 overview / user guides).
- **`occtswift`** — the Swift wrapper API.
- **this repo's own package** — its `context` library, where indexed.

The reference manual (per-class Doxygen API) is not indexed: read the bundled
`OCCT.xcframework/.../Headers/*.hxx`, or WebFetch `dev.opencascade.org/doc/refman/html/class_*.html`
for a specific class.

Ecosystem standard — see
[OKF-STANDARD.md](https://github.com/SecondMouseAU/ecosystem/blob/main/OKF-STANDARD.md).
