---
type: policy
title: Documentation updates are mandatory
description: Docs must be updated with every release — or every PR for repos not yet on stable semver.
tags: [policy, docs, release, semver]
timestamp: 2026-06-27
---

# Documentation updates are mandatory

Documentation — the `context`-indexed docs, this repo's `okf/` bundle, and any public API reference —
must not drift from the code:

- **Repos on stable semver (≥ 1.0):** every **release** must ship the matching documentation update.
  A release that changes public API or behaviour without updating the docs is incomplete.
- **Repos not yet on semver (0.x / pre-release / untagged):** every **PR** that changes public API or
  behaviour must update the docs in the same PR.

This is the other half of the [`context-first`](context-first.md) contract: agents query the
`context` docs (`occt`, `occtswift`, this package) as the source of truth, so those docs must be
current — stale docs are worse than none.
