# OCCTSwift#3019 and #3033: where a SheetMetal bend sits along its seam

Both findings came out of reviewing #2972's fix, and they are one missing quantity. `Builder.build()`
never had a trustworthy answer to "which run of the seam does this bend occupy". It resolved a bend
to one flange *piece* by matching a range on one axis, and for a seam diagonal to a flange's axes
it had no run at all.

| issue | what the builder did | what that did to the shape |
|---|---|---|
| #3019 | read a convex bend's kiss segment off the flange piece its lookup returned, the **first** piece when none matched exactly | the prism came out as long as a sliver of the flange, or in the wrong place, or inside the web where it added nothing |
| #3033 | had no run for a diagonal seam, so the concave selection took the free edge beside the bend, and the convex prism took the whole of the *from* flange's edge | `filletFailed` for a concave bend, and **silently too much material** for a convex one |

## Running it

```bash
swift run Harnesses 2972-sheetmetal-volumes
```

The harness is #2972's, extended (`Scripts/repro/harnesses/SheetMetalVolumes.swift`): eight more
fixtures, a defect model that says which wrong answer a measurement matches, and point probes for
the places a volume tolerance would swallow.

## The defect model

```
misbuilt = ideal - (pi/4) t^2 (L - built)      per convex bend, `built` being the length the prism got
```

It is declared per fixture before the fixture is run, and it is what the `misbuilt` column and the
`MISBUILT` verdict read. On the unfixed builder it names every wrong volume below to the digit,
apart from the fillet run-out the stepped concave bend carries either way (at most 0.08).

## Measured on `main` at 316392ac, `v4.0.0-kernel.3`, before

| fixture | prism got | measured | vs ideal | model misses by |
|---|---|---|---|---|
| `Issue3019.steppedWebZ` | 10 of 45 | 6043.410006 | **-110.033016** | -0.077273 |
| `Issue3019.convexBendDoingTheSplitting` (control) | 25 of 25 | 6100.268252 | 0 | |
| `Issue3019.convexBendSpansSeveralCells` | 5 of 35, at the wrong end | 5427.701101 | **-94.325995** | -0.078215 |
| `Issue3019.convexBendAcrossTheSplitAxis` | 0 of 45, inside the web | 7385.586997 | **-141.375942** | -0.004272 |
| `Issue3033.diagonalSteppedConcave` | | `filletFailed` | | |
| `Issue3033.diagonalSteppedConvexBaseFirst` | 11.31 of 4 | 851.543064 | **+22.976693** | 0 |
| `Issue3033.diagonalSteppedConvexUprightFirst` (control) | 4 of 4 | 828.566371 | 0 | |
| `Issue3033.diagonalWideConvexUprightFirst` | 17.31 of 11.31 | 1136.666789 | **+18.849556** | 0 |

Every bend-material probe the defect moves reads wrongly: `outside` where the prism should be,
`inside` past the bend's own run.

## After

| fixture | measured | vs ideal |
|---|---|---|
| `Issue3019.steppedWebZ` | 6153.364428 | -0.078595 |
| `Issue3019.convexBendDoingTheSplitting` | 6100.268252 | 0.000000 |
| `Issue3019.convexBendSpansSeveralCells` | 5521.948705 | -0.078391 |
| `Issue3019.convexBendAcrossTheSplitAxis` | 7526.937588 | -0.025351 |
| `Issue3033.diagonalSteppedConcave` | 817.931417 | 0.000000 |
| `Issue3033.diagonalSteppedConvexBaseFirst` | 828.566371 | 0.000000 |
| `Issue3033.diagonalSteppedConvexUprightFirst` | 828.566371 | 0.000000 |
| `Issue3033.diagonalWideConvexUprightFirst` | 1117.817233 | 0.000000 |

Every probe reads as the construction says, and the ten pinned fixtures from #2972 are unchanged
to the last digit the harness prints.

The residuals on the three stepped fixtures are the fillet run-out #2972 measured (0.014 to 0.4
there, 0.025 to 0.08 here): OCCT closes the fillet off a little past the step where the seam line
runs on into a flat neighbour. Their size does not depend on this change, since the unfixed
builder misses its own defect model by the same 0.004 to 0.08. The diagonal fixtures show none.

## #3019: three ways a bend lost its run

The web is split wherever another bend covers less of it than it spans. The old lookup then took
the one piece whose range on the seam axis equalled the bend's, and the first piece when none did.

