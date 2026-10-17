# #3486: what a binary OCAF file declares after and inside the storage sections

Follow-up to #3477. Measured 2026-10-18 against the macOS slice of `v4.0.0-kernel.7`, through
`TDocStd_Application::Open` with the bridge guards absent (`probe.mm`), under the #3477 interposer.

```bash
K=<unzipped kernel.7>/OCCT.xcframework/macos-arm64
clang -dynamiclib -o $W/interpose.dylib Scripts/repro/3477/interpose.c
clang++ -std=c++17 -ObjC++ -w -I $K/Headers -L $K -lOCCT-macos -framework Foundation \
  -framework AppKit -lz -lc++ Scripts/repro/3486/probe.mm -o $W/probe
$W/probe $W/a.cbf make-int          # python3 Scripts/repro/3486/ocaf.py $W/a.cbf checks the builder against it
W=$W python3 Scripts/repro/3486/cases.py storage|data|shape
```

`ocaf.py` builds the files (layout in its docstring). Results of the storage cases vary from run to
run where the bad index lands in mapped memory, so a silent load is not a pass.

## Storage sections (before `edata`): mitigated by the bridge

All in `FSD_BinaryFile::ReadCompleteInfo`, reached from every open through `PCDM_ReadWriter::FileFormat`.

| Case | Result |
|---|---|
| `type_num_N`, N outside [1, count] | `SetValue` writes outside the array: 0, -1, 2, 100 load silently, 3, 2^20, 2^28 SIGSEGV/SIGBUS |
| `type_count_neg5`, `nbobj_neg5` | `HArray1(1, -5)` asks `malloc((size_t)-40)`: SIGSEGV |
| `ref_*` (any record) | `theCallBack->Value(aTypeNum)->New()` is a call through a null handle: SIGSEGV |
| `ref_no_comment`, `root_no_comment` | `ReadArray()` is null: SIGSEGV |
| `root_ref_N`, N outside [1, object count] | out-of-range read: SIGBUS or a silent load |
| `root_ref1` (in range), `type_num_1` | load |

Fixed in `occtOcafDeclaredSizesFit`, limits taken from the file's own declared counts. `Count()`
also treated a negative count as "no records" (#3485), which is why the two negative-count files got
through it.

## Document data (after `edata`)

| Case | Result | Bridge |
|---|---|---|
| `toc_512` | `ReadTOC` writes `aBuf[512]`: abort | refused (the reader's own 512) |
| `toc_513`, `p_len_*`, `p_type_*`, `p_id_huge`, `d_intpackedmap_big`, `d_intlist_big`, NamedShape counts | status failure or ok, no fault | nothing to do |
| `d_intarray_1g/8g`, `d_realarray_8g`, `d_bytearray_big` | 1 to 8 GiB requested from a ~400 byte file, status ok | **not mitigated** |
| `d_extstrarray_big`, `d_refarray_big` | 17 GiB / 8 GiB requested, 19 s | **not mitigated** |
| `d_ref_label_2e30` | no result in 60 s | **not mitigated** |
| `deep_1000` / `deep_20000` | loads / SIGSEGV | **not mitigated** |
| `sh_long_token_4k`, `_1m` | SIGTRAP / no result in 60 s | **not mitigated** |

Why not mitigated: the array drivers (1) allocate from two ints inside a payload only each driver
can interpret; (2) the stack depth is a property of the thread, not of the file; (3) the shape
section needs a parser. See `okf/references/known-occt-bugs.md`. A kernel patch needs a decision.
The wasm outcome of these was not run; it is inferred from the sizes requested.
