// #2052: the browser runtime measurement for the Phase 0 spike module.
//
// This file is the WHOLE experiment, and it is imported unchanged by both runners:
//
//   node-run.mjs   rung 2, Node with the browser shim and in-memory preopens
//   index.html     rung 3, a real browser with the same shim and the same preopens
//
// Sharing it is the point. #2175 ran the module under `wasmkit`, where a preopen is a real
// directory on disk, and recorded the browser filesystem shape as INFERRED rather than measured.
// Two things could make the inference wrong: the shim's in-memory filesystem behaving differently
// from a real one, or the browser behaving differently from Node. One file for both runners means
// a disagreement between the rungs isolates exactly one of those, instead of leaving both open.
//
// Nothing here knows anything about OCCT. The module is the unmodified Release build from
// Scripts/repro/2175; see this directory's README.md for its sha256.

import {
  WASI,
  File,
  OpenFile,
  PreopenDirectory,
  ConsoleStdout,
  WASIProcExit,
} from "./browser_wasi_shim/index.js";

/// The directory the guest is told to work in, as argv[1].
///
/// It is a preopen NAME and not a host path: under `wasmkit` the same argument was a real directory
/// that the host had to create first. That asymmetry is the thing being measured, so the name is
/// deliberately not `/tmp` or anything the host would have anyway.
export const WORK_DIR = "/work";

/// `Exporter.stepData` writes to `FileManager.default.temporaryDirectory` and reads back, so the
/// bytes-out convenience works or not purely on whether this is preopened. #2175 reported it rather
/// than asserting it, and so does this.
export const TMP_DIR = "/tmp";

/// The six cases the module reports, in the order it prints them. Used to check that a run that
/// exits 0 actually ran everything, because an exit code of 0 is also what a module that printed
/// nothing and fell out of `_start` would give.
export const EXPECTED_CASES = [
  "box",
  "fuse",
  "step-export",
  "step-import",
  "must-fail-raise",
  "must-fail-internal",
];

/**
 * Run the spike module once and return everything observable about the run.
 *
 * @param {WebAssembly.Module|BufferSource} moduleOrBytes an already-compiled module, or its bytes
 * @param {(line: string) => void} [log] called per stdout/stderr line as it arrives
 * @returns {Promise<object>} the run record: exit code, lines, per-case verdicts, timings, and the
 *   contents of both preopened directories after the run
 */
