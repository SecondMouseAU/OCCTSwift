# Phase 3: OCCTMiscTests injection matrix (#1989)

**Target**: every `@Test` in `Tests/OCCTMiscTests/` (119 across six files).
**Policy**: `okf/policies/prove-the-test-fails.md`: inject a defect in the code the test exercises,
watch the named expectation fail, restore, watch it pass.

This file was rewritten from scratch for #1989. The nine rows it held before named five bridge
functions that do not exist (`OCCTShapeProject`, `OCCTKDTreeSearch`, `OCCTHatchPatternGenerate`,
`OCCTUnicodeConvert`, `OCCTDirectoryListing`), ticked every Red and Green cell without quoting a
single failing expectation, and waived the other 110 tests. Every row below was run: the Red
column quotes the expectation that failed under the injection, file:line as Swift Testing printed
it, and Green is the same test passing after the injection was reverted.

Kernel parity for each row is in `../../766-execution/kernel-parity/OCCTMiscTests.json`, with the
probe that produced it under `Scripts/repro/766-*/`.

## BridgeExceptionDiagnosticsTests.swift

Fixture for every test but one: `IntTools.isDirsCoinside(0,0,0, 0,0,1)`, which reaches `OCCTIntToolsIsDirsCoinside`, whose `gp_Dir(0,0,0)` throws inside the bridge's `try`. The channel itself is `occtRecordCaughtException` and the `OCCTDiagnostics*` accessors in `Sources/OCCTBridge/src/OCCTBridge.mm`, read by `Sources/OCCTSwift/OCCTDiagnostics.swift`. Injections were applied in four builds (I1; I2+I5+I6+I8+I9; I3+I5+I7+I8; I4), and each row quotes the line only its own injection can fail.

| Suite | Test | Bridge / Swift function | Injection | Red (failing expectation) | Green | Parity |
|---|---|---|---|---|---|---|
| Bridge exception diagnostics (#1161) | recordsTheOCCTFailure | OCCTIntToolsIsDirsCoinside, occtRecordCaughtException | I1: the Standard_Failure clause records kind StdException and an empty type | `BridgeExceptionDiagnosticsTests.swift:41` `record.kind == .occtFailure`, `BridgeExceptionDiagnosticsTests.swift:42` `record.exceptionType == "Standard_ConstructionError"` | passes | PASS: kernel throws Standard_ConstructionError, "gp_Dir() - input vector has zero norm" |
| Bridge exception diagnostics (#1161) | explainsANilReturnFromAPublicAPI | OCCTShapeHistoryFromRotate | I1 | `BridgeExceptionDiagnosticsTests.swift:61` `record.kind == .occtFailure`, `BridgeExceptionDiagnosticsTests.swift:62` `record.exceptionType == "Standard_ConstructionError"` | passes | PASS: gp_Ax1 with gp_Dir(0,0,0) throws Standard_ConstructionError |
| Bridge exception diagnostics (#1161) | recordsNothingByDefault | OCCTDiagnosticsCaptureEnabled | I2: thread-local capture flag defaults to true | `BridgeExceptionDiagnosticsTests.swift:69` `OCCTDiagnostics.isCaptureEnabled == false`, `BridgeExceptionDiagnosticsTests.swift:71` `OCCTDiagnostics.records.isEmpty` | passes | N/A (bridge state) |
| Bridge exception diagnostics (#1161) | recordsNothingOnSuccess | OCCTIntToolsIsDirsCoinside | I9: the success path runs an inner try that records a caught gp_Dir(0,0,0) | `BridgeExceptionDiagnosticsTests.swift:81` `diagnostics.isEmpty` | passes | PASS: kernel returns true, no throw |
| Bridge exception diagnostics (#1161) | capturesNest | OCCTDiagnostics.capturing (Swift) | I3: capturing returns records(from: 0) instead of from its start index | `BridgeExceptionDiagnosticsTests.swift:97` `innerDiagnostics.count == 1` | passes | N/A (bridge state) |
| Bridge exception diagnostics (#1161) | clearsTheBuffer | OCCTDiagnosticsClear | I4: clear resets the dropped count but not the records | `BridgeExceptionDiagnosticsTests.swift:112` `OCCTDiagnostics.records.isEmpty` | passes | N/A (bridge state) |
| Bridge exception diagnostics (#1161) | boundsTheBuffer | occtRecordCaughtException | I5: THE_DIAGNOSTIC_RECORD_LIMIT 256 -> 512 | `BridgeExceptionDiagnosticsTests.swift:132` `diagnostics.count == cap`, `BridgeExceptionDiagnosticsTests.swift:133` `OCCTDiagnostics.droppedRecordCount == attempts - cap` | passes | N/A (bridge state) |
| Bridge exception diagnostics (#1161) | capturesAStackTraceOnRequest | OCCTDiagnosticsSetStackTraceDepth | I6: the setter ignores its argument | `BridgeExceptionDiagnosticsTests.swift:149` `OCCTDiagnostics.stackTraceDepth == 16`, `BridgeExceptionDiagnosticsTests.swift:154` `!(try #require(withTrace.first).stackTrace.isEmpty)` | passes | PASS: kernel stack string empty at depth 0, non-empty at 16 |
| Bridge exception diagnostics (#1161) | clampsANegativeStackTraceDepth | OCCTDiagnosticsSetStackTraceDepth | I7: both clamps removed (Swift max(0, _) and the bridge's depth < 0 ? 0). they clamp independently, so removing one alone leaves the other doing the work (not run separately) | `BridgeExceptionDiagnosticsTests.swift:162` `OCCTDiagnostics.stackTraceDepth == 0` | passes | EXPECTED_DIVERGENCE: kernel keeps -5, which is why the clamp exists |
| Bridge exception diagnostics (#1161) | loggingIsIndependentOfCapture | occtRecordCaughtException | I8: return right after logging, so a logged record is never captured | `BridgeExceptionDiagnosticsTests.swift:177` `whileLogging.count == 1` | passes | N/A (bridge state) |
| Bridge exception diagnostics (#1161) | describesItself | OCCTDiagnostics.Record.description | I1 | `BridgeExceptionDiagnosticsTests.swift:197` `record.description.hasPrefix("OCCTIntToolsIsDirsCoinside: Standard_ConstructionError: ")` | passes | PASS: exception type matches the kernel's |
