import re,subprocess,sys,collections
probe,scan=sys.argv[1],sys.argv[2]
rows=[]
for l in open(scan):
    m=re.match(r"(\w+) (\d+) (\d+) sharedVerts=0 .*exit=139",l)
    if m and "same=1" not in l: rows.append(m.groups())
g=collections.defaultdict(list)
for sh,i,j in rows:
    r=subprocess.run([probe,"pair",sh,i,j],capture_output=True,text=True,timeout=60)
    m=re.search(r"GUARD (\S+) i=(\d+) j=(\d+)",r.stderr)
    done=re.search(r"done=(\d)",r.stdout)
    g[(m.group(1) if m else "none", done.group(1) if done else "?", r.returncode)].append(f"{sh} {i} {j}")
print(len(rows),"crashing pairs with no shared vertex")
for k,v in sorted(g.items()): print(k,len(v),v[:6])
