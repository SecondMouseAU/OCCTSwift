# #2983 XCAF re-sweep: the injection matrix

The evidence behind the PR that rewrote the weak tests of nine `OCCTXCAFTests` files (tests the #766
certification recorded Red and never rewrote). Measured on 2026-10-07 against `origin/main` at
`6ffeb9dbd` and the pinned kernel `v4.0.0-kernel.4`. Every figure is that day's and is
re-derivable from the files here; re-measure rather than quote.

## What is here

| file | what it is |
|---|---|
| `SweepXcafShadow.swift.txt` | the harness: module-local Swift functions that shadow 61 bridge entry points, each distorted by a switch named in `SWEEP_XCAF_SWITCH`. A `.txt` so no build or linter reads it in place |
| `inject.py` | the edits to tracked files a shadow cannot make: `BRepGraph+Attributes.swift` is pure Swift (no bridge symbol), and three modifier writers in `GDTWrite.swift` are called directly by `Issue1037GDTEnumRangeTests`, so a same-named shadow makes those calls ambiguous and they are spliced instead |
| `switches.txt` | the 395 switches, under `GROSS` and `SEMANTIC` headers |
| `run-injection-matrix.py` | runs the built bundle once per switch and writes `matrix-LABEL.json` |
| `run.sh` | the whole loop: apply, build, run, restore, prove the restore |
| `report.py` | prints the per-file table below from the committed JSON, no build needed |
| `matrix-before.json`, `matrix-after.json` | the same switches against `origin/main`'s nine files and against the rewrites |
| `transcript-before.txt`, `transcript-after.txt` | the runner's output |

## How the switches are chosen

A switch is a defect somebody could plausibly write, not an arbitrary perturbation.

* **GROSS (109)**: a constant answer (`true`, `false`, 0, nil, -1), a write that reports success and
  stores nothing, a refusal that stops refusing.
* **SEMANTIC (286)**: the wrong label, the wrong member (a qualifier read as the angular qualifier,
  a material requirement read as the zone modifier), an off-by-one index, a swapped or reversed or
  sorted sequence, a count one too many or capped, a translation axis swapped or dropped, a matrix
  transposed, a flag inverted, a value truncated or doubled, the first face meshed instead of all,
  a node read in the wrong frame, the wrong node of an encoded store written first, a snapshot
  format check off by one, a restore that drops attributes.

## Result

`python3 Scripts/repro/2983-xcaf-resweep/report.py`, with the old and new columns on one frozen
`origin/main` and one build per column:

| file | switches | caught by old | caught by new | old crashed the process |
|---|---|---|---|---|
| Issue443TriangulationAttributeTests | 42 | 38 | 42 | 3 |
| TDFLabelPropertyTests | 58 | 46 | 58 | 0 |
| BRepGraphAttributeTests | 50 | 24 | 49 | 0 |
| XCAFComponentMatrixTests | 7 | 1 | 7 | 0 |
| XDEAssemblyOperationTests | 35 | 15 | 35 | 0 |
| DocumentExplorerExtensionTests | 21 | 14 | 21 | 0 |
| XCAFPrsStyleTests | 28 | 8 | 24 | 0 |
| GDTDimensionAccessorTests | 57 | 50 | 56 | 0 |
| GDTToleranceDatumAccessorTests | 97 | 94 | 95 | 0 |
| **all** | **395** | **290** | **387** | **3** |

The old tests caught 290 of 395 switches (105 redden nothing, 93 of them semantic); the rewrites
catch 387. The three the old tests "caught" by crashing the process are `T_SET_FALSE`,
`T_SET_TRUE_NOOP` and `T_NODES_ZERO`: the old triangulation tests wrote `Int32(1)...count` over a
count of zero, a trap that ended the run, so every later test of the suite never ran.

### The eight switches the rewrites do not catch, and why each is a statement about the subject

| switch | why nothing can catch it |
|---|---|
| `P_CREATE_INVISIBLE` | `OCCTXCAFPrsStyleCreate` returns a hidden style, then `PresentationStyle.toOCCT()` overwrites `isVisible` from the Swift property, so the bridge's value never survives |
| `P_SURF_SWAP_RB`, `P_SURF_SWAP_RG`, `P_CURV_SWAP_RG` | a channel swap applied to both sides of a comparison is a bijection. The style's colours are never read back from OCCT (`surfaceColor` is the Swift property), only compared with `isEqual`, and a bijection of the colour space preserves equality. Unreachable from the public API |
| `G_DIM_MODCOUNT_PLUS1`, `G_TOL_MODCOUNT_PLUS1`, `G_DAT_MODCOUNT_PLUS1` | a modifier count one too large asks for index `count`, which the bridge answers with -1, and the Swift read drops a raw value with no enum case. The output is identical, so the switch is an equivalent mutant |
| `A_RESTORE_PARALLEL` | restoring with `parallel: true` can only change node numbering on a shape big enough to split across threads. A box cannot show it. The doc comment's claim (the rebuild pins `parallel: false` for deterministic indexing) is not testable on a small fixture |

Two further limits of what a bridge shadow can reach: the merge inside
`OCCTDocumentSetTriangulationFromShape` (maximum deflection over faces, per-face location and
reversal) is C++ that no Swift shadow can edit, and the rule against editing a `.mm` for a sweep
leaves it alone. Its outcomes are pinned against an independent reading instead (each face's own
`Shape.triangulation...`, summed, and the corner set of the box) rather than by a switch.
