# #967: `'type_traits' file not found` in a consumer's build

An external report: OCCTSwift 3.0.0 added to an Xcode project, macOS arm64, and the project stops
compiling with `'type_traits' file not found` at `Standard_std.hxx`'s `#include <type_traits>`.
The header is spelled `Standard_Std.hxx` on disk, and every diagnostic in this directory's
transcripts prints it that way, so the report's lowercase `Standard_std.hxx` is the reporter's own
transcription rather than anything a compiler emitted. Nothing turns on which spelling is used, and
no mechanism is offered for it here, because none was measured. This package's own `swift build` and
`swift test` are green, so nothing internal to it can signal.

## Answer

The failing translation unit belongs to the **consumer**, not to this package. It is an
Objective-C (`.m`) file in the consumer's own target that includes an OCCT C++ header.
`OCCT.xcframework` ships roughly 7,000 C++ headers with a `HeadersPath`, so both SwiftPM and Xcode
put them on the include path of anything that links it, and `#include <STEPControl_Reader.hxx>`
resolves from the consumer's own source. A `.m` file is compiled as Objective-C, the C++ standard
library is not on the include path of an Objective-C translation unit, and `Standard_Std.hxx`
includes `<type_traits>` on line 19.

Renaming the file to `.mm` compiles it as Objective-C++ and the include chain resolves, provided the
target is at C++17 or later. That second half is a separate wall and is easy to miss, because
crossing the first one lands you in `NCollection_LinearVector.hxx` on `std::is_trivially_copyable_v`
rather than back at your own line.

The reporting project's own settings were read rather than assumed: it is a plain Xcode macOS app
that sets `CLANG_CXX_LANGUAGE_STANDARD = gnu++20`, and it holds a file `cam/OCCTBridge.m` whose
first draft included `<STEPControl_Reader.hxx>` and `<TopoDS_Shape.hxx>`. Being already above C++17,
that project needs only the rename. Nothing here establishes what any particular Xcode template
emits; what was measured is that a target which sets no standard at all lands below C++17, `gnu++14`
on the generated project used for the Xcode rows here, and that a consumer `Package.swift` with no
`cxxLanguageStandard` does the same.

No code in this package changes. What landed is documentation: a short
"What your own target has to set" section in `README.md`, a Mac Catalyst row in its platform table,
the full treatment in [`docs/guides/consuming-from-objective-c.md`](../../../docs/guides/consuming-from-objective-c.md)
and a link to it from `docs/index.md`. The answer to that question was previously written down
nowhere.

## The grid

Everything below was built, not reasoned about, and every row has a transcript in this directory.
`swiftpm-rows.txt` is a captured, path-normalised copy of `run.sh`'s stdout for the ten
`swift build` rows; `run.sh` itself writes nothing outside its workdir, so re-running it and seeing
that file unchanged is not evidence it is current, and the way to check is to compare its output.
`xcode-rows.txt` holds the `xcodebuild` rows and `url-consumer.txt` the one row that needs the
network. `pass` means the build completed.

### A consumer whose own code is Swift only

| Consumer shape | Build system | Result |
|---|---|---|
| Swift library target, `import OCCTSwift`, URL dependency on v3.0.0 | `swift build` | pass, `url-consumer.txt` |
| Swift library target, `import OCCTSwift` and nothing else | `swift build` | pass, `run.sh` row 1 |
| Swift library target calling the API | `swift build` | pass, `run.sh` row 2 |
| Swift library target with `.interoperabilityMode(.Cxx)` | `swift build` | pass, `run.sh` row 3 |
| Swift target touching `Mesh`, `Surface`, `Curve3D`, `Document` | `swift build` | pass, `run.sh` row 4 |
| Swift executable target | `swift build` | pass, `run.sh` row 5 |
| The consumer package built by Xcode, macOS | `xcodebuild` | pass |
| A real Xcode macOS **app project** with the package dependency | `xcodebuild` | pass |
| The same app forced to `CLANG_CXX_LIBRARY=libstdc++` | `xcodebuild` | pass. Why it is harmless is not measured here; what is, is that `-stdlib=libstdc++` fails `#include <type_traits>` on this toolchain, so it cannot have reached the bridge |
| The consumer package, generic iOS | `xcodebuild` | pass |
| The consumer package, iOS Simulator | `xcodebuild` | pass |
| The consumer package, Mac Catalyst | `xcodebuild` | fail, and unrelated: `no library for this platform was found in OCCT.xcframework`, which is self-explaining and is not #967 |
| visionOS, tvOS | `xcodebuild` | not measurable here, neither platform is installed on the measuring machine |

No Swift-only consumer reproduces the report, on either build system.

### A consumer with its own Objective-C or Objective-C++ code

Every row includes `<STEPControl_Reader.hxx>` from a file in the consumer's own target, and differs
only in that file's language and the target's C++ standard.

| Consumer shape | Build system | Result |
|---|---|---|
| Xcode app, `.m` (Objective-C) | `xcodebuild` | **fail: `Standard_Std.hxx:19:10: error: 'type_traits' file not found`** |
| The same file renamed `.mm`, target setting no standard (resolves to `gnu++14`) | `xcodebuild` | fail: `no template named 'is_trivially_copyable_v'`, and six more, all C++17 |
| The same, `CLANG_CXX_LANGUAGE_STANDARD=c++17` | `xcodebuild` | pass |
| SwiftPM consumer package, `.m` (Objective-C) | `swift build` | **fail: the identical `type_traits` error**, `run.sh` row 6 |
| SwiftPM consumer package, `.c` (C) | `swift build` | fail: the same `type_traits` error, `run.sh` row 7 |
| The same renamed `.mm`, consumer manifest declaring no C++ standard | `swift build` | fail: the same C++17 errors, `run.sh` row 8 |
| The same, consumer manifest declaring `cxxLanguageStandard: .cxx17` | `swift build` | pass, `run.sh` row 9 |
| A `.cpp` (C++) file, consumer manifest declaring `cxxLanguageStandard: .cxx17` | `swift build` | pass, `run.sh` row 10 |

