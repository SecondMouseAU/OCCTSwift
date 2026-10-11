#!/usr/bin/env python3
"""Over-approximate the bridge entry points the lifted OCCTCurveTests files reach (repo root).

For every identifier a lifted test calls (`.name(`, `Type.name(`, `name(` and property reads), find the
Swift declarations of that name under Sources/OCCTSwift, take each body by brace matching, and collect
the OCCT* calls in it. For each capitalised type the tests construct, every `init` body in the file
that declares it is added too. Over-approximation costs only more switches; it cannot hide a gap.
"""
import glob, re, subprocess, sys

lifted = subprocess.run(["git", "diff", "--name-only", "--diff-filter=AM", "origin/main", "HEAD", "--",
                         "Tests/OCCTCurveTests"], capture_output=True, text=True).stdout.split()
lifted = [f for f in lifted if f.endswith(".swift")]
names, types = set(), set()
for f in lifted:
    t = re.sub(r"//[^\n]*", "", open(f).read())
    names |= set(re.findall(r"\.(\w+)\b", t))
    types |= set(re.findall(r"\b([A-Z]\w+)\s*[\(\.]", t))
src = {f: open(f).read() for f in glob.glob("Sources/OCCTSwift/**/*.swift", recursive=True)}

def body(text, start):
    i = text.find("{", start)
    if i < 0:
        return ""
    d = 0
    for j in range(i, len(text)):
        if text[j] == "{": d += 1
        elif text[j] == "}":
            d -= 1
            if d == 0:
                return text[i:j + 1]
    return text[i:]

# a name declared in many files (count, first, point, ...) is a collection or generic accessor, not a
# test subject; following it would pull in half the bridge
decl_files = {}
for f, t in src.items():
    for m in re.finditer(r"\b(?:func|var)\s+(\w+)", t):
        decl_files.setdefault(m.group(1), set()).add(f)
found = set()
for f, t in src.items():
    for m in re.finditer(r"\b(?:func|var)\s+(\w+)", t):
        if m.group(1) in names and len(decl_files[m.group(1)]) <= 6:
            found |= set(re.findall(r"\b(OCCT\w+)\s*\(", body(t, m.end())))
    for ty in types:
        if re.search(r"\b(?:struct|class|enum|extension)\s+%s\b" % re.escape(ty), t):
            for m in re.finditer(r"\binit[?!]?\s*\(", t):
                found |= set(re.findall(r"\b(OCCT\w+)\s*\(", body(t, m.end())))
# A test file that imports OCCTBridge and calls a symbol itself sees the shadow and the import as equally
# visible: "ambiguous use of". Those symbols cannot be shadowed (injection-sweep-mechanics.md).
direct = set()
for f in glob.glob("Tests/**/*.swift", recursive=True):
    t = open(f).read()
    if re.search(r"^import OCCTBridge", t, re.M):
        direct |= set(re.findall(r"\b(OCCT\w+)\b", t))
print("\n".join(sorted(found - direct)))
