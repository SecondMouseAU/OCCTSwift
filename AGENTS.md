# AGENTS.md — OCCTSwift Ecosystem Workspace

**Working directory:** The agent's working directory (repository root). Agents are confined strictly to this directory.

---

## Key Conventions (from `.claude/CLAUDE.md`)

### OCCT / OCCTSwift — Mandatory Docs Lookup
Never rely on training data for OCCT/OCCTSwift signatures. Use in order:
1. **`context` MCP** (`mcp__context__get_docs`) — `occt`, `occt-refman@8.0.1`, `occtswift`, and other ecosystem packages
2. **context7** — for external libs not in local `context` cache
3. **Other ecosystem repos** (`okf/`, `docs/`, READMEs) — the fallback

**Rebuilding `occt-refman`:** Download `refman-doc.zip` from OCCT GitHub release, extract `class*.html` + `struct*.html` + `namespace*.html` (drop `dir_*`, `*_source.html`, nav indexes), then `context add <folder> --name occt-refman --pkg-version <version>`. Verify: `context query "occt-refman@<version>" "gp_Pnt Coord"` must cite `classgp___pnt.html`.

**Glob gotcha:** Use `class*`, NOT `class_*` — Doxygen mangles lowercase-starting classes (e.g., `gp_Pnt` → `classgp___pnt.html`).

**OCCT 8.0.1 tag:** `V8.0.1` (with dots), not `V8_0_1`.

### Swift Package Index (SPI)
Do **NOT** PR directly to `SwiftPackageIndex/PackageList`. Open an issue via template at <https://github.com/SwiftPackageIndex/PackageList/issues/new/choose>.

---

## Core OCCTSwift Libraries (SemVer-stable v1.0.0 as of 2026-05-07)

All hosted at `https://github.com/SecondMouseAU/<repo>`:

| Repo | Purpose |
|------|---------|
| `OCCTSwift` | Swift wrapper for OpenCASCADE 8.0.0 — keystone |
| `OCCTSwiftViewport` | Metal 3D viewport, no OCCT dep |
| `OCCTSwiftTools` | Bridge: only place OCCT + Viewport meet |
| `OCCTSwiftCADKit` | SwiftUI viewport + STEP/STL/BREP import + picking |
| `OCCTSwiftIO` | Headless CAD I/O (STEP/IGES/STL/OBJ/BREP ↔ glTF/GLB/OBJ/PLY/STEP/BREP) |
| `OCCTSwiftAIS` | Selection, manipulators, dimensions, scene objects |
| `OCCTSwiftMesh` | Mesh algorithms on `OCCTSwift.Mesh` |
| `OCCTSwiftScripts` | Script harness for parametric geometry |
| `swiftGCS` | Geometric constraint solver (missing parametric system) |
| `OCCTMCP` | MCP server for LLM CAD authoring via OCCTSwift |
| `OCCTDesignLoop` | Drawings (PNG/PDF) → BREP solids |

---

## Per-Project Commands (Swift packages)

```bash
swift build          # Build
swift test           # Run tests
swift format         # Format (via .swift-format)
swiftlint            # Lint (orphaned_doc_comment only)
```

---

## Mandatory First Step: Read `okf/`

**Every agent must read `okf/policies/` before starting work.** All policies are mandatory:
- `context-first.md` — OCCT/OCCTSwift docs lookup via MCP
- `search-before-building.md` — search before writing new code
- `docs-current.md` — docs ship with the change
- `writing-style.md` — no em-dashes, banned words
- `code-structure.md` — one type per file, domain vocabulary
- `issue-tracking.md` — type:* and priority:* labels
- `code-style.md` — Swift API Design Guidelines + Google Swift Style via swift-format

---

## Git Commit Identity

- Every commit MUST include `Signed-off-by` and `Co-authored-by` trailers for the human operator
- Use `git config user.name` / `git config user.email` from the working repo — do not hardcode
- If `git config user.email` is empty, STOP and ask

---

## Navigation

- **Global OCCT rules:** `cat .claude/CLAUDE.md` (in repo root)
- **Project-specific rules:** `cat CLAUDE.md` (in repo root)
- **Kilo config:** `cat kilo.json` (in repo root)
- **Ecosystem overview:** `cat okf/references/ecosystem.md` (if present)