Three scenarios are covered on both build systems, `.m`, `.mm` below C++17 and `.mm` at C++17, and
the two agree on each. That is the second construction, and it is what makes this a property of the
package's header exposure rather than of Xcode. `.c` and `.cpp` were measured on SwiftPM only.

## Re-running it

```bash
bash Scripts/repro/967-consumer-compile/run.sh
```

That covers the ten SwiftPM rows, which need no Xcode project and no network. It checks each row against the
outcome it is supposed to have and **exits 1 on any mismatch**, so a finding that has changed, or a
diagnostic whose wording has drifted, reports as a failure rather than as a transcript nobody reads.
Captured output is in `swiftpm-rows.txt`.

Two things it guards, each proved able to fail rather than assumed:

- **The comparator.** With the `.m` row's expectation flipped from `type_traits` to `pass` the run
  reports `-> expected pass, got type_traits: MISMATCH`, exactly one row of ten, and exits 1.
  Restored, it reports all ten matched and exits 0.
- **That the file under test was compiled at all.** A green `swift build` is not evidence of that:
  deleting a row's source from a kept workdir and rebuilding still prints
  `Build of target: 'ConsumerLang' complete! (1.05s)` with no compile line, so a verdict resting on
  that string alone would report `pass` for a row whose subject never existed. Each row therefore
  requires its own compile line first and reports `not_compiled` otherwise. The guard was watched
  firing rather than inferred from that experiment: with `write_lang_source` made a no-op and
  nothing else changed, all five C-family rows report
  `-> expected <x>, got not_compiled: MISMATCH` and the run exits 1. Every row also writes a
  uniquely named source (`Repro967_row<N>`, `Consumer_row<N>.swift`), so the requirement never
  depends on a neighbouring row having failed and left nothing cached.

The Xcode rows are not scripted, because generating an app project needs a tool this repo does not
depend on, and Mac Catalyst, visionOS and tvOS destinations need platforms a given machine may not
have installed. Their captured `xcodebuild` output is committed as `xcode-rows.txt` instead, so
those rows are evidenced even though they are not re-runnable from here.

All six transcripts have their absolute paths normalised and say so in their own first lines,
because the originals named an agent worktree that no longer exists. Each uses whichever
placeholders its own output contains, `<repo>` for the checkout and `<work>` for a throwaway
directory, so the set differs per file and each file's header is the authority rather than a list
here, which has been wrong twice.

Two further measurements the ten build rows do not cover:

- `warnings-and-stdlib.txt`, a captured copy of `measure-warnings.sh`'s output, carries the deprecation figures
  the guide quotes (0 for an include-only `.mm`, 5 for four legacy spellings, header-level
  `-W#pragma-messages` from two legacy convenience headers, and 0 for all of them under
  `OCCT_NO_DEPRECATED`) and the `-stdlib=libstdc++` result the Catalyst row's reasoning rests on.
- `bridge-reach.txt`, a captured copy of `measure-bridge-reach.sh`'s output, answers how far a consumer can
  actually reach, which matters because it is the route the reporting project was one `#import`
  away from. Both a Swift target writing `import OCCTBridge` and an Objective-C target writing
  `#import "OCCTBridge.h"` compile, link and run, printing `23.999999999999996` for a 2x3x4 box.
  `OCCTBridge` is not a product and its C surface carries no compatibility promise, so this is a
  route to understand rather than to recommend. `docs/architecture/overview.md` and `Package.swift`
  each called it impossible, in three successive wordings, until this was measured.
  Proved able to fail, like `run.sh`'s two guards: with the `#import` removed from the generated
  `.m` and nothing else changed, the run reports `did not reach the bridge: MISMATCH` for that
  route, `1 route(s) did not`, and exits 1.

## Why no test holds this

The failing compile is of a file in the consumer's project. `swift test` compiles this package's
targets and nothing else, so no test here can execute it.

The adjacent invariant that **is** ours is that no public bridge header drags a consumer into C++.
Measured across `Sources/OCCTBridge/include/`: `OCCTBridge.h` imports `<Foundation/Foundation.h>`
and the fifteen per-domain headers, and each of those fifteen carries exactly three preprocessor
lines, its own `#ifndef` / `#define` / `#endif` guard, and includes nothing at all.

That invariant is already held by this package's own build, and the proof is an injection rather
than an argument. `Sources/OCCTSwift/*.swift` do `import OCCTBridge` with no C++ interop, so the
Swift compiler builds the `OCCTBridge` clang module in Objective-C mode on every `swift build`.
Adding `#include <Standard_Std.hxx>` to `OCCTBridge.h` fails `swift build` here with
`could not build Objective-C module 'OCCTBridge'` and the same `'type_traits' file not found`,
before any consumer sees it. A new gate script would duplicate a check the ordinary build performs.
See `injection.txt`, whose three legs are a full rebuild of the unmodified header, the injected
failure, and a full rebuild after restoring.

**The enforcement is a side effect, so it is recorded where it could be removed.** It holds only
because `OCCTSwift`'s target declares no `.interoperabilityMode(.Cxx)`. Turning interop on would
compile those headers as C++ and move the failure out of this build and into every consumer's, with
nothing here reporting the loss. A comment on that target in `Package.swift` says so, because a
manifest edit is where it would happen and this file is not what the editor would have open.
