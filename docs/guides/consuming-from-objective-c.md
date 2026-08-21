---
title: Consuming the package
nav_order: 14
---

# Consuming the package, and reaching OCCT's C++ API from your own code

## A Swift target needs nothing

A target that does `import OCCTSwift` needs no `cxxLanguageStandard`, no
`.interoperabilityMode(.Cxx)` and no extra build settings. The C++ is sealed inside this package's
own Objective-C++ bridge, and the module you import is a plain Swift one.

Measured on v3.0.0, ten Swift-only consumer shapes, all green:

- Under `swift build`, a consumer package resolving OCCTSwift by URL and by local path; a library
  target, a library target with `.interoperabilityMode(.Cxx)`, a library target touching `Mesh`,
  `Surface`, `Curve3D` and `Document`, and an executable target.
- Under `xcodebuild`, that consumer package on macOS, generic iOS and iOS Simulator.
- Under `xcodebuild`, a real Xcode macOS app project with the package as a dependency, both with
  Xcode's default `CLANG_CXX_LIBRARY` and forced to `libstdc++`. Both are green. That the override
  does not reach this package's own bridge target is the likeliest reading and is not measured
  here: what is measured is that the build succeeds, and `-stdlib=libstdc++` on this toolchain
  fails `#include <type_traits>` outright, so it cannot have reached the bridge's `.mm` files.

## OCCT's own headers are visible, and have two requirements

`OCCT.xcframework` carries roughly 7,000 C++ headers and declares a `HeadersPath`, so both SwiftPM
and Xcode put them on the include path of anything that links it. `#include <STEPControl_Reader.hxx>`
therefore resolves from a file in your own project, which is useful and is also how #967 happened.
A file that includes an OCCT header has two requirements, and missing either one fails inside OCCT
rather than at your own line.

### 1. The file must be Objective-C++ or C++

`.mm` or `.cpp`, never `.m` or `.c`. The C++ standard library is not on the include path of an
Objective-C or C translation unit, and OCCT's headers reach `<type_traits>` almost immediately, so
such a file stops at:

```
Standard_Std.hxx:19:10: error: 'type_traits' file not found
```

That is the whole of #967. The reporting project had a file named `OCCTBridge.m`, one letter away
from the `.mm` its own header comment named.

### 2. The target must be at C++17 or later

This one is easy to miss, because crossing the first wall lands you in
`NCollection_LinearVector.hxx` on `std::is_trivially_copyable_v` rather than back at your own line:

```
NCollection_LinearVector.hxx:95:26: error: no template named 'is_trivially_copyable_v' in namespace 'std'
```

The `cxxLanguageStandard: .cxx17` in this package's manifest applies to **this package's** targets,
not to yours. A target that does not set a standard falls below C++17 (measured: `gnu++14` on a
generated Xcode project, and the SwiftPM default with no `cxxLanguageStandard` in the consumer's own
manifest). Set `CLANG_CXX_LANGUAGE_STANDARD` to `c++17` or later on an Xcode target, or declare
`cxxLanguageStandard: .cxx17` in your own `Package.swift`.

### Expect OCCT's own deprecation warnings

OCCT 8.0 deprecates its legacy spellings (`Standard_True`, `Standard_Real`, the `TopTools_*` map
and list typedefs, `TColStd_Array1Of*`) in favour of native C++ types and explicit `NCollection_*`
templates. Two different warnings come out of that, and only one of them tracks your own code.
Measured on a `.mm` compiled against the pinned headers: including `<STEPControl_Reader.hxx>` and
using nothing gives **0** `-Wdeprecated-declarations`, and naming four legacy spellings gives
**5**, so that kind is in proportion to what you write. But some of OCCT's legacy convenience
headers are deprecated as *headers*, and those warn on the include alone: `<TopTools_ListOfShape.hxx>`
and `<TColStd_Array1OfReal.hxx>` each emit
`is deprecated since OCCT 8.0.0 [-W#pragma-messages]` with no code of yours at all.

`OCCT_NO_DEPRECATED` is OCCT's own opt-out, defined in `Standard_Macro.hxx`, and it takes both kinds
to 0. This package sets it on its own bridge target, which is 16 `.mm` files written in the
legacy idiom and was measuring roughly 684 warnings per consumer build before it did (#281). Define
it on yours if the noise is drowning your own diagnostics, remembering that it buys quiet rather
than absolution: the spellings are still deprecated and will be removed upstream eventually.

## Check the Swift API first

Most reasons to write that file are already wrapped. Reading a STEP file and measuring it is Swift:

```swift
import OCCTSwift

let shape = try Shape.loadSTEP(from: stepURL)
print(shape.faces().count, shape.volume ?? 0)
try shape.writeSTL(to: stlURL, deflection: 0.05)
```

`Document.loadSTEP(from:)` is the assembly-aware version, when you want the product structure,
colours and names rather than one merged shape. See
[`docs/API_REFERENCE.md`](../API_REFERENCE.md) for the full surface.

**That route is Swift only, and this page would otherwise imply otherwise.** `Sources/OCCTSwift`
carries no `@objc` declarations, and the package vends exactly one library product, `OCCTSwift`, so
`OCCTBridge` is not something a consumer can import either. An Objective-C file cannot call `Shape`
or `Document`. If your app is Objective-C, the two options are a small Swift file of your own that
does the OCCT work and exposes an `@objc` facade to the rest of your app, or the `.mm` route above
talking to OCCT's C++ directly. The `.mm` route is more code and puts you on OCCT's own API rather
than this one, which is the trade this page exists to make visible rather than to decide for you.

## Mac Catalyst

There is no Mac Catalyst slice in `OCCT.xcframework`, so a Catalyst destination fails at build
planning with `no library for this platform was found in OCCT.xcframework`. Unlike visionOS and
tvOS, which the same message describes and which `Scripts/build-occt.sh` can produce under
`BUILD_ALL_PLATFORMS=1`, there is no local-rebuild route: that script has no Catalyst target at all.
Plain macOS and iOS are unaffected. See the platform table in
[README](https://github.com/SecondMouseAU/OCCTSwift#supported-platforms).

## Reproducer

[`Scripts/repro/967-consumer-compile/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/967-consumer-compile)
carries the full measured grid and a `run.sh` that builds a throwaway consumer package ten ways and
checks each against its expected outcome.
