import subprocess,os,re,sys,json
R="/Users/elb/Projects/worktrees/resweep-2983-leftovers"
H="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/libexec/swift/pm/swiftpm-testing-helper"
ANSI=re.compile(r"\x1b\[[0-9;]*m")
FAIL=re.compile(r'^✘ Test (?:"((?:[^"\\]|\\.)*)"|(\w+)\(\)) (?:recorded an issue|failed)',re.M)
T={"OCCTAnalysisTests":"CanonicalRecognitionDetailed|HatchBuilder","OCCTGeom2dTests":"AxisPlacement2D","OCCTBRepGraphTests":"Issue1078|Issue336"}
SW=[l.split() for l in open("switches.txt") if l.strip()]
def run(t,sw):
    b=f"{R}/.build/out/Products/Debug/{t}.xctest/Contents/MacOS/{t}"
    env=dict(os.environ); env.pop("SW",None)
    if sw: env["SW"]=sw
    for _ in range(4):
        p=subprocess.run([H,"--test-bundle-path",b,"--filter",T[t],b,"--testing-library","swift-testing"],capture_output=True,text=True,env=env,timeout=600)
        if p.returncode in(-15,143): continue
        break
    out=ANSI.sub("",p.stdout+p.stderr)
    red=sorted({(m.group(1) or m.group(2)+"()") for m in FAIL.finditer(out) if not (m.group(1) or "").startswith("run with")})
    red=[r for r in red if not r.startswith("Test run") ]
    return p.returncode,red
label=sys.argv[1]
res={}
for t in T:
    c,r=run(t,""); print(f"[{label}] baseline {t} exit={c} red={r}")
for sw,t in SW:
    c,r=run(t,sw)
    crash=c<0 or c>1
    print(f"{sw:22s} {t:20s} exit={c} {'CRASH ' if crash else ''}red={len(r)} {r}")
    res[sw]=r
json.dump(res,open(f"matrix-{label}.json","w"),indent=1)
