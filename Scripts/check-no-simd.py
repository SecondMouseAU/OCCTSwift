#!/usr/bin/env python3
"""Gate: no Swift file imports Apple's `simd` module or calls one of its `simd_` functions (#2759).

Apple's `simd` module exists on Apple platforms and nowhere else. Until #2759 the package papered
over that with `Sources/WASICompat/simd`, a second implementation of the same functions compiled
only for WebAssembly, so Apple and wasm ran different code for the same call, and the two differed
on `simd_normalize` of a zero vector until #2764 aligned them by hand. #2759 replaced every use with
plain-Swift helpers (`Sources/OCCTSwift/SIMDVectorOps.swift`) and package-owned matrix types
(`Matrix.swift`), so one implementation runs everywhere. This gate is what keeps it that way: the
first `import simd` or `simd_dot(` that comes back is the stand-in coming back with it.

WHAT IT FLAGS, in code only. Comments and string literals are stripped first, because the migration
notes legitimately name the old spellings:

  * `import simd` in any spelling (`@_exported import simd`, `import simd.vector`);
  * `canImport(simd)`, which is how a conditional re-introduction would be written;
  * any identifier beginning `simd_`, `matrix_` or `vector_`, which is Apple's C naming (`simd_dot`,
    `simd_float4x4`, `matrix_identity_float4x4`, `vector_float3`).

WHAT IT DELIBERATELY DOES NOT FLAG: the label `simd:` in `GeomDirection(simd:)` (a public argument
label of this package, nothing to do with the module), the Swift stdlib types `SIMD2`/`SIMD3`/
`SIMD4` and their `.sum()`, `pointwiseMin`, `pointwiseMax`, and the word `simd` in prose.

THE POPULATION is every `*.swift` under the roots in `ROOTS`, minus `EXEMPT`. The one exemption is
the stand-in itself, which exists only while test files that still import it do; the PR that migrates
the last such file deletes the stand-in, this exemption and the `Tests` gap in `ROOTS` together. A run
that finds fewer than `MINIMUM_FILES` Swift files in total exits 2 as a refusal rather than reporting
"clean" over an empty population, which is what a blind detector looks like.

Exit status: 0 clean, 1 a violation, 2 a refusal (wrong directory, empty population, bad option).
"""

import os
import re
import sys

ROOTS = ["Sources"]
EXEMPT = ["Sources/WASICompat/simd"]
MINIMUM_FILES = 200

IMPORT_RE = re.compile(r"\bimport\s+simd\b")
CAN_IMPORT_RE = re.compile(r"\bcanImport\s*\(\s*simd\s*\)")
IDENT_RE = re.compile(r"\b(?:simd|matrix|vector)_[A-Za-z0-9_]*")


def strip_comments_and_strings(text):
    """Return `text` with comments and string-literal contents blanked, newlines preserved.

    Handles line comments, nested block comments, quoted strings with escapes, triple-quoted
    multi-line strings, and `#`-delimited raw strings (any number of `#`). Replacing with spaces keeps line numbers exact.
    """
    out = []
    i = 0
    n = len(text)
    while i < n:
        c = text[i]
        nxt = text[i + 1] if i + 1 < n else ""
        if c == "/" and nxt == "/":
            while i < n and text[i] != "\n":
                out.append(" ")
                i += 1
            continue
        if c == "/" and nxt == "*":
            depth = 1
            out.append("  ")
            i += 2
            while i < n and depth:
                if text.startswith("/*", i):
                    depth += 1
                    out.append("  ")
                    i += 2
                elif text.startswith("*/", i):
                    depth -= 1
                    out.append("  ")
                    i += 2
                else:
                    out.append("\n" if text[i] == "\n" else " ")
                    i += 1
            continue
        if c == "#" or c == '"':
            hashes = 0
            j = i
            while j < n and text[j] == "#":
                hashes += 1
                j += 1
            if j < n and text[j] == '"':
                multiline = text.startswith('"""', j)
                quote = '"""' if multiline else '"'
                closer = quote + "#" * hashes
                start = j + len(quote)
                k = start
                while k < n:
                    if hashes == 0 and text[k] == "\\":
                        k += 2
                        continue
                    if text.startswith(closer, k):
                        break
                    k += 1
                end = min(k + len(closer), n)
                out.append(text[i:start].replace('"', " ").replace("#", " "))
                for ch in text[start:k]:
                    out.append("\n" if ch == "\n" else " ")
                out.append(" " * (end - k))
                i = end
                continue
        out.append(c)
        i += 1
    return "".join(out)


def violations_in(text):
    """Return [(line, kind, snippet)] for one file's text."""
    found = []
    code = strip_comments_and_strings(text)
    for number, line in enumerate(code.split("\n"), start=1):
        if IMPORT_RE.search(line):
            found.append((number, "import simd", line.strip()))
        if CAN_IMPORT_RE.search(line):
            found.append((number, "canImport(simd)", line.strip()))
        for m in IDENT_RE.finditer(line):
            found.append((number, "Apple simd identifier " + m.group(0), line.strip()))
    return found


def swift_files(root, roots, exempt):
    files = []
    for r in roots:
        base = os.path.join(root, r)
        for dirpath, dirnames, filenames in os.walk(base):
            rel_dir = os.path.relpath(dirpath, root)
            if any(rel_dir == e or rel_dir.startswith(e + os.sep) for e in exempt):
                dirnames[:] = []
                continue
            dirnames[:] = [d for d in dirnames if d != ".build"]
            for name in filenames:
                if name.endswith(".swift"):
                    files.append(os.path.join(rel_dir, name))
    return sorted(files)


