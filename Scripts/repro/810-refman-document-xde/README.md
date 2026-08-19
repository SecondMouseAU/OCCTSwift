# #810: refman coverage audit, Document/XDE assembly (Pass 3 of #807)

Two files:

| file | what it is |
|---|---|
| `refman_census.py` | the census. 278 classes, four verdicts, two over-coverage checks, a lane re-derivation, and its own self-test. |
| `selftest_removal_matrix.py` | the proof that the self-test's guards are load-bearing. |

```bash
python3 Scripts/repro/810-refman-document-xde/refman_census.py                 # the table
python3 Scripts/repro/810-refman-document-xde/refman_census.py --verbose       # + matching files
python3 Scripts/repro/810-refman-document-xde/refman_census.py --reverify-lane # + lane drift check
python3 Scripts/repro/810-refman-document-xde/refman_census.py --self-test     # the 8 detector cases
python3 Scripts/repro/810-refman-document-xde/selftest_removal_matrix.py       # the removal matrix
```

Both run from any cwd. Both need `Libraries/OCCT.xcframework` for the checks that read the pinned
headers, and report SKIPPED rather than passing silently without it, which is the case in CI.

## Result

| verdict | count |
|---|---|
| `ok` | 118 |
| `deliberate, recorded` | 160 |
| `under` | 0 |
| `over` | 35 fixed in this PR, 1 deferred to #971 |

The lane is 278 classes against #810's own seven prefixes (188) plus six packages named by no pass
at all. The widening, and the forty-four further packages handed off to #973 rather than absorbed,
are argued in `refman_census.py`'s module docstring.

## What found the over-coverage

Neither #808 nor #809 could produce an `over` verdict; both established over-coverage by one hand
read-through and pinned only the conclusions. #928 built the class-level detector. This pass ran it,
and then built a second detector for the half it cannot see.

