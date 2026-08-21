# #1055 / #1056: the datum name's length, and two write paths that answered for what the document did not take

Three defects, all on the GD&T surface, all reachable from the public Swift API. Everything here is
measured through `Document`, so unlike the neighbouring GD&T directories there is no C++ probe: the
two Swift suites **are** the reproducer, and `run.sh` is the injection matrix that proves they are
not decorative.

## The three defects

### #1055, a name truncated at 63 bytes on the way out

`OCCTDatumInfo` carried the datum identifier back through a `char name[64]`, filled with

```objc
strncpy(info.name, hName->String().ToCString(), std::min((int)sizeof(info.name) - 1, hName->Length()));
```

while `createDatum(name:)` handed OCCT the whole string. Measured on `main` at `cb482250`, a
100-character name wrote 100 and read 63, with nothing anywhere in the chain saying so: no flag, no
length field, no `nil`. `Datum.name` is a plain `String`, so a caller comparing what it wrote
against what it read saw a mismatch and no explanation.

The bound was not derived from anything. STEP AP242 datum identifiers are conventionally short
(`A`, `B`, `A1`), which is presumably why 64 looked generous, but a datum arriving from a STEP
import is read through the same accessor and nothing bounds its name.

### #1056 site 1, a discarded tolerance result

`createDimension(on:type:value:lowerTolerance:upperTolerance:)` created the dimension, called
`OCCTDocumentSetDimensionTolerance` and threw away its `Bool`. The setter has three `return false`
paths and none reached the caller, so a tolerance pair the document refused still produced a valid
index for a `.simple` dimension.

`Double.nan` is the cheapest trigger, because the bridge's readback is an exact `==` against both
stored values and NaN never equals itself, but anything OCCT does not store bit for bit takes the
same path.

**One claim from the original report is not reproduced and should not be carried forward**: that the
exact `==` readback rejects a NaN tolerance which was in fact applied. It was not applied. The
refusal precedes `dimAttr->SetObject(dimObj)`, the object OCCT mutates is a copy the document never
sees, and `dimension(at:)` reads back `.simple`. The defect was only ever the discarded return.

### #1056 site 2, a value under a cleared modifier

`OCCTDocumentSetGeomToleranceZoneModifier` wrote

```objc
tolObj->SetValueOfZoneModifier(value > 0.0 ? value : 0.0);
```

with no reference to the modifier it had just set, so `.none` with a value stored the value. The
reader gates `zoneModifierValue` on `> 0` and never on the modifier, so nothing downstream caught it
and `geomTolerance(at:)` reported a projected-zone length of 15 on a tolerance with no projected
zone. `OCCTDocumentSetDatumModifierWithValue`, four hundred lines below in the same file, already
cleared its value under `_None` and carried a comment saying why.

## What was chosen, and why

For #1055 the question was which contract, not which patch. Three shapes were on the table:
keep the fixed buffer and report the truncation, return the name through a caller-sized
out-parameter, or refuse a write longer than the readable bound.

The third was rejected because it does not help a datum that arrived from a STEP import, which is
read through the same accessor and was never written by this package. The first leaves an arbitrary
bound in a public C header that a caller has to know about to use correctly.

What shipped is the second, plus the length report that makes it self-describing:

```c
int32_t OCCTDocumentGetDatumName(OCCTDocumentRef doc, int32_t index, char* outName, int32_t maxLen);
```

It fills `outName` up to `maxLen - 1` bytes, NUL-terminates, and returns the length of the **whole**
identifier, so `>= maxLen` means "what you hold is a prefix" and is also exactly the buffer size to
allocate for the next call. `NULL` with `maxLen` `0` asks for the length alone. That is the ordinary
C sizing protocol, it works for a caller that is not Swift, and truncation is never silent: the
number that says so comes back on the same call. `OCCTDatumInfo.name` is gone rather than kept
alongside, so there is one way to read the name and it cannot truncate without reporting.

For #1056 site 1, the fix cannot be "return `nil` after the fact", because the dimension already
exists by then and nothing in this bridge can undo an `AddDimension()`. So the whole object,
tolerance included, is built and checked **before** any label is created:
`OCCTDocumentCreateDimensionWithTolerance`. Both create entry points and
`OCCTDocumentSetDimensionTolerance` now share one `occtDimensionApplyTolerance`, so the two
spellings of the operation agree on what counts as applied by construction rather than by two copies
staying in step.

For #1056 site 2 the setter clears the value under `_None`, matching the datum sibling exactly. The
call still returns `true`: the document and the answer now agree, which is the property the issue is
about, and refusing a call that did what was asked would be a different defect.

## The injection matrix

`./run.sh` restores each defect in turn, rebuilds, runs both suites and reports what goes red. It
refuses to start if the two files it edits have uncommitted changes, and restores from its own
copies on exit.

| Injection | Restores | Cases red |
|---|---|---|
| `A1` | `OCCTDocumentGetDatumName` reports the copied length rather than the whole one | 6, across 4 tests: the 100-character round trip, `length: 64` and `65`, the short-buffer report, the `datums` enumeration |
| `A2a` | drop the negative-`maxLen` half of the argument guard | 1: `malformedBufferArgumentsAreRefused`, which reads `1` instead of `-1` |
| `A2b` | drop the null-`outName` half of the argument guard | none, **SIGSEGV** (signal 11) at the `(nil, 8)` call, which takes the run with it, see below |
| `A3` | `Document.datumName` keeps the first call's answer, dropping the resize | 5, across 3 tests: the Swift half only, both bridge-level tests stay green |
| `B` | `occtDocumentCreateDimensionImpl` applies the tolerance and ignores the refusal | 6, all three cases of `nonStorableToleranceRefusesTheCreate`, on both `index == nil` and `dimensionCount == 0` |
| `C` | `SetValueOfZoneModifier` stops clearing under `_None` | 2: `noneModifierStoresNoValue` and `clearingAModifierClearsItsValue` |

