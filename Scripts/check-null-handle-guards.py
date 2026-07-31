#!/usr/bin/env python3
"""Verify that every bridge function guards the geometry Handle, not just the wrapper pointer.

`OCCTCurve3DRef`, `OCCTCurve2DRef` and `OCCTSurfaceRef` are pointers to a wrapper struct whose
only field is an OCCT `Handle`. Checking the pointer says nothing about the handle, and a null
handle reaching OCCT is usually an unconditional dereference: `Scripts/repro/556-null-handle-guard-sweep`
measures 24 of the 35 distinct OCCT entry points this bridge passes such a handle into as an
uncatchable OS signal, which the enclosing `catch (...)` cannot intercept. So the opener has to
test both:

    if (!x || x->curve.IsNull()) return <the same fallback the catch below uses>;

#478 fixed the 14 functions that dereferenced the handle themselves; #556 fixed the 60 that pass
it to an OCCT API which dereferences it internally. This script is what keeps that at zero: it is
the same walk that produced both lists, so a new function that checks only the pointer is reported
the moment it is added.

A `DownCast(x->curve)` is NOT a use: down-casting a null handle returns a null handle, and every
such site in this bridge checks the cast result. Without that exclusion the walk reports several
hundred false positives.

Usage (from the repo root):

    python3 Scripts/check-null-handle-guards.py          # report unguarded sites
    python3 Scripts/check-null-handle-guards.py --quiet  # exit status only

Exit status is 1 when any site is unguarded, so this can gate a commit.
"""
import glob
import os
import re
import sys

SRC_DIR = 'Sources/OCCTBridge/src'

# wrapper parameter type -> the handle field it carries
WRAPPERS = {
    'OCCTCurve3DRef': 'curve',
    'OCCTCurve2DRef': 'curve',
    'OCCTSurfaceRef': 'surface',
}

# Sites deliberately left unguarded, with the reason. Keep this list empty-by-default: an entry
# is a promise that every caller checks both the pointer and the handle.
ALLOWED = {
    # Returns Geom2dGcc_QualifiedCurve by value, so it has no null-safe fallback to return.
    # All of its callers reject a null pointer and a null handle before calling.
    ('OCCTBridge_Geom2d.mm', 'makeQualifiedCurve'),
}

FUNC = re.compile(r'^(?:static\s+)?[A-Za-z_][\w:<>,\s\*&]*?\b(\w+)\s*\(([^;{]*?)\)\s*\{', re.M | re.S)
NOT_A_FUNCTION = {'if', 'for', 'while', 'switch', 'catch', 'return'}


def strip_comments(text):
    """Blank out comments and preserve every newline, so line numbers still line up."""
    out, i, n = [], 0, len(text)
    while i < n:
        if text.startswith('//', i):
            j = text.find('\n', i)
            j = n if j < 0 else j
            out.append(' ' * (j - i))
            i = j
        elif text.startswith('/*', i):
            j = text.find('*/', i + 2)
            j = n if j < 0 else j + 2
            out.append(''.join(c if c == '\n' else ' ' for c in text[i:j]))
            i = j
        elif text[i] == '"':
            j = i + 1
            while j < n and text[j] != '"':
                if text[j] == '\\':
                    j += 1
                j += 1
            out.append(text[i:j + 1])
            i = j + 1
        else:
            out.append(text[i])
            i += 1
    return ''.join(out)


def functions(text):
    """(name, params, body start, body end) for every function definition in the file."""
    for m in FUNC.finditer(text):
        name, params = m.group(1), m.group(2)
        if name in NOT_A_FUNCTION:
            continue
        start = i = m.end() - 1
        depth = 0
        while i < len(text):
            if text[i] == '{':
                depth += 1
            elif text[i] == '}':
                depth -= 1
                if depth == 0:
                    break
            i += 1
        yield name, params, start, i


def wrapper_params(params):
    """(name, handle field, whether it is an array) for each wrapper-typed parameter."""
    out = []
    for p in params.split(','):
        p = p.strip()
        for wrapper, field in WRAPPERS.items():
            if not re.search(r'\b' + wrapper + r'\b', p):
                continue
            m = re.search(r'(\w+)\s*(\[\s*\])?\s*$', p)
            if m and m.group(1) not in WRAPPERS:
                tail = p[p.index(wrapper) + len(wrapper):]
                out.append((m.group(1), field, '*' in tail or bool(m.group(2))))
            break
    return out


def unguarded_sites():
    """Every (file, line, function, parameter) whose handle reaches OCCT without an IsNull test."""
    found = []
    for path in sorted(glob.glob(os.path.join(SRC_DIR, '*.mm'))) + \
            sorted(glob.glob(os.path.join(SRC_DIR, '*.h'))):
        raw = open(path).read()
        text = strip_comments(raw)
        for name, params, body_start, body_end in functions(text):
            body = text[body_start:body_end + 1]
            for param, field, is_array in wrapper_params(params):
                if is_array:
                    use = re.compile(r'\b' + re.escape(param) + r'\s*\[[^\]]*\]\s*->\s*' + field + r'\b')
                else:
                    use = re.compile(r'\b' + re.escape(param) + r'\s*->\s*' + field + r'\b')
                first_real, guarded = None, False
                for u in use.finditer(body):
                    after = body[u.end():u.end() + 40]
                    before = body[max(0, u.start() - 80):u.start()]
                    if re.match(r'\s*\.\s*IsNull\s*\(', after):
                        guarded = True          # this occurrence IS the guard
                        continue
                    if re.search(r'DownCast\s*\(\s*$', before):
                        continue                # null-safe: DownCast(null) returns null
                    first_real = u
                    break
                if first_real is None or guarded:
                    continue
                if (os.path.basename(path), name) in ALLOWED:
                    continue
                line = text.count('\n', 0, body_start + first_real.start()) + 1
                found.append((os.path.basename(path), line, name, param, field,
                              raw.splitlines()[line - 1].strip()))
    return found


def main():
    quiet = '--quiet' in sys.argv
    sites = unguarded_sites()
    if not sites:
        if not quiet:
            print('All bridge functions guard the geometry handle as well as the wrapper pointer.')
        return 0
    if not quiet:
        print(f'{len(sites)} (function, argument) pair(s) reach OCCT with an unchecked handle:\n')
        for f, line, func, param, field, src in sites:
            print(f'  {f}:{line}  {func}({param})')
            print(f'      {src}')
            print(f'      want: if (!{param} || {param}->{field}.IsNull()) return <fallback>;')
    return 1


if __name__ == '__main__':
    sys.exit(main())