export async function runSpike(moduleOrBytes, log = () => {}) {
  const lines = [];
  const record = (stream) => (line) => {
    lines.push({ stream, line });
    log(`[${stream}] ${line}`);
  };

  // Empty maps, so every file the run reads is one the run itself wrote. The STEP file the import
  // case reads back and the malformed file the last case parses are both created by the guest.
  // Handing it a prepared file would test less: it would not show that a WRITE reaches a readable
  // inode in the same filesystem.
  const workContents = new Map();
  const tmpContents = new Map();

  const fds = [
    new OpenFile(new File([])), // 0, stdin: never read, but wasi-libc expects fd 0 to exist
    ConsoleStdout.lineBuffered(record("stdout")), // 1
    ConsoleStdout.lineBuffered(record("stderr")), // 2
    new PreopenDirectory(WORK_DIR, workContents), // 3
    new PreopenDirectory(TMP_DIR, tmpContents), // 4
  ];

  // argv[1] is the directory, exactly as `wasmkit run --dir <path> <module> <path>` passed it.
  const args = ["OCCTWasmSpike", WORK_DIR];
  // TMPDIR so Foundation's temporaryDirectory resolves to the preopen rather than to a guess.
  const env = [`TMPDIR=${TMP_DIR}`];

  // `{ debug: false }` is REQUIRED and not a default. The shim's Debug.enable is
  // `enabled === undefined ? true : enabled`, so constructing a WASI with no options object, or
  // with one that omits `debug`, turns per-syscall logging ON. Measured: without it the run prints
  // a `wasi:` line per path operation, straight to console.log rather than to the guest's stdout,
  // which in the browser page would land in the devtools console and not in the transcript.
  const wasi = new WASI(args, env, fds, { debug: false });

  const compileStart = performance.now();
  const module =
    moduleOrBytes instanceof WebAssembly.Module
      ? moduleOrBytes
      : await WebAssembly.compile(moduleOrBytes);
  const compileMs = performance.now() - compileStart;

  const instantiateStart = performance.now();
  const instance = await WebAssembly.instantiate(module, {
    wasi_snapshot_preview1: wasi.wasiImport,
  });
  const instantiateMs = performance.now() - instantiateStart;

  // `wasi.start` throws WASIProcExit for a non-zero exit, and the module exits with its failure
  // count, so a throw here is a RESULT and not an error. Anything else is a real failure: a trap
  // reaches this catch as a RuntimeError, which is precisely the outcome #2171 says an
  // exception-flag miss produces.
  let exitCode = 0;
  let trap = null;
  const runStart = performance.now();
  try {
    exitCode = wasi.start(instance);
  } catch (e) {
    if (e instanceof WASIProcExit) {
      exitCode = e.code;
    } else {
      trap = e;
      exitCode = null;
    }
  }
  const runMs = performance.now() - runStart;

  return {
    exitCode,
    trap: trap ? `${trap.name}: ${trap.message}` : null,
    lines,
    cases: parseCases(lines),
    notes: lines.filter((l) => l.line.startsWith("note ")).map((l) => l.line),
    timings: { compileMs, instantiateMs, runMs },
    // What the run left behind, which is the filesystem measurement: names and byte counts of
    // every inode in each preopen. An empty `/work` after a run that claims to have exported a
    // STEP file would mean the write went nowhere and the read came from somewhere else.
    work: describeDir(workContents),
    tmp: describeDir(tmpContents),
    memoryPages: instance.exports.memory?.buffer?.byteLength / 65536 || null,
  };
}

/** Turn the module's `case <name> PASS|FAIL  <detail>` lines into a name -> {passed, detail} map. */
function parseCases(lines) {
  const cases = {};
  for (const { line } of lines) {
    const m = /^case\s+(\S+)\s+(PASS|FAIL)\s*(.*)$/.exec(line);
    if (m) cases[m[1]] = { passed: m[2] === "PASS", detail: m[3].trim() };
  }
  return cases;
}

/** Name and size of every entry in a preopen's contents map, sorted, for a stable record. */
function describeDir(contents) {
  return [...contents.entries()]
    .map(([name, inode]) => ({
      name,
      bytes: inode?.data ? inode.data.byteLength : null,
      kind: inode?.data ? "file" : "dir",
    }))
    .sort((a, b) => a.name.localeCompare(b.name));
}

/**
 * Judge a run record. Separate from running it so both runners apply identical criteria, and so
 * the criteria are stated in one place rather than implied by whichever assertions a runner wrote.
 */
export function verdict(run) {
  const problems = [];
  if (run.trap) problems.push(`the module trapped: ${run.trap}`);
  if (run.exitCode !== 0) problems.push(`exit ${run.exitCode}, expected 0 (it is the failure count)`);
  for (const name of EXPECTED_CASES) {
    const c = run.cases[name];
    if (!c) problems.push(`case ${name} never reported`);
    else if (!c.passed) problems.push(`case ${name} FAILED: ${c.detail}`);
  }
  // The filesystem assertion, and the reason this harness looks at the preopens at all: the guest
  // claimed to write a STEP file, so a readable inode of non-trivial size must exist in the
  // in-memory preopen afterwards. #2175 could not check this, because there the file was on disk.
  const step = run.work.find((e) => e.name === "spike-fused.step");
  if (!step) problems.push(`no spike-fused.step in ${WORK_DIR} after the run`);
  else if (!step.bytes) problems.push(`spike-fused.step is present but empty`);
  return { ok: problems.length === 0, problems };
}
