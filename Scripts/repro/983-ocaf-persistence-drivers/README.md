# #983: refman coverage audit, OCAF persistence and format drivers lane (Pass 3c of #807)

Three files:

| file | what it is |
|---|---|
| `derive_lane.py` | confirms the already-derived lane (#973's `partition_census.py --pass 983`) rather than re-deriving it, and shows the eight format-registration classes are reached BY CALL in the real bridge source. |
| `refman_census.py` | the census. 342 classes across 38 packages, four verdicts, a family-level (not per-class) curated-reason table, an over-coverage sweep, a family-count assertion, a lane re-derivation, and its own self-test. |
| `selftest_removal_matrix.py` | the proof that the self-test's guards are load-bearing, including two checks unique to this lane's structurally different classifier (gaps.md TEXT vs the `CURATED` python table, isolated from each other) that found real, measured, non-obvious behavior on the first run. |

```bash
python3 Scripts/repro/983-ocaf-persistence-drivers/derive_lane.py
python3 Scripts/repro/983-ocaf-persistence-drivers/derive_lane.py --calls
python3 Scripts/repro/983-ocaf-persistence-drivers/derive_lane.py --diff-973
python3 Scripts/repro/983-ocaf-persistence-drivers/refman_census.py
python3 Scripts/repro/983-ocaf-persistence-drivers/refman_census.py --verbose
python3 Scripts/repro/983-ocaf-persistence-drivers/refman_census.py --reverify-lane
python3 Scripts/repro/983-ocaf-persistence-drivers/refman_census.py --self-test
python3 Scripts/repro/983-ocaf-persistence-drivers/selftest_removal_matrix.py
```

All run from any cwd, in about a second. The checks that read the pinned headers report SKIPPED
rather than passing silently without `Libraries/OCCT.xcframework` (this worktree symlinks
`Libraries/` to the sibling checkout at `/Users/elb/Projects/OCCTSwift/Libraries`, pinned to the
same asset as this branch's own `Package.swift`; a fresh clone or CI has neither).

## Result

| verdict | count |
|---|---|
| `ok` | 9 |
| `deliberate, recorded` | 333 |
| `under` | 0 |
| `over` | 0 fixed in this PR; 2 found and **filed** as [#1232](https://github.com/SecondMouseAU/OCCTSwift/issues/1232), not fixed, per this task's carve-out |

Before this PR the table read `ok` 9, `deliberate, recorded` 1 (`Storage_Schema`, incidentally, from
a pre-existing #371/#374 mention), `under` 332.

## The lane's shape, and why the census looks different from #811's and #812's

#983's own body predicts this and the measurement confirms it: "expect this to be answered once
for the whole driver family rather than per class, and expect that to be the correct answer: an
attribute driver is not a callable capability, it is what makes an attribute survive a round trip."
38 packages, 342 classes, and **9 of them are individually wrapped or documented** -- the eight
classes named on a real line of `Sources/OCCTBridge` (`BinDrivers`, `BinLDrivers`, `XmlDrivers`,
`XmlLDrivers`, `BinXCAFDrivers`, `XmlXCAFDrivers`, `PCDM_ReaderStatus`, `PCDM_StoreStatus`), plus
the bare `PCDM` package header (incidentally named by a section heading). Every other class is
machinery those eight, the six `OCCTDocumentDefineFormat*` functions, and the
`OCCTDocumentSaveOCAF*`/`OCCTDocumentLoadOCAF` entry points configure, and `refman_census.py`
curates it in **thirteen family-level buckets**, not 333 individual reasons:

| bucket | count | what it is |
|---|---:|---|
| Driver-table subclasses | 18 | the concrete storage/retrieval driver each wrapped format's `DefineFormat` registers |
| Attribute drivers | 109 | one class per already-wrapped OCAF attribute type, registered wholesale |
| TObj_-based format drivers | 16 | a real driver family for a document type nothing builds |
| Driver-table infrastructure | 17 | the container and bootstrap drivers every attribute driver registers into |
| Stream primitives | 19 | scalar/array read-write primitives the drivers call |
| Persistent schema and stream layer | 98 | the schema/type-binding layer `SaveAs`/`Open` walk internally |
| Physical file layer | 7 | the file open/read/write/seek primitives the drivers open through |
| Plugin loader | 4 | the GUID-to-factory resolver, bypassed since the bridge calls `DefineFormat` directly |
| XML DOM | 24 | the DOM implementation the Xml drivers parse/write through |
| Package utility | 1 | a bare, all-static helper class |
| Cross-document reference bookkeeping | 2 | the file-level counterpart of a gap #810 already recorded |
| Driver abstract bases and plumbing | 14 | the rest of `PCDM_` |
| **Genuine gap, family-level** | 4 | `StdDrivers_`/`StdLDrivers_`: a real, narrow format-registration gap, see below |

Every bucket's reason is now in `docs/occtswift-wrapping-gaps.md`'s new "OCAF persistence and
format drivers lane" section, with every one of the 333 class names spelled out in full (not
abbreviated), because `refman_census.py`'s `recorded_in_gaps()` check is a literal
`\bClassName\b` search and an abbreviated form (`BinMDataStd_*Driver`) does not satisfy it -- this
was the first real bug the census itself caught while writing the docs section, see "What went
wrong once, and how the census caught it" below.

## The one genuine finding: a family-level gap, not a per-driver one

`StdDrivers_`/`StdLDrivers_` (`StdDrivers`, `StdDrivers_DocumentRetrievalDriver`, `StdLDrivers`,
`StdLDrivers_DocumentRetrievalDriver`) have the identical `DefineFormat` shape as the six
already-wrapped format-registration packages, registering the legacy `"MDTV-Standard"` and
`"OCC-StdLite"` OCAF formats, and neither is called anywhere in the bridge. Both are **read-only**
at the OCCT level (confirmed against the pinned headers: each package ships only a
`*_DocumentRetrievalDriver`, no `*_DocumentStorageDriver`), so this is narrow but real: importing an
OCAF document written by pre-"lite" (pre-6.3-era) OCCT-based software is not supported by
`Document.defineFormat*()`/`loadOCAF(from:)`. This is exactly the shape #983's own body asks this
lane to look for -- a gap in the **format-registration surface**, not a per-driver gap -- and it is
recorded rather than wrapped here (low-value, low-demand format, and a read-only registration would
still be a genuinely new, if small, public API).

## Over-coverage: two stale claims, filed rather than fixed

`Scripts/census-doc-occt-attribution.py --lane <this lane's 38 packages>` found **0 candidates**:
this lane is barely documented outside the 9 individually-covered classes, so the detector's
`Class::Method` attribution shape has almost nothing to check.

The real finding came from reading `docs/thread-safety.md` by hand, per #983's own pointer at the
`#349`/`#353`/`#374` cluster it describes "in terms of carried kernel patches" -- and confirmed
independently by `refman_census.py`'s own method-attribution check, which flags three lines
(297, 324, 330) attributing `ICurrentData` to `Storage_Schema`, a member the pinned header no
longer declares:

1. The `### Resource_Manager::Debug / Storage_Schema::ICurrentData() races, fixed (issue #374)`
   section still describes the FIRST, superseded version of that fix (an `ICurrentDataMutex()`
   `std::recursive_mutex`). `Scripts/patches/README.md`'s own `0016` entry and issue #518 (closed)
   record that this was revised on upstream review (OCCT#1399) to a `myCurrentData` per-instance
   field with no mutex at all -- confirmed directly against
   `Scripts/patches/0016-Resource_Manager-atomic-Debug-Storage_Schema-per-instance-374.patch`'s
   current contents, which contain no `ICurrentDataMutex` anywhere. `CLAUDE.md`'s own `#374` entry
   in Known OCCT Bugs carries the identical stale mechanism.
2. The `Scripts/tsan.supp` suppression-policy paragraph cites the `#353` `CDM_Application`
   metadata-map suppression as a "current example," but `tsan.supp` itself says that suppression
   was removed in v1.15.11 once patch `0015` landed, and `0015` is in fact carried.

**Neither is fixed here.** Per this task's own carve-out: a human is concurrently building
reproducers for open thread-safety issues in `docs/thread-safety.md`, so an over-coverage fix
there is filed for review rather than landed unreviewed in this audit's own PR. Both findings are
filed as [#1232](https://github.com/SecondMouseAU/OCCTSwift/issues/1232), with the exact stale text
quoted and what the correction should say. `METHOD_ATTRIBUTION_ALLOWED` in `refman_census.py`
allow-lists `("Storage_Schema", "ICurrentData")` specifically so this known, filed finding does not
fail the census gate every run until #1232 is resolved; the allow-list entry comes out the same PR
that fixes it, so the census goes back to verifying the fix.

## What went wrong once, and how the census caught it

The first draft of the gaps.md section abbreviated the class lists for readability (`BinMDataStd`
and its 21 `BinMDataStd_*Driver` classes (`AsciiString`, `BooleanArray`, ...)` rather than spelling
out `BinMDataStd_AsciiStringDriver` etc. in full). `refman_census.py`'s own `recorded_in_gaps()`
check does a literal `\bClassName\b` search, so the abbreviated form satisfied it for none of the
21: the census correctly reported all of them `under` with the message "no line in
occtswift-wrapping-gaps.md," even though a human reading the prose would call the class covered.
Fixed by generating the full class-name lists from `CURATED` directly and pasting them into the
docs section verbatim (the `ATTRIBUTE_DRIVER`, `TOBJ_DRIVER` and `PERSISTENT_SCHEMA` buckets, the
three that had used the abbreviated form), re-running the census after each fix. This is exactly
the failure mode the census exists to catch, and it caught it on the first real use, not in a
contrived self-test.

## Proving the detectors fail

`selftest_removal_matrix.py` switches off each accepting shape in turn:

```
declares_member baseline: 12/12 cases pass unmodified

  method-call          disabled -> 4/12 cases fail  [load-bearing]
  nested-type          disabled -> 1/12 cases fail  [load-bearing]
  data-member          disabled -> 1/12 cases fail  [load-bearing]
  base-class-walk      disabled -> 2/12 cases fail  [load-bearing]
  none-propagation     disabled -> 1/12 cases fail  [load-bearing]

_ATTRIBUTION_RE baseline: 6/6 cases pass with the shipped pattern

  closing-backtick-anchor    imposed -> 2/6 cases fail  [load-bearing]
  no-leading-backtick        imposed -> 1/6 cases fail  [load-bearing]

classify baseline (real tree): {'ok': 9, 'deliberate, recorded': 333, 'under': 0}
  docs-first AND gaps.md-as-docs -> {'ok': 342, ...}  [load-bearing]
    ordering alone                -> {'ok': 15, ...}   [load-bearing]
    gaps.md-as-docs alone         -> {'ok': 9, ...}    [redundant on this lane]
```

**This lane's `_header_bases` carries no `using X = Template<...>` alias branch at all**, unlike
#811's/#812's, because measured (not assumed): no header among this lane's 342 is declared that
way. Carrying an alias-resolution path nothing in the lane's own data would ever exercise is
exactly the "accepting branch with 0/N cases" shape #812's own README calls decoration, so it is
removed rather than kept-but-untested. The None-propagation shape still needed a real case, and
this lane has a genuine one that is not an alias template: `class BinObjMgt_RRelocationTable :
public NCollection_DataMap<int, occ::handle<Standard_Transient>>` -- `_header_bases`' comma-split
does not respect the nested angle brackets, so it also returns `"occ::handle"` as a second "base," a
real parse artifact with no header of its own. `NCollection_DataMap` genuinely lacks the probe
member (`False`), so the walk proceeds to the artifact, whose header is absent (`None`), and that
`None` must propagate rather than be swallowed as `False`. Documented in `_header_bases`' own
docstring so a future reader does not mistake it for a bug to fix.

**Two checks unique to this lane's classifier, both measured wrong on the first draft and
corrected by running them rather than by reasoning about them:**

```
this lane's own addition: gaps.md TEXT vs the CURATED python table, isolated
  gaps.md TEXT stripped (CURATED intact) -> {'ok': 9, 'deliberate, recorded': 1, 'under': 332}
    -> matches expected  [load-bearing for 332 of 333; Storage_Schema survives on a SECOND,
       pre-existing gaps.md mention this lane's own section did not create]
  CURATED emptied (gaps.md TEXT intact)  -> {'ok': 15, 'deliberate, recorded': 327, 'under': 0}
    -> matches expected  [PARTIALLY load-bearing: 6 of 333 curated classes are ALSO separately
       documented outside gaps.md, and CURATED's priority over the docs test in classify()'s
       ordering is what keeps them at `deliberate, recorded` instead of flipping to `ok`]
```

The first draft of both checks asserted the more obvious-sounding property (strip the text ->
everything drops to `under`; empty the table -> nothing changes, since every name is still in the
text) and both were wrong when actually run. `Storage_Schema` has a second mention in the
`#371`/`#374` writeup that predates this PR, so stripping only this lane's own new section leaves
one class still `deliberate, recorded`. And `classify()`'s ordering puts the curated-table check
*before* the documented-elsewhere check, so for the 6 classes that are both curated and separately
named in `docs/thread-safety.md`'s prose (`BinLDrivers_DocumentStorageDriver`, `PCDM_Reader`,
`PCDM_StorageDriver`, `Storage`, `Storage_CallBack`, `Storage_Schema` -- `Storage` itself only on a
bare-word false match against unrelated pages, the same "name match, not reason match" caveat
#811/#812 both already carry), removing `CURATED` lets the docs check fire first and they become
`ok` instead. Both corrected values are recorded in the script with the measured reason, not the
originally-assumed one.

## What this pass did not do

- **No general-purpose gate promotion.** Same status #811/#812 leave `census-doc-occt-attribution.py`
  in: still a report, not a gate. 0 candidates on this lane specifically, the lowest of the three
  lanes it has now run on, because this lane is barely documented at all outside the classes this
  census already accounts for.
- **`docs/thread-safety.md` is not touched**, on purpose, per this task's carve-out. See #1232.
- **`StdDrivers_`/`StdLDrivers_` are not wrapped.** The finding is recorded as a genuine,
  narrow gap, not implemented; see "The one genuine finding" above.
