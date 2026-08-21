import re,os,sys,collections
H="Libraries/OCCT.xcframework/macos-arm64/Headers"
BR="Sources/OCCTBridge/src"

def occt_public_methods(cls):
    """Public methods declared in an OCCT header, excluding ctors/dtor/operators/DEFINE_ macros."""
    p=f"{H}/{cls}.hxx"
    if not os.path.exists(p): return None
    src=open(p,errors="ignore").read()
    src=re.sub(r'//[^\n]*','',src)
    src=re.sub(r'/\*.*?\*/','',src,flags=re.S)
    # crude but consistent: Standard_EXPORT or inline decls with a name followed by (
    names=set()
    for m in re.finditer(r'\b([A-Z][A-Za-z0-9_]*)\s*\(', src):
        n=m.group(1)
        if n==cls or n.startswith("DEFINE_") or n in {"Standard_EXPORT","NCollection_Sequence","Handle"}: continue
        names.add(n)
    return names

def bridge_calls(cls, files):
    """Distinct OCCT methods our bridge invokes on this class, by ->Method( / ::Method( near the class."""
    used=set()
    for f in files:
        p=f"{BR}/{f}"
        if not os.path.exists(p): continue
        src=open(p,errors="ignore").read()
        if cls not in src: continue
        for m in re.finditer(rf'{cls}::([A-Za-z][A-Za-z0-9_]*)\s*\(', src): used.add(m.group(1))
        # instance calls: find variables declared of this type, then their -> / . calls
        for vm in re.finditer(rf'\b{cls}\b[\s&*]+([a-z][A-Za-z0-9_]*)', src):
            v=vm.group(1)
            for cm in re.finditer(rf'\b{v}\s*(?:->|\.)\s*([A-Za-z][A-Za-z0-9_]*)\s*\(', src): used.add(cm.group(1))
        for vm in re.finditer(rf'Handle\({cls}\)\s+([a-zA-Z][A-Za-z0-9_]*)', src):
            v=vm.group(1)
            for cm in re.finditer(rf'\b{v}\s*(?:->|\.)\s*([A-Za-z][A-Za-z0-9_]*)\s*\(', src): used.add(cm.group(1))
    return used

SAMPLE=sys.argv[1:] if len(sys.argv)>1 else []
# Scan .mm AND the in-src headers: this repo hosts shared helpers in OCCTBridge_Internal.h
# as inline (CLAUDE.md's reach rule), so a .mm-only scan misses the most-shared call sites.
ALL=[f for f in os.listdir(BR) if f.endswith(".mm") or f.endswith(".h")]
print(f"{'OCCT class':<44} {'public':>7} {'we call':>8} {'cover':>7}")
print("-"*72)
rows=[]
for cls in SAMPLE:
    pub=occt_public_methods(cls)
    if pub is None: print(f"{cls:<44} {'no header':>7}"); continue
    used=bridge_calls(cls, ALL)
    hit=used & pub
    pct=100*len(hit)/max(1,len(pub))
    rows.append((cls,len(pub),len(hit),pct,sorted(pub-hit)))
    print(f"{cls:<44} {len(pub):>7} {len(hit):>8} {pct:>6.0f}%")
print()
for cls,n,h,pct,missing in sorted(rows,key=lambda r:r[3]):
    print(f"== {cls}: not reached ({len(missing)}) ==")
    print("   "+", ".join(missing[:24])+(" ..." if len(missing)>24 else ""))
