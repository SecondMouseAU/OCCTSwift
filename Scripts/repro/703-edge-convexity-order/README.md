# #703 — `OCCTEdgeGetConvexity` face1/face2 order dependence

Ground truth for the [automated review of PR #720](https://github.com/SecondMouseAU/OCCTSwift/pull/720)
(the #703 fix). The order-dependence bug itself and the ChFi3d ground-truth scorecard against it
are in the PR's own verification comment; this directory covers the two findings from that review
that needed independent measurement rather than code inspection: finding 2/9 (sliver-face/zero-
centroid instability) and finding 7 (performance).

## Finding 2/9 — sliver-face centroid stability

`repro_sliver.mm` fuses two 20mm boxes overlapping by a deliberately tiny sliver, the textbook way
to make `BRepAlgoAPI` emit a genuine sliver face, and inspects every resulting face under area 1.0
with both the plain `BRepGProp::SurfaceProperties` overload (what `OCCTEdgeGetConvexity` called
before this fix) and the adaptive `Eps` overload (what the new `OCCTFaceGetAreaCentroid` calls).

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/703-edge-convexity-order/repro_sliver.mm -o /tmp/repro_703_sliver
/tmp/repro_703_sliver
```

Recorded output is in `ground-truth-output.txt`. Result: a 0.0005mm overlap produces four sliver
faces of area ~0.01 (not zero, not garbage), and the plain and `Eps=1e-6` overloads agree to
machine precision (0 relative error) on both area and centroid. Shrinking the overlap to 1e-7mm
(at/below `BRepAlgoAPI`'s own fuzzy tolerance) does not produce a *thinner* sliver; it produces
**no sliver at all**: the boxes just fuse into a plain 10-face box. OCCT's own tolerance handling
does not let a genuinely near-zero-area face survive as its own topological face, so the specific
instability the review described (a garbage centroid from an unstable integration) was not
reproduced with a normal boolean operation.

`OCCTFaceGetAreaCentroid` (`OCCTBridge_Properties.mm`) still declines any face under area `1e-9`,
several orders of magnitude below the smallest sliver measured here, added defensively and for
free while restructuring for finding 7's fix below, not because this probe found a live bug.

## Finding 7 — redundant `SurfaceProperties` integration

Before this fix, `OCCTEdgeGetConvexity` called `BRepGProp::SurfaceProperties` on `face1` and
`face2` directly, once per call. `AAG.buildGraph()` calls it once per **adjacent face pair**, so a
face with K neighbors had its own whole-face integration repeated K times building one graph.

Measured with a throwaway Swift Testing fixture (a 300x300x20mm plate with 256 through-holes cut
in a 16x16 grid, yielding 134 faces / 140 adjacent pairs) timing `Shape.buildAAG()` directly, three
runs per configuration, `env -u OCCTSWIFT_LOCAL swift test`:

| configuration | `buildAAG()` wall time |
|---|---|
| pre-#703 (tangent-plane formula, no integration at all) | 15.1 / 16.5 / 15.4 ms |
| #703 as merged (centroid formula, uncached: 280 `SurfaceProperties` calls) | 152 / 114 / 183 ms |
| #703 + this fix (centroid formula, cached: 134 `SurfaceProperties` calls) | 75.0 / 73.8 / 69.3 ms |

280 calls -> 134 calls is a 2.09x reduction; the measured wall-time ratio (~150ms -> ~73ms, 2.06x)
tracks it almost exactly, confirming the redundancy was the dominant cost. The fix: precompute each
face occurrence's area centroid once in `AAG.buildGraph()` (a new `OCCTFaceGetAreaCentroid` bridge
call) and pass it into `OCCTEdgeGetConvexity`, which no longer computes it internally.

The remaining ~4.7x gap versus the pre-#703 baseline (73ms vs 15ms) is not a caching problem: it is
the inherent cost of one real numerical area/centroid integration per face versus a handful of
point derivative evaluations, and is not reducible without changing the classification approach
itself, the same formula-change territory as #723, out of scope here. Swapping to
`ChFi3d::DefineConnectType` (the reviewer's/verification comment's suggestion for #723) would also
remove this overhead as a side effect, since it samples locally rather than integrating a whole
face; worth noting for whoever picks that up, not a reason to do it in this PR.

## Update following #723's fix

#723 replaced the centroid formula with `ChFi3d::DefineConnectType` entirely, which removed the
centroid caching this finding added (there is nothing left to precompute) along with the
`OCCTFaceGetAreaCentroid` bridge call it depended on. Re-measured with the same method, a fresh
throwaway `Shape.buildAAG()` timing fixture, `env -u OCCTSWIFT_BRIDGE_PREBUILT OCCTSWIFT_LOCAL=1
swift test`, three runs per configuration, **built to the same description** (a 300x300x20mm
plate, through-holes on a 16x16 grid, radius 5) but yielding 262 faces / 524 adjacent pairs, not
this finding's 134/140: the exact hole radius and spacing were not recorded above, and this fixture
does not reproduce them. The two are different fixtures at a similar scale, not the same one:

| configuration | `buildAAG()` wall time (262 faces / 524 pairs) |
|---|---|
| #703 + this fix (centroid formula, cached) | 354 / 632 / 833 ms, 469 / 448 / 404 ms (two fresh builds) |
| #723 (`ChFi3d::DefineConnectType`, no caching needed) | 113 / 110 / 112 ms, 185 / 156 / 155 ms (two fresh builds) |

Every #723 run is faster than every cached-centroid run (min 110ms vs min 354ms, over 3x), even
though this fixture is roughly double the face count of the one above, and both configurations show
run-to-run variance consistent with ambient system load rather than the classifier itself: the
gap between configurations is far larger than the gap between runs of the same configuration.
`ChFi3d::DefineConnectType` needs no numerical integration at all (a handful of `D1` derivative
evaluations per edge, the same order of cost as the pre-#703 tangent-plane formula this table's
first row measured at 15ms on the smaller 134-face fixture), so this is the expected outcome, not a
surprise: the caching this finding added existed only to make an expensive formula affordable, and
#723 removed the expense instead.

**A caveat on the absolute numbers**: unlike this finding's own table, these were measured on a
machine also running other work, and a `git stash`/`stash pop` cycle between configurations was
found to leave a stale, un-rebuilt `.o` on one occasion (SwiftPM's incremental build did not notice
the restored source content had changed), caught only because the resulting timing matched the
*other* configuration almost exactly, and fixed by forcing a rebuild (`touch` the changed sources)
before every timed run. Anyone repeating this measurement should force a clean rebuild between
configurations rather than trust an incremental one after restoring stashed changes.
