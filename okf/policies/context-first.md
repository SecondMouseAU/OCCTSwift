---
type: policy
title: "Documentation lookup: `context` first"
description: Look docs up via context (ecosystem), context7 (external), then other repos' docs. Never training-data recall.
tags: [policy, docs, context, context7, agents]
timestamp: 2026-08-22
---

# Documentation lookup: `context` first

When answering or writing code that touches **OCCT** or the **OCCTSwift** API, you **MUST** look the
documentation up rather than relying on training-data recall of OCCT/OCCTSwift signatures. It is
stale and wrong for this fast-moving stack.

**Lookup order:**

1. **`context` MCP** (`mcp__context__get_docs`) for all ecosystem docs: `occt` (the OpenCASCADE
   kernel overview), `occt-refman` (the per-class Doxygen API), `occtswift` (the Swift wrapper),
   `ecosystem` (this standard and every shared policy), this repo's own package, and the other
   OCCTSwift-family packages indexed there.
2. **`context query` on the command line**, when the MCP tool cannot see a package you know is
   installed. See below: this is not a lesser option, it is the same index reached a different way.
3. **context7** for **external** or third-party libraries that are not in the local `context` cache.
4. **Docs in the other ecosystem repos** (their `okf/`, `docs/`, READMEs), when a topic is indexed
   nowhere.

## When `get_docs` says a package is missing and you believe it is installed

**Check with the CLI before concluding anything.**

```bash
context list                                  # what is actually installed
context query "occtswift@3.0.0" "Shape bounds"  # query it directly
```

The MCP tool's `library` parameter is an **enum fixed when the MCP server connected**. The server
reads `~/.context/packages` once at startup and only rebuilds that list when a package arrives
through its own `download_package` tool. A package installed any other way, which includes every
`context add`, is therefore invisible to `get_docs` for the rest of the session, while
`context query` sees it immediately.

So `get_docs` reporting a package as missing means "not in the list I was given at connect time",
not "not installed". Reading it as the latter has already sent agents to WebFetch for docs that were
sitting in the cache.

Two ways out, both fine: run `/mcp` to reconnect and rebuild the enum, or just use `context query`,
which never goes stale. Fixed upstream in
[neuledge/context#117](https://github.com/neuledge/context/pull/117); until that ships, the CLI is
the path that always tells the truth.

## The reference manual is indexed

`occt-refman` carries the per-class Doxygen API, which is a different thing from `occt`'s
narrative overview and is usually what you want for a signature. Query by class name:

```bash
context query "occt-refman@8.0.1" "BRepAlgoAPI_Fuse"   # -> class_b_rep_algo_a_p_i___fuse.html
context query "occt-refman@8.0.1" "gp_Pnt"             # -> classgp___pnt.html
```

Fall back to the bundled `OCCT.xcframework/.../Headers/*.hxx`, or WebFetch
`dev.opencascade.org/doc/refman/html/class_*.html`, only when a class is genuinely absent. That
happens after an OCCT version bump, before the refman package is rebuilt for the new version.

## Versions in the cache are the versions you get

A package is indexed at a specific release and does not follow the repo. `context list` shows
which. If it lags what this repo builds against, the docs will describe an API you do not have, so
check the version before trusting a signature that looks wrong.

Refreshing is per package, and re-adding under the same `--name` replaces the old entry:

```bash
# An ecosystem package, built from a worktree at the release tag so the docs match the version.
git -C ~/Projects/OCCTSwift worktree add --detach /tmp/occtswift v3.0.0
context add /tmp/occtswift --name occtswift --pkg-version 3.0.0

# The OCCT kernel overview, from upstream.
~/Projects/ecosystem/scripts/index-occt-docs.sh V8_0_0_p1
```

`context add` narrows to a `docs/` folder when it finds one, which is usually what you want and
occasionally not: it will silently index six files and report success while missing everything
else. Check the reported file count against what you expected.

Ecosystem standard: see
[OKF-STANDARD.md](https://github.com/SecondMouseAU/ecosystem/blob/main/OKF-STANDARD.md).
