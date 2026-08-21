# Em-dash sweep

`okf/policies/writing-style.md` bans the em-dash outright and says a dedicated pass to strip the
existing ones is not required. This is that pass, run once.

## Result

**10,614 replaced across 376 files.** 318 remain, in the 55 files on a style manifest. See below.

Measured before running, so the rules follow the data rather than taste: 97.6% were the spaced
` - ` form, 236 trailing, 23 line-leading, 3 unspaced. 1,761 lines matched the labelled-term
template and 909 dashes were followed by a capitalised word.

## Rules

- **COLON** where the dash follows a labelled term at the head of a line, list item or table cell.
  This is the `- `param` - description` template every `docs/reference/` page is built on.
- **PERIOD** where the line carries exactly one dash and the next word is capitalised, so the halves
  are independent clauses. Restricted to unpaired dashes, so a parenthetical is never split.
- **COMMA** everywhere else.

A dash after terminal punctuation is dropped rather than doubled; a trailing ` -` becomes a comma.

## Three exclusions, each a measured failure of an earlier draft

Not precautions. Each came from sampling a draft's output:

1. A period **inside a code span**: `` `contains(uid:). GraphUID` ``.
2. A period **inside an unclosed parenthesis**, splitting an aside: `(replaces any existing. OCCT
   8.0.0p1 holds`.
3. `swift-format` rejected `domain. NOT arc length` as a two-sentence doc summary, which is the
   all-caps emphasis case.

## Why 55 files were skipped

The style-manifest ratchet (`okf/policies/code-style.md`) says a file you touch must be brought
fully clean and removed from the manifest in the same PR. Editing the 55 manifest files this sweep
would otherwise reach costs 12,421 reformat lines, and `swift-format format -i` does not make them
lint-clean: **264 violations survive it**, 210 `BeginDocumentationCommentWithOneLineSummary`, 47
`ValidateDocumentationComments`, and 7 `AlwaysUseLowerCamelCase`.

That last group is the blocker rather than the volume. It includes `PaperSize.A0` and `A1`, public
enum cases, so cleaning those files means a **source-breaking rename**. A punctuation sweep is not
the change that should carry one.

Leaving them is what the ratchet is designed to produce: each clears when someone next edits it for
a real reason. The 318 remaining are tracked so the count is not rediscovered.

## Re-running

    python3 Scripts/repro/385-em-dash-sweep/replace-em-dashes.py

It skips manifest files by design. Verify after: `swift build`, the full `swift test`, all eight
gates, both style manifests, and `swift-format lint` / `clang-format --dry-run --Werror` on every
changed file.
