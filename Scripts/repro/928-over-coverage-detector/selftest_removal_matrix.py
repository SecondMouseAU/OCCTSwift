#!/usr/bin/env python3
r"""The removal matrix for `Scripts/census-doc-occt-attribution.py --self-test`.

`okf/policies/prove-the-test-fails.md`: adding a `--self-test` is not the rule, watching it fail is.
Each row here disables exactly one guard in the detector, re-runs the self-test in-process, and
reports which cases fail. A guard whose removal fails nothing has a decorative case, not coverage,
and the policy's own history in this repo is a `--self-test` that passed 6/6 while one of its cases
proved nothing, twice in a row.

Every guard is disabled by patching the module object, never by editing the file, so a crash cannot
leave the tree modified.

    python3 Scripts/repro/928-over-coverage-detector/selftest_removal_matrix.py

Exits 1 if any row fails nothing, which is the outcome that means a case needs rewriting.
"""

from __future__ import annotations

import contextlib
import importlib.util
import io
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))


def fresh_detector():
    spec = importlib.util.spec_from_file_location(
        "_detector_matrix", os.path.join(ROOT, "Scripts", "census-doc-occt-attribution.py")
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def run_self_test(mod) -> tuple[int, list[str]]:
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        failures = mod.self_test()
    failed = [l.split("FAIL", 1)[1].strip() for l in buf.getvalue().split("\n") if "FAIL" in l]
    return failures, failed


# Each row: (label, a function that disables one guard on the module).
ROWS = [
    ("clause-scope negation markers",
     lambda m: setattr(m, "CLAUSE_MARKERS", [])),
    ("positional negation markers",
     lambda m: setattr(m, "POSITIONAL_MARKERS", [])),
    ("clause splitting (treat the whole claim as one clause)",
     lambda m: setattr(m, "CLAUSE_SPLIT", re.compile(r"(?!x)x"))),
    ("the enum-value tail rule (`TopAbs_EDGE`)",
     lambda m: _patch_enum_rule(m)),
    ("the package-prefix manifest (accept any `prefix_name` shape)",
     lambda m: _patch_prefix_rule(m)),
    ("the backtick-only rule for markdown",
     lambda m: _patch_quoted_rule(m)),
    ("the scoped `Class::Member` fallback spelling",
     lambda m: setattr(m, "attribution_names", lambda cls, member: {cls})),
    ("the class-existence check against the pinned headers",
     lambda m: _patch_existence(m)),
    ("the unresolved bucket (drop unresolvable claims silently)",
     lambda m: _patch_unresolved(m)),
    ("the fenced-block skip in the doc parser",
     lambda m: setattr(m, "FENCE", re.compile(r"(?!x)x"))),
    ("wrapped-bullet continuation lines",
     lambda m: setattr(m, "gather_continuation",
                       lambda lines, j, indent, text: (text, j))),
    ("heading subject tracking",
     lambda m: setattr(m, "_member_of", lambda _t: None)),
    ("the two-column table channel",
     lambda m: setattr(m, "TABLE_ROW", re.compile(r"(?!x)x"))),
    ("the bridge-header doc-comment channel",
     lambda m: setattr(m, "DOC_COMMENT", re.compile(r"(?!x)x"))),
    ("the declaration match under a header doc comment",
     lambda m: setattr(m, "DECL_NAME", re.compile(r"(?!x)x"))),
]


def _patch_enum_rule(m):
    orig = m.class_tokens

    def relaxed(text, prefixes, bare, quoted_only=True):
        out, seen = [], set()
        spans = m.BACKTICK_SPAN.findall(text) if quoted_only else [text]
        for span in spans:
            for mo in m.CLASS_TOKEN.finditer(span):
                pkg, rest, member = mo.group("pkg"), mo.group("rest"), mo.group("member")
                if rest is not None:
                    if pkg not in prefixes:
                        continue
                    cls = f"{pkg}_{rest}"          # the enum-value skip is what is removed
                else:
                    if not quoted_only or pkg not in bare:
                        continue
                    cls = pkg
                if (cls, member) not in seen:
                    seen.add((cls, member))
                    out.append((cls, member))
        return out

    m.class_tokens = relaxed
    return orig


def _patch_prefix_rule(m):
    orig = m.class_tokens

    def relaxed(text, prefixes, bare, quoted_only=True):
        return orig(text, prefixes | {"some", "any"}, bare, quoted_only)

    m.class_tokens = relaxed


def _patch_quoted_rule(m):
    orig = m.class_tokens
    m.class_tokens = lambda text, p, b, quoted_only=True: orig(text, p, b, False)



def _patch_existence(m):
    orig = m.run
    m.run = (lambda claims, reach, ms, p, b, header_names, lane=None:
             orig(claims, reach, ms, p, b, None, lane))


def _patch_unresolved(m):
    orig = m.run

    def dropping(claims, reach, ms, p, b, header_names, lane=None):
        findings, unresolved, checked = orig(claims, reach, ms, p, b, header_names, lane)
        return findings, [], checked

    m.run = dropping



def main() -> int:
    base = fresh_detector()
    base_failures, _ = run_self_test(base)
    print(f"baseline self-test: {base_failures} failures (expected 0)\n")
    if base_failures:
        print("the self-test does not pass on an unmodified tree; fix that before reading this "
              "matrix")
        return 1

    decorative = []
    for label, disable in ROWS:
        mod = fresh_detector()
        disable(mod)
        failures, names = run_self_test(mod)
        mark = "fails" if failures else "NOTHING FAILS"
        print(f"  {mark:13} {label}")
        for n in names:
            print(f"                  -> {n}")
        if not failures:
            decorative.append(label)

    print()
    if decorative:
        print("These guards can be removed with no self-test case failing. Each one's case is "
              "decorative and needs rewriting, not celebrating:")
        for label in decorative:
            print(f"  {label}")
        return 1
    print(f"every one of the {len(ROWS)} guards is load-bearing: removing it fails at least one "
          f"case.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
