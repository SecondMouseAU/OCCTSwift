# Generate the detailed API reference for an OCCTSwift type

Generate (or refresh) the per-type function-reference page(s) under `docs/reference/`, modelled on
OCCT's own class reference. Each page is produced by a **subagent** (Sonnet) that reads the Swift
source + the `OCCTBridge` mapping + the upstream OCCT docs and writes the page following the template
in `docs/reference/README.md`.

**Arguments:** `$ARGUMENTS` = one or more Swift type names or source file stems (e.g. `Wire`,
`Edge Face Mesh`, or `Shape --section Booleans`). No args → ask which type(s); or offer the next
`☐ todo` rows from the Status table in `docs/reference/README.md`.

## Instructions (you orchestrate; subagents do the writing)

1. **Resolve targets.** For each name in `$ARGUMENTS`, the source is `Sources/OCCTSwift/<Type>.swift`.
   Confirm it exists. For a **giant** file (Document, Shape, BRepGraph, Surface, Curve2D, Curve3D),
   split the work by `// MARK:` section — one subagent per section, output `docs/reference/<Type>-<Area>.md`
   — unless a single `--section <name>` was given.

2. **Dispatch one subagent per target** (Agent tool, `subagent_type: general-purpose`,
   `model: sonnet` — use `haiku` only for tiny ≤20-decl types). Run independent targets in the same
   message so they execute in parallel. Give each subagent **exactly** this prompt (substitute the
   bracketed values):

   ---
   You are writing one page of the OCCTSwift **API reference** — a detailed, per-type function
   reference modelled on OCCT's Doxygen class docs. Write the page for **`[TYPE]`** from
   `Sources/OCCTSwift/[FILE].swift`[, only the `// MARK: [SECTION]` section]. Output it to
   **`docs/reference/[OUTPUT].md`** with the Write tool. Return only a one-line summary (how many
   members documented) — not the page body.

   **Read first, in this order:**
   1. `docs/reference/README.md` — the **page layout + entry-template + entry rules** you must follow exactly.
   2. `Sources/OCCTSwift/[FILE].swift` — the source of truth for signatures, `///` doc comments, and `// MARK:` grouping.
   3. The `OCCTBridge` mapping for each method's OCCT class: grep the bridge implementation for the
      `OCCT…` function the method calls — `grep -rn "<bridgeFn>" Sources/OCCTBridge/src/*.mm` — and read
      that impl to see which `Upstream_Class::Method` it wraps. The cross-reference index comment in
      `Sources/OCCTBridge/include/OCCTBridge.h` and `docs/API_REFERENCE.md` also map classes.
   4. For upstream behaviour/semantics, query context7 `/open-cascade-sas/occt` (resolve-library-id is
      not needed — use that ID directly) about the relevant OCCT class. Treat it as the *style + behaviour*
      model; the pinned headers under `Libraries/OCCT.xcframework/.../Headers` are the version-of-record.

   **Write the page** following the template and the six **entry rules** in `docs/reference/README.md`:
   verbatim signatures; one `###` per public `func`/`var`/`static func`/`init` in source order, grouped
   by `// MARK:`; required OCCT mapping (omit only for pure-Swift); signature-faithful runnable examples
   (reuse a cookbook/test snippet where one exists — check `docs/guides/cookbook/` and `Tests/`; never
   force-unwrap); no invention (if a method's purpose is unclear from source+bridge+OCCT, say so briefly);
   concise reference style.

   Do **not** edit any file other than your output page. Do not run `swift build`/`swift test`.
   ---

3. **Collect & verify.** When subagents finish, spot-check each page: front-matter present, signatures
   match the source (grep a couple), OCCT mappings look right, examples are signature-faithful. Fix
   obvious slips inline; re-dispatch a subagent if a page is materially wrong.

4. **Update the index.** Tick the `Status` table rows in `docs/reference/README.md` (☐ todo → ✅ done),
   and ensure each new page is reachable (the Jekyll `parent: API Reference` front-matter handles nav).

5. **Report** which pages landed and the running coverage; do **not** commit unless asked.

## Notes
- Subagents write their own pages (no giant returns to you) — keep batches to ~6–10 parallel jobs.
- This is additive docs only: no code, no counts, no release. Commit as a `docs(reference): …` PR.
- Examples in reference pages aren't auto-compiled; prefer reused cookbook/test snippets, which are.
