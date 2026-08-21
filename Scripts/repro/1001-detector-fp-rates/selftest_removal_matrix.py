#!/usr/bin/env python3
"""Prove the two detectors changed by #1001 have load-bearing guards, not decorative ones.

`prove-the-test-fails.md` is explicit that adding a `--self-test` is not the rule and watching it
fail is. So each mechanism below is switched off in memory, one at a time, and the detector's own
fixture battery is re-run. A row that leaves the case count unchanged is a guard doing nothing OR a
case proving nothing, and either way it is reported rather than celebrated.

    python3 Scripts/repro/1001-detector-fp-rates/selftest_removal_matrix.py
"""

import importlib.util
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
COVERAGE = os.path.join(ROOT, "Scripts", "repro", "385-coverage-sample")

_counter = [0]


def fresh(which):
    _counter[0] += 1
    path = os.path.join(COVERAGE, f"detect-{which}.py")
    spec = importlib.util.spec_from_file_location(f"_m{_counter[0]}", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# --- detect-hardcoded-arguments.py -------------------------------------------------------------

def hardcoded_rows():
    def r1(m):
        original = m.strip_noise
        m.strip_noise = lambda t: original(t.replace('"', "'"))

    def r2(m):
        m.strip_noise = lambda t: t

    def r3(m):
        """Whole-file scanning reverts to the first version's line-by-line loop."""
        original = m.scan_text

        def per_line(text, path="<text>"):
            out = []
            for i, line in enumerate(text.split("\n"), 1):
                for row in original(line, path):
                    out.append((path, i, row[2], row[3], row[4]))
            return out

        m.scan_text = per_line

    def r4(m):
        """Balanced-paren scanning reverts to the first version's paren-free argument class."""
        def shallow(text, open_at):
            j = open_at + 1
            while j < len(text):
                if text[j] == ')':
                    return j
                if text[j] in '(;':
                    return -1
                j += 1
            return -1

        m.matching_paren = shallow

    def r5(m):
        m.SKIP_ARG = set()

    def r6(m):
        """The two-literal threshold effectively drops to one."""
        original = m.split_top_level
        m.split_top_level = lambda args: original(args) + original(args)

    def r7(m):
        m.OCCT_PREFIXES = ("",)

    return [
        ("R1  string literals no longer blanked", r1),
        ("R2  comments no longer blanked", r2),
        ("R3  whole-file scanning reverted to line-by-line", r3),
        ("R4  balanced-paren scanning reverted to a paren-free class", r4),
        ("R5  SKIP_ARG emptied", r5),
        ("R6  the two-literal threshold effectively lowered", r6),
        ("R7  the OCCT-class filter removed", r7),
    ]


# --- detect-dead-parameters.py -----------------------------------------------------------------

def dead_rows():
    def r1(m):
        original = m.strip_noise
        m.strip_noise = lambda t: original(t.replace('"', "'"))

    def r2(m):
        m.strip_noise = lambda t: t

    def r3(m):
        """The unnamed-parameter rule reverts to the first version's Ref/OCCT name exemption."""
        def old(param):
            p = param.strip().replace("_Nonnull", "").replace("_Nullable", "")
            w = re.findall(r'\b([A-Za-z_]\w*)\s*(?:\[\s*\])?$', p)
            types = {"void", "const", "int32_t", "int64_t", "double", "float", "bool", "char",
                     "unsigned", "size_t"}
            if w and w[0] not in types and not w[0].startswith("OCCT") \
                    and not w[0].endswith("Ref"):
                return w[0]
            return None

        m.parameter_name = old

    def r4(m):
        """The unnamed-parameter exemption is dropped: the last token is always taken as a name."""
        def always(param):
            cleaned = re.sub(r'\[\s*\]', ' ', param)
            cleaned = re.sub(r'[\*&]', ' ', cleaned)
            tokens = [t for t in re.findall(r'[A-Za-z_]\w*', cleaned) if t not in m.QUALIFIERS]
            return tokens[-1] if tokens else None

        m.parameter_name = always

    def r5(m):
        """The brace-body requirement is dropped, so a declaration counts as a definition."""
        m.SIG = re.compile(r'^[A-Za-z_][\w \*\_\(\)]*?\b(OCCT[A-Za-z0-9_]+)\s*\(([^)]*)\)', re.M)

    return [
        ("R1  string literals no longer blanked", r1),
        ("R2  comments no longer blanked", r2),
        ("R3  unnamed-parameter rule reverted to the Ref/OCCT exemption", r3),
        ("R4  unnamed-parameter exemption dropped entirely", r4),
        ("R5  the brace-body requirement dropped", r5),
    ]


def score_hardcoded(mod):
    ok = 0
    for _name, src, expected in mod.SELF_TEST:
        try:
            if len(mod.scan_text(src)) == expected:
                ok += 1
        except Exception:
            pass
    return ok, len(mod.SELF_TEST)


def score_dead(mod):
    ok = 0
    for _name, src, expected in mod.SELF_TEST:
        try:
            got = sorted(d for row in mod.scan_text(src) for d in row[3])
            if got == sorted(expected):
                ok += 1
        except Exception:
            pass
    return ok, len(mod.SELF_TEST)


def run(which, rows, scorer):
    print(f"\n=== detect-{which}.py")
    base_ok, total = scorer(fresh(which))
    print(f"  {'baseline':<60} {base_ok}/{total}")
    decorative = []
    for label, remove in rows:
        mod = fresh(which)
        remove(mod)
        ok, _ = scorer(mod)
        dropped = ok < base_ok
        if not dropped:
            decorative.append(label)
        print(f"  {label:<60} {ok}/{total}{'' if dropped else '   <- NO CASE DROPPED'}")
    return base_ok == total, decorative


def main():
    clean1, dec1 = run("hardcoded-arguments", hardcoded_rows(), score_hardcoded)
    clean2, dec2 = run("dead-parameters", dead_rows(), score_dead)

    print("\nThe one mechanism deliberately absent from the matrix")
    print("  split_top_level (hardcoded-arguments). Naive comma splitting cannot OVER-count here,")
    print("  because KNOB is anchored and a fragment torn out of a nested call carries a paren")
    print("  ('Geom_Baz(1e-6' or '1e-6)'), which never matches. Checked rather than assumed: no")
    print("  arrangement of nested calls and literals changes the reported count. It is kept")
    print("  because it makes the reported LITERAL LIST correct, not the count, and the fixture")
    print("  battery asserts counts. Recording that is the point; claiming it as coverage is not.")

    for which, dec in (("hardcoded-arguments", dec1), ("dead-parameters", dec2)):
        if dec:
            print(f"\nDECORATIVE in detect-{which}.py, needs rewriting rather than celebrating:")
            for label in dec:
                print(f"  {label}")

    return 0 if (clean1 and clean2 and not dec1 and not dec2) else 1


if __name__ == "__main__":
    sys.exit(main())
