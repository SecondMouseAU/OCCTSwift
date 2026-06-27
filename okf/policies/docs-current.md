---
type: policy
title: Documentation updates are mandatory
description: Docs update with every release — or every PR for repos not yet on stable semver. See Release discipline.
tags: [policy, docs, release, semver]
timestamp: 2026-06-27
---

# Documentation updates are mandatory

Documentation updates ship **with the change**, never as a follow-up: every **release** for repos on
stable semver (≥ 1.0), and every **PR** that changes a public API surface for repos not yet on semver
(0.x / untagged).

For exactly what to update each time — `README.md`, the API reference, the changelog, the relevant
reference page, and in-source doc comments with runnable examples — follow the authoritative
**Release discipline** in
[OKF-STANDARD.md](https://github.com/SecondMouseAU/ecosystem/blob/main/OKF-STANDARD.md) and the repo's
`CLAUDE.md` Release Process.