| source | candidates | true | false | rate |
|---|---|---|---|---|
| `census-doc-occt-attribution.py --lane ...` (#928) | 34 | 18 | 16 | 47.1% false |
| `check_method_attributions()` (this file, new) | 24 | 22 | 2 | 8.3% false |
| reading | 1 | 1 | 0 | |

Five findings appear in both detectors' output, because the claim names both a class that is not
reached and a member that is not declared: `CDF_Application::NbDocuments`/`ReadingFormats`/
`WritingFormats`, and `TNaming_Tool::SameShape` twice. So the union is 36 rather than 41: 35 fixed
here and one (#971) deferred, which is #928's alone.

**#928's 47.1% on this lane is close to its own measured 41.0%** over a uniform 40-row sample, which
is the first independent check of that figure. The sixteen false positives fall into the categories
its README already names, in these proportions:

- **misresolved subject** (9). The claim sits under a heading whose Swift member name resolves to
  a hundred bridge functions (`init`, `isEmpty`, `name`, `type`, `isEqual`), so the detector checks
  the wrong function. Every one is `AssemblyItemId.init`, `ViewObject.init`, `NoteObject.init`,
  `PresentationStyle.init`/`isEmpty`, `DimensionInfo.type` or `IDFilter.init` and every claim is
  correct.
- **the second half of a paired table cell** (3). `docs/API_REFERENCE.md` rows read
  `document.dimensionCount / document.dimension(at:)`; the detector resolves the first member and
  the `XCAFDimTolObjects_*Object` attribution belongs to the second, which does reach it.
- **a class reached one call deeper** (2). `TDF_Label::NewChild()` is literally
  `TDF_TagSource::NewChild(*this)`, and `XCAFDoc_ShapeTool::GetLocation` opens with
  `L.FindAttribute(XCAFDoc_Location::GetID(), ...)`. Both attributions are accurate; the identifier
  is simply not spelled in the bridge.
- **a base-class method on a subclass-typed handle** (1). `nc->UserName()` on a
  `Handle(XCAFDoc_NoteComment)` calls `XCAFDoc_Note::UserName`.
- **a mention that is not an attribution** (1). `docs/reference/Shape-Features.md` names
  `XCAFDoc_Centroid` as the OCCT writer whose convention `centerOfMass` matches, in a sentence
  whose primary attribution is `BRepGProp::VolumeProperties`.

The method check's own two false positives are both `docs/thread-safety.md` naming a kernel-internal
symbol across versions (`XCAFDoc_ShapeTool::theAutoNaming`, and the `AutoNamingScope` that patch
`0011` added and #363 then replaced). Both are in `METHOD_ATTRIBUTION_ALLOWED` with that reason, so
the check stays silent about them without going blind.

### The corrections raise #928's own count, and that is expected

Re-running #928 on this lane after the fixes gives **22**, not 16. The arithmetic:

| | count |
|---|---|
| pre-existing false positives (the five categories above) | 16 |
| **new**, created by this PR's own corrections | 5 |
| the deferred finding, #971, still genuinely present | 1 |

The five new ones are the shape #928's README already names in its single NOISY row: a correction
that explains itself names the wrong class again in a contrastive sentence, and the detector cannot
see the contrast. Four are exactly that (`TNaming_Tool` twice, for "`TNaming_Tool` declares no
`SameShape` member in OCCT 8.0.1", and `TNaming_Builder::Select` once, for "exists and is a
different operation"). The fifth is the accessor-chain category:
`XCAFDoc_AssemblyItemRef::GetItem()` returns an `XCAFDoc_AssemblyItemId` whose `ToString()` the
bridge calls, so the correction is right and the identifier is never spelled in the code.

Keeping the contrastive sentences is deliberate. A reader who arrives at a corrected entry knowing
the old attribution needs to be told which class does not have the member, and losing that to keep
a report's count down would be optimising the wrong thing. The count is recorded here so the next
pass over this lane does not read 22 as 22 defects.

## Proving the detectors fail

Per `okf/policies/prove-the-test-fails.md`, and the reason this directory has a second file.

**The regression check.** Run against the tree before this PR's corrections, `refman_census.py`
reports all 35 findings as regressions and exits 1. That is the whole battery failing on its
subject, not a constructed case:

```
Known over-coverage findings tracked: 35
REGRESSION: the following fixed over-coverage findings have reappeared:
  docs/reference/Document-Persistence-IO.md: Document.saveOCAF(to:) -- '- **OCCT:** `XCAFApp_Application::SaveAs` / `PCDM_StoreStatus`.'
  ... 34 more ...
```

After the corrections it exits 0. The comparison collapses whitespace on both sides, so re-wrapping
a wrong sentence across a line break still counts as a regression.

**The deferred check is inverted, and was proved the same way.** `DEFERRED_OVER_FINDINGS` holds the
one finding this PR does not fix (#971), and it fails when the bad text is **gone**, because a
deferred finding that has quietly been fixed leaves the census describing a tree that no longer
exists. Injected by applying #971's own fix to a scratch copy of the header: the script reported
`STALE: ... move each entry from DEFERRED_OVER_FINDINGS to KNOWN_OVER_FINDINGS` and exited 1;
reverted, exit 0.

**The under-coverage check.** Deleting the `TNaming_UsedShapes` entry from
`docs/occtswift-wrapping-gaps.md` moves that class from `deliberate, recorded` to `under` and exits
1; restored, exit 0.

**The method-attribution detector.** Eight self-test cases, and `selftest_removal_matrix.py`
switches off each of `declares_member`'s four accepting shapes in turn:

```
baseline: 8/8 cases pass unmodified

method-call        disabled -> 4/8 cases fail  [load-bearing]
nested-type        disabled -> 1/8 cases fail  [load-bearing]
data-member        disabled -> 1/8 cases fail  [load-bearing]
base-class-walk    disabled -> 1/8 cases fail  [load-bearing]
```

Every shape was added because omitting it produced a false report on this lane's real docs, and the
matrix is what holds that claim. Three of the four are single-case, which is the minimum that
proves anything; each names the real doc line it protects in `SELF_TEST_CASES`.

## The flagship finding

`XCAFApp_Application`. The pinned refman documents `GetApplication()` as "the only valid method to
get `XCAFApp_Application` object", and the class's constructor is protected, so it is telling the
truth. OCCTSwift does not use it: #371 replaced it with a private `TDocStd_Application` per
document, because the shared instance is what made the #341 / #344 / #349 / #353 race cluster
reachable. Four `docs/reference/Document-Persistence-IO.md` entries still named it as the backing
class; all four are corrected, that page gained a "Why not `XCAFApp_Application`" section, and
`docs/occtswift-wrapping-gaps.md` carries the full reasoning under a `DELIBERATE_DIVERGENCE` entry
so the divergence reads as a decision rather than as drift.

A second, quieter instance of the same divergence: `docs/thread-safety.md` still said, in the
present tense, that every document-producing call goes through that singleton. Its own #371 section
130 lines below says otherwise. Neither detector can see a tense.

## What this pass did not do

- **Forty-four OCAF-family packages, about 460 headers, are named by no pass and are not audited
  here.** They are enumerated with their measured bridge usage in #973.
- **#971**, the one over-coverage finding left in the tree, is a two-line bridge header comment
  behind a measured 1,714-line clang-format reformat.
- **#970**, two API defects found while checking the transaction entries. The docs now describe
  what the code does; whether the code should do it is a behaviour change and a separate PR.
