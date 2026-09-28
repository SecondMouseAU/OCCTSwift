# #2763: which branch `Standard_ErrorHandler::Abort` takes in the pinned kernel

`Standard_ErrorHandler.hxx` declares `Abort` as a template with two bodies, chosen by
`OCC_CONVERT_SIGNALS` **in the translation unit that instantiates it**:

```cpp
template <typename T>
void Standard_ErrorHandler::Abort(const T& theError)
{
#ifndef OCC_CONVERT_SIGNALS
  throw theError;
#else
  Standard_ErrorHandler* anActive = FindHandler();
  if (anActive == nullptr) { std::cerr << "*** Abort *** ..."; exit(1); }
  anActive->myCaughtError = theError;
  longjmp(anActive->myLabel, true);
#endif
}
```

#2750 wrote down the `throw` branch ("a plain `throw` with `OCC_CONVERT_SIGNALS` undefined").
#2188 and #2191 had already established the opposite, and both readings were on `main` at once,
which is what #2763 is. Reading the sources decides which prose matches the **files**. It does not
decide what the **shipped binary** does, and the binary is what a consumer runs, so this directory
asks the pinned asset.

Run it from the repository root, after one `swift build` has resolved the pin:

```bash
Scripts/repro/2763-abort-signal-mechanism/run.sh
```

## What it measures, two independent ways

**Part 1 reads the shipped archive.** `OSD/OSD_signal.cxx` is the only translation unit in OCCT
that instantiates the template, so it alone chooses the branch, and what its object file
references settles which body was compiled. Against `v4.0.0-kernel.2`'s `libOCCT-macos.a`:

| evidence | found | means |
|---|---|---|
| `strings`: `*** Abort *** an exception was raised, but no catch was found.` | present | the `#else` body, which is the only place that string exists |
| `nm -u`: `Standard_ErrorHandler::FindHandler()` | present | same |
| `nm -u`: `_longjmp` | present | same |

**Part 2 runs the installed handler.** No OCCT geometry is involved: the question is only what
OCCT's `SegvHandler` does, so the probe raises an ordinary `SIGSEGV` by reading through a null
pointer. One process per case, because two of them are expected to end the process. Measured
2026-09-28 on macOS arm64 against the same pinned slice:

| case | `OSD::SetSignal` | handler registered | result | exit |
|---|---|---|---|---|
| `bare-segv` | no | no | dies at the default disposition | 139 |
| `no-handler` | yes | no | `*** Abort *** ... no catch was found.` then `exit(1)`, and the plain `catch (Standard_Failure const&)` never runs | 1 |
| `with-handler`, TU without the define | yes | no, `OCC_CATCH_SIGNALS` expanded to nothing | SKIPPED, so the case cannot pass falsely | 3 |
| `with-handler`, TU with the define | yes | yes | `caught a Standard_Failure: SIGSEGV 'segmentation violation' detected. Address 0.` | 0 |

`no-handler` is the discriminating case. A plain `throw` would have reached that `catch`, or hit
`std::terminate`; instead the process printed the `#else` body's own message and exited 1. **So
`Abort` takes the `longjmp` branch, and "a plain `throw` with `OCC_CONVERT_SIGNALS` undefined"
describes a configuration this repo does not build.**

The probe fails rather than reporting clean if the null read ever returns, on
`okf/policies/static-gates.md`'s rule about a detector whose own view is implausible, and `run.sh`
checks each exit code against the expected one rather than leaving it to be eyeballed.

## What this settles about #2750, which was right

#2750's observation, that the same fault kills one process and comes back as a caught
`Standard_Failure` in another depending on nothing the caller controls, is reproduced by
`Scripts/repro/2750-analyzer-incontext-guard/` and holds. The `longjmp` branch explains it without
needing a `throw`, and the third row above is the missing step: `BRepCheck_Analyzer.cxx` wraps every
`InContext` call in `try { OCC_CATCH_SIGNALS ... } catch (Standard_Failure const&)`, it is an OCCT
translation unit so the macro is live there, and that handler is what `FindHandler()` finds. #2750's
prose also said "`Perform()`'s `OCC_CATCH_SIGNALS` is inert here either way and absorbs nothing",
which is the same mistake twice: it is the one thing that makes the analyzer survive. Both
sentences are corrected in `OCCTBridge_Internal.h` and in that directory's README.

The conclusion is unchanged, and #2750's guard is unaffected: guard the fault, never rely on either
outcome.

## Why the bridge is in the `no-handler` row

SwiftPM defines nothing for `Sources/OCCTBridge/src/*.mm`, so an `OCC_CATCH_SIGNALS` written in
bridge code expands to nothing and registers no handler. A fault in an OCCT frame with no OCCT site
above it therefore takes row two: `FindHandler()` returns null, OCCT prints, and the process exits 1.
Row three is the bridge's own state, measured rather than asserted, which is why it is in the table
instead of only in the prose.

## Related

#2750 (the observation and the guard), #2746 (the defect), #2188 and #2191 (the define and the
template, established first), #345 (a C++ exception reaching the Swift boundary is uncatchable too).
