# review images for patch 0058. usage: render2.py <pairs.json> <verdicts.json> <groups116.json> <before-scan> <outdir>
import json,os,sys,math,collections,re
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d.art3d import Poly3DCollection
SP=os.environ["SP"]
pj,vj,gj,bscan,OUT=sys.argv[1:6]
os.makedirs(OUT,exist_ok=True)
data=json.load(open(pj)); verd=json.load(open(vj)); groups=json.load(open(gj))
before={}
for l in open(bscan):
    m=re.match(r"(\w+) (\d+) (\d+) .*?exit=(\d+)",l)
    if m: before[f"{m.group(1)} {m.group(2)} {m.group(3)}"]=("crash" if m.group(4)=="139" else "throw" if m.group(4)=="4" else ("path" if "done=1" in l else "notdone"))
byk={f"{d['shape']} {d['i']} {d['j']}":d for d in data}
VIEWS={"iso":(-55,26),"iso2":(125,26),"top":(-90,89)}
OCTA={"iso":(25,24),"iso2":(115,24),"top":(-90,89)}
meshes={}
def mesh(sh):
    if sh not in meshes:
        faces={};cur=None
        for l in open(f"{SP}/viz/{sh}.mesh"):
            t=l.split()
            if t[0]=="F": cur=int(t[1]);faces[cur]=[]
            else:
                v=[float(x) for x in t[1:]]; faces[cur].append([v[0:3],v[3:6],v[6:9]])
        meshes[sh]=faces
    return meshes[sh]
def bedges(tris):
    cnt=collections.Counter()
    for t in tris:
        for a in range(3):
            p,q=t[a],t[(a+1)%3]
            cnt[tuple(sorted([tuple(round(x,4) for x in p),tuple(round(x,4) for x in q)]))]+=1
    return [k for k,c in cnt.items() if c==1]
def draw(ax,d,view="iso",guides=False,result=True,labels=False):
    sh,i,j=d["shape"],d["i"],d["j"]; F=mesh(sh)
    ax.computed_zorder=False
    allp=[]
    for k,tris in F.items():
        col=(0.75,0.75,0.78,0.12)
        if k==i: col=(0.85,0.1,0.1,0.5)
        if k==j: col=(0.1,0.3,0.9,0.5)
        if i==j and k==i: col=(0.6,0.2,0.6,0.5)
        ax.add_collection3d(Poly3DCollection(tris,facecolors=[col],edgecolors=[(0,0,0,0)],linewidths=0,zorder=1))
        for t in tris: allp+=t
        hl=k in (i,j)
        for p,q in bedges(tris):
            ax.plot([p[0],q[0]],[p[1],q[1]],[p[2],q[2]],color=(0.1,0.1,0.1,0.9 if hl else 0.55),lw=1.1 if hl else 0.7,zorder=2)
        if labels:
            pts=[p for t in tris for p in t]; c=[sum(q[a] for q in pts)/len(pts) for a in range(3)]
            ax.text(c[0]*1.02,c[1]*1.02,c[2]*1.02,str(k),fontsize=9,color="k",zorder=20,ha="center")
    xs,ys,zs=zip(*allp)
    c=[(max(a)+min(a))/2 for a in (xs,ys,zs)]; r=max(max(a)-min(a) for a in (xs,ys,zs))/2*1.08
    ax.set_xlim(c[0]-r,c[0]+r);ax.set_ylim(c[1]-r,c[1]+r);ax.set_zlim(c[2]-r,c[2]+r); ax.set_box_aspect((1,1,1)); ax.set_axis_off()
    az,el=(OCTA if sh=="octa" else VIEWS)[view]; ax.view_init(elev=el,azim=az)
    if guides:
        cm=plt.get_cmap("tab10")
        for n,p in enumerate(d["paths"]):
            col=cm(n%10); last=None
            for kind,v in p:
                if kind=="E": ax.plot([v[0],v[3]],[v[1],v[4]],[v[2],v[5]],color=col,lw=2.4,zorder=10); last=v[3:6]
                else: last=v
            if last: ax.scatter([last[0]],[last[1]],[last[2]],color=col,s=30,edgecolors="k",zorder=11)
    if result:
        for pl in d["poly"]:
            a,b,cc=zip(*pl); ax.plot(a,b,cc,color="k",lw=4,zorder=12)
        if d["poly"]:
            e=[d["poly"][0][0],d["poly"][-1][-1]]
            ax.scatter([e[0][0],e[1][0]],[e[0][1],e[1][1]],[e[0][2],e[1][2]],color="k",s=26,zorder=13)
