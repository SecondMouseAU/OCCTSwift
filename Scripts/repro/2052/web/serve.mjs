// #2052: a static server for the browser rung.
//
// `python3 -m http.server` is not usable here: it does not map `.wasm` to `application/wasm`, and
// `WebAssembly.compileStreaming` refuses anything else, so the page would silently take its
// fetch-and-compile fallback and the measurement would be of the wrong code path.
//
// Usage: node serve.mjs <root-dir> [port]

import { createServer } from "node:http";
import { createReadStream, statSync } from "node:fs";
import { extname, join, normalize } from "node:path";

const root = process.argv[2];
const port = Number(process.argv[3] ?? 8052);
if (!root) {
  console.error("usage: node serve.mjs <root-dir> [port]");
  process.exit(2);
}

const TYPES = {
  ".html": "text/html; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".wasm": "application/wasm",
  ".json": "application/json",
};

createServer((req, res) => {
  // normalize() then strip any leading traversal, so a request cannot escape the staging dir.
  const rel = normalize(decodeURIComponent(new URL(req.url, "http://x").pathname)).replace(/^(\.\.[/\\])+/, "");
  const path = join(root, rel === "/" ? "index.html" : rel);
  let st;
  try {
    st = statSync(path);
  } catch {
    res.writeHead(404, { "content-type": "text/plain" });
    return res.end(`not found: ${rel}`);
  }
  res.writeHead(200, {
    "content-type": TYPES[extname(path)] ?? "application/octet-stream",
    "content-length": st.size,
    // No COOP/COEP. That is deliberate and is part of the measurement: #2169 chose the
    // non-threads wasip1 variant precisely so the browser consumer would NOT need cross-origin
    // isolation, so the page has to work without it. `crossOriginIsolated` is reported on the page.
    "cache-control": "no-store",
  });
  createReadStream(path).pipe(res);
}).listen(port, "127.0.0.1", () => {
  console.log(`serving ${root} at http://127.0.0.1:${port}/`);
});