- **Full width** (`steppedWebZ`). `foot` covers y in [10, 35] of the web's [0, 45], so the web is
  cut at 10 and 35. The convex bend to `lip` covers all 45, equals no piece, and fell back to the
  first: y in [0, 10]. That is #3019's own measurement, on the fixture the issue suggested.
- **Several pieces** (`convexBendSpansSeveralCells`). `foot` [10, 35] and `lip` [5, 40] cut the web
  at 5, 10, 35 and 40. The convex bend's run [5, 40] covers three pieces and equals none, so it
  fell back to y in [0, 5], which is **outside its own run**: the prism came out 5 long and
  protruded past `lip`.
- **The other axis** (`convexBendAcrossTheSplitAxis`). A tab on the web's back edge splits the web
  along z. The convex bend runs along y and covers [0, 45], which *every* piece shares, so the old
  lookup matched the first piece of the first row, z in [0, 8], at the far end of the web from the
  bend. The prism was built inside the web body and the Z's convex corner was missing entirely.

The control, `convexBendDoingTheSplitting`, is the bend that does the splitting itself: its range
equals one piece exactly, the old lookup found it, and it is identical before and after.

## #3033: which option, and why

The issue offered two, and recommended refusing by name. **Supporting it turned out to be the
smaller change**, for two reasons that were measured, not argued:

1. Refusing needs the same quantity as supporting. To say a diagonal seam is *stepped* the builder
   must know the run both flanges share, and once it has that run it can use it.
2. The fused solid already splits the chamfer's top edge at the contact boundary, so the extent
   filter #2972 added works on a diagonal seam with no flange split. The harness lists the edges:

   ```
   narrow upright: 3 edge(s) on the chamfer's top line: [0.000000, 3.000000] [3.000000, 7.000000] [7.000000, 11.313708]
   wide upright:   1 edge(s) on the chamfer's top line: [0.000000, 11.313708]
   ```

   The upright covers 3 to 7, and the filter selects the middle edge exactly.

A refusal would also have fixed less. The survey that decided it (a 20 x 20 base with a chamfered
corner, an upright on the 11.31 chamfer edge, thickness 2, radius 1.5, every upright width and both
declaration orders, on the unfixed builder):

| bend | upright | base first | upright first |
|---|---|---|---|
| concave | spans the edge | builds, 968.060617 | builds (a no-op, see below) |
| concave | narrower: centred, flush at either end, or staggered | **`filletFailed`** | no-op |
| concave | wider | builds, correct | no-op |
| convex | spans the edge | builds, correct | builds, correct |
| convex | narrower | **+22.98, prism the whole 11.31** | correct |
| convex | wider | correct | **+18.85, prism the upright's whole edge** |

The convex rows are the part the issue did not know about. A diagonal stepped convex seam never
failed: it built, with the prism cut to the *from* flange's edge whatever the other flange
covered, so the two declaration orders disagreed and one of them was wrong. A refusal for the
concave case alone would have left that silent, and a blanket refusal of any step would have
refused wide uprights that were already correct. Reading the real run fixes every wrong row and
refuses nothing, and adds no `BuildError` case.

(The "upright first" concave column is a no-op because `.auto` reads an upright declared first as
convex: the base sits on its `-normal` side. That is the documented inference, not part of this.)

## What changed

- `build()` resolves each bend to the flanges the caller **declared** and to the run its own
  intersection gives, never to a flange piece. The matched-piece map, `SplitResult.matchedByBend`
  and `recordMatched` are gone, and `splitFlange` names every piece for its cell, none after the
  whole flange.
- The convex kiss segment is cut to that run. An end already inside it is left exactly where it was,
  so a bend that covers the whole edge returns the edge itself.
- Where the seam is not along a profile axis of both flanges, the run is read from the two
  flanges' profile edges that lie on the seam line. A flange with no such edge, or two runs that
  do not overlap, leave the bend unbounded as before, which is what keeps #1565's diagonal fixture
  building exactly as it did.

## Found on the way, left alone: #3045

A stepped concave bend can return a solid with `isValid == false`. It is not this change's, it
predates it, and it is why the first #3019 fixtures were redesigned: the convex bend's union onto
the invalid solid ended 470 to 480 below the closed form and made the convex fix look wrong.
Filed as #3045 with the measurements, which are identical on the unfixed and the fixed builder.