def run(root, roots=None, exempt=None, minimum=MINIMUM_FILES):
    roots = ROOTS if roots is None else roots
    exempt = EXEMPT if exempt is None else exempt
    files = swift_files(root, roots, exempt)
    if len(files) < minimum:
        print(
            f"check-no-simd: refusing, found {len(files)} Swift files under {roots} "
            f"(expected at least {minimum}); is this the repo root?",
            file=sys.stderr,
        )
        return 2
    bad = []
    for rel in files:
        with open(os.path.join(root, rel), encoding="utf-8") as handle:
            text = handle.read()
        for number, kind, snippet in violations_in(text):
            bad.append((rel, number, kind, snippet))
    if bad:
        print(f"check-no-simd: {len(bad)} use(s) of Apple's simd module:")
        for rel, number, kind, snippet in bad:
            print(f"  {rel}:{number}: {kind}: {snippet}")
        print(
            "\nUse the plain-Swift helpers in Sources/OCCTSwift/SIMDVectorOps.swift (or, in tests, "
            "the target's SIMDTestHelpers.swift) and Matrix4x4F / Matrix3x3D. See #2759."
        )
        return 1
    print(f"check-no-simd: {len(files)} Swift files, no Apple simd import or call.")
    return 0


def self_test():
    failures = []

    def expect(name, text, kinds):
        got = sorted(k.split(" ")[0] if k.startswith("import") else k for _, k, _ in violations_in(text))
        want = sorted(kinds)
        if got != want:
            failures.append(f"{name}: expected {want}, got {got}")

    expect("clean", "let a = SIMD3<Double>(1, 2, 3)\nlet s = a.sum()\n", [])
    expect("import", "import simd\n", ["import"])
    expect("exported import", "@_exported import simd\n", ["import"])
    expect("import in comment", "// import simd\n/// simd_dot(a, b)\n", [])
    expect("block comment", "/* import simd\n simd_dot */\nlet x = 1\n", [])
    expect("nested block comment", "/* a /* b */ import simd */\nlet x = 1\n", [])
    expect("string literal", 'let s = "simd_dot and import simd"\n', [])
    expect("raw string", 'let s = #"simd_dot "quoted" "#\n', [])
    expect("multiline string", 'let s = """\nimport simd\nsimd_dot\n"""\n', [])
    expect("code after string", 'let s = "x"; let p = simd_dot(a, b)\n', ["Apple simd identifier simd_dot"])
    expect("call", "let d = simd_dot(a, b)\n", ["Apple simd identifier simd_dot"])
    expect("type", "var m: simd_float4x4\n", ["Apple simd identifier simd_float4x4"])
    expect("matrix constant", "let i = matrix_identity_float4x4\n", ["Apple simd identifier matrix_identity_float4x4"])
    expect("vector type", "let v: vector_float3\n", ["Apple simd identifier vector_float3"])
    expect("canImport", "#if canImport(simd)\n#endif\n", ["canImport(simd)"])
    expect("label is not the module", "let d = GeomDirection(simd: v)\nlet e = point.simd\n", [])
    expect("stdlib simd types", "let m = pointwiseMin(a, b)\nlet n = SIMD4<Float>.zero\n", [])
    expect("unrelated simd word", "let simdLike = 1\nlet mysimd_x = 2\n", [])
    expect("line numbers survive stripping", "/* x\ny */\nimport simd\n", ["import"])
    lines = [n for n, _, _ in violations_in("/* x\ny */\nimport simd\n")]
    if lines != [3]:
        failures.append(f"line number: expected [3], got {lines}")

    # The walker: exemption honoured, population floor refuses an empty tree.
    import contextlib
    import io
    import shutil
    import tempfile

    tmp = tempfile.mkdtemp(prefix="check-no-simd-")
    quiet = contextlib.redirect_stdout(io.StringIO())
    quiet_err = contextlib.redirect_stderr(io.StringIO())
    try:
        for rel, body in [
            ("Sources/A/a.swift", "let x = 1\n"),
            ("Sources/B/b.swift", "import simd\n"),
            ("Sources/WASICompat/simd/shim.swift", "public func simd_dot() {}\n"),
        ]:
            path = os.path.join(tmp, rel)
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w") as handle:
                handle.write(body)
        with quiet, quiet_err:
            if run(tmp, ["Sources"], ["Sources/WASICompat/simd"], minimum=1) != 1:
                failures.append("walker: the import in Sources/B must fail")
            os.remove(os.path.join(tmp, "Sources/B/b.swift"))
            if run(tmp, ["Sources"], ["Sources/WASICompat/simd"], minimum=1) != 0:
                failures.append("walker: the exempt directory must not be scanned")
            if run(tmp, ["Sources"], [], minimum=1) != 1:
                failures.append("walker: without the exemption the shim must fail")
            if run(tmp, ["Sources"], ["Sources/WASICompat/simd"], minimum=50) != 2:
                failures.append("walker: an under-populated tree must refuse with 2")
            if run(os.path.join(tmp, "nowhere"), ["Sources"], [], minimum=1) != 2:
                failures.append("walker: a missing root must refuse with 2")
    finally:
        shutil.rmtree(tmp)

    if failures:
        print("check-no-simd --self-test FAILED:")
        for f in failures:
            print("  " + f)
        return 1
    print("check-no-simd --self-test: ok")
    return 0


def main(argv):
    if len(argv) > 1 and argv[1] == "--self-test":
        return self_test()
    if len(argv) > 1:
        print("usage: check-no-simd.py [--self-test]", file=sys.stderr)
        return 2
    if not os.path.isdir("Sources"):
        print("check-no-simd: run from the repository root", file=sys.stderr)
        return 2
    return run(".")


if __name__ == "__main__":
    sys.exit(main(sys.argv))
