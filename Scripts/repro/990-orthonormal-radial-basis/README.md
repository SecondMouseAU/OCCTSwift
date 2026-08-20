# #990: the thread datum against the shared `perpendicularBasis(to:)`

`ThreadFeatures.swift` carried its own perpendicular-to-an-axis construction,
`orthonormalRadial(axis:)`, alongside the module-wide `perpendicularBasis(to:)` that #881
introduced and whose own doc comment already claimed to be "shared by every OCCTSwift site that
needs a stable basis perpendicular to one direction". #990 asks for the two to converge.

They are not interchangeable as written. `orthonormalRadial` returns one vector,
`perpendicularBasis` returns two, so converging them is a choice of element, and that choice moves
the angle a thread starts at about its own axis. This directory is the measurement that choice was
made on.

## What is here

| file | what it does |
|---|---|
| `gp_ax2_truth.mm` | prints OCCT's own `gp_Ax2(gp_Pnt, gp_Dir)` X and Y directions for nine axes, read from the pinned kernel |
| `basis-compare.swift` | checks a verbatim copy of `perpendicularBasis(to:)` against those numbers, then compares `orthonormalRadial` to each of its two elements |

Both are standalone. The compile lines are in each file's header comment.

## Measured, against `main` at 90917a70

`basis-compare.swift` step 1 confirms the copy of `perpendicularBasis(to:)` reproduces `gp_Ax2`
exactly on all six world axes and to 1.1e-16 on the three oblique ones, so step 2 is comparing
against the real function rather than a drifted copy.

Step 2:

```
+X        orth=(+0.0000,-1.0000,+0.0000) right=(-0.0000,+0.0000,+1.0000) up=(+0.0000,-1.0000,+0.0000)  angle(orth,right)= 90.000  angle(orth,up)=  0.000
-X        orth=(+0.0000,+1.0000,-0.0000) right=(-0.0000,+0.0000,-1.0000) up=(-0.0000,-1.0000,+0.0000)  angle(orth,right)= 90.000  angle(orth,up)=180.000
+Y        orth=(+1.0000,+0.0000,+0.0000) right=(+0.0000,-0.0000,+1.0000) up=(+1.0000,+0.0000,-0.0000)  angle(orth,right)= 90.000  angle(orth,up)=  0.000
-Y        orth=(-1.0000,+0.0000,+0.0000) right=(+0.0000,-0.0000,-1.0000) up=(+1.0000,+0.0000,+0.0000)  angle(orth,right)= 90.000  angle(orth,up)=180.000
+Z        orth=(+0.0000,+1.0000,+0.0000) right=(+1.0000,+0.0000,-0.0000) up=(-0.0000,+1.0000,+0.0000)  angle(orth,right)= 90.000  angle(orth,up)=  0.000
-Z        orth=(+0.0000,-1.0000,+0.0000) right=(-1.0000,+0.0000,-0.0000) up=(+0.0000,+1.0000,+0.0000)  angle(orth,right)= 90.000  angle(orth,up)=180.000
(1,2,3)   angle(orth,right)=111.845  angle(orth,up)=158.155
(1,1,1)   angle(orth,right)= 60.000  angle(orth,up)=150.000
(0,1,1)   angle(orth,right)= 90.000  angle(orth,up)=180.000
```

Step 3, a 200x200 sphere sample: `orth == up` for 540 of 40,000 axes, `orth == right` for 10,068.

## Verdict: the second element

Neither element reproduces `orthonormalRadial` everywhere, so converging the two moves the thread's
start angle about its own axis for most axes. That is a rotation of a thread about its own axis
rather than a wrong thread: both constructions return a unit vector perpendicular to the axis, and
neither is canonical for a helix, which is why no OCCTSwift API has ever specified the clocking.

**The second element (`up`) is the one taken**, because it reproduces the shipped vector exactly on
+Z, +X and +Y, the axes every existing test, doc example and cookbook snippet in this repo uses.
The first element is 90 degrees away on every one of those.

The sphere-sample counts in step 3 are not the criterion and would pick the other one. Agreement on
an arbitrary axis is a coincidence of where the two constructions' branch boundaries fall, not
evidence about the axes callers actually pass.

## What pins it

`Tests/OCCTThreadTests/Issue990ThreadAxisBasisTests.swift` measures the groove's angular position
on a real threaded rod for all six world axes, through `Shape.classifyPoint`, and expects it on the
`gp_Ax2` Y direction (the constants above, not a second call to `perpendicularBasis(to:)`).

Proven against both wrong answers:

| injection | result |
|---|---|
| the pre-#990 `orthonormalRadial` restored | -X, -Y and -Z fail at 178.13 degrees; the three positive axes pass |
| `perpendicularBasis(to: axis).0` taken instead | all six fail at 91.87 degrees |
| the threaded shaft replaced by the plain shank | all six fail: no ring point lands outside the solid, so there is no groove to measure |
| the threaded shaft replaced by an undersized cylinder | all six fail: the groove covers the whole ring rather than an arc |

The last two rows are there because the first two only prove the *guard*, not the fixture: a
fixture that had quietly stopped being a thread would pass every angular assertion by measuring
nothing.
