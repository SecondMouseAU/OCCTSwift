import json,os,sys,math
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d.art3d import Poly3DCollection
SP=os.environ["SP"]; OUT=sys.argv[1]
os.makedirs(OUT,exist_ok=True)
data=json.load(open(SP+"/viz/pairs.json"))
GROUP={"pad-start-path(j-1)":"G1","pad-end-path":"G1","E1-previous-level":"G2","E2-previous-level":"G2","no-common-face":"G3"}
GNAME={"G1":"G1 a path stops short of the end face","G2":"G2 a path is a bare vertex with no edge before it","G3":"G3 no face holds the path edge and the section edge"}
VIEW={"hex":(35,22),"lshape":(-60,28),"ushape":(-60,28),"tube":(30,22),"octa":(35,22),"box":(35,22)}
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
def verdict(d):
    if d["before_exit"]==139:
        g=GROUP.get(d["guard"],"?")
        return "crash","pinned kernel: SIGSEGV   |   patched: refused (no path)",g
    if d["before_exit"]==0: return "ok","kernel answers a path (unchanged by the patch)",None
    return "throw","kernel throws, bridge answers nil (unchanged)",None
def draw(ax,d,paths=True,result=True,fixed=False):
    sh,i,j=d["shape"],d["i"],d["j"]
    F=mesh(sh)
    allp=[]
    for k,tris in F.items():
        col=(0.75,0.75,0.78,0.10)
        if k==i: col=(0.85,0.1,0.1,0.55)
        if k==j: col=(0.1,0.3,0.9,0.55)
        pc=Poly3DCollection(tris,facecolors=[col],edgecolors=[(0.2,0.2,0.2,0.0)],linewidths=0.0,zorder=1)
        ax.add_collection3d(pc)
        for t in tris: allp+=t
    ax.computed_zorder=False
    xs,ys,zs=zip(*allp)
    c=[(max(a)+min(a))/2 for a in (xs,ys,zs)]; r=max(max(a)-min(a) for a in (xs,ys,zs))/2*1.05
    ax.set_xlim(c[0]-r,c[0]+r);ax.set_ylim(c[1]-r,c[1]+r);ax.set_zlim(c[2]-r,c[2]+r)
    ax.set_box_aspect((1,1,1)); ax.set_axis_off()
    def cen(k):
        pts=[p for t in F[k] for p in t]; return [sum(q[a] for q in pts)/len(pts) for a in range(3)]
    ci,cj=cen(i),cen(j)
    az=math.degrees(math.atan2(cj[1]-ci[1],cj[0]-ci[0]))+55
    if abs(cj[0]-ci[0])+abs(cj[1]-ci[1])<1e-6: az=35
    el=VIEW.get(sh,(0,24))[1] if False else 28
    if sh=='octa': az,el=25,24
    if fixed: az,el=(25,24) if sh=='octa' else (-55,26)
    ax.view_init(elev=el,azim=az)
    import collections
    for k,tris in F.items():
        cnt=collections.Counter()
        for t in tris:
            for a in range(3):
                p,q=t[a],t[(a+1)%3]
                key=tuple(sorted([tuple(round(x,4) for x in p),tuple(round(x,4) for x in q)]))
                cnt[key]+=1
        for key,c in cnt.items():
            if c==1:
                p,q=key
                hl=k in (i,j)
                ax.plot([p[0],q[0]],[p[1],q[1]],[p[2],q[2]],color=(0.15,0.15,0.15,0.9 if hl else 0.5),lw=1.0 if hl else 0.6,zorder=2)
    if paths:
        cm=plt.get_cmap("tab10")
        for n,p in enumerate(d["paths"]):
            col=cm(n%10); last=None
            for kind,v in p:
                if kind=="E":
                    ax.plot([v[0],v[3]],[v[1],v[4]],[v[2],v[5]],color=col,lw=2.6,zorder=10); last=v[3:6]
                else:
                    ax.scatter([v[0]],[v[1]],[v[2]],color=col,s=30,marker="s",zorder=10); last=v
            if last: ax.scatter([last[0]],[last[1]],[last[2]],color=col,s=34,edgecolors="k",zorder=11)
    if result:
        for pl in d["poly"]:
            a,b,cc=zip(*pl); ax.plot(a,b,cc,color="k",lw=4,zorder=12)
def title(d):
    kind,txt,g=verdict(d)
    t=f"{d['shape']}  faces {d['i']} (red) and {d['j']} (blue)"
    if g: t+=f"\n{GNAME[g]}"
    return t+"\n"+txt
def detail(d,fn):
    fig=plt.figure(figsize=(11,5.6))
    a=fig.add_subplot(1,2,1,projection="3d"); draw(a,d,paths=False,result=False); a.set_title("the input: start face red, end face blue",fontsize=10)
    b=fig.add_subplot(1,2,2,projection="3d"); draw(b,d,paths=True,result=True)
    b.set_title("what Build() traces: one coloured path per start vertex (dots = where it stopped)" if d["paths"] and not d["poly"] else "the middle path (black) the kernel returns",fontsize=9)
    fig.suptitle(title(d),fontsize=11)
    fig.tight_layout(rect=(0,0,1,0.9)); fig.savefig(fn,dpi=110); plt.close(fig)
def sheet(sh,fn,cols=4):
    ds=[d for d in data if d["shape"]==sh]
    rows=math.ceil(len(ds)/cols)
    fig=plt.figure(figsize=(3.3*cols,3.5*rows))
    for n,d in enumerate(ds):
        ax=fig.add_subplot(rows,cols,n+1,projection="3d"); draw(ax,d,paths=False,result=True,fixed=True)
        kind,txt,g=verdict(d)
        colr={"crash":"#b00020","ok":"#1b7f3b","throw":"#555555"}[kind]
        lab={"crash":f"{g}: crash -> refused","ok":"returns a path","throw":"throws -> nil"}[kind]
        ax.set_title(f"{d['i']} / {d['j']}\n{lab}",fontsize=9,color=colr)
    fig.suptitle(f"{sh}: every pair of faces with no shared vertex (red = start face, blue = end face)",fontsize=11)
    fig.tight_layout(rect=(0,0,1,0.97)); fig.savefig(fn,dpi=90); plt.close(fig)
if __name__=="__main__":
    reps=[("hex",0,2),("hex",0,4),("tube",1,3),("lshape",0,2),("ushape",0,2),("ushape",4,7),("octa",0,6),("hex",0,3),("tube",1,2)]
    for sh,i,j in reps:
        d=next(x for x in data if x["shape"]==sh and x["i"]==i and x["j"]==j)
        detail(d,f"{OUT}/pair-{sh}-{i}-{j}.png")
    for sh in sorted({d["shape"] for d in data if d["before_exit"]==139}):
        sheet(sh,f"{OUT}/sheet-{sh}.png")
