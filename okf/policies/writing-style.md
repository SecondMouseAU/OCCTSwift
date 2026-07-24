---
type: policy
title: Writing style — no em-dashes, banned words
description: No em-dashes anywhere; specific hedge/filler/sycophancy words and phrases (honest/honestly, "you're right") banned outright, in code, docs, commit messages, PR bodies, and third-party messages.
tags: [policy, style, writing, agents]
timestamp: 2026-07-24
---

# Writing style (all prose and comments)

**No em-dashes.** The em-dash (`—`), and `--` used as a sentence dash, are banned in every code
comment, doc comment, markdown doc, changelog, commit message, and PR body across the ecosystem.
Use ordinary punctuation instead: a comma, colon, semicolon, parentheses, or two separate sentences.
This is a total ban going forward. A dedicated pass to strip existing ones is not required, but
clear them from any file you are already editing.

Why: em-dash-heavy prose reads as machine-generated. The ecosystem's house voice uses plain,
correct punctuation.

**Banned words and phrases.** The following are banned outright, in the same scope as the em-dash
rule (code comments, doc comments, markdown docs, changelogs, commit messages, PR bodies, and any
message sent to a third party such as an upstream issue or PR comment):

- `honest` / `honestly` (as in "the honest answer is..." or "to be honest")
- "you're right" / "you're absolutely right" (or similar reflexive affirmation opening a reply)

This list is a standing personal preference, not exhaustive, and grows as more get flagged. Ask
before assuming a word or phrase is safe if it reads like a hedge, a tell, or empty affirmation
("to be fair", "I think", "in fact", "great question") rather than a plain statement of the thing
itself.

Why: these are filler or sycophancy that a plain, direct statement doesn't need. Cut the word and
the sentence usually reads better on its own; for the affirmations, answer the question instead of
opening by telling the user they're right.

Ecosystem standard: see
[OKF-STANDARD.md](https://github.com/SecondMouseAU/ecosystem/blob/main/OKF-STANDARD.md).
