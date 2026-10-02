// Run one wasm test-runner module under Node with the browser's WASI shim (#2894).
//
// WHY THIS EXISTS AND WHY IT IS NOT wasmkit. #2894 measured the same module file, byte for byte,
// under both runtimes: an OCCT exception thrown several frames below the bridge's `catch (...)` is
// caught under Node and reaches `std::terminate` under wasmkit 0.3.1. The compiler output is not the
// variable, so a suite run under wasmkit measures the interpreter's exception handling and not the
// target's. The target for #1689 is a browser.
//
// The shim is @bjorn3/browser_wasi_shim, the same pinned package #2052's browser rungs import, so a
// disagreement between this and the browser page isolates the browser rather than the WASI surface.
// Node's own `node:wasi` would be less code here and would measure something different.
//
// Usage: node wasm-test-node-runner.mjs <shim-dir> <module.wasm> [guest args...]
//
// Exits with the module's own exit code. A trap exits 70 and says so, because a trap and a failing
// test suite are different outcomes and the caller has to tell them apart: a trap ends the module,
// so every test after it is unreported.

import { readFile } from "node:fs/promises";
import { basename } from "node:path";
import { pathToFileURL } from "node:url";

const [, , shimDir, modulePath, ...guestArgs] = process.argv;
if (!shimDir || !modulePath) {
  console.error("usage: node wasm-test-node-runner.mjs <shim-dir> <module.wasm> [guest args...]");
  process.exit(2);
}

const { WASI, File, OpenFile, PreopenDirectory, ConsoleStdout, WASIProcExit } = await import(
  pathToFileURL(`${shimDir}/index.js`).href
);

// `/tmp` is what Foundation's `temporaryDirectory` resolves to once TMPDIR names it, and several
// suites write a fixture there and read it back. `/work` is a second writable preopen for anything
// that wants a directory of its own. Both are in-memory, so a file a test reads is one a test wrote,
// which is the stronger check: it proves a write reaches a readable inode rather than finding a file
// the host happened to leave lying about.
const WORK_DIR = "/work";
const TMP_DIR = "/tmp";
const workContents = new Map();
const tmpContents = new Map();

// Unbuffered per line and written straight through, so a suite that traps has already emitted
// everything up to the trap. wasmkit loses the tail of stdout when the module aborts, which cost a
// round of wrong conclusions in #2894; this does not.
const fds = [
  new OpenFile(new File([])), // 0, stdin: never read, but wasi-libc expects fd 0 to exist
  ConsoleStdout.lineBuffered((line) => process.stdout.write(`${line}\n`)), // 1
  ConsoleStdout.lineBuffered((line) => process.stderr.write(`${line}\n`)), // 2
  new PreopenDirectory(WORK_DIR, workContents), // 3
  new PreopenDirectory(TMP_DIR, tmpContents), // 4
];

const moduleName = basename(modulePath);
const args = [moduleName, ...guestArgs];
const env = [`TMPDIR=${TMP_DIR}`];

// `{ debug: false }` is REQUIRED, not a default: the shim's `Debug.enable` treats an absent value as
// true, so omitting it prints a `wasi:` line per path operation straight to console.log, interleaved
// with the guest's own output and into the transcript.
const wasi = new WASI(args, env, fds, { debug: false });

const bytes = await readFile(modulePath);
const module = await WebAssembly.compile(bytes);
const instance = await WebAssembly.instantiate(module, {
  wasi_snapshot_preview1: wasi.wasiImport,
});

try {
  process.exit(wasi.start(instance));
} catch (error) {
  if (error instanceof WASIProcExit) {
    process.exit(error.code);
  }
  // A trap. Swift Testing has printed whatever it got to, and the caller needs to know the run
  // ended rather than concluded.
  process.stderr.write(`TRAP: ${error.name}: ${error.message}\n`);
  process.exit(70);
}
