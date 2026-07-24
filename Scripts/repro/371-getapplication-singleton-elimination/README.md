# OCCTSwift#371 reproducer — private `TDocStd_Application` per document

Writeup for the singleton-elimination refactor: replacing every
`XCAFApp_Application::GetApplication()` call in the bridge with a private
`new TDocStd_Application()` per `OCCTDocument`, per upstream maintainer feedback on
[OCCT#1396](https://github.com/Open-Cascade-SAS/OCCT/issues/1396) (our #353 repro issue).

## Verdict

**Partial win, with a new discovery.** Ground-truth C++ testing confirmed a bare
`TDocStd_Application` behaves identically to `XCAFApp_Application::GetApplication()` for our
usage (create, attach XCAF tools, add shape, set color, retarget storage format, save, reload with
a *separate* private instance). Header inspection confirmed the state #344/#349/#353 fixed
(`CDF_Directory::myDocuments`, `CDF_Application::myReaders`/`myWriters`,
`CDM_Application::myMetaDataLookUpTable`) is per-instance, not static — a private app per document
makes that state exclusive to one document by construction.

**But a dedicated confirmation harness (`occt_371_private_app.cpp`) — private app per
thread/round, zero shared state, zero serialization mutex, run against the real TSan-instrumented
kernel — was NOT clean.** It found two previously-uncharacterized races, filed upstream as
[OCCT#1398](https://github.com/Open-Cascade-SAS/OCCT/issues/1398):

1. **`Resource_Manager::Resource_Manager()`** (`Resource_Manager.cxx:109`) writes a file-scope
   global `Debug` on every construction, unsynchronized.
2. **`Storage_Schema::ICurrentData()`** (`Storage_Schema.cxx:802`) — a process-wide mutable
   `Handle` that every `Storage_Schema` constructor nullifies and every (de)serialization call
   reads, also unsynchronized.

Neither had ever been caught by this project's prior TSan gates (#298/#319/#341/#344/#345/#348/
#349/#353) because none of them exercised concurrent construction of *independent* application
instances — every prior investigation (and all of production, until this change) shares one
`XCAFApp_Application::GetApplication()` instance, so `Resources()`'s own per-instance lazy-init
mutex (from the #344 fix) accidentally made `Resource_Manager`/`Storage_Schema` usage happen only
once, serially, for the whole process. Moving to a private instance per caller — the pattern
OCCT's own maintainer recommended in #1396 — is what first makes these concurrent, and they race.

## Practical implication

`ocafStoreMutex()` (`Sources/OCCTBridge/src/OCCTBridge_Document.mm`, originally added for #349) is
**not fully redundant after this refactor** — it turns out to also serialize the
Resource_Manager/Storage_Schema hazard, for reasons unrelated to why it was first added. Its
coverage was expanded to include the six `OCCTDocumentDefineFormatBin/BinL/Xml/XmlL/BinXCAF/
XmlXCAF` functions and `OCCTDocumentCreateWithFormat` (previously outside the lock — safe only by
accident, since every document shared one app instance) so every `DefineFormat`/`Open`/`SaveAs`/
`Save` call now goes through the same mutex regardless of which private app instance it's on.

Confirmed by adding an equivalent mutex to a copy of `occt_371_private_app.cpp` (wrapping
`DefineFormat`/`SaveAs`/`Open` exactly as the expanded `ocafStoreMutex()` now does): 8x50 clean,
zero TSan warnings, zero failures — same coverage, same result as the real bridge.

## What #371 still genuinely fixes

The refactor itself is real and worth keeping: `OCCTDocument` no longer touches the shared
`XCAFApp_Application::GetApplication()` singleton at all, which means our own bridge can no longer
trip over the *original* mechanisms behind #341/#344/#349/#353 (shared `CDF_Directory`, shared
driver cache, shared metadata lookup table) — those are now structurally per-document. What it does
NOT do is eliminate the need for all cross-thread serialization around OCAF persistence calls,
because `Resource_Manager`/`Storage_Schema` are lower-layer, genuinely process-global state that
lives below `CDF_Application`/`TDocStd_Application` entirely.

## Repro

`occt_371_private_app.cpp`: N threads x M rounds, each round builds a **brand-new private**
`TDocStd_Application`, defines formats, populates and saves a document, closes it, then opens a
**separate, also brand-new private** app to reload and verify — mirroring `OCCTDocument`'s ctor and
`OCCTDocumentLoadOCAF`'s "never reuse the writer's app" pattern exactly. No barrier is strictly
required (unlike #344/#349/#353's shared-instance harnesses) since there's no shared instance to
contend for, but one is still used at the SaveAs point to maximize genuine overlap.

```
Usage: occt_371_private_app <threads> <rounds> <scratchDir>
```

Unguarded run (8x50): 16 TSan race warnings, 0 functional failures (the races are real but don't
corrupt data in a single-threaded-per-object test — they're a race on OCCT's own internal
bookkeeping, not on the document being saved).

Guarded run (same harness + a mutex around `DefineFormat`/`SaveAs`/`Open`, matching the expanded
`ocafStoreMutex()`): 0 TSan warnings, 0 failures.
