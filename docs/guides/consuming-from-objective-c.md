# Consuming the package, and reaching OCCT's C++ API from your own code

## A Swift target needs nothing

A target that does `import OCCTSwift` needs no `cxxLanguageStandard`, no
`.interoperabilityMode(.Cxx)` and no extra build settings. The C++ is sealed inside this package's
own Objective-C++ bridge, and the module you import is a plain Swift one.

Measured on v3.0.0, ten Swift-only consumer shapes, all green: a library target and an executable
target under `swift build`, by URL and by local path, one of them with
`.interoperabilityMode(.Cxx)` on the consumer's own target and one touching `Mesh`, `Surface`,
`Curve3D` and `Document`; the same package built by `xcodebuild`; and a real Xcode macOS app project
with the package as a dependency, on macOS, generic iOS and iOS Simulator.

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

## Mac Catalyst

There is no Mac Catalyst slice in `OCCT.xcframework`, so a Catalyst destination fails at build
planning with `no library for this platform was found in OCCT.xcframework`. Plain macOS and iOS are
unaffected. See the platform table in [`README.md`](../../README.md).

## Reproducer

[`Scripts/repro/967-consumer-compile/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/967-consumer-compile)
carries the full measured grid and a `run.sh` that builds a throwaway consumer package five ways and
checks each against its expected outcome.
