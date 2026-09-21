# #1161: can a shared helper classify an exception a `catch (...)` already holds?

`probe.mm` answers the one mechanical question the bridge's diagnostics channel rests on: called
from inside an existing `catch (...)` block, can a helper find out *what* was thrown without the
catch block being restructured into a typed catch ladder? If yes, instrumenting a catch site costs
one line; if no, it costs a rewrite of all 3,652 of them.

## Build and run

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/1161/probe.mm -o /tmp/occt_probe_1161
/tmp/occt_probe_1161
```

## What it measured, against the pinned kernel (OCCT 8.0.1, 2026-09-21)

```
1. Standard_ConstructionError thrown by hand
  [case1] Standard_Failure type=Standard_ConstructionError what="hand-thrown construction error" stackLen=0
2. real OCCT throw: gp_Dir from a zero vector
  [case2] Standard_Failure type=Standard_ConstructionError what="gp_Dir() - input vector has zero norm" stackLen=0
3. std::runtime_error
  [case3] std::exception what="plain std error"
4. non-exception type (int)
  [case4] unknown exception
5. nested: helper called from an INNER catch, outer still rethrows fine
  [case5-inner] Standard_Failure type=Standard_OutOfRange what="inner" stackLen=0
  [case5-outer] Standard_Failure type=Standard_OutOfRange what="inner" stackLen=0
6. with stack traces requested
  [case6] Standard_Failure type=Standard_NullObject what="with trace" stackLen=358
7. OCCT throw from deeper in the kernel: MakeEdge on identical points
  [case7] Standard_Failure type=StdFail_NotDone what="BRep_API: command not done" stackLen=0
8. the guard: helper called with NO exception in flight
  [case8] guard fired: no exception in flight, returning safely
```

Seven findings, all of which the shipped `occtRecordCaughtException` depends on:

1. **A bare `throw;` inside a helper called from a `catch (...)` block rethrows the exception the
   caller holds**, so it can be caught again by type. That is the whole mechanism.
2. `Standard_Failure::ExceptionType()` reports the real **subclass** name, not
   `"Standard_Failure"`, so the record names the OCCT exception that was actually raised.
3. `what()` carries OCCT's own message, including from deep kernel calls (case 7).
4. A `std::exception` that is not a `Standard_Failure` is distinguishable (case 3), and so is a
   thrown non-exception type (case 4). Since OCCT 8.0.1's `Standard_Failure` derives from
   `std::exception`, the `Standard_Failure` clause has to come **first** or every OCCT failure is
   misclassified as a plain `std::exception` and loses its type name.
5. Classifying from an **inner** catch does not consume the exception: the outer `throw;` still
   delivers the same one (case 5). A nested instrumented site cannot break an enclosing handler.
6. Stack traces are available, but only when `Standard_Failure::SetDefaultStackTraceLength` is
   non-zero (case 6, 358 characters at depth 8; zero everywhere else). That is what
   `OCCTDiagnostics.stackTraceDepth` sets, and why it defaults to off.
7. A bare `throw;` with **no exception in flight** calls `std::terminate`, so the shipped helper
   checks `std::current_exception()` first. Case 8 calls the guarded form from outside any catch
   block: it returns, and the process survives to print `done`. The guard is a backstop against a
   misplaced call, not a licence to make one.

## What this says nothing about

OS signals. `OCC_CONVERT_SIGNALS` is undefined in this build, so a `SIGSEGV`/`SIGBUS`/`SIGFPE`
raised inside OCCT is not an exception, reaches no `catch` clause, and nothing here can see it.
