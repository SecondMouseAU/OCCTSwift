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

import { readFile, readdir } from "node:fs/promises";
import { basename, dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const [, , shimDir, modulePath, ...guestArgs] = process.argv;
if (!shimDir || !modulePath) {
  console.error("usage: node wasm-test-node-runner.mjs <shim-dir> <module.wasm> [guest args...]");
  process.exit(2);
}

const { WASI, File, Directory, OpenFile, PreopenDirectory, ConsoleStdout, WASIProcExit } = await import(
  pathToFileURL(`${shimDir}/index.js`).href
);

// The shim reports every directory with `fs_rights_base` and `fs_rights_inheriting` of 0. wasi-libc's
// `faccessat` answers `access(path, W_OK)` from the rights on the directory fd it resolves the path
// against, so with 0 rights every `access(W_OK)` is EACCES, on a directory this filesystem lets the
// guest write to. `OSD_FileNode::Remove` guards its `rmdir` with exactly that call, so `rmdir` was
// never reached, and the shim's own `path_remove_directory` was never the problem (#3025).
// Reporting full rights on a preopen is accurate for these two: both are writable by construction.
class WritablePreopenDirectory extends PreopenDirectory {
  fd_fdstat_get() {
    const result = super.fd_fdstat_get();
    result.fdstat.fs_rights_base = ALL_RIGHTS;
    result.fdstat.fs_rights_inherited = ALL_RIGHTS;
    return result;
  }
}
const ALL_RIGHTS = (1n << 30n) - 1n; // WASI preview1 defines 30 right bits (0 through 29)

// `/tmp` is what Foundation's `temporaryDirectory` resolves to once TMPDIR names it, and several
// suites write a fixture there and read it back. `/work` is a second writable preopen for anything
// that wants a directory of its own. Both are in-memory, so a file a test reads is one a test wrote,
// which is the stronger check: it proves a write reaches a readable inode rather than finding a file
// the host happened to leave lying about.
const WORK_DIR = "/work";
const TMP_DIR = "/tmp";
const workContents = new Map();
const tmpContents = new Map();

// #3026: several suites read a `.brep` out of `Tests/<Target>/Fixtures/` by
// `URL(fileURLWithPath: #filePath).deletingLastPathComponent()`, and `#filePath` is the absolute HOST
// path of the test source, baked in when the module was compiled. The module is built from the
// checkout this script lives in, so `<repo>/Tests` is that path's prefix wherever the checkout is
// (a laptop, a CI runner), and it is derived here from the script's own location rather than
// written down. The guest sees it as a preopen of the same absolute name. Only `Fixtures`
// directories are loaded, from disk, once, so a test can read the files and cannot reach the
// source tree.
const TESTS_DIR = resolve(dirname(fileURLToPath(import.meta.url)), "..", "Tests");

async function loadDirectory(hostDir) {
  const entries = new Map();
  for (const entry of await readdir(hostDir, { withFileTypes: true })) {
    const full = join(hostDir, entry.name);
    if (entry.isDirectory()) {
      entries.set(entry.name, await loadDirectory(full));
    } else if (entry.isFile()) {
      entries.set(entry.name, new File(await readFile(full)));
    }
  }
  return new Directory(entries);
}

async function loadFixtureTree() {
  const targets = new Map();
  let names = [];
  try {
    names = await readdir(TESTS_DIR, { withFileTypes: true });
  } catch {
    return targets; // no Tests/ beside the script: nothing to expose, and no suite can need it
  }
  for (const target of names) {
    if (!target.isDirectory()) continue;
    try {
      const fixtures = await loadDirectory(join(TESTS_DIR, target.name, "Fixtures"));
      targets.set(target.name, new Directory(new Map([["Fixtures", fixtures]])));
    } catch (error) {
      // Only a missing directory means "this target has no Fixtures"; a permission or I/O error
      // must not quietly turn a fixture test back into an `.importFailed` (Kilo, #3138).
      if (error.code !== "ENOENT") throw error;
    }
  }
  return targets;
}

// Unbuffered per line and written straight through, so a suite that traps has already emitted
// everything up to the trap. wasmkit loses the tail of stdout when the module aborts, which cost a
// round of wrong conclusions in #2894; this does not.
const fds = [
  new OpenFile(new File([])), // 0, stdin: never read, but wasi-libc expects fd 0 to exist
  ConsoleStdout.lineBuffered((line) => process.stdout.write(`${line}\n`)), // 1
  ConsoleStdout.lineBuffered((line) => process.stderr.write(`${line}\n`)), // 2
  new WritablePreopenDirectory(WORK_DIR, workContents), // 3
  new WritablePreopenDirectory(TMP_DIR, tmpContents), // 4
  new PreopenDirectory(TESTS_DIR, await loadFixtureTree()), // 5, Tests/<Target>/Fixtures only
];

const moduleName = basename(modulePath);
const args = [moduleName, ...guestArgs];
// HOME is set because a native process always has one and #3025's `readHome()` asserts its own
// `getenv("HOME")` oracle is non-nil. It names `/work`, a writable preopen, so anything that resolves
// a path under it lands on a directory this filesystem actually has.
const env = [`TMPDIR=${TMP_DIR}`, `HOME=${WORK_DIR}`];

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
