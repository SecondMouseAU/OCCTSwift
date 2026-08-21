# #967: `'type_traits' file not found` in a consumer's build

An external report: OCCTSwift 3.0.0 added to an Xcode project, macOS arm64, and the project stops
compiling with `'type_traits' file not found` at `Standard_std.hxx`'s `#include <type_traits>`.
The header is spelled `Standard_Std.hxx` on disk, which the report gets away with because macOS
filesystems are case-insensitive by default. This package's own `swift build` and `swift test` are
green, so nothing internal to it can signal.

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
with `CLANG_CXX_LANGUAGE_STANDARD = gnu++20` (the Xcode template's own default) and a file
`cam/OCCTBridge.m` whose first draft included `<STEPControl_Reader.hxx>` and `<TopoDS_Shape.hxx>`.
For that project the rename alone is sufficient.

Nothing in this package changes. `README.md` gained a "What your own target has to set" section,
because the answer to that question was previously written down nowhere.

## The grid

Everything below was built, not reasoned about. `pass` means the build completed.

### A consumer whose own code is Swift only

| Consumer shape | Build system | Result |
|---|---|---|
| Swift library target, `import OCCTSwift`, URL dependency on v3.0.0 | `swift build` | pass |
| Swift library target, local path dependency | `swift build` | pass |
| Swift library target with `.interoperabilityMode(.Cxx)` | `swift build` | pass |
| Executable target | `swift build` | pass |
| Target touching `Mesh`, `Surface`, `Curve3D`, `Document` | `swift build` | pass |
| The consumer package built by Xcode, macOS | `xcodebuild` | pass |
| A real Xcode macOS **app project** with the package dependency | `xcodebuild` | pass |
| The same app forced to `CLANG_CXX_LIBRARY=libstdc++` | `xcodebuild` | pass, the setting does not reach package targets |
| The consumer package, generic iOS | `xcodebuild` | pass |
| The consumer package, iOS Simulator | `xcodebuild` | pass |
| The consumer package, Mac Catalyst | `xcodebuild` | fail, and unrelated: `no library for this platform was found in OCCT.xcframework`, which is self-explaining and is not #967 |
| visionOS, tvOS | `xcodebuild` | not measurable here, neither platform is installed on the measuring machine |

No Swift-only consumer reproduces the report, on either build system.

### A consumer with its own Objective-C or Objective-C++ code

| Consumer shape | Build system | Result |
|---|---|---|
| Xcode app with a `.m` file including `<STEPControl_Reader.hxx>` | `xcodebuild` | **fail: `Standard_Std.hxx:19:10: error: 'type_traits' file not found`** |
| The same file renamed `.mm`, target at Xcode's `gnu++14` default | `xcodebuild` | fail: `no template named 'is_trivially_copyable_v'` and six more, all C++17 |
| The same, `CLANG_CXX_LANGUAGE_STANDARD=c++17` | `xcodebuild` | pass |
| SwiftPM consumer package with an Objective-C target including the same header | `swift build` | **fail: the identical `type_traits` error** |
| The same renamed `.mm`, consumer manifest declaring no C++ standard | `swift build` | fail: the same C++17 errors |
| The same, consumer manifest declaring `cxxLanguageStandard: .cxx17` | `swift build` | pass |

The two build systems agree on all six rows, which is what makes this a property of the package's
header exposure rather than of Xcode.

## Re-running it

```bash
bash Scripts/repro/967-consumer-compile/run.sh
```

That covers the three SwiftPM rows, which need no Xcode project. Captured output is in
`swiftpm-rows.txt`. The Xcode rows were run against a generated app project and are not scripted
here, since generating one needs a tool this repo does not depend on.

## Why no test holds this

The failing compile is of a file in the consumer's project. `swift test` compiles this package's
targets and nothing else, so no test here can execute it.

The adjacent invariant that **is** ours is that no public bridge header drags a consumer into C++:
`Sources/OCCTBridge/include/OCCTBridge.h` and the fifteen per-domain headers it imports include
`<Foundation/Foundation.h>` and each other, and nothing else. That one is already held by this
package's own build, measured rather than assumed: `Sources/OCCTSwift/*.swift` do `import OCCTBridge`
with no C++ interop, so the Swift compiler builds the `OCCTBridge` clang module in Objective-C mode
on every `swift build`. Adding `#include <Standard_Std.hxx>` to `OCCTBridge.h` fails
`swift build` here with the same `'type_traits' file not found`, before any consumer sees it. See
`injection.txt`.
