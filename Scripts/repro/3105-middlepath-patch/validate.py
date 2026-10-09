# geometric validation of every pair the patched kernel answers. usage: validate.py <pairs.json> <scan-before.txt> <groups116.json>
import json,re,sys,math,collections
data=json.load(open(sys.argv[1])); before=open(sys.argv[2]).read(); groups=json.load(open(sys.argv[3]))
prev=set()
for l in before.splitlines():
    m=re.match(r"(\w+) (\d+) (\d+) .*done=1",l)
    if m: prev.add(" ".join(m.groups()))
CONVEX={"box","cyl","cone","octa","hex","tri","pent","oct8","frustum","capsule"}
import os
def inbox(d):
    pts=[]
    for l in open(os.environ["SP"]+"/viz/"+d["shape"]+".mesh"):
        if l.startswith("T "):
            v=[float(x) for x in l.split()[1:]]; pts+= [v[0:3],v[3:6],v[6:9]]
    lo=[min(p[a] for p in pts)-1e-6 for a in range(3)]; hi=[max(p[a] for p in pts)+1e-6 for a in range(3)]
    return all(lo[a]<=q[a]<=hi[a] for pl in d["poly"] for q in pl for a in range(3))
def self_cross(d):
    pts=[p for pl in d["poly"] for p in pl]
    # drop repeated points; test the planar polyline for a crossing between non-adjacent segments
    q=[pts[0]]
    for p in pts[1:]:
        if math.dist(p,q[-1])>1e-9: q.append(p)
    zs=[p[2] for p in q]
    if max(zs)-min(zs)>1e-6: return False   # not planar in z: not tested
    def ccw(a,b,c): return (c[1]-a[1])*(b[0]-a[0])-(b[1]-a[1])*(c[0]-a[0])
    def inter(a,b,c,e):
        d1,d2,d3,d4=ccw(a,b,c),ccw(a,b,e),ccw(c,e,a),ccw(c,e,b)
        return d1*d2<-1e-12 and d3*d4<-1e-12
    n=len(q)-1
    for i in range(n):
        for j in range(i+2,n):
            if inter(q[i],q[i+1],q[j],q[j+1]): return True
    return False
def cat(d):
    k=f"{d['shape']} {d['i']} {d['j']}"
    if k in prev: return "previously returned"
    if k in groups: return groups[k]+" (was a crash)"
    if d["sv"]>0 or d["same"]: return "shares a vertex / same face"
    return "other"
def guide_len(paths):
    out=[]
    for p in paths:
        t=0
        for kind,v in p:
            if kind=="E": t+=math.dist(v[:3],v[3:6])
        out.append(t)
    return out
verd={};rows=[];res=collections.defaultdict(lambda:collections.Counter()); fails=collections.defaultdict(list)
for d in data:
    if d["done"]!=1: continue
    c=d["check"]; cat_=cat(d)
    if not c: fails[cat_].append((d,"no CHECK line")); res[cat_]["n"]+=1; continue
    kv=dict(x.split("=",1) for x in c.split())
    f=lambda k: float(kv[k])
    g=guide_len(d["paths"]); gmax=max(g) if g else 0; gmin=min(g) if g else 0
    tests={
     "valid(BRepCheck)":kv["valid"]=="1","is wire":kv["type"]=="5","connected":kv["connected"]=="1",
     "ends at section centroids":f("d0")<1e-6 and f("d1")<1e-6,
     "ends in section planes":(f("plane0")<1e-6 or f("plane0")<0) and (f("plane1")<1e-6 or f("plane1")<0),
     "length>=chord":f("length")>=f("chord")-1e-6,
     "length<=longest guide":f("length")<=gmax*(1+1e-6)+1e-6,
     "path inside the solid (convex solids) or its bounding box":(kv.get("out","0/1").split("/")[0]=="0") if d["shape"] in CONVEX else inbox(d),
     "no self-crossing (paths in a plane)":not self_cross(d),
     "deterministic":bool(d["deterministic"]),
    }
    verd[f"{d['shape']} {d['i']} {d['j']}"]={"cat":cat_,"sensible":all(tests.values()),"failed":[k for k,v in tests.items() if not v],"length":f("length"),"chord":f("chord"),"guide_max":gmax,"out":kv.get("out")}
    res[cat_]["n"]+=1
    for k,v in tests.items():
        if v: res[cat_][k]+=1
        else: fails[cat_].append((d,k,c,[round(x,3) for x in g]))
out=[]
for cat_,cn in sorted(res.items()):
    n=cn["n"]; out.append(f"## {cat_}: {n} pairs")
    for k in ["valid(BRepCheck)","is wire","connected","ends at section centroids","ends in section planes","length>=chord","length<=longest guide","path inside the solid (convex solids) or its bounding box","no self-crossing (paths in a plane)","deterministic"]:
        out.append(f"  {k}: {cn[k]}/{n}")
for cat_,fl in fails.items():
    for x in fl: out.append(f"FAIL [{cat_}] {x[0]['shape']} {x[0]['i']}/{x[0]['j']}: {x[1]}  {x[2:] if len(x)>2 else ''}")
print("\n".join(out))

json.dump(verd,open(sys.argv[1].replace(".json","-verdicts.json"),"w"))
