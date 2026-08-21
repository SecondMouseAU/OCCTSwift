"""Bridge functions that declare a parameter and never read it.
A dead parameter means the caller's input cannot affect the answer."""
import re,os,sys
BR="Sources/OCCTBridge/src"
def strip(s):
    s=re.sub(r'/\*.*?\*/','',s,flags=re.S)
    return re.sub(r'//[^\n]*','',s)
hits=[]
for fn in sorted(os.listdir(BR)):
    if not (fn.endswith(".mm") or fn.endswith(".h")): continue
    src=open(f"{BR}/{fn}",errors="ignore").read()
    # public bridge definitions: return type, OCCT-prefixed name, params, brace body
    for m in re.finditer(r'^[A-Za-z_][\w \*\_\(\)]*?\b(OCCT[A-Za-z0-9_]+)\s*\(([^)]*)\)\s*\n?\{', src, re.M):
        name,params=m.group(1),m.group(2)
        if params.strip() in ("","void"): continue
        # extract body by brace matching
        i=src.index("{",m.start()); d=0
        for j in range(i,len(src)):
            if src[j]=="{": d+=1
            elif src[j]=="}":
                d-=1
                if d==0: break
        body=strip(src[i:j+1])
        pnames=[]
        for p in params.split(","):
            p=p.strip().replace("_Nonnull","").replace("_Nullable","")
            w=re.findall(r'\b([A-Za-z_]\w*)\s*(?:\[\s*\])?$',p)
            TYPES={"void","const","int32_t","int64_t","double","float","bool","char","unsigned","size_t"}
            if w and w[0] not in TYPES and not w[0].startswith("OCCT") and not w[0].endswith("Ref"):
                pnames.append(w[0])
        dead=[p for p in pnames if not re.search(rf'\b{re.escape(p)}\b', body)]
        if dead:
            hits.append((fn,src[:m.start()].count("\n")+1,name,dead,len(pnames)))
print(f"{len(hits)} bridge function(s) with an unread parameter\n")
for fn,ln,name,dead,total in sorted(hits,key=lambda h:-len(h[3])):
    print(f"  {fn}:{ln}  {name}")
    print(f"      unread: {', '.join(dead)}   ({len(dead)} of {total})")
