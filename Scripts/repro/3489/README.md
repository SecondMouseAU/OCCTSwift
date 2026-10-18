# #3489: what carried patches 0070 to 0072 change in a binary OCAF file's document data

Follow-up to #3486 (`Scripts/repro/3486/`, which has the first measurement of every case but the
list drivers, `NamedData` and the table names past the first). Measured 2026-10-18 against the
macOS slice of `v4.0.0-kernel.7` ("unpatched") and the same slice with the translation units of
patches `0070` to `0072` compiled from the patched tree and swapped in with `ar r` ("patched"),
through `TDocStd_Application::Open` with the bridge guards absent (`probe.mm`), under the #3477
interposer.

```bash
K=<unzipped kernel.7>/OCCT.xcframework/macos-arm64      # or a copy with the patched objects swapped in
clang -dynamiclib -o $W/interpose.dylib Scripts/repro/3477/interpose.c
clang++ -std=c++17 -ObjC++ -w -I $K/Headers -L $K -lOCCT-macos -framework Foundation \
  -framework AppKit -lz -lc++ Scripts/repro/3489/probe.mm -o $W/probe
$W/probe $W/rt.cbf roundtrip                              # one of every array/list attribute, saved and reopened
W=$W PROBE=probe python3 Scripts/repro/3489/cases.py arrays|label|shape
```

`ocaf.py` is `Scripts/repro/3486/ocaf.py` (its docstring has the layout; `python3 ocaf.py
<file saved by probe make-int>` checks the builder). `probe.mm` is the #3486 probe plus
`roundtrip`. The shape section is read only when the file's type list names `TNaming_NamedShape`,
which is why `cases.py` lists it.

## The cases, unpatched and patched

Unpatched is the log's first allocation of 8 MiB or more, or the outcome; patched is `status=0`,
no allocation logged, 0.0 s, in every row.

| Case | Unpatched |
|---|---|
| `intarray_2^28`, `intarray_int_max` | 1 GiB, 8 GiB (1.6 s) |
| `realarray_2^29` | 4 GiB |
| `bytearray_int_max` | 2 GiB, 11.7 s |
| `extstrarray_2^30` | 16 GiB, 16.0 s |
| `refarray_2^30` | 8 GiB |
| `boolarray_int_max` | 256 MiB |
| `intlist_2^22`, `reallist_2^22` | 16, 32 MiB, then a 4M node list |
| `nameddata_intarray_big`, `nameddata_realarray_big` | 2 GiB, 4 GiB |
| `ref_tags_536870912` (2^29), `ref_tags_1073741824` (2^30) | no result in 60 s (2^28 returns: its product fits) |
| `token_4096_at_{Locations,Curve2ds,Curves,Surfaces,TShapes}` | SIGTRAP, all five |
| `token_1048576_at_Locations` | no result in 60 s |
| `token_300_at_*` | status ok (the stack is overwritten silently) |
| `intarray_ok`, `realarray_ok`, `bytearray_ok`, `boolarray_ok`, `intlist_ok`, `ref_ok_no_tags` | status ok, both |

`probe roundtrip` saves one attribute of every kind (`IntegerArray`, `RealArray`, `ByteArray`,
`ExtStringArray`, `BooleanArray`, `ReferenceArray`, the three lists, `NamedData` with both array
kinds), reopens the file and compares the values: `roundtrip OK` on both, so the bound refuses no
file the writer produces.

## Not patched: label nesting

`deep_1000` loads and `deep_20000` SIGSEGVs (`Scripts/repro/3486`), unchanged. `ReadSubTree`
recurses once per nested label and the limit is the stack of the thread that calls `Open`, not
anything in the file, so there is no quantity to compare against. OCCT's OCAF readers have no depth
guard to follow: the only depth bounds in the source are `BRepGraph`'s, which derive theirs from the
node count of the graph they walk. Options: rewrite `ReadSubTree` as a loop with an explicit stack
(a kernel refactor, not a bounds check), or a stack-size constant, which is arbitrary.

## Not measured: wasm

Native only. On 32-bit wasm the array rows request more than the 4 GiB address space, so the
allocator failure of #3477 follows; the patched code never forms `count * size`, it divides what is
left in the record by the element size.
