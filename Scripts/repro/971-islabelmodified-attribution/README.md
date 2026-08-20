# #971: which half of `OCCTDocumentIsLabelModified`'s comment was wrong

`Sources/OCCTBridge/include/OCCTBridge_Document.h` carried a two-line comment that contradicted
itself:

```c
/// Check if a label is marked as modified (via TDocStd_Modified on root).
/// Note: This uses TDocStd_Document::GetModified(), not TDocStd_Modified attribute directly.
bool OCCTDocumentIsLabelModified(OCCTDocumentRef doc, int64_t labelId);
```

#971 proposed keeping the second line and deleting the first, on the reasoning that
`TDocStd_Modified` is never constructed anywhere in `Sources/OCCTBridge` (true), and that
`TDocStd_Document::GetModified()` therefore "returns the document's own `TDF_LabelMap`, which is a
different mechanism from the root-label `TDocStd_Modified` attribute".

Measured, that last step is wrong, and the correction runs the other way: **the first line was
right and the second was the one to delete.**

## The kernel source

`TDocStd_Document`'s three modified-label methods are forwarders, nothing more
(`Libraries/occt-src/src/ApplicationFramework/TKLCAF/TDocStd/TDocStd_Document.cxx:151-175`):

```cpp
void TDocStd_Document::SetModified(const TDF_Label& L) { TDocStd_Modified::Add(L); }
void TDocStd_Document::PurgeModified()                 { TDocStd_Modified::Clear(Main()); }
const NCollection_Map<TDF_Label>& TDocStd_Document::GetModified() const
{ return TDocStd_Modified::Get(Main()); }
```

and `TDocStd_Modified`'s statics all resolve through `label.Root()`
(`TDocStd_Modified.cxx:45-105`), so the store really is the `TDocStd_Modified` attribute on the
root label. The document owns no map of its own: `TDocStd_Document` has no `myModified` member.
`TDocStd_Document::IsModified` does not exist at all in 8.0.1 (it is commented out at
`TDocStd_Document.cxx:158-161`).

The class never appears in `Sources/OCCTBridge` because the kernel constructs it on the bridge's
behalf inside `TDocStd_Modified::Add`, not because the bridge reaches a different store.

## The second construction

`probe.mm` measures it from outside the kernel rather than reading the source twice. Build and run:

```bash
ln -s <main checkout>/Libraries Libraries          # a worktree's Libraries/ is its own tree
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/971-islabelmodified-attribution/probe.mm -o /tmp/occt_971_probe
/tmp/occt_971_probe
```

Measured against the pinned kernel:

```
before SetModified:
  doc->GetModified() threw             : Standard_DomainError: TDocStd_Modified::Get : IsEmpty
  root has TDocStd_Modified attribute  : no
  TDocStd_Modified::Contains(child)    = false
after doc->SetModified(child):
  root has TDocStd_Modified attribute  : yes
  doc->GetModified().Contains(child)   = true
  attr->Get().Contains(child)          = true
  TDocStd_Modified::Contains(child)    = true
  &doc->GetModified() == &attr->Get()  = true (one map, one mechanism)
after doc->PurgeModified():
  doc->GetModified().Contains(child)   = false
  attr->Get().Contains(child)          = false
after TDocStd_Modified::Add(child):
  doc->GetModified().Contains(child)   = true
```

Four things settle it. Calling the document API creates the `TDocStd_Modified` attribute on the
root label. The map `GetModified()` returns is the same object, by address, that the root
attribute's own `Get()` returns. Clearing through the document API clears the attribute. Marking
through the attribute API is visible through the document API. There is one store, reached two
ways.

## The behaviour the deleted line was groping at

`GetModified()` throws `Standard_DomainError("TDocStd_Modified::Get : IsEmpty")` on a document
where nothing has ever been marked, because `TDocStd_Modified::Get` raises rather than returning an
empty map when the root has no attribute (`TDocStd_Modified.cxx:83-90`). `PurgeModified()` and
`SetModified()` do not, since both tolerate the attribute being absent.

`OCCTDocumentIsLabelModified`'s existing `catch (...) { return false; }`
(`Sources/OCCTBridge/src/OCCTBridge_Document.mm:2201`) turns that into the correct answer, so this
is not a defect and no bridge change is needed. It is worth knowing before anyone "simplifies" that
catch away, and it is why the throw is not reachable from Swift: `Document.isModified(_:)` returns
`false` for an untouched document rather than trapping.

## Proving the clang-format sweep changed no code

`OCCTBridge_Document.h` was grandfathered on `Scripts/style-manifest-bridge.txt`, so correcting two
lines in it obliges the same PR to bring it fully `clang-format` clean and take it off the manifest
(`okf/policies/code-style.md`). Measured with the pinned config, that is **1,714 lines of `diff -u`
output**, matching #971's figure exactly: 322 lines removed, 610 added, 72 hunks, the file growing
2,233 to 2,521 lines. The churn is 932 lines; 1,714 is the `diff -u` total, which includes three
context lines per hunk.

A mechanical sweep that size is where a real change hides, and this repo has twice paid for one
(#942, #959). `tokens-unchanged.py` compares the file before and after by **token sequence** rather
than by line, so formatting is invisible to it and a moved, added or deleted token is not:

```bash
cp Sources/OCCTBridge/include/OCCTBridge_Document.h /tmp/pre_reformat.h   # after the comment fix
clang-format -i -style=file Sources/OCCTBridge/include/OCCTBridge_Document.h
python3 Scripts/repro/971-islabelmodified-attribution/tokens-unchanged.py \
  /tmp/pre_reformat.h Sources/OCCTBridge/include/OCCTBridge_Document.h
```

```
CODE      identical: 51192 chars of normalized non-comment text
COMMENTS  identical after whitespace collapse: 39591 chars
```

Comparing normalized *text* rather than tokens is not enough, and that is measured rather than
assumed: the first run of this comparator collapsed whitespace runs to a single space and reported
`CODE DIFFERS` at `double *_Nonnull` becoming `double* _Nonnull`, which is a star moving across a
space, not a token changing. Tokenizing is what tells those apart.

`--self-test` runs nine cases: four reformat-shaped edits that must read as unchanged (whitespace,
pointer-star placement, re-indentation, comment reflow) and five content-shaped edits that must not
(an identifier rename, a deleted declaration, an added `extern`, a changed comment word, and a `//`
inside a string literal). Under a one-at-a-time removal matrix every feature earns its place:
9/9 baseline, 8/9 without the tokenizer, 7/9 without comment stripping, 8/9 without string-literal
awareness.

## Downstream of this correction

`docs/reference/Document.md` attributed `isModified(_:)` to `TDocStd_Document::IsModified`, a
method that does not exist in 8.0.1; corrected to `TDocStd_Document::GetModified` in the same PR.

PR #977's census artifact (`Scripts/repro/810-refman-document-xde/refman_census.py`, not yet on
`main`) carries the reversed claim in three places: its `TDocStd_Modified` gap rationale, its
`DEFERRED_OVER_FINDINGS` entry for this function, and the paragraph it adds to
`docs/occtswift-wrapping-gaps.md`. All three say `GetModified()` is "a different mechanism". They
need the correction above, and the `DEFERRED_OVER_FINDINGS` entry needs to move to
`KNOWN_OVER_FINDINGS` or be dropped, since its `bad_phrase` is the line this PR kept rather than
the line it deleted. Flagged on #977 rather than edited across PR branches.
