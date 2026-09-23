# #2171: does the bridge's error contract survive on wasm?

The bridge answers a failed OCCT call by catching at the C boundary and returning a refusal.
`check-throwing-calls.py` gates that every throwing OCCT construction is caught, guarded or
unreachable. If exceptions do not work on `wasm32-unknown-wasip1`, every one of those sites traps
instead of refusing, and the port is a different project.

[PR #2180](https://github.com/SecondMouseAU/OCCTSwift/pull/2180) had already shown a throw crossing
a flat C boundary and being caught, in one C++ file. This spike re-ran that and then asked the
questions one file cannot answer: what happens when the raise, the frames it passes through, and
the catch are compiled separately and not identically, which is the situation a kernel of OCCT's
size creates by default.

`run.sh` builds and runs everything below. `transcript.txt` is a recorded run.

## Re-running #2180 first

Its package was copied out of `origin/wasm/2169-toolchain-pin` and built unchanged. It printed
`libc++ compute path: 6.75`, `C++ throw/catch path: -26.0` and
`hello from wasm32-unknown-wasip1`, which is its claim exactly. Both of its negative cases
reproduced too: dropping the `eh` linker settings fails the link on `__cxa_throw`,
`__cxa_begin_catch`, `_Unwind_CallPersonality` and five more, and cutting `WASM_CXX_EH_FLAGS` to a
bare `-fwasm-exceptions` builds a module wasmkit refuses with
`Error: "Message(text: "Illegal opcode: [6]")" at offset 0x282`.

Its inspection of the runtimes holds as well: the Swift SDK's `libc++abi.a` carries
`cxa_noexception.cpp.o` and defines no `__cxa_throw`, only `__cxa_throw_bad_array_new_length`,
while wasi-sdk's `eh` flavour defines the real one.

**One correction.** That PR documents, in three places, that `touch Package.swift` makes an edit to
the pins file reach the next build. It does not. SwiftPM keys its manifest cache on the *content*
of `Package.swift`, and touching changes the mtime and not the hash. Measured, from a clean
`.build`, with the pins edited to a bare `-fwasm-exceptions`:

| Action after editing the pins file | Rebuild | Module |
|------------------------------------|---------|--------|
| nothing | `Build complete! (0.22s)` | runs clean, so the flag reads as unnecessary |
| `touch Package.swift` | `Build complete! (0.22s)` | still runs clean |
| append a comment line to `Package.swift` | recompiles the C++ target | `Illegal opcode: [6]` |
| `swift build --manifest-cache none` | recompiles the C++ target | `Illegal opcode: [6]` |

This package therefore passes `--manifest-cache none` on every build rather than relying on a
cache-busting edit, and reads its flags from the environment.

## The eight cases

`standalone/` is one Swift executable over four C++ and C targets, arranged to put the same demands
on the unwinder OCCT will: a failure type raised through a static `Raise` entry point and caught by
base reference, refcounted objects live on the stack between the raise and the catch, a target
deliberately built *without* the exception flags, and setjmp beside them.

| Case | Sentinel | What it establishes |
|------|----------|---------------------|
| catch by derived type | 20 | a raise crossed a target boundary and its own type caught it |
| catch by base reference | 21 | `std::exception&` caught a derived failure, so the type match reached the base |
| `catch (...)` | 22 | the handler shape every `OCCTBridge` function's outermost catch uses |
| libc++ raised it, not us | 23 | a `std::out_of_range` from `vector::at` crossed the seam between the two libc++ builds |
| through a non-EH frame | **10** | it propagated, and that frame's destructor did **not** run |
| try/catch in a non-EH TU | **-1** | that catch never fired, and no diagnostic said so |
| setjmp/longjmp | 7 | a longjmp arrived back at its setjmp in a TU carrying the exception flags |
| leak on an all-EH path | 0 | every destructor ran when the whole path carried the flags |

The first four are the answer to #2171 as written: exceptions compile, link, run and are caught,
including across separately compiled targets, including when libc++ rather than our own code is the
thrower.

The two in bold are the finding this spike exists for, and they are two different failures of the
same cause.

## The flags are not optional for OCCT, and their absence is silent

`ProbeMiddleNoEH` is an ordinary C++ target with ordinary C++ in it, distinguished only by having
no `cxxSettings` in the manifest. It stands in for what happens if the bridge receives
`WASM_CXX_EH_FLAGS` and OCCT's own CMake does not.

Compiling it produced no error and no warning. What it produced was:

- an exception raised below it **propagates through it**, because in the wasm exception model
  propagation is the VM's job rather than the frame's, and
- the frame's **stack cleanup does not run**, so every local that frame held is leaked, and
- a `try`/`catch (...)` written **inside** it silently never fires; the exception sails past into
  the caller's handler.

Flipping that one target's `cxxSettings` on, changing nothing else, turns case five from 10 into 11
and case six from -1 into 42. That is the whole causal chain in one variable.

For OCCT the third point is the dangerous one. OCCT does not only raise `Standard_Failure`, it
catches it internally to convert a failure into a status: `catch (Standard_Failure` appears in the
pinned headers alone in `BRepMesh_NodeInsertionMeshAlgo.hxx`, `IMeshTools_ModelAlgo.hxx` and
`IMeshTools_ModelBuilder.hxx`, before counting the `.cxx` files. Build OCCT without the flags and
those handlers are gone with no diagnostic anywhere: an algorithm that was supposed to return
`IsDone() == false` raises through to the bridge instead, and every OCCT frame between the two
leaks whatever it held, which in OCCT means `Handle` references and `TopoDS_Shape` instances.

So `Scripts/build-occt-wasm.sh` has to put `WASM_CXX_EH_FLAGS` into `CMAKE_CXX_FLAGS` for the whole
OCCT build, not just into the bridge's. It currently says nothing about exceptions at all. That is
#2172's first job.

## setjmp needs its own flag, and it is also silent

`-fwasm-exceptions` does nothing for `setjmp`. On wasip1, `setjmp` and `longjmp` are not libc
functions: `libsetjmp.a` defines `__wasm_setjmp`, `__wasm_setjmp_test` and `__wasm_longjmp`, and
only `-mllvm -wasm-enable-sjlj` lowers a setjmp pair into them. Without that flag clang compiles
the file without complaint and the link fails on two undefined symbols, `setjmp` and `longjmp`.
With the flag, and with `-lsetjmp` on the link line, a round trip works alongside the exception
flags in the same translation unit.

This settles the unverified half of #2047: the claim that `OSD_ThreadPool.cxx`'s setjmp needs
`-fwasm-exceptions` is wrong in its particulars. It needs `-mllvm -wasm-enable-sjlj`, which is a
different flag, and `-lsetjmp`, which is a different library. OCCT's other setjmp user, the
`OCC_CATCH_SIGNALS` macro in `Standard_ErrorHandler.hxx`, expands to a real `setjmp` inside OCCT.
This section used to say it expands to nothing, which is true of the bridge's own compile and
false of OCCT's, since OCCT's CMake adds `-DOCC_CONVERT_SIGNALS` on every non-Windows target
(#2188). #2172 measured the consequence: six TKernel objects reference `__wasm_setjmp`, so both
flags are required rather than precautionary. See `Scripts/repro/2172/README.md`.

## An uncaught exception

`probe-uncaught` raises with no handler anywhere above it. The module does not trap and does not
abort. The exception leaves through `_start` and the runtime reports it:

    raising with no handler anywhere above...
    Error: wasm exception (payload: [WasmTypes.Value.i32(1293504)])
    exit status: 1

This is a better position than the native build is in. Natively, an exception reaching the Swift
boundary is uncatchable in-process (#345). On wasm it is a first class value the host sees, which a
JavaScript embedder can catch at the call. The instance's state afterwards is still undefined, so
it is a diagnostic improvement and not a licence to stop catching at the bridge.

## What it costs in module size

`size/size-probe.cpp` is the same program twice, differing only in whether it reports a failure by
throwing or by returning a sentinel. No Swift, because a Swift executable's runtime is several
megabytes and would bury the number.

|  | no exceptions | exceptions | delta |
|--|---------------|------------|-------|
| `-O0` | 641,855 | 837,961 | +196,106 |
| `-Os` | 189,975 | 396,989 | +207,014 |

The delta barely moves between the two optimisation levels, so it is mostly the fixed cost of
linking the exception-enabled `libc++abi` and `libunwind`, roughly 200 KB. What this does **not**
measure is the per-function part, the landing pads and unwind tables in the code that can throw,
which is the part that scales with OCCT. Take 200 KB as a floor for the whole module and nothing
more.

## What is still not established

- **Nothing here has met OCCT.** The largest object file in this package is a few kilobytes. Whether
  the two libc++ builds still agree across a static archive of OCCT's size is #2172 and #2174.
- **The libc++ seam rests on weak symbol resolution.** `std::__throw_out_of_range` and its family are
  weak symbols. The Swift SDK's prebuilt `libc++.a` references no `__cxa_throw` at all, so its
  copies abort where ours throw. In this link the exception-enabled definition won, which is why
  case four passes. That is link-order dependent, and a link that pulls the `libc++.a` member in
  first would get the aborting one. Worth re-checking at OCCT scale rather than assuming.
- **`operator new` and `std::bad_alloc`** were not probed. Under the wasm32 4 GB ceiling an OCCT
  allocation failure is a realistic path, and which of the two runtimes supplies `operator new`
  decides whether it throws or aborts.
