# #3065: does carried patch 0031 protect anything we promise, and what does it cost

Investigation for [#3065](https://github.com/SecondMouseAU/OCCTSwift/issues/3065). Probe code and
transcripts only; no patch was changed. Context: `0031` (#1153) locks the BSpline adaptor cache,
and an upstream maintainer says the cache is unsynchronised by design (one adaptor per thread).

Environment: Apple M4, 10 cores, **load average 90 to 130 throughout** (other agents were running),
so the timings below are comparable to each other (interleaved in one run) and not absolute.

## Files

| File | What it is |
|---|---|
| `adaptor_contract.cpp` | one probe: `race` (value correctness against `Geom_BSplineCurve::D0`) and `perf` (ns per `D0`) |
| `run.sh` | `build` (stock and patched variants), `tsan` (TSan builds of the #2074 harness), `race`, `perf` |
| `measure.py` | driver: one process per run |
| `race-transcript.txt`, `perf-transcript.txt` | the numbers quoted in the issue comment |
| `tsan-2074-transcript.txt` | TSan A/B of the existing #2074 harness |
| `gate-without-0031-transcript.txt` | the whole `tsan-stress.sh` gate with the locking removed |

## Variants

`stock` is `HEAD` of `Libraries/occt-src` (vanilla `V8_0_1`) for `BSplCLib_Cache`, `BSplSLib_Cache`,
`GeomAdaptor_Curve`, `GeomAdaptor_Surface`, compiled with their own headers. `patched` is the same
with `0031` applied (the files are byte-identical to the ones in `Libraries/occt-src`). The probe is
compiled against each variant's headers, so probe and adaptor agree on the class layout: this is a
true A/B, unlike an override-link of one unpatched `.cxx` under patched headers, which
`tsan-stress.sh`'s #2074 comment rules out as an ODR violation.

## Gate with the locking removed (layout-safe)

The gate was also run with the lock removed from the whole kernel's perspective: the four stock
`.cxx` files compiled (TSan) against the **patched** headers, so the class layout is unchanged and
the mutex members are simply never taken, then linked ahead of the TSan kernel archives. In a copy of
`tsan-stress.sh`, the compile line gets `$NEUTRAL/*.o` after `"$src_path"`. Proof it is effective:
the same binary's `curve_shared_adaptor` mode reports 32 races and aborts.
