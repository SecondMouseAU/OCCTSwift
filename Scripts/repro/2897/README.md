# #2897: the TObj_Application singleton is freed, and wasm is the one platform that says so

`OCCTXCAFTests` died on wasm inside `OCCTTObjApplicationCreateDocument` with

    Trap: indirect call type mismatch,
      expected FunctionType(parameters: [i32, i32, i32], results: [i32]),
      got      FunctionType(parameters: [i32],           results: [i32])

and the issue read that as a possible vtable or ABI disagreement between the headers the bridge
compiles against and the kernel it links: a class of defect no Apple build could detect, because
there the wrong slot is an indirect branch that happens to work.

It is not that. The slot is right, the vtable is right, and the **object is not there**.

## What was measured

| | |
|---|---|
| `./run.sh` | the sequence on wasm: traps, as #2897 reports |
| `./run.sh --native` | the same source on macOS arm64: **SIGSEGV**, exit 139 |
| `./run.sh --vtable-parity` | every vtable the bridge lays out against the archive's: no disagreement |
| `spike/` | the two excluded suites replayed through the shipped bridge and Swift wrapper |

## The mechanism

`OCCTTObjApplicationGetInstance` hands out a raw pointer to `TObj_Application::GetInstance()`'s
process-wide singleton and takes one `IncrementRefCounter()` for it.
`OCCTTObjApplicationRelease` gave it back with a bare `DecrementRefCounter()`.

A release with **no matching get** therefore did not fail and did not free anything. It took the
place of the one reference `GetInstance()`'s own function-local static `Handle` holds, leaving the
count one below the truth. That is what made it look harmless, and it is why
`Issue1588TObjApplicationReleaseTests.doubleReleaseDoesNotCorruptSingleton` performs exactly that
over-release and then passes.

The object dies later, in a caller that did nothing wrong: the next ordinary `occ::handle` to fall
out of scope decrements to zero, and `occ::handle::EndScope` calls `Delete()`, which is
`delete this`. `GetInstance()`'s static handle keeps pointing at the freed block. Every later
caller reads a vptr out of reclaimed memory and dispatches through it.

In the failing run the two are about 660 transcript lines apart: the over-release is at line 467 of
`OCCTXCAFTests.out` and the trap is at 1143, in `TObjApplicationTests.createDocument`.

`probe.cpp` is that sequence with nothing else in it, and prints the reference count at each step:

    PHASE 2: one unmatched release, which is what the test suite performs
      after GetInstance             refcount = 2
      after Release                 refcount = 1
      after the UNMATCHED one       refcount = 0   <-- one BELOW the static handle's own reference

## Why the trap says "type mismatch"

Because the word the garbage vptr points at is read as a function index, and wasm checks the type
of the table entry that index selects before it calls. Which function that is depends on what the
allocator put in the reclaimed block, so the message varies: the issue's run reported a type
mismatch against a one-parameter function, this probe reports
`indirect call to null element (uninitialized element 0)`, and the un-excluded suite reported
`uninitialized element 12`. All three are the same defect, and none of them is a signature
disagreement.

**Apple is exposed, and not benignly.** The same source on macOS arm64 is a SIGSEGV on the same
sequence, because an indirect branch through a reclaimed vptr is undefined behaviour everywhere.
The reason the macOS test suite does not crash today is only that `TObj_Application` keeps a
reference per open document, and the suite leaves documents open, so the count has further to fall
before it reaches zero. Nothing about that is a property anyone chose.

## The sweep: is any indirect call actually mistyped?

`vtable-parity.py` answers the question the issue asked, mechanically. It compares, for every
polymorphic class the bridge's own translation units lay out, clang's
`-fdump-vtable-layouts` slot list (the bridge's compile-time view, and the slot indices its
`call_indirect`s use) against the ordered `_ZTV` relocations in `Libraries/libOCCT-wasm.a` (the
vtables the program links). A disagreement in slot count, or in the name or arity at any slot,
would be exactly the defect #2897 suspected.

    ./run.sh --vtable-parity

See `transcript.txt` for the run. There is no disagreement.

## Files

| | |
|---|---|
| `probe.cpp` | the sequence against the kernel archive alone, with reference counts |
| `run.sh` | builds and runs it for wasm, for macOS (`--native`), and the sweep (`--vtable-parity`) |
| `vtable-parity.py` | the sweep |
| `spike/` | a Swift package that replays both excluded suites through the shipped bridge |
| `transcript.txt` | the measured output of each |
