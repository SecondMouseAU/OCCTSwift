# #1403 Phase 1: the DE gate baseline, and every surviving race classified

> **Superseded in part by [`rescope-2026-09-20.md`](rescope-2026-09-20.md).** The logs in this
> directory are truncated at 200 KB each, so the classification below rests on 64 of 242 reports.
> Re-derived from untruncated logs, `Interface_Protocol::theactive()` has **zero** measured support
> and is removed from bucket (b); `NM_DETECTED`, the `static int` sentinel family and three shared
> `DataMap` registries are added. The rest of bucket (b) below is confirmed. Read that file first.

Measured 2026-09-20 against the pinned kernel plus all carried patches (so `0033` is in), on the
ThreadSanitizer build in `Libraries/occt-install-tsan`, by `Scripts/tsan-stress.sh run` with the five
independent `1157` scenarios newly registered in `SCENARIOS`.

**These five scenarios fail. That is the point of this directory.** The DE path had never been in the
gate, so nothing was measuring it. Registering it produced this baseline, and nothing here has been
suppressed.

## Result

```
>>> TSan gate: 19/24 scenarios clean
```

| Scenario | Race warnings |
|---|---|
| `step_write_independent 8 20` | 44 |
| `step_read_independent 8 20` | **4** |
| `iges_write_independent 8 20` | **129** |
| `iges_read_independent 8 20` | **16** |
| `mixed_step_iges_independent 8 20` | 49 |

Two of those five have never been measured before. #1157's table recorded only the two write
scenarios and the warm-start wrapper, so the read paths are new data, and they are not clean.

The `iges_write` figure is **129 against the 72 that #1157 recorded after `0033`**. The two runs are
not directly comparable (different TSan build, and a race count is a report count rather than a
defect count), but it is not the reduction the earlier figure would suggest and should not be quoted
as one.

## The access sites, ranked

Frame #0 of every race access across all five logs, so these are where the racing read or write
happens rather than who called it:

| Count | Site | What it is |
|---|---|---|
| **26** | `IFSelect_WorkSession.cxx:86` | `theerrhand = errhand = true;` in the constructor |
| 25 | `Standard_Handle.hxx:377` | handle refcount traffic on shared objects (symptom) |
| 17 | `TCollection_AsciiString.cxx:769` | string mutation inside a shared map (symptom) |
| 15 | `NCollection_DataMap.hxx:810` | map mutation (symptom) |
| **10** | `STEPControl_ActorWrite.cxx:473` | `SetGroupMode`, `mygroup = mode;` on the shared actor |
| 10 | `MoniTool_TypedValue.cxx:1059` | `theival = ival;`, an `Interface_Static` value |
| 9 | `MoniTool_TypedValue.cxx:1036` | `return theival;`, the matching read |
| 1 | `IGESToBRep_Actor.cxx:97` | `theeps = ...GlobalSection().Resolution();` in `SetModel` |
| 1 | `STEPControl_Controller.cxx:497` | the `inic` one-time flag |
| 1 | `XSAlgo.cxx:30` | the `XSAlgo` one-time flag |

**The single most frequent site is the `errhand` global.** That matters beyond the count: a
correction posted on #1403 on 2026-09-19 claimed `theerrhand` was an instance field and that the
issue's `errhand` bullet should be dropped. The instance field exists, but so does the file-scope
`static bool errhand` at `IFSelect_WorkSession.cxx:76` that it is mirrored into, and it is the
busiest racing site in the whole data-exchange path. The bullet was right and the correction was
wrong; both are now corrected on the issue.

## The three-way classification

### (b) Per-process singletons carrying per-operation state, the only real targets