Baseline with no injection: 14 tests in 2 suites, all passing.

Three things the table is worth reading carefully for.

**`A2b` is stronger evidence than a red case, and it cannot be reported as one.** Removing the
null-buffer half lets `outName[0] = '\0'` run on a null pointer, which takes the process down at the
`(nil, 8)` call. A SIGSEGV is not a failing test, so the row is not "the test caught it"; it is "the
guard is load-bearing and the removal proves it a different way". The `(&buffer, -1)` expectation
one line above it is evaluated first, so the crash lands mid-test rather than before any assertion
runs, and takes the whole run with it.

**`A1` and `A3` overlap but are not the same experiment.** Both fail the three Swift-level tests,
because either half of the sizing protocol alone is enough to truncate. `A1` additionally fails
`shortBufferReportsTheFullLength`, and `A3` leaves both bridge-level tests green. That disjointness
is what says the two halves are separately covered rather than one masking the other.

**`C` reaches `clearingAModifierClearsItsValue` only because that test passes a value with the
clear.** An earlier draft cleared with `setGeomToleranceZoneModifier(at:, .none)` and no value,
which the old code already handled correctly through its `value > 0.0` gate, so the test was green
under its own injection and proved nothing. The test now does both, and its own comment says which
half is the probe and which is the regression guard.

**One guard has no row here, and adds nothing measurable, deliberately.** `Document.datumName`'s
second call checks `Int(again) < exact.count` as well as `again >= 0`. Nothing can make that fire:
`again` is the same name's length read a second time, and this surface has no rename and no removal,
so it cannot exceed the buffer sized from the first read. It is there because the failure it would
prevent is exactly #1055's, a prefix handed back as the name, at the one site the whole contract
rests on. An injection row would measure nothing, and `prove-the-test-fails` asks that such a case be
labelled rather than celebrated, which is what this paragraph is.

## The pattern this fixes one instance of

A fixed buffer that truncates silently is not unique to `OCCTDatumInfo`. Swept across the whole
bridge, seven sites remain after this change, none touched here:

| Site | Shape |
|---|---|
| `OCCTBridge_Document.h` `OCCTMaterialInfo.name[128]` | fixed `char[N]` in a returned struct |
| `OCCTBridge_Document.h` `OCCTMaterialInfo.description[256]` | fixed `char[N]` in a returned struct |
| `OCCTBridge_AIS.h` `OCCTTextLabelInfo.text[256]` | fixed `char[N]` in a returned struct, `strncpy` at `OCCTBridge_AIS.mm:573` |
| `OCCTDocumentGetLayerName` | caller-sized `char*`/`maxLen`, truncates and returns `true` |
| `OCCTDocumentGetLengthUnit` | the same, `if (len >= maxNameLen) len = maxNameLen - 1;` then `return true`. `Document.lengthUnit` hardcodes 64. |
| `OCCTDocumentGetLabelLayers` | caller-sized `char*`/`maxLen` per name, truncates each and reports nothing |
| `OCCTBRepGraphHistoryGetRecordInfo` | caller-sized `char*`/`maxLen`, truncates and returns `true` |

**The criterion is one string cut short, not one list cut short**, and the two are easy to run
together. `OCCTDocumentGetLabelLayers` also caps the number of names at `maxNames` and returns only
what it wrote, and so do `OCCTDirectoryList` and `OCCTFileList` (`OCCTBridge_IO.h:761,774`), which
loop `while (it.More() && count < maxCount)`; `DirectoryIterator.list` and `FileIterator.list`
default that cap to 1000, so a directory of 1001 entries reads as 1000 with nothing said. That is a
real defect of the same family and it is deliberately not in the table above, because a fix for it
is a different signature change from the one #1078 settles: a count contract, not a string one.
Filed as its own note on #1078 rather than folded into the seven.

`OCCTUnicodeConvertFromUnicode` has the same signature shape and is **not** in the list: OCCT's own
`Resource_Unicode::ConvertUnicodeToFormat` returns false when the buffer is too small, so that one
already reports.

**The `OCCTDocumentGetLengthUnit` row was missed on the first pass and added on review**, which is
worth recording rather than quietly correcting: the sweep was run before this change touched
`Document.lengthUnit`, and the site sits in the same file, four lines from a row that did make the
list. A census taken once and not re-run against the diff is a census of the tree you started with.

All seven are filed as #1078, which reuses the contract settled here. They want one PR rather than
seven, because dropping the three `char[N]` fields and changing the four `maxLen` returns are both
source-breaking changes to the public C header.

## Files

| File | What it is |
|---|---|
| `run.sh` | The injection matrix. `./run.sh` for all six, `./run.sh B` for one. |
| `Tests/OCCTXCAFTests/Issue1055DatumNameLengthTests.swift` | The #1055 suite, in the test tree rather than here because it is permanent coverage. |
| `Tests/OCCTXCAFTests/Issue1056GDTWriteAnswerTests.swift` | The #1056 suite, same. |

Requires a local `Libraries/OCCT.xcframework`; `run.sh` builds with `OCCTSWIFT_LOCAL=1` and with
`OCCTSWIFT_BRIDGE_PREBUILT` unset, since it edits `.mm` sources a prebuilt bridge would mask.
