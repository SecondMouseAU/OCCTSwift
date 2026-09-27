// #2052 rung 3: drive a real browser over CDP and read the page's verdict.
//
// This exists so rung 3 is a REPRODUCIBLE step rather than "open the page and look". A measurement
// nobody can re-run is not one this repo keeps, and a browser rung that needs a human at a keyboard
// could never become a CI job.
//
// No npm dependency: Chrome's DevTools Protocol is a WebSocket, and Node has had a global
// `WebSocket` since 22. puppeteer-core would be 40 MB to do the same four calls.
//
// Usage: node drive.mjs <url> [--chrome /path/to/binary] [--headed] [--timeout-ms N]

import { spawn } from "node:child_process";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const args = process.argv.slice(2);
const url = args.find((a) => !a.startsWith("--"));
const flag = (name, fallback) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 && args[i + 1] && !args[i + 1].startsWith("--") ? args[i + 1] : fallback;
};
if (!url) {
  console.error("usage: node drive.mjs <url> [--chrome <binary>] [--headed] [--timeout-ms N]");
  process.exit(2);
}

const CHROME = flag(
  "chrome",
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
);
const HEADED = args.includes("--headed");
const TIMEOUT_MS = Number(flag("timeout-ms", 600000));
const PORT = Number(flag("port", 9222));

// A throwaway profile, never the user's. Chrome refuses --remote-debugging-port against a profile
// another Chrome already has open, and pointing a driver at somebody's live browser session is not
// something a repro script should do.
const profile = mkdtempSync(join(tmpdir(), "occtswift-2052-chrome-"));

const chromeArgs = [
  `--remote-debugging-port=${PORT}`,
  `--user-data-dir=${profile}`,
  "--no-first-run",
  "--no-default-browser-check",
  // The module is 141 MB and the page allocates ~41 MiB of linear memory on top. Chrome's default
  // limits are fine; these two only remove noise from the measurement.
  "--disable-extensions",
  "--disable-background-networking",
  ...(HEADED ? [] : ["--headless=new"]),
  url,
];

console.error(`launching ${CHROME} ${HEADED ? "headed" : "headless"} on port ${PORT}`);
const chrome = spawn(CHROME, chromeArgs, { stdio: ["ignore", "ignore", "pipe"] });
let chromeStderr = "";
chrome.stderr.on("data", (d) => (chromeStderr += d.toString()));

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// BOTH address families, and this is not defensive padding. Chrome 153 on macOS binds the DevTools
// port to IPv6 `[::1]` ONLY: `lsof -nP -iTCP -sTCP:LISTEN -p <pid>` reports `TCP [::1]:9222`, and
// nothing is listening on `127.0.0.1:9222`. A driver that polls the IPv4 address alone simply never
// connects and reports a timeout, which reads exactly like the page failing to run. Measured
// 2026-09-27, and it cost a run to find.
const ENDPOINTS = [`http://[::1]:${PORT}`, `http://127.0.0.1:${PORT}`];
let endpoint = null;

/** Poll /json/version on both families until one answers, so we do not race Chrome's startup. */
async function waitForEndpoint(deadline) {
  while (Date.now() < deadline) {
    for (const base of ENDPOINTS) {
      try {
        const r = await fetch(`${base}/json/version`);
        if (r.ok) {
          endpoint = base;
          console.error(`devtools endpoint: ${base}`);
          return (await r.json()).webSocketDebuggerUrl;
        }
      } catch {}
    }
    await sleep(200);
  }
  throw new Error(
    `Chrome's debugging endpoint never came up on any of ${ENDPOINTS.join(", ")}.\n${chromeStderr}`,
  );
}

/** The page target for our URL, which is not the browser-level target /json/version gives. */
async function findPageTarget(deadline) {
  while (Date.now() < deadline) {
    const list = await (await fetch(`${endpoint}/json/list`)).json();
    const page = list.find((t) => t.type === "page" && t.url.startsWith(url.split("#")[0]));
    if (page?.webSocketDebuggerUrl) return page;
    await sleep(200);
  }
  throw new Error("no page target for the URL");
}

let exitCode = 1;
try {
  const deadline = Date.now() + TIMEOUT_MS;
  await waitForEndpoint(deadline);
  const page = await findPageTarget(deadline);
  console.error(`attached to ${page.url}`);

  const ws = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((res, rej) => {
    ws.onopen = res;
    ws.onerror = rej;
  });

  let nextId = 1;
  const pending = new Map();
  const consoleLines = [];
  ws.onmessage = (ev) => {
    const msg = JSON.parse(ev.data);
    if (msg.id && pending.has(msg.id)) {
      pending.get(msg.id)(msg);
      pending.delete(msg.id);
    } else if (msg.method === "Runtime.consoleAPICalled") {
      consoleLines.push(msg.params.args.map((a) => a.value ?? a.description ?? "").join(" "));
    } else if (msg.method === "Runtime.exceptionThrown") {
      // Surfaced, because a module that traps reaches the page as an uncaught exception and the
      // page's own `catch` would otherwise be the only place it appeared.
      consoleLines.push(
        `UNCAUGHT: ${msg.params.exceptionDetails.exception?.description ?? msg.params.exceptionDetails.text}`,
      );
    }
  };
  const send = (method, params = {}) =>
    new Promise((res) => {
      const id = nextId++;
      pending.set(id, res);
      ws.send(JSON.stringify({ id, method, params }));
    });

  await send("Runtime.enable");

  // Poll for the page's own result object rather than for a load event: `window.__RESULT__` is set
  // as the LAST statement of the module script, so its presence means the whole page ran. A load
  // event fires long before a 141 MB module has compiled.
  let result = null;
  while (Date.now() < deadline) {
    const r = await send("Runtime.evaluate", {
      expression: "window.__RESULT__ ? JSON.stringify(window.__RESULT__) : null",
      returnByValue: true,
      awaitPromise: false,
    });
    const v = r.result?.result?.value;
    if (v) {
      result = JSON.parse(v);
      break;
    }
    await sleep(500);
  }

  if (!result) {
    console.error(`timed out after ${TIMEOUT_MS} ms with no window.__RESULT__`);
    for (const l of consoleLines) console.error(`  console: ${l}`);
    throw new Error("no result");
  }

  console.log(JSON.stringify(result, null, 2));
  exitCode = result.verdict?.ok ? 0 : 1;
  console.error(result.verdict?.ok ? "VERDICT: PASS" : `VERDICT: FAIL ${JSON.stringify(result.verdict)}`);
} finally {
  chrome.kill("SIGTERM");
  try {
    rmSync(profile, { recursive: true, force: true });
  } catch {}
}
process.exit(exitCode);
