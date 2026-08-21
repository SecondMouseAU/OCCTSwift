# #726 sub-kind 4: the subject the caller never fed

Pass 4a (#385) confirmed three instances of #726's stated subject, "a value that was never
computed, returned through an API whose shape says it was measured", and reported that
`Scripts/census-unmeasured-values.py` flagged none of them. This directory is the measurement
behind the sub-kind added to close the first of those three, plus the measurement of what the new
shape does and does not reach.

## What the blind spot was

Sub-kinds 1, 2 and 3 all key on an **output**: a literal on the right of an assignment, a pinned
`.count` in a test, a boolean flag that never flips. None asks where the value came **from**. A
function that queries an object it default-constructed itself, and returns what that throwaway
says, passes all three.

Measured, not inherited from the Pass 4a comment. Running every sub-kind against #1000's six
`DraftInfo` members, reconstructed from PR #1002's own diff (`git show 6e66a3d1`):

| instance | sub-kind 1 | sub-kind 3 | sub-kind 4 |
|---|---|---|---|
| #1000 `DraftInfo`, six members | nothing | nothing | **5 of 6** |
| #999 `OCCTGeomPlateErrors` | nothing | nothing | nothing |
| #996 `OCCTDocumentGetDimensionInfo` | `info.isValid = false` | nothing | nothing |

Sub-kind 2 reads `Tests/`, not the bridge, so it has no opinion on any of the three.

## The five of six, and the sixth

Caught, four as unfed subjects and one as an echo:

- `OCCTDraftEdgeInfoNewGeometry(void)` and `OCCTDraftFaceInfoNewGeometry(void)`: no parameters at
  all, `Draft_EdgeInfo ei;`, `return ei.NewGeometry();`.
- `OCCTDraftVertexInfoGeometry(double* x, double* y, double* z)`: out-parameters only, published
  one step removed through `gp_Pnt p = vi.Geometry();`. The intermediate type is lowercase-initial,
  which is why the detector's type test accepts `gp_`-style names and why removing that acceptance
  is a row in the matrix below.
- `OCCTDraftEdgeInfoSetTangent(double dx, double dy, double dz)`: three caller parameters, none of
  which reaches the subject, which is configured with `ei.SetNewGeometry(true)` instead.
- `OCCTDraftVertexInfoAddParameter(double param)`: `return param; // echo back`.

Not caught: `OCCTDraftFaceInfoFromSurface(OCCTSurfaceRef surface)`. It really did build its
`Draft_FaceInfo` from the caller's surface, then checked nothing and returned `true`. In bridge
text that is identical to a setter reporting that it ran, and to an RAII scope guard constructed
for its side effect. Flagging it would report both.

## Why #999 and #996 are not reachable from bridge text

Both were measured against the pre-fix sources (`git show 0dfa6ddd^` and `06c89e07^`), not argued
from the code shape.

**#999 `OCCTGeomPlateErrors`.** Its `GeomPlate_BuildPlateSurface builder(3, 10, 5, tolerance);` was
fed the caller's tolerance, and `builder.Add(pc)` fed it the caller's points, so no rule about
whether the caller's input reaches the subject can call it unfed. What was fabricated sat in the
kernel: `myG0Error`/`myG1Error`/`myG2Error` are written only by `VerifSurface()`, which the
point-only path never runs, and nothing initialises them. The bridge-visible half of that site is
its two unread parameters, and that is already reported by
`Scripts/repro/385-coverage-sample/detect-dead-parameters.py`, re-run here against the pre-fix
file:

```
3 bridge function(s) with an unread parameter

  OCCTBridge_ProjLib_NLPlate.mm:1309  OCCTGeomPlateErrors
      unread: maxDegree, maxSegments   (2 of 8)
```

so the census does not duplicate it. The kernel half needs a pass over `Libraries/occt-src`, which
is what #726's own comment on kernel-side sites proposes.

**#996 the GD&T range dimension.** `OCCTDocumentGetDimensionInfo(doc, index)` took the caller's
document and index, reached the caller's own dimension object, and called three real accessors on
it. Every value came from a genuine computation. What was wrong is that `GetLowerTolValue()`
answers a flat `0` for a range dimension, meaning "not applicable", and the bridge published it as
a tolerance. Nothing in the bridge text says so. Catching that class needs the pinned headers and a
rule about applicability predicates the bridge never consults (`IsDimWithRange`,
`IsDimWithPlusMinusTolerance`), which is a different corpus and a different question. Sub-kind 1
does flag that function, for `info.isValid = false`, which is the "default, then flip on success"
shape the script already documents as the common legitimate case, so that flag was not evidence of
the defect either.

## The real run, and its adjudication

`python3 Scripts/census-unmeasured-values.py --subjects` reports **46 candidates in 18 functions
and 0 echoes** on this tree (`run-subkind4.txt`). All 18 adjudicate to verdict 1, not an instance.
That is not a precision estimate: #1000's members were deleted from this tree the day before, so
there is no live instance of the shape left to find, and 18 is a count of noise on a clean tree.

The adjudication is measured rather than read off the code, because the one thing the detector
cannot see is whether a default constructor populates its object. `probe_default_subjects.mm`
compiles against the pinned kernel and asks each subject directly (`probe-transcript.txt`):

| family | functions | what the probe measured |
|---|---|---|
| process and host queries | `OCCTMemInfoHeapUsage`, `OCCTMemInfoHeapUsageMiB`, `OCCTMemInfoWorkingSet`, `OCCTMemInfoString`, `OCCTProcessId`, `OCCTProcessUserName`, `OCCTProcessExecutablePath`, `OCCTProcessExecutableFolder`, `OCCTHostName`, `OCCTInternetAddress`, `OCCTSystemVersion`, `OCCTDirectoryBuildTemporary` | a fresh `OSD_MemInfo` moved by exactly 67108864 bytes across a 64 MiB allocation, a fresh `OSD_Process` returned the real `getpid()` and `$USER`, a fresh `OSD_Host` returned the real host name and `Darwin 25.6.0`, `BuildTemporary()` returned a real path |
| OCCT's own documented defaults | `OCCTVisMaterialCommonDefault`, `OCCTVisMaterialPBRDefault`, `OCCTXCAFPrsStyleCreate`, `OCCTMat2dIdentity` | diffuse `0.8 0.8 0.8`, matching `XCAFDoc_VisMaterialCommon.hxx`'s own member initialiser; PBR base colour `1 1 1`; `XCAFPrs_Style::IsEmpty()` flips from 1 to 0 when a colour is set, so the default reading is a real state; `gp_Mat2d` after `SetIdentity()` is `1 0 0 1` |
| process-global registries | `OCCTDriverTableExists`, `OCCTTObjApplicationGetInstance` | no measurement needed: both take no parameters and publish the existence of a process-wide singleton, which is what they are for |

For contrast, in the same run, three consecutive fresh `Draft_EdgeInfo`/`Draft_FaceInfo`/
`Draft_VertexInfo` instances answered `false`, `false` and `(0, 0, 0)` every time, and only
`SetNewGeometry(true)` moved the flag.

One contrast worth keeping: `OCCTMat2dIdentity(double* mat)` is a candidate and its sibling
`OCCTMat2dRotation(double angle, double* mat)` is not, because the second passes the caller's angle
into the same subject. That is the detector working, on two functions three lines apart.

Nothing here is worth an issue, so none was filed.

## Removal matrix

Per `okf/policies/prove-the-test-fails.md`. Each guard was removed from a copy of the script, one
at a time, `--self-test` re-run, and the bare `--subjects` run re-measured against the tree.
Baseline: **54/54 cases, 46 candidates in 18 functions, 0 echoes**.

| guard removed | self-test | case it flips | tree |
|---|---|---|---|
| A. publication `new` exclusion | 53/54 | C7 factory, new object built from the local's properties | 46 in 18 |
| B. member-read requirement | 53/54 | C9 the local is the product, handed back whole | 62 in 31 |
| C. catch-block exclusion | 53/54 | C10 the only reading sits inside `catch` | 46 in 18 |
| D. control-dependence taint | 53/54 | C4 subject selected by a caller index | 47 in 19 |
| E. receiver walk across intermediate parens | 52/54 | C3, C5 | 512 in 268 |
| F. call-group taint | 52/54 | C3, C5 | 965 in 377 |
| G. assignment and constructor taint | 53/54 | C6 fed only by an assignment | 1376 in 491 |
| H. subject `new`-initialiser exclusion | 53/54 | C8 fresh Handle handed back | 48 in 20 |
| I. echo: parameter must contribute nothing else | 53/54 | E2 count that also bounds the loop | 46 in 18, **3 echoes** |
| J. lowercase-initial OCCT type names | 53/54 | M2 the `gp_Pnt` out-param case | 42 in 17 |
| K. `Handle(T)` declaration binding | 53/54 | M5 Handle-typed throwaway | 44 in 16 |

Nine of the eleven rows flip exactly one case that no other row flips.

**E and F flip the same pair and are not disjoint, deliberately.** The receiver walk exists to widen
the group the call-group rule builds, so every case E flips, F flips too, and no fixture can
separate them. What separates them is the tree: removing E leaves 512 candidates, removing F leaves
965, against a baseline of 46. Both numbers are the detector going blind in the reporting direction,
which is why neither row is decorative even though they share their fixtures.

**Row A came back green on its first version and was rewritten, not celebrated.** The factory
fixture originally returned `new OCCTSurface(new Geom_Plane(pln));`, which the member-read guard (B)
already kept clean on its own, so removing A changed nothing on the self-test or on the tree. The
fixture now reads `axis.Location()` and `axis.Direction()` inside the `new` expression, which
satisfies B and leaves A as the only guard holding it. That is the "something else is standing in
front of it" case the policy names, caught by running the matrix rather than by reading it.

Rows A, C and I do not move the tree count, and that is a fact about this tree rather than about
the guards: there is no live site here that constructs a new object out of an unfed local's
properties, none that reads an unfed local only inside `catch`, and the three real returned-count
functions are the ones row I keeps out. Each of the three flips its own fixture, so each is proven
by the self-test rather than by the corpus.

## Files

- `probe_default_subjects.mm`, `probe-transcript.txt`: what a default-constructed subject reports,
  for every family the run flags, and for the `Draft_*` classes for contrast. Build line is in the
  file's own header comment.
- `run-subkind4.txt`: the full `--subjects` run this README adjudicates.
