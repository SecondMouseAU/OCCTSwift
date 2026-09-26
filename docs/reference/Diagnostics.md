---
title: Bridge Diagnostics
parent: API Reference
---

# Bridge Diagnostics

`OCCTDiagnostics` reads the OCCT exceptions the bridge catches on the way to returning `nil`. Every bridge function wraps its OCCT calls in `try { } catch (...) { return <refusal>; }`, so a failure arrives in Swift as `nil` with the `Standard_Failure`'s own type and message already discarded; [#1161](https://github.com/SecondMouseAU/OCCTSwift/issues/1161) measured 3,652 such handlers and none that catch `Standard_Failure`. Instrumented catch sites hand the type and message to this channel instead. No signature anywhere changed, and a caller who never asks sees no behaviour change.

## Topics

- [OCCTDiagnostics](#occtdiagnostics) · [OCCTDiagnostics.Record](#occtdiagnosticsrecord) · [OCCTDiagnostics.Kind](#occtdiagnosticskind) · [Coverage](#coverage) · [What this cannot report](#what-this-cannot-report)

---

## OCCTDiagnostics

A caseless `enum` namespace. Two switches and one scope: a thread-local **capture** buffer you read from Swift, and a process-wide **logging** switch that sends the same records to OCCT's own default messenger.

### `OCCTDiagnostics.capturing(_:)`

Runs a closure with capture on and returns both its value and the records it produced.

```swift
public static func capturing<T>(
    _ body: () throws -> T
) rethrows -> (value: T, diagnostics: [Record])
```

Captures nest: an inner scope reports only its own records, and the enclosing scope still counts them as part of its own. Capture returns to whatever it was when the scope exits.

`body` is synchronous on purpose. The buffer is thread-local, because an OCCT exception is caught on the thread that made the bridge call, so a scope that could suspend and resume on another thread would collect from the wrong one. A non-`async` closure cannot contain an `await`, which is the point.

- **Parameters:** `body`, the work to watch.
- **Returns:** `body`'s value, and the records instrumented catch sites produced while it ran.
- **OCCT:** `Standard_Failure::ExceptionType()`, `what()` and `GetStackString()`, read by `occtRecordCaughtException` in `OCCTBridge.mm` through a bare `throw;` that reclassifies the in-flight exception.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 10)!
  let (rotated, diagnostics) = OCCTDiagnostics.capturing {
      box.rotatedWithFullHistory(axis: .zero, angle: .pi / 4)
  }
  if rotated == nil {
      for record in diagnostics {
          print(record)
          // OCCTShapeHistoryFromRotate: Standard_ConstructionError: gp_Dir() - input vector has zero norm
      }
  }
  ```
- **Note:** if `body` throws, the records it produced stay in the buffer and are readable through [`records`](#occtdiagnosticsrecords), they are simply not in the tuple that never returned.

---

### `OCCTDiagnostics.records`

Every record the calling thread is currently holding, oldest first.

```swift
public static var records: [Record] { get }
```

- **Example:**
  ```swift
  OCCTDiagnostics.isCaptureEnabled = true
  defer { OCCTDiagnostics.isCaptureEnabled = false }
  _ = Shape.box(width: 1, height: 1, depth: 1)?.rotatedWithFullHistory(axis: .zero, angle: 1)
  print(OCCTDiagnostics.records.map(\.exceptionType))   // ["Standard_ConstructionError"]
  ```

---

### `OCCTDiagnostics.isCaptureEnabled`

Whether the calling thread is collecting records.

```swift
public static var isCaptureEnabled: Bool { get set }
```

Off by default, and thread-local. Prefer [`capturing(_:)`](#occtdiagnosticscapturing_), which sets and restores it around one piece of work; set it directly only when the work you want to watch cannot be wrapped in a closure.

- **Example:**
  ```swift
  OCCTDiagnostics.isCaptureEnabled = true
  defer {
      OCCTDiagnostics.isCaptureEnabled = false
      OCCTDiagnostics.clear()
  }
  ```

---

### `OCCTDiagnostics.isLoggingEnabled`

Whether the bridge is logging every recorded exception, process-wide and for every thread.

```swift
public static var isLoggingEnabled: Bool { get set }
```

Records go to `Message::DefaultMessenger()` at `Message_Alarm` gravity, so they land wherever the host already routes OCCT's own messages (standard output, with OCCT's default printer). Independent of capture: either, both or neither.

Starts on when the environment variable `OCCTSWIFT_BRIDGE_DIAGNOSTICS` is set to anything but empty or `0`, so a process can be made to explain itself with no code change:

```
OCCTSWIFT_BRIDGE_DIAGNOSTICS=1 swift run MyTool
```

- **OCCT:** `Message::DefaultMessenger()->Send(..., Message_Alarm)`.
- **Note:** sending goes through one process-wide messenger, which OCCT does not serialise, so treat this as a debugging switch rather than something to leave on under concurrent load.

---

### `OCCTDiagnostics.stackTraceDepth`

How many frames OCCT captures into every `Standard_Failure` it constructs.

```swift
public static var stackTraceDepth: Int { get set }
```

`0`, OCCT's own default, means no stack trace, and [`Record.stackTrace`](#occtdiagnosticsrecord) is then empty. Capturing frames costs time on the throwing path, and this is process-wide: it affects every OCCT exception, not only the ones this channel records. Raise it only while a trace is actually being read. A negative value is clamped to `0`.

- **OCCT:** `Standard_Failure::SetDefaultStackTraceLength` / `DefaultStackTraceLength`.
- **Example:**
  ```swift
  OCCTDiagnostics.stackTraceDepth = 16
  defer { OCCTDiagnostics.stackTraceDepth = 0 }
  let (_, diagnostics) = OCCTDiagnostics.capturing { suspectOperation() }
  print(diagnostics.first?.stackTrace ?? "no record")
  ```

---

### `OCCTDiagnostics.droppedRecordCount`

How many records the calling thread discarded because its buffer was full.

```swift
public static var droppedRecordCount: Int { get }
```

The buffer holds at most 256 records so that a capture left switched on cannot grow without limit. Anything past that is counted here and not stored. A non-zero value means the capture was too wide, not that anything went wrong.

---

### `OCCTDiagnostics.clear()`

Discards the calling thread's records and its `droppedRecordCount`.

```swift
public static func clear()
```

---

## OCCTDiagnostics.Record

One OCCT exception, as the bridge caught and classified it.

```swift
public struct Record: Sendable, Equatable {
    public let kind: Kind
    public let function: String
    public let exceptionType: String
    public let message: String
    public let stackTrace: String
}
```

| Field | What it holds |
|---|---|
| `kind` | how the exception was classified, see [Kind](#occtdiagnosticskind) |
| `function` | the bridge function that caught it, from `__func__` at the catch site |
| `exceptionType` | `Standard_Failure::ExceptionType()`, the OCCT exception's own class name, e.g. `Standard_ConstructionError`, `StdFail_NotDone`. Empty for the two non-OCCT kinds |
| `message` | `what()`, the message OCCT raised with, e.g. `gp_Dir() - input vector has zero norm`. Empty for `.unknown` |
| `stackTrace` | `Standard_Failure::GetStackString()`, empty unless `stackTraceDepth` is non-zero |

### `OCCTDiagnostics.Record.description`

The function, the OCCT exception class and the message, on one line.

```swift
public var description: String { get }
```

- **Example:**
  ```swift
  print(record)   // OCCTShapeFuse: StdFail_NotDone: BRep_API: command not done
  ```

---

## OCCTDiagnostics.Kind

```swift
public enum Kind: Int32, Sendable, CaseIterable {
    case occtFailure = 0
    case standardException = 1
    case unknown = 2
}
```

- `.occtFailure`: a `Standard_Failure` or any OCCT subclass of it. Both a type name and a message are known. This is what an OCCT failure looks like, and in OCCT 8.0.1 `Standard_Failure` itself derives from `std::exception`, which is why the bridge's catch ladder tests it first.
- `.standardException`: a `std::exception` that is not a `Standard_Failure`. A message is known, the type name is not.
- `.unknown`: something else was thrown, so neither a type name nor a message is available.

---

## Coverage

**Every function-level `catch (...)` block in the bridge records what it caught.** [#2077](https://github.com/SecondMouseAU/OCCTSwift/issues/2077) swept the channel across all 74 `Sources/OCCTBridge/src/*.mm` files, and `Scripts/check-bridge-diagnostics.py` is what keeps it that way: a gate in CI's `gate-scripts` job that fails when a bridge function's outermost catch block does not call `occtRecordCaughtException(__func__);` as its first statement.

Two function-level sites are exempt, both in `OCCTBridge.mm`, both on the gate's own exemption list with a written reason and both inside this channel's own machinery, where a record would feed itself:

- `occtRecordCaughtException` is the classifier. A call inside its own `catch (...)` clause would `throw;` the same exception, land back in the same clause, and recurse until the stack ran out.
- `occtDiagnosticsLog` is that function's tail, reached only while a record is being sent. A diagnostic that throws must not become the failure being diagnosed.

So an empty capture no longer means "the site was never instrumented". It means the failure raised nothing to classify, which is the second of the two cases under [What this cannot report](#what-this-cannot-report): `IsDone() == false`, a null result handle, a rejected argument. The first case, an OS signal, never returns a `nil` to read a capture beside, because it ends the process.

Numbers still come from the source, never from a page:

```bash
python3 Scripts/check-bridge-diagnostics.py          # the verdict, and the counts behind it
python3 Scripts/check-bridge-diagnostics.py --list   # every site, one line each
```

### Deeper catch blocks, and why the gate stops at function level

A `catch (...)` nested inside a loop or an inner `try` is a different question, and the gate deliberately does not answer it. Many of them are ordinary recover-and-continue control flow, where recording would report a failure for a call that went on to succeed:

```cpp
catch (...)
{
  // Deliberately NOT calling occtRecordCaughtException here (#1161). This one recovers: an
  // edge with no 3D curve is skipped and the sampling pass goes on to succeed, so recording
  // it would report a failure for a call that did not fail. The diagnostics channel is for
  // catch blocks that refuse the call.
  continue;
} // no 3D curve on this edge, nothing to sample
```

Others swallow the exception and convert it into a refusal the outermost handler will never see, and those **are** instrumented, because otherwise the reason is lost entirely: `occtFindSurface`'s three inner catches in each `OCCTBridge_Topology_*.mm` file, and `OCCTBSplineApproxInterp::run()` in each `OCCTBridge_Curve3D_*.mm` file. Each carries a note saying why it records despite not being outermost. Of the bridge's 54 deeper blocks, 21 record and 33 say in place why they do not.

Only a function-level block is unambiguously "this call refused", which is measurable rather than assumed: every one of the bridge's function-level `catch (...)` blocks is the only function-level `try`/`catch` in its own function, so none of them is a first attempt with a fallback behind it.

### Adding a bridge file, or a bridge function

The gate reports the site; this writes the call:

```bash
python3 Scripts/add-bridge-diagnostics.py --dry-run Sources/OCCTBridge/src/OCCTBridge_Mesh.mm
python3 Scripts/add-bridge-diagnostics.py Sources/OCCTBridge/src/OCCTBridge_Mesh.mm
Scripts/format-bridge.sh Sources/OCCTBridge/src/OCCTBridge_Mesh.mm
```

It instruments every function-level catch block, reports every deeper one instead of touching it, and is idempotent, so re-running after a merge is safe. A block whose first lines already mention `occtRecordCaughtException` is left alone, which is why an exemption comment is load-bearing and not only documentation: it is what stops the next run reinserting the call.

## What this cannot report

**An OS signal.** `OCC_CATCH_SIGNALS` is inert in bridge code, because SwiftPM compiles `Sources/OCCTBridge/src/*.mm` without `OCC_CONVERT_SIGNALS`, so a `SIGSEGV`, `SIGBUS` or `SIGFPE` raised inside OCCT never becomes a C++ exception a bridge `catch` clause can see, and never appears here. OCCT's own translation units are compiled with the define, which its CMake adds on every non-Windows target, so OCCT's own `OCC_CATCH_SIGNALS` sites do register a handler; nothing the bridge writes can (#2188). Those crashes end the process. The kernel defects behind the cited crashes are recorded one row each in [`okf/references/known-occt-bugs.md`](https://github.com/SecondMouseAU/OCCTSwift/blob/main/okf/references/known-occt-bugs.md).

That is not a gap in this channel so much as the reason it is a smaller thing than #1161's own evidence list suggests. Of the ten defects that issue cites, six (#345, #348, #484, #636, #913, #1022) were uncatchable signals and two (#905, #1018) were silent wrong values with no exception raised at all. A catch-site diagnostic reports neither shape. It reports the third: a real `Standard_Failure`, with a message, that the bridge caught and threw away.

**A failure that raised nothing.** `IsDone() == false`, a null result handle, a rejected argument: these never construct an exception, so there is nothing for this channel to classify. They are why a `nil` return can come back with an empty capture even from an instrumented function.
