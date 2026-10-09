# gathers, for every pair of scan.txt, the traced paths, the guard that fired and (when done) the result checks,
# running a done pair three times to test determinism. usage: gather2.py <probe_ret> <scan.txt> <out.json>
import re,subprocess,json,sys,os
probe,scan,outj=sys.argv[1:4]
SP=os.environ["SP"]
rows=[]
for l in open(scan):
    m=re.match(r"(\w+) (\d+) (\d+) sharedVerts=(\d+) .*?same=(\d).*?exit=(\d+)",l)
    if m: rows.append((m.group(1),int(m.group(2)),int(m.group(3)),int(m.group(4)),int(m.group(5)),int(m.group(6))))
def run(sh,i,j,check=True):
    env=dict(os.environ,CHECK="1") if check else os.environ
    return subprocess.run([probe,"pair",sh,str(i),str(j)],capture_output=True,text=True,timeout=120,env=env)
shapes=sorted({r[0] for r in rows})
for sh in shapes:
    f=f"{SP}/viz/{sh}.mesh"
    if not os.path.exists(f): subprocess.run([probe,"mesh",sh,f],check=True)
data=[]
for sh,i,j,sv,same,ex in rows:
    r=run(sh,i,j)
    paths=[]
    for l in r.stderr.splitlines()+r.stdout.splitlines():
        if "PATH " in l:
            t=l[l.index("PATH "):].split(); segs=[];k=2
            while k<len(t):
                if t[k]=="E": segs.append(("E",[float(x) for x in t[k+1:k+7]])); k+=7
                elif t[k]=="V": segs.append(("V",[float(x) for x in t[k+1:k+4]])); k+=4
                else: break
            paths.append(segs)
    g=re.search(r"GUARD line=(\d+)",r.stderr)
    lev=re.search(r"LEVELS i=(\d+) solidEdges=(\d+)",r.stderr)
    done=re.search(r"done=(\d)",r.stdout)
    exc=re.search(r"exception (.*)",r.stdout)
    d=dict(shape=sh,i=i,j=j,sv=sv,same=same,scan_exit=ex,exit=r.returncode,guard=int(g.group(1)) if g else None,
           done=int(done.group(1)) if done else None,exc=exc.group(1).strip() if exc else None,paths=paths,levels=[int(lev.group(1)),int(lev.group(2))] if lev else None,poly=[],check=None,deterministic=None)
    if d["done"]==1:
        c=re.search(r"CHECK (.*)",r.stdout); d["check"]=c.group(1).strip() if c else None
        sigs={d["check"]}
        for _ in range(2):
            r2=run(sh,i,j); c2=re.search(r"CHECK (.*)",r2.stdout); sigs.add(c2.group(1).strip() if c2 else None)
        d["deterministic"]=len(sigs)==1
        pr=subprocess.run([probe,"pathpoly",sh,str(i),str(j),f"{SP}/viz/pp.txt"],capture_output=True)
        d["polyfail"]=pr.returncode!=0
        for l in (open(f"{SP}/viz/pp.txt") if pr.returncode==0 else []):
            if l.startswith("L "):
                v=[float(x) for x in l.split()[1:]]; d["poly"].append([v[a:a+3] for a in range(0,len(v),3)])
    data.append(d)
json.dump(data,open(outj,"w"))
print(len(data),"pairs")
