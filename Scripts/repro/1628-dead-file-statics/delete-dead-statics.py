"""Delete dead file-static definitions named on the command line, one file at a time.

Takes the census's own verdicts, so the population deleted is the population measured. Removes each
definition's declaration line through its closing brace, plus the contiguous `//` comment block
immediately above it, EXCEPT `// MARK:` lines: a doc comment describes the function being deleted and
would become a comment about nothing, while a MARK is a section header whose scope is wider than one
function.
"""
import importlib.util, sys, collections

spec = importlib.util.spec_from_file_location("c", "Scripts/census-dead-file-statics.py")
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)

names = set(sys.argv[1:])
if not names:
    raise SystemExit("usage: delete.py <helperName> ...")

r = m.run_census()
targets = [d for d in r["dead"] if d["name"] in names]
unseen = names - {d["name"] for d in targets}
if unseen:
    raise SystemExit(f"not reported dead anywhere: {sorted(unseen)}")

by_file = collections.defaultdict(list)
for t in targets:
    by_file[t["file"]].append(t)

total = 0
for path, group in sorted(by_file.items()):
    lines = open(path).read().split("\n")
    drop = set()
    for t in sorted(group, key=lambda x: -x["line"]):
        start = t["line"] - 1  # 0-based declaration line
        end = t["end_line"] - 1  # 0-based closing brace line
        # Walk back over the doc comment that belongs to this definition.
        i = start - 1
        while i >= 0:
            stripped = lines[i].strip()
            if not stripped.startswith("//") or stripped.startswith("// MARK:"):
                break
            i -= 1
        for k in range(i + 1, end + 1):
            drop.add(k)
        # One blank line after the definition, if dropping it does not join two code lines.
        if end + 1 < len(lines) and lines[end + 1].strip() == "":
            drop.add(end + 1)
        total += 1
    out = [l for k, l in enumerate(lines) if k not in drop]
    # Collapse any run of 3+ blank lines the removal created down to one.
    cleaned = []
    for l in out:
        if l.strip() == "" and cleaned and cleaned[-1].strip() == "":
            continue
        cleaned.append(l)
    open(path, "w").write("\n".join(cleaned))
    print(f"{path}: removed {len(group)} definition(s), {len(drop)} lines")
print(f"total definitions removed: {total}")
