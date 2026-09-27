// #2052 rung 2: the Node control.
//
// Same shim, same harness, same in-memory preopens as the browser page. The only difference is
// where the bytes come from and that there is no browser. If this passes and the browser does not,
// the browser is the variable; if both fail, the shim or the in-memory filesystem is.
//
// Usage: node node-run.mjs <path-to-OCCTWasmSpike.wasm> [--json]

import { readFile } from "node:fs/promises";
import { runSpike, verdict } from "./harness.mjs";

const [, , modulePath, ...flags] = process.argv;
if (!modulePath) {
  console.error("usage: node node-run.mjs <path-to-OCCTWasmSpike.wasm> [--json]");
  process.exit(2);
}
const asJson = flags.includes("--json");

const bytes = await readFile(modulePath);
console.error(`module: ${modulePath} (${bytes.byteLength} bytes)`);

const run = await runSpike(bytes, asJson ? () => {} : (l) => console.error(l));
const v = verdict(run);

if (asJson) {
  console.log(JSON.stringify({ ...run, verdict: v }, null, 2));
} else {
  console.error("");
  console.error(`exit=${run.exitCode} trap=${run.trap ?? "none"}`);
  console.error(
    `compile=${run.timings.compileMs.toFixed(0)}ms ` +
      `instantiate=${run.timings.instantiateMs.toFixed(0)}ms ` +
      `run=${run.timings.runMs.toFixed(0)}ms ` +
      `memory=${run.memoryPages} pages`,
  );
  console.error(`work: ${JSON.stringify(run.work)}`);
  console.error(`tmp:  ${JSON.stringify(run.tmp)}`);
  for (const n of run.notes) console.error(n);
  console.error(v.ok ? "VERDICT: PASS" : `VERDICT: FAIL\n  ${v.problems.join("\n  ")}`);
}

process.exit(v.ok ? 0 : 1);