| construction | `isValid` | volume against the closed form |
|---|---|---|
| foot under a wider web, thickness 2, web 20 high, r = 0.5 to 1.9 | true | the fillet run-out under it |
| the same, r = 2.0 / 2.5 / 3.0 | **false** | -0.143 / **+7.673** / **+16.164** |
| `SheetMetalTests.zBracket`'s `mid` to `top`, alone, r = 1.5 / 3.0 | true / **false** | -0.041 / **+26.086** |
| a top flange running into the web, top narrower, every r from 0.5 to 4 | **false** | exact |
| a 20-wide base butting an 80-wide tab, r = 1.5, both orders | **false** | exact |

So the invalid flag is not the whole of it: once the radius passes the thickness on the first two
shapes the volume is wrong too. All four pinned stepped fixtures have `r < t` and have the wider
flange doing the butting, so none of them probes it. The cause is not established.

## Prove the test fails

`swift test --filter 'OCCTMiscTests\.(Issue3019ConvexBendOnSplitFlangeTests|Issue2972DiagonalSteppedSeamTests)'`,
nine tests: T1 to T4 are #3019's, T5 to T9 are #3033's.

| T | test | what it asserts |
|---|---|---|
| T1 | `fullWidthBendOnASplitFlange` | the full-width convex bend on a split web is built full length |
| T2 | `convexBendDoingTheSplitting` | control: the bend that splits the web builds over exactly its own run |
| T3 | `convexBendSpansSeveralPieces` | a run spanning several pieces is built over its run |
| T4 | `convexBendAcrossTheSplitAxis` | a web split along its other axis still gets its prism |
| T5 | `controlBuilds` | control: the upright spanning the whole chamfer edge, pinned |
| T6 | `steppedBuilds` | the narrow diagonal upright builds, to its closed form, with the free corner sharp |
| T7 | `wideUprightIsUnchanged` | control: the wide concave upright, pinned to its pre-change measurement |
| T8 | `convexSteppedIsTheSameEitherWay` | the narrow convex upright, both declaration orders |
| T9 | `convexWideStopsAtTheBase` | the wide convex upright, both declaration orders |

**The unfixed builder** (`SheetMetal.swift` from the commit before the fix): **6 of 9 fail, 20 issues**.
Red: T1, T3, T4, T6, T8, T9. Green, as designed: T2, T5, T7.

**Injections** into the fixed builder, one runtime switch each in a temporary copy of
`SheetMetal.swift` (restored with `git checkout`), one build serving every switch. The no-switch run
is fully green, and the switch set was asserted against the test set both ways.

| test | none | I1 | I2 | I3 | I5a | I5b | I10 |
|---|---|---|---|---|---|---|---|
| T1 | ok | ok | ok | ok | ok | ok | **RED** |
| T2 | ok | **RED** | ok | ok | **RED** | **RED** | **RED** |
| T3 | ok | **RED** | ok | ok | **RED** | **RED** | **RED** |
| T4 | ok | ok | ok | ok | ok | ok | **RED** |
| T5 | ok | ok | ok | **RED** | ok | ok | ok |
| T6 | ok | ok | **RED** | **RED** | ok | ok | ok |
| T7 | ok | ok | ok | **RED** | ok | ok | ok |
| T8 | ok | **RED** | **RED** | **RED** | **RED** | **RED** | ok |
| T9 | ok | **RED** | **RED** | **RED** | **RED** | **RED** | ok |

- **I1**: the convex prism is not cut to the extent. Reddens T2, T3, T8 and T9, the four where the
  *from* flange's edge is longer than the run, and nothing where it is not (T1, T4, and the
  concave tests).
- **I2**: a diagonal seam gets no extent. Reddens T6, the concave case that threw, and the two
  convex ones, and nothing else, so T6 and T2/T3 are disjoint on I1 and I2.
- **I3**: the diagonal extent is 0.5 short. The only switch that reddens the two controls T5 and
  T7, which is what says the run has to be exactly right for the whole-edge cases too.
- **I5a, I5b**: only one end of the prism is cut. Each reddens the same four as I1, so each end of
  the cut is exercised on its own.
- **I10**: the convex bend reads the web's first piece again, which is the #3019 defect put back
  into the fixed code. Reddens T1 and T4, which no other switch does, and leaves every diagonal
  test green, so the piece lookup and the diagonal run are independent.

T1 and T4 are red only under I10 and on the unfixed builder; they pin the defect itself, where the
others pin the cut that replaced it.
