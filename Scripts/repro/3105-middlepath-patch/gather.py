import re,subprocess,json,sys,os
SP=os.environ["SP"]
rows=[]
for l in open(SP+"/scan-before.txt"):
    m=re.match(r"(\w+) (\d+) (\d+) sharedVerts=0 .*?exit=(\d+)",l)
    if m and "same=1" not in l: rows.append((m.group(1),int(m.group(2)),int(m.group(3)),int(m.group(4))))
shapes=sorted({r[0] for r in rows})
for sh in shapes:
    subprocess.run([SP+"/probe_v","mesh",sh,f"{SP}/viz/{sh}.mesh"],check=True)
data=[]
for sh,i,j,ex in rows:
    r=subprocess.run([SP+"/probe_v","pair",sh,str(i),str(j)],capture_output=True,text=True,timeout=60)
    paths=[]
    for l in r.stderr.splitlines()+r.stdout.splitlines():
        if "PATH " in l:
            t=l[l.index("PATH "):].split()
            segs=[];k=2
            while k<len(t):
                if t[k]=="E": segs.append(("E",[float(x) for x in t[k+1:k+7]])); k+=7
                elif t[k]=="V": segs.append(("V",[float(x) for x in t[k+1:k+4]])); k+=4
                else: break
            paths.append(segs)
    g=re.search(r"GUARD (\S+) i=(\d+) j=(\d+)",r.stderr)
    done=re.search(r"done=(\d)",r.stdout)
    poly=[]
    if done and done.group(1)=="1":
        subprocess.run([SP+"/probe_v","pathpoly",sh,str(i),str(j),f"{SP}/viz/pp.txt"],check=True)
        for l in open(SP+"/viz/pp.txt"):
            if l.startswith("L "):
                v=[float(x) for x in l.split()[1:]]; poly.append([v[a:a+3] for a in range(0,len(v),3)])
    data.append(dict(shape=sh,i=i,j=j,before_exit=ex,guard=g.group(1) if g else None,guard_ij=[int(g.group(2)),int(g.group(3))] if g else None,done=int(done.group(1)) if done else None,paths=paths,poly=poly))
json.dump(data,open(SP+"/viz/pairs.json","w"))
print(len(data),"pairs;",len(shapes),"solids:",shapes)
