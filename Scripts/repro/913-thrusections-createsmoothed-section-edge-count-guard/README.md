# OCCTSwift #913: `BRepOffsetAPI_ThruSections::CreateSmoothed()` has no bounds check on its fixed-stride `shapes` array

`ThruSectionsBuilder`, given `checkCompatibility(false)` and 3+ sections where a later section's
edge count differs from section 1's, either SIGSEGVs/SIGBUSes (more edges) or silently succeeds
with wrong geometry (fewer edges) instead of failing cleanly. Found incidentally while hunting for
a failure trigger during [#910](https://github.com/SecondMouseAU/OCCTSwift/issues/910)'s own PR
review.

## Mechanism

`CreateSmoothed()` derives `nbEdges` -- the edge count it assumes every section has -- from
section 1 alone (or section 2, if section 1 is a punctual/degenerate vertex section). It allocates
`shapes`, an `NCollection_Array1<TopoDS_Shape>` sized exactly `nbSects * nbEdges`, then fills it by
walking each section's wire with a `BRepTools_WireExplorer`, incrementing a running index with
**no bounds check**.

`BRepFill_CompatibleWires` (via `checkCompatibility(true)`, the default) normally reconciles
differing edge counts across sections before `CreateSmoothed()` ever runs.  `checkCompatibility
(false)` ("no check") skips that entirely, so nothing enforces that every section actually has
`nbEdges` edges. Two ways that goes wrong, both exercised in `occt_913_test.mm` below:

- **More edges than section 1**: the fill loop walks the array straight past the end of `shapes`
  -- an out-of-bounds write, corrupting adjacent heap memory instead of raising a catchable
  failure.
- **Fewer edges than section 1**: if a later section's surplus edges exactly compensate an
  earlier section's shortfall, the running write index never exceeds the array's bounds at any
  point -- no overrun, no crash, so `Build()` reports success today, but with per-section strides
  silently misaligned to the wrong geometry. Confirmed: `Build() == true` **and**
  `Shape().IsValid() == false` for the accepted result.

**Reached only with 3+ sections.** With exactly 2 sections, `Build()` always takes the
`CreateRuled()` path instead (`if (myWires.Length() == 2 || myIsRuled) CreateRuled(); else
CreateSmoothed();`), which builds its shell via `BRepFill_Generator` -- a different mechanism that
doesn't share this fixed-stride allocation.

**Needs no reused builder as such.** The original investigation found the crash only via a
"build once successfully, reuse the same builder, build again with a mismatched section" sequence,
which looked like it needed that specific reuse pattern. It doesn't: instrumenting the fill loop
directly shows the write index reaching one past `shapes.Upper()` on a single, from-scratch
`Build()` call too. What actually varies is process/allocator state at the moment of the overrun --
a from-scratch process more often lands the out-of-bounds write in unmapped-but-harmless heap slack
than a process that has already done other allocation/deallocation work, so a single-call
reproduction is unreliable while a reused-builder one (or, as this probe's own runs show, one
preceded by several other successful `ThruSections` builds) is *more* likely to crash but still not
guaranteed to, every run.

**SIGSEGV and SIGBUS were both genuinely observed, in different binaries -- not a contradiction to
resolve to one signal.** An early, isolated reproducer (just the reused-builder overrun scenario,
nothing else run first) crashed with `signal 11` (SIGSEGV) consistently, caught by this probe's own
`backtrace_symbols_fd`-based handler. A separately-built GTest binary (linking
`BRepOffsetAPI_ThruSections_Test.cxx` against the same stock archive, no custom handler, OS default
signal handling) crashed with `Bus error: 10` (SIGBUS). CI caught a third instance directly: PR
#915's `swift build + test (macOS)` job (`swift test` against `Package.swift`'s pinned kernel,
which does not have this patch) aborted with:

```
*** Abort *** an exception was raised, but no catch was found.
	... The exception is: SIGSEGV 'segmentation violation' detected. Address 85e5c2a64238.
```

Same defect, same out-of-bounds write, three different binaries -- which signal manifests depends
on allocator/memory layout at the moment of the overrun, exactly the process-state sensitivity
described above. Do not read a different signal on a later observation as evidence this is a
different bug.

## Running it

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/913-thrusections-createsmoothed-section-edge-count-guard/occt_913_test.mm \
  -o /tmp/occt_913_test
/tmp/occt_913_test
```

Compile once against the stock archive (`stock.txt`) and once with a patched
`BRepOffsetAPI_ThruSections.cxx` override-linked in front -- compile that file standalone and link
its `.o` **before** `-lOCCT-macos` on the command line (`patched.txt`) -- and diff. Six scenarios,
matching the six numbered cases in the probe's own header comment: three that must always succeed
(matching edge counts, a punctual apex, and `checkCompatibility(true)` reconciliation), the overrun
case (case 4 -- process-state dependent, see above; this exact captured run did not crash, which
is itself expected and documented, not a failure of the repro), the fewer-edges silent-success case
(case 5 -- the one difference between `stock.txt` and `patched.txt`: `IsDone=1` before, `IsDone=0`
after), and the zero-edge punctual hardening (case 6 -- `IsDone=0` on both, see below).

## The zero-edge-at-punctual-position case is a hardening, not a proven-live fix

The patch's punctual-section exemption (`w1Point`/`w2Point`) additionally checks that the section
actually has at least one edge before exempting it from validation, since `w1Point`/`w2Point` are
computed by a pre-existing loop that is vacuously `true` for a wire with **no** edges at all (the
loop body that would clear the flag never runs) -- which would otherwise let the fill loop walk an
uninitialized `BRepTools_WireExplorer` and read a null edge.

Attempted to reproduce a live crash for this specific case, including via a reused builder (build
successfully with 3 matching sections, then add a genuinely empty wire as a 4th and rebuild) -- see
case 6 in `occt_913_test.mm`. Neither attempt crashed, against stock OR patched: something else
downstream (most likely `TotalSurf()`'s own null-surface guard reacting to whatever a degenerate
empty-wire input produces) already reports `IsDone() == false` for this input today, by an
unconfirmed mechanism independent of this patch. The hardening is kept anyway -- it is correct and
cheap regardless of whether today's fill loop actually reaches the unguarded path it describes --
but no committed GTest claims to prove it closes a live gap, because the one written for it could
not be made to fail without the check and was removed rather than kept as unproven coverage.

## Fix

`Scripts/patches/0027-BRepOffsetAPI_ThruSections-CreateSmoothed-section-edge-count-guard-913.patch`.
Before allocating `shapes`, walk every non-punctual section and count its edges; on a mismatch (an
inequality test, not a "too many" test -- deliberately symmetric, since both directions are the
same underlying contract violation), set `myStatus` to
`BRepFill_ThruSectionErrorStatus_ProfilesInconsistent` and return, matching the early-return idiom
this function already uses two lines below. The punctual-section test (`isPunctualSection`, a local
lambda) is shared with the pre-existing fill loop 15 lines below, which used to duplicate the same
two-clause boolean expression separately.

Filed upstream as [OCCT#1466](https://github.com/Open-Cascade-SAS/OCCT/pull/1466). Full validation
transcripts and the PR #915 review response (12 findings, all addressed or explicitly documented)
live in `Scripts/patches/README.md`'s `0027` entry.
