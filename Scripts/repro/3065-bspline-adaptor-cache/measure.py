import subprocess, sys, statistics, re
kind, out, n = sys.argv[1], sys.argv[2], int(sys.argv[3])
def run(v, args, tmo=60):
    try:
        r = subprocess.run([f"{out}/{v}/contract"] + args, capture_output=True, text=True, timeout=tmo)
        return r.returncode, r.stdout.strip()
    except subprocess.TimeoutExpired:
        return "TIMEOUT", ""
if kind == "race":
    for v in ("stock", "patched"):
        for mode in ("shared", "copy"):
            wrongs, bad, tot, rcs = [], 0, 0, []
            for _ in range(n):
                rc, o = run(v, ["race", mode, "8", "20000"])
                m = re.match(r"wrong=(\d+) total=(\d+)", o)
                if rc != 0 or not m:
                    bad += 1; rcs.append(rc); continue
                wrongs.append(int(m[1])); tot = int(m[2])
            nz = sum(1 for w in wrongs if w > 0)
            print(f"{v:8s} {mode:7s} runs={n} abnormal(crash/hang)={bad} {rcs if rcs else ''} runs_with_wrong_points={nz}/{len(wrongs)} wrong_per_run min/median/max={min(wrongs, default=0)}/{statistics.median(wrongs) if wrongs else 0}/{max(wrongs, default=0)} of {tot}")
else:
    for mode, th in (("hot", 1), ("alt", 1), ("hot", 8), ("alt", 8), ("sharedhot", 8), ("sharedalt", 8)):
        for v in ("stock", "patched"):
            xs = []
            for _ in range(n):
                rc, o = run(v, ["perf", mode, str(th), "2000000" if th == 1 else "1000000"], 120)
                m = re.search(r"ns_per_call=([\d.]+)", o)
                if m: xs.append(float(m[1]))
            if xs: print(f"{mode:9s} threads={th} {v:8s} ns/call median={statistics.median(xs):8.1f} min={min(xs):8.1f} max={max(xs):8.1f} (n={len(xs)})")
            else: print(f"{mode:9s} threads={th} {v:8s} no result")