| State | Site | Written per operation by |
|---|---|---|
| `errhand`, `bufstr` | `IFSelect_WorkSession.cxx:76` | every WorkSession construction (`:86`) and `SetErrorHandle` (`:98`), copied back at ~10 sites |
| `STEPControl_ActorWrite::mygroup` | `STEPControl_ActorWrite.cxx:473` | `SetGroupMode`, called immediately before every transfer (`STEPControl_Controller.cxx:469`) |
| `STEPControl_ActorWrite::myContext` | `STEPControl_ActorWrite.cxx:619-622`, `:658` | `Transfer()` itself |
| `IGESToBRep_Actor::themodel`, `theeps` | `IGESToBRep_Actor.cxx:94-97`, `:189` | every IGES read; the actor is stored on the controller (`IGESControl_Controller.cxx:145`) so it is shared, unlike STEP's per-session read actor |
| `Interface_Protocol::theactive()` | `Interface_Protocol.cxx:39-42` | `IFSelect_WorkSession::SetProtocol` (`:106`), i.e. every reader/writer construction; outside `XSControl_WorkSession`'s own `GetGlobalMutex()` |
| `Interface_Static` values | `MoniTool_TypedValue.cxx:1036`, `:1059` | `0033` closed the container's memory safety and deliberately not the configure-then-run window |
| `myAdaptorSession` items | `XSControl_Controller.cxx:403` | handed to every WorkSession **by handle, not copied** |

### (a) One-time-init, benign after a serialized warm-up

`STEPControl_Controller.cxx:497` (`inic`, unguarded, where the constructor at `:61-63` has its own
mutex), `XSAlgo.cxx:30`, `IGESControl_Controller`'s constructor flag (`:76-82`, **no mutex at all**
unlike STEP's), `Interface_StaticStandards.cxx:20`'s `THE_Interface_Static_deja`,
`IGESToBRep::theContainer`, `ShapeProcess::aMapOfOperators`, `Interface_InterfaceModel.cxx:44`'s
template map.

These are why the `step_write_warmstart` wrapper exists: it forces the warm-up single-threaded
in-process so these stop reporting and only bucket (b) remains.

### (c) Genuine per-instance state, safe unless the instance is shared

`IFSelect_WorkSession`/`XSControl_WorkSession` members including `theerrhand` itself,
`XSControl_TransferReader::myActor` and the `STEPControl_ActorRead` it caches, each
`Transfer_FinderProcess`/`TransientProcess`, each model. The bridge already constructs a fresh
reader/writer per call at all 40 DE entry points, so bucket (c) is not the lever.

The `TCollection_AsciiString`, `Standard_Handle` and `NCollection_DataMap` sites in the ranking above
are **symptoms of bucket (b)**, not separate defects: they are the strings, refcounts and map nodes
inside the shared objects listed there.

## Verdict for #1403

**Bucket (b) is not empty, so the gate in the plan is not met and the restructure is warranted.**
#1403's verdict stands: not fixable by an accessor lock.

Its scope was too narrow in two places, both now confirmed by measurement rather than inspection:
`Interface_Protocol::theactive()` is absent from its list, and the IGES read actor is shared where
STEP's is not, which the issue anticipated by noting it traced write paths only.

Cheapest first target: **`errhand`/`bufstr`**. They are pure mirrors of an existing instance field,
which makes deleting them the #363 pattern almost exactly, and they are the busiest racing site
measured.

## Reproducing

```bash
Scripts/tsan-stress.sh build     # once, if Libraries/occt-install-tsan is absent
Scripts/tsan-stress.sh run       # the five 1157 scenarios are registered in SCENARIOS
```

Expect `19/24 scenarios clean` until the restructure lands. Do **not** add a `Scripts/tsan.supp`
entry to make these green: that file's policy requires a reason, an issue link and a removal
condition per entry, and suppressing a scenario registered specifically to stop the DE path being
unmeasured would defeat the registration.

The two `cross_talk_schema_*` modes are deliberately **not** registered. They set the same
`Interface_Static` key from every thread and cross-talk 16000/16000 by construction, with and
without an accessor lock, which is the measurement that proved a locked accessor cannot fix that
shape. Expected to race, so they gate nothing, exactly like #341's `shared_adaptor_cache`.
