# #3029: OCCT prints STEP write statistics on every export; who owns that?

Every STEP write puts a `Statistics on Transfer (Write)` block on standard output: thirteen lines of
it, seven with text, in green. The issue asks what the library should do about it and says to follow
OCCT. OCCT's answer is that **the host owns the messenger**, and what the library was missing was the
host's handle on it, not a switch of its own.

## What prints, measured

Against the pinned `v4.0.0-kernel.3` macOS slice (`libOCCT-macos.a` sha256
`6d51d59022d2cef98152a8f3c5a6b640a5bac2a5968678e80e40cd5dac6ebc18`), by `run.sh`
(`transcript.txt`). A recording printer is added to the default messenger at trace level `Trace`, so
it sees every message whatever the other printers are set to, and stdout is left to OCCT, so the
line counts are what OCCT's own printer wrote.

| scenario | lines OCCT put on stdout | messages sent to the default messenger |
|---|---|---|
| `STEPControl_Writer`, as shipped | **13** | 4, all `info` |
| same, default printers at trace level `warning` | **0** | 4, all `info` |
| same, at `fail` | 0 | 4 |
| same, a writer-local messenger with no printers (the issue's proposal) | **4** | 2 |
| `STEPCAFControl_Writer` (an XDE document) | 13 | 4, all `info` |
| same, at `warning` | 0 | 4 |
| `IGESControl_Writer` | 0 | 0 |
| `STEPControl_Reader` on a malformed file | 2 | 3: two `trace`, one `fail` |
| same, at `warning` | **2** | 3 |

So the block is **four `Message_Info` messages**, STEP only (a shape or a document; IGES prints
nothing), and a printer at trace level `warning` drops all four while the `**** ERR StepFile`
complaint of a malformed file, a `Message_Fail`, is unchanged by it:

```
**** ERR StepFile : Undefined Parsing: Line 6: Incorrect syntax: unexpected ';'    ****
```

That last row is what the issue was afraid of losing: "no way for a consumer to turn it off short of
detaching the printers from OCCT's process-wide default messenger, which also silences anything
genuinely wrong". Detaching does. **Raising the printers' trace level does not**, and it is OCCT's
own mechanism.

## Where the four messages come from

| message | source (`V8_0_1`) | messenger |
|---|---|---|
| the header and `Transfer Mode` line | `XSControl_TransferWriter::PrintStats`, `XSControl_TransferWriter.cxx:48-50` | `myTransferWriter->Messenger()`, a `Transfer_FinderProcess`'s, which defaults to `Message::DefaultMessenger()` (`Transfer_ProcessForFinder_0.cxx:56`) and has a setter (`:383-387`) |
| `Transferring Shape, ShapeType = N` | `XSControl_TransferWriter.cxx:172-177` | the same |
| `** WorkSession : Sending all data` | `IFSelect_ModelCopier.cxx:313` | `Message::SendInfo()`, **hard-wired** |
| ` Step File Name : ... Write  Done` | `StepSelect_WorkLibrary::WriteFile`, `StepSelect_WorkLibrary.cxx:85`, `:103`, `:137-139` | `Message::SendInfo()`, **hard-wired** |

The issue proposes giving the writer's own messenger no printers. Measured, that silences the first
two and leaves the last two: four lines of stdout instead of thirteen
(`transcript.txt`, "what the writer-local messenger leaves on stdout"). Half of the block has no
per-writer handle at all, so no option on `Exporter.writeSTEP` could remove it without a kernel
change.

## What OCCT's own callers do

Looked for, in `Libraries/occt-src`, in the order `okf/policies/follow-occt-callers.md` gives:

1. **Production libraries.** `STEPControl_`, `STEPCAFControl_`, `DESTEP_Provider` and the transfer
   classes never silence it and have no flag for it. The only trace-level controls in
   `src/DataExchange` are integer per-process levels (`Transfer_ProcessForFinder::SetTraceLevel`,
   `Interface_FileReaderTool::SetTraceLevel`) that govern the *transfer's* messages, not
   `PrintStats`.
2. **DRAW.** `dtracelevel [trace|info|warn|alarm|fail]` (`Draw_BasicCommands.cxx:976-1068`, registered
   at `:1274`) walks `Message::DefaultMessenger()->ChangePrinters()` and calls
   `aPrinter->SetTraceLevel(aLevel)` on each (`:1065`). That is the user-facing control, and it is a
   control over the host's messenger, not over the writer.
   `XSTEPDRAWRUN` (`XSDRAW.cxx:99-105`) saves the messenger's printers, adds a `Draw_Printer`, runs
   the STEP or IGES command and restores them: the harness manages the printers around the library.
   `DRAWEXE.cxx:270-281` replaces the `std::cout` printer outright on the wasm build.
3. **The documentation.** `TDocStd_Application.hxx:62-63`: "the trace level of messages can be tuned
   by setting trace level (SetTraceLevel (Gravity)) for the used Printer. By default, trace level is
   Message_Info, so that all messages are output." `Message_Printer.hxx:41-43` says the same.

The convention is consistent across all three: **OCCT's library code prints at `Info` and leaves the
level to whoever embeds it.** A host that wants quiet raises the level of its own printers.

## What the library does about it, and what it does not

**Added: `Messenger.defaultTraceLevel` and `Messenger.setDefaultTraceLevel(_:)`**, OCCT's `dtracelevel`
and nothing more, in `Sources/OCCTSwift/Messenger.swift` over `OCCTDefaultMessengerTraceLevel` and
`OCCTDefaultMessengerSetTraceLevel` in the bridge. A host calls
`Messenger.setDefaultTraceLevel(.warning)` once at launch and its STEP exports stop printing while
every warning, alarm and failure still does. Inside `capturingDefaultOutput` it reads and writes the
printers the capture set aside, the ones that print to the host's stream, so a level set during a
scope is the level after it and the captured text is the same whatever the level is.

**Not done, with the reason for each:**

- **Silence it in the bridge's STEP writers** (the issue's option 1). Eleven construction sites, and
  after all eleven two of the four messages would still print, per the table above. The only way to
  stop all four is to detach the default messenger's printers around each export, which is
  `capturingDefaultOutput`: it mutates one process-wide object while other threads print through it,
  and it refuses to nest, so a second concurrent export either prints or loses the first's silence.
  `docs/thread-safety.md` and #1403 are a series about making concurrent STEP I/O safe, and this
  would add a shared-state mutation to every one of those calls.
