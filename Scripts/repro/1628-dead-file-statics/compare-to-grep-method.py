"""#1628's own stated method, reproduced literally, to explain the divergence.

  # for each .mm: every `static <type> name(...)` whose name appears once in the file (the definition)
"""
import glob, re, os, importlib.util, collections

spec = importlib.util.spec_from_file_location("c", "Scripts/census-dead-file-statics.py")
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)

NAIVE = re.compile(r"^static\s+[\w\s\*&:<>,]*?\b([A-Za-z_]\w*)\s*\(", re.M)
naive = set()
for path in sorted(glob.glob("Sources/OCCTBridge/src/*.mm")):
    raw = open(path).read()
    for mt in NAIVE.finditer(raw):
        name = mt.group(1)
        if len(re.findall(rf"\b{re.escape(name)}\b", raw)) == 1:
            naive.add((path, name, raw.count("\n", 0, mt.start()) + 1))

mine = set()
for path in sorted(glob.glob("Sources/OCCTBridge/src/*.mm")):
    raw = open(path).read()
    prep = m.prepare(raw)
    res = m.analyse_text(prep, m.header_names())
    for d in res["dead"]:
        mine.add((path, d["name"], d["line"]))

print("naive (#1628's literal method) today:", len(naive))
print("this script:                        ", len(mine))
only_naive = naive - mine
only_mine = mine - naive
print("\nin naive only:", len(only_naive))
print(collections.Counter(n for _, n, _ in only_naive).most_common(20))
print("\nin this script only:", len(only_mine))
print(collections.Counter(n for _, n, _ in only_mine).most_common(30))
