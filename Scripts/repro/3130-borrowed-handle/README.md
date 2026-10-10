# #3130: a borrowed `.handle` loses its owner before the C call runs

A scratch package that links the repo's `OCCTSwift` and calls bridge functions with `.handle`
read off different kinds of owner. Run in an optimised build, because a debug build extends every
lifetime to scope end and hides the whole class.

```bash
cd Scripts/repro/3130-borrowed-handle
unset OCCTSWIFT_BRIDGE_PREBUILT
swift build -c release -Xswiftc -enable-testing
for v in A RE RF TF TS NCM LM NW NS REL RS SPL SPLF SPS WHM WHE WHF WHT WHS; do
  for i in 1 2 3 4 5 6 7 8; do MallocScribble=1 MallocPreScribble=1 .build/release/probe $v; done
done
```

Measured on macOS arm64, `-c release`, 8 runs per variant under `MallocScribble`:

| variant | owner | result |
|---|---|---|
| A  | `edges[0].handle` into `OCCTEdgeSetSameParameter` | segfault 7/8, wrong answer 1/8 |
| RE | `edges[0].handle` into `OCCTEdgeGetLength` | segfault 7/8, 0.0 1/8 |
| RF | `faces[0].handle` into `OCCTFaceGetArea` | segfault 7/8, 0.0 1/8 |
| TF | `b.edges().first!.handle` | segfault 5/8, 0.0 3/8 |
| TS | `Shape.box(...)!.handle` | bus error 2/8, wrong `false` 6/8 |
| NCM, LM, NW, NS, REL, RS | owner bound to a named `let` or `for` variable | correct 8/8 |
| SPL, SPS | `let h = owner.handle`, owner unused afterwards, `h` used by later calls (`Document`, `Shape`) | correct 8/8 |
| SPLF | SPL inside `withExtendedLifetime(doc)` | correct 8/8 |
| WHM, WHE, WHF, WHT, WHS | the A, RE, RF, TF, TS shapes through `withHandle` | correct 8/8 |

Not reproduced here: the wasm builds (not this repo's job to touch), and any claim about iOS.

The regression test is `Tests/OCCTTopologyTests/TopoDS/Issue3130BorrowedHandleTests.swift`; it cannot fail in
a debug build, so the optimised run is
`swift test -c release -Xswiftc -enable-testing --filter Issue3130BorrowedHandle`.
