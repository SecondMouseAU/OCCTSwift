#!/usr/bin/env python3
"""Run every #3233 case against the three kernels (one process each) and write results/measure.json.
  measure.py <bin dir holding cdump_k5, cdump_main, cdump_new> <out json> [stem ...]"""
import json, os, subprocess, sys, concurrent.futures as cf
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cases3233 as C


def args_of(case, mode, alt=False):
    items = case.alt if (alt and case.alt) else case.items
    return [mode, case.shape] + ["%r:%s" % (r, ",".join("%.9g" % x for x in m)) for r, m in case.edges] + ["--"] + items


def parse(out):
    d = {}
    for l in out.splitlines():
        t = l.split()
        if not t:
            continue
        if t[0] == "STATUS":
            tag = t[1]
            if len(t) > 2 and t[2] in ("done",):
                d[tag] = {k: float(v) if "." in v else int(v) for k, v in (x.split("=") for x in t[3:])}
                d[tag]["done"] = True
            else:
                d[tag] = {"done": False, "why": " ".join(t[2:])}
        elif t[0] == "DIFF":
            d["diff"] = {k: float(v) for k, v in (x.split("=") for x in t[1:])}
    return d


def run(exe, argv, timeout=60):
    try:
        p = subprocess.run([exe] + argv, capture_output=True, text=True, timeout=timeout, start_new_session=True)
        d = parse(p.stdout)
        d["rc"] = p.returncode
        return d
    except subprocess.TimeoutExpired as e:
        out = e.stdout.decode() if isinstance(e.stdout, bytes) else (e.stdout or "")
        d = parse(out)
        d["timeout"] = True
        return d


if __name__ == "__main__":
    bindir, outp = sys.argv[1], sys.argv[2]
    only = sys.argv[3:]
    cases = [c for c in C.CASES if not only or c.stem in only]
    res = {}
    if os.path.exists(outp):
        res = json.load(open(outp))
    jobs = {}
    with cf.ThreadPoolExecutor(6) as ex:
        for c in cases:
            jobs[(c.stem, "new", "ref")] = ex.submit(run, os.path.join(bindir, "cdump_new"), args_of(c, "ref"))
            for k in ("k5", "main", "new", "61"):
                jobs[(c.stem, k, "main")] = ex.submit(run, os.path.join(bindir, "cdump_" + k), args_of(c, "cmp"))
            if getattr(c, "ridge", None):
                jobs[(c.stem, "new", "alt")] = ex.submit(run, os.path.join(bindir, "cdump_new"), ["ref", c.shape, "--"] + c.ridge)
        for (stem, k, w), f in jobs.items():
            res.setdefault(stem, {})[{"main": ("p61" if k == "61" else k), "alt": "alt", "ref": "ref"}[w]] = f.result()
    json.dump(res, open(outp, "w"), indent=1)
    for c in cases:
        r = res[c.stem]
        def s(x):
            if "kernel" not in x:
                return "HANG(>60s) before the kernel answered" if x.get("timeout") else "NO-OUTPUT rc=%s" % x.get("rc")
            k = x["kernel"]
            if not k["done"]: return "declined" if k.get("why") in ("declined", "") else k.get("why")
            d = x.get("diff", {})
            if x.get("timeout"): return "%s v=%.4f, then HANG in the boolean/tessellation (>60s)" % ("valid" if k["valid"] else "INVALID", k["vol"])
            return "%s v=%.4f d=(%.2e,%.2e)" % ("valid" if k["valid"] else "INVALID", k["vol"], d.get("kernel_minus_ref", -1), d.get("ref_minus_kernel", -1))
        ref = r["ref"].get("ref", {})
        print("%-20s ref:%s %.4f | k5 %s | main %s | new %s %s %s" % (c.stem, "ok" if ref.get("valid") else "BAD", ref.get("vol", -1), s(r["k5"]), s(r["main"]), s(r["new"]), "| 0061", s(r["p61"])), flush=True)
