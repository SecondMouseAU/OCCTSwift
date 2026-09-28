# #1628: dead file-static definitions in the bridge

Evidence for the census and the deletion pass. Nothing here runs in CI; the census itself
(`Scripts/census-dead-file-statics.py`) is what CI runs, and only its `--self-test`.

| file | what it is |
|---|---|
| `removal-matrix.sh` | the removal matrix for the census, per `okf/policies/prove-the-test-fails.md`. Breaks one rule at a time and requires the `--self-test` to go red. Every line must read `load-bearing`. |
| `compare-to-grep-method.py` | #1628's own stated grep method, reproduced literally, against the census. Explains the population difference rather than asserting it. |
| `delete-dead-statics.py` | the deletion pass. Takes helper names, reads the census's own verdicts, and removes each definition plus the doc comment above it. Refuses a name the census does not report dead. |

## What the removal matrix found on its first run

Three of the ten rules were **not** load-bearing, which is the point of running it:

- `STATIC_DECL`'s `;` exclusion. The character class matches newlines, which it must, since a bridge
  definition's return type, name and parameter list routinely span lines. Excluding `;` is therefore
  the only thing stopping a `static` variable's declarator from pairing with the **next** ordinary
  function's name. No fixture had a `static` variable followed by a function.
- `brace_extent()`'s prototype rejection. The prototype case asserted the dead **name** set, and a
  prototype counted as a definition carries the same name, so the case passed either way. It now
  asserts the count.
- `body_digests()`'s inclusion of live definitions. The divergence case handed `divergent_sets()` a
  report dict it built by hand, so it never exercised the collection that decides which definitions
  get digested at all. It now runs the real collection over two synthetic files, which is the shape
  `fillCommonPart` has.

## The population, and why three numbers exist for it

| figure | where | method |
|---|---|---|
| 441 | #1628's body, 2026-09-07 | grep: `static <type> name(` whose name appears once in the file |
| 425 | #1628's reopening comment, 2026-09-28 | the same sentence of method, re-run |
| 407 | `compare-to-grep-method.py`, 2026-09-28 | the same sentence of method, reconstructed here |
| **472** | `census-dead-file-statics.py`, 2026-09-28 | the committed census |

The first three are the same method producing three answers, which is the census-once rule's whole
argument. The census's population is a strict **superset** of the grep's: zero definitions the grep
reports are absent from it. The 65 it adds are three mechanical classes the "appears exactly once"
rule cannot see:

- an **overload set** (`occtArgList` is defined twice per file, so its name appears twice);
- a **`Handle(Foo)` return type**, where the grep reads `Handle` as the function name and `Handle`
  appears all over the file;
- a helper whose name also appears in a **comment**.

## Proving the census is not blind against the real tree

Fixtures prove the detector catches what its author thought of. Two checks against the real tree,
both run and both restored, prove it looks at the real corpus:

1. A `static int occtInjectedDeadHelperForSelfCheck(int)` appended to
   `OCCTBridge_Spatial_Bounding.mm` was reported at `676-679`.
2. Adding one caller for it in the same file removed it from the report.

And the deletion claim, proved the other way round: forcibly removing the **live** `fillCommonPart`
from `OCCTBridge_Modeling_Boolean.mm` fails the build with
`use of undeclared identifier 'fillCommonPart'` at both call sites, 2622 and 2681. That is the
compiler adjudicating the census's verdict, which is why a deletion pass is safe to drive from it.
