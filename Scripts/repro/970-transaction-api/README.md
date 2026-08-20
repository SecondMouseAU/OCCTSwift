# #970: what OCCT offers for a transaction name and a transaction number

`probe_transaction.mm` is a ground-truth C++ probe against the pinned kernel (OCCT 8.0.1). It
answers the two questions #970 asks before any code changes, plus a third defect it turned up.
`probe_transaction.out` is its transcript.

Build and run from the repo root:

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/970-transaction-api/probe_transaction.mm -o /tmp/occt_970_probe
/tmp/occt_970_probe
```

## 1. There is no named-open API, and the name lives on the committed delta

`TDocStd_Document` has `OpenCommand()`, `NewCommand()`, `CommitCommand()`, `AbortCommand()` and
`HasOpenCommand()`, none of which takes a name. Its own transaction is a private
`TDF_Transaction myUndoTransaction`, constructed as `myUndoTransaction("UNDO")`
(`TDocStd_Document.cxx:76`); `TDF_Transaction`'s name is a constructor argument with no setter, so
even a wrapped `TDF_Transaction` could not be renamed after construction.

What OCCT does have is `TDF_Delta::SetName` / `TDF_Delta::Name`, and one caller of it:

```cpp
bool TDocStd_MultiTransactionManager::CommitCommand(const TCollection_ExtendedString& theName)
{
  ...
  myUndos.First()->SetName(theName);
```

So a caller-supplied transaction name belongs on the delta a commit produces, not on the open
transaction. Case F measures the round trip, and case J that the name survives undo and redo
(`TDocStd_Document::Undo` copies it onto the redo delta):

```
--- F: where a transaction name can live ---
delta name before SetName = ''
delta name after  SetName = 'add part'
delta BeginTime=0 EndTime=1 Data->Time()=1
--- J: does a delta name survive undo and redo? ---
undo delta name = 'add part'
after Undo, redo delta name = 'add part'
after Redo, undo delta name = 'add part'
```

## 2. `TDF_Data::Transaction()` is a depth, and a document never takes it past 1

`TDF_Data::Transaction()` returns `myTransaction`, incremented by `OpenTransaction()` and
decremented on commit or abort: the depth of the open transaction stack on the data framework.

A `TDocStd_Document` holds exactly one `TDF_Transaction`, so the depth is 0 or 1 in every state its
command API can reach. Nested transaction mode does not change this, which is the part worth
measuring rather than reading: `TDocStd_Document::OpenTransaction` *commits and reopens* the same
transaction when one is already open, accumulating into a `TDocStd_CompoundDelta` FILO instead of
pushing a second framework transaction.

```
--- C: undo limit 10, nested transaction mode ---
open #1               | HasOpenCommand=1 | Data->Transaction()=1 | ...
open #2 (nested)      | HasOpenCommand=1 | Data->Transaction()=1 | ...
open #3 (nested)      | HasOpenCommand=1 | Data->Transaction()=1 | ...
```

Only a raw `TDF_Transaction` opened directly on the document's `TDF_Data` stacks, and no document
API does that:

```
--- E: raw TDF_Transaction stack on the document's own TDF_Data ---
t1.Open() -> 2 name='outer' Data->Transaction()=2 HasOpenCommand=1
t2.Open() -> 3 name='inner' Data->Transaction()=3 HasOpenCommand=1
```

So `HasOpenCommand() ? 1 : 0`, the expression the bridge used, agrees with
`GetData()->Transaction()` in every reachable state, including case A's (with the undo limit at its
default of 0, `OpenCommand()` opens nothing at all and both report 0). The defect is that the value
was synthesized rather than read, and that the documentation promised a counter the document does
not have. `TDF_Data::Time()` is the counter that does exist, and it is the unit
`TDF_Delta::BeginTime`/`EndTime` are expressed in:

```
--- G: does Data->Time() advance per committed transaction? ---
before open #0 Time()=0 Transaction()=0
before open #1 Time()=1 Transaction()=0
before open #2 Time()=2 Transaction()=0
before open #3 Time()=3 Transaction()=0
after 4 commits Time()=4 undos=4
after Undo      Time()=3 undos=3 redos=1
after Redo      Time()=4 undos=4 redos=0
```

## 3. `OCCTDocumentCommitWithDelta` could not return a delta (found here, fixed with #970)

Its first statement was `doc->doc->SetUndoLimit(100)`. `TDocStd_Document::SetUndoLimit` commits the
open transaction before it changes the limit (`TDocStd_Document.cxx:443`, `CommitTransaction()`), so
the `CommitCommand()` on the next line had nothing left to commit, returned false, and the bridge
returned `nullptr`. Case I runs the bridge's own sequence:

```
--- I: what OCCTDocumentCommitWithDelta actually does ---
before: HasOpenCommand=1 undos=0
after SetUndoLimit(100): HasOpenCommand=0 undos=1
CommitCommand() -> 0 undos=1   (the bridge returns nullptr when this is false)
```

`Document.commitWithDelta()` therefore returned `nil` for every transaction that had one open,
which is every intended use. The existing coverage did not catch it because
`OCCTXCAFTests.commitWithDelta` and `deltaName` wrapped every assertion in
`if let delta = doc.commitWithDelta()`, so a `nil` skipped the body and both tests passed on an
empty run. Both now assert the delta is non-nil first.
