# OCCTSwift#341 reproducer — `XCAFDoc_ShapeTool::theAutoNaming` global race

Minimal artifact backing the characterization of the long-standing, never-filed "pre-existing
non-deterministic NCollection arm64 race under parallel execution" claim (`CLAUDE.md`'s Known OCCT
Bugs, `docs/CHANGELOG.md`, and OCCTReconstruct's `okf/references/ecosystem-dependencies.md:37`
`swift test --no-parallel` guidance).

## Verdict

**Not NCollection, and not what was claimed** — but a real, previously-undetected race exists
nearby, in XCAF. Applying the #298 TSan protocol (minimal-module ThreadSanitizer build of
V8_0_0_p1 + all 10 carried patches, `FoundationClasses`+`ModelingData`+`ModelingAlgorithms`+
`DataExchange`) against several stress scenarios:

| Scenario | Threads × iters | Result |
|---|---|---|
| `create_fillet_boolean` (fuse+fillet, the #298 shape) | 8×30 | Clean except the already-known, benign `BOPAlgo_InitMessages` lazy-init race |
| `mesh_independent` (independent `BRepMesh_IncrementalMesh`) | 8×30 | Clean |
| `obj_roundtrip_unique` (concurrent OBJ write+read, **each thread its own uniquely-named file**) | 8×25 | **9 races**, 10×200 → **17 races**, all resolving to one root cause |

Every non-cosmetic race is the same one: `RWMesh_CafReader::fillDocument()` (the shared base class
of `RWObj_CafReader` and `RWGltf_CafReader` — so this reaches OBJ **and** glTF import) does

```cpp
const bool wasAutoNaming = XCAFDoc_ShapeTool::AutoNaming();  // read
XCAFDoc_ShapeTool::SetAutoNaming(false);                     // write
...                                                          // build the document tree;
                                                               // XCAFDoc_ShapeTool::AddShape reads
                                                               // theAutoNaming internally
XCAFDoc_ShapeTool::SetAutoNaming(wasAutoNaming);              // restore
```

against `XCAFDoc_ShapeTool::theAutoNaming` — a plain `static bool` at namespace scope in
`XCAFDoc_ShapeTool.cxx`, process-global, with **zero synchronization**. Any two threads concurrently
importing/exporting OBJ, glTF, or PLY (PLY export calls `AddShape` directly) race on it: one
thread's restore can stomp another's in-flight `SetAutoNaming(false)`, so a concurrent import can
silently pick up the wrong auto-naming mode mid-build — same failure class as
[[issue-298-fillet-blendfunc-statics]] (a save/modify/restore dance on unsynchronized global state),
just cosmetic (default names) rather than geometric (wrong volume) in its direct effect.

The remaining races are `Message_PrinterOStream`/`std::cout` — OCCT's default console messenger
writes progress text from multiple threads with no locking. Real per TSan, but cosmetic (interleaved
console output), not memory-corrupting; not fixed here.

This also is not obviously the mechanism behind the empirical SIGSEGV/SIGABRT seen in ~2/20 full
`swift test` parallel runs during this investigation (garbage-looking fault addresses, one
"File was not written with this version of the topology" BinTools message) — those remain
uncharacterized; the working theory is unrelated fixed-temp-file-path collisions between concurrently
running tests (several `.brep`/`.stp` fixtures across `Tests/` share literal names), not a kernel
memory-safety bug. Not pursued further here; flagged for a follow-up test-isolation audit.

## Repro

```
occt_341_stress obj_roundtrip_unique <threads> <iterations> <tmpDir>
```

Each thread builds a box, meshes it, writes it to `<tmpDir>/occt341_obj_<thread>_<iter>.obj` via
`RWObj_CafWriter`, then reads it back via `RWObj_CafReader` into a fresh `TDocStd_Document` —
deliberately **not** a file-path collision (every thread uses its own file), to isolate OCCT's own
internal state from test-harness file races.

Build (minimal-module TSan OCCT, matching the #298/#319 methodology — see
`docs/CHANGELOG.md`/memory for the full cmake invocation): `FoundationClasses`+`ModelingData`+
`ModelingAlgorithms`+`DataExchange`, `RelWithDebInfo`, `-fsanitize=thread -g`, against a throwaway
install prefix (not the shipped xcframework tree). Then:

```bash
clang++ -std=c++17 -fsanitize=thread -g -O1 \
  -I<tsan-install>/include/opencascade -L<tsan-install>/lib \
  occt_341_stress.cpp -o occt_341_stress \
  $(ls <tsan-install>/lib/libTK*.a | xargs -n1 basename | sed 's/^lib//;s/\.a$//;s/^/-l/') \
  -lz -lc++ -framework Foundation

MMGT_OPT=0 TSAN_OPTIONS="halt_on_error=0" \
  ./occt_341_stress obj_roundtrip_unique 8 25 /tmp/occt341_scratch
```

## Fix

Immediate mitigation (this repo, no kernel patch needed): the bridge now serializes every
OBJ/glTF/PLY CAF-reader/writer bridge function on a dedicated `meshCafMutex()`
(`OCCTBridge_IO.mm`) — matches the #298 PR1 pattern (bridge-side lock first, upstream kernel fix as
a follow-up). Not yet filed upstream; the correct kernel-level fix is a mutex around
`RWMesh_CafReader::fillDocument()`'s save/modify/restore window (not `thread_local`, since
`SetAutoNaming`/`AutoNaming` are public API meant to express one process-wide setting — thread-local
storage would silently change that semantic for direct callers).

## Corrected doctrine

The downstream `swift test --no-parallel` / "NCollection race" claim traces back at least to v0.51.0
(`docs/CHANGELOG.md`) with no reproducer, no issue, and no root cause ever attached. Three suites in
this repo (`Tests/OCCTStressTests/StressConcurrencyTests.swift`) were `.disabled()` for the same
reason with the same lack of evidence; re-enabled during this investigation and ran clean across 25
repeated iterations. See `CLAUDE.md`'s Known OCCT Bugs entry (updated alongside this fix) for the
corrected, narrower hazard surface.
