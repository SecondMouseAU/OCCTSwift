import re,sys
def load(f):
    d={}
    for l in open(f):
        m=re.match(r"(\w+) (\d+) (\d+) ",l)
        if not m: continue
        ex=re.search(r"exit=(\d+)",l).group(1)
        sig=re.search(r"-> (.*?)\s+exit=",l)
        sv=int(re.search(r"sharedVerts=(\d+)",l).group(1)); same=re.search(r"same=(\d)",l).group(1)
        d[m.groups()]=(ex,sig.group(1) if sig else "",sv,same)
    return d
b=load(sys.argv[1]); a=load(sys.argv[2])
import collections
c=collections.Counter()
for k in b:
    c[(b[k][0],a[k][0])]+=1
print(c)
# a pair that returned a path before must return the same one (edge count, length, centre of mass)
bad=[k for k in b if b[k][0]=="0" and b[k][1]!=a[k][1]]
print("pairs that returned a path before and a different answer after:",len(bad),bad)
print("pairs whose answer is a path, before / after:",sum("done=1" in b[k][1] for k in b),"/",sum("done=1" in a[k][1] for k in a))
dis=lambda d,k:d[k][2]==0 and d[k][3]=="0"
print("no shared vertex, not the same face (%d): before %s, after %s"%(sum(dis(b,k) for k in b),
      dict(collections.Counter(b[k][0] for k in b if dis(b,k))),dict(collections.Counter(a[k][0] for k in a if dis(a,k)))))
rest=[k for k in a if a[k][0] not in("0","4")]
print("still aborting after (all share a vertex or are the same face, which the bridge refuses):",len(rest),
      "of which share no vertex:",sum(dis(a,k) for k in rest))
