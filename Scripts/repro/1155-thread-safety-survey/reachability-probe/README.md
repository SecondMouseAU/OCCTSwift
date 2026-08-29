# Reachability probe: is `TopOpeBRepBuild_ffsfs.cxx`/`GridSS.cxx`'s `GLOBAL_*` cluster ever hit?

Single-threaded, not TSan. The three `*_probe.cxx` files are copies of the real OCCT source
(`Libraries/occt-src/src/ModelingAlgorithms/TKBool/TopOpeBRepBuild/TopOpeBRepBuild_{ffsfs,GridSS,KPart}.cxx`)
with one `fprintf(stderr, "[PROBE] ...")` inserted at the top of `GFillFaceSFS()`, `GMergeSolids()`,
`FindIsKPart()` and `KPreturn()` -- the only four functions that read/write the `GLOBAL_*`/`static_*`
cluster documented in the parent README's "Verdict" section. Compiled standalone and linked ahead of
the production `libOCCT-macos.a` (the override-link technique from
`okf/policies/upstream-occt-patch-process.md` #1), so these three `.o` files' definitions win at
link time over the archive's copies, and any call the archive itself makes to one of the four
instrumented functions prints before running the real body.

`fillet_reachability_harness.cpp` drives `BRepFilletAPI_MakeFillet`/`MakeChamfer` through five
geometries chosen to be the most likely to hit OCCT's "SameDomain" face-merge logic: a box with
all 12 edges filleted (the corner case where three fillets converge), a box fused with a sphere
then filleted (matching the existing `341-meshcaf` gate scenario's own geometry), two boxes
sharing an entire coincident face then fused and filleted, a chamfered box, and a filleted
cylinder.

`probe_output.txt`: the captured run. Zero `[PROBE]` lines across all five geometries -- none of
the four instrumented functions were ever called.

```bash
clang++ -std=c++17 -w -O0 -g -I<xcframework>/Headers -c TopOpeBRepBuild_ffsfs_probe.cxx -o ffsfs_probe.o
clang++ -std=c++17 -w -O0 -g -I<xcframework>/Headers -c TopOpeBRepBuild_GridSS_probe.cxx -o gridss_probe.o
clang++ -std=c++17 -w -O0 -g -I<xcframework>/Headers -c TopOpeBRepBuild_KPart_probe.cxx -o kpart_probe.o
clang++ -std=c++17 -w -O0 -g -I<xcframework>/Headers -c fillet_reachability_harness.cpp -o harness.o
clang++ -std=c++17 -w -O0 -g harness.o ffsfs_probe.o gridss_probe.o kpart_probe.o \
  -L<xcframework>/macos-arm64 -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  -o probe_test
./probe_test
```

This is corroborating evidence, not the proof: the proof is the static call-graph argument in the
parent README (`TopOpeBRepBuild_HBuilder::Perform(HDS)`, the only overload `ChFi3d_Builder.cxx`
calls, never reaches `FindIsKPart()`, which only the two-argument `Perform(HDS, S1, S2)` calls,
which nothing in this tree calls). A reachability probe against five geometries is not proof for
every geometry; the call-graph argument is what generalizes.
