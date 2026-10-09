import re,collections,sys
c=collections.Counter(); allc=collections.Counter()
for l in open(sys.argv[1]):
    m=re.match(r"(\w+) (\d+) (\d+) sharedVerts=(\d+) .*same=(\d)",l)
    if not m: continue
    e=re.search(r"exit=(\d+)",l).group(1); d=re.search(r"done=(\d)",l)
    allc[(e)]+=1
    if m.group(4)=="0" and m.group(5)=="0": c[(e,d.group(1) if d else "-")]+=1
print("all 573 by exit:",dict(allc)); print("disjoint 196 (exit,done):",dict(c))
