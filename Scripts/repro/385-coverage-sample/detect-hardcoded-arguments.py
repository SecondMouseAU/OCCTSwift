"""Probe: bare numeric literals passed as arguments to an OCCT constructor or method inside the
bridge. Distinct from #726, which looks at what a function RETURNS; this looks at what it PASSES."""
import re,os,collections
BR="Sources/OCCTBridge/src"
# a literal that is plausibly a tuning knob rather than an index/flag/identity
KNOB = re.compile(r'^-?(?:[2-9]\d*|\d+\.\d+|1\d+|0\.\d+|1e-?\d+)$')
SKIP_ARG = {"0","1","-1","2","3"}          # indices, dimensions, ordinals: too noisy alone
call = re.compile(r'\b([A-Z][A-Za-z0-9_]*(?:_[A-Za-z0-9_]+)?)\s*(?:\w+\s*)?\(([^();]{4,200})\)')
hits=collections.Counter(); sites=[]
for fn in sorted(os.listdir(BR)):
    if not fn.endswith(".mm"): continue
    src=open(f"{BR}/{fn}",errors="ignore").read()
    src=re.sub(r'//[^\n]*','',src)
    for i,line in enumerate(src.split("\n"),1):
        for m in call.finditer(line):
            cls,args=m.group(1),m.group(2)
            if not ("_" in cls or cls.startswith(("gp","Geom","BRep","Shape","Approx","Adaptor"))): continue
            parts=[a.strip() for a in args.split(",")]
            lits=[a for a in parts if KNOB.match(a) and a not in SKIP_ARG]
            if len(lits)>=2:                      # 2+ tuning literals in one call
                hits[fn]+=1; sites.append((fn,i,cls,", ".join(lits),line.strip()[:88]))
print(f"{sum(hits.values())} call site(s) passing 2+ bare tuning literals to an OCCT API\n")
for f,n in hits.most_common(): print(f"  {n:3}  {f}")
print()
for f,i,cls,lits,txt in sites[:14]: print(f"  {f}:{i}\n      {cls}  literals: {lits}\n      {txt}")