- **Silence it by default and add a property to put it back** (option 2). The same, plus the part the
  brief asks to state plainly, below.
- **Route it to the bridge's own diagnostics channel** (option 3). Impossible for the same reason:
  half of it never passes through anything the bridge holds.

## SemVer

**The addition is MINOR**: two new public members, nothing removed, and the default is unchanged, so
no consumer's output moves.

**Silencing by default would change observable behaviour for every consumer, with no signature
change and so no compile error to find it.** Anyone who reads the `Step File Name : ... Write  Done`
line, greps a log for `Statistics on Transfer`, or relies on seeing OCCT's Info output at all would
lose it silently. `okf/policies/semver-at-release.md` is "when in doubt, say MAJOR" because a wrong
MINOR costs a consumer's build, and a change that removes text a consumer may parse is that case.
Done through the trace level it would also be process-wide and silence every OCCT component's Info
output, not only STEP's. That is a direction call for the owner, and it is not made here.

## What this does not show

`transcript.txt` is the kernel half, run in its own process. The Swift tests
(`Issue3029DefaultTraceLevelTests`) check the wrapper: that the level read is the level set, that a
refused level changes nothing, and that inside a capture the level lands on the host's printers
while the capture's own printer, and so its text, is unaffected. They deliberately do not redirect
standard output, because Swift Testing runs suites in parallel and prints its own progress to that
stream, so a descriptor swap around an export would swallow a sibling suite's result lines.

One thing the tests cannot say, and a one-off run did, with descriptor 1 swapped for a file around
each call and nothing else running (a scratch test, not committed, for the reason above). Through
the Swift API, `Exporter.writeSTEP` on a box:

| `Messenger.defaultTraceLevel` | lines on stdout | statistics block |
|---|---|---|
| `.info`, as shipped | 13 | present |
| `.warning` | **0** | absent |
| `.fail` | 0 | absent |
| `.info` again | 13 | present, so setting it back restores it |

and `Shape.load(fromPath:)` on a malformed file at `.warning` still printed its two lines, the
`**** ERR StepFile` complaint among them.

### Prove-the-test-fails

Four injections into the bridge functions, each rebuilt and run against
`Issue3029DefaultTraceLevelTests`, each restored with `git checkout --` and checked clean:

| injection | caught by |
|---|---|
| A. the setter changes nothing | `levelReadsBackWhatWasSet` (6 issues) and `levelInsideACaptureLandsOnTheHostsPrinters` (2) |
| B. the level always lands on the messenger's own printers, so on the capture's inside a capture | `levelInsideACaptureLandsOnTheHostsPrinters` (2) |
| C. the range check is gone | `outOfRangeLevelIsRefused` (3) |
| D. the getter reports the highest level among printers, not the lowest | **nothing**, and it cannot be: the default messenger has one printer here and no Swift API attaches a second, so highest and lowest are the same number. The "lowest" rule is stated in the doc comment and not pinned by a test |

Row D is labelled as adding nothing because that is what it measured. The restored tree passes all
four tests.

## Reproduce

```bash
Scripts/repro/3029-step-write-statistics/run.sh
```

`run.sh` finds the pinned asset under `.build/artifacts` after a `swift build`, prints which kernel it
read, builds in a temporary directory and never writes to the repository.