def status(d):
    k=f"{d['shape']} {d['i']} {d['j']}"; b=before.get(k,"?")
    if d["done"]==1:
        v=verd.get(k,{})
        new = b!="path"
        tag=("NEW path" if new else "path (as before)")
        return tag+(", doubtful" if not v.get("sensible",True) else ""), ("#b36b00" if not v.get("sensible",True) else "#1b7f3b")
    if d["exit"]==4: return "throws (as before)" if b=="throw" else "throws","#555555"
    return ("refused, was a crash" if b=="crash" else "not done (as before)" if b=="notdone" else "refused (was a throw)"),"#b00020" if b=="crash" else "#555555"
def sheet(sh,fn,cols=5,disjoint_only=True):
    ds=[d for d in data if d["shape"]==sh and (not disjoint_only or (d["sv"]==0 and not d["same"]))]
    if not ds: return
    rows=math.ceil(len(ds)/cols)
    fig=plt.figure(figsize=(3.2*cols,3.3*rows))
    for n,d in enumerate(ds):
        ax=fig.add_subplot(rows,cols,n+1,projection="3d"); draw(ax,d,"iso")
        t,c=status(d); ax.set_title(f"{d['i']} / {d['j']}\n{t}",fontsize=8,color=c)
    fig.suptitle(f"{sh}: every pair of faces that share no vertex (red = start face, blue = end face, black = the path returned)",fontsize=11)
    fig.tight_layout(rect=(0,0,1,0.97)); fig.savefig(fn,dpi=80); plt.close(fig)
def detail(d,fn,labels=False,note=None):
    fig=plt.figure(figsize=(15,5.4))
    for n,(view,gd,res,ttl) in enumerate([("iso",False,True,"isometric: the path returned (black)"),("iso2",False,True,"from the other side"),("iso",True,False,"what Build() traces from each start vertex (dots = where it stops)")]):
        ax=fig.add_subplot(1,3,n+1,projection="3d"); draw(ax,d,view,guides=gd,result=res,labels=labels); ax.set_title(ttl,fontsize=9)
    t,c=status(d); k=f"{d['shape']} {d['i']} {d['j']}"; v=verd.get(k,{})
    sub=f"  length {v['length']:.2f}, straight chord {v['chord']:.2f}, longest guide {v['guide_max']:.2f}" if v else ""
    fig.suptitle(f"{d['shape']}  start face {d['i']} (red)  end face {d['j']} (blue):  {t}{sub}"+(f"\n{note}" if note else ""),fontsize=11,color="k")
    fig.tight_layout(rect=(0,0,1,0.9)); fig.savefig(fn,dpi=85); plt.close(fig)
if __name__=="__main__":
    mode=sys.argv[6] if len(sys.argv)>6 else "all"
    if mode in("all","sheets"):
        for sh in sorted({d["shape"] for d in data}): sheet(sh,f"{OUT}/sheet-{sh}.png",cols=6 if sh in("star","oct8") else 5)
    if mode in("all","details"):
        sel=json.load(open(sys.argv[7])) if len(sys.argv)>7 else []
        for k in sel:
            d=byk[k]; detail(d,f"{OUT}/pair-{d['shape']}-{d['i']}-{d['j']}.png",labels=(d["shape"]=="octa"))
