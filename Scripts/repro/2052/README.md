# #2052: the Phase 0 spike module in a real browser

`Scripts/repro/2052/run.sh` reproduces everything here.

## What this measures, and why it needed measuring

[#2175](https://github.com/SecondMouseAU/OCCTSwift/issues/2175) linked and ran the whole stack for
`wasm32-unknown-wasip1` and returned **GO with four conditions**. The second condition is the reason
this directory exists, quoted from the memo:

> **Nothing has run in a browser** (#2052). Everything here is `wasmkit` on macOS. The browser
> filesystem shape is inferred, not measured, and the import list is the reason to expect it to hold
> rather than a proof that it does.

Two specific things were inferred rather than measured, and both are load-bearing for #1689:

1. **That the module runs in a browser at all.** `wasmkit` is a standalone runtime. A browser is a
   different WebAssembly host with a different engine, a different exception implementation and a
   4 GB address-space model it does not fully control.
2. **That the file API works against an in-memory preopen.** Under `wasmkit` a preopen is
   `--dir /some/real/path`, and the guest's `open`/`read`/`write` reach a real filesystem. In a
   browser there is no filesystem at all: a preopen is a JavaScript object holding `Uint8Array`s.
   #2175 reasoned that the guest cannot tell the two apart, from the host-import list being
   identical either way, and said in terms that this was inference.

## The three rungs

Each rung changes exactly one variable against the rung below it, so a failure lands somewhere.

| Rung | Runtime | Preopen is | Where |
|---|---|---|---|
| 1 | `wasmkit` 0.3.1, macOS | a real directory on disk | `Scripts/repro/2175` |
| 2 | Node 26, `@bjorn3/browser_wasi_shim` 0.4.2 | JavaScript objects, in memory | `./run.sh node` |
| 3 | a real browser, same shim | JavaScript objects, in memory | `./run.sh serve`, then load the page |

Rung 2 is the control and is the reason rung 3's result can be attributed. If 2 passes and 3 fails,
the browser is the variable. If both fail, the shim or its in-memory filesystem is, and the module
is exonerated either way. **`web/harness.mjs` is imported unchanged by both runners**, which is what
makes that inference valid rather than approximate: the two rungs differ in their host and in where
the module bytes come from, and in nothing else.

## The module

Not rebuilt here. This issue is about the host side, and rebuilding costs a wasi-sdk, a Swift wasm
SDK and a 69-minute OCCT build.

| | |
|---|---|
| path | `Scripts/repro/2175/spike/.build/out/Products/Release-webassembly-wasm32/OCCTWasmSpike.wasm` |
| size | 141,861,273 bytes |
| sha256 | `3ff64f6b8cfcad9d23333bbd562ee55b3157e6c5461d2b387498b42198d8a774` |
| built from | `f58bed16`, the merged #2175 work |

`run.sh` checks that sha256 and reports a mismatch rather than failing, since rebuilding it is
legitimate. Every exact byte count below was taken against that binary.

## The cases

Whatever `Scripts/repro/2175/spike` reports, because the point is to compare like with like.
`Scripts/repro/2175/README.md` explains what each one is for; the short version is that the two
must-fail cases are the load-bearing ones, since #2171 measured that a build with the exception
flags missing returns correct boxes, correct fuses and correct STEP files and answers every error by
trapping.

**The set has grown twice since the three-rung comparison below was taken**, which is dated and is
left as measured: #2894 added `unwind-depth-1` and `unwind-depth-n`, the same exception at two
unwind depths, and #3021 added `occt-output-capture`. The live list is `EXPECTED_CASES` in
[`web/harness.mjs`](web/harness.mjs), and it is membership rather than a count, so neither addition
reddened anything here until somebody looked. Add a case there in the same change that adds it to
the spike.

## The result: all three rungs agree, case for case

Measured 2026-09-27, macOS 27.0.0, arm64.

| Case | Rung 1, `wasmkit` | Rung 2, Node | Rung 3, Chrome 153 |
|---|---|---|---|
| `box` | volume 6000.0, 6/12/8 | **same** | **same** |
| `fuse` | volume 1875.0, 12 faces, valid | **same** | **same** |
| `step-export` | 36,189 bytes, `ISO-10303-21;` | **same** | **same** |
| `step-import` | volume 1875.0, 12 faces | **same** | **same** |
| `must-fail-raise` | `nil`, 1 record, `Standard_DomainError` | **same** | **same** |
| `must-fail-internal` | throws `IFSelect_RetFail`, **0** bridge records | **same** | **same** |
| exit code | 0 | 0 | 0 |
| trap | none | none | none |

**Not "equivalent", identical.** The STEP file is 36,189 bytes in all three, the fused volume is
1875.0 in all three, and the two must-fail cases produce the same record counts. The byte count is
the useful one: a STEP writer that behaved differently against an in-memory filesystem would be very
unlikely to land on the same total.

The two must-fail cases are what make the other four mean anything, and both behaved in the browser.
`Shape.box(0, 0, 0)` raises `Standard_DomainError` inside `TKPrim`, the unwinder crosses from OCCT
into the bridge's outermost `catch (...)`, and Swift receives `nil` with exactly one diagnostic
record. **A trap would have reached the page as an uncaught `RuntimeError`**, which `drive.mjs`
reports separately for this reason. It did not happen.

## Chrome, headless and headed

| | headless | headed |
|---|---|---|
| user agent | `HeadlessChrome/153.0.0.0` | `Chrome/153.0.0.0` |
| verdict | PASS | PASS |
| `compileStreaming`, 141,861,273 bytes | 294 ms | 254 ms |
| instantiate | 14 ms | 13 ms |
| `_start`, all six cases | 301 ms | 342 ms |
| wall clock, fetch to verdict | 616 ms | 615 ms |
| linear memory | 652 pages = 40.8 MiB | 652 pages = 40.8 MiB |

Headed as well as headless, because a headless-only result would leave "it works in a real browser"
resting on the mode that is least like one.

**Under a second, fetch to verdict, for a 141 MB module doing two STEP operations.** That is over
localhost with no compression, so it is a compile-and-run figure and not a load-time one. It does
say that neither compilation nor the kernel is the thing that would make a browser app feel slow.

## The two inferences #2175 flagged, now measured

### 1. No cross-origin isolation is needed

| | |
|---|---|
| `crossOriginIsolated` | **false** |
| `SharedArrayBuffer` | **absent** |
| `navigator.hardwareConcurrency` | 10, and the module uses one thread |

`serve.mjs` deliberately sends **no** COOP or COEP headers, so this is a measurement and not a
default. #2169 chose the non-threads `wasip1` variant over `wasip1-threads` partly on the grounds
that the threads variant "forces COOP/COEP cross-origin isolation on the browser consumer". That
reasoning is now confirmed from the other side: the non-threads module needs none of it. **A
consumer can serve this from an ordinary static host**, with no header configuration, no
`Cross-Origin-Embedder-Policy`, and no consequent breakage of their own third-party embeds.

### 2. The in-memory preopen behaves like a real directory

This is the one #2175 could not check at all, because there the files were on disk.

After the run, the `/work` preopen, which is a plain JavaScript `Map` the page owns, contains:

| entry | bytes | written by |
|---|---|---|
| `spike-fused.step` | 36,189 | `Exporter.writeSTEP`, case 3 |
| `spike-broken.step` | 33 | `Data.write(to:)`, case 5b |

Both were created by the guest during the run. The harness starts with **empty** maps for exactly
this reason: a prepared file would have shown that a read works, and not that a write reaches a
readable inode in the same filesystem, which is what case 4 then does by reading `spike-fused.step`
back and getting the same solid.

`/tmp` is **empty** afterwards, and that is also correct rather than a gap: `Exporter.stepData`
writes a `UUID`-named file there, reads it back and unlinks it. The note line reports the bytes
came through:

```
note stepData   bytes=36189 via FileManager.default.temporaryDirectory = /tmp
```

so **the bytes-out convenience works in a browser**, with `TMPDIR=/tmp` in the environment and
`/tmp` preopened. 36,189 bytes, the same as the path-taking export.

### What this settles for #1689

STEP bytes reached JavaScript with no filesystem involved at any point. The guest wrote to a
preopen the page owns, so the bytes are already a `Uint8Array` in page scope: a download is a `Blob`
away, and handing bytes *in* is `new File(bytes)` in the map before the run. **No bytes-in/bytes-out
variant of the OCCT or OCCTSwift API is needed**, which is what #2175 predicted from `wasmkit` and
what this confirms where it actually matters.

## What is still NOT measured

Said plainly, because this directory's whole purpose is that an inference was recorded as one.

- **One browser engine.** Chrome 153 only. No Firefox, no Safari. Safari matters most, since it has
  historically been the last to ship WebAssembly features, and `-fwasm-exceptions` is exactly the
  kind of feature that could differ.
- **No JavaScriptKit.** The consumer #1689 describes is a SwiftWasm app using JavaScriptKit, and
  this is a plain WASI command module: it runs `_start` and exits. A reactor module that stays
  resident and answers calls from JavaScript is a different shape, and is Phase 5.
- **Localhost, uncompressed, warm.** Not a cold cache over a real network, which is the number a
  product decision about size would need, and which belongs to #2761.
- **Six calls.** Still not a test suite. Phase 0's third condition is untouched by this.

## Reproducing

```bash
cd Scripts/repro/2052
./run.sh stage                     # fetch the pinned shim, stage module + page
./run.sh node                      # rung 2. Asserts; exits non-zero on any failed case
./run.sh serve                     # rung 3. Then, in another shell:
node .stage/drive.mjs http://127.0.0.1:8052/            # headless
node .stage/drive.mjs http://127.0.0.1:8052/ --headed --port 9223
```

`SPIKE_MODULE=/path/to/OCCTWasmSpike.wasm` points it at your own build; `run.sh` reports a sha256
mismatch rather than failing, since rebuilding is legitimate.

## Three things that cost a run each

Recorded because each one produces a symptom that reads as "the module is broken".

1. **Chrome binds its DevTools port to IPv6 only, in headless mode.**
   `lsof -nP -iTCP -sTCP:LISTEN -p <pid>` reports `TCP [::1]:9222`, and nothing answers on
   `127.0.0.1:9222`. A driver polling the IPv4 address alone times out, which looks exactly like the
   page never finishing. **Headed Chrome binds IPv4**, measured in the same session on port 9223, so
   testing only one mode would have hidden it. `drive.mjs` polls both families.
2. **The shim's debug logging is ON unless you explicitly pass `{ debug: false }`.**
   `Debug.enable` is `enabled === undefined ? true : enabled`, so `new WASI(args, env, fds)` with no
   options object enables per-syscall logging. It goes to `console.log` rather than to the guest's
   stdout, so in the browser it lands in devtools and not in the transcript.
3. **`npm init -y` refuses a directory whose name starts with a dot**, with
   `Invalid name: ".stage"`. Under `set -e` with output redirected, the staging step ends silently
   and the next command reports a missing directory. `run.sh` writes the manifest itself.
