# #2074: the Surface/Curve3D evaluation surface, measured

One of the two surfaces #707 named as having **no TSan scenario at all**. Ranked first of the two
because a real defect was already known here.

## Why this surface

Carried patch `0031` (#1153) found it: `BSplCLib_Cache` and `BSplSLib_Cache` hold the span they
last built and rebuild it **in place, from a const evaluator**. Two threads evaluating parameters
in different spans make one cache rebuild under the other's feet, and the second thread then reads
polynomial coefficients for a span its parameter is not in. That is **a wrong point, not merely a
sanitiser report**.

It is reachable without any caller sharing a cache deliberately: `GeomAdaptor_Curve` and
`GeomAdaptor_Surface` build one cache per adaptor and hand it to every caller of their const
evaluators.

## The harness

`occt_2074_stress.cpp`, pure C++ so it isolates OCCT rather than the bridge. Six modes:

| Mode | Shape | In the gate |
|---|---|---|
| `curve_independent` | own geometry, own adaptor | yes |
| `surface_independent` | own geometry, own adaptor | yes |
| `curve_shared_geometry` | shared curve, own adaptor per thread | yes |
| `surface_shared_geometry` | shared surface, own adaptor per thread | yes |
| `curve_shared_adaptor` | one adaptor, therefore one cache, for all threads | **no** |
| `surface_shared_adaptor` | one adaptor, therefore one cache, for all threads | **no** |

The `*_shared_geometry` modes are the realistic consumer shape: one `Curve3D` held by a caller and
evaluated from several tasks. The `*_shared_adaptor` modes are `0031`'s own reproduction shape,
adversarial by construction, and excluded from the gate the same way #341's `shared_adaptor_cache`
and the `cross_talk_schema_*` modes are, per `tsan-stress.sh`'s POLICY block.

**The parameters are the design.** Every mode drives threads at parameters in different spans,
staggered by thread index, over a 9-span curve and a 7-by-7-span surface. A harness whose threads
all evaluated one span would find nothing here however many threads it ran, because the cache would
never need rebuilding.

## Result

Against the pinned kernel (`v4.0.0-kernel.1`, which carries `0031`), 8 threads, 40 iterations:

```
curve_independent          exit=0 races=0
surface_independent        exit=0 races=0
curve_shared_geometry      exit=0 races=0
surface_shared_geometry    exit=0 races=0
curve_shared_adaptor       exit=0 races=0
surface_shared_adaptor     exit=0 races=0
```

Named racing globals: **none**. Per the DE segment's lesson, that is the claim, not a report count:
counts are run-unstable, and the same binary and arguments gave `iges_write` 129 reports in one run
and 38 in another. Presence or absence of a named global is binary.

## The harness is clean, not blind, and here is the proof

Injecting a deliberate unsynchronised global into `curve_independent` and rebuilding:

```
exit=134  races=1
WARNING: ThreadSanitizer: data race (pid=32074)
```

So TSan, the thread pool, the instrumented kernel and the suppressions file all work in this setup.

## The limit this method has, stated rather than glossed

**This harness has not been A/B'd against `0031` unpatched, and it cannot be by override-linking.**

The #1022 repro's technique is to compile the unpatched `.cxx` and link it ahead of the archive.
That works there because `0029` touches no header. `0031` **adds `mutable std::recursive_mutex
myMutex` to `BSplCLib_Cache`**, so it changes the class layout, and the rest of the archive is
compiled against the patched header. Linking one object built against a 0031-less header into that
archive is an ODR violation, not an experiment: the two disagree about the size of the object.

The attempt was made and caught by checking whether the override had taken effect, which it had
not. Recorded here because the next person to reach for that technique on a layout-changing patch
should know it does not apply.

**So the supportable claim is "clean on the patched kernel, with the plumbing proven".** The claim
"this harness would have caught `0031`" is not available by this method. If OCCT 8.0.2 absorbs
`0031` upstream, the layout question resolves and a genuine A/B becomes possible; that is worth
checking during the 8.0.2 repatch survey.

## Reproducing

```bash
Scripts/tsan-stress.sh run          # the four gate modes, with everything else
```

Or one mode directly, against the TSan-instrumented kernel:

```bash
INSTALL_DIR="$PWD/Libraries/occt-install-tsan"
libs=$(ls "$INSTALL_DIR"/lib/libTK*.a | xargs -n1 basename | sed 's/^lib//;s/\.a$//;s/^/-l/')
$(xcrun --find clang++) -std=c++17 -fsanitize=thread -g -O1 -w \
  -isysroot "$(xcrun --show-sdk-path)" \
  -I"$INSTALL_DIR/include/opencascade" -L"$INSTALL_DIR/lib" \
  Scripts/repro/2074-adaptor-evaluation/occt_2074_stress.cpp -o /tmp/s2074 \
  $libs -lz -lc++ -framework Foundation
MMGT_OPT=0 TSAN_OPTIONS="halt_on_error=0:exitcode=66:suppressions=$PWD/Scripts/tsan.supp" \
  /tmp/s2074 curve_shared_geometry 8 40
```
