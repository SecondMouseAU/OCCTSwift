# #1403: `IFSelect_WorkSession`'s `errhand` global, and its relocation

The first bucket-(b) target from
[`../1157-interface-static-thread-safety/gate-baseline-1403/`](../1157-interface-static-thread-safety/gate-baseline-1403/),
carried as `Scripts/patches/0036-IFSelect_WorkSession-per-instance-error-guard-1403.patch`.

## The mechanism is worse than a data race

`errhand` is not a value, it is a **recursion sentinel**. Every one of the nine guarded blocks has
this shape:

```cpp
if (errhand)
{
  errhand = false;                 // mark the frame active
  try { OCC_CATCH_SIGNALS  iter = EvalSelection(sel); }   // call ITSELF
  catch (Standard_Failure const& e) { report }
  errhand = theerrhand;            // restore
  return iter;
}
// ... the real work, reached only through that recursive call
```

The flag exists so the function wraps itself in a `try` exactly once. With two threads:

- thread A sees `errhand == true`, clears it, recurses into the guarded path;
- thread B sees `errhand == false` and takes the **unguarded** path.

So **one thread silently loses its exception handling because another cleared the sentinel.** That
is a lost-protection bug, not only a torn flag, and it is why this site dominated the baseline.

## The fix

The global was a pure mirror of the existing per-instance `theerrhand`, written only as
`theerrhand = errhand = ...`. It is deleted, and a per-instance `mutable bool myInErrorHandler`
takes over the sentinel role:

```cpp
if (theerrhand && !myInErrorHandler)
{
  myInErrorHandler = true;
  ...
  myInErrorHandler = false;
}
```

Semantically identical single-threaded, and per-instance under concurrency. **No lock**, which is
this project's own precedent: #363 moved `theAutoNaming` onto `XCAFDoc_ShapeTool` after upstream
rejected the mutex framing, and #361 moved `TNaming_Scope` onto `OCCTDocument`.
`docs/thread-safety.md` states the rule: "when it was wrongly made global/shared in the first place,
the fix is relocating ownership to whatever object actually owns the data, not locking access to the
wrong owner."

Nine blocks, in `EvalSelection`, `EvaluateComplete`, `EvaluateDispatch`, `EvaluateFile`,
`EvaluateSelection`, `SendAll`, `SendSelected` and `SendSplit`.

## Verification, by override-link

The patched translation unit compiled with TSan and linked ahead of
`Libraries/occt-install-tsan`'s archive, then the `1157` harness re-run:

| | baseline | with `0036` |
|---|---|---|
| `step_read_independent` races | 4 | **3** |
| `iges_read_independent` races | 15 | **11** |
| `IFSelect_WorkSession.cxx:86` as a race **access site** | **6** | **0** |

The last row is the result. The remaining `IFSelect_WorkSession` strings in the patched logs are
*caller* frames, which every data-exchange operation has; zero access sites means the race is gone
rather than moved. The residual races are other bucket-(b) state: the shared
`STEPControl_ActorWrite`, `Interface_Protocol::theactive()`, and `Interface_Static`'s values.

## Live upstream

Not only in our pin. Current `Open-Cascade-SAS/OCCT` master still declares
`static bool errhand;` at `IFSelect_WorkSession.cxx:78` with 36 references, so this is worth
upstreaming rather than only carrying.

## Deliberately NOT included: `bufstr`

The other file-scope global on the same line:

```cpp
static TCollection_AsciiString bufstr;
```

It is filled and then returned as `bufstr.ToCString()`, so two concurrent callers receive pointers
into **one shared buffer**. Relocating it does not fix that: the defect is in a signature that hands
out a pointer to shared state, so it needs an API decision rather than a field move. Filed
separately rather than bundled into a mechanical relocation.